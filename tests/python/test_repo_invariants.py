"""Unit tests for scripts/lib/repo_invariants.py (file-content repository invariants)."""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

ri = load_module("scripts/lib/repo_invariants.py")
SCRIPT = REPO_ROOT / "scripts" / "lib" / "repo_invariants.py"


def write(root: Path, rel: str, data: bytes | str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode() if isinstance(data, str) else data)
    return path


class TempRoot(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()


class TrackedFilesTest(TempRoot):
    def test_plain_directory_lists_every_file_but_git_internals(self):
        write(self.root, "b/two.txt", "2")
        write(self.root, "one.txt", "1")
        write(self.root, ".git/config", "x")
        self.assertEqual(ri.tracked_files(self.root), ["b/two.txt", "one.txt"])

    def test_git_work_tree_lists_tracked_files_only(self):
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(["git", "init", "-q", str(self.root)], check=True, env=env)
        write(self.root, "tracked.txt", "t")
        write(self.root, "untracked.txt", "u")
        subprocess.run(["git", "-C", str(self.root), "add", "tracked.txt"], check=True, env=env)
        self.assertEqual(ri.tracked_files(self.root), ["tracked.txt"])

    def test_subdirectory_of_a_work_tree_is_walked_as_files(self):
        with mock.patch.object(ri, "git_toplevel", return_value=Path("/elsewhere")):
            write(self.root, "f.txt", "f")
            self.assertEqual(ri.tracked_files(self.root), ["f.txt"])

    def test_git_unavailable(self):
        with mock.patch.object(ri.subprocess, "run", side_effect=OSError("no git")):
            self.assertIsNone(ri.git_toplevel(self.root))

    def test_read_bytes_of_a_missing_file_is_none(self):
        self.assertIsNone(ri.read_bytes(self.root, "gone.bin"))
        write(self.root, "f.bin", b"abcdef")
        self.assertEqual(ri.read_bytes(self.root, "f.bin", 2), b"ab")
        self.assertEqual(ri.read_bytes(self.root, "f.bin"), b"abcdef")


class WormIndicatorsTest(TempRoot):
    def test_folder_open_task_and_automatic_tasks(self):
        write(self.root, ".vscode/tasks.json", '{"tasks": [{"runOptions": {"runOn": "folderOpen"}}]}')
        write(self.root, ".vscode/settings.json", '{"task.allowAutomaticTasks": "on"}')
        problems = ri.worm_indicators(self.root, [".vscode/settings.json", ".vscode/tasks.json"])
        self.assertEqual(len(problems), 2)
        self.assertIn("sets task.allowAutomaticTasks", problems[0])
        self.assertIn("runOn: folderOpen", problems[1])

    def test_comments_nesting_and_trailing_commas_do_not_hide_the_payload(self):
        cases = {
            "a/.vscode/tasks.json": '{"tasks": [{"runOptions": {"runOn" /* c */ : "folderOpen",},},],}',
            "b/.vscode/tasks.json": '{"runOptions": {"runOn": // c\n "folderOpen"}}',
            "c/.vscode/settings.json": '{"task": {"allowAutomaticTasks": "on"}}',
            "d/x.code-workspace": '{"settings": {"task.allowAutomaticTasks": "on"}, "tasks": {"tasks": [{"runOptions": {"runOn": "folderOpen"}}]}}',
        }
        for rel, text in cases.items():
            write(self.root, rel, text)
            self.assertTrue(ri.worm_indicators(self.root, [rel]), rel)
        self.assertEqual(len(ri.worm_indicators(self.root, ["d/x.code-workspace"])), 2)

    def test_comment_markers_inside_strings_and_unterminated_comments(self):
        write(self.root, ".vscode/tasks.json", '{"label": "a // b /* c */ \\" d", "list": [1, 2,\n], } /* unterminated')
        self.assertEqual(ri.worm_indicators(self.root, [".vscode/tasks.json"]), [])

    def test_cr_terminated_line_comment_does_not_hide_a_member(self):
        # VS Code's scanner ends a // comment at a bare CR as well as at LF.
        write(self.root, "a/.vscode/tasks.json",
              '{"tasks": [{"label": "x", "command": "echo pwn" // c\r, "runOptions": {"runOn": "folderOpen"}\n}]}')
        write(self.root, "b/.vscode/settings.json", '{"editor.tabSize": 2 // c\r, "task.allowAutomaticTasks": "on"\n}')
        problems = ri.worm_indicators(self.root, ["a/.vscode/tasks.json", "b/.vscode/settings.json"])
        self.assertEqual(len(problems), 2)
        self.assertIn("runOn: folderOpen", problems[0])
        self.assertIn("sets task.allowAutomaticTasks", problems[1])

    def test_utf8_bom_is_ignored_like_vscode_does(self):
        bom = b"\xef\xbb\xbf"
        write(self.root, "a/.vscode/extensions.json", bom + b'{"recommendations": ["ms-python.python"]}')
        self.assertEqual(ri.worm_indicators(self.root, ["a/.vscode/extensions.json"]), [])
        write(self.root, "b/.vscode/settings.json", bom + b'{"task.allowAutomaticTasks": "on"}')
        problems = ri.worm_indicators(self.root, ["b/.vscode/settings.json"])
        self.assertEqual(len(problems), 1)
        self.assertIn("sets task.allowAutomaticTasks", problems[0])

    def test_parsed_structure_and_text_patterns_are_combined(self):
        # A duplicate key keeps only the last value in the parsed structure, but the literal
        # folder-open member is still in the file, so it is reported.
        write(self.root, ".vscode/tasks.json", '{"runOptions": {"runOn": "folderOpen", "runOn": "default"}}')
        problems = ri.worm_indicators(self.root, [".vscode/tasks.json"])
        self.assertEqual(len(problems), 1)
        self.assertIn("runOn: folderOpen", problems[0])

    def test_unparseable_config_is_flagged_and_still_pattern_matched(self):
        write(self.root, ".vscode/settings.json", "{'task.allowAutomaticTasks': 'on'}")
        write(self.root, ".vscode/notes.txt", 'runOn: "folderOpen"')
        problems = ri.worm_indicators(self.root, [".vscode/settings.json", ".vscode/notes.txt"])
        self.assertEqual(len(problems), 3)
        self.assertIn("cannot be parsed as JSON with comments", problems[0])
        self.assertIn("sets task.allowAutomaticTasks", problems[1])
        self.assertIn("runOn: folderOpen", problems[2])

    def test_ordinary_config_and_unrelated_files_pass(self):
        write(self.root, ".vscode/tasks.json", '{"tasks": [{"label": "build", "command": "make"}]}')
        write(self.root, "docs/runOn.md", 'Never use "runOn": "folderOpen" in a task.')
        self.assertEqual(ri.worm_indicators(self.root, [".vscode/tasks.json", "docs/runOn.md"]), [])

    def test_unicode_escaped_keys_are_decoded_like_vscode_does(self):
        write(self.root, ".vscode/tasks.json", '{"runOptions": {"runOn": "folder\\u004fpen"}}')
        write(self.root, ".vscode/settings.json", '{"task.allow\\u0041utomaticTasks": "on"}')
        problems = ri.worm_indicators(self.root, [".vscode/settings.json", ".vscode/tasks.json"])
        self.assertEqual(len(problems), 2)

    def test_tracked_but_deleted_config_is_skipped(self):
        self.assertEqual(ri.worm_indicators(self.root, [".vscode/tasks.json"]), [])

    def test_public_fonts_anywhere(self):
        problems = ri.worm_indicators(self.root, ["site/public/fonts/a.woff2", "public/fonts/b.woff2", "fonts/c.woff2"])
        self.assertEqual([p.split(":")[0] for p in problems], ["site/public/fonts/a.woff2", "public/fonts/b.woff2"])


class BinarySignaturesTest(TempRoot):
    def test_matching_signatures_pass(self):
        files = {
            "a.woff2": b"wOF2rest", "a.woff": b"wOFF", "a.ttf": b"true", "b.ttf": b"\x00\x01\x00\x00",
            "c.ttf": b"OTTO", "a.otf": b"OTTO", "a.eot": b"\x00" * 34 + b"LP",
            "a.png": b"\x89PNG\r\n\x1a\nIHDR", "a.jpg": b"\xff\xd8\xff\xe0", "a.JPEG": b"\xff\xd8\xff\xdb",
            "a.gif": b"GIF89a", "b.gif": b"GIF87a", "a.webp": b"RIFF\x00\x00\x00\x00WEBPVP8 ",
            "a.ico": b"\x00\x00\x01\x00", "a.bmp": b"BM", "notes.txt": b"anything",
        }
        for rel, data in files.items():
            write(self.root, rel, data)
        self.assertEqual(ri.binary_signatures(self.root, sorted(files)), [])

    def test_text_and_partial_signatures_fail(self):
        write(self.root, "font.woff2", "#!/bin/sh\necho pwned\n")
        write(self.root, "riff.webp", b"RIFF\x00\x00\x00\x00WAVE")
        problems = ri.binary_signatures(self.root, ["font.woff2", "riff.webp"])
        self.assertEqual(problems, [
            "font.woff2: not a .woff2 file (its bytes do not start with the format's signature)",
            "riff.webp: not a .webp file (its bytes do not start with the format's signature)",
        ])

    def test_tracked_but_deleted_file_is_skipped(self):
        self.assertEqual(ri.binary_signatures(self.root, ["gone.png"]), [])


class VendoredSkillsLockTest(TempRoot):
    def lock(self, skills):
        write(self.root, ri.LOCK_FILE, json.dumps({"version": 1, "skills": skills}))

    def files(self):
        return ri.tracked_files(self.root)

    def test_hash_scheme_matches_the_lock_tool(self):
        write(self.root, ".agents/skills/s/SKILL.md", "skill")
        write(self.root, ".agents/skills/s/adapters/B.md", "b")
        write(self.root, ".agents/skills/s/adapters/a.md", "a")
        expected = hashlib.sha256()
        for rel in ("adapters/a.md", "adapters/B.md", "SKILL.md"):
            expected.update(rel.encode())
            expected.update((self.root / ".agents/skills/s" / rel).read_bytes())
        got = ri.skill_hash(self.root, "s", ["SKILL.md", "adapters/B.md", "adapters/a.md"])
        self.assertEqual(got, expected.hexdigest())

    def managed_lock(self, managed, skills=None):
        write(self.root, ri.LOCK_FILE, json.dumps({"version": 1, "skills": skills or {}, "toolManaged": managed}))

    def graphify_dirs(self, content="g"):
        for base in (".agents/skills", ".claude/skills"):
            write(self.root, f"{base}/graphify/SKILL.md", content)
            write(self.root, f"{base}/graphify/.graphify_version", "1.0")
            write(self.root, f"{base}/graphify/references/q.md", "q")

    def current_managed(self):
        return {d: {"computedHash": ri.dir_hash(self.root / d, ri.dir_files(self.root, d, self.files()))}
                for d in (".agents/skills/graphify", ".claude/skills/graphify")}

    def test_matching_lock_passes_and_tool_managed_skills_are_hash_locked(self):
        write(self.root, ".agents/skills/s/SKILL.md", "skill")
        self.graphify_dirs()
        write(self.root, ".agents/plugins/marketplace.json", "{}")
        self.managed_lock(self.current_managed(), {"s": {"computedHash": ri.skill_hash(self.root, "s", ["SKILL.md"])}})
        self.assertEqual(ri.vendored_skills_lock(self.root, self.files()), [])

    def test_tool_managed_skill_edits_and_unlocked_dirs_fail_with_the_refresh_command(self):
        self.graphify_dirs()
        managed = self.current_managed()
        self.managed_lock(managed)
        write(self.root, ".claude/skills/graphify/SKILL.md", "tampered")
        write(self.root, ".claude/skills/other/SKILL.md", "o")
        problems = ri.vendored_skills_lock(self.root, self.files())
        hint = "refresh with: python3 scripts/lib/repo_invariants.py refresh-skills-lock"
        self.assertEqual(problems, [
            f".claude/skills/graphify: content does not match skills-lock.json toolManaged computedHash ({hint})",
            f".claude/skills/other: tool-managed skill is not in skills-lock.json toolManaged ({hint})",
        ])
        managed[".agents/skills/gone"] = {"computedHash": "0" * 64}
        self.managed_lock(managed)
        self.assertIn(".agents/skills/gone: listed in skills-lock.json toolManaged but missing",
                      ri.vendored_skills_lock(self.root, self.files())[0])

    def test_unlocked_graphify_under_agents_skills_fails(self):
        self.graphify_dirs()
        self.lock({})
        self.assertEqual(ri.vendored_skills_lock(self.root, self.files()), [
            ".agents/skills/graphify: tool-managed skill is not in skills-lock.json toolManaged "
            "(refresh with: python3 scripts/lib/repo_invariants.py refresh-skills-lock)",
            ".claude/skills/graphify: tool-managed skill is not in skills-lock.json toolManaged "
            "(refresh with: python3 scripts/lib/repo_invariants.py refresh-skills-lock)",
        ])

    def test_invalid_tool_managed_section(self):
        write(self.root, ri.LOCK_FILE, json.dumps({"skills": {}, "toolManaged": ["x"]}))
        self.assertEqual(ri.vendored_skills_lock(self.root, []),
                         ['skills-lock.json: "toolManaged" must be an object'])

    def test_refresh_rewrites_hashes_and_adds_new_tool_dirs(self):
        self.graphify_dirs()
        write(self.root, ".agents/skills/s/SKILL.md", "vendored, not tool-managed")
        self.lock({"s": {"computedHash": "keep"}})
        self.assertEqual(ri.refresh_skills_lock(self.root), [".agents/skills/graphify", ".claude/skills/graphify"])
        data = json.loads((self.root / ri.LOCK_FILE).read_text())
        self.assertEqual(data["skills"], {"s": {"computedHash": "keep"}})
        self.assertEqual(data["version"], 1)
        entry = data["toolManaged"][".claude/skills/graphify"]
        self.assertEqual(entry["version"], "1.0")
        self.assertEqual(entry["computedHash"], self.current_managed()[".claude/skills/graphify"]["computedHash"])
        self.assertEqual(ri.vendored_skills_lock(self.root, self.files()), [
            "s: content does not match skills-lock.json (computedHash)"])
        # An upgrade changes the files; refreshing again re-locks them and drops vanished dirs.
        write(self.root, ".claude/skills/graphify/SKILL.md", "upgraded")
        (self.root / ".agents/skills/graphify/SKILL.md").unlink()
        for leftover in (self.root / ".agents/skills/graphify").rglob("*"):
            if leftover.is_file():
                leftover.unlink()
        self.assertEqual(ri.refresh_skills_lock(self.root), [".claude/skills/graphify"])
        data = json.loads((self.root / ri.LOCK_FILE).read_text())
        self.assertEqual(list(data["toolManaged"]), [".claude/skills/graphify"])

    def test_refresh_without_a_lock_or_with_a_broken_one(self):
        self.graphify_dirs()
        self.assertEqual(ri.refresh_skills_lock(self.root), [".agents/skills/graphify", ".claude/skills/graphify"])
        self.assertEqual(json.loads((self.root / ri.LOCK_FILE).read_text())["skills"], {})
        write(self.root, ri.LOCK_FILE, "{ broken")
        with self.assertRaises(ValueError):
            ri.refresh_skills_lock(self.root)

    def test_dir_files_lists_tracked_files_of_one_directory(self):
        write(self.root, ".claude/skills/a/SKILL.md", "a")
        write(self.root, ".claude/skills/a/refs/x.md", "x")
        write(self.root, ".claude/skills/ab/SKILL.md", "ab")
        self.assertEqual(ri.dir_files(self.root, ".claude/skills/a", self.files()), ["SKILL.md", "refs/x.md"])

    def test_mismatch_missing_and_unlisted(self):
        write(self.root, ".agents/skills/s/SKILL.md", "changed")
        write(self.root, ".agents/skills/rogue/SKILL.md", "r")
        write(self.root, ".agents/skills/graphify/SKILL.md", "no version marker")
        self.lock({"s": {"computedHash": "0" * 64}, "gone": {"computedHash": "1" * 64}})
        self.assertEqual(ri.vendored_skills_lock(self.root, self.files()), [
            "gone: listed in skills-lock.json but missing from .agents/skills/",
            "s: content does not match skills-lock.json (computedHash)",
            "graphify: vendored skill is not in skills-lock.json",
            "rogue: vendored skill is not in skills-lock.json",
        ])

    def test_no_lock_and_no_skills_passes(self):
        self.assertEqual(ri.vendored_skills_lock(self.root, []), [])

    def test_skills_without_a_lock_are_unlisted(self):
        write(self.root, ".agents/skills/s/SKILL.md", "s")
        self.assertEqual(ri.vendored_skills_lock(self.root, self.files()),
                         ["s: vendored skill is not in skills-lock.json"])

    def test_invalid_lock(self):
        for content in ("{ broken", "[1, 2]"):
            write(self.root, ri.LOCK_FILE, content)
            self.assertEqual(ri.vendored_skills_lock(self.root, []),
                             ['skills-lock.json: not valid JSON with a "skills" object'])


class SiteDuplicateIdsTest(TempRoot):
    def test_duplicates_at_any_depth_and_only_in_site_pages(self):
        write(self.root, "site/index.html", '<p id="x"></p><img id="x"/><b id=""></b><i id=""></i>')
        write(self.root, "site/help/a/b.html", '<a id="k"></a><a id="j"></a><svg><g id="k"/></svg>')
        write(self.root, "site/ok.html", '<p id="one"></p><p id="two"></p><p class="c"></p>')
        write(self.root, "research/report.html", '<p id="d"></p><p id="d"></p>')
        write(self.root, "site/notes.md", 'id="d" id="d"')
        files = ri.tracked_files(self.root) + ["site/gone.html"]
        self.assertEqual(ri.site_duplicate_ids(self.root, sorted(files)), [
            "site/help/a/b.html: duplicate id k",
            "site/index.html: duplicate id x",
        ])


HARDENED = """\
name: CI
on: [push]
permissions:
  contents: read
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v5
        with:
          persist-credentials: false
      - name: Use an input safely
        env:
          TAG: ${{ github.ref_name }}
        run: |
          echo "$TAG"
      - run: echo inline
  second:
    if: ${{ github.event_name == 'push' }}
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: checkout
        uses: actions/checkout@v5
        with: { fetch-depth: 0, persist-credentials: false }
"""


class WorkflowHardeningTest(TempRoot):
    def problems(self, text, rel=".github/workflows/w.yml"):
        write(self.root, rel, text)
        return ri.workflow_hardening(self.root, [rel])

    def test_hardened_workflow_passes(self):
        self.assertEqual(self.problems(HARDENED), [])

    def test_other_files_are_ignored(self):
        write(self.root, ".github/dependabot.yml", "version: 2\n")
        self.assertEqual(ri.workflow_hardening(self.root, [".github/dependabot.yml", ".github/workflows/gone.yml"]), [])

    def test_each_weakness_is_reported(self):
        weak = """\
name: Weak
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: actions/checkout@v4
      - run: npx --yes html-validate@latest site
      - name: Interpolated
        run: |
          tag="${{ github.event.release.tag_name }}"
          # comment lines are skipped, even ${{ x }} and npx -y
          npx -y html-validate site
      - run: echo "${{ inputs.runtimes }}"
"""
        problems = self.problems(weak)
        rel = ".github/workflows/w.yml"
        self.assertEqual(problems, [
            f"{rel}: no top-level permissions block (least privilege)",
            f"{rel}: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is not set to true in the top-level env",
            f"{rel}:6: continue-on-error hides failures",
            f"{rel}:8: actions/checkout without persist-credentials: false",
            f"{rel}:9: unpinned @latest or npx --yes",
            f"{rel}:12: ${{{{ }}}} expression inside a run script (pass it through env)",
            f"{rel}:14: unpinned @latest or npx --yes",
            f"{rel}:15: ${{{{ }}}} expression inside a run script (pass it through env)",
            f"{rel}: job build has no timeout-minutes",
        ])

    def test_write_all_and_any_continue_on_error_value(self):
        text = HARDENED.replace("permissions:\n  contents: read\n", "permissions: write-all\n")
        self.assertIn(".github/workflows/w.yml: permissions: write-all (grant only the scopes the job needs)",
                      self.problems(text))
        for value in ('"true"', "${{ true }}", "yes"):
            weak = HARDENED.replace("    timeout-minutes: 20\n", f"    timeout-minutes: 20\n    continue-on-error: {value}\n", 1)
            self.assertTrue(any("continue-on-error hides failures" in p for p in self.problems(weak)), value)
        ok = HARDENED.replace("    timeout-minutes: 20\n", "    timeout-minutes: 20\n    continue-on-error: false  # explicit\n", 1)
        self.assertEqual(self.problems(ok), [])

    def test_equivalent_yaml_spellings_are_caught(self):
        base = "    timeout-minutes: 20\n"
        for extra in ('    "continue-on-error": true\n', "    continue-on-error:\n      true\n"):
            weak = HARDENED.replace(base, base + extra, 1)
            self.assertTrue(any("continue-on-error" in p or "quoted keys" in p for p in self.problems(weak)), extra)
        flow = HARDENED.replace("    steps:\n", "    steps:\n      - {run: echo ok, continue-on-error: true}\n", 1)
        self.assertTrue(any("flow-style" in p for p in self.problems(flow)))
        quoted = HARDENED.replace("permissions:\n  contents: read\n", 'permissions: "write-all"\n')
        self.assertTrue(any("write-all" in p for p in self.problems(quoted)))

    def test_honest_script_content_is_not_mistaken_for_hidden_settings(self):
        script = HARDENED.replace(
            '      - run: echo inline\n',
            '      - name: Write config\n        run: |\n          cat > cfg.json <<EOF\n          {"ref": "main"}\n          - {a: b}\n          EOF\n'
            '      - uses: actions/github-script@v7\n        with:\n          script: |\n            - {not: a step}\n            "ref": "main"\n            continue-on-error: true\n', 1)
        self.assertEqual(self.problems(script), [])

    def test_flow_style_jobs_and_steps_cannot_hide_settings(self):
        flow_job = HARDENED + """  third: {runs-on: ubuntu-latest, timeout-minutes: 5, continue-on-error: true, steps: [{run: echo ok}]}\n"""
        self.assertTrue(any("flow-style" in p for p in self.problems(flow_job)))
        flow_steps = HARDENED.replace(
            "    steps:\n      - name: checkout\n", "    steps: [{run: 'echo ${{ github.event.issue.title }}', continue-on-error: true}]\n    xsteps:\n      - name: checkout\n", 1)
        self.assertTrue(any("flow-style" in p for p in self.problems(flow_steps)))
        flow_brace = HARDENED.replace("    steps:\n      - name: checkout\n", "    steps: {}\n    xsteps:\n      - name: checkout\n", 1)
        self.assertTrue(any("flow-style" in p for p in self.problems(flow_brace)))
        # Flow collections for ordinary values stay fine.
        fine = HARDENED.replace("on: [push]", "on:\n  push:\n    branches: [main]\n  workflow_dispatch: {}\n")
        self.assertEqual(self.problems(fine), [])

    def test_ci_guard_must_see_ignored_files(self):
        rel = ".github/workflows/ci.yml"
        self.assertEqual(self.problems(HARDENED + "# formerly: git status --porcelain --ignored\n", rel),
                         [f"{rel}: the checkout-unchanged guard must use git status --porcelain --ignored"])
        self.assertEqual(self.problems(HARDENED + "      - run: git status --porcelain --ignored\n", rel), [])
        self.assertEqual(self.problems(HARDENED, rel),
                         [f"{rel}: the checkout-unchanged guard must use git status --porcelain --ignored"])

    def test_step_level_timeout_does_not_count_for_the_job(self):
        text = HARDENED.replace("    timeout-minutes: 5\n", "").replace(
            "        uses: actions/checkout@v5\n", "        uses: actions/checkout@v5\n        timeout-minutes: 5\n")
        self.assertEqual(self.problems(text), [".github/workflows/w.yml: job second has no timeout-minutes"])

    def test_force_flag_only_counts_at_the_top_level(self):
        text = HARDENED.replace("env:\n  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n", "").replace(
            "    timeout-minutes: 20\n", "    timeout-minutes: 20\n    env:\n      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n")
        self.assertEqual(self.problems(text), [
            ".github/workflows/w.yml: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is not set to true in the top-level env"])

    def test_workflow_without_jobs(self):
        text = "on: [push]\npermissions: {}\nenv:\n  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n"
        self.assertEqual(self.problems(text, ".github/workflows/empty.yaml"), [])


class TrackedFileSizeTest(TempRoot):
    def test_large_and_missing_files(self):
        with (self.root / "big.bin").open("wb") as handle:
            handle.truncate((ri.MAX_TRACKED_MIB + 1) * 1024 * 1024)
        write(self.root, "small.txt", "s")
        problems = ri.tracked_file_size(self.root, ["big.bin", "gone.bin", "small.txt"])
        self.assertEqual(problems, ["big.bin: 91.0 MiB, over the 90 MiB limit (GitHub rejects files over 100 MB)"])


def home_path(name, tail="proj/file.txt"):
    return "/Users/" + name + "/" + tail


def mail(local, domain):
    return local + "@" + domain


class PersonalDataTest(TempRoot):
    def problems(self, text, rel="docs/x.md"):
        write(self.root, rel, text)
        return ri.personal_data(self.root, [rel])

    def test_personal_machine_paths_are_reported_without_their_value(self):
        for text in (home_path("dave"), "see /home/" + "erin" + "/x", "C:" + "\\Users\\" + "frank" + "\\x",
                     "C:/Users/" + "frank" + "/x", "-Users-" + "gina" + "-proj"):
            problems = self.problems("line one\n" + text + "\n")
            self.assertEqual(problems, ["docs/x.md:2: personal home-directory path (use a placeholder such as /Users/<user>/)"], text)

    def test_placeholders_and_generic_names_pass(self):
        text = "\n".join([
            "/Users/<user>/proj", "/Users/$USER/proj", "/Users/${USER}/p", "/home/" + "user/p", "/home/runner/work",
            "/Users/Shared/x", "/Users/you/x", "C:" + "\\Users\\Ada\\x", home_path("example"), "/home/<name>/x", "~/projects",
            "/usr/home/", "/var/home", "cats/Users/", "/Users", "/Users/"])
        self.assertEqual(self.problems(text), [])

    def test_email_addresses_must_be_allowlisted(self):
        bad = self.problems("contact " + mail("someone", "gmail.com") + " or " + mail("x", "corp.io") + "\n")
        self.assertEqual(bad, ["docs/x.md:1: email address outside the allowlist (alolabs.dev, sourcevo.com, noreply, test domains)"] * 2)
        self.assertNotIn("gmail", bad[0])

    def test_allowlisted_addresses_pass(self):
        good = [mail("info", "alolabs.dev"), mail("hello", "alolabs.io"), mail("a", "sourcevo.com"), mail("noreply", "anthropic.com"),
                mail("12345+x", "users.noreply.github.com"), mail("No-Reply", "other.org"), mail("a", "example.com"),
                mail("a", "mail.example.org"), mail("a", "e.invalid"), mail("a", "x.test"), mail("a", "host.local"),
                mail("git", "github.com"), mail("token", "github.com"), mail("t", "test.com"), mail("a", "t.com")]
        self.assertEqual(self.problems("\n".join(good)), [])
        self.assertTrue(self.problems(mail("someone", "github.com")))
        self.assertTrue(self.problems(mail("a", "notexample.com")))

    def test_binary_and_missing_files_are_skipped(self):
        write(self.root, "img.bin", b"\x00\x01" + home_path("dave").encode())
        write(self.root, "ok.md", "fine")
        self.assertEqual(ri.personal_data(self.root, ["img.bin", "gone.md", "ok.md"]), [])

    def test_problems_are_per_line_in_file_order(self):
        write(self.root, "a.md", "x\n" + home_path("dave") + "\n")
        write(self.root, "b.md", mail("q", "gmail.com") + "\n" + home_path("dave") + "\n")
        self.assertEqual([p.split(" ")[0] for p in ri.personal_data(self.root, ["a.md", "b.md"])],
                         ["a.md:2:", "b.md:1:", "b.md:2:"])


class MainTest(TempRoot):
    def run_main(self, argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ri.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_usage_errors(self):
        for argv in ([], ["nope"], ["worm-indicators", ".", "extra"]):
            code, _, err = self.run_main(argv)
            self.assertEqual(code, 2)
            self.assertIn("usage: repo_invariants.py", err)

    def test_pass_and_fail(self):
        code, out, _ = self.run_main(["tracked-file-size", str(self.root)])
        self.assertEqual((code, out), (0, ""))
        write(self.root, "x.png", "text")
        code, out, _ = self.run_main(["binary-signatures", str(self.root)])
        self.assertEqual(code, 1)
        self.assertIn("  x.png: not a .png file", out)

    def test_default_root_is_the_current_directory(self):
        write(self.root, "x.gif", "text")
        cwd = os.getcwd()
        try:
            os.chdir(self.root)
            code, out, _ = self.run_main(["binary-signatures"])
        finally:
            os.chdir(cwd)
        self.assertEqual(code, 1)
        self.assertIn("x.gif", out)

    def test_personal_data_check_runs_from_the_cli(self):
        write(self.root, "ok.md", "fine")
        code, out, _ = self.run_main(["personal-data", str(self.root)])
        self.assertEqual((code, out), (0, ""))
        write(self.root, "bad.md", home_path("dave"))
        code, out, _ = self.run_main(["personal-data", str(self.root)])
        self.assertEqual(code, 1)
        self.assertEqual(out, "  bad.md:1: personal home-directory path (use a placeholder such as /Users/<user>/)\n")

    def test_refresh_skills_lock_command(self):
        write(self.root, ".claude/skills/graphify/SKILL.md", "g")
        write(self.root, ".claude/skills/graphify/.graphify_version", "2.0")
        code, out, _ = self.run_main(["refresh-skills-lock", str(self.root)])
        self.assertEqual((code, out), (0, "  locked .claude/skills/graphify\n"))
        self.assertEqual(json.loads((self.root / ri.LOCK_FILE).read_text())["toolManaged"][".claude/skills/graphify"]["version"], "2.0")
        write(self.root, ri.LOCK_FILE, "{ broken")
        code, _, err = self.run_main(["refresh-skills-lock", str(self.root)])
        self.assertEqual(code, 2)
        self.assertIn("skills-lock.json", err)

    def test_cli_entry_point(self):
        write(self.root, "ok.txt", "fine")
        proc = subprocess.run([sys.executable, str(SCRIPT), "worm-indicators", str(self.root)],
                              capture_output=True, text=True)
        self.assertEqual((proc.returncode, proc.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()

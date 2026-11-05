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

    def test_refresh_hashes_tracked_files_only(self):
        import subprocess
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        write(self.root, ".gitignore", ".DS_Store\n.claude/skills/mine/\n")
        write(self.root, ".claude/skills/graphify/SKILL.md", "g")
        write(self.root, ".claude/skills/graphify/.graphify_version", "2.0")
        subprocess.run(["git", "-C", str(self.root), "add", "-A"], check=True)
        write(self.root, ".claude/skills/graphify/.DS_Store", "junk")
        write(self.root, ".claude/skills/mine/.graphify_version", "1")
        self.assertEqual(ri.refresh_skills_lock(self.root), [".claude/skills/graphify"])
        self.assertEqual(ri.vendored_skills_lock(self.root, ri.tracked_files(self.root)), [])

    def test_refresh_handles_non_object_lock_and_dirs_without_a_version_file(self):
        write(self.root, ".claude/skills/plain/SKILL.md", "p")
        write(self.root, ri.LOCK_FILE, "[1]")
        with self.assertRaises(ValueError):
            ri.refresh_skills_lock(self.root)
        write(self.root, ri.LOCK_FILE, "{}")
        self.assertEqual(ri.refresh_skills_lock(self.root), [".claude/skills/plain"])
        entry = json.loads((self.root / ri.LOCK_FILE).read_text())["toolManaged"][".claude/skills/plain"]
        self.assertEqual(list(entry), ["computedHash"])

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
    REL = ".github/workflows/w.yml"

    def problems(self, text, rel=REL):
        write(self.root, rel, text)
        return ri.workflow_hardening(self.root, [rel])

    def variant(self, step, base=HARDENED):
        """HARDENED with the plain 'run: echo inline' step replaced by STEP."""
        self.assertIn("      - run: echo inline\n", base)
        return base.replace("      - run: echo inline\n", step, 1)

    def messages(self, text):
        return [p.split(": ", 1)[1] for p in self.problems(text)]

    def assertCaught(self, text, needle, label=""):
        self.assertTrue(any(needle in p for p in self.problems(text)), f"{label}: {self.problems(text)}")

    def test_hardened_workflow_passes(self):
        self.assertEqual(self.problems(HARDENED), [])

    def test_other_files_are_ignored(self):
        write(self.root, ".github/dependabot.yml", "version: 2\n")
        self.assertEqual(ri.workflow_hardening(self.root, [".github/dependabot.yml", ".github/workflows/gone.yml"]), [])

    def test_each_weakness_is_reported_with_its_line(self):
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
          # comment lines are skipped for npx -y but ${{ x }} is still expanded
          npx -y html-validate site
      - run: echo "${{ inputs.runtimes }}"
"""
        rel = self.REL
        self.assertEqual(self.problems(weak), [
            f"{rel}: no top-level permissions block (least privilege)",
            f"{rel}: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is not set to true in the top-level env",
            f"{rel}:6: continue-on-error hides failures",
            f"{rel}:8: actions/checkout without persist-credentials: false",
            f"{rel}:9: unpinned @latest or npx --yes",
            f"{rel}:11: ${{{{ }}}} expression inside a run script (pass it through env)",
            f"{rel}:11: unpinned @latest or npx --yes",
            f"{rel}:15: ${{{{ }}}} expression inside a run script (pass it through env)",
            f"{rel}: job build has no timeout-minutes",
        ])

    def test_write_all_and_any_continue_on_error_value(self):
        text = HARDENED.replace("permissions:\n  contents: read\n", "permissions: write-all\n")
        self.assertIn(f"{self.REL}: permissions: write-all (grant only the scopes the job needs)", self.problems(text))
        quoted = HARDENED.replace("permissions:\n  contents: read\n", 'permissions: "write-all"\n')
        self.assertCaught(quoted, "write-all")
        for value in ('"true"', "${{ true }}", "yes", '"false"', "1"):
            weak = HARDENED.replace("    timeout-minutes: 20\n", f"    timeout-minutes: 20\n    continue-on-error: {value}\n", 1)
            self.assertCaught(weak, "continue-on-error hides failures", value)
        ok = HARDENED.replace("    timeout-minutes: 20\n", "    timeout-minutes: 20\n    continue-on-error: false  # explicit\n", 1)
        self.assertEqual(self.problems(ok), [])

    def test_list_item_block_scalars_do_not_hide_sibling_keys(self):
        self.assertCaught(self.variant("      - run: |\n          git status --porcelain --ignored\n        continue-on-error: true\n"),
                          "continue-on-error hides failures")
        self.assertCaught(self.variant('      - name: >-\n          Greet\n        run: echo "${{ github.event.issue.title }}"\n'),
                          "expression inside a run script")

    def test_every_yaml_spelling_resolves_to_the_same_findings(self):
        injection = "echo ${{ github.event.issue.title }}"
        spellings = {
            "flow step": f"      - {{run: '{injection}', continue-on-error: true}}\n",
            "anchored flow step": f"      - &s {{run: '{injection}'}}\n",
            "tagged flow step": f"      - !!map {{run: '{injection}'}}\n",
            "space before colon": f"      - run : {injection}\n",
            "quoted key": f"      - 'run': {injection}\n",
            "escaped key": f'      - "r\\u0075n": {injection}\n',
            "complex key": f"      - ? run\n        : {injection}\n",
            "escaped dollar": '      - run: "echo \\u0024{{ github.event.issue.title }}"\n',
            "hex escaped dollar": '      - run: "echo \\x24{{ github.event.issue.title }}"\n',
            "folded scalar": f"      - run: >\n          {injection}\n",
            "run alias": f"      - &t\n        run: {injection}\n      - *t\n",
            "scalar alias": f"      - name: x\n        env:\n          T: &t '{injection}'\n        run: *t\n",
            "merge key": f"      - &base\n        run: {injection}\n      - <<: *base\n        name: y\n",
            "property on its own line": f"      - name: x\n        run:\n          &t \"{injection}\"\n",
        }
        for label, step in spellings.items():
            self.assertCaught(self.variant(step), "expression inside a run script", label)
        self.assertCaught(self.variant("      - {run: echo, continue-on-error: true}\n"), "continue-on-error hides failures")
        self.assertCaught(self.variant("      - run: echo\n        continue-on-error : true\n"), "continue-on-error hides failures")
        self.assertCaught(self.variant("      - run: echo\n        ? continue-on-error\n        : true\n"), "continue-on-error hides failures")
        self.assertCaught(self.variant("      - &t {run: echo, continue-on-error: true}\n      - *t\n"), "continue-on-error hides failures")

    def test_flow_and_anchored_jobs_and_steps_are_resolved(self):
        flow_job = HARDENED + "  third: {runs-on: ubuntu-latest, continue-on-error: true, steps: [{run: echo ok}]}\n"
        self.assertCaught(flow_job, "continue-on-error hides failures")
        self.assertIn(f"{self.REL}: job third has no timeout-minutes", self.problems(flow_job))
        anchored = HARDENED + "  third: &j {runs-on: x, timeout-minutes: 1, continue-on-error: true}\n  fourth: *j\n"
        self.assertEqual(len([p for p in self.problems(anchored) if "continue-on-error" in p]), 2)
        tagged_steps = HARDENED.replace("    steps:\n      - name: checkout\n", "    steps: !!seq [{run: 'echo ${{ x }}'}]\n    xsteps:\n      - name: checkout\n", 1)
        self.assertCaught(tagged_steps, "expression inside a run script")
        anchored_jobs = "jobs: &j\n  a: {runs-on: x, continue-on-error: true}\n" + HARDENED.split("jobs:\n")[0]
        self.assertCaught(anchored_jobs, "continue-on-error hides failures")
        flow_jobs = "jobs: !!map {a: {runs-on: x}}\n" + HARDENED.split("jobs:\n")[0]
        self.assertIn(f"{self.REL}: job a has no timeout-minutes", self.problems(flow_jobs))
        merged = HARDENED + "  third:\n    <<: &d {runs-on: x, continue-on-error: true}\n    timeout-minutes: 3\n"
        self.assertCaught(merged, "continue-on-error hides failures")
        overridden = HARDENED + "  third:\n    <<: &d {runs-on: x, continue-on-error: true}\n    continue-on-error: false\n    timeout-minutes: 3\n"
        self.assertEqual(self.problems(overridden), [])

    def test_code_inputs_of_steps_are_checked(self):
        for form in ("with: {script: \"core.info('${{ github.event.issue.title }}')\"}\n",
                     "with:\n          script: |\n            core.info(`${{ github.event.issue.title }}`)\n",
                     "with:\n          script: |\n            # core.info(`${{ github.event.comment.body }}`)\n",
                     "with:\n          'script': x ${{ github.head_ref }}\n"):
            self.assertCaught(self.variant("      - uses: actions/github-script@v7\n        " + form), "with: script input", form)
        # Other inputs and env values carry expressions safely.
        safe = self.variant("      - uses: actions/cache@v4\n        with:\n          key: ${{ hashFiles('x') }}\n        env:\n          T: ${{ github.event.issue.title }}\n")
        self.assertEqual(self.problems(safe), [])

    def test_more_code_inputs_and_container_options_are_checked(self):
        expr = "${{ github.event.issue.title }}"
        for key in ("inlineScript", "start", "build", "install", "arguments", "pre-command", "post_run", "install-command", "deploy_command"):
            step = f"      - uses: some/action@v1\n        with:\n          {key}: echo {expr}\n"
            self.assertCaught(self.variant(step), f"with: {key} input", key)
        listed = f"      - uses: actions/github-script@v7\n        with:\n          script:\n            - core.info('ok')\n            - core.info('{expr}')\n"
        self.assertCaught(self.variant(listed), "with: script input")
        self.assertEqual(self.problems(self.variant("      - uses: some/action@v1\n        with:\n          script: [1, 2]\n          start: 3\n")), [])
        container = HARDENED.replace("    runs-on: ubuntu-latest\n    timeout-minutes: 20\n", f"    runs-on: ubuntu-latest\n    timeout-minutes: 20\n    container:\n      image: x\n      options: --label {expr}\n", 1)
        self.assertCaught(container, "container options input")
        service = HARDENED.replace("    runs-on: ubuntu-latest\n    timeout-minutes: 20\n", f"    runs-on: ubuntu-latest\n    timeout-minutes: 20\n    services:\n      db:\n        image: x\n        options: --label {expr}\n", 1)
        self.assertCaught(service, "container options input")
        plain = HARDENED.replace("    runs-on: ubuntu-latest\n    timeout-minutes: 20\n", "    runs-on: ubuntu-latest\n    timeout-minutes: 20\n    container: node:22\n    services: x\n", 1)
        self.assertEqual(self.problems(plain), [])

    def test_privileged_triggers_must_not_check_out_the_pull_request_head(self):
        checkout = lambda ref: f"      - uses: actions/checkout@v5\n        with:\n          persist-credentials: false\n          {ref}\n"
        hardened = HARDENED.replace("on: [push]", "on:\n  pull_request_target:\n    types: [opened]")
        bad_refs = ("ref: ${{ github.event.pull_request.head.sha }}", "ref: ${{ github.head_ref }}", "ref: refs/pull/1/merge",
                    "ref: ${{ github.event.workflow_run.head_branch }}", "repository: ${{ github.event.pull_request.head.repo.full_name }}",
                    "ref: ${{ github.event.pull_request.merge_commit_sha }}")
        for trigger in ("on:\n  pull_request_target:\n    types: [opened]", "on: workflow_run", "on: [push, pull_request_target]", "on:\n  workflow_run:\n    workflows: [x]"):
            base = HARDENED.replace("on: [push]", trigger)
            for ref in bad_refs:
                self.assertCaught(self.variant(checkout(ref), base), "checks out the head of the pull request", f"{trigger} {ref}")
        self.assertEqual(self.problems(self.variant(checkout("ref: main"), hardened)), [])
        self.assertEqual(self.problems(self.variant(checkout("fetch-depth: 0"), hardened)), [])
        # The same checkout under an unprivileged trigger is the normal pull request build.
        self.assertEqual(self.problems(self.variant(checkout("ref: ${{ github.event.pull_request.head.sha }}"))), [])

    def test_checkout_rule_ignores_case_and_reusable_callers_need_no_timeout(self):
        self.assertCaught(self.variant("      - uses: Actions/Checkout@v5\n"), "without persist-credentials: false")
        caller = HARDENED + "  call:\n    uses: ./.github/workflows/other.yml\n    secrets: inherit\n"
        self.assertEqual(self.problems(caller), [])
        self.assertIn(f"{self.REL}: job plain has no timeout-minutes", self.problems(HARDENED + "  plain:\n    runs-on: x\n"))

    def test_commented_expressions_in_run_bodies_are_caught(self):
        for style in ("|", ">"):
            found = self.problems(self.variant(
                f"      - run: {style}\n          echo ok\n          # echo \"${{{{ github.event.comment.body }}}}\"\n"))
            self.assertEqual(len([p for p in found if "expression inside a run script" in p]), 1, style)
        # A YAML comment outside any scalar is not part of the workflow.
        self.assertEqual(self.problems(self.variant("      # run: echo ${{ x }}\n      - run: echo ok\n")), [])

    def test_honest_script_content_is_not_mistaken_for_settings(self):
        script = self.variant(
            '      - name: Write config\n        run: |\n          cat > cfg.json <<EOF\n          {"ref": "main"}\n          - {a: b}\n          continue-on-error: true\n          EOF\n'
            "      - run: \"echo 'a: *b & !c'\"\n")
        self.assertEqual(self.problems(script), [])
        fine = HARDENED.replace("on: [push]", "on:\n  push:\n    branches: [main]\n  workflow_dispatch: {}\n")
        self.assertEqual(self.problems(fine), [])

    def test_ci_guard_must_see_ignored_files(self):
        rel = ".github/workflows/ci.yml"
        guard = f"{rel}: the checkout-unchanged guard must use git status --porcelain --ignored"
        self.assertEqual(self.problems(HARDENED + "# formerly: git status --porcelain --ignored\n", rel), [guard])
        self.assertEqual(self.problems(self.variant("      - run: git status --porcelain --ignored\n"), rel), [])
        self.assertEqual(self.problems(HARDENED, rel), [guard])

    def test_job_timeouts_must_be_job_level(self):
        text = HARDENED.replace("    timeout-minutes: 5\n", "").replace(
            "        uses: actions/checkout@v5\n", "        uses: actions/checkout@v5\n        timeout-minutes: 5\n")
        self.assertEqual(self.problems(text), [f"{self.REL}: job second has no timeout-minutes"])
        self.assertEqual(self.problems(HARDENED.replace("  second:\n", "  second: just-a-string\n  xsecond:\n", 1).split("  xsecond:")[0]),
                         [f"{self.REL}: job second has no timeout-minutes"])

    def test_force_flag_only_counts_at_the_top_level(self):
        text = HARDENED.replace("env:\n  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n", "").replace(
            "    timeout-minutes: 20\n", "    timeout-minutes: 20\n    env:\n      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n")
        flag = f"{self.REL}: FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 is not set to true in the top-level env"
        self.assertEqual(self.problems(text), [flag])
        self.assertEqual(self.problems(HARDENED.replace("NODE24: true", 'NODE24: "true"')), [])
        self.assertEqual(self.problems(HARDENED.replace("env:\n  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n", "env: x\n")), [flag])

    def test_workflow_without_jobs(self):
        text = "on: [push]\npermissions: {}\nenv:\n  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true\n"
        self.assertEqual(self.problems(text, ".github/workflows/empty.yaml"), [])
        self.assertEqual(self.problems(text + "jobs: x\n", ".github/workflows/empty.yaml"), [])
        self.assertEqual(self.problems(text + "jobs:\n  a:\n    steps: x\n    timeout-minutes: 1\n    runs-on: x\n", ".github/workflows/e.yaml"), [])
        self.assertEqual(self.problems(text + "jobs:\n  a:\n    steps: [x, {run: y}]\n    timeout-minutes: 1\n", ".github/workflows/e.yaml"), [])

    def test_unparsable_or_unreadable_workflows_fail_closed(self):
        rel = self.REL
        for label, text, needle in (
            ("syntax", "jobs: [\n", "not parsed as YAML"),
            ("duplicate key", HARDENED + "permissions: {}\n", "duplicate key"),
            ("unhashable key", "? [a]\n: b\n", "not parsed as YAML"),
            ("scalar document", "just text\n", "not a YAML mapping"),
            ("empty", "", "not a YAML mapping"),
        ):
            found = self.problems(text)
            self.assertEqual(len(found), 1, label)
            self.assertIn(needle, found[0], label)
            self.assertTrue(found[0].startswith(rel), label)

    def test_missing_pyyaml_fails_closed(self):
        import sys
        from unittest import mock
        with mock.patch.dict(sys.modules, {"yaml": None}):
            found = self.problems(HARDENED)
        self.assertEqual(len(found), 1)
        self.assertIn("PyYAML is required", found[0])


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
        bad = self.problems("contact " + mail("dave", "gmail.com") + " or " + mail("pat", "corp.io") + "\n")
        self.assertEqual(bad, ["docs/x.md:1: " + ri.EMAIL_MESSAGE] * 2)
        self.assertNotIn("gmail", bad[0])

    def test_allowlisted_addresses_pass(self):
        good = [mail("info", "alolabs.dev"), mail("hello", "alolabs.io"), mail("a", "sourcevo.com"), mail("noreply", "anthropic.com"),
                mail("12345+x", "users.noreply.github.com"), mail("No-Reply", "other.org"), mail("a", "example.com"),
                mail("a", "mail.example.org"), mail("a", "e.invalid"), mail("a", "x.test"),
                mail("git", "github.com"), mail("token", "github.com"), mail("t", "test.com"), mail("a", "t.com")]
        self.assertEqual(self.problems("\n".join(good)), [])
        self.assertTrue(self.problems(mail("dave", "github.com")))
        self.assertTrue(self.problems(mail("a", "notexample.com")))

    def test_flattened_escaped_and_encoded_home_forms_are_reported(self):
        forms = [
            "Users-" + "dave" + "-projects-repo",                 # Cursor project dir
            "_Users_" + "dave" + "_projects_repo",                # lean-ctx
            "/home/".replace("/home/", "-home-") + "dave" + "-proj",  # Claude project dir on Linux
            "/var/home/" + "dave" + "/x",
            "/users/" + "dave" + "/x",                            # lower case
            "\\/Users\\/" + "dave" + "\\/x",                      # JSON-escaped
            "%2FUsers%2F" + "dave" + "%2Fx",                      # URL-encoded
            "file:///Users/" + "dave" + "/.cursor/x",
            "/mnt/c/Users/" + "dave" + "/x",                      # WSL
            "\\\\/Users\\\\/" + "dave" + "\\\\/x",                  # double-escaped JSON
            "\\u002fUsers\\u002f" + "dave" + "\\u002fx",              # unicode-escaped JSON
            "C:\\\\\\\\Users\\\\\\\\" + "dave",                      # JSON-escaped Windows path
        ]
        for form in forms:
            self.assertEqual(self.problems("a\n" + form + "\n"), ["docs/x.md:2: " + ri.HOME_MESSAGE], form)

    def hashed(self, *names):
        write(self.root, ri.TOKEN_FILE, "# hashes\n" + "".join(
            f"{hashlib.sha256(n.encode()).hexdigest()} {len(n)}  # token\n" for n in names) + "bogus\nabc x\n")

    def identity_problems(self, text, rel="docs/x.md"):
        write(self.root, rel, text)
        return ri.personal_data(self.root, [rel])

    def context_hash(self, text, rel="docs/x.md"):
        """The hash the failing check suggests for the first identity token of TEXT."""
        message = self.identity_problems(text, rel)[0]
        return message.split("'file <path> ")[1].split("'")[0]

    def test_hashed_identity_tokens_catch_every_separator_and_encoding_form(self):
        self.hashed("dave", "mcdonald")
        forms = ["users_" + "dave" + "_projects", "x_users_" + "dave" + "__claude_plugins", "x_home_" + "dave" + "_silver_bullet",
                 "users-" + "dave" + "-silver-bullet", "\\\\wsl$\\Ubuntu\\home\\" + "dave", "~" + "dave" + "/projects",
                 "Users." + "dave" + ".projects", "&#47;Users&#47;" + "dave", "/Users\\" + "dave" + "\\x", "McDonald, " + "Dave",
                 "mail dave\u00e9", "dave",
                 "wrote\\n" + "Dave" + " said", "wrote\\t" + "Dave", "github.com%2F" + "dave" + "%2Frepo", "%20" + "dave",
                 "\\u0064" + "ave", "&#100;" + "ave", "&#x64;" + "ave", "d\u200bave", "d\u00adave", "\uff44\uff41\uff56\uff45",
                 "\u24d3ave", "x\\u000a" + "dave"]
        for form in forms:
            found = self.problems("a\nline " + form + " and " + form + "\n")
            self.assertEqual(len(found), 1, form)
            self.assertTrue(found[0].startswith("docs/x.md:2: " + ri.IDENTITY_MESSAGE.split(" (")[0]), form)
        # Only whole tokens count: a longer word that merely contains the name is a different token.
        self.assertEqual(self.problems("davenport fandave dave2 xdavex\n"), [])
        # A Windows path whose name starts with n/t/r survives the \\n decoding.
        self.hashed("nick")
        self.assertEqual(len(self.problems("C:\\Users\\" + "nick" + "\\x\n")), 2)
        # Without a token file the check is off.
        (self.root / ri.TOKEN_FILE).unlink()
        self.assertEqual(self.problems("dave\n"), [])

    def test_allowlist_entries_exempt_one_context_not_the_file(self):
        self.hashed("dave")
        header = "# public\n"
        legit = 'name: "' + "Dave" + ' Jones",\n'
        digest = self.context_hash(legit)
        write(self.root, ri.ALLOW_FILE, header + f"file docs/*.md {digest}\n")
        write(self.root, "docs/x.md", legit + legit + "second " + "dave" + " mention\n" + "other.txt\n")
        found = ri.personal_data(self.root, ["docs/x.md", ri.ALLOW_FILE])
        self.assertEqual([p.split(": ")[0] for p in found], ["docs/x.md:3"])
        self.assertIn(f"add 'file <path> ", found[0])
        # The entry is bound to the file glob.
        write(self.root, "other/y.md", legit)
        self.assertEqual(len(ri.personal_data(self.root, ["other/y.md"])), 1)
        # Path-shaped uses are reported even inside an allowed context.
        for shaped in ("users_" + "dave" + "_x", "-users-" + "dave" + "-x", "_home_" + "dave" + "_x", "~" + "dave", "~/" + "dave", "/Users/" + "dave", "Users." + "dave"):
            quoted = "Dave" + " " + shaped
            line = 'by "' + quoted + '"\n'
            write(self.root, "docs/p.md", line)
            digest = hashlib.sha256(quoted.encode()).hexdigest()[:16]
            write(self.root, ri.ALLOW_FILE, f"file docs/*.md {digest}\n")
            found = ri.personal_data(self.root, ["docs/p.md"])
            self.assertTrue(any("home-directory-shaped path" in p for p in found), shaped)
        # A single-line file: only the exact quoted string is exempt.
        line = '{"label":"' + "Dave" + ' Jones","other":"' + "dave" + ' again"}\n'
        write(self.root, "docs/g.json", line)
        digest = self.context_hash(line, "docs/g.json")
        write(self.root, ri.ALLOW_FILE, f"file docs/g.json {digest}\n")
        self.assertEqual(len(ri.personal_data(self.root, ["docs/g.json"])), 1)

    def test_the_allowlist_file_is_scanned_and_its_directives_are_validated(self):
        self.hashed("dave")
        digest = "a" * 16
        bad = ["home", "HOME x", "email", "file", "file docs/x.md", "file docs/x.md short", "file docs/x.md " + "z" * 16, "file a b " + digest]
        write(self.root, ri.ALLOW_FILE, "# written by dave\n" + "\n".join(bad) + f"\nfile docs/*.md {digest}\nemail " + mail("dave", "gmail.com") + "\n# " + home_path("erin") + "\n")
        found = ri.personal_data(self.root, [ri.ALLOW_FILE])
        self.assertEqual(len([p for p in found if "unknown or incomplete directive" in p]), len(bad))
        self.assertEqual(len([p for p in found if ri.HOME_MESSAGE in p]), 1)
        self.assertEqual(len([p for p in found if ri.IDENTITY_MESSAGE.split(" (")[0] in p]), 1)  # only the comment: entries do not exempt the allowlist itself

    def test_ordinary_identifiers_are_not_flagged(self):
        text = "\n".join(["the home_page_code path", "home_screen_work", "is_home_dir_projects", "home-made-projects", "my_home_town_github",
                          "users_per_github_org", "home_assistant_code", "def get_users_by_projects():", "HOME_URL_PROJECTS",
                          "self.home_dir_src", "Users-API-v2", "-home-screen-", "/home/steam", "/home/ollama", "deploy@prod.internal"])
        self.assertEqual(self.problems(text), [])

    def test_line_numbers_survive_escape_decoding_and_far_apart_hits(self):
        text = ("\\u002f" * 40 + "\n") * 3 + home_path("dave") + "\n" + "pad " * 100 + "\n" + mail("pat", "corp.io") + " " + home_path("erin") + "\n"
        self.assertEqual([p.split(" ")[0] for p in self.problems(text)], ["docs/x.md:4:", "docs/x.md:6:", "docs/x.md:6:"])

    def test_personal_email_forms_are_reported(self):
        for address in (mail("dave", "host.local"), mail("dave", "mac.local"), mail("dave", "gmail.com")):
            self.assertEqual(len(self.problems(address)), 1, address)

    def test_system_ci_and_vendor_content_is_not_flagged(self):
        text = "\n".join([
            "/home/linuxbrew/.linuxbrew/bin/brew", "/home/codespace/x", "/home/gitpod/x", "/home/ec2-user/x", "/home/vagrant/x",
            "/home/jovyan/x", "/home/pi/x", "/home/circleci/x", "/home/coder/x", "C:" + "\\Users\\runneradmin\\x",
            "C:" + "\\Users\\Public\\x", "C:" + "\\Users\\Default\\x",
            "logo@2x.png", "icon@3x.webp", "git@gitlab.com:org/repo.git", "git@bitbucket.org:org/repo.git",
            "security@anthropic.com", "support@vendor.io", "Users-and-goals", "_home_core_markets(slug)", "home-page-title",
            "/Users/xxxxxxx/x", "users_table_name", "_home_core_markets", "users-guide-intro",
            "/home/azureuser/x", "/home/opc", "/home/centos", "/home/debian", "/home/fedora", "/var/home/core", "/home/git",
            "/home/postgres", "/home/nonroot", "/home/app", "/home/mambauser", "/home/user1", "/home/johndoe", "/mnt/c/Users/Administrator",
            "C:" + "\\Users\\Administrator", "C:" + "\\Users\\WDAGUtilityAccount",
            "git config user.email action@github.com", "github-actions@github.com", "ssh ubuntu@ec2-1.compute.amazonaws.com",
            "user@domain.tld", "you@yourcompany.com", "jane@acme.com", "first.last@company.com", "hi@anthropic.com", "docs@python.org"])
        self.assertEqual(self.problems(text), [])

    def test_audited_exceptions_come_from_the_allowlist_file(self):
        write(self.root, ri.ALLOW_FILE, "# audited\nhome " + "Dave" + "\nemail " + mail("pat", "corp.io") + "\nemail @" + "ok.org" + "\n")
        text = home_path("dave") + "\n" + mail("pat", "corp.io") + "\n" + mail("any", "ok.org") + "\n"
        write(self.root, "docs/x.md", text)
        self.assertEqual(ri.personal_data(self.root, ["docs/x.md", ri.ALLOW_FILE]), [])
        write(self.root, "docs/y.md", mail("other", "corp.io") + "\n" + home_path("erin") + "\n")
        self.assertEqual(len(ri.personal_data(self.root, ["docs/y.md"])), 2)

    def test_pdf_links_are_scanned_and_other_binaries_skipped(self):
        link = ("/URI (file:///Users/" + "dave" + "/.cursor/x)").encode()
        write(self.root, "r.pdf", b"%PDF-1.4\n\x00\x01\n" + link + b"\n")
        write(self.root, "r.png", b"\x00\x01" + link)
        self.assertEqual(ri.personal_data(self.root, ["r.pdf", "r.png"]), ["r.pdf:3: " + ri.HOME_MESSAGE])

    def test_big_files_with_many_at_signs_scan_quickly(self):
        write(self.root, "big.json", ("a" * 70 + "@" + "b" * 300 + " ") * 4000)
        import time
        start = time.time()
        ri.personal_data(self.root, ["big.json"])
        self.assertLess(time.time() - start, 10)

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

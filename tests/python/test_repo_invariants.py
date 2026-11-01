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
        write(self.root, ".vscode/settings.json", "{'task.allowAutomaticTasks': 'on'}")
        problems = ri.worm_indicators(self.root, [".vscode/settings.json", ".vscode/tasks.json"])
        self.assertEqual(len(problems), 2)
        self.assertIn("sets task.allowAutomaticTasks", problems[0])
        self.assertIn("runOn: folderOpen", problems[1])

    def test_ordinary_config_and_unrelated_files_pass(self):
        write(self.root, ".vscode/tasks.json", '{"tasks": [{"label": "build", "command": "make"}]}')
        write(self.root, "docs/runOn.md", 'Never use "runOn": "folderOpen" in a task.')
        self.assertEqual(ri.worm_indicators(self.root, [".vscode/tasks.json", "docs/runOn.md"]), [])

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

    def test_matching_lock_passes_and_tool_managed_skill_is_allowed(self):
        write(self.root, ".agents/skills/s/SKILL.md", "skill")
        write(self.root, ".agents/skills/graphify/SKILL.md", "g")
        write(self.root, ".agents/skills/graphify/.graphify_version", "1.0")
        write(self.root, ".agents/plugins/marketplace.json", "{}")
        self.lock({"s": {"computedHash": ri.skill_hash(self.root, "s", ["SKILL.md"])}})
        self.assertEqual(ri.vendored_skills_lock(self.root, self.files()), [])

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


class TrackedFileSizeTest(TempRoot):
    def test_large_and_missing_files(self):
        with (self.root / "big.bin").open("wb") as handle:
            handle.truncate((ri.MAX_TRACKED_MIB + 1) * 1024 * 1024)
        write(self.root, "small.txt", "s")
        problems = ri.tracked_file_size(self.root, ["big.bin", "gone.bin", "small.txt"])
        self.assertEqual(problems, ["big.bin: 91.0 MiB, over the 90 MiB limit (GitHub rejects files over 100 MB)"])


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

    def test_cli_entry_point(self):
        write(self.root, "ok.txt", "fine")
        proc = subprocess.run([sys.executable, str(SCRIPT), "worm-indicators", str(self.root)],
                              capture_output=True, text=True)
        self.assertEqual((proc.returncode, proc.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()

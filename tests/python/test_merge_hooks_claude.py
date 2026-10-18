"""Unit tests for scripts/lib/install-claude/merge-hooks.py (runs on temp HOME copies)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT

SCRIPT = str(REPO_ROOT / "scripts/lib/install-claude/merge-hooks.py")
PLUGIN = "${CLAUDE_PLUGIN_ROOT}"


def hook(cmd):
    return {"type": "command", "command": cmd}


class MergeHooksTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name).resolve()
        self.home = self.tmp / "home"
        (self.home / ".claude").mkdir(parents=True)
        self.settings = self.home / ".claude" / "settings.json"

    def make_install(self, rel="plain", hooks=None):
        root = self.tmp / rel
        (root / "hooks").mkdir(parents=True)
        if hooks is None:
            hooks = {
                "PreToolUse": [{"matcher": "Bash", "hooks": [hook(f"{PLUGIN}/hooks/a.sh")]}],
                "SessionStart": [{"hooks": [hook(f"{PLUGIN}/hooks/s.sh")]}],
            }
        (root / "hooks" / "hooks.json").write_text(json.dumps({"hooks": hooks}))
        return root

    def run_script(self, install):
        out = io.StringIO()
        with mock.patch.dict(os.environ, {"HOME": str(self.home)}), \
             mock.patch("sys.argv", ["merge-hooks.py", str(install)]), \
             contextlib.redirect_stdout(out):
            runpy.run_path(SCRIPT, run_name="__main__")
        return out.getvalue()

    def load(self):
        return json.loads(self.settings.read_text())

    def test_creates_settings_when_missing(self):
        install = self.make_install()
        out = self.run_script(install)
        self.assertEqual(out, "SB hooks registered in the host runtime settings.json\n")
        data = self.load()
        self.assertEqual(data["hooks"]["PreToolUse"], [
            {"matcher": "Bash", "hooks": [hook(f"{install}/hooks/a.sh")]}])
        # no matcher -> stored with empty matcher
        self.assertEqual(data["hooks"]["SessionStart"], [
            {"matcher": "", "hooks": [hook(f"{install}/hooks/s.sh")]}])
        self.assertTrue(self.settings.read_text().endswith("}\n"))

    def test_idempotent_second_run_no_change(self):
        install = self.make_install()
        self.run_script(install)
        first = self.settings.read_text()
        self.run_script(install)
        self.assertEqual(self.settings.read_text(), first)

    def test_preserves_foreign_settings_and_hooks(self):
        install = self.make_install()
        self.settings.write_text(json.dumps({
            "theme": "dark",
            "hooks": {"PreToolUse": [
                {"matcher": "Bash", "hooks": [hook("/usr/bin/other")]},
                {"matcher": "Edit", "hooks": [hook("/usr/bin/edit")]},
            ]},
        }))
        self.run_script(install)
        data = self.load()
        self.assertEqual(data["theme"], "dark")
        pre = data["hooks"]["PreToolUse"]
        self.assertEqual(pre[0]["hooks"], [hook("/usr/bin/other"), hook(f"{install}/hooks/a.sh")])
        self.assertEqual(pre[1], {"matcher": "Edit", "hooks": [hook("/usr/bin/edit")]})

    def test_matched_group_without_hooks_key_gets_one(self):
        install = self.make_install()
        # group without "hooks" is dropped by the purge (kept list empty) and re-created
        self.settings.write_text(json.dumps({"hooks": {"PreToolUse": [{"matcher": "Bash"}]}}))
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["PreToolUse"],
                         [{"matcher": "Bash", "hooks": [hook(f"{install}/hooks/a.sh")]}])

    def test_purges_stale_sb_entries(self):
        install = self.make_install()
        self.settings.write_text(json.dumps({"hooks": {
            "PreToolUse": [
                {"matcher": "Bash", "hooks": [
                    hook("/home/u/.claude/plugins/cache/alo-labs/silver-bullet/0.9.0/hooks/a.sh"),
                    hook(f"{PLUGIN}/hooks/literal.sh"),
                    hook("/usr/bin/keep"),
                ]},
                {"matcher": "Edit", "hooks": [hook("/opt/silver-bullet/1.0.0/hooks/z.sh")]},
            ],
            "Stop": [{"matcher": "", "hooks": [hook("/opt/silver-bullet/1.0.0/hooks/stop.sh")]}],
        }}))
        self.run_script(install)
        hooks = self.load()["hooks"]
        self.assertNotIn("Stop", hooks)  # event with only stale entries is removed
        pre = hooks["PreToolUse"]
        self.assertEqual([g["matcher"] for g in pre], ["Bash"])  # Edit group fully stale
        self.assertEqual(pre[0]["hooks"], [hook("/usr/bin/keep"), hook(f"{install}/hooks/a.sh")])

    def test_current_install_entries_not_stale_and_not_duplicated(self):
        install = self.make_install()
        existing = hook(f"{install}/hooks/a.sh")
        self.settings.write_text(json.dumps({"hooks": {
            "PreToolUse": [{"matcher": "Bash", "hooks": [existing]}]}}))
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["PreToolUse"],
                         [{"matcher": "Bash", "hooks": [existing]}])

    def test_substitution_walks_nested_values_and_keeps_non_strings(self):
        install = self.make_install(hooks={"PreToolUse": [{
            "matcher": "Bash",
            "extra": [1, None, True, {"k": f"{PLUGIN}/x"}],
            "hooks": [{"type": "command", "command": f"{PLUGIN}/hooks/a.sh", "timeout": 5}],
        }]})
        self.run_script(install)
        # Only the hook entries are copied (extra group keys are not merged).
        self.assertEqual(self.load()["hooks"]["PreToolUse"], [
            {"matcher": "Bash", "hooks": [
                {"type": "command", "command": f"{install}/hooks/a.sh", "timeout": 5}]}])

    def test_versioned_install_uses_stable_current_alias(self):
        install = self.make_install("silver-bullet/1.2.3")
        self.run_script(install)
        alias = self.tmp / "silver-bullet" / "current"
        self.assertTrue(alias.is_symlink())
        self.assertEqual(os.readlink(alias), str(install))
        self.assertEqual(self.load()["hooks"]["PreToolUse"][0]["hooks"],
                         [hook(f"{alias}/hooks/a.sh")])

    def test_versioned_install_replaces_existing_symlink_dir_and_file_alias(self):
        install = self.make_install("silver-bullet/1.2.3")
        alias = self.tmp / "silver-bullet" / "current"
        other = self.tmp / "elsewhere"
        other.mkdir()
        alias.symlink_to(other)
        self.run_script(install)
        self.assertEqual(os.readlink(alias), str(install))
        self.assertTrue(other.is_dir())  # symlink target untouched

        alias.unlink()
        alias.mkdir()
        (alias / "junk").write_text("x")
        self.run_script(install)
        self.assertTrue(alias.is_symlink())

        alias.unlink()
        alias.write_text("plain file")
        self.run_script(install)
        self.assertTrue(alias.is_symlink())
        self.assertEqual(os.readlink(alias), str(install))

    def test_versioned_install_falls_back_to_raw_path_when_symlink_fails(self):
        install = self.make_install("silver-bullet/2.0.0")
        with mock.patch("pathlib.Path.symlink_to", side_effect=OSError("denied")):
            self.run_script(install)
        self.assertFalse((self.tmp / "silver-bullet" / "current").exists())
        self.assertEqual(self.load()["hooks"]["PreToolUse"][0]["hooks"],
                         [hook(f"{install}/hooks/a.sh")])

    def test_non_version_suffix_is_not_aliased(self):
        install = self.make_install("silver-bullet/latest")
        self.run_script(install)
        self.assertFalse((self.tmp / "silver-bullet" / "current").exists())

    def test_wrong_typed_containers_refused_without_touching_file(self):
        install = self.make_install()
        bad = [[1], {"hooks": "x"}, {"hooks": ["x"]}, {"hooks": {"PreToolUse": "str"}},
               {"hooks": {"PreToolUse": {"a": 1}}}, {"hooks": {"PreToolUse": [{"hooks": "str"}]}},
               {"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": {"a": 1}}]}}]
        for data in bad:
            self.settings.write_text(json.dumps(data))
            before = self.settings.read_bytes()
            with self.assertRaisesRegex(ValueError, "must be a JSON|top level"):
                self.run_script(install)
            self.assertEqual(self.settings.read_bytes(), before)
            self.assertEqual(list(self.settings.parent.glob("*.bak")), [])

    def test_null_or_empty_containers_repaired_and_foreign_entries_kept(self):
        install = self.make_install()
        self.settings.write_text(json.dumps({"hooks": None}))
        self.run_script(install)
        self.assertIn("PreToolUse", self.load()["hooks"])
        self.settings.write_text(json.dumps({"hooks": {"PreToolUse": [
            "foreign", {"matcher": "Bash", "hooks": ["foreign-hook", {"command": None},
                                                       hook("/usr/bin/keep")]}]}}))
        self.run_script(install)
        pre = self.load()["hooks"]["PreToolUse"]
        self.assertEqual(pre[0], "foreign")
        self.assertEqual(pre[1]["hooks"][:3], ["foreign-hook", {"command": None}, hook("/usr/bin/keep")])
        self.assertIn(hook(f"{install}/hooks/a.sh"), pre[1]["hooks"])

    def test_malformed_settings_crash_without_clobbering(self):
        install = self.make_install()
        self.settings.write_text("{not json")
        with self.assertRaises(json.JSONDecodeError):
            self.run_script(install)
        self.assertEqual(self.settings.read_text(), "{not json")

    def test_missing_hooks_json_crashes_without_creating_settings(self):
        install = self.tmp / "empty"
        install.mkdir()
        with self.assertRaises(FileNotFoundError):
            self.run_script(install)
        self.assertFalse(self.settings.exists())

    def test_hooks_json_without_hooks_key_registers_nothing(self):
        install = self.tmp / "nohooks"
        (install / "hooks").mkdir(parents=True)
        (install / "hooks" / "hooks.json").write_text("{}")
        self.run_script(install)
        self.assertEqual(self.load(), {"hooks": {}})

    def test_symlinked_settings_written_through_link(self):
        install = self.make_install()
        real = self.tmp / "real-settings.json"
        real.write_text(json.dumps({"keep": 1}))
        self.settings.symlink_to(real)
        self.run_script(install)
        self.assertTrue(self.settings.is_symlink())
        data = json.loads(real.read_text())
        self.assertEqual(data["keep"], 1)
        self.assertIn("PreToolUse", data["hooks"])


if __name__ == "__main__":
    unittest.main()

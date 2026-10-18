"""Unit tests for scripts/lib/install-cursor/merge-cursor-hooks.py (temp HOME only)."""
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

SCRIPT = str(REPO_ROOT / "scripts/lib/install-cursor/merge-cursor-hooks.py")
ROOT_VAR = "${CURSOR_PLUGIN_ROOT}"


def entry(cmd, matcher=None, **extra):
    item = {"command": cmd}
    if matcher is not None:
        item["matcher"] = matcher
    item.update(extra)
    return item


class MergeCursorHooksTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name).resolve()
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.target = self.home / ".cursor" / "hooks.json"

    def make_install(self, rel="plain", hooks=None):
        root = self.tmp / rel
        (root / "hooks").mkdir(parents=True)
        if hooks is None:
            hooks = {"preToolUse": [entry(f"{ROOT_VAR}/hooks/a.sh", "Shell")]}
        (root / "hooks" / "cursor-hooks.json").write_text(json.dumps({"hooks": hooks}))
        return root

    def run_script(self, *args):
        out = io.StringIO()
        with mock.patch.dict(os.environ, {"HOME": str(self.home)}), \
             mock.patch("sys.argv", ["merge-cursor-hooks.py", *map(str, args)]), \
             contextlib.redirect_stdout(out):
            runpy.run_path(SCRIPT, run_name="__main__")
        return out.getvalue()

    def seed(self, data):
        self.target.parent.mkdir(parents=True, exist_ok=True)
        self.target.write_text(data if isinstance(data, str) else json.dumps(data))

    def load(self):
        return json.loads(self.target.read_text())

    # --- usage / creation -------------------------------------------------
    def test_missing_or_empty_argument_exits_with_usage(self):
        for args in ((), ("",)):
            with self.assertRaises(SystemExit) as cm:
                self.run_script(*args)
            self.assertIn("usage: merge-cursor-hooks.py", str(cm.exception))
        self.assertFalse(self.target.exists())

    def test_creates_file_and_parent_dir(self):
        install = self.make_install()
        out = self.run_script(install)
        self.assertEqual(out, "SB hooks registered in ~/.cursor/hooks.json\n")
        self.assertEqual(self.load(), {
            "version": 1,
            "hooks": {"preToolUse": [entry(f"{install}/hooks/a.sh", "Shell")]},
        })

    def test_idempotent(self):
        install = self.make_install()
        self.run_script(install)
        first = self.target.read_text()
        self.run_script(install)
        self.assertEqual(self.target.read_text(), first)

    def test_existing_version_kept_and_missing_version_defaulted(self):
        install = self.make_install()
        self.seed({"version": 3, "hooks": {}, "other": True})
        self.run_script(install)
        data = self.load()
        self.assertEqual((data["version"], data["other"]), (3, True))
        self.seed({"hooks": {}})
        self.run_script(install)
        self.assertEqual(self.load()["version"], 1)

    def test_settings_without_hooks_key_gets_one(self):
        install = self.make_install()
        self.seed({"version": 1})
        self.run_script(install)
        self.assertIn("preToolUse", self.load()["hooks"])

    def test_same_command_different_matcher_both_registered(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {"preToolUse": [
            entry(f"{install}/hooks/a.sh", "Read")]}})
        self.run_script(install)
        matchers = [e.get("matcher") for e in self.load()["hooks"]["preToolUse"]]
        self.assertEqual(matchers, ["Read", "Shell"])

    def test_new_entry_without_matcher_matches_existing_without_matcher(self):
        install = self.make_install(hooks={"stop": [{"command": f"{ROOT_VAR}/hooks/s.sh"}]})
        self.run_script(install)
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["stop"], [{"command": f"{install}/hooks/s.sh"}])

    # --- stale / malformed purge -----------------------------------------
    def test_purges_stale_and_malformed_entries(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {
            "preToolUse": [
                entry("/x/codex-hook-adapter.sh --foo"),
                entry(f"{ROOT_VAR}/hooks/literal.sh"),
                entry("/dev/plugins/silver-bullet/hooks/dev.sh"),
                entry("/opt/silver-bullet/0.9.0/hooks/old.sh"),
                entry("/usr/bin/keep"),
                entry(f"{install}/hooks/current.sh"),
            ],
            "stop": [entry("/opt/silver-bullet/0.9.0/hooks/s.sh")],
        }})
        self.run_script(install)
        hooks = self.load()["hooks"]
        self.assertNotIn("stop", hooks)
        cmds = [e["command"] for e in hooks["preToolUse"]]
        self.assertEqual(cmds, ["/usr/bin/keep", f"{install}/hooks/current.sh",
                                f"{install}/hooks/a.sh"])

    def test_dev_checkout_entry_inside_current_install_is_kept(self):
        install = self.make_install("dev/plugins/silver-bullet")
        keep = f"{install}/hooks/mine.sh"
        self.seed({"version": 1, "hooks": {"stop": [entry(keep)]}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["stop"], [entry(keep)])

    def test_non_list_event_value_left_alone(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {"custom": {"a": 1}}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["custom"], {"a": 1})

    # --- duplicate collapse ----------------------------------------------
    def test_duplicates_collapse_with_matcher_union_and_max_timeout(self):
        install = self.make_install(hooks={})
        self.seed({"version": 1, "hooks": {"preToolUse": [
            entry("/c/one", "Read|Write", timeout=5),
            entry("/c/two"),
            entry("/c/one", "Write | Shell", timeout=9),
            entry("/c/one", 5, timeout="x"),
            "not-a-dict",
            {"nocommand": True},
            entry("/c/two", "Shell"),
        ]}})
        self.run_script(install)
        out = self.load()["hooks"]["preToolUse"]
        self.assertEqual(out[0], {"command": "/c/one", "matcher": "Read|Write|Shell|5", "timeout": 9})
        self.assertEqual(out[1], {"command": "/c/two"})  # unrestricted wins; no timeouts
        self.assertEqual(out[2:], ["not-a-dict", {"nocommand": True}])

    def test_unrestricted_duplicate_drops_matcher(self):
        install = self.make_install(hooks={})
        self.seed({"version": 1, "hooks": {"stop": [
            entry("/c/x", "Read"), entry("/c/x", ".*"), entry("/c/y", "A"), entry("/c/y", "A")]}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["stop"],
                         [{"command": "/c/x"}, {"command": "/c/y", "matcher": "A"}])

    def test_blank_matchers_collapse_to_unrestricted(self):
        install = self.make_install(hooks={})
        self.seed({"version": 1, "hooks": {"stop": [
            entry("/c/x", "|"), entry("/c/x", " | ")]}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["stop"], [{"command": "/c/x"}])

    # --- bad input ----------------------------------------------------------
    def test_non_dict_and_non_string_command_entries_do_not_crash(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {"preToolUse": [
            "oops", None, 7, {"command": None}, {"command": ["x"]}, entry("/usr/bin/keep")]}})
        self.run_script(install)
        out = self.load()["hooks"]["preToolUse"]
        self.assertEqual(out[:3], ["oops", None, 7])
        self.assertIn(entry("/usr/bin/keep"), out)
        self.assertIn(entry(f"{install}/hooks/a.sh", "Shell"), out)

    def test_foreign_entries_with_odd_commands_survive_and_bridge_is_not_malformed(self):
        install = self.make_install()
        foreign = [{"command": None}, {"command": ["x"]}, {"command": 5}, {"other": 1}]
        bridge = entry("/x/cursor-hook-bridge.sh")
        self.seed({"version": 1, "hooks": {"preToolUse": [
            *foreign, bridge, entry('/y/codex-hook-adapter.sh" cursor-hook-bridge')]}})
        self.run_script(install)
        out = self.load()["hooks"]["preToolUse"]
        for item in foreign:
            self.assertIn(item, out)
        self.assertIn(bridge, out)
        self.assertNotIn('/y/codex-hook-adapter.sh" cursor-hook-bridge',
                         [e.get("command") for e in out])

    def test_malformed_json_crashes_without_clobbering(self):
        install = self.make_install()
        self.seed("{broken")
        with self.assertRaises(json.JSONDecodeError):
            self.run_script(install)
        self.assertEqual(self.target.read_text(), "{broken")

    def test_missing_source_hooks_file_raises(self):
        install = self.tmp / "none"
        install.mkdir()
        with self.assertRaises(FileNotFoundError):
            self.run_script(install)
        self.assertFalse(self.target.exists())

    def test_source_without_hooks_registers_nothing(self):
        install = self.make_install(hooks={})
        self.run_script(install)
        self.assertEqual(self.load(), {"version": 1, "hooks": {}})

    def test_symlinked_target_written_through(self):
        install = self.make_install()
        real = self.tmp / "real.json"
        real.write_text(json.dumps({"version": 1, "keep": 1, "hooks": {}}))
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(real)
        self.run_script(install)
        self.assertTrue(self.target.is_symlink())
        data = json.loads(real.read_text())
        self.assertEqual(data["keep"], 1)
        self.assertIn("preToolUse", data["hooks"])

    # --- stable alias --------------------------------------------------------
    def test_versioned_install_uses_current_alias_replacing_old_kinds(self):
        install = self.make_install("silver-bullet/1.2.3")
        alias = self.tmp / "silver-bullet" / "current"
        self.run_script(install)
        self.assertEqual(os.readlink(alias), str(install))
        self.assertEqual(self.load()["hooks"]["preToolUse"][0]["command"],
                         f"{alias}/hooks/a.sh")
        alias.unlink()
        alias.mkdir()
        (alias / "junk").write_text("x")
        self.run_script(install)
        self.assertTrue(alias.is_symlink())
        alias.unlink()
        alias.write_text("file")
        self.run_script(install)
        self.assertEqual(os.readlink(alias), str(install))
        other = self.tmp / "other"
        other.mkdir()
        alias.unlink()
        alias.symlink_to(other)
        self.run_script(install)
        self.assertEqual(os.readlink(alias), str(install))
        self.assertTrue(other.is_dir())

    def test_alias_failure_falls_back_to_raw_path(self):
        install = self.make_install("silver-bullet/2.0.0")
        with mock.patch("pathlib.Path.symlink_to", side_effect=OSError("denied")):
            self.run_script(install)
        self.assertEqual(self.load()["hooks"]["preToolUse"][0]["command"],
                         f"{install}/hooks/a.sh")

    def test_substitution_handles_nested_and_scalar_values(self):
        install = self.make_install(hooks={"preToolUse": [
            {"command": f"{ROOT_VAR}/hooks/a.sh", "timeout": 3, "env": {"R": ROOT_VAR},
             "list": [ROOT_VAR, 1, None]}]})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["preToolUse"], [{
            "command": f"{install}/hooks/a.sh", "timeout": 3, "env": {"R": str(install)},
            "list": [str(install), 1, None]}])


if __name__ == "__main__":
    unittest.main()

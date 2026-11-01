"""Unit tests for scripts/lib/install-cursor/merge-cursor-hooks.py (temp HOME only)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import shlex
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

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

    def run_script(self, *args, cursor_home=None):
        out = io.StringIO()
        env = {k: v for k, v in os.environ.items() if k != "CURSOR_HOME"}
        env["HOME"] = str(self.home)
        if cursor_home is not None:
            env["CURSOR_HOME"] = str(cursor_home)
        with mock.patch.dict(os.environ, env, clear=True), \
             mock.patch("sys.argv", ["merge-cursor-hooks.py", *map(str, args)]), \
             contextlib.redirect_stdout(out):
            try:
                runpy.run_path(SCRIPT, run_name="__main__")
            except SystemExit as exc:
                if exc.code != 0:
                    raise
        return out.getvalue()

    def refused(self, *args):
        with self.assertRaises(SystemExit) as cm:
            self.run_script(*args)
        return str(cm.exception)

    def seed(self, data):
        self.target.parent.mkdir(parents=True, exist_ok=True)
        self.target.write_text(data if isinstance(data, str) else json.dumps(data))

    def load(self):
        return json.loads(self.target.read_text())

    # --- usage / creation -------------------------------------------------

    def test_missing_or_empty_argument_exits_with_usage(self):
        for args in ((), ("",)):
            self.assertIn("usage: merge-cursor-hooks.py", self.refused(*args))
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

    def test_sb_entry_with_an_old_matcher_is_replaced(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {"preToolUse": [
            entry(f"{install}/hooks/a.sh", "Read")]}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["preToolUse"], [entry(f"{install}/hooks/a.sh", "Shell")])

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
                entry(f"{ROOT_VAR}/hooks/completion-audit.sh"),
                entry("/dev/plugins/silver-bullet/hooks/dev-cycle-check.sh"),
                entry("/opt/silver-bullet/0.9.0/hooks/old.sh"),
                entry("/h/.cursor/plugins/cache/alo-labs/silver-bullet/0.8.0/hooks/gone.sh"),
                entry("/usr/bin/keep"),
                entry(f"{install}/hooks/current.sh"),
            ],
            "stop": [entry("/opt/silver-bullet/0.9.0/hooks/s.sh")],
        }})
        self.run_script(install)
        hooks = self.load()["hooks"]
        self.assertNotIn("stop", hooks)
        cmds = [e["command"] for e in hooks["preToolUse"]]
        self.assertEqual(cmds, ["/usr/bin/keep", f"{install}/hooks/a.sh"])

    def test_entry_inside_the_install_but_not_in_the_manifest_is_dropped(self):
        install = self.make_install("dev/plugins/silver-bullet")
        self.seed({"version": 1, "hooks": {"stop": [entry(f"{install}/hooks/mine.sh")]}})
        self.run_script(install)
        self.assertNotIn("stop", self.load()["hooks"])

    def test_non_list_event_value_left_alone(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {"custom": {"a": 1}}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["custom"], {"a": 1})

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

    def test_wrong_typed_containers_refused_without_touching_file(self):
        install = self.make_install()
        for data in ([1], {"hooks": "x"}, {"hooks": [{"a": 1}]},
                     {"hooks": {"preToolUse": "str"}}, {"hooks": {"preToolUse": {"a": 1}}}):
            self.seed(data)
            before = self.target.read_bytes()
            self.assertRegex(self.refused(install), "must be a JSON|top level")
            self.assertEqual(self.target.read_bytes(), before)
            self.assertEqual(list(self.target.parent.glob("*.sb-backup")), [])

    def test_wrong_typed_manifest_is_refused(self):
        install = self.make_install(hooks=[1])
        self.assertIn("hooks must be a JSON object", self.refused(install))
        install = self.make_install("other", hooks={"stop": {"a": 1}})
        self.assertIn("stop must be a JSON array", self.refused(install))
        self.assertFalse(self.target.exists())

    def test_null_or_empty_containers_are_repaired(self):
        install = self.make_install()
        for data in ({"hooks": None}, {"hooks": []}, {"hooks": {"preToolUse": None}},
                     {"hooks": {"preToolUse": {}}}):
            self.seed(data)
            self.run_script(install)
            self.assertEqual(self.load()["hooks"]["preToolUse"], [entry(f"{install}/hooks/a.sh", "Shell")])

    def test_malformed_json_is_refused_without_clobbering(self):
        install = self.make_install()
        self.seed("{broken")
        self.assertIn("not valid JSON", self.refused(install))
        self.assertEqual(self.target.read_text(), "{broken")

    def test_missing_source_hooks_file_is_refused(self):
        install = self.tmp / "none"
        install.mkdir()
        self.assertIn("hook manifest not found", self.refused(install))
        self.assertFalse(self.target.exists())

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

    # --- ownership-based replace (R7-04, R7-28, R7-02, R7-14) -------------

    def bridge(self, root, event, script):
        return f'"{root}/hooks/cursor-hook-bridge.sh" {event} "{root}/hooks/{script}"'

    def test_upgrade_drops_removed_hooks_and_updates_changed_fields(self):
        old = self.make_install("cache/silver-bullet/1.0.0", hooks={"preToolUse": [
            entry(self.bridge(ROOT_VAR, "preToolUse", "graphify-gate.sh"), "Shell", timeout=10),
            entry(self.bridge(ROOT_VAR, "preToolUse", "completion-audit.sh"), "Shell", timeout=15)]})
        self.run_script(old)
        new = self.make_install("cache/silver-bullet/2.0.0", hooks={"preToolUse": [
            entry(self.bridge(ROOT_VAR, "preToolUse", "completion-audit.sh"), "Shell|Read", timeout=30)]})
        self.run_script(new)
        alias = self.tmp / "cache" / "silver-bullet" / "current"
        self.assertEqual(self.load()["hooks"]["preToolUse"], [
            entry(self.bridge(alias, "preToolUse", "completion-audit.sh"), "Shell|Read", timeout=30)])

    def test_real_manifest_merged_twice_equals_the_manifest(self):
        manifest = json.loads((REPO_ROOT / "hooks" / "cursor-hooks.json").read_text())
        install = self.make_install("real", hooks=manifest["hooks"])
        user = entry("/usr/local/bin/my-guard --strict", "Shell")
        self.seed({"version": 1, "hooks": {"preToolUse": [user]}})
        for _ in range(3):
            self.run_script(install)
        hooks = self.load()["hooks"]
        for event, entries in manifest["hooks"].items():
            expected = json.loads(json.dumps(entries).replace(ROOT_VAR, str(install)))
            if event == "preToolUse":
                expected = [user, *expected]
            self.assertEqual(hooks[event], expected, event)

    def test_install_path_with_space_or_shell_characters_stays_one_argument(self):
        for rel in ("Jane Doe/sb", 'odd $HOME `x` "q"\\b/sb'):
            install = self.make_install(rel, hooks={"stop": [
                entry(self.bridge(ROOT_VAR, "stop", "stop-check.sh"))]})
            bridge = install / "hooks" / "cursor-hook-bridge.sh"
            bridge.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$0" "$@"\n')
            bridge.chmod(0o755)
            self.run_script(install)
            command = self.load()["hooks"]["stop"][0]["command"]
            ran = subprocess.run(["bash", "-c", command], capture_output=True, text=True, check=True)
            self.assertEqual(ran.stdout.splitlines(), [str(bridge), "stop", f"{install}/hooks/stop-check.sh"])
            self.assertEqual(len(shlex.split(command)), 3)
            self.target.unlink()

    def test_old_unquoted_entries_are_replaced(self):
        install = self.make_install("cache/silver-bullet/3.0.0", hooks={"stop": [
            entry(self.bridge(ROOT_VAR, "stop", "stop-check.sh"))]})
        alias = self.tmp / "cache" / "silver-bullet" / "current"
        old = f'"{alias}/hooks/cursor-hook-bridge.sh" stop {alias}/hooks/stop-check.sh'
        self.seed({"version": 1, "hooks": {"stop": [entry(old)]}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["stop"], [entry(self.bridge(alias, "stop", "stop-check.sh"))])

    def test_foreign_entries_are_never_collapsed_or_reordered(self):
        install = self.make_install(hooks={})
        foreign = [entry("/c/one", "Read", timeout=5), entry("/c/one", "Write", timeout=9),
                   entry('node "$HOME/.cursor/hooks/x.js"'), entry("echo silver-bullet rocks"),
                   entry("/x/cursor-hook-bridge.sh"), entry(f"{ROOT_VAR}/hooks/other-plugin.sh")]
        self.seed({"version": 1, "hooks": {"stop": foreign}})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["stop"], foreign)

    def test_write_is_atomic_keeps_mode_and_backs_up(self):
        install = self.make_install()
        self.seed({"version": 1, "hooks": {"stop": [entry("/mine.sh")]}})
        before = self.target.read_bytes()
        self.target.chmod(0o600)
        self.run_script(install)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)
        self.assertEqual((self.target.parent / "hooks.json.sb-backup").read_bytes(), before)
        self.assertEqual(sorted(p.name for p in self.target.parent.iterdir()), ["hooks.json", "hooks.json.sb-backup"])
        mtime = self.target.stat().st_mtime_ns
        self.run_script(install)
        self.assertEqual(self.target.stat().st_mtime_ns, mtime)

    def test_cursor_home_is_honoured(self):
        install = self.make_install()
        other = self.tmp / "elsewhere"
        out = self.run_script(install, cursor_home=other)
        self.assertEqual(out, f"SB hooks registered in {other}/hooks.json\n")
        self.assertTrue((other / "hooks.json").is_file())
        self.assertFalse(self.target.exists())

    def test_importing_the_module_merges_nothing(self):
        module = load_module("scripts/lib/install-cursor/merge-cursor-hooks.py")
        self.assertEqual(module.shell_escaped('a"b$c`d\\e'), 'a\\"b\\$c\\`d\\\\e')
        self.assertFalse(self.target.exists())

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

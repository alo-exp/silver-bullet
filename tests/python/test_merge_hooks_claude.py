"""Unit tests for scripts/lib/install-claude/merge-hooks.py (runs on temp HOME copies)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

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
        self.registry = self.home / ".claude" / "plugins" / "installed_plugins.json"

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

    def run_script(self, install, **env):
        out = io.StringIO()
        clean = {k: v for k, v in os.environ.items() if k != "CLAUDE_CONFIG_DIR"}
        clean.update({"HOME": str(self.home), **env})
        with mock.patch.dict(os.environ, clean, clear=True), \
             mock.patch("sys.argv", ["merge-hooks.py", str(install)]), \
             contextlib.redirect_stdout(out):
            try:
                runpy.run_path(SCRIPT, run_name="__main__")
            except SystemExit as exc:
                if exc.code != 0:
                    raise
        return out.getvalue()

    def refused(self, install):
        with self.assertRaises(SystemExit) as cm:
            self.run_script(install)
        return str(cm.exception)

    def load(self):
        return json.loads(self.settings.read_text())

    def register_plugin(self):
        self.registry.parent.mkdir(parents=True, exist_ok=True)
        self.registry.write_text(json.dumps({"plugins": {
            "silver-bullet@alo-labs": [{"installPath": "/x"}], "other@m": [{}]}}))

    # --- manual installs: every (event, matcher, command) is registered -----------------

    def test_creates_settings_when_missing(self):
        install = self.make_install()
        out = self.run_script(install)
        self.assertEqual(out, f"SB hooks registered in {self.settings}\n")
        data = self.load()
        self.assertEqual(data["hooks"]["PreToolUse"], [
            {"matcher": "Bash", "hooks": [hook(f"{install}/hooks/a.sh")]}])
        self.assertEqual(data["hooks"]["SessionStart"], [
            {"matcher": "", "hooks": [hook(f"{install}/hooks/s.sh")]}])
        self.assertTrue(self.settings.read_text().endswith("}\n"))

    def test_creates_the_claude_dir_on_a_fresh_home(self):
        (self.home / ".claude").rmdir()
        install = self.make_install()
        self.run_script(install)
        self.assertIn("SessionStart", self.load()["hooks"])

    def test_every_registration_of_the_real_manifest_is_kept(self):
        """R7-29: a hook registered under several matchers keeps all of them (96 of 96)."""
        manifest = json.loads((REPO_ROOT / "hooks" / "hooks.json").read_text())
        install = self.make_install("real", hooks=manifest["hooks"])

        def triples(hooks, root):
            return sorted((event, group.get("matcher", ""), h["command"].replace(PLUGIN, root))
                          for event, groups in hooks.items() for group in groups for h in group["hooks"])

        expected = triples(manifest["hooks"], str(install))
        self.assertEqual(len(expected), 96)
        for _ in range(2):
            self.run_script(install)
            self.assertEqual(triples(self.load()["hooks"], str(install)), expected)

    def test_idempotent_second_run_no_change(self):
        install = self.make_install()
        self.run_script(install)
        first = self.settings.read_text()
        mtime = self.settings.stat().st_mtime_ns
        self.run_script(install)
        self.assertEqual(self.settings.read_text(), first)
        self.assertEqual(self.settings.stat().st_mtime_ns, mtime)

    def test_user_groups_are_never_touched(self):
        install = self.make_install()
        user = [{"matcher": "Bash", "hooks": [hook("/usr/bin/other"), hook('node "$HOME/.claude/hooks/x.js"')]},
                {"matcher": "Edit", "hooks": [hook('"${CLAUDE_PROJECT_DIR}/.claude/hooks/lint.sh"')]}]
        self.settings.write_text(json.dumps({"theme": "dark", "hooks": {"PreToolUse": user}}))
        self.run_script(install)
        data = self.load()
        self.assertEqual(data["theme"], "dark")
        self.assertEqual(data["hooks"]["PreToolUse"][:2], user)
        self.assertEqual(data["hooks"]["PreToolUse"][2], {"matcher": "Bash", "hooks": [hook(f"{install}/hooks/a.sh")]})

    def test_purges_stale_sb_entries_only(self):
        install = self.make_install()
        self.settings.write_text(json.dumps({"hooks": {
            "PreToolUse": [
                {"matcher": "Bash", "hooks": [
                    hook("/home/u/.claude/plugins/cache/alo-labs/silver-bullet/0.9.0/hooks/a.sh"),
                    hook(f"{PLUGIN}/hooks/completion-audit.sh"),
                    hook(f"{PLUGIN}/hooks/other-plugin.sh"),
                    hook("/usr/bin/keep"),
                ]},
                {"matcher": "Edit", "hooks": [hook("/opt/silver-bullet/1.0.0/hooks/z.sh")]},
            ],
            "Stop": [{"matcher": "", "hooks": [hook("/opt/silver-bullet/1.0.0/hooks/stop.sh")]}],
            "Empty": [],
        }}))
        self.run_script(install)
        hooks = self.load()["hooks"]
        self.assertNotIn("Stop", hooks)  # event with only stale entries is removed
        self.assertEqual(hooks["Empty"], [])  # the user's empty event is kept
        pre = hooks["PreToolUse"]
        self.assertEqual(pre[0], {"matcher": "Bash", "hooks": [hook(f"{PLUGIN}/hooks/other-plugin.sh"), hook("/usr/bin/keep")]})
        self.assertEqual(pre[1:], [{"matcher": "Bash", "hooks": [hook(f"{install}/hooks/a.sh")]}])

    def test_substitution_walks_nested_values_and_keeps_non_strings(self):
        install = self.make_install(hooks={"PreToolUse": [{
            "matcher": "Bash",
            "extra": [1, None, True, {"k": f"{PLUGIN}/x"}],
            "hooks": [{"type": "command", "command": f"{PLUGIN}/hooks/a.sh", "timeout": 5}],
        }]})
        self.run_script(install)
        self.assertEqual(self.load()["hooks"]["PreToolUse"], [
            {"matcher": "Bash", "hooks": [
                {"type": "command", "command": f"{install}/hooks/a.sh", "timeout": 5}]}])

    def test_versioned_install_uses_stable_current_alias(self):
        install = self.make_install("silver-bullet/1.2.3")
        self.run_script(install)
        alias = self.tmp / "silver-bullet" / "current"
        self.assertTrue(alias.is_symlink())
        self.assertEqual(os.readlink(alias), str(install))
        self.assertEqual(self.load()["hooks"]["PreToolUse"][0]["hooks"], [hook(f"{alias}/hooks/a.sh")])

    def test_versioned_install_replaces_existing_symlink_dir_and_file_alias(self):
        install = self.make_install("silver-bullet/1.2.3")
        alias = self.tmp / "silver-bullet" / "current"
        other = self.tmp / "elsewhere"
        other.mkdir()
        alias.symlink_to(other)
        self.run_script(install)
        self.assertEqual(os.readlink(alias), str(install))
        self.assertTrue(other.is_dir())
        alias.unlink()
        alias.mkdir()
        (alias / "junk").write_text("x")
        self.run_script(install)
        self.assertTrue(alias.is_symlink())
        alias.unlink()
        alias.write_text("plain file")
        self.run_script(install)
        self.assertEqual(os.readlink(alias), str(install))

    def test_versioned_install_falls_back_to_raw_path_when_symlink_fails(self):
        install = self.make_install("silver-bullet/2.0.0")
        with mock.patch("pathlib.Path.symlink_to", side_effect=OSError("denied")):
            self.run_script(install)
        self.assertFalse((self.tmp / "silver-bullet" / "current").exists())
        self.assertEqual(self.load()["hooks"]["PreToolUse"][0]["hooks"], [hook(f"{install}/hooks/a.sh")])

    def test_non_version_suffix_is_not_aliased(self):
        install = self.make_install("silver-bullet/latest")
        self.run_script(install)
        self.assertFalse((self.tmp / "silver-bullet" / "current").exists())

    # --- R7-21: the Claude Code plugin delivers the hooks; settings get no copies -------

    def test_plugin_install_adds_nothing_and_removes_old_copies(self):
        install = self.make_install("cache/alo-labs/silver-bullet/1.0.0")
        self.run_script(install)  # an earlier sb:init copied the hooks
        self.assertIn("PreToolUse", self.load()["hooks"])
        user = {"matcher": "Bash", "hooks": [hook('"$HOME/bin/fmt.sh"')]}
        data = self.load()
        data["hooks"]["PreToolUse"].insert(0, user)
        self.settings.write_text(json.dumps(data))
        self.register_plugin()
        out = self.run_script(install)
        self.assertIn("delivered by the Claude Code plugin; removed 2 duplicate settings entries", out)
        self.assertEqual(self.load()["hooks"], {"PreToolUse": [user]})
        self.assertIn("removed 0 duplicate settings entries", self.run_script(install))

    def test_plugin_install_on_clean_settings_writes_nothing_new(self):
        install = self.make_install()
        self.register_plugin()
        self.settings.write_text(json.dumps({"theme": "dark"}))
        self.assertIn("removed 0 duplicate settings entries", self.run_script(install))
        self.assertEqual(self.load(), {"theme": "dark", "hooks": {}})

    def test_one_removed_entry_is_reported_in_the_singular(self):
        install = self.make_install(hooks={"Stop": [{"hooks": [hook(f"{PLUGIN}/hooks/s.sh")]}]})
        self.run_script(install)
        self.register_plugin()
        self.assertIn("removed 1 duplicate settings entry from", self.run_script(install))

    def test_other_hosts_install_paths_are_not_merged(self):
        for rel in (".codex/plugins/cache/alo-labs-codex/silver-bullet/current", ".cursor/plugins/cache/alo-labs/silver-bullet/current"):
            install = self.make_install(rel)
            self.assertIn("belongs to another host", self.run_script(install))
        self.assertFalse(self.settings.exists())

    def test_claude_config_dir_is_honoured(self):
        install = self.make_install()
        config = self.tmp / "config"
        out = self.run_script(install, CLAUDE_CONFIG_DIR=str(config))
        self.assertEqual(out, f"SB hooks registered in {config / 'settings.json'}\n")
        self.assertFalse(self.settings.exists())

    def test_write_is_atomic_keeps_mode_and_backs_up(self):
        install = self.make_install()
        self.settings.write_text(json.dumps({"keep": 1}))
        self.settings.chmod(0o600)
        self.run_script(install)
        self.assertEqual(stat.S_IMODE(self.settings.stat().st_mode), 0o600)
        self.assertEqual(json.loads((self.settings.parent / "settings.json.sb-backup").read_text()), {"keep": 1})

    # --- refusals ------------------------------------------------------------------------

    def test_wrong_typed_containers_refused_without_touching_file(self):
        install = self.make_install()
        bad = [[1], {"hooks": "x"}, {"hooks": ["x"]}, {"hooks": {"PreToolUse": "str"}},
               {"hooks": {"PreToolUse": {"a": 1}}}]
        for data in bad:
            self.settings.write_text(json.dumps(data))
            before = self.settings.read_bytes()
            self.assertRegex(self.refused(install), "must be a JSON|top level")
            self.assertEqual(self.settings.read_bytes(), before)
            self.assertEqual(list(self.settings.parent.glob("*.sb-backup")), [])

    def test_wrong_typed_manifest_or_registry_refused(self):
        install = self.make_install(hooks={"Stop": {"a": 1}})
        self.assertIn("Stop must be a JSON array", self.refused(install))
        install = self.make_install("list", hooks=[1])
        self.assertIn("hooks must be a JSON object", self.refused(install))
        self.registry.parent.mkdir(parents=True)
        self.registry.write_text("{broken")
        self.assertIn("not valid JSON", self.refused(self.make_install("third")))
        self.assertFalse(self.settings.exists())

    def test_foreign_and_odd_entries_kept_untouched(self):
        install = self.make_install()
        odd = ["foreign", {"matcher": "Bash", "hooks": ["foreign-hook", {"command": None}, hook("/usr/bin/keep")]},
               {"hooks": "str"}, {"matcher": "Bash", "hooks": {"a": 1}}]
        self.settings.write_text(json.dumps({"hooks": {"PreToolUse": odd, "Stop": None}}))
        self.run_script(install)
        hooks = self.load()["hooks"]
        self.assertEqual(hooks["PreToolUse"][:4], odd)
        self.assertEqual(hooks["Stop"], [])
        self.settings.write_text(json.dumps({"hooks": None}))
        self.run_script(install)
        self.assertIn("PreToolUse", self.load()["hooks"])

    def test_malformed_settings_refused_without_clobbering(self):
        install = self.make_install()
        self.settings.write_text("{not json")
        self.assertIn("not valid JSON", self.refused(install))
        self.assertEqual(self.settings.read_text(), "{not json")

    def test_missing_hooks_json_refused_without_creating_settings(self):
        install = self.tmp / "empty"
        install.mkdir()
        self.assertIn("hook manifest not found", self.refused(install))
        self.assertFalse(self.settings.exists())

    def test_missing_argument_prints_usage(self):
        for argv in (["merge-hooks.py"], ["merge-hooks.py", ""]):
            with mock.patch("sys.argv", argv), self.assertRaises(SystemExit) as cm:
                runpy.run_path(SCRIPT, run_name="__main__")
            self.assertIn("usage: merge-hooks.py", str(cm.exception))

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

    def test_importing_the_module_merges_nothing(self):
        module = load_module("scripts/lib/install-claude/merge-hooks.py", "sbtest_claude_merge_hooks")
        self.assertEqual(module.sub_path([1, "x"], "/r"), [1, "x"])
        self.assertFalse(self.settings.exists())


if __name__ == "__main__":
    unittest.main()

"""Unit tests for scripts/lib/merge-token-compression-config.py (temp HOME / temp repo only)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

REL = "scripts/lib/merge-token-compression-config.py"
mod = load_module(REL)

MANIFEST = {
    "tools": {
        "context_mode": {"command": "/opt/g/context-mode", "args": ["mcp"], "env": {"CM": "1"}},
        "rtk": {"command": "/opt/g/rtk", "args": []},
        "graphify": {"command": "/opt/g/graphify", "args": ["serve"], "env": {}},
        "agentmemory": {"command": "/opt/g/agentmemory", "args": ["mcp"], "env": {}},
        "leanctx": {"command": "/opt/g/lean-ctx", "args": ["mcp"], "env": {}},
    }
}


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name).resolve()
        self.home = self.tmp / "home"
        self.home.mkdir()
        env = {k: v for k, v in os.environ.items() if k not in ("CODEX_HOME", "CONTEXT_MODE_PKG")}
        env["HOME"] = str(self.home)
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        # No real PATH lookups or network-ish commands, ever.
        which = mock.patch.object(mod.shutil, "which", return_value=None)
        which.start()
        self.addCleanup(which.stop)
        npm = mock.patch("subprocess.check_output", side_effect=FileNotFoundError("npm"))
        self.npm = npm.start()
        self.addCleanup(npm.stop)
        ens = mock.patch.object(mod, "ensure_global_instances", return_value=MANIFEST)
        self.ensure = ens.start()
        self.addCleanup(ens.stop)
        dis = mock.patch.object(mod, "disable_claude_native_context_mode", return_value=False)
        self.disable = dis.start()
        self.addCleanup(dis.stop)

    def quiet(self, fn, *a, **kw):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            result = fn(*a, **kw)
        self.out, self.err = out.getvalue(), err.getvalue()
        return result

    def write(self, path, data):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data if isinstance(data, str) else json.dumps(data))
        return path

    def read_json(self, path):
        return json.loads(Path(path).read_text())

    def make_pkg(self, name="cm-pkg"):
        pkg = self.tmp / name
        (pkg / "configs" / "cursor").mkdir(parents=True)
        (pkg / "configs" / "codex").mkdir(parents=True)
        (pkg / "configs" / "opencode").mkdir(parents=True)
        os.environ["CONTEXT_MODE_PKG"] = str(pkg)
        return pkg


class JsonFilesTest(Base):
    def test_load_json(self):
        self.assertEqual(mod.load_json(self.tmp / "none.json"), {})
        self.assertEqual(mod.load_json(self.tmp / "none.json", {"d": 1}), {"d": 1})
        self.assertEqual(mod.load_json(self.write(self.tmp / "a.json", {"k": 1})), {"k": 1})
        with self.assertRaises(json.JSONDecodeError):
            mod.load_json(self.write(self.tmp / "bad.json", "{x"))

    def test_load_json_non_object_raises_value_error(self):
        with self.assertRaisesRegex(ValueError, "expected a JSON object"):
            mod.load_json(self.write(self.tmp / "list.json", "[1]"))

    def test_save_json_and_backup(self):
        target = self.tmp / "a" / "b.json"
        self.quiet(mod.save_json, target, {"a": 1}, False)
        self.assertEqual(target.read_text(), '{\n  "a": 1\n}\n')
        self.assertFalse(target.with_suffix(".json.bak").exists())
        self.quiet(mod.save_json, target, {"a": 2}, False)
        self.assertEqual(self.read_json(target.with_suffix(".json.bak")), {"a": 1})
        self.quiet(mod.save_json, target, {"a": 3}, True)
        self.assertEqual(self.out, f"DRY-RUN: would write {target}\n")
        self.assertEqual(self.read_json(target), {"a": 2})

    def test_backup_file_ignores_missing(self):
        mod.backup_file(self.tmp / "none")
        self.assertEqual(list(self.tmp.glob("*.bak")), [])
        f = self.write(self.tmp / "x.txt", "hi")
        mod.backup_file(f)
        self.assertEqual((self.tmp / "x.txt.bak").read_text(), "hi")


class HookEntriesTest(Base):
    def test_command_and_key(self):
        self.assertEqual(mod.hook_command({"command": 5}), "5")
        self.assertEqual(mod.hook_command({}), "")
        self.assertEqual(mod.hook_entry_key({"command": "c", "matcher": "m"}), ("c", "m"))
        self.assertEqual(mod.hook_entry_key({"command": "c"}), ("c", ""))

    def test_non_dict_entries_do_not_crash(self):
        self.assertEqual(mod.hook_command("junk"), "")
        self.assertEqual(mod.hook_command(None), "")
        self.assertEqual(mod.hook_entry_key("junk"), ("", ""))
        merged, added = mod.merge_hook_entries(["junk", None, {"command": "a"}], [{"command": "b"}])
        self.assertEqual((merged, added), (["junk", None, {"command": "a"}, {"command": "b"}], 1))

    def test_merge_hook_entries(self):
        existing = [{"command": "a", "matcher": "x"}]
        merged, added = mod.merge_hook_entries(existing, [
            {"command": "a", "matcher": "x"},       # duplicate
            {"command": "a", "matcher": "y"},       # same cmd, other matcher: kept
            {"command": ""},                         # blank command skipped
            {"matcher": "z"},                        # no command skipped
            {"command": "b"},
        ])
        self.assertEqual(added, 2)
        self.assertEqual(merged, [{"command": "a", "matcher": "x"}, {"command": "a", "matcher": "y"},
                                  {"command": "b"}])
        self.assertEqual(existing, [{"command": "a", "matcher": "x"}])  # not mutated

    def test_reorder(self):
        rtk, cm = {"command": "rtk hook cursor"}, {"command": "context-mode hook cursor pretooluse"}
        other = {"command": "other"}
        hooks = {"preToolUse": [other, cm, rtk]}
        self.assertTrue(mod.reorder_pretooluse_rtk_before_cm(hooks))
        self.assertEqual(hooks["preToolUse"], [other, rtk, cm])
        self.assertFalse(mod.reorder_pretooluse_rtk_before_cm(hooks))  # already ordered
        self.assertFalse(mod.reorder_pretooluse_rtk_before_cm({}))
        self.assertFalse(mod.reorder_pretooluse_rtk_before_cm({"preToolUse": "x"}))
        self.assertFalse(mod.reorder_pretooluse_rtk_before_cm({"preToolUse": [cm]}))
        self.assertFalse(mod.reorder_pretooluse_rtk_before_cm({"preToolUse": [rtk]}))
        hooks = {"preToolUse": ["junk", cm, None, rtk]}
        self.assertTrue(mod.reorder_pretooluse_rtk_before_cm(hooks))
        self.assertEqual(hooks["preToolUse"], ["junk", rtk, cm, None])


class MergeHooksFileTest(Base):
    def test_create_and_idempotent(self):
        target = self.home / ".cursor" / "hooks.json"
        frags = [{"hooks": {"preToolUse": [{"command": "context-mode hook cursor pretooluse"}]}},
                 {"hooks": {"preToolUse": [{"command": "rtk hook cursor"}], "stop": [{"command": "s"}]}}]
        added = self.quiet(mod.merge_hooks_file, target, frags, False)
        self.assertEqual(added, 3)
        data = self.read_json(target)
        self.assertEqual(data["version"], 1)
        # RTK is moved in front of Context Mode
        self.assertEqual([e["command"] for e in data["hooks"]["preToolUse"]],
                         ["rtk hook cursor", "context-mode hook cursor pretooluse"])
        self.assertEqual(self.quiet(mod.merge_hooks_file, target, frags, False), 0)
        self.assertEqual(self.read_json(target), data)

    def test_existing_settings_kept(self):
        target = self.write(self.home / "h.json", {"version": 7, "x": 1, "hooks": {
            "stop": [{"command": "mine"}]}})
        self.quiet(mod.merge_hooks_file, target, [{"hooks": {"stop": [{"command": "s"}]}}, {}], False)
        data = self.read_json(target)
        self.assertEqual((data["version"], data["x"]), (7, 1))
        self.assertEqual([e["command"] for e in data["hooks"]["stop"]], ["mine", "s"])
        no_version = self.write(self.home / "h2.json", {"hooks": {}})
        self.quiet(mod.merge_hooks_file, no_version, [], False)
        self.assertEqual(self.read_json(no_version)["version"], 1)

    def test_dry_run_and_malformed(self):
        target = self.home / "h.json"
        added = self.quiet(mod.merge_hooks_file, target, [{"hooks": {"stop": [{"command": "s"}]}}], True)
        self.assertEqual(added, 1)
        self.assertFalse(target.exists())
        self.assertIn("DRY-RUN: would write", self.out)
        self.write(target, "{bad")
        with self.assertRaises(json.JSONDecodeError):
            self.quiet(mod.merge_hooks_file, target, [], False)
        self.assertEqual(target.read_text(), "{bad")


class MergeCodexHooksTest(Base):
    FRAG = {"hooks": {"SessionStart": [{"matcher": "", "hooks": [
        {"type": "command", "command": "context-mode hook codex sessionstart"}]}]}}

    def test_create_dedupe_and_dry_run(self):
        target = self.home / ".codex" / "hooks.json"
        self.assertEqual(self.quiet(mod.merge_codex_hooks_file, target, self.FRAG, False), 1)
        self.assertEqual(self.quiet(mod.merge_codex_hooks_file, target, self.FRAG, False), 0)
        self.assertEqual(len(self.read_json(target)["hooks"]["SessionStart"]), 1)
        other = self.home / "other.json"
        self.assertEqual(self.quiet(mod.merge_codex_hooks_file, other, self.FRAG, True), 1)
        self.assertFalse(other.exists())

    def test_tolerates_foreign_shapes(self):
        target = self.write(self.home / "hooks.json", {"hooks": {"SessionStart": [
            "junk", {"hooks": ["junk", {"command": "mine"}]}, {"hooks": []}, {}]}})
        self.assertEqual(self.quiet(mod.merge_codex_hooks_file, target, self.FRAG, False), 1)
        groups = self.read_json(target)["hooks"]["SessionStart"]
        self.assertEqual(len(groups), 5)
        self.assertEqual(groups[0], "junk")

    def test_group_without_commands_and_non_command_entries(self):
        frag = {"hooks": {"Stop": [{"hooks": ["junk", {"type": "x"}]}]}}
        target = self.home / "hooks.json"
        self.assertEqual(self.quiet(mod.merge_codex_hooks_file, target, frag, False), 1)

    def test_entry_in_other_group_counts_as_present(self):
        target = self.write(self.home / "hooks.json", {"hooks": {"SessionStart": [
            {"hooks": [{"command": "x"}, {"command": "context-mode hook codex sessionstart"}]}]}})
        self.assertEqual(self.quiet(mod.merge_codex_hooks_file, target, self.FRAG, False), 0)


class McpMergeTest(Base):
    def test_merge_mcp_server(self):
        target = self.home / ".cursor" / "mcp.json"
        self.assertTrue(self.quiet(mod.merge_mcp_server, target, "a", {"command": "a"}, False))
        self.assertFalse(self.quiet(mod.merge_mcp_server, target, "a", {"command": "other"}, False))
        self.assertTrue(self.quiet(mod.merge_mcp_server, target, "b", {"command": "b"}, False))
        self.assertEqual(self.read_json(target), {"mcpServers": {"a": {"command": "a"}, "b": {"command": "b"}}})
        self.assertTrue(self.quiet(mod.merge_mcp_server, target, "c", {}, True))
        self.assertNotIn("c", self.read_json(target)["mcpServers"])

    def test_merge_mcp_server_bad_container(self):
        for bad in (None, [], "x"):
            target = self.write(self.home / "m.json", {"mcpServers": bad, "keep": 1})
            self.assertTrue(self.quiet(mod.merge_mcp_server, target, "a", {"command": "a"}, False), bad)
            data = self.read_json(target)
            self.assertEqual((data["keep"], data["mcpServers"]), (1, {"a": {"command": "a"}}))

    def test_shared_claude_context_mode(self):
        spec = {"command": "/opt/cm", "args": ["mcp"], "env": {}}
        target = self.home / ".claude.json"
        f = mod.merge_shared_claude_context_mode
        self.assertTrue(self.quiet(f, target, spec, False))
        self.assertEqual(self.read_json(target)["mcpServers"]["context-mode"], spec)
        self.assertFalse(self.quiet(f, target, spec, False))
        # command/args drift repaired, other keys preserved
        self.write(target, {"mcpServers": {"context-mode": {"command": "old", "args": [], "mine": 1}}})
        self.assertTrue(self.quiet(f, target, spec, False))
        cm = self.read_json(target)["mcpServers"]["context-mode"]
        self.assertEqual((cm["command"], cm["args"], cm["mine"]), ("/opt/cm", ["mcp"], 1))
        # legacy alias is promoted then repaired
        self.write(target, {"mcpServers": {"user-context-mode": {"command": "legacy", "args": ["mcp"]}}})
        self.assertTrue(self.quiet(f, target, spec, False))
        servers = self.read_json(target)["mcpServers"]
        self.assertEqual(list(servers), ["context-mode"])
        self.assertEqual(servers["context-mode"]["command"], "/opt/cm")
        # legacy alias dropped when canonical exists and is current
        self.write(target, {"mcpServers": {"context-mode": dict(spec), "user-context-mode": {}}})
        self.assertTrue(self.quiet(f, target, spec, False))
        self.assertNotIn("user-context-mode", self.read_json(target)["mcpServers"])
        # malformed canonical entry replaced
        self.write(target, {"mcpServers": {"context-mode": "bad"}})
        self.assertTrue(self.quiet(f, target, spec, False))
        self.assertEqual(self.read_json(target)["mcpServers"]["context-mode"], spec)
        # dry run leaves the file
        self.write(target, {"mcpServers": {}})
        self.assertTrue(self.quiet(f, target, spec, True))
        self.assertEqual(self.read_json(target), {"mcpServers": {}})

    def test_shared_claude_bad_container(self):
        spec = {"command": "/opt/cm", "args": []}
        target = self.write(self.home / ".claude.json", {"mcpServers": None})
        self.assertTrue(self.quiet(mod.merge_shared_claude_context_mode, target, spec, False))
        self.assertEqual(self.read_json(target)["mcpServers"]["context-mode"], spec)

    def test_cli_allowlist(self):
        target = self.home / ".cursor" / "cli-config.json"
        self.assertEqual(self.quiet(mod.merge_cli_allowlist, target, ["a", "b", "a"], False), 2)
        data = self.read_json(target)
        self.assertEqual(data, {"version": 1, "permissions": {"allow": ["a", "b"], "deny": []}})
        self.assertEqual(self.quiet(mod.merge_cli_allowlist, target, ["a", "c"], False), 1)
        self.assertEqual(self.read_json(target)["permissions"]["allow"], ["a", "b", "c"])
        self.write(target, {"permissions": {"deny": ["z"]}})
        self.assertEqual(self.quiet(mod.merge_cli_allowlist, target, ["a"], False), 1)
        data = self.read_json(target)
        self.assertEqual((data["version"], data["permissions"]), (1, {"deny": ["z"], "allow": ["a"]}))
        self.assertEqual(self.quiet(mod.merge_cli_allowlist, target, ["q"], True), 1)
        self.assertEqual(self.read_json(target)["permissions"]["allow"], ["a"])

    def test_cli_allowlist_bad_shapes_are_repaired(self):
        target = self.write(self.home / "c.json", {"permissions": {"allow": "oops"}})
        self.assertEqual(self.quiet(mod.merge_cli_allowlist, target, ["a"], False), 1)
        self.assertEqual(self.read_json(target)["permissions"]["allow"], ["a"])
        target = self.write(self.home / "c2.json", {"permissions": []})
        self.assertEqual(self.quiet(mod.merge_cli_allowlist, target, ["a"], False), 1)
        self.assertEqual(self.read_json(target)["permissions"]["allow"], ["a"])


class FileCopyTest(Base):
    def test_copy_file(self):
        src = self.write(self.tmp / "src.txt", "one")
        dest = self.tmp / "d" / "dest.txt"
        self.assertFalse(mod.copy_file(self.tmp / "nope", dest, False))
        self.assertTrue(self.quiet(mod.copy_file, src, dest, True))
        self.assertEqual(self.out, f"DRY-RUN: would copy {src} -> {dest}\n")
        self.assertFalse(dest.exists())
        self.assertTrue(mod.copy_file(src, dest, False))
        self.assertEqual(dest.read_text(), "one")
        src.write_text("two")
        self.assertTrue(mod.copy_file(src, dest, False))
        self.assertEqual((dest.read_text(), dest.with_suffix(".txt.bak").read_text()), ("two", "one"))

    def test_same_file_is_not_copied(self):
        src = self.write(self.tmp / "src.txt", "one")
        self.assertFalse(mod.copy_file(src, src, False))
        link = self.tmp / "link.txt"
        link.symlink_to(src)
        self.assertFalse(mod.copy_file(src, link, False))
        self.assertFalse(link.with_suffix(".txt.bak").exists())

    def test_resolve_oserror_falls_through_to_copy(self):
        src = self.write(self.tmp / "src.txt", "one")
        dest = self.tmp / "dest.txt"
        with mock.patch.object(Path, "resolve", side_effect=OSError("loop")):
            self.assertTrue(mod.copy_file(src, dest, False))
        self.assertEqual(dest.read_text(), "one")

    def test_stage_agents_template(self):
        f = mod.stage_agents_template
        src = self.write(self.tmp / "tpl.md", "template")
        dest = self.tmp / "host" / "AGENTS.md"
        self.assertEqual(f(self.tmp / "none.md", dest, False), "missing")
        self.assertEqual(self.quiet(f, src, dest, True), "installed")
        self.assertFalse(dest.exists())
        self.assertEqual(f(src, dest, False), "installed")
        self.assertEqual(dest.read_text(), "template")
        self.assertEqual(f(src, dest, False), "unchanged")
        dest.write_text("my rules")
        self.assertEqual(self.quiet(f, src, dest, False), "staged")
        self.assertEqual(dest.read_text(), "my rules")  # never overwritten
        staged = dest.with_name("AGENTS.md.context-mode-template")
        self.assertEqual(staged.read_text(), "template")
        self.assertIn("NOTICE: kept existing", self.err)
        staged.unlink()
        self.assertEqual(self.quiet(f, src, dest, True), "staged")
        self.assertFalse(staged.exists())
        self.assertIn("DRY-RUN: would stage", self.out)

    def test_append_unique_plugin(self):
        plugins = ["a"]
        self.assertFalse(mod.append_unique_plugin(plugins, "a"))
        self.assertTrue(mod.append_unique_plugin(plugins, "b"))
        self.assertEqual(plugins, ["a", "b"])

    def test_write_opencode_rtk_plugin(self):
        f = mod.write_opencode_rtk_plugin
        src = self.write(self.tmp / "rtk.ts", 'const c = "__SB_RTK_COMMAND__";\n')
        target = self.tmp / "o" / "plugins" / "rtk.ts"
        self.assertFalse(f(self.tmp / "none.ts", target, "/x/rtk", False))
        self.assertTrue(self.quiet(f, src, target, "/x/rtk", True))
        self.assertFalse(target.exists())
        self.assertTrue(f(src, target, "/x/rtk", False))
        self.assertEqual(target.read_text(), 'const c = "/x/rtk";\n')
        self.assertFalse(f(src, target, "/x/rtk", False))
        self.assertTrue(f(src, target, "/y/rtk", False))
        self.assertEqual(target.read_text(), 'const c = "/y/rtk";\n')
        self.assertEqual(target.with_suffix(".ts.bak").read_text(), 'const c = "/x/rtk";\n')


class PackageRootTest(Base):
    def test_env_override(self):
        pkg = self.tmp / "envpkg"
        pkg.mkdir()
        os.environ["CONTEXT_MODE_PKG"] = str(pkg)
        self.assertEqual(mod.context_mode_pkg_root(), pkg)
        self.npm.assert_not_called()

    def test_env_not_a_dir_falls_through(self):
        os.environ["CONTEXT_MODE_PKG"] = str(self.tmp / "missing")
        self.assertIsNone(mod.context_mode_pkg_root())

    def test_cli_on_path_with_package_json(self):
        pkg = self.tmp / "node_modules" / "context-mode"
        pkg.mkdir(parents=True)
        (pkg / "package.json").write_text("{}")
        cli = pkg / "cli.js"
        cli.write_text("")
        mod.shutil.which.return_value = str(cli)
        self.assertEqual(mod.context_mode_pkg_root(), pkg)
        self.npm.assert_not_called()

    def test_cli_without_package_json_falls_to_npm_root(self):
        cli = self.write(self.tmp / "bin" / "context-mode", "")
        mod.shutil.which.return_value = str(cli)
        root = self.tmp / "npm-root"
        (root / "context-mode").mkdir(parents=True)
        self.npm.side_effect = None
        self.npm.return_value = f"{root}\n"
        self.assertEqual(mod.context_mode_pkg_root(), root / "context-mode")
        self.assertEqual(self.npm.call_args.args[0], ["npm", "root", "-g"])

    def test_npm_root_without_package_dir_or_failing(self):
        self.npm.side_effect = None
        self.npm.return_value = f"{self.tmp}\n"
        self.assertIsNone(mod.context_mode_pkg_root())
        self.npm.side_effect = subprocess.CalledProcessError(1, "npm")
        self.assertIsNone(mod.context_mode_pkg_root())
        self.npm.side_effect = FileNotFoundError("npm")
        self.assertIsNone(mod.context_mode_pkg_root())

    def test_cursor_hooks_path(self):
        repo = self.tmp / "repo"
        self.assertIsNone(mod.context_mode_cursor_hooks_path(repo))
        bundled = self.write(repo / "scripts" / "lib" / "context-mode-cursor-hooks.json", {})
        self.assertEqual(mod.context_mode_cursor_hooks_path(repo), bundled)
        pkg = self.make_pkg()
        self.assertEqual(mod.context_mode_cursor_hooks_path(repo), bundled)  # pkg has no hooks.json
        cand = self.write(pkg / "configs" / "cursor" / "hooks.json", {})
        self.assertEqual(mod.context_mode_cursor_hooks_path(repo), cand)

    def test_extended_cursor_hooks(self):
        hooks = mod.context_mode_extended_cursor_hooks()["hooks"]
        self.assertEqual(hooks["sessionStart"][0]["matcher"], "startup|clear|compact")
        self.assertEqual(hooks["afterAgentResponse"][0]["command"],
                         "context-mode hook cursor afteragentresponse")


class CodexTomlTest(Base):
    def test_requires_package_and_snippet(self):
        target = self.home / ".codex" / "config.toml"
        self.assertFalse(mod.merge_codex_config_toml(target, False))
        pkg = self.make_pkg()
        self.assertFalse(mod.merge_codex_config_toml(target, False))  # no snippet file
        self.assertFalse(target.exists())
        self.write(pkg / "configs" / "codex" / "config.toml", "# snippet")
        self.assertTrue(mod.merge_codex_config_toml(target, False))
        self.assertEqual(target.read_text(), (
            '[mcp_servers.context-mode]\ncommand = "/opt/g/context-mode"\nargs = ["mcp"]\n'))
        self.assertFalse(target.with_suffix(".toml.bak").exists())

    def test_existing_marker_and_append(self):
        pkg = self.make_pkg()
        self.write(pkg / "configs" / "codex" / "config.toml", "# snippet")
        target = self.write(self.home / "config.toml", "[mcp_servers.context-mode]\ncommand='x'\n")
        self.assertFalse(mod.merge_codex_config_toml(target, False))
        target.write_text('model = "x"')
        self.assertTrue(mod.merge_codex_config_toml(target, False))
        text = target.read_text()
        self.assertTrue(text.startswith('model = "x"\n[mcp_servers.context-mode]\n'))
        self.assertEqual(target.with_suffix(".toml.bak").read_text(), 'model = "x"')
        target.write_text("")
        self.assertTrue(mod.merge_codex_config_toml(target, False))
        self.assertTrue(target.read_text().startswith("[mcp_servers.context-mode]"))

    def test_dry_run(self):
        pkg = self.make_pkg()
        self.write(pkg / "configs" / "codex" / "config.toml", "# snippet")
        target = self.home / "config.toml"
        self.assertTrue(self.quiet(mod.merge_codex_config_toml, target, True))
        self.assertIn("DRY-RUN: would append context-mode block", self.out)
        self.assertFalse(target.exists())


class HermesTest(Base):
    def test_create_append_and_skip(self):
        cfg = self.home / ".hermes" / "config.yaml"
        self.assertTrue(mod.merge_hermes_context_mode_mcp(cfg, False))
        text = cfg.read_text()
        self.assertTrue(text.startswith("plugins:\n  enabled: []\n\n# === rtk-cm context-mode MCP block ===\n"))
        self.assertFalse(mod.merge_hermes_context_mode_mcp(cfg, False))
        cfg.write_text("model: x\n")
        self.assertTrue(mod.merge_hermes_context_mode_mcp(cfg, False))
        self.assertTrue(cfg.read_text().startswith("model: x\n\n# === rtk-cm"))
        self.assertEqual(cfg.with_suffix(".yaml.bak").read_text(), "model: x\n")

    def test_skip_when_marker_or_server_present(self):
        cfg = self.home / "c.yaml"
        cfg.write_text("mcp_servers:\n  context-mode:\n    command: x\n")
        self.assertFalse(mod.merge_hermes_context_mode_mcp(cfg, False))
        cfg.write_text("# === rtk-cm context-mode MCP block ===\n")
        self.assertFalse(mod.merge_hermes_context_mode_mcp(cfg, False))

    def test_dry_run(self):
        cfg = self.home / "c.yaml"
        self.assertTrue(self.quiet(mod.merge_hermes_context_mode_mcp, cfg, True))
        self.assertIn("DRY-RUN: would append context-mode MCP", self.out)
        self.assertFalse(cfg.exists())


class OptimizeCursorTest(Base):
    def make_repo(self):
        repo = self.tmp / "repo"
        self.write(repo / "scripts" / "lib" / "cursor-cli-allowlist.json", {"allow": ["Shell(rtk)"]})
        self.write(repo / "templates" / "cursor" / "token-compression-enforcement.mdc", "tce")
        self.write(repo / ".cursor" / "rules" / "context-mode.mdc", "repo-cm")
        return repo

    def test_without_context_mode_package(self):
        repo = self.make_repo()
        res = self.quiet(mod.optimize_cursor, repo, False)
        self.assertEqual(res, {"host": "cursor", "status": "supported", "hooks_added": 2,
                               "mcp_added": False, "allow_added": 1, "rules_copied": 2})
        hooks = self.read_json(self.home / ".cursor" / "hooks.json")
        self.assertEqual(set(hooks["hooks"]), {"sessionStart", "afterAgentResponse"})
        self.assertEqual(self.read_json(self.home / ".cursor" / "cli-config.json")["permissions"]["allow"],
                         ["Shell(rtk)"])
        rules = self.home / ".cursor" / "rules"
        self.assertEqual((rules / "token-compression-enforcement.mdc").read_text(), "tce")
        self.assertEqual((rules / "context-mode.mdc").read_text(), "repo-cm")
        # project rule copied onto itself is skipped (same file)
        self.assertEqual((repo / ".cursor" / "rules" / "context-mode.mdc").read_text(), "repo-cm")
        self.assertFalse((self.home / ".cursor" / "mcp.json").exists())

    def test_with_package_hooks_mcp_and_rules(self):
        repo = self.make_repo()
        pkg = self.make_pkg()
        self.write(pkg / "configs" / "cursor" / "hooks.json", {"hooks": {"preToolUse": [
            {"command": "context-mode hook cursor pretooluse"}]}})
        self.write(pkg / "configs" / "cursor" / "mcp.json", {"mcpServers": {
            "context-mode": {"command": "npx", "args": ["x"]},
            "user-context-mode": {"command": "npx"},
            "extra": {"command": "extra"}}})
        self.write(pkg / "configs" / "cursor" / "context-mode.mdc", "pkg-cm")
        res = self.quiet(mod.optimize_cursor, repo, False)
        self.assertTrue(res["mcp_added"])
        servers = self.read_json(self.home / ".cursor" / "mcp.json")["mcpServers"]
        self.assertEqual(servers["context-mode"]["command"], "/opt/g/context-mode")
        self.assertEqual(servers["user-context-mode"]["command"], "/opt/g/context-mode")
        self.assertEqual(servers["extra"], {"command": "extra"})
        self.assertEqual((self.home / ".cursor" / "rules" / "context-mode.mdc").read_text(), "pkg-cm")
        self.assertEqual((repo / ".cursor" / "rules" / "context-mode.mdc").read_text(), "pkg-cm")
        self.assertEqual(res["hooks_added"], 3)
        again = self.quiet(mod.optimize_cursor, repo, False)
        self.assertEqual((again["hooks_added"], again["mcp_added"], again["allow_added"]), (0, False, 0))

    def test_package_without_mcp_json_or_with_bad_servers(self):
        repo = self.make_repo()
        pkg = self.make_pkg()
        res = self.quiet(mod.optimize_cursor, repo, False)
        self.assertFalse(res["mcp_added"])
        self.write(pkg / "configs" / "cursor" / "mcp.json", {"mcpServers": ["bad"]})
        res = self.quiet(mod.optimize_cursor, repo, False)
        self.assertFalse(res["mcp_added"])
        self.assertFalse((self.home / ".cursor" / "mcp.json").exists())

    def test_skip_cli_config_and_dry_run(self):
        repo = self.make_repo()
        res = self.quiet(mod.optimize_cursor, repo, True, True)
        self.assertEqual(res["allow_added"], 0)
        self.assertFalse((self.home / ".cursor").exists())
        self.assertIn("DRY-RUN", self.out)

    def test_missing_allowlist_file_means_no_entries(self):
        repo = self.tmp / "emptyrepo"
        repo.mkdir()
        res = self.quiet(mod.optimize_cursor, repo, False)
        self.assertEqual((res["allow_added"], res["rules_copied"]), (0, 0))


class OptimizeCodexClaudeTest(Base):
    def test_codex_without_package(self):
        res = self.quiet(mod.optimize_codex, False)
        self.assertEqual(res, {"host": "codex", "status": "supported", "hooks_added": 0,
                               "config_merged": False, "agents_copied": False,
                               "agents_template": "missing"})

    def test_codex_with_package(self):
        pkg = self.make_pkg()
        self.write(pkg / "configs" / "codex" / "hooks.json", TestCodexFrag.FRAG)
        self.write(pkg / "configs" / "codex" / "AGENTS.md", "agents")
        self.write(pkg / "configs" / "codex" / "config.toml", "# s")
        custom = self.tmp / "codex-home"
        os.environ["CODEX_HOME"] = str(custom)
        res = self.quiet(mod.optimize_codex, False)
        self.assertEqual((res["hooks_added"], res["config_merged"], res["agents_copied"],
                          res["agents_template"]), (1, True, True, "installed"))
        self.assertEqual((custom / "AGENTS.md").read_text(), "agents")
        self.assertIn("mcp_servers.context-mode", (custom / "config.toml").read_text())
        (custom / "AGENTS.md").write_text("mine")
        res = self.quiet(mod.optimize_codex, False)
        self.assertEqual((res["agents_copied"], res["agents_template"], res["hooks_added"],
                          res["config_merged"]), (False, "staged", 0, False))

    def test_codex_package_without_hooks_file(self):
        self.make_pkg()
        res = self.quiet(mod.optimize_codex, True)
        self.assertEqual((res["hooks_added"], res["agents_template"]), (0, "missing"))

    def test_claude(self):
        res = self.quiet(mod.optimize_claude, False)
        self.assertEqual(res, {"host": "claude", "status": "supported", "adapter": "manifest_mcp",
                               "mcp_added": True, "native_plugin_disabled": False})
        self.disable.assert_called_once_with(dry_run=False)
        cm = self.read_json(self.home / ".claude.json")["mcpServers"]["context-mode"]
        self.assertEqual(cm["command"], "/opt/g/context-mode")
        self.disable.return_value = True
        res = self.quiet(mod.optimize_claude, True)
        self.assertEqual((res["mcp_added"], res["native_plugin_disabled"]), (False, True))


class TestCodexFrag:
    FRAG = {"hooks": {"SessionStart": [{"matcher": "", "hooks": [
        {"type": "command", "command": "context-mode hook codex sessionstart"}]}]}}


class OptimizeOpenCodeTest(Base):
    def make_repo(self):
        repo = self.tmp / "repo"
        self.write(repo / "scripts" / "lib" / "global-toolstack" / "opencode-rtk-plugin.ts",
                   'run("__SB_RTK_COMMAND__")\n')
        return repo

    def cfg(self):
        return self.home / ".config" / "opencode" / "opencode.json"

    def test_fresh_install(self):
        repo = self.make_repo()
        res = self.quiet(mod.optimize_opencode, False, repo)
        self.assertEqual((res["plugin_added"], res["plugin_written"], res["mcp_added"]),
                         (True, True, False))
        data = self.read_json(self.cfg())
        self.assertEqual(data["plugin"], ["context-mode", "./plugins/rtk.ts"])
        self.assertEqual(data["$schema"], "https://opencode.ai/config.json")
        self.assertEqual(data["mcp"], {})
        self.assertEqual((self.cfg().parent / "plugins" / "rtk.ts").read_text(), 'run("/opt/g/rtk")\n')
        again = self.quiet(mod.optimize_opencode, False, repo)
        self.assertEqual((again["plugin_added"], again["plugin_written"], again["mcp_added"]),
                         (False, False, False))

    def test_stale_stack_entries_are_repaired(self):
        repo = self.make_repo()
        self.write(self.cfg(), {"plugin": ["context-mode"], "mcp": {
            "context-mode": {"command": ["npx", "x"]},
            "user-context-mode": {},
            "graphify": {"type": "local", "command": ["npx", "graphify"], "enabled": True},
            "user-agentmemory": {"type": "local", "command": ["npx", "am"], "enabled": True},
            "lean-ctx": {"type": "local", "command": ["lean-ctx"], "enabled": True}}})
        res = self.quiet(mod.optimize_opencode, False, repo)
        self.assertTrue(res["mcp_added"])
        mcp = self.read_json(self.cfg())["mcp"]
        self.assertEqual(set(mcp), {"graphify", "agentmemory", "leanctx"})
        self.assertEqual(mcp["graphify"]["command"], ["/opt/g/graphify", "serve"])
        self.assertEqual(mcp["agentmemory"]["command"], ["/opt/g/agentmemory", "mcp"])
        self.assertEqual(mcp["leanctx"]["environment"], mod.LEANCTX_ENV_CM_ACTIVE)

    def test_leanctx_without_context_mode_uses_base_env(self):
        repo = self.make_repo()
        self.write(self.cfg(), {"plugin": [], "mcp": {
            "leanctx": {"type": "local", "command": ["x"], "enabled": True}}})
        self.quiet(mod.optimize_opencode, False, repo, rtk_only=False, context_mode_only=False)
        data = self.read_json(self.cfg())
        # plugin got added, so context mode is plugin-owned and the env is the CM-active one
        self.assertEqual(data["mcp"]["leanctx"]["environment"], mod.LEANCTX_ENV_CM_ACTIVE)
        self.write(self.cfg(), {"plugin": [], "mcp": {
            "leanctx": {"type": "local", "command": ["x"], "enabled": True}}})
        self.quiet(mod.optimize_opencode, False, repo, rtk_only=True)
        data = self.read_json(self.cfg())
        self.assertEqual(data["mcp"]["leanctx"]["command"], ["x"])  # rtk-only: untouched
        self.write(self.cfg(), {"plugin": ["./plugins/rtk.ts"], "mcp": {
            "leanctx": {"type": "local", "command": ["x"], "enabled": True}}})
        res = self.quiet(mod.optimize_opencode, False, repo, rtk_only=True)
        self.assertEqual(res["mcp_added"], False)

    def test_base_env_when_context_mode_absent(self):
        repo = self.make_repo()
        self.write(self.cfg(), {"plugin": [], "mcp": {
            "leanctx": {"type": "local", "command": ["x"], "enabled": True}}})
        with mock.patch.object(mod, "opencode_ensure_context_mode_plugin", return_value=False):
            self.quiet(mod.optimize_opencode, False, repo)
        data = self.read_json(self.cfg())
        self.assertEqual(data["mcp"]["leanctx"]["environment"], mod.LEANCTX_ENV_BASE)

    def test_context_mode_only_and_rtk_only(self):
        repo = self.make_repo()
        res = self.quiet(mod.optimize_opencode, False, repo, context_mode_only=True)
        self.assertEqual((res["plugin_added"], res["plugin_written"]), (True, False))
        self.assertEqual(self.read_json(self.cfg())["plugin"], ["context-mode"])
        self.assertFalse((self.cfg().parent / "plugins" / "rtk.ts").exists())
        self.cfg().unlink()
        res = self.quiet(mod.optimize_opencode, False, repo, rtk_only=True)
        self.assertEqual(self.read_json(self.cfg())["plugin"], ["./plugins/rtk.ts"])
        self.assertTrue(res["plugin_written"])

    def test_bad_plugin_and_mcp_containers_are_replaced(self):
        repo = self.make_repo()
        self.write(self.cfg(), {"plugin": "x", "mcp": ["y"]})
        res = self.quiet(mod.optimize_opencode, False, repo)
        data = self.read_json(self.cfg())
        self.assertEqual(data["plugin"], ["context-mode", "./plugins/rtk.ts"])
        self.assertEqual(data["mcp"], {})
        self.assertTrue(res["plugin_added"])

    def test_dry_run_writes_nothing(self):
        repo = self.make_repo()
        res = self.quiet(mod.optimize_opencode, True, repo)
        self.assertTrue(res["plugin_added"])
        self.assertFalse(self.cfg().exists())
        self.assertIn("DRY-RUN", self.out)

    def test_agents_template(self):
        repo = self.make_repo()
        pkg = self.make_pkg()
        self.write(pkg / "configs" / "opencode" / "AGENTS.md", "oc agents")
        res = self.quiet(mod.optimize_opencode, False, repo)
        self.assertEqual((res["agents_copied"], res["agents_template"]), (True, "installed"))
        self.assertEqual((self.cfg().parent / "AGENTS.md").read_text(), "oc agents")
        res = self.quiet(mod.optimize_opencode, False, repo)
        self.assertEqual((res["agents_copied"], res["agents_template"]), (False, "unchanged"))

    def test_missing_rtk_plugin_source_and_existing_config_untouched(self):
        repo = self.tmp / "norepo"
        repo.mkdir()
        self.write(self.cfg(), {"plugin": ["context-mode", "./plugins/rtk.ts"], "mcp": {}})
        before = self.cfg().read_bytes()
        res = self.quiet(mod.optimize_opencode, False, repo)
        self.assertEqual((res["plugin_added"], res["plugin_written"], res["mcp_added"]),
                         (False, False, False))
        self.assertEqual(self.cfg().read_bytes(), before)  # nothing changed, nothing rewritten


class OtherHostsAndMainTest(Base):
    def test_hermes_and_goose(self):
        res = self.quiet(mod.optimize_hermes, False)
        self.assertEqual((res["host"], res["status"], res["mcp_merged"]), ("hermes", "partial", True))
        self.assertEqual(mod.optimize_goose(), {
            "host": "goose", "status": "unsupported", "skipped": True,
            "reason": "Neither RTK nor Context Mode ship Goose integrations upstream"})

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "argv", ["merge-token-compression-config.py", *argv]), \
             contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = mod.main()
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    def test_main_default_is_cursor(self):
        repo = self.tmp / "repo"
        repo.mkdir()
        code, out, _ = self.run_main("--repo-root", str(repo), "--skip-cli-config")
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["status"], "ok")
        self.assertEqual([r["host"] for r in data["results"]], ["cursor"])

    def test_main_each_host_and_all(self):
        repo = self.tmp / "repo"
        repo.mkdir()
        for host in ("codex", "claude", "opencode", "hermes", "goose"):
            code, out, _ = self.run_main("--host", host, "--repo-root", str(repo), "--dry-run")
            self.assertEqual(code, 0, host)
            self.assertEqual(json.loads(out[out.index('{\n  "status"'):])["results"][0]["host"], host)
        code, out, _ = self.run_main("--host", "all", "--repo-root", str(repo), "--dry-run",
                                     "--rtk-only")
        self.assertEqual([r["host"] for r in json.loads(out[out.index('{\n  "status"'):])["results"]],
                         ["cursor", "codex", "claude", "opencode", "hermes", "goose"])

    def test_main_flags_reach_opencode(self):
        repo = self.tmp / "repo"
        repo.mkdir()
        with mock.patch.object(mod, "optimize_opencode", return_value={"host": "opencode"}) as oc:
            self.run_main("--host", "opencode", "--repo-root", str(repo), "--context-mode-only")
        oc.assert_called_once_with(False, repo, rtk_only=False, context_mode_only=True)

    def test_main_mutually_exclusive_flags(self):
        code, _, err = self.run_main("--rtk-only", "--context-mode-only")
        self.assertEqual(code, 2)
        self.assertIn("mutually exclusive", err)

    def test_dunder_main(self):
        repo = self.tmp / "repo"
        repo.mkdir()
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["x", "--host", "goose"]), \
             contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / REL), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertIn('"unsupported"', out.getvalue())


if __name__ == "__main__":
    unittest.main()

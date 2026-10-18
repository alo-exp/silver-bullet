"""Unit tests for scripts/lib/merge-leanctx-mcp-config.py (temp HOME only, no real manifest)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

try:
    import tomllib
except ImportError:  # pragma: no cover - python < 3.11
    tomllib = None

REL = "scripts/lib/merge-leanctx-mcp-config.py"
mod = load_module(REL)

MANIFEST = {
    "tools": {
        "leanctx": {"command": "/opt/g/lean-ctx", "args": ["mcp"], "env": {"FROM_MANIFEST": "1"}},
        "context_mode": {"command": "/opt/g/context-mode", "args": ["serve"], "env": {}},
    }
}
PREFIX = {"LEANCTX_MCP_TOOL_PREFIX": "lctx_"}
CM_ENV_KEYS = {"LEAN_CTX_DISABLED_TOOLS", "LEANCTX_DISABLE_SHELL_MCP", "LEANCTX_DISABLE_SANDBOX_MCP",
               "LEANCTX_DISABLE_FETCH_MCP", "LEANCTX_DISABLE_FTS", "LEANCTX_PRIMARY_FTS"}


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name).resolve()
        self.home = self.tmp / "home"
        self.home.mkdir()
        env = {k: v for k, v in os.environ.items() if k != "CODEX_HOME"}
        env["HOME"] = str(self.home)
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def quiet(self, fn, *a, **kw):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            result = fn(*a, **kw)
        self.last_out = out.getvalue()
        return result

    def write(self, path, data):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data if isinstance(data, str) else json.dumps(data))
        return path

    def read_json(self, path):
        return json.loads(Path(path).read_text())


class JsonIoTest(Base):
    def test_load_json_variants(self):
        self.assertEqual(mod.load_json(self.tmp / "none.json"), {})
        self.assertEqual(mod.load_json(self.tmp / "none.json", {"d": 1}), {"d": 1})
        self.assertEqual(mod.load_json(self.write(self.tmp / "a.json", {"k": 1})), {"k": 1})
        with self.assertRaises(json.JSONDecodeError):
            mod.load_json(self.write(self.tmp / "bad.json", "{x"))

    def test_load_json_rejects_non_object_top_level(self):
        path = self.write(self.tmp / "list.json", "[1]")
        with self.assertRaisesRegex(ValueError, "expected a JSON object"):
            mod.load_json(path)

    def test_save_json_writes_backup_and_creates_parents(self):
        target = self.tmp / "deep" / "dir" / "x.json"
        mod.save_json(target, {"a": 1}, dry_run=False)
        self.assertEqual(target.read_text(), '{\n  "a": 1\n}\n')
        self.assertFalse(target.with_suffix(".json.bak").exists())
        mod.save_json(target, {"a": 2}, dry_run=False)
        self.assertEqual(self.read_json(target.with_suffix(".json.bak")), {"a": 1})
        self.assertEqual(self.read_json(target), {"a": 2})

    def test_save_json_dry_run(self):
        target = self.tmp / "x.json"
        self.quiet(mod.save_json, target, {"a": 1}, True)
        self.assertEqual(self.last_out, f"DRY-RUN: would write {target}\n")
        self.assertFalse(target.exists())


class PresenceTest(Base):
    def test_cursor_and_claude(self):
        p = self.tmp / "m.json"
        self.assertFalse(mod.context_mode_present_cursor(p))
        self.write(p, {"mcpServers": {"context-mode": {}}})
        self.assertTrue(mod.context_mode_present_cursor(p))
        self.write(p, {"mcpServers": {"user-context-mode": {}}})
        self.assertFalse(mod.context_mode_present_cursor(p))
        self.assertTrue(mod.context_mode_present_claude(p))
        self.write(p, {"mcpServers": {"other": {}}})
        self.assertFalse(mod.context_mode_present_claude(p))
        self.write(p, {"mcpServers": None})
        self.assertFalse(mod.context_mode_present_cursor(p))
        self.assertFalse(mod.context_mode_present_claude(p))
        self.write(p, {"mcpServers": ["context-mode"]})
        self.assertFalse(mod.context_mode_present_cursor(p))

    def test_opencode(self):
        p = self.tmp / "o.json"
        self.assertFalse(mod.context_mode_present_opencode(p))
        self.write(p, {"plugin": ["context-mode@1.2"]})
        self.assertTrue(mod.context_mode_present_opencode(p))
        self.write(p, {"mcp": {"context-mode": {}}})
        self.assertTrue(mod.context_mode_present_opencode(p))
        self.write(p, {"mcp": {"user-context-mode": {}}})
        self.assertTrue(mod.context_mode_present_opencode(p))
        self.write(p, {"mcp": {"x": {}}})
        self.assertFalse(mod.context_mode_present_opencode(p))
        self.write(p, {"mcp": None})
        self.assertFalse(mod.context_mode_present_opencode(p))

    def test_codex(self):
        p = self.tmp / "c.toml"
        self.assertFalse(mod.context_mode_present_codex(p))
        p.write_text("[mcp_servers.other]\n")
        self.assertFalse(mod.context_mode_present_codex(p))
        p.write_text("[mcp_servers.context-mode]\ncommand = 'x'\n")
        self.assertTrue(mod.context_mode_present_codex(p))


class EnvTest(Base):
    def test_leanctx_server_env(self):
        self.assertEqual(mod.leanctx_server_env(False), PREFIX)
        env = mod.leanctx_server_env(True)
        self.assertEqual(set(env) - set(PREFIX), CM_ENV_KEYS)
        self.assertEqual(env["LEAN_CTX_DISABLED_TOOLS"], ",".join(mod.LEANCTX_ROUTED_DISABLED_TOOLS))
        self.assertEqual(env["LEANCTX_PRIMARY_FTS"], "context_mode")

    def test_cursor_server_spec(self):
        plain = mod.leanctx_cursor_server(False, MANIFEST)
        self.assertEqual((plain["command"], plain["args"], plain["env"]),
                         ("/opt/g/lean-ctx", ["mcp"], PREFIX))
        self.assertNotIn("disabledTools", plain)
        cm = mod.leanctx_cursor_server(True, MANIFEST)
        self.assertEqual(cm["disabledTools"], mod.CM_OVERLAP_TOOLS)
        self.assertIsNot(cm["disabledTools"], mod.CM_OVERLAP_TOOLS)
        # manifest env is replaced, and the manifest itself is not mutated
        self.assertEqual(MANIFEST["tools"]["leanctx"]["env"], {"FROM_MANIFEST": "1"})

    def test_remove_upstream_duplicate(self):
        servers = {"lean-ctx": {}, "other": {}}
        self.assertTrue(mod.remove_upstream_lean_ctx_duplicate(servers))
        self.assertEqual(servers, {"other": {}})
        self.assertFalse(mod.remove_upstream_lean_ctx_duplicate(servers))


class CursorMergeTest(Base):
    def target(self):
        return self.home / ".cursor" / "mcp.json"

    def merge(self, dry_run=False):
        return self.quiet(mod.merge_cursor_mcp, self.target(), dry_run, MANIFEST)

    def test_creates_new_file(self):
        res = self.merge()
        self.assertEqual(res, {"host": "cursor", "mcp_merged": True, "cm_active": False})
        servers = self.read_json(self.target())["mcpServers"]
        self.assertEqual(list(servers), ["leanctx"])
        lean = servers["leanctx"]
        self.assertEqual((lean["command"], lean["args"], lean["env"]),
                         ("/opt/g/lean-ctx", ["mcp"], PREFIX))
        self.assertNotIn("disabledTools", lean)
        self.assertFalse(self.target().with_suffix(".json.bak").exists())

    def test_idempotent(self):
        self.merge()
        first = self.target().read_bytes()
        res = self.merge()
        self.assertEqual(res["mcp_merged"], False)
        self.assertEqual(self.target().read_bytes(), first)
        self.assertFalse(self.target().with_suffix(".json.bak").exists())

    def test_context_mode_active_adds_disabled_tools_and_env(self):
        self.write(self.target(), {"mcpServers": {"context-mode": {"command": "cm"}}})
        res = self.merge()
        self.assertTrue(res["cm_active"])
        lean = self.read_json(self.target())["mcpServers"]["leanctx"]
        self.assertEqual(lean["disabledTools"], mod.CM_OVERLAP_TOOLS)
        self.assertEqual(set(lean["env"]), set(PREFIX) | CM_ENV_KEYS)
        self.assertEqual(self.merge()["mcp_merged"], False)

    def test_existing_entry_updated_preserving_foreign_settings(self):
        self.write(self.target(), {"mcpServers": {
            "lean-ctx": {"command": "dup"},
            "context-mode": {},
            "leanctx": {"command": "old", "args": ["x"], "env": {"MINE": "1", "LEANCTX_MCP_TOOL_PREFIX": "bad"},
                        "disabledTools": ["custom", "ctx_search"], "extra": True}}})
        res = self.merge()
        self.assertTrue(res["mcp_merged"])
        servers = self.read_json(self.target())["mcpServers"]
        self.assertNotIn("lean-ctx", servers)
        lean = servers["leanctx"]
        self.assertEqual((lean["command"], lean["args"], lean["extra"]), ("/opt/g/lean-ctx", ["mcp"], True))
        self.assertEqual(lean["env"]["MINE"], "1")
        self.assertEqual(lean["env"]["LEANCTX_MCP_TOOL_PREFIX"], "lctx_")
        self.assertEqual(lean["disabledTools"][:2], ["custom", "ctx_search"])
        self.assertEqual(sorted(lean["disabledTools"]), sorted({"custom", *mod.CM_OVERLAP_TOOLS}))
        self.assertEqual(self.read_json(self.target().with_suffix(".json.bak"))["mcpServers"]["leanctx"]["command"], "old")

    def test_only_disabled_tools_missing_triggers_write(self):
        spec = mod.leanctx_cursor_server(True, MANIFEST)
        spec["disabledTools"] = ["ctx_search"]
        self.write(self.target(), {"mcpServers": {"context-mode": {}, "leanctx": spec}})
        self.assertTrue(self.merge()["mcp_merged"])
        lean = self.read_json(self.target())["mcpServers"]["leanctx"]
        self.assertEqual(sorted(lean["disabledTools"]), sorted(mod.CM_OVERLAP_TOOLS))

    def test_dry_run_leaves_file_alone(self):
        original = {"mcpServers": {"lean-ctx": {}}}
        self.write(self.target(), original)
        res = self.merge(dry_run=True)
        self.assertTrue(res["mcp_merged"])
        self.assertEqual(self.last_out, f"DRY-RUN: would write {self.target()}\n")
        self.assertEqual(self.read_json(self.target()), original)

    def test_removing_duplicate_alone_is_a_change(self):
        spec = mod.leanctx_cursor_server(False, MANIFEST)
        self.write(self.target(), {"mcpServers": {"lean-ctx": {}, "leanctx": spec}})
        self.assertTrue(self.merge()["mcp_merged"])
        self.assertEqual(list(self.read_json(self.target())["mcpServers"]), ["leanctx"])

    def test_malformed_or_non_object_file_raises_and_is_untouched(self):
        self.write(self.target(), "{broken")
        with self.assertRaises(json.JSONDecodeError):
            self.merge()
        self.assertEqual(self.target().read_text(), "{broken")
        self.write(self.target(), "[1]")
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.target().read_text(), "[1]")
        self.assertFalse(self.target().with_suffix(".json.bak").exists())

    def test_non_dict_entries_are_replaced_not_crashes(self):
        for bad in ("string", ["list"], None, 5):
            self.write(self.target(), {"mcpServers": {"leanctx": bad, "keep": {"command": "k"}}})
            self.assertTrue(self.merge()["mcp_merged"], bad)
            servers = self.read_json(self.target())["mcpServers"]
            self.assertEqual(servers["leanctx"]["command"], "/opt/g/lean-ctx", bad)
            self.assertEqual(servers["keep"], {"command": "k"})

    def test_non_dict_env_and_disabled_tools_are_repaired(self):
        self.write(self.target(), {"mcpServers": {"context-mode": {}, "leanctx": {
            "command": "/opt/g/lean-ctx", "args": ["mcp"], "env": ["bad"], "disabledTools": "ctx_search"}}})
        self.merge()
        lean = self.read_json(self.target())["mcpServers"]["leanctx"]
        self.assertEqual(lean["env"]["LEANCTX_MCP_TOOL_PREFIX"], "lctx_")
        self.assertEqual(sorted(lean["disabledTools"]), sorted(mod.CM_OVERLAP_TOOLS))

    def test_non_dict_mcp_servers_container_is_replaced(self):
        for bad in (None, [], "x"):
            self.write(self.target(), {"mcpServers": bad, "other": 1})
            self.assertTrue(self.merge()["mcp_merged"], bad)
            data = self.read_json(self.target())
            self.assertEqual(data["other"], 1)
            self.assertEqual(data["mcpServers"]["leanctx"]["command"], "/opt/g/lean-ctx")

    def test_symlinked_target_is_written_through(self):
        real = self.write(self.tmp / "real.json", {"mcpServers": {}, "keep": 1})
        self.target().parent.mkdir(parents=True)
        self.target().symlink_to(real)
        self.merge()
        self.assertTrue(self.target().is_symlink())
        data = self.read_json(real)
        self.assertEqual(data["keep"], 1)
        self.assertIn("leanctx", data["mcpServers"])


class ClaudeMergeTest(Base):
    def target(self):
        return self.home / ".claude.json"

    def merge(self, dry_run=False):
        return self.quiet(mod.merge_claude_mcp, self.target(), dry_run, MANIFEST)

    def test_create_idempotent_and_replace(self):
        res = self.merge()
        self.assertEqual(res, {"host": "claude", "mcp_merged": True, "cm_active": False})
        self.assertEqual(self.read_json(self.target())["mcpServers"]["leanctx"]["env"], PREFIX)
        first = self.target().read_bytes()
        self.assertFalse(self.merge()["mcp_merged"])
        self.assertEqual(self.target().read_bytes(), first)

    def test_context_mode_aliases_and_duplicate(self):
        self.write(self.target(), {"projects": {"p": 1}, "mcpServers": {
            "user-context-mode": {}, "lean-ctx": {}, "leanctx": {"command": "stale", "mine": 1}}})
        res = self.merge()
        self.assertTrue(res["cm_active"])
        data = self.read_json(self.target())
        self.assertEqual(data["projects"], {"p": 1})
        self.assertEqual(set(data["mcpServers"]), {"user-context-mode", "leanctx"})
        lean = data["mcpServers"]["leanctx"]
        self.assertEqual(lean, mod.leanctx_cursor_server(True, MANIFEST))  # replaced wholesale
        self.assertTrue(self.target().with_suffix(".json.bak").is_file())

    def test_dry_run_and_bad_container(self):
        self.write(self.target(), {"mcpServers": "oops"})
        res = self.merge(dry_run=True)
        self.assertTrue(res["mcp_merged"])
        self.assertEqual(self.read_json(self.target()), {"mcpServers": "oops"})
        self.merge()
        self.assertEqual(self.read_json(self.target())["mcpServers"]["leanctx"]["command"], "/opt/g/lean-ctx")


class StripCollisionTest(Base):
    def test_cases(self):
        p = self.tmp / "m.json"
        self.assertFalse(mod.strip_unprefixed_leanctx_collision(p, False))
        self.write(p, {"mcpServers": {"leanctx": "str"}})
        self.assertFalse(mod.strip_unprefixed_leanctx_collision(p, False))
        self.write(p, {"mcpServers": {}})
        self.assertFalse(mod.strip_unprefixed_leanctx_collision(p, False))
        self.write(p, {"mcpServers": {"leanctx": {"disabledTools": "not-a-list"}}})
        self.assertTrue(mod.strip_unprefixed_leanctx_collision(p, False))
        self.assertEqual(self.read_json(p)["mcpServers"]["leanctx"]["disabledTools"], mod.CM_OVERLAP_TOOLS)
        before = p.read_bytes()
        self.assertFalse(mod.strip_unprefixed_leanctx_collision(p, False))
        self.assertEqual(p.read_bytes(), before)
        self.write(p, {"mcpServers": {"leanctx": {"disabledTools": ["mine"]}}})
        self.assertTrue(mod.strip_unprefixed_leanctx_collision(p, False))
        self.assertEqual(self.read_json(p)["mcpServers"]["leanctx"]["disabledTools"][0], "mine")
        self.write(p, {"mcpServers": {"leanctx": {}}})
        self.assertTrue(self.quiet(mod.strip_unprefixed_leanctx_collision, p, True))
        self.assertEqual(self.read_json(p), {"mcpServers": {"leanctx": {}}})
        self.assertIn("DRY-RUN", self.last_out)


class OpenCodeMergeTest(Base):
    def target(self):
        return self.home / ".config" / "opencode" / "opencode.json"

    def merge(self, dry_run=False):
        return self.quiet(mod.merge_opencode_mcp, self.target(), dry_run, MANIFEST)

    def test_creates_scaffold(self):
        res = self.merge()
        self.assertEqual(res, {"host": "opencode", "mcp_merged": True, "cm_active": False})
        data = self.read_json(self.target())
        self.assertEqual(data["$schema"], "https://opencode.ai/config.json")
        self.assertEqual(data["plugin"], [])
        self.assertEqual(data["mcp"]["leanctx"], {
            "type": "local", "command": ["/opt/g/lean-ctx", "mcp"], "enabled": True,
            "environment": PREFIX})
        first = self.target().read_bytes()
        self.assertFalse(self.merge()["mcp_merged"])
        self.assertEqual(self.target().read_bytes(), first)

    def test_fills_missing_schema_and_replaces_bad_mcp(self):
        self.write(self.target(), {"mcp": ["bad"], "theme": "x"})
        self.merge()
        data = self.read_json(self.target())
        self.assertEqual(data["$schema"], "https://opencode.ai/config.json")
        self.assertEqual(data["theme"], "x")
        self.assertIn("leanctx", data["mcp"])

    def test_plugin_owned_context_mode(self):
        self.write(self.target(), {"plugin": ["context-mode@0.1", "other"], "mcp": {
            "context-mode": {"command": ["cm"]}, "user-context-mode": {}, "lean-ctx": {}}})
        res = self.merge()
        self.assertTrue(res["cm_active"])
        data = self.read_json(self.target())
        self.assertEqual(data["plugin"], ["context-mode", "other"])
        self.assertEqual(set(data["mcp"]), {"leanctx"})
        self.assertEqual(set(data["mcp"]["leanctx"]["environment"]), set(PREFIX) | CM_ENV_KEYS)
        self.assertFalse(self.merge()["mcp_merged"])

    def test_mcp_only_context_mode_is_canonicalized(self):
        self.write(self.target(), {"mcp": {"user-context-mode": {"command": ["old"]}}})
        res = self.merge()
        self.assertTrue(res["cm_active"])
        mcp = self.read_json(self.target())["mcp"]
        self.assertEqual(set(mcp), {"context-mode", "leanctx"})
        self.assertEqual(mcp["context-mode"]["command"], ["/opt/g/context-mode", "serve"])

    def test_plugin_not_a_list_is_ignored(self):
        self.write(self.target(), {"plugin": "context-mode", "mcp": {}})
        res = self.merge()
        self.assertFalse(res["cm_active"])

    def test_dry_run(self):
        self.write(self.target(), {"mcp": {}})
        res = self.merge(dry_run=True)
        self.assertTrue(res["mcp_merged"])
        self.assertEqual(self.last_out, f"DRY-RUN: would write {self.target()}\n")
        self.assertEqual(self.read_json(self.target()), {"mcp": {}})


class CodexTomlTest(Base):
    def target(self):
        return self.home / ".codex" / "config.toml"

    def merge(self, dry_run=False, path=None):
        return self.quiet(mod.merge_codex_toml, path or self.target(), dry_run, MANIFEST)

    def parsed(self, path=None):
        text = (path or self.target()).read_text()
        if tomllib is None:
            return None
        return tomllib.loads(text)

    def test_bounds(self):
        text = "a = 1\n[one]\nx = 1\n[two]\ny = 2\n"
        start, end = mod.toml_section_bounds(text, "[one]")
        self.assertEqual(text[start:end], "[one]\nx = 1\n")
        start, end = mod.toml_section_bounds(text, "[two]")
        self.assertEqual(text[start:end], "[two]\ny = 2\n")
        self.assertIsNone(mod.toml_section_bounds(text, "[three]"))
        self.assertIsNone(mod.toml_section_bounds("[one] # c\n", "[one]"))
        self.assertIsNotNone(mod.toml_section_bounds("[one]   \nx=1\n", "[one]"))
        self.assertIsNone(mod.toml_section_bounds("[one]x\n", "[one]"))

    def test_creates_file(self):
        res = self.merge()
        self.assertEqual(res, {"host": "codex", "mcp_merged": True, "cm_active": False})
        self.assertEqual(self.target().read_text(), (
            '[mcp_servers.leanctx]\ncommand = "/opt/g/lean-ctx"\nargs = ["mcp"]\n\n'
            '[mcp_servers.leanctx.env]\nLEANCTX_MCP_TOOL_PREFIX = "lctx_"\n'))
        if tomllib:
            self.assertEqual(self.parsed()["mcp_servers"]["leanctx"]["command"], "/opt/g/lean-ctx")
        self.assertFalse(self.target().with_suffix(".toml.bak").exists())

    def test_idempotent(self):
        self.merge()
        first = self.target().read_text()
        res = self.merge()
        self.assertFalse(res["mcp_merged"])
        self.assertEqual(self.target().read_text(), first)

    def test_appends_to_existing_text_with_separation(self):
        self.write(self.target(), 'model = "x"')  # no trailing newline
        self.merge()
        text = self.target().read_text()
        self.assertTrue(text.startswith('model = "x"\n\n[mcp_servers.leanctx]\n'))
        self.assertEqual(self.target().with_suffix(".toml.bak").read_text(), 'model = "x"')
        if tomllib:
            self.assertEqual(self.parsed()["model"], "x")

    def test_context_mode_present(self):
        self.write(self.target(), "[mcp_servers.context-mode]\ncommand = \"cm\"\n")
        res = self.merge()
        self.assertTrue(res["cm_active"])
        text = self.target().read_text()
        self.assertIn("LEAN_CTX_DISABLED_TOOLS", text)
        if tomllib:
            env = self.parsed()["mcp_servers"]["leanctx"]["env"]
            self.assertEqual(env["LEANCTX_PRIMARY_FTS"], "context_mode")

    def test_removes_upstream_lean_ctx_sections_only(self):
        self.write(self.target(), (
            '[mcp_servers.lean-ctx]\ncommand = "dup"\n\n'
            '[mcp_servers.lean-ctx.env]\nA = "1"\n'
            '[mcp_servers.lean-ctx-standalone]\ncommand = "keep"\n'
            '[other]\nz = 1\n'))
        res = self.merge()
        self.assertTrue(res["mcp_merged"])
        text = self.target().read_text()
        self.assertNotIn("[mcp_servers.lean-ctx]", text)
        self.assertNotIn("[mcp_servers.lean-ctx.env]", text)
        self.assertIn("[mcp_servers.lean-ctx-standalone]", text)
        self.assertIn("[other]", text)
        if tomllib:
            self.assertEqual(self.parsed()["mcp_servers"]["lean-ctx-standalone"]["command"], "keep")

    def test_removal_only_is_still_a_change_when_block_exists(self):
        self.merge()
        text = self.target().read_text()
        self.target().write_text(text + '\n[mcp_servers.lean-ctx]\ncommand = "dup"\n')
        res = self.merge()
        self.assertTrue(res["mcp_merged"])
        self.assertNotIn("lean-ctx]", self.target().read_text().replace("leanctx", ""))

    def test_existing_section_is_normalized(self):
        self.write(self.target(), (
            '[mcp_servers.leanctx]\ncommand = "old"\nargs = ["x"]\nstartup_timeout_sec = 5\n\n'
            '[mcp_servers.leanctx.env]\nLEANCTX_MCP_TOOL_PREFIX = "bad"\nMINE = "1"\n'))
        res = self.merge()
        self.assertTrue(res["mcp_merged"])
        text = self.target().read_text()
        self.assertIn('command = "/opt/g/lean-ctx"', text)
        self.assertIn('args = ["mcp"]', text)
        self.assertIn("startup_timeout_sec = 5", text)
        self.assertIn('LEANCTX_MCP_TOOL_PREFIX = "lctx_"', text)
        self.assertIn('MINE = "1"', text)
        self.assertFalse(self.merge()["mcp_merged"])
        if tomllib:
            lean = self.parsed()["mcp_servers"]["leanctx"]
            self.assertEqual((lean["command"], lean["env"]["MINE"]), ("/opt/g/lean-ctx", "1"))

    def test_missing_command_args_and_env_lines_are_inserted(self):
        self.write(self.target(), '[mcp_servers.leanctx]\nstartup_timeout_sec = 5\n\n'
                                  '[mcp_servers.leanctx.env]\nMINE = "1"\n')
        self.merge()
        if tomllib:
            lean = self.parsed()["mcp_servers"]["leanctx"]
            self.assertEqual((lean["command"], lean["args"], lean["startup_timeout_sec"]),
                             ("/opt/g/lean-ctx", ["mcp"], 5))
            self.assertEqual(lean["env"], {"LEANCTX_MCP_TOOL_PREFIX": "lctx_", "MINE": "1"})

    def test_missing_env_section_is_appended(self):
        self.write(self.target(), '[mcp_servers.leanctx]\ncommand = "/opt/g/lean-ctx"\nargs = ["mcp"]')
        self.merge()
        text = self.target().read_text()
        self.assertIn("[mcp_servers.leanctx.env]", text)
        if tomllib:
            self.assertEqual(self.parsed()["mcp_servers"]["leanctx"]["env"], PREFIX)

    def test_header_at_end_of_file_without_newline_stays_valid_toml(self):
        for text in ("[mcp_servers.leanctx]", "[mcp_servers.leanctx]\n[mcp_servers.leanctx.env]"):
            self.write(self.target(), text)
            self.merge()
            if tomllib:
                lean = self.parsed()["mcp_servers"]["leanctx"]
                self.assertEqual(lean["command"], "/opt/g/lean-ctx", text)
                self.assertEqual(lean["env"], PREFIX, text)

    def test_normalize_helpers_directly(self):
        self.assertEqual(mod.normalize_codex_root("x = 1\n", "leanctx", MANIFEST), "x = 1\n")
        out = mod.normalize_codex_env("", {"K": "v"})
        self.assertEqual(out, '[mcp_servers.leanctx.env]\nK = "v"\n')
        out = mod.normalize_codex_env("a = 1", {"K": "v"})
        self.assertEqual(out, 'a = 1\n\n[mcp_servers.leanctx.env]\nK = "v"\n')

    def test_dry_run_does_not_write(self):
        res = self.merge(dry_run=True)
        self.assertTrue(res["mcp_merged"])
        self.assertIn(f"DRY-RUN: would append leanctx block to {self.target()}", self.last_out)
        self.assertFalse(self.target().exists())

    def test_symlinked_config_is_written_through(self):
        real = self.write(self.tmp / "real.toml", 'model = "x"\n')
        self.target().parent.mkdir(parents=True)
        self.target().symlink_to(real)
        self.merge()
        self.assertTrue(self.target().is_symlink())
        self.assertIn("[mcp_servers.leanctx]", real.read_text())


class OptimizeAndMainTest(Base):
    def test_unsupported_host(self):
        with self.assertRaisesRegex(ValueError, "unsupported host: vim"):
            mod.optimize_host("vim", False, MANIFEST)

    def test_each_host_writes_its_own_file(self):
        for host, path in (
            ("cursor", self.home / ".cursor" / "mcp.json"),
            ("claude", self.home / ".claude.json"),
            ("opencode", self.home / ".config" / "opencode" / "opencode.json"),
            ("codex", self.home / ".codex" / "config.toml"),
        ):
            res = self.quiet(mod.optimize_host, host, False, MANIFEST)
            self.assertEqual((res["host"], res["mcp_merged"]), (host, True), host)
            self.assertTrue(path.is_file(), host)

    def test_codex_home_override(self):
        custom = self.tmp / "custom-codex"
        with mock.patch.dict(os.environ, {"CODEX_HOME": str(custom)}):
            self.quiet(mod.optimize_host, "codex", False, MANIFEST)
        self.assertTrue((custom / "config.toml").is_file())
        self.assertFalse((self.home / ".codex").exists())

    def test_cursor_with_context_mode_strips_collision(self):
        path = self.home / ".cursor" / "mcp.json"
        self.write(path, {"mcpServers": {"context-mode": {}}})
        res = self.quiet(mod.optimize_host, "cursor", False, MANIFEST)
        self.assertTrue(res["cm_active"])
        lean = self.read_json(path)["mcpServers"]["leanctx"]
        self.assertEqual(lean["disabledTools"], mod.CM_OVERLAP_TOOLS)

    def test_manifest_default_comes_from_ensure_global_instances(self):
        with mock.patch.object(mod, "ensure_global_instances", return_value=MANIFEST) as ens:
            res = self.quiet(mod.optimize_host, "claude", True)
        ens.assert_called_once_with(dry_run=True)
        self.assertEqual(res["host"], "claude")

    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["merge-leanctx-mcp-config.py", *argv]), \
             mock.patch.object(mod, "ensure_global_instances", return_value=MANIFEST) as ens, \
             contextlib.redirect_stdout(out):
            code = mod.main()
        return code, out.getvalue(), ens

    def test_main_default_host_cursor(self):
        code, out, ens = self.run_main()
        self.assertEqual(code, 0)
        ens.assert_called_once_with(dry_run=False)
        data = json.loads(out)
        self.assertEqual([r["host"] for r in data["results"]], ["cursor"])
        self.assertEqual(data["status"], "ok")

    def test_main_all_hosts_dry_run(self):
        code, out, ens = self.run_main("--host", "all", "--dry-run")
        ens.assert_called_once_with(dry_run=True)
        payload = out[out.index("{\n  \"status\""):]
        self.assertEqual([r["host"] for r in json.loads(payload)["results"]],
                         ["cursor", "codex", "claude", "opencode"])
        self.assertFalse((self.home / ".cursor").exists())

    def test_dunder_main(self):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["x", "--host", "claude"]), \
             mock.patch.object(sys.modules["five_tool_instances"], "ensure_global_instances",
                               return_value=MANIFEST), \
             contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / REL), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertTrue((self.home / ".claude.json").is_file())


if __name__ == "__main__":
    unittest.main()

"""Unit tests for scripts/lib/global-toolstack/patch-mcp.py: Codex config.toml
merging (text-level TOML edits) and the codex host entry in main()."""

import contextlib
import copy
import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

pm = load_module("scripts/lib/global-toolstack/patch-mcp.py")

MANIFEST = {
    "tools": {
        "graphify": {"command": "/opt/five/graphify-mcp", "args": ["--stdio"]},
        "agentmemory": {
            "command": "/opt/five/agentmemory",
            "args": ["mcp"],
            "env": {"AGENTMEMORY_URL": "http://localhost:3111"},
        },
        "context_mode": {"command": "/opt/five/context-mode", "args": []},
        "leanctx": {"command": "/opt/five/lean-ctx", "args": ["serve"]},
    }
}


class CodexCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        env = {k: v for k, v in os.environ.items() if not k.startswith(("RT_", "CODEX_HOME", "TOOLSTACK_"))}
        env["HOME"] = str(self.root / "home")
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.path = self.root / "codex" / "config.toml"

    def merge(self, **flags):
        kwargs = dict(patch_graphify=False, patch_leanctx=False, patch_agentmemory=False, patch_context_mode=False)
        kwargs.update(flags)
        return pm.merge_codex_mcp(self.path, manifest=copy.deepcopy(MANIFEST), **kwargs)

    def text(self):
        return self.path.read_text(encoding="utf-8")


class BlockTest(CodexCase):
    def test_graphify_block(self):
        self.assertEqual(
            pm.codex_mcp_block("graphify", cm_active=False, manifest=MANIFEST),
            '[mcp_servers.graphify]\ncommand = "/opt/five/graphify-mcp"\nargs = ["--stdio"]\n',
        )

    def test_agentmemory_block_has_env_table(self):
        block = pm.codex_mcp_block("agentmemory", cm_active=False, manifest=MANIFEST)
        self.assertIn("[mcp_servers.agentmemory]\ncommand = \"/opt/five/agentmemory\"", block)
        self.assertIn('[mcp_servers.agentmemory.env]\nAGENTMEMORY_URL = "http://localhost:3111"\n', block)

    def test_context_mode_block_uses_underscore_spec(self):
        self.assertEqual(
            pm.codex_mcp_block("context-mode", cm_active=False, manifest=MANIFEST),
            '[mcp_servers.context-mode]\ncommand = "/opt/five/context-mode"\nargs = []\n',
        )

    def test_leanctx_block_env_depends_on_context_mode(self):
        base = pm.codex_mcp_block("leanctx", cm_active=False, manifest=MANIFEST)
        active = pm.codex_mcp_block("leanctx", cm_active=True, manifest=MANIFEST)
        self.assertIn('LEANCTX_MCP_TOOL_PREFIX = "lctx_"', base)
        self.assertNotIn("LEANCTX_DISABLE_SHELL_MCP", base)
        self.assertIn('LEANCTX_DISABLE_SHELL_MCP = "1"', active)
        self.assertIn("[mcp_servers.leanctx.env]", active)


class TomlHelperTest(CodexCase):
    def test_section_bounds(self):
        text = "a = 1\n[mcp_servers.x]\ncommand = \"c\"\n\n[other]\nk = 1\n"
        start, end = pm._toml_section_bounds(text, "[mcp_servers.x]")
        self.assertEqual(text[start:end], '[mcp_servers.x]\ncommand = "c"\n\n')
        start, end = pm._toml_section_bounds(text, "[other]")
        self.assertEqual(text[start:end], "[other]\nk = 1\n")
        self.assertIsNone(pm._toml_section_bounds(text, "[missing]"))

    def test_section_bounds_does_not_match_prefix(self):
        text = "[mcp_servers.x.env]\nK = 1\n"
        self.assertIsNone(pm._toml_section_bounds(text, "[mcp_servers.x]"))

    def test_set_root_keys_replaces_and_adds(self):
        body = 'command = "old"\nextra = 1\n'
        out = pm._toml_set_root_keys(body, "/new", ["a"])
        self.assertIn('command = "/new"', out)
        self.assertIn('args = ["a"]', out)
        self.assertIn("extra = 1", out)
        self.assertEqual(out.count("command"), 1)
        self.assertEqual(pm._toml_set_root_keys(out, "/new", ["a"]), out)

    def test_set_env_creates_section(self):
        out = pm._toml_set_env("x = 1", "s", {"A": "1", "B": "2"})
        self.assertEqual(out, 'x = 1\n\n[mcp_servers.s.env]\nA = "1"\nB = "2"\n')
        self.assertEqual(pm._toml_set_env("", "s", {"A": "1"}), '[mcp_servers.s.env]\nA = "1"\n')
        self.assertTrue(pm._toml_set_env("x = 1\n", "s", {"A": "1"}).startswith("x = 1\n\n[mcp"))

    def test_set_env_updates_existing_section(self):
        text = '[mcp_servers.s.env]\nA = "old"\nKEEP = "k"\n\n[next]\nz = 1\n'
        out = pm._toml_set_env(text, "s", {"A": "new", "B": "2"})
        self.assertIn('A = "new"', out)
        self.assertIn('B = "2"', out)
        self.assertIn('KEEP = "k"', out)
        self.assertTrue(out.endswith("[next]\nz = 1\n"))
        self.assertEqual(pm._toml_set_env(out, "s", {"A": "new", "B": "2"}), out)

    def test_set_env_header_without_trailing_newline(self):
        out = pm._toml_set_env("[mcp_servers.s.env]", "s", {"A": "1"})
        self.assertIn('A = "1"', out)
        self.assertTrue(out.startswith("[mcp_servers.s.env]"))

    def test_normalize_server_appends_block(self):
        out = pm._toml_normalize_server("x = 1", "graphify", manifest=MANIFEST, cm_active=False)
        self.assertTrue(out.startswith("x = 1\n\n[mcp_servers.graphify]\n"))
        self.assertEqual(pm._toml_normalize_server("", "graphify", manifest=MANIFEST, cm_active=False).count("[mcp_servers.graphify]"), 1)

    def test_normalize_server_repairs_existing_section(self):
        text = '[mcp_servers.graphify]\ncommand = "old"\nargs = []\ncustom = true\n\n[tail]\nk = 1\n'
        out = pm._toml_normalize_server(text, "graphify", manifest=MANIFEST, cm_active=False)
        self.assertIn('command = "/opt/five/graphify-mcp"', out)
        self.assertIn('args = ["--stdio"]', out)
        self.assertIn("custom = true", out)
        self.assertTrue(out.endswith("[tail]\nk = 1\n"))

    def test_normalize_server_existing_header_at_eof_without_newline(self):
        out = pm._toml_normalize_server("[mcp_servers.graphify]", "graphify", manifest=MANIFEST, cm_active=False)
        self.assertIn('command = "/opt/five/graphify-mcp"', out)

    def test_normalize_server_with_env_adds_env_section(self):
        text = '[mcp_servers.agentmemory]\ncommand = "old"\nargs = []\n'
        out = pm._toml_normalize_server(text, "agentmemory", manifest=MANIFEST, cm_active=False)
        self.assertIn('[mcp_servers.agentmemory.env]\nAGENTMEMORY_URL = "http://localhost:3111"', out)


class MergeCodexTest(CodexCase):
    def test_nothing_enabled_is_a_noop(self):
        changed, msg = self.merge()
        self.assertEqual((changed, msg), (False, "OK: config.toml unchanged (idempotent)"))
        self.assertFalse(self.path.exists())

    def test_creates_all_servers(self):
        changed, msg = self.merge(patch_graphify=True, patch_leanctx=True, patch_agentmemory=True, patch_context_mode=True)
        self.assertEqual((changed, msg), (True, "OK: config.toml merged atomically"))
        text = self.text()
        for header in ("[mcp_servers.graphify]", "[mcp_servers.leanctx]", "[mcp_servers.leanctx.env]", "[mcp_servers.agentmemory]", "[mcp_servers.agentmemory.env]", "[mcp_servers.context-mode]"):
            self.assertEqual(text.count(header), 1, header)
        self.assertIn('LEANCTX_DISABLE_SHELL_MCP = "1"', text)  # context-mode consent => overlap env
        self.assertEqual(self.merge(patch_graphify=True, patch_leanctx=True, patch_agentmemory=True, patch_context_mode=True), (False, "OK: config.toml unchanged (idempotent)"))
        self.assertEqual(self.text(), text)

    def test_leanctx_without_context_mode_uses_base_env(self):
        self.merge(patch_leanctx=True)
        self.assertNotIn("LEANCTX_DISABLE_SHELL_MCP", self.text())

    def test_existing_context_mode_section_activates_overlap_env_and_is_normalised(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text('[mcp_servers.context-mode]\ncommand = "old"\nargs = ["x"]\n')
        changed, _ = self.merge(patch_leanctx=True)
        self.assertTrue(changed)
        text = self.text()
        self.assertIn('LEANCTX_DISABLE_SHELL_MCP = "1"', text)
        self.assertIn('command = "/opt/five/context-mode"', text)
        self.assertIn("args = []", text)
        self.assertEqual(text.count("[mcp_servers.context-mode]"), 1)

    def test_legacy_lean_ctx_sections_removed_and_user_sections_kept(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text(
            'model = "x"\n\n[mcp_servers.lean-ctx]\ncommand = "old"\n\n[mcp_servers.lean-ctx.env]\nA = "1"\n\n[mcp_servers.mine]\ncommand = "m"\n'
        )
        changed, _ = self.merge()
        self.assertTrue(changed)
        text = self.text()
        self.assertNotIn("lean-ctx", text)
        self.assertIn("[mcp_servers.mine]", text)
        self.assertIn('model = "x"', text)

    def test_existing_graphify_section_is_repaired_in_place(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text('[mcp_servers.graphify]\ncommand = "old"\nargs = ["z"]\n\n[mcp_servers.mine]\ncommand = "m"\n')
        changed, _ = self.merge(patch_graphify=True)
        self.assertTrue(changed)
        text = self.text()
        self.assertIn('command = "/opt/five/graphify-mcp"', text)
        self.assertNotIn('"z"', text)
        self.assertIn("[mcp_servers.mine]", text)

    def test_disabled_servers_are_left_alone(self):
        self.path.parent.mkdir(parents=True)
        original = '[mcp_servers.graphify]\ncommand = "keep-me"\n'
        self.path.write_text(original)
        changed, _ = self.merge(patch_agentmemory=True)
        self.assertTrue(changed)
        self.assertIn('command = "keep-me"', self.text())

    def test_unchanged_existing_file_is_not_rewritten(self):
        self.merge(patch_graphify=True)
        mtime = self.path.stat().st_mtime_ns
        with mock.patch.object(pm, "atomic_write_text") as writer:
            self.assertEqual(self.merge(patch_graphify=True)[0], False)
        writer.assert_not_called()
        self.assertEqual(self.path.stat().st_mtime_ns, mtime)


class MainCodexHostTest(CodexCase):
    def run_main(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = pm.main()
        return code, out.getvalue().strip()

    def setUp(self):
        super().setUp()
        ensure = mock.patch.object(pm, "ensure_global_instances", return_value=copy.deepcopy(MANIFEST))
        ensure.start()
        self.addCleanup(ensure.stop)
        os.environ["RT_HOST"] = "codex"

    def test_codex_home_override(self):
        os.environ["CODEX_HOME"] = str(self.root / "codex")
        os.environ["RT_PATCH_GRAPHIFY"] = "1"
        code, out = self.run_main()
        self.assertEqual((code, out), (0, "OK: config.toml merged atomically"))
        self.assertIn("[mcp_servers.graphify]", self.text())

    def test_default_codex_home(self):
        os.environ["RT_PATCH_AGENTMEMORY"] = "1"
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("[mcp_servers.agentmemory]", (Path(os.environ["HOME"]) / ".codex" / "config.toml").read_text())

    def test_codex_second_run_reports_idempotent(self):
        os.environ["CODEX_HOME"] = str(self.root / "codex")
        os.environ["RT_PATCH_LEANCTX"] = "1"
        self.run_main()
        self.assertEqual(self.run_main(), (0, "OK: config.toml unchanged (idempotent)"))


class ScriptEntryPointTest(unittest.TestCase):
    def test_runs_as_script_without_flags(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {k: v for k, v in os.environ.items() if not k.startswith(("RT_", "SB_GLOBAL_", "FIVE_TOOL_"))}
            env["HOME"] = tmp
            res = subprocess.run([sys.executable, str(Path(pm.__file__))], capture_output=True, text=True, env=env, check=False)
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertEqual(res.stdout.strip(), "OK: mcp.json unchanged (no patch flags)")


if __name__ == "__main__":
    unittest.main()

"""Unit tests for scripts/lib/global-toolstack/patch-mcp.py: Codex config.toml
merging (structural TOML edits) and the codex host entry in main()."""

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


def parse_toml(text):
    import tomllib

    return tomllib.loads(text)


class NormalizeServerTest(CodexCase):
    def doc(self, text):
        return pm.sbc.TomlDocument(text)

    def test_graphify_table_is_created(self):
        doc = self.doc("")
        self.assertTrue(pm._toml_normalize_server(doc, "graphify", manifest=MANIFEST, cm_active=False))
        self.assertEqual(
            parse_toml(doc.text), {"mcp_servers": {"graphify": {"command": "/opt/five/graphify-mcp", "args": ["--stdio"]}}}
        )

    def test_agentmemory_gets_env_table(self):
        doc = self.doc("")
        pm._toml_normalize_server(doc, "agentmemory", manifest=MANIFEST, cm_active=False)
        server = parse_toml(doc.text)["mcp_servers"]["agentmemory"]
        self.assertEqual(server["command"], "/opt/five/agentmemory")
        self.assertEqual(server["env"], {"AGENTMEMORY_URL": "http://localhost:3111"})

    def test_context_mode_uses_the_underscore_spec(self):
        doc = self.doc("")
        pm._toml_normalize_server(doc, "context-mode", manifest=MANIFEST, cm_active=False)
        self.assertEqual(parse_toml(doc.text)["mcp_servers"]["context-mode"], {"command": "/opt/five/context-mode", "args": []})

    def test_leanctx_env_depends_on_context_mode(self):
        base, active = self.doc(""), self.doc("")
        pm._toml_normalize_server(base, "leanctx", manifest=MANIFEST, cm_active=False)
        pm._toml_normalize_server(active, "leanctx", manifest=MANIFEST, cm_active=True)
        self.assertEqual(parse_toml(base.text)["mcp_servers"]["leanctx"]["env"], pm.LEANCTX_ENV_BASE)
        self.assertEqual(parse_toml(active.text)["mcp_servers"]["leanctx"]["env"], pm.LEANCTX_ENV_CM_ACTIVE)

    def test_existing_table_is_repaired_in_place(self):
        doc = self.doc('[mcp_servers.graphify]\ncommand = "old"\nargs = []\ncustom = true\n\n[tail]\nk = 1\n')
        self.assertTrue(pm._toml_normalize_server(doc, "graphify", manifest=MANIFEST, cm_active=False))
        parsed = parse_toml(doc.text)
        self.assertEqual(parsed["mcp_servers"]["graphify"], {"command": "/opt/five/graphify-mcp", "args": ["--stdio"], "custom": True})
        self.assertEqual(parsed["tail"], {"k": 1})
        self.assertFalse(pm._toml_normalize_server(doc, "graphify", manifest=MANIFEST, cm_active=False))

    def test_header_at_end_of_file_without_newline(self):
        doc = self.doc("[mcp_servers.graphify]")
        pm._toml_normalize_server(doc, "graphify", manifest=MANIFEST, cm_active=False)
        self.assertEqual(parse_toml(doc.text)["mcp_servers"]["graphify"]["command"], "/opt/five/graphify-mcp")

    def test_existing_env_keys_are_updated_and_kept(self):
        doc = self.doc('[mcp_servers.agentmemory.env]\nAGENTMEMORY_URL = "http://old"\nKEEP = "k"\n')
        pm._toml_normalize_server(doc, "agentmemory", manifest=MANIFEST, cm_active=False)
        env = parse_toml(doc.text)["mcp_servers"]["agentmemory"]["env"]
        self.assertEqual(env, {"AGENTMEMORY_URL": "http://localhost:3111", "KEEP": "k"})


class MergeCodexTest(CodexCase):
    def test_nothing_enabled_is_a_noop(self):
        changed, msg = self.merge()
        self.assertEqual((changed, msg), (False, "OK: config.toml unchanged (idempotent)"))
        self.assertFalse(self.path.exists())

    def test_creates_all_servers_as_valid_toml(self):
        changed, msg = self.merge(patch_graphify=True, patch_leanctx=True, patch_agentmemory=True, patch_context_mode=True)
        self.assertEqual((changed, msg), (True, "OK: config.toml merged atomically"))
        servers = parse_toml(self.text())["mcp_servers"]
        self.assertEqual(sorted(servers), ["agentmemory", "context-mode", "graphify", "leanctx"])
        self.assertEqual(servers["leanctx"]["env"]["LEANCTX_DISABLE_SHELL_MCP"], "1")  # context-mode consent => overlap env
        text = self.text()
        self.assertEqual(self.merge(patch_graphify=True, patch_leanctx=True, patch_agentmemory=True, patch_context_mode=True), (False, "OK: config.toml unchanged (idempotent)"))
        self.assertEqual(self.text(), text)

    def test_leanctx_without_context_mode_uses_base_env(self):
        self.merge(patch_leanctx=True)
        self.assertNotIn("LEANCTX_DISABLE_SHELL_MCP", self.text())

    def test_existing_context_mode_table_activates_overlap_env_and_is_normalised(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text('[mcp_servers.context-mode]\ncommand = "old"\nargs = ["x"]\n')
        changed, _ = self.merge(patch_leanctx=True)
        self.assertTrue(changed)
        servers = parse_toml(self.text())["mcp_servers"]
        self.assertEqual(servers["leanctx"]["env"]["LEANCTX_DISABLE_SHELL_MCP"], "1")
        self.assertEqual(servers["context-mode"], {"command": "/opt/five/context-mode", "args": []})

    def test_legacy_lean_ctx_is_replaced_only_when_leanctx_is_consented(self):
        self.path.parent.mkdir(parents=True)
        original = 'model = "x"\n\n[mcp_servers.lean-ctx]\ncommand = "old"\n\n[mcp_servers.lean-ctx.env]\nSECRET = "1"\n\n[mcp_servers.mine]\ncommand = "m"\n'
        self.path.write_text(original)
        self.assertEqual(self.merge(patch_graphify=True)[0], True)
        text = self.text()
        self.assertEqual(parse_toml(text)["mcp_servers"]["lean-ctx"]["env"], {"SECRET": "1"})  # R6-07
        self.merge(patch_leanctx=True)
        parsed = parse_toml(self.text())
        self.assertNotIn("lean-ctx", parsed["mcp_servers"])
        self.assertEqual(parsed["mcp_servers"]["mine"], {"command": "m"})
        self.assertEqual(parsed["model"], "x")
        self.assertIn("SECRET", self.path.with_name("config.toml.sb-backup").read_text())

    def test_valid_toml_stays_valid_whatever_shape_it_has(self):
        # R6-06: regex editing broke these; each is a legal Codex config.
        shapes = [
            '[mcp_servers.graphify]\n# comment\ncommand = "old"\nargs = [\n  "a",\n  "b",\n]\n',
            "[ mcp_servers . graphify ]\ncommand = 'old'\n",
            'notes = """\n[mcp_servers.graphify]\nnot a table\n"""\n',
            '[mcp_servers.graphify]\r\ncommand = "old"\r\n',
            'mcp_servers.graphify.command = "dotted"\n',
            '[mcp_servers]\ngraphify = { command = "inline" }\n',
        ]
        for text in shapes:
            with self.subTest(text=text):
                self.path.parent.mkdir(parents=True, exist_ok=True)
                self.path.write_bytes(text.encode())
                try:
                    self.merge(patch_graphify=True)
                except pm.sbc.ConfigError:
                    # A shape that cannot be merged safely is refused and left byte-identical.
                    self.assertEqual(self.path.read_bytes(), text.encode())
                    continue
                parse_toml(self.text())

    def test_existing_graphify_table_is_repaired_in_place(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text('[mcp_servers.graphify]\ncommand = "old"\nargs = ["z"]\n\n[mcp_servers.mine]\ncommand = "m"\n')
        changed, _ = self.merge(patch_graphify=True)
        self.assertTrue(changed)
        servers = parse_toml(self.text())["mcp_servers"]
        self.assertEqual(servers["graphify"]["command"], "/opt/five/graphify-mcp")
        self.assertEqual(servers["graphify"]["args"], ["--stdio"])
        self.assertEqual(servers["mine"], {"command": "m"})

    def test_disabled_servers_are_left_alone(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text('[mcp_servers.graphify]\ncommand = "keep-me"\n')
        changed, _ = self.merge(patch_agentmemory=True)
        self.assertTrue(changed)
        self.assertIn('command = "keep-me"', self.text())

    def test_unchanged_existing_file_is_not_rewritten(self):
        self.merge(patch_graphify=True)
        mtime = self.path.stat().st_mtime_ns
        with mock.patch.object(pm.sbc, "write_toml") as writer:
            self.assertEqual(self.merge(patch_graphify=True)[0], False)
        writer.assert_not_called()
        self.assertEqual(self.path.stat().st_mtime_ns, mtime)

    def test_write_keeps_symlink_mode_and_backup(self):
        real = self.root / "dotfiles" / "codex.toml"
        real.parent.mkdir(parents=True)
        real.write_text('model = "x"\n')
        real.chmod(0o640)
        self.path.parent.mkdir(parents=True)
        self.path.symlink_to(real)
        self.merge(patch_graphify=True)
        self.assertTrue(self.path.is_symlink())
        self.assertEqual(real.stat().st_mode & 0o777, 0o640)
        self.assertEqual(real.with_name("codex.toml.sb-backup").read_text(), 'model = "x"\n')
        self.assertIn("graphify", real.read_text())

    def test_unparseable_config_is_refused_and_left_alone(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("this is = = not toml\n")
        with self.assertRaises(pm.sbc.ConfigError):
            self.merge(patch_graphify=True)
        self.assertEqual(self.text(), "this is = = not toml\n")


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

    def test_unparseable_config_exits_2_and_is_untouched(self):
        os.environ["CODEX_HOME"] = str(self.root / "codex")
        os.environ["RT_PATCH_GRAPHIFY"] = "1"
        self.path.parent.mkdir(parents=True)
        self.path.write_text("= broken\n")
        code, _ = self.run_main()
        self.assertEqual(code, 2)
        self.assertEqual(self.text(), "= broken\n")


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

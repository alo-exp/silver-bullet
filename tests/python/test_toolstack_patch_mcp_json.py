"""Unit tests for scripts/lib/global-toolstack/patch-mcp.py: JSON host merges
(Cursor/Claude mcp.json), Graphify handshake, AgentMemory/LeanCTX/Context Mode
normalisation and the OpenCode projection."""

import contextlib
import copy
import io
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

pm = load_module("scripts/lib/global-toolstack/patch-mcp.py")


def make_manifest(root="/opt/five"):
    return {
        "tools": {
            "graphify": {"command": f"{root}/graphify-mcp", "args": ["--stdio"]},
            "agentmemory": {
                "command": f"{root}/agentmemory",
                "args": ["mcp"],
                "env": {"AGENTMEMORY_URL": "http://localhost:3111"},
            },
            "context_mode": {"command": f"{root}/context-mode", "args": []},
            "leanctx": {"command": f"{root}/lean-ctx", "args": ["serve"]},
            "rtk": {"command": f"{root}/rtk", "args": []},
        }
    }


MANIFEST = make_manifest()


class McpCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        env = {k: v for k, v in os.environ.items() if not k.startswith(("RT_", "CODEX_HOME", "TOOLSTACK_"))}
        env["HOME"] = str(self.home)
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        ensure = mock.patch.object(pm, "ensure_global_instances", return_value=copy.deepcopy(MANIFEST))
        ensure.start()
        self.addCleanup(ensure.stop)

    def flags(self, **names):
        for name, value in names.items():
            os.environ[f"RT_PATCH_{name.upper()}"] = "1" if value else "0"

    def run_main(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = pm.main()
        return code, out.getvalue().strip(), err.getvalue().strip()


class LoadAndNormalizeTest(McpCase):
    def test_load_json(self):
        p = self.root / "m.json"
        self.assertEqual(pm.load_json(p), {})
        p.write_text('{"a": 1}')
        self.assertEqual(pm.load_json(p), {"a": 1})

    def test_normalize_mcp_config(self):
        self.assertEqual(pm.normalize_mcp_config({"mcpServers": {}, "x": 1}), {"x": 1})
        data = {"mcpServers": {"a": {}}}
        self.assertEqual(pm.normalize_mcp_config(data), data)
        self.assertIsNot(pm.normalize_mcp_config(data), data)
        self.assertEqual(pm.normalize_mcp_config({"mcpServers": []}), {"mcpServers": []})
        self.assertEqual(pm.normalize_mcp_config({"mcp": {}, "x": 1}), {"x": 1})
        self.assertEqual(pm.normalize_mcp_config({"mcp": {"a": {}}}), {"mcp": {"a": {}}})

    def test_atomic_writers(self):
        target = self.root / "a" / "b.json"
        pm.atomic_write_json(target, {"k": 1})
        self.assertEqual(json.loads(target.read_text()), {"k": 1})
        text = self.root / "c" / "d.toml"
        pm.atomic_write_text(text, "x = 1\n")
        self.assertEqual(text.read_text(), "x = 1\n")
        self.assertEqual([p.name for p in text.parent.iterdir()], ["d.toml"])
        self.assertEqual([p.name for p in target.parent.iterdir()], ["b.json"])


class GraphifyHandshakeTest(McpCase):
    def manifest_with_binary(self):
        binary = self.root / "graphify-mcp"
        binary.write_text("#!/bin/sh\n")
        binary.chmod(0o755)
        m = copy.deepcopy(MANIFEST)
        m["tools"]["graphify"]["command"] = str(binary)
        return m

    def test_installed_by_file(self):
        self.assertTrue(pm.graphify_mcp_installed(self.manifest_with_binary()))

    def test_installed_by_path_lookup(self):
        m = copy.deepcopy(MANIFEST)
        m["tools"]["graphify"]["command"] = "graphify-mcp-not-here"
        with mock.patch.object(pm.shutil, "which", return_value="/usr/bin/x"):
            self.assertTrue(pm.graphify_mcp_installed(m))
        with mock.patch.object(pm.shutil, "which", return_value=None):
            self.assertFalse(pm.graphify_mcp_installed(m))

    def test_not_installed(self):
        self.assertEqual(pm.graphify_mcp_handshake(MANIFEST), (False, "graphify-mcp not installed"))

    def run_handshake(self, **run_kwargs):
        m = self.manifest_with_binary()
        with mock.patch.object(pm.subprocess, "run", **run_kwargs) as run:
            result = pm.graphify_mcp_handshake(m)
        return result, run, m

    def test_exit_zero_and_one_are_ok(self):
        for code in (0, 1):
            result, run, m = self.run_handshake(return_value=subprocess.CompletedProcess([], code))
            self.assertEqual(result, (True, None))
            self.assertEqual(run.call_args.args[0], [m["tools"]["graphify"]["command"], "--stdio"])
            self.assertEqual(run.call_args.kwargs["timeout"], pm.GRAPHIFY_MCP_HANDSHAKE_TIMEOUT)

    def test_other_exit_codes_fail(self):
        result, _, _ = self.run_handshake(return_value=subprocess.CompletedProcess([], 3))
        self.assertEqual(result, (False, "graphify-mcp exited 3"))

    def test_timeout_still_merges_with_warning(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            result, _, _ = self.run_handshake(side_effect=subprocess.TimeoutExpired("x", 15))
        self.assertEqual(result, (True, "handshake_timeout"))
        self.assertIn("handshake timed out", err.getvalue())

    def test_os_error_fails_with_message(self):
        result, _, _ = self.run_handshake(side_effect=OSError("boom"))
        self.assertEqual(result, (False, "boom"))


class MergeAgentmemoryTest(McpCase):
    def test_adds_canonical_entry(self):
        servers = {}
        self.assertTrue(pm.merge_agentmemory(servers, MANIFEST))
        self.assertEqual(servers["agentmemory"]["command"], "/opt/five/agentmemory")

    def test_idempotent(self):
        servers = {}
        pm.merge_agentmemory(servers, MANIFEST)
        self.assertFalse(pm.merge_agentmemory(servers, MANIFEST))

    def test_repairs_command_args_and_env(self):
        servers = {"agentmemory": {"command": "old", "args": ["x"], "env": {"KEEP": "1", "AGENTMEMORY_URL": "bad"}}}
        self.assertTrue(pm.merge_agentmemory(servers, MANIFEST))
        entry = servers["agentmemory"]
        self.assertEqual((entry["command"], entry["args"]), ("/opt/five/agentmemory", ["mcp"]))
        self.assertEqual(entry["env"], {"KEEP": "1", "AGENTMEMORY_URL": "http://localhost:3111"})

    def test_adds_missing_env_block(self):
        servers = {"agentmemory": {"command": "/opt/five/agentmemory", "args": ["mcp"]}}
        self.assertTrue(pm.merge_agentmemory(servers, MANIFEST))
        self.assertEqual(servers["agentmemory"]["env"], {"AGENTMEMORY_URL": "http://localhost:3111"})

    def test_non_dict_env_is_replaced(self):
        servers = {"agentmemory": {"command": "/opt/five/agentmemory", "args": ["mcp"], "env": "junk"}}
        self.assertTrue(pm.merge_agentmemory(servers, MANIFEST))
        self.assertIsInstance(servers["agentmemory"]["env"], dict)

    def test_spec_without_env_leaves_existing_env_alone(self):
        m = copy.deepcopy(MANIFEST)
        del m["tools"]["agentmemory"]["env"]
        servers = {"agentmemory": {"command": "/opt/five/agentmemory", "args": ["mcp"], "env": {"A": "1"}}}
        self.assertFalse(pm.merge_agentmemory(servers, m))
        servers = {"agentmemory": {"command": "/opt/five/agentmemory", "args": ["mcp"]}}
        self.assertFalse(pm.merge_agentmemory(servers, m))
        self.assertNotIn("env", servers["agentmemory"])

    def test_legacy_alias_is_preserved_when_it_is_the_only_entry(self):
        servers = {"user-agentmemory": {"command": "old", "args": []}}
        self.assertTrue(pm.merge_agentmemory(servers, MANIFEST))
        self.assertNotIn("agentmemory", servers)
        self.assertEqual(servers["user-agentmemory"]["command"], "/opt/five/agentmemory")

    def test_canonical_wins_when_both_exist(self):
        servers = {"user-agentmemory": {"command": "old"}, "agentmemory": {"command": "/opt/five/agentmemory", "args": ["mcp"], "env": {"AGENTMEMORY_URL": "http://localhost:3111"}}}
        self.assertFalse(pm.merge_agentmemory(servers, MANIFEST))
        self.assertEqual(servers["user-agentmemory"], {"command": "old"})

    def test_non_dict_existing_is_replaced(self):
        servers = {"agentmemory": "junk"}
        self.assertTrue(pm.merge_agentmemory(servers, MANIFEST))
        self.assertIsInstance(servers["agentmemory"], dict)


class MergeGraphifyTest(McpCase):
    def test_existing_entry_is_repaired(self):
        servers = {"graphify": {"command": "old", "args": [], "keep": 1}}
        self.assertTrue(pm.merge_graphify(servers, manifest=MANIFEST, require_handshake=True))
        self.assertEqual(servers["graphify"], {"command": "/opt/five/graphify-mcp", "args": ["--stdio"], "keep": 1})
        self.assertFalse(pm.merge_graphify(servers, manifest=MANIFEST, require_handshake=True))

    def test_missing_entry_added_without_handshake(self):
        servers = {}
        self.assertTrue(pm.merge_graphify(servers, manifest=MANIFEST, require_handshake=False))
        self.assertEqual(servers["graphify"]["command"], "/opt/five/graphify-mcp")

    def test_handshake_failure_skips_with_warning(self):
        servers = {}
        err = io.StringIO()
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(False, "graphify-mcp not installed")):
            with contextlib.redirect_stderr(err):
                self.assertFalse(pm.merge_graphify(servers, manifest=MANIFEST, require_handshake=True))
        self.assertEqual(servers, {})
        self.assertIn("WARN: graphify merge skipped: graphify-mcp not installed", err.getvalue())

    def test_handshake_failure_without_reason_is_silent(self):
        err = io.StringIO()
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(False, None)):
            with contextlib.redirect_stderr(err):
                self.assertFalse(pm.merge_graphify({}, manifest=MANIFEST, require_handshake=True))
        self.assertEqual(err.getvalue(), "")

    def test_handshake_success_adds(self):
        servers = {}
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(True, None)):
            self.assertTrue(pm.merge_graphify(servers, manifest=MANIFEST, require_handshake=True))
        self.assertIn("graphify", servers)


class MergeLeanctxTest(McpCase):
    def test_creates_with_base_env(self):
        servers = {}
        self.assertTrue(pm.merge_leanctx(servers, MANIFEST))
        lean = servers["leanctx"]
        self.assertEqual(lean["command"], "/opt/five/lean-ctx")
        self.assertEqual(lean["env"], pm.LEANCTX_ENV_BASE)
        self.assertNotIn("disabledTools", lean)

    def test_does_not_mutate_the_manifest_spec(self):
        m = copy.deepcopy(MANIFEST)
        pm.merge_leanctx({}, m)
        self.assertNotIn("env", m["tools"]["leanctx"])

    def test_removes_legacy_aliases(self):
        servers = {"lean-ctx-standalone": {}, "lean-ctx": {}}
        self.assertTrue(pm.merge_leanctx(servers, MANIFEST))
        self.assertEqual(set(servers), {"leanctx"})

    def test_context_mode_present_switches_to_overlap_env(self):
        servers = {"context-mode": {"command": "x"}}
        self.assertTrue(pm.merge_leanctx(servers, MANIFEST))
        lean = servers["leanctx"]
        self.assertEqual(lean["env"], pm.LEANCTX_ENV_CM_ACTIVE)
        self.assertEqual(lean["disabledTools"], pm.CM_OVERLAP_TOOLS)

    def test_legacy_context_mode_alias_counts_as_present(self):
        servers = {"user-context-mode": {}}
        pm.merge_leanctx(servers, MANIFEST)
        self.assertEqual(servers["leanctx"]["env"], pm.LEANCTX_ENV_CM_ACTIVE)

    def test_idempotent_with_and_without_context_mode(self):
        for servers in ({}, {"context-mode": {}}):
            pm.merge_leanctx(servers, MANIFEST)
            self.assertFalse(pm.merge_leanctx(servers, MANIFEST))

    def test_existing_entry_is_repaired_and_user_env_preserved(self):
        servers = {
            "context-mode": {},
            "leanctx": {"command": "old", "args": [], "env": {"MINE": "1"}, "disabledTools": ["mine", "ctx_search"]},
        }
        self.assertTrue(pm.merge_leanctx(servers, MANIFEST))
        lean = servers["leanctx"]
        self.assertEqual((lean["command"], lean["args"]), ("/opt/five/lean-ctx", ["serve"]))
        self.assertEqual(lean["env"]["MINE"], "1")
        self.assertEqual(lean["disabledTools"][0:2], ["mine", "ctx_search"])
        self.assertEqual(sorted(set(lean["disabledTools"])), sorted({"mine", *pm.CM_OVERLAP_TOOLS}))
        self.assertEqual(len(lean["disabledTools"]), len(set(lean["disabledTools"])))

    def test_non_dict_env_and_disabled_tools_reset(self):
        servers = {"context-mode": {}, "leanctx": {"command": "/opt/five/lean-ctx", "args": ["serve"], "env": "x", "disabledTools": "y"}}
        self.assertTrue(pm.merge_leanctx(servers, MANIFEST))
        self.assertIsInstance(servers["leanctx"]["env"], dict)
        self.assertIsInstance(servers["leanctx"]["disabledTools"], list)

    def test_existing_matching_entry_without_changes(self):
        servers = {"leanctx": {"command": "/opt/five/lean-ctx", "args": ["serve"], "env": dict(pm.LEANCTX_ENV_BASE)}}
        self.assertFalse(pm.merge_leanctx(servers, MANIFEST))


class ContextModeTest(McpCase):
    def test_present(self):
        self.assertFalse(pm.context_mode_present({}))
        self.assertTrue(pm.context_mode_present({"context-mode": 1}))
        self.assertTrue(pm.context_mode_present({"user-context-mode": 1}))

    def test_normalize_repairs_canonical_entry(self):
        servers = {"context-mode": {"command": "old", "args": ["x"], "keep": 1}}
        self.assertTrue(pm.normalize_context_mode(servers, MANIFEST))
        self.assertEqual(servers["context-mode"], {"command": "/opt/five/context-mode", "args": [], "keep": 1})
        self.assertFalse(pm.normalize_context_mode(servers, MANIFEST))

    def test_normalize_promotes_legacy_alias(self):
        servers = {"user-context-mode": {"command": "old", "args": []}}
        self.assertTrue(pm.normalize_context_mode(servers, MANIFEST))
        self.assertNotIn("user-context-mode", servers)
        self.assertEqual(servers["context-mode"]["command"], "/opt/five/context-mode")

    def test_normalize_drops_alias_when_canonical_exists(self):
        servers = {"context-mode": {"command": "/opt/five/context-mode", "args": []}, "user-context-mode": {"command": "x"}}
        self.assertTrue(pm.normalize_context_mode(servers, MANIFEST))
        self.assertEqual(set(servers), {"context-mode"})

    def test_normalize_nothing_present(self):
        servers = {}
        self.assertFalse(pm.normalize_context_mode(servers, MANIFEST))
        self.assertEqual(servers, {})

    def test_normalize_non_dict_alias_is_dropped(self):
        servers = {"user-context-mode": "junk"}
        self.assertTrue(pm.normalize_context_mode(servers, MANIFEST))
        self.assertEqual(servers, {})

    def test_ensure_adds_when_allowed(self):
        servers = {}
        self.assertTrue(pm.ensure_context_mode(servers, MANIFEST, allow_add=True))
        self.assertEqual(servers["context-mode"]["command"], "/opt/five/context-mode")

    def test_ensure_does_not_add_without_consent(self):
        servers = {}
        self.assertFalse(pm.ensure_context_mode(servers, MANIFEST, allow_add=False))
        self.assertEqual(servers, {})

    def test_ensure_normalizes_existing_without_consent(self):
        servers = {"user-context-mode": {"command": "old", "args": []}}
        self.assertTrue(pm.ensure_context_mode(servers, MANIFEST, allow_add=False))
        self.assertIn("context-mode", servers)

    def test_ensure_readds_after_non_dict_alias_dropped(self):
        servers = {"user-context-mode": "junk"}
        self.assertTrue(pm.ensure_context_mode(servers, MANIFEST, allow_add=True))
        self.assertIsInstance(servers["context-mode"], dict)

    def test_ensure_non_dict_alias_without_consent_reports_change(self):
        servers = {"user-context-mode": "junk"}
        self.assertTrue(pm.ensure_context_mode(servers, MANIFEST, allow_add=False))
        self.assertEqual(servers, {})


class OpencodeMergeTest(McpCase):
    def merge(self, **flags):
        path = self.home / ".config" / "opencode" / "opencode.json"
        kwargs = dict(patch_graphify=False, patch_leanctx=False, patch_agentmemory=False, patch_context_mode=False)
        kwargs.update(flags)
        return pm.merge_opencode_mcp(path, manifest=copy.deepcopy(MANIFEST), **kwargs), path

    def read(self, path):
        return json.loads(path.read_text())

    def test_nothing_to_do_does_not_create_file(self):
        (changed, msg), path = self.merge()
        self.assertEqual((changed, msg), (False, "OK: opencode.json unchanged (idempotent)"))
        self.assertFalse(path.exists())

    def test_agentmemory_and_leanctx_projection(self):
        (changed, msg), path = self.merge(patch_agentmemory=True, patch_leanctx=True)
        self.assertEqual((changed, msg), (True, "OK: opencode.json merged atomically"))
        mcp = self.read(path)["mcp"]
        self.assertEqual(mcp["agentmemory"]["command"], ["/opt/five/agentmemory", "mcp"])
        self.assertEqual(mcp["agentmemory"]["environment"], {"AGENTMEMORY_URL": "http://localhost:3111"})
        self.assertEqual(mcp["leanctx"]["environment"], pm.LEANCTX_ENV_BASE)
        (changed, msg), _ = self.merge(patch_agentmemory=True, patch_leanctx=True)
        self.assertEqual((changed, msg), (False, "OK: opencode.json unchanged (idempotent)"))

    def test_context_mode_plugin_added_and_mcp_entry_removed(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcp": {"context-mode": {"type": "local"}, "user-context-mode": {}, "other": {"type": "local"}}}))
        (changed, _), _ = self.merge(patch_context_mode=True, patch_leanctx=True)
        self.assertTrue(changed)
        data = self.read(path)
        self.assertEqual(data["plugin"], ["context-mode"])
        self.assertEqual(set(data["mcp"]), {"other", "leanctx"})
        self.assertEqual(data["mcp"]["leanctx"]["environment"], pm.LEANCTX_ENV_CM_ACTIVE)

    def test_existing_plugin_is_canonicalised_without_consent(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"plugin": ["context-mode@1", "context-mode@2", "x"], "mcp": {}}))
        (changed, _), _ = self.merge(patch_agentmemory=False)
        self.assertTrue(changed)
        self.assertEqual(self.read(path)["plugin"], ["context-mode", "x"])

    def test_non_list_plugin_value_untouched_without_consent(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"plugin": "junk", "mcp": {}}))
        (changed, _), _ = self.merge()
        self.assertFalse(changed)
        self.assertEqual(self.read(path)["plugin"], "junk")

    def test_consent_keeps_existing_plugin_list(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"plugin": ["other"], "mcp": {}}))
        (changed, _), _ = self.merge(patch_context_mode=True)
        self.assertTrue(changed)
        self.assertEqual(self.read(path)["plugin"], ["other", "context-mode"])

    def test_mcp_entry_is_the_fallback_when_the_plugin_cannot_be_registered(self):
        # Defensive path: if the plugin helper leaves OpenCode without the
        # native plugin, Context Mode is still wired as a local MCP server.
        with mock.patch.object(pm, "opencode_ensure_context_mode_plugin", return_value=False):
            (changed, _), path = self.merge(patch_context_mode=True)
        self.assertTrue(changed)
        entry = self.read(path)["mcp"]["context-mode"]
        self.assertEqual(entry["command"], ["/opt/five/context-mode"])
        self.assertEqual(entry["type"], "local")

    def test_non_list_plugin_value_replaced_with_consent(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"plugin": "junk", "mcp": {}}))
        (changed, _), _ = self.merge(patch_context_mode=True)
        self.assertTrue(changed)
        self.assertEqual(self.read(path)["plugin"], ["context-mode"])

    def test_non_dict_mcp_is_reset(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcp": ["junk"]}))
        (changed, _), _ = self.merge(patch_agentmemory=True)
        self.assertTrue(changed)
        self.assertIn("agentmemory", self.read(path)["mcp"])

    def test_context_mode_mcp_entry_when_plugin_absent_but_consented_is_plugin(self):
        # consent adds the plugin, so no mcp.context-mode entry is created
        (changed, _), path = self.merge(patch_context_mode=True)
        self.assertTrue(changed)
        self.assertNotIn("context-mode", self.read(path)["mcp"])

    def test_legacy_context_mode_server_counts_as_active_for_leanctx_env(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcp": {"user-context-mode": {"type": "local"}}}))
        self.merge(patch_leanctx=True)
        self.assertEqual(self.read(path)["mcp"]["leanctx"]["environment"], pm.LEANCTX_ENV_CM_ACTIVE)

    def test_graphify_existing_entry_is_repaired(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcp": {"graphify": {"type": "local", "command": ["old"], "enabled": True}}}))
        (changed, _), _ = self.merge(patch_graphify=True)
        self.assertTrue(changed)
        self.assertEqual(self.read(path)["mcp"]["graphify"]["command"], ["/opt/five/graphify-mcp", "--stdio"])

    def test_graphify_missing_added_after_handshake(self):
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(True, None)):
            (changed, _), path = self.merge(patch_graphify=True)
        self.assertTrue(changed)
        self.assertIn("graphify", self.read(path)["mcp"])

    def test_graphify_missing_skipped_when_handshake_fails(self):
        err = io.StringIO()
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(False, "nope")), contextlib.redirect_stderr(err):
            (changed, _), path = self.merge(patch_graphify=True)
        self.assertFalse(changed)
        self.assertIn("WARN: graphify merge skipped: nope", err.getvalue())
        self.assertFalse(path.exists())

    def test_graphify_handshake_failure_without_reason_is_silent(self):
        err = io.StringIO()
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(False, None)), contextlib.redirect_stderr(err):
            (changed, _), _ = self.merge(patch_graphify=True)
        self.assertFalse(changed)
        self.assertEqual(err.getvalue(), "")

    def test_legacy_leanctx_aliases_collapse(self):
        path = self.home / ".config" / "opencode" / "opencode.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcp": {"lean-ctx": {"type": "local", "command": ["x"], "enabled": True}, "user-leanctx": {}}}))
        self.merge(patch_leanctx=True)
        mcp = self.read(path)["mcp"]
        self.assertEqual(set(mcp), {"leanctx"})
        self.assertEqual(mcp["leanctx"]["command"], ["/opt/five/lean-ctx", "serve"])


class PiAdapterTest(McpCase):
    def test_installs_through_the_pi_installer(self):
        pi_dir = self.root / "pi-agent"
        stack = self.root / "stack"
        os.environ["PI_CODING_AGENT_DIR"] = str(pi_dir)
        os.environ["SB_GLOBAL_TOOLSTACK_HOME"] = str(stack)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            ok, message = pm.install_pi_adapter(self.root, dry_run=True, enabled_tools={"rtk", "graphify"})
        self.assertTrue(ok)
        self.assertEqual(message, "OK: Pi five-tool adapter installed (graphify,rtk)")
        self.assertIn("DRY-RUN: would copy", out.getvalue())
        self.assertFalse(pi_dir.exists())

    def test_loader_failure(self):
        with mock.patch("importlib.util.spec_from_file_location", return_value=None):
            self.assertEqual(
                pm.install_pi_adapter(self.root, dry_run=True, enabled_tools=set()),
                (False, "ERROR: unable to load Pi adapter installer"),
            )

    def test_spec_without_loader(self):
        spec = mock.Mock(loader=None)
        with mock.patch("importlib.util.spec_from_file_location", return_value=spec):
            self.assertFalse(pm.install_pi_adapter(self.root, dry_run=True, enabled_tools=set())[0])


class MainJsonHostsTest(McpCase):
    def mcp_path(self, host):
        return self.home / (".claude.json" if host == "claude" else ".cursor/mcp.json")

    def test_no_flags(self):
        code, out, _ = self.run_main()
        self.assertEqual((code, out), (0, "OK: mcp.json unchanged (no patch flags)"))
        pm.ensure_global_instances.assert_not_called()

    def test_cursor_full_merge(self):
        self.flags(graphify=True, leanctx=True, agentmemory=True, context_mode=True)
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(True, None)):
            code, out, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(out, "OK: mcp.json merged atomically (graphify_added=True, leanctx_changed=True, agentmemory_added=True)")
        servers = json.loads(self.mcp_path("cursor").read_text())["mcpServers"]
        self.assertEqual(set(servers), {"graphify", "leanctx", "agentmemory", "context-mode"})
        self.assertEqual(servers["leanctx"]["env"], pm.LEANCTX_ENV_CM_ACTIVE)
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(True, None)):
            code, out, _ = self.run_main()
        self.assertEqual(out, "OK: mcp.json unchanged (idempotent)")

    def test_cursor_preserves_unrelated_servers(self):
        path = self.mcp_path("cursor")
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcpServers": {"mine": {"command": "x"}}, "other": 1}))
        self.flags(agentmemory=True)
        self.run_main()
        data = json.loads(path.read_text())
        self.assertEqual(data["other"], 1)
        self.assertIn("mine", data["mcpServers"])
        self.assertIn("agentmemory", data["mcpServers"])

    def test_graphify_skipped_when_handshake_fails(self):
        self.flags(graphify=True)
        with mock.patch.object(pm, "graphify_mcp_handshake", return_value=(False, "nope")):
            code, out, err = self.run_main()
        self.assertEqual(out, "OK: mcp.json unchanged (idempotent)")
        self.assertIn("graphify merge skipped", err)
        self.assertFalse(self.mcp_path("cursor").exists())

    def test_context_mode_aliases_normalised_even_without_context_mode_flag(self):
        path = self.mcp_path("cursor")
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mcpServers": {"user-context-mode": {"command": "old", "args": []}}}))
        self.flags(agentmemory=True)
        self.run_main()
        servers = json.loads(path.read_text())["mcpServers"]
        self.assertNotIn("user-context-mode", servers)
        self.assertEqual(servers["context-mode"]["command"], "/opt/five/context-mode")

    def test_claude_host_uses_dot_claude_json_and_disables_native_plugin(self):
        os.environ["RT_HOST"] = "claude"
        self.flags(context_mode=True)
        with mock.patch.object(pm, "disable_claude_native_context_mode", return_value=True) as disable:
            code, out, _ = self.run_main()
        disable.assert_called_once_with()
        self.assertEqual(code, 0)
        self.assertIn("context-mode", json.loads(self.mcp_path("claude").read_text())["mcpServers"])
        self.assertFalse(self.mcp_path("cursor").exists())

    def test_claude_host_without_context_mode_does_not_touch_plugin(self):
        os.environ["RT_HOST"] = "claude"
        self.flags(agentmemory=True)
        with mock.patch.object(pm, "disable_claude_native_context_mode") as disable:
            self.run_main()
        disable.assert_not_called()

    def test_claude_plugin_disable_failure_exits_2(self):
        os.environ["RT_HOST"] = "claude"
        self.flags(context_mode=True)
        with mock.patch.object(pm, "disable_claude_native_context_mode", side_effect=RuntimeError("claude CLI is unavailable")):
            code, out, err = self.run_main()
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertEqual(err, "ERROR: claude CLI is unavailable")
        self.assertFalse(self.mcp_path("claude").exists())

    def test_opencode_host(self):
        os.environ["RT_HOST"] = "opencode"
        self.flags(agentmemory=True)
        code, out, _ = self.run_main()
        self.assertEqual((code, out), (0, "OK: opencode.json merged atomically"))
        path = self.home / ".config" / "opencode" / "opencode.json"
        self.assertIn("agentmemory", json.loads(path.read_text())["mcp"])

    def test_pi_host_success(self):
        os.environ["RT_HOST"] = "pi"
        os.environ["TOOLSTACK_REPO_ROOT"] = str(self.root)
        self.flags(graphify=True, leanctx=True)
        with mock.patch.object(pm, "install_pi_adapter", return_value=(True, "OK: pi")) as install:
            code, out, _ = self.run_main()
        self.assertEqual((code, out), (0, "OK: pi"))
        args, kwargs = install.call_args
        self.assertEqual(args[0], self.root)
        self.assertFalse(kwargs["dry_run"])
        self.assertEqual(kwargs["enabled_tools"], {"graphify", "leanctx"})

    def test_pi_host_failure_exits_2(self):
        os.environ["RT_HOST"] = "pi"
        self.flags(agentmemory=True, context_mode=True)
        with mock.patch.object(pm, "install_pi_adapter", return_value=(False, "ERROR: x")) as install:
            code, out, err = self.run_main()
        self.assertEqual((code, out, err), (2, "", "ERROR: x"))
        self.assertEqual(install.call_args.kwargs["enabled_tools"], {"agentmemory", "context_mode"})
        self.assertEqual(install.call_args.args[0], Path.cwd())


if __name__ == "__main__":
    unittest.main()

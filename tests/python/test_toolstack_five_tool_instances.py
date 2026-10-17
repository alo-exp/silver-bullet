"""Unit tests for scripts/lib/global-toolstack/five_tool_instances.py and the
fix-shell-compression-hook.py compatibility shim."""

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from sbtest import load_module

fti = load_module("scripts/lib/global-toolstack/five_tool_instances.py")
shim = load_module("scripts/lib/global-toolstack/fix-shell-compression-hook.py")

BASE_ENV_KEYS = (
    "SB_GLOBAL_TOOLSTACK_HOME",
    "FIVE_TOOL_HOME",
    "FIVE_TOOL_TOOLSTACK_HOME",
    "XDG_DATA_HOME",
)


class IsolatedHome(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name).resolve()
        env = {k: v for k, v in os.environ.items() if not k.startswith(("SB_GLOBAL_", "FIVE_TOOL_"))}
        env["HOME"] = str(self.home)
        env.pop("XDG_DATA_HOME", None)
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        # Path.home() reads HOME on posix.


class AdapterEnvironmentTest(IsolatedHome):
    def test_legacy_command_name_is_translated(self):
        os.environ["SB_GLOBAL_GRAPHIFY_COMMAND"] = "/legacy/graphify"
        env = fti._adapter_environment()
        self.assertEqual(env["FIVE_TOOL_GRAPHIFY_COMMAND"], "/legacy/graphify")
        # the legacy name itself is left alone in the copy, not in os.environ
        self.assertNotIn("FIVE_TOOL_GRAPHIFY_COMMAND", os.environ)

    def test_generic_name_wins_over_legacy(self):
        os.environ["SB_GLOBAL_RTK_COMMAND"] = "/legacy/rtk"
        os.environ["FIVE_TOOL_RTK_COMMAND"] = "/generic/rtk"
        self.assertEqual(fti._adapter_environment()["FIVE_TOOL_RTK_COMMAND"], "/generic/rtk")

    def test_empty_legacy_value_is_ignored(self):
        os.environ["SB_GLOBAL_RTK_COMMAND"] = ""
        self.assertNotIn("FIVE_TOOL_RTK_COMMAND", fti._adapter_environment())


class HomeAndManifestPathTest(IsolatedHome):
    def test_override_home_used_for_home_and_manifest(self):
        os.environ["SB_GLOBAL_TOOLSTACK_HOME"] = str(self.home / "custom")
        self.assertEqual(fti._legacy_override_home(), self.home / "custom")
        self.assertEqual(fti.global_toolstack_home(), self.home / "custom")
        self.assertEqual(fti.global_instances_manifest_path(), self.home / "custom" / "instances.json")

    def test_whitespace_override_is_ignored_and_tilde_expanded(self):
        os.environ["SB_GLOBAL_TOOLSTACK_HOME"] = "   "
        self.assertIsNone(fti._legacy_override_home())
        os.environ["SB_GLOBAL_TOOLSTACK_HOME"] = "~/tilde-stack"
        self.assertEqual(fti._legacy_override_home(), self.home / "tilde-stack")

    def test_generic_root_without_override(self):
        home = fti.global_toolstack_home()
        manifest = fti.global_instances_manifest_path()
        self.assertTrue(str(home).startswith(str(self.home)))
        self.assertEqual(manifest.name, "manifest.json")
        self.assertEqual(manifest.parent, home)

    def test_legacy_manifest_location(self):
        self.assertEqual(
            fti._legacy_manifest_path(), self.home / ".silver-bullet" / "five-tool-stack" / "instances.json"
        )


class ClaudeContextModeTest(IsolatedHome):
    def write_settings(self, payload):
        path = self.home / ".claude" / "settings.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload if isinstance(payload, str) else json.dumps(payload), encoding="utf-8")

    def test_missing_settings(self):
        self.assertFalse(fti.claude_native_context_mode_enabled())

    def test_invalid_json(self):
        self.write_settings("{not json")
        self.assertFalse(fti.claude_native_context_mode_enabled())

    def test_non_dict_json(self):
        self.write_settings("[1, 2]")
        self.assertFalse(fti.claude_native_context_mode_enabled())

    def test_enabled_plugins_not_a_dict(self):
        self.write_settings({"enabledPlugins": ["context-mode@context-mode"]})
        self.assertFalse(fti.claude_native_context_mode_enabled())

    def test_plugin_must_be_exactly_true(self):
        self.write_settings({"enabledPlugins": {fti.CLAUDE_CONTEXT_MODE_PLUGIN: "yes"}})
        self.assertFalse(fti.claude_native_context_mode_enabled())
        self.write_settings({"enabledPlugins": {fti.CLAUDE_CONTEXT_MODE_PLUGIN: False}})
        self.assertFalse(fti.claude_native_context_mode_enabled())

    def test_enabled(self):
        self.write_settings({"enabledPlugins": {fti.CLAUDE_CONTEXT_MODE_PLUGIN: True}})
        self.assertTrue(fti.claude_native_context_mode_enabled())

    def test_explicit_home_argument(self):
        other = self.home / "other"
        (other / ".claude").mkdir(parents=True)
        (other / ".claude" / "settings.json").write_text(
            json.dumps({"enabledPlugins": {fti.CLAUDE_CONTEXT_MODE_PLUGIN: True}}), encoding="utf-8"
        )
        self.assertTrue(fti.claude_native_context_mode_enabled(other))
        self.assertFalse(fti.claude_native_context_mode_enabled())

    def enable(self):
        self.write_settings({"enabledPlugins": {fti.CLAUDE_CONTEXT_MODE_PLUGIN: True}})

    def test_disable_noop_when_not_enabled(self):
        with mock.patch.object(fti.subprocess, "run") as run:
            self.assertFalse(fti.disable_claude_native_context_mode())
        run.assert_not_called()

    def test_disable_dry_run_reports_without_running(self):
        self.enable()
        with mock.patch.object(fti.subprocess, "run") as run:
            self.assertTrue(fti.disable_claude_native_context_mode(dry_run=True))
        run.assert_not_called()

    def test_disable_requires_claude_cli(self):
        self.enable()
        with mock.patch.object(fti.shutil, "which", return_value=None), mock.patch.object(fti.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "claude CLI is unavailable"):
                fti.disable_claude_native_context_mode()
        run.assert_not_called()

    def test_disable_runs_claude_plugin_disable(self):
        self.enable()
        done = subprocess.CompletedProcess([], 0, stdout=None, stderr="")
        with mock.patch.object(fti.shutil, "which", return_value="/bin/claude"), mock.patch.object(
            fti.subprocess, "run", return_value=done
        ) as run:
            self.assertTrue(fti.disable_claude_native_context_mode())
        self.assertEqual(
            run.call_args.args[0],
            ["/bin/claude", "plugin", "disable", fti.CLAUDE_CONTEXT_MODE_PLUGIN, "--scope", "user"],
        )
        self.assertIs(run.call_args.kwargs["check"], False)

    def test_disable_failure_reports_last_stderr_line(self):
        self.enable()
        failed = subprocess.CompletedProcess([], 1, stdout=None, stderr="warn\nreal reason\n")
        with mock.patch.object(fti.shutil, "which", return_value="/bin/claude"), mock.patch.object(
            fti.subprocess, "run", return_value=failed
        ):
            with self.assertRaises(RuntimeError) as ctx:
                fti.disable_claude_native_context_mode()
        self.assertEqual(str(ctx.exception), "failed to disable context-mode@context-mode: real reason")

    def test_disable_failure_without_stderr(self):
        self.enable()
        for stderr in ("", None):
            failed = subprocess.CompletedProcess([], 2, stdout=None, stderr=stderr)
            with mock.patch.object(fti.shutil, "which", return_value="/bin/claude"), mock.patch.object(
                fti.subprocess, "run", return_value=failed
            ):
                with self.assertRaises(RuntimeError) as ctx:
                    fti.disable_claude_native_context_mode()
            self.assertEqual(str(ctx.exception), "failed to disable context-mode@context-mode")


class EnsureInstancesTest(IsolatedHome):
    def fake_bins(self):
        bindir = self.home / "bin"
        bindir.mkdir()
        for name in ("graphify-mcp", "agentmemory", "context-mode", "lean-ctx", "rtk"):
            path = bindir / name
            path.write_text("#!/bin/sh\nexit 0\n")
            path.chmod(0o755)
        os.environ["PATH"] = str(bindir) + os.pathsep + os.environ.get("PATH", "")
        return bindir

    def test_override_home_writes_manifest_without_legacy_migration(self):
        self.fake_bins()
        stack = self.home / "stack"
        os.environ["SB_GLOBAL_TOOLSTACK_HOME"] = str(stack)
        legacy = fti._legacy_manifest_path()
        legacy.parent.mkdir(parents=True)
        legacy.write_text(json.dumps({"tools": {"rtk": {"command": "/legacy/rtk", "args": []}}}))
        result = fti.ensure_global_instances()
        self.assertTrue((stack / "instances.json").is_file())
        self.assertEqual(result["_result"]["path"], str(stack / "instances.json"))
        self.assertTrue(result["_result"]["changed"])
        self.assertFalse(result["_result"]["migrated"])
        self.assertIn("graphify", result["tools"])

    def test_dry_run_does_not_write(self):
        self.fake_bins()
        stack = self.home / "stack2"
        os.environ["SB_GLOBAL_TOOLSTACK_HOME"] = str(stack)
        result = fti.ensure_global_instances(dry_run=True)
        self.assertTrue(result["_result"]["changed"])
        self.assertFalse((stack / "instances.json").exists())

    def test_without_override_legacy_manifest_is_consulted(self):
        self.fake_bins()
        legacy = fti._legacy_manifest_path()
        legacy.parent.mkdir(parents=True)
        legacy.write_text(json.dumps({"schema": "v1", "tools": {}}))
        result = fti.ensure_global_instances(dry_run=True)
        self.assertTrue(result["_result"]["migrated"])
        self.assertEqual(result["_result"]["path"], str(fti.global_instances_manifest_path()))

    def test_legacy_env_command_is_honoured(self):
        bindir = self.fake_bins()
        os.environ["SB_GLOBAL_RTK_COMMAND"] = str(bindir / "rtk")
        manifest = fti.ensure_global_instances(dry_run=True)
        self.assertEqual(fti.tool_command(manifest, "rtk"), str((bindir / "rtk").resolve()))

    def test_tool_accessors(self):
        manifest = {"tools": {"rtk": {"command": "/x/rtk", "args": ["a"], "env": {"K": "V"}}}}
        spec = fti.tool_spec(manifest, "rtk")
        self.assertEqual(spec["command"], "/x/rtk")
        self.assertEqual(spec["args"], ["a"])
        self.assertEqual(fti.tool_command(manifest, "rtk"), "/x/rtk")
        self.assertEqual(fti.mcp_server_spec(manifest, "rtk"), spec)
        with self.assertRaises(KeyError):
            fti.tool_spec(manifest, "graphify")


class ShimTest(unittest.TestCase):
    def test_main_prints_delegation_notice(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.assertEqual(shim.main(), 0)
        self.assertEqual(buf.getvalue().strip(), "delegated to patch-hooks via reconciler")

    def test_script_exit_code(self):
        res = subprocess.run(
            [sys.executable, str(Path(shim.__file__))], capture_output=True, text=True, check=False
        )
        self.assertEqual(res.returncode, 0)
        self.assertEqual(res.stdout.strip(), "delegated to patch-hooks via reconciler")


if __name__ == "__main__":
    unittest.main()

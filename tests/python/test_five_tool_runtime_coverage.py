"""Unit tests for scripts/lib/five_tool_runtime/{runtime,projections,cli}.py.

Complements tests/scripts/test-generic-five-tool-runtime.sh with the branches
that script does not reach: platform data-root selection, Homebrew Cellar path
stabilisation, atomic-write failure handling, manifest validation errors,
Windows launchers, projection invariants and the standalone CLI.
"""

import io
import json
import os
import stat
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT

LIB = str(REPO_ROOT / "scripts" / "lib")
if LIB not in sys.path:
    sys.path.insert(0, LIB)

from five_tool_runtime import cli, projections, runtime  # noqa: E402


def _fake_tools(root: Path) -> Path:
    """Create executable stand-ins for every tool launcher in root/bin."""
    bin_dir = root / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    for definition in runtime.TOOL_DEFINITIONS.values():
        path = bin_dir / definition["executable"]
        path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        path.chmod(0o755)
    return bin_dir


def _manifest(root: Path) -> dict:
    bin_dir = _fake_tools(root)
    env = {"PATH": str(bin_dir)}
    with mock.patch.dict(os.environ, {"PATH": str(bin_dir)}):
        return runtime.ensure_manifest(
            manifest_path=root / "m.json", env=env, dry_run=True
        )


class GlobalHomeTests(unittest.TestCase):
    def test_override_wins_and_is_expanded(self):
        got = runtime.global_toolstack_home(
            {"FIVE_TOOL_STACK_HOME": " ~/custom ", "XDG_STATE_HOME": "/x"},
            home=Path("/h"),
        )
        self.assertEqual(got, Path("~/custom").expanduser())

    def test_xdg_state_then_xdg_data_then_default(self):
        home = Path("/h")
        self.assertEqual(
            runtime.global_toolstack_home({"XDG_STATE_HOME": "/s"}, home, "linux"),
            Path("/s/five-tool-stack"),
        )
        self.assertEqual(
            runtime.global_toolstack_home({"XDG_DATA_HOME": "/d"}, home, "linux"),
            Path("/d/five-tool-stack"),
        )
        self.assertEqual(
            runtime.global_toolstack_home({}, home, "darwin"),
            Path("/h/.local/state/five-tool-stack"),
        )

    def test_non_string_env_value_is_ignored(self):
        got = runtime.global_toolstack_home(
            {"FIVE_TOOL_STACK_HOME": 5}, Path("/h"), "linux"  # type: ignore[dict-item]
        )
        self.assertEqual(got, Path("/h/.local/state/five-tool-stack"))

    def test_windows_roots(self):
        home = Path("/h")
        self.assertEqual(
            runtime.global_toolstack_home({"LOCALAPPDATA": "/L", "APPDATA": "/A"}, home, "win32"),
            Path("/L/five-tool-stack"),
        )
        self.assertEqual(
            runtime.global_toolstack_home({"APPDATA": "/A"}, home, "cygwin"),
            Path("/A/five-tool-stack"),
        )
        self.assertEqual(
            runtime.global_toolstack_home({}, home, "msys"),
            Path("/h/AppData/Local/five-tool-stack"),
        )

    def test_canonical_manifest_path(self):
        got = runtime.canonical_manifest_path({"FIVE_TOOL_STACK_HOME": "/r"})
        self.assertEqual(got, Path("/r/manifest.json"))


class StablePathTests(unittest.TestCase):
    def test_plain_path_is_resolved(self):
        with tempfile.TemporaryDirectory() as tmp:
            real = Path(tmp, "real")
            real.write_text("x")
            link = Path(tmp, "link")
            link.symlink_to(real)
            self.assertEqual(runtime._stable_path(link), str(real.resolve()))

    def test_cellar_real_with_non_cellar_link_records_the_link(self):
        with tempfile.TemporaryDirectory() as tmp:
            keg = Path(tmp, "Cellar", "f", "1.0", "bin")
            keg.mkdir(parents=True)
            real = keg / "tool"
            real.write_text("x")
            link = Path(tmp, "bin", "tool")
            link.parent.mkdir()
            link.symlink_to(real)
            self.assertEqual(runtime._stable_path(link), str(link.absolute()))

    def test_cellar_path_uses_which_when_it_points_at_the_same_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            real = Path(tmp, "Cellar", "f", "1.0", "tool")
            real.parent.mkdir(parents=True)
            real.write_text("x")
            stable = Path(tmp, "stable", "tool")
            stable.parent.mkdir()
            stable.symlink_to(real)
            with mock.patch.object(runtime.shutil, "which", return_value=str(stable)):
                self.assertEqual(runtime._stable_path(real), str(stable))

    def test_cellar_path_falls_back_to_real_when_which_differs(self):
        with tempfile.TemporaryDirectory() as tmp:
            real = Path(tmp, "Cellar", "f", "1.0", "tool")
            real.parent.mkdir(parents=True)
            real.write_text("x")
            other = Path(tmp, "other")
            other.write_text("y")
            for which in (None, str(other)):
                with mock.patch.object(runtime.shutil, "which", return_value=which):
                    self.assertEqual(runtime._stable_path(real), str(real.resolve()))


class CandidateTests(unittest.TestCase):
    def test_resolve_candidate_empty_file_which_and_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = _fake_tools(Path(tmp))
            self.assertIsNone(runtime._resolve_candidate(""))
            exe = bin_dir / "rtk"
            self.assertEqual(runtime._resolve_candidate(str(exe)), str(exe.resolve()))
            with mock.patch.dict(os.environ, {"PATH": str(bin_dir)}):
                self.assertEqual(runtime._resolve_candidate("rtk"), str(exe.resolve()))
                self.assertIsNone(runtime._resolve_candidate("definitely-not-a-tool"))

    def test_select_command_falls_back_to_unresolved_expected_candidate(self):
        env = {"FIVE_TOOL_RTK_COMMAND": "/nonexistent/dir/rtk"}
        with mock.patch.dict(os.environ, {"PATH": "/nonexistent"}):
            self.assertEqual(runtime._select_command("rtk", {}, env), "/nonexistent/dir/rtk")

    def test_select_command_falls_back_to_bare_executable(self):
        env = {"FIVE_TOOL_RTK_COMMAND": "/nonexistent/dir/wrong-name"}
        with mock.patch.dict(os.environ, {"PATH": "/nonexistent"}):
            # No override or prior command qualifies: the bare executable name is returned.
            self.assertEqual(runtime._select_command("rtk", {}, env), "rtk")

    def test_entrypoint_helpers(self):
        self.assertTrue(runtime._expected_entrypoint("context_mode", "/g/cli.bundle.mjs"))
        self.assertTrue(runtime._expected_entrypoint("agentmemory", "/g/cli.js".replace(".js", "")))
        self.assertFalse(runtime._expected_entrypoint("rtk", "/h/.claude/rtk"))
        self.assertFalse(runtime._expected_entrypoint("rtk", "/h/.config/opencode/rtk"))
        self.assertFalse(runtime._expected_entrypoint("nope", "/g/rtk"))
        self.assertFalse(runtime._expected_entrypoint("rtk", ""))
        self.assertEqual(runtime._entrypoint_name("C:\\bin\\RTK.EXE"), "rtk")

    def test_legacy_entry_and_prior_env_merge(self):
        self.assertEqual(runtime._legacy_tool_entry({"tools": []}, "rtk"), {})
        legacy = {"tools": {"agentmemory": {"env": {"AGENTMEMORY_URL": "http://x", "N": 1}, "version": "9"}}}
        item = runtime._normalise_tool("agentmemory", legacy, {}, {})
        self.assertEqual(item["env"]["AGENTMEMORY_URL"], "http://x")
        self.assertEqual(item["env"]["N"], "1")
        self.assertEqual(item["version"], "9")


class AtomicWriteTests(unittest.TestCase):
    def test_chmod_failures_are_tolerated_and_file_is_written(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp, "sub", "m.json")
            with mock.patch.object(Path, "chmod", side_effect=OSError("nope")):
                runtime._atomic_write(target, {"a": 1})
            self.assertEqual(json.loads(target.read_text()), {"a": 1})
            self.assertEqual([p.name for p in target.parent.iterdir()], ["m.json"])

    def test_private_permissions_on_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp, "d", "m.json")
            runtime._atomic_write(target, {"a": 1})
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)

    def test_temp_file_removed_when_replace_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp, "m.json")
            with mock.patch.object(Path, "replace", side_effect=OSError("boom")):
                with self.assertRaises(OSError):
                    runtime._atomic_write(target, {"a": 1})
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_unlink_failure_during_cleanup_is_swallowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp, "m.json")
            with mock.patch.object(Path, "replace", side_effect=OSError("boom")), \
                    mock.patch.object(Path, "unlink", side_effect=OSError("stuck")):
                with self.assertRaises(OSError) as ctx:
                    runtime._atomic_write(target, {"a": 1})
            self.assertEqual(str(ctx.exception), "boom")


class ValidateManifestTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.manifest = _manifest(self.root)
        self.manifest.pop("_result", None)
        patcher = mock.patch.dict(os.environ, {"PATH": str(self.root / "bin")})
        patcher.start()
        self.addCleanup(patcher.stop)

    def errors(self, manifest=None, **kw):
        return runtime.validate_manifest(self.manifest if manifest is None else manifest, **kw)["errors"]

    def test_valid_manifest(self):
        result = runtime.validate_manifest(self.manifest, require_commands=True)
        self.assertEqual(result["errors"], [])
        self.assertTrue(result["valid"])
        self.assertEqual(result["tools"], 5)

    def test_empty_manifest_reports_everything(self):
        errs = self.errors({})
        for expected in (
            "schema must be five-tool-stack/v1",
            "scope must be user-global",
            "tools must be an object",
            "missing tool: rtk",
            "hosts are missing",
            "coordination rules are missing",
        ):
            self.assertIn(expected, errs)

    def test_per_tool_errors(self):
        m = json.loads(json.dumps(self.manifest))
        tools = m["tools"]
        tools["graphify"]["command"] = ""
        tools["agentmemory"]["command"] = "/x/not-agentmemory"
        tools["rtk"]["transport"] = "stdio"
        tools["rtk"]["args"] = "x"
        tools["rtk"]["env"] = []
        tools["rtk"]["identity"] = "x"
        tools["rtk"]["capabilities"] = None
        tools["leanctx"]["identity"] = {"name": "other", "package": "p"}
        tools["context_mode"]["identity"] = {"name": "context_mode", "package": ""}
        errs = self.errors(m)
        for expected in (
            "graphify command is missing",
            "agentmemory command is not a global entrypoint: /x/not-agentmemory",
            "rtk transport is incorrect",
            "rtk args are missing",
            "rtk env is missing",
            "rtk identity is missing",
            "rtk capabilities are missing",
            "leanctx identity is malformed",
            "context_mode identity is malformed",
        ):
            self.assertIn(expected, errs)

    def test_unavailable_command_is_error_when_required_else_warning(self):
        m = json.loads(json.dumps(self.manifest))
        m["tools"]["rtk"]["command"] = "/nonexistent/rtk"
        strict = runtime.validate_manifest(m, require_commands=True)
        self.assertIn("rtk command is unavailable: /nonexistent/rtk", strict["errors"])
        lax = runtime.validate_manifest(m)
        self.assertEqual(lax["errors"], [])
        self.assertEqual(lax["warnings"], ["rtk command is unavailable: /nonexistent/rtk"])

    def test_host_and_coordination_errors(self):
        m = json.loads(json.dumps(self.manifest))
        del m["hosts"]["pi"]
        m["coordination"] = {"rtk_rewrite": "double", "context_mode": []}
        errs = self.errors(m)
        self.assertIn("missing host projection: pi", errs)
        self.assertIn("one-global-instance rule is missing", errs)
        self.assertIn("RTK rewrite rule must be single", errs)
        self.assertIn("Context Mode mutual-exclusion rule is missing", errs)


class EnsureAndInspectTests(unittest.TestCase):
    def test_install_is_idempotent_and_migrates_legacy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = _fake_tools(root)
            env = {"PATH": str(bin_dir)}
            legacy = root / "legacy.json"
            legacy.write_text(json.dumps({"tools": {"rtk": {"version": "1.2"}}}))
            manifest_path = root / "state" / "manifest.json"
            with mock.patch.dict(os.environ, {"PATH": str(bin_dir)}):
                first = runtime.ensure_manifest(
                    manifest_path=manifest_path, legacy_manifest_path=legacy, env=env
                )
                self.assertTrue(first["_result"]["changed"])
                self.assertTrue(first["_result"]["migrated"])
                self.assertEqual(first["tools"]["rtk"]["version"], "1.2")
                self.assertEqual(first["migration"], {"source": "legacy", "completed": True})
                second = runtime.repair_manifest(
                    manifest_path=manifest_path, legacy_manifest_path=legacy, env=env
                )
                # The migration marker is only emitted on the run that migrated,
                # so the next run rewrites once to drop it; after that it is stable.
                self.assertTrue(second["_result"]["changed"])
                self.assertFalse(second["_result"]["migrated"])
                self.assertNotIn("migration", second)
                third = runtime.repair_manifest(
                    manifest_path=manifest_path, legacy_manifest_path=legacy, env=env
                )
                self.assertFalse(third["_result"]["changed"])

    def test_dry_run_and_canonical_default_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"FIVE_TOOL_STACK_HOME": tmp}
            result = runtime.ensure_manifest(env=env, dry_run=True)
            self.assertEqual(result["_result"]["path"], str(Path(tmp, "manifest.json")))
            self.assertTrue(result["_result"]["changed"])
            self.assertFalse(Path(tmp, "manifest.json").exists())

    def test_empty_or_missing_legacy_is_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            legacy = Path(tmp, "legacy.json")
            legacy.write_text("[1]")
            for leg in (legacy, Path(tmp, "absent.json")):
                result = runtime.ensure_manifest(
                    manifest_path=Path(tmp, "m.json"), legacy_manifest_path=leg,
                    env={}, dry_run=True,
                )
                self.assertFalse(result["_result"]["migrated"])

    def test_inspect_manifest_present_and_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            absent = runtime.inspect_manifest(manifest_path=Path(tmp, "no.json"))
            self.assertFalse(absent["present"])
            self.assertFalse(absent["valid"])
            self.assertEqual(absent["manifest"], {})
            runtime.ensure_manifest(manifest_path=Path(tmp, "m.json"), env={})
            present = runtime.inspect_manifest(manifest_path=Path(tmp, "m.json"))
            self.assertTrue(present["present"])
            self.assertTrue(present["valid"])
            via_env = runtime.inspect_manifest(env={"FIVE_TOOL_STACK_HOME": tmp})
            self.assertEqual(via_env["path"], str(Path(tmp, "manifest.json")))

    def test_load_manifest_rejects_malformed_and_non_object(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp, "bad.json")
            bad.write_text("{")
            arr = Path(tmp, "arr.json")
            arr.write_text("[]")
            self.assertEqual(runtime.load_manifest(bad), {})
            self.assertEqual(runtime.load_manifest(arr), {})
            self.assertEqual(runtime.load_manifest(Path(tmp, "none.json")), {})


class LaunchTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.manifest = _manifest(Path(self._tmp.name))

    def test_launch_spec_missing_tool_raises(self):
        for bad in ({}, {"tools": []}, {"tools": {"rtk": []}}, {"tools": {"rtk": {"command": 3}}}):
            with self.assertRaises(KeyError):
                runtime.launch_spec(bad, "rtk")

    def test_launch_spec_tolerates_odd_env(self):
        spec = runtime.launch_spec({"tools": {"rtk": {"command": "rtk", "env": "x"}}}, "rtk")
        self.assertEqual(spec["env"], {})
        self.assertEqual(spec["args"], [])

    def test_launch_argv_windows_wrappers(self):
        def argv(command, platform_name):
            m = {"tools": {"rtk": {"command": command, "args": ["a"]}}}
            return runtime.launch_argv(m, "rtk", platform_name)

        self.assertEqual(
            argv("C:\\x\\rtk.ps1", "win32"),
            ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\x\\rtk.ps1", "a"],
        )
        self.assertEqual(argv("C:\\x\\rtk.CMD", "win32"), ["cmd.exe", "/d", "/c", "C:\\x\\rtk.CMD", "a"])
        self.assertEqual(argv("C:\\x\\rtk.bat", "cygwin"), ["cmd.exe", "/d", "/c", "C:\\x\\rtk.bat", "a"])
        self.assertEqual(argv("C:\\x\\rtk.exe", "win32"), ["C:\\x\\rtk.exe", "a"])
        self.assertEqual(argv("/x/rtk.cmd", "linux"), ["/x/rtk.cmd", "a"])

    def test_merged_environment(self):
        got = runtime.merged_environment({"A": "1"}, self.manifest, "agentmemory")
        self.assertEqual(got["A"], "1")
        self.assertEqual(got["AGENTMEMORY_URL"], "http://localhost:3111")
        self.assertEqual(runtime.merged_environment(None, self.manifest, "rtk"), {})

    def test_duplicate_registration_names(self):
        self.assertEqual(runtime.duplicate_registration_names(["a", "b", "a", "a", "b"]), ("a", "b"))
        self.assertEqual(runtime.duplicate_registration_names([]), ())


class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.manifest = _manifest(Path(self._tmp.name))

    def test_mcp_entries_include_env_only_when_present(self):
        entries = projections.mcp_server_entries(self.manifest)
        self.assertEqual(sorted(entries), ["agentmemory", "context-mode", "graphify", "leanctx"])
        self.assertEqual(entries["agentmemory"]["env"], {"AGENTMEMORY_URL": "http://localhost:3111"})
        self.assertNotIn("env", entries["graphify"])
        native = projections.mcp_server_entries(self.manifest, native_context_mode=True)
        self.assertNotIn("context-mode", native)

    def test_opencode_plugin_reference(self):
        self.assertIsNone(projections.opencode_plugin_reference(self.manifest))
        m = json.loads(json.dumps(self.manifest))
        m["tools"]["context_mode"]["command"] = "/g/ctx/cli.bundle.mjs"
        self.assertEqual(
            projections.opencode_plugin_reference(m),
            "file:///g/ctx/build/adapters/opencode/plugin.js",
        )
        proj = projections.project_host(m, "opencode")
        self.assertEqual(proj["plugin"], ["file:///g/ctx/build/adapters/opencode/plugin.js"])
        self.assertTrue(proj["rules"]["contextModeNative"])
        self.assertFalse(proj["rules"]["contextModeMcpPresent"])
        no_plugin = projections.project_host(self.manifest, "opencode")
        self.assertEqual(no_plugin["plugin"], [])

    def test_pi_entries_disable_rtk_and_respect_selection(self):
        entries = projections.pi_server_entries(self.manifest, ["rtk", "graphify"])
        self.assertTrue(entries["graphify"]["enabled"])
        self.assertFalse(entries["leanctx"]["enabled"])
        self.assertFalse(entries["rtk"]["enabled"], "RTK must stay the single disabled rewrite owner")
        everything = projections.pi_server_entries(self.manifest)
        self.assertTrue(all(v["enabled"] for k, v in everything.items() if k != "rtk"))
        proj = projections.project_host(self.manifest, "pi", enabled_tools=["graphify"])
        self.assertEqual(proj["kind"], "extension")
        self.assertTrue(proj["servers"]["graphify"]["enabled"])

    def test_project_host_unknown_and_standard(self):
        with self.assertRaises(ValueError):
            projections.project_host(self.manifest, "emacs")
        claude = projections.project_host(self.manifest, "claude")
        self.assertNotIn("plugin", claude)
        self.assertNotIn("servers", claude)
        self.assertTrue(claude["rules"]["contextModeMcpPresent"])
        self.assertEqual(projections.validate_projection(claude), {"valid": True, "errors": []})

    def test_validate_projection_errors(self):
        class Dup(dict):
            def keys(self):
                return ["a", "a"]

        bad = {
            "mcpServers": Dup({"a": 1}),
            "rules": {"contextModeNative": True, "contextModeMcpPresent": True, "rtkRewriteOwner": "other"},
        }
        result = projections.validate_projection(bad)
        self.assertFalse(result["valid"])
        self.assertEqual(
            result["errors"],
            [
                "duplicate MCP registrations: a",
                "native Context Mode and MCP Context Mode both enabled",
                "RTK rewrite owner is not rtk",
            ],
        )
        # Missing rules/servers are tolerated (no rules dict => no rule errors).
        self.assertEqual(projections.validate_projection({}), {"valid": True, "errors": []})


class CliTests(unittest.TestCase):
    def run_cli(self, *argv):
        out = io.StringIO()
        with redirect_stdout(out):
            code = cli.main(list(argv))
        return code, json.loads(out.getvalue())

    def test_install_repair_inspect_cycle(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = _fake_tools(Path(tmp))
            manifest = str(Path(tmp, "m.json"))
            with mock.patch.dict(os.environ, {"PATH": str(bin_dir)}):
                code, out = self.run_cli("install", "--manifest", manifest)
                self.assertEqual(code, 0)
                self.assertTrue(out["_result"]["changed"])
                code, out = self.run_cli("repair", "--manifest", manifest)
                self.assertEqual(code, 0)
                self.assertFalse(out["_result"]["changed"])
                code, out = self.run_cli("inspect", "--manifest", manifest)
                self.assertEqual(code, 0)
                self.assertTrue(out["present"])
                code, out = self.run_cli("validate", "--manifest", manifest)
                self.assertEqual(code, 0)

    def test_dry_run_install_does_not_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp, "m.json")
            code, out = self.run_cli("install", "--manifest", str(manifest), "--dry-run",
                                     "--platform", "linux", "--home", tmp)
            self.assertEqual(code, 0)
            self.assertFalse(manifest.exists())

    def test_inspect_missing_manifest_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, out = self.run_cli("inspect", "--manifest", str(Path(tmp, "none.json")))
            self.assertEqual(code, 1)
            self.assertFalse(out["valid"])

    def test_invalid_install_result_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = {"_result": {"validation": {"valid": False}}}
            with mock.patch.object(cli, "ensure_manifest", return_value=bad):
                code, _ = self.run_cli("install", "--manifest", str(Path(tmp, "m.json")))
            self.assertEqual(code, 1)

    def test_missing_subcommand_is_a_usage_error(self):
        with self.assertRaises(SystemExit) as ctx, mock.patch("sys.stderr", io.StringIO()):
            cli.main([])
        self.assertEqual(ctx.exception.code, 2)

    def test_module_main_guard(self):
        import runpy

        with tempfile.TemporaryDirectory() as tmp:
            out = io.StringIO()
            argv = ["cli.py", "inspect", "--manifest", str(Path(tmp, "none.json"))]
            pkg_dir = str(REPO_ROOT / "scripts/lib/five_tool_runtime")
            with mock.patch.object(sys, "argv", argv), redirect_stdout(out), \
                    mock.patch.object(sys, "path", [pkg_dir] + sys.path):
                with self.assertRaises(SystemExit) as ctx:
                    runpy.run_path(str(REPO_ROOT / "scripts/lib/five_tool_runtime/cli.py"), run_name="__main__")
            self.assertEqual(ctx.exception.code, 1)
            self.assertFalse(json.loads(out.getvalue())["valid"])


if __name__ == "__main__":
    unittest.main()

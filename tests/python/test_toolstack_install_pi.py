"""Unit tests for scripts/lib/global-toolstack/install-pi.py (Pi adapter installer)."""

import contextlib
import io
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

pi = load_module("scripts/lib/global-toolstack/install-pi.py")

MANIFEST = {"tools": {"leanctx": {"command": "/opt/lean-ctx", "args": []}}}


class PiCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.agent = self.root / "agent"
        env = {k: v for k, v in os.environ.items() if k != "PI_CODING_AGENT_DIR"}
        env["HOME"] = str(self.root / "home")
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.manifest_path = self.root / "manifest.json"
        for name, value in (
            ("ensure_global_instances", mock.Mock(return_value=MANIFEST)),
            ("global_instances_manifest_path", mock.Mock(return_value=self.manifest_path)),
        ):
            p = mock.patch.object(pi, name, value)
            p.start()
            self.addCleanup(p.stop)

    def use_agent_dir(self):
        os.environ["PI_CODING_AGENT_DIR"] = str(self.agent)

    def read(self, rel):
        return json.loads((self.agent / rel).read_text(encoding="utf-8"))

    def run_install(self, **kwargs):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            result = pi.install(
                self.root,
                kwargs.pop("dry_run", False),
                kwargs.pop("enabled_tools", None),
                allow_package_install=kwargs.pop("allow_package_install", False),
            )
        return result, out.getvalue()


class WriteJsonTest(PiCase):
    def test_dry_run_only_announces(self):
        target = self.root / "sub" / "f.json"
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            pi.write_json(target, {"a": 1}, True)
        self.assertEqual(out.getvalue().strip(), f"DRY-RUN: would write {target}")
        self.assertFalse(target.parent.exists())

    def test_writes_atomically_with_private_mode(self):
        target = self.root / "deep" / "dir" / "f.json"
        pi.write_json(target, {"a": 1}, False)
        self.assertEqual(json.loads(target.read_text()), {"a": 1})
        self.assertTrue(target.read_text().endswith("\n"))
        self.assertEqual([p.name for p in target.parent.iterdir()], ["f.json"])

    def test_new_files_are_private_under_the_installer_umask_and_existing_modes_kept(self):
        old = os.umask(0o077)
        try:
            target = self.root / "private.json"
            pi.write_json(target, {"a": 1}, False)
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        finally:
            os.umask(old)
        target.chmod(0o640)
        pi.write_json(target, {"a": 2}, False)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o640)
        self.assertEqual(json.loads(Path(str(target) + ".sb-backup").read_text()), {"a": 1})

    def test_symlinked_settings_stay_symlinks(self):
        real = self.root / "dotfiles" / "settings.json"
        real.parent.mkdir()
        real.write_text("{}")
        link = self.root / "settings.json"
        link.symlink_to(real)
        pi.write_json(link, {"a": 1}, False)
        self.assertTrue(link.is_symlink())
        self.assertEqual(json.loads(real.read_text()), {"a": 1})


class LoadJsonTest(PiCase):
    def test_missing(self):
        self.assertEqual(pi.load_json(self.root / "nope.json"), {})

    def test_invalid_is_refused_not_replaced_by_an_empty_object(self):
        p = self.root / "bad.json"
        p.write_text("{oops")
        with self.assertRaises(pi.sbc.ConfigError):
            pi.load_json(p)

    def test_non_object_is_refused(self):
        p = self.root / "list.json"
        p.write_text("[1]")
        with self.assertRaises(pi.sbc.ConfigError):
            pi.load_json(p)

    def test_valid_object(self):
        p = self.root / "ok.json"
        p.write_text('{"a": 1}')
        self.assertEqual(pi.load_json(p), {"a": 1})


class AddUniqueTest(unittest.TestCase):
    def test_add_and_duplicate(self):
        items = ["a"]
        self.assertTrue(pi.add_unique(items, "b"))
        self.assertFalse(pi.add_unique(items, "a"))
        self.assertEqual(items, ["a", "b"])


class LeanctxConfigTest(PiCase):
    def test_creates_config(self):
        path = self.root / "lean" / "config.json"
        self.assertTrue(pi.update_pi_leanctx_config(path, MANIFEST, False))
        data = json.loads(path.read_text())
        self.assertEqual(data["mode"], "additive")
        self.assertIs(data["routeShell"], False)
        self.assertIs(data["enableMcp"], True)
        self.assertEqual(data["binary"], "/opt/lean-ctx")
        self.assertEqual(data["env"]["LEANCTX_DISABLE_SHELL_MCP"], "1")
        self.assertEqual(data["disableTools"], ["ctx_shell"])
        self.assertEqual(data["toolPrefix"], "lctx_")

    def test_second_run_is_idempotent(self):
        path = self.root / "lean" / "config.json"
        pi.update_pi_leanctx_config(path, MANIFEST, False)
        before = path.read_text()
        self.assertFalse(pi.update_pi_leanctx_config(path, MANIFEST, False))
        self.assertEqual(path.read_text(), before)

    def test_preserves_user_settings_and_merges(self):
        path = self.root / "lean" / "config.json"
        path.parent.mkdir()
        path.write_text(json.dumps({"env": {"MINE": "1"}, "disableTools": ["x"], "toolPrefix": "my_", "other": True}))
        self.assertTrue(pi.update_pi_leanctx_config(path, MANIFEST, False))
        data = json.loads(path.read_text())
        self.assertEqual(data["env"]["MINE"], "1")
        self.assertEqual(data["env"]["LEANCTX_PRIMARY_FTS"], "context_mode")
        self.assertEqual(data["disableTools"], ["x", "ctx_shell"])
        self.assertEqual(data["toolPrefix"], "my_")
        self.assertTrue(data["other"])

    def test_non_dict_env_and_non_list_disable_tools_are_reset(self):
        path = self.root / "lean" / "config.json"
        path.parent.mkdir()
        path.write_text(json.dumps({"env": "junk", "disableTools": "junk"}))
        pi.update_pi_leanctx_config(path, MANIFEST, False)
        data = json.loads(path.read_text())
        self.assertIsInstance(data["env"], dict)
        self.assertEqual(data["disableTools"], ["ctx_shell"])

    def test_dry_run_reports_change_without_writing(self):
        path = self.root / "lean" / "config.json"
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertTrue(pi.update_pi_leanctx_config(path, MANIFEST, True))
        self.assertIn("DRY-RUN", out.getvalue())
        self.assertFalse(path.exists())


class InstallTest(PiCase):
    def test_full_install(self):
        self.use_agent_dir()
        result, out = self.run_install(
            enabled_tools={"graphify", "agentmemory", "context_mode", "leanctx", "rtk"}, allow_package_install=True
        )
        ext = self.agent / "extensions" / "silver-bullet-five-tool-stack"
        self.assertEqual((ext / "index.ts").read_bytes(), (Path(pi.__file__).parent / "pi-five-tool-stack.ts").read_bytes())
        config = self.read("extensions/silver-bullet-five-tool-stack/config.json")
        self.assertEqual(config["manifest"], str(self.manifest_path))
        self.assertEqual(config["profile"], "five_tool_routed")
        self.assertTrue(all(s["enabled"] for s in config["servers"].values()))
        self.assertEqual(set(config["servers"]), {"graphify", "agentmemory", "context_mode", "leanctx", "rtk"})
        settings = self.read("settings.json")
        self.assertEqual(settings["extensions"], [str(ext)])
        self.assertEqual(settings["packages"], ["npm:pi-lean-ctx"])
        self.assertTrue((self.agent / "extensions" / "pi-lean-ctx" / "config.json").is_file())
        self.assertEqual(result["host"], "pi")
        self.assertEqual(result["status"], "supported")
        self.assertTrue(result["leanctx_config_changed"])
        self.assertFalse(result["pi_leanctx_installed"])
        self.assertEqual(result["extension"], str(ext / "index.ts"))
        self.assertIn("WARN: pi-lean-ctx package is not installed", out)

    def test_default_agent_dir_uses_home_and_tilde_reference(self):
        result, _ = self.run_install()
        agent = Path(os.environ["HOME"]) / ".pi" / "agent"
        settings = json.loads((agent / "settings.json").read_text())
        self.assertEqual(settings["extensions"], ["~/.pi/agent/extensions/silver-bullet-five-tool-stack"])
        self.assertEqual(result["settings"], str(agent / "settings.json"))

    def test_second_install_is_idempotent(self):
        self.use_agent_dir()
        self.run_install()
        settings_before = (self.agent / "settings.json").read_text()
        result, _ = self.run_install()
        self.assertEqual((self.agent / "settings.json").read_text(), settings_before)
        self.assertFalse(result["leanctx_config_changed"])

    def test_installed_package_suppresses_warning(self):
        self.use_agent_dir()
        (self.agent / "npm" / "node_modules" / "pi-lean-ctx").mkdir(parents=True)
        result, out = self.run_install()
        self.assertTrue(result["pi_leanctx_installed"])
        self.assertNotIn("WARN", out)

    def test_changed_extension_is_replaced_unchanged_is_kept(self):
        self.use_agent_dir()
        self.run_install()
        index = self.agent / "extensions" / "silver-bullet-five-tool-stack" / "index.ts"
        index.write_text("// tampered\n")
        self.run_install()
        self.assertNotEqual(index.read_text(), "// tampered\n")
        mtime = index.stat().st_mtime_ns
        self.run_install()
        self.assertEqual(index.stat().st_mtime_ns, mtime)

    def test_dry_run_writes_nothing(self):
        self.use_agent_dir()
        result, out = self.run_install(dry_run=True)
        self.assertFalse(self.agent.exists())
        self.assertIn("DRY-RUN: would copy", out)
        self.assertEqual(out.count("DRY-RUN: would write"), 2)
        pi.ensure_global_instances.assert_called_with(dry_run=True)

    def test_missing_adapter_source_is_an_error(self):
        self.use_agent_dir()
        fake = self.root / "empty" / "install-pi.py"
        fake.parent.mkdir()
        with mock.patch.object(pi, "__file__", str(fake)):
            with self.assertRaisesRegex(RuntimeError, "Pi adapter source missing"):
                pi.install(self.root, False)

    def test_selective_enable_preserves_previous_and_skips_leanctx(self):
        self.use_agent_dir()
        cfg = self.agent / "extensions" / "silver-bullet-five-tool-stack" / "config.json"
        cfg.parent.mkdir(parents=True)
        cfg.write_text(json.dumps({"servers": {"graphify": {"enabled": True}, "rtk": {"enabled": "yes"}, "leanctx": "junk"}}))
        result, _ = self.run_install(enabled_tools={"agentmemory"})
        servers = self.read("extensions/silver-bullet-five-tool-stack/config.json")["servers"]
        self.assertEqual(
            servers,
            {
                "graphify": {"enabled": True},
                "agentmemory": {"enabled": True},
                "context_mode": {"enabled": False},
                "leanctx": {"enabled": False},
                "rtk": {"enabled": False},
            },
        )
        self.assertFalse(result["leanctx_config_changed"])
        self.assertFalse((self.agent / "extensions" / "pi-lean-ctx" / "config.json").exists())

    def test_pi_lean_ctx_is_registered_only_with_leanctx(self):
        # R6-10: an RTK-only or Context-Mode-only enable does not add the unpinned npm package
        self.use_agent_dir()
        self.run_install(enabled_tools={"rtk", "context_mode"})
        self.assertEqual(self.read("settings.json").get("packages"), [])
        self.assertFalse((self.agent / "extensions" / "pi-lean-ctx" / "config.json").exists())
        # enabling leanctx alone never lists an npm package: that needs the caller's install consent
        result, _ = self.run_install(enabled_tools={"leanctx"})
        self.assertEqual(self.read("settings.json")["packages"], [])
        self.assertTrue(self.read("extensions/silver-bullet-five-tool-stack/config.json")["servers"]["leanctx"]["enabled"])
        self.run_install(enabled_tools={"leanctx"}, allow_package_install=True)
        self.assertEqual(self.read("settings.json")["packages"], ["npm:pi-lean-ctx"])
        # allow-install without leanctx lists nothing
        self.run_install(enabled_tools={"rtk"}, allow_package_install=True)
        self.assertEqual(self.read("settings.json")["packages"], ["npm:pi-lean-ctx"])

    def test_no_enable_tool_enables_nothing_new(self):
        self.use_agent_dir()
        self.run_install()
        servers = self.read("extensions/silver-bullet-five-tool-stack/config.json")["servers"]
        self.assertFalse(any(s["enabled"] for s in servers.values()))

    def test_unparseable_settings_are_left_alone(self):
        # R6-09: a settings.json that is not strict JSON (comments, trailing commas) is not replaced
        self.use_agent_dir()
        self.agent.mkdir()
        original = '{\n  // my theme\n  "theme": "dark",\n}\n'
        (self.agent / "settings.json").write_text(original)
        with self.assertRaises(pi.sbc.ConfigError):
            self.run_install(enabled_tools={"rtk"})
        self.assertEqual((self.agent / "settings.json").read_text(), original)

    def test_corrupt_extension_config_is_replaced_with_a_backup(self):
        self.use_agent_dir()
        cfg = self.agent / "extensions" / "silver-bullet-five-tool-stack" / "config.json"
        cfg.parent.mkdir(parents=True)
        cfg.write_text("{broken")
        self.run_install(enabled_tools={"rtk"})
        self.assertEqual(Path(str(cfg) + ".sb-backup").read_text(), "{broken")
        self.assertTrue(self.read("extensions/silver-bullet-five-tool-stack/config.json")["servers"]["rtk"]["enabled"])

    def test_selective_enable_leanctx_configures_bridge(self):
        self.use_agent_dir()
        result, _ = self.run_install(enabled_tools={"leanctx"})
        self.assertTrue(result["leanctx_config_changed"])
        self.assertTrue((self.agent / "extensions" / "pi-lean-ctx" / "config.json").is_file())

    def test_non_dict_previous_servers_are_ignored(self):
        self.use_agent_dir()
        cfg = self.agent / "extensions" / "silver-bullet-five-tool-stack" / "config.json"
        cfg.parent.mkdir(parents=True)
        cfg.write_text(json.dumps({"servers": ["graphify"]}))
        self.run_install(enabled_tools={"rtk"})
        servers = self.read("extensions/silver-bullet-five-tool-stack/config.json")["servers"]
        self.assertEqual([n for n, s in servers.items() if s["enabled"]], ["rtk"])

    def test_existing_settings_are_preserved_and_malformed_lists_reset(self):
        self.use_agent_dir()
        self.agent.mkdir()
        (self.agent / "settings.json").write_text(
            json.dumps({"extensions": "junk", "packages": {"x": 1}, "theme": "dark"})
        )
        self.run_install(enabled_tools={"leanctx"}, allow_package_install=True)
        settings = self.read("settings.json")
        self.assertEqual(settings["theme"], "dark")
        self.assertEqual(len(settings["extensions"]), 1)
        self.assertEqual(settings["packages"], ["npm:pi-lean-ctx"])

    def test_existing_package_reference_not_duplicated(self):
        self.use_agent_dir()
        self.agent.mkdir()
        ref = str(self.agent / "extensions" / "silver-bullet-five-tool-stack")
        (self.agent / "settings.json").write_text(
            json.dumps({"extensions": [ref], "packages": ["npm:pi-lean-ctx@1.2"]})
        )
        self.run_install()
        settings = self.read("settings.json")
        self.assertEqual(settings["extensions"], [ref])
        self.assertEqual(settings["packages"], ["npm:pi-lean-ctx@1.2"])


class MainTest(PiCase):
    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["install-pi.py", *argv]), contextlib.redirect_stdout(out):
            code = pi.main()
        return code, out.getvalue()

    def test_main_passes_flags(self):
        self.use_agent_dir()
        with mock.patch.object(pi, "install", return_value={"ok": True}) as install:
            code, out = self.run_main("--repo-root", str(self.root), "--dry-run", "--enable-tool", "rtk", "--enable-tool", "graphify")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {"ok": True})
        root, dry, tools = install.call_args.args
        self.assertEqual(root, self.root)
        self.assertTrue(dry)
        self.assertEqual(tools, {"rtk", "graphify"})

    def test_main_reports_a_config_error_with_exit_2(self):
        err = io.StringIO()
        with mock.patch.object(pi, "install", side_effect=pi.sbc.ConfigError("x: bad json")), contextlib.redirect_stderr(err):
            code, _ = self.run_main()
        self.assertEqual(code, 2)
        self.assertIn("ERROR: x: bad json", err.getvalue())

    def test_main_makes_new_files_private_and_restores_the_umask(self):
        self.use_agent_dir()
        before = os.umask(0o022)
        try:
            self.run_main("--enable-tool", "rtk")
            self.assertEqual(os.umask(0o022), 0o022)
        finally:
            os.umask(before)
        self.assertEqual(stat.S_IMODE((self.agent / "settings.json").stat().st_mode), 0o600)

    def test_main_defaults_enable_nothing_new(self):
        with mock.patch.object(pi, "install", return_value={}) as install:
            self.run_main()
        self.assertIsNone(install.call_args.args[2])
        self.assertFalse(install.call_args.args[1])

    def test_main_rejects_unknown_tool(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                self.run_main("--enable-tool", "nope")
        self.assertEqual(ctx.exception.code, 2)

    def test_main_end_to_end(self):
        self.use_agent_dir()
        code, out = self.run_main("--repo-root", str(self.root))
        self.assertEqual(code, 0)
        self.assertIn('"host": "pi"', out)

    def test_allow_install_flag_on_the_command_line(self):
        self.use_agent_dir()
        code, _ = self.run_main("--repo-root", str(self.root), "--enable-tool", "leanctx")
        self.assertEqual(code, 0)
        self.assertEqual(self.read("settings.json")["packages"], [])
        code, _ = self.run_main("--repo-root", str(self.root), "--enable-tool", "leanctx", "--allow-install")
        self.assertEqual(code, 0)
        self.assertEqual(self.read("settings.json")["packages"], ["npm:pi-lean-ctx"])


class ScriptEntryPointTest(unittest.TestCase):
    def test_dry_run_as_a_script(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {k: v for k, v in os.environ.items() if not k.startswith(("SB_GLOBAL_", "FIVE_TOOL_"))}
            env.update(HOME=tmp, PI_CODING_AGENT_DIR=str(Path(tmp) / "agent"))
            res = subprocess.run(
                [sys.executable, str(Path(pi.__file__)), "--dry-run"],
                capture_output=True, text=True, env=env, check=False,
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertIn("DRY-RUN: would copy", res.stdout)
            self.assertIn('"host": "pi"', res.stdout)
            self.assertFalse((Path(tmp) / "agent").exists())


if __name__ == "__main__":
    unittest.main()

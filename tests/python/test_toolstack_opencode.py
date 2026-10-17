"""Unit tests for scripts/lib/global-toolstack/opencode.py (OpenCode projection
of the shared five-tool manifest)."""

import tempfile
import unittest
from pathlib import Path

from sbtest import load_module

oc = load_module("scripts/lib/global-toolstack/opencode.py")


def manifest(command="/bin/tool", args=None, env=None, tool="rtk"):
    spec = {"command": command, "args": args if args is not None else []}
    if env is not None:
        spec["env"] = env
    return {"tools": {tool: spec}}


class ServerConfigTest(unittest.TestCase):
    def test_basic_shape(self):
        cfg = oc.opencode_server_config(manifest("/bin/rtk", ["mcp", "--x"]), "rtk")
        self.assertEqual(cfg, {"type": "local", "command": ["/bin/rtk", "mcp", "--x"], "enabled": True})

    def test_manifest_env_becomes_environment(self):
        cfg = oc.opencode_server_config(manifest(env={"A": "1"}), "rtk")
        self.assertEqual(cfg["environment"], {"A": "1"})

    def test_explicit_environment_replaces_manifest_env(self):
        cfg = oc.opencode_server_config(manifest(env={"A": "1"}), "rtk", environment={"B": "2"})
        self.assertEqual(cfg["environment"], {"B": "2"})

    def test_empty_explicit_environment_drops_env(self):
        cfg = oc.opencode_server_config(manifest(env={"A": "1"}), "rtk", environment={})
        self.assertNotIn("environment", cfg)

    def test_missing_args_default(self):
        spec = {"tools": {"rtk": {"command": "/bin/rtk"}}}
        self.assertEqual(oc.opencode_server_config(spec, "rtk")["command"], ["/bin/rtk"])

    def test_unknown_tool_raises(self):
        with self.assertRaises(KeyError):
            oc.opencode_server_config(manifest(), "graphify")


class UpsertServerTest(unittest.TestCase):
    CFG = {"type": "local", "command": ["/bin/x"], "enabled": True}

    def test_adds_missing_server(self):
        servers = {}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG))
        self.assertEqual(servers["x"], self.CFG)
        self.assertIsNot(servers["x"], self.CFG)

    def test_add_disallowed(self):
        servers = {}
        self.assertFalse(oc.opencode_upsert_server(servers, "x", self.CFG, allow_add=False))
        self.assertEqual(servers, {})

    def test_add_disallowed_still_removes_non_dict_alias(self):
        servers = {"old": "junk"}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG, aliases=("old",), allow_add=False))
        self.assertEqual(servers, {})

    def test_idempotent_when_equal(self):
        servers = {"x": dict(self.CFG)}
        self.assertFalse(oc.opencode_upsert_server(servers, "x", self.CFG))
        self.assertEqual(servers["x"], self.CFG)

    def test_fixes_drifted_fields(self):
        servers = {"x": {"type": "remote", "command": ["old"], "enabled": False, "extra": 1}}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG))
        self.assertEqual(servers["x"], {**self.CFG, "extra": 1})

    def test_alias_is_migrated_to_canonical_name(self):
        servers = {"legacy": {"type": "local", "command": ["old"], "enabled": True, "note": "keep"}}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG, aliases=("legacy",)))
        self.assertNotIn("legacy", servers)
        self.assertEqual(servers["x"]["command"], ["/bin/x"])
        self.assertEqual(servers["x"]["note"], "keep")

    def test_first_dict_alias_wins_and_non_dict_alias_skipped(self):
        servers = {"a1": "junk", "a2": {"command": ["two"], "tag": "a2"}, "a3": {"tag": "a3"}}
        oc.opencode_upsert_server(servers, "x", self.CFG, aliases=("a1", "a2", "a3"))
        self.assertEqual(servers["x"]["tag"], "a2")
        self.assertEqual(set(servers), {"x"})

    def test_canonical_entry_wins_over_alias(self):
        servers = {"x": dict(self.CFG, tag="canon"), "legacy": {"tag": "legacy"}}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG, aliases=("legacy",)))
        self.assertEqual(servers["x"]["tag"], "canon")
        self.assertNotIn("legacy", servers)

    def test_non_dict_canonical_entry_is_replaced(self):
        servers = {"x": "junk"}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG))
        self.assertEqual(servers["x"], self.CFG)

    def test_environment_set_and_env_removed(self):
        cfg = dict(self.CFG, environment={"A": "1"})
        servers = {"x": dict(self.CFG, env={"OLD": "1"})}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", cfg))
        self.assertEqual(servers["x"]["environment"], {"A": "1"})
        self.assertNotIn("env", servers["x"])

    def test_environment_unchanged_but_env_removed(self):
        cfg = dict(self.CFG, environment={"A": "1"})
        servers = {"x": dict(cfg, env={"OLD": "1"})}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", cfg))
        self.assertNotIn("env", servers["x"])

    def test_environment_already_canonical(self):
        cfg = dict(self.CFG, environment={"A": "1"})
        servers = {"x": dict(cfg)}
        self.assertFalse(oc.opencode_upsert_server(servers, "x", cfg))

    def test_stale_environment_keys_removed_when_not_wanted(self):
        servers = {"x": dict(self.CFG, environment={"A": "1"}, env={"B": "2"})}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG))
        self.assertEqual(servers["x"], self.CFG)

    def test_only_env_key_removed_when_not_wanted(self):
        servers = {"x": dict(self.CFG, env={"B": "2"})}
        self.assertTrue(oc.opencode_upsert_server(servers, "x", self.CFG))
        self.assertEqual(servers["x"], self.CFG)


class ServerPresenceTest(unittest.TestCase):
    def test_present_by_name_or_alias(self):
        self.assertTrue(oc.opencode_existing_server_present({"x": {}}, "x"))
        self.assertTrue(oc.opencode_existing_server_present({"old": {}}, "x", ("old",)))

    def test_absent_or_non_dict(self):
        self.assertFalse(oc.opencode_existing_server_present({}, "x"))
        self.assertFalse(oc.opencode_existing_server_present({"x": "junk", "old": []}, "x", ("old",)))


class ContextModePluginRecognitionTest(unittest.TestCase):
    def test_recognised_entries(self):
        for entry in (
            "context-mode",
            "context-mode@1.2.3",
            "/opt/cm/build/adapters/opencode/plugin.js",
            "file:///opt/cm/build/adapters/opencode/plugin.js",
            "file:///opt/my%20dir/build/adapters/opencode/plugin.js",
        ):
            with self.subTest(entry=entry):
                self.assertTrue(oc.opencode_is_context_mode_plugin(entry))

    def test_rejected_entries(self):
        for entry in (None, 5, ["context-mode"], "context-mode-extra", "other", "/x/plugin.js", "file:///x/plugin.js"):
            with self.subTest(entry=entry):
                self.assertFalse(oc.opencode_is_context_mode_plugin(entry))

    def test_plugin_present_in_config(self):
        self.assertTrue(oc.opencode_context_mode_plugin_present({"plugin": ["a", "context-mode"]}))
        self.assertFalse(oc.opencode_context_mode_plugin_present({"plugin": ["a"]}))
        self.assertFalse(oc.opencode_context_mode_plugin_present({"plugin": "context-mode"}))
        self.assertFalse(oc.opencode_context_mode_plugin_present({}))


class ContextModePluginSpecTest(unittest.TestCase):
    def package(self, tmp, with_plugin=True):
        root = Path(tmp).resolve() / "cm"
        (root / "build" / "adapters" / "opencode").mkdir(parents=True)
        if with_plugin:
            (root / "build" / "adapters" / "opencode" / "plugin.js").write_text("export default {}\n")
        cli = root / "cli.bundle.mjs"
        cli.write_text("")
        return root, cli

    def test_absolute_command_with_plugin_file_gives_file_uri(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, cli = self.package(tmp)
            spec = oc.opencode_context_mode_plugin_spec(manifest(str(cli), tool="context_mode"))
            self.assertEqual(spec, (root / "build/adapters/opencode/plugin.js").as_uri())

    def test_plugin_file_missing_falls_back_to_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, cli = self.package(tmp, with_plugin=False)
            self.assertEqual(oc.opencode_context_mode_plugin_spec(manifest(str(cli), tool="context_mode")), "context-mode")

    def test_relative_command_falls_back_to_name(self):
        self.assertEqual(oc.opencode_context_mode_plugin_spec(manifest("context-mode", tool="context_mode")), "context-mode")


class EnsurePluginTest(unittest.TestCase):
    M = manifest("context-mode", tool="context_mode")  # spec resolves to the bare name

    def test_adds_when_missing(self):
        plugins = ["other"]
        self.assertTrue(oc.opencode_ensure_context_mode_plugin(plugins, self.M))
        self.assertEqual(plugins, ["other", "context-mode"])

    def test_add_disallowed(self):
        plugins = ["other"]
        self.assertFalse(oc.opencode_ensure_context_mode_plugin(plugins, self.M, allow_add=False))
        self.assertEqual(plugins, ["other"])

    def test_already_canonical(self):
        plugins = ["context-mode", "other"]
        self.assertFalse(oc.opencode_ensure_context_mode_plugin(plugins, self.M))
        self.assertEqual(plugins, ["context-mode", "other"])

    def test_rewrites_first_match_and_dedupes(self):
        plugins = ["context-mode@0.1", "x", "/old/build/adapters/opencode/plugin.js", "context-mode@0.2"]
        self.assertTrue(oc.opencode_ensure_context_mode_plugin(plugins, self.M))
        self.assertEqual(plugins, ["context-mode", "x"])

    def test_dedupes_even_when_first_is_canonical(self):
        plugins = ["context-mode", "context-mode@2"]
        self.assertTrue(oc.opencode_ensure_context_mode_plugin(plugins, self.M))
        self.assertEqual(plugins, ["context-mode"])


class RemoveMcpTest(unittest.TestCase):
    def test_removes_both_aliases(self):
        servers = {"context-mode": {}, "user-context-mode": {}, "keep": {}}
        self.assertTrue(oc.opencode_remove_context_mode_mcp(servers))
        self.assertEqual(servers, {"keep": {}})

    def test_nothing_to_remove(self):
        servers = {"keep": {}}
        self.assertFalse(oc.opencode_remove_context_mode_mcp(servers))
        self.assertEqual(servers, {"keep": {}})


if __name__ == "__main__":
    unittest.main()

"""Unit tests for scripts/lib/uninstall_cursor_legacy.py: strip-only cleanup of ~/.cursor."""
from __future__ import annotations

import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path

from sbtest import load_module

m = load_module("scripts/lib/uninstall_cursor_legacy.py")

PLUGIN_ROOT = "/home/u/.cursor/plugins/cache/alo-labs/silver-bullet/0.50.0"
SB_BRIDGE = f'"{PLUGIN_ROOT}/hooks/cursor-hook-bridge.sh"'
USER_HOOK = {"command": "/home/u/bin/my-hook.sh"}


def run(argv):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = m.main(argv)
    return code, out.getvalue(), err.getvalue()


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.home = Path(self._tmp.name).resolve() / ".cursor"
        self.home.mkdir()

    def write(self, rel, text):
        path = self.home / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def write_json(self, rel, data):
        return self.write(rel, json.dumps(data))

    def clean(self, *extra):
        return run(["--cursor-home", str(self.home), *extra])

    def backups(self):
        root = self.home / ".silver-bullet-legacy-backup"
        return sorted(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()) if root.is_dir() else []


class HooksTest(Base):
    def test_removes_only_silver_bullet_entries_and_keeps_a_backup(self):
        path = self.write_json(
            "hooks.json",
            {
                "version": 1,
                "hooks": {
                    "beforeShellExecution": [{"command": SB_BRIDGE}, USER_HOOK],
                    "stop": [{"command": SB_BRIDGE}],
                    "afterFileEdit": ["not-a-dict", {"command": 5}, {"matcher": "x"}],
                    "weird": {"not": "a list"},
                    "preToolUse": [
                        {"command": "${CURSOR_PLUGIN_ROOT}/hooks/cursor-hook-bridge.sh"},
                        {"command": "$CURSOR_PLUGIN_ROOT/hooks/not-an-sb-hook.sh"},
                        {"command": f"bash {self.home}/hooks/toolstack/graphify-gate.sh"},
                        {"command": f"{self.home}/hooks/toolstack/my-own-gate.sh"},
                        {"command": "bash codex-hook-adapter.sh cursor-hook-bridge.sh"},
                    ],
                },
            },
        )
        code, out, _ = self.clean()
        self.assertEqual(code, 0)
        data = json.loads(path.read_text())
        self.assertEqual(data["hooks"]["beforeShellExecution"], [USER_HOOK])
        self.assertNotIn("stop", data["hooks"])
        self.assertEqual(data["hooks"]["afterFileEdit"], ["not-a-dict", {"command": 5}, {"matcher": "x"}])
        self.assertEqual(data["hooks"]["weird"], {"not": "a list"})
        self.assertEqual(
            [e["command"] for e in data["hooks"]["preToolUse"]],
            ["$CURSOR_PLUGIN_ROOT/hooks/not-an-sb-hook.sh", f"{self.home}/hooks/toolstack/my-own-gate.sh"],
        )
        self.assertIn("updated", out)
        self.assertTrue(Path(str(path) + ".sb-backup").is_file())

    def test_hooks_without_silver_bullet_entries_are_left_alone(self):
        path = self.write_json("hooks.json", {"hooks": {"stop": [USER_HOOK]}})
        before = path.read_bytes()
        code, out, _ = self.clean()
        self.assertEqual(code, 0)
        self.assertIn("nothing Silver Bullet created", out)
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse(Path(str(path) + ".sb-backup").exists())

    def test_absent_and_shapeless_hooks_files(self):
        self.assertEqual(self.clean()[0], 0)
        self.write_json("hooks.json", {"hooks": []})
        self.assertEqual(self.clean()[0], 0)

    def test_invalid_json_is_an_error_and_unchanged(self):
        path = self.write("hooks.json", "{nope")
        code, _, err = self.clean()
        self.assertEqual(code, 1)
        self.assertIn("left unchanged", err)
        self.assertEqual(path.read_text(), "{nope")


class McpTest(Base):
    def test_removes_only_servers_pointing_into_the_silver_bullet_runtime(self):
        path = self.write_json(
            "mcp.json",
            {
                "mcpServers": {
                    "leanctx": {"command": "/home/u/.silver-bullet/five-tool-stack/bin/lean-ctx", "args": ["mcp"]},
                    "graphify": {"command": "graphify", "args": ["--mcp"]},
                    "agentmemory": "not-a-dict",
                    "mine": {"command": "/home/u/.silver-bullet/x"},
                }
            },
        )
        code, _, err = self.clean()
        self.assertEqual(code, 0)
        self.assertEqual(sorted(json.loads(path.read_text())["mcpServers"]), ["agentmemory", "graphify", "mine"])
        self.assertIn("'graphify' does not point into", err)
        self.assertTrue(Path(str(path) + ".sb-backup").is_file())

    def test_nothing_owned_leaves_the_file_untouched(self):
        path = self.write_json("mcp.json", {"mcpServers": {"graphify": {"command": "graphify"}, "mine": {"command": "x"}}})
        before = path.read_text()
        code, _, err = self.clean()
        self.assertEqual(code, 0)
        self.assertEqual(path.read_text(), before)
        self.assertFalse(Path(str(path) + ".sb-backup").exists())
        self.assertIn("'graphify' does not point into", err)

    def test_other_shapes_are_ignored(self):
        self.write_json("mcp.json", {"mcpServers": []})
        self.assertEqual(self.clean()[0], 0)
        self.write_json("mcp.json", {})
        self.assertEqual(self.clean()[0], 0)


class AgentsTest(Base):
    def managed(self, name="sb-ladder-a", description=m.AGENT_DESCRIPTION_PREFIX + "x", marker=m.AGENT_MARKER):
        return f"---\nname: {name}\ndescription: {description}\n---\nbody\n{marker}\n"

    def test_moves_generated_and_listed_agents_only(self):
        self.write("agents/sb-ladder-a.md", self.managed())
        self.write("agents/sb:review.md", "user content")
        self.write("agents/sb:plan/SKILL.md", "dir")
        self.write("agents/silver:debug.json", "{}")
        self.write("agents/sb:mine.md", "not shipped")
        self.write("agents/sb:review.txt", "wrong suffix")
        self.write("agents/other.md", "mine")
        self.write("agents/wrong-name.md", self.managed(name="other"))
        self.write("agents/bad-desc.md", self.managed(name="bad-desc", description="mine"))
        self.write("agents/no-marker.md", self.managed(name="no-marker", marker="<!-- x -->"))
        self.write("agents/no-front.md", "plain\n")
        self.write("agents/open-front.md", "---\nname: open-front\n")
        self.write("agents/empty.md", "")
        (self.home / "agents" / "bad utf8.md").write_bytes(b"\xff\xfe")
        (self.home / "agents" / "sb:link.md").symlink_to(self.home / "agents" / "other.md")
        code, _, _ = self.clean()
        self.assertEqual(code, 0)
        remaining = sorted(p.name for p in (self.home / "agents").iterdir())
        self.assertEqual(
            remaining,
            ["bad utf8.md", "bad-desc.md", "empty.md", "no-front.md", "no-marker.md", "open-front.md", "other.md",
             "sb:link.md", "sb:mine.md", "sb:review.txt", "wrong-name.md"],
        )
        self.assertEqual(
            [b.split("/", 1)[1] for b in self.backups()],
            ["agents/sb-ladder-a.md", "agents/sb:plan/SKILL.md", "agents/sb:review.md", "agents/silver:debug.json"],
        )

    def test_no_agents_directory(self):
        self.assertEqual(self.clean()[0], 0)


class RulesToolstackPluginsTest(Base):
    def rule(self, name, description=None):
        self.write(f"rules/{name}.mdc", f"---\ndescription: {description or m.RULES[name]}\nalwaysApply: true\n---\nx\n")

    def test_rules_by_name_and_exact_description(self):
        self.rule("no-fast-mode")
        self.rule("silver-orchestrator")
        self.rule("leanctx", description="my own leanctx rule")
        self.write("rules/graphify.mdc", "---\ndescription: graphify knowledge graph context\n---\n")
        (self.home / "rules" / "agentmemory.mdc").symlink_to(self.home / "rules" / "graphify.mdc")
        (self.home / "rules" / "recommended-tools.mdc").write_bytes(b"\xff\xfe")
        code, _, err = self.clean()
        self.assertEqual(code, 0)
        self.assertEqual(
            sorted(p.name for p in (self.home / "rules").iterdir()),
            ["agentmemory.mdc", "graphify.mdc", "leanctx.mdc", "recommended-tools.mdc"],
        )
        self.assertIn("leanctx.mdc: named like a Silver Bullet rule", err)
        self.assertEqual(self.backups(), [self.backups()[0].split("/")[0] + "/rules/no-fast-mode.mdc",
                                          self.backups()[1].split("/")[0] + "/rules/silver-orchestrator.mdc"])

    def test_toolstack_directory_config_and_state(self):
        self.write("hooks/toolstack/lib/common.sh", f"# shellcheck shell=bash\n{m.TOOLSTACK_HEADER}\n")
        self.write("hooks/toolstack/graphify-gate.sh", "x")
        self.write_json("toolstack.json", {"state_dir": m.TOOLSTACK_STATE_DIR})
        self.write("state/toolstack/repo-root", "/r")
        self.assertEqual(self.clean()[0], 0)
        for rel in ("hooks/toolstack", "toolstack.json", "state/toolstack"):
            self.assertFalse((self.home / rel).exists(), rel)
        self.assertEqual(len(self.backups()), 4)

    def test_unmarked_toolstack_is_kept(self):
        self.write("hooks/toolstack/lib/common.sh", "# mine\n")
        self.write_json("toolstack.json", {"state_dir": "/elsewhere"})
        self.write("state/toolstack/f", "x")
        code, _, err = self.clean()
        self.assertEqual(code, 0)
        self.assertIn("lacks the Silver Bullet toolstack header", err)
        self.assertTrue((self.home / "hooks/toolstack").is_dir())
        self.assertTrue((self.home / "toolstack.json").is_file())
        self.assertTrue((self.home / "state/toolstack").is_dir())

    def test_state_dir_without_a_marked_config_stays_and_bad_config_is_not_marked(self):
        self.write("toolstack.json", "{nope")
        self.write("state/toolstack/f", "x")
        self.assertEqual(self.clean()[0], 0)
        self.assertTrue((self.home / "state/toolstack/f").exists())

    def test_marked_config_without_state_dir_moves_just_the_config(self):
        self.write_json("toolstack.json", {"state_dir": m.TOOLSTACK_STATE_DIR})
        self.assertEqual(self.clean()[0], 0)
        self.assertFalse((self.home / "toolstack.json").exists())

    def test_plugin_copies_and_registry(self):
        self.write("plugins/cache/alo-labs/silver-bullet/0.5.0/x", "x")
        self.write("plugins/cache/alo-labs/other/x", "keep")
        self.write("plugins/marketplaces/github.com/alo-exp/silver-bullet/sha/x", "x")
        self.write_json("plugins/local/silver-bullet/.cursor-plugin/plugin.json", {"name": "silver-bullet"})
        registry = self.write_json(
            "plugins/installed_plugins.json",
            {"version": 2, "plugins": {m.PLUGIN_ID: [{"x": 1}], "other@x": [{"y": 2}]}},
        )
        self.assertEqual(self.clean()[0], 0)
        self.assertFalse((self.home / "plugins/cache/alo-labs/silver-bullet").exists())
        self.assertFalse((self.home / "plugins/local/silver-bullet").exists())
        self.assertTrue((self.home / "plugins/cache/alo-labs/other/x").exists())
        self.assertEqual(json.loads(registry.read_text())["plugins"], {"other@x": [{"y": 2}]})

    def test_foreign_local_plugin_and_other_registry_shapes_stay(self):
        self.write_json("plugins/local/silver-bullet/.cursor-plugin/plugin.json", {"name": "mine"})
        self.write_json("plugins/installed_plugins.json", {"plugins": []})
        code, _, err = self.clean()
        self.assertEqual(code, 0)
        self.assertIn("does not name silver-bullet", err)
        self.assertTrue((self.home / "plugins/local/silver-bullet").is_dir())
        self.write("plugins/local/silver-bullet/.cursor-plugin/plugin.json", "{nope")
        self.assertEqual(self.clean()[0], 0)
        self.assertTrue((self.home / "plugins/local/silver-bullet").is_dir())


class RunTest(Base):
    def populate(self):
        self.write_json("hooks.json", {"hooks": {"stop": [{"command": SB_BRIDGE}]}})
        self.write("agents/sb:plan.md", "x")

    def test_dry_run_changes_nothing(self):
        self.populate()
        before = (self.home / "hooks.json").read_bytes()
        code, out, _ = self.clean("--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("would update", out)
        self.assertIn("would move", out)
        self.assertEqual((self.home / "hooks.json").read_bytes(), before)
        self.assertTrue((self.home / "agents/sb:plan.md").exists())
        self.assertFalse((self.home / ".silver-bullet-legacy-backup").exists())

    def test_second_run_is_a_no_op(self):
        self.populate()
        self.assertEqual(self.clean()[0], 0)
        snapshot = {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file() and ".silver-bullet-legacy-backup" not in str(p)}
        code, out, _ = self.clean()
        self.assertEqual(code, 0)
        self.assertIn("nothing Silver Bullet created", out)
        self.assertEqual(snapshot, {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file() and ".silver-bullet-legacy-backup" not in str(p)})

    def test_missing_home_is_not_an_error(self):
        code, out, _ = run(["--cursor-home", str(self.home / "absent")])
        self.assertEqual(code, 0)
        self.assertIn("nothing to do", out)

    def test_default_home_comes_from_the_environment(self):
        os.environ["CURSOR_HOME"] = str(self.home / "from-env")
        self.addCleanup(os.environ.pop, "CURSOR_HOME", None)
        self.assertIn("from-env", run([])[1])


if __name__ == "__main__":
    unittest.main()

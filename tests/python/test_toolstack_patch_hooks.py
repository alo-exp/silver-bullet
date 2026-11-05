"""Unit tests for scripts/lib/global-toolstack/patch-hooks.py (idempotent
~/.cursor/hooks.json patching for the global toolstack gates)."""

import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import load_module

ph = load_module("scripts/lib/global-toolstack/patch-hooks.py")

MANIFEST = {
    "tools": {
        "rtk": {"command": "/bin/rtk", "args": []},
        "context_mode": {"command": "/bin/context-mode", "args": []},
    }
}
CM = "/bin/context-mode"


class HooksCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.ts = self.root / "toolstack"
        self.hooks_path = self.root / "hooks.json"
        self.ts.mkdir()
        env = {k: v for k, v in os.environ.items() if not k.startswith("RT_PATCH_")}
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        for name, value in (
            ("TS", self.ts),
            ("HOOKS", self.hooks_path),
            ("ensure_global_instances", mock.Mock(return_value=MANIFEST)),
        ):
            p = mock.patch.object(ph, name, value)
            p.start()
            self.addCleanup(p.stop)

    def enable(self, *names):
        for name in names:
            os.environ[f"RT_PATCH_{name}"] = "1"

    def script(self, name):
        (self.ts / name).write_text("#!/bin/sh\n")

    def all_scripts(self):
        for name in (
            "session-bootstrap.sh",
            "stack-compression-coordinator.sh",
            "graphify-gate.sh",
            "agentmemory-gate.sh",
            "rtk-gate.sh",
            "context-mode-gate.sh",
            "token-compression-tools-gate.sh",
            "record-graphify-query.sh",
            "record-agentmemory-usage.sh",
        ):
            self.script(name)

    def write(self, data):
        self.hooks_path.write_text(json.dumps(data), encoding="utf-8")

    def read(self):
        return json.loads(self.hooks_path.read_text(encoding="utf-8"))

    def run_main(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ph.main()
        return code, out.getvalue().strip()


class PureHelpersTest(unittest.TestCase):
    def test_load_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "h.json"
            self.assertEqual(ph.load_json(p), {})
            p.write_text('{"a": 1}')
            self.assertEqual(ph.load_json(p), {"a": 1})

    def test_normalize_hooks_config(self):
        self.assertEqual(ph.normalize_hooks_config({"hooks": {}, "x": 1}), {"x": 1})
        data = {"hooks": {"a": []}}
        self.assertEqual(ph.normalize_hooks_config(data), data)
        self.assertIsNot(ph.normalize_hooks_config(data), data)
        self.assertEqual(ph.normalize_hooks_config({"hooks": []}), {"hooks": []})
        self.assertEqual(ph.normalize_hooks_config({}), {})

    def test_patch_enabled(self):
        with mock.patch.dict(os.environ, {"RT_PATCH_FOO": "1", "RT_PATCH_BAR": "0"}):
            self.assertTrue(ph.patch_enabled("foo"))
            self.assertFalse(ph.patch_enabled("bar"))
            self.assertFalse(ph.patch_enabled("baz"))

    def test_entry(self):
        self.assertEqual(ph.entry("c"), {"command": "c"})
        self.assertEqual(ph.entry("c", "Shell", 10), {"command": "c", "matcher": "Shell", "timeout": 10})
        self.assertEqual(ph.entry("c", "", 0), {"command": "c"})

    def test_hook_cmd_tolerates_non_dict_entries(self):
        for junk in ("junk", None, 5, ["command"]):
            self.assertEqual(ph.hook_cmd(junk), "")

    def test_hook_cmd(self):
        self.assertEqual(ph.hook_cmd({"command": "x"}), "x")
        self.assertEqual(ph.hook_cmd({}), "")
        self.assertEqual(ph.hook_cmd({"command": 5}), "5")

    def test_is_legacy_routing_hook(self):
        for cmd in (
            "lean-ctx hook deny",
            "lean-ctx hook redirect x",
            "lean-ctx hook rewrite",
            "bash ~/.cursor/hooks/toolstack/shell-compression.sh",
            "bash /p/cursor-hook-bridge.sh graphify-gate.sh",
            "bash /p/cursor-hook-bridge.sh rtk-gate.sh",
            "lean-ctx\\\\ hook rewrite",
        ):
            with self.subTest(cmd=cmd):
                self.assertTrue(ph.is_legacy_routing_hook(cmd))
        for cmd in ("bash /p/cursor-hook-bridge.sh other.sh", "bash graphify-gate.sh", "rtk hook cursor", ""):
            with self.subTest(cmd=cmd):
                self.assertFalse(ph.is_legacy_routing_hook(cmd))

    def test_has_cmd(self):
        hooks = [{"command": "a b"}, {"command": "c"}]
        self.assertTrue(ph.has_cmd(hooks, "b"))
        self.assertFalse(ph.has_cmd(hooks, "z"))
        self.assertFalse(ph.has_cmd([], "z"))

    def test_has_toolstack_hook(self):
        hooks = [{"command": "bash /x/toolstack/graphify-gate.sh"}]
        self.assertTrue(ph.has_toolstack_hook(hooks, "graphify-gate.sh"))
        self.assertFalse(ph.has_toolstack_hook(hooks, "rtk-gate.sh"))


class ContextModePhaseTest(unittest.TestCase):
    def test_phases(self):
        for phase in ("pretooluse", "posttooluse", "afteragentresponse", "sessionstart", "stop"):
            self.assertEqual(ph.context_mode_hook_phase(f"context-mode hook cursor {phase}"), phase)
            self.assertEqual(ph.context_mode_hook_phase(f"/opt/context-mode/cli.js hook cursor {phase}"), phase)

    def test_unknown_phase_and_foreign_commands(self):
        self.assertIsNone(ph.context_mode_hook_phase("context-mode hook cursor bogus"))
        self.assertIsNone(ph.context_mode_hook_phase("rtk hook cursor"))
        self.assertIsNone(ph.context_mode_hook_phase("tool hook cursor pretooluse"))
        self.assertIsNone(ph.context_mode_hook_phase("context-mode hook cursor"))
        self.assertIsNone(ph.context_mode_hook_phase("context-mode run cursor pretooluse"))
        self.assertIsNone(ph.context_mode_hook_phase(""))

    def test_unbalanced_quotes_fall_back_to_split(self):
        self.assertEqual(ph.context_mode_hook_phase("context-mode 'x hook cursor stop"), "stop")

    def test_first_marker_without_context_mode_is_skipped_then_later_match(self):
        self.assertEqual(
            ph.context_mode_hook_phase("hook cursor stop context-mode hook cursor pretooluse"),
            "pretooluse",
        )


class ContextModeArgvTest(unittest.TestCase):
    def test_plain_command(self):
        m = {"tools": {"context_mode": {"command": "/bin/cm", "args": ["--x"]}}}
        self.assertEqual(ph.context_mode_hook_argv(m, "stop"), ["/bin/cm", "--x", "hook", "cursor", "stop"])
        self.assertEqual(ph.canonical_context_mode_hook(m, "stop"), "/bin/cm --x hook cursor stop")

    def test_missing_args_default(self):
        m = {"tools": {"context_mode": {"command": "/bin/cm"}}}
        self.assertEqual(ph.context_mode_hook_argv(m, "stop"), ["/bin/cm", "hook", "cursor", "stop"])

    def test_js_entry_prefers_node_on_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp).resolve()
            node = tmp / "pathnode"
            node.write_text("")
            node.chmod(0o755)
            m = {"tools": {"context_mode": {"command": str(tmp / "cli.mjs"), "args": []}}}
            with mock.patch.object(ph.shutil, "which", return_value=str(node)):
                argv = ph.context_mode_hook_argv(m, "pretooluse")
            self.assertEqual(argv, [str(node), str(tmp / "cli.mjs"), "hook", "cursor", "pretooluse"])

    def test_js_entry_falls_back_to_sibling_bin_node(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp).resolve()
            (tmp / "bin").mkdir()
            node = tmp / "bin" / "node"
            node.write_text("")
            node.chmod(0o755)
            sub = tmp / "lib"
            sub.mkdir()
            m = {"tools": {"context_mode": {"command": str(sub / "cli.cjs"), "args": []}}}
            with mock.patch.object(ph.shutil, "which", return_value=None):
                argv = ph.context_mode_hook_argv(m, "stop")
            self.assertEqual(argv[0], str(node))

    def test_js_entry_without_usable_node_is_left_bare(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp).resolve()
            (tmp / "bin").mkdir()
            (tmp / "bin" / "node").write_text("")  # not executable
            (tmp / "bin" / "node").chmod(0o644)
            m = {"tools": {"context_mode": {"command": str(tmp / "cli.js"), "args": []}}}
            with mock.patch.object(ph.shutil, "which", return_value=None):
                argv = ph.context_mode_hook_argv(m, "stop")
            self.assertEqual(argv[0], str(tmp / "cli.js"))


class ScriptEntryTest(HooksCase):
    def test_toolstack_script_exists(self):
        self.assertFalse(ph.toolstack_script_exists("a.sh"))
        self.script("a.sh")
        self.assertTrue(ph.toolstack_script_exists("a.sh"))

    def test_hook_entry_for_script(self):
        self.assertIsNone(ph.hook_entry_for_script("a.sh", "Shell", 5))
        self.script("a.sh")
        self.assertEqual(
            ph.hook_entry_for_script("a.sh", "Shell", 5),
            {"command": f"bash {self.ts}/a.sh", "matcher": "Shell", "timeout": 5},
        )
        self.assertEqual(ph.hook_entry_for_script("a.sh"), {"command": f"bash {self.ts}/a.sh"})


class MergeMatchersTest(unittest.TestCase):
    def test_union_preserving_order(self):
        self.assertEqual(ph._merge_matchers([{"matcher": "A|B"}, {"matcher": "B| C "}]), "A|B|C")

    def test_unrestricted_wins(self):
        self.assertIsNone(ph._merge_matchers([{"matcher": "A"}, {}]))
        self.assertIsNone(ph._merge_matchers([{"matcher": ".*"}, {"matcher": "A"}]))
        self.assertIsNone(ph._merge_matchers([{"matcher": ""}]))

    def test_only_separators_is_none(self):
        self.assertIsNone(ph._merge_matchers([{"matcher": "|"}]))
        self.assertIsNone(ph._merge_matchers([]))


class DeduplicateTest(unittest.TestCase):
    def test_merges_duplicates(self):
        entries = [
            {"command": "x", "matcher": "A", "timeout": 5},
            {"command": "y"},
            {"command": "x", "matcher": "B", "timeout": 20},
            {"command": "x", "matcher": "A|C", "timeout": "slow"},
        ]
        result, removed = ph.deduplicate_hook_entries(entries)
        self.assertEqual(removed, 2)
        self.assertEqual(result, [{"command": "x", "matcher": "A|B|C", "timeout": 20}, {"command": "y"}])

    def test_unrestricted_duplicate_drops_matcher(self):
        result, removed = ph.deduplicate_hook_entries([{"command": "x", "matcher": "A"}, {"command": "x"}])
        self.assertEqual((result, removed), ([{"command": "x"}], 1))

    def test_no_timeouts_keeps_existing_none(self):
        result, _ = ph.deduplicate_hook_entries([{"command": "x", "matcher": "A"}, {"command": "x", "matcher": "B"}])
        self.assertNotIn("timeout", result[0])

    def test_non_dict_and_commandless_entries_kept_untouched(self):
        entries = ["junk", {"matcher": "A"}, {"matcher": "A"}, {"command": "x"}, {"command": "x"}]
        result, removed = ph.deduplicate_hook_entries(entries)
        self.assertEqual(result, ["junk", {"matcher": "A"}, {"matcher": "A"}, {"command": "x"}])
        self.assertEqual(removed, 1)

    def test_nothing_to_do(self):
        entries = [{"command": "a"}, {"command": "b"}]
        self.assertEqual(ph.deduplicate_hook_entries(entries), (entries, 0))


class InsertBeforeBridgeTest(unittest.TestCase):
    def test_inserts_before_bridge_and_skips_present(self):
        hooks = [{"command": "a"}, {"command": "bash /p/cursor-hook-bridge.sh x"}]
        new = [
            {"command": "bash /t/toolstack/g1.sh"},
            {"command": "bash /t/toolstack/g2.sh"},
            {"command": "bash /t/toolstack/a.sh"},
        ]
        hooks.append({"command": "bash /t/toolstack/a.sh"})
        added = ph.insert_before_bridge(hooks, new)
        self.assertEqual(added, 2)
        self.assertEqual(
            [h["command"] for h in hooks],
            ["a", "bash /t/toolstack/g1.sh", "bash /t/toolstack/g2.sh", "bash /p/cursor-hook-bridge.sh x", "bash /t/toolstack/a.sh"],
        )

    def test_appends_without_bridge(self):
        hooks = [{"command": "a"}]
        self.assertEqual(ph.insert_before_bridge(hooks, [{"command": "bash /t/toolstack/g.sh"}]), 1)
        self.assertEqual(hooks[-1]["command"], "bash /t/toolstack/g.sh")


class EnsureRtkBeforeCmTest(unittest.TestCase):
    RTK = "/bin/rtk hook cursor"

    def call(self, pretool, patch_rtk=True):
        return ph.ensure_rtk_before_cm(pretool, patch_rtk=patch_rtk, patch_cm=True, rtk_hook_command=self.RTK)

    def test_disabled(self):
        pre = [{"command": f"{CM} hook cursor pretooluse"}]
        self.assertFalse(self.call(pre, patch_rtk=False))
        self.assertEqual(len(pre), 1)

    def test_noop_when_nothing_present(self):
        self.assertFalse(self.call([{"command": "other"}]))
        self.assertFalse(self.call([]))

    def test_rewrites_rtk_command(self):
        pre = [{"command": "old/rtk hook cursor"}]
        self.assertTrue(self.call(pre))
        self.assertEqual(pre[0]["command"], self.RTK)

    def test_already_correct(self):
        pre = [{"command": self.RTK}, {"command": f"{CM} hook cursor pretooluse"}]
        self.assertFalse(self.call(pre))

    def test_moves_rtk_before_cm(self):
        pre = [{"command": f"{CM} hook cursor pretooluse"}, {"command": "x"}, {"command": self.RTK}]
        self.assertTrue(self.call(pre))
        self.assertEqual([h["command"] for h in pre], [self.RTK, f"{CM} hook cursor pretooluse", "x"])

    def test_inserts_missing_rtk_before_cm(self):
        pre = [{"command": "x"}, {"command": f"{CM} hook cursor pretooluse"}]
        self.assertTrue(self.call(pre))
        self.assertEqual(pre[1], {"command": self.RTK, "matcher": "Shell"})

    def test_cm_posttooluse_is_not_the_pretool_marker(self):
        pre = [{"command": f"{CM} hook cursor posttooluse"}]
        self.assertFalse(self.call(pre))


class HookListTest(unittest.TestCase):
    def test_hook_list(self):
        hooks = {"a": [1], "b": "junk"}
        self.assertEqual(ph.hook_list(hooks, "a"), ([1], True))
        self.assertEqual(ph.hook_list(hooks, "b"), ([], False))
        self.assertEqual(ph.hook_list(hooks, "c"), ([], False))
        lst = []
        ph.attach_hook_list(hooks, "c", lst)
        self.assertIs(hooks["c"], lst)

    def test_atomic_write_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "nested" / "hooks.json"
            ph.atomic_write_json(target, {"hooks": {"a": []}})
            self.assertEqual(json.loads(target.read_text()), {"hooks": {"a": []}})
            self.assertTrue(target.read_text().endswith("\n"))
            self.assertEqual([p.name for p in target.parent.iterdir()], ["hooks.json"])


class MainTest(HooksCase):
    def test_no_consent_leaves_everything_alone(self):
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(out, "OK: hooks.json unchanged (no consented patch targets)")
        self.assertFalse(self.hooks_path.exists())
        ph.ensure_global_instances.assert_not_called()

    def test_graphify_only_creates_hooks(self):
        self.all_scripts()
        self.enable("GRAPHIFY")
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(out, "OK: hooks.json patched (4 changes)")
        hooks = self.read()["hooks"]
        self.assertEqual(
            hooks["sessionStart"],
            [{"command": f"bash {self.ts}/session-bootstrap.sh", "matcher": "startup|clear|compact", "timeout": 120}],
        )
        self.assertEqual(
            hooks["preToolUse"],
            [{"command": f"bash {self.ts}/graphify-gate.sh", "matcher": "Edit|Write|MultiEdit|Shell", "timeout": 10}],
        )
        self.assertEqual(hooks["afterShellExecution"], [{"command": f"bash {self.ts}/record-graphify-query.sh", "matcher": ".*", "timeout": 10}])
        self.assertEqual([h["command"] for h in hooks["postToolUse"]], [f"bash {self.ts}/record-graphify-query.sh"])

    def test_second_run_is_idempotent(self):
        self.all_scripts()
        self.enable("GRAPHIFY", "AGENTMEMORY", "RTK", "CONTEXT_MODE", "LEANCTX")
        self.run_main()
        first = self.hooks_path.read_text()
        code, out = self.run_main()
        self.assertEqual(out, "OK: hooks.json unchanged (idempotent)")
        self.assertEqual(self.hooks_path.read_text(), first)

    def test_full_stack_gate_set_and_order(self):
        self.all_scripts()
        self.enable("GRAPHIFY", "AGENTMEMORY", "RTK", "CONTEXT_MODE")
        self.write(
            {
                "hooks": {
                    "preToolUse": [
                        {"command": f"{CM} hook cursor pretooluse", "matcher": "Shell"},
                        {"command": "bash /p/cursor-hook-bridge.sh route"},
                    ],
                    "postToolUse": [{"command": f"{CM} hook cursor posttooluse"}],
                    "sessionStart": [{"command": "sidekick start"}, {"command": "other"}],
                }
            }
        )
        self.run_main()
        hooks = self.read()["hooks"]
        pre = [h["command"] for h in hooks["preToolUse"]]
        self.assertEqual(pre[0], "/bin/rtk hook cursor")
        self.assertEqual(pre[1], f"{CM} hook cursor pretooluse")
        self.assertEqual(pre[-1], "bash /p/cursor-hook-bridge.sh route")
        for gate in ("stack-compression-coordinator", "graphify-gate", "agentmemory-gate", "rtk-gate", "context-mode-gate", "token-compression-tools-gate"):
            self.assertEqual(sum(f"toolstack/{gate}.sh" in c for c in pre), 1, gate)
        self.assertNotIn("leanctx-gate", " ".join(pre))
        # session bootstrap lands right after the sidekick hook
        self.assertEqual([h["command"] for h in hooks["sessionStart"]][:3], ["sidekick start", f"bash {self.ts}/session-bootstrap.sh", "other"])
        # recorders land right after the context-mode post hook
        post = [h["command"] for h in hooks["postToolUse"]]
        self.assertEqual(post[0], f"{CM} hook cursor posttooluse")
        self.assertEqual(post[1:], [f"bash {self.ts}/record-graphify-query.sh", f"bash {self.ts}/record-agentmemory-usage.sh"][::-1])

    def test_leanctx_adds_only_coordinator(self):
        self.all_scripts()
        self.enable("LEANCTX")
        self.run_main()
        pre = self.read()["hooks"]["preToolUse"]
        self.assertEqual(len(pre), 1)
        self.assertIn("stack-compression-coordinator.sh", pre[0]["command"])
        self.assertEqual(pre[0]["matcher"], "Edit|Write|MultiEdit|Shell|Read|Grep|CallMcpTool|MCP|WebFetch")

    def test_missing_scripts_are_not_wired(self):
        self.enable("GRAPHIFY", "AGENTMEMORY")
        code, out = self.run_main()
        self.assertEqual(out, "OK: hooks.json unchanged (idempotent)")
        self.assertFalse(self.hooks_path.exists())

    def test_legacy_hooks_removed_and_context_mode_canonicalised(self):
        self.enable("CONTEXT_MODE")
        self.write(
            {
                "hooks": {
                    "preToolUse": [
                        {"command": "lean-ctx hook rewrite"},
                        "junk",
                        {"command": "context-mode hook cursor pretooluse", "matcher": "Shell"},
                        {"command": "context-mode hook cursor pretooluse", "matcher": "Edit", "timeout": 3},
                        {"command": "bash /p/cursor-hook-bridge.sh rtk-gate.sh"},
                    ],
                    "stop": "not-a-list",
                    "postToolUse": [{"command": "context-mode hook cursor posttooluse"}, "junk"],
                }
            }
        )
        code, out = self.run_main()
        self.assertEqual(out, "OK: hooks.json patched (6 changes)")
        data = self.read()["hooks"]
        self.assertEqual(
            data["preToolUse"],
            ["junk", {"command": f"{CM} hook cursor pretooluse", "matcher": "Shell|Edit", "timeout": 3}],
        )
        self.assertEqual(data["stop"], "not-a-list")
        self.assertEqual(data["postToolUse"][0]["command"], f"{CM} hook cursor posttooluse")

    def test_non_list_event_values_are_skipped_not_clobbered(self):
        self.enable("GRAPHIFY")
        self.write({"hooks": {"preToolUse": "oops"}})
        self.all_scripts()
        self.run_main()
        # the string value is not a list: hook_list treats it as absent and replaces it
        self.assertIsInstance(self.read()["hooks"]["preToolUse"], list)

    def test_existing_rtk_hook_is_repointed(self):
        self.enable("RTK")
        self.write({"hooks": {"preToolUse": [{"command": "/old/rtk hook cursor"}]}})
        code, out = self.run_main()
        self.assertEqual(out, "OK: hooks.json patched (1 changes)")
        self.assertEqual(self.read()["hooks"]["preToolUse"][0]["command"], "/bin/rtk hook cursor")

    def test_missing_rtk_is_attached_even_without_preexisting_list(self):
        # cm hook lives in an unrelated event; preToolUse has no rtk/cm => nothing to attach
        self.enable("RTK")
        self.write({"hooks": {"postToolUse": []}})
        code, out = self.run_main()
        self.assertEqual(out, "OK: hooks.json unchanged (idempotent)")

    def test_unattached_preToolUse_list_attaches_on_rtk_change(self):
        # Force the rtk branch to mutate a list that was never attached to hooks.
        self.enable("RTK")
        self.write({"hooks": {}})
        with mock.patch.object(ph, "ensure_rtk_before_cm", return_value=True) as ensure:
            code, out = self.run_main()
        ensure.assert_called_once()
        self.assertEqual(out, "OK: hooks.json patched (1 changes)")
        self.assertEqual(self.read()["hooks"]["preToolUse"], [])

    def test_existing_session_bootstrap_and_recorders_not_duplicated(self):
        self.all_scripts()
        self.enable("GRAPHIFY", "AGENTMEMORY")
        self.run_main()
        before = self.read()
        self.run_main()
        self.assertEqual(self.read(), before)

    def test_session_bootstrap_without_sidekick_goes_first(self):
        self.all_scripts()
        self.enable("GRAPHIFY")
        self.write({"hooks": {"sessionStart": [{"command": "other"}]}})
        self.run_main()
        self.assertIn("session-bootstrap.sh", self.read()["hooks"]["sessionStart"][0]["command"])

    def test_gates_attached_to_existing_pretool_list_without_extra_attach(self):
        self.all_scripts()
        self.enable("AGENTMEMORY")
        self.write({"hooks": {"preToolUse": [{"command": "x"}], "postToolUse": [{"command": "y"}], "afterShellExecution": [{"command": "z"}]}})
        self.run_main()
        hooks = self.read()["hooks"]
        self.assertEqual(len(hooks["preToolUse"]), 2)
        self.assertEqual(len(hooks["postToolUse"]), 2)
        self.assertEqual(hooks["afterShellExecution"], [{"command": "z"}])

    def test_graphify_with_existing_after_shell_list(self):
        self.all_scripts()
        self.enable("GRAPHIFY")
        self.write({"hooks": {"afterShellExecution": [{"command": "bash /p/cursor-hook-bridge.sh x"}]}})
        self.run_main()
        cmds = [h["command"] for h in self.read()["hooks"]["afterShellExecution"]]
        self.assertEqual(cmds, [f"bash {self.ts}/record-graphify-query.sh", "bash /p/cursor-hook-bridge.sh x"])


class ScriptEntryPointTest(unittest.TestCase):
    def test_runs_as_script_without_consent(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {k: v for k, v in os.environ.items() if not k.startswith(("RT_PATCH_", "SB_GLOBAL_", "FIVE_TOOL_"))}
            env["HOME"] = tmp
            res = subprocess.run(
                [sys.executable, str(Path(ph.__file__))], capture_output=True, text=True, env=env, check=False
            )
            self.assertEqual(res.returncode, 0, res.stderr)
            self.assertEqual(res.stdout.strip(), "OK: hooks.json unchanged (no consented patch targets)")
            self.assertFalse((Path(tmp) / ".cursor").exists())


if __name__ == "__main__":
    unittest.main()

"""Unit tests for scripts/generate-cursor-hooks.py."""
from __future__ import annotations

import contextlib
import io
import json
import pathlib
import runpy
import tempfile
import unittest
from unittest import mock

from sbtest import REPO_ROOT, load_module

g = load_module("scripts/generate-cursor-hooks.py")
P = g.PLUGIN_ROOT


class SkipRulesTest(unittest.TestCase):
    def test_basename_and_suffix_rules(self):
        self.assertTrue(g.should_skip_shell_duplicate("record-skill.sh"))
        self.assertTrue(g.should_skip_shell_duplicate("foo-gate.sh"))
        self.assertTrue(g.should_skip_shell_duplicate("foo-guard.sh"))
        self.assertFalse(g.should_skip_shell_duplicate("compliance-status.sh"))


class NormalizeHookPathTest(unittest.TestCase):
    def test_strips_quotes_and_substitutes_root(self):
        self.assertEqual(
            g.normalize_hook_path('"${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"'), f"{P}/hooks/x.sh"
        )

    def test_installed_cache_path_is_rewritten(self):
        self.assertEqual(
            g.normalize_hook_path("/h/.claude/plugins/silver-bullet/hooks/a/b.sh"),
            f"{P}/hooks/a/b.sh",
        )

    def test_already_plugin_rooted_and_other_paths_pass_through(self):
        self.assertEqual(g.normalize_hook_path(f"{P}/hooks/x.sh"), f"{P}/hooks/x.sh")
        self.assertEqual(g.normalize_hook_path("/opt/other/x.sh"), "/opt/other/x.sh")


class ExtractHookPathTest(unittest.TestCase):
    def test_bridge_command_returns_third_token(self):
        cmd = '"${CLAUDE_PLUGIN_ROOT}/hooks/cursor-hook-bridge.sh" preToolUse hooks/x.sh'
        self.assertEqual(g.extract_hook_path(cmd), "hooks/x.sh")

    def test_bridge_command_short_returns_stripped_command(self):
        cmd = '"/a/cursor-hook-bridge.sh"'
        self.assertEqual(g.extract_hook_path(cmd), "/a/cursor-hook-bridge.sh")

    def test_bridge_command_unbalanced_quote_falls_back_to_split(self):
        cmd = "/a/cursor-hook-bridge.sh ev 'x.sh"
        self.assertEqual(g.extract_hook_path(cmd), "'x.sh")

    def test_codex_adapter_command(self):
        cmd = "bash ${CLAUDE_PLUGIN_ROOT}/hooks/codex-hook-adapter.sh PreToolUse ${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"
        self.assertEqual(g.extract_hook_path(cmd), f"{P}/hooks/x.sh")

    def test_plain_command_uses_last_token(self):
        self.assertEqual(
            g.extract_hook_path("${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"), f"{P}/hooks/x.sh"
        )

    def test_adapter_without_enough_args_uses_last_token(self):
        self.assertEqual(g.extract_hook_path("codex-hook-adapter.sh Pre"), "Pre")

    def test_unbalanced_quote_plain_command_falls_back_to_split(self):
        self.assertEqual(g.extract_hook_path("run 'x.sh"), "'x.sh")

    def test_empty_command(self):
        self.assertEqual(g.extract_hook_path(""), "")
        self.assertEqual(g.extract_hook_path('""'), "")


class RewriteCommandTest(unittest.TestCase):
    def test_bridge_command_only_substitutes_root(self):
        cmd = '"${CLAUDE_PLUGIN_ROOT}/hooks/cursor-hook-bridge.sh" preToolUse x.sh'
        self.assertEqual(
            g.rewrite_command(cmd, "stop"), f'"{P}/hooks/cursor-hook-bridge.sh" preToolUse x.sh'
        )

    def test_plain_hook_is_wrapped_in_bridge(self):
        self.assertEqual(
            g.rewrite_command("${CLAUDE_PLUGIN_ROOT}/hooks/x.sh", "stop"),
            f'"{P}/hooks/cursor-hook-bridge.sh" stop {P}/hooks/x.sh',
        )

    def test_path_with_space_is_quoted(self):
        out = g.rewrite_command("/odd dir/x.sh", "stop")
        # last token only: shlex split yields '/odd dir/x.sh' as two tokens -> 'dir/x.sh'
        self.assertTrue(out.endswith(" dir/x.sh"))
        quoted = g.rewrite_command('"/odd dir/x.sh"', "stop")
        self.assertTrue(quoted.endswith(' "/odd dir/x.sh"'))

    def test_already_quoted_space_path_not_double_quoted(self):
        with mock.patch.object(g, "extract_hook_path", return_value='"/a b/x.sh"'), \
                mock.patch.object(g, "normalize_hook_path", side_effect=lambda p: p):
            out = g.rewrite_command("whatever", "stop")
        self.assertTrue(out.endswith(' "/a b/x.sh"'))
        self.assertNotIn('""', out)


class TranslateMatcherTest(unittest.TestCase):
    def test_empty_and_wildcard(self):
        self.assertEqual(g.translate_matcher("", "preToolUse"), "")
        self.assertEqual(g.translate_matcher(".*", "preToolUse"), ".*")

    def test_tool_names_are_translated_and_deduped(self):
        self.assertEqual(
            g.translate_matcher("Bash|exec_command|apply_patch|Edit|shell", "preToolUse"),
            "Shell|Write|Edit",
        )

    def test_exec_command_dropped_for_shell_events(self):
        self.assertIsNone(g.translate_matcher("Bash|exec_command", "beforeShellExecution"))
        self.assertIsNone(g.translate_matcher("exec_command", "afterShellExecution"))

    def test_only_separators_yields_none(self):
        self.assertIsNone(g.translate_matcher("| |", "preToolUse"))


class DuplicateDecisionTest(unittest.TestCase):
    def test_only_tool_events_with_shell_matchers(self):
        cmd = "${CLAUDE_PLUGIN_ROOT}/hooks/compliance-status.sh"
        self.assertTrue(g.should_duplicate_to_shell("PreToolUse", "Bash", cmd))
        self.assertTrue(g.should_duplicate_to_shell("PostToolUse", "Edit|exec_command", cmd))
        self.assertFalse(g.should_duplicate_to_shell("Stop", "Bash", cmd))
        self.assertFalse(g.should_duplicate_to_shell("PreToolUse", "Edit", cmd))
        self.assertFalse(g.should_duplicate_to_shell(
            "PreToolUse", "Bash", "${CLAUDE_PLUGIN_ROOT}/hooks/record-skill.sh"))

    def test_global_stack_hook(self):
        self.assertTrue(g.is_global_stack_hook("${CLAUDE_PLUGIN_ROOT}/hooks/rtk-gate.sh"))
        self.assertFalse(g.is_global_stack_hook("${CLAUDE_PLUGIN_ROOT}/hooks/other.sh"))

    def test_shell_event_names(self):
        self.assertEqual(g.shell_cursor_event("PreToolUse"), "beforeShellExecution")
        self.assertEqual(g.shell_cursor_event("PostToolUse"), "afterShellExecution")


def _cmd(name):
    return "${CLAUDE_PLUGIN_ROOT}/hooks/" + name


class BuildCursorHooksTest(unittest.TestCase):
    def test_build(self):
        src = {"hooks": {
            "UnknownEvent": [{"hooks": [{"command": _cmd("a.sh")}]}],
            "PreToolUse": [
                {"matcher": "Bash", "hooks": [
                    {"type": "command", "command": _cmd("compliance-status.sh"), "timeout": 7},
                    {"type": "prompt", "command": _cmd("skipped.sh")},
                    {"command": _cmd("rtk-gate.sh")},
                ]},
                {"matcher": "exec_command", "hooks": [{"command": _cmd("compliance-status.sh")}]},
                {"matcher": "|", "hooks": [{"command": _cmd("nomatcher.sh")}]},
            ],
            "PostToolUse": [
                {"matcher": "Bash", "hooks": [{"command": _cmd("trivial-file-clear.sh")}]},
            ],
            "Stop": [{"hooks": [{"command": _cmd("stop-check.sh"), "timeout": 3}]}],
        }}
        out = g.build_cursor_hooks(src)
        self.assertEqual(out["version"], 1)
        h = out["hooks"]
        self.assertNotIn("unknownEvent", h)
        pre = h["preToolUse"]
        self.assertEqual(pre[0]["matcher"], "Shell")
        self.assertEqual(pre[0]["timeout"], 7)
        self.assertTrue(pre[0]["command"].endswith(f"preToolUse {P}/hooks/compliance-status.sh"))
        self.assertTrue(all("rtk-gate" not in e["command"] for e in pre))
        self.assertTrue(all("skipped.sh" not in e["command"] for e in pre))
        self.assertNotIn("matcher", pre[-1])
        self.assertTrue(pre[-1]["command"].endswith("nomatcher.sh"))
        before = h["beforeShellExecution"]
        self.assertEqual(len(before), 2)  # the Bash group and the exec_command group
        self.assertEqual(before[0]["matcher"], ".*")
        self.assertEqual(before[0]["timeout"], 7)
        after = h["afterShellExecution"]
        self.assertEqual(after[0]["matcher"], ".*")
        self.assertNotIn("timeout", after[0])
        self.assertEqual(h["stop"][0]["timeout"], 3)
        self.assertNotIn("matcher", h["stop"][0])

    def test_missing_hooks_key(self):
        self.assertEqual(g.build_cursor_hooks({}), {"version": 1, "hooks": {}})

    def test_shell_duplicate_without_timeout_has_no_timeout_key(self):
        src = {"hooks": {"PreToolUse": [
            {"matcher": "Bash", "hooks": [{"command": _cmd("compliance-status.sh")}]}]}}
        h = g.build_cursor_hooks(src)["hooks"]
        self.assertNotIn("timeout", h["beforeShellExecution"][0])
        self.assertNotIn("timeout", h["preToolUse"][0])

    def test_real_manifest_builds(self):
        src = json.loads((REPO_ROOT / "hooks" / "hooks.json").read_text())
        out = g.build_cursor_hooks(src)
        committed = json.loads((REPO_ROOT / "hooks" / "cursor-hooks.json").read_text())
        self.assertEqual(out, committed)


class MainTest(unittest.TestCase):
    def test_main_writes_both_outputs(self):
        with tempfile.TemporaryDirectory() as d:
            d = pathlib.Path(d)
            hooks_json = d / "hooks.json"
            hooks_json.write_text(json.dumps({"hooks": {"Stop": [
                {"hooks": [{"command": _cmd("stop-check.sh")}]}]}}))
            out = d / "out" / "cursor-hooks.json"
            out.parent.mkdir()
            plugin_out = d / "plug" / "deep" / "cursor-hooks.json"
            buf = io.StringIO()
            with mock.patch.object(g, "HOOKS_JSON", hooks_json), \
                    mock.patch.object(g, "OUT_JSON", out), \
                    mock.patch.object(g, "PLUGIN_OUT_JSON", plugin_out), \
                    contextlib.redirect_stdout(buf):
                rc = g.main()
            self.assertEqual(rc, 0)
            self.assertEqual(out.read_text(), plugin_out.read_text())
            data = json.loads(out.read_text())
            self.assertIn("stop", data["hooks"])
            self.assertTrue(out.read_text().endswith("}\n"))
            self.assertIn(f"wrote {out}", buf.getvalue())
            self.assertIn(f"wrote {plugin_out}", buf.getvalue())

    def test_invalid_manifest_raises(self):
        with tempfile.TemporaryDirectory() as d:
            bad = pathlib.Path(d) / "hooks.json"
            bad.write_text("{not json")
            with mock.patch.object(g, "HOOKS_JSON", bad):
                with self.assertRaises(json.JSONDecodeError):
                    g.main()

    def test_script_entrypoint_exit_zero(self):
        # Run as __main__ with the repo-writing paths redirected by a patched pathlib write.
        written = []
        def fake_write(self, data, *a, **k):
            written.append(str(self))
            return len(data)

        with mock.patch.object(pathlib.Path, "write_text", fake_write), \
                mock.patch.object(pathlib.Path, "mkdir", lambda *a, **k: None), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "generate-cursor-hooks.py"),
                               run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertEqual(len(written), 2)


if __name__ == "__main__":
    unittest.main()

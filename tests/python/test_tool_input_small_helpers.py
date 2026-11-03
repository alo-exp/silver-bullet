"""Unit tests for the small hooks/lib/tool-input/*.py helpers.

Covers tool_command_string.py, shell_unwrap_rtk.py, skill_adapter_invocation.py,
patch_paths.py and invoked_script_path.py (argv in, stdout/exit code out).
"""

import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tool_input_support import run_tool_input_script


def payload(**tool_input):
    return json.dumps({"tool_name": "Bash", "tool_input": tool_input})


class ToolCommandStringTest(unittest.TestCase):
    def run_script(self, arg):
        return run_tool_input_script("tool_command_string.py", arg)

    def test_command_string_is_printed_verbatim(self):
        res = self.run_script(payload(command="git status --short"))
        self.assertEqual(res.code, 0)
        self.assertEqual(res.stdout, "git status --short")

    def test_cmd_key_is_used_when_command_missing(self):
        res = self.run_script(payload(cmd="ls -la"))
        self.assertEqual(res.stdout, "ls -la")

    def test_command_list_is_shell_quoted(self):
        res = self.run_script(payload(command=["git", "commit", "-m", "two words", 3]))
        self.assertEqual(res.stdout, "git commit -m 'two words' 3")

    def test_non_string_non_list_command_prints_nothing(self):
        res = self.run_script(payload(command={"nested": "x"}))
        self.assertEqual((res.code, res.stdout), (0, ""))

    def test_invalid_json_exits_cleanly(self):
        res = self.run_script("{not json")
        self.assertEqual((res.code, res.stdout), (0, ""))

    def test_empty_argument_is_treated_as_empty_object(self):
        res = self.run_script("")
        self.assertEqual((res.code, res.stdout), (0, ""))

    def test_tool_input_that_is_not_an_object_is_ignored(self):
        res = self.run_script(json.dumps({"tool_input": "git push"}))
        self.assertEqual((res.code, res.stdout), (0, ""))
        res = self.run_script(json.dumps(["not", "an", "object"]))
        self.assertEqual((res.code, res.stdout), (0, ""))

    def test_payload_can_come_from_stdin(self):
        # A payload over 128 KiB cannot be one argv element; the hooks send it on stdin.
        big = payload(command="git commit -m x # " + "a" * 200000)
        for args in ((), ("-",)):
            with self.subTest(args=args), mock.patch("sys.stdin", io.StringIO(big)):
                res = run_tool_input_script("tool_command_string.py", *args)
            self.assertTrue(res.stdout.startswith("git commit -m x # aaa"))
            self.assertEqual(len(res.stdout), len("git commit -m x # ") + 200000)


class ShellUnwrapRtkTest(unittest.TestCase):
    def run_script(self, arg):
        return run_tool_input_script("shell_unwrap_rtk.py", arg)

    def test_strips_env_rtk_disabled_and_rtk_wrapper(self):
        res = self.run_script("env RTK_DISABLED=1 rtk git commit -m 'a b'")
        self.assertEqual(res.stdout, "git commit -m 'a b'")

    def test_strips_other_assignments_and_rtk_disabled_variants(self):
        res = self.run_script("FOO=bar RTK_DISABLED=true git push origin")
        self.assertEqual(res.stdout, "git push origin")

    def test_plain_command_is_requoted_unchanged(self):
        res = self.run_script("gh pr create --title x")
        self.assertEqual(res.stdout, "gh pr create --title x")

    def test_empty_payload_prints_nothing(self):
        res = self.run_script("")
        self.assertEqual((res.code, res.stdout), (0, ""))

    def test_whitespace_payload_prints_nothing(self):
        res = self.run_script("   ")
        self.assertEqual((res.code, res.stdout), (0, ""))

    def test_unbalanced_quote_echoes_payload(self):
        res = self.run_script("git commit -m 'oops")
        self.assertEqual(res.stdout, "git commit -m 'oops")

    def test_wrapper_only_prints_nothing(self):
        res = self.run_script("env RTK_DISABLED=1 rtk")
        self.assertEqual((res.code, res.stdout), (0, ""))


class SkillAdapterInvocationTest(unittest.TestCase):
    def run_script(self, arg):
        return run_tool_input_script("skill_adapter_invocation.py", arg)

    def test_relative_adapter_invoke_skill_matches(self):
        res = self.run_script("scripts/silver-bullet invoke-skill silver-feature")
        self.assertEqual((res.code, res.stdout), (0, "adapter\n"))

    def test_env_assignments_and_absolute_adapter_match(self):
        res = self.run_script("env SB_X=1 FOO=2 /opt/sb/scripts/silver-bullet invoke-skill silver-plan")
        self.assertEqual((res.code, res.stdout), (0, "adapter\n"))

    def test_other_subcommand_is_rejected(self):
        res = self.run_script("scripts/silver-bullet doctor")
        self.assertEqual((res.code, res.stdout), (1, ""))

    def test_other_program_is_rejected(self):
        res = self.run_script("scripts/other invoke-skill x")
        self.assertEqual(res.code, 1)

    def test_adapter_without_subcommand_is_rejected(self):
        res = self.run_script("FOO=1 scripts/silver-bullet")
        self.assertEqual(res.code, 1)

    def test_shell_control_operators_are_rejected(self):
        for cmd in (
            "scripts/silver-bullet invoke-skill x; git push",
            "scripts/silver-bullet invoke-skill x && rm -rf y",
            "scripts/silver-bullet invoke-skill x > out.txt",
        ):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.run_script(cmd).code, 1)

    def test_empty_and_unparseable_payloads_are_rejected(self):
        self.assertEqual(self.run_script("").code, 1)
        self.assertEqual(self.run_script("scripts/silver-bullet 'unterminated").code, 1)


class PatchPathsTest(unittest.TestCase):
    def run_script(self, arg):
        return run_tool_input_script("patch_paths.py", arg)

    def test_collects_add_update_delete_and_move_paths_once(self):
        patch = "\n".join(
            [
                "*** Begin Patch",
                "*** Add File: src/new.py",
                "+print('x')",
                "*** Update File: src/old.py",
                "*** Move to: src/renamed.py",
                "*** Delete File: src/gone.py",
                "*** Update File: src/old.py",
                "*** End Patch",
            ]
        )
        res = self.run_script(json.dumps({"tool_input": {"input": patch}}))
        self.assertEqual(res.lines, ["src/new.py", "src/old.py", "src/renamed.py", "src/gone.py"])

    def test_walks_nested_lists_and_dicts_and_ignores_non_strings(self):
        tool_input = {
            "patches": [{"body": "*** Add File: a.txt"}, 7, None, ["*** Delete File: b.txt"]],
            "count": 2,
        }
        res = self.run_script(json.dumps({"tool_input": tool_input}))
        self.assertEqual(res.lines, ["a.txt", "b.txt"])

    def test_blank_path_after_marker_is_skipped(self):
        res = self.run_script(json.dumps({"tool_input": {"input": "*** Add File:   \n*** Add File: ok.md"}}))
        self.assertEqual(res.lines, ["ok.md"])

    def test_missing_tool_input_and_bad_json_print_nothing(self):
        self.assertEqual(self.run_script(json.dumps({"tool_name": "Edit"})).stdout, "")
        self.assertEqual(self.run_script("").stdout, "")
        bad = self.run_script("[[[")
        self.assertEqual((bad.code, bad.stdout), (0, ""))


class InvokedScriptPathTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.base = Path(self._tmp.name).resolve()
        (self.base / "tools").mkdir()
        self.script = self.base / "tools" / "run.sh"
        self.script.write_text("echo hi\n")
        (self.base / "a-dir.sh").mkdir()

    def tearDown(self):
        self._tmp.cleanup()

    def run_script(self, command, base=None):
        return run_tool_input_script("invoked_script_path.py", str(base or self.base), command)

    def test_bash_script_argument_is_resolved_against_base_dir(self):
        res = self.run_script("bash -x tools/run.sh arg")
        self.assertEqual(res.lines, [str(self.script)])

    def test_direct_relative_and_absolute_scripts_are_resolved(self):
        self.assertEqual(self.run_script("./tools/run.sh").lines, [str(self.script)])
        self.assertEqual(self.run_script(f"{self.script} --flag").lines, [str(self.script)])
        self.assertEqual(self.run_script("env A=1 tools/run.sh").lines, [str(self.script)])

    def test_nested_shell_dash_c_is_unwrapped(self):
        res = self.run_script("bash -c \"sh -lc 'zsh tools/run.sh'\"")
        self.assertEqual(res.lines, [str(self.script)])

    def test_home_relative_script_is_expanded(self):
        with mock.patch.dict(os.environ, {"HOME": str(self.base)}):
            res = self.run_script("~/tools/run.sh")
        self.assertEqual(res.lines, [str(self.script)])

    def test_missing_or_non_file_targets_print_nothing(self):
        self.assertEqual(self.run_script("bash tools/missing.sh").stdout, "")
        self.assertEqual(self.run_script("./a-dir.sh").stdout, "")

    def test_non_script_commands_print_nothing(self):
        for cmd in (
            "python3 tools/run.sh",
            "bash -e",
            "bash -c",
            "bash -c ''",
            "env FOO=1",
            "",
            "bash 'unterminated",
        ):
            with self.subTest(cmd=cmd):
                res = self.run_script(cmd)
                self.assertEqual((res.code, res.stdout), (0, ""))


class StdinTransportTest(unittest.TestCase):
    """Every helper takes its input on stdin when the argument is "-" (how tool-input.sh calls
    them), so inputs larger than one argv element (128 KiB on Linux) still arrive whole."""

    PAD = " # " + "a" * 200000

    def run_stdin(self, name, text, *args):
        with mock.patch("sys.stdin", io.StringIO(text)):
            return run_tool_input_script(name, *args, "-")

    def test_each_helper_reads_stdin(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = str(Path(tmp).resolve())
            Path(base, "run.sh").write_text("echo hi\n")
            self.assertEqual(self.run_stdin("shell_unwrap_rtk.py", "rtk git status" + self.PAD).stdout[:10],
                             "git status")
            self.assertEqual(self.run_stdin("skill_adapter_invocation.py",
                                            "scripts/silver-bullet invoke-skill x" + self.PAD).code, 0)
            self.assertEqual(self.run_stdin("command_looks_read_only.py", "ls" + self.PAD).code, 0)
            self.assertEqual(self.run_stdin("candidate_write_paths.py", "echo x > o.txt" + self.PAD, base).lines,
                             [str(Path(base, "o.txt"))])
            self.assertEqual(self.run_stdin("invoked_script_path.py", "bash run.sh" + self.PAD, base).lines,
                             [str(Path(base, "run.sh"))])
            patch = json.dumps({"tool_input": {"input": "*** Add File: big.txt\n+" + "a" * 200000}})
            self.assertEqual(self.run_stdin("patch_paths.py", patch).lines, ["big.txt"])


if __name__ == "__main__":
    unittest.main()

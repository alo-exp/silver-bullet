"""Unit tests for scripts/lib/strip-cursor-sb-hooks.py (temp HOME only)."""
from __future__ import annotations

import contextlib
import io
import json
import os
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT

SCRIPT = str(REPO_ROOT / "scripts/lib/strip-cursor-sb-hooks.py")

SB_COMMANDS = [
    "bash /x/silver-bullet/1.2.3/hooks/a.sh",
    "bash ${CURSOR_PLUGIN_ROOT}/hooks/b.sh",
    "bash /repo/plugins/silver-bullet/hooks/c.sh",
    "bash codex-hook-adapter.sh cursor-hook-bridge.sh d",
]


class StripCursorHooksTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name).resolve()
        self.home = self.tmp / "home"
        (self.home / ".cursor").mkdir(parents=True)
        self.target = self.home / ".cursor" / "hooks.json"

    def run_script(self, *args):
        out = io.StringIO()
        with mock.patch.dict(os.environ, {"HOME": str(self.home)}), \
             mock.patch("sys.argv", ["strip-cursor-sb-hooks.py", *map(str, args)]), \
             contextlib.redirect_stdout(out):
            runpy.run_path(SCRIPT, run_name="__main__")
        return out.getvalue()

    def seed(self, data):
        raw = data if isinstance(data, str) else json.dumps(data)
        self.target.write_text(raw)
        return raw.encode()

    def assert_untouched(self, raw):
        self.assertEqual(self.target.read_bytes(), raw)
        self.assertEqual(sorted(p.name for p in self.target.parent.iterdir()), ["hooks.json"])

    def test_missing_file_is_skipped(self):
        with self.assertRaises(SystemExit) as cm:
            self.run_script(self.target)
        self.assertEqual(cm.exception.code, 0)
        self.assertFalse(self.target.exists())

    def test_default_path_uses_home(self):
        raw = self.seed({"hooks": {"stop": [{"command": SB_COMMANDS[0]}]}})
        out = self.run_script()
        self.assertIn("SB hooks stripped", out)
        self.assertEqual(json.loads(self.target.read_text()), {"hooks": {}})
        self.assertNotEqual(self.target.read_bytes(), raw)

    def test_explicit_argv_path_wins_over_default_home_file(self):
        decoy = self.seed({"hooks": {"stop": [{"command": SB_COMMANDS[0]}]}})
        other = self.tmp / "elsewhere" / "custom-hooks.json"
        other.parent.mkdir()
        other.write_text(json.dumps({"hooks": {"stop": [{"command": SB_COMMANDS[1]}, {"command": "echo mine"}]}}))
        out = self.run_script(other)
        self.assertIn(f"SB hooks stripped from {other}", out)
        self.assertEqual(json.loads(other.read_text()), {"hooks": {"stop": [{"command": "echo mine"}]}})
        self.assertEqual(self.target.read_bytes(), decoy)  # the default $HOME file was not touched

    def test_strips_every_sb_shape_and_keeps_foreign(self):
        foreign = {"command": "echo mine"}
        self.seed({
            "version": 1,
            "hooks": {
                "preToolUse": [{"command": c} for c in SB_COMMANDS] + [foreign],
                "stop": [{"command": SB_COMMANDS[0]}],
                "custom": {"not": "a list"},
            },
        })
        out = self.run_script(self.target)
        self.assertIn(f"SB hooks stripped from {self.target}", out)
        data = json.loads(self.target.read_text())
        self.assertEqual(data["version"], 1)
        self.assertEqual(data["hooks"]["preToolUse"], [foreign])
        self.assertNotIn("stop", data["hooks"])
        self.assertEqual(data["hooks"]["custom"], {"not": "a list"})
        self.assertEqual(sorted(p.name for p in self.target.parent.iterdir()), ["hooks.json"])

    def test_written_file_uses_two_space_indent_and_trailing_newline(self):
        self.seed({"version": 1, "hooks": {"stop": [{"command": SB_COMMANDS[0]}, {"command": "mine"}]}})
        self.run_script(self.target)
        self.assertEqual(
            self.target.read_text(),
            '{\n  "version": 1,\n  "hooks": {\n    "stop": [\n      {\n        "command": "mine"\n      }\n    ]\n  }\n}\n',
        )

    def test_commands_with_only_one_of_the_adapter_markers_are_foreign(self):
        foreign = [
            {"command": "bash /opt/tools/codex-hook-adapter.sh run"},
            {"command": "bash /opt/tools/cursor-hook-bridge.sh run"},
        ]
        raw = self.seed({"hooks": {"stop": foreign}})
        out = self.run_script(self.target)
        self.assertIn("No SB hooks found", out)
        self.assert_untouched(raw)
        self.seed({"hooks": {"stop": foreign + [{"command": SB_COMMANDS[3]}]}})
        self.run_script(self.target)
        self.assertEqual(json.loads(self.target.read_text()), {"hooks": {"stop": foreign}})

    def test_failed_write_leaves_original_intact_and_no_temp_file(self):
        raw = self.seed({"hooks": {"stop": [{"command": SB_COMMANDS[0]}, {"command": "mine"}]}})
        with mock.patch("os.replace", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(OSError, "disk full"):
                self.run_script(self.target)
        self.assert_untouched(raw)

    def test_rewrite_preserves_permissions_and_symlinked_file(self):
        real = self.tmp / "dotfiles" / "hooks.json"
        real.parent.mkdir()
        real.write_text(json.dumps({"hooks": {"stop": [{"command": SB_COMMANDS[0]}, {"command": "mine"}]}}))
        real.chmod(0o640)
        self.target.symlink_to(real)
        self.run_script(self.target)
        self.assertTrue(self.target.is_symlink())
        self.assertEqual(json.loads(real.read_text()), {"hooks": {"stop": [{"command": "mine"}]}})
        self.assertEqual(real.stat().st_mode & 0o777, 0o640)
        self.assertEqual(sorted(p.name for p in real.parent.iterdir()), ["hooks.json"])

    def test_idempotent_second_run_reports_nothing_found(self):
        self.seed({"hooks": {"stop": [{"command": SB_COMMANDS[0]}, {"command": "x"}]}})
        self.run_script(self.target)
        after_first = self.target.read_bytes()
        out = self.run_script(self.target)
        self.assertIn(f"No SB hooks found in {self.target}", out)
        self.assertEqual(self.target.read_bytes(), after_first)

    def test_no_change_leaves_file_byte_identical(self):
        raw = self.seed('{"hooks":   {"stop": [{"command": "mine"}]}}')
        out = self.run_script(self.target)
        self.assertIn("No SB hooks found", out)
        self.assert_untouched(raw)

    def test_missing_or_null_hooks_key_is_noop(self):
        for payload in ({}, {"hooks": None}, {"hooks": {}}):
            raw = self.seed(payload)
            out = self.run_script(self.target)
            self.assertIn("No SB hooks found", out)
            self.assert_untouched(raw)

    def test_foreign_entries_of_odd_shape_are_preserved(self):
        odd = ["a string", 7, None, {"command": 5}, {"no": "command"}]
        self.seed({"hooks": {"stop": odd + [{"command": SB_COMMANDS[0]}]}})
        self.run_script(self.target)
        self.assertEqual(json.loads(self.target.read_text()), {"hooks": {"stop": odd}})

    def test_empty_foreign_event_list_is_preserved(self):
        self.seed({"hooks": {"keep": [], "stop": [{"command": SB_COMMANDS[0]}]}})
        self.run_script(self.target)
        self.assertEqual(json.loads(self.target.read_text()), {"hooks": {"keep": []}})

    def test_empty_falsy_hooks_value_is_noop(self):
        for empty in ([], "", 0):
            raw = self.seed({"hooks": empty})
            self.assertIn("No SB hooks found", self.run_script(self.target))
            self.assert_untouched(raw)

    def test_invalid_json_raises_clear_error_and_keeps_file(self):
        raw = self.seed("{not json")
        with self.assertRaisesRegex(ValueError, "not valid JSON"):
            self.run_script(self.target)
        self.assert_untouched(raw)

    def test_wrong_typed_top_level_raises_and_keeps_file(self):
        raw = self.seed([1, 2])
        with self.assertRaisesRegex(ValueError, "JSON object"):
            self.run_script(self.target)
        self.assert_untouched(raw)

    def test_wrong_typed_hooks_raises_and_keeps_file(self):
        for bad in ([{"command": SB_COMMANDS[0]}], "text", 5):
            raw = self.seed({"hooks": bad})
            with self.assertRaisesRegex(ValueError, "'hooks' must be a JSON object"):
                self.run_script(self.target)
            self.assert_untouched(raw)


if __name__ == "__main__":
    unittest.main()

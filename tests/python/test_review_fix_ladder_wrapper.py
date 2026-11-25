"""Unit tests for the scripts/review-fix-ladder.py wrapper (re-exports the impl API, delegates main)."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import runpy
import sys
import unittest
from unittest import mock

from sbtest import REPO_ROOT, load_module

REL = "scripts/review-fix-ladder.py"
SCRIPT = str(REPO_ROOT / REL)
HERE = str(REPO_ROOT / "scripts")
LIB = str(REPO_ROOT / "scripts" / "lib")


class WrapperTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.w = load_module(REL, name="rfl_wrapper_under_test")

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch("sys.argv", ["review-fix-ladder.py", *argv]), \
             contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = self.w.main()
        return rc, out.getvalue(), err.getvalue()

    def test_impl_public_api_reexported_but_not_private(self):
        self.assertTrue(callable(self.w.resolve_ladder))
        self.assertTrue(callable(self.w.detect_host))
        self.assertFalse(hasattr(self.w, "decide_launch"))  # subscription-first / Cursor routing is gone
        self.assertFalse(hasattr(self.w, "_ORIG_DECIDE_LAUNCH"))
        self.assertIsNot(self.w.main, self.w._impl.main)

    def test_main_delegates_to_the_impl(self):
        with mock.patch.object(self.w._impl, "main", return_value=7) as impl_main:
            rc, out, _ = self.run_main("--model", "x")
        self.assertEqual((rc, out), (7, ""))
        impl_main.assert_called_once_with()

    def test_impl_main_result_is_coerced_to_int(self):
        with mock.patch.object(self.w._impl, "main", return_value=True):
            rc, _, _ = self.run_main()
        self.assertIs(type(rc), int)
        self.assertEqual(rc, 1)

    def test_policy_flag_runs_through_the_impl(self):
        rc, out, _ = self.run_main("--launcher-steps")
        self.assertEqual(rc, 0)
        self.assertIsInstance(json.loads(out)["steps"], list)

    def test_sys_path_gets_lib_and_here_when_absent(self):
        trimmed = [p for p in sys.path if p not in (LIB, HERE)]
        with mock.patch.object(sys, "path", trimmed):
            load_module(REL, name="rfl_wrapper_fresh_a")
            self.assertIn(LIB, trimmed)
            self.assertIn(HERE, trimmed)

    def test_sys_path_not_duplicated_when_present(self):
        path = [LIB, HERE] + [p for p in sys.path if p not in (LIB, HERE)]
        with mock.patch.object(sys, "path", path):
            load_module(REL, name="rfl_wrapper_fresh_b")
            self.assertEqual(path.count(LIB), 1)
            self.assertEqual(path.count(HERE), 1)

    def test_unloadable_impl_raises_import_error(self):
        with mock.patch.object(importlib.util, "spec_from_file_location", return_value=None):
            with self.assertRaisesRegex(ImportError, "cannot load the review-fix-ladder implementation"):
                runpy.run_path(SCRIPT, run_name="rfl_wrapper_noload")

    def test_entrypoint_exits_with_the_impl_status(self):
        out = io.StringIO()
        with mock.patch("sys.argv", ["review-fix-ladder.py", "--launcher-steps"]), contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(SCRIPT, run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertIn("steps", json.loads(out.getvalue()))


if __name__ == "__main__":
    unittest.main()

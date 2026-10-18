"""Unit tests for the scripts/review-fix-ladder.py wrapper (policy dispatch + decide_launch route)."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import runpy
import sys
import unittest
from pathlib import Path
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

    def test_impl_public_api_reexported_but_not_private_or_overridden(self):
        w = self.w
        self.assertTrue(callable(w.subscription_family_for_model))
        self.assertIsNot(w.main, w._impl.main)
        self.assertIs(w._impl.decide_launch, w.decide_launch)
        self.assertIsNot(w.decide_launch, w._ORIG_DECIDE_LAUNCH)

    def test_decide_launch_attaches_default_host_route(self):
        payload = self.w.decide_launch("gpt-5", "high")
        route = self.w._rfl_policy.default_agent_host_route("gpt-5")
        self.assertEqual(payload["default_agent_host"], route["host"])
        self.assertEqual(payload["default_agent_skill"], route["skill"])
        self.assertEqual(payload["default_agent_route"], route["route"])
        self.assertIs(payload["preserves_host_mode"], True)
        self.assertEqual(payload["action"], "invoke_subscription")

    def test_decide_launch_passes_subscription_arguments(self):
        payload = self.w.decide_launch(
            "gpt-5", "high", prefix="zz", subscription_exit=0, subscription_output="ok"
        )
        self.assertEqual(payload["action"], "accept_subscription")
        self.assertTrue(payload["subagent_name"].startswith("zz"))

    def test_policy_flag_is_dispatched_without_running_impl(self):
        with mock.patch.object(self.w._impl, "main", side_effect=AssertionError("impl ran")):
            rc, out, _ = self.run_main("--launcher-steps")
        self.assertEqual(rc, 0)
        self.assertIsInstance(json.loads(out)["steps"], list)

    def test_default_host_route_flag(self):
        rc, out, _ = self.run_main("--default-host-route", "--model", "gpt-5")
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["route"], "/sb:agent-codex")

    def test_non_policy_args_fall_through_to_impl_main(self):
        with mock.patch.object(self.w._impl, "main", return_value=7) as impl_main:
            rc, out, _ = self.run_main("--model", "x")
        self.assertEqual(rc, 7)
        impl_main.assert_called_once_with()
        self.assertEqual(out, "")

    def test_impl_main_result_is_coerced_to_int(self):
        with mock.patch.object(self.w._impl, "main", return_value=True):
            rc, _, _ = self.run_main()
        self.assertIs(type(rc), int)
        self.assertEqual(rc, 1)

    def test_sys_path_gets_lib_and_here_when_absent(self):
        trimmed = [p for p in sys.path if p not in (LIB, HERE)]
        with mock.patch.object(sys, "path", trimmed):
            load_module(REL, name="rfl_wrapper_fresh_a")
            # the wrapper inserts both; sbtest also puts the script dir first
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
            with self.assertRaisesRegex(ImportError, "cannot load review-fix-ladder impl"):
                runpy.run_path(SCRIPT, run_name="rfl_wrapper_noload")

    def test_entrypoint_exits_with_policy_status(self):
        out = io.StringIO()
        with mock.patch("sys.argv", ["review-fix-ladder.py", "--launcher-steps"]), \
             contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(SCRIPT, run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertIn("steps", json.loads(out.getvalue()))


if __name__ == "__main__":
    unittest.main()

"""gh accepts persistent flags (-R/--repo) between the command group and the subcommand: the delivery is still seen."""

from __future__ import annotations

import os
import sys
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sbtest  # noqa: E402

sa = sbtest.load_module("hooks/lib/tool-input/shell_analysis.py", "sbtest_sa_gh_order")


class GhOptionOrderTests(unittest.TestCase):
    def actions(self, cmd):
        return sa.analyze_command(cmd, "/tmp", False)["actions"]

    def test_flags_between_group_and_subcommand(self):
        for cmd, action in (
                ("gh pr -R o/r merge 1 --squash", "pr_merge"), ("gh pr -R=o/r merge 1", "pr_merge"),
                ("gh pr -Ro/r merge 1", "pr_merge"), ("gh pr --repo o/r create --fill", "pr_create"),
                ("gh pr --repo=o/r create", "pr_create"), ("gh release -R o/r create v9 --target X", "release_create"),
                ("gh release --repo o/r edit v9", "release_create"), ("gh release -R o/r upload v9 a.zip", "release_create"),
                ("gh -R X pr merge 1", "pr_merge"), ("gh --repo X pr create", "pr_create"),
                ("gh pr merge 12 -R X", "pr_merge"), ("gh release create v9 --repo X", "release_create"),
                ("GH_REPO=X gh pr merge 1", "pr_merge"), ("gh pr -R o/r --draft -R p/q merge 1", "pr_merge")):
            with self.subTest(cmd=cmd):
                self.assertIn(action, self.actions(cmd))

    def test_not_deliveries(self):
        for cmd in ("gh pr -R o/r list", "gh pr --repo o/r view 1", "gh release -R o/r list", "gh pr -R o/r"):
            with self.subTest(cmd=cmd):
                self.assertEqual(self.actions(cmd), [])

    def test_dynamic_flag_is_possible_delivery(self):
        result = sa.analyze_command('gh pr "$F" merge 1', "/tmp", False)
        self.assertIn("pr_merge", result["possible_actions"])


if __name__ == "__main__":
    unittest.main()

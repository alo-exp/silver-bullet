"""Unit tests for scripts/lib/rfl_launcher_policy.py (pure library: launch retry/skip, tables, matrix)."""
from __future__ import annotations

import unittest
from unittest import mock

from sbtest import load_module

lp = load_module("scripts/lib/rfl_launcher_policy.py")


class LaunchActionTest(unittest.TestCase):
    def act(self, **kw):
        args = dict(attempts=1, outcome="timeout")
        args.update(kw)
        return lp.next_launch_action(**args)

    def test_validation(self):
        with self.assertRaisesRegex(ValueError, "attempts must be >= 1"):
            self.act(attempts=0)
        with self.assertRaisesRegex(ValueError, "unsupported phase"):
            self.act(phase="later")
        with self.assertRaisesRegex(ValueError, "unsupported outcome"):
            self.act(outcome="weird")
        with self.assertRaisesRegex(ValueError, "unsupported outcome"):
            self.act(outcome=None)

    def test_success(self):
        out = self.act(outcome=" SUCCESS ", attempts=3)
        self.assertEqual((out["action"], out["post_ladder_retry_done"], out["attempts"]),
                         ("continue", False, 3))
        out = self.act(outcome="success", phase="post_ladder")
        self.assertEqual((out["action"], out["post_ladder_retry_done"]), ("recovered", True))
        self.assertFalse(out["skipped"] or out["retry"])

    def test_first_failure_retries_immediately(self):
        for outcome in ("cannot_launch", "TIMEOUT"):
            out = self.act(outcome=outcome)
            self.assertEqual((out["action"], out["retry"], out["retry_kind"], out["skipped"]),
                             ("retry_immediate", True, "immediate", False))

    def test_exact_payloads(self):
        base = {"outcome": "timeout", "phase": "rung", "attempts": 1}
        self.assertEqual(self.act(), {
            **base, "action": "retry_immediate", "skipped": False, "retry": True,
            "retry_kind": "immediate", "post_ladder_retry_pending": False,
            "post_ladder_retry_done": False})
        self.assertEqual(self.act(attempts=2), {
            **base, "attempts": 2, "action": "skip", "skipped": True, "retry": False,
            "retry_kind": None, "post_ladder_retry_pending": True,
            "post_ladder_retry_done": False})
        self.assertEqual(self.act(phase="post_ladder", attempts=2), {
            **base, "attempts": 2, "phase": "post_ladder", "action": "remain_skipped",
            "skipped": True, "retry": False, "retry_kind": None,
            "post_ladder_retry_pending": False, "post_ladder_retry_done": True})
        ok = self.act(outcome="success")
        self.assertEqual((ok["skipped"], ok["retry"], ok["retry_kind"],
                          ok["post_ladder_retry_pending"], ok["post_ladder_retry_done"]),
                         (False, False, None, False, False))

    def test_second_failure_skips_and_never_substitutes_a_model(self):
        out = self.act(attempts=2)
        self.assertEqual((out["action"], out["skipped"], out["retry"], out["post_ladder_retry_pending"]), ("skip", True, False, True))
        self.assertNotIn("substitute_model", out)
        self.assertEqual(self.act(attempts=7)["action"], "skip")

    def test_post_ladder_failure_remains_skipped(self):
        out = self.act(phase="post_ladder", attempts=5)
        self.assertEqual((out["action"], out["skipped"], out["post_ladder_retry_pending"],
                          out["post_ladder_retry_done"]), ("remain_skipped", True, False, True))

    def test_phase_defaults_when_blank(self):
        self.assertEqual(self.act(phase=None)["phase"], "rung")
        with self.assertRaisesRegex(ValueError, "unsupported phase"):
            self.act(phase="  ")


class SkipArtifactTest(unittest.TestCase):
    def artifact(self, **kw):
        args = dict(rung=3, event="", outcome="timeout", attempts=2)
        args.update(kw)
        fake = mock.Mock()
        fake.now.return_value.strftime.return_value = "2030-01-01T00:00:00Z"
        with mock.patch.object(lp, "datetime", fake):
            return lp.skip_retry_artifact(**args)

    def test_skip_payload(self):
        out = self.artifact(next_rung="4")
        self.assertEqual(out["event"], "skip")
        self.assertEqual(out["timestamp"], "2030-01-01T00:00:00Z")
        self.assertEqual(out["action"], "skip")
        self.assertEqual(out["skipped_md"], (
            "# SKIPPED — rung 3\n\n- reason: `timeout`\n- event: `skip`\n- attempts: 2\n"
            "- phase: `rung`\n- timestamp: 2030-01-01T00:00:00Z\n- next_rung: 4\n"
            "- post_ladder_retry_pending: True\n"))

    def test_next_rung_zero_is_shown_and_none_is_na(self):
        self.assertIn("- next_rung: 0\n", self.artifact(next_rung=0)["skipped_md"])
        self.assertIn("- next_rung: n/a\n", self.artifact()["skipped_md"])

    def test_explicit_event(self):
        out = self.artifact(event="custom", next_rung=None)
        self.assertEqual(out["event"], "custom")
        self.assertEqual(out["action"], "skip")
        self.assertTrue(out["skipped_md"].startswith("# SKIPPED — rung 3\n"))
        self.assertIn("- next_rung: n/a\n", out["skipped_md"])

    def test_invalid_outcome_raises(self):
        with self.assertRaises(ValueError):
            self.artifact(outcome="success-ish")


class RenderTest(unittest.TestCase):

    def test_normalize_severity(self):
        for raw, want in (("high", "HIGH"), ("Blockers", "HIGH"), ("medium", "MED"),
                          ("lows", "LOW"), ("nitpicks", "NIT"), ("", "LOW"), (None, "LOW"),
                          ("weird", "LOW"), ("  nit ", "NIT")):
            self.assertEqual(lp.normalize_severity(raw), want, raw)

    def test_issue_table(self):
        out = lp.render_issue_table([
            {"id": "A|1", "title": "t\nx", "severity": "blocker"},
            {"id": "B", "title": "nit title", "severity": "nits"},
            {"id": "C"},
            {"id": "D", "severity": None},
            {"id": "E", "severity": "weird"},
        ])
        self.assertTrue(out.startswith("## Reported issues (by severity)\n\n### HIGH\n\n"))
        self.assertTrue(out.endswith("|\n"))
        self.assertIn("### HIGH\n\n| ID | Title |\n|----|-------|\n| A\\|1 | t x |\n", out)
        self.assertIn("### MED\n\n| ID | Title |\n|----|-------|\n| — | **none** |\n", out)
        self.assertIn("### LOW\n\n| ID | Title |\n|----|-------|\n| C |  |\n| D |  |\n| E |  |\n", out)
        self.assertIn("### NIT\n\n| ID | Title |\n|----|-------|\n| B | nit title |\n", out)

    def test_issue_table_empty(self):
        out = lp.render_issue_table([])
        self.assertEqual(out.count("| — | **none** |"), 4)

    def test_triage_table(self):
        self.assertIn("| — | — | — | **none** |", lp.render_triage_table([]))
        out = lp.render_triage_table([
            {"id": "A", "severity": "medium", "decision": " accept ", "reason": "a|b"},
            {},
        ])
        lines = out.splitlines()
        self.assertEqual(lines[-2], "| A | MED | ACCEPT | a\\|b |")
        self.assertEqual(lines[-1], "|  | LOW |  |  |")
        self.assertTrue(out.endswith("|\n"))

    def test_resolved_table(self):
        self.assertIn("| — | — | — | — | **none** |", lp.render_resolved_table([]))
        out = lp.render_resolved_table([
            {"id": "A", "severity": "high", "title": "T", "decision": "accept", "resolved": True},
            {"id": "B", "decision": "reject", "resolved": False},
            {"id": "C", "resolved": "n/a"},
            {"id": "D"},
        ])
        lines = out.splitlines()
        self.assertEqual(lines[-4:], [
            "| A | HIGH | T | ACCEPT | yes |",
            "| B | LOW |  | REJECT | no |",
            "| C | LOW |  |  | n/a |",
            "| D | LOW |  |  |  |",
        ])

    def test_ladder_matrix_totals_and_footnotes(self):
        out = lp.render_ladder_complete_matrix([
            {"rung": 1, "reviewer": "opus", "high": 1, "med": "2", "low": None, "nit": 3,
             "accepted": 4, "clean": True},
            {"rung": "2|b", "reviewer": "gpt", "reported": 9, "id_collision": True,
             "skipped_then_retried": True},
            {"rung": 3, "reported": 0, "high": 5},
        ])
        lines = out.splitlines()
        self.assertIn("| 1 | opus | 1 | 2 | 0 | 3 | 6 | 4 |", lines)
        self.assertIn("| 2\\|b | gpt | 0 | 0 | 0 | 0 | 9 | 0 |", lines)
        self.assertIn("| 3 |  | 5 | 0 | 0 | 0 | 0 | 0 |", lines)  # explicit reported=0 kept
        self.assertIn("| TOTAL | — | 6 | 2 | 0 | 3 | 15 | 4 |", lines)
        self.assertIn("Footnotes:", lines)
        self.assertIn("- Rung 1: CLEAN", lines)
        self.assertIn("- Rung 2\\|b: ID collision; skipped-then-retried", lines)
        self.assertNotIn("- Rung 3", "\n".join(lines))
        self.assertTrue(out.endswith("\n"))

    def test_ladder_matrix_empty(self):
        out = lp.render_ladder_complete_matrix([])
        self.assertIn("| TOTAL | — | 0 | 0 | 0 | 0 | 0 | 0 |", out)
        self.assertIn("Footnotes: none.", out)
        self.assertNotIn("Footnotes:\n", out)

    def test_ladder_matrix_non_numeric_count_raises(self):
        with self.assertRaises(ValueError):
            lp.render_ladder_complete_matrix([{"high": "many"}])

    def test_mandatory_steps_is_a_copy(self):
        steps = lp.launcher_mandatory_steps()
        self.assertEqual(steps, list(lp.LAUNCHER_MANDATORY_STEPS))
        steps.append("x")
        self.assertNotIn("x", lp.launcher_mandatory_steps())

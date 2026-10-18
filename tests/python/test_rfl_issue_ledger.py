"""Unit tests for scripts/lib/rfl_issue_ledger.py."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from sbtest import load_module

led = load_module("scripts/lib/rfl_issue_ledger.py")


class NormalizeTest(unittest.TestCase):
    def test_severity(self):
        n = led._norm_severity
        self.assertEqual(n("high"), "HIGH")
        self.assertEqual(n(" Medium "), "MED")
        self.assertEqual(n("nitpick"), "NIT")
        self.assertEqual(n("NITPICKS"), "NIT")
        self.assertEqual(n("low-nit"), "NIT")
        self.assertEqual(n("bogus"), "LOW")
        self.assertEqual(n(""), "LOW")
        self.assertEqual(n(None), "LOW")

    def test_decision(self):
        n = led._norm_decision
        for raw in ("reject-as-wrong", "REJECT_AS_WRONG", "wrong", "reject"):
            self.assertEqual(n(raw), "REJECT", raw)
        self.assertEqual(n("accept"), "ACCEPT")
        self.assertEqual(n("KEEP REJECT collision"), "REJECT")
        self.assertEqual(n("accept-apply"), "ACCEPT")
        self.assertEqual(n("deferred"), "DEFERRED")
        self.assertEqual(n(""), "ACCEPT")
        self.assertEqual(n(None), "ACCEPT")

    def test_resolved(self):
        n = led._norm_resolved
        self.assertEqual(n(True), "yes")
        self.assertEqual(n(False), "no")  # JSON false is "no", not missing/empty
        for raw in ("YES", "y", "true", "Applied", "done"):
            self.assertEqual(n(raw), "yes", raw)
        for raw in ("n/a", "NA", "—", "-"):
            self.assertEqual(n(raw), "n/a", raw)
        for raw in ("no", "n", "false", "pending", "", None, 0):
            self.assertEqual(n(raw), "no", raw)
        self.assertEqual(n("Maybe"), "maybe")

    def test_short_sha_and_md_cell(self):
        self.assertEqual(led._short_sha("a" * 40), "a" * 12)
        self.assertEqual(led._short_sha("a" * 12), "a" * 12)
        self.assertEqual(led._short_sha("  abc "), "abc")
        self.assertEqual(led._short_sha(None), "")
        self.assertEqual(led._md_cell("a|b\nc "), "a\\|b c")
        self.assertEqual(led._md_cell(5), "5")

    def test_normalize_row_aliases(self):
        row = led.normalize_ledger_row({
            "id": " X-1 ", "severity": "medium", "status": "reject", "resolved": False,
            "apply_sha": " abc ", "title": "line1\nline2 "})
        self.assertEqual(row, {"id": "X-1", "severity": "MED", "decision": "REJECT",
                               "resolved": "no", "sha": "abc", "summary": "line1 line2"})
        row = led.normalize_ledger_row({"id": "X", "decision": "ACCEPT", "status": "REJECT",
                                        "sha": "s", "apply_sha": "t", "summary": "S",
                                        "title": "T", "resolved": "yes"})
        self.assertEqual((row["decision"], row["sha"], row["summary"]), ("ACCEPT", "s", "S"))
        row = led.normalize_ledger_row({"one_line": "ol"})
        self.assertEqual(row, {"id": "", "severity": "LOW", "decision": "ACCEPT",
                               "resolved": "no", "sha": "", "summary": "ol"})
        self.assertEqual(led.normalize_ledger_row({"id": None, "summary": None})["summary"], "")


class MergeTest(unittest.TestCase):
    def merge(self, *rows):
        return led.merge_ledger_rows(list(rows))

    def test_skips_rows_without_id_and_keeps_order(self):
        out = self.merge({"id": "B"}, {"summary": "orphan"}, {"id": "A"})
        self.assertEqual([r["id"] for r in out], ["B", "A"])

    def test_duplicate_merge_prefers_longer_text_and_yes(self):
        out = self.merge(
            {"id": "A", "severity": "LOW", "summary": "short", "sha": "", "resolved": "no"},
            {"id": "A", "severity": "HIGH", "summary": "a longer one", "sha": "abc",
             "resolved": "yes", "decision": "REJECT"},
        )
        self.assertEqual(len(out), 1)
        row = out[0]
        self.assertEqual((row["severity"], row["summary"], row["sha"], row["resolved"],
                          row["decision"]), ("HIGH", "a longer one", "abc", "yes", "REJECT"))

    def test_shorter_later_text_does_not_replace_and_empty_never_does(self):
        out = self.merge(
            {"id": "A", "summary": "the long summary", "sha": "abcdef"},
            {"id": "A", "summary": "short", "sha": ""},
        )
        self.assertEqual((out[0]["summary"], out[0]["sha"]), ("the long summary", "abcdef"))

    def test_resolved_precedence(self):
        def res(a, b):
            return self.merge({"id": "A", "resolved": a}, {"id": "A", "resolved": b})[0]["resolved"]

        self.assertEqual(res("yes", "no"), "yes")
        self.assertEqual(res("yes", "n/a"), "yes")
        self.assertEqual(res("n/a", "yes"), "yes")
        self.assertEqual(res("no", "n/a"), "n/a")
        self.assertEqual(res("n/a", "no"), "n/a")
        self.assertEqual(res("no", "no"), "no")


LEDGER_MD = """\
Freeze SHA after APPLY: `abcdef0123456789`

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| ID | x | y | z |
| — | — | — | — |
| -x | a | b | c |
| R-1 | high | ACCEPT | Missing check |
| R-2 | nit | REJECT-as-wrong | Not a bug | extra
| short | cells |
| after | table | closed | row |

freeze sha after apply: `1234567890abcdef`
| ID | Severity | Status | Summary |
| R-3 | med | accepted | Second table |
text ends table
| R-4 | low | accept | not in a table |
"""


class MarkdownTest(unittest.TestCase):
    def test_parse_markdown(self):
        rows = led.parse_issue_ledger_markdown(LEDGER_MD)
        self.assertEqual([r["id"] for r in rows], ["R-1", "R-2", "R-3"])
        r1, r2, r3 = rows
        self.assertEqual((r1["severity"], r1["decision"], r1["resolved"], r1["sha"]),
                         ("HIGH", "ACCEPT", "yes", "abcdef0123456789"))
        self.assertEqual((r2["severity"], r2["decision"], r2["resolved"]),
                         ("NIT", "REJECT", "n/a"))
        self.assertEqual(r2["summary"], "Not a bug")
        self.assertEqual((r3["sha"], r3["severity"], r3["decision"]),
                         ("1234567890abcdef", "MED", "ACCEPT"))

    def test_parse_empty(self):
        self.assertEqual(led.parse_issue_ledger_markdown(""), [])
        self.assertEqual(led.parse_issue_ledger_markdown("| R | a | b | c |\n"), [])

    def test_sha_must_be_hex_8_to_64(self):
        text = "Freeze SHA after APPLY: `abc`\n| ID | Severity | Status | Summary |\n| R | low | accept | s |\n"
        self.assertEqual(led.parse_issue_ledger_markdown(text)[0]["sha"], "")


class PolicyCPayloadTest(unittest.TestCase):
    def test_full_payload(self):
        payload = {
            "apply_sha": " deadbeefdeadbeef ",
            "issues": {
                "HIGH": [{"id": "H-1", "title": "high issue"}, "junk", {"id": ""}, {"summary": "x"}],
                "MED": [{"id": "M-1", "summary": "med issue"}],
                "LOW": "none", "NIT": "", "X": None, "Y": {"not": "list"}, "Z": 5,
            },
            "resolved": [
                {"id": "H-1", "resolved": True},
                {"id": "R-9", "resolved": "yes", "title": "only resolved"},
                "junk", {"id": ""},
            ],
            "triage": [
                {"id": "H-1", "severity": "high", "decision": "accept", "reason": "r"},
                {"id": "T-1", "severity": "low", "decision": "reject", "reason": "triage reason"},
                {"id": "", "severity": "low"},
                "junk",
            ],
        }
        rows = {r["id"]: r for r in led.parse_policy_c_payload(payload)}
        self.assertEqual(list(rows), ["H-1", "T-1", "M-1", "R-9"])
        self.assertEqual(rows["H-1"], {"id": "H-1", "severity": "HIGH", "decision": "ACCEPT",
                                       "resolved": "yes", "sha": "deadbeefdeadbeef",
                                       "summary": "high issue"})
        self.assertEqual(rows["T-1"]["summary"], "triage reason")
        self.assertEqual((rows["T-1"]["decision"], rows["T-1"]["resolved"]), ("REJECT", "no"))
        self.assertEqual(rows["M-1"]["severity"], "LOW")
        self.assertEqual(rows["M-1"]["decision"], "ACCEPT")
        self.assertEqual(rows["M-1"]["summary"], "med issue")
        self.assertEqual(rows["R-9"]["summary"], "only resolved")
        self.assertEqual(rows["R-9"]["resolved"], "yes")

    def test_empty_and_odd_shapes(self):
        self.assertEqual(led.parse_policy_c_payload({}), [])
        self.assertEqual(led.parse_policy_c_payload({"issues": [1], "triage": "x"}), [])
        self.assertEqual(led.parse_policy_c_payload({"issues": None, "resolved": None,
                                                     "triage": None}), [])

    def test_non_list_resolved_does_not_crash(self):
        for bad in (5, True, {"id": "X"}, "text"):
            rows = led.parse_policy_c_payload(
                {"issues": {"HIGH": [{"id": "H", "title": "t"}]}, "resolved": bad})
            self.assertEqual([r["id"] for r in rows], ["H"], bad)


class CollectTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.run_dir = Path(self._tmp.name)

    def test_no_inputs(self):
        self.assertEqual(led.collect_issue_ledger(), [])
        self.assertEqual(led.collect_issue_ledger(rows=[]), [])
        self.assertEqual(led.collect_issue_ledger(run_dir=self.run_dir), [])

    def test_inline_rows_skip_non_dicts(self):
        out = led.collect_issue_ledger(rows=[{"id": "A", "severity": "high"}, "x", None])
        self.assertEqual([r["id"] for r in out], ["A"])

    def test_missing_run_dir_directory(self):
        self.assertEqual(led.collect_issue_ledger(run_dir=self.run_dir / "nope"), [])

    def test_all_sources_merged_with_freeze_sha(self):
        (self.run_dir / "ISSUE-LEDGER.md").write_text(
            "| ID | Severity | Status | Summary |\n| A | high | accept | from md |\n")
        sub = self.run_dir / "sub"
        sub.mkdir()
        (sub / "POLICY-C-2.json").write_text(json.dumps(
            {"issues": {"HIGH": [{"id": "A", "title": "longer from policy"}]},
             "triage": [{"id": "A", "severity": "high", "decision": "accept"}]}))
        (self.run_dir / "POLICY-C.json").write_text(json.dumps({"apply_sha": "cafebabe12345678"}))
        (self.run_dir / "POLICY-CAT.json").write_text(json.dumps(
            {"issues": {"LOW": [{"id": "SKIPPED", "title": "x"}]}}))
        (self.run_dir / "POLICY-C-bad.json").write_text("{nope")
        (self.run_dir / "POLICY-C-list.json").write_text("[1]")
        (self.run_dir / "LADDER-STATUS.json").write_text(
            json.dumps({"freeze": {"apply_sha": "1111111111111111"}}))
        out = led.collect_issue_ledger(run_dir=self.run_dir, rows=[{"id": "B", "sha": "own"}])
        by = {r["id"]: r for r in out}
        self.assertEqual(sorted(by), ["A", "B"])
        self.assertEqual(by["A"]["summary"], "longer from policy")
        self.assertEqual(by["A"]["sha"], "1111111111111111")
        self.assertEqual(by["B"]["sha"], "own")

    def test_freeze_sha256_preferred_and_non_dict_freeze_ignored(self):
        (self.run_dir / "LADDER-STATUS.json").write_text(
            json.dumps({"freeze": {"sha256": "aaaaaaaaaaaaaaaa", "apply_sha": "b"}}))
        out = led.collect_issue_ledger(run_dir=self.run_dir, rows=[{"id": "A"}])
        self.assertEqual(out[0]["sha"], "aaaaaaaaaaaaaaaa")
        for freeze in ("str", None, {}):
            (self.run_dir / "LADDER-STATUS.json").write_text(json.dumps({"freeze": freeze}))
            out = led.collect_issue_ledger(run_dir=self.run_dir, rows=[{"id": "A"}])
            self.assertEqual(out[0]["sha"], "")

    def test_bad_ladder_status_ignored(self):
        for text in ("{bad", "[1]"):
            (self.run_dir / "LADDER-STATUS.json").write_text(text)
            out = led.collect_issue_ledger(run_dir=self.run_dir, rows=[{"id": "A"}])
            self.assertEqual(out[0]["sha"], "")

    def test_undecodable_files_are_skipped_not_fatal(self):
        (self.run_dir / "POLICY-C.json").write_bytes(b"\xff\xfe{")
        (self.run_dir / "LADDER-STATUS.json").write_bytes(b"\xff\xfe{")
        (self.run_dir / "ISSUE-LEDGER.md").write_bytes(b"\xff\xfe| ID |")
        out = led.collect_issue_ledger(run_dir=self.run_dir, rows=[{"id": "A"}])
        self.assertEqual([r["id"] for r in out], ["A"])

    def test_iter_policy_c_files(self):
        (self.run_dir / "POLICY-C.json").write_text("{}")
        (self.run_dir / "POLICY-C_x.json").write_text("{}")
        (self.run_dir / "POLICY-Cx.json").write_text("{}")
        (self.run_dir / "POLICY-C.txt").write_text("{}")
        names = [p.name for p in led._iter_policy_c_files(self.run_dir)]
        self.assertEqual(names, ["POLICY-C.json", "POLICY-C_x.json"])
        self.assertEqual(led._iter_policy_c_files(self.run_dir / "none"), [])


class RenderTest(unittest.TestCase):
    ROWS = [{"id": "A|1", "severity": "HIGH", "decision": "ACCEPT", "resolved": "yes",
             "sha": "a" * 20, "summary": "multi\nline | pipe"}]

    def test_render_ledger(self):
        text = led.render_issue_ledger(self.ROWS)
        lines = text.splitlines()
        self.assertEqual(lines[0], "## Issue ledger (already identified)")
        self.assertTrue(text.endswith("|\n"))
        self.assertEqual(lines[-1], "| A\\|1 | HIGH | ACCEPT | yes | aaaaaaaaaaaa | multi line \\| pipe |")

    def test_render_empty_ledger(self):
        self.assertIn("| — | — | — | — | — | **none** |", led.render_issue_ledger([]))
        self.assertEqual(led.render_issue_ledger([{}]).splitlines()[-1], "|  |  |  |  |  |  |")

    def test_render_brief_and_roundtrip(self):
        brief = led.render_review_brief(self.ROWS)
        self.assertTrue(brief.startswith("## Hop review (Policy G / pack-ledger)\n"))
        for rule in led.RESIDUAL_ONLY_RULES:
            self.assertIn(f"- {rule}", brief)
        self.assertIn("Do **not** re-file ledger IDs", brief)
        self.assertTrue(brief.endswith("ledger.\n"))

    def test_write_review_brief(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "a" / "b" / "brief.md"
            out = led.write_review_brief(str(target), self.ROWS)
            self.assertEqual(out, target)
            self.assertEqual(target.read_text(), led.render_review_brief(self.ROWS))


if __name__ == "__main__":
    unittest.main()

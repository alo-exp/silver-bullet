"""Coverage tests for extract_claims (in-process CLI runs)."""

import json
import tempfile
import unittest
from pathlib import Path

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import extract_claims as ec


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestClassify(unittest.TestCase):
    def test_recommendation_words_any_section(self):
        for sec in ("recommendations", "finding_1"):
            self.assertEqual(ec.classify_claim("Teams should adopt it.", sec), "recommendation")
        self.assertEqual(ec.classify_claim("We RECOMMEND this.", "x"), "recommendation")

    def test_speculation(self):
        self.assertEqual(ec.classify_claim("Prices might fall.", "finding_1"), "speculation")

    def test_synthesis_only_in_synthesis_like_sections(self):
        text = "Overall the data agree."
        for sec in ("synthesis", "conclusion", "limitations"):
            self.assertEqual(ec.classify_claim(text, sec), "synthesis")
        self.assertEqual(ec.classify_claim(text, "finding_1"), "factual")
        self.assertEqual(ec.classify_claim("Plain statement.", "synthesis"), "factual")

    def test_recommendation_beats_speculation(self):
        self.assertEqual(ec.classify_claim("You should note it might change.", "x"),
                         "recommendation")


class TestParsing(unittest.TestCase):
    def test_section_ids(self):
        md = "\n".join([
            "intro line", "## Executive Summary", "a", "## Introduction", "b",
            "## Finding 12: Thing", "c", "## Synthesis", "d", "## Limitations", "e",
            "## Recommendations", "f", "## Conclusion", "g", "## Random Heading Here!", "h",
        ])
        ids = [s for s, _ in ec.parse_sections(md)]
        self.assertEqual(ids, ["preamble", "executive_summary", "introduction", "finding_12",
                               "synthesis", "limitations", "recommendations", "conclusion",
                               "random_heading_here_"])

    def test_leading_header_has_no_preamble_and_empty_section_dropped(self):
        secs = ec.parse_sections("## Synthesis\n## Conclusion\nbody text")
        self.assertEqual(secs, [("conclusion", "body text")])

    def test_trailing_header_without_content(self):
        secs = ec.parse_sections("x\n## Synthesis")
        self.assertEqual(secs, [("preamble", "x")])

    def test_extract_sentences_strips_markdown_and_short_fragments(self):
        text = ("- **Bold claim** is made here for testing purposes. Short one. "
                "*Italic claim* shows up in this sentence too.")
        self.assertEqual(ec.extract_sentences(text), [
            "Bold claim is made here for testing purposes.",
            "Italic claim shows up in this sentence too.",
        ])

    def test_extract_sentences_drops_leading_table_and_heading(self):
        # only the first fragment of a text can begin with '|' or '#'
        self.assertEqual(ec.extract_sentences("| a table row that is clearly longer than thirty chars |"), [])
        self.assertEqual(ec.extract_sentences("# A heading that is clearly longer than thirty"), [])
        self.assertEqual(
            ec.extract_sentences("# A heading that is clearly longer than thirty. "
                                 "Real sentence that is long enough to keep."),
            ["Real sentence that is long enough to keep."])


class TestCLI(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.d = self._td.name
        self.claims = Path(self.d) / "claims.jsonl"

    def write_report(self, text):
        p = Path(self.d) / "report.md"
        p.write_text(text)
        return str(p)

    def test_extract_missing_report(self):
        code, out, err = call_main(ec, ["extract", "--report", "/nonexistent/r.md", "--dir", self.d])
        self.assertEqual(code, 1)
        self.assertIn("Report not found", err)

    def test_extract_claims_dedup_on_rerun(self):
        report = self.write_report(
            "Preamble sentence that must not become a claim at all.\n"
            "## Finding 1\n"
            "Solar capacity grew sharply in 2023 [1, 2]. Costs fell by half over the same period [3].\n"
            "## Recommendations\n"
            "Operators should expand storage capacity soon.\n")
        _, out, _ = call_main(ec, ["extract", "--report", report, "--dir", self.d])
        res = json.loads(out)
        self.assertEqual((res["claims_added"], res["claims_skipped"], res["total_claims"]), (3, 0, 3))
        rows = ec.read_jsonl(str(self.claims))
        self.assertEqual([r["section_id"] for r in rows], ["finding_1", "finding_1", "recommendations"])
        self.assertEqual(rows[0]["_citation_numbers"], [1, 2])
        self.assertEqual(rows[1]["_citation_numbers"], [3])
        self.assertEqual(rows[2]["claim_type"], "recommendation")
        self.assertEqual(rows[0]["support_status"], "unverified")
        _, out, _ = call_main(ec, ["extract", "--report", report, "--dir", self.d])
        res = json.loads(out)
        self.assertEqual((res["claims_added"], res["claims_skipped"], res["total_claims"]), (0, 3, 3))
        self.assertEqual(len(ec.read_jsonl(str(self.claims))), 3)

    def test_add_requires_text(self):
        code, _, err = call_main(ec, ["add", "--dir", self.d, "--json", json.dumps({"section_id": "s"})])
        self.assertEqual(code, 1)
        self.assertIn("text is required", err)

    def test_add_default_section_duplicate_and_type_fallback(self):
        _, out, _ = call_main(ec, ["add", "--dir", self.d, "--json", json.dumps(
            {"text": "A claim", "claim_type": "weird", "cited_source_ids": ["s1"]})])
        added = json.loads(out)
        self.assertEqual(added["status"], "added")
        _, out, _ = call_main(ec, ["add", "--dir", self.d, "--json", json.dumps({"text": "a  CLAIM"})])
        self.assertEqual(json.loads(out), {"status": "duplicate", "claim_id": added["claim_id"]})
        _, out, _ = call_main(ec, ["add", "--dir", self.d, "--json", json.dumps(
            {"text": "Other", "section_id": "synthesis", "claim_type": "synthesis"})])
        rows = ec.read_jsonl(str(self.claims))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["section_id"], "unknown")
        self.assertEqual(rows[0]["claim_type"], "factual")
        self.assertEqual(rows[0]["cited_source_ids"], ["s1"])
        self.assertEqual(rows[1]["claim_type"], "synthesis")

    def _seed(self):
        rows = [
            {"claim_id": "1", "section_id": "a", "claim_type": "factual", "support_status": "unverified"},
            {"claim_id": "2", "section_id": "b", "claim_type": "synthesis", "support_status": "supported"},
            {"claim_id": "3", "section_id": "a", "claim_type": "factual", "support_status": "supported"},
            {"claim_id": "3", "section_id": "a", "claim_type": "factual", "support_status": "supported"},
            {"claim_id": "4"},
        ]
        for r in rows:
            ec.append_jsonl(str(self.claims), r)

    def test_list_filters(self):
        self._seed()
        def ids(*extra):
            _, out, _ = call_main(ec, ["list", "--dir", self.d, *extra])
            return [c["claim_id"] for c in json.loads(out)["claims"]]
        self.assertEqual(ids(), ["1", "2", "3", "4"])
        self.assertEqual(ids("--section", "a"), ["1", "3"])
        self.assertEqual(ids("--type", "synthesis"), ["2"])
        self.assertEqual(ids("--status", "supported"), ["2", "3"])
        self.assertEqual(ids("--section", "a", "--type", "factual", "--status", "supported"), ["3"])

    def test_stats(self):
        self._seed()
        _, out, _ = call_main(ec, ["stats", "--dir", self.d])
        res = json.loads(out)
        self.assertEqual(res["total"], 4)
        self.assertEqual(res["by_type"], {"factual": 2, "synthesis": 1, "unknown": 1})
        self.assertEqual(res["by_status"], {"unverified": 1, "supported": 2, "unknown": 1})
        self.assertEqual(res["by_section"], {"a": 2, "b": 1, "unknown": 1})

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "extract_claims.py", ["stats", "--dir", self.d])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["total"], 0)


if __name__ == "__main__":
    unittest.main()

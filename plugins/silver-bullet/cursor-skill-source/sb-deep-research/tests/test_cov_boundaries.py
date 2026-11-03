"""Boundary tests (at / just below / just above each threshold) and write-behaviour pins."""

import json
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import build_sample_matrix, call_main

import citation_manager as cm
import deps_probe
import matrix_ops as mo
import search_orchestrator as so
import source_evaluator as se
import validate_report as vr

HAS_OPENPYXL = deps_probe.openpyxl_importable()
NOW = datetime(2026, 6, 1)


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class FakeDT(datetime):
    @classmethod
    def now(cls, tz=None):
        return datetime(2026, 6, 1, tzinfo=tz)


class TestSourceEvaluatorBoundaries(unittest.TestCase):
    def setUp(self):
        self.ev = se.SourceEvaluator()
        p = mock.patch.object(se, "datetime", FakeDT)
        p.start()
        self.addCleanup(p.stop)

    def age(self, days):
        return self.ev._evaluate_recency((NOW - timedelta(days=days)).date().isoformat())

    def test_recency_age_thresholds(self):
        cases = [(89, 100.0), (90, 85.0), (91, 85.0),
                 (364, 85.0), (365, 70.0), (366, 70.0),
                 (729, 70.0), (730, 50.0), (731, 50.0),
                 (1824, 50.0), (1825, 30.0), (1826, 30.0)]
        for days, expected in cases:
            self.assertEqual(self.age(days), expected, f"age {days} days")

    def test_bias_cap_and_floor(self):
        # arxiv (+20) with a balancing phrase (+10) reaches exactly 100 and is not reduced
        self.assertEqual(self.ev._evaluate_bias("arxiv.org", "t", "however")[0], 100.0)
        self.assertEqual(self.ev._evaluate_bias("arxiv.org", "t", None)[0], 90.0)
        # worst case (sensational title, nothing else) stays at 50, never below the clamp
        self.assertEqual(self.ev._evaluate_bias("x.com", "SECRET", None)[0], 50.0)

    def test_authority_tier_threshold(self):
        self.assertEqual(self.ev._authority_tier("a.com", 85.0), "primary")
        self.assertEqual(self.ev._authority_tier("a.com", 84.99), "secondary")
        self.assertEqual(self.ev._authority_tier("a.com", 85.01), "primary")
        self.assertEqual(self.ev._authority_tier("a.com", 65.0), "secondary")
        self.assertEqual(self.ev._authority_tier("a.com", 64.99), "tertiary")
        self.assertEqual(self.ev._authority_tier("a.com", 45.0), "tertiary")
        self.assertEqual(self.ev._authority_tier("a.com", 44.99), "unknown")

    def test_sensational_low_authority_is_E_below_50_only(self):
        f = self.ev._reliability_letter
        self.assertEqual(f(49.99, 0, ["sensationalism"]), "E")
        self.assertEqual(f(50.0, 0, ["sensationalism"]), "D")
        self.assertEqual(f(50.01, 0, ["sensationalism"]), "D")
        # other letter thresholds
        self.assertEqual(f(88, 75, []), "A")
        self.assertEqual(f(88, 74.99, []), "B")
        self.assertEqual(f(87.99, 100, []), "B")
        self.assertEqual(f(75, 0, []), "B")
        self.assertEqual(f(74.99, 0, []), "C")
        self.assertEqual(f(55, 0, []), "C")
        self.assertEqual(f(54.99, 0, []), "D")
        self.assertEqual(f(40, 0, []), "D")
        self.assertEqual(f(39.99, 0, []), "F")
        self.assertEqual(f(30, 0, []), "F")
        self.assertEqual(f(29.99, 0, []), "E")

    def factors(self, domain=60, recency=60, expertise=60, bias=60):
        return self.ev._identify_factors("d", domain, recency, expertise, bias, [])

    def test_factor_thresholds(self):
        self.assertIn("domain", self.factors(domain=85))
        self.assertNotIn("domain", self.factors(domain=84.99))
        self.assertIn("domain", self.factors(domain=45))
        self.assertNotIn("domain", self.factors(domain=45.01))
        self.assertIn("recency", self.factors(recency=85))
        self.assertNotIn("recency", self.factors(recency=84.99))
        self.assertIn("recency", self.factors(recency=40))
        self.assertNotIn("recency", self.factors(recency=40.01))
        self.assertEqual(self.factors(expertise=80)["expertise"], "Expert source")
        self.assertNotIn("expertise", self.factors(expertise=79.99))
        self.assertEqual(self.factors(expertise=45)["expertise"], "Limited expertise indicators")
        self.assertNotIn("expertise", self.factors(expertise=45.01))
        self.assertEqual(self.factors(bias=80)["bias"], "Balanced perspective")
        self.assertNotIn("bias", self.factors(bias=79.99))
        self.assertEqual(self.factors(bias=50)["bias"], "Potential bias detected")
        self.assertNotIn("bias", self.factors(bias=50.01))

    def test_recommendation_thresholds(self):
        f = self.ev._generate_recommendation
        self.assertEqual(f(60, "C3"), "moderate_trust")
        self.assertEqual(f(59.99, "C3"), "low_trust")
        self.assertEqual(f(60, "B3"), "moderate_trust")
        self.assertEqual(f(60, "D3"), "low_trust")
        self.assertEqual(f(75, "A1"), "high_trust")
        self.assertEqual(f(74.99, "A1"), "moderate_trust")
        self.assertEqual(f(40, "F6"), "low_trust")
        self.assertEqual(f(39.99, "F6"), "verify")


class TestValidateReportBoundaries(unittest.TestCase):
    def make(self, content, profile=None):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        p = Path(d.name) / "r.md"
        p.write_text(content, encoding="utf-8")
        v = vr.ReportValidator(p)
        if profile is not None:
            v.profile = profile
        return v

    def test_word_count_boundary(self):
        for n, warned in ((499, True), (500, False), (501, False)):
            v = self.make("w " * n)
            self.assertTrue(v._check_word_count())
            self.assertEqual(bool(v.warnings), warned, n)
        v = self.make("w " * 499)
        v._check_word_count()
        self.assertEqual(v.warnings, ["Report is very short: 499 words (consider expanding)"])

    def test_metadata_position_relative_to_bibliography(self):
        # metadata after the bibliography: unexpected sections between them are rejected
        v = self.make("## Bibliography\n[1] x\n## Surprise\n## Report Metadata\nm")
        self.assertFalse(v._check_bibliography_tail())
        # metadata before the bibliography: the section scan does not apply, whatever follows
        v = self.make("## Report Metadata\nm\n## Surprise\n## Bibliography\n[1] x")
        self.assertTrue(v._check_bibliography_tail())
        # same start offset (identical labels): empty gap, nothing to reject
        profile = {"section_labels": {"bibliography": "Same", "metadata": "Same"}}
        v = self.make("## Same\n## Surprise\n", profile=profile)
        self.assertTrue(v._check_bibliography_tail())
        # adjacent: metadata immediately after bibliography passes
        v = self.make("## Bibliography\n[1] x\n## Report Metadata\nm")
        self.assertTrue(v._check_bibliography_tail())


@unittest.skipUnless(HAS_OPENPYXL, "openpyxl not installed")
class TestMatrixOpsBehaviours(unittest.TestCase):
    def setUp(self):
        mo._require_openpyxl()
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.dir = Path(self._td.name)
        self.src = self.dir / "src.xlsx"
        self.out = self.dir / "out.xlsx"
        build_sample_matrix(self.src)

    def rgb(self, ws, row, col):
        return ws.cell(row, col).fill.fgColor.rgb

    def test_new_row_clones_style_of_preceding_row_not_the_one_before(self):
        mo.add_platform(str(self.src), str(self.out), "D", {},
                        [{"category": "Sec", "feature": "MFA"}, {"category": "Ops", "feature": "Hooks"}])
        ws = mo.openpyxl.load_workbook(self.out).active
        names = [ws.cell(r, 1).value for r in range(5, ws.max_row + 1)]
        self.assertEqual(names, ["Sec", "SSO", "Audit", "MFA", "Ops", "API", "CLI", "Hooks"])
        critical, high, medium, low = "00F4C7C3", "00FCE8B2", "00E8EEF4", "00F3F4F6"
        self.assertEqual(self.rgb(ws, 6, 2), critical)   # SSO
        self.assertEqual(self.rgb(ws, 7, 2), high)       # Audit (last row of Sec)
        # in-loop flush: MFA copies Audit (expanded[-1]), not SSO (expanded[-2])
        self.assertEqual(self.rgb(ws, 8, 2), high)
        self.assertEqual(self.rgb(ws, 10, 2), medium)    # API
        self.assertEqual(self.rgb(ws, 11, 2), low)       # CLI (last row of Ops)
        # post-loop flush: Hooks copies CLI, not API
        self.assertEqual(self.rgb(ws, 12, 2), low)

    def formula_priority_matrix(self):
        """Feature F2's priority cell is a formula (no cached value, as written by openpyxl)."""
        wb = mo.openpyxl.Workbook()
        ws = wb.active
        ws.append(["Capability / Feature", "Priority", "P1"])
        ws.append(["Total", "—", None])
        ws.append(["Score", "—", None])
        ws.append(["Cat", None, None])
        ws.append(["F1", "Critical", "✔"])
        ws.append(["F2", '="Critical"', "✔"])
        p = self.dir / "formula.xlsx"
        wb.save(p)
        return str(p)

    def test_read_only_views_use_cached_values_not_formulas(self):
        # a formula cell has no cached value, so with data_only=True F2 has no priority and is not
        # a feature row; reading formulas instead would count it (and its tick)
        p = self.formula_priority_matrix()
        feats = mo.extract_features(p)
        self.assertEqual(feats["total_features"], 1)
        self.assertEqual([f["name"] for f in feats["categories"][0]["features"]], ["F1"])
        self.assertEqual(mo.info(p)["total_features"], 1)
        self.assertEqual(mo.ranked_scores(p)["rankings"], [{"platform": "P1", "score": 5, "ticks": 1, "rank": 1}])
        self.assertEqual(mo.verify_ticks(p)["P1"]["total_features"], 1)

    def test_editing_views_keep_formulas(self):
        # the editing operations load without data_only, so formulas survive a round trip
        mo.reorder_columns_by_score(str(self.src), str(self.out))
        ws = mo.openpyxl.load_workbook(self.out).active
        self.assertTrue(str(ws.cell(3, 3).value).startswith("=COUNTIF("))


class TestWriteBehaviours(unittest.TestCase):
    def test_manifest_keeps_non_ascii_characters(self):
        with tempfile.TemporaryDirectory() as d:
            call_main(cm, ["init-run", "--out-dir", d, "--query", "café 日本"])
            raw = (Path(d) / "run_manifest.json").read_bytes()
            self.assertIn("café 日本".encode("utf-8"), raw)
            self.assertNotIn(b"\\u00e9", raw)

    def test_bibliography_json_keeps_non_ascii_characters(self):
        with tempfile.TemporaryDirectory() as d:
            cm.append_jsonl(str(Path(d) / "sources.jsonl"), {
                "source_id": "s", "canonical_locator": "c", "title": "café", "raw_url": "u"})
            _, out, _ = call_main(cm, ["export-bibliography", "--dir", d, "--style", "json"])
            self.assertIn("café", out)
            self.assertNotIn("\\u00e9", out)

    def test_orchestrator_creates_missing_parent_directories(self):
        with mock.patch("shutil.which", return_value=None), tempfile.TemporaryDirectory() as d:
            out_dir = Path(d) / "a" / "b" / "c"
            so.orchestrate("what is x", out_dir)
            self.assertTrue((out_dir / "run_manifest.json").is_file())

    def test_orchestrator_second_run_into_existing_dir(self):
        with mock.patch("shutil.which", return_value=None), tempfile.TemporaryDirectory() as d:
            so.orchestrate("q", Path(d))
            so.orchestrate("q", Path(d))
            self.assertTrue((Path(d) / "run_manifest.json").is_file())


if __name__ == "__main__":
    unittest.main()

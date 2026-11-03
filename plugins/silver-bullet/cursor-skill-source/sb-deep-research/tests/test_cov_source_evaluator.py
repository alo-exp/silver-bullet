"""Coverage tests for source_evaluator (clock pinned, no network)."""

import json
import unittest
from datetime import datetime
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import source_evaluator as se


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class FakeDT(datetime):
    """datetime whose now() is pinned to 2026-06-01."""

    @classmethod
    def now(cls, tz=None):
        return datetime(2026, 6, 1, tzinfo=tz)


class TestEvaluator(unittest.TestCase):
    def setUp(self):
        self.ev = se.SourceEvaluator()
        p = mock.patch.object(se, "datetime", FakeDT)
        p.start()
        self.addCleanup(p.stop)

    def test_extract_domain(self):
        self.assertEqual(self.ev._extract_domain("https://WWW.Example.COM/a"), "example.com")
        self.assertEqual(self.ev._extract_domain("not a url"), "")

    def test_subdomain_score(self):
        f = self.ev._subdomain_authority_score
        self.assertEqual(f("docs.python.org"), 90.0)
        self.assertEqual(f("developer.mozilla.org"), 90.0)
        self.assertEqual(f("nasa.gov"), 85.0)
        self.assertEqual(f("mit.edu"), 85.0)
        self.assertEqual(f("a.b.c.example.com"), 45.0)
        self.assertEqual(f("example.com"), 60.0)

    def test_domain_authority(self):
        f = self.ev._evaluate_domain_authority
        self.assertEqual(f("arxiv.org"), 90.0)
        self.assertEqual(f("github.com"), 70.0)
        self.assertEqual(f("foo.blogspot.com"), 40.0)
        self.assertEqual(f("agency.gov"), 88.0)
        self.assertEqual(f("uni.edu"), 88.0)
        self.assertEqual(f("random.io"), 55.0)

    def test_recency_buckets(self):
        f = self.ev._evaluate_recency
        self.assertEqual(f(None), 50.0)
        self.assertEqual(f(""), 50.0)
        self.assertEqual(f("2026-05-01"), 100.0)
        self.assertEqual(f("2025-12-01"), 85.0)
        self.assertEqual(f("2025-01-01"), 70.0)
        self.assertEqual(f("2022-01-01"), 50.0)
        self.assertEqual(f("2010-01-01"), 30.0)
        self.assertEqual(f("2026-05-20T00:00:00Z"), 100.0)  # tz-aware branch
        self.assertEqual(f("2010-01-01T00:00:00+00:00"), 30.0)
        self.assertEqual(f("garbage"), 50.0)

    def test_expertise(self):
        f = self.ev._evaluate_expertise
        self.assertEqual(f("example.com", "Title", None), 50.0)
        self.assertEqual(f("arxiv.org", "t", None), 80.0)
        self.assertEqual(f("nasa.gov", "t", None), 75.0)
        self.assertEqual(f("who.int", "t", None), 75.0)
        self.assertEqual(f("example.com", "API Documentation", None), 70.0)
        self.assertEqual(f("docs.example.com", "t", None), 70.0)
        self.assertEqual(f("example.com", "t", "Prof. X, PhD"), 65.0)
        self.assertEqual(f("example.com", "t", "Dr. Who"), 65.0)
        self.assertEqual(f("example.com", "t", "Jane"), 50.0)
        self.assertEqual(f("nature.com", "documentation", "Professor"), 100.0)  # capped

    def test_bias(self):
        f = self.ev._evaluate_bias
        self.assertEqual(f("example.com", "Plain", None), (70.0, []))
        self.assertEqual(f("example.com", "SHOCKING news", None), (50.0, ["sensationalism"]))
        self.assertEqual(f("arxiv.org", "t", None), (90.0, []))
        self.assertEqual(f("aws.amazon.com", "t", ""), (70.0, ["commercial"]))
        self.assertEqual(f("cloud.google.com", "t", None)[1], ["commercial"])
        self.assertEqual(f("learn.azure.microsoft.com", "t", None)[1], ["commercial"])
        self.assertEqual(f("example.com", "t", "However, X"), (80.0, []))
        self.assertEqual(f("example.com", "t", "no hedging here"), (70.0, []))
        self.assertEqual(f("arxiv.org", "t", "although"), (100.0, []))  # 70+20+10 capped
        self.assertEqual(f("example.com", "!", "critics argue")[0], 60.0)

    def test_bias_clamped_at_zero(self):
        with mock.patch.object(se.SourceEvaluator, "SENSATIONAL_PATTERNS", ["x"]):
            ev = se.SourceEvaluator()
            score, _ = ev._evaluate_bias("d", "x", None)
            self.assertEqual(score, 50.0)

    def test_authority_tier(self):
        f = self.ev._authority_tier
        self.assertEqual(f("a.com", 90), "primary")
        self.assertEqual(f("x.gov", 10), "primary")
        self.assertEqual(f("x.edu", 10), "primary")
        self.assertEqual(f("a.com", 70), "secondary")
        self.assertEqual(f("a.com", 50), "tertiary")
        self.assertEqual(f("a.com", 40), "unknown")

    def test_source_class(self):
        f = self.ev._source_class
        for t in ("government", "academic", "documentation"):
            self.assertEqual(f(t, "unknown"), "primary")
        self.assertEqual(f("news", "primary"), "secondary")
        self.assertEqual(f("web", "secondary"), "secondary")
        self.assertEqual(f("web", "unknown"), "tertiary")
        self.assertEqual(f(None, "primary"), "primary")
        self.assertEqual(f("other", "unknown"), "unknown")

    def test_reliability_letter(self):
        f = self.ev._reliability_letter
        self.assertEqual(f(40, 50, ["sensationalism"]), "E")
        self.assertEqual(f(90, 80, ["sensationalism"]), "A")
        self.assertEqual(f(90, 80, []), "A")
        self.assertEqual(f(90, 70, []), "B")
        self.assertEqual(f(75, 90, []), "B")
        self.assertEqual(f(60, 0, []), "C")
        self.assertEqual(f(40, 0, []), "D")
        self.assertEqual(f(35, 0, []), "F")
        self.assertEqual(f(10, 0, []), "E")

    def test_credibility_digit(self):
        f = self.ev._credibility_digit
        self.assertEqual(f(80, 85), "1")
        self.assertEqual(f(79, 85), "2")
        self.assertEqual(f(100, 70), "2")
        self.assertEqual(f(0, 55), "3")
        self.assertEqual(f(0, 40), "4")
        self.assertEqual(f(0, 25), "5")
        self.assertEqual(f(0, 24.9), "6")

    def test_identify_factors(self):
        f = self.ev._identify_factors
        flags = []
        self.assertEqual(f("d", 90, 90, 90, 90, flags), {
            "domain": "High authority domain", "recency": "Recent information",
            "expertise": "Expert source", "bias": "Balanced perspective"})
        self.assertEqual(flags, [])
        flags = []
        out = f("d", 40, 30, 40, 40, flags)
        self.assertEqual(out, {
            "domain": "Low authority domain - verify claims",
            "recency": "Outdated information - verify currency",
            "expertise": "Limited expertise indicators",
            "bias": "Potential bias detected"})
        self.assertEqual(flags, ["recency_risk"])
        flags = ["recency_risk"]
        f("d", 60, 30, 60, 60, flags)
        self.assertEqual(flags, ["recency_risk"])  # no duplicate
        self.assertEqual(f("d", 60, 60, 60, 60, []), {})

    def test_recommendation(self):
        f = self.ev._generate_recommendation
        self.assertEqual(f(80, "A1"), "high_trust")
        self.assertEqual(f(75, "B2"), "high_trust")
        self.assertEqual(f(74, "B2"), "moderate_trust")
        self.assertEqual(f(65, "C3"), "moderate_trust")
        self.assertEqual(f(65, "D3"), "low_trust")
        self.assertEqual(f(40, "F6"), "low_trust")
        self.assertEqual(f(10, "A1"), "verify")
        self.assertEqual(f(50, ""), "low_trust")  # empty code treated as F

    def test_evaluate_source_end_to_end(self):
        s = self.ev.evaluate_source("https://www.nature.com/articles/x", "A Study",
                                    content="However, results vary", publication_date="2026-05-20",
                                    author="Dr. Jane", source_type="academic")
        self.assertEqual(s.reliability_code, "A1")
        self.assertEqual(s.authority_tier, "primary")
        self.assertEqual(s.source_class, "primary")
        self.assertEqual(s.recommendation, "high_trust")
        self.assertEqual(s.domain_authority, 90.0)
        self.assertEqual(s.recency, 100.0)
        self.assertEqual(s.overall_score, round(90 * .35 + 100 * .20 + 95 * .25 + 100 * .20 + 60 * .05, 2))
        self.assertEqual(s.factors["domain"], "High authority domain")

    def test_evaluate_source_low_quality(self):
        s = self.ev.evaluate_source("https://x.blogspot.com/p", "SHOCKING!!", publication_date="2005-01-01")
        self.assertEqual(s.reliability_code[0], "E")
        self.assertIn("sensationalism", s.bias_flags)
        self.assertIn("recency_risk", s.bias_flags)
        self.assertGreaterEqual(s.overall_score, 40)
        self.assertEqual(s.recommendation, "low_trust")
        self.assertEqual(s.source_class, "unknown")


class TestCLI(unittest.TestCase):
    def test_plain_output(self):
        code, out, _ = call_main(se, ["--url", "https://nasa.gov/x", "--title", "Mission",
                                      "--source-type", "government"])
        self.assertEqual(code, 0)
        lines = dict(l.split(": ", 1) for l in out.strip().splitlines())
        self.assertEqual(lines["authority_tier"], "primary")
        self.assertIn("reliability_code", lines)
        self.assertEqual(lines["bias_flags"], "[]")
        self.assertEqual(lines["recommendation"], "high_trust")

    def test_json_output(self):
        code, out, _ = call_main(se, ["--url", "https://aws.amazon.com/x", "--title", "Docs", "--json",
                                      "--content", "however", "--author", "Dr. X",
                                      "--publication-date", "bad-date"])
        data = json.loads(out)
        self.assertIn("commercial", data["bias_flags"])
        self.assertEqual(data["recency"], 50.0)

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "source_evaluator.py", ["--url", "https://a.com", "--title", "t"])
        self.assertEqual(code, 0)
        self.assertIn("recommendation:", out)


if __name__ == "__main__":
    unittest.main()

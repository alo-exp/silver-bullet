"""Offline unit tests for validate_landscape_content: helpers, gates and CLI."""

from __future__ import annotations

import contextlib
import copy
import io
import json
import os
import socket
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import category_pack  # noqa: E402
import validate_landscape_content as vlc  # noqa: E402

PACK_ID = "agentic-sdlc-process-orchestrator"

ALL_SECTIONS = (
    "# Report\n\n## 1. Market Definition & Scope\n\nOut of scope: coding agents.\n\n"
    "## 2. Market Overview\n\n## 3. Competitive Positioning\n\n### 3A. Chart\n\n"
    "## 4. Key Industry Trends\n\n## 5. Top Commercial Solutions\n\n"
    "## 6. Top Open Source Solutions\n\n## 7. Adjacent Markets\n\n"
    "## 8. Explicitly Excluded\n\n## 9. Buying Guidance\n\n## 10. Future Outlook\n\n"
    "## 11. Source Reliability Assessment\n"
)

SPA_MARKERS = (
    "COMPARE_MAX = 10 type: 'radar' vc-compare-cb "
    "border: none; outline: none; background: var(--sb-snav-chip-bg) "
    "WAVE_ZONE_FILLS font-size: 1.875rem _scrollToVendorCard compareResultsSection"
)


def comparison(**over):
    base = {
        "winner": "silver-bullet",
        "rankings": [{"solution": "silver-bullet", "score": 25}, {"solution": "ai-dlc", "score": 20}],
        "rows": [
            {"type": "feature", "name": "Workflow composition", "priority": "Critical",
             "solutions": {"silver-bullet": True, "ai-dlc": True}},
            {"type": "feature", "name": "Hook-enforced gates", "priority": "Critical",
             "solutions": {"silver-bullet": True, "ai-dlc": False}},
        ],
    }
    base.update(over)
    return base


def chart(**over):
    base = {
        "mq_data": [{"label": "Silver Bullet", "q": "Leaders"}],
        "gmq_data": [{"label": "Silver Bullet", "q": "Challengers"}],
        "wave_data": [{"label": "Silver Bullet"}],
        "vc_commercial": [{"label": "Silver Bullet"}],
        "titles": {"vc": "Value Curve"},
    }
    base.update(over)
    return base


class _Base(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        spy = mock.patch.object(socket.socket, "connect", side_effect=AssertionError("network used"))
        spy.start()
        self.addCleanup(spy.stop)

    def put(self, rel, data):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data if isinstance(data, str) else json.dumps(data), encoding="utf-8")
        return path

    def run_validate(self, **kw):
        return vlc.validate_landscape_content(self.root, **kw)

    def errors(self, **kw):
        return self.run_validate(**kw)["errors"]


class HelperTests(_Base):
    def test_load_json(self):
        self.assertIsNone(vlc._load_json(self.root / "missing.json"))
        self.assertIsNone(vlc._load_json(self.put("list.json", [1, 2])))
        self.assertEqual(vlc._load_json(self.put("d.json", {"a": 1})), {"a": 1})

    def test_resolve_must_have(self):
        self.assertEqual(vlc._resolve_must_have_features(" Verification Gates "),
                         ["Hook-enforced gates", "Automated review loops", "CI integration"])
        self.assertEqual(vlc._resolve_must_have_features("sso login"), ["Sso Login"])

    def test_critical_fill_rate(self):
        self.assertEqual(vlc._critical_fill_rate({}), (0.0, 0, 0, 0.0))
        rate, filled, total, mean = vlc._critical_fill_rate({"rows": [
            "junk",
            {"type": "other", "priority": "Critical", "solutions": {"a": 1}},
            {"type": "feature", "priority": "High", "solutions": {"a": 1}},
            {"type": "feature", "priority": "Critical", "solutions": {"a": 1, "b": 1, "c": 0, "d": 0}},
            {"type": "feature", "priority": "Critical", "solutions": {"a": 1, "b": 0}},
            {"type": "feature", "priority": "Critical"},
        ]})
        self.assertEqual((filled, total), (3, 6))
        self.assertAlmostEqual(rate, 0.5)
        self.assertAlmostEqual(mean, 0.5)  # only the 2-of-4 row is "active" (>=2 filled)

    def test_winner_coverage(self):
        f = vlc._winner_must_have_coverage
        self.assertEqual(f({}, {"must_haves": ["x"]}), ["no winner in comparison.json"])
        self.assertEqual(f({"winner": "w"}, {}), [])
        comp = {"winner": "w", "rows": [
            "junk", {"type": "feature"}, {"type": "other", "name": "A"},
            {"type": "feature", "name": "Workflow composition", "solutions": {"w": True}},
            {"type": "feature", "name": "Hook-enforced gates", "solutions": {"w": False}},
            {"type": "feature", "name": "CI integration"},
            {"type": "feature", "name": "Automated review loops", "solutions": {"w": True}},
        ]}
        need = {"must_haves": ["workflow composition", "Verification Gates", "multi-agent orchestration",
                               "unknown thing"]}
        self.assertEqual(f(comp, need), ["winner 'w' lacks must-have 'unknown thing'"])

    def test_winner_coverage_gap_when_row_unfilled(self):
        comp = {"winner": "w", "rows": [
            {"type": "feature", "name": "Workflow composition", "solutions": {"w": False}}]}
        self.assertEqual(vlc._winner_must_have_coverage(comp, {"must_haves": ["workflow composition"]}),
                         ["winner 'w' lacks must-have 'workflow composition'"])

    def test_slug_display_and_topn(self):
        comp = {"rankings": ["junk", {"solution": ""}, {"solution": "Silver Bullet!"}, {"solution": "AI DLC"}]}
        self.assertEqual(vlc._slug_display_map(comp), {
            "Silver Bullet!": "Silver Bullet!", "silver-bullet": "Silver Bullet!",
            "AI DLC": "AI DLC", "ai-dlc": "AI DLC"})
        self.assertEqual(vlc._slug_display_map({}), {})
        self.assertEqual(vlc._collect_topn_slugs({}, None), set())
        got = vlc._collect_topn_slugs(
            comp,
            {"mq_data": ["junk", {"label": ""}, {"label": "AI DLC"}],
             "gmq_data": [{"label": "ai-dlc"}, {"label": "nothing"}],
             "wave_data": None})
        # chart labels can only re-add ranking solutions that are already present
        self.assertEqual(got, {"Silver Bullet!", "AI DLC"})


class CoreValidationTests(_Base):
    def test_missing_comparison(self):
        res = self.run_validate()
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["errors"], ["comparison/comparison.json missing or invalid"])
        self.put("comparison/comparison.json", [1])
        self.assertEqual(self.errors(), ["comparison/comparison.json missing or invalid"])

    def test_fill_rate_gates(self):
        def run(rows):
            self.put("comparison/comparison.json", comparison(rows=rows, winner=None, rankings=[]))
            return [e for e in self.errors(min_critical_fill_rate=0.5) if "Critical" in e]

        def mk(*fills):
            return [{"type": "feature", "priority": "Critical",
                     "solutions": {f"s{i}": v for i, v in enumerate(fills)}}]

        self.assertEqual(run([]), ["no Critical feature rows in comparison matrix"])
        self.assertEqual(len(run(mk(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))), 1)  # hollow (<10%)
        hollow = run(mk(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))[0]
        self.assertIn("hollow report", hollow)
        low = run(mk(1, 1, 0, 0, 0, 0))  # 33% < 50%, active mean 33%
        self.assertEqual(len(low), 1)
        self.assertIn("both below minimum 50%", low[0])
        self.assertEqual(run(mk(1, 1, 1, 0)), [])  # 75%
        # high active mean rescues a low overall rate
        rows = mk(1, 1, 0, 0, 0, 0, 0, 0, 0, 0)  # overall 20%, active mean 20%
        self.assertEqual(len(run(rows)), 1)
        rows = [{"type": "feature", "priority": "Critical", "solutions": {"a": 1, "b": 1}}] + \
               [{"type": "feature", "priority": "Critical", "solutions": {f"x{i}": 0 for i in range(10)}}]
        # overall 2/12 ~ 16.7% < 50 but active mean 100% >= 50 -> no error
        self.assertEqual(run(rows), [])

    def test_metrics_and_winner_score(self):
        self.put("comparison/comparison.json", comparison())
        res = self.run_validate()
        m = res["metrics"]
        self.assertEqual(m["winner"], "silver-bullet")
        self.assertEqual(m["winner_score"], 25)
        self.assertEqual(m["critical_filled_cells"], 3)
        self.assertEqual(m["critical_total_cells"], 4)
        self.assertEqual(m["must_have_gaps"], [])
        # winner absent from rankings (and a junk entry) -> score None
        self.put("comparison/comparison.json", comparison(winner="ghost", rankings=["junk", {"solution": "x"}]))
        res = self.run_validate()
        self.assertIsNone(res["metrics"]["winner_score"])
        self.assertIn("landscape/landscape-report.md missing", res["errors"])

    def test_no_winner_reported(self):
        self.put("comparison/comparison.json", comparison(winner=""))
        self.assertIn("no winner in comparison.json", self.errors())

    def test_must_have_gap_surfaces(self):
        self.put("need_profile.json", {"must_haves": ["workflow composition", "ghost feature"]})
        self.put("comparison/comparison.json", comparison())
        res = self.run_validate()
        self.assertEqual([e for e in res["errors"] if "must-have" in e],
                         ["winner 'silver-bullet' lacks must-have 'ghost feature'"])
        self.assertEqual(res["metrics"]["must_have_gaps"], ["winner 'silver-bullet' lacks must-have 'ghost feature'"])

    def test_silver_bullet_zero_score(self):
        self.put("comparison/comparison.json", comparison(
            rankings=[{"solution": "silver-bullet", "score": 0}]))
        self.assertIn("silver-bullet score is 0 despite non-trivial matrix fill (ranking inconsistency)",
                      self.errors())
        self.put("comparison/comparison.json", comparison(
            rankings=[{"solution": "silver-bullet", "score": 3}]))
        self.assertFalse(any("score is 0" in e for e in self.errors()))
        self.put("comparison/comparison.json", comparison(
            rows=[{"type": "feature", "priority": "Critical", "solutions": {"a": 0, "b": 0, "c": 0, "d": 0,
                                                                            "e": 0, "f": 0, "g": 0, "h": 0,
                                                                            "i": 0, "j": 0, "k": 1}}],
            rankings=[{"solution": "silver-bullet", "score": 0}]))
        self.assertFalse(any("score is 0" in e for e in self.errors()))


class MarkdownGateTests(_Base):
    def setUp(self):
        super().setUp()
        self.put("comparison/comparison.json", comparison())

    def test_no_markdown(self):
        res = self.run_validate()
        self.assertIn("landscape/landscape-report.md missing", res["errors"])
        self.assertNotIn("landscape_report_bytes", res["metrics"])
        self.assertFalse(any("Overview blurb" in e for e in res["errors"]))

    def test_complete_markdown_passes_without_pack(self):
        self.put("landscape/landscape-report.md", ALL_SECTIONS)
        res = self.run_validate()
        self.assertEqual(res["errors"], [])
        self.assertEqual(res["status"], "pass")
        self.assertEqual(res["metrics"]["landscape_report_bytes"], len(ALL_SECTIONS.encode()))
        self.assertEqual(res["metrics"]["bad_overview_hits"], 0)

    def test_missing_sections_and_pack_sections(self):
        self.put("need_profile.json", {"category_pack_id": "no-such-pack"})
        self.put("landscape/landscape-report.md", "### 3A. x\n")
        errs = self.errors()
        self.assertIn("landscape-report.md missing section: Market Overview", errs)
        self.assertIn("landscape-report.md missing Adjacent Markets section (pack active)", errs)
        self.assertIn("landscape-report.md missing Explicitly Excluded section (pack active)", errs)
        # an unresolvable pack never reaches the catalog gates
        self.assertFalse(any("catalog_audit" in e for e in errs))

    def test_compression_markers(self):
        self.put("landscape/landscape-report.md", ALL_SECTIONS + "\n[lean-ctx: dropped]\n")
        errs = self.errors()
        self.assertTrue(any(e.startswith("landscape-report.md contains compression markers: ") and
                            "lean-ctx" in e for e in errs))

    def test_compression_marker_without_snippets(self):
        self.put("landscape/landscape-report.md", ALL_SECTIONS)
        with mock.patch.object(vlc, "contains_compression_markers", return_value=True), \
                mock.patch.object(vlc, "find_compression_marker_snippets", return_value=[]):
            errs = self.errors()
        self.assertIn("landscape-report.md contains compression markers: (marker detected)", errs)

    def test_overview_axes_and_chart_headings(self):
        md = ALL_SECTIONS.replace("### 3A. Chart", "") + (
            "\n**Overview**: Capability profile derived from signals\n"
            "**Overview**: Triangulate consolidated notes\n"
            "Axes: **x**\n")
        self.put("landscape/landscape-report.md", md)
        errs = self.errors()
        self.assertIn("landscape-report.md has 2 unusable Overview blurb(s) (meta-research / matrix dump language)", errs)
        self.assertIn("landscape-report.md still contains Axes caption under 3A", errs)
        self.assertIn("landscape-report.md missing ### 3A. / ### 3B. chart headings", errs)
        # numbered 3.N.1 headings satisfy the chart-heading rule
        self.put("landscape/landscape-report.md", ALL_SECTIONS.replace("### 3A. Chart", "#### 3.1.1 Chart"))
        self.assertFalse(any("chart headings" in e for e in self.errors()))


class ChartGateTests(_Base):
    def setUp(self):
        super().setUp()
        self.put("comparison/comparison.json", comparison())
        self.put("landscape/landscape-report.md", ALL_SECTIONS)

    def chart_errors(self, data):
        self.put("landscape/chart-data.json", data)
        return self.run_validate()

    def test_clean_chart(self):
        res = self.chart_errors(chart())
        self.assertEqual(res["errors"], [])
        self.assertEqual((res["metrics"]["chart_mq_points"], res["metrics"]["chart_gmq_points"],
                          res["metrics"]["chart_wave_points"]), (1, 1, 1))
        self.assertNotIn("vendor_url_health_dropped", res["metrics"])

    def test_non_dict_chart_json_is_empty(self):
        res = self.chart_errors([1])
        self.assertIn("chart-data.json has empty mq_data or wave_data", res["errors"])
        self.assertEqual(res["metrics"]["chart_mq_points"], 0)

    def test_empty_mq_or_wave(self):
        self.assertIn("chart-data.json has empty mq_data or wave_data",
                      self.chart_errors(chart(mq_data=[]))["errors"])
        self.assertIn("chart-data.json has empty mq_data or wave_data",
                      self.chart_errors(chart(wave_data=[]))["errors"])

    def test_identical_mq_gmq(self):
        pts = [{"label": "Silver Bullet", "q": "Leaders"}]
        errs = self.chart_errors(chart(mq_data=pts, gmq_data=list(pts)))["errors"]
        self.assertIn("chart-data.json mq_data and gmq_data are identical (3A/3B must differ)", errs)
        self.assertNotIn("chart-data.json mq_data and gmq_data are identical (3A/3B must differ)",
                         self.chart_errors(chart(gmq_data=[]))["errors"])

    def test_vc_title(self):
        bad = self.chart_errors(chart(titles={"vc": "Blue Ocean"}))["errors"]
        self.assertIn("chart-data.json titles.vc missing Value Curve / Radar labeling", bad)
        for ok in ("My Radar", "VALUE CURVE", ""):
            self.assertFalse(any("titles.vc" in e for e in self.chart_errors(chart(titles={"vc": ok}))["errors"]))
        self.assertFalse(any("titles.vc" in e for e in self.chart_errors(chart(titles="nope"))["errors"]))

    def test_leaders_missing_from_value_curve(self):
        data = chart(
            mq_data=["junk", {"label": "Alpha", "q": "Leaders"}, {"label": "", "q": "Leaders"},
                     {"label": "Beta", "q": "Visionaries"}],
            gmq_data=[{"label": "Gamma", "q": "Leaders"}],
            vc_commercial=["junk", {"label": "Alpha"}, {"label": ""}],
            vc_oss=[{"label": "Zed"}],
        )
        errs = self.chart_errors(data)["errors"]
        self.assertIn("chart-data.json Value Curve missing MQ leader series: Gamma", errs)
        data["vc_oss"] = [{"label": "Gamma"}]
        self.assertFalse(any("Value Curve missing" in e for e in self.chart_errors(data)["errors"]))

    def _urlopen(self, dead):
        def fake(req, **kw):
            if any(d in req.full_url for d in dead):
                raise urllib.error.HTTPError(req.full_url, 404, "nf", {}, None)
            resp = mock.MagicMock()
            resp.__enter__.return_value = resp
            resp.status = 200
            resp.geturl.return_value = req.full_url
            return resp
        return fake

    def test_vendor_url_health(self):
        urls = {f"V{i}": f"https://dead{i}.example" for i in range(10)}
        urls["Fine"] = "https://fine.example"
        env = {k: v for k, v in os.environ.items() if k != "SB_SKIP_VENDOR_URL_HEALTH"}
        with mock.patch.dict(os.environ, env, clear=True), \
                mock.patch("urllib.request.urlopen", side_effect=self._urlopen(["dead"])):
            res = self.chart_errors(chart(vendor_urls=urls))
        dropped = res["metrics"]["vendor_url_health_dropped"]
        self.assertEqual(len(dropped), 10)
        msg = [e for e in res["errors"] if "vendor_urls include dead" in e]
        self.assertEqual(len(msg), 1)
        self.assertIn("(10)", msg[0])
        self.assertIn("V0→https://dead0.example (http-404)", msg[0])
        self.assertNotIn("V8→", msg[0])  # sample is capped at 8
        self.assertNotIn("Fine", msg[0])

    def test_vendor_url_health_all_good_and_non_dict(self):
        env = {k: v for k, v in os.environ.items() if k != "SB_SKIP_VENDOR_URL_HEALTH"}
        with mock.patch.dict(os.environ, env, clear=True), \
                mock.patch("urllib.request.urlopen", side_effect=self._urlopen([])):
            res = self.chart_errors(chart(vendor_urls={"A": "https://a.example"}))
        self.assertEqual(res["metrics"]["vendor_url_health_dropped"], [])
        self.assertFalse(any("vendor_urls" in e for e in res["errors"]))
        res = self.chart_errors(chart(vendor_urls=["x"]))
        self.assertNotIn("vendor_url_health_dropped", res["metrics"])

    def test_chart_missing_requires_manifest_type(self):
        self.assertFalse(any("chart-data.json missing" in e for e in self.run_validate()["errors"]))
        for rt, expect in (("solution-landscape", True), ("solution-compare", True), ("other", False)):
            self.put("run_manifest.json", {"research_type": rt})
            self.assertEqual("landscape/chart-data.json missing" in self.errors(), expect, rt)
        self.put("run_manifest.json", [1])
        self.assertNotIn("landscape/chart-data.json missing", self.errors())


class SpaGateTests(_Base):
    def setUp(self):
        super().setUp()
        self.put("comparison/comparison.json", comparison())
        self.put("landscape/landscape-report.md", ALL_SECTIONS)

    def test_spa_markers(self):
        self.put("landscape-report.html", SPA_MARKERS)
        res = self.run_validate()
        self.assertEqual(res["errors"], [])
        self.assertEqual(res["metrics"]["landscape_spa_bytes"], len(SPA_MARKERS.encode()))
        self.put("landscape-report.html", "<html></html>")
        errs = self.errors()
        for label in ("compare max 10", "value-curve radar chart", "compare checkboxes",
                      "snav chips without outline", "wave zone fills", "H1 rem hierarchy",
                      "chart-to-card navigation", "bottom compare section"):
            self.assertIn(f"landscape-report.html missing durable SPA marker: {label}", errs)

    def test_spa_absent_rules(self):
        self.assertNotIn("landscape-report.html missing after landscape synthesis", self.errors())
        self.put("run_manifest.json", {"research_type": "solution-landscape"})
        self.assertNotIn("landscape-report.html missing after landscape synthesis", self.errors())
        self.put("landscape/chart-data.json", chart())
        self.assertIn("landscape-report.html missing after landscape synthesis", self.errors())
        self.put("run_manifest.json", {"research_type": "other"})
        self.assertNotIn("landscape-report.html missing after landscape synthesis", self.errors())


class CatalogGateTests(_Base):
    def setUp(self):
        super().setUp()
        self.put("comparison/comparison.json", comparison())
        self.put("need_profile.json", {"category_pack_id": PACK_ID})
        self.md = ALL_SECTIONS
        self.put("landscape/landscape-report.md", self.md)

    def audit(self, **kw):
        base = {"core": ["silver-bullet"], "adjacent": [], "gaps": [], "counts": {"core": 1}}
        base.update(kw)
        self.put("landscape/catalog_audit.json", base)

    def cat_errors(self, **kw):
        return self.errors(**kw)

    def test_missing_or_empty_audit(self):
        self.assertIn("landscape/catalog_audit.json missing (required when category_pack_id is set)", self.errors())
        self.put("landscape/catalog_audit.json", [])
        self.assertIn("landscape/catalog_audit.json missing (required when category_pack_id is set)", self.errors())
        self.put("landscape/catalog_audit.json", {})
        self.assertIn("landscape/catalog_audit.json missing (required when category_pack_id is set)", self.errors())

    def test_clean_audit(self):
        self.audit()
        res = self.run_validate()
        self.assertEqual(res["errors"], [])
        self.assertEqual(res["metrics"]["catalog_audit"], {"core": 1})

    def test_overlap_with_market_cores(self):
        self.audit(markets={"apo": {"core": ["a", "b"]}, "x": "junk", "y": {}}, adjacent=["b", "c"])
        self.assertIn("adjacent list overlaps market cores (must be empty): b", self.errors())

    def test_overlap_uses_matrix_slugs_then_core_fallback(self):
        self.audit(matrix_slugs=["m"], adjacent=["m"])
        self.assertIn("adjacent list overlaps market cores (must be empty): m", self.errors())
        self.audit(core=["k"], adjacent=["k"])
        self.assertIn("adjacent list overlaps market cores (must be empty): k", self.errors())
        self.audit(core=None, adjacent=["k"])
        self.assertFalse(any("overlaps" in e for e in self.errors()))

    def test_forbidden_slug_in_topn_from_charts(self):
        self.put("comparison/comparison.json", comparison(
            rankings=[{"solution": "silver-bullet", "score": 1}, {"solution": "cline", "score": 1}]))
        self.audit()
        errs = self.errors()
        self.assertIn("forbidden slug 'cline' in Top-N rankings or charts", errs)
        # sunset slugs are forbidden too
        self.put("comparison/comparison.json", comparison(
            rankings=[{"solution": "silver-bullet", "score": 1}, {"solution": "devika", "score": 1}]))
        self.assertIn("forbidden slug 'devika' in Top-N rankings or charts", self.errors())

    def test_parent_child_dual_listing(self):
        self.audit()
        md = ALL_SECTIONS.replace(
            "## 5. Top Commercial Solutions\n",
            "## 5. Top Commercial Solutions\n\n### LangChain\n\n### LangGraph (OSS)\n\n### Cognition\n\n### Devin\n")
        self.put("landscape/landscape-report.md", md)
        errs = self.errors()
        self.assertIn("parent+child dual listing in core sections: langchain + langgraph", errs)
        # alias pairs resolving to the same canonical slug are not a dual listing
        self.assertFalse(any("devin + devin" in e for e in errs))
        # only one of the pair listed -> fine
        self.put("landscape/landscape-report.md", ALL_SECTIONS.replace(
            "## 5. Top Commercial Solutions\n", "## 5. Top Commercial Solutions\n\n### LangChain\n"))
        self.assertFalse(any("dual listing" in e for e in self.errors()))

    def test_core_block_uses_adjacent_heading_and_fallbacks(self):
        self.audit()
        listed = "\n### LangChain\n\n### LangGraph\n"
        # listings after the Adjacent Markets heading are outside the core block
        md = ALL_SECTIONS.replace("## 7. Adjacent Markets\n", "## 7. Adjacent Markets\n" + listed)
        self.put("landscape/landscape-report.md", md)
        self.assertFalse(any("dual listing" in e for e in self.errors()))
        # without an Adjacent Markets heading the core block runs to the end of the text
        md = ("## 1. Market Definition & Scope exclude coding agent\n## 5. Top Commercial Solutions\n" + listed)
        self.put("landscape/landscape-report.md", md)
        self.assertIn("parent+child dual listing in core sections: langchain + langgraph", self.errors())
        # no "## 5." heading at all: find() == -1 slices the last character only
        self.put("landscape/landscape-report.md", "out of scope\n" + listed.replace("###", "####"))
        self.assertFalse(any("dual listing" in e for e in self.errors()))
        # fallback literal "## 7. Adjacent" works even when the regex heading form is absent
        md = "out of scope\n## 5. Core\n### LangChain\n### LangGraph\n## 7. Adjacent stuff\n### Cognition\n"
        self.put("landscape/landscape-report.md", md)
        self.assertIn("parent+child dual listing in core sections: langchain + langgraph", self.errors())

    def test_gaps_acknowledgement(self):
        self.audit(gaps=["zuvo"])
        self.assertIn("must_research gaps ['zuvo'] without coverage_gaps.json acknowledgment", self.errors())
        self.put("coverage_gaps.json", {})
        self.assertFalse(any("must_research gaps" in e for e in self.errors()))

    def test_apo_exclusion_language(self):
        self.audit()
        md = ALL_SECTIONS.replace("Out of scope: coding agents.", "Nothing here.")
        self.put("landscape/landscape-report.md", md)
        self.assertIn("Market Definition lacks exclusion language for coding agents / host runtimes (APO pack)",
                      self.errors())
        for marker in ("coding agent", "HOST RUNTIME", "out of scope", "Excluded from core"):
            self.put("landscape/landscape-report.md", md.replace("Nothing here.", marker))
            self.assertFalse(any("exclusion language" in e for e in self.errors()), marker)

    def test_max_core_count(self):
        many = [f"s{i}" for i in range(26)]
        self.audit(markets={"apo": {"core": many}})
        self.assertIn("primary market core count 26 exceeds pack max_core_count 24", self.errors())
        # explicit primary market id from the audit; core falls back to audit core
        self.audit(primary_market_id="other", markets={"apo": {"core": many}}, core=["a"])
        self.assertFalse(any("exceeds" in e for e in self.errors()))
        self.audit(core=many)
        self.assertIn("primary market core count 26 exceeds pack max_core_count 24", self.errors())
        self.audit(core=many[:24])
        self.assertFalse(any("exceeds" in e for e in self.errors()))

    def test_non_apo_pack_and_pack_defaults(self):
        pack = copy.deepcopy(category_pack.resolve_pack_from_need({"category_pack_id": PACK_ID}))
        pack["category_id"] = "something-else"
        pack["max_core_count"] = None
        pack["primary_market_id"] = ""
        pack["parent_child_dedupe"] = [
            {"parent_slug": "", "prefer_slug": "x"},
            {"parent_slug": "x", "prefer_slug": ""},
            {"parent_slug": "same", "prefer_slug": "same"},
        ]
        self.audit(core=[f"s{i}" for i in range(25)])
        self.put("landscape/landscape-report.md", ALL_SECTIONS.replace("Out of scope: coding agents.", "x"))
        with mock.patch.object(vlc, "resolve_pack_from_need", return_value=pack):
            errs = self.errors()
        # non-APO: no exclusion-language gate; max_core falls back to 25; primary id to "apo"
        self.assertFalse(any("exclusion language" in e for e in errs))
        self.assertFalse(any("exceeds" in e for e in errs))
        self.assertFalse(any("dual listing" in e for e in errs))
        self.audit(core=[f"s{i}" for i in range(26)])
        with mock.patch.object(vlc, "resolve_pack_from_need", return_value=pack):
            self.assertIn("primary market core count 26 exceeds pack max_core_count 25", self.errors())

    def test_augment_rules(self):
        self.audit(core=["augment-code"])
        self.put("comparison/comparison.json", comparison(
            rankings=[{"solution": "silver-bullet", "score": 1}, {"solution": "augment-code", "score": 1}]))
        errs = self.errors()
        self.assertIn("augment-code in Top-N without augment-cosmos rename per pack policy", errs)
        self.put("comparison/comparison.json", comparison(
            rankings=[{"solution": "silver-bullet", "score": 1}, {"solution": "augment-code", "score": 1},
                      {"solution": "augment-cosmos", "score": 1}]))
        self.assertFalse(any("without augment-cosmos rename per" in e for e in self.errors()))
        self.put("comparison/comparison.json", comparison())
        # prose mentions Augment Code without Cosmos while audit core has it
        self.put("landscape/landscape-report.md", ALL_SECTIONS + "\nAugment-Code is mentioned.\n")
        self.assertIn("augment-code present in core without Cosmos rename", self.errors())
        # Cosmos also mentioned -> fine
        self.put("landscape/landscape-report.md", ALL_SECTIONS + "\nAugment Code and augment cosmos.\n")
        self.assertFalse(any("without Cosmos rename" in e for e in self.errors()))
        # mention but audit core does not hold it -> fine
        self.audit(core=["silver-bullet"])
        self.put("landscape/landscape-report.md", ALL_SECTIONS + "\nAugment-Code is mentioned.\n")
        self.assertFalse(any("without Cosmos rename" in e for e in self.errors()))


class MainTests(_Base):
    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["validate_landscape_content.py", *argv]), \
                contextlib.redirect_stdout(out):
            code = vlc.main()
        return code, json.loads(out.getvalue())

    def test_main_fail_and_pass(self):
        code, payload = self.run_main("--dir", str(self.root))
        self.assertEqual(code, 1)
        self.assertEqual(payload["status"], "fail")
        self.put("comparison/comparison.json", comparison())
        self.put("landscape/landscape-report.md", ALL_SECTIONS)
        code, payload = self.run_main("--dir", str(self.root), "--min-critical-fill", "0.1")
        self.assertEqual((code, payload["status"], payload["errors"]), (0, "pass", []))

    def test_main_threshold_is_forwarded(self):
        self.put("comparison/comparison.json", comparison(
            rows=[{"type": "feature", "priority": "Critical", "solutions": {"a": 1, "b": 0, "c": 0}}],
            winner=None, rankings=[]))
        self.put("landscape/landscape-report.md", ALL_SECTIONS)
        code, payload = self.run_main("--dir", str(self.root), "--min-critical-fill", "0.9")
        self.assertEqual(code, 1)
        self.assertTrue(any("below minimum 90%" in e for e in payload["errors"]))

    def test_script_entry_point(self):
        import runpy

        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["v.py", "--dir", str(self.root)]), \
                contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as cm:
            runpy.run_path(str(SCRIPTS / "validate_landscape_content.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 1)
        self.assertEqual(json.loads(out.getvalue())["status"], "fail")

    def test_main_requires_dir(self):
        with mock.patch.object(sys, "argv", ["x"]), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                vlc.main()
        self.assertEqual(cm.exception.code, 2)


if __name__ == "__main__":
    unittest.main()

"""Durable DR landscape report-builder contracts (not one-off fullpool tweaks)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
ASSETS = Path(__file__).resolve().parents[1] / "assets"
sys.path.insert(0, str(SCRIPTS))

from materialize_solution_artifacts import (  # noqa: E402
    OVERVIEW_SEEDS,
    build_scr_md,
    is_unusable_overview_claim,
)
from skill_paths import resolve_multi_ai_scripts  # noqa: E402
from synthesize_landscape import build_chart_data, build_report_markdown  # noqa: E402


class OverviewQualityTests(unittest.TestCase):
    def test_rejects_meta_research_overviews(self) -> None:
        self.assertTrue(
            is_unusable_overview_claim(
                "Cline participates in the agentic SDLC orchestration category as a commercial option."
            )
        )
        self.assertTrue(
            is_unusable_overview_claim(
                "Triangulate consolidated narrative centers ~7 names (Cursor, Devin)."
            )
        )
        self.assertTrue(
            is_unusable_overview_claim(
                "Coverage is based on multi-AI envelope synthesis and comparison matrix signals."
            )
        )

    def test_accepts_product_blurbs(self) -> None:
        self.assertFalse(
            is_unusable_overview_claim(
                "Devin is Cognition's autonomous software engineer that plans and ships PRs.",
                focus_name="Devin (Cognition)",
            )
        )

    def test_overview_seeds_cover_core_catalog(self) -> None:
        for slug in ("silver-bullet", "factory-ai", "devin", "openhands", "langgraph-platform"):
            self.assertIn(slug, OVERVIEW_SEEDS)
            self.assertGreater(len(OVERVIEW_SEEDS[slug]), 20)

    def test_build_scr_prefers_seed_over_meta_claim(self) -> None:
        envelopes = [
            {
                "phase_id": "DR-RETRIEVE",
                "logical_model_id": "test",
                "payload": {
                    "evidence": [
                        {
                            "claim": (
                                "Cline participates in the agentic SDLC orchestration category "
                                "as an open-source option. Coverage is based on multi-AI "
                                "envelope synthesis and comparison matrix signals."
                            )
                        }
                    ]
                },
            }
        ]
        scr = build_scr_md("cline", envelopes)
        self.assertIn(OVERVIEW_SEEDS["cline"][:40], scr)
        self.assertNotIn("participates in the agentic", scr)


class ChartBuilderTests(unittest.TestCase):
    def test_mq_and_gmq_are_distinct(self) -> None:
        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 29},
                {"solution": "factory-ai", "score": 22},
                {"solution": "devin", "score": 18},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {"silver-bullet": True, "factory-ai": True, "devin": False},
                },
                {
                    "type": "feature",
                    "name": "Atomic flow catalog",
                    "solutions": {"silver-bullet": True, "factory-ai": False, "devin": False},
                },
                {
                    "type": "feature",
                    "name": "Hook-enforced gates",
                    "solutions": {"silver-bullet": True, "factory-ai": True, "devin": False},
                },
                {
                    "type": "feature",
                    "name": "Parent/child delegation",
                    "solutions": {"silver-bullet": True, "factory-ai": True, "devin": True},
                },
                {
                    "type": "feature",
                    "name": "Managed hosting",
                    "solutions": {"silver-bullet": False, "factory-ai": True, "devin": True},
                },
                {
                    "type": "feature",
                    "name": "Prebuilt SDLC templates",
                    "solutions": {"silver-bullet": True, "factory-ai": True, "devin": False},
                },
                {
                    "type": "feature",
                    "name": "CI integration",
                    "solutions": {"silver-bullet": True, "factory-ai": False, "devin": True},
                },
                {
                    "type": "feature",
                    "name": "IDE-native integration",
                    "solutions": {"silver-bullet": True, "factory-ai": False, "devin": False},
                },
                {
                    "type": "feature",
                    "name": "Free tier / OSS core",
                    "solutions": {"silver-bullet": True, "factory-ai": False, "devin": False},
                },
            ],
        }
        support = {
            slug: {row["name"]: bool(row["solutions"].get(slug)) for row in comparison["rows"]}
            for slug in ("silver-bullet", "factory-ai", "devin")
        }
        chart = build_chart_data(
            comparison,
            category="Agentic SDLC orchestration",
            support=support,
            need={},
            scope_text="agentic sdlc orchestration landscape",
        )
        self.assertNotEqual(chart["mq_data"], chart["gmq_data"])
        self.assertIn("Radar", chart["titles"]["vc"])
        self.assertTrue(any(p["q"] == "Leaders" for p in chart["gmq_data"]))

    def test_value_curve_includes_gmq_leaders(self) -> None:
        comparison = {
            "rankings": [
                {"solution": "deepwork", "score": 28},
                {"solution": "silver-bullet", "score": 26},
                {"solution": "conductor", "score": 24},
                {"solution": "turboshovel", "score": 22},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Atomic flow catalog",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Hook-enforced gates",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Parent/child delegation",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Managed hosting",
                    "solutions": {"deepwork": True, "silver-bullet": False, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Prebuilt SDLC templates",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "CI integration",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": False},
                },
                {
                    "type": "feature",
                    "name": "IDE-native integration",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": False, "turboshovel": False},
                },
                {
                    "type": "feature",
                    "name": "Free tier / OSS core",
                    "solutions": {"deepwork": False, "silver-bullet": True, "conductor": False, "turboshovel": False},
                },
            ],
        }
        commercial = [
            {"slug": "deepwork", "name": "Deepwork"},
            {"slug": "conductor", "name": "Conductor"},
            {"slug": "turboshovel", "name": "Turboshovel"},
        ]
        oss = [{"slug": "silver-bullet", "name": "Silver Bullet"}]
        support = {
            slug: {row["name"]: bool(row["solutions"].get(slug)) for row in comparison["rows"]}
            for slug in ("deepwork", "silver-bullet", "conductor", "turboshovel")
        }
        chart = build_chart_data(
            comparison,
            category="Agentic SDLC orchestration",
            support=support,
            need={},
            scope_text="agentic sdlc orchestration landscape",
            commercial=commercial,
            oss=oss,
        )
        gmq_leaders = {p["label"] for p in chart["gmq_data"] if p["q"] == "Leaders"}
        mq_leaders = {p["label"] for p in chart["mq_data"] if p["q"] == "Leaders"}
        vc_labels = {s["label"] for s in chart["vc_commercial"] + chart["vc_oss"]}
        all_leaders = gmq_leaders | mq_leaders
        self.assertTrue(gmq_leaders)
        self.assertTrue(all_leaders.issubset(vc_labels), f"missing VC series for {all_leaders - vc_labels}")

    def test_value_curve_backfills_leaders_without_catalog_slug_match(self) -> None:
        """Leaders must appear on VC even when catalog is incomplete and labels differ from slugs."""
        comparison = {
            "rankings": [
                {"solution": "deepwork", "score": 28},
                {"solution": "silver-bullet", "score": 26},
                {"solution": "conductor", "score": 24},
                {"solution": "turboshovel", "score": 22},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Atomic flow catalog",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Hook-enforced gates",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Parent/child delegation",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Managed hosting",
                    "solutions": {"deepwork": True, "silver-bullet": False, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "Prebuilt SDLC templates",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": True},
                },
                {
                    "type": "feature",
                    "name": "CI integration",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": True, "turboshovel": False},
                },
                {
                    "type": "feature",
                    "name": "IDE-native integration",
                    "solutions": {"deepwork": True, "silver-bullet": True, "conductor": False, "turboshovel": False},
                },
                {
                    "type": "feature",
                    "name": "Free tier / OSS core",
                    "solutions": {"deepwork": False, "silver-bullet": True, "conductor": False, "turboshovel": False},
                },
            ],
        }
        support = {
            slug: {row["name"]: bool(row["solutions"].get(slug)) for row in comparison["rows"]}
            for slug in ("deepwork", "silver-bullet", "conductor", "turboshovel")
        }
        # APO-like partial catalog: top commercial slice only — no OSS, no deepwork/conductor rows.
        commercial = [
            {"slug": "sdlc-plugin", "name": "SDLC Plugin"},
            {"slug": "cc10x", "name": "cc10x"},
            {"slug": "agenthub", "name": "AgentHub"},
            {"slug": "turboshovel", "name": "Turboshovel"},
            {"slug": "director", "name": "Director"},
        ]
        known = {
            "deepwork": "Deepwork",
            "silver-bullet": "Silver Bullet",
            "conductor": "Conductor",
            "turboshovel": "Turboshovel",
        }
        chart = build_chart_data(
            comparison,
            category="Agentic SDLC orchestration",
            support=support,
            need={},
            scope_text="agentic sdlc orchestration landscape",
            commercial=commercial,
            oss=[],
            known=known,
        )
        gmq_leaders = {p["label"] for p in chart["gmq_data"] if p["q"] == "Leaders"}
        vc_labels = {s["label"] for s in chart["vc_commercial"] + chart["vc_oss"]}
        self.assertEqual(
            set(),
            gmq_leaders - vc_labels,
            f"expected all GMQ leaders on VC; missing {gmq_leaders - vc_labels}",
        )
        self.assertIn("Silver Bullet", vc_labels)
        self.assertIn("Deepwork", vc_labels)

    def test_report_markdown_has_no_axes_caption(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            md = build_report_markdown(
                category="Agentic SDLC orchestration",
                platform_list="test-model",
                scope_text="agentic sdlc orchestration",
                need={"category": "Agentic SDLC orchestration", "category_pack_id": "agentic-sdlc-process-orchestrator"},
                comparison={"rankings": [{"solution": "silver-bullet", "score": 20}], "rows": []},
                consolidation={"consensus": [], "divergence": []},
                envelopes=[],
                claims=[],
                root=root,
                report_date="July 19, 2026",
            )
        self.assertNotRegex(md, r"(?m)^Axes:\s*\*\*")
        self.assertIn("### 3A.", md)
        self.assertIn("### 3B.", md)
        self.assertIn("Radar of Key Competitive Factors", md)
        self.assertIn("### Model response weights", md)
        self.assertNotIn("min_pass_count", md)
        self.assertIn("core peer set", md)


    def test_value_curve_includes_barkain_and_cc10x_mq_leaders(self) -> None:
        """APO-style fixture: Barkain + cc10x must be Leaders on MQ/GMQ and on VC radar."""
        comparison = {
            "rankings": [
                {"solution": "deepwork", "score": 25},
                {"solution": "silver-bullet", "score": 25},
                {"solution": "conductor", "score": 24},
                {"solution": "barkain-workflow-orchestrator", "score": 22},
                {"solution": "director", "score": 22},
                {"solution": "cc10x", "score": 20},
                {"solution": "turboshovel", "score": 19},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {
                        "deepwork": True,
                        "silver-bullet": True,
                        "conductor": True,
                        "barkain-workflow-orchestrator": True,
                        "director": True,
                        "cc10x": True,
                        "turboshovel": True,
                    },
                },
                {
                    "type": "feature",
                    "name": "Atomic flow catalog",
                    "solutions": {
                        "deepwork": True,
                        "silver-bullet": True,
                        "conductor": True,
                        "barkain-workflow-orchestrator": False,
                        "director": True,
                        "cc10x": False,
                        "turboshovel": False,
                    },
                },
                {
                    "type": "feature",
                    "name": "Hook-enforced gates",
                    "solutions": {
                        "deepwork": True,
                        "silver-bullet": True,
                        "conductor": True,
                        "barkain-workflow-orchestrator": True,
                        "director": False,
                        "cc10x": True,
                        "turboshovel": True,
                    },
                },
                {
                    "type": "feature",
                    "name": "Parent/child agent delegation",
                    "solutions": {
                        "deepwork": False,
                        "silver-bullet": True,
                        "conductor": False,
                        "barkain-workflow-orchestrator": True,
                        "director": False,
                        "cc10x": False,
                        "turboshovel": False,
                    },
                },
                {
                    "type": "feature",
                    "name": "Managed hosting",
                    "solutions": {
                        "deepwork": False,
                        "silver-bullet": False,
                        "conductor": False,
                        "barkain-workflow-orchestrator": False,
                        "director": False,
                        "cc10x": False,
                        "turboshovel": False,
                    },
                },
                {
                    "type": "feature",
                    "name": "Prebuilt SDLC templates",
                    "solutions": {
                        "deepwork": False,
                        "silver-bullet": True,
                        "conductor": True,
                        "barkain-workflow-orchestrator": False,
                        "director": False,
                        "cc10x": False,
                        "turboshovel": False,
                    },
                },
                {
                    "type": "feature",
                    "name": "CI integration",
                    "solutions": {
                        "deepwork": False,
                        "silver-bullet": True,
                        "conductor": True,
                        "barkain-workflow-orchestrator": False,
                        "director": False,
                        "cc10x": False,
                        "turboshovel": True,
                    },
                },
                {
                    "type": "feature",
                    "name": "IDE-native integration",
                    "solutions": {
                        "deepwork": True,
                        "silver-bullet": True,
                        "conductor": False,
                        "barkain-workflow-orchestrator": False,
                        "director": False,
                        "cc10x": False,
                        "turboshovel": False,
                    },
                },
                {
                    "type": "feature",
                    "name": "Free tier / OSS core",
                    "solutions": {
                        "deepwork": False,
                        "silver-bullet": True,
                        "conductor": False,
                        "barkain-workflow-orchestrator": False,
                        "director": False,
                        "cc10x": False,
                        "turboshovel": False,
                    },
                },
                {
                    "type": "feature",
                    "name": "Zero-infra bootstrap",
                    "solutions": {
                        "deepwork": False,
                        "silver-bullet": False,
                        "conductor": False,
                        "barkain-workflow-orchestrator": True,
                        "director": True,
                        "cc10x": True,
                        "turboshovel": True,
                    },
                },
            ],
        }
        support = {
            slug: {row["name"]: bool(row["solutions"].get(slug)) for row in comparison["rows"]}
            for slug in (
                "deepwork",
                "silver-bullet",
                "conductor",
                "barkain-workflow-orchestrator",
                "director",
                "cc10x",
                "turboshovel",
            )
        }
        known = {
            "barkain-workflow-orchestrator": "Barkain Workflow Orchestrator",
            "cc10x": "cc10x",
            "deepwork": "Deepwork",
            "silver-bullet": "Silver Bullet",
            "conductor": "Conductor",
            "director": "Director",
            "turboshovel": "Turboshovel",
        }
        commercial = [
            {"slug": "barkain-workflow-orchestrator", "name": "Barkain Workflow Orchestrator"},
            {"slug": "cc10x", "name": "cc10x"},
            {"slug": "deepwork", "name": "Deepwork"},
            {"slug": "conductor", "name": "Conductor"},
            {"slug": "turboshovel", "name": "Turboshovel"},
        ]
        chart = build_chart_data(
            comparison,
            category="Agentic SDLC orchestration",
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            scope_text="agentic sdlc orchestration landscape",
            commercial=commercial,
            oss=[{"slug": "silver-bullet", "name": "Silver Bullet"}],
            known=known,
        )
        gmq_leaders = {p["label"] for p in chart["gmq_data"] if p["q"] == "Leaders"}
        mq_leaders = {p["label"] for p in chart["mq_data"] if p["q"] == "Leaders"}
        vc_labels = {s["label"] for s in chart["vc_commercial"] + chart["vc_oss"]}
        self.assertIn("Barkain Workflow Orchestrator", gmq_leaders | mq_leaders)
        self.assertIn("cc10x", gmq_leaders | mq_leaders)
        self.assertIn("Barkain Workflow Orchestrator", vc_labels)
        self.assertIn("cc10x", vc_labels)
        self.assertTrue((gmq_leaders | mq_leaders).issubset(vc_labels))


class TemplateContractTests(unittest.TestCase):

    def test_template_contains_durable_spa_contracts(self) -> None:
        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        for needle in (
            "COMPARE_MAX = 10",
            "type: 'radar'",
            "vc-compare-cb",
            "border: none; outline: none; background: var(--sb-snav-chip-bg)",
            "sbWaveZoneFills",
            "--sb-chart-zone-leaders",
            "chartGridColor",
            "themedSeriesPalette",
            "font-weight: 500",
            "font-size: 1.875rem",
            "font-size:1.25rem",
            "export-bar--flow",
            "layoutExportBarForViewport",
            "source-reliability-section",
            "_scrollToVendorCard",
            "compareResultsSection",
            "attachChartVendorNav",
            "vendor-' + cardSlug",
            "setupQuadrantCompareOverlays",
            "quadrant-compare-btn",
            "_formatCompareScore",
            "cmp-score-row",
        ):
            self.assertIn(needle, template, msg=f"missing {needle!r}")

    def test_matrix_charts_use_quadrant_fills_not_wave_zones(self) -> None:
        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        # Gartner MQ/GMQ backgrounds must read --sb-chart-quad-* via sbQuadrantFills().
        self.assertIn("function sbQuadrantFills()", template)
        self.assertIn("function sbWaveZoneFills()", template)
        self.assertIn("function sbWaveQuadrantFills()", template)
        for hex in ("#e8f4fd", "#f0eaf8", "#fff3e6", "#f0f0f0"):
            self.assertIn(hex, template, msg=f"missing light quad hex {hex!r}")
        self.assertIn("--sb-chart-quad-leaders", template)
        self.assertIn("--sb-chart-zone-leaders", template)
        # mqQuadrantRegions + GMQ beforeDraw must not source wave zone washes.
        mq_fn = template.split("function mqQuadrantRegions", 1)[1].split("function ", 1)[0]
        self.assertIn("sbQuadrantFills()", mq_fn)
        self.assertNotIn("sbWaveQuadrantFills()", mq_fn)
        gmq_block = template.split("id: 'gmqQuadrants'", 1)[1].split("id: 'waveArcZones'", 1)[0]
        self.assertIn("sbQuadrantFills()", gmq_block)
        self.assertNotIn("sbWaveQuadrantFills()", gmq_block)
        # sbWaveQuadrantFills maps wave zones only (for wave-style quadrant overlays).
        wave_quad_fn = template.split("function sbWaveQuadrantFills()", 1)[1].split("function ", 1)[0]
        self.assertIn("sbWaveZoneFills()", wave_quad_fn)
        self.assertNotIn("sbQuadrantFills()", wave_quad_fn)
        # Wave arc plugin must keep zone/wave vars, not Gartner quad palette.
        wave_arc = template.split("id: 'waveArcZones'", 1)[1].split("id: 'vcWaveBackground'", 1)[0]
        self.assertIn("sbChartTheme().wave", wave_arc)
        self.assertNotIn("sbQuadrantFills()", wave_arc)

    def test_resolve_multi_ai_scripts_points_at_authored_tree(self) -> None:
        scripts = resolve_multi_ai_scripts()
        self.assertTrue((scripts / "synthesize_landscape.py").is_file())
        self.assertTrue((scripts / "landscape_preview_render.py").is_file())
        self.assertTrue((scripts.parent / "assets" / "landscape-preview.template.html").is_file())

    def test_linkify_skips_generic_sdlc_but_keeps_product_names(self) -> None:
        from synthesize_landscape import _linkify_markdown_vendors, build_link_pairs

        pairs = build_link_pairs(
            None,
            commercial=[
                {
                    "slug": "sdlc-plugin",
                    "name": "SDLC",
                    "url": "https://claude.com/plugins",
                },
                {"slug": "bmad-method", "name": "BMAD-METHOD", "url": "https://bmad.ai/"},
                {"slug": "gsd", "name": "GSD", "url": "https://github.com/gsd"},
                {"slug": "devin", "name": "Devin (Cognition)", "url": "https://devin.ai/"},
                {"slug": "zuvo", "name": "Zuvo", "url": "https://zuvo.dev/"},
            ],
            known={
                "sdlc-plugin": "SDLC",
                "bmad-method": "BMAD-METHOD",
                "gsd": "GSD",
                "devin": "Devin (Cognition)",
                "zuvo": "Zuvo",
            },
        )
        labels = {label for label, _url in pairs}
        self.assertNotIn("SDLC", labels)
        self.assertIn("SDLC Plugin", labels)
        self.assertIn("BMAD-METHOD", labels)
        self.assertIn("GSD", labels)
        self.assertIn("Devin (Cognition)", labels)
        self.assertIn("Zuvo", labels)

        prose = (
            "Agentic SDLC orchestration compares BMAD-METHOD, GSD, Devin, and Zuvo. "
            "Use SDLC Plugin for Claude Code workflows."
        )
        linked = _linkify_markdown_vendors(prose, pairs)
        self.assertNotIn("[SDLC](", linked)
        self.assertIn("[BMAD-METHOD](", linked)
        self.assertIn("[GSD](", linked)
        self.assertIn("[Devin](", linked)
        self.assertIn("[Zuvo](", linked)
        self.assertIn("[SDLC Plugin](", linked)


if __name__ == "__main__":
    unittest.main()

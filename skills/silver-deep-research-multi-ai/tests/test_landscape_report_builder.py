"""Durable DR landscape report-builder contracts (not one-off fullpool tweaks)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
ASSETS = Path(__file__).resolve().parents[1] / "assets"
sys.path.insert(0, str(SCRIPTS))

from materialize_solution_artifacts import (  # noqa: E402
    OVERVIEW_SEEDS,
    build_scr_md,
    is_unusable_overview_claim,
)
from skill_paths import resolve_multi_ai_scripts  # noqa: E402
from synthesize_landscape import (  # noqa: E402
    build_chart_data,
    build_report_markdown,
    synthesize_landscape,
)


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
        self.assertIn("Scoring methodology", md)
        self.assertIn("Executive Summary", md)
        self.assertIn("Vendor inclusion ledger", md)
        self.assertIn("Coverage completeness matrix", md)
        self.assertIn("Consensus Resolution Table", md)
        self.assertIn("Consensus Patterns", md)
        self.assertTrue(
            "### 3A." in md or "### 3.1 " in md or "### 4.1 " in md,
            "expected positioning headings",
        )
        self.assertIn("Radar of Key Competitive Factors", md)
        self.assertIn("### Model response weights", md)
        self.assertNotIn("min_pass_count", md)
        self.assertIn("core peer set", md)
        self.assertNotIn("tiny deterministic jitter", md)
        self.assertNotIn("0.85·jitter", md)


    def test_value_curve_includes_barkain_and_cc10x_mq_leaders(self) -> None:
        """Barkain stays Leader on APO axes; cc10x is plotted but not a Leader on sparse execute ticks."""
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
        plotted = {p["slug"] for p in chart["gmq_data"] + chart["mq_data"]}
        self.assertIn("Barkain Workflow Orchestrator", gmq_leaders | mq_leaders)
        self.assertIn("cc10x", plotted)
        self.assertNotIn("cc10x", {p["slug"] for p in chart["gmq_data"] + chart["mq_data"] if p["q"] == "Leaders"})
        self.assertIn("Barkain Workflow Orchestrator", vc_labels)
        self.assertTrue((gmq_leaders | mq_leaders).issubset(vc_labels))
        plugin_chart = build_chart_data(
            comparison,
            category="Agentic SDLC orchestration",
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            scope_text="agentic sdlc orchestration landscape",
            commercial=commercial,
            oss=[{"slug": "silver-bullet", "name": "Silver Bullet"}],
            known=known,
            market_id="sdlc-plugins",
        )
        plugin_leaders = {
            p["slug"]
            for p in plugin_chart["gmq_data"] + plugin_chart["mq_data"]
            if p["q"] == "Leaders"
        }
        self.assertNotIn("cc10x", plugin_leaders)


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
            "_vendorCardDomId(cardSlug, marketId)",
            "vendor-' + s + '--' + mid",
            "setupQuadrantCompareOverlays",
            "quadrant-compare-btn",
            "_formatCompareScore",
            "cmp-score-row",
            "HOMEPAGE_VENDOR_URLS",
            "_homepageFromHeading",
            "vc-name-link",
            "ensureExternalLinksNewTab",
            'target="_blank"',
            "noopener noreferrer",
            "landscape-report.pdf",
            "landscape-report.pdf?v=",
            "Date.now()",
            "window.open(pdfHref, '_blank', 'noopener,noreferrer')",
            "function _marketChartSource(anchor)",
            "whenChartParentReady is rAF-deferred",
            "payload.mq_data",
            "payload.gmq_data",
            "#content h3, #content h4",
        ):
            self.assertIn(needle, template, msg=f"missing {needle!r}")

    def test_inject_snapshots_per_market_chart_data_before_raf(self) -> None:
        """MQ/GMQ/Wave must not read restored PRIMARY globals inside whenChartParentReady."""
        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        mq = template.split("function inject2x2(", 1)[1].split("function injectGMQ(", 1)[0]
        gmq = template.split("function injectGMQ(", 1)[1].split("function injectWave(", 1)[0]
        wave = template.split("function injectWave(", 1)[1].split("function injectValueCurve(", 1)[0]
        self.assertIn("const payload = _marketChartSource(anchorH3);", mq)
        self.assertIn("const mqData = payload.mq_data;", mq)
        self.assertIn("data: mqData.map(", mq)
        self.assertNotIn("MQ_DATA.map(", mq)
        self.assertIn("const gmqData = payload.gmq_data;", gmq)
        self.assertIn("data: gmqData.map(", gmq)
        self.assertNotIn("GMQ_DATA.map(", gmq)
        self.assertIn("const waveData = payload.wave_data;", wave)
        self.assertIn("waveData.map(", wave)
        self.assertNotIn("WAVE_DATA.map(", wave)
        # Fallback GMQ must see Magic Quadrant h4 headings, not only h3.
        self.assertIn("querySelectorAll('#content h3, #content h4')", mq)

    def test_external_links_open_in_new_tab(self) -> None:
        """Homepage / card / prose links must use target=_blank + noopener."""
        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        self.assertIn("function ensureExternalLinksNewTab", template)
        self.assertIn("a.setAttribute('target', '_blank')", template)
        self.assertIn("a.setAttribute('rel', 'noopener noreferrer')", template)
        # Unique homepage snav pills keep new-tab; multi-market in-page anchors preventDefault.
        snav = template.split("function addPills", 1)[1].split("function insertVendorFilterBar", 1)[0]
        self.assertIn("Open ${display} website (new tab)", snav)
        self.assertIn("el.target = '_blank'", snav)
        self.assertIn("e.preventDefault()", snav)
        self.assertIn("_vendorCardDomId", snav)
        self.assertIn("Jump to ${display}", snav)
        # Card titles keep new-tab attrs
        self.assertIn('target="_blank" rel="noopener noreferrer"', template)
        from landscape_preview_render import _patch_chart_bootstrap

        boot = _patch_chart_bootstrap(template)
        self.assertIn("ensureExternalLinksNewTab", boot)
        self.assertIn('target="_blank" rel="noopener noreferrer"', boot)

    def test_pdf_export_opens_sibling_file_not_blob_or_print(self) -> None:
        """Create PDF must open sibling landscape-report.pdf — never blob:null or print()."""
        from landscape_preview_render import _patch_pdf_export

        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        fn = template.split("async function exportToPDF()", 1)[1].split(
            "function _inlineStylesForGDocs", 1
        )[0]
        self.assertIn("landscape-report.pdf", fn)
        self.assertIn("landscape-report.pdf?v=", fn)
        self.assertIn("Date.now()", fn)
        self.assertIn("window.open(pdfHref, '_blank', 'noopener,noreferrer')", fn)
        self.assertNotIn("createObjectURL", fn)
        self.assertNotIn("window.print(", fn)
        self.assertNotIn("blobUrl", fn)
        patched = _patch_pdf_export(template)
        pfn = patched.split("async function exportToPDF()", 1)[1].split(
            "function _inlineStylesForGDocs", 1
        )[0]
        self.assertIn("landscape-report.pdf?v=", pfn)
        self.assertIn("Date.now()", pfn)
        self.assertIn("window.open(pdfHref, '_blank'", pfn)
        self.assertNotIn("createObjectURL", pfn)
        self.assertNotIn("window.print(", pfn)

    def test_write_sibling_landscape_pdf_invokes_playwright(self) -> None:
        from unittest.mock import patch

        from landscape_independent_pdf import PRINT_ROOT_ID
        from landscape_preview_render import write_sibling_landscape_pdf

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            html_path = root / "landscape-report.html"
            html_path.write_text("<html><body id='content'>ok</body></html>", encoding="utf-8")
            (root / "landscape").mkdir()
            (root / "landscape" / "chart-data.json").write_text(
                json.dumps(
                    {
                        "primary_market_id": "apo",
                        "markets": {
                            "apo": {
                                "titles": {"mq": "MQ", "gmq": "GMQ", "wave": "Wave"},
                                "mq_data": [
                                    {"slug": "a", "label": "A", "x": 6, "y": 7, "q": "Leaders"}
                                ],
                                "gmq_data": [
                                    {"slug": "a", "label": "A", "x": 6, "y": 7, "q": "Leaders"}
                                ],
                                "wave_data": [
                                    {
                                        "slug": "a",
                                        "label": "A",
                                        "offering": 3,
                                        "strategy": 3,
                                        "presence": 2,
                                    }
                                ],
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )
            (root / "landscape" / "landscape-report.md").write_text(
                "# T\n\n## 1. Market Definition & Scope\n\nScope.\n",
                encoding="utf-8",
            )
            pdf_path = html_path.with_name("landscape-report.pdf")

            def _fake_run(cmd, check):
                pdf_path.write_bytes(b"%PDF-1.4 fake")
                class _R:
                    returncode = 0
                return _R()

            with patch("landscape_independent_pdf.subprocess.run", side_effect=_fake_run) as mocked:
                info = write_sibling_landscape_pdf(html_path)
            self.assertEqual(info["status"], "ok")
            self.assertEqual(Path(info["pdf"]).resolve(), pdf_path.resolve())
            self.assertTrue(pdf_path.is_file())
            argv = mocked.call_args[0][0]
            self.assertIn("pdf", argv)
            self.assertEqual(Path(argv[-1]).resolve(), pdf_path.resolve())
            self.assertTrue(str(argv[-2]).startswith("file:"))
            self.assertNotIn("landscape-report.html", str(argv[-2]))
            self.assertIn("--wait-for-selector", argv)
            self.assertIn(f"#{PRINT_ROOT_ID}", argv)
            self.assertNotIn("#content", argv)

    def test_patch_pdf_export_rewrites_print_dialog_body(self) -> None:
        from landscape_preview_render import _patch_pdf_export

        stale = (
            "async function exportToPDF() {\n"
            "  const blobUrl = URL.createObjectURL(blob);\n"
            "  window.print();\n"
            "}\n\n"
            "function _inlineStylesForGDocs(root) {}\n"
        )
        patched = _patch_pdf_export(stale)
        self.assertIn("landscape-report.pdf?v=", patched)
        self.assertIn("Date.now()", patched)
        self.assertIn("window.open(pdfHref, '_blank'", patched)
        self.assertNotIn("window.print(", patched)
        self.assertNotIn("createObjectURL", patched)

    def test_multi_market_vendor_card_ids_are_market_scoped(self) -> None:
        """Same vendor in APO + sdlc-plugins must not emit duplicate HTML ids."""
        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        self.assertIn("function _vendorCardDomId(slug, marketId)", template)
        self.assertIn("card.id = _vendorCardDomId(cardSlug, marketId)", template)
        self.assertIn("function _resolveMarketIdFromNode(node)", template)
        self.assertIn("const fromSelf = _marketIdFromHeadingText(node.textContent);", template)
        self.assertIn("if (fromSelf) return fromSelf;", template)
        # snav keeps both market occurrences reachable
        snav = template.split("function addPills", 1)[1].split("function insertVendorFilterBar", 1)[0]
        self.assertIn("multi && marketId", snav)
        self.assertIn("_marketShortLabel(marketId)", snav)
        self.assertIn("el.href = '#' + cardId", snav)
        # Bare vendor-{slug} assignment must not remain as the only id path.
        self.assertNotIn("card.id = 'vendor-' + cardSlug;", template)

    def test_bootstrap_accumulates_homepage_vendor_urls(self) -> None:
        """Per-market chart swaps must not drop homepage URLs used for card titles."""
        from landscape_preview_render import _patch_chart_bootstrap

        template = (ASSETS / "landscape-preview.template.html").read_text(encoding="utf-8")
        boot = _patch_chart_bootstrap(template)
        self.assertIn("let HOMEPAGE_VENDOR_URLS = {}", boot)
        apply_fn = boot.split("function applyChartData", 1)[1].split(
            "function applyMarketChartFromHeading", 1
        )[0]
        self.assertIn("HOMEPAGE_VENDOR_URLS[label] = url", apply_fn)
        self.assertIn("_homepageFromHeading(h3, displayName)", boot)
        vendor_url_fn = boot.split("function _vendorUrl", 1)[1].split("function ", 1)[0]
        self.assertIn("HOMEPAGE_VENDOR_URLS[label]", vendor_url_fn)

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

        with mock.patch.dict(os.environ, {"SB_SKIP_VENDOR_URL_HEALTH": "1"}):
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


class FreshSynthesizeRenderContractTests(unittest.TestCase):
    """Engine defaults for a *new* run — not the locked APO HTML."""

    def setUp(self) -> None:
        self._health_skip = mock.patch.dict(os.environ, {"SB_SKIP_VENDOR_URL_HEALTH": "1"})
        self._health_skip.start()
        self.addCleanup(self._health_skip.stop)

    def _seed_run(self, root: Path) -> None:
        (root / "contributions").mkdir(parents=True)
        (root / "consolidated").mkdir(parents=True)
        (root / "comparison").mkdir(parents=True)
        (root / "run_manifest.json").write_text(
            json.dumps(
                {
                    "query": "Agentic SDLC orchestration landscape",
                    "research_type": "solution-landscape",
                    "mode": "deep",
                    "run_id": "test-fresh-synthesize",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        (root / "need_profile.json").write_text(
            json.dumps(
                {
                    "category": "Agentic SDLC orchestration",
                    "category_pack_id": "agentic-sdlc-process-orchestrator",
                    "persona_id": "startup",
                    "license_preference": "mixed",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        (root / "contributions" / "all-envelopes.json").write_text(
            json.dumps(
                [
                    {
                        "phase_id": "DR-RETRIEVE",
                        "logical_model_id": "test-a",
                        "payload": {
                            "evidence": [
                                {
                                    "claim": "Silver Bullet composes workflows with hook-enforced gates."
                                }
                            ]
                        },
                    },
                    {
                        "phase_id": "DR-RETRIEVE",
                        "logical_model_id": "test-b",
                        "payload": {
                            "evidence": [
                                {
                                    "claim": "Factory.ai provides managed hosting for agentic delivery."
                                }
                            ]
                        },
                    },
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        (root / "consolidated" / "consolidation.json").write_text(
            json.dumps(
                {
                    "consensus": [
                        {
                            "text": "Process orchestration sits above coding agents.",
                            "support_count": 2,
                        }
                    ],
                    "divergence": [
                        {
                            "text": "Whether managed hosting is required for SMB APO buyers.",
                            "sides": [
                                {"stance": "required", "agents": ["test-a"]},
                                {"stance": "optional", "agents": ["test-b"]},
                            ],
                        }
                    ],
                }
            )
            + "\n",
            encoding="utf-8",
        )
        (root / "comparison" / "comparison.json").write_text(
            json.dumps(
                {
                    "rankings": [
                        {"solution": "silver-bullet", "score": 20, "rank": 1},
                        {"solution": "factory-ai", "score": 16, "rank": 2},
                    ],
                    "winner": "silver-bullet",
                    "runner_up": "factory-ai",
                    "rows": [
                        {"type": "category", "name": "Process orchestration"},
                        {
                            "type": "feature",
                            "name": "Workflow composition",
                            "priority": "Critical",
                            "solutions": {"silver-bullet": True, "factory-ai": True},
                        },
                        {
                            "type": "feature",
                            "name": "Hook-enforced gates",
                            "priority": "High",
                            "solutions": {"silver-bullet": True, "factory-ai": False},
                        },
                    ],
                }
            )
            + "\n",
            encoding="utf-8",
        )

    def test_fresh_synthesize_render_emits_analyst_defaults_and_lockstep(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_run(root)
            syn = synthesize_landscape(root, force=True)
            self.assertEqual(syn.get("status"), "ok")
            md = (root / "landscape" / "landscape-report.md").read_text(encoding="utf-8")
            self.assertIn("Executive Summary", md)
            self.assertIn("Vendor inclusion ledger", md)
            self.assertIn("Coverage completeness matrix", md)
            self.assertIn("Consensus Resolution Table", md)
            self.assertIn("Final analyst decision", md)
            self.assertIn("Consensus Patterns", md)
            rubric = json.loads((root / "landscape" / "features-rubric.json").read_text())
            self.assertEqual(rubric.get("source"), "comparison.json")
            names = [f for cat in rubric["categories"] for f in cat["features"]]
            self.assertIn("Workflow composition", names)
            self.assertNotIn("Visual/E2E verification", names)

            from landscape_preview_render import render_landscape_outputs

            env = {
                **os.environ,
                "SB_SKIP_LANDSCAPE_PDF": "1",
                "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1",
            }
            with mock.patch.dict(os.environ, env, clear=False):
                result = render_landscape_outputs(root)
            self.assertEqual(result.get("status"), "ok")
            self.assertEqual(result.get("pdf_href"), "landscape-report.pdf")
            html = (root / "landscape-report.html").read_text(encoding="utf-8")
            self.assertIn('id="report-data"', html)
            self.assertIn("data-sb-landscape-viewer", html)
            self.assertIn('target="_blank"', html)
            self.assertIn("noopener noreferrer", html)
            self.assertIn("landscape-report.pdf?v=", html)
            start = html.find('id="report-data"')
            self.assertGreater(start, 0)
            script_start = html.find(">", start) + 1
            script_end = html.find("</script>", script_start)
            payload = json.loads(html[script_start:script_end])
            self.assertEqual(payload.get("markdown"), md)

    def test_fresh_render_invokes_sibling_pdf_writer(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_run(root)
            synthesize_landscape(root, force=True)
            from landscape_preview_render import render_landscape_outputs

            with mock.patch(
                "landscape_preview_render.write_sibling_landscape_pdf",
                return_value={"pdf": str(root / "landscape-report.pdf"), "bytes": 12},
            ) as writer:
                with mock.patch.dict(os.environ, {"SB_SKIP_LANDSCAPE_PDF": ""}, clear=False):
                    result = render_landscape_outputs(root)
            writer.assert_called_once()
            self.assertEqual(result.get("pdf_href"), "landscape-report.pdf")
            self.assertNotEqual(result.get("pdf"), "skipped")

    def test_legacy_landscape_spa_retired(self) -> None:
        spa = (SCRIPTS / "generate_spa_report.py").read_text(encoding="utf-8")
        self.assertNotIn("def render_landscape(", spa)
        self.assertNotIn("data-landscape-marker", spa)
        wrapper = (SCRIPTS / "generate_landscape_report.py").read_text(encoding="utf-8")
        self.assertIn("render_landscape_outputs", wrapper)
        self.assertNotIn("from generate_spa_report import main", wrapper)




if __name__ == "__main__":
    unittest.main()


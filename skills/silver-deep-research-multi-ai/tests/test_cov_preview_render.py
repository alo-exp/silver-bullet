"""Offline unit tests for landscape_preview_render (payload collection, template patching, PDF routing)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import landscape_preview_render as lpr  # noqa: E402


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


def pack() -> dict:
    return {
        "category_id": "demo-pack",
        "primary_market_id": "m1",
        "markets": [
            {"id": "m1", "display_name": "M1", "seeds": [
                {"slug": "alpha", "name": "Alpha", "homepage": "https://alpha.example"},
                {"slug": "beta", "name": "Beta", "license": "oss", "homepage": "https://beta.example"}]},
            {"id": "m2", "display_name": "M2", "seeds": [{"slug": "gamma", "name": "Gamma", "homepage": "https://gamma.example"}]},
        ],
    }


class OfflineCase(unittest.TestCase):
    """Every test in this module runs with network health checks and PDF rendering switched off."""

    def setUp(self) -> None:
        patcher = mock.patch.dict(os.environ, {"SB_SKIP_VENDOR_URL_HEALTH": "1"})
        patcher.start()
        self.addCleanup(patcher.stop)
        net = mock.patch("urllib.request.urlopen", side_effect=AssertionError("network access in a unit test"))
        net.start()
        self.addCleanup(net.stop)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)


class LoaderTests(OfflineCase):
    def test_load_json(self) -> None:
        self.assertIsNone(lpr._load_json(self.root / "none.json"))
        write_json(self.root / "a.json", {"a": 1})
        self.assertEqual(lpr._load_json(self.root / "a.json"), {"a": 1})

    def test_typed_loaders_reject_wrong_shapes(self) -> None:
        for name, loader, rel in (
            ("manifest", lpr._load_manifest, "run_manifest.json"),
            ("need", lpr._load_need_profile, "need_profile.json"),
            ("comparison", lpr._load_comparison, "comparison/comparison.json"),
            ("consolidation", lpr._load_consolidation, "consolidated/consolidation.json"),
        ):
            with self.subTest(name):
                self.assertEqual(loader(self.root), {})
                write_json(self.root / rel, ["not", "a", "dict"])
                self.assertEqual(loader(self.root), {})
                write_json(self.root / rel, {"ok": name})
                self.assertEqual(loader(self.root), {"ok": name})

    def test_load_envelopes(self) -> None:
        self.assertEqual(lpr._load_envelopes(self.root), [])
        write_json(self.root / "contributions" / "all-envelopes.json", {"not": "list"})
        self.assertEqual(lpr._load_envelopes(self.root), [])
        write_json(self.root / "contributions" / "all-envelopes.json", [{"a": 1}, "junk", 2])
        self.assertEqual(lpr._load_envelopes(self.root), [{"a": 1}])

    def test_audit_link_slugs(self) -> None:
        self.assertEqual(lpr._audit_link_slugs(self.root), [])
        write_json(self.root / "landscape" / "catalog_audit.json", ["x"])
        self.assertEqual(lpr._audit_link_slugs(self.root), [])
        write_json(self.root / "landscape" / "catalog_audit.json", {"matrix_slugs": ["a", "b"], "adjacent": ["b", "c", "", None]})
        self.assertEqual(lpr._audit_link_slugs(self.root), ["a", "b", "c"])

    def test_load_chart_data_search_order(self) -> None:
        self.assertEqual(lpr._load_chart_data(self.root), lpr.CHART_DEFAULTS)
        self.assertIsNot(lpr._load_chart_data(self.root), lpr.CHART_DEFAULTS)
        write_json(self.root / "consolidated" / "chart-data.json", {"mq_data": [{"slug": "late"}]})
        self.assertEqual(lpr._load_chart_data(self.root)["mq_data"], [{"slug": "late"}])
        write_json(self.root / "chart-data.json", ["not a dict"])
        self.assertEqual(lpr._load_chart_data(self.root)["mq_data"], [{"slug": "late"}])
        write_json(self.root / "landscape" / "chart-data.json", {"mq_data": [{"slug": "first"}], "extra": 1})
        merged = lpr._load_chart_data(self.root)
        self.assertEqual((merged["mq_data"], merged["extra"]), ([{"slug": "first"}], 1))
        self.assertIn("anchors", merged)  # defaults are kept underneath

    def test_load_chart_data_enriches_when_comparison_given(self) -> None:
        write_json(self.root / "chart-data.json", {"mq_data": []})
        with mock.patch.object(lpr, "_enrich_chart_data", return_value={"enriched": True}) as enrich:
            out = lpr._load_chart_data(self.root, comparison={"rankings": []}, need={"n": 1})
        self.assertEqual(out, {"enriched": True})
        self.assertEqual(enrich.call_args.args[1], self.root)
        self.assertEqual(enrich.call_args.kwargs, {"need": {"n": 1}})


class FindMarkdownTests(OfflineCase):
    def test_priorities(self) -> None:
        land = self.root / "landscape"
        self.assertEqual(lpr._find_landscape_markdown(self.root), (land / "landscape-report.md", ""))
        land.mkdir()
        (land / "landscape-report.md").write_text("  \n", encoding="utf-8")
        # blank canonical is skipped but remembered as the last resort
        self.assertEqual(lpr._find_landscape_markdown(self.root), (land / "landscape-report.md", "  \n"))
        (self.root / "x landscape y.md").write_text("root landscape text", encoding="utf-8")
        self.assertEqual(lpr._find_landscape_markdown(self.root)[1], "root landscape text")
        (self.root / "A Market Landscape Report.md").write_text("market report text", encoding="utf-8")
        self.assertEqual(lpr._find_landscape_markdown(self.root)[1], "market report text")
        (land / "small.md").write_text("small", encoding="utf-8")
        (land / "big.md").write_text("big content here", encoding="utf-8")
        (land / "blank.md").write_text("\n", encoding="utf-8")
        (land / "dir.md").mkdir()
        self.assertEqual(lpr._find_landscape_markdown(self.root), (land / "big.md", "big content here"))
        (land / "landscape-report.md").write_text("canonical wins", encoding="utf-8")
        self.assertEqual(lpr._find_landscape_markdown(self.root), (land / "landscape-report.md", "canonical wins"))

    def test_only_blank_candidates_and_directory_matches(self) -> None:
        land = self.root / "landscape"
        land.mkdir()
        (land / "blank.md").write_text(" ", encoding="utf-8")
        (self.root / "dir landscape.md").mkdir()
        path, text = lpr._find_landscape_markdown(self.root)
        self.assertEqual((path, text), (land / "landscape-report.md", ""))

    def test_no_landscape_dir_uses_root_candidates(self) -> None:
        (self.root / "one landscape.md").write_text("root text", encoding="utf-8")
        self.assertEqual(lpr._find_landscape_markdown(self.root), (self.root / "one landscape.md", "root text"))


class ChartSlugTests(OfflineCase):
    def test_slugs_dedupe_and_skip_malformed(self) -> None:
        data = {
            "mq_data": [{"slug": " a "}, {"slug": "a"}, {"slug": ""}, "junk", {"nope": 1}],
            "markets": {"m1": {"mq_data": [{"slug": "b"}, {"slug": "a"}]}, "m2": "junk", "m3": {"mq_data": "bad"}},
        }
        self.assertEqual(lpr._chart_slugs_from_data(data), ["a", "b"])
        self.assertEqual(lpr._chart_slugs_from_data({"mq_data": "bad"}), [])
        self.assertEqual(lpr._chart_slugs_from_data({}), [])


class EnrichTests(OfflineCase):
    def run_enrich(self, chart, comparison=None, *, the_pack="default", pairs=None, need=None):
        the_pack = pack() if the_pack == "default" else the_pack
        seen = []

        def fake_link_pairs(rankings, **kw):
            seen.append((rankings, kw))
            return [list(p) for p in (pairs if pairs is not None else [["Alpha", "https://alpha.example"]])]

        with mock.patch("category_pack.resolve_pack_from_need", return_value=the_pack), \
                mock.patch("materialize_solution_artifacts._effective_known_solutions", return_value={"alpha": "Alpha"}), \
                mock.patch("synthesize_landscape.build_link_pairs", fake_link_pairs):
            out = lpr._enrich_chart_data(chart, self.root, comparison or {}, need=need)
        return out, seen

    def test_without_pack_uses_chart_slugs_and_merges_existing_pairs(self) -> None:
        chart = {"mq_data": [{"slug": "alpha", "label": "Alpha", "q": "Leaders"}],
                 "gmq_data": [{"slug": "alpha", "label": "Alpha", "q": "Challengers"}],
                 "link_pairs": [["Alpha", "https://stale.example"], ["Old Vendor", "https://old.example"], ["bad"], "junk"]}
        out, seen = self.run_enrich(chart, {"rankings": [{"solution": "alpha"}, "junk"]}, the_pack=None, pairs=[["Alpha", "https://alpha.example"]])
        self.assertEqual(seen[0][1]["matrix_slugs"], ["alpha"])
        self.assertEqual(seen[0][1]["chart_slugs"], ["alpha"])
        self.assertIsNone(seen[0][1]["commercial"])
        self.assertEqual(seen[0][0], [{"solution": "alpha"}])
        self.assertEqual(out["vendor_urls"], {"Alpha": "https://alpha.example", "Old Vendor": "https://old.example"})
        self.assertEqual([p[0] for p in out["link_pairs"]], ["Old Vendor", "Alpha"])  # longest label first
        # the MQ quadrant wins over GMQ in the vendor buckets
        self.assertEqual(out["vendor_buckets"]["leaders"], ["Alpha"])
        self.assertEqual(out["vendor_buckets"]["challengers"], [])
        self.assertNotIn("link_pairs", chart.get("markets", {}))
        self.assertEqual(chart["link_pairs"][0], ["Alpha", "https://stale.example"])  # input untouched

    def test_no_pairs_yields_empty_maps_and_non_list_existing_pairs_are_ignored(self) -> None:
        out, _ = self.run_enrich({"link_pairs": "not a list", "mq_data": []}, the_pack=None, pairs=[])
        self.assertEqual((out["link_pairs"], out["vendor_urls"]), ([], {}))
        # a non-list mq_data and non-list gmq_data skip bucket building only when both are non-lists
        out2, _ = self.run_enrich({"mq_data": "bad", "gmq_data": "bad"}, the_pack=None, pairs=[])
        self.assertNotIn("vendor_buckets", out2)
        out3, _ = self.run_enrich({"mq_data": "bad", "gmq_data": [{"label": "G", "q": "Leaders"}]}, the_pack=None, pairs=[])
        self.assertEqual(out3["vendor_buckets"]["leaders"], ["G"])
        out4, _ = self.run_enrich({"mq_data": [{"label": "M", "q": "Leaders"}], "gmq_data": "bad"}, the_pack=None, pairs=[])
        self.assertEqual(out4["vendor_buckets"]["leaders"], ["M"])

    def test_audit_file_drives_matrix_slugs(self) -> None:
        write_json(self.root / "landscape" / "catalog_audit.json", {"matrix_slugs": ["alpha"], "adjacent": ["beta", "alpha", ""]})
        _, seen = self.run_enrich({"mq_data": [{"slug": "zzz"}]}, the_pack=None)
        self.assertEqual(seen[0][1]["matrix_slugs"], ["alpha", "beta"])
        write_json(self.root / "landscape" / "catalog_audit.json", ["not a dict"])
        _, seen2 = self.run_enrich({"mq_data": [{"slug": "zzz"}]}, the_pack=None)
        self.assertEqual(seen2[0][1]["matrix_slugs"], ["zzz"])

    def test_pack_derives_catalogs_and_rankings_fallback(self) -> None:
        comparison = {"rankings": [{"solution": "alpha"}, {"solution": "beta"}, {"nosolution": 1}]}
        out, seen = self.run_enrich({}, comparison)
        kw = seen[0][1]
        self.assertEqual(kw["matrix_slugs"], ["alpha", "beta"])  # chart has no slugs; the catalog is derived from rankings
        self.assertEqual([e["slug"] for e in kw["commercial"]], ["alpha"])
        self.assertEqual([e["slug"] for e in kw["oss"]], ["beta"])
        self.assertEqual(out["vendor_buckets"]["commercial"], ["Alpha"])
        self.assertEqual(out["vendor_buckets"]["oss"], ["Beta"])

    def test_pack_with_chart_slugs_does_not_fall_back_to_rankings(self) -> None:
        chart = {"mq_data": [{"slug": "gamma"}]}
        out, seen = self.run_enrich(chart, {"rankings": [{"solution": "alpha"}]})
        self.assertEqual(seen[0][1]["matrix_slugs"], ["gamma"])
        self.assertEqual([e["slug"] for e in seen[0][1]["commercial"]], ["gamma"])  # chart slugs, not rankings, feed the catalog

    def test_per_market_charts(self) -> None:
        write_json(self.root / "landscape" / "catalog_audit.json", {"markets": {"m1": {"core": ["alpha"]}}})
        chart = {
            "markets": {
                "m1": {"mq_data": [{"slug": "alpha", "label": "Alpha", "q": "Leaders"}], "gmq_data": [{"slug": "alpha", "label": "Alpha", "q": "Niche Players"}]},
                "m2": {"mq_data": [{"slug": "gamma", "label": "Gamma", "q": "Challengers"}]},
                "m4": {"mq_data": [{"slug": "delta", "label": "Delta"}]},
                "m5": {"mq_data": "not a list"},
                "junk": "string market",
            },
        }
        comparison = {"rankings": [{"solution": "alpha"}, {"solution": "gamma"}]}
        out, seen = self.run_enrich(chart, comparison, pairs=[["Alpha", "https://alpha.example"]])
        markets = out["markets"]
        self.assertEqual(markets["junk"], "string market")
        # m1: slugs come from the audit core and the call is scoped to that market's rankings
        m1_call = [kw for _r, kw in seen if kw["chart_slugs"] == ["alpha"] and kw["matrix_slugs"] == ["alpha"]]
        self.assertTrue(m1_call)
        self.assertEqual(markets["m1"]["vendor_urls"], {"Alpha": "https://alpha.example"})
        self.assertEqual(markets["m1"]["vendor_buckets"]["leaders"], ["Alpha"])
        self.assertEqual([r for r, kw in seen if kw["chart_slugs"] == ["alpha"]], [[{"solution": "alpha"}]])
        # m2: not in the audit, so the pack's own seed list is used
        self.assertTrue([kw for _r, kw in seen if kw["chart_slugs"] == ["gamma"]])
        self.assertEqual(markets["m2"]["vendor_buckets"]["challengers"], ["Gamma"])
        # m4: neither audit nor pack know it, so the market's own MQ slugs are used and no rankings match
        m4_calls = [(r, kw) for r, kw in seen if kw["chart_slugs"] == ["delta"]]
        self.assertEqual(m4_calls[0][0], None)
        # m5: no bucket building for a malformed mq list
        self.assertNotIn("vendor_buckets", markets["m5"])

    def test_market_without_pairs_keeps_chart_without_link_keys(self) -> None:
        chart = {"markets": {"m1": {"mq_data": [{"slug": "alpha", "label": "Alpha"}]}}}
        out, _ = self.run_enrich(chart, pairs=[])
        self.assertNotIn("link_pairs", out["markets"]["m1"])
        self.assertNotIn("vendor_urls", out["markets"]["m1"])

    def test_non_dict_markets_value_is_left_alone(self) -> None:
        out, _ = self.run_enrich({"markets": None})
        self.assertIsNone(out["markets"])


class DeriveVendorTests(OfflineCase):
    def test_license_tags_and_dedupe(self) -> None:
        comparison = {"rankings": [
            {"solution": "plain"}, {"solution": "plain"}, {"solution": ""}, "junk",
            {"solution": "tagged-oss", "license": "OSS"}, {"solution": "opened", "type": "Open source"},
            {"solution": "beta"}, {"solution": "silver-bullet"},
        ]}
        with mock.patch("category_pack.resolve_pack_from_need", return_value=pack()):
            commercial, oss = lpr._derive_vendors_from_comparison(comparison, need={"category_pack_id": "x"})
        self.assertEqual(commercial, ["plain"])
        self.assertEqual(oss, ["tagged-oss", "opened", "beta", "silver-bullet"])

    def test_no_pack_and_column_fallback(self) -> None:
        with mock.patch("category_pack.resolve_pack_from_need", return_value=None):
            self.assertEqual(lpr._derive_vendors_from_comparison({}), ([], []))
            rows = {"rows": [{"type": "feature", "name": "F", "solutions": {"zeta": "y", "silver-bullet": "y"}}]}
            commercial, oss = lpr._derive_vendors_from_comparison(rows)
        self.assertEqual((commercial, oss), (["zeta"], ["silver-bullet"]))

    def test_solution_columns(self) -> None:
        self.assertEqual(lpr._solution_columns({"rankings": [{"solution": "b"}, {"solution": "a"}, {"x": 1}, "junk"]}), ["b", "a"])
        rows = {"rankings": [{"x": 1}], "rows": [
            {"type": "feature", "solutions": {"z": 1, "y": 2}}, {"type": "feature", "solutions": "str"},
            {"type": "group", "solutions": {"q": 1}}, "junk"]}
        self.assertEqual(lpr._solution_columns(rows), ["y", "z"])
        self.assertEqual(lpr._solution_columns({}), [])
        self.assertEqual(lpr._solution_columns({"rankings": "str"}), [])


class CollectPayloadTests(OfflineCase):
    def seed(self, **over) -> None:
        write_json(self.root / "landscape" / "chart-data.json", over.get("chart", {"mq_data": [{"slug": "alpha"}]}))
        write_json(self.root / "comparison" / "comparison.json", over.get("comparison", {"rankings": [{"solution": "alpha"}], "rows": []}))
        (self.root / "landscape" / "landscape-report.md").write_text(over.get("markdown", "# Report title\n\nBody text\n"), encoding="utf-8")

    def test_full_payload(self) -> None:
        self.seed()
        write_json(self.root / "run_manifest.json", {"query": "Q?", "research_type": "solution-compare", "run_id": "r1", "mode": "deep",
                                                      "workflow_id": "wf", "started_at": "s", "finished_at": "f", "multi_ai": {"k": 1}})
        write_json(self.root / "need_profile.json", {"category": "Cat"})
        write_json(self.root / "consolidated" / "consolidation.json",
                   {"consensus": [{"text": "c1", "n": 1}, "junk"], "divergence": [{"text": "d1"}, {"nothing": 1}], "other": 7})
        write_json(self.root / "contributions" / "all-envelopes.json",
                   [{"payload": {"claim": "env claim", "list": ["x", {"text": "nested"}], "n": 3}}])
        with mock.patch("synthesize_landscape.scrub_membership_framing", side_effect=lambda text, p: text.upper()):
            data = lpr.collect_landscape_payload(self.root)
        self.assertEqual(data["title"], "Q?")
        self.assertEqual(data["research_type"], "solution-compare")
        self.assertEqual(data["need_profile"], {"category": "Cat"})
        self.assertEqual(data["pdf_href"], "landscape-report.pdf")
        self.assertEqual(data["research_slug"], self.root.name)
        self.assertEqual(data["landscape"]["markdown_path"], "landscape/landscape-report.md")
        self.assertEqual(data["markdown"], "# Report title\n\nBody text\n")
        self.assertEqual(data["manifest"], {"run_id": "r1", "mode": "deep", "workflow_id": "wf", "started_at": "s", "finished_at": "f", "multi_ai": {"k": 1}})
        self.assertEqual(data["consolidation"]["consensus"], [{"text": "C1", "n": 1}])
        self.assertEqual(data["consolidation"]["divergence"], [{"text": "D1"}, {"nothing": 1, "text": ""}])
        self.assertEqual(data["consolidation"]["other"], 7)
        self.assertEqual(data["envelopes"], [{"payload": {"claim": "ENV CLAIM", "list": ["X", {"text": "NESTED"}], "n": 3}}])
        self.assertEqual(data["chart_data"]["mq_data"], [{"slug": "alpha"}])
        self.assertIn("anchors", data["chart_data"])
        self.assertEqual(data["landscape"]["commercial_vendors"], ["alpha"])
        self.assertEqual(data["canonical_paths"]["comparison"], str(self.root / "comparison" / "comparison.json"))
        self.assertTrue(data["generated_by"].endswith("landscape_preview_render.py"))
        self.assertIn("xlsx_href", data)

    def test_defaults_and_title_fallbacks(self) -> None:
        self.seed()
        data = lpr.collect_landscape_payload(self.root)
        self.assertEqual(data["research_type"], "solution-landscape")
        self.assertEqual(data["need_profile"], {"category": "landscape"})
        self.assertEqual(data["title"], "landscape report")  # file stem with dashes replaced
        self.assertEqual(data["manifest"]["multi_ai"], {})
        write_json(self.root / "need_profile.json", {"category": "From Need"})
        self.assertEqual(lpr.collect_landscape_payload(self.root)["title"], "From Need")

    def test_markdown_comes_from_fallback_search_and_charts_from_loader(self) -> None:
        (self.root / "Some Market Landscape Report.md").write_text("# Found\n\ntext", encoding="utf-8")
        write_json(self.root / "chart-data.json", {"mq_data": [{"slug": "root-level"}]})
        data = lpr.collect_landscape_payload(self.root)
        self.assertEqual(data["markdown"], "# Found\n\ntext")
        self.assertEqual(data["title"], "Some Market Landscape Report")
        self.assertEqual(data["landscape"]["markdown_path"], "Some Market Landscape Report.md")
        self.assertEqual(data["chart_data"]["mq_data"], [{"slug": "root-level"}])

    def test_compression_markers_are_sanitized_or_rejected(self) -> None:
        self.seed(markdown="# T\n\nkeep\n[Archived]\n... [lean-ctx: cut]\ntail\n")
        data = lpr.collect_landscape_payload(self.root)
        self.assertEqual(data["markdown"], "# T\n\nkeep\ntail")
        self.seed(markdown="# T\n")
        with mock.patch.object(lpr, "sanitize_compression_markers", side_effect=lambda t: t + "\n[Archived]"):
            with self.assertRaisesRegex(ValueError, "landscape markdown payload"):
                lpr.collect_landscape_payload(self.root)

    def test_comparison_falls_back_to_loader_and_non_dict_sources(self) -> None:
        self.seed()
        sources = {"markdown": 5, "chart_data": ["x"], "comparison": ["y"],
                   "paths": {"markdown": str(self.root / "landscape" / "landscape-report.md")}}
        with mock.patch("landscape_independent_pdf.load_canonical_landscape_sources", return_value=sources):
            data = lpr.collect_landscape_payload(self.root)
        self.assertEqual(data["comparison"], {"rankings": [{"solution": "alpha"}], "rows": []})
        self.assertEqual(data["markdown"], "# Report title\n\nBody text\n")
        self.assertEqual(data["chart_data"]["mq_data"], [{"slug": "alpha"}])

    def test_markdown_path_outside_root_uses_canonical_relative_path(self) -> None:
        real = self.root / "real"
        self.seed()
        (self.root / "real").mkdir()
        link = self.root / "link"
        link.symlink_to(self.root, target_is_directory=True)
        data = lpr.collect_landscape_payload(link)
        self.assertEqual(data["landscape"]["markdown_path"], "landscape/landscape-report.md")
        del real

    def test_missing_markdown_file_still_reports_canonical_relative_path(self) -> None:
        write_json(self.root / "landscape" / "chart-data.json", {})
        data = lpr.collect_landscape_payload(self.root)
        self.assertEqual(data["markdown"], "")
        self.assertEqual(data["landscape"]["markdown_path"], "landscape/landscape-report.md")


class TemplatePatchTests(OfflineCase):
    def test_patch_chart_bootstrap(self) -> None:
        self.assertEqual(lpr._patch_chart_bootstrap("no markers"), "no markers")
        reversed_ = f"{lpr.MARKER_END}\nmiddle\n{lpr.MARKER_START}\n"
        self.assertEqual(lpr._patch_chart_bootstrap(reversed_), reversed_)
        only_start = f"head {lpr.MARKER_START} tail"
        self.assertEqual(lpr._patch_chart_bootstrap(only_start), only_start)
        spliced = lpr._patch_chart_bootstrap(f"HEAD\n{lpr.MARKER_START}\nOLD CHART DATA\n{lpr.MARKER_END}(a,b) {{}}\nTAIL")
        self.assertTrue(spliced.startswith("HEAD\n"))
        self.assertNotIn("OLD CHART DATA", spliced)
        self.assertIn("function bootstrapFromEmbedded()", spliced)
        self.assertIn("function renderMatrixPanel()", spliced)
        self.assertTrue(spliced.endswith(f"{lpr.MARKER_END}(a,b) {{}}\nTAIL"))

    def test_generated_javascript_keeps_regex_escapes_intact(self) -> None:
        spliced = lpr._patch_chart_bootstrap(f"{lpr.MARKER_START}\n{lpr.MARKER_END}")
        self.assertIn(r"/\b\w/g", spliced)  # word-boundary, not a backspace character
        self.assertNotIn("\x08", spliced)
        self.assertIn(r".replace(/\s*\([^)]*\)\s*/g, '')", spliced)
        self.assertIn(r".replace(/[^\w\s-]/g, '')", spliced)
        self.assertIn(r".replace(/[\s_]+/g, '-')", spliced)
        self.assertIn(r"md.split('\n')", spliced)

    def test_strip_hardcoded_link_pairs(self) -> None:
        self.assertEqual(lpr._strip_hardcoded_link_pairs("none"), "none")
        no_fn = f"a\n{lpr.HYPERLINKS_START}\nconst LINK_PAIRS = [];\n"
        self.assertEqual(lpr._strip_hardcoded_link_pairs(no_fn), no_fn)
        out = lpr._strip_hardcoded_link_pairs(f"a\n{lpr.HYPERLINKS_START}\nconst LINK_PAIRS = [];\nfunction linkify() {{}}\nz")
        self.assertEqual(out, "a\n// ─── Hyperlinks (populated from embedded chart_data.link_pairs) ─────────\nfunction linkify() {}\nz")

    def test_patch_load_call(self) -> None:
        tmpl = "async function loadFile(path) {\n  body\n}\nstart();\nloadFile('x.md');   \nnext();\n" + lpr.BOOTSTRAP_COMMENT + "\n"
        out = lpr._patch_load_call(tmpl)
        self.assertNotIn("loadFile", out)
        self.assertIn("scheduleLandscapeBootstrap", out)
        self.assertNotIn(lpr.BOOTSTRAP_COMMENT, out)
        self.assertIn("start();\nnext();", out)
        # already patched templates are left alone
        done = "x scheduleLandscapeBootstrap y"
        self.assertEqual(lpr._patch_load_call(done), done)
        # marker edited away: autostart is injected before the first DOMContentLoaded listener
        fallback = lpr._patch_load_call("a\ndocument.addEventListener('DOMContentLoaded', () => {\nb")
        self.assertIn("scheduleLandscapeBootstrap", fallback)
        self.assertLess(fallback.index("scheduleLandscapeBootstrap"), fallback.index("DOMContentLoaded', () => {"))
        # nothing to patch at all
        self.assertEqual(lpr._patch_load_call("plain"), "plain")

    def test_modern_theme_is_inserted_once_before_style_end(self) -> None:
        out = lpr._inject_modern_theme("<style>a{}</style><style>b{}</style>")
        self.assertEqual(out.count("#matrixDrawer {"), 1)
        self.assertTrue(out.startswith("<style>a{}"))
        self.assertIn("Roboto Condensed", out)
        self.assertEqual(out.count("</style>"), 2)
        self.assertLess(out.index("Roboto Condensed"), out.index("</style>"))

    def test_matrix_ui_injection(self) -> None:
        base = ('<button id="pdfExportBtn" class="x">PDF</button><div id="compareDrawer" class="d"></div>'
                "<script>document.addEventListener('DOMContentLoaded', () => {\n"
                "document.getElementById('pdfExportBtn').addEventListener('click', exportToPDF);\n});</script>")
        out = lpr._inject_matrix_ui(base)
        self.assertEqual(out.count('id="matrixBtn"'), 1)
        self.assertIn('id="matrixDrawer"', out)
        self.assertLess(out.index('id="matrixBtn"'), out.index('id="pdfExportBtn"'))
        self.assertLess(out.index('id="matrixDrawer"'), out.index('id="compareDrawer"'))
        self.assertIn("matrixCloseBtn", out)
        self.assertIn("matrixBtn.addEventListener('click'", out)
        # idempotent: nothing is added a second time
        self.assertEqual(lpr._inject_matrix_ui(out), out)
        # existing button/drawer markup is respected but the click hook is still added when missing
        pre = '<i id="matrixBtn"></i><i id="matrixDrawer"></i>' + base.replace("<script>", "<script>/* */").replace("DOMContentLoaded", "DOMContentLoaded") 
        res = lpr._inject_matrix_ui(pre)
        self.assertEqual(res.count('id="matrixBtn"'), 1)
        self.assertEqual(res.count('id="matrixDrawer"'), 1)

    def test_pdf_export_patch(self) -> None:
        self.assertEqual(lpr._patch_pdf_export("nothing"), "nothing")
        self.assertEqual(lpr._patch_pdf_export("function _inlineStylesForGDocs(r) {}\nasync function exportToPDF() {}"),
                         "function _inlineStylesForGDocs(r) {}\nasync function exportToPDF() {}")
        legacy = "A\nasync function exportToPDF() { window.print(); }\nfunction _inlineStylesForGDocs(r) {}\nZ"
        out = lpr._patch_pdf_export(legacy)
        self.assertTrue(out.startswith("A\nasync function exportToPDF() {\n  const btn"))
        self.assertIn("landscape-report.pdf?v=", out)
        self.assertNotIn("window.print(", out)
        self.assertTrue(out.endswith("function _inlineStylesForGDocs(r) {}\nZ"))
        self.assertEqual(lpr._patch_pdf_export(out), out)  # already patched
        blob = out.replace("window.open(pdfHref", "createObjectURL(pdfHref")
        self.assertNotEqual(lpr._patch_pdf_export(blob), blob)  # blob URLs are replaced again

    def test_inject_report_data(self) -> None:
        out = lpr._inject_report_data('<html lang="en"><head><title>x</title></head>', {"k": "</script>"})
        self.assertIn('<head>\n<script type="application/json" id="report-data">', out)
        self.assertIn('data-sb-landscape-viewer="multai-v1"', out)
        self.assertNotIn("</script></script>", out)
        bare = lpr._inject_report_data("<html>no head</html>", {"k": 1})
        self.assertEqual(bare, "<html>no head</html>")


class RenderPreviewTests(OfflineCase):
    def test_full_template_render(self) -> None:
        data = {"title": "A <b>title</b>", "markdown": "# T", "comparison": {}, "chart_data": {}}
        page = lpr.render_landscape_preview(data)
        for marker in lpr.LANDSCAPE_MARKERS:
            self.assertIn(marker, page)
        self.assertIn("<title>A &lt;b&gt;title&lt;/b&gt;</title>", page)
        self.assertIn("function bootstrapFromEmbedded()", page)
        self.assertNotIn("async function loadFile", page)
        self.assertIn('id="report-data"', page)
        self.assertNotIn("\x08", page)
        self.assertIn(r"/\b\w/g", page)

    def test_default_title_and_missing_template(self) -> None:
        self.assertIn("<title>Landscape Report</title>", lpr.render_landscape_preview({}))
        with mock.patch.object(lpr, "TEMPLATE_PATH", self.root / "missing.html"):
            with self.assertRaisesRegex(FileNotFoundError, "landscape template missing"):
                lpr.render_landscape_preview({})


class PdfRoutingTests(OfflineCase):
    def test_playwright_argv(self) -> None:
        with mock.patch.object(lpr.shutil, "which", side_effect=lambda n: "/b/pw" if n == "playwright" else "/b/npx"):
            self.assertEqual(lpr._playwright_argv(), ["/b/pw"])
        with mock.patch.object(lpr.shutil, "which", side_effect=lambda n: "/b/npx" if n == "npx" else None):
            self.assertEqual(lpr._playwright_argv(), ["/b/npx", "--yes", "playwright"])
        with mock.patch.object(lpr.shutil, "which", return_value=None):
            with self.assertRaisesRegex(FileNotFoundError, "playwright CLI not found"):
                lpr._playwright_argv()

    def test_skip_flag_matrix(self) -> None:
        def skip(**env):
            with mock.patch.dict(os.environ, {"SB_SKIP_LANDSCAPE_PDF": "", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "", "PYTEST_CURRENT_TEST": ""}):
                os.environ.update(env)
                return lpr._skip_landscape_pdf()

        self.assertFalse(skip())
        self.assertFalse(skip(SB_ALLOW_SKIP_LANDSCAPE_PDF="1"))
        self.assertFalse(skip(SB_SKIP_LANDSCAPE_PDF="1"))  # the skip flag alone is not honored outside tests
        for truthy in ("1", "true", "YES", " yes "):
            self.assertTrue(skip(SB_SKIP_LANDSCAPE_PDF=truthy, SB_ALLOW_SKIP_LANDSCAPE_PDF="1"), truthy)
        self.assertTrue(skip(SB_SKIP_LANDSCAPE_PDF="1", PYTEST_CURRENT_TEST="tests/x.py::t"))
        self.assertFalse(skip(SB_SKIP_LANDSCAPE_PDF="0", SB_ALLOW_SKIP_LANDSCAPE_PDF="1"))

    def make_research_root(self, base: Path) -> None:
        write_json(base / "comparison" / "comparison.json", {})
        (base / "landscape").mkdir(parents=True, exist_ok=True)
        (base / "landscape" / "landscape-report.md").write_text("# x", encoding="utf-8")

    def test_research_root_resolution(self) -> None:
        out_dir = self.root / "out"
        out_dir.mkdir()
        html_path = out_dir / "landscape-report.html"
        html_path.write_text("x", encoding="utf-8")
        # nothing is a research root: the explicit root (or the HTML folder) is the answer
        self.assertEqual(lpr._research_root_for_pdf(html_path), out_dir.resolve())
        other = self.root / "other"
        other.mkdir()
        self.assertEqual(lpr._research_root_for_pdf(html_path, other), other.resolve())
        # the HTML folder itself qualifies
        self.make_research_root(out_dir)
        self.assertEqual(lpr._research_root_for_pdf(html_path), out_dir.resolve())
        # explicit root wins over the HTML folder, duplicates are skipped
        self.make_research_root(other)
        self.assertEqual(lpr._research_root_for_pdf(html_path, other), other.resolve())
        self.assertEqual(lpr._research_root_for_pdf(html_path, out_dir), out_dir.resolve())
        # the HTML parent's parent qualifies too
        deep = self.root / "proj" / "reports"
        deep.mkdir(parents=True)
        self.make_research_root(self.root / "proj")
        deep_html = deep / "landscape-report.html"
        deep_html.write_text("x", encoding="utf-8")
        self.assertEqual(lpr._research_root_for_pdf(deep_html), (self.root / "proj").resolve())

    def test_write_sibling_pdf(self) -> None:
        with self.assertRaisesRegex(FileNotFoundError, "landscape HTML missing"):
            lpr.write_sibling_landscape_pdf(self.root / "nope.html")
        html_path = self.root / "landscape-report.html"
        html_path.write_text("x", encoding="utf-8")
        calls = []

        def fake(root, pdf, *, timeout_ms, print_html_path):
            calls.append((root, pdf, timeout_ms, print_html_path))
            return {"pdf": str(pdf), "bytes": 12}

        with mock.patch("landscape_independent_pdf.write_independent_landscape_pdf", fake):
            info = lpr.write_sibling_landscape_pdf(html_path, timeout_ms=77, research_root=self.root)
        self.assertEqual(info, {"pdf": str(self.root.resolve() / "landscape-report.pdf"), "bytes": 12})
        root, pdf, timeout_ms, printed = calls[0]
        self.assertEqual((root, timeout_ms), (self.root.resolve(), 77))
        self.assertEqual(printed, self.root.resolve() / "landscape-report.print.html")

    def render_outputs(self, **env):
        write_json(self.root / "landscape" / "chart-data.json", {})
        write_json(self.root / "comparison" / "comparison.json", {})
        (self.root / "landscape" / "landscape-report.md").write_text("# R\n", encoding="utf-8")
        with mock.patch.dict(os.environ, {"SB_SKIP_LANDSCAPE_PDF": "", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "", "PYTEST_CURRENT_TEST": ""}):
            os.environ.update(env)
            with mock.patch.object(lpr, "write_sibling_landscape_pdf", return_value={"pdf": "/x.pdf", "bytes": 9}) as sib:
                result = lpr.render_landscape_outputs(self.root)
        return result, sib

    def test_render_outputs_skipping_pdf(self) -> None:
        result, sib = self.render_outputs(SB_SKIP_LANDSCAPE_PDF="1", SB_ALLOW_SKIP_LANDSCAPE_PDF="1")
        self.assertEqual(result["pdf"], "skipped")
        self.assertNotIn("pdf_bytes", result)
        sib.assert_not_called()
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["profile"], "landscape")
        self.assertEqual(result["markers"], lpr.LANDSCAPE_MARKERS)
        self.assertEqual(result["out"], str(self.root / "landscape-report.html"))
        self.assertEqual(result["sources"]["markdown"], str(self.root / "landscape" / "landscape-report.md"))
        self.assertIn("data-sb-landscape-viewer", (self.root / "landscape-report.html").read_text(encoding="utf-8"))

    def test_render_outputs_writing_pdf(self) -> None:
        result, sib = self.render_outputs()
        self.assertEqual((result["pdf"], result["pdf_bytes"]), ("/x.pdf", 9))
        sib.assert_called_once_with(self.root / "landscape-report.html", research_root=self.root)

    def test_render_outputs_custom_out_and_source_fallback(self) -> None:
        write_json(self.root / "landscape" / "chart-data.json", {})
        write_json(self.root / "comparison" / "comparison.json", {})
        (self.root / "landscape" / "landscape-report.md").write_text("# R\n", encoding="utf-8")
        custom = self.root / "custom.html"
        with mock.patch.dict(os.environ, {"SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"}):
            with mock.patch.object(lpr, "collect_landscape_payload", return_value={"title": "T", "canonical_paths": {}}):
                result = lpr.render_landscape_preview_file(self.root, out=custom)
        self.assertTrue(custom.is_file())
        self.assertEqual(result["out"], str(custom))
        self.assertEqual(result["sources"]["chart_data"], str(self.root / "landscape" / "chart-data.json"))
        self.assertEqual(result["sources"]["comparison"], str(self.root / "comparison" / "comparison.json"))


if __name__ == "__main__":
    unittest.main()

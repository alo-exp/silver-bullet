"""Asymmetric cases that pin operators and comparisons the broader coverage tests leave unconstrained."""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import landscape_independent_pdf as lp  # noqa: E402
import landscape_preview_render as lpr  # noqa: E402
import materialize_solution_artifacts as mat  # noqa: E402


def scatter(points, **kw):
    base = dict(title="T", x_label="X", y_label="Y", colors={}, chart_kind="mq:t")
    base.update(kw)
    # skip the collision pass so the crafted coordinates and quadrants reach the plotter unchanged
    with mock.patch.dict(sys.modules, {"synthesize_landscape": None}):
        return lp._svg_scatter(points=points, **base)


class LabelFallbackSideTests(unittest.TestCase):
    """When no ring slot is free the label is pushed toward the plot centre, on the side the dot is NOT on."""

    def last_label_x(self, cx: float) -> float:
        items = [(cx, 30.0, f"Vendor {i}", 26) for i in range(30)]
        out = lp._place_point_labels(items, x_min=0.0, x_max=100.0, y_min=0.0, y_max=60.0)
        return out[-1][0]

    def test_left_of_centre_pushes_right_and_centre_or_right_pushes_left(self) -> None:
        self.assertEqual(self.last_label_x(30.0), 42.0)  # dot left of centre -> label 12px to its right
        self.assertEqual(self.last_label_x(50.0), 38.0)  # dot exactly at centre -> label to its left
        self.assertEqual(self.last_label_x(70.0), 58.0)  # dot right of centre -> label to its left


class DotColourTests(unittest.TestCase):
    def fills(self, svg: str) -> list[str]:
        return re.findall(r'<circle class="fig-pt"[^>]*? fill="([^"]*)"', svg)

    def test_palette_colour_wins_and_unknown_quadrant_cycles_the_wave_palette(self) -> None:
        pts = [
            {"slug": "a", "label": "A", "x": 2, "y": 2, "q": "Leaders"},
            {"slug": "b", "label": "B", "x": 4, "y": 4, "q": "Mystery"},
            {"slug": "c", "label": "C", "x": 6, "y": 6},
        ]
        svg = scatter(pts, colors={"Leaders": "#abcdef"})
        self.assertEqual(self.fills(svg), ["#abcdef", lp._WAVE_PALETTE[1], lp._WAVE_PALETTE[2]])

    def test_wave_title_is_used_for_the_aria_label_only_when_given(self) -> None:
        block = {"wave_data": [{"slug": "w", "label": "W", "strategy": 2, "offering": 3, "presence": 2}]}
        with_title = lp.render_market_figures({"markets": {"m": {**block, "titles": {"wave": "Custom Wave"}}}}, "m")
        self.assertIn('aria-label="Custom Wave"', with_title)
        without = lp.render_market_figures({"markets": {"m": block}}, "m")
        self.assertIn('aria-label="Wave"', without)


class MarkdownEdgeTests(unittest.TestCase):
    def test_italic_link_after_text_is_wrapped_but_double_star_prefix_is_not(self) -> None:
        a = '<a href="https://u" target="_blank" rel="noopener noreferrer">t</a>'
        self.assertEqual(lp._md_inline("x *[t](https://u)* y"), "x <em>" + a + "</em> y")
        # three stars before the link: the char two back is also "*", so it is not a lone-star emphasis
        self.assertEqual(lp._md_inline("x **[t](https://u)* y"), "x **" + a + "* y")

    def test_table_separator_detection_uses_either_test(self) -> None:
        out = lp.markdown_to_html("| A | B |\n|---|---|\n|--|--|\n| 1 | 2 |")
        self.assertEqual(out.count("<tr>"), 2)  # header row + the single data row; the short separator is skipped
        self.assertIn("<td>1</td><td>2</td>", out)
        self.assertNotIn("<td>--</td>", out)
        # a row whose first cell is a dash run is treated as a separator even though other cells are text
        out2 = lp.markdown_to_html("| A | B |\n|---|---|\n|---| x |\n| 1 | 2 |")
        self.assertNotIn("<td>x</td>", out2)
        self.assertIn("<td>1</td>", out2)


class OverviewFocusTests(unittest.TestCase):
    CROWD = "Aider, Cline and Continue are alternatives"

    def test_focus_name_containing_the_product_is_not_counted_as_another_product(self) -> None:
        # name ("aider") is inside the longer focus name: only cline and continue remain -> usable
        self.assertFalse(mat.is_unusable_overview_claim(self.CROWD, focus_name="Aider Tool"))

    def test_focus_name_inside_the_product_display_name_is_not_counted(self) -> None:
        claim = "Microsoft AutoGen, Aider and Cline are alternatives"
        self.assertFalse(mat.is_unusable_overview_claim(claim, focus_name="autogen"))
        self.assertTrue(mat.is_unusable_overview_claim(claim, focus_name="zzz"))

    def test_empty_focus_counts_every_product(self) -> None:
        self.assertTrue(mat.is_unusable_overview_claim(self.CROWD))


class MatrixEntryHeadTests(unittest.TestCase):
    def test_feature_aliases_and_features_with_a_trailing_product_stay_feature_rows(self) -> None:
        for head in ("ci/cd devin", "hook gates devin", "audit log devin", "self-serve signup devin"):
            with self.subTest(head=head):
                self.assertFalse(mat._matrix_entry_head_is_solution(head))
        # the same trailing product without a feature prefix is a solution head
        self.assertTrue(mat._matrix_entry_head_is_solution("the devin platform"))


class ProseNegationTests(unittest.TestCase):
    def test_features_in_a_but_clause_are_negative_with_or_without_lack_words(self) -> None:
        support: dict = {}
        mat._parse_prose_claim(support, "Devin offers workflow composition, but scores poorly on hook gates")
        self.assertIs(support["devin"]["Hook-enforced gates"], False)
        self.assertTrue(support["devin"]["Workflow composition"])


class PreviewEnrichmentTests(unittest.TestCase):
    def enrich(self, chart, link_pairs=None, pack=None):
        with mock.patch("category_pack.resolve_pack_from_need", return_value=pack), \
                mock.patch("materialize_solution_artifacts._effective_known_solutions", return_value={}), \
                mock.patch("synthesize_landscape.build_link_pairs", return_value=link_pairs or []), \
                mock.patch("vendor_link_labels.filter_vendor_link_pairs", side_effect=lambda p: [list(x) for x in p if isinstance(x, (list, tuple))]):
            return lpr._enrich_chart_data(chart, Path("."), {})

    def test_non_sequence_link_pair_entries_do_not_break_the_merge(self) -> None:
        out = self.enrich({"link_pairs": [["Old", "https://old.example"]]}, link_pairs=[5, None, ["A", "https://a.example"]])
        self.assertEqual(out["vendor_urls"]["A"], "https://a.example")
        self.assertEqual(out["vendor_urls"]["Old"], "https://old.example")

    def test_market_buckets_use_mq_and_a_list_gmq_only(self) -> None:
        pack = {"category_id": "p", "markets": [{"id": "m", "seeds": []}]}
        mq = [{"label": "A", "q": "Leaders"}]
        gmq = [{"label": "G", "q": "Leaders"}, {"label": "A", "q": "Challengers"}]
        with mock.patch("category_pack.market_slug_sets", return_value={}), \
                mock.patch("category_pack.catalog_entries_from_pack", return_value=([], [])):
            both = self.enrich({"markets": {"m": {"mq_data": mq, "gmq_data": gmq}}}, pack=pack)["markets"]["m"]["vendor_buckets"]
            bad = self.enrich({"markets": {"m": {"mq_data": mq, "gmq_data": "oops"}}}, pack=pack)["markets"]["m"]["vendor_buckets"]
            absent = self.enrich({"markets": {"m": {"mq_data": mq}}}, pack=pack)["markets"]["m"]["vendor_buckets"]
        self.assertEqual(sorted(both["leaders"]), ["A", "G"])  # GMQ-only vendor counted, MQ wins for A
        self.assertEqual(both["challengers"], [])
        self.assertEqual(bad["leaders"], ["A"])  # a malformed gmq_data is ignored, not iterated
        self.assertEqual(absent["leaders"], ["A"])


class PreviewPayloadTests(unittest.TestCase):
    def test_need_profile_reaches_pack_resolution_and_scrubbing(self) -> None:
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "landscape").mkdir()
            (root / "comparison").mkdir()
            (root / "landscape" / "landscape-report.md").write_text("# T\n", encoding="utf-8")
            (root / "landscape" / "chart-data.json").write_text("{}", encoding="utf-8")
            (root / "comparison" / "comparison.json").write_text("{}", encoding="utf-8")
            (root / "need_profile.json").write_text(json.dumps({"category": "Cat"}), encoding="utf-8")
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(
                json.dumps([{"payload": {"notes": {"claim": "deep"}, "list": ["x"]}}]), encoding="utf-8")
            sentinel = {"pack": "sentinel"}
            seen_need, seen_pack = [], []

            def resolve(need):
                seen_need.append(need)
                # only the real need profile resolves to a pack; an empty one must not
                return sentinel if need == {"category": "Cat"} else None

            def scrub(text, pack):
                seen_pack.append(pack)
                return text.upper()

            with mock.patch("category_pack.resolve_pack_from_need", side_effect=resolve), \
                    mock.patch("synthesize_landscape.scrub_membership_framing", side_effect=scrub):
                data = lpr.collect_landscape_payload(root)
        self.assertIn({"category": "Cat"}, seen_need)
        self.assertTrue(seen_pack and all(p is sentinel for p in seen_pack))  # pack from the need profile, not {}
        # "notes" holds a dict, not a string, so it is recursed into rather than scrubbed as a whole
        self.assertEqual(data["envelopes"][0]["payload"]["notes"], {"claim": "DEEP"})
        self.assertEqual(data["envelopes"][0]["payload"]["list"], ["X"])


if __name__ == "__main__":
    unittest.main()

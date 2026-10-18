"""Offline unit tests for landscape_independent_pdf (pure functions, fake network, fake Playwright)."""

from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import landscape_independent_pdf as lp  # noqa: E402


_NET_PATCH = None


def setUpModule() -> None:
    # Any accidental HTTP request (font CSS in a freshly exec'd module, for instance) fails
    # immediately and offline instead of reaching the network.
    global _NET_PATCH
    _NET_PATCH = mock.patch.object(urllib.request, "urlopen", side_effect=urllib.error.URLError("network disabled in tests"))
    _NET_PATCH.start()


def tearDownModule() -> None:
    _NET_PATCH.stop()


class _FakeResp:
    def __init__(self, data: bytes) -> None:
        self._data = data

    def read(self) -> bytes:
        return self._data

    def __enter__(self) -> "_FakeResp":
        return self

    def __exit__(self, *exc) -> bool:
        return False


class PlaywrightArgvTests(unittest.TestCase):
    def test_prefers_playwright_then_npx_then_fails(self) -> None:
        with mock.patch.object(lp.shutil, "which", side_effect=lambda n: "/bin/playwright" if n == "playwright" else "/bin/npx"):
            self.assertEqual(lp._playwright_argv(), ["/bin/playwright"])
        with mock.patch.object(lp.shutil, "which", side_effect=lambda n: "/bin/npx" if n == "npx" else None):
            self.assertEqual(lp._playwright_argv(), ["/bin/npx", "--yes", "playwright"])
        with mock.patch.object(lp.shutil, "which", return_value=None):
            with self.assertRaisesRegex(FileNotFoundError, "playwright CLI not found"):
                lp._playwright_argv()


class LoaderTests(unittest.TestCase):
    def test_load_json_variants(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "x.json"
            self.assertEqual(lp._load_json(p), {})
            p.write_text("{bad", encoding="utf-8")
            self.assertEqual(lp._load_json(p), {})
            p.write_text("[1]", encoding="utf-8")
            self.assertEqual(lp._load_json(p), {})
            p.write_text('{"a": 1}', encoding="utf-8")
            self.assertEqual(lp._load_json(p), {"a": 1})
            with mock.patch.object(Path, "read_text", side_effect=OSError("io")):
                self.assertEqual(lp._load_json(p), {})

    def test_canonical_sources(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            empty = lp.load_canonical_landscape_sources(root)
            self.assertEqual((empty["markdown"], empty["chart_data"], empty["comparison"]), ("", {}, {}))
            (root / "landscape").mkdir()
            (root / "comparison").mkdir()
            (root / "consolidated").mkdir()
            (root / "landscape" / "landscape-report.md").write_text("# T\n", encoding="utf-8")
            (root / "landscape" / "chart-data.json").write_text('{"c": 1}', encoding="utf-8")
            (root / "comparison" / "comparison.json").write_text('{"k": 2}', encoding="utf-8")
            (root / "consolidated" / "consolidation.json").write_text('{"d": 3}', encoding="utf-8")
            src = lp.load_canonical_landscape_sources(root)
            self.assertEqual(src["markdown"], "# T\n")
            self.assertTrue(src["paths"]["markdown"].endswith("landscape/landscape-report.md"))
            self.assertEqual(lp.load_chart_data(root), {"c": 1})
            self.assertEqual(lp.load_comparison(root), {"k": 2})
            self.assertEqual(lp.load_consolidation(root), {"d": 3})
            self.assertEqual(lp.load_landscape_markdown(root), "# T\n")

    def test_non_dict_and_non_str_payloads_are_normalized(self) -> None:
        bad = {"markdown": 5, "chart_data": [1], "comparison": "x"}
        with mock.patch.object(lp, "load_canonical_landscape_sources", return_value=bad):
            self.assertEqual(lp.load_chart_data(Path(".")), {})
            self.assertEqual(lp.load_comparison(Path(".")), {})
            self.assertEqual(lp.load_landscape_markdown(Path(".")), "")

    def test_load_spa_report_data(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(lp.load_spa_report_data(root), {})
            page = root / "landscape-report.html"
            page.write_text("<html>no data</html>", encoding="utf-8")
            self.assertEqual(lp.load_spa_report_data(root), {})
            page.write_text("<script id='report-data' type='application/json'>{bad</script>", encoding="utf-8")
            self.assertEqual(lp.load_spa_report_data(root), {})
            page.write_text('<script type="application/json" id="report-data">[1]</script>', encoding="utf-8")
            self.assertEqual(lp.load_spa_report_data(root), {})
            page.write_text('<script type="application/json" id="report-data">{"markdown": "m"}</script>', encoding="utf-8")
            self.assertEqual(lp.load_spa_report_data(root), {"markdown": "m"})
            with mock.patch.object(Path, "read_text", side_effect=OSError("io")):
                self.assertEqual(lp.load_spa_report_data(root), {})


class ChartStructureTests(unittest.TestCase):
    def test_market_chart_block_and_ids(self) -> None:
        chart = {"primary_market_id": "b", "markets": {"a": {"mq_data": []}, "b": {"x": 1}, "c": "str"}}
        self.assertEqual(lp.market_chart_block(chart, "a"), {"mq_data": []})
        self.assertEqual(lp.market_chart_block(chart, "zzz"), {})
        self.assertEqual(lp.market_chart_block({"primary_market_id": "p", "markets": {"a": {}}}, "p"), {"primary_market_id": "p", "markets": {"a": {}}})
        flat = {"mq_data": [1]}
        self.assertIs(lp.market_chart_block(flat, "anything"), flat)
        self.assertEqual(lp.iter_market_ids(chart), ["b", "a", "c"])
        self.assertEqual(lp.iter_market_ids({"primary_market_id": "gone", "markets": {"a": {}}}), ["a"])
        self.assertEqual(lp.iter_market_ids({"primary_market_id": "solo"}), ["solo"])
        self.assertEqual(lp.iter_market_ids({}), ["primary"])

    def test_quadrant_divergences(self) -> None:
        chart = {"markets": {"m": {
            "mq_data": [{"slug": "a", "label": "A", "q": "Leaders"}, {"slug": "b", "q": "Niche Players"}, {"slug": "c", "q": ""},
                        {"slug": "only-mq", "q": "Leaders"}, "junk"],
            "gmq_data": [{"slug": "a", "q": "Challengers"}, {"slug": "b", "label": "Bee", "q": "Niche Players"},
                         {"slug": "c", "q": "Leaders"}, "junk"],
        }}}
        self.assertEqual(lp.quadrant_divergences(chart), [{"market": "m", "slug": "a", "label": "A", "mq": "Leaders", "gmq": "Challengers"}])
        chart2 = {"markets": {"m": {"mq_data": [{"slug": "z", "q": "Leaders"}], "gmq_data": [{"slug": "z", "label": "Zed", "q": "Niche Players"}]}}}
        self.assertEqual(lp.quadrant_divergences(chart2)[0]["label"], "Zed")
        chart3 = {"markets": {"m": {"mq_data": [{"slug": "z", "q": "Leaders"}], "gmq_data": [{"slug": "z", "q": "Niche Players"}]}}}
        self.assertEqual(lp.quadrant_divergences(chart3)[0]["label"], "z")
        self.assertEqual(lp.quadrant_divergences({}), [])


class SmallHelperTests(unittest.TestCase):
    def test_escape_anchor_clip(self) -> None:
        self.assertEqual(lp._esc('<a href="x">&\''), "&lt;a href=&quot;x&quot;&gt;&amp;&#x27;")
        self.assertEqual(lp._html_ext_anchor("https://a/?q=1&r=2", "<b>t</b>"),
                         '<a href="https://a/?q=1&amp;r=2" target="_blank" rel="noopener noreferrer"><b>t</b></a>')
        self.assertEqual(lp._clip_id("mq:apo plugin"), "cmq-apo-plugin")

    def test_boxes_overlap(self) -> None:
        self.assertTrue(lp._boxes_overlap((0, 0, 10, 10), (5, 5, 10, 10)))
        self.assertFalse(lp._boxes_overlap((0, 0, 10, 10), (20, 0, 10, 10)))
        self.assertFalse(lp._boxes_overlap((0, 0, 10, 10), (0, 20, 10, 10)))
        self.assertFalse(lp._boxes_overlap((20, 0, 10, 10), (0, 0, 10, 10)))
        self.assertFalse(lp._boxes_overlap((0, 20, 10, 10), (0, 0, 10, 10)))
        # padding bridges a small gap
        self.assertTrue(lp._boxes_overlap((0, 0, 10, 10), (11, 0, 10, 10)))
        self.assertFalse(lp._boxes_overlap((0, 0, 10, 10), (11, 0, 10, 10), pad=0.0))

    def test_clamp_and_inside(self) -> None:
        self.assertEqual(lp._clamp_label_box((-50, -50, 20, 10), 0, 100, 0, 100), (0, 0, 20, 10))
        self.assertEqual(lp._clamp_label_box((95, 95, 20, 10), 0, 100, 0, 100), (80, 90, 20, 10))
        self.assertEqual(lp._clamp_label_box((0, 0, 500, 500), 0, 100, 0, 50), (0, 0, 100, 50))
        # a degenerate plot still allows an 8px box
        self.assertEqual(lp._clamp_label_box((0, 0, 30, 30), 0, 2, 0, 2)[2:], (8.0, 8.0))
        self.assertTrue(lp._box_in_plot((0, 0, 10, 10), 0, 10, 0, 10))
        self.assertFalse(lp._box_in_plot((-1, 0, 10, 10), 0, 10, 0, 10))
        self.assertFalse(lp._box_in_plot((0, -1, 10, 10), 0, 10, 0, 10))
        self.assertFalse(lp._box_in_plot((1, 0, 10, 10), 0, 10, 0, 10))
        self.assertFalse(lp._box_in_plot((0, 1, 10, 10), 0, 10, 0, 10))

    def test_coord_collision_wrapper(self) -> None:
        pts = [{"slug": "a", "x": 1, "y": 1}, "junk", {"slug": "b", "x": 1, "y": 1}]
        out = lp._apply_plot_coord_collisions(pts, wave=False)
        self.assertEqual(len(out), 2)
        out_w = lp._apply_plot_coord_collisions(pts, wave=True)
        self.assertEqual(len(out_w), 2)
        with mock.patch.dict(sys.modules, {"synthesize_landscape": None}):
            plain = lp._apply_plot_coord_collisions(pts, wave=False)
        self.assertEqual(plain, [{"slug": "a", "x": 1, "y": 1}, {"slug": "b", "x": 1, "y": 1}])


class FontEmbedTests(unittest.TestCase):
    def setUp(self) -> None:
        saved = lp._FONT_CSS_CACHE
        lp._FONT_CSS_CACHE = None
        self.addCleanup(setattr, lp, "_FONT_CSS_CACHE", saved)

    def test_cache_hit_skips_network(self) -> None:
        lp._FONT_CSS_CACHE = "cached-css"
        with mock.patch.object(lp.urllib.request, "urlopen", side_effect=AssertionError("network")) as m:
            self.assertEqual(lp._embed_roboto_font_css(), "cached-css")
        m.assert_not_called()

    def test_css_fetch_failure_caches_empty_string(self) -> None:
        for exc in (urllib.error.URLError("down"), TimeoutError("slow"), OSError("io")):
            lp._FONT_CSS_CACHE = None
            with mock.patch.object(lp.urllib.request, "urlopen", side_effect=exc):
                self.assertEqual(lp._embed_roboto_font_css(), "")
            self.assertEqual(lp._FONT_CSS_CACHE, "")

    def test_font_urls_are_inlined_and_failed_fonts_left_alone(self) -> None:
        css = "@font-face{src:url(https://fonts.example/a.woff2)} @font-face{src:url(https://fonts.example/b.woff2)} local(x)"
        seen = []

        def fake_urlopen(target, timeout=None):
            if hasattr(target, "full_url"):
                seen.append(("css", target.get_header("User-agent"), timeout))
                return _FakeResp(css.encode())
            seen.append(("font", target, timeout))
            if target.endswith("b.woff2"):
                raise urllib.error.URLError("missing")
            return _FakeResp(b"\x00FONT")

        with mock.patch.object(lp.urllib.request, "urlopen", fake_urlopen):
            out = lp._embed_roboto_font_css()
        self.assertIn("url('data:font/woff2;base64,AEZPTlQ=')", out)
        self.assertIn("url(https://fonts.example/b.woff2)", out)
        self.assertEqual(seen[0][0], "css")
        self.assertIn("Mozilla/5.0", seen[0][1])
        self.assertEqual([s[0] for s in seen], ["css", "font", "font"])
        self.assertEqual(lp._FONT_CSS_CACHE, out)


class LabelPlacementTests(unittest.TestCase):
    BOUNDS = dict(x_min=0.0, x_max=200.0, y_min=0.0, y_max=120.0)

    def test_spread_points_get_non_overlapping_boxes_inside_the_plot(self) -> None:
        items = [(40.0, 60.0, "Alpha", 6.5), (120.0, 60.0, "Beta", 6.5), (80.0, 100.0, "Gamma", 6.5)]
        out = lp._place_point_labels(items, **self.BOUNDS)
        self.assertEqual([lab for _x, _y, lab in out], ["Alpha", "Beta", "Gamma"])
        for (x, y, _lab), (cx, cy, _l, _r) in zip(out, items):
            self.assertTrue(0.0 <= x <= 200.0 and 0.0 <= y <= 120.0)
            self.assertNotEqual((round(x), round(y)), (round(cx), round(cy)))

    def test_empty_input(self) -> None:
        self.assertEqual(lp._place_point_labels([], **self.BOUNDS), [])

    CROWDED = [
        (62.9, 61.1, "L" * 19, 26), (64.1, 62.4, "L" * 17, 10), (63.0, 61.0, "L" * 16, 26), (63.1, 61.3, "L" * 4, 6.5),
        (65.5, 60.6, "L" * 13, 26), (63.0, 61.8, "L" * 23, 6.5), (61.6, 58.7, "L" * 22, 10), (60.9, 61.5, "L" * 14, 26),
        (63.2, 59.9, "L" * 5, 26), (61.6, 62.1, "L" * 21, 26), (65.0, 57.3, "L" * 16, 10), (62.2, 59.8, "L" * 14, 6.5),
        (61.3, 57.6, "L" * 14, 26), (62.9, 58.5, "L" * 16, 6.5), (65.4, 58.9, "L" * 20, 10), (61.5, 59.7, "L" * 18, 6.5),
        (62.2, 58.8, "L" * 11, 26), (64.7, 62.4, "L" * 5, 10), (60.9, 58.4, "L" * 10, 6.5), (62.5, 60.9, "L" * 6, 26),
    ]

    def test_dense_cluster_of_big_bubbles_still_gets_distinct_in_plot_labels(self) -> None:
        # The ring search fails for most of these points; the inward fallback plus the vertical
        # nudge search must still find a free slot for each label.
        out = lp._place_point_labels(self.CROWDED, x_min=0.0, x_max=100.0, y_min=0.0, y_max=60.0)
        self.assertEqual([lab for _x, _y, lab in out], [item[2] for item in self.CROWDED])
        self.assertEqual(len({(round(x, 1), round(y, 1)) for x, y, _ in out}), len(self.CROWDED))
        for x, y, _lab in out:
            self.assertTrue(0.0 <= x <= 100.0 and 0.0 <= y <= 60.0)

    def test_tiny_plot_cannot_hold_any_box_and_falls_back_inward(self) -> None:
        # A 6px-wide plot is narrower than the minimum 8px label box, so no ring candidate is "in plot".
        out = lp._place_point_labels([(3.0, 30.0, "abc", 6.5)], x_min=0.0, x_max=6.0, y_min=0.0, y_max=60.0)
        self.assertEqual(out, [(2.0, 16.0, "abc")])

    def test_coincident_points_in_a_small_plot_all_receive_a_position(self) -> None:
        out = lp._place_point_labels([(12.0, 12.0, "a", 6.5)] * 4, x_min=0.0, x_max=20.0, y_min=0.0, y_max=20.0)
        self.assertEqual(out, [(10.0, 9.0, "a")] * 4)


def sample_points(n: int = 3, **extra) -> list[dict]:
    qs = ["Leaders", "Challengers", "Visionaries", "Niche Players"]
    return [{"slug": f"s{i}", "label": f"Vendor {i}", "x": 2.0 + i * 2.5, "y": 3.0 + i * 1.7, "q": qs[i % 4], **extra} for i in range(n)]


class SvgScatterTests(unittest.TestCase):
    def render(self, points, **kw):
        base = dict(title="T <1>", x_label="X", y_label="Y", colors={}, chart_kind="mq:apo")
        base.update(kw)
        return lp._svg_scatter(points=points, **base)

    def render_raw(self, points, **kw):
        """Render without the synthesize collision pass so crafted points reach the plotter unchanged."""
        with mock.patch.dict(sys.modules, {"synthesize_landscape": None}):
            return self.render(points, **kw)

    def test_quadrant_chart_structure(self) -> None:
        svg = self.render(sample_points(4), colors={"Leaders": "#111111"})
        self.assertIn('data-chart="mq:apo"', svg)
        self.assertEqual(svg.count('class="fig-pt"'), 4)
        for name in ("NICHE PLAYERS", "VISIONARIES", "CHALLENGERS", "LEADERS"):
            self.assertIn(f">{name}</text>", svg)
        self.assertIn('aria-label="T &lt;1&gt;"', svg)
        self.assertIn('fill="#111111"', svg)  # custom colour for Leaders
        self.assertIn('class="legend">Leaders</text>', svg)
        self.assertIn('class="legend">Niche Players</text>', svg)
        self.assertNotIn("STRONG PERFORMERS", svg)
        self.assertIn('stroke="#ffffff"', svg)

    def test_named_regions_can_be_hidden(self) -> None:
        svg = self.render(sample_points(2), named_regions=False)
        self.assertNotIn("quad-label", svg)

    def test_points_are_filtered_and_sized(self) -> None:
        pts = [
            {"slug": "ok", "label": "Ok", "x": "5", "y": "5", "q": "Leaders", "sz": 5},
            {"slug": "bad", "x": "not-a-number", "y": 1},
            {"slug": "none-y", "x": None, "y": None, "sz": "bogus"},
            "junk",
            {"label": "Only label", "x": 1, "y": 1, "sz": -3},
            {"slug": "zero", "x": 2, "y": 2, "sz": 0},
        ]
        svg = self.render_raw(pts, size_key="sz", size_max=5.0)
        self.assertEqual(svg.count('class="fig-pt"'), 4)
        self.assertIn('r="15.0"', svg)  # sz=5 of 5 -> 5 + 10
        self.assertIn('r="5.0"', svg)  # sz=-3 is clamped to 0 -> 5 + 0
        self.assertEqual(svg.count('r="7.0"'), 2)  # bogus text and 0 both fall back to raw=1.0 -> 7.0
        self.assertIn('data-slug="Only label"', svg)

    def test_non_dict_points_from_the_collision_pass_are_skipped(self) -> None:
        pts = [{"slug": "a", "x": 5, "y": 5, "q": "Leaders"}, "junk", None]
        with mock.patch.object(lp, "_apply_plot_coord_collisions", return_value=pts):
            svg = self.render(pts)
        self.assertEqual(svg.count('class="fig-pt"'), 1)

    def test_wave_chart(self) -> None:
        pts = [
            {"slug": "w1", "label": "W1", "strategy": 4, "offering": 4, "presence": 4},
            {"slug": "w2", "label": "W2", "strategy": 2, "offering": 3, "presence": "bad"},
            {"slug": "w3", "label": "W3", "strategy": 1, "offering": 1, "presence": 9},
        ]
        svg = self.render(pts, chart_kind="wave:apo", colors={}, axis_min=0.5, axis_max=4.9, x_key="strategy",
                          y_key="offering", size_key="presence", size_max=4.0, named_regions=False, wave=True)
        for zone in ("CONTENDERS", "STRONG PERFORMERS", "LEADERS"):
            self.assertIn(zone, svg)
        self.assertIn("Emerging", svg)
        self.assertIn("Strong", svg)
        self.assertIn('fill-opacity="0.42"', svg)
        self.assertIn('r="26.0"', svg)  # presence 4
        self.assertIn('r="8.0"', svg)  # bad presence -> 1
        self.assertIn('r="10.0"', svg)  # unknown presence value -> default radius
        self.assertIn("Bubble size", svg)  # no quadrant on any point -> bubble-size legend

    def test_wave_without_points_shows_bubble_legend(self) -> None:
        svg = self.render([], chart_kind="wave:x", wave=True, size_key="presence", axis_min=0.5, axis_max=4.9)
        self.assertIn("Bubble size = Market Presence", svg)

    def test_no_legend_for_unquadranted_non_wave_points(self) -> None:
        svg = self.render_raw([{"slug": "a", "x": 5, "y": 5}])
        self.assertNotIn('class="legend"', svg)
        # the collision pass assigns quadrants from coordinates, so the legend then appears
        self.assertIn('class="legend"', self.render([{"slug": "a", "x": 5, "y": 5}]))

    def test_far_labels_get_leader_lines(self) -> None:
        # coincident points push most labels away from their dots, which draws a leader line
        pts = [{"slug": f"c{i}", "label": f"Crowded vendor {i}", "x": 5.0, "y": 5.0, "q": "Leaders"} for i in range(12)]
        svg = self.render(pts)
        self.assertIn('stroke-width="0.6" opacity="0.55"', svg)

    def test_label_next_to_its_dot_has_no_leader_line(self) -> None:
        svg = self.render_raw([{"slug": "edge", "label": "Edge", "x": 9.5, "y": 9.5}])
        self.assertNotIn('opacity="0.55"', svg)
        far = self.render_raw([{"slug": "mid", "label": "Mid", "x": 5, "y": 5}])
        self.assertIn('opacity="0.55"', far)

    def test_custom_palette_missing_quadrant_falls_back_to_cycle(self) -> None:
        svg = self.render_raw([{"slug": "a", "x": 1, "y": 1, "q": "Leaders"}], colors={"Challengers": "#222222"})
        self.assertIn("#1f3864", svg)  # first wave-palette colour used as the cycle fallback
        self.assertIn('class="legend">Leaders</text>', svg)


class FigureTests(unittest.TestCase):
    def test_figure_escapes(self) -> None:
        fig = lp._figure("A<B", "<svg/>", "cap&")
        self.assertIn("A&lt;B", fig)
        self.assertIn("<svg/>", fig)
        self.assertIn("cap&amp;", fig)

    def test_render_market_figures_all_kinds(self) -> None:
        block = {
            "titles": {"mq": "MQ title", "mq_x": "MX", "mq_y": "MY", "gmq": "G title", "gmq_x": "GX", "gmq_y": "GY", "wave": "W title"},
            "mq_data": sample_points(2), "gmq_data": sample_points(2),
            "wave_data": [{"slug": "w", "label": "W", "strategy": 2, "offering": 3, "presence": 2}],
            "mq_colors": {"Leaders": "#010101"}, "gmq_colors": "not-a-dict",
        }
        chart = {"primary_market_id": "apo", "markets": {"apo": block}}
        out = lp.render_market_figures(chart, "apo")
        self.assertTrue(out.startswith('<section class="market-charts" data-market="apo">'))
        self.assertTrue(out.endswith("</section>"))
        for kind in ("mq:apo", "gmq:apo", "wave:apo"):
            self.assertIn(f'data-chart="{kind}"', out)
        self.assertIn("MQ title", out)
        self.assertIn("W title", out)
        self.assertIn("Gartner-style MQ", out)

    def test_render_market_figures_defaults_and_empty(self) -> None:
        chart = {"mq_data": sample_points(2), "gmq_data": ["junk"] + sample_points(1)}
        out = lp.render_market_figures(chart, "solo")
        self.assertIn("solo positioning matrix", out)
        self.assertIn("solo Magic Quadrant", out)
        self.assertNotIn("wave:", out)
        self.assertEqual(lp.render_market_figures({"markets": {"a": {}}}, "zzz"),
                         '<section class="market-charts" data-market="zzz">\n</section>')
        wave_only = lp.render_market_figures({"wave_data": [{"slug": "w", "strategy": 1, "offering": 1, "presence": 1}]}, "x")
        self.assertIn("x Wave-style assessment", wave_only)


class MarkdownTests(unittest.TestCase):
    def test_inline_formats_and_autolinks(self) -> None:
        out = lp._inline_fmt_raw("**b** *e* `c` __d__ _u_ snake_case_word")
        self.assertEqual(out, "<strong>b</strong> <em>e</em> <code>c</code> <strong>d</strong> <em>u</em> snake_case_word")
        # unclosed markers stay literal and are HTML-escaped
        self.assertEqual(lp._inline_fmt_raw("**open `tick <x>"), "**open `tick &lt;x&gt;")
        self.assertEqual(lp._inline_fmt_raw("a * b"), "a * b")
        self.assertEqual(lp._inline_fmt_raw("__never closed"), "__never closed")
        self.assertEqual(lp._inline_fmt_raw("_never closed"), "_never closed")
        self.assertEqual(lp._inline_fmt_raw("under_score_ok and a_"), "under_score_ok and a_")
        anchor = '<a href="https://b.example/y" target="_blank" rel="noopener noreferrer">https://b.example/y</a>'
        self.assertEqual(lp._inline_fmt_raw("`https://b.example/y.`"), f"<code>{anchor}</code>")
        self.assertEqual(lp._inline_fmt_raw("`ftp://q`"), "<code>ftp://q</code>")
        self.assertEqual(lp._inline_fmt_raw("`see https://b.example/y`"), "<code>see https://b.example/y</code>")
        self.assertEqual(lp._inline_fmt_raw("`https://b.example/y.`", autolink=False), "<code>https://b.example/y.</code>")
        bare = lp._inline_fmt_raw("go to http://c.example/x. then")
        self.assertIn('<a href="http://c.example/x"', bare)
        self.assertTrue(bare.endswith(". then"))
        self.assertEqual(lp._inline_fmt_raw("go http://c.example/x", autolink=False), "go http://c.example/x")
        self.assertEqual(lp._inline_fmt_raw("https:// alone"), "https:// alone")

    def test_legacy_inline_fmt_wrapper_delegates(self) -> None:
        self.assertEqual(lp._inline_fmt("**x** <y>", re.compile("a"), re.compile("b"), re.compile("c")), "<strong>x</strong> &lt;y&gt;")

    def test_md_inline_link_wrapping(self) -> None:
        a = '<a href="https://u" target="_blank" rel="noopener noreferrer">{}</a>'
        self.assertEqual(lp._md_inline("plain"), "plain")
        self.assertEqual(lp._md_inline("see [t](https://u)"), "see " + a.format("t"))
        self.assertEqual(lp._md_inline("**[t](https://u)** x"), "<strong>" + a.format("t") + "</strong> x")
        self.assertEqual(lp._md_inline("*[t](https://u)* x"), "<em>" + a.format("t") + "</em> x")
        # a double-star on one side only, or **-emphasis directly after a lone star, is not wrapping
        self.assertEqual(lp._md_inline("**[t](https://u)*"), "**" + a.format("t") + "*")
        self.assertEqual(lp._md_inline("**[t](https://u)"), "**" + a.format("t"))
        self.assertEqual(lp._md_inline("*[t](https://u)**"), "*" + a.format("t") + "**")
        self.assertEqual(lp._md_inline("x**[t](https://u)*"), "x**" + a.format("t") + "*")
        self.assertEqual(lp._md_inline("[**s**](https://u)"), a.format("<strong>s</strong>"))
        self.assertEqual(lp._md_inline("[a](https://u) and [b](https://u)"), a.format("a") + " and " + a.format("b"))
        # link text is not auto-linked again
        self.assertEqual(lp._md_inline("[https://x.example](https://u)"), a.format("https://x.example"))

    def test_list_line_parsing(self) -> None:
        self.assertEqual(lp._parse_list_line("- a"), (0, "ul", "a"))
        self.assertEqual(lp._parse_list_line("  • b"), (2, "ul", "b"))
        self.assertEqual(lp._parse_list_line("\t* c"), (2, "ul", "c"))
        self.assertEqual(lp._parse_list_line("3. d"), (0, "ol", "d"))
        self.assertEqual(lp._parse_list_line("  10. e"), (2, "ol", "e"))
        self.assertEqual(lp._parse_list_line("- - doubled marker"), (0, "ul", "doubled marker"))
        self.assertIsNone(lp._parse_list_line("plain"))
        self.assertIsNone(lp._parse_list_line("-nospace"))
        self.assertEqual(lp._clean_list_body("  - * x  "), "x")

    def test_blocks(self) -> None:
        out = lp.markdown_to_html("# H1\r\n\r\ntext line\r\n###### H6 **b**\r\n")
        self.assertEqual(out.split("\n"), ["<h1>H1</h1>", "<p>text line</p>", "<h6>H6 <strong>b</strong></h6>"])
        self.assertEqual(lp.markdown_to_html(""), "")

    def test_table(self) -> None:
        md = "| A | B |\n|---|:--:|\n| 1 | **two** |\n| [l](https://l.example) | x |\nafter"
        out = lp.markdown_to_html(md)
        self.assertIn("<thead><tr><th>A</th><th>B</th></tr></thead>", out)
        self.assertIn("<tr><td>1</td><td><strong>two</strong></td></tr>", out)
        self.assertIn('<td><a href="https://l.example"', out)
        self.assertTrue(out.endswith("</tbody></table>\n<p>after</p>"))
        # a header-only table has an empty body, and a table of nothing but separators is dropped
        self.assertIn("<tbody>\n</tbody></table>", lp.markdown_to_html("| H |\n|---|"))
        self.assertEqual(lp.markdown_to_html("|---|\n|---|"), "")
        # a list directly before a table is closed first
        mixed = lp.markdown_to_html("- item\n| H |\n|---|\n| c |")
        self.assertLess(mixed.index("</ul>"), mixed.index("<table>"))

    def test_nested_lists_and_transitions(self) -> None:
        out = lp.markdown_to_html("- a\n  - b\n- c\n1. d\n2. e")
        self.assertEqual(
            out.split("\n"),
            ["<ul>", "<li>a", "<ul>", "<li>b", "</li>", "</ul>", "</li>", "<li>c", "</li>", "</ul>", "<ol>", "<li>d", "</li>", "<li>e", "</li>", "</ol>"],
        )
        # switching list type while nested closes the inner list first
        out2 = lp.markdown_to_html("- a\n  - b\n1. c")
        self.assertIn("</ul>\n</li>\n</ul>\n<ol>\n<li>c", out2)
        # dedent to an in-between indent opens a fresh list at that level
        out3 = lp.markdown_to_html("- a\n    - b\n  - c")
        self.assertEqual(out3.count("<ul>"), 3)
        self.assertEqual(out3.count("</ul>"), 3)
        # dedent into a parent of another type
        out4 = lp.markdown_to_html("1. a\n  - b\n  - c\n2. d")
        self.assertIn("<ol>", out4)
        self.assertEqual(out4.count("<ol>"), 1)
        # an indented list that starts with a deeper indent than anything open
        out5 = lp.markdown_to_html("    - deep\n  1. shallow")
        self.assertEqual(out5.count("<ul>") + out5.count("<ol>"), 2)
        self.assertIn("<ol>", out5)
        self.assertTrue(out5.endswith("</ol>"))
        # a blank line ends the list
        out6 = lp.markdown_to_html("- a\n\n- b")
        self.assertEqual(out6.count("<ul>"), 2)

    def test_leftover_markers_are_stripped_after_rendering(self) -> None:
        # a bullet whose text starts with an ordered-list marker loses that marker in the final pass
        self.assertEqual(lp.markdown_to_html("- 1. foo"), "<ul>\n<li>foo\n</li>\n</ul>")
        self.assertEqual(lp.markdown_to_html("1. - bar"), "<ol>\n<li>bar\n</li>\n</ol>")
        self.assertEqual(lp.markdown_to_html("- first\n- second").count("<li>-"), 0)


class SectionHelperTests(unittest.TestCase):
    def test_split_sections(self) -> None:
        self.assertEqual(lp._split_md_sections("just text"), [("", "just text")])
        self.assertEqual(lp._split_md_sections("pre\n## A\nbody a\n## B\nbody b\n"),
                         [("", "pre\n"), ("## A", "\nbody a\n"), ("## B", "\nbody b\n")])
        self.assertEqual(lp._split_md_sections("## Only\n"), [("## Only", "\n")])
        self.assertEqual(lp._split_md_sections("   \n## A\nx"), [("## A", "\nx")])

    def test_notable_block_strip_and_section_html(self) -> None:
        text = "intro\n**Notable divergences** (x)\n\n- one\n- two\n\nkeep this"
        self.assertEqual(lp._strip_notable_divergences_block(text), "intro\nkeep this")
        self.assertEqual(lp._strip_notable_divergences_block(""), "")
        self.assertEqual(lp._strip_notable_divergences_block(None), "")  # type: ignore[arg-type]
        self.assertEqual(lp._section_html("## Head", "body"), "<h2>Head</h2>\n<p>body</p>")
        self.assertEqual(lp._section_html("", "just body"), "<p>just body</p>")

    def test_slugify_label(self) -> None:
        self.assertEqual(lp._slugify_label("Silver Bullet (SB)"), "silver-bullet")
        self.assertEqual(lp._slugify_label("Foo_Bar  Baz!"), "foo-bar-baz")
        self.assertEqual(lp._slugify_label(None), "")  # type: ignore[arg-type]

    def test_rankings_and_features(self) -> None:
        self.assertEqual(lp._comparison_rankings({"rankings": [{"solution": "a"}, {"nosolution": 1}, "junk"]}), [{"solution": "a"}])
        by_rank = lp._comparison_rankings({"rankings": {"x": {"solution": "b", "rank": 2}, "y": {"solution": "a", "rank": 1},
                                                          "z": {"solution": "c"}, "w": "junk", "v": {"rank": 0}}})
        self.assertEqual([r["solution"] for r in by_rank], ["a", "b", "c"])
        self.assertEqual(lp._comparison_rankings({"rankings": "str"}), [])
        self.assertEqual(lp._comparison_rankings({}), [])
        feats = lp._comparison_features({"rows": [{"type": "feature", "name": "F"}, {"type": "group", "name": "G"},
                                                  {"type": "feature"}, "junk"]})
        self.assertEqual(feats, [{"type": "feature", "name": "F"}])
        self.assertEqual(lp._comparison_features({}), [])

    def test_solution_label(self) -> None:
        chart = {
            "vendor_urls": {"Exact-slug": "u", "Silver Bullet (SB)": "u2"},
            "markets": {
                "bad": "junk",
                "m": {"mq_data": ["junk", {"slug": "by-slug", "label": "By Slug Label"}, {"label": "By Label Name"}, {"slug": "nolabel"}],
                       "gmq_data": [], "wave_data": [{"slug": "wv", "label": "Wave Vendor"}]},
            },
        }
        self.assertEqual(lp._solution_label("", chart), "")
        self.assertEqual(lp._solution_label(None, chart), "")  # type: ignore[arg-type]
        self.assertEqual(lp._solution_label("Exact-slug", chart), "Exact-slug")
        self.assertEqual(lp._solution_label("silver-bullet", chart), "Silver Bullet (SB)")
        self.assertEqual(lp._solution_label("by-slug", chart), "By Slug Label")
        self.assertEqual(lp._solution_label("by-label-name", chart), "By Label Name")
        self.assertEqual(lp._solution_label("nolabel", chart), "nolabel")
        self.assertEqual(lp._solution_label("wv", chart), "Wave Vendor")
        self.assertEqual(lp._solution_label("some-unknown", chart), "some unknown")
        self.assertEqual(lp._solution_label("some-unknown", None), "some unknown")

    def test_needles_and_haystack(self) -> None:
        body = "\n# heading\n\n|---|:--|\nA short line\n" + "This is a sufficiently long body sentence with [a link](https://x.example/very/long) inside. " * 2 + "\n"
        needles = lp.section_body_needles(body)
        self.assertEqual(len(needles), 1)
        self.assertLessEqual(len(needles[0]), 80)
        self.assertNotIn("https", needles[0])
        self.assertEqual(lp.section_body_needles(body, min_len=5)[0], "A short line")
        self.assertEqual(lp.section_body_needles(""), [])
        self.assertEqual(lp.section_body_needles(None), [])  # type: ignore[arg-type]
        self.assertEqual(lp._norm_body_haystack("Hello, [World](https://x.example) https://y.example/z OK!"), "hello world ok")
        self.assertEqual(lp._norm_body_haystack(None), "")  # type: ignore[arg-type]

    def test_assert_section_bodies(self) -> None:
        body_a = "The quick brown fox jumps over the lazy dog near the riverbank today."
        body_b = "Another distinct paragraph that talks about completely different subject matter."
        md = f"preamble ignored text that is long enough to be a needle but has no heading\n## Alpha\n{body_a}\n## Beta\n{body_b}\n## Empty\n\n## Short\nshort words only\n"
        lp.assert_section_bodies_in_text(md, f"{body_a} {body_b}")
        with self.assertRaisesRegex(AssertionError, "missing from PDF/print text: ## Beta"):
            lp.assert_section_bodies_in_text(md, body_a)
        with self.assertRaisesRegex(AssertionError, "## Alpha, ## Beta"):
            lp.assert_section_bodies_in_text(md, "nothing relevant at all")
        lp.assert_section_bodies_in_text("", "")
        lp.assert_section_bodies_in_text(None, "x")  # type: ignore[arg-type]
        # needles with fewer than four words never count as a hit, so such a section is reported
        with self.assertRaises(AssertionError):
            lp.assert_section_bodies_in_text("## Tiny\n" + "x" * 60 + "\n", "x" * 60)


class ComparisonHtmlTests(unittest.TestCase):
    def comparison(self, n: int = 2):
        return {
            "winner": "w<1>", "runner_up": "r",
            "rankings": [{"solution": f"sol-{i}", "score": 10 - i} for i in range(n)],
            "rows": [
                {"type": "feature", "name": "Feature <A>", "priority": "high", "solutions": {"sol-0": "yes", "sol-1": "no"}},
                {"type": "feature", "name": "Feature B", "solutions": "not-a-dict"},
            ],
            "caveats": ["keep me", "mentions landscape-report.html", "Interactive SPA only", 5, "see [l](https://c.example)"],
        }

    def test_matrix_chunks_scores_and_caveats(self) -> None:
        out = lp.comparison_matrix_html(self.comparison(9), {"vendor_urls": {"Sol 0": "u"}})
        self.assertIn("Winner: <strong>w&lt;1&gt;</strong>. Runner-up: <strong>r</strong>.", out)
        self.assertEqual(out.count('<table class="matrix">'), 2)  # 9 solutions -> columns 7 + 2
        self.assertIn('<td>yes</td>\n<td>no</td>', out)
        self.assertIn("<td>—</td>", out)  # Feature B has no per-solution cells
        self.assertIn("Feature &lt;A&gt;", out)
        self.assertIn('<th>Sol 0<div class="score">Score 10</div></th>', out)
        self.assertIn('<tr class="cmp-score-row"><td><strong>Weighted score</strong></td><td>—</td>\n<td>10</td>\n<td>9</td>', out)
        self.assertIn("<h3>Matrix caveats</h3><ul>", out)
        self.assertIn("<li>keep me</li>", out)
        self.assertNotIn("landscape-report.html", out)
        self.assertNotIn("Interactive SPA", out)
        self.assertIn('href="https://c.example"', out)
        self.assertEqual(lp.comparison_highlights_html(self.comparison(2)), lp.comparison_matrix_html(self.comparison(2)))

    def test_score_fallbacks_and_empty_matrix(self) -> None:
        cmp_ = {"rankings": [{"solution": "a", "total_score": 7}, {"solution": "b"}],
                "rows": [{"type": "feature", "name": "F", "solutions": {}}], "caveats": "not a list"}
        out = lp.comparison_matrix_html(cmp_)
        self.assertIn('Score 7</div>', out)
        self.assertIn('Score —</div>', out)
        self.assertNotIn("Matrix caveats", out)
        for empty in ({}, {"rankings": [{"solution": "a"}]}, {"rows": [{"type": "feature", "name": "F"}]}):
            self.assertIn("Comparison matrix not populated yet.", lp.comparison_matrix_html(empty))
        self.assertIn("Winner: <strong></strong>", lp.comparison_matrix_html({}))
        only_shown = lp.comparison_matrix_html({"caveats": ["landscape-report.html only"]})
        self.assertNotIn("Matrix caveats", only_shown)


class SyncPayloadTests(unittest.TestCase):
    def test_writes_each_canonical_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            written = lp.sync_canonical_payload_files(root, {"markdown": "# T", "chart_data": {"a": "é"}, "comparison": {"k": 1}})
            self.assertEqual(set(written), {"markdown", "chart_data", "comparison"})
            self.assertEqual((root / "landscape" / "landscape-report.md").read_text(encoding="utf-8"), "# T\n")
            self.assertEqual(json.loads((root / "landscape" / "chart-data.json").read_text(encoding="utf-8")), {"a": "é"})
            self.assertIn("é", (root / "landscape" / "chart-data.json").read_text(encoding="utf-8"))
            self.assertEqual(json.loads((root / "comparison" / "comparison.json").read_text(encoding="utf-8")), {"k": 1})
            lp.sync_canonical_payload_files(root, {"markdown": "keeps newline\n"})
            self.assertEqual((root / "landscape" / "landscape-report.md").read_text(encoding="utf-8"), "keeps newline\n")

    def test_ignores_blank_or_wrongly_typed_fields_and_empty_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(lp.sync_canonical_payload_files(root, {"markdown": "  ", "chart_data": {}, "comparison": []}), {})
            self.assertEqual(lp.sync_canonical_payload_files(root, {"markdown": 5, "chart_data": [1], "comparison": "x"}), {})
            self.assertEqual(lp.sync_canonical_payload_files(root), {})  # no payload and no SPA page on disk
            self.assertFalse((root / "landscape").exists())

    def test_falls_back_to_the_embedded_spa_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            blob = json.dumps({"markdown": "# From SPA"})
            (root / "landscape-report.html").write_text(f'<script id="report-data" type="application/json">{blob}</script>', encoding="utf-8")
            written = lp.sync_canonical_payload_files(root)
            self.assertEqual(set(written), {"markdown"})
            self.assertEqual((root / "landscape" / "landscape-report.md").read_text(encoding="utf-8"), "# From SPA\n")
            # an empty-dict payload also falls back to the page
            self.assertEqual(set(lp.sync_canonical_payload_files(root, {})), {"markdown"})


class DivergenceTests(unittest.TestCase):
    def test_bullets_from_markdown(self) -> None:
        md = (
            "## A\ntext\n**Notable divergences** (inter-model)\n\n- `a` said X\n\n- `b` said Y\nstray line\n- `c` said Z\n"
            "**Another bold block**\n- not included\n## Next\n- also not\n"
        )
        self.assertEqual(lp.notable_divergence_bullets(md), ["`a` said X", "`b` said Y", "`c` said Z"])
        stop_at_heading = "**Notable divergences**\n\n- one\n## H\n- two\n"
        self.assertEqual(lp.notable_divergence_bullets(stop_at_heading), ["one"])
        nested_header = "**Notable divergences**\n\n**Notable divergences** again\n- x\n"
        self.assertEqual(lp.notable_divergence_bullets(nested_header), ["x"])

    def test_falls_back_to_consolidation(self) -> None:
        consolidation = {"divergence": [
            "junk",
            {"text": "", "claim_key": ""},
            {"claim_key": "key-only claim", "supporting_agents": ["agent-a", "", "agent-a", "agent-b"], "model_families": "fam-x", "agents": ["agent-c"]},
            {"text": "Plain text with ocg-minimax-m3 and claude-opus mention", "model_families": ["  "]},
            {"text": "nothing attributable"},
            {"text": "many", "supporting_agents": [f"a{i}" for i in range(12)]},
            {"text": "dup string", "model_families": "agent-a", "agents": " agent-a "},
            {"text": "mentions ocg-dup-model again", "supporting_agents": ["ocg-dup-model"]},
        ]}
        out = lp.notable_divergence_bullets("no divergence block here", consolidation)
        self.assertEqual(out[0], "`agent-a`, `agent-b`, `fam-x`, `agent-c` — key-only claim")
        self.assertEqual(out[1], "`ocg-minimax-m3`, `claude-opus` — Plain text with ocg-minimax-m3 and claude-opus mention")
        self.assertEqual(out[2], "nothing attributable")
        self.assertEqual(out[3].count("`"), 16)  # capped at eight ids
        self.assertEqual(out[4], "`agent-a` — dup string")
        self.assertEqual(out[5], "`ocg-dup-model` — mentions ocg-dup-model again")
        self.assertEqual(len(out), 6)
        # a heading with no bullets after it also falls back
        self.assertEqual(lp.notable_divergence_bullets("**Notable divergences**\n\nno bullets\n", {"divergence": [{"text": "t"}]}), ["t"])
        self.assertEqual(lp.notable_divergence_bullets("", None), [])
        self.assertEqual(lp.notable_divergence_bullets("", {"divergence": None}), [])

    def test_divergences_html(self) -> None:
        with_bullets = lp.divergences_html({}, {}, "**Notable divergences**\n\n- `a` said **X**\n")
        self.assertIn("<ul>", with_bullets)
        self.assertIn("<li><code>a</code> said <strong>X</strong></li>", with_bullets)
        empty = lp.divergences_html({}, {}, "", None)
        self.assertIn("No inter-model research disagreements were extracted", empty)
        self.assertNotIn("<ul>", empty)
        self.assertTrue(empty.startswith('<section class="divergences">'))


class PrintHtmlTests(unittest.TestCase):
    def test_plain_text_and_injection(self) -> None:
        self.assertEqual(lp._plain_html_text("<b>a</b> <i>b</i>"), "a b")
        self.assertEqual(lp._plain_html_text(None), "")  # type: ignore[arg-type]
        body = "<h2>One</h2><p>x</p><h2>Two</h2><h2>Two again</h2>"
        out, placed = lp._inject_after_matching_h2(body, lambda t: t.startswith("Two"), "[INJECT]")
        self.assertTrue(placed)
        self.assertEqual(out.count("[INJECT]"), 1)  # only the first match receives it
        self.assertLess(out.index("Two</h2>"), out.index("[INJECT]"))
        out2, placed2 = lp._inject_after_matching_h2(body, lambda t: False, "[INJECT]")
        self.assertFalse(placed2)
        self.assertEqual(out2, body)

    def make_root(self, root: Path, markdown: str, chart=None, comparison=None) -> None:
        (root / "landscape").mkdir(parents=True, exist_ok=True)
        (root / "comparison").mkdir(parents=True, exist_ok=True)
        (root / "landscape" / "landscape-report.md").write_text(markdown, encoding="utf-8")
        (root / "landscape" / "chart-data.json").write_text(json.dumps(chart or {}), encoding="utf-8")
        (root / "comparison" / "comparison.json").write_text(json.dumps(comparison or {}), encoding="utf-8")

    CHART = {"primary_market_id": "apo", "markets": {"apo": {"mq_data": sample_points(2), "gmq_data": sample_points(2)}}}
    CMP = {"winner": "a", "runner_up": "b", "rankings": [{"solution": "a", "score": 3}],
           "rows": [{"type": "feature", "name": "Gate feature", "solutions": {"a": "yes"}}]}

    def test_build_with_positioning_heading_and_title(self) -> None:
        md = "# My Report\n\n## 1. Intro\ntext\n\n## 3. Competitive positioning\nmore\n\n## 4. Rest\nend\n"
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_root(root, md, self.CHART, self.CMP)
            html_out = lp.build_independent_print_html(root)
        self.assertIn("<title>My Report</title>", html_out)
        self.assertIn("<h1>My Report</h1>", html_out)
        self.assertEqual(html_out.count("<h1>"), 1)  # the markdown H1 was lifted into the masthead
        self.assertIn(lp.INDEPENDENT_PDF_MARKER, html_out)
        self.assertIn(f'id="{lp.PRINT_ROOT_ID}"', html_out)
        self.assertLess(html_out.index("Competitive positioning"), html_out.index('class="market-charts"'))
        self.assertLess(html_out.index('class="market-charts"'), html_out.index("4. Rest"))
        self.assertIn("Gate feature", html_out)
        self.assertGreater(html_out.index("Comparison matrix"), html_out.index("4. Rest"))
        lp.assert_print_html_independent(html_out)

    def test_build_appends_charts_when_no_positioning_heading_and_defaults_title(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_root(root, "## Only\nbody\n", self.CHART, self.CMP)
            html_out = lp.build_independent_print_html(root)
        self.assertIn("<title>Landscape report</title>", html_out)
        self.assertGreater(html_out.index('class="market-charts"'), html_out.index("Only"))
        self.assertLess(html_out.index('class="market-charts"'), html_out.index("Comparison matrix"))

    def test_build_tolerates_non_dict_sources(self) -> None:
        bad = {"markdown": None, "chart_data": [1], "comparison": "x"}
        with mock.patch.object(lp, "load_canonical_landscape_sources", return_value=bad):
            html_out = lp.build_independent_print_html(Path("."))
        self.assertIn("Comparison matrix not populated yet.", html_out)
        self.assertIn("<title>Landscape report</title>", html_out)

    def test_assert_print_html_independent_failures(self) -> None:
        good = (f"<!-- {lp.INDEPENDENT_PDF_MARKER} --><body id=\"{lp.PRINT_ROOT_ID}\"><svg><circle class=\"fig-pt\"/></svg></body>")
        lp.assert_print_html_independent(good)
        cases = [
            ("<body></body>", "missing independent PDF marker"),
            (f"<!-- {lp.INDEPENDENT_PDF_MARKER} -->", "missing independent root id"),
            (f"<!-- {lp.INDEPENDENT_PDF_MARKER} --><body id=\"{lp.PRINT_ROOT_ID}\"></body>", "missing vector chart figures"),
            (f"<!-- {lp.INDEPENDENT_PDF_MARKER} --><body id=\"{lp.PRINT_ROOT_ID}\"><svg class=\"fig-pt\"></svg>Renderer: x</body>", "renderer attribution"),
            (good + f" visible {lp.INDEPENDENT_PDF_MARKER}", "marker leaked"),
            (good.replace("</body>", "exportBar</body>"), "SPA chrome: exportBar"),
        ]
        for html_in, needle in cases:
            with self.subTest(needle=needle):
                with self.assertRaisesRegex(RuntimeError, needle):
                    lp.assert_print_html_independent(html_in)
                # fix the third case's svg tag form: <svg + class="fig-pt" both required
        self.assertEqual(len(cases), 6)


class WritePdfTests(unittest.TestCase):
    def setUp(self) -> None:
        saved = lp._FONT_CSS_CACHE
        lp._FONT_CSS_CACHE = ""
        self.addCleanup(setattr, lp, "_FONT_CSS_CACHE", saved)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "landscape").mkdir()
        (self.root / "comparison").mkdir()
        (self.root / "landscape" / "landscape-report.md").write_text("# Rep\n\n## Alpha Heading\nbody text\n## R&D Heading\nmore\n", encoding="utf-8")
        (self.root / "landscape" / "chart-data.json").write_text(json.dumps(PrintHtmlTests.CHART), encoding="utf-8")
        (self.root / "comparison" / "comparison.json").write_text(json.dumps(PrintHtmlTests.CMP), encoding="utf-8")

    def fake_run(self, content: bytes = b"%PDF-1.4 fake", write: bool = True):
        calls = []

        def run(cmd, check=False):
            calls.append((cmd, check))
            if write:
                Path(cmd[-1]).write_bytes(content)
            return mock.Mock(returncode=0)

        return run, calls

    def test_writes_pdf_through_playwright(self) -> None:
        run, calls = self.fake_run()
        with mock.patch.object(lp.shutil, "which", side_effect=lambda n: "/x/playwright" if n == "playwright" else None), \
                mock.patch.object(lp.subprocess, "run", run):
            info = lp.write_independent_landscape_pdf(self.root, timeout_ms=555)
        pdf = (self.root / "landscape-report.pdf").resolve()
        self.assertEqual(info["status"], "ok")
        self.assertEqual(info["pdf"], str(pdf))
        self.assertEqual(info["bytes"], len(b"%PDF-1.4 fake"))
        self.assertEqual(info["engine"], lp.INDEPENDENT_PDF_MARKER)
        self.assertEqual(info["print_selector"], f"#{lp.PRINT_ROOT_ID}")
        cmd, check = calls[0]
        self.assertTrue(check)
        self.assertEqual(cmd[:3], ["/x/playwright", "pdf", "--paper-format"])
        self.assertIn("555", cmd)
        self.assertEqual(cmd[-1], str(pdf))
        self.assertTrue(cmd[-2].startswith("file://") and cmd[-2].endswith("landscape-report.print.html"))
        printed = (self.root / "landscape-report.print.html").read_text(encoding="utf-8")
        self.assertIn(lp.INDEPENDENT_PDF_MARKER, printed)

    def test_custom_output_paths(self) -> None:
        run, calls = self.fake_run()
        out_pdf = self.root / "sub" / "x.pdf"
        out_pdf.parent.mkdir()
        printed = self.root / "sub" / "p.html"
        with mock.patch.object(lp.shutil, "which", return_value="/x/playwright"), mock.patch.object(lp.subprocess, "run", run):
            info = lp.write_independent_landscape_pdf(self.root, out_pdf, print_html_path=printed)
        self.assertEqual(info["pdf"], str(out_pdf.resolve()))
        self.assertTrue(printed.is_file())

    def expect_error(self, pattern: str, *, content: bytes = b"%PDF-1.4 fake", write: bool = True, patch_html=None) -> None:
        run, _ = self.fake_run(content, write)
        ctx = mock.patch.object(lp, "build_independent_print_html", return_value=patch_html) if patch_html is not None else mock.patch.object(lp, "_FONT_CSS_CACHE", "")
        with ctx, mock.patch.object(lp.shutil, "which", return_value="/x/playwright"), mock.patch.object(lp.subprocess, "run", run):
            with self.assertRaisesRegex(RuntimeError, pattern):
                lp.write_independent_landscape_pdf(self.root)

    def valid_html(self, extra: str = "") -> str:
        return (f'<!-- {lp.INDEPENDENT_PDF_MARKER} --><body id="{lp.PRINT_ROOT_ID}"><svg><circle class="fig-pt"/></svg>'
                f"Alpha Heading R&amp;D Heading Gate feature{extra}</body>")

    def test_rejections(self) -> None:
        self.expect_error("dropped SPA heading: Alpha Heading", patch_html=self.valid_html().replace("Alpha Heading", ""))
        self.expect_error("dropped comparison feature: Gate feature", patch_html=self.valid_html().replace("Gate feature", ""))
        self.expect_error("still uses highlights-only comparison", patch_html=self.valid_html(" Comparison matrix highlights"))
        self.expect_error("did not write independent PDF", write=False, patch_html=self.valid_html())
        self.expect_error("did not write independent PDF", content=b"%PD", patch_html=self.valid_html())
        self.expect_error("is not a PDF file", content=b"NOTAPDF-bytes", patch_html=self.valid_html())
        self.expect_error("contains SPA chrome bytes", content=b"%PDF-1.4 pdfExportBtn", patch_html=self.valid_html())
        self.expect_error("contains SPA chrome bytes", content=b"%PDF-1.4 exportBar", patch_html=self.valid_html())

    def test_escaped_heading_is_accepted(self) -> None:
        run, _ = self.fake_run()
        html_ok = self.valid_html()
        self.assertIn("R&amp;D Heading", html_ok)
        self.assertNotIn("R&D Heading", html_ok)
        with mock.patch.object(lp, "build_independent_print_html", return_value=html_ok), \
                mock.patch.object(lp.shutil, "which", return_value="/x/playwright"), mock.patch.object(lp.subprocess, "run", run):
            self.assertEqual(lp.write_independent_landscape_pdf(self.root)["status"], "ok")

    def test_main(self) -> None:
        run, _ = self.fake_run()
        import contextlib
        import io

        buf = io.StringIO()
        with mock.patch.object(lp.shutil, "which", return_value="/x/playwright"), mock.patch.object(lp.subprocess, "run", run), \
                contextlib.redirect_stdout(buf):
            rc = lp.main(["--dir", str(self.root)])
            rc2 = lp.main(["--dir", str(self.root), "--out", str(self.root / "other.pdf")])
        self.assertEqual((rc, rc2), (0, 0))
        lines = buf.getvalue().strip().splitlines()
        self.assertEqual(json.loads(lines[0])["pdf"], str((self.root / "landscape-report.pdf").resolve()))
        self.assertEqual(json.loads(lines[1])["pdf"], str((self.root / "other.pdf").resolve()))

    def test_script_entrypoint(self) -> None:
        import runpy

        run, _ = self.fake_run()
        with mock.patch.object(lp.shutil, "which", return_value="/x/playwright"), mock.patch.object(lp.subprocess, "run", run), \
                mock.patch.object(sys, "argv", ["landscape_independent_pdf.py", "--dir", str(self.root)]):
            import contextlib
            import io

            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(SCRIPTS / "landscape_independent_pdf.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)


if __name__ == "__main__":
    unittest.main()

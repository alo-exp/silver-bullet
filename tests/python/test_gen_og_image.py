"""Unit tests for site/gen_og_image.py with Pillow replaced by recording fakes.

No image library, font file or network is used: the fakes record every drawing
call, so the tests check geometry, colours and call order instead of pixels.
"""
from __future__ import annotations

import contextlib
import io
import math
import runpy
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module


class FakePixels:
    def __init__(self, store):
        self.store = store

    def __setitem__(self, key, value):
        self.store[key] = value


ALL_IMAGES: list = []
ALL_DRAWS: list = []


class FakeImage:
    """Stands in for PIL.Image.Image; keeps pixel writes only for small images."""

    def __init__(self, mode, size, color=None, path=None):
        ALL_IMAGES.append(self)
        self.mode = mode
        self.size = size
        self.width, self.height = size
        self.color = color
        self.path = path
        self.px = {}
        self.ops = []
        self.saved = None

    def load(self):
        if self.width * self.height <= 20000:
            return FakePixels(self.px)
        return FakePixels({})

    def convert(self, mode):
        out = FakeImage(mode, self.size)
        out.ops.append(("convert-from", self.mode))
        return out

    def resize(self, size, resample=None):
        out = FakeImage(self.mode, size)
        out.ops.append(("resize", size, resample))
        return out

    def filter(self, flt):
        out = FakeImage(self.mode, self.size)
        out.ops.append(("filter", flt))
        return out

    def alpha_composite(self, other, dest=(0, 0)):
        self.ops.append(("alpha_composite", other, dest))

    def putalpha(self, mask):
        self.ops.append(("putalpha", mask))

    def paste(self, other, box, mask=None):
        self.ops.append(("paste", other, box, mask))

    def save(self, path, fmt, optimize=False):
        self.saved = (path, fmt, optimize)


class FakeDraw:
    def __init__(self, image):
        self.image = image
        self.calls = []

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.calls.append(("ellipse", box, fill, outline, width))

    def line(self, points, fill=None, width=1, joint=None):
        self.calls.append(("line", points, fill, width, joint))

    def text(self, xy, text, font=None, fill=None):
        self.calls.append(("text", xy, text, font, fill))

    def textlength(self, text, font=None):
        return 10.0 * len(text)

    def rounded_rectangle(self, box, radius=0, fill=None, outline=None, width=1):
        self.calls.append(("rounded_rectangle", box, radius, fill, outline, width))


class FakeFont:
    def __init__(self, path, size):
        self.path = path
        self.size = size

    def getbbox(self, text):
        return (3, 2, 3 + 10 * len(text), 2 + self.size)


def make_fake_pil():
    def new(mode, size, color=None):
        return FakeImage(mode, size, color)

    def open_(path):
        return FakeImage("RGB", (200, 100), path=path)

    image = types.ModuleType("PIL.Image")
    image.new = new
    image.open = open_
    image.Image = FakeImage
    image.LANCZOS = "LANCZOS-legacy"
    image.Resampling = types.SimpleNamespace(LANCZOS="LANCZOS")
    image.eval = lambda img, fn: ("eval", img, tuple(fn(v) for v in (10, 72, 73, 500)))

    draw = types.ModuleType("PIL.ImageDraw")

    def Draw(img):
        d = FakeDraw(img)
        ALL_DRAWS.append(d)
        return d

    draw.Draw = Draw
    draw.ImageDraw = FakeDraw

    flt = types.ModuleType("PIL.ImageFilter")
    flt.GaussianBlur = lambda radius: ("blur", radius)

    font = types.ModuleType("PIL.ImageFont")
    font.truetype = lambda path, size: FakeFont(path, size)
    font.FreeTypeFont = FakeFont

    pil = types.ModuleType("PIL")
    pil.Image, pil.ImageDraw, pil.ImageFilter, pil.ImageFont = image, draw, flt, font
    mods = {"PIL": pil, "PIL.Image": image, "PIL.ImageDraw": draw, "PIL.ImageFilter": flt, "PIL.ImageFont": font}
    return mods


FAKE_MODS = make_fake_pil()
with mock.patch.dict(sys.modules, FAKE_MODS):
    g = load_module("site/gen_og_image.py")


class ColorHelpers(unittest.TestCase):
    def test_parse_hex_with_and_without_hash_and_whitespace(self):
        self.assertEqual(g._parse_hex("#00c834"), (0, 200, 52))
        self.assertEqual(g._parse_hex("  ffffff "), (255, 255, 255))

    def test_parse_rgba(self):
        self.assertEqual(g._parse_rgba("rgba(0, 200, 52, .18)"), (0, 200, 52, 0.18))

    def test_alpha255_rounds_and_clamps(self):
        self.assertEqual(g._alpha255(0.0), 0)
        self.assertEqual(g._alpha255(1.0), 255)
        self.assertEqual(g._alpha255(0.045), 11)
        self.assertEqual(g._alpha255(-3), 0)
        self.assertEqual(g._alpha255(9), 255)

    def test_lerp_color_truncates_per_channel(self):
        self.assertEqual(g.lerp_color((0, 0, 0), (255, 100, 10), 0.5), (127, 50, 5))
        self.assertEqual(g.lerp_color((10, 20, 30), (10, 20, 30), 0.7), (10, 20, 30))
        self.assertEqual(g.lerp_color((0, 0, 0), (200, 200, 200), 1.0), (200, 200, 200))

    def test_sample_stops_interpolates_inside_a_segment(self):
        stops = [(0.0, (0, 0, 0)), (0.5, (100, 100, 100)), (1.0, (200, 0, 0))]
        self.assertEqual(g.sample_stops(stops, 0.25), (50, 50, 50))
        self.assertEqual(g.sample_stops(stops, 0.75), (150, 50, 50))
        self.assertEqual(g.sample_stops(stops, 0.0), (0, 0, 0))

    def test_sample_stops_outside_the_range_returns_the_last_colour(self):
        stops = [(0.2, (1, 1, 1)), (0.4, (9, 9, 9))]
        self.assertEqual(g.sample_stops(stops, 0.9), (9, 9, 9))
        self.assertEqual(g.sample_stops(stops, 0.1), (9, 9, 9))

    def test_sample_stops_zero_width_segment_does_not_divide_by_zero(self):
        stops = [(0.5, (10, 10, 10)), (0.5, (20, 20, 20))]
        self.assertEqual(g.sample_stops(stops, 0.5), (10, 10, 10))


class TokenLoading(unittest.TestCase):
    CSS = (
        ":root{--accent:#00c834;--accent-light:#009a28;--dim : rgba(1,2,3,.5) ;}\n"
        '[data-theme="dark"]{--accent:#112233;--only-dark:#abcdef;}\n'
    )

    def css_file(self, text):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        p = Path(tmp.name) / "tokens.css"
        p.write_text(text, encoding="utf-8")
        return p

    def test_light_theme_stops_before_the_dark_block(self):
        tokens = g.load_theme_tokens(self.css_file(self.CSS), "light")
        self.assertEqual(tokens["accent"], "#00c834")
        self.assertEqual(tokens["dim"], "rgba(1,2,3,.5)")
        self.assertNotIn("only-dark", tokens)

    def test_dark_theme_reads_the_dark_block(self):
        tokens = g.load_theme_tokens(self.css_file(self.CSS), "dark")
        self.assertEqual(tokens, {"accent": "#112233", "only-dark": "#abcdef"})

    def test_light_theme_without_a_dark_block_reads_everything(self):
        tokens = g.load_theme_tokens(self.css_file(":root{--a:#010203;--b:#040506;}"), "light")
        self.assertEqual(tokens, {"a": "#010203", "b": "#040506"})

    def test_dark_theme_without_a_dark_block_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "Dark theme block not found"):
            g.load_theme_tokens(self.css_file(":root{--a:#010203;}"), "dark")

    def test_token_rgb_and_rgba_lookup(self):
        self.assertEqual(g._token_rgb({"x": "#0a0b0c"}, "x"), (10, 11, 12))
        self.assertEqual(g._token_rgba({"x": "rgba(1,2,3,.25)"}, "x"), (1, 2, 3, 0.25))

    def test_token_rgb_rejects_non_hex_values(self):
        with self.assertRaisesRegex(ValueError, r"Token --x is not a hex color: 'rgba\(1,2,3,1\)'"):
            g._token_rgb({"x": "rgba(1,2,3,1)"}, "x")

    def test_module_constants_come_from_the_real_tokens_file(self):
        light = g.load_theme_tokens(REPO_ROOT / "site" / "tokens.css", "light")
        self.assertEqual(g.ACCENT, g._parse_hex(light["accent"]))
        self.assertEqual(g.HERO_GREEN, g.ACCENT_LIGHT)
        self.assertEqual(g.GRID_ALPHA, 13)
        self.assertEqual(g.MINT_FILL[:3], g._parse_rgba(light["mint-a14"])[:3])


class Gradients(unittest.TestCase):
    def test_gradient_h_fills_80_rows_per_column_from_the_stops(self):
        stops = [(0.0, (0, 0, 0)), (1.0, (200, 100, 50))]
        img = g.gradient_h(5, stops)
        self.assertEqual(img.size, (5, 80))
        self.assertEqual(len(img.px), 5 * 80)
        self.assertEqual(img.px[(0, 0)], (0, 0, 0))
        self.assertEqual(img.px[(4, 79)], (200, 100, 50))
        self.assertEqual(img.px[(2, 10)], (100, 50, 25))
        self.assertEqual(img.px[(2, 10)], img.px[(2, 70)])

    def test_gradient_h_single_pixel_width_uses_t_zero(self):
        img = g.gradient_h(1, [(0.0, (7, 8, 9)), (1.0, (1, 1, 1))])
        self.assertEqual(img.px[(0, 0)], (7, 8, 9))

    def test_gradient_bg_runs_along_the_160_degree_axis(self):
        img = g.gradient_bg(10, 6)
        self.assertEqual(img.size, (10, 6))
        self.assertEqual(len(img.px), 60)
        self.assertEqual(img.px[(0, 0)], g.BG_STOPS[0][1])
        cos_a, sin_a = math.cos(math.radians(160)), math.sin(math.radians(160))
        diag = 10 * cos_a + 6 * sin_a
        for x, y in ((9, 5), (4, 3), (0, 5)):
            expected = g.sample_stops(g.BG_STOPS, (x * cos_a + y * sin_a) / diag)
            self.assertEqual(img.px[(x, y)], expected, (x, y))
        self.assertNotEqual(img.px[(0, 0)], img.px[(9, 5)])


class Drawing(unittest.TestCase):
    def canvas(self, size=(1200, 630)):
        return FakeImage("RGBA", size)

    def test_add_glow_draws_shrinking_ellipses_then_blurs_and_composites(self):
        canvas = self.canvas()
        before = len(ALL_DRAWS)
        g.add_glow(canvas, 100, 50, 20, (1, 2, 3), 0.5)
        draw = ALL_DRAWS[before]
        ellipses = [c for c in draw.calls if c[0] == "ellipse"]
        self.assertEqual([c[1] for c in ellipses], [(80, 30, 120, 70), (88, 38, 112, 62), (96, 46, 104, 54)])
        # radius 20, 12, 4 -> alpha = 255 * 0.5 * (1 - r/20) ** 2
        self.assertEqual([c[2][3] for c in ellipses], [0, int(255 * 0.5 * (0.4**2)), int(255 * 0.5 * (0.8**2))])
        self.assertEqual(ellipses[0][2][:3], (1, 2, 3))
        (_, glow, dest), = [op for op in canvas.ops if op[0] == "alpha_composite"]
        self.assertEqual(glow.ops, [("filter", ("blur", 5))])
        self.assertEqual(dest, (0, 0))

    def test_add_grid_draws_a_subtle_line_every_44_pixels(self):
        canvas = self.canvas()
        before = len(ALL_DRAWS)
        g.add_grid(canvas)
        lines = [c for c in ALL_DRAWS[before].calls if c[0] == "line"]
        vertical = [c for c in lines if c[1][0] == c[1][2]]
        horizontal = [c for c in lines if c[1][1] == c[1][3]]
        self.assertEqual(len(vertical), len(range(0, g.W, 44)))
        self.assertEqual(len(horizontal), len(range(0, g.H, 44)))
        self.assertEqual(vertical[1][1], (44, 0, 44, g.H))
        self.assertEqual(horizontal[1][1], (0, 44, g.W, 44))
        self.assertTrue(all(c[2] == (*g.ACCENT, 11) and c[3] == 1 for c in lines))
        self.assertEqual(len([op for op in canvas.ops if op[0] == "alpha_composite"]), 1)

    def test_draw_gradient_text_masks_the_gradient_with_the_text_shape(self):
        canvas = self.canvas()
        font = FakeFont("f", 20)
        grad = FakeImage("RGB", (620, 80))
        before = len(ALL_DRAWS)
        g.draw_gradient_text(canvas, (174, 73), "abc", font, grad)
        # bbox = (3, 2, 33, 22) -> text box 30 x 20, padded by 4
        mask_draw = ALL_DRAWS[before]
        self.assertEqual(mask_draw.image.size, (34, 24))
        self.assertEqual(mask_draw.image.mode, "L")
        self.assertEqual(mask_draw.calls, [("text", (-1, 0), "abc", font, 255)])
        (_, crop, box, mask), = [op for op in canvas.ops if op[0] == "paste"]
        self.assertEqual(crop.size, (34, 24))
        self.assertEqual(crop.ops[0], ("resize", (34, 24), "LANCZOS-legacy"))
        self.assertEqual(crop.ops[1], ("putalpha", mask_draw.image))
        self.assertEqual(box, (174, 73))
        self.assertIs(mask, crop)

    def test_draw_tracking_text_spreads_characters_to_the_target_width(self):
        draw = FakeDraw(None)
        font = FakeFont("f", 10)
        g.draw_tracking_text(draw, (5, 7), "ABC", font, (1, 2, 3), 60)
        # natural width 30, 2 gaps -> tracking 15; each char is 10 wide
        self.assertEqual([(c[1], c[2]) for c in draw.calls], [((5.0, 7), "A"), ((30.0, 7), "B"), ((55.0, 7), "C")])
        self.assertTrue(all(c[4] == (1, 2, 3) for c in draw.calls))

    def test_draw_tracking_text_never_uses_negative_tracking(self):
        draw = FakeDraw(None)
        g.draw_tracking_text(draw, (0, 0), "ABC", FakeFont("f", 10), (0, 0, 0), 10)
        self.assertEqual([c[1][0] for c in draw.calls], [0.0, 10.0, 20.0])

    def test_draw_tracking_text_single_character(self):
        draw = FakeDraw(None)
        g.draw_tracking_text(draw, (3, 4), "X", FakeFont("f", 10), (0, 0, 0), 100)
        self.assertEqual([(c[1], c[2]) for c in draw.calls], [((3.0, 4), "X")])

    def test_rounded_rect_forwards_every_argument(self):
        draw = FakeDraw(None)
        g.rounded_rect(draw, (1, 2, 3, 4), 5, (6, 7, 8), (9, 9, 9), 2)
        g.rounded_rect(draw, (1, 2, 3, 4), 5, (6, 7, 8))
        self.assertEqual(draw.calls, [
            ("rounded_rectangle", (1, 2, 3, 4), 5, (6, 7, 8), (9, 9, 9), 2),
            ("rounded_rectangle", (1, 2, 3, 4), 5, (6, 7, 8), None, 1),
        ])

    def test_glow_line_composites_a_blurred_copy_then_the_sharp_line(self):
        canvas = self.canvas()
        before = len(ALL_DRAWS)
        g.glow_line(canvas, [(0, 0), (10, 10)], (1, 2, 3))
        self.assertEqual(ALL_DRAWS[before].calls, [("line", [(0, 0), (10, 10)], (1, 2, 3, 170), 3, "curve")])
        composites = [op for op in canvas.ops if op[0] == "alpha_composite"]
        self.assertEqual(len(composites), 2)
        self.assertEqual(composites[0][1].ops, [("filter", ("blur", 7))])
        self.assertEqual(composites[1][1].ops, [])
        before = len(ALL_DRAWS)
        g.glow_line(canvas, [(0, 0)], (1, 2, 3), width=9, alpha=5)
        self.assertEqual(ALL_DRAWS[before].calls[0][2:4], ((1, 2, 3, 5), 9))

    def test_check_icon_draws_a_ring_and_tick_then_downsamples(self):
        before = len(ALL_DRAWS)
        icon = g.check_icon()
        calls = ALL_DRAWS[before].calls
        self.assertEqual(calls[0], ("ellipse", (12, 12, 76, 76), None, (*g.HERO_GREEN, 255), 8))
        self.assertEqual(calls[1][0], "line")
        self.assertEqual(calls[1][3:], (8, "curve"))
        self.assertEqual(calls[1][1][0], (22 * 0.30 * 4, 22 * 0.52 * 4))
        self.assertEqual(icon.size, (22, 22))
        self.assertEqual(icon.ops, [("resize", (22, 22), "LANCZOS")])

    def test_check_icon_scales_stroke_with_size_but_keeps_a_minimum(self):
        before = len(ALL_DRAWS)
        g.check_icon(size=10, scale=2)
        # stroke = max(2, round(0.95)) * 2 = 4 ; pad = round(1.3) * 2 = 2 ; canvas 20
        self.assertEqual(ALL_DRAWS[before].calls[0][1:], ((2, 2, 18, 18), None, (*g.HERO_GREEN, 255), 4))

    def test_draw_feature_places_the_icon_and_the_label(self):
        canvas = self.canvas()
        draw = FakeDraw(canvas)
        font = FakeFont("f", 22)
        g.draw_feature(draw, canvas, (732, 196), "Quality Gates", font)
        (_, icon, dest), = [op for op in canvas.ops if op[0] == "alpha_composite"]
        self.assertEqual(icon.size, (22, 22))
        self.assertEqual(dest, (732, 199))
        self.assertEqual(draw.calls, [("text", (760, 196), "Quality Gates", font, g.TEXT_SECONDARY)])


class MainRender(unittest.TestCase):
    def run_main(self):
        out = io.StringIO()
        n_images, n_draws = len(ALL_IMAGES), len(ALL_DRAWS)
        with mock.patch.object(g, "W", 40), mock.patch.object(g, "H", 20), contextlib.redirect_stdout(out):
            g.main()
        return out.getvalue(), ALL_IMAGES[n_images:], ALL_DRAWS[n_draws:]

    def test_main_composes_the_card_and_saves_a_png(self):
        text, images, draws = self.run_main()
        final = next(i for i in images if i.saved)
        self.assertEqual(final.saved, (g.OUT, "PNG", True))
        self.assertEqual(final.mode, "RGB")
        self.assertIn(f"Saved {g.OUT} (40x20)", text)
        self.assertIn("Tokens: accent=#", text)
        self.assertIn("hero-green=#009a28", text)

        drawn = [c[2] for d in draws for c in d.calls if c[0] == "text"]
        for expected in ("Maximize AI-driven", "Dev Process Reliability", "29 Atomic Flows · 26 Workflows",
                         "Enforce the Method Back to the AI Madness!", "AGENTIC PROCESS ORCHESTRATOR",
                         "Engineering Best Practices", "Knowledge Management"):
            self.assertIn(expected, drawn)
        self.assertEqual(sum(1 for t in drawn if t in {
            "Engineering Best Practices", "Dynamically Tailored Workflows", "Verification & Validation Loops",
            "Quality Gates", "Spec-to-Release Traceability", "Cost Optimization", "Intent-Aligned Results",
            "Knowledge Management"}), 8)

    def test_main_lays_out_feature_rows_42_pixels_apart(self):
        _, _, draws = self.run_main()
        feats = [c for d in draws for c in d.calls if c[0] == "text" and c[1][0] == 732 + 28]
        self.assertEqual([c[1][1] for c in feats], [196 + 42 * i for i in range(8)])

    def test_main_caps_the_logo_shadow_alpha_at_72(self):
        _, images, _ = self.run_main()
        evals = [op[1] for i in images for op in i.ops if op[0] == "alpha_composite" and isinstance(op[1], tuple)]
        self.assertEqual(len(evals), 1)
        # per-pixel alpha: values below the cap pass through, larger ones are clamped to 72
        self.assertEqual(evals[0][2], (10, 72, 72, 72))

    def test_main_loads_the_bullet_logo_scaled_to_104_pixels_high(self):
        _, images, _ = self.run_main()
        logo = next(i for i in images if i.path == g.BULLET)
        self.assertEqual(logo.mode, "RGB")
        resized = [i for i in images if i.ops and i.ops[0] == ("resize", (208, 104), "LANCZOS-legacy")]
        self.assertTrue(resized, "200x100 logo becomes 208x104")

    def test_main_uses_the_bold_and_regular_fonts_at_the_designed_sizes(self):
        _, _, draws = self.run_main()
        fonts = {(c[3].path, c[3].size) for d in draws for c in d.calls if c[0] == "text"}
        self.assertIn((str(g.FONT_BOLD), 56), fonts)
        self.assertIn((str(g.FONT_REG), 31), fonts)
        self.assertIn((str(g.FONT_REG), 22), fonts)

    def test_running_the_file_as_a_script_calls_main(self):
        out = io.StringIO()
        with mock.patch.dict(sys.modules, FAKE_MODS), contextlib.redirect_stdout(out):
            runpy.run_path(str(REPO_ROOT / "site" / "gen_og_image.py"), run_name="__main__")
        self.assertIn("Saved ", out.getvalue())
        self.assertIn("(1200x630)", out.getvalue())


if __name__ == "__main__":
    unittest.main()

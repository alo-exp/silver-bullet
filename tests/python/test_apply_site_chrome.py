"""Unit tests for scripts/apply-site-chrome.py (operates on a scratch site tree only)."""
from __future__ import annotations

import contextlib
import io
import re
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

a = load_module("scripts/apply-site-chrome.py")


class SiteCase(unittest.TestCase):
    """Patch SITE/REPO to a scratch tree that holds the real chrome templates."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name).resolve()
        self.site = self.repo / "site"
        (self.site / "help").mkdir(parents=True)
        for patch in (mock.patch.object(a, "SITE", self.site), mock.patch.object(a, "REPO", self.repo)):
            patch.start()
            self.addCleanup(patch.stop)

    def page(self, rel, text=""):
        p = self.site / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        return p


PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<title>t</title>
<link rel="stylesheet" href="tokens.css">
<style>
nav{position:fixed}
.page-nav{display:flex}
.sidebar-nav{list-style:none}
footer{padding:1px}
.hero{padding:96px 24px 40px}
</style>
</head>
<body>
<nav><a>old</a></nav>
<section class="hero"><div class="container"><h1>How Can We Help You?</h1><p>sub</p></div></section>
<footer><p>old</p></footer>
<script src="common.js"></script>
</body>
</html>
"""


class PathHelpersTest(SiteCase):
    def test_prefixes(self):
        self.assertEqual(a.root_prefix(self.site / "index.html"), "")
        self.assertEqual(a.root_prefix(self.site / "help" / "x" / "y.html"), "../../")
        self.assertEqual(a.help_prefix(self.site / "help" / "index.html"), "./")
        self.assertEqual(a.help_prefix(self.site / "help" / "x" / "y.html"), "../")

    def test_render_substitutes_root_and_extras(self):
        self.assertEqual(a.render("{{ROOT}}a {{X}} {{ROOT}}", "../", X="v"), "../a v ../")

    def test_slug_title(self):
        self.assertEqual(a.slug_title("silver-feature.html"), "/sb:feature")
        self.assertEqual(a.slug_title("concepts"), "Concepts")
        self.assertEqual(a.slug_title("some-page.html"), "Some Page")

    def test_link_to_section(self):
        inside = self.site / "help" / "concepts" / "a.html"
        self.assertEqual(a.link_to_section(inside, "concepts"), "./")
        self.assertEqual(a.link_to_section(inside, "reference"), "../reference/")
        self.assertEqual(a.link_to_section(self.site / "help" / "top.html", "concepts"), "./concepts/")

    def test_is_help_page(self):
        self.assertTrue(a.is_help_page(self.site / "help" / "index.html"))
        self.assertFalse(a.is_help_page(self.site / "index.html"))


class BreadcrumbTest(SiteCase):
    def crumb(self, rel):
        return a.build_breadcrumb(self.site / "help" / rel)

    def test_help_home(self):
        self.assertEqual(
            self.crumb("index.html"),
            '<a href="../">Home</a><span class="sep">/</span><span class="current">Help Center</span>',
        )

    def test_top_level_page(self):
        out = self.crumb("faq.html")
        self.assertIn('<a href="./">Help</a>', out)
        self.assertTrue(out.endswith('<span class="current">Faq</span>'))

    def test_section_index(self):
        out = self.crumb("concepts/index.html")
        self.assertTrue(out.endswith('<span class="current">Concepts</span>'))
        self.assertNotIn('href="./">Concepts', out)

    def test_section_leaf_page(self):
        out = self.crumb("workflows/silver-feature.html")
        self.assertIn('<a href="./">Workflows</a>', out)
        self.assertTrue(out.endswith('<span class="current">/sb:feature</span>'))

    def test_unknown_section_title_from_slug(self):
        out = self.crumb("my-section/page.html")
        self.assertIn(">My Section</a>", out)

    def test_nested_index_has_no_current_leaf(self):
        out = self.crumb("concepts/sub/index.html")
        self.assertTrue(out.endswith("Concepts</a>"))
        self.assertNotIn('class="current"', out)


class HelpSubnavTest(SiteCase):
    def test_section_links_active(self):
        out = a.help_section_links(self.site / "help" / "concepts" / "x.html")
        self.assertIn('<a href="../concepts/" class="active">Concepts</a>', out)
        self.assertEqual(out.count('class="active"'), 1)
        top = a.help_section_links(self.site / "help" / "index.html")
        self.assertNotIn("active", top)
        self.assertIn('<a href="./getting-started/">Start</a>', top)

    def test_search_markup(self):
        self.assertIn('id="nav-search-input"', a.help_search_markup())

    def test_build_help_subnav_fills_placeholders(self):
        out = a.build_help_subnav(self.site / "help" / "concepts" / "x.html")
        self.assertNotIn("{{", out)
        self.assertIn('id="help-subnav"', out)
        self.assertIn("nav-search-wrap", out)
        self.assertIn("help-subnav-links", out)
        self.assertIn('<span class="current">X</span>', out)


class HeadAssetsTest(SiteCase):
    def test_existing_chrome_link_is_rewritten(self):
        html = '<head><link rel="stylesheet" href="old/chrome.css?v=1"></head>'
        out = a.ensure_head_assets(html, "../")
        self.assertIn(f'href="../chrome.css?v={a.CHROME_VER}"', out)
        self.assertEqual(out.count("chrome.css"), 1)

    def test_inserted_after_tokens(self):
        html = '<head><link rel="stylesheet" href="tokens.css"></head>'
        out = a.ensure_head_assets(html, "")
        self.assertRegex(out, r'tokens\.css">\n<link rel="stylesheet" href="chrome\.css')

    def test_inserted_after_neutral_variants_when_no_tokens(self):
        html = '<head><link rel="stylesheet" href="neutral-variants.css"></head>'
        out = a.ensure_head_assets(html, "")
        self.assertRegex(out, r'neutral-variants\.css">\n<link rel="stylesheet" href="chrome\.css')

    def test_inserted_before_head_close_otherwise(self):
        out = a.ensure_head_assets("<head></head>", "")
        self.assertIn('  <link rel="stylesheet" href="chrome.css?v=', out)
        self.assertLess(out.index("chrome.css"), out.index("</head>"))

    def test_help_page_adds_neutral_link_after_tokens_and_variant_attr(self):
        html = '<html lang="en" class="x"><head><link rel="stylesheet" href="tokens.css"></head>'
        out = a.ensure_head_assets(html, "../", help_page=True)
        self.assertIn("neutral-variants.css?v=s3-home-icons", out)
        self.assertRegex(out, r'tokens\.css">\n<link rel="stylesheet" href="\.\./neutral-variants')
        self.assertIn('<html lang="en" class="x" data-neutral-variant="s3">', out)

    def test_help_page_adds_neutral_link_next_to_chrome_when_no_tokens(self):
        out = a.ensure_head_assets("<head></head>", "", help_page=True)
        self.assertRegex(out, r"chrome\.css\?v=[^\"]*\">\n<link rel=\"stylesheet\" href=\"neutral-variants")

    def test_help_page_keeps_existing_neutral_and_variant(self):
        html = ('<html lang="en" data-neutral-variant="s3"><head>'
                '<link rel="stylesheet" href="neutral-variants.css"></head>')
        out = a.ensure_head_assets(html, "", help_page=True)
        self.assertEqual(out.count("neutral-variants.css"), 1)
        self.assertEqual(out.count("data-neutral-variant"), 1)

    def test_non_help_page_gets_no_neutral(self):
        out = a.ensure_head_assets('<html lang="en"><head></head>', "")
        self.assertNotIn("neutral-variants", out)
        self.assertNotIn("data-neutral-variant", out)


class ThemeBootTest(unittest.TestCase):
    def test_old_boot_script_replaced(self):
        old = ("<head><script>document.documentElement.setAttribute('data-theme',"
               "localStorage.getItem('silver-bullet-theme')==='dark'?'dark':'light');</script></head>")
        out = a.normalize_theme_boot(old)
        self.assertEqual(out, f"<head>{a.THEME_BOOT}</head>")

    def test_current_boot_untouched(self):
        html = f"<head>{a.THEME_BOOT}</head>"
        self.assertEqual(a.normalize_theme_boot(html), html)

    def test_missing_boot_inserted_after_head_open(self):
        self.assertEqual(a.normalize_theme_boot("<head><x></head>"), f"<head>\n{a.THEME_BOOT}<x></head>")

    def test_missing_boot_without_head_is_noop(self):
        self.assertEqual(a.normalize_theme_boot("<p>x</p>"), "<p>x</p>")


class BodyScriptsTest(unittest.TestCase):
    def test_existing_script_rewritten(self):
        out = a.ensure_body_scripts('<body><script src="x/chrome.js?v=1"></script></body>', "../")
        self.assertEqual(out, f'<body><script src="../chrome.js?v={a.CHROME_VER}"></script></body>')

    def test_adds_lucide_and_chrome_when_missing(self):
        out = a.ensure_body_scripts("<body></body>", "")
        self.assertIn(a.LUCIDE, out)
        self.assertLess(out.index("lucide"), out.index("chrome.js"))

    def test_lucide_not_duplicated(self):
        out = a.ensure_body_scripts(f"<body>{a.LUCIDE}</body>", "")
        self.assertEqual(out.count("lucide.min.js"), 1)
        self.assertIn("chrome.js", out)


class CssStrippingTest(unittest.TestCase):
    def test_strip_chrome_css_removes_chrome_rules_only(self):
        css = "nav{a:b}.nav-logo{x:y}.page-nav{keep:1}footer{p:1}.sidebar-nav li a:hover{c:d}.other{k:v}"
        self.assertEqual(a.strip_chrome_css(css), ".page-nav{keep:1}.other{k:v}")

    def test_strip_chrome_css_media_rules(self):
        css = "@media(max-width:768px){.nav-search-wrap{display:none}}.keep{a:b}"
        self.assertEqual(a.strip_chrome_css(css), ".keep{a:b}")

    def test_strip_inline_nav_css_banner_blocks(self):
        css = "/* ───── NAV ───── */\nnav{x}\n/* ───── HERO ───── */\n.h{a:b}"
        out = a.strip_inline_nav_css(css)
        self.assertEqual(out, "/* NAV — chrome.css */\n/* ───── HERO ───── */\n.h{a:b}")
        css2 = "/* NAV */\nnav{x}\n/* HERO */\n.h{}"
        self.assertEqual(a.strip_inline_nav_css(css2), "/* NAV — chrome.css */\n/* HERO */\n.h{}")

    def test_strip_inline_nav_css_scattered_rules(self):
        css = ("nav .nav-links{a:b}\nnav .nav-cta:hover{c:d}\n.nav-toggle{e:f}\n"
               ".keep{k:v}")
        self.assertEqual(a.strip_inline_nav_css(css), ".keep{k:v}")

    def test_strip_inline_footer_css(self):
        css = ("/* ───── FOOTER ───── */\nfooter{x}\n/* ───── NEXT ───── */\n"
               "footer a{color:var(--text-secondary);text-decoration:none}\n"
               "footer a:hover{color:var(--accent-light)}\n"
               "footer .footer-copyright{a:b}\n"
               "@media(max-width:600px){.footer-inner{a:b}x{c:d}}\n"
               "@media(max-width:768px){footer .footer-inner{a:b}x{c:d}}\n"
               '[data-theme="light"]\n[data-theme="dark"] footer \n'
               ".keep{k:v}")
        out = a.strip_inline_footer_css(css)
        self.assertIn("/* FOOTER — chrome.css */", out)
        self.assertIn(".keep{k:v}", out)
        for gone in ("footer a", "footer-copyright", "footer-inner", "[data-theme"):
            self.assertNotIn(gone, out)

    def test_strip_inline_footer_css_lone_footer_line(self):
        self.assertEqual(a.strip_inline_footer_css("a\nfooter\nb"), "a\n\nb")
        css = "/* FOOTER */\nfooter{x}\n/* CALLOUT */\n.k{}"
        self.assertEqual(a.strip_inline_footer_css(css), "/* FOOTER — chrome.css */\n/* CALLOUT */\n.k{}")

    def test_collapse_style_whitespace(self):
        out = a.collapse_style_whitespace("<style>\n\n a{}\n\n\n b{}\n</style><style>\n\nc{}</style>")
        self.assertEqual(out, "<style>\n a{}\n b{}\n</style><style>\n\nc{}</style>")

    def test_repair_css_damage_restores_selectors(self):
        css = ".page-\n.breadcrumb-\n.sidebar-\n.breadcrumb-.breadcrumb-nav{a:b}.sidebar-.sidebar-nav{c:d}"
        out = a.repair_css_damage(css)
        self.assertIn(".page-nav{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:40px}", out)
        self.assertEqual(out.count(".breadcrumb-nav{font-size:.9rem"), 2)
        self.assertEqual(out.count(".sidebar-nav{list-style:none"), 2)
        self.assertNotIn(".page-\n", out)

    def test_repair_css_damage_removes_orphan_footer_fragments(self):
        css = ("footer a{color:var(--text-secondary);text-decoration:none}\n"
               "footer a:hover{color:var(--accent-light)}\n }\nX")
        self.assertEqual(a.repair_css_damage(css).strip(), "X")
        compact = ("footer a{color:var(--text-secondary);text-decoration:none}"
                   "footer a:hover{color:var(--accent-light)}\n }Y")
        self.assertEqual(a.repair_css_damage(compact), "Y")
        marker = "/* FOOTER */\nfooter a{c:d}\nfooter a:hover{e:f}\n}Z"
        self.assertEqual(a.repair_css_damage(marker), "/* FOOTER */Z")


class BlockEditsTest(unittest.TestCase):
    def test_remove_help_index_subtitle(self):
        html = '<section class="hero"><div class="container"><h1>How Can We Help You?</h1>\n<p>sub\ntext</p></div>'
        out = a.remove_help_index_subtitle(html)
        self.assertNotIn("sub", out)
        self.assertIn("<h1>How Can We Help You?</h1>", out)
        self.assertEqual(a.remove_help_index_subtitle("<p>x</p>"), "<p>x</p>")

    def test_replace_block(self):
        out = a.replace_block("a<nav class='x'>old</nav>b", "nav", "\n<nav>new</nav>\n")
        self.assertEqual(out, "a<nav>new</nav>b")
        out = a.replace_block("<NAV>old</NAV>", "nav", "<nav>n</nav>")
        self.assertEqual(out, "<nav>n</nav>")

    def test_replace_block_missing_raises(self):
        with self.assertRaisesRegex(ValueError, "missing <footer> block"):
            a.replace_block("<nav></nav>", "footer", "x")

    def test_find_div_block_end(self):
        html = "<div><div>x</div></div>tail"
        self.assertEqual(a._find_div_block_end(html, 0), len("<div><div>x</div></div>"))

    def test_find_div_block_end_unclosed(self):
        with self.assertRaisesRegex(ValueError, "unclosed help-subnav block"):
            a._find_div_block_end("<div><div></div>", 0)


class HelpSubnavInsertTest(unittest.TestCase):
    SUB = '<div class="help-subnav" id="help-subnav"><div class="help-subnav-inner">I</div></div>'

    def test_replaces_existing_block(self):
        html = f"<nav></nav>{self.SUB.replace('I', 'OLD')}<main></main>"
        out = a.replace_or_insert_help_subnav(html, "\n<NEW></NEW>\n")
        self.assertEqual(out, "<nav></nav><NEW></NEW><main></main>")

    def test_inserts_after_nav_when_absent(self):
        out = a.replace_or_insert_help_subnav("<nav></nav><main></main>", "<NEW/>")
        self.assertEqual(out, "<nav></nav>\n\n<NEW/><main></main>")

    def test_repair_close_noop_cases(self):
        self.assertEqual(a.repair_help_subnav_close("<p>x</p>"), "<p>x</p>")
        no_inner = '<div class="help-subnav" id="help-subnav"><p></p>'
        self.assertEqual(a.repair_help_subnav_close(no_inner), no_inner)
        closed = self.SUB + "\n<section>"
        self.assertEqual(a.repair_help_subnav_close(closed), closed)
        other = '<div class="help-subnav" id="help-subnav"><div class="help-subnav-inner">I</div>\n<main>'
        self.assertEqual(a.repair_help_subnav_close(other), other)

    def test_repair_close_inserts_missing_div(self):
        broken = ('<div class="help-subnav" id="help-subnav"><div class="help-subnav-inner">I</div>'
                  '\n<div class="page-hero">h</div>')
        out = a.repair_help_subnav_close(broken)
        self.assertEqual(
            out,
            '<div class="help-subnav" id="help-subnav"><div class="help-subnav-inner">I</div>'
            '\n</div>\n\n<div class="page-hero">h</div>',
        )
        hero = broken.replace('div class="page-hero"', 'section class="hero"')
        self.assertIn("\n</div>\n", a.repair_help_subnav_close(hero))


class MiscInsertsTest(SiteCase):
    def test_search_script_already_present(self):
        html = '<script src="search.js"></script>'
        self.assertEqual(a.ensure_help_search_script(html, self.site / "help" / "index.html"), html)

    def test_search_script_before_common_js(self):
        html = '<body><script src="../common.js?v=2"></script></body>'
        out = a.ensure_help_search_script(html, self.site / "help" / "x" / "y.html")
        self.assertEqual(
            out, '<body><script src="../search.js"></script>\n<script src="../common.js?v=2"></script></body>')

    def test_search_script_before_body_close_otherwise(self):
        out = a.ensure_help_search_script("<body></body>", self.site / "help" / "index.html")
        self.assertEqual(out, '<body><script src="./search.js"></script>\n</body>')

    def test_body_class(self):
        self.assertEqual(a.ensure_body_class('<body class="has-x">', "has-x"), '<body class="has-x">')
        self.assertEqual(a.ensure_body_class('<body class="a">', "zz"), '<body class="a zz">')
        self.assertEqual(a.ensure_body_class("<body>", "zz"), '<body class="zz">')
        self.assertEqual(a.ensure_body_class('<body id="i">', "zz"), '<body class="zz" id="i">')

    def test_layout_padding_noop_without_marker(self):
        css = ".hero{padding:96px 24px 40px}"
        self.assertEqual(a.adjust_help_layout_padding(css), css)

    def test_layout_padding_rewritten_with_marker(self):
        css = "has-help-subnav .page-hero{padding:80px 0}.hero{padding:96px 24px 40px}"
        out = a.adjust_help_layout_padding(css)
        self.assertIn(".page-hero{padding-bottom:64px;padding-left:24px;padding-right:24px}", out.replace(" 0}", "}"))
        self.assertIn(".hero{padding-bottom:80px;padding-left:24px;padding-right:24px}", out)


class PatchFileTest(SiteCase):
    def test_patch_regular_page_updates_file_and_is_idempotent(self):
        p = self.page("index.html", PAGE.replace('<section class="hero">', "<section>"))
        self.assertTrue(a.patch_file(p))
        out = p.read_text()
        self.assertIn('<nav>\n  <div class="nav-inner">', out)
        self.assertIn('<footer>\n  <div class="footer-inner">', out)
        self.assertNotIn("<a>old</a>", out)
        self.assertNotIn("nav{position:fixed}", out)
        self.assertIn(".page-nav{display:flex}", out)
        self.assertIn(f"chrome.css?v={a.CHROME_VER}", out)
        self.assertIn(f"chrome.js?v={a.CHROME_VER}", out)
        self.assertIn(a.THEME_BOOT, out)
        self.assertNotIn("help-subnav", out)
        self.assertNotIn("neutral-variants", out)
        before = out
        self.assertFalse(a.patch_file(p))
        self.assertEqual(p.read_text(), before)

    def test_patch_help_index_page(self):
        p = self.page("help/index.html", PAGE)
        self.assertTrue(a.patch_file(p))
        out = p.read_text()
        self.assertIn('id="help-subnav"', out)
        self.assertIn('<body class="has-help-subnav">', out)
        self.assertIn('<script src="./search.js"></script>', out)
        self.assertIn('data-neutral-variant="s3"', out)
        self.assertIn("neutral-variants.css", out)
        self.assertNotIn("<p>sub</p>", out)
        self.assertIn("Help Center", out)
        self.assertEqual(out.count('id="help-subnav"'), 1)
        self.assertFalse(a.patch_file(p))

    def test_patch_nested_help_page_keeps_subtitle(self):
        p = self.page("help/concepts/a.html", PAGE)
        a.patch_file(p)
        out = p.read_text()
        self.assertIn("<p>sub</p>", out)
        self.assertIn('href="../../chrome.css', out)
        self.assertIn('<span class="current">A</span>', out)

    def test_patch_missing_nav_raises_and_leaves_file(self):
        p = self.page("terms/index.html", "<html><body><footer></footer></body></html>")
        with self.assertRaisesRegex(ValueError, "missing <nav> block"):
            a.patch_file(p)
        self.assertEqual(p.read_text(), "<html><body><footer></footer></body></html>")

    def test_patch_missing_footer_raises(self):
        p = self.page("terms/index.html", "<html><body><nav></nav></body></html>")
        with self.assertRaisesRegex(ValueError, "missing <footer> block"):
            a.patch_file(p)


class MainTest(SiteCase):
    def run_main(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = a.main()
        return rc, out.getvalue(), err.getvalue()

    def test_main_patches_skips_and_counts(self):
        self.page("index.html", PAGE)
        self.page("terms/index.html", "<html><body>no chrome</body></html>")
        self.page("privacy/index.html", PAGE)
        (self.site / "help" / "dir.html").mkdir()  # matches help/**/*.html but is not a file
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0)
        self.assertIn("patched site/index.html", out)
        self.assertIn("patched site/privacy/index.html", out)
        self.assertIn("done: 2 file(s) updated", out)
        self.assertIn("SKIP site/terms/index.html: missing <nav> block", err)
        self.assertNotIn("dir.html", out + err)
        # second run: nothing changes
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0)
        self.assertEqual(out, "done: 0 file(s) updated\n")

    def test_main_with_empty_site(self):
        rc, out, err = self.run_main()
        self.assertEqual((rc, out, err), (0, "done: 0 file(s) updated\n", ""))

    def test_script_entrypoint_runs_against_real_site_without_mutating_it(self):
        # Run the real script file as __main__ but with pathlib writes captured so the
        # tracked site/ tree is never modified.
        writes = []

        def fake_write(self, data, *args, **kwargs):
            writes.append(self)
            return len(data)

        out = io.StringIO()
        with mock.patch.object(Path, "write_text", fake_write), contextlib.redirect_stdout(out), \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "apply-site-chrome.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertRegex(out.getvalue(), r"done: \d+ file\(s\) updated")
        self.assertEqual(len(writes), len(re.findall(r"^patched ", out.getvalue(), re.M)))


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""In-process tests for verify_html.py."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'verify_html.py')
_spec = importlib.util.spec_from_file_location('verify_html_under_test', SCRIPT)
vh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vh)

GOOD_HTML = (
    '<html><head><title>T</title></head><body>'
    '<div class="header">h</div><div class="content">'
    '<h2 class="section-title">Executive Summary</h2><p>See [1].</p></div>'
    '<div class="bibliography"><div class="bib-entry">[1] x</div></div>'
    '</body></html>'
)
GOOD_MD = '## Executive Summary\nSee [1].\n## Bibliography\n[1] x\n'


def make(html, md):
    d = Path(tempfile.mkdtemp())
    (d / 'r.html').write_text(html, encoding='utf-8')
    (d / 'r.md').write_text(md, encoding='utf-8')
    return vh.HTMLVerifier(d / 'r.html', d / 'r.md'), d


def verify(html, md):
    v, _ = make(html, md)
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        ok = v.verify()
    return v, ok, out.getvalue()


class TestVerify(unittest.TestCase):
    def test_all_good(self):
        v, ok, out = verify(GOOD_HTML, GOOD_MD)
        self.assertTrue(ok)
        self.assertEqual((v.errors, v.warnings), ([], []))
        self.assertIn('All checks passed', out)

    def test_unreadable_files(self):
        v = vh.HTMLVerifier(Path('/nonexistent/a.html'), Path('/nonexistent/a.md'))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertFalse(v.verify())
        self.assertEqual(len(v.errors), 1)
        self.assertTrue(v.errors[0].startswith('Failed to read files:'))

    def test_errors_and_warnings_printed(self):
        v, ok, out = verify('<html>TODO</html>', GOOD_MD)
        self.assertFalse(ok)
        self.assertIn('ERRORS (', out)
        self.assertIn('Found unreplaced placeholders: TODO', out)
        self.assertNotIn('All checks passed', out)

    def test_warnings_only_pass(self):
        html = GOOD_HTML.replace('class="bib-entry"', 'class="other"')
        v, ok, out = verify(html, GOOD_MD)
        self.assertTrue(ok)
        self.assertEqual(v.warnings, ['Bibliography present but entries not properly formatted'])
        self.assertIn('WARNINGS (1)', out)
        self.assertNotIn('ERRORS', out)


class TestSections(unittest.TestCase):
    def test_placeholder_sections(self):
        v, _ = make('', '')
        v._check_sections('<div class="section">#</div><div class="section">#</div>', '')
        self.assertEqual(len(v.errors), 1)
        self.assertIn('Found 2 placeholder sections', v.errors[0])

    def test_count_mismatch_and_missing(self):
        v, _ = make('', '')
        md = '## A\n## B\n## C\n'
        v._check_sections('<h2 class="section-title">A</h2>', md)
        self.assertIn('MD has 3 sections, HTML has only 1', v.errors[0])
        self.assertEqual(v.errors[1], "Missing sections in HTML: {'B', 'C'}") if "'B', 'C'" in v.errors[1] \
            else self.assertEqual(v.errors[1], "Missing sections in HTML: {'C', 'B'}")

    def test_count_mismatch_with_no_missing_names(self):
        v, _ = make('', '')
        # duplicate heading names in MD, all present in HTML set, but count larger
        md = '## A\n## A\n## A\n'
        v._check_sections('<h2 class="section-title">A</h2>', md)
        self.assertEqual(len(v.errors), 1)
        self.assertIn('Section count mismatch', v.errors[0])

    def test_one_extra_section_allowed(self):
        v, _ = make('', '')
        v._check_sections('<h2 class="section-title">A</h2>', '## A\n## Bibliography\n')
        self.assertEqual(v.errors, [])

    def test_executive_summary_missing(self):
        v, _ = make('', '')
        v._check_sections('<p>x</p>', 'Executive Summary text')
        self.assertEqual(v.errors, ['Executive Summary missing from HTML'])

    def test_executive_summary_present(self):
        v, _ = make('', '')
        v._check_sections('Executive Summary', 'Executive Summary')
        self.assertEqual(v.errors, [])


class TestPlaceholdersEmojis(unittest.TestCase):
    def test_placeholders_listed(self):
        v, _ = make('', '')
        v._check_no_placeholders('x {{TITLE}} FIXME y')
        self.assertEqual(v.errors, ['Found unreplaced placeholders: {{TITLE}}, FIXME'])

    def test_no_placeholders(self):
        v, _ = make('', '')
        v._check_no_placeholders('clean')
        self.assertEqual(v.errors, [])

    def test_emojis(self):
        v, _ = make('', '')
        v._check_no_emojis('ok \U0001F600 and \U0001F680')
        self.assertEqual(len(v.errors), 1)
        self.assertIn('Found 2 emojis', v.errors[0])

    def test_no_emojis(self):
        v, _ = make('', '')
        v._check_no_emojis('plain text')
        self.assertEqual(v.errors, [])

    def test_non_latin_text_and_box_drawing_are_not_emojis(self):
        # The emoji range 24C2-1F251 used to swallow CJK, box drawing, etc.
        v, _ = make('', '')
        v._check_no_emojis('\u4e2d\u6587\u62a5\u544a \u2500\u2502 \u3042')
        self.assertEqual(v.errors, [])

    def test_symbol_blocks_flagged(self):
        # Regression: the narrowed range dropped the Miscellaneous Symbols,
        # Miscellaneous Symbols and Arrows and Supplemental Symbols blocks.
        cases = {
            '\u26a0': 'warning sign', '\u26a1': 'high voltage', '\u2b50': 'star',
            '\u2600': 'sun', '\u2611': 'ballot box check', '\u2665': 'heart',
            '\u25b6': 'play button', '\u2b06': 'up arrow', '\U0001F916': 'robot',
            '\U0001F9E0': 'brain', '\U0001F947': 'gold medal', '\u25fb': 'white medium square',
            '\u2934': 'arrow curving up', '\U0001F100': 'digit zero full stop',
        }
        for ch, name in cases.items():
            with self.subTest(name):
                v, _ = make('', '')
                v._check_no_emojis('x' + ch + 'y')
                self.assertEqual(len(v.errors), 1, name)
                self.assertIn('Found 1 emojis', v.errors[0])

    def test_symbol_block_edges(self):
        for ch in ('\u2600', '\u26ff', '\u2b00', '\u2bff', '\U0001F900', '\U0001F9FF'):
            with self.subTest(hex(ord(ch))):
                v, _ = make('', '')
                v._check_no_emojis(ch)
                self.assertEqual(len(v.errors), 1)

    def test_neighbouring_non_emoji_not_flagged(self):
        for ch in ('\u257f', '\u2580', '\u25b5', '\u2c00', '\U0001F8ff', '\u2190', '\u4e2d', '\u3042'):
            with self.subTest(hex(ord(ch))):
                v, _ = make('', '')
                v._check_no_emojis(ch)
                self.assertEqual(v.errors, [])

    def test_enclosed_symbols_still_flagged(self):
        v, _ = make('', '')
        v._check_no_emojis('\u24c2 \U0001F170 \U0001F251')
        self.assertEqual(len(v.errors), 1)
        self.assertIn('Found 3 emojis', v.errors[0])


class TestStructure(unittest.TestCase):
    def test_missing_elements(self):
        v, _ = make('', '')
        v._check_structure('<div>')
        self.assertIn('Missing HTML tag in HTML', v.errors)
        self.assertIn('Missing bibliography section in HTML', v.errors)
        self.assertEqual(len(v.errors), 7)
        self.assertEqual(v.warnings, [])

    def test_unclosed_divs_warning(self):
        v, _ = make('', '')
        v._check_structure(GOOD_HTML + '<div><div><div>')
        self.assertEqual(v.errors, [])
        self.assertEqual(len(v.warnings), 1)
        self.assertIn('Possible unclosed divs', v.warnings[0])


class TestCitations(unittest.TestCase):
    def test_none_in_html(self):
        v, _ = make('', '')
        v._check_citations('<p>x</p>', 'see [1] and [2]')
        self.assertIn('No citations found in HTML content (but present in MD)', v.errors)

    def test_fewer_citations_warning_excludes_bibliography(self):
        v, _ = make('', '')
        html = 'a [1] <div class="bibliography">[2] [3] [4]'
        v._check_citations(html, '[1] [2] [3] [4]')
        self.assertEqual(v.errors, [])
        self.assertEqual(v.warnings, ['Fewer citations in HTML (1) than MD (4)'])

    def test_no_bibliography_class_uses_whole_html(self):
        v, _ = make('', '')
        v._check_citations('[1] [2]', '[1] [2]')
        self.assertEqual((v.errors, v.warnings), ([], []))

    def test_no_md_citations(self):
        v, _ = make('', '')
        v._check_citations('x', 'none')
        self.assertEqual((v.errors, v.warnings), ([], []))


class TestBibliography(unittest.TestCase):
    def test_missing_section(self):
        v, _ = make('', '')
        v._check_bibliography('<p>', '## Bibliography')
        self.assertEqual(v.errors, ['Bibliography section missing from HTML'])

    def test_no_bibliography_in_md(self):
        v, _ = make('', '')
        v._check_bibliography('<p>', '## Other')
        self.assertEqual((v.errors, v.warnings), ([], []))


class TestMain(unittest.TestCase):
    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['verify_html.py', *argv]), contextlib.redirect_stdout(out):
            code = vh.main()
        return code, out.getvalue()

    def test_missing_html(self):
        code, out = self.run_main('--html', '/nonexistent/a.html', '--md', '/nonexistent/a.md')
        self.assertEqual(code, 1)
        self.assertIn('HTML file not found', out)

    def test_missing_md(self):
        _, d = make(GOOD_HTML, GOOD_MD)
        code, out = self.run_main('--html', str(d / 'r.html'), '--md', str(d / 'none.md'))
        self.assertEqual(code, 1)
        self.assertIn('Markdown file not found', out)

    def test_success_and_failure(self):
        _, d = make(GOOD_HTML, GOOD_MD)
        code, out = self.run_main('--html', str(d / 'r.html'), '--md', str(d / 'r.md'))
        self.assertEqual(code, 0)
        self.assertIn('All checks passed', out)
        (d / 'r.html').write_text('TBD', encoding='utf-8')
        code, _ = self.run_main('--html', str(d / 'r.html'), '--md', str(d / 'r.md'))
        self.assertEqual(code, 1)

    def test_run_as_script(self):
        _, d = make(GOOD_HTML, GOOD_MD)
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['verify_html.py', '--html', str(d / 'r.html'), '--md', str(d / 'r.md')]), \
                contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as cm:
            runpy.run_path(SCRIPT, run_name='__main__')
        self.assertEqual(cm.exception.code, 0)


if __name__ == '__main__':
    unittest.main()

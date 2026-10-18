"""Coverage tests for md_to_html (pure string conversion, no I/O except the CLI)."""

import tempfile
import unittest
from pathlib import Path

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import md_to_html as m


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestSplit(unittest.TestCase):
    def test_bibliography_split(self):
        content, bib = m.convert_markdown_to_html("# T\n## A\ntext\n## Bibliography\n[1] T - https://x.org/p\n")
        self.assertIn('<h2 class="section-title">A</h2>', content)
        self.assertNotIn("x.org", content)
        self.assertIn('<a href="https://x.org/p" target="_blank">T</a>', bib)

    def test_no_bibliography(self):
        content, bib = m.convert_markdown_to_html("# T\n## A\ntext")
        self.assertEqual(bib, "")
        self.assertIn("<p>text", content)

    def test_blank_bibliography(self):
        self.assertEqual(m._convert_bibliography_section("  \n "), "")


class TestBibliography(unittest.TestCase):
    def test_entries_and_bold(self):
        html = m._convert_bibliography_section(
            "\n[1] Title one - https://example.com/a\n[2] Other **bold** - http://x.org/b\nfree **text**\n")
        self.assertTrue(html.startswith('<div class="bibliography-content">'))
        self.assertTrue(html.endswith("</div>"))
        self.assertIn('<span class="bib-number">[1]</span> <a href="https://example.com/a" target="_blank">Title one</a>', html)
        self.assertIn('target="_blank">Other <strong>bold</strong></a>', html)
        self.assertIn("free <strong>text</strong>", html)


class TestContentSection(unittest.TestCase):
    def test_front_matter_skipped_until_first_h2(self):
        html = m._convert_content_section("# Title\nfront\n### not a section\n## First\nbody")
        self.assertNotIn("front", html)
        self.assertNotIn("not a section", html)
        self.assertIn('<h2 class="section-title">First</h2>', html)

    def test_no_h2_gives_empty_output(self):
        self.assertEqual(m._convert_content_section("# Title\nonly front matter"), "")

    def test_headings_and_inline_formatting(self):
        html = m._convert_content_section(
            "## S\n### Sub\n#### Deep\nA **bold** *it* `code` line\n")
        self.assertIn('<h3 class="subsection-title">Sub</h3>', html)
        self.assertIn('<h4 class="subsubsection-title">Deep</h4>', html)
        self.assertIn("<p>A <strong>bold</strong> <em>it</em> <code>code</code> line", html)

    def test_sections_are_closed(self):
        html = m._convert_content_section("## One\nx\n## Two\ny\n")
        self.assertEqual(html.count('<div class="section">'), 2)
        self.assertEqual(html.count("</div>"), 2)
        self.assertLess(html.index("</div>"), html.index("Two"))

    def test_executive_summary_wrapped(self):
        html = m._convert_content_section("## Executive Summary\ntext\n## Next\nmore")
        self.assertIn('<div class="executive-summary"><h2 class="section-title">Executive Summary</h2>', html)

    def test_no_executive_summary_no_wrapper(self):
        self.assertNotIn("executive-summary", m._convert_content_section("## Other\ntext"))


class TestLists(unittest.TestCase):
    def test_unordered_both_markers(self):
        out = m._convert_lists("- a\n* b\ntext")
        self.assertEqual(out, "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\ntext")

    def test_ordered(self):
        out = m._convert_lists("1. a\n2. b\n\nafter")
        self.assertEqual(out, "<ol>\n<li>a</li>\n<li>b</li>\n</ol>\n\nafter")

    def test_ordered_after_unordered_closes_with_ol(self):
        out = m._convert_lists("- a\n\n1. x\n2. y\n\nend")
        self.assertEqual(out, "<ul>\n<li>a</li>\n</ul>\n\n<ol>\n<li>x</li>\n<li>y</li>\n</ol>\n\nend")

    def test_continuation_lines_are_merged(self):
        out = m._convert_lists("- a\n  more\n    even more\n- b")
        self.assertEqual(out, "<ul>\n<li>a more even more</li>\n<li>b</li>\n</ul>")

    def test_list_at_end_is_closed(self):
        self.assertEqual(m._convert_lists("- a"), "<ul>\n<li>a</li>\n</ul>")
        self.assertEqual(m._convert_lists("1. a"), "<ol>\n<li>a</li>\n</ol>")

    def test_unindented_text_ends_list(self):
        out = m._convert_lists("- a\nplain")
        self.assertEqual(out, "<ul>\n<li>a</li>\n</ul>\nplain")

    def test_indented_list_level(self):
        out = m._convert_lists("  - a\n  text at same level")
        self.assertEqual(out, "<ul>\n<li>a</li>\n</ul>\n  text at same level")


class TestTables(unittest.TestCase):
    def test_table(self):
        out = m._convert_tables("| H1 | H2 |\n|----|----|\n| a | b |\nafter")
        self.assertEqual(out.split("\n"), [
            "<table>", "<thead><tr>", "<th>H1</th>", "<th>H2</th>", "</tr></thead>", "<tbody>",
            "<tr>", "<td>a</td>", "<td>b</td>", "</tr>", "</tbody></table>", "after"])

    def test_table_at_end_closed(self):
        out = m._convert_tables("| H |\n| a |")
        self.assertTrue(out.endswith("</tbody></table>"))

    def test_pipe_inside_text_is_not_a_table(self):
        self.assertEqual(m._convert_tables("a | b"), "a | b")


class TestParagraphs(unittest.TestCase):
    def test_wrapping(self):
        out = m._convert_paragraphs("line one\nline two\n\n<h3>x</h3>\nplain\n<div>y</div>\nlast")
        self.assertEqual(out.split("\n"), [
            "<p>line one", "line two", "</p>", "", "<h3>x</h3>", "<p>plain", "</p>", "<div>y</div>",
            "<p>last", "</p>"])

    def test_html_lines_close_open_paragraph(self):
        out = m._convert_paragraphs("text\n</div>\nmore")
        self.assertEqual(out.split("\n"), ["<p>text", "</p>", "</div>", "<p>more", "</p>"])

    def test_blank_without_open_paragraph(self):
        self.assertEqual(m._convert_paragraphs("\n"), "\n")

    def test_all_html_markers_recognised(self):
        for line in ("x <h2>", "x <ul>", "x <ol>", "x <li>", "x <table>", "x </ul>", "x </ol>", "x </div>"):
            self.assertEqual(m._convert_paragraphs(line), line, line)


class TestCloseSections(unittest.TestCase):
    def test_close(self):
        out = m._close_sections('<div class="section">a\nx\n<div class="section">b')
        self.assertEqual(out.split("\n"), ['<div class="section">a', "x", "</div>", '<div class="section">b', "</div>"])

    def test_no_sections(self):
        self.assertEqual(m._close_sections("plain\ntext"), "plain\ntext")


class TestCLI(unittest.TestCase):
    def test_usage(self):
        code, out, _ = call_main(m, [])
        self.assertEqual(code, 1)
        self.assertIn("Usage: python md_to_html.py", out)

    def test_missing_file(self):
        code, out, _ = call_main(m, ["/nonexistent/file.md"])
        self.assertEqual(code, 1)
        self.assertIn("not found", out)

    def test_converts_file(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "r.md"
            f.write_text("# T\n## Sec\nhello\n## Bibliography\n[1] A - https://a.org/x\n")
            code, out, _ = call_main(m, [str(f)])
            self.assertEqual(code, 0)
            self.assertIn("=== CONTENT HTML ===", out)
            self.assertIn('<h2 class="section-title">Sec</h2>', out)
            self.assertIn("=== BIBLIOGRAPHY HTML ===", out)
            self.assertIn("bib-entry", out)
            code, out, _ = run_script(SCRIPTS / "md_to_html.py", [str(f)])
            self.assertEqual(code, 0)

    def test_output_is_truncated(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "r.md"
            f.write_text("## Sec\n" + "word " * 1000 + "\n## Bibliography\n" + "x" * 2000)
            _, out, _ = call_main(m, [str(f)])
            content_part = out.split("=== BIBLIOGRAPHY HTML ===")[0]
            self.assertLessEqual(len(content_part), 1000 + 40)
            self.assertLessEqual(len(out.split("=== BIBLIOGRAPHY HTML ===")[1].strip()), 500)


if __name__ == "__main__":
    unittest.main()

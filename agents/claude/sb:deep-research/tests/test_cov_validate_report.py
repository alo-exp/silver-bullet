"""Coverage tests for validate_report (each check exercised directly and end to end)."""

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import validate_report as vr

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class Base(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.dir = Path(self._td.name)

    def make(self, content, lang="en", profile=None):
        p = self.dir / "report.md"
        p.write_text(content, encoding="utf-8")
        v = vr.ReportValidator(p, lang=lang)
        if profile is not None:
            v.profile = profile
        return v

    def run_validate(self, v):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            ok = v.validate()
        return ok, buf.getvalue()


class TestProfileAndRead(Base):
    def test_profile_selection(self):
        self.assertIn("section_labels", vr.load_report_profile("en"))
        self.assertEqual(vr.load_report_profile("zh")["section_labels"]["bibliography"], "参考文献")
        # unknown language falls back to the default profile
        self.assertEqual(vr.load_report_profile("fr"), vr.load_report_profile("en"))

    def test_missing_profile_file(self):
        with mock.patch.object(vr, "DEFAULT_PROFILE_PATH", self.dir / "none.json"):
            self.assertEqual(vr.load_report_profile("en"), {"section_labels": {}, "forecast_forbidden": []})

    def test_profile_without_default_key(self):
        f = self.dir / "p.json"
        f.write_text(json.dumps({"profiles": {"en": {"x": 1}}}))
        with mock.patch.object(vr, "DEFAULT_PROFILE_PATH", f):
            self.assertEqual(vr.load_report_profile("xx"), {"x": 1})
        f.write_text(json.dumps({}))
        with mock.patch.object(vr, "DEFAULT_PROFILE_PATH", f):
            self.assertEqual(vr.load_report_profile("en"), {})

    def test_unreadable_report_exits(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), self.assertRaises(SystemExit) as ctx:
            vr.ReportValidator(self.dir / "absent.md")
        self.assertEqual(ctx.exception.code, 1)
        self.assertIn("Cannot read report", buf.getvalue())


class TestExecutiveSummary(Base):
    def test_missing(self):
        v = self.make("# T\n## Intro\nx")
        self.assertFalse(v._check_executive_summary())
        self.assertEqual(v.errors, ["Missing 'Executive Summary' section"])

    def test_length_warnings(self):
        long = "## Executive Summary\n" + "word " * 401 + "\n## Next"
        v = self.make(long)
        self.assertTrue(v._check_executive_summary())
        self.assertEqual(v.warnings, ["Executive summary too long: 401 words (should be ≤400)"])
        v = self.make("## Executive Summary\nshort text\n## Next")
        self.assertTrue(v._check_executive_summary())
        self.assertEqual(v.warnings, ["Executive summary too short: 2 words (should be ≥50)"])
        v = self.make("## Executive Summary\n" + "word " * 100 + "\n## Next")
        self.assertTrue(v._check_executive_summary())
        self.assertEqual(v.warnings, [])

    def test_zh_label(self):
        v = self.make("## 执行摘要\n" + "字 " * 60, lang="zh")
        self.assertTrue(v._check_executive_summary())


class TestLanguageProfile(Base):
    def test_no_labels_passes(self):
        v = self.make("x", profile={})
        self.assertTrue(v._check_language_profile())

    def test_missing_labels_reported(self):
        v = self.make("## Introduction\n")
        self.assertFalse(v._check_language_profile())
        self.assertEqual(v.errors, ["Missing profile sections (en): Bibliography, Recommendations"])

    def test_all_present_or_label_absent_from_profile(self):
        v = self.make("## Introduction\n## Bibliography\n## Recommendations")
        self.assertTrue(v._check_language_profile())
        v = self.make("nothing", profile={"section_labels": {"x": "y"}})
        self.assertTrue(v._check_language_profile())


class TestToc(Base):
    def test_duplicates(self):
        v = self.make("### A\n### a \n### B\n")
        self.assertFalse(v._check_toc_uniqueness())
        self.assertEqual(v.errors, ["Duplicate TOC headings: ['a']"])
        v = self.make("### A\n### B\n")
        self.assertTrue(v._check_toc_uniqueness())


class TestMetadataAndForecast(Base):
    def test_metadata(self):
        v = self.make("## Report Metadata\nx")
        self.assertTrue(v._check_metadata_block())
        v = self.make("nothing")
        self.assertFalse(v._check_metadata_block())
        self.assertEqual(v.errors, ["Missing metadata block: 'Report Metadata'"])
        v = self.make("nothing", profile={})
        v._check_metadata_block()
        self.assertEqual(v.errors, ["Missing metadata block: 'Report Metadata'"])

    def test_forecast(self):
        v = self.make("It WILL DEFINITELY work")
        self.assertFalse(v._check_forecast_wording())
        self.assertEqual(v.errors, ["Forbidden forecast wording (en): ['will definitely']"])
        self.assertTrue(self.make("It might work")._check_forecast_wording())
        self.assertTrue(self.make("x", profile={})._check_forecast_wording())


class TestBibliographyTail(Base):
    def test_not_required(self):
        v = self.make("anything", profile={"bibliography_tail_required": False})
        self.assertTrue(v._check_bibliography_tail())

    def test_no_bibliography_or_no_metadata(self):
        self.assertTrue(self.make("## Metadata only\n## Report Metadata")._check_bibliography_tail())
        self.assertTrue(self.make("## Bibliography\n[1] x")._check_bibliography_tail())

    def test_metadata_before_bibliography_is_fine(self):
        v = self.make("## Report Metadata\nx\n## Bibliography\n[1] x\n## Extra")
        self.assertTrue(v._check_bibliography_tail())

    def test_allowed_and_unexpected_sections_between(self):
        ok = "## Bibliography\n[1] x\n## Methodology\nm\n## Appendix A\na\n## Report Metadata\nmeta"
        self.assertTrue(self.make(ok)._check_bibliography_tail())
        bad = "## Bibliography\n[1] x\n## Surprise\ns\n## Report Metadata\nmeta"
        v = self.make(bad)
        self.assertFalse(v._check_bibliography_tail())
        self.assertEqual(v.errors, ["Unexpected section between Bibliography and Metadata: Surprise"])
        zh = "## 参考文献\n[1] x\n## 方法论附录\nm\n## 报告元数据\nmeta"
        self.assertTrue(self.make(zh, lang="zh")._check_bibliography_tail())


class TestRequiredSections(Base):
    ALL = ("Executive Summary", "Introduction", "Main Analysis", "Synthesis", "Limitations",
           "Recommendations", "Bibliography", "Methodology")

    def test_missing_required(self):
        v = self.make("## Introduction\n## Synthesis")
        self.assertFalse(v._check_required_sections())
        self.assertIn("Missing sections: Executive Summary, Main Analysis", v.errors[0])

    def test_recommended_warning_and_clean(self):
        body = "\n".join(f"## {s}" for s in self.ALL)
        v = self.make(body)
        self.assertTrue(v._check_required_sections())
        self.assertEqual(v.warnings, ["Missing recommended sections (for academic rigor): "
                                      "Counterevidence Register, Claims-Evidence Table"])
        v = self.make(body + "\n## Counterevidence Register\n## Claims-Evidence Table")
        self.assertTrue(v._check_required_sections())
        self.assertEqual(v.warnings, [])

    def test_default_labels_without_profile(self):
        v = self.make("\n".join(f"## {s}" for s in self.ALL), profile={})
        self.assertTrue(v._check_required_sections())


class TestCitations(Base):
    def test_none(self):
        v = self.make("no cites")
        self.assertFalse(v._check_citations())
        self.assertEqual(v.errors, ["No citations found in report"])

    def test_few_and_gaps(self):
        v = self.make("a [1] b [3] c [3]")
        self.assertTrue(v._check_citations())
        self.assertEqual(v.warnings, ["Only 2 unique sources cited (recommended: ≥10)",
                                      "Non-consecutive citation numbers, missing: [2]"])

    def test_ten_consecutive_clean(self):
        v = self.make(" ".join(f"[{i}]" for i in range(1, 11)))
        self.assertTrue(v._check_citations())
        self.assertEqual(v.warnings, [])


class TestBibliography(Base):
    def bib(self, text):
        return self.make("body [1] [2]\n## Bibliography\n" + text + "\n## Report Metadata\nm")

    def test_missing_section(self):
        v = self.make("body [1]")
        self.assertFalse(v._check_bibliography())
        self.assertEqual(v.errors, ["Missing 'Bibliography' section"])

    def test_truncation_placeholders(self):
        for text, desc in [
            ("[8-75] refs", "Citation range"),
            ("Additional 20 citations", "Additional citations"),
            ("others would be included", "would be included"),
            ("[...continue", "[...continue"),
            ("[Continue with the rest", "[Continue with"),
            ("and more etc.", "etc."),
            ("and so on", "and so on"),
        ]:
            v = self.bib("[1] a\n[2] b\n" + text)
            self.assertFalse(v._check_bibliography(), text)
            self.assertIn(desc, v.errors[0])
            self.assertIn("UNUSABLE", v.errors[1])

    def test_etc_inside_word_not_flagged(self):
        v = self.bib("[1] a etc.x\n[2] b")
        self.assertTrue(v._check_bibliography())

    def test_no_entries(self):
        v = self.bib("nothing here")
        self.assertFalse(v._check_bibliography())
        self.assertEqual(v.errors, ["Bibliography has no entries"])

    def test_gaps(self):
        v = self.make("[1] [3]\n## Bibliography\n[1] a\n[3] c\n")
        self.assertFalse(v._check_bibliography())
        self.assertEqual(v.errors, ["Bibliography has gaps in numbering: missing [2]"])

    def test_citation_missing_from_bibliography(self):
        v = self.make("[1] [2] [3]\n## Bibliography\n[1] a\n[2] b\n")
        self.assertFalse(v._check_bibliography())
        self.assertEqual(v.errors, ["Citations missing from bibliography: ['3']"])

    def test_cross_reference_inside_bibliography_entry_is_not_a_body_citation(self):
        v = self.make("only [1]\n## Bibliography\n[1] a, see also [9]\n## Report Metadata\nm")
        self.assertTrue(v._check_bibliography())
        self.assertEqual(v.errors, [])

    def test_unused_entries_warn(self):
        v = self.make("only [1]\n## Bibliography\n[1] a\n[2] b\n")
        self.assertTrue(v._check_bibliography())
        self.assertEqual(v.warnings, ["Unused bibliography entries: ['2']"])
        self.assertTrue(self.bib("[1] a\n[2] b")._check_bibliography())


class TestPlaceholdersAndTruncation(Base):
    def test_placeholders(self):
        v = self.make("some TODO and [citation needed] here")
        self.assertFalse(v._check_placeholders())
        self.assertEqual(v.errors, ["Found placeholder text: TODO, [citation needed]"])
        self.assertTrue(self.make("clean text")._check_placeholders())

    def test_content_truncation(self):
        for text, desc in [
            ("Content continues below", "Content continues"),
            ("Due to length we stop", "Due to length"),
            ("this would continue", "would continue"),
            ("[Sections 3-9 omitted", "[Sections X-Y"),
            ("Additional sections follow", "Additional sections"),
            ("A comprehensive 40k word document that continues", "comprehensive...document that continues"),
        ]:
            v = self.make(text)
            self.assertFalse(v._check_content_truncation(), text)
            self.assertIn(desc, v.errors[0])
            self.assertIn("INCOMPLETE", v.errors[1])
        self.assertTrue(self.make("complete text")._check_content_truncation())


class TestCounts(Base):
    def test_word_count(self):
        v = self.make("few words")
        self.assertTrue(v._check_word_count())
        self.assertEqual(v.warnings, ["Report is very short: 2 words (consider expanding)"])
        v = self.make("w " * 600)
        self.assertTrue(v._check_word_count())
        self.assertEqual(v.warnings, [])

    def test_source_count(self):
        v = self.make("no bibliography")
        self.assertTrue(v._check_source_count())
        self.assertEqual(v.warnings, [])
        v = self.make("## Bibliography\n[1] a\n[1] dup\n[2] b\n")
        self.assertTrue(v._check_source_count())
        self.assertEqual(v.warnings, ["Only 2 sources (recommended: ≥10)"])
        entries = "\n".join(f"[{i}] s" for i in range(1, 11))
        v = self.make("## Bibliography\n" + entries)
        self.assertTrue(v._check_source_count())
        self.assertEqual(v.warnings, [])


class TestBrokenLinks(Base):
    def test_links(self):
        (self.dir / "exists.md").write_text("x")
        v = self.make("[a](./exists.md#anchor) [b](./gone.md) [c](https://x.example) [d](./also-gone.md#h)")
        self.assertFalse(v._check_broken_references())
        self.assertEqual(v.errors, ["Broken internal links: ./gone.md, ./also-gone.md#h"])
        self.assertTrue(self.make("[a](./exists.md)")._check_broken_references())


class TestSummaryAndValidate(Base):
    def test_valid_fixture_passes_all(self):
        v = vr.ReportValidator(FIXTURES / "valid_report.md", lang="en")
        ok, out = self.run_validate(v)
        self.assertTrue(ok)
        self.assertEqual(v.errors, [])
        self.assertIn("VALIDATING REPORT: valid_report.md", out)
        self.assertIn("✅ PASS", out)
        self.assertNotIn("❌ FAIL", out)

    def test_summary_variants(self):
        v = self.make("x")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            v._print_summary()
        self.assertIn("ALL CHECKS PASSED", buf.getvalue())
        v.warnings.append("w1")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            v._print_summary()
        self.assertIn("WARNINGS (1)", buf.getvalue())
        self.assertIn("VALIDATION PASSED (with warnings)", buf.getvalue())
        v.errors.append("e1")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            v._print_summary()
        self.assertIn("ERRORS (1)", buf.getvalue())
        self.assertIn("• e1", buf.getvalue())
        self.assertIn("VALIDATION FAILED", buf.getvalue())

    def test_failing_report(self):
        v = self.make("nothing useful [1]")
        ok, out = self.run_validate(v)
        self.assertFalse(ok)
        self.assertIn("❌ FAIL", out)
        self.assertIn("Missing 'Executive Summary' section", out)


class TestMain(Base):
    def test_missing_report(self):
        code, out, _ = call_main(vr, ["--report", str(self.dir / "none.md")])
        self.assertEqual(code, 1)
        self.assertIn("Report file not found", out)

    def test_valid_and_invalid(self):
        code, out, _ = call_main(vr, ["-r", str(FIXTURES / "valid_report.md")])
        self.assertEqual(code, 0)
        code, out, _ = call_main(vr, ["-r", str(FIXTURES / "broken_en_forecast.md"), "-l", "en"])
        self.assertEqual(code, 1)
        code, out, _ = call_main(vr, ["-r", str(FIXTURES / "valid_report_zh.md"), "--lang", "zh"])
        self.assertEqual(code, 0)

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "validate_report.py", ["-r", str(self.dir / "none.md")])
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()

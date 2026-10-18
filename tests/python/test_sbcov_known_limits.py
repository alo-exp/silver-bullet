"""Unit tests for the audited known-limits mechanism in tests/coverage/sbcov.py.

Known limits remove statements that no test can cover from the coverage
denominator, one audited entry at a time (tests/coverage/known-limits.json).
The validation is strict so the list cannot rot or hide new gaps.
"""

import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT as sbtest_root, load_module

try:
    sbcov = load_module("tests/coverage/sbcov.py")
except ImportError as exc:  # coverage tooling requirements missing
    sbcov = None
    SKIP_REASON = str(exc)

FIXTURE = "tests/coverage/fixtures/calibration.sh"  # line 17 is `echo "MISS: else arm"`


def bash_result(missing, statements=10, covered=None, lines=8, lines_covered=None):
    covered = statements - len(missing) if covered is None else covered
    return {
        "statements": statements,
        "statements_covered": covered,
        "lines": lines,
        "lines_covered": lines - len(missing) if lines_covered is None else lines_covered,
        "functions": 2,
        "functions_covered": 2,
        "missing_statements": [{"line": ln, "end": ln, "word": w} for ln, w in missing],
        "missing_functions": [],
        "orphan_hits": [],
        "parse_errors": [],
    }


def entry(**kw):
    base = {
        "file": FIXTURE,
        "line": 17,
        "word": "echo",
        "kind": "unreachable",
        "reason": "dead arm",
        "evidence": "proof",
    }
    base.update(kw)
    return base


def apply(entries, bash=None, py=None, js=None, scoped=None):
    results = {"bash": bash or {}, "python": py or {}, "javascript": js or {}}
    scoped = scoped or {"bash": [FIXTURE], "python": [], "javascript": []}
    return sbcov.apply_known_limits(entries, results, scoped), results


@unittest.skipIf(sbcov is None, "coverage tooling requirements missing")
class ApplyKnownLimitsTest(unittest.TestCase):
    def test_matching_entry_adjusts_totals(self):
        res = {FIXTURE: bash_result([(17, "echo"), (30, "echo")])}
        (applied, errors), results = apply([entry()], bash=res)
        self.assertEqual(errors, [])
        self.assertEqual([a["line"] for a in applied], [17])
        r = results["bash"][FIXTURE]
        self.assertEqual((r["statements"], r["statements_covered"]), (9, 8))
        self.assertEqual([m["line"] for m in r["missing_statements"]], [30])
        self.assertEqual(r["known_limits"], 1)

    def test_sole_statement_line_leaves_the_line_denominator(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        (_, errors), results = apply([entry()], bash=res)
        self.assertEqual(errors, [])
        r = results["bash"][FIXTURE]
        self.assertEqual((r["lines"], r["lines_covered"]), (7, 7))

    def test_functions_are_not_changed(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        _, results = apply([entry()], bash=res)
        r = results["bash"][FIXTURE]
        self.assertEqual((r["functions"], r["functions_covered"]), (2, 2))

    def test_wrong_word_is_an_error(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        (applied, errors), results = apply([entry(word="printf")], bash=res)
        self.assertEqual(applied, [])
        self.assertTrue(any("no statement" in e and "printf" in e for e in errors), errors)
        self.assertEqual(results["bash"][FIXTURE]["statements"], 10)

    def test_wrong_line_is_an_error(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        (_, errors), _ = apply([entry(line=18)], bash=res)
        self.assertTrue(any("no statement" in e and ":18" in e for e in errors), errors)

    def test_out_of_scope_file_is_an_error(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        (_, errors), _ = apply([entry(file="hooks/not-in-scope.sh")], bash=res)
        self.assertTrue(any("not in scope" in e for e in errors), errors)

    def test_out_of_scope_file_is_an_error_even_with_only(self):
        (_, errors), _ = apply([entry(file="hooks/not-in-scope.sh")], bash={})
        self.assertTrue(any("not in scope" in e for e in errors), errors)

    def test_covered_entry_is_stale(self):
        res = {FIXTURE: bash_result([(30, "echo")])}  # line 17 was covered this run
        (applied, errors), results = apply([entry()], bash=res)
        self.assertEqual(applied, [])
        self.assertTrue(any("stale known limit: now covered" in e for e in errors), errors)
        self.assertEqual(results["bash"][FIXTURE]["statements"], 10)

    def test_only_skips_unmeasured_files(self):
        # The file is in scope but this run measured nothing for it.
        (applied, errors), _ = apply([entry()], bash={})
        self.assertEqual((applied, errors), ([], []))

    def test_invalid_kind_and_missing_fields_are_errors(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        (_, errors), _ = apply([entry(kind="flaky")], bash=res)
        self.assertTrue(any("kind" in e for e in errors), errors)
        bad = entry()
        del bad["reason"]
        (_, errors), _ = apply([bad], bash=res)
        self.assertTrue(any("reason" in e for e in errors), errors)

    def test_duplicate_entries_are_an_error(self):
        res = {FIXTURE: bash_result([(17, "echo")])}
        (_, errors), _ = apply([entry(), entry()], bash=res)
        self.assertTrue(any("duplicate" in e for e in errors), errors)

    def test_python_entry_adjusts_statements(self):
        py = {"scripts/x.py": {"statements": 5, "statements_covered": 4, "branches": 2,
                               "branches_covered": 2, "missing_lines": [7, 9], "missing_branches": {}}}
        e = {"file": "scripts/x.py", "line": 7, "kind": "unreachable", "reason": "r", "evidence": "e"}
        scoped = {"bash": [], "python": ["scripts/x.py"], "javascript": []}
        (applied, errors), results = apply([e], py=py, scoped=scoped)
        self.assertEqual(errors, [])
        r = results["python"]["scripts/x.py"]
        self.assertEqual((r["statements"], r["statements_covered"], r["missing_lines"]), (4, 4, [9]))
        self.assertEqual(applied[0]["language"], "python")

    def test_python_covered_line_is_stale(self):
        py = {"scripts/x.py": {"statements": 5, "statements_covered": 5, "branches": 0,
                               "branches_covered": 0, "missing_lines": [], "missing_branches": {}}}
        e = {"file": "scripts/x.py", "line": 7, "kind": "unmeasurable", "reason": "r", "evidence": "e"}
        scoped = {"bash": [], "python": ["scripts/x.py"], "javascript": []}
        (_, errors), _ = apply([e], py=py, scoped=scoped)
        self.assertTrue(any("stale known limit: now covered" in e for e in errors), errors)

    def test_js_entry_adjusts_lines(self):
        js = {"site/a.js": {"lines": 5, "lines_covered": 4, "functions": 1, "functions_covered": 1,
                            "branches": 0, "branches_covered": 0, "missing_lines": [3], "measured": True}}
        e = {"file": "site/a.js", "line": 3, "kind": "unreachable", "reason": "r", "evidence": "e"}
        scoped = {"bash": [], "python": [], "javascript": ["site/a.js"]}
        (_, errors), results = apply([e], js=js, scoped=scoped)
        self.assertEqual(errors, [])
        r = results["javascript"]["site/a.js"]
        self.assertEqual((r["lines"], r["lines_covered"], r["missing_lines"]), (4, 4, []))


@unittest.skipIf(sbcov is None, "coverage tooling requirements missing")
class LoadKnownLimitsTest(unittest.TestCase):
    def test_missing_file_means_no_entries(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(sbcov.load_known_limits(Path(d) / "none.json"), ([], []))

    def test_malformed_json_is_an_error(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "kl.json"
            p.write_text("{nope")
            entries, errors = sbcov.load_known_limits(p)
            self.assertEqual(entries, [])
            self.assertTrue(errors)

    def test_reads_entries_key(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "kl.json"
            p.write_text(json.dumps({"entries": [entry()]}))
            self.assertEqual(sbcov.load_known_limits(p), ([entry()], []))

    def test_shipped_file_is_well_formed(self):
        entries, errors = sbcov.load_known_limits()
        self.assertEqual(errors, [])
        for e in entries:
            self.assertIn(e["kind"], ("unreachable", "unmeasurable"))

    def test_shipped_bash_entries_name_real_statements(self):
        entries, _ = sbcov.load_known_limits()
        _, scoped = sbcov.load_scope()
        for e in entries:
            self.assertIn(e["file"], scoped["bash"])
            stmts = sbcov.analyze_bash(sbtest_root / e["file"]).statements
            self.assertTrue(
                any(st.start == e["line"] and (st.word or "*") == e["word"] for st in stmts),
                f"{e['file']}:{e['line']} ({e['word']})",
            )


@unittest.skipIf(sbcov is None, "coverage tooling requirements missing")
class ReportKnownLimitsTest(unittest.TestCase):
    def run_report(self, entries, missing, only=None, fail_under=None):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        tmp_path = Path(tmp.name)
        kl = tmp_path / "kl.json"
        kl.write_text(json.dumps({"entries": entries}))
        scoped = {"bash": [FIXTURE], "python": [], "javascript": []}
        res = {FIXTURE: bash_result(missing)} if missing is not None else {}
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sbcov, "KNOWN_LIMITS_FILE", kl), \
             mock.patch.object(sbcov, "load_scope", return_value=({}, scoped)), \
             mock.patch.object(sbcov, "bash_coverage", return_value=res), \
             mock.patch.object(sbcov, "python_coverage", return_value={}), \
             mock.patch.object(sbcov, "js_coverage", return_value={}), \
             redirect_stdout(out), redirect_stderr(err):
            code = sbcov.report(tmp_path, fail_under, False, only)
        summary = json.loads((tmp_path / "coverage-summary.json").read_text())
        return code, out.getvalue() + err.getvalue(), summary

    def test_fail_under_100_passes_on_adjusted_totals(self):
        code, text, summary = self.run_report([entry()], [(17, "echo")], fail_under=100)
        self.assertEqual(code, 0, text)
        self.assertEqual(summary["summary"]["bash"]["statements"], 9)
        self.assertEqual(summary["summary"]["bash"]["statements_covered"], 9)

    def test_fail_under_100_fails_without_the_entry(self):
        code, text, _ = self.run_report([], [(17, "echo")], fail_under=100)
        self.assertEqual(code, 2, text)

    def test_text_and_json_list_the_entries(self):
        code, text, summary = self.run_report([entry(reason="dead arm of the dispatch case")], [(17, "echo")])
        self.assertEqual(code, 0, text)
        self.assertIn("Known limits", text)
        self.assertIn(f"{FIXTURE}:17", text)
        self.assertIn("unreachable", text)
        self.assertIn("dead arm of the dispatch case", text)
        listed = summary["summary"]["known_limits"]
        self.assertEqual([(k["file"], k["line"], k["word"], k["kind"], k["reason"]) for k in listed],
                         [(FIXTURE, 17, "echo", "unreachable", "dead arm of the dispatch case")])

    def test_invalid_entry_exits_non_zero_even_without_fail_under(self):
        code, text, _ = self.run_report([entry(word="printf")], [(17, "echo")])
        self.assertEqual(code, 3, text)
        self.assertIn("known limit", text.lower())

    def test_stale_entry_exits_non_zero(self):
        code, text, _ = self.run_report([entry()], [(30, "echo")])
        self.assertEqual(code, 3, text)
        self.assertIn("stale known limit: now covered", text)

    def test_only_skips_unmeasured_entries(self):
        code, text, summary = self.run_report([entry()], None, only=["hooks/*"])
        self.assertEqual(code, 0, text)
        self.assertEqual(summary["summary"].get("known_limits"), [])


if __name__ == "__main__":
    unittest.main()

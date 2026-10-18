"""Unit tests for scripts/validate-evidence-findings.py."""
from __future__ import annotations

import contextlib
import io
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

REL = "scripts/validate-evidence-findings.py"
v = load_module(REL, name="vef_under_test")

HDR = "| domain | scope | severity | confidence | evidence | finding | required_action | owner_workflow | blocking_status |"
SEP = "|---|---|---|---|---|---|---|---|---|"
GOOD = "| code | a.py | BLOCK | HIGH | a.py:1 | bug | fix | sb:bugfix | blocks ship |"


def table(*rows, header=HDR):
    return "\n".join([header, SEP, *rows]) + "\n"


class HelperTest(unittest.TestCase):
    def test_canonical_header_aliases_and_underscores(self):
        self.assertEqual(v.canonical_header("Pack"), "domain")
        self.assertEqual(v.canonical_header("required_action"), "required_action")
        self.assertEqual(v.canonical_header("Ship Impact"), "blocking_status")
        self.assertEqual(v.canonical_header("  SEV "), "severity")
        self.assertIsNone(v.canonical_header("nonsense"))

    def test_split_row(self):
        self.assertEqual(v.split_row(" | a | b |  c | "), ["a", "b", "c"])

    def test_is_separator_row(self):
        self.assertFalse(v.is_separator_row([]))
        self.assertTrue(v.is_separator_row(["---", ":---:", "---:", ""]))
        self.assertTrue(v.is_separator_row(["- - -"]))
        self.assertFalse(v.is_separator_row(["---", "abc"]))
        self.assertFalse(v.is_separator_row(["--"]))

    def test_parse_table(self):
        lines = [HDR, SEP, GOOD, "", "| x | y | z |"]
        headers, rows, nxt = v.parse_table(lines, 0)
        self.assertEqual(len(headers), 9)
        self.assertEqual(len(rows), 1)
        self.assertEqual(nxt, 3)

    def test_parse_table_skips_blank_rows_and_runs_to_eof(self):
        lines = [HDR, SEP, "|  |  |", GOOD]
        _, rows, nxt = v.parse_table(lines, 0)
        self.assertEqual(len(rows), 1)
        self.assertEqual(nxt, 4)

    def test_parse_table_rejections(self):
        self.assertIsNone(v.parse_table([HDR], 0))  # no room for separator
        self.assertIsNone(v.parse_table(["| a | b |", "|--|--|"], 0))  # < 3 headers
        self.assertIsNone(v.parse_table([HDR, "| not | a | separator |"], 0))

    def test_looks_like_finding_table(self):
        self.assertTrue(v.looks_like_finding_table(["Severity", "Issue", "Proof"]))
        self.assertFalse(v.looks_like_finding_table(["Severity", "Issue"]))

    def test_parse_table_header_and_separator_at_end_of_file(self):
        headers, rows, nxt = v.parse_table([HDR, SEP], 0)
        self.assertEqual((len(headers), rows, nxt), (9, [], 2))
        headers, rows, nxt = v.parse_table(["intro", HDR, SEP], 1)
        self.assertEqual((len(headers), rows, nxt), (9, [], 3))
        self.assertIsNone(v.parse_table([HDR, SEP], 1))  # start on the separator: nothing follows

    def test_section_markers_are_not_part_of_the_module(self):
        self.assertFalse(hasattr(v, "in_findings_section"))
        self.assertFalse(hasattr(v, "FINDING_SECTION_MARKERS"))


class DiscoverTest(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.root = Path(d.name).resolve()

    def test_discovers_sorted_and_dedupes_overlapping_globs(self):
        for rel in (".planning/REVIEW.md", ".planning/p2/REVIEW.md", ".planning/p1/DOMAIN-AUDIT.md"):
            f = self.root / rel
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text("x")
        with mock.patch.object(v, "ARTIFACT_GLOBS", [".planning/**/REVIEW.md", ".planning/**/REVIEW.md", ".planning/**/DOMAIN-AUDIT.md"]):
            found = v.discover_artifacts(self.root)
        rels = [str(p.relative_to(self.root)) for p in found]
        self.assertEqual(rels, [".planning/REVIEW.md", ".planning/p2/REVIEW.md", ".planning/p1/DOMAIN-AUDIT.md"])

    def test_no_planning_dir(self):
        self.assertEqual(v.discover_artifacts(self.root), [])


class ValidateTableTest(unittest.TestCase):
    def run_table(self, headers, rows, strict=False):
        res = v.ValidationResult()
        v.validate_table(res, "p.md", headers, rows, strict)
        return res

    def hdrs(self):
        return v.split_row(HDR)

    def test_clean_row_has_no_issues(self):
        res = self.run_table(self.hdrs(), [v.split_row(GOOD)])
        self.assertEqual((res.issues, res.tables_checked), ([], 1))

    def test_missing_columns_warn_or_error(self):
        res = self.run_table(["severity", "finding", "evidence"], [])
        self.assertEqual(res.issues[0].level, "warn")
        self.assertIn("domain, scope, confidence, required_action, owner_workflow, blocking_status", res.issues[0].message)
        res = self.run_table(["severity", "finding", "evidence"], [], strict=True)
        self.assertEqual([i.level for i in res.errors], ["error"])
        self.assertEqual(res.warnings, [])

    def test_row_value_checks(self):
        row = ["code", "a.py", "huge", "maybe", "e", "f", "fix", "wf", "sometimes"]
        res = self.run_table(self.hdrs(), [row])
        msgs = [i.message for i in res.issues]
        self.assertEqual(msgs, [
            "row 1: invalid severity 'huge'",
            "row 1: invalid confidence 'maybe'",
            "row 1: invalid blocking_status 'sometimes'",
        ])

    def test_empty_required_fields_and_lowercase_values_ok(self):
        row = ["code", "a.py", "warn", "low", "", " ", "fix", "wf", "Does Not Block"]
        res = self.run_table(self.hdrs(), [row])
        self.assertEqual([i.message for i in res.issues], [
            "row 1: empty required field 'finding'",
            "row 1: empty required field 'evidence'",
        ])

    def test_empty_required_not_checked_when_column_absent(self):
        res = self.run_table(["severity", "scope", "x"], [["info", "s", "y"]])
        self.assertEqual([i.message for i in res.issues if "empty required" in i.message], [])

    def test_placeholder_rows_are_skipped_and_numbering_counts_them(self):
        rows = [["-", "n/a", "TBD", "", "na", "-", "-", "-", "-"], ["code", "a", "BAD", "HIGH", "e", "f", "r", "w", "blocks ship"]]
        res = self.run_table(self.hdrs(), rows)
        self.assertEqual([i.message for i in res.issues], ["row 2: invalid severity 'BAD'"])

    def test_extra_cells_beyond_headers_ignored(self):
        res = self.run_table(self.hdrs(), [v.split_row(GOOD) + ["extra"]])
        self.assertEqual(res.issues, [])


class ValidateRepoTest(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.root = Path(d.name).resolve()
        (self.root / ".planning" / "p").mkdir(parents=True)

    def write(self, name, text):
        f = self.root / ".planning" / "p" / name
        f.write_text(text, encoding="utf-8")
        return f

    def test_tables_inside_and_outside_findings_sections_and_noise(self):
        self.write("REVIEW.md", "\n".join([
            "# R", "intro | with pipe", "| a | b |", "|--|--|",  # table too narrow
            "| only | header | row |", "plain",  # header without separator row
            "## Summary", table(GOOD), "## Findings", table(GOOD, "| c | a | WRONG | HIGH | e | f | r | w | blocks ship |"),
            "| a | b | c |", "|---|---|---|", "| x | y | z |",  # non-finding table
        ]) + "\n")
        res = v.validate_repo(self.root)
        self.assertEqual(res.artifacts_scanned, 1)
        self.assertEqual(res.tables_checked, 2)
        self.assertEqual([i.message for i in res.issues], ["row 2: invalid severity 'WRONG'"])
        self.assertEqual(res.issues[0].path, ".planning/p/REVIEW.md")

    def test_finding_shaped_table_under_any_heading_is_validated(self):
        bad = "| c | a | WRONG | HIGH | e | f | r | w | blocks ship |"
        for heading in ("## Summary", "## Notes", "# Top", "## Findings"):
            with self.subTest(heading=heading):
                self.write("REVIEW.md", f"{heading}\n" + table(bad))
                res = v.validate_repo(self.root)
                self.assertEqual(res.tables_checked, 1)
                self.assertEqual([i.message for i in res.issues], ["row 1: invalid severity 'WRONG'"])
        self.write("REVIEW.md", "## Summary\n| a | b | c |\n|---|---|---|\n| x | y | z |\n")
        self.assertEqual(v.validate_repo(self.root).tables_checked, 0)

    def test_directory_named_like_artifact_is_ignored(self):
        (self.root / ".planning" / "p" / "SECURITY.md").mkdir()
        res = v.validate_repo(self.root)
        self.assertEqual((res.artifacts_scanned, res.tables_checked, res.issues), (0, 0, []))

    def test_undecodable_bytes_are_replaced(self):
        (self.root / ".planning" / "p" / "REVIEW.md").write_bytes(b"\xff\xfe\n" + table(GOOD).encode())
        res = v.validate_repo(self.root, strict=True)
        self.assertEqual((res.artifacts_scanned, res.tables_checked, res.issues), (1, 1, []))


class FormatAndMainTest(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.root = Path(d.name).resolve()
        (self.root / ".planning").mkdir()

    def write(self, text):
        (self.root / ".planning" / "REVIEW.md").write_text(text)

    def run_main(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = v.main(["--root", str(self.root), *argv])
        return rc, out.getvalue()

    def test_format_text_pass_and_issues(self):
        self.write("## Findings\n" + table(GOOD))
        rc, out = self.run_main()
        self.assertEqual(rc, 0)
        self.assertEqual(out.strip(), "Evidence schema validation passed (1 artifacts, 1 finding tables).")
        res = v.ValidationResult(issues=[v.Issue("warn", "a.md", "w"), v.Issue("error", "b.md", "e")], tables_checked=2, artifacts_scanned=3)
        text = v.format_text(res)
        self.assertEqual(text.splitlines(), [
            "Evidence schema validation: 1 warning(s), 1 error(s) (3 artifacts, 2 finding tables).",
            "WARN: a.md — w",
            "ERROR: b.md — e",
        ])

    def test_warn_only_default_exits_zero_json_not_passed(self):
        self.write("## Findings\n" + table("| c | a | BAD | HIGH | e | f | r | w | blocks ship |"))
        rc, out = self.run_main("--json")
        payload = json.loads(out)
        self.assertEqual(rc, 0)
        self.assertEqual((payload["passed"], payload["strict"]), (False, False))
        self.assertEqual(len(payload["warnings"]), 1)
        self.assertEqual(payload["errors"], [])
        rc, out = self.run_main()
        self.assertEqual(rc, 0)
        self.assertIn("WARN: .planning/REVIEW.md", out)

    def test_strict_warnings_become_errors(self):
        self.write("## Findings\n" + table("| c | a | BAD | HIGH | e | f | r | w | blocks ship |"))
        rc, out = self.run_main("--strict", "--json")
        payload = json.loads(out)
        self.assertEqual(rc, 1)
        self.assertEqual((payload["passed"], payload["strict"], len(payload["errors"])), (False, True, 1))
        self.assertEqual(payload["errors"][0]["path"], ".planning/REVIEW.md")

    def test_strict_with_only_warnings_exits_one(self):
        res = v.ValidationResult(issues=[v.Issue("warn", "a", "w")])
        with mock.patch.object(v, "validate_repo", return_value=res), contextlib.redirect_stdout(io.StringIO()) as o:
            self.assertEqual(v.main(["--strict"]), 1)
            self.assertEqual(v.main([]), 0)
            v.main(["--strict", "--json"])
        self.assertIn('"passed": true', o.getvalue())  # json "passed" ignores warnings when strict

    def test_json_output_is_indented_with_two_spaces(self):
        self.write("## Findings\n" + table(GOOD))
        rc, out = self.run_main("--json")
        self.assertEqual(rc, 0)
        self.assertEqual(out, (
            '{\n  "passed": true,\n  "strict": false,\n  "artifacts_scanned": 1,\n'
            '  "tables_checked": 1,\n  "warnings": [],\n  "errors": []\n}\n'
        ))

    def test_clean_json_passes(self):
        self.write("## Findings\n" + table(GOOD))
        rc, out = self.run_main("--json")
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["passed"], True)

    def test_main_uses_sys_argv_when_argv_none(self):
        self.write("x\n")
        out = io.StringIO()
        with mock.patch("sys.argv", ["v", "--root", str(self.root)]), contextlib.redirect_stdout(out):
            self.assertEqual(v.main(), 0)
        self.assertIn("passed (1 artifacts, 0 finding tables)", out.getvalue())

    def test_entrypoint_and_lib_path_handling(self):
        self.write("x\n")
        lib = str(REPO_ROOT / "scripts" / "lib")
        for present in (False, True):
            path = [p for p in sys.path if p != lib]
            if present:
                path.insert(0, lib)
            with mock.patch.object(sys, "path", path), \
                 mock.patch("sys.argv", ["v", "--root", str(self.root)]), \
                 contextlib.redirect_stdout(io.StringIO()) as out:
                with self.assertRaises(SystemExit) as cm:
                    runpy.run_path(str(REPO_ROOT / REL), run_name="__main__")
            self.assertEqual(cm.exception.code, 0)
            self.assertIn("passed", out.getvalue())
            self.assertEqual(path.count(lib), 1)


if __name__ == "__main__":
    unittest.main()

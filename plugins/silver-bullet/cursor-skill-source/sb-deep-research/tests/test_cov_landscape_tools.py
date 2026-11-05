"""Coverage tests for github_skill_retrieval, shortlist_candidates, validate_compare, validate_landscape."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import github_skill_retrieval as gh
import shortlist_candidates as sl
import validate_compare as vc
import validate_landscape as vl


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestGithubRetrieval(unittest.TestCase):
    def test_parse_full_name_forms(self):
        self.assertEqual(gh.parse_github_full_name(" owner/repo "), ("owner", "repo"))
        self.assertEqual(gh.parse_github_full_name("https://github.com/o/r.git"), ("o", "r"))
        self.assertEqual(gh.parse_github_full_name("http://github.com/o/r/tree/main"), ("o", "r"))
        with self.assertRaises(ValueError):
            gh.parse_github_full_name("not a repo")
        with self.assertRaises(ValueError):
            gh.parse_github_full_name("a/b/c")

    def test_resolve_default_branch(self):
        self.assertEqual(gh.resolve_default_branch("o/r"), "main")
        self.assertEqual(gh.resolve_default_branch("o/r", fallback="trunk"), "trunk")
        self.assertEqual(gh.resolve_default_branch("o/r", {"o/r": "dev"}), "dev")
        self.assertEqual(gh.resolve_default_branch("o/x", {"o/r": "dev"}, fallback="f"), "f")
        calls = []
        def fn(owner, repo):
            calls.append((owner, repo))
            return "master"
        self.assertEqual(gh.resolve_default_branch("https://github.com/o/r", fn), "master")
        self.assertEqual(calls, [("o", "r")])

    def test_urls_and_plan(self):
        self.assertEqual(gh.build_skill_md_raw_url("o", "r", "b"),
                         "https://raw.githubusercontent.com/o/r/b/SKILL.md")
        self.assertEqual(gh.naive_skill_md_raw_url("o", "r", "x/S.md"),
                         "https://raw.githubusercontent.com/o/r/main/x/S.md")
        plan = gh.skill_md_retrieval_plan("o/r", {"o/r": "dev"})
        self.assertEqual(plan["default_branch"], "dev")
        self.assertTrue(plan["use_corrected_url"])
        self.assertTrue(plan["skill_md_url"].endswith("/dev/SKILL.md"))
        self.assertTrue(plan["naive_main_url"].endswith("/main/SKILL.md"))
        same = gh.skill_md_retrieval_plan("o/r")
        self.assertFalse(same["use_corrected_url"])
        self.assertEqual(same["full_name"], "o/r")

    def test_enrich_hits(self):
        hits = [{"fullName": "o/r"}, {"full_name": "p/q", "stars": 3}, {"name": "nofull"}]
        out = gh.enrich_github_search_hits(hits, {"o/r": "dev"}, path="sub/SKILL.md")
        self.assertEqual(out[0]["default_branch"], "dev")
        self.assertTrue(out[0]["skill_md_url"].endswith("/dev/sub/SKILL.md"))
        self.assertTrue(out[0]["skill_md_url_corrected"])
        self.assertEqual(out[1]["default_branch"], "main")
        self.assertFalse(out[1]["skill_md_url_corrected"])
        self.assertEqual(out[1]["stars"], 3)
        self.assertEqual(out[2], {"name": "nofull"})
        self.assertNotIn("skill_md_url", out[2])
        self.assertNotIn("default_branch", hits[0])  # input not mutated


class TestShortlist(unittest.TestCase):
    def test_slug(self):
        self.assertEqual(sl._slug("--Hello World!--"), "hello-world")
        self.assertEqual(len(sl._slug("a" * 100)), 64)

    def test_load_jsonl_skips_blank(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "c.jsonl"
            p.write_text('{"a":1}\n\n   \n{"b":2}\n')
            self.assertEqual(sl.load_jsonl(p), [{"a": 1}, {"b": 2}])

    def test_commercial_license(self):
        f = sl._is_commercial_license
        self.assertFalse(f(""))
        self.assertFalse(f("---"))
        self.assertFalse(f("Non-Commercial"))
        self.assertFalse(f("Not Commercial use"))
        self.assertTrue(f("Commercial"))
        self.assertTrue(f("SaaS"))
        self.assertTrue(f("Proprietary EULA"))
        self.assertFalse(f("MIT"))
        self.assertEqual(sl._normalize_license(None), "")

    def test_license_ok(self):
        ok = sl.license_ok
        self.assertTrue(ok({"license": "GPL"}, "mixed"))
        self.assertTrue(ok({"license_type": "Open Source"}, "oss"))
        self.assertTrue(ok({"license": " MIT "}, "oss"))
        self.assertFalse(ok({"license": "Proprietary"}, "oss"))
        self.assertFalse(ok({}, "oss"))
        self.assertTrue(ok({"license": "commercial"}, "commercial"))
        self.assertFalse(ok({"license": "MIT"}, "commercial"))
        self.assertTrue(ok({"license": "MIT"}, "anything-else"))

    def test_score_row(self):
        self.assertEqual(sl.score_row({"score": 3}, []), 3.0)
        self.assertEqual(sl.score_row({"relevance": 2}, []), 2.0)
        self.assertEqual(sl.score_row({"score": None}, []), 0.0)
        self.assertEqual(sl.score_row({"score": 1, "desc": "Has SSO"}, ["sso", "api"]), 3.0)
        self.assertEqual(sl.score_row({"score": 1, "desc": "sso api"}, ["SSO", "API"]), 5.0)

    def test_shortlist_filters_ranks_and_names(self):
        cands = [
            {"name": "Alpha", "score": 1, "license": "MIT"},
            {"name": "Bad-Veto", "score": 9, "license": "MIT"},
            {"solution": "Beta", "score": 2, "license": "Apache", "slug": "custom", "rationale": "why"},
            {"name": "Prop", "score": 5, "license": "Proprietary"},
            {"score": 1.5, "license": "mit"},
            {"name": "Gamma SSO", "score": 0, "license": "mit"},
        ]
        need = {"license_preference": "oss", "hard_vetoes": ["VETO"], "must_haves": ["sso"]}
        out = sl.shortlist(cands, need, 4)
        names = [r["name"] for r in out]
        self.assertEqual(names, ["Beta", "Gamma SSO", "solution-3", "Alpha"])
        self.assertEqual([r["rank"] for r in out], [1, 2, 3, 4])
        self.assertEqual(out[0]["slug"], "custom")
        self.assertEqual(out[0]["rationale"], "why")
        self.assertEqual(out[1]["rationale"], "Top candidate from landscape survey")
        self.assertEqual(out[1]["score"], 2.0)
        self.assertEqual(out[1]["slug"], "gamma-sso")
        self.assertNotIn("Prop", names)
        self.assertNotIn("Bad-Veto", names)

    def test_shortlist_defaults_and_count_limit(self):
        out = sl.shortlist([{"name": "a", "score": 1}, {"name": "b", "score": 2}], {}, 1)
        self.assertEqual([r["name"] for r in out], ["b"])

    def test_main_writes_shortlist(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "c.jsonl").write_text('{"name":"a","score":1}\n{"name":"b","score":2}\n')
            (root / "n.json").write_text("{}")
            out = root / "sub" / "shortlist.json"
            code, stdout, _ = call_main(sl, ["--candidates", str(root / "c.jsonl"),
                                             "--need-profile", str(root / "n.json"),
                                             "--out", str(out), "--count", "2"])
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(stdout), {"status": "ok", "count": 2, "out": str(out)})
            data = json.loads(out.read_text())
            self.assertEqual(data["count"], 2)
            self.assertEqual([s["name"] for s in data["solutions"]], ["b", "a"])

    def test_main_errors_when_too_few(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "c.jsonl").write_text('{"name":"a","score":1}\n')
            (root / "n.json").write_text("{}")
            out = root / "shortlist.json"
            code, stdout, stderr = call_main(sl, ["--candidates", str(root / "c.jsonl"),
                                                  "--need-profile", str(root / "n.json"),
                                                  "--out", str(out)])
            self.assertEqual(code, 1)
            self.assertEqual(stdout, "")
            self.assertIn("shortlist has 1 items, expected 5", stderr)
            self.assertFalse(out.exists())

    def test_run_as_script(self):
        code, _, _ = run_script(SCRIPTS / "shortlist_candidates.py", ["--candidates", "/x"])
        self.assertEqual(code, 2)  # argparse: missing required args


def _mk(root: Path, rel: str, text: str = "x"):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    return p


class TestValidateLandscape(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name) / "run"
        self.root.mkdir()

    def full(self):
        _mk(self.root, "shortlist/shortlist.json", json.dumps({"solutions": [1, 2, 3, 4, 5]}))
        _mk(self.root, "landscape/landscape-report.md")
        for i in range(5):
            _mk(self.root, f"solutions/s{i}/scr.md")
        _mk(self.root, "comparison/comparison.json")
        _mk(self.root, "comparison/run-comparison-matrix.xlsx")
        _mk(self.root, "report.html")

    def test_empty_dir_lists_all_errors(self):
        res = vl.validate(self.root)
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["errors"][:3], [
            "missing shortlist/shortlist.json",
            "missing landscape/landscape-report.md",
            "missing solutions/ directory"])
        self.assertIn("missing comparison/comparison.json", res["errors"])
        self.assertIn("missing comparison/run-comparison-matrix.xlsx", res["errors"])
        self.assertIn("missing report.html", res["errors"])

    def test_pass(self):
        self.full()
        res = vl.validate(self.root)
        self.assertEqual(res, {"status": "pass", "errors": [], "warnings": []})

    def test_wrong_counts(self):
        self.full()
        _mk(self.root, "shortlist/shortlist.json", json.dumps({}))
        (self.root / "solutions" / "s0" / "scr.md").unlink()
        res = vl.validate(self.root)
        self.assertIn("shortlist must have exactly 5 solutions, got 0", res["errors"])
        self.assertIn("expected 5 scr.md files, found 4", res["errors"])

    def test_legacy_xlsx_accepted(self):
        self.full()
        (self.root / "comparison" / "run-comparison-matrix.xlsx").unlink()
        _mk(self.root, "comparison/comparison-matrix.xlsx")
        self.assertEqual(vl.validate(self.root)["status"], "pass")

    def test_missing_xlsx_without_openpyxl_adds_hint(self):
        self.full()
        (self.root / "comparison" / "run-comparison-matrix.xlsx").unlink()
        with mock.patch.object(vl, "openpyxl_importable", return_value=False):
            res = vl.validate(self.root)
        self.assertEqual(len(res["errors"]), 2)
        self.assertIn("openpyxl not installed", res["errors"][1])
        with mock.patch.object(vl, "openpyxl_importable", return_value=True):
            self.assertEqual(len(vl.validate(self.root)["errors"]), 1)

    def test_main_exit_codes(self):
        code, out, _ = call_main(vl, ["--dir", str(self.root)])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["status"], "fail")
        self.full()
        code, out, _ = call_main(vl, ["--dir", str(self.root)])
        self.assertEqual(code, 0)
        code, out, _ = run_script(SCRIPTS / "validate_landscape.py", ["--dir", str(self.root)])
        self.assertEqual(code, 0)


class TestValidateCompare(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name) / "run"
        self.root.mkdir()

    def full(self, names=("a", "b")):
        _mk(self.root, "solutions_requested.json", json.dumps({"solutions": list(names)}))
        for n in names:
            _mk(self.root, f"solutions/{n}/scr.md")
        _mk(self.root, "comparison/comparison.json")
        _mk(self.root, "comparison/run-comparison-matrix.xlsx")
        _mk(self.root, "report.html")

    def test_empty_dir(self):
        res = vc.validate(self.root)
        self.assertEqual(res["status"], "fail")
        self.assertEqual(res["errors"][:2], ["missing solutions_requested.json",
                                             "missing solutions/ directory"])
        self.assertIn("missing report.html", res["errors"])

    def test_pass(self):
        self.full()
        self.assertEqual(vc.validate(self.root), {"status": "pass", "errors": [], "warnings": []})

    def test_names_key_and_too_few(self):
        self.full()
        _mk(self.root, "solutions_requested.json", json.dumps({"names": ["a"]}))
        res = vc.validate(self.root)
        self.assertIn("need N>=2 named solutions, got 1", res["errors"])
        self.assertIn("expected 1 SCR dirs, found 2", res["errors"])

    def test_too_many_is_warning_only(self):
        names = [f"s{i}" for i in range(13)]
        self.full(names)
        res = vc.validate(self.root)
        self.assertEqual(res["status"], "pass")
        self.assertEqual(res["warnings"], ["soft warn: 13 solutions exceeds practical limit of 12"])

    def test_shortlist_forbidden(self):
        self.full()
        _mk(self.root, "shortlist/shortlist.json")
        res = vc.validate(self.root)
        self.assertIn("shortlist.json must not exist in solution-compare mode", res["errors"])

    def test_solutions_dir_without_request_file(self):
        (self.root / "solutions").mkdir()
        res = vc.validate(self.root)
        self.assertEqual(res["errors"][0], "missing solutions_requested.json")
        self.assertNotIn("missing solutions/ directory", res["errors"])

    def test_legacy_xlsx_and_openpyxl_hint(self):
        self.full()
        (self.root / "comparison" / "run-comparison-matrix.xlsx").unlink()
        with mock.patch.object(vc, "openpyxl_importable", return_value=False):
            res = vc.validate(self.root)
            self.assertEqual(len(res["errors"]), 2)
            self.assertIn("openpyxl not installed", res["errors"][1])
        with mock.patch.object(vc, "openpyxl_importable", return_value=True):
            self.assertEqual(len(vc.validate(self.root)["errors"]), 1)
        _mk(self.root, "comparison/comparison-matrix.xlsx")
        self.assertEqual(vc.validate(self.root)["status"], "pass")

    def test_main_exit_codes(self):
        code, out, _ = call_main(vc, ["--dir", str(self.root)])
        self.assertEqual(code, 1)
        self.full()
        code, out, _ = call_main(vc, ["--dir", str(self.root)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["status"], "pass")
        code, _, _ = run_script(SCRIPTS / "validate_compare.py", ["--dir", str(self.root)])
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

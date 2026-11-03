"""Coverage tests for matrix_core, need_profile_personas, compare_solutions, generate_comparison_xlsx."""

import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SCRIPTS, call_main, run_script

import compare_solutions as cs
import generate_comparison_xlsx as gx
import matrix_core as mc
import need_profile_personas as npp
import deps_probe

HAS_OPENPYXL = deps_probe.openpyxl_importable()


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestMatrixCore(unittest.TestCase):
    def test_slug_and_filename_fallbacks(self):
        self.assertEqual(mc.research_dir_slug(Path("/a/b/my-run")), "my-run")
        self.assertEqual(mc.research_dir_slug(Path("/")), "research")
        self.assertEqual(mc.comparison_matrix_xlsx_filename(""), "research-comparison-matrix.xlsx")
        self.assertEqual(mc.comparison_matrix_xlsx_filename("  "), "research-comparison-matrix.xlsx")
        self.assertEqual(mc.comparison_matrix_xlsx_filename("x"), "x-comparison-matrix.xlsx")

    def test_xlsx_path_ignores_report_html(self):
        p = mc.comparison_matrix_xlsx_path(Path("/r/run"), report_html=Path("/z/other.html"))
        self.assertEqual(p, Path("/r/run/comparison/run-comparison-matrix.xlsx"))

    def test_default_spa_report_path(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            # no manifest, no landscape -> report.html
            self.assertEqual(mc.default_spa_report_path(root), root / "report.html")
            # existing landscape report wins without manifest
            (root / "landscape-report.html").write_text("x")
            self.assertEqual(mc.default_spa_report_path(root), root / "landscape-report.html")
            (root / "landscape-report.html").unlink()
            # manifest research type picks landscape even if file absent
            (root / "run_manifest.json").write_text(json.dumps({"research_type": "solution-compare"}))
            self.assertEqual(mc.default_spa_report_path(root), root / "landscape-report.html")
            (root / "run_manifest.json").write_text(json.dumps({"research_type": "general"}))
            self.assertEqual(mc.default_spa_report_path(root), root / "report.html")
            # corrupt manifest is tolerated
            (root / "run_manifest.json").write_text("{not json")
            self.assertEqual(mc.default_spa_report_path(root), root / "report.html")

    def test_href(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "run"
            self.assertIsNone(mc.comparison_matrix_xlsx_href(root))
            (root / "comparison").mkdir(parents=True)
            (root / "comparison" / "run-comparison-matrix.xlsx").write_text("x")
            self.assertEqual(mc.comparison_matrix_xlsx_href(root),
                             "comparison/run-comparison-matrix.xlsx")

    def test_href_falls_back_to_absolute_when_not_relative(self):
        fake = mock.MagicMock()
        fake.is_file.return_value = True
        fake.relative_to.side_effect = ValueError("not relative")
        fake.__str__ = lambda self: "/abs/path.xlsx"
        with mock.patch.object(mc, "comparison_matrix_xlsx_path", return_value=fake):
            self.assertEqual(mc.comparison_matrix_xlsx_href(Path("/r")), "/abs/path.xlsx")

    def test_scoring(self):
        self.assertEqual(mc.priority_weight("Critical"), 5)
        self.assertEqual(mc.priority_weight("unknown"), 1)
        rows = [
            {"type": "category", "name": "c"},
            {"type": "feature", "priority": "Critical", "solutions": {"a": mc.TICK, "b": ""}},
            {"type": "feature", "priority": "Low", "solutions": {"a": mc.TICK, "b": mc.TICK}},
            {"type": "feature", "solutions": None},
            {"type": "feature", "priority": "Medium", "solutions": {"b": "-"}},
        ]
        self.assertEqual(mc.score_solutions_from_rows(rows, ["a", "b"]), {"a": 6, "b": 1})


class TestPersonas(unittest.TestCase):
    def test_catalog_and_get(self):
        self.assertEqual(npp.list_persona_ids(), ["enterprise", "regulated", "startup"])
        self.assertIsNone(npp.get_persona(""))
        self.assertIsNone(npp.get_persona("nope"))
        p = npp.get_persona("startup")
        p["label"] = "mutated"
        self.assertNotEqual(npp.get_persona("startup")["label"], "mutated")

    def test_get_persona_non_dict_entry(self):
        with mock.patch.object(npp, "_catalog", return_value={"odd": "string"}):
            self.assertIsNone(npp.get_persona("odd"))

    def test_catalog_rejects_non_object_personas(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "p.json"
            f.write_text(json.dumps({"personas": ["a"]}))
            npp._catalog.cache_clear()
            try:
                with mock.patch.object(npp, "_PERSONAS_PATH", f):
                    with self.assertRaises(ValueError):
                        npp._catalog()
                f.write_text(json.dumps({}))
                npp._catalog.cache_clear()
                with mock.patch.object(npp, "_PERSONAS_PATH", f):
                    self.assertEqual(npp._catalog(), {})
            finally:
                npp._catalog.cache_clear()

    def test_max_priority(self):
        self.assertEqual(npp.max_priority("High", "Low"), "High")
        self.assertEqual(npp.max_priority("Low", "Critical"), "Critical")
        self.assertEqual(npp.max_priority("High", "High"), "High")
        self.assertEqual(npp.max_priority("Bogus", "Low"), "Bogus")  # both weigh 1; first wins

    def test_apply_persona_priority_paths(self):
        f = npp.apply_persona_priority
        self.assertEqual(f("x", "c", "Low", {}), "Low")
        self.assertEqual(f("x", "c", "Low", {"persona_id": "nope"}), "Low")
        need = {"persona_id": "startup"}
        # feature override raises, never lowers
        self.assertEqual(f("Self-serve signup", None, "Low", need), "Critical")
        self.assertEqual(f("Self-serve signup", None, "Critical", need), "Critical")
        # category floor: exact, suffix, substring, no match
        self.assertEqual(f("x", "Time to value", "Low", need), "Critical")
        self.assertEqual(f("x", "Core Time to value", "Low", need), "Critical")
        self.assertEqual(f("x", "Developer Experience Tools", "Low", need), "High")
        self.assertEqual(f("x", "Unrelated", "Low", need), "Low")
        self.assertEqual(f("x", "Developer Experience", "Very High", need), "Very High")

    def test_persona_without_override_or_floor_maps(self):
        with mock.patch.object(npp, "get_persona", return_value={"label": "bare"}):
            self.assertEqual(npp.apply_persona_priority("f", "c", "Low", {"persona_id": "z"}), "Low")


def _write_features(root: Path, name: str, data):
    d = root / "solutions" / name
    d.mkdir(parents=True)
    (d / "features.json").write_text(json.dumps(data))


class TestHelpers(unittest.TestCase):
    def test_slug_and_feature_name(self):
        self.assertEqual(cs._slug(" Hello, World! "), "hello-world")
        self.assertEqual(cs._feature_name("  SSO "), "SSO")
        self.assertIsNone(cs._feature_name("   "))
        self.assertEqual(cs._feature_name({"name": " A "}), "A")
        self.assertEqual(cs._feature_name({"feature": "B"}), "B")
        self.assertIsNone(cs._feature_name({"name": ""}))
        self.assertIsNone(cs._feature_name(42))

    def test_load_features(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            self.assertEqual(cs.load_features(root / "missing"), {})
            _write_features(root, "b-dir", {"solution_name": "Beta"})
            _write_features(root, "a-dir", {})
            (root / "solutions" / "empty").mkdir()
            (root / "solutions" / "stray.txt").write_text("x")
            got = cs.load_features(root / "solutions")
            self.assertEqual(list(got), ["a-dir", "Beta"])

    def test_priority_for_feature(self):
        need = {"must_haves": [" SSO "], "nice_to_haves": ["Audit"], "weights_override": {"Logs": "Low"}}
        f = cs.priority_for_feature
        self.assertEqual(f("sso", need), "Critical")
        self.assertEqual(f("AUDIT", need), "High")
        self.assertEqual(f("Other", need), "Medium")
        self.assertEqual(f("Logs", need), "Low")
        self.assertEqual(f("x", {"must_haves": None, "nice_to_haves": None}), "Medium")
        self.assertEqual(f("SSO", {"persona_id": "enterprise"}, "Identity and access"), "Critical")


class TestBuildComparison(unittest.TestCase):
    def test_build_comparison_semantics(self):
        a = {"categories": [
                {"name": "Sec", "features": ["SSO", {"name": "Audit", "supported": False}, "  ", 3]},
                {"features": [{"feature": "Export", "present": True}]},
             ],
             "features": ["Loose", "SSO"]}
        b = {"categories": [{"name": "Sec", "features": [{"name": "SSO"}]}],
             "features": [{"name": "Loose", "supported": False}, {"name": "Audit"}, {"name": ""}]}
        need = {"must_haves": ["sso"], "constraints": ["c1"], "research_type": "rt",
                "license_preference": "oss"}
        comp = cs.build_comparison_json({"A": a, "B": b}, need)
        self.assertEqual(comp["categories"], ["Sec", "General", "Capabilities"])
        rows = {r["name"]: r for r in comp["rows"] if r["type"] == "feature"}
        self.assertEqual(rows["SSO"]["priority"], "Critical")
        self.assertEqual(rows["SSO"]["solutions"], {"A": mc.TICK, "B": mc.TICK})
        self.assertEqual(rows["Audit"]["solutions"], {"A": "", "B": mc.TICK})  # A marks it unsupported
        self.assertEqual(rows["Export"]["solutions"], {"A": mc.TICK, "B": ""})
        self.assertEqual(rows["Loose"]["solutions"], {"A": mc.TICK, "B": ""})
        self.assertEqual(comp["research_type"], "rt")
        self.assertEqual(comp["license_preference"], "oss")
        self.assertEqual(comp["caveats"], ["c1"])
        self.assertEqual([r["solution"] for r in comp["rankings"]], ["A", "B"])
        self.assertEqual([r["rank"] for r in comp["rankings"]], [1, 2])
        self.assertEqual(comp["winner"], "A")
        self.assertEqual(comp["runner_up"], "B")

    def test_single_and_zero_solutions(self):
        one = cs.build_comparison_json({"A": {"features": ["X"]}}, {})
        self.assertEqual(one["winner"], "A")
        self.assertIsNone(one["runner_up"])
        self.assertEqual(one["caveats"], [])
        none = cs.build_comparison_json({}, {})
        self.assertIsNone(none["winner"])
        self.assertEqual(none["rankings"], [])


class TestMarkdown(unittest.TestCase):
    def test_matrix_markdown(self):
        comp = {
            "rankings": [{"solution": "A", "rank": 1, "score": 5}, {"solution": "B", "rank": 2, "score": 0}],
            "rows": [{"type": "category", "name": "Sec"},
                     {"type": "feature", "name": "SSO", "priority": "Critical",
                      "solutions": {"A": mc.TICK}}],
        }
        md = cs.matrix_markdown(comp)
        self.assertIn("| Feature | Priority | A | B |", md)
        self.assertIn("|---------|----------|---|---|", md)
        self.assertIn("| **Sec** | |  |  |", md)
        self.assertIn(f"| SSO | Critical | {mc.TICK} |  |", md)
        self.assertIn("- #1 **A** — score 5", md)
        self.assertTrue(md.endswith("\n"))
        self.assertIn("# Comparison Matrix", cs.matrix_markdown({}))


class TestCompareSolutions(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name)
        (self.root / "need_profile.json").write_text(json.dumps({"must_haves": ["SSO"]}))
        _write_features(self.root, "a", {"solution_name": "A", "features": ["SSO", "API"]})
        _write_features(self.root, "b", {"solution_name": "B", "features": ["API"]})

    def test_needs_two_solutions(self):
        import shutil
        shutil.rmtree(self.root / "solutions" / "b")
        with self.assertRaises(ValueError):
            cs.compare_solutions(self.root, emit_xlsx=False)

    def test_writes_outputs_without_xlsx(self):
        res = cs.compare_solutions(self.root, emit_xlsx=False)
        self.assertEqual(res, {"status": "ok", "winner": "A"})
        comp = json.loads((self.root / "comparison" / "comparison.json").read_text())
        self.assertEqual(comp["winner"], "A")
        self.assertIn("| SSO | Critical |", (self.root / "comparison" / "comparison-matrix.md").read_text())

    def test_explicit_need_profile_path(self):
        other = self.root / "elsewhere.json"
        other.write_text(json.dumps({"must_haves": ["API"]}))
        cs.compare_solutions(self.root, need_profile=other, emit_xlsx=False)
        comp = json.loads((self.root / "comparison" / "comparison.json").read_text())
        prios = {r["name"]: r["priority"] for r in comp["rows"] if r["type"] == "feature"}
        self.assertEqual(prios["API"], "Critical")

    def test_category_pack_excludes_solutions(self):
        pack_mod = types.ModuleType("category_pack")
        pack_mod.resolve_pack_from_need = lambda need: {"id": "p"}
        pack_mod.get_hard_exclusion_slugs = lambda pack, need: ["B", "", None]
        _write_features(self.root, "c", {"solution_name": "C", "features": ["API"]})
        with mock.patch.dict(sys.modules, {"category_pack": pack_mod}):
            cs.compare_solutions(self.root, emit_xlsx=False)
        comp = json.loads((self.root / "comparison" / "comparison.json").read_text())
        self.assertEqual(sorted(r["solution"] for r in comp["rankings"]), ["A", "C"])

    def test_category_pack_without_pack_or_exclusions_keeps_all(self):
        pack_mod = types.ModuleType("category_pack")
        pack_mod.resolve_pack_from_need = lambda need: None
        pack_mod.get_hard_exclusion_slugs = lambda pack, need: ["B"]
        with mock.patch.dict(sys.modules, {"category_pack": pack_mod}):
            cs.compare_solutions(self.root, emit_xlsx=False)
        comp = json.loads((self.root / "comparison" / "comparison.json").read_text())
        self.assertEqual(len(comp["rankings"]), 2)
        pack_mod.resolve_pack_from_need = lambda need: {"id": "p"}
        pack_mod.get_hard_exclusion_slugs = lambda pack, need: []
        with mock.patch.dict(sys.modules, {"category_pack": pack_mod}):
            cs.compare_solutions(self.root, emit_xlsx=False)
        comp = json.loads((self.root / "comparison" / "comparison.json").read_text())
        self.assertEqual(len(comp["rankings"]), 2)

    def test_category_pack_errors_are_swallowed(self):
        pack_mod = types.ModuleType("category_pack")
        def boom(need):
            raise RuntimeError("bad pack")
        pack_mod.resolve_pack_from_need = boom
        pack_mod.get_hard_exclusion_slugs = lambda pack, need: []
        with mock.patch.dict(sys.modules, {"category_pack": pack_mod}):
            res = cs.compare_solutions(self.root, emit_xlsx=False)
        self.assertEqual(res["status"], "ok")

    def test_xlsx_import_error_becomes_runtime_error(self):
        with mock.patch.object(gx, "generate_comparison_xlsx", side_effect=ImportError("no openpyxl")):
            with self.assertRaises(RuntimeError) as cm:
                cs.compare_solutions(self.root)
        self.assertIn("openpyxl is required", str(cm.exception))

    def test_xlsx_error_status_becomes_runtime_error(self):
        with mock.patch.object(gx, "generate_comparison_xlsx",
                               return_value={"status": "error", "reason": "kaput"}):
            with self.assertRaisesRegex(RuntimeError, "kaput"):
                cs.compare_solutions(self.root)
        with mock.patch.object(gx, "generate_comparison_xlsx", return_value={"status": "error"}):
            with self.assertRaisesRegex(RuntimeError, "xlsx generation failed"):
                cs.compare_solutions(self.root)

    def test_xlsx_ok_reports_output(self):
        with mock.patch.object(gx, "generate_comparison_xlsx",
                               return_value={"status": "ok", "output": "/o.xlsx"}) as g:
            res = cs.compare_solutions(self.root)
        g.assert_called_once_with(self.root)
        self.assertEqual(res, {"status": "ok", "winner": "A", "xlsx": "/o.xlsx"})

    def test_main_success_and_failure(self):
        code, out, _ = call_main(cs, ["--dir", str(self.root), "--no-emit-xlsx"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["winner"], "A")
        need = self.root / "np.json"
        need.write_text("{}")
        code, out, _ = call_main(cs, ["--dir", str(self.root), "--no-emit-xlsx",
                                      "--need-profile", str(need)])
        self.assertEqual(code, 0)
        import shutil
        shutil.rmtree(self.root / "solutions" / "b")
        code, out, _ = call_main(cs, ["--dir", str(self.root), "--no-emit-xlsx"])
        self.assertEqual(out, "")
        self.assertIn("Need at least 2 solutions", str(code))

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "compare_solutions.py",
                                  ["--dir", str(self.root), "--no-emit-xlsx"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["status"], "ok")


def _comparison():
    return {
        "rankings": [{"solution": "A", "score": 5, "rank": 1}, {"solution": "B", "score": 0, "rank": 2}],
        "rows": [
            {"type": "category", "name": "Sec"},
            {"type": "feature", "name": "SSO", "priority": "Critical", "solutions": {"A": mc.TICK, "B": ""}},
            {"type": "feature", "name": "", "priority": "Low", "solutions": {}},
            {"type": "other"},
            {"type": "category", "name": "Empty"},
            {"type": "category"},
            {"type": "feature", "name": "API", "solutions": {"A": mc.TICK, "B": mc.TICK}},
        ],
    }


class TestBuilderConfig(unittest.TestCase):
    def test_solution_order(self):
        self.assertEqual(gx._solution_order({"rankings": [{"solution": "A"}, {"solution": ""}, {}]}), ["A"])
        self.assertEqual(gx._solution_order({"rows": [
            {"type": "category"}, {"type": "feature", "solutions": {}},
            {"type": "feature", "solutions": {"X": "", "Y": ""}}]}), ["X", "Y"])
        self.assertEqual(gx._solution_order({}), [])

    def test_config_mapping(self):
        cfg = gx.comparison_to_builder_config(_comparison(), {"category": "IDP", "persona_id": "startup"})
        self.assertEqual(cfg["title"], "IDP (startup) — Capability Comparison Matrix")
        self.assertEqual(cfg["categories"], [
            {"name": "Sec", "features": [{"name": "SSO", "priority": "Critical"}]},
            {"name": "General", "features": [{"name": "API", "priority": "Medium"}]},
        ])
        self.assertEqual(cfg["platforms"], [{"name": "A", "features": ["SSO", "API"]},
                                            {"name": "B", "features": ["API"]}])

    def test_default_title(self):
        cfg = gx.comparison_to_builder_config({}, {})
        self.assertEqual(cfg["title"], "Solution — Capability Comparison Matrix")
        self.assertEqual(cfg["categories"], [])
        self.assertEqual(cfg["platforms"], [])


class TestGenerateXlsx(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.root = Path(self._td.name) / "run"
        (self.root / "comparison").mkdir(parents=True)
        (self.root / "comparison" / "comparison.json").write_text(json.dumps(_comparison()))

    def test_empty_platforms_and_categories_rejected(self):
        (self.root / "comparison" / "comparison.json").write_text(json.dumps({"rows": []}))
        with self.assertRaisesRegex(ValueError, "no solution columns"):
            gx.generate_comparison_xlsx(self.root)
        (self.root / "comparison" / "comparison.json").write_text(json.dumps({
            "rankings": [{"solution": "A"}], "rows": []}))
        with self.assertRaisesRegex(ValueError, "no feature rows"):
            gx.generate_comparison_xlsx(self.root)

    def test_build_reorder_and_cleanup(self):
        calls = {}
        def fake_build(config, path):
            calls["build"] = (config, path)
            Path(path).write_text("built")
            return {"platform_names": ["A", "B"], "features": 2}
        def fake_reorder(src, dst):
            calls["reorder"] = (src, dst)
            Path(dst).write_text("reordered")
            return {"moved": True}
        with mock.patch.object(gx, "build_matrix", fake_build), \
                mock.patch.object(gx, "reorder_columns_by_score", fake_reorder):
            res = gx.generate_comparison_xlsx(self.root)
        out = self.root / "comparison" / "run-comparison-matrix.xlsx"
        self.assertEqual(res, {"status": "ok", "output": str(out), "platforms": ["A", "B"],
                               "features": 2, "reorder": {"moved": True}})
        self.assertEqual(out.read_text(), "reordered")
        self.assertFalse(out.with_suffix(".tmp.xlsx").exists())

    def test_no_reorder_and_single_platform_just_move(self):
        def fake_build(config, path):
            Path(path).write_text("built")
            return {}
        with mock.patch.object(gx, "build_matrix", fake_build), \
                mock.patch.object(gx, "reorder_columns_by_score") as reorder:
            res = gx.generate_comparison_xlsx(self.root, reorder=False,
                                              out_path=self.root / "o" / "x.xlsx",
                                              need_profile_path=self.root / "absent.json")
            reorder.assert_not_called()
        self.assertEqual((self.root / "o" / "x.xlsx").read_text(), "built")
        self.assertEqual(res["platforms"], [])
        self.assertEqual(res["features"], 0)
        self.assertEqual(res["reorder"], {})

    def test_failed_build_cleans_temp_file(self):
        def fake_build(config, path):
            Path(path).write_text("partial")
            raise RuntimeError("boom")
        with mock.patch.object(gx, "build_matrix", fake_build):
            with self.assertRaisesRegex(RuntimeError, "boom"):
                gx.generate_comparison_xlsx(self.root)
        self.assertEqual(list((self.root / "comparison").glob("*.tmp.xlsx")), [])

    def test_need_profile_is_read(self):
        (self.root / "need_profile.json").write_text(json.dumps({"category": "Zed"}))
        seen = {}
        def fake_build(config, path):
            seen["title"] = config["title"]
            Path(path).write_text("b")
            return {}
        with mock.patch.object(gx, "build_matrix", fake_build), \
                mock.patch.object(gx, "reorder_columns_by_score", return_value={}):
            gx.generate_comparison_xlsx(self.root)
        self.assertTrue(seen["title"].startswith("Zed"))

    @unittest.skipUnless(HAS_OPENPYXL, "openpyxl not installed")
    def test_real_workbook_roundtrip(self):
        import openpyxl
        res = gx.generate_comparison_xlsx(self.root)
        wb = openpyxl.load_workbook(res["output"])
        self.assertTrue(wb.sheetnames)

    def test_main_ok_error_and_script(self):
        with mock.patch.object(gx, "generate_comparison_xlsx", return_value={"status": "ok"}) as g:
            argv = ["--dir", str(self.root), "--comparison", "c.json", "--need-profile", "n.json",
                    "--out", "o.xlsx", "--report-html", "r.html", "--no-reorder"]
            import io, contextlib
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(gx.main(argv), 0)
            kw = g.call_args.kwargs
            self.assertEqual(kw["comparison_path"], Path("c.json"))
            self.assertEqual(kw["need_profile_path"], Path("n.json"))
            self.assertEqual(kw["out_path"], Path("o.xlsx"))
            self.assertEqual(kw["report_html"], Path("r.html"))
            self.assertFalse(kw["reorder"])
            self.assertEqual(json.loads(out.getvalue()), {"status": "ok"})
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(gx.main(["--dir", str(self.root)]), 0)
            kw = g.call_args.kwargs
            self.assertIsNone(kw["comparison_path"])
            self.assertTrue(kw["reorder"])
        err = io.StringIO()
        with mock.patch.object(gx, "generate_comparison_xlsx", side_effect=ValueError("bad")), \
                contextlib.redirect_stderr(err):
            self.assertEqual(gx.main(["--dir", str(self.root)]), 1)
        self.assertEqual(json.loads(err.getvalue()), {"status": "error", "reason": "bad"})
        code, _, stderr = run_script(SCRIPTS / "generate_comparison_xlsx.py", ["--dir", "/nonexistent-dir"])
        self.assertEqual(code, 1)
        self.assertIn('"status": "error"', stderr)


if __name__ == "__main__":
    unittest.main()

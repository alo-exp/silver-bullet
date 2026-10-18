"""Coverage tests for matrix_ops (real openpyxl workbooks in temp dirs)."""

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import covhelp
from covhelp import SAMPLE_CONFIG, SCRIPTS, build_sample_matrix, call_main, run_script

import deps_probe
import matrix_ops as mo

HAS_OPENPYXL = deps_probe.openpyxl_importable()
TICK = "✔"
DASH = "—"


def setUpModule():
    covhelp.block_network()


def tearDownModule():
    covhelp.unblock_network()


class TestGuard(unittest.TestCase):
    @unittest.skipUnless(HAS_OPENPYXL, "openpyxl not installed")
    def test_import_error_and_idempotent_load(self):
        with mock.patch.object(mo, "openpyxl", None), mock.patch.dict(sys.modules, {"openpyxl": None}):
            with self.assertRaises(ImportError) as ctx:
                mo._require_openpyxl()
        self.assertIn("openpyxl is required for matrix operations", str(ctx.exception))
        mo._require_openpyxl()
        self.assertIsNotNone(mo.openpyxl)
        mo._require_openpyxl()


@unittest.skipUnless(HAS_OPENPYXL, "openpyxl not installed")
class XlsxCase(unittest.TestCase):
    def setUp(self):
        mo._require_openpyxl()
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.dir = Path(self._td.name)
        self.src = self.dir / "src.xlsx"
        self.out = self.dir / "out.xlsx"
        build_sample_matrix(self.src)

    def load(self, path=None, data_only=False):
        return mo.openpyxl.load_workbook(path or self.out, data_only=data_only)

    def make_no_title(self, path=None):
        """Matrix whose row 1 is the header row (no title row)."""
        wb = mo.openpyxl.Workbook()
        ws = wb.active
        ws.append(["Capability / Feature", "Priority", "P1", "P2"])
        ws.append(["Total Capabilities", DASH, None, None])
        ws.append(["Score", DASH, None, None])
        ws.append(["Cat A", None, None, None])
        ws.append(["F1", "High", TICK, None])
        ws.append(["F2", "Low", None, TICK])
        ws.append(["Cat B", DASH, None, None])
        ws.append(["F3", "Critical", TICK, TICK])
        p = path or (self.dir / "notitle.xlsx")
        wb.save(p)
        return p


class TestHelpers(XlsxCase):
    def test_layout_detection(self):
        ws = self.load(self.src).active
        L = mo._Layout(ws)
        self.assertEqual((L.title_row, L.header_row, L.total_row, L.score_row, L.data_start), (1, 2, 3, 4, 5))
        self.assertEqual(L.freeze_pane, "A5")
        ws2 = self.load(self.make_no_title()).active
        L2 = mo._Layout(ws2)
        self.assertEqual((L2.title_row, L2.header_row, L2.total_row, L2.score_row, L2.data_start),
                         (None, 1, 2, 3, 4))
        self.assertEqual(L2.freeze_pane, "A4")

    def test_row_type(self):
        ws = self.load(self.make_no_title()).active
        self.assertEqual(mo._row_type(ws, 4), mo.RowType.CATEGORY)
        self.assertEqual(mo._row_type(ws, 5), mo.RowType.FEATURE)
        self.assertEqual(mo._row_type(ws, 7), mo.RowType.CATEGORY)  # dash priority = still a heading
        self.assertIsNone(mo._row_type(ws, 20))

    def test_clone_style(self):
        ws = self.load(self.src).active
        mo._clone_style(ws["A1"], ws["Z1"])
        self.assertEqual(ws["Z1"].fill.fgColor.rgb, ws["A1"].fill.fgColor.rgb)
        self.assertTrue(ws["Z1"].font.bold)
        ws["A6"].number_format = "0.00"
        mo._clone_style(ws["A6"], ws["Z6"])
        self.assertEqual(ws["Z6"].number_format, "0.00")

    def test_clone_style_skips_missing_or_falsy_attributes(self):
        ws = self.load(self.src).active
        dst = ws["Z2"]
        before = (dst.font.name, dst.font.sz, dst.font.bold, dst.fill.fgColor.rgb)
        src = mock.MagicMock(spec=["number_format"])
        src.number_format = "0.0"
        mo._clone_style(src, dst)  # no style attributes on the source at all
        self.assertEqual(dst.number_format, "0.0")
        self.assertEqual((dst.font.name, dst.font.sz, dst.font.bold, dst.fill.fgColor.rgb), before)

    def test_columns_and_lookups(self):
        ws = self.load(self.src).active
        L = mo._Layout(ws)
        self.assertEqual(mo._last_plat_col(ws, L), 5)
        self.assertEqual(mo._platform_cols(ws, L), {"Alpha": 3, "Beta": 4, "Gamma": 5})
        self.assertEqual(mo._all_features(ws, L), ["SSO", "Audit", "API", "CLI"])
        cats = mo._all_categories(ws, L)
        self.assertEqual([c["name"] for c in cats], ["Sec", "Ops"])
        self.assertEqual(cats[0]["start_row"], 5)
        self.assertEqual(cats[0]["end_row"], 7)
        self.assertEqual(cats[1]["features"][0], {"name": "API", "priority": "Medium", "row": 9})

    def test_features_before_first_category_are_ignored_by_category_scan(self):
        wb = mo.openpyxl.Workbook()
        ws = wb.active
        ws.append(["Capability / Feature", "Priority", "P1"])
        ws.append(["Total", DASH, None])
        ws.append(["Score", DASH, None])
        ws.append(["Orphan", "High", TICK])
        ws.append(["Cat", None, None])
        L = mo._Layout(ws)
        self.assertEqual([c["name"] for c in mo._all_categories(ws, L)], ["Cat"])
        self.assertEqual(mo._all_features(ws, L), ["Orphan"])

    def test_merge_helpers(self):
        wb = self.load(self.src)
        ws = wb.active
        L = mo._Layout(ws)
        saved = mo._unmerge_all(ws)
        self.assertEqual(sorted(saved), ["A1:E1", "A5:E5", "A8:E8"])
        self.assertEqual(list(ws.merged_cells.ranges), [])
        mo._remerge_all(ws, 5, L)
        self.assertEqual(sorted(str(r) for r in ws.merged_cells.ranges), ["A1:E1", "A5:E5", "A8:E8"])
        # no title row: only category headings are merged
        ws2 = self.load(self.make_no_title()).active
        L2 = mo._Layout(ws2)
        mo._remerge_all(ws2, 4, L2)
        self.assertEqual(sorted(str(r) for r in ws2.merged_cells.ranges), ["A4:D4", "A7:D7"])

    def test_formulas_depend_on_layout(self):
        ws = self.load(self.make_no_title()).active
        L = mo._Layout(ws)
        self.assertEqual(mo._countif("C", L), '=COUNTIF(C4:C1048576,"✔")')
        self.assertIn("$B$4:$B$1048576", mo._score_formula("C", L))
        self.assertEqual(mo._score_formula("C", L).count("COUNTIFS"), 5)

    def test_scores_orphans_styles(self):
        ws = self.load(self.src).active
        L = mo._Layout(ws)
        self.assertEqual(mo._compute_score(ws, 3, L), 5 + 2)       # Alpha: SSO(Critical) + API(Medium)
        self.assertEqual(mo._compute_score(ws, 4, L), 5 + 3 + 2 + 1)
        self.assertEqual(mo._compute_score(ws, 5, L), 0)
        self.assertEqual(mo._validate_no_orphans(ws, {"SSO", "Nope", "Also"}, L), ["Also", "Nope"])
        styles = mo._cache_col_styles(ws, 3)
        self.assertEqual(len(styles), ws.max_row)
        self.assertEqual(set(styles[0]), {"font", "fill", "border", "alignment", "protection"})
        mo._apply_col_styles(ws, 6, styles)
        self.assertEqual(ws.cell(2, 6).fill.fgColor.rgb, ws.cell(2, 3).fill.fgColor.rgb)

    def test_backfill_and_row_roundtrip(self):
        ws = self.load(self.src).active
        L = mo._Layout(ws)
        ws.cell(3, 3).value = "stale"
        mo._backfill_formulas(ws, 4, L)
        self.assertEqual(ws.cell(3, 3).value, mo._countif("C", L))
        self.assertEqual(ws.cell(4, 4).value, mo._score_formula("D", L))
        rd = mo._read_row_data(ws, 6, 5)
        self.assertEqual(rd["values"][:2], ["SSO", "Critical"])
        self.assertEqual(rd["row_type"], mo.RowType.FEATURE)
        mo._write_row_data(ws, 30, rd)
        self.assertEqual(ws.cell(30, 1).value, "SSO")
        self.assertEqual(ws.cell(30, 2).fill.fgColor.rgb, ws.cell(6, 2).fill.fgColor.rgb)
        # short or empty style lists leave cells unstyled
        mo._write_row_data(ws, 31, {"values": ["x", "y", "z"], "styles": [{}]})
        self.assertEqual([ws.cell(31, c).value for c in (1, 2, 3)], ["x", "y", "z"])


class TestAddPlatform(XlsxCase):
    def test_basic(self):
        res = mo.add_platform(str(self.src), str(self.out), "Delta",
                              {"SSO": True, "Audit": False, "Ghost": True})
        self.assertEqual(res, {"platform_col": 6, "ticks_applied": 1, "new_rows_added": 0,
                               "orphans": ["Ghost"], "total_features": 4})
        ws = self.load().active
        self.assertEqual(ws.cell(2, 6).value, "Delta")
        self.assertEqual(ws.cell(3, 6).value, mo._countif("F", mo._Layout(ws)))
        self.assertEqual(ws.cell(6, 6).value, TICK)
        self.assertIsNone(ws.cell(7, 6).value)
        self.assertIsNone(ws.cell(5, 6).value)  # category row
        self.assertEqual(ws.freeze_panes, "A5")
        self.assertEqual(ws.auto_filter.ref, "A2:F2")
        self.assertIn("A1:F1", [str(r) for r in ws.merged_cells.ranges])
        self.assertIn("A5:F5", [str(r) for r in ws.merged_cells.ranges])

    def test_no_title_layout_and_no_autofilter(self):
        src = self.make_no_title()
        res = mo.add_platform(str(src), str(self.out), "P3", {"F1": True, "F3": True})
        self.assertEqual(res["platform_col"], 5)
        self.assertEqual(res["ticks_applied"], 2)
        ws = self.load().active
        self.assertEqual(ws.cell(1, 5).value, "P3")
        self.assertEqual(ws.cell(5, 5).value, TICK)
        self.assertEqual(ws.freeze_panes, "A4")
        self.assertIsNone(ws.auto_filter.ref)

    def test_new_rows_inserted_at_end_of_categories(self):
        new_rows = [
            {"category": "Sec", "feature": "MFA", "priority": "Very High"},
            {"category": "Ops", "feature": "Webhooks", "ticked": False},
            {"category": "Missing", "feature": "Lost"},
        ]
        features = {"SSO": True}
        res = mo.add_platform(str(self.src), str(self.out), "Delta", features, new_rows)
        self.assertEqual(res["new_rows_added"], 2)
        self.assertEqual(res["total_features"], 6)
        self.assertEqual(features["MFA"], True)
        self.assertEqual(features["Webhooks"], False)
        self.assertNotIn("Lost", features)
        ws = self.load().active
        col_a = [ws.cell(r, 1).value for r in range(5, ws.max_row + 1)]
        self.assertEqual(col_a, ["Sec", "SSO", "Audit", "MFA", "Ops", "API", "CLI", "Webhooks"])
        self.assertEqual(ws.cell(8, 2).value, "Very High")
        self.assertEqual(ws.cell(8, 6).value, TICK)       # MFA ticked for the new platform
        self.assertIsNone(ws.cell(12, 6).value)           # Webhooks not ticked
        self.assertEqual(ws.cell(6, 6).value, TICK)       # SSO

    def test_new_rows_default_priority_and_ticked(self):
        res = mo.add_platform(str(self.src), str(self.out), "D", {},
                              [{"category": "Sec", "feature": "X"}])
        self.assertEqual(res["new_rows_added"], 1)
        ws = self.load().active
        self.assertEqual(ws.cell(8, 2).value, "Medium")
        self.assertEqual(ws.cell(8, 6).value, TICK)


class TestReorderColumns(XlsxCase):
    def test_sorted_by_score(self):
        res = mo.reorder_columns_by_score(str(self.src), str(self.out))
        self.assertEqual(res, {"order": ["Beta", "Alpha", "Gamma"], "scores": {"Beta": 11, "Alpha": 7, "Gamma": 0}})
        ws = self.load().active
        self.assertEqual([ws.cell(2, c).value for c in (3, 4, 5)], ["Beta", "Alpha", "Gamma"])
        self.assertEqual(ws.cell(7, 3).value, TICK)       # Beta has Audit
        self.assertEqual(ws.cell(7, 4).value, DASH)       # Alpha does not
        self.assertEqual(ws.cell(3, 4).value, mo._countif("D", mo._Layout(ws)))
        self.assertEqual(ws.freeze_panes, "A5")
        self.assertIn("A1:E1", [str(r) for r in ws.merged_cells.ranges])

    def test_no_title_layout(self):
        res = mo.reorder_columns_by_score(str(self.make_no_title()), str(self.out))
        self.assertEqual(res, {"order": ["P1", "P2"], "scores": {"P1": 8, "P2": 6}})
        ws = self.load().active
        self.assertEqual(ws.freeze_panes, "A4")
        self.assertEqual(ws.cell(2, 3).value, mo._countif("C", mo._Layout(ws)))

    def test_ties_keep_original_order(self):
        res = mo.reorder_columns_by_score(str(self.src), str(self.out))
        again = mo.reorder_columns_by_score(str(self.out), str(self.dir / "again.xlsx"))
        self.assertEqual(again["order"], res["order"])
        wb = mo.openpyxl.Workbook()
        ws = wb.active
        ws.append(["Capability / Feature", "Priority", "A", "B"])
        ws.append(["Total", DASH, None, None])
        ws.append(["Score", DASH, None, None])
        ws.append(["Cat", None, None, None])
        ws.append(["F", "High", TICK, TICK])
        tie = self.dir / "tie.xlsx"
        wb.save(tie)
        self.assertEqual(mo.reorder_columns_by_score(str(tie), str(self.out))["order"], ["A", "B"])

    def test_no_platforms(self):
        wb = mo.openpyxl.Workbook()
        ws = wb.active
        ws.append(["Capability / Feature", "Priority"])
        p = self.dir / "noplat.xlsx"
        wb.save(p)
        res = mo.reorder_columns_by_score(str(p), str(self.out))
        self.assertEqual(res, {"order": [], "scores": {}})
        self.assertTrue(self.out.exists())


class TestCombo(XlsxCase):
    def test_missing_platforms(self):
        res = mo.create_combo_column(str(self.src), str(self.out), "A+Z", "Alpha", "Zed")
        self.assertEqual(res, {"error": "Platform(s) not found: ['Zed']"})
        res = mo.create_combo_column(str(self.src), str(self.out), "A+Z", "Y", "Zed")
        self.assertEqual(res, {"error": "Platform(s) not found: ['Y', 'Zed']"})
        self.assertFalse(self.out.exists())

    def test_union_counts(self):
        res = mo.create_combo_column(str(self.src), str(self.out), "Combo", "Alpha", "Beta")
        self.assertEqual(res, {"combo_col": 6, "tick_count": 4, "unique_a": 0, "unique_b": 2, "overlap": 2})
        res = mo.create_combo_column(str(self.src), str(self.out), "Combo", "Beta", "Alpha")
        self.assertEqual((res["unique_a"], res["unique_b"], res["overlap"]), (2, 0, 2))
        ws = self.load().active
        self.assertEqual(ws.cell(2, 6).value, "Combo")
        self.assertEqual(ws.cell(7, 6).value, TICK)
        self.assertIsNone(ws.cell(5, 6).value)
        res = mo.create_combo_column(str(self.src), str(self.out), "None", "Gamma", "Gamma")
        self.assertEqual(res["tick_count"], 0)
        self.assertIsNone(self.load().active.cell(6, 6).value)


class TestReadOnlyViews(XlsxCase):
    def test_verify_ticks(self):
        res = mo.verify_ticks(str(self.src))
        self.assertEqual(res["Alpha"], {"ticked": ["SSO", "API"], "not_ticked": ["Audit", "CLI"],
                                        "tick_count": 2, "total_features": 4})
        self.assertEqual(res["Gamma"]["tick_count"], 0)

    def test_extract_features(self):
        res = mo.extract_features(str(self.src))
        self.assertEqual(res["total_categories"], 2)
        self.assertEqual(res["total_features"], 4)
        self.assertEqual(res["categories"][0], {"name": "Sec", "features": [
            {"name": "SSO", "priority": "Critical"}, {"name": "Audit", "priority": "High"}]})

    def test_ranked_scores(self):
        res = mo.ranked_scores(str(self.src))
        self.assertEqual(res["rankings"], [
            {"platform": "Beta", "score": 11, "ticks": 4, "rank": 1},
            {"platform": "Alpha", "score": 7, "ticks": 2, "rank": 2},
            {"platform": "Gamma", "score": 0, "ticks": 0, "rank": 3}])

    def test_info_both_layouts(self):
        res = mo.info(str(self.src))
        self.assertEqual(res, {"title": "Sample Matrix", "platforms": ["Alpha", "Beta", "Gamma"],
                               "platform_count": 3, "categories": ["Sec", "Ops"], "category_count": 2,
                               "total_features": 4, "layout": "with_title", "header_row": 2,
                               "data_start_row": 5})
        res = mo.info(str(self.make_no_title()))
        self.assertEqual((res["layout"], res["header_row"], res["data_start_row"]), ("no_title", 1, 4))
        self.assertEqual(res["title"], "Capability / Feature")


class TestReorderRowsAndCategories(XlsxCase):
    def test_reorder_rows(self):
        res = mo.reorder_rows(str(self.src), str(self.out), "Sec", ["Audit", "Nope"])
        self.assertEqual(res, {"category": "Sec", "rows_reordered": 2, "features_not_found": ["Nope"]})
        ws = self.load().active
        self.assertEqual([ws.cell(r, 1).value for r in (5, 6, 7, 8, 9, 10)],
                         ["Sec", "Audit", "SSO", "Ops", "API", "CLI"])
        self.assertEqual(ws.cell(6, 2).value, "High")
        self.assertEqual(ws.cell(7, 4).value, TICK)   # SSO row keeps its platform cells
        self.assertEqual(mo.extract_features(str(self.out))["total_features"], 4)

    def test_reorder_rows_unknown_category(self):
        res = mo.reorder_rows(str(self.src), str(self.out), "Missing", ["x"])
        self.assertEqual(res, {"error": "Category not found: Missing"})
        self.assertFalse(self.out.exists())

    def test_reorder_categories(self):
        res = mo.reorder_categories(str(self.src), str(self.out), ["Ops", "Ghost"])
        self.assertEqual(res, {"categories_reordered": 1, "categories_not_found": ["Ghost"]})
        ws = self.load().active
        self.assertEqual([ws.cell(r, 1).value for r in range(5, 11)],
                         ["Ops", "API", "CLI", "Sec", "SSO", "Audit"])
        self.assertIn("A5:E5", [str(r) for r in ws.merged_cells.ranges])
        self.assertIn("A8:E8", [str(r) for r in ws.merged_cells.ranges])

    def test_reorder_categories_keeps_unlisted_in_original_order(self):
        res = mo.reorder_categories(str(self.src), str(self.out), [])
        self.assertEqual(res["categories_reordered"], 0)
        ws = self.load().active
        self.assertEqual(ws.cell(5, 1).value, "Sec")


class TestCLI(XlsxCase):
    def run_cli(self, *argv):
        code, out, err = call_main(mo, list(argv))
        return code, (json.loads(out) if out.strip() else None), err

    def test_commands(self):
        feats = self.dir / "feats.json"
        feats.write_text(json.dumps({"SSO": True}))
        rows = self.dir / "rows.json"
        rows.write_text(json.dumps([{"category": "Sec", "feature": "MFA"}]))
        code, data, _ = self.run_cli("add-platform", "--src", str(self.src), "--out", str(self.out),
                                     "--platform", "D", "--features", str(feats), "--new-rows", str(rows))
        self.assertEqual((code, data["new_rows_added"], data["platform_col"]), (0, 1, 6))
        code, data, _ = self.run_cli("add-platform", "--src", str(self.src), "--out", str(self.out),
                                     "--platform", "D", "--features", str(feats))
        self.assertEqual(data["new_rows_added"], 0)
        code, data, _ = self.run_cli("reorder-columns", "--src", str(self.src), "--out", str(self.out))
        self.assertEqual(data["order"][0], "Beta")
        code, data, _ = self.run_cli("combo", "--src", str(self.src), "--out", str(self.out),
                                     "--name", "C", "--platform-a", "Alpha", "--platform-b", "Beta")
        self.assertEqual(data["tick_count"], 4)
        code, data, _ = self.run_cli("verify", "--src", str(self.src))
        self.assertEqual(data["Beta"]["tick_count"], 4)
        order = self.dir / "order.json"
        order.write_text(json.dumps(["Audit"]))
        code, data, _ = self.run_cli("reorder-rows", "--src", str(self.src), "--out", str(self.out),
                                     "--category", "Sec", "--order", str(order))
        self.assertEqual(data["rows_reordered"], 2)
        order.write_text(json.dumps(["Ops"]))
        code, data, _ = self.run_cli("reorder-categories", "--src", str(self.src), "--out", str(self.out),
                                     "--order", str(order))
        self.assertEqual(data["categories_reordered"], 1)
        code, data, _ = self.run_cli("extract-features", "--src", str(self.src))
        self.assertEqual(data["total_features"], 4)
        code, data, _ = self.run_cli("scores", "--src", str(self.src))
        self.assertEqual(data["rankings"][0]["platform"], "Beta")
        code, data, _ = self.run_cli("info", "--src", str(self.src))
        self.assertEqual(data["platform_count"], 3)

    def test_requires_command(self):
        code, data, err = self.run_cli()
        self.assertEqual(code, 2)

    def test_run_as_script(self):
        code, out, _ = run_script(SCRIPTS / "matrix_ops.py", ["info", "--src", str(self.src)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["title"], "Sample Matrix")


if __name__ == "__main__":
    unittest.main()

"""Unit tests for synthesize_landscape helpers: filtering, chart support, wave scoring."""

from __future__ import annotations

import json
import unittest
from unittest import mock

from synth_helpers import APO_NEED, TmpCase, sl


class RankingsMarkdownTests(unittest.TestCase):
    def test_rankings_dump(self):
        md = sl._comparison_rankings_markdown({
            "rankings": ["junk", {"solution": "a", "score": 3}, {"solution": None, "score": None},
                         {"solution": "b", "score": 1}],
        })
        self.assertIn("Winner: **a** | Runner-up: **", md)
        self.assertIn("1. `a` — 3", md)
        self.assertIn("2. `` — None", md)
        explicit = sl._comparison_rankings_markdown({"winner": "w", "runner_up": "r", "rankings": []})
        self.assertIn("Winner: **w** | Runner-up: **r**", explicit)
        empty = sl._comparison_rankings_markdown({})
        self.assertIn("Winner: **** | Runner-up: ****", empty)


class FilterComparisonTests(unittest.TestCase):
    def pack(self):
        from category_pack import resolve_pack_from_need
        return resolve_pack_from_need(APO_NEED)

    def test_passthrough_without_pack_or_dict(self):
        comp = {"rankings": [{"solution": "x"}]}
        self.assertIs(sl.filter_comparison_for_pack(comp, None), comp)
        self.assertEqual(sl.filter_comparison_for_pack([1], self.pack()), [1])

    def test_filters_and_renumbers(self):
        comp = {
            "winner": "cline",
            "runner_up": "devika",
            "rankings": [
                {"solution": "cline", "score": 9},          # hard-excluded
                {"solution": "silver-bullet", "score": 8},
                "junk",
                {"solution": "", "score": 7},               # blank slug
                {"solution": "devika", "score": 6},         # sunset registry
                {"solution": "sdlc-plugin", "score": 5},    # always dropped alias
                {"solution": "ai-dlc", "score": 4},
            ],
            "rows": [
                "row-junk",
                {"name": "f", "solutions": {"cline": True, "silver-bullet": True, "ai-dlc": False}},
                {"name": "g", "solutions": "not-a-dict"},
            ],
        }
        out = sl.filter_comparison_for_pack(comp, self.pack(), APO_NEED)
        self.assertEqual([(r["solution"], r["rank"]) for r in out["rankings"]],
                         [("silver-bullet", 1), ("ai-dlc", 2)])
        self.assertEqual(out["winner"], "silver-bullet")
        self.assertEqual(out["runner_up"], "ai-dlc")
        self.assertEqual(out["rows"][0], "row-junk")
        self.assertEqual(out["rows"][1]["solutions"], {"silver-bullet": True, "ai-dlc": False})
        self.assertEqual(out["rows"][2]["solutions"], "not-a-dict")
        # input is not mutated
        self.assertEqual(len(comp["rankings"]), 7)

    def test_winner_and_runner_without_survivors(self):
        comp = {"winner": "cline", "runner_up": "devika", "rankings": [{"solution": "cline"}]}
        out = sl.filter_comparison_for_pack(comp, self.pack())
        self.assertIsNone(out["winner"])
        self.assertIsNone(out["runner_up"])
        comp = {"winner": "cline", "runner_up": "devika",
                "rankings": [{"solution": "silver-bullet"}]}
        out = sl.filter_comparison_for_pack(comp, self.pack())
        self.assertEqual(out["winner"], "silver-bullet")
        self.assertIsNone(out["runner_up"])

    def test_valid_winner_kept(self):
        comp = {"winner": "silver-bullet", "runner_up": "ai-dlc",
                "rankings": [{"solution": "silver-bullet"}, {"solution": "ai-dlc"}]}
        out = sl.filter_comparison_for_pack(comp, self.pack())
        self.assertEqual((out["winner"], out["runner_up"]), ("silver-bullet", "ai-dlc"))

    def test_canonical_alias_and_allow_list(self):
        pack = {"product_aliases": {"alias-x": "real-x", "bad-alias": "cline"},
                "hard_exclusions": [{"slug": "cline"}], "sunset_registry": [],
                "markets": [{"market_id": "m", "seeds": [{"slug": "real-x"}]}]}
        comp = {"rankings": [{"solution": s} for s in
                             ("alias-x", "real-x", "bad-alias", "other", "allowed")]}
        out = sl.filter_comparison_for_pack(comp, pack, matrix_slugs={"real-x", "allowed"})
        # alias columns dropped, alias to a forbidden canonical dropped, off-list dropped
        self.assertEqual([r["solution"] for r in out["rankings"]], ["real-x", "allowed"])
        out = sl.filter_comparison_for_pack(comp, pack)
        self.assertEqual([r["solution"] for r in out["rankings"]], ["real-x", "other", "allowed"])


class CatalogAndBucketTests(TmpCase):
    def test_resolve_catalogs_with_prepared_audit(self):
        audit = {"matrix_slugs": ["silver-bullet", "ai-dlc"], "core": ["ignored"]}
        with mock.patch("solution_classifier.classify_solutions") as classify:
            commercial, oss, got = sl._resolve_catalogs(APO_NEED, [], audit)
        classify.assert_not_called()
        self.assertIs(got, audit)
        slugs = {e["slug"] for e in commercial + oss}
        self.assertIn("silver-bullet", slugs)

    def test_resolve_catalogs_classifies_when_no_audit(self):
        fake = {"core": ["silver-bullet"]}
        with mock.patch("solution_classifier.classify_solutions", return_value=fake) as classify:
            commercial, oss, got = sl._resolve_catalogs(APO_NEED, [{"e": 1}], None)
        classify.assert_called_once()
        self.assertIs(got, fake)
        self.assertIn("silver-bullet", {e["slug"] for e in commercial + oss})

    def test_resolve_catalogs_legacy(self):
        commercial, oss, audit = sl._resolve_catalogs({}, [], None)
        self.assertEqual(audit, {})
        self.assertTrue(commercial)

    def test_known_and_overview_for_need(self):
        self.assertIsInstance(sl._known_for_need({}), dict)
        self.assertIsInstance(sl._overview_for_need({}), dict)

    def test_vendor_license_bucket(self):
        b = sl.vendor_license_bucket
        self.assertEqual(b("zz", license_map={"zz": "oss"}), "oss")
        self.assertEqual(b("langchain"), "oss")  # in OSS catalog
        self.assertEqual(b("cursor", license_map={"cursor": "commercial"}), "commercial")
        com = next(iter(sl.COMMERCIAL_SLUGS - sl.NON_COMMERCIAL_SLUGS))
        self.assertEqual(b(com), "commercial")
        self.assertEqual(b("unlisted", license_map={"unlisted": "mixed"}), "commercial")
        self.assertEqual(b("unlisted", license_map={"unlisted": "unknown"}), "commercial")
        self.assertEqual(b("unlisted", license_map={"unlisted": "weird"}), "commercial")
        self.assertEqual(b("unlisted", license_map={"unlisted": "weird"}, fallback="oss"), "oss")
        self.assertEqual(b("unlisted", fallback="oss"), "oss")


class FeatureSupportTests(unittest.TestCase):
    def test_feat_supported(self):
        f = sl._feat_supported
        self.assertTrue(f({"A": True}, "A"))
        self.assertFalse(f({}, "A"))
        # long/short alias in both directions
        self.assertTrue(f({"Parent/child agent delegation": True}, "Parent/child delegation"))
        self.assertTrue(f({"Parent/child delegation": True}, "Parent/child agent delegation"))
        self.assertFalse(f({"Parent/child delegation": False}, "Parent/child agent delegation"))

    def test_feat_equiv_table(self):
        with mock.patch.dict(sl._CHART_FEAT_EQUIV, {"X": ("Y", "Z")}):
            self.assertTrue(sl._feat_supported({"Z": True}, "X"))
            self.assertFalse(sl._feat_supported({"Y": False}, "X"))
        self.assertFalse(sl._feat_supported({"Z": True}, "X"))

    def test_model_family_label(self):
        m = sl._model_family_label
        for mid, fam in (("Claude-3", "claude"), ("gemini-pro", "gemini"), ("gpt-4", "openai"),
                         ("luna-1", "openai"), ("qwen-2", "qwen"), ("deepseek-v3", "deepseek"),
                         ("kimi-k2", "kimi"), ("mimo-7b", "mimo"), ("MiniMax-M1", "minimax"),
                         ("foo-bar", "foo"), ("", "unknown"), (None, "unknown")):
            self.assertEqual(m(mid), fam, mid)


class LedgerTests(TmpCase):
    def test_load_statuses(self):
        self.assertEqual(sl._load_inclusion_ledger_statuses(None), {})
        self.assertEqual(sl._load_inclusion_ledger_statuses(self.root), {})
        path = self.put("landscape/inclusion-ledger.json", "{not json")
        self.assertEqual(sl._load_inclusion_ledger_statuses(self.root), {})
        path.write_text(json.dumps({"vendors": [
            "junk", {"criteria": []}, {"slug": ""},
            {"slug": "a", "criteria": ["junk", {"criterion": "  "}, {"criterion": "Cross-Session State", "status": "PASS"},
                                       {"name": "Other", "status": None}]},
            {"slug": "b"},
        ]}))
        self.assertEqual(sl._load_inclusion_ledger_statuses(self.root), {
            "a": {"cross session state": "pass", "other": "unknown"}, "b": {}})

    def test_load_statuses_unreadable_file(self):
        self.put("landscape/inclusion-ledger.json", "{}")
        with mock.patch.object(sl.Path, "read_text", side_effect=OSError("denied")):
            self.assertEqual(sl._load_inclusion_ledger_statuses(self.root), {})

    def test_cross_session_status(self):
        self.assertEqual(sl._cross_session_status("silver-bullet", None), "pass")
        self.assertEqual(sl._cross_session_status("other", None), "unknown")
        self.put("landscape/inclusion-ledger.json", {"vendors": [
            {"slug": "v1", "criteria": [{"criterion": "Cross session", "status": "fail"}]},
            {"slug": "v2", "criteria": [{"criterion": "Persisted state", "status": "pass"}]},
            {"slug": "v3", "criteria": [{"criterion": "Cross session", "status": "partial"},
                                        {"criterion": "unrelated", "status": "pass"}]},
            {"slug": "silver-bullet", "criteria": [{"criterion": "x", "status": "fail"}]},
        ]})
        self.assertEqual(sl._cross_session_status("v1", self.root), "fail")
        self.assertEqual(sl._cross_session_status("v2", self.root), "pass")
        self.assertEqual(sl._cross_session_status("v3", self.root), "unknown")
        self.assertEqual(sl._cross_session_status("silver-bullet", self.root), "pass")


class LeaderRulesTests(TmpCase):
    def test_methodology_and_leader_rules(self):
        gates = {"Hook-enforced gates": True}
        self.assertFalse(sl._is_methodology_without_gates(gates))
        self.assertFalse(sl._is_methodology_without_gates({"Managed hosting": True}))
        self.assertFalse(sl._is_methodology_without_gates({"Automated review loops": True}))
        self.assertTrue(sl._is_methodology_without_gates({}))
        self.assertTrue(sl._must_not_be_leader("apo", "x", {}, None))
        self.assertFalse(sl._must_not_be_leader("apo", "x", gates, None))
        self.assertFalse(sl._must_not_be_leader("other", "x", {}, None))
        self.assertFalse(sl._must_not_be_leader(None, "x", {}, None))
        self.assertTrue(sl._must_not_be_leader("sdlc-plugins", "x", gates, None))
        self.assertTrue(sl._must_not_be_leader("sdlc-plugins", "silver-bullet", {}, None))
        self.assertFalse(sl._must_not_be_leader("sdlc-plugins", "silver-bullet", gates, None))

    def test_feat_tick_and_vc_kcfs(self):
        t = sl._feat_tick
        self.assertTrue(t({"A": True}, "A"))
        self.assertFalse(t({"A": False}, "A"))
        self.assertIsNone(t({}, "A"))
        self.assertIsNone(t({"A": None}, "A"))
        # False recorded under the aliased long form counts as an explicit false
        self.assertFalse(t({"Parent/child agent delegation": False}, "Parent/child delegation"))
        self.assertFalse(t({"Parent/child delegation": False}, "Parent/child agent delegation"))
        k = sl.KCF_NAMES[0]
        got = sl.select_vc_kcfs(["a", "b", "ghost"], {"a": {k: True}, "b": {k: False}})
        self.assertEqual(got, [k])
        self.assertEqual(sl.select_vc_kcfs(["a"], {"a": {k: False}}), [])
        self.assertEqual(sl.select_vc_kcfs([], {}), [])

    def test_wave_band(self):
        self.assertEqual([sl._wave_band(v) for v in (3.5, 3.0, 2.5, 2.0, 1.5, 1.4)],
                         ["Strong", "Good", "Good", "Moderate", "Moderate", "Emerging"])

    def test_quadrant_and_descriptor(self):
        self.assertEqual([sl._quadrant(x, y) for x, y in ((6, 6), (5, 6), (6, 5), (5, 5))],
                         ["Leaders", "Challengers", "Visionaries", "Niche Players"])
        self.assertEqual([sl._wave_descriptor(s) for s in (29, 14, 8, 1)],
                         ["Strong", "Good", "Moderate", "Emerging"])
        self.assertEqual(sl._wave_descriptor(5, 0), "Emerging")

    def test_coord_helpers(self):
        self.assertEqual(sl._clamp_chart_xy(0, 20), (1.0, 9.5))
        self.assertEqual(sl._round_coord("1.26"), 1.3)


class AxisEnforcementTests(unittest.TestCase):
    def test_enforce_non_leader_y(self):
        self.assertEqual(sl._enforce_non_leader_y([], {"a"}), [])
        pts = [{"slug": "a", "x": 7, "y": 6}]
        self.assertIs(sl._enforce_non_leader_y(pts, set()), pts)
        pts = [{"slug": "a", "x": 7, "y": 6.0}, {"slug": "b", "x": 7, "y": 5.4},
               {"slug": "c", "x": 3, "y": 6.0}, {"slug": "d", "y": None}]
        out = sl._enforce_non_leader_y(pts, {"a"})
        by = {p["slug"]: p for p in out}
        self.assertEqual(by["a"]["y"], 5.3)  # 5.4 is taken by b
        self.assertEqual(by["a"]["q"], "Visionaries")
        self.assertEqual(by["c"]["y"], 6.0)  # not demoted
        self.assertEqual(by["c"]["q"], "Challengers")
        self.assertEqual(by["d"]["q"], "Niche Players")

    def test_enforce_non_leader_y_all_slots_taken(self):
        pts = [{"slug": "a", "x": 7, "y": 6.0}]
        taken = [{"slug": f"o{i}", "x": 1, "y": round(5.4 - i / 10, 1)} for i in range(45)]
        out = sl._enforce_non_leader_y(pts + taken, {"a"})
        self.assertEqual(out[0]["y"], sl._LEADER_Y_CAP)

    def test_enforce_axis_cap(self):
        f = sl._enforce_axis_cap
        self.assertEqual(f([], {"a"}, key="x", cap=6.5), [])
        pts = [{"slug": "a", "x": 8, "y": 3}]
        self.assertIs(f(pts, set(), key="x", cap=6.5), pts)
        pts = [{"slug": "a", "x": 8, "y": 3}, {"slug": "b", "x": 6.5, "y": 8}, {"slug": "c", "x": 9, "y": 9}]
        out = f(pts, {"a", "zzz"}, key="x", cap=6.5)
        self.assertEqual(out[0]["x"], 6.4)  # 6.5 taken
        self.assertEqual(out[0]["q"], "Visionaries")
        self.assertEqual(out[2]["x"], 9)    # not in slugs
        self.assertEqual(out[1]["x"], 6.5)  # at the cap already

    def test_enforce_axis_cap_exhausted_range(self):
        pts = [{"slug": "a", "x": 8, "y": 3}] + [
            {"slug": f"o{i}", "x": round(1.0 + i / 10, 1), "y": 1} for i in range(0, 60)]
        out = sl._enforce_axis_cap(pts, {"a"}, key="x", cap=2.0, lo=1.0)
        self.assertEqual(out[0]["x"], 2.0)


class ScrBonusTests(TmpCase):
    def test_load_scr_text(self):
        self.assertEqual(sl._load_scr_text(None, "a"), "")
        self.assertEqual(sl._load_scr_text(self.root, ""), "")
        self.assertEqual(sl._load_scr_text(self.root, "a"), "")
        self.put("solutions/a/scr.md", "hello")
        self.assertEqual(sl._load_scr_text(self.root, "a"), "hello")
        with mock.patch.object(sl.Path, "read_text", side_effect=OSError("denied")):
            self.assertEqual(sl._load_scr_text(self.root, "a"), "")

    def test_strategy_bonus(self):
        b = sl._scr_strategy_bonus
        self.assertEqual(b(""), 0.0)
        self.assertEqual(b("nothing relevant"), 0.0)
        self.assertEqual(b("works with claude"), 0.10)
        self.assertEqual(b("open source"), 0.20)
        self.assertEqual(b("an ecosystem"), 0.15)
        self.assertEqual(b("marketplace"), 0.15)
        self.assertEqual(b("roadmap"), 0.10)
        host2 = [m for m in sl._WAVE_STRATEGY_HOST_MARKERS][:2]
        self.assertEqual(b(" ".join(host2)), 0.25)
        self.assertEqual(b(" ".join(host2) + " open source marketplace roadmap"), 0.55)
        self.assertEqual(b("MIT licensed"), 0.20)

    def test_wave_strategy_score(self):
        self.assertEqual(sl._wave_strategy_score({}), 1.0)
        feats = {name: True for name, _w in sl._WAVE_STRATEGY_FEATURE_WEIGHTS}
        self.assertLessEqual(sl._wave_strategy_score(feats, scr_text="open source roadmap"), 4.0)
        one = sl._WAVE_STRATEGY_FEATURE_WEIGHTS[0]
        self.assertAlmostEqual(sl._wave_strategy_score({one[0]: True}), round(1.0 + one[1], 1))
        self.assertAlmostEqual(sl._wave_strategy_score({}, scr_text="roadmap"), 1.1)


class ChartSupportTests(TmpCase):
    def test_avoid_wave_collisions(self):
        pts = [{"label": "a", "strategy": 2.0, "offering": 2.0},
               {"label": "b", "strategy": 2.0, "offering": 2.0},
               {"label": "c", "strategy": None, "offering": None, "presence": 2}]
        out = sl.avoid_wave_coord_collisions(pts)
        self.assertEqual([p["label"] for p in out], ["a", "b", "c"])
        self.assertEqual(len({p["strategy"] for p in out}), 3)
        self.assertEqual(len({p["offering"] for p in out}), 3)
        for p in out:
            self.assertNotIn("x", p)
            self.assertNotIn("q", p)
            self.assertTrue(1.0 <= p["strategy"] <= 4.0 and 1.0 <= p["offering"] <= 4.0)
        self.assertEqual(out[2]["presence"], 2)

    def test_normalize_support(self):
        got = sl._normalize_chart_support({
            "a": {"Parent/child agent delegation": True},
            "b": {"Parent/child agent delegation": True, "Parent/child delegation": True},
            "c": {},
        })
        self.assertTrue(got["a"]["Parent/child delegation"])
        self.assertNotIn("Parent/child delegation", got["c"])
        self.assertTrue(got["b"]["Parent/child delegation"])

    def test_merge_features_json(self):
        support = {"a": {"X": True}}
        self.assertIs(sl._merge_features_json_support(support, None), support)
        got = sl._merge_features_json_support(support, self.root)  # no solutions dir
        self.assertEqual(got, support)
        self.assertIsNot(got, support)
        self.put("solutions/bad/features.json", "{oops")
        self.put("solutions/a/features.json", {"categories": [
            "junk",
            {"features": ["junk", {"name": ""}, {"name": "X", "supported": False},
                          {"name": "Y", "supported": True}, {"name": "Z", "supported": None},
                          {"name": "Parent/child agent delegation", "supported": True}]},
            {"features": None},
        ]})
        self.put("solutions/new/features.json", {"categories": None})
        got = sl._merge_features_json_support(support, self.root)
        self.assertEqual(got["a"]["X"], False)
        self.assertEqual(got["a"]["Y"], True)
        self.assertNotIn("Z", got["a"])
        self.assertTrue(got["a"]["Parent/child delegation"])
        self.assertEqual(got["new"], {})
        self.assertNotIn("bad", got)

    def test_build_chart_support_uses_comparison_and_root(self):
        comp = {"rows": [{"type": "feature", "name": "Workflow composition",
                          "solutions": {"a": True, "b": False}}]}
        self.put("solutions/b/features.json", {"categories": [
            {"features": [{"name": "Workflow composition", "supported": True}]}]})
        got = sl._build_chart_support(comp, root=self.root)
        self.assertTrue(got["a"]["Workflow composition"])
        self.assertTrue(got["b"]["Workflow composition"])
        self.assertTrue(sl._build_chart_support(comp)["a"]["Workflow composition"])


if __name__ == "__main__":
    unittest.main()

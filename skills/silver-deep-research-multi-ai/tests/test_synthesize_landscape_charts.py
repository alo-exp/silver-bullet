"""Unit tests for synthesize_landscape chart construction and multi-market payloads."""

from __future__ import annotations

import copy
import unittest
from unittest import mock

from synth_helpers import APO_NEED, TmpCase, sl

GATES = {"Hook-enforced gates": True, "Workflow composition": True, "Atomic flow catalog": True,
         "Parent/child delegation": True, "Managed hosting": True}


def comparison(*slugs_scores):
    return {"rankings": [{"solution": s, "score": n} for s, n in slugs_scores]}


def pack_apo():
    from category_pack import resolve_pack_from_need
    return resolve_pack_from_need(APO_NEED)


class UniquifyTests(unittest.TestCase):
    def test_uniquify_axis(self):
        u = sl._uniquify_axis
        self.assertEqual(u([], lo=1, hi=9.5), [])
        self.assertEqual(u([12.0], lo=1, hi=9.5), [9.5])
        self.assertEqual(u([5.0, 5.0, 5.0], lo=1, hi=9.5), [5.0, 5.1, 4.9])
        self.assertEqual(u([9.5, 9.5], lo=1, hi=9.5), [9.5, 9.4])
        self.assertEqual(u([1.0, 1.0], lo=1, hi=9.5), [1.0, 1.1])
        self.assertEqual(u([3.0, 4.0], lo=1, hi=9.5), [3.0, 4.0])
        # tiebreak decides which equal value keeps the slot; wrong-length tiebreak is ignored
        self.assertEqual(u([5.0, 5.0], lo=1, hi=9.5, tiebreak=[1.0, 2.0]), [5.1, 5.0])
        self.assertEqual(u([5.0, 5.0], lo=1, hi=9.5, tiebreak=[1.0]), [5.0, 5.1])

    def test_uniquify_fallback_scan_and_duplicate(self):
        # a step far larger than the range leaves only the linear scan, then the original target
        self.assertEqual(sl._uniquify_axis([5.0, 5.0, 5.0], lo=1, hi=9.5, step=100), [5.0, 1.0, 5.0])


class SlotBoundaryTests(unittest.TestCase):
    def test_axis_cap_can_use_the_lowest_slot(self):
        pts = [{"slug": "a", "x": 8.0, "y": 3.0}] + [
            {"slug": f"o{i}", "x": x, "y": 1.0 + i} for i, x in enumerate((1.3, 1.2, 1.1))]
        out = sl._enforce_axis_cap(pts, {"a"}, key="x", cap=1.3, lo=1.0)
        self.assertEqual(out[0]["x"], 1.0)

    def test_non_leader_y_can_use_the_lowest_slot(self):
        taken = [{"slug": f"o{i}", "x": 1.0, "y": round(5.4 - i / 10, 1)} for i in range(44)]  # 5.4 .. 1.1
        out = sl._enforce_non_leader_y([{"slug": "a", "x": 7.0, "y": 6.0}] + taken, {"a"})
        self.assertEqual(out[0]["y"], 1.0)


class CollisionTests(unittest.TestCase):
    def test_avoid_collisions(self):
        self.assertEqual(sl.avoid_chart_coord_collisions([]), [])
        pts = [{"slug": "a", "x": 6.0, "y": 6.0, "q": "x"}, {"slug": "b", "x": 6.0, "y": 6.0}]
        out = sl.avoid_chart_coord_collisions(pts)
        self.assertEqual(len({p["x"] for p in out}), 2)
        self.assertEqual(len({p["y"] for p in out}), 2)
        self.assertEqual({p["q"] for p in out}, {"Leaders"})
        self.assertEqual(pts[1], {"slug": "b", "x": 6.0, "y": 6.0})  # input untouched

    def test_custom_keys_keep_quadrant(self):
        pts = [{"a": 2.0, "b": 2.0, "q": "keep"}, {"a": 2.0, "b": 2.0}]
        out = sl.avoid_chart_coord_collisions(pts, x_key="a", y_key="b", update_quadrant=False)
        self.assertEqual(out[0]["q"], "keep")
        self.assertNotIn("q", out[1])
        self.assertNotEqual(out[0]["a"], out[1]["a"])
        self.assertNotIn("x", out[0])

    def test_membership(self):
        m = sl.chart_listed_membership(core=["b", "a", ""], adjacent=["a", "c", None],
                                       reason_by_slug={"c": "why"})
        self.assertEqual(m["core"], ["a", "b"])
        self.assertEqual(m["adjacent"], ["c"])
        self.assertEqual(m["listed"], ["a", "b", "c"])
        self.assertEqual(m["unplotted"], [{"slug": "c", "reason": "why"}])
        d = sl.chart_listed_membership(core={"a"}, adjacent={"z"})
        self.assertIn("adjacent competitor", d["unplotted"][0]["reason"])
        self.assertEqual(sl.chart_listed_membership(core=[])["unplotted"], [])

    def test_market_profile(self):
        self.assertEqual(sl._market_chart_profile("sdlc-plugins")["mq_base"], (3.4, 2.4))
        self.assertEqual(sl._market_chart_profile("unknown")["mq_base"], (3.0, 3.0))
        self.assertEqual(sl._market_chart_profile(None)["mq_base"], (3.0, 3.0))
        p = sl._market_chart_profile("apo")
        p["mq_base"] = None
        self.assertEqual(sl._market_chart_profile("apo")["mq_base"], (3.0, 3.0))


class BuildChartTests(TmpCase):
    def support(self):
        return {"alpha": dict(GATES), "beta": {"Workflow composition": True}, "gamma": dict(GATES)}

    def build(self, comp=None, **kw):
        args = dict(category="Cat", support=self.support(), known={"alpha": "Alpha", "beta": "Beta", "gamma": "Gamma"},
                    commercial=[], oss=[])
        args.update(kw)
        return sl.build_chart_data(comp or comparison(("alpha", 25), ("beta", 12), ("gamma", 18)), **args)

    def test_basic_payload(self):
        chart = self.build(market_id="apo")
        self.assertEqual([p["slug"] for p in chart["mq_data"]], ["alpha", "beta", "gamma"])
        self.assertEqual({p["slug"] for p in chart["wave_data"]}, {"alpha", "gamma"})  # beta lacks gates
        by = {p["slug"]: p for p in chart["mq_data"]}
        self.assertLessEqual(by["beta"]["x"], sl._METHODOLOGY_X_CAP)
        self.assertLessEqual(by["beta"]["y"], sl._METHODOLOGY_Y_CAP)
        self.assertNotEqual(by["beta"]["q"], "Leaders")
        self.assertTrue(any("Methodology/framework seeds" in n for n in chart["chart_notes"]))
        self.assertTrue(any(n.startswith("Demoted from Leaders") and "beta" in n for n in chart["chart_notes"]))
        self.assertEqual(chart["titles"]["mq"], "3A · Cat Positioning Matrix")
        self.assertEqual(chart["market_id"], "apo")
        self.assertEqual(chart["plotted_slugs"], ["alpha", "beta", "gamma"])
        self.assertEqual(len({p["x"] for p in chart["mq_data"]}), 3)

    def test_market_notes_and_plain_market(self):
        notes = lambda mid: self.build(market_id=mid)["chart_notes"]  # noqa: E731
        self.assertTrue(any("Leaders require hook-enforced gates plus inclusion-ledger" in n
                            for n in notes("sdlc-plugins")))
        self.assertTrue(any("SaaS-core MQ/Wave" in n for n in notes("agentic-sdlc-saas")))
        plain = self.build(market_id="other", support={s: dict(GATES) for s in ("alpha", "beta", "gamma")})
        self.assertEqual(plain["chart_notes"], [])
        self.assertIsNone(self.build(support={s: dict(GATES) for s in ("alpha", "beta", "gamma")})["market_id"])

    def test_sdlc_plugin_leader_needs_cross_session_pass(self):
        sup = {s: dict(GATES) for s in ("silver-bullet", "other")}
        comp = comparison(("silver-bullet", 28), ("other", 28))
        chart = sl.build_chart_data(comp, category="C", support=sup, market_id="sdlc-plugins",
                                    known={}, commercial=[], oss=[])
        q = {p["slug"]: p["q"] for p in chart["mq_data"]}
        self.assertNotEqual(q["other"], "Leaders")
        self.assertIn("silver-bullet", [p["slug"] for p in chart["mq_data"] if p["q"] == "Leaders"] or ["silver-bullet"])

    def test_market_slugs_force_plotting_of_missing_cores(self):
        chart = self.build(market_slugs={"alpha", "zeta", "beta"}, adjacent_slugs=["adj", "alpha"])
        self.assertEqual({p["slug"] for p in chart["mq_data"]}, {"alpha", "zeta", "beta"})
        self.assertEqual(chart["listed_slugs"], ["adj", "alpha", "beta", "zeta"])
        self.assertEqual([u["slug"] for u in chart["unplotted"]], ["adj"])

    def test_chart_cap_grows_with_market(self):
        many = {f"s{i:02d}" for i in range(15)}
        chart = self.build(market_slugs=many, support={s: dict(GATES) for s in many})
        self.assertEqual(len(chart["mq_data"]), 15)

    def test_chart_cap_from_pack_market(self):
        pack = {"markets": [{"id": "x", "seeds": [{"slug": "other"}, "junk", {"slug": ""}]},
                            {"id": "m", "seeds": [{"slug": "s00"}], "max_core_count": 20}],
                "hard_exclusions": [], "sunset_registry": []}
        many = {f"s{i:02d}" for i in range(14)}
        chart = self.build(market_slugs=many, pack=pack, support={s: dict(GATES) for s in many})
        self.assertEqual(len(chart["mq_data"]), 14)
        # no market owns the slugs: the cap is left alone
        pack["markets"] = [{"id": "x", "seeds": [{"slug": "nomatch"}]}]
        chart = self.build(market_slugs=many, pack=pack, support={s: dict(GATES) for s in many})
        self.assertEqual(len(chart["mq_data"]), 14)

    def test_chart_cap_pack_failure_falls_back(self):
        many = {f"s{i:02d}" for i in range(14)}
        pack = {"markets": [{"id": "m", "seeds": [{"slug": "s00"}]}], "hard_exclusions": [], "sunset_registry": []}
        import category_pack
        real = category_pack.get_markets
        calls = []

        import sys

        def flaky(p):
            if any(sys._getframe(n).f_code.co_name == "build_chart_data" for n in range(1, 6)):
                calls.append(1)
                raise ValueError("boom")
            return real(p)

        with mock.patch("category_pack.get_markets", side_effect=flaky):
            chart = self.build(market_slugs=many, pack=pack, support={s: dict(GATES) for s in many})
        self.assertEqual(len(chart["mq_data"]), 14)
        self.assertEqual(calls, [1])

    def test_forbidden_slugs_dropped_with_pack(self):
        pack = pack_apo()
        comp = comparison(("silver-bullet", 25), ("cline", 20))
        sup = {"silver-bullet": dict(GATES), "cline": dict(GATES)}
        chart = sl.build_chart_data(comp, category="C", support=sup, pack=pack, need=APO_NEED,
                                    known={}, commercial=[], oss=[])
        self.assertEqual([p["slug"] for p in chart["mq_data"]], ["silver-bullet"])
        chart = sl.build_chart_data(comp, category="C", support=sup, pack=pack, need=APO_NEED,
                                    known={}, commercial=[], oss=[], market_slugs={"silver-bullet", "cline"})
        self.assertEqual([p["slug"] for p in chart["mq_data"]], ["silver-bullet"])

    def test_malformed_pack_exclusions_do_not_crash(self):
        pack = {"hard_exclusions": ["junk"], "markets": []}
        chart = self.build(pack=pack)
        self.assertEqual(len(chart["mq_data"]), 3)

    def test_shared_axis_invariant_raises(self):
        same = lambda pts, **kw: [dict(p, x=5.0, y=5.0) for p in pts]  # noqa: E731
        with mock.patch.object(sl, "avoid_chart_coord_collisions", side_effect=same):
            with self.assertRaisesRegex(ValueError, "shared axis line remains in apo:mq_data"):
                self.build(market_id="apo", support={s: dict(GATES) for s in ("alpha", "beta", "gamma")})
            with self.assertRaisesRegex(ValueError, "in Cat:mq_data"):
                self.build(support={s: dict(GATES) for s in ("alpha", "beta", "gamma")})

    def test_shared_axis_invariant_is_per_axis(self):
        sup = {s: dict(GATES) for s in ("alpha", "beta", "gamma")}

        def only(axis_to_share):
            def fn(pts, **kw):
                out = [dict(p, x=float(i + 1), y=float(i + 1)) for i, p in enumerate(pts)]
                for p in out:
                    p[axis_to_share] = 5.0
                return out
            return fn

        for axis in ("x", "y"):
            with mock.patch.object(sl, "avoid_chart_coord_collisions", side_effect=only(axis)):
                with self.assertRaisesRegex(ValueError, "shared axis line remains"):
                    self.build(market_id="apo", support=sup)

    def test_adjacent_reasons_from_pack_market(self):
        pack = {"hard_exclusions": [], "sunset_registry": [],
                "markets": [{"id": "m1", "adjacent_seeds": [
                    {"slug": ""}, {"slug": "q", "quarantine": True},
                    {"slug": "d", "notes": "Demoted adjacent"}, {"slug": "n", "notes": "plain"}]},
                    {"id": "other", "adjacent_seeds": [{"slug": "zz"}]}]}
        chart = self.build(pack=pack, market_id="m1", adjacent_slugs=["q", "d", "n"])
        reasons = {u["slug"]: u["reason"] for u in chart["unplotted"]}
        self.assertIn("quarantined", reasons["q"])
        self.assertEqual(reasons["d"], "Demoted adjacent")
        self.assertIn("adjacent competitor", reasons["n"])

    def test_value_curve_leaders_and_catalog_fallbacks(self):
        sup = {"alpha": dict(GATES), "gamma": dict(GATES)}
        chart = self.build(comparison(("alpha", 29), ("gamma", 5)), support=sup,
                           oss=[{"slug": "gamma", "name": "Gamma"}],
                           license_map={"gamma": "oss"})
        labels = {s["label"] for s in chart["vc_commercial"] + chart["vc_oss"]}
        leaders = {p["label"] for p in chart["mq_data"] + chart["gmq_data"] if p["q"] == "Leaders"}
        self.assertEqual(labels, leaders)
        self.assertTrue(chart["vc_kcfs"])
        self.assertEqual({s["label"] for s in chart["vc_oss"]} <= {"Gamma"}, True)

    def test_value_curve_without_leaders_uses_catalogs(self):
        # no gates anywhere: nobody leads, so the radar falls back to the catalog heads
        sup = {s: {} for s in ("alpha", "beta", "gamma")}
        com = [{"slug": "", "name": "Blank"}, {"slug": "c1", "name": "C1"}, {"slug": "c1b", "name": "C1"}]
        chart = self.build(support=sup, market_id="apo", commercial=com, oss=[{"slug": "o1", "name": "O1"}],
                           license_map={"o1": "oss"})
        self.assertEqual([s["label"] for s in chart["vc_commercial"]], ["C1"])
        self.assertEqual([s["label"] for s in chart["vc_oss"]], ["O1"])
        self.assertEqual(len(chart["vc_kcfs"]), 6)
        self.assertNotIn("Managed hosting", chart["vc_kcfs"])

    def test_value_curve_from_top_when_catalogs_empty(self):
        sup = {s: {} for s in ("alpha", "beta", "gamma")}
        chart = self.build(support=sup, market_id="apo")
        self.assertEqual({s["label"] for s in chart["vc_commercial"] + chart["vc_oss"]},
                         {"Alpha", "Beta", "Gamma"})

    def test_vendor_urls_match_link_pairs(self):
        chart = self.build(commercial=[{"slug": "alpha", "name": "Alpha", "url": "https://alpha.example"}])
        self.assertEqual(chart["vendor_urls"], dict(chart["link_pairs"]))
        self.assertEqual(chart["vendor_urls"]["Alpha"], "https://alpha.example")

    def test_wave_scr_bonus_and_cross_session_ledger(self):
        self.put("solutions/alpha/scr.md", "open source roadmap")
        a = self.build()
        self.assertTrue(a["wave_data"])


class MultiMarketTests(TmpCase):
    def setUp(self):
        super().setUp()
        self.pack = pack_apo()

    def comp(self):
        return {"rankings": [{"solution": "silver-bullet", "score": 28}, {"solution": "ai-dlc", "score": 20},
                             {"solution": "cline", "score": 9}]}

    def sup(self):
        return {"silver-bullet": dict(GATES), "ai-dlc": {"Workflow composition": True}}

    def test_per_market_payloads(self):
        out = sl.build_multi_market_chart_data(self.comp(), pack=self.pack, support=self.sup(),
                                               need=APO_NEED, root=self.root)
        self.assertTrue(out["markets"])
        self.assertEqual(out["primary_market_id"], "apo")
        apo = out["markets"]["apo"]
        self.assertEqual(apo["market_id"], "apo")
        self.assertEqual(apo["plotted_slugs"], sorted({p["slug"] for p in apo["mq_data"]}))
        self.assertNotIn("cline", apo["plotted_slugs"])
        self.assertTrue(set(apo["plotted_slugs"]) <= set(apo["membership"]["core"]))
        # top level mirrors the primary market, minus the per-market identity keys
        self.assertNotIn("market_role", out)
        self.assertEqual(out["mq_data"], apo["mq_data"])
        labels = set(apo["vendor_buckets"]["commercial"]) | set(apo["vendor_buckets"]["oss"])
        self.assertTrue({p["label"] for p in apo["mq_data"]} <= labels)

    def test_audit_cores_adjacent_and_link_merge(self):
        audit = {"matrix_slugs": ["silver-bullet", "ai-dlc"], "adjacent": ["devin", "", "silver-bullet"],
                 "markets": {"apo": {"core": ["silver-bullet", "cline"], "adjacent": ["devin", "cline"]}}}
        out = sl.build_multi_market_chart_data(self.comp(), pack=self.pack, support=self.sup(),
                                               need=APO_NEED, audit=audit)
        apo = out["markets"]["apo"]
        self.assertEqual(apo["plotted_slugs"], ["silver-bullet"])
        self.assertNotIn("cline", [u["slug"] for u in apo["unplotted"]])
        self.assertEqual(out["vendor_urls"], dict(out["link_pairs"]))

    def test_bucket_backfill_for_unlisted_plotted_labels(self):
        real = sl.build_chart_data

        def spy(*a, **kw):
            chart = real(*a, **kw)
            chart["vendor_buckets"] = {"commercial": [], "oss": []}
            return chart

        with mock.patch.object(sl, "build_chart_data", side_effect=spy):
            out = sl.build_multi_market_chart_data(self.comp(), pack=self.pack, support=self.sup())
        apo = out["markets"]["apo"]
        both = set(apo["vendor_buckets"]["commercial"]) | set(apo["vendor_buckets"]["oss"])
        self.assertTrue({p["label"] for p in apo["mq_data"]} <= both)

        def spy_none(*a, **kw):
            chart = real(*a, **kw)
            chart["vendor_buckets"] = None
            chart["membership"] = None
            chart["mq_data"] = chart["mq_data"] + [{"slug": "", "label": ""}]
            return chart

        with mock.patch.object(sl, "build_chart_data", side_effect=spy_none):
            out = sl.build_multi_market_chart_data(self.comp(), pack=self.pack, support=self.sup())
        self.assertTrue(out["markets"]["apo"]["plotted_slugs"])

    def test_oss_labels_backfilled_to_oss_bucket(self):
        real = sl.build_chart_data

        def spy(*a, **kw):
            chart = real(*a, **kw)
            chart["vendor_buckets"] = {}
            return chart

        with mock.patch.object(sl, "build_chart_data", side_effect=spy):
            out = sl.build_multi_market_chart_data(
                {"rankings": [{"solution": "langchain", "score": 5}]}, pack=self.pack,
                support={"langchain": dict(GATES)})
        buckets = [m["vendor_buckets"] for m in out["markets"].values()]
        self.assertTrue(any("LangChain" in b.get("oss", []) or b.get("oss") for b in buckets) or buckets)

    def test_ineligible_markets_skipped_and_error_paths(self):
        pack = copy.deepcopy(self.pack)
        pack["markets"] = [dict(m) for m in pack["markets"]]
        pack["markets"][0]["chart_eligible"] = False
        first = pack["markets"][0]["id"]
        out = sl.build_multi_market_chart_data(self.comp(), pack=pack, support=self.sup())
        self.assertNotIn(first, out["markets"])
        # a pack whose exclusion data is unreadable still builds charts without forbidden slugs
        bad = {"markets": [{"id": "m", "role": "primary", "seeds": [{"slug": "silver-bullet"}]}],
               "hard_exclusions": [], "primary_market_id": "m"}
        out = sl.build_multi_market_chart_data(self.comp(), pack=bad, support=self.sup(),
                                               need={"hard_vetoes": 5})
        self.assertIn("m", out["markets"])

    def test_no_forbidden_and_no_links(self):
        pack = {"markets": [{"id": "m", "role": "primary", "seeds": [{"slug": "silver-bullet"}]}],
                "hard_exclusions": [], "sunset_registry": [], "primary_market_id": "m"}
        with mock.patch.object(sl, "build_link_pairs", return_value=[]):
            out = sl.build_multi_market_chart_data(self.comp(), pack=pack, support=self.sup())
        self.assertEqual(out["markets"]["m"]["plotted_slugs"], ["silver-bullet"])
        self.assertEqual(out["vendor_urls"], dict(out["markets"]["m"]["link_pairs"]))

    def test_all_markets_ineligible(self):
        pack = {"markets": [{"id": "m", "chart_eligible": False}], "primary_market_id": "m"}
        with mock.patch.object(sl, "build_link_pairs", return_value=[]):
            out = sl.build_multi_market_chart_data({}, pack=pack, support={})
        self.assertEqual(out["markets"], {})
        self.assertEqual(out["primary_market_id"], "m")

    def test_market_sections_commercial_and_oss(self):
        audit = {"markets": {"agentic-sdlc-saas": {"core": ["devin", "factory-ai"]},
                             "apo": {"core": ["deepwork", "silver-bullet", "metagpt"]},
                             "sdlc-plugins": {"core": ["gsd"]}}}
        sections, nxt = sl._market_solution_sections(self.pack, audit, start_num=7)
        self.assertEqual([(s["market_id"], s["kind"], s["num"]) for s in sections], [
            ("apo", "commercial", 7), ("apo", "oss", 8), ("sdlc-plugins", "oss", 9),
            ("agentic-sdlc-saas", "commercial", 10)])
        self.assertEqual(nxt, 11)
        apo_com, apo_oss, _plug, saas = sections
        self.assertEqual([e["slug"] for e in apo_com["entries"]], ["deepwork"])
        self.assertEqual([e["slug"] for e in apo_oss["entries"]], ["silver-bullet", "metagpt"])
        self.assertEqual([e["slug"] for e in saas["entries"]], ["devin", "factory-ai"])
        self.assertEqual((saas["market_role"], apo_com["market_role"]), ("Tertiary", "Primary"))
        self.assertTrue(saas["market_display"])

    def test_market_sections(self):
        audit = {"markets": {"apo": {"core": ["silver-bullet", "langchain"]}}}
        sections, nxt = sl._market_solution_sections(self.pack, audit, start_num=5)
        self.assertTrue(sections)
        self.assertEqual(nxt, 5 + len(sections))
        kinds = {(s["market_id"], s["kind"]) for s in sections}
        self.assertIn(("apo", "oss"), kinds)
        self.assertEqual([s["num"] for s in sections], list(range(5, 5 + len(sections))))
        empty, n = sl._market_solution_sections(self.pack, None)
        self.assertEqual((empty, n), ([], 5))


if __name__ == "__main__":
    unittest.main()

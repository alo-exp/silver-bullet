"""Synthetic-pack tests for solution_classifier branches (offline, no real packs)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import solution_classifier as sc  # noqa: E402


def pack() -> dict:
    return {
        "category_id": "synthetic",
        "primary_market_id": "m1",
        "max_core_count": 25,
        "markets": [
            {
                "id": "m1",
                "role": "primary",
                "display_name": "Market One",
                "seeds": [
                    {"slug": "core-a", "name": "Core A", "must_research": True},
                    {"slug": "core-b", "name": "Core B"},
                    {"slug": "silver-bullet", "name": "Silver Bullet"},
                    {"name": "slugless"},
                ],
                "adjacent_seeds": [
                    {"slug": "adj-quarantine", "name": "Quarantined", "quarantine": True},
                    {"slug": "adj-demoted", "name": "Demoted One", "notes": "Was DEMOTED in 2025"},
                    {"slug": "adj-plain", "name": "Plain Adj", "adjacent_class": "adjc"},
                    {"name": "slugless"},
                ],
            },
            {
                "id": "m2",
                "role": "secondary",
                "display_name": "Market Two",
                "chart_eligible": False,
                "max_core_count": 1,
                "seeds": [{"slug": "core-m2", "name": "Core M2"}, {"slug": "core-m2b", "name": "Core M2B", "must_research": True}],
            },
            {"display_name": "idless market", "seeds": [{"slug": "ignored-seed"}]},
        ],
        "hard_exclusions": [
            {"slug": "excl-ide", "exclusion_class": "ide"},
            {"slug": "excl-bare"},
            {"slug": "core-b"},
            {"name": "slugless"},
        ],
        "sunset_registry": [{"slug": "sun", "reason": "discontinued"}, {"slug": "sun-noreason"}],
        "adjacent_classes": [{"id": "adjc"}, {"id": "ide2"}],
        "exclusion_classes": [{"id": "ide"}],
        "product_aliases": {"corea": "core-a", "old-m2": "core-m2"},
        "parent_child_dedupe": [{"parent_slug": "core-m2b", "prefer_slug": "core-m2"}],
    }


class HelperTests(unittest.TestCase):
    def test_slug_set_and_sunset_map(self) -> None:
        self.assertEqual(sc._slug_set_from_entries([{"slug": "a"}, {"slug": ""}, {"name": "x"}, {"slug": 5}]), {"a", "5"})
        self.assertEqual(sc._sunset_map(pack()), {"sun": "discontinued", "sun-noreason": "sunset"})

    def test_market_core_slug_map_and_adjacent_slugs(self) -> None:
        mapping = sc._market_core_slug_map(pack())
        self.assertEqual(mapping["core-a"], ["m1"])
        self.assertEqual(mapping["core-m2"], ["m2"])
        self.assertNotIn("ignored-seed", mapping)  # market without an id is skipped
        dup = {"markets": [{"id": "a", "seeds": [{"slug": "s"}]}, {"id": "b", "seeds": [{"slug": "s"}]}]}
        self.assertEqual(sc._market_core_slug_map(dup), {"s": ["a", "b"]})
        self.assertEqual(sc._all_adjacent_seed_slugs(pack()), {"adj-quarantine", "adj-demoted", "adj-plain"})

    def test_exclusion_class_by_slug(self) -> None:
        out = sc._exclusion_class_by_slug(pack())
        self.assertEqual(out["excl-ide"], "ide")
        self.assertEqual(out["excl-bare"], "hard_exclusion")
        self.assertNotIn("core-b", out)  # market core seeds are never hard-excluded
        self.assertEqual(out["adj-plain"], "adjc")
        self.assertNotIn("adj-demoted", out)


class MarketClassificationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.market = pack()["markets"][0]

    def classify(self, slug, **over):
        kwargs = dict(envelope_slugs=set(), hard_vetoes=set(), sunset={}, hard_exclusions=set())
        kwargs.update(over)
        return sc._classify_slug_for_market(slug, self.market, **kwargs)

    def test_priority_order(self) -> None:
        self.assertEqual(self.classify("core-a", hard_vetoes={"core-a"}), ("excluded", "hard_veto from need_profile"))
        self.assertEqual(self.classify("core-a", sunset={"core-a": "gone"}), ("sunset", "gone"))
        self.assertEqual(self.classify("zzz", hard_exclusions={"zzz"}), ("excluded", "pack hard_exclusion"))
        # a core seed wins over the hard exclusion list
        self.assertEqual(self.classify("core-a", hard_exclusions={"core-a"}, envelope_slugs={"core-a"}), ("core", "m1 market_seed"))

    def test_core_requires_evidence_except_silver_bullet(self) -> None:
        self.assertEqual(self.classify("core-a", envelope_slugs={"core-a"}), ("core", "m1 market_seed"))
        self.assertEqual(self.classify("core-a"), ("excluded", "m1 seed without envelope evidence (gap)"))
        self.assertEqual(self.classify("silver-bullet"), ("core", "m1 market_seed"))

    def test_adjacent_variants(self) -> None:
        cls, reason = self.classify("adj-quarantine")
        self.assertEqual(cls, "adjacent")
        self.assertIn("quarantined watchlist", reason)
        self.assertEqual(self.classify("adj-demoted"), ("adjacent", "m1 demoted adjacent (not core plotted)"))
        self.assertEqual(self.classify("adj-plain"), ("adjacent", "m1 adjacent_seed"))

    def test_unknown_slug_and_idless_market(self) -> None:
        self.assertEqual(self.classify("unknown"), ("excluded", "not in m1 seeds"))
        idless = {"seeds": []}
        self.assertEqual(
            sc._classify_slug_for_market(5, idless, envelope_slugs=set(), hard_vetoes=set(), sunset={}, hard_exclusions=set()),
            ("excluded", "not in  seeds"),
        )

    def test_adjacent_seed_with_non_dict_lookup_falls_through(self) -> None:
        # adjacent_seeds contains a slug whose seed lookup yields nothing usable: plain adjacent.
        market = {"id": "mx", "adjacent_seeds": [{"slug": "dup", "notes": None}]}
        out = sc._classify_slug_for_market("dup", market, envelope_slugs=set(), hard_vetoes=set(), sunset={}, hard_exclusions=set())
        self.assertEqual(out, ("adjacent", "mx adjacent_seed"))


class ExtractionTests(unittest.TestCase):
    def test_extract_candidates_from_text(self) -> None:
        aliases = {"corea": "core-a", "x": "tiny", "core-a": "core-a", "core-b": "core-b"}
        known = {"core-a": "Core A", "other": "Other Tool", "core-b": "Core B"}
        found = sc._extract_candidates_from_text("We compared COREA and core b and Other Tool; x", aliases, known)
        self.assertEqual(found, ["core-b", "core-a", "other"])
        self.assertEqual(sc._extract_candidates_from_text("nothing relevant", aliases, known), [])
        # alias shorter than two chars is ignored, and duplicates collapse
        self.assertEqual(sc._extract_candidates_from_text("x", {"x": "tiny"}, {}), [])
        self.assertEqual(sc._extract_candidates_from_text("core-a core a Core A", {"core-a": "core-a"}, {"core-a": "Core A"}), ["core-a"])

    def test_envelope_evidence_slugs_resolve_aliases(self) -> None:
        envs = [{"payload": {"evidence": [{"claim": "CoreA is great"}], "claim_candidates": [{"text": "old-m2 helps"}]}}]
        self.assertEqual(sc._envelope_evidence_slugs(envs, pack()), {"core-a", "core-m2"})

    def test_discover_candidates_ranks_and_tokenizes(self) -> None:
        envs = [
            {"payload": {"evidence": [{"claim": "Core A; CoreB, silver-bullet / Core A"}]}},
            {"payload": {"critiques": [{"finding": "x" * 60}, {"finding": "core-b"}, {"finding": " "}]}},
            {"payload": {"gaps": [{"description": "a"}, {"area": "Core M2"}]}},
        ]
        out = sc.discover_candidate_slugs(envs, pack())
        # best-scored slugs first: evidence-backed seeds outrank seeds only scored by the pack
        self.assertEqual(out[:2], ["core-a", "core-b"])
        for slug in ("core-a", "core-b", "silver-bullet", "core-m2", "adj-plain"):
            self.assertIn(slug, out)
        # seeds from every market are scored once, evidence adds more
        self.assertLess(out.index("core-a"), out.index("core-m2b"))
        self.assertLess(out.index("core-m2"), out.index("core-m2b"))
        self.assertEqual(len(out), len(set(out)))


class ClassifySlugTests(unittest.TestCase):
    def kw(self, **over):
        base = dict(
            hard_vetoes=set(), core_seeds={"core-a"}, all_core_seeds={"core-a", "other-market-core"},
            market_core_map={"other-market-core": ["m9"]}, adjacent_seeds={"adj-primary"},
            all_adjacent_seeds={"adj-any", "other-market-core"}, hard_exclusions={"hx", "core-a"},
            sunset={"sun": "dead"}, exclusion_map={"hx": "hard_exclusion", "cls-adj": "adjc", "cls-ex": "ide"},
            adjacent_class_ids={"adjc"}, envelope_slugs=set(),
        )
        base.update(over)
        return base

    def go(self, slug, **over):
        return sc._classify_slug(slug, pack(), **self.kw(**over))

    def test_ordering(self) -> None:
        self.assertEqual(self.go("sun", hard_vetoes={"sun"}), ("excluded", "hard_veto from need_profile"))
        self.assertEqual(self.go("sun"), ("sunset", "dead"))
        self.assertEqual(self.go("hx"), ("excluded", "pack hard_exclusion (hard_exclusion)"))
        self.assertEqual(self.go("hx", exclusion_map={}), ("excluded", "pack hard_exclusion (hard_exclusion)"))
        self.assertEqual(self.go("augment-code")[0], "excluded")
        self.assertIn("augment-cosmos", self.go("augment-code")[1])

    def test_core_seed_evidence_rules(self) -> None:
        self.assertEqual(self.go("core-a", envelope_slugs={"core-a"}), ("core", "pack core_seed"))
        self.assertEqual(self.go("core-a"), ("excluded", "core_seed without envelope evidence (gap)"))
        self.assertEqual(self.go("other-market-core", envelope_slugs={"other-market-core"}), ("core", "m9 market_seed"))
        self.assertEqual(self.go("other-market-core"), ("excluded", "m9 market_seed without envelope evidence (gap)"))
        self.assertEqual(self.go("silver-bullet", all_core_seeds={"silver-bullet"}, market_core_map={}), ("core", "market market_seed"))
        self.assertEqual(self.go("lonely", all_core_seeds={"lonely"}, market_core_map={}), ("excluded", "market market_seed without envelope evidence (gap)"))

    def test_adjacent_and_exclusion_class_paths(self) -> None:
        self.assertEqual(self.go("adj-any"), ("adjacent", "pack adjacent_seed"))
        self.assertEqual(self.go("adj-primary"), ("adjacent", "pack adjacent_seed"))
        self.assertEqual(self.go("cls-adj"), ("adjacent", "exclusion_class adjc (adjacent only)"))
        self.assertEqual(self.go("cls-ex"), ("excluded", "exclusion_class ide"))
        self.assertEqual(self.go("nothing"), ("excluded", "not in pack seeds and no inclusion evidence"))

    def test_alias_is_resolved_first(self) -> None:
        self.assertEqual(self.go("CoreA", envelope_slugs={"core-a"}), ("core", "pack core_seed"))


class ClassifySolutionsTests(unittest.TestCase):
    def envs(self, *claims):
        return [{"payload": {"evidence": [{"claim": c} for c in claims]}}]

    def test_requires_a_pack(self) -> None:
        with self.assertRaisesRegex(ValueError, "category pack required"):
            sc.classify_solutions([], None, None)
        with self.assertRaisesRegex(ValueError, "category pack required"):
            sc.classify_solutions([], {"category_pack_id": ""})
        with self.assertRaisesRegex(ValueError, "category pack required"):
            sc.classify_solutions([], {"category_pack_id": "does-not-exist"})

    def test_end_to_end_classification(self) -> None:
        claims = [
            "Core A and Core B are strong",
            "core-m2 plus Core M2B and old-m2",
            "Quarantined, Demoted One and Plain Adj are adjacent; excl-ide and sun were seen",
            "totally-unknown-tool is mentioned",
        ]
        need = {"hard_vetoes": ["Core B"], "must_research": ["core-m2b", "never-seen"]}
        audit = sc.classify_solutions(self.envs(*claims), need, pack())
        self.assertEqual(audit["pack_id"], "synthetic")
        self.assertEqual(audit["primary_market_id"], "m1")
        self.assertEqual(audit["core"], ["core-a", "silver-bullet"])
        self.assertEqual(audit["by_slug"]["core-b"], {"classification": "excluded", "reason": "hard_veto from need_profile"})
        self.assertEqual(audit["by_slug"]["sun"]["classification"], "sunset")
        self.assertIn("sun", audit["sunset"])
        self.assertEqual(audit["by_slug"]["excl-ide"]["reason"], "pack hard_exclusion (ide)")
        self.assertIn("adj-plain", audit["adjacent"])
        self.assertEqual(audit["by_slug"]["adj-plain"]["classification"], "adjacent")
        self.assertNotIn("core-a", audit["excluded"])
        # market 2 is capped at max_core_count=1 and prefers must_research; dedupe drops the parent
        m2 = audit["markets"]["m2"]
        self.assertFalse(m2["chart_eligible"])
        self.assertEqual(m2["core"], ["core-m2"])
        self.assertEqual(audit["matrix_slugs"], ["core-a", "core-m2", "silver-bullet"])
        self.assertEqual(audit["by_slug"]["core-m2"]["reason"], "m2 market_core (matrix)")
        self.assertEqual(audit["by_slug"]["core-a"]["reason"], "pack core_seed")
        # alias mirrored into by_slug
        self.assertEqual(audit["by_slug"]["old-m2"]["canonical_slug"], "core-m2")
        # must_research gap list: never-seen has no evidence; core-m2b has evidence but was deduped out
        self.assertIn("never-seen", audit["gaps"])
        self.assertEqual(audit["counts"]["gaps"], len(audit["gaps"]))
        self.assertEqual(audit["counts"]["core"], 2)
        self.assertEqual(audit["counts"]["matrix_slugs"], 3)
        self.assertEqual(audit["markets"][""]["role"], None)
        # core slugs from a market never show up as adjacent anywhere
        for market_audit in audit["markets"].values():
            self.assertFalse(set(market_audit["adjacent"]) & {"core-a", "core-m2"})

    def test_market_core_overflow_keeps_must_research_first(self) -> None:
        p = pack()
        p["parent_child_dedupe"] = []
        audit = sc.classify_solutions(self.envs("Core M2 and Core M2B"), None, p)
        self.assertEqual(audit["markets"]["m2"]["core"], ["core-m2b"])
        self.assertIn("core-m2b", audit["matrix_slugs"])
        self.assertNotIn("core-m2", audit["matrix_slugs"])

    def test_parent_child_dedupe_demotes_core_in_by_slug(self) -> None:
        p = pack()
        p["markets"][0]["seeds"].append({"slug": "child-x", "name": "Child X"})
        p["parent_child_dedupe"] = [{"parent_slug": "core-a", "prefer_slug": "child-x"}]
        audit = sc.classify_solutions(self.envs("Core A and Child X"), None, p)
        self.assertNotIn("core-a", audit["core"])
        self.assertIn("child-x", audit["core"])
        self.assertIn("core-a", audit["excluded"])
        self.assertEqual(audit["by_slug"]["core-a"]["classification"], "excluded")

    def test_market_without_primary_core_and_no_max_uses_default(self) -> None:
        p = {"category_id": "tiny", "markets": [{"id": "only", "role": "primary", "seeds": [{"slug": "one"}]}]}
        audit = sc.classify_solutions(self.envs("one is here"), {}, p)
        self.assertEqual(audit["core"], ["one"])
        self.assertEqual(audit["markets"]["only"]["core"], ["one"])
        audit2 = sc.classify_solutions([], None, {"category_id": "t2", "primary_market_id": "ghost",
                                                  "markets": [{"id": "only", "seeds": []}]})
        self.assertEqual(audit2["core"], [])


class AuditIoTests(unittest.TestCase):
    def test_write_catalog_audit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = sc.write_catalog_audit(tmp, {"a": 1})
            self.assertEqual(out, Path(tmp) / "landscape" / "catalog_audit.json")
            self.assertEqual(json.loads(out.read_text(encoding="utf-8")), {"a": 1})

    def test_classify_and_audit_reads_files_and_handles_bad_shapes(self) -> None:
        p = {"category_id": "tiny", "markets": [{"id": "only", "role": "primary", "seeds": [{"slug": "one"}]}]}
        captured = {}

        def fake_classify(envelopes, need):
            captured["envelopes"] = envelopes
            captured["need"] = need
            return {"marker": True}

        orig = sc.classify_solutions
        sc.classify_solutions = fake_classify
        try:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                # nothing on disk: empty need and envelopes
                audit = sc.classify_and_audit(root)
                self.assertEqual(audit, {"marker": True})
                self.assertEqual((captured["need"], captured["envelopes"]), ({}, []))
                self.assertTrue((root / "landscape" / "catalog_audit.json").is_file())
                (root / "need_profile.json").write_text(json.dumps({"k": 1}), encoding="utf-8")
                (root / "contributions").mkdir()
                env_path = root / "contributions" / "all-envelopes.json"
                env_path.write_text(json.dumps([{"a": 1}, "junk", 3]), encoding="utf-8")
                sc.classify_and_audit(root)
                self.assertEqual(captured["need"], {"k": 1})
                self.assertEqual(captured["envelopes"], [{"a": 1}])
                env_path.write_text(json.dumps({"not": "a list"}), encoding="utf-8")
                sc.classify_and_audit(root)
                self.assertEqual(captured["envelopes"], [])
                # explicit arguments bypass the files
                sc.classify_and_audit(root, envelopes=[{"z": 1}], need={"n": 2})
                self.assertEqual((captured["need"], captured["envelopes"]), ({"n": 2}, [{"z": 1}]))
        finally:
            sc.classify_solutions = orig
        del p


if __name__ == "__main__":
    unittest.main()

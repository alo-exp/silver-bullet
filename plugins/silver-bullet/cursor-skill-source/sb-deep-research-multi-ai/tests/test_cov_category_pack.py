"""Synthetic-pack unit tests for category_pack (loader, getters, builders, catalog split)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import category_pack as cp  # noqa: E402


def legacy_pack() -> dict:
    """Pack with no ``markets`` key: markets are synthesized from core_seeds."""
    return {
        "category_id": "demo-pack",
        "display_name": "Demo",
        "definition": "A demo market",
        "primary_market_id": "demo",
        "core_seeds": [
            {"slug": "alpha", "name": "Alpha", "must_research": True, "license": "oss",
             "homepage": " https://alpha.example ", "github": "org/alpha"},
            {"slug": "beta", "name": "Beta"},
            {"name": "no slug"},
        ],
        "adjacent_seeds": [{"slug": "gamma", "name": "Gamma", "official_url": "https://gamma.example"}],
        "hard_exclusions": [{"slug": "bad", "name": "Bad"}, {"slug": "alpha"}, {"name": "slugless"}],
        "sunset_registry": [{"slug": "old", "name": "Old"}, {"name": "slugless"}],
        "product_aliases": {"Alpha_Old": "alpha", "alpha": "alpha", "x y": "beta"},
        "parent_child_dedupe": [
            {"parent_slug": "beta", "prefer_slug": "alpha"},
            {"parent_slug": "", "prefer_slug": "alpha"},
            {"parent_slug": "alpha", "prefer_slug": "alpha"},
        ],
        "exclusion_classes": [{"id": "ide", "label": "IDE", "description": "d"}, {"label": "no id"}],
        "adjacent_classes": [{"id": "adj"}, {"label": "no id"}],
        "feature_axes": [{"id": "ax"}],
        "inclusion_criteria": {
            "min_pass_count": 2,
            "criteria": [{"id": "c1", "label": "L1", "description": " d1 "}, {"id": "c2", "label": "L2", "description": "d2"}, {"id": "c3", "label": "L3", "description": "d3"}],
        },
        "min_core_count": 1,
        "max_core_count": 9,
        "jobs_to_be_done": ["job one"],
    }


def multi_pack() -> dict:
    return {
        "category_id": "multi",
        "display_name": "Multi",
        "primary_market_id": "m1",
        "markets": [
            {"id": "m1", "display_name": "M1", "role": "primary",
             "seeds": [{"slug": "a", "name": "A", "must_research": True}, {"slug": "b"}],
             "adjacent_seeds": [{"slug": "c", "name": "C"}, {"name": "slugless"}]},
            {"id": "m2", "display_name": "M2", "role": "secondary", "seeds": [{"slug": "d", "name": "D"}, {"name": "x"}]},
            {"display_name": "idless", "seeds": [{"slug": "e"}]},
        ],
    }


class LoaderTests(unittest.TestCase):
    def test_skill_root_found_and_missing(self) -> None:
        self.assertTrue((cp._deep_research_skill_root() / "schemas" / "need_profile.schema.json").is_file())
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "a" / "b" / "category_pack.py"
            fake.parent.mkdir(parents=True)
            with mock.patch.object(cp, "__file__", str(fake)):
                with self.assertRaisesRegex(FileNotFoundError, "silver-deep-research skill root not found"):
                    cp._deep_research_skill_root()

    def test_skill_root_via_skills_subdirectory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            schemas = root / "skills" / "silver-deep-research" / "schemas"
            schemas.mkdir(parents=True)
            (schemas / "need_profile.schema.json").write_text("{}", encoding="utf-8")
            fake = root / "mirror" / "scripts" / "category_pack.py"
            fake.parent.mkdir(parents=True)
            with mock.patch.object(cp, "__file__", str(fake)):
                self.assertEqual(cp._deep_research_skill_root().resolve(), (root / "skills" / "silver-deep-research").resolve())

    def test_load_category_pack_validation(self) -> None:
        for bad in ("", "has space", "../x", "a/b"):
            with self.assertRaisesRegex(ValueError, "invalid category_pack_id"):
                cp.load_category_pack(bad)
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "ok-pack.json").write_text(json.dumps({"category_id": "ok-pack"}), encoding="utf-8")
            (d / "wrong.json").write_text(json.dumps({"category_id": "other"}), encoding="utf-8")
            with mock.patch.object(cp, "category_packs_dir", return_value=d):
                self.assertEqual(cp.load_category_pack("ok-pack"), {"category_id": "ok-pack"})
                with self.assertRaisesRegex(FileNotFoundError, "category pack not found: nope"):
                    cp.load_category_pack("nope")
                with self.assertRaisesRegex(ValueError, "does not match id 'wrong'"):
                    cp.load_category_pack("wrong")

    def test_resolve_pack_from_need_profile(self) -> None:
        pack = legacy_pack()
        with mock.patch.object(cp, "load_category_pack", return_value=pack):
            with self.assertRaisesRegex(ValueError, "missing category_pack_id"):
                cp.resolve_pack_from_need_profile({})
            plain = cp.resolve_pack_from_need_profile({"category_pack_id": "demo-pack"})
            self.assertEqual(plain["inclusion_criteria"], pack["inclusion_criteria"])
            self.assertTrue(plain["allow_adjacent_section"])
            self.assertEqual(plain["must_research"], ["alpha"])
            self.assertEqual(plain["hard_exclusion_slugs"], ["bad", "old"])
            custom_inc = {"criteria": [{"id": "z"}]}
            custom_exc = [{"id": "q"}]
            merged = cp.resolve_pack_from_need_profile(
                {
                    "category_pack_id": "demo-pack",
                    "inclusion_criteria": custom_inc,
                    "exclusion_classes": custom_exc,
                    "allow_adjacent_section": False,
                    "must_research": ["Zed Product"],
                    "hard_vetoes": ["Alpha Old"],
                }
            )
            self.assertEqual(merged["inclusion_criteria"], custom_inc)
            self.assertEqual(merged["exclusion_classes"], custom_exc)
            self.assertFalse(merged["allow_adjacent_section"])
            self.assertIn("zed-product", merged["must_research"])
            self.assertIn("alpha", merged["hard_exclusion_slugs"])
            # the base pack is not mutated
            self.assertEqual(pack["inclusion_criteria"]["min_pass_count"], 2)

    def test_resolve_pack_from_need_swallows_loader_errors(self) -> None:
        self.assertIsNone(cp.resolve_pack_from_need(None))
        self.assertIsNone(cp.resolve_pack_from_need({}))
        self.assertIsNone(cp.resolve_pack_from_need({"category_pack_id": ""}))
        with mock.patch.object(cp, "resolve_pack_from_need_profile", side_effect=FileNotFoundError("x")):
            self.assertIsNone(cp.resolve_pack_from_need({"category_pack_id": "a"}))
        with mock.patch.object(cp, "resolve_pack_from_need_profile", side_effect=ValueError("x")):
            self.assertIsNone(cp.resolve_pack_from_need({"category_pack_id": "a"}))
        with mock.patch.object(cp, "resolve_pack_from_need_profile", return_value={"k": 1}):
            self.assertEqual(cp.resolve_pack_from_need({"category_pack_id": "a"}), {"k": 1})


class CriteriaTests(unittest.TestCase):
    def test_get_inclusion_criteria_requires_criteria(self) -> None:
        for pack in ({}, {"inclusion_criteria": {}}, {"inclusion_criteria": {"criteria": []}}):
            with self.assertRaisesRegex(ValueError, "criteria is empty"):
                cp.get_inclusion_criteria(pack)
        self.assertEqual(cp.get_inclusion_criteria(legacy_pack())["min_pass_count"], 2)

    def test_format_prose_uses_threshold_fallbacks_and_skips_non_dicts(self) -> None:
        prose = cp.format_inclusion_criteria_prose(legacy_pack())
        self.assertIn("**2 of 3**", prose)
        self.assertIn("- **L1** — d1", prose)
        self.assertIn("- **L3** — d3", prose)
        junk = {"inclusion_criteria": {"min_pass_count": 1, "criteria": ["junk", {"id": "k", "label": "K", "description": "dk"}]}}
        prose_junk = cp.format_inclusion_criteria_prose(junk)
        self.assertNotIn("junk", prose_junk)
        self.assertIn("**1 of 2**", prose_junk)
        self.assertIn("- **K** — dk", prose_junk)
        fallback = {"inclusion_threshold": 4, "inclusion_criteria": {"criteria": [{"id": "only"}]}}
        prose2 = cp.format_inclusion_criteria_prose(fallback)
        self.assertIn("**4 of 1**", prose2)
        self.assertIn("- **only** — ", prose2)
        default = {"inclusion_criteria": {"criteria": [{"description": "d"}]}}
        prose3 = cp.format_inclusion_criteria_prose(default)
        self.assertIn("**3 of 1**", prose3)
        self.assertIn("- **Criterion** — d", prose3)


class MarketGetterTests(unittest.TestCase):
    def test_get_markets_explicit_and_synthesized(self) -> None:
        mp = multi_pack()
        self.assertEqual([m.get("id") for m in cp.get_markets(mp)], ["m1", "m2", None])
        synth = cp.get_markets(legacy_pack())
        self.assertEqual(len(synth), 1)
        self.assertEqual(synth[0]["id"], "demo")
        self.assertEqual(synth[0]["role"], "primary")
        self.assertEqual(len(synth[0]["seeds"]), 3)
        bare = cp.get_markets({})
        self.assertEqual(bare[0]["id"], "apo")
        self.assertEqual(bare[0]["display_name"], "Primary market")
        self.assertEqual(bare[0]["seeds"], [])
        self.assertEqual(bare[0]["adjacent_seeds"], [])

    def test_primary_market_id_and_lookup(self) -> None:
        self.assertEqual(cp.get_primary_market_id(multi_pack()), "m1")
        self.assertEqual(cp.get_primary_market_id({"markets": [{"id": "first"}]}), "first")
        self.assertEqual(cp.get_primary_market_id({}), "apo")
        self.assertEqual(cp.get_market_by_id(multi_pack(), "m2")["display_name"], "M2")
        self.assertIsNone(cp.get_market_by_id(multi_pack(), "zzz"))

    def test_market_seed_getters(self) -> None:
        mp = multi_pack()
        self.assertEqual([s["slug"] for s in cp.get_market_seeds(mp, "m2") if "slug" in s], ["d"])
        self.assertEqual(cp.get_market_seeds(mp, "unknown"), [])
        self.assertEqual([s["slug"] for s in cp.get_market_seeds(mp)], ["a", "b"])
        self.assertEqual([s["slug"] for s in cp.get_market_adjacent_seeds(mp, "m1") if "slug" in s], ["c"])
        self.assertEqual(cp.get_market_adjacent_seeds(mp, "unknown"), [])

    def test_all_market_seed_slugs(self) -> None:
        mp = multi_pack()
        self.assertEqual(cp.get_all_market_seed_slugs(mp), ["a", "b", "d", "e"])
        self.assertEqual(cp.get_all_market_seed_slugs(mp, include_adjacent=True), ["a", "b", "c", "d", "e"])

    def test_core_and_adjacent_seed_fallbacks(self) -> None:
        # primary market exists but has no seeds -> falls back to top-level core_seeds
        pack = {"primary_market_id": "p", "markets": [{"id": "p", "seeds": []}],
                "core_seeds": [{"slug": "legacy"}], "adjacent_seeds": [{"slug": "ladj"}]}
        self.assertEqual(cp.get_core_seed_slugs(pack), ["legacy"])
        # primary market has adjacent_seeds == [] (not None) -> returns the empty list
        pack["markets"][0]["adjacent_seeds"] = []
        self.assertEqual(cp.get_adjacent_seed_slugs(pack), [])
        # primary market lacks adjacent_seeds -> falls back to the pack level list
        del pack["markets"][0]["adjacent_seeds"]
        self.assertEqual(cp.get_adjacent_seed_slugs(pack), ["ladj"])
        # primary market id does not exist
        orphan = {"primary_market_id": "none", "markets": [{"id": "x", "seeds": [{"slug": "s"}]}],
                  "core_seeds": [{"slug": "top"}, {"name": "slugless"}]}
        self.assertEqual(cp.get_core_seed_slugs(orphan), ["top"])
        self.assertEqual(cp.get_adjacent_seeds(orphan), [])

    def test_must_research_slugs(self) -> None:
        self.assertEqual(cp.get_must_research_slugs(legacy_pack()), ["alpha"])
        need = {"must_research": ["Some Thing", "alpha"], "must_haves": ["capability words", "slug-like", "plain"]}
        self.assertEqual(cp.get_must_research_slugs(legacy_pack(), need), ["alpha", "some-thing", "slug-like"])
        self.assertEqual(cp.get_must_research_slugs(legacy_pack(), {}), ["alpha"])

    def test_registries_and_class_ids(self) -> None:
        pack = legacy_pack()
        self.assertEqual([e["slug"] for e in cp.get_hard_exclusions(pack) if "slug" in e], ["bad", "alpha"])
        self.assertEqual(len(cp.get_sunset_registry(pack)), 2)
        self.assertEqual(cp.get_exclusion_class_ids(pack), ["ide"])
        self.assertEqual(cp.get_adjacent_class_ids(pack), ["adj"])
        self.assertEqual(cp.get_feature_axes(pack), [{"id": "ax"}])
        self.assertEqual(cp.get_exclusion_class_ids({}), [])
        self.assertEqual(cp.get_adjacent_class_ids({}), [])
        self.assertEqual(cp.get_feature_axes({}), [])
        self.assertEqual(cp.get_hard_exclusions({}), [])
        self.assertEqual(cp.get_sunset_registry({}), [])
        self.assertEqual(cp.get_parent_child_dedupe({}), [])

    def test_hard_exclusion_slugs_skip_market_cores_and_apply_vetoes(self) -> None:
        pack = legacy_pack()
        # "alpha" is a core seed so its exclusion entry is ignored; sunset slugs always count
        self.assertEqual(cp.get_hard_exclusion_slugs(pack), {"bad", "old"})
        self.assertEqual(cp.get_hard_exclusion_slugs(pack, {"hard_vetoes": ["Alpha Old", "Brand New"]}),
                         {"bad", "old", "alpha", "brand-new"})
        self.assertEqual(cp.get_hard_exclusion_slugs(pack, {}), {"bad", "old"})


class AliasTests(unittest.TestCase):
    def test_product_aliases_normalized(self) -> None:
        self.assertEqual(cp.get_product_aliases(legacy_pack()), {"alpha-old": "alpha", "alpha": "alpha", "x-y": "beta"})
        self.assertEqual(cp.get_product_aliases({}), {})

    def test_expand_by_slug_aliases(self) -> None:
        by_slug = {"alpha": {"classification": "core", "reason": "r"}, "beta": {"classification": "core"}}
        out = cp.expand_by_slug_aliases(by_slug, legacy_pack())
        self.assertEqual(out["alpha-old"]["canonical_slug"], "alpha")
        self.assertEqual(out["alpha-old"]["reason"], "alias of alpha: r")
        self.assertEqual(out["x-y"]["reason"], "alias of beta: ")
        self.assertNotIn("canonical_slug", out["alpha"])
        self.assertEqual(by_slug.keys(), {"alpha", "beta"})
        # canonical missing from by_slug, or alias already classified: nothing mirrored
        self.assertEqual(cp.expand_by_slug_aliases({}, legacy_pack()), {})
        pre = {"alpha": {"classification": "core"}, "alpha-old": {"classification": "excluded"}}
        out2 = cp.expand_by_slug_aliases(pre, legacy_pack())
        self.assertEqual(out2["alpha-old"], {"classification": "excluded"})

    def test_resolve_canonical_slug_follows_chains_and_stops_on_cycles(self) -> None:
        pack = {"product_aliases": {"a": "b", "b": "c", "loop1": "loop2", "loop2": "loop1"}}
        self.assertEqual(cp.resolve_canonical_slug(" A ", pack), "c")
        self.assertEqual(cp.resolve_canonical_slug("plain", pack), "plain")
        self.assertIn(cp.resolve_canonical_slug("loop1", pack), {"loop1", "loop2"})

    def test_parent_child_dedupe(self) -> None:
        pack = legacy_pack()
        self.assertEqual(cp.apply_parent_child_dedupe(["beta", "alpha", "Alpha_Old"], pack), ["alpha"])
        self.assertEqual(cp.apply_parent_child_dedupe(["beta", "gamma"], pack), ["beta", "gamma"])
        self.assertEqual(cp.apply_parent_child_dedupe([], pack), [])

    def test_normalize_and_slugify(self) -> None:
        pack = legacy_pack()
        self.assertEqual(cp.slugify(" Foo_Bar baz "), "foo-bar-baz")
        self.assertIsNone(cp.normalize_slug("", pack))
        self.assertIsNone(cp.normalize_slug("", None))
        self.assertEqual(cp.normalize_slug("Foo Bar", None), "foo-bar")
        self.assertEqual(cp.normalize_slug("Foo Bar", {}), "foo-bar")
        self.assertEqual(cp.normalize_slug("Alpha Old", pack), "alpha")


class BuilderTests(unittest.TestCase):
    def test_prompt_block_single_and_multi_market(self) -> None:
        base = legacy_pack()
        base["exclusion_classes"] = [{"id": "ide", "label": "IDE", "description": "d"}]
        single = cp.pack_prompt_block(base)
        self.assertIn("## Category market contract — Demo", single)
        self.assertIn("- job one", single)
        self.assertIn("candidate must pass ≥2 of 3", single)
        self.assertIn("`ide` — IDE: d", single)
        self.assertIn("**Must-research core seeds:** Alpha, Beta, no slug", single)
        self.assertIn("**Adjacent-only seeds (short Adjacent section if enabled):** Gamma", single)
        self.assertIn("**Hard exclusions (never list as in-scope):** Bad, alpha, slugless", single)
        self.assertIn("**Sunset / discontinued (never list):** Old, slugless", single)
        self.assertIn("1–9 in-scope", single)
        self.assertNotIn("Multi-market landscape", single)
        mp = multi_pack()
        mp["inclusion_criteria"] = {"criteria": [{"id": "c", "label": "L", "description": "D"}]}
        multi = cp.pack_prompt_block(mp)
        self.assertIn("Multi-market landscape", multi)
        self.assertIn("**M2** (`m2`, secondary): D, x", multi)
        self.assertIn("**idless** (`None`, None): e", multi)
        self.assertIn("## Category market contract — Multi", multi)
        # no display name falls back to the category id
        nodisplay = {"category_id": "cid", "inclusion_criteria": {"criteria": [{"id": "c", "label": "L", "description": "D"}]}}
        self.assertIn("## Category market contract — cid", cp.pack_prompt_block(nodisplay))

    def test_alias_map_and_known_solutions(self) -> None:
        pack = legacy_pack()
        aliases = cp.build_alias_map(pack)
        self.assertEqual(aliases["alpha"], "alpha")
        self.assertEqual(aliases["alpha-old"], "alpha")
        self.assertEqual(aliases["beta"], "beta")
        self.assertEqual(aliases["gamma"], "gamma")
        self.assertEqual(aliases["bad"], "bad")
        self.assertEqual(aliases["old"], "old")
        self.assertEqual(aliases["x-y"], "beta")
        # a seed without a name only registers its slug
        nameless = cp.build_alias_map({"core_seeds": [{"slug": "solo"}]})
        self.assertEqual(nameless, {"solo": "solo"})
        known = cp.build_known_solutions(pack)
        self.assertEqual(known["beta"], "Beta")
        self.assertEqual(known["gamma"], "Gamma")
        self.assertEqual(known["old"], "Old")
        # the nameless hard-exclusion entry for alpha overrides the seed name; aliases mirror it
        self.assertEqual(known["alpha"], "alpha")
        self.assertEqual(known["alpha-old"], "alpha")
        self.assertEqual(known["x-y"], "Beta")
        self.assertNotIn("slugless", known)
        # a seed without a name falls back to its slug
        self.assertEqual(cp.build_known_solutions({"markets": [{"id": "m", "seeds": [{"slug": "zz"}]}],
                                                    "hard_exclusions": [{"slug": "hh"}]}), {"zz": "zz", "hh": "hh"})

    def test_license_by_slug(self) -> None:
        pack = legacy_pack()
        lic = cp.build_license_by_slug(pack)
        self.assertEqual(lic["alpha"], "oss")
        self.assertEqual(lic["beta"], "commercial")
        self.assertEqual(lic["alpha-old"], "oss")
        # legacy top-level seeds not covered by markets are added; slugless seeds skipped
        pack2 = {"markets": [{"id": "m", "seeds": []}],
                 "core_seeds": [{"slug": "top-only", "license": "oss"}, {"name": "n"}],
                 "adjacent_seeds": [{"slug": "adj-top"}]}
        lic2 = cp.build_license_by_slug(pack2)
        self.assertEqual(lic2, {"top-only": "oss", "adj-top": "commercial"})
        # a seed already described by a market keeps the market's license
        pack3 = {"markets": [{"id": "m", "seeds": [{"slug": "in-market", "license": "oss"}]}]}
        self.assertEqual(cp.build_license_by_slug(pack3), {"in-market": "oss"})

    def test_overview_seeds(self) -> None:
        self.assertEqual(cp.build_overview_seeds({}), {})
        self.assertEqual(cp.build_overview_seeds({"overview_seeds": {"a": "b"}}), {"a": "b"})

    def test_homepage_and_github_maps(self) -> None:
        pack = legacy_pack()
        pack["homepage_by_slug"] = {"beta": " https://beta.example ", "": "x", "empty": ""}
        pack["github_by_slug"] = {"beta": "org/beta", "": "x", "empty": ""}
        pack["product_aliases"]["from-alias"] = "delta"
        pack["homepage_by_slug"]["from-alias"] = "https://alias.example"
        pack["github_by_slug"]["from-alias"] = "org/alias"
        home = cp.build_homepage_by_slug(pack)
        self.assertEqual(home["alpha"], "https://alpha.example")
        self.assertEqual(home["beta"], "https://beta.example")
        self.assertEqual(home["gamma"], "https://gamma.example")
        self.assertEqual(home["alpha-old"], "https://alpha.example")
        self.assertEqual(home["delta"], "https://alias.example")
        self.assertNotIn("empty", home)
        gh = cp.build_github_by_slug(pack)
        self.assertNotIn("empty", gh)
        self.assertEqual(gh["alpha"], "org/alpha")
        self.assertEqual(gh["alpha-old"], "org/alpha")
        self.assertEqual(gh["delta"], "org/alias")
        # non-dict maps and non-dict / slugless seeds are ignored
        weird = {"homepage_by_slug": ["x"], "github_by_slug": "str",
                 "markets": [{"id": "m", "seeds": ["junk", {"name": "no slug", "homepage": "h"}, {"slug": "s"}]}]}
        self.assertEqual(cp.build_homepage_by_slug(weird), {})
        self.assertEqual(cp.build_github_by_slug(weird), {})

    def test_seed_url_helpers(self) -> None:
        self.assertEqual(cp._seed_homepage({"url": " u "}), "u")
        self.assertEqual(cp._seed_homepage({"homepage_url": "h", "url": ""}), "h")
        self.assertIsNone(cp._seed_homepage({}))
        self.assertEqual(cp._seed_github({"repo_url": " r "}), "r")
        self.assertEqual(cp._seed_github({"github_url": "g"}), "g")
        self.assertIsNone(cp._seed_github({"github": ""}))

    def test_catalog_entries_split(self) -> None:
        pack = legacy_pack()
        commercial, oss = cp.catalog_entries_from_pack(pack, ["alpha", "beta", "unknown-thing"])
        self.assertEqual([e["slug"] for e in oss], ["alpha"])
        self.assertEqual(oss[0]["license"], "OSS")
        self.assertEqual(oss[0]["url"], "https://alpha.example")
        self.assertEqual(oss[0]["github"], "org/alpha")
        self.assertEqual([e["slug"] for e in commercial], ["beta", "unknown-thing"])
        self.assertEqual(commercial[1]["name"], "Unknown Thing")
        self.assertNotIn("url", commercial[0])
        self.assertNotIn("github", commercial[0])
        mp = multi_pack()
        c, o = cp.catalog_entries_from_pack(mp, ["a", "d", "b"], market_id="m1")
        self.assertEqual([e["slug"] for e in c], ["a", "b"])
        self.assertEqual(o, [])
        c2, _ = cp.catalog_entries_from_pack(mp, ["a"], market_id="missing")
        self.assertEqual(c2, [])

    def test_market_slug_sets(self) -> None:
        self.assertEqual(cp.market_slug_sets(multi_pack()), {"m1": {"a", "b"}, "m2": {"d"}})
        self.assertEqual(cp.market_slug_sets(legacy_pack()), {"demo": {"alpha", "beta"}})


if __name__ == "__main__":
    unittest.main()

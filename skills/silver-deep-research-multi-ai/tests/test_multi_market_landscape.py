"""Multi-market landscape engine contracts."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
DR_SKILL = SCRIPTS.parent.parent / "silver-deep-research"
PACK_PATH = DR_SKILL / "reference" / "landscape" / "category-packs" / "agentic-sdlc-process-orchestrator.json"

sys.path.insert(0, str(SCRIPTS))

from category_pack import (  # noqa: E402
    build_license_by_slug,
    get_markets,
    load_category_pack,
)
from materialize_solution_artifacts import materialize_solution_artifacts  # noqa: E402
from solution_classifier import classify_solutions  # noqa: E402
from synthesize_landscape import build_multi_market_chart_data  # noqa: E402


class MultiMarketPackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pack = load_category_pack("agentic-sdlc-process-orchestrator")

    def test_pack_has_three_markets(self) -> None:
        markets = get_markets(self.pack)
        self.assertEqual(len(markets), 3)
        ids = [m["id"] for m in markets]
        self.assertEqual(ids, ["apo", "sdlc-plugins", "agentic-sdlc-saas"])

    def test_zuvo_is_oss_in_sdlc_plugins_not_apo_core(self) -> None:
        apo_slugs = {s["slug"] for s in self.pack["markets"][0]["seeds"]}
        plugin_core = {s["slug"] for s in self.pack["markets"][1]["seeds"]}
        plugin_adj = {s["slug"] for s in self.pack["markets"][1]["adjacent_seeds"]}
        self.assertNotIn("zuvo", apo_slugs)
        self.assertIn("zuvo", plugin_core)
        self.assertNotIn("zuvo", plugin_adj)
        licenses = build_license_by_slug(self.pack)
        self.assertEqual(licenses["zuvo"], "oss")

    def test_sdlc_plugin_alias_maps_to_zuvo_not_apo(self) -> None:
        """sdlc-plugin was a mis-seeded APO commercial duplicate of Zuvo research."""
        from category_pack import resolve_canonical_slug

        apo_slugs = {s["slug"] for s in self.pack["markets"][0]["seeds"]}
        core_slugs = {s["slug"] for s in self.pack.get("core_seeds") or []}
        self.assertNotIn("sdlc-plugin", apo_slugs)
        self.assertNotIn("sdlc-plugin", core_slugs)
        self.assertEqual(resolve_canonical_slug("sdlc-plugin", self.pack), "zuvo")
        self.assertEqual(resolve_canonical_slug("sdlc", self.pack), "zuvo")
        plugin_core = {s["slug"] for s in self.pack["markets"][1]["seeds"]}
        plugin_adj = {s["slug"] for s in self.pack["markets"][1]["adjacent_seeds"]}
        self.assertIn("zuvo", plugin_core)
        self.assertNotIn("zuvo", plugin_adj)

    def test_bmad_and_gsd_in_sdlc_plugins_market(self) -> None:
        plugin_slugs = {s["slug"] for s in self.pack["markets"][1]["seeds"]}
        self.assertIn("bmad", plugin_slugs)
        self.assertIn("gsd", plugin_slugs)
        self.assertIn("superpowers", plugin_slugs)
        self.assertIn("spec-kit", plugin_slugs)


class MultiMarketClassifierTests(unittest.TestCase):
    def test_secondary_market_core_includes_bmad_gsd_with_evidence(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        envelopes = [
            {
                "phase_id": "DR-RETRIEVE",
                "logical_model_id": "test",
                "payload": {
                    "evidence": [
                        {"claim": "BMAD provides multi-agent SDLC phases with structured handoffs."},
                        {"claim": "GSD runs Discuss, Plan, Execute, Verify, Ship per milestone."},
                        {"claim": "Zuvo is an open-source SDLC plugin for Claude Code."},
                        {"claim": "Silver Bullet ships hook-enforced APO workflows."},
                    ]
                },
            }
        ]
        audit = classify_solutions(envelopes, {"category_pack_id": "agentic-sdlc-process-orchestrator"}, pack)
        plugin_core = set(audit["markets"]["sdlc-plugins"]["core"])
        self.assertIn("bmad", plugin_core)
        self.assertIn("gsd", plugin_core)
        self.assertIn("zuvo", plugin_core)
        plugin_adj = set(audit["markets"]["sdlc-plugins"]["adjacent"])
        self.assertNotIn("zuvo", plugin_adj)
        self.assertIn("bmad", audit["matrix_slugs"])
        self.assertIn("gsd", audit["matrix_slugs"])


class MultiMarketChartTests(unittest.TestCase):
    def test_per_market_chart_blocks(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 28},
                {"solution": "bmad", "score": 20},
                {"solution": "gsd", "score": 18},
                {"solution": "factory-ai", "score": 22},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {
                        "silver-bullet": True,
                        "bmad": True,
                        "gsd": True,
                        "factory-ai": True,
                    },
                },
                {
                    "type": "feature",
                    "name": "Hook-enforced gates",
                    "solutions": {"silver-bullet": True, "bmad": False, "gsd": False, "factory-ai": False},
                },
            ],
        }
        support = {
            slug: {row["name"]: bool(row["solutions"].get(slug)) for row in comparison["rows"]}
            for slug in ("silver-bullet", "bmad", "gsd", "factory-ai")
        }
        chart = build_multi_market_chart_data(
            comparison,
            pack=pack,
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            audit={
                "markets": {
                    "apo": {"core": ["silver-bullet"]},
                    "sdlc-plugins": {"core": ["bmad", "gsd"]},
                    "agentic-sdlc-saas": {"core": ["factory-ai"]},
                }
            },
        )
        self.assertIn("markets", chart)
        self.assertEqual(set(chart["markets"].keys()), {"apo", "sdlc-plugins", "agentic-sdlc-saas"})
        self.assertTrue(chart["markets"]["sdlc-plugins"]["mq_data"])
        self.assertTrue(chart["markets"]["agentic-sdlc-saas"]["gmq_data"])
        self.assertIn("mq_data", chart)
        # All-OSS plugins market must not inherit SaaS commercial catalog.
        plugins_commercial = chart["markets"]["sdlc-plugins"]["vendor_buckets"]["commercial"]
        self.assertEqual(plugins_commercial, [])
        self.assertNotIn("Factory.ai", plugins_commercial)
        saas_oss = chart["markets"]["agentic-sdlc-saas"]["vendor_buckets"]["oss"]
        self.assertEqual(saas_oss, [])
        self.assertNotIn("Silver Bullet", saas_oss)
        self.assertNotIn("GSD (Get Shit Done)", saas_oss)


class MultiMarketMaterializeTests(unittest.TestCase):
    def test_bmad_gsd_get_scr_artifacts(self) -> None:
        envelopes = [
            {
                "phase_id": "DR-RETRIEVE",
                "logical_model_id": "test",
                "payload": {
                    "evidence": [
                        {"claim": "BMAD Method uses Analyst, PM, Architect, Developer, QA roles."},
                        {"claim": "GSD milestone loop: Discuss, Plan, Execute, Verify, Ship."},
                        {"claim": "AI-DLC is a commercial process orchestrator."},
                        {"claim": "Silver Bullet enforces hook gates across SDLC."},
                    ]
                },
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(
                json.dumps(envelopes), encoding="utf-8"
            )
            (root / "need_profile.json").write_text(
                json.dumps({"category_pack_id": "agentic-sdlc-process-orchestrator"}),
                encoding="utf-8",
            )
            materialize_solution_artifacts(root, envelopes=envelopes)
            slugs = {
                s["slug"]
                for s in json.loads((root / "solutions.json").read_text())["solutions"]
            }
            self.assertIn("bmad", slugs)
            self.assertIn("gsd", slugs)
            self.assertTrue((root / "solutions" / "bmad" / "scr.md").is_file())
            self.assertTrue((root / "solutions" / "gsd" / "scr.md").is_file())


class MultiMarketMembershipConsistencyTests(unittest.TestCase):
    """User-critical: multi-set membership, no coord collisions, chart⊆listed."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.pack = load_category_pack("agentic-sdlc-process-orchestrator")

    def test_silver_bullet_seeded_in_apo_and_sdlc_plugins(self) -> None:
        apo = next(m for m in get_markets(self.pack) if m["id"] == "apo")
        plugins = next(m for m in get_markets(self.pack) if m["id"] == "sdlc-plugins")
        apo_core = {s["slug"] for s in apo["seeds"]}
        plugin_core = {s["slug"] for s in plugins["seeds"]}
        self.assertIn("silver-bullet", apo_core)
        self.assertIn("silver-bullet", plugin_core)
        self.assertIn("silver-bullet", apo_core & plugin_core)

    def test_classifier_puts_sb_in_apo_and_plugins_core(self) -> None:
        envelopes = [
            {
                "phase_id": "DR-RETRIEVE",
                "logical_model_id": "test",
                "payload": {
                    "evidence": [
                        {"claim": "Silver Bullet ships hook-enforced gates and plugin packs for Cursor."},
                        {"claim": "BMAD Method is an SDLC methodology pack."},
                        {"claim": "Factory.ai is a commercial SDLC SaaS platform."},
                    ]
                },
            }
        ]
        audit = classify_solutions(
            envelopes,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            pack=self.pack,
        )
        apo_core = set(audit["markets"]["apo"]["core"])
        plugin_core = set(audit["markets"]["sdlc-plugins"]["core"])
        self.assertIn("silver-bullet", apo_core)
        self.assertIn("silver-bullet", plugin_core)
        self.assertIn("silver-bullet", apo_core & plugin_core)

    def test_no_duplicate_chart_coords_within_market(self) -> None:
        from synthesize_landscape import avoid_chart_coord_collisions, build_multi_market_chart_data

        comparison = {
            "rankings": [
                {"solution": "augment-cosmos", "score": 29},
                {"solution": "devin", "score": 29},
                {"solution": "factory-ai", "score": 29},
                {"solution": "tembo", "score": 13},
                {"solution": "magic-dev", "score": 8},
                {"solution": "silver-bullet", "score": 38},
                {"solution": "bmad", "score": 32},
                {"solution": "gsd", "score": 30},
            ],
            "rows": [],
        }
        # Identical feature maps — previously forced Factory/Devin/Cosmos onto one pixel.
        shared = {
            "Workflow composition": True,
            "Atomic flow catalog": False,
            "Parent/child delegation": True,
            "Hook-enforced gates": True,
            "Managed hosting": False,
            "Prebuilt SDLC templates": False,
            "IDE-native integration": True,
            "Free tier / OSS core": True,
            "CI integration": False,
        }
        support = {
            "augment-cosmos": dict(shared),
            "devin": dict(shared),
            "factory-ai": dict(shared),
            "tembo": {"Workflow composition": True, "Hook-enforced gates": True},
            "magic-dev": {"Workflow composition": True},
            "silver-bullet": {
                **shared,
                "Atomic flow catalog": True,
                "Prebuilt SDLC templates": True,
            },
            "bmad": dict(shared),
            "gsd": dict(shared),
        }
        chart = build_multi_market_chart_data(
            comparison,
            pack=self.pack,
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            audit={
                "markets": {
                    "apo": {"core": ["silver-bullet"], "adjacent": []},
                    "sdlc-plugins": {
                        "core": ["silver-bullet", "bmad", "gsd"],
                        "adjacent": ["crewai"],
                    },
                    "agentic-sdlc-saas": {
                        "core": [
                            "augment-cosmos",
                            "devin",
                            "factory-ai",
                            "tembo",
                            "magic-dev",
                        ],
                        "adjacent": ["cursor"],
                    },
                }
            },
        )
        for mid, mchart in chart["markets"].items():
            for key in ("mq_data", "gmq_data"):
                pts = mchart.get(key) or []
                coords = {(p["x"], p["y"]) for p in pts}
                self.assertEqual(
                    len(coords),
                    len(set(coords)),
                    f"duplicate coords in {mid}.{key}: {coords}",
                )
                self.assertEqual(
                    len({p["x"] for p in pts}),
                    len(pts),
                    f"shared vertical (x) in {mid}.{key}: {[p['x'] for p in pts]}",
                )
                self.assertEqual(
                    len({p["y"] for p in pts}),
                    len(pts),
                    f"shared horizontal (y) in {mid}.{key}: {[p['y'] for p in pts]}",
                )
            # Market-specific scoring: SaaS trio must not share one identical point.
            if mid == "agentic-sdlc-saas":
                trio = {
                    p["slug"]: (p["x"], p["y"])
                    for p in mchart["mq_data"]
                    if p["slug"] in {"augment-cosmos", "devin", "factory-ai"}
                }
                self.assertEqual(len(trio), 3)
                self.assertEqual(len(set(trio.values())), 3)

            plotted = {p["slug"] for p in mchart.get("mq_data") or []}
            listed = set(mchart.get("listed_slugs") or [])
            core = set((mchart.get("membership") or {}).get("core") or [])
            adj = set((mchart.get("membership") or {}).get("adjacent") or [])
            self.assertTrue(plotted <= listed, f"{mid}: plotted {plotted - listed} not in listed")
            self.assertTrue(plotted <= (core | adj | plotted))
            # Chart⊆listed invariant (precise): plotted ⊆ core ∪ adjacent
            self.assertTrue(plotted <= (core | adj))
            # Unplotted adjacent are explicit, not silent mismatches.
            unplotted = {u["slug"] for u in (mchart.get("unplotted") or [])}
            self.assertTrue(adj <= unplotted | plotted)

        # Collision helper is deterministic on ties.
        tied = [
            {"slug": "a", "label": "A", "x": 5.0, "y": 5.0, "q": "Leaders"},
            {"slug": "b", "label": "B", "x": 5.0, "y": 5.0, "q": "Leaders"},
            {"slug": "c", "label": "C", "x": 5.0, "y": 5.0, "q": "Leaders"},
        ]
        fixed = avoid_chart_coord_collisions(tied)
        self.assertEqual(len({(p["x"], p["y"]) for p in fixed}), 3)
        self.assertEqual(len({p["x"] for p in fixed}), 3, msg=f"shared vertical: {fixed}")
        self.assertEqual(len({p["y"] for p in fixed}), 3, msg=f"shared horizontal: {fixed}")


class AnalystGradeMembershipFixes(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pack = load_category_pack("agentic-sdlc-process-orchestrator")


    def test_plugins_mq_not_all_leaders_y95(self) -> None:
        """sdlc-plugins MQ must not clamp every core point to Leaders y=9.5."""
        from synthesize_landscape import build_multi_market_chart_data

        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 38},
                {"solution": "bmad", "score": 32},
                {"solution": "gsd", "score": 30},
                {"solution": "oh-my-pi", "score": 28},
                {"solution": "ruflo", "score": 26},
                {"solution": "spec-kit", "score": 22},
                {"solution": "superclaude", "score": 20},
                {"solution": "superpowers", "score": 18},
                {"solution": "claude-harness", "score": 12},
            ],
            "rows": [],
        }
        shared = {
            "Workflow composition": True,
            "Hook-enforced gates": True,
            "IDE-native integration": True,
            "Free tier / OSS core": True,
            "Prebuilt SDLC templates": True,
            "Atomic flow catalog": False,
            "Parent/child delegation": False,
            "Managed hosting": False,
        }
        support = {r["solution"]: dict(shared) for r in comparison["rankings"]}
        support["silver-bullet"]["Atomic flow catalog"] = True
        support["silver-bullet"]["Parent/child delegation"] = True
        support["oh-my-pi"]["Parent/child delegation"] = True
        support["ruflo"]["Parent/child delegation"] = True
        support["claude-harness"]["Prebuilt SDLC templates"] = False
        chart = build_multi_market_chart_data(
            comparison,
            pack=self.pack,
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            audit={
                "markets": {
                    "apo": {"core": ["silver-bullet"], "adjacent": []},
                    "sdlc-plugins": {
                        "core": [r["solution"] for r in comparison["rankings"]],
                        "adjacent": ["zuvo"],
                    },
                    "agentic-sdlc-saas": {"core": ["devin"], "adjacent": ["tembo"]},
                }
            },
        )
        ys = [p["y"] for p in chart["markets"]["sdlc-plugins"]["mq_data"]]
        self.assertTrue(ys, "expected plugins mq points")
        self.assertLess(sum(1 for y in ys if y >= 9.4) / len(ys), 0.5)
        self.assertGreater(max(ys) - min(ys), 1.0)

    def test_zuvo_plugins_core_identity_verified(self) -> None:
        from category_pack import build_github_by_slug, build_homepage_by_slug

        plugins = next(m for m in get_markets(self.pack) if m["id"] == "sdlc-plugins")
        core = {s["slug"] for s in plugins["seeds"]}
        adj = {s["slug"] for s in plugins["adjacent_seeds"]}
        self.assertIn("zuvo", core)
        self.assertNotIn("zuvo", adj)
        zuvo = next(s for s in plugins["seeds"] if s["slug"] == "zuvo")
        self.assertFalse(zuvo.get("quarantine"))
        self.assertEqual(zuvo.get("homepage"), "https://zuvo.dev/")
        self.assertEqual(zuvo.get("github"), "https://github.com/greglas75/zuvo")
        self.assertEqual(build_homepage_by_slug(self.pack).get("zuvo"), "https://zuvo.dev/")
        self.assertEqual(
            build_github_by_slug(self.pack).get("zuvo"),
            "https://github.com/greglas75/zuvo",
        )

    def test_tembo_demoted_saas_adjacent_not_core(self) -> None:
        saas = next(m for m in get_markets(self.pack) if m["id"] == "agentic-sdlc-saas")
        core = {s["slug"] for s in saas["seeds"]}
        adj = {s["slug"] for s in saas["adjacent_seeds"]}
        self.assertNotIn("tembo", core)
        self.assertIn("tembo", adj)

    def test_p1_pack_membership_named_vendors(self) -> None:
        from category_pack import get_hard_exclusion_slugs

        apo = next(m for m in get_markets(self.pack) if m["id"] == "apo")
        plugins = next(m for m in get_markets(self.pack) if m["id"] == "sdlc-plugins")
        saas = next(m for m in get_markets(self.pack) if m["id"] == "agentic-sdlc-saas")
        apo_core = {s["slug"] for s in apo["seeds"]}
        apo_adj = {s["slug"] for s in apo["adjacent_seeds"]}
        plugin_core = {s["slug"] for s in plugins["seeds"]}
        saas_core = {s["slug"] for s in saas["seeds"]}
        hard = get_hard_exclusion_slugs(self.pack)
        self.assertNotIn("agenthub", apo_core)
        self.assertIn("agenthub", apo_adj)
        self.assertNotIn("ateam", apo_core)
        self.assertNotIn("ateam", apo_adj)
        self.assertIn("ateam", hard)
        for slug in ("cc10x", "cavekit-v31", "barkain-workflow-orchestrator"):
            self.assertNotIn(slug, apo_core)
            self.assertIn(slug, plugin_core)
        self.assertIn("devin", saas_core)
        self.assertIn("devin", apo_adj)

    def test_plotted_slugs_lockstep_membership_core_and_mq(self) -> None:
        audit = {
            "markets": {
                "apo": {
                    "core": ["silver-bullet", "agentsys"],
                    "adjacent": ["agenthub", "devin"],
                },
                "sdlc-plugins": {
                    "core": [
                        "cc10x",
                        "cavekit-v31",
                        "barkain-workflow-orchestrator",
                        "bmad",
                    ],
                    "adjacent": [],
                },
                "agentic-sdlc-saas": {"core": ["devin"], "adjacent": []},
            }
        }
        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 40},
                {"solution": "agentsys", "score": 20},
                {"solution": "cc10x", "score": 18},
                {"solution": "cavekit-v31", "score": 16},
                {"solution": "barkain-workflow-orchestrator", "score": 14},
                {"solution": "bmad", "score": 22},
                {"solution": "devin", "score": 30},
                {"solution": "agenthub", "score": 10},
                {"solution": "ateam", "score": 9},
            ],
            "rows": [],
        }
        support = {r["solution"]: {"Workflow composition": True} for r in comparison["rankings"]}
        chart = build_multi_market_chart_data(
            comparison,
            pack=self.pack,
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            audit=audit,
        )
        apo = chart["markets"]["apo"]
        plugins = chart["markets"]["sdlc-plugins"]
        saas = chart["markets"]["agentic-sdlc-saas"]
        for market in (apo, plugins, saas):
            mq = sorted(p["slug"] for p in market["mq_data"])
            self.assertEqual(market["plotted_slugs"], mq)
            self.assertEqual(market["plotted_slugs"], market["membership"]["core"])
        self.assertNotIn("agenthub", apo["plotted_slugs"])
        self.assertNotIn("agenthub", {p["slug"] for p in apo["mq_data"]})
        leaders = {p["slug"] for p in apo["mq_data"] if p.get("q") == "Leaders"}
        self.assertNotIn("agenthub", leaders)
        self.assertNotIn("ateam", apo["plotted_slugs"])
        self.assertNotIn("ateam", {p["slug"] for p in apo["mq_data"]})
        for slug in ("cc10x", "cavekit-v31", "barkain-workflow-orchestrator"):
            self.assertIn(slug, plugins["plotted_slugs"])
            self.assertNotIn(slug, apo["plotted_slugs"])
        self.assertIn("devin", saas["plotted_slugs"])
        self.assertNotIn("devin", apo["plotted_slugs"])


    def test_host_runtimes_are_saas_adjacent_not_core(self) -> None:
        saas = next(m for m in get_markets(self.pack) if m["id"] == "agentic-sdlc-saas")
        core = {s["slug"] for s in saas["seeds"]}
        adj = {s["slug"] for s in saas["adjacent_seeds"]}
        for slug in ("cursor", "claude-code", "codex", "github-copilot", "cognition-scout"):
            self.assertNotIn(slug, core)
            self.assertIn(slug, adj)
        for slug in ("factory-ai", "devin", "augment-cosmos"):
            self.assertIn(slug, core)
        self.assertNotIn("magic-dev", core)
        self.assertNotIn("tembo", core)
        self.assertIn("tembo", adj)

    def test_magic_dev_hard_excluded_not_saas_core(self) -> None:
        from category_pack import get_hard_exclusion_slugs

        saas = next(m for m in get_markets(self.pack) if m["id"] == "agentic-sdlc-saas")
        core = {s["slug"] for s in saas["seeds"]}
        hard = get_hard_exclusion_slugs(self.pack)
        self.assertNotIn("magic-dev", core)
        self.assertIn("magic-dev", hard)

    def test_claude_harness_oss_in_plugins(self) -> None:
        plugins = next(m for m in get_markets(self.pack) if m["id"] == "sdlc-plugins")
        harness = next(s for s in plugins["seeds"] if s["slug"] == "claude-harness")
        self.assertEqual(harness["license"], "oss")
        apo = next(m for m in get_markets(self.pack) if m["id"] == "apo")
        self.assertNotIn("claude-harness", {s["slug"] for s in apo["seeds"]})

    def test_metagpt_plots_on_apo_mq_when_missing_from_rankings(self) -> None:
        from synthesize_landscape import build_chart_data

        comparison = {"rankings": [{"solution": "silver-bullet", "score": 30}], "rows": []}
        chart = build_chart_data(
            comparison,
            category="Primary — APO",
            support={"silver-bullet": {}, "metagpt": {}},
            market_slugs={"silver-bullet", "metagpt"},
            commercial=[],
            oss=[{"slug": "silver-bullet", "name": "Silver Bullet"}, {"slug": "metagpt", "name": "MetaGPT"}],
            known={"silver-bullet": "Silver Bullet", "metagpt": "MetaGPT"},
            pack=self.pack,
        )
        labels = {p["label"] for p in chart["mq_data"]}
        self.assertIn("MetaGPT", labels)
        self.assertIn("Silver Bullet", labels)

    def test_filter_comparison_drops_claude_code_expert(self) -> None:
        from synthesize_landscape import filter_comparison_for_pack

        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 10},
                {"solution": "claude-code-expert", "score": 5},
                {"solution": "sdlc-plugin", "score": 4},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {
                        "silver-bullet": "✔",
                        "claude-code-expert": "✔",
                        "sdlc-plugin": "✔",
                    },
                }
            ],
            "winner": "claude-code-expert",
        }
        filtered = filter_comparison_for_pack(comparison, self.pack, {})
        slugs = {r["solution"] for r in filtered["rankings"]}
        self.assertIn("silver-bullet", slugs)
        self.assertNotIn("claude-code-expert", slugs)
        self.assertNotIn("sdlc-plugin", slugs)
        self.assertNotIn("claude-code-expert", filtered["rows"][0]["solutions"])

    def test_scrub_claude_harness_apo_framing(self) -> None:
        from synthesize_landscape import scrub_membership_framing

        text = (
            "Claude Harness is a primary-market APO candidate — Claude Code wrapper, "
            "process enforcement, compliance layer above host."
        )
        out = scrub_membership_framing(text, self.pack)
        self.assertNotIn("primary-market APO candidate", out)
        self.assertRegex(out, r"(?i)sdlc-plugins|not an APO")

    def test_scrub_claude_harness_apo_framing_markdown_link(self) -> None:
        """Linked display names must scrub too — bare-name-only regex left SPA profiles dirty."""
        from synthesize_landscape import scrub_membership_framing

        text = (
            "* **Overview**: [Claude Harness](https://github.com/anthropics/claude-code) "
            "is a primary-market APO candidate — Claude Code wrapper, process enforcement."
        )
        out = scrub_membership_framing(text, self.pack)
        self.assertNotIn("primary-market APO candidate", out)
        self.assertRegex(out, r"(?i)sdlc-plugins|not an APO")
        self.assertIn("github.com/anthropics/claude-code", out)

    def test_rewrite_agentsys_ai_url(self) -> None:
        from vendor_link_labels import rewrite_vendor_url, scrub_embedded_vendor_urls

        self.assertEqual(
            rewrite_vendor_url("https://agentsys.ai"),
            "https://github.com/agent-sh/agentsys",
        )
        payload = scrub_embedded_vendor_urls(
            {"sources": [{"title": "AgentSys", "url": "https://agentsys.ai"}]}
        )
        self.assertEqual(payload["sources"][0]["url"], "https://github.com/agent-sh/agentsys")

    def test_multi_market_vendor_dom_ids_must_be_unique(self) -> None:
        """Silver Bullet in APO + sdlc-plugins must emit distinct market-scoped card ids."""
        assets = Path(__file__).resolve().parents[1] / "assets" / "landscape-preview.template.html"
        template = assets.read_text(encoding="utf-8")
        self.assertIn("function _vendorCardDomId(slug, marketId)", template)
        self.assertIn("vendor-' + s + '--' + mid", template)

        def vendor_card_dom_id(slug: str, market_id: str = "") -> str:
            s = (slug or "").strip()
            mid = (market_id or "").strip()
            return f"vendor-{s}--{mid}" if mid else f"vendor-{s}"

        # Same slug in two markets → two ids (the soft defect before this fix).
        apo_id = vendor_card_dom_id("silver-bullet", "apo")
        plugins_id = vendor_card_dom_id("silver-bullet", "sdlc-plugins")
        outlook_id = vendor_card_dom_id("silver-bullet", "")
        ids = [apo_id, plugins_id, outlook_id]
        self.assertEqual(apo_id, "vendor-silver-bullet--apo")
        self.assertEqual(plugins_id, "vendor-silver-bullet--sdlc-plugins")
        self.assertEqual(outlook_id, "vendor-silver-bullet")
        self.assertEqual(len(ids), len(set(ids)), msg=f"duplicate ids: {ids}")
        # Legacy unscoped duplicate would collide:
        legacy = ["vendor-silver-bullet", "vendor-silver-bullet"]
        self.assertNotEqual(len(legacy), len(set(legacy)))

    def test_filter_comparison_drops_magic_dev(self) -> None:
        from synthesize_landscape import filter_comparison_for_pack

        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 10},
                {"solution": "magic-dev", "score": 13},
                {"solution": "devin", "score": 9},
            ],
            "rows": [
                {
                    "type": "feature",
                    "name": "Workflow composition",
                    "solutions": {
                        "silver-bullet": "✔",
                        "magic-dev": "✔",
                        "devin": "✔",
                    },
                }
            ],
            "winner": "magic-dev",
        }
        filtered = filter_comparison_for_pack(comparison, self.pack, {})
        slugs = {r["solution"] for r in filtered["rankings"]}
        self.assertNotIn("magic-dev", slugs)
        self.assertNotIn("magic-dev", filtered["rows"][0]["solutions"])
        self.assertNotEqual(filtered.get("winner"), "magic-dev")

    def test_magic_dev_not_plotted_even_if_audit_lists_saas_core(self) -> None:
        from synthesize_landscape import build_multi_market_chart_data

        comparison = {
            "rankings": [
                {"solution": "devin", "score": 32},
                {"solution": "factory-ai", "score": 22},
                {"solution": "augment-cosmos", "score": 20},
                {"solution": "magic-dev", "score": 13},
            ],
            "rows": [],
        }
        support = {
            "devin": {"Workflow composition": True, "Managed hosting": True},
            "factory-ai": {"Workflow composition": True, "Managed hosting": True},
            "augment-cosmos": {"Workflow composition": True, "Managed hosting": True},
            "magic-dev": {"Workflow composition": True},
        }
        chart = build_multi_market_chart_data(
            comparison,
            pack=self.pack,
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            audit={
                "markets": {
                    "apo": {"core": ["silver-bullet"], "adjacent": []},
                    "sdlc-plugins": {"core": ["silver-bullet"], "adjacent": []},
                    "agentic-sdlc-saas": {
                        "core": ["devin", "factory-ai", "augment-cosmos", "magic-dev"],
                        "adjacent": [],
                    },
                }
            },
        )
        saas = chart["markets"]["agentic-sdlc-saas"]
        plotted = {p["slug"] for p in saas["mq_data"]}
        self.assertNotIn("magic-dev", plotted)
        self.assertNotIn("magic-dev", set(saas.get("plotted_slugs") or []))
        self.assertNotIn("magic-dev", set((saas.get("membership") or {}).get("core") or []))

    def test_ai_dlc_not_wave_peer_and_vision_capped(self) -> None:
        from synthesize_landscape import build_chart_data, _METHODOLOGY_X_CAP

        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 38},
                {"solution": "ai-dlc", "score": 19},
            ],
            "rows": [],
        }
        support = {
            "silver-bullet": {
                "Workflow composition": True,
                "Atomic flow catalog": True,
                "Hook-enforced gates": True,
                "Parent/child delegation": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
            },
            "ai-dlc": {
                "Workflow composition": True,
                "Atomic flow catalog": False,
                "Hook-enforced gates": False,
                "Managed hosting": False,
                "Automated review loops": False,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
            },
        }
        chart = build_chart_data(
            comparison,
            category="Primary — APO",
            support=support,
            market_slugs={"silver-bullet", "ai-dlc"},
            known={"silver-bullet": "Silver Bullet", "ai-dlc": "AI-DLC"},
            pack=self.pack,
            market_id="apo",
        )
        wave_slugs = {p["slug"] for p in chart["wave_data"]}
        self.assertNotIn("ai-dlc", wave_slugs)
        aidlc_gmq = next(p for p in chart["gmq_data"] if p["slug"] == "ai-dlc")
        self.assertLessEqual(aidlc_gmq["x"], _METHODOLOGY_X_CAP)
        self.assertNotEqual(aidlc_gmq.get("q"), "Leaders")

    def test_plugin_wave_capped_without_cross_session(self) -> None:
        from synthesize_landscape import (
            build_chart_data,
            _NON_LEADER_WAVE_PRESENCE_CAP,
        )

        comparison = {
            "rankings": [
                {"solution": "silver-bullet", "score": 38},
                {"solution": "gsd", "score": 34},
            ],
            "rows": [],
        }
        shared = {
            "Workflow composition": True,
            "Hook-enforced gates": True,
            "Prebuilt SDLC templates": True,
            "Managed hosting": False,
            "Atomic flow catalog": False,
        }
        support = {
            "silver-bullet": {**shared, "Atomic flow catalog": True, "Parent/child delegation": True},
            "gsd": dict(shared),
        }
        chart = build_chart_data(
            comparison,
            category="Secondary — plugins",
            support=support,
            market_slugs={"silver-bullet", "gsd"},
            known={"silver-bullet": "Silver Bullet", "gsd": "GSD"},
            pack=self.pack,
            market_id="sdlc-plugins",
        )
        gsd_wave = next(p for p in chart["wave_data"] if p["slug"] == "gsd")
        self.assertLessEqual(gsd_wave["presence"], _NON_LEADER_WAVE_PRESENCE_CAP)
        gsd_mq = next(p for p in chart["mq_data"] if p["slug"] == "gsd")
        self.assertNotEqual(gsd_mq.get("q"), "Leaders")

    def test_scoring_methodology_discloses_weights(self) -> None:
        from synthesize_landscape import _scoring_methodology_lines

        lines = _scoring_methodology_lines({"rows": [], "rankings": []}, self.pack)
        text = "\n".join(lines)
        self.assertIn("Scoring methodology", text)
        self.assertIn("ticks ×", text)
        self.assertIn("Hard-exclusion membership", text)
        self.assertIn("Magic.dev", text)
        self.assertIn("omitted from Wave", text)
        self.assertNotIn("tiny deterministic jitter", text)
        self.assertNotIn("0.85·jitter", text)


if __name__ == "__main__":
    unittest.main()

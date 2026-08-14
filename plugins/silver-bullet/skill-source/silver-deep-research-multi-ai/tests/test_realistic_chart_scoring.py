"""Analyst-grade chart/matrix honesty guards (no false equivalences / clone coords)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from synthesize_landscape import (  # noqa: E402
    _CHART_FEAT_EQUIV,
    _build_chart_support,
    _feat_supported,
    _is_methodology_without_gates,
    _must_not_be_leader,
    _vc_series_entry,
    _wave_strategy_score,
    avoid_chart_coord_collisions,
    avoid_wave_coord_collisions,
    build_consensus_patterns,
    build_multi_market_chart_data,
    select_notable_divergences,
    select_vc_kcfs,
)
from category_pack import resolve_pack_from_need  # noqa: E402


class RealisticChartScoringTests(unittest.TestCase):
    def test_no_zero_infra_to_managed_hosting_equivalence(self) -> None:
        self.assertEqual(_CHART_FEAT_EQUIV, {})
        feats = {"Zero-infra bootstrap": True, "Managed hosting": False}
        self.assertFalse(_feat_supported(feats, "Managed hosting"))
        self.assertTrue(_feat_supported({"Managed hosting": True}, "Managed hosting"))

    def test_wave_strategy_not_two_feature_staircase(self) -> None:
        """Peers with only Workflow composition must not all share one Strategy x-value."""
        thin = {"Workflow composition": True}
        rich = {
            "Workflow composition": True,
            "Atomic flow catalog": True,
            "Hook-enforced gates": True,
            "Skill/plugin marketplace": True,
            "Free tier / OSS core": True,
            "Prebuilt SDLC templates": True,
        }
        mid = {
            "Workflow composition": True,
            "Managed hosting": True,
            "Automated review loops": True,
            "Predictable pricing": True,
        }
        lean_saas = {
            "Workflow composition": True,
            "Managed hosting": True,
            "IDE-native integration": True,
        }
        scores = [
            _wave_strategy_score(thin),
            _wave_strategy_score(lean_saas),
            _wave_strategy_score(mid),
            _wave_strategy_score(rich),
        ]
        self.assertEqual(len(set(scores)), 4, scores)
        self.assertLess(scores[0], scores[1])
        self.assertLess(scores[1], scores[2])
        self.assertLess(scores[2], scores[3])

    def test_wave_strategy_values_not_all_equal_across_markets(self) -> None:
        pack = resolve_pack_from_need(
            {"category_pack_id": "agentic-sdlc-process-orchestrator"}
        )
        comparison = {
            "rankings": [
                {"solution": "augment-cosmos", "score": 24},
                {"solution": "devin", "score": 32},
                {"solution": "factory-ai", "score": 20},
                {"solution": "tembo", "score": 15},
                {"solution": "magic-dev", "score": 10},
                {"solution": "silver-bullet", "score": 38},
                {"solution": "bmad", "score": 32},
                {"solution": "gsd", "score": 34},
                {"solution": "oh-my-pi", "score": 30},
                {"solution": "cc10x", "score": 28},
                {"solution": "ai-dlc", "score": 18},
                {"solution": "agenthub", "score": 12},
            ],
            "rows": [],
        }
        support = {
            "augment-cosmos": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": True,
                "IDE-native integration": True,
            },
            "devin": {
                "Workflow composition": True,
                "Managed hosting": True,
                "IDE-native integration": True,
                "Free tier / OSS core": True,
                "Automated review loops": True,
                "Predictable pricing": True,
                "Per-seat transparency": True,
            },
            "factory-ai": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": True,
                "IDE-native integration": True,
                "Automated review loops": True,
            },
            "tembo": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": True,
                "IDE-native integration": True,
            },
            "magic-dev": {
                "Workflow composition": True,
                "Managed hosting": True,
                "IDE-native integration": True,
            },
            "silver-bullet": {
                "Workflow composition": True,
                "Atomic flow catalog": True,
                "Hook-enforced gates": True,
                "Parent/child delegation": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
                "Skill/plugin marketplace": True,
                "Managed hosting": False,
            },
            "bmad": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
                "Skill/plugin marketplace": True,
            },
            "gsd": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
                "Automated review loops": True,
                "Skill/plugin marketplace": True,
            },
            "oh-my-pi": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Parent/child delegation": True,
                "Skill/plugin marketplace": True,
            },
            "cc10x": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
                "Skill/plugin marketplace": True,
            },
            "ai-dlc": {
                "Workflow composition": True,
                "Free tier / OSS core": True,
                "Prebuilt SDLC templates": True,
                "Zero-infra bootstrap": True,
            },
            "agenthub": {
                "Workflow composition": True,
                "IDE-native integration": True,
                "Parent/child delegation": True,
            },
        }
        chart = build_multi_market_chart_data(
            comparison,
            pack=pack,
            support=support,
            need={"category_pack_id": "agentic-sdlc-process-orchestrator"},
            audit={
                "markets": {
                    "apo": {
                        "core": ["silver-bullet", "cc10x", "ai-dlc", "agenthub"],
                        "adjacent": [],
                    },
                    "sdlc-plugins": {
                        "core": ["silver-bullet", "bmad", "gsd", "oh-my-pi"],
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
            wave = mchart.get("wave_data") or []
            if len(wave) < 2:
                continue
            strategies = [float(p.get("strategy") or 0) for p in wave]
            self.assertGreater(
                len(set(strategies)),
                1,
                f"{mid}: Wave Strength of Strategy collapsed to one value: {strategies}",
            )
            pairs = {
                (
                    round(float(p.get("strategy") or 0), 1),
                    round(float(p.get("offering") or 0), 1),
                )
                for p in wave
            }
            self.assertEqual(
                len(pairs),
                len(wave),
                f"{mid}: duplicate Wave (strategy, offering) pairs",
            )

    def test_features_json_false_clears_managed_hosting_credit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sol = root / "solutions" / "plugin-x"
            sol.mkdir(parents=True)
            (sol / "features.json").write_text(
                json.dumps(
                    {
                        "solution_name": "plugin-x",
                        "categories": [
                            {
                                "name": "Time to value",
                                "features": [
                                    {"name": "Managed hosting", "supported": False},
                                    {"name": "Zero-infra bootstrap", "supported": True},
                                ],
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            comparison = {
                "rows": [
                    {
                        "type": "feature",
                        "name": "Managed hosting",
                        # Matrix wrongly ticked — features.json false must win for charts.
                        "solutions": {"plugin-x": "✔"},
                    },
                    {
                        "type": "feature",
                        "name": "Zero-infra bootstrap",
                        "solutions": {"plugin-x": "✔"},
                    },
                ]
            }
            support = _build_chart_support(comparison, root=root)
            self.assertFalse(support["plugin-x"].get("Managed hosting"))
            self.assertTrue(support["plugin-x"].get("Zero-infra bootstrap"))

    def test_no_duplicate_coords_and_chart_subset_of_listed(self) -> None:
        pack = resolve_pack_from_need(
            {"category_pack_id": "agentic-sdlc-process-orchestrator"}
        )
        comparison = {
            "rankings": [
                {"solution": "augment-cosmos", "score": 24},
                {"solution": "devin", "score": 32},
                {"solution": "factory-ai", "score": 20},
                {"solution": "tembo", "score": 15},
                {"solution": "magic-dev", "score": 10},
                {"solution": "silver-bullet", "score": 38},
                {"solution": "bmad", "score": 32},
                {"solution": "gsd", "score": 34},
            ],
            "rows": [],
        }
        support = {
            "augment-cosmos": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": True,
                "Hook-enforced gates": False,
                "IDE-native integration": True,
            },
            "devin": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": False,
                "Hook-enforced gates": False,
                "IDE-native integration": True,
                "Free tier / OSS core": True,
            },
            "factory-ai": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": True,
                "Hook-enforced gates": False,
                "IDE-native integration": True,
                "Automated review loops": True,
            },
            "tembo": {
                "Workflow composition": True,
                "Managed hosting": True,
                "Parent/child delegation": True,
                "IDE-native integration": True,
            },
            "magic-dev": {
                "Workflow composition": True,
                "Managed hosting": True,
                "IDE-native integration": True,
            },
            "silver-bullet": {
                "Workflow composition": True,
                "Atomic flow catalog": True,
                "Hook-enforced gates": True,
                "Parent/child delegation": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
                "Managed hosting": False,
            },
            "bmad": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
            },
            "gsd": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Prebuilt SDLC templates": True,
                "Free tier / OSS core": True,
                "Zero-infra bootstrap": True,
                "Automated review loops": True,
            },
        }
        chart = build_multi_market_chart_data(
            comparison,
            pack=pack,
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
                points = mchart[key]
                deduped = avoid_chart_coord_collisions([dict(p) for p in points])
                coords = {(p["x"], p["y"]) for p in deduped}
                self.assertEqual(
                    len(coords),
                    len(deduped),
                    f"{mid}.{key} still has duplicate coords",
                )
                self.assertEqual(
                    len({p["x"] for p in deduped}),
                    len(deduped),
                    f"{mid}.{key} shared vertical x={[p['x'] for p in deduped]}",
                )
                self.assertEqual(
                    len({p["y"] for p in deduped}),
                    len(deduped),
                    f"{mid}.{key} shared horizontal y={[p['y'] for p in deduped]}",
                )
            wave = mchart.get("wave_data") or []
            if wave:
                wave_deduped = avoid_wave_coord_collisions([dict(p) for p in wave])
                wave_coords = {(p["strategy"], p["offering"]) for p in wave_deduped}
                self.assertEqual(
                    len(wave_coords),
                    len(wave_deduped),
                    f"{mid}.wave_data still has duplicate (strategy, offering)",
                )
                self.assertEqual(
                    len({p["strategy"] for p in wave_deduped}),
                    len(wave_deduped),
                    f"{mid}.wave shared strategy x",
                )
                self.assertEqual(
                    len({p["offering"] for p in wave_deduped}),
                    len(wave_deduped),
                    f"{mid}.wave shared offering y",
                )
            membership = mchart.get("membership") or {}
            listed = set(membership.get("listed") or mchart.get("listed_slugs") or [])
            plotted = {p["slug"] for p in mchart.get("mq_data") or []}
            if listed:
                self.assertTrue(
                    plotted <= listed,
                    f"{mid}: plotted not ⊆ listed: {sorted(plotted - listed)}",
                )

    def test_select_notable_divergences_dedupes_subject_restatements(self) -> None:
        items: list[dict[str, Any]] = [
            {
                "claim_key": "ai-dlc weakest",
                "text": "AI-DLC (AWS) is the weakest APO core seed by enforcement depth.",
                "support_count": 1,
                "supporting_agents": ["ocg-deepseek-v4-flash"],
                "model_families": ["deepseek"],
            },
            {
                "claim_key": "ai-dlc methodology",
                "text": "AI-DLC is a methodology/framework rather than a shipped host-integrated product.",
                "support_count": 1,
                "supporting_agents": ["claude-opus-4.8-medium"],
                "model_families": ["claude"],
            },
            {
                "claim_key": "ai-dlc enterprise",
                "text": "AI-DLC represents enterprise-grade APO with AWS-backed lifecycle orchestration",
                "support_count": 1,
                "supporting_agents": ["ocg-mimo-v2.5"],
                "model_families": ["mimo"],
            },
            {
                "claim_key": "ai-dlc weakest restated",
                "text": "AI-DLC (AWS / awslabs) is the weakest APO core seed by enforcement depth and lacks gates.",
                "support_count": 1,
                "supporting_agents": ["ocg-deepseek-v4-flash"],
                "model_families": ["deepseek"],
            },
            {
                "claim_key": "augment short",
                "text": "Augment Cosmos (not Augment Code) is the correct product-level name for the tertiary market entry",
                "support_count": 1,
                "supporting_agents": ["ocg-qwen3.7-plus"],
                "model_families": ["qwen"],
            },
            {
                "claim_key": "augment long",
                "text": "Augment Cosmos (not Augment Code) is the correct product-level name for the tertiary market entry; Augment Code is the parent company brand.",
                "support_count": 1,
                "supporting_agents": ["ocg-mimo-v2.5"],
                "model_families": ["mimo"],
            },
            {
                "claim_key": "magic include",
                "text": "Factory.ai, Devin, Tembo, Magic.dev, and Cognition Scout represent the tertiary market peers.",
                "support_count": 1,
                "supporting_agents": ["gemini-3.5-flash"],
                "model_families": ["gemini"],
            },
            {
                "claim_key": "magic exclude",
                "text": "Magic.dev and Cognition Scout are hard-excluded per category-pack rules and must not appear in solution cards.",
                "support_count": 1,
                "supporting_agents": ["ocg-qwen3.7-plus"],
                "model_families": ["qwen"],
            },
        ]
        out = select_notable_divergences(items, limit=8)
        texts = [str(i.get("text") or "") for i in out]
        blob = "\n".join(texts)
        ai = [t for t in texts if "AI-DLC" in t]
        aug = [t for t in texts if "Augment Cosmos naming" in t]
        self.assertEqual(len(ai), 1, texts)
        self.assertIn("ocg-deepseek-v4-flash", ai[0])
        self.assertIn("claude-opus-4.8-medium", ai[0])
        self.assertIn("ocg-mimo-v2.5", ai[0])
        self.assertIn("weakest", ai[0].lower())
        self.assertIn("enterprise-grade", ai[0].lower())
        self.assertEqual(len(aug), 0, "naming restatements are not model disagreements")
        self.assertTrue(any("Magic.dev" in t for t in texts), blob)
        self.assertIn("hard-excluded", blob.lower())
        self.assertNotIn("MQ vs GMQ", blob)

    def test_unique_x_and_y_for_clamped_high_cluster(self) -> None:
        stacked = [
            {"slug": f"s{i}", "label": f"S{i}", "x": 9.5, "y": 5.0 + i * 0.2, "q": "Leaders"}
            for i in range(9)
        ]
        stacked[2]["y"] = 5.0  # duplicate y with s0
        stacked.append({"slug": "lone", "label": "Lone", "x": 7.4, "y": 3.6, "q": "Visionaries"})
        fixed = avoid_chart_coord_collisions(stacked)
        xs = [p["x"] for p in fixed]
        ys = [p["y"] for p in fixed]
        self.assertEqual(len(set(xs)), 10, msg=xs)
        self.assertEqual(len(set(ys)), 10, msg=ys)
        self.assertTrue(all(8.6 <= p["x"] <= 9.5 for p in fixed if p["slug"].startswith("s")), xs)
        lone = next(p for p in fixed if p["slug"] == "lone")
        self.assertEqual(lone["x"], 7.4)
        # Rank of original y is preserved for the stacked cluster.
        order = sorted(range(9), key=lambda i: (stacked[i]["y"], i))
        ys_in_rank = [fixed[i]["y"] for i in order]
        self.assertEqual(ys_in_rank, sorted(ys_in_rank))

    def test_secondary_pack_without_cross_session_cannot_be_leader(self) -> None:
        feats = {
            "Workflow composition": True,
            "Hook-enforced gates": True,
            "Prebuilt SDLC templates": True,
            "Free tier / OSS core": True,
        }
        self.assertTrue(_must_not_be_leader("sdlc-plugins", "gsd", feats, None))
        self.assertFalse(
            _must_not_be_leader(
                "sdlc-plugins",
                "silver-bullet",
                {**feats, "Atomic flow catalog": True},
                None,
            )
        )

    def test_ai_dlc_methodology_without_gates_is_not_peer_complete(self) -> None:
        feats = {
            "Workflow composition": True,
            "Prebuilt SDLC templates": True,
            "Free tier / OSS core": True,
        }
        self.assertTrue(_is_methodology_without_gates(feats))
        self.assertTrue(_must_not_be_leader("apo", "ai-dlc", feats, None))

    def test_blue_ocean_drops_unevidenced_and_all_false_hosting(self) -> None:
        support = {
            "silver-bullet": {
                "Workflow composition": True,
                "Atomic flow catalog": True,
                "Hook-enforced gates": True,
                "Managed hosting": False,
            },
            "gsd": {
                "Workflow composition": True,
                "Hook-enforced gates": True,
                "Managed hosting": False,
            },
        }
        kcfs = select_vc_kcfs(["silver-bullet", "gsd"], support)
        self.assertIn("Workflow composition", kcfs)
        self.assertNotIn("Managed hosting", kcfs)
        self.assertNotIn("Predictable pricing", kcfs)
        series = _vc_series_entry(
            "silver-bullet",
            "Silver Bullet",
            support["silver-bullet"],
            known={"silver-bullet": "Silver Bullet"},
            kcfs=kcfs,
        )
        self.assertTrue(all(v in {1, 5} for v in series["data"]))
        self.assertNotIn(3, series["data"])

    def test_consensus_patterns_require_cross_family_agreement(self) -> None:
        envelopes = [
            {
                "phase_id": "DR-TRIANGULATE",
                "logical_model_id": "claude-opus-4.8-medium",
                "payload": {
                    "claim_candidates": [
                        {
                            "text": "APO is a process layer above a host coding-agent runtime with hook gates."
                        }
                    ]
                },
            },
            {
                "phase_id": "DR-TRIANGULATE",
                "logical_model_id": "ocg-qwen3.7-plus",
                "payload": {
                    "claim_candidates": [
                        {
                            "text": "The process layer sits above the host; deterministic gates differentiate packs."
                        }
                    ]
                },
            },
            {
                "phase_id": "DR-CRITIQUE",
                "logical_model_id": "gemini-3.5-flash",
                "payload": {
                    "claim_candidates": [
                        {
                            "text": "Secondary-market methodology packs lack cross-session state machines."
                        }
                    ]
                },
            },
        ]
        patterns = build_consensus_patterns(envelopes, min_families=2)
        ids = {p["id"] for p in patterns}
        self.assertIn("process-first", ids)
        self.assertIn("hook-gates", ids)
        self.assertNotIn("catalogs", ids)


if __name__ == "__main__":
    unittest.main()

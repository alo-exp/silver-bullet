"""Tests for live envelope → SCR materialization."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from materialize_solution_artifacts import (  # noqa: E402
    build_features_json,
    materialize_solution_artifacts,
    parse_feature_support,
    synthesize_feature_rubric,
    write_run_features_json,
)

LIVE_MATRIX_CLAIMS = [
    (
        "Matrix entry — Workflow composition (Critical): "
        "✔ silver-bullet, factory-ai, github-copilot-workspace, langgraph-platform; "
        "✖ cursor-agents, sweep-ai, devin, openhands."
    ),
    (
        "Matrix entry — Hook-enforced gates (Medium/verification-adjacent): "
        "✔ silver-bullet, cursor-agents only among evaluated set."
    ),
    (
        "Matrix entry — Atomic flow catalog: "
        "✔ silver-bullet only — unique process catalog differentiator vs peers."
    ),
    (
        "Matrix entry — Free tier / OSS core + predictable pricing "
        "(Very High startup weight): ✔ silver-bullet (and partially openhands/langgraph OSS); "
        "commercial peers weaker on pricing transparency."
    ),
]


def _envelopes_from_claims(claims: list[str]) -> list[dict]:
    return [
        {
            "phase_id": "DR-RETRIEVE",
            "logical_model_id": "test-model",
            "payload": {"evidence": [{"claim": claim, "confidence": 0.9} for claim in claims]},
        }
    ]


class MaterializeSolutionArtifactsTests(unittest.TestCase):
    def test_materialize_from_matrix_claim(self) -> None:
        envelopes = [
            {
                "phase_id": "DR-RETRIEVE",
                "payload": {
                    "evidence": [
                        {
                            "claim": (
                                "Matrix Critical row 'Workflow composition': "
                                "silver-bullet, factory-ai pass; cursor-agents do not."
                            )
                        }
                    ]
                },
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(
                json.dumps(envelopes),
                encoding="utf-8",
            )
            result = materialize_solution_artifacts(root, envelopes=envelopes)
            self.assertEqual(result["status"], "ok")
            self.assertTrue((root / "solutions.json").is_file())
            sb = json.loads((root / "solutions" / "silver-bullet" / "features.json").read_text())
            cursor = json.loads((root / "solutions" / "cursor-agents" / "features.json").read_text())
            wf_sb = next(
                f
                for cat in sb["categories"]
                for f in cat["features"]
                if f["name"] == "Workflow composition"
            )
            wf_cursor = next(
                f
                for cat in cursor["categories"]
                for f in cat["features"]
                if f["name"] == "Workflow composition"
            )
            self.assertTrue(wf_sb["supported"])
            self.assertFalse(wf_cursor["supported"])

    def test_parse_live_matrix_entry_format(self) -> None:
        support = parse_feature_support(_envelopes_from_claims(LIVE_MATRIX_CLAIMS))
        sb = support.get("silver-bullet", {})
        self.assertTrue(sb.get("Workflow composition"))
        self.assertTrue(sb.get("Hook-enforced gates"))
        self.assertTrue(sb.get("Atomic flow catalog"))
        self.assertTrue(sb.get("Free tier / OSS core"))
        self.assertTrue(sb.get("Predictable pricing"))
        self.assertFalse(support.get("cursor-agents", {}).get("Workflow composition"))
        self.assertTrue(support.get("cursor-agents", {}).get("Hook-enforced gates"))

    def test_only_slug_positive_not_global_negative(self) -> None:
        claim = "Matrix entry — Atomic flow catalog: ✔ silver-bullet only — unique differentiator."
        support = parse_feature_support(_envelopes_from_claims([claim]))
        self.assertTrue(support.get("silver-bullet", {}).get("Atomic flow catalog"))
        self.assertIsNone(support.get("factory-ai", {}).get("Atomic flow catalog"))

    def test_unknown_features_omitted_not_false(self) -> None:
        features = build_features_json("silver-bullet", {"silver-bullet": {"Workflow composition": True}})
        names = [f["name"] for cat in features["categories"] for f in cat["features"]]
        wf = next(
            f for cat in features["categories"] for f in cat["features"] if f["name"] == "Workflow composition"
        )
        self.assertTrue(wf["supported"])
        self.assertIn("Workflow composition", names)
        self.assertNotIn("Atomic flow catalog", names)
        self.assertNotEqual(features.get("rubric_source"), "fallback-template")

    def test_comparison_rows_synthesize_rubric_not_canned_template(self) -> None:
        comparison = {
            "rankings": [{"solution": "alpha", "score": 5, "rank": 1}],
            "rows": [
                {"type": "category", "name": "Orchestration"},
                {
                    "type": "feature",
                    "name": "Widget orchestration",
                    "solutions": {"alpha": True, "beta": False},
                },
            ],
        }
        rubric = synthesize_feature_rubric(comparison=comparison)
        self.assertEqual(rubric["source"], "comparison.json")
        names = [f for cat in rubric["categories"] for f in cat["features"]]
        self.assertEqual(names, ["Widget orchestration"])
        self.assertNotIn("Visual/E2E verification", names)
        features = build_features_json(
            "alpha",
            {"alpha": {"Widget orchestration": True}},
            comparison=comparison,
        )
        feat_names = [f["name"] for cat in features["categories"] for f in cat["features"]]
        self.assertEqual(feat_names, ["Widget orchestration"])

    def test_write_run_features_json_emits_rubric_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            comparison = {
                "rankings": [
                    {"solution": "alpha", "score": 4, "rank": 1},
                    {"solution": "beta", "score": 2, "rank": 2},
                ],
                "rows": [
                    {"type": "category", "name": "Core"},
                    {
                        "type": "feature",
                        "name": "Custom gate",
                        "solutions": {"alpha": True, "beta": False},
                    },
                ],
            }
            result = write_run_features_json(
                root,
                comparison=comparison,
                support={"alpha": {"Custom gate": True}, "beta": {"Custom gate": False}},
                known={"alpha": "Alpha", "beta": "Beta"},
            )
            self.assertEqual(result["rubric_source"], "comparison.json")
            rubric = json.loads((root / "landscape" / "features-rubric.json").read_text())
            self.assertEqual(rubric["source"], "comparison.json")
            alpha = json.loads((root / "solutions" / "alpha" / "features.json").read_text())
            names = [f["name"] for cat in alpha["categories"] for f in cat["features"]]
            self.assertEqual(names, ["Custom gate"])
            self.assertTrue(
                next(f for cat in alpha["categories"] for f in cat["features"])["supported"]
            )

    def test_parse_solution_led_matrix_entry_prose(self) -> None:
        claims = [
            (
                "Matrix entry — cc10x: high enforcement depth but Claude-only host breadth. "
                "One router controls advancement across workflows and persists evidence under .cc10x."
            ),
            (
                "Matrix entry — Silver Bullet: lifecycle_span=yes, plugin_skill_hook_packaging=yes, "
                "deterministic_gates=yes, cross_session_state=yes, specialist_agents=yes, "
                "quality_release_enforcement=yes, process_layer_above_host=yes. In-scope score 7/7."
            ),
        ]
        support = parse_feature_support(_envelopes_from_claims(claims))
        cc10x = support.get("cc10x", {})
        sb = support.get("silver-bullet", {})
        self.assertTrue(cc10x.get("Workflow composition"))
        self.assertTrue(cc10x.get("Hook-enforced gates"))
        self.assertTrue(sb.get("Workflow composition"))
        self.assertTrue(sb.get("Hook-enforced gates"))
        self.assertTrue(sb.get("Parent/child agent delegation"))

    def test_competitor_lacks_do_not_poison_primary_slug(self) -> None:
        claim = (
            "Cursor is Silver Bullet's most important startup competitor because it has momentum. "
            "However, Cursor lacks hook-enforced quality gates and workflow composition."
        )
        support = parse_feature_support(_envelopes_from_claims([claim]))
        sb = support.get("silver-bullet", {})
        self.assertIsNone(sb.get("Workflow composition"))
        self.assertIsNone(sb.get("Hook-enforced gates"))

    def test_parse_startup_weighted_core_bulk_list(self) -> None:
        claims = [
            (
                "Startup-weighted core (8–12) for matrix: Silver Bullet, Superpowers, GSD, BMAD, "
                "GitHub Spec Kit, Cavekit v3.1, Deepwork, Barkain, Conductor, cc10x, Director, SuperClaude."
            ),
            (
                "Confirmed in-scope core set for the startup-weighted matrix (all satisfy ≥3 inclusion "
                "criteria with lifecycle span, plugin/skill/hook packaging, deterministic gates, "
                "cross-session state, specialist agents, and quality/release enforcement above a host "
                "runtime): Silver Bullet, Zuvo, cc10x, AgentSys, Barkain, Turboshovel, Cavekit."
            ),
        ]
        from category_pack import build_known_solutions, resolve_pack_from_need

        need = {"category_pack_id": "agentic-sdlc-process-orchestrator"}
        pack = resolve_pack_from_need(need)
        known = build_known_solutions(pack)
        support = parse_feature_support(
            _envelopes_from_claims(claims),
            known=known,
            pack=pack,
        )
        for slug in ("bmad", "gsd", "zuvo", "spec-kit", "superpowers", "silver-bullet"):
            feats = support.get(slug, {})
            self.assertTrue(feats.get("Workflow composition"), msg=slug)
            self.assertTrue(feats.get("Hook-enforced gates"), msg=slug)

    def test_parse_matrix_leaders_for_saas_market(self) -> None:
        claim = (
            "Startup-weighted APO matrix leaders are Silver Bullet (host-integrated process layer), "
            "Factory.ai, Devin, and Augment Cosmos, with host runtimes excluded from direct peer comparison."
        )
        support = parse_feature_support(_envelopes_from_claims([claim]))
        for slug in ("factory-ai", "devin", "augment-cosmos"):
            self.assertTrue(support.get(slug, {}).get("Workflow composition"), msg=slug)


if __name__ == "__main__":
    unittest.main()


class OverviewIdentityLeakTests(unittest.TestCase):
    def test_director_superpowers_overview_rejected(self) -> None:
        from materialize_solution_artifacts import is_unusable_overview_claim

        self.assertTrue(
            is_unusable_overview_claim(
                "Superpowers is distributed through the first-party Claude plugin directory.",
                focus_name="Director",
            )
        )

    def test_cc10x_methodology_leak_rejected(self) -> None:
        from materialize_solution_artifacts import is_unusable_overview_claim

        self.assertTrue(
            is_unusable_overview_claim(
                "Startup-weighted comparison: Silver Bullet remains the anchor score.",
                focus_name="cc10x",
            )
        )


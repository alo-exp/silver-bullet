"""Tests for pack-driven solution classifier."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from category_pack import load_category_pack  # noqa: E402
from solution_classifier import classify_solutions  # noqa: E402


def _envelopes(*claims: str) -> list[dict]:
    return [
        {
            "phase_id": "DR-RETRIEVE",
            "logical_model_id": "test",
            "payload": {"evidence": [{"claim": c} for c in claims]},
        }
    ]


class SolutionClassifierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.pack = load_category_pack("agentic-sdlc-process-orchestrator")
        cls.need = {
            "category_pack_id": "agentic-sdlc-process-orchestrator",
            "hard_vetoes": ["tembo"],
        }

    def test_coding_agents_excluded(self) -> None:
        audit = classify_solutions(
            _envelopes("Cline is a popular IDE coding agent.", "Aider edits repos in git loops."),
            self.need,
            self.pack,
        )
        self.assertIn("cline", audit["excluded"])
        self.assertIn("aider", audit["excluded"])
        self.assertNotIn("cline", audit["core"])
        self.assertNotIn("aider", audit["core"])

    def test_core_seeds_classified_core(self) -> None:
        audit = classify_solutions(
            _envelopes("AI-DLC provides process orchestration.", "AgentSys composes SDLC workflows."),
            self.need,
            self.pack,
        )
        self.assertIn("ai-dlc", audit["core"])
        self.assertIn("agentsys", audit["core"])

    def test_linear_excluded(self) -> None:
        audit = classify_solutions(
            _envelopes("Linear issue tracking connects to coding agents."),
            self.need,
            self.pack,
        )
        self.assertIn("linear", audit["excluded"])

    def test_autogen_sunset(self) -> None:
        audit = classify_solutions(
            _envelopes("Microsoft AutoGen is a multi-agent framework."),
            self.need,
            self.pack,
        )
        self.assertIn("autogen", audit["sunset"])

    def test_parent_child_dedupe_cognition_devin(self) -> None:
        audit = classify_solutions(
            _envelopes("Cognition builds Devin.", "Devin plans and ships PRs."),
            self.need,
            self.pack,
        )
        matrix = set(audit.get("matrix_slugs") or [])
        self.assertTrue(
            "devin" in matrix or "devin" in audit["adjacent"],
            "devin should be matrix core or adjacent when evidenced in envelopes",
        )
        self.assertNotIn("cognition", audit["core"])

    def test_secondary_market_cores_not_excluded(self) -> None:
        audit = classify_solutions(
            _envelopes(
                "BMAD-METHOD ships 21 specialist agents.",
                "GSD is a Claude Code methodology pack.",
                "Superpowers composable skills by obra.",
                "Zuvo wraps Claude Code with quality gates.",
                "Oh My Pi composes specialist workflows.",
            ),
            self.need,
            self.pack,
        )
        matrix = set(audit.get("matrix_slugs") or [])
        for slug in ("bmad", "gsd", "superpowers", "zuvo", "oh-my-pi"):
            self.assertIn(slug, matrix, f"{slug} should be in matrix_slugs")
            self.assertNotIn(slug, audit["excluded"], f"{slug} must not be globally excluded")
            self.assertEqual(
                audit["by_slug"][slug]["classification"],
                "core",
                f"{slug} by_slug should be core",
            )
        self.assertLessEqual(len(audit["core"]), 24, "primary core count within pack max")

    def test_hard_vetoes_honored(self) -> None:
        audit = classify_solutions(
            _envelopes("Tembo runs cloud agents across repos."),
            self.need,
            self.pack,
        )
        self.assertIn("tembo", audit["excluded"])
        self.assertEqual(
            audit["by_slug"]["tembo"]["reason"],
            "hard_veto from need_profile",
        )

    def test_augment_code_excluded(self) -> None:
        audit = classify_solutions(
            _envelopes("Augment Code positions as agentic development at org scale."),
            self.need,
            self.pack,
        )
        self.assertNotIn("augment-code", audit["core"])
        matrix = set(audit.get("matrix_slugs") or [])
        self.assertTrue(
            "augment-code" in audit["excluded"]
            or "augment-cosmos" in matrix
            or "augment-cosmos" in audit["adjacent"]
            or "augment-cosmos" in audit["excluded"]
        )

    def test_silver_bullet_always_core(self) -> None:
        audit = classify_solutions(_envelopes("Silver Bullet orchestrates workflows."), self.need, self.pack)
        self.assertIn("silver-bullet", audit["core"])

    def test_must_research_gaps_tracked(self) -> None:
        audit = classify_solutions(_envelopes("Silver Bullet only."), self.need, self.pack)
        self.assertIn("ai-dlc", audit["gaps"])

    def test_adjacent_excludes_market_cores(self) -> None:
        audit = classify_solutions(
            _envelopes(
                "BMAD-METHOD ships specialist agents.",
                "GSD runs milestone SDLC loops.",
                "Zuvo is an OSS SDLC plugin.",
                "Factory.ai ships autonomous delivery.",
                "Devin plans and ships PRs.",
                "Silver Bullet enforces hook gates.",
                "AI-DLC provides process orchestration.",
            ),
            self.need,
            self.pack,
        )
        market_cores: set[str] = set()
        for ma in (audit.get("markets") or {}).values():
            market_cores.update(ma.get("core") or [])
        overlap = set(audit.get("adjacent") or []) & market_cores
        self.assertEqual(
            overlap,
            set(),
            f"adjacent must not list market cores: {sorted(overlap)}",
        )
        self.assertIn("bmad", market_cores)
        self.assertIn("factory-ai", market_cores)
        self.assertNotIn("bmad", audit.get("adjacent") or [])
        self.assertNotIn("factory-ai", audit.get("adjacent") or [])

    def test_product_alias_mirrored_in_by_slug(self) -> None:
        audit = classify_solutions(
            _envelopes("Factory.ai ships Droids for autonomous SDLC delivery."),
            self.need,
            self.pack,
        )
        self.assertIn("factory-ai", audit["by_slug"])
        self.assertEqual(audit["by_slug"]["factory-ai"]["classification"], "core")
        self.assertIn("factory", audit["by_slug"])
        self.assertEqual(audit["by_slug"]["factory"]["classification"], "core")
        self.assertEqual(audit["by_slug"]["factory"]["canonical_slug"], "factory-ai")


class PackSchemaTests(unittest.TestCase):
    def test_apo_pack_loads(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        self.assertEqual(pack["category_id"], "agentic-sdlc-process-orchestrator")
        self.assertGreaterEqual(len(pack["core_seeds"]), 5)


if __name__ == "__main__":
    unittest.main()

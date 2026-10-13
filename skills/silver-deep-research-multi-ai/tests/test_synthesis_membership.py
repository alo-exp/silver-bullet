"""Synthesis membership aligned with matrix columns (pack-driven)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from materialize_solution_artifacts import materialize_solution_artifacts  # noqa: E402
from synthesize_landscape import build_report_markdown, synthesize_landscape  # noqa: E402


APO_NEED = {
    "category": "Agentic SDLC Process Orchestrators",
    "category_pack_id": "agentic-sdlc-process-orchestrator",
    "must_haves": ["workflow composition"],
}

ENVELOPES = [
    {
        "phase_id": "DR-RETRIEVE",
        "logical_model_id": "test",
        "payload": {
            "evidence": [
                {
                    "claim": (
                        "Matrix entry — Workflow composition: "
                        "✔ silver-bullet, ai-dlc, agentsys; ✖ cline, aider, cursor-agents."
                    )
                },
                {"claim": "AI-DLC provides process orchestration above coding agents."},
                {"claim": "AgentSys composes SDLC workflows with hook gates."},
                {"claim": "Cline is an IDE coding agent — out of scope for APO."},
            ]
        },
    }
]


class SynthesisMembershipTests(unittest.TestCase):
    def test_core_matrix_excludes_coding_agents(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(
                json.dumps(ENVELOPES), encoding="utf-8"
            )
            (root / "need_profile.json").write_text(json.dumps(APO_NEED), encoding="utf-8")
            mat = materialize_solution_artifacts(root, envelopes=ENVELOPES)
            slugs = {
                s["slug"]
                for s in json.loads((root / "solutions.json").read_text())["solutions"]
            }
            self.assertIn("silver-bullet", slugs)
            self.assertIn("ai-dlc", slugs)
            self.assertNotIn("cline", slugs)
            self.assertNotIn("aider", slugs)
            self.assertGreater(mat.get("core_count", 0), 0)

    def test_report_sections_exclude_hard_exclusions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "contributions").mkdir()
            (root / "contributions" / "all-envelopes.json").write_text(
                json.dumps(ENVELOPES), encoding="utf-8"
            )
            (root / "need_profile.json").write_text(json.dumps(APO_NEED), encoding="utf-8")
            comparison = {
                "winner": "silver-bullet",
                "rankings": [
                    {"solution": "silver-bullet", "score": 28},
                    {"solution": "ai-dlc", "score": 22},
                    {"solution": "agentsys", "score": 20},
                ],
                "rows": [
                    {
                        "type": "feature",
                        "name": "Workflow composition",
                        "solutions": {"silver-bullet": True, "ai-dlc": True, "agentsys": True},
                    }
                ],
            }
            (root / "comparison" / "comparison.json").parent.mkdir(parents=True, exist_ok=True)
            (root / "comparison" / "comparison.json").write_text(
                json.dumps(comparison), encoding="utf-8"
            )
            md = build_report_markdown(
                category=APO_NEED["category"],
                platform_list="test",
                scope_text="agentic sdlc process orchestration",
                need=APO_NEED,
                comparison=comparison,
                consolidation={"consensus": [], "divergence": []},
                envelopes=ENVELOPES,
                claims=[],
                root=root,
                report_date="July 19, 2026",
            )
            self.assertIn("Adjacent Markets", md)
            self.assertIn("Explicitly Excluded", md)
            self.assertIn("Consensus Patterns", md)
            self.assertIn("Scoring methodology", md)
            self.assertIn("Lean startup / spec-first packs", md)
            self.assertNotIn("Prioritise Silver Bullet and OSS core orchestrators", md)
            self.assertNotRegex(md, r"### Cline \(OSS")
            self.assertNotRegex(md, r"### Aider \(OSS")
            matrix_slugs = {r["solution"] for r in comparison["rankings"]}
            for slug in ("silver-bullet", "ai-dlc", "agentsys"):
                self.assertIn(slug, matrix_slugs)


if __name__ == "__main__":
    unittest.main()


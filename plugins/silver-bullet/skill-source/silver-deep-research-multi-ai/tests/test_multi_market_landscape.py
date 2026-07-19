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
        plugin_slugs = {s["slug"] for s in self.pack["markets"][1]["seeds"]}
        self.assertNotIn("zuvo", apo_slugs)
        self.assertIn("zuvo", plugin_slugs)
        licenses = build_license_by_slug(self.pack)
        self.assertEqual(licenses["zuvo"], "oss")

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


if __name__ == "__main__":
    unittest.main()

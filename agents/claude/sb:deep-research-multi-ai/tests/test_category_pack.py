"""Unit tests for category market pack schema and loader."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
DR_SKILL = SKILL_ROOT.parent / "silver-deep-research"
PACKS_DIR = DR_SKILL / "reference" / "landscape" / "category-packs"
SCHEMA_PATH = PACKS_DIR / "schema.json"
APO_PACK_PATH = PACKS_DIR / "agentic-sdlc-process-orchestrator.json"

sys.path.insert(0, str(SCRIPTS))

from category_pack import (  # noqa: E402
    apply_parent_child_dedupe,
    format_inclusion_criteria_prose,
    get_core_seed_slugs,
    get_hard_exclusion_slugs,
    get_must_research_slugs,
    get_product_aliases,
    load_category_pack,
    pack_prompt_block,
    resolve_canonical_slug,
    resolve_pack_from_need_profile,
)


class CategoryPackSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        cls.apo = json.loads(APO_PACK_PATH.read_text(encoding="utf-8"))

    def test_schema_and_apo_pack_exist(self) -> None:
        self.assertTrue(SCHEMA_PATH.is_file())
        self.assertTrue(APO_PACK_PATH.is_file())

    def test_apo_pack_required_fields(self) -> None:
        required = set(self.schema["required"])
        for field in required:
            self.assertIn(field, self.apo, f"missing required field: {field}")

    def test_apo_inclusion_criteria_seven_with_min_three(self) -> None:
        criteria = self.apo["inclusion_criteria"]
        self.assertEqual(criteria["rule"], "min_pass_count")
        self.assertEqual(criteria["min_pass_count"], 3)
        self.assertEqual(len(criteria["criteria"]), 7)
        prose = format_inclusion_criteria_prose(self.apo)
        self.assertIn("core peer set", prose)
        self.assertIn("3 of 7", prose)
        self.assertNotIn("min_pass_count", prose)

    def test_apo_core_and_exclusion_counts(self) -> None:
        self.assertGreaterEqual(len(self.apo["core_seeds"]), 8)
        self.assertGreaterEqual(len(self.apo["hard_exclusions"]), 10)
        self.assertGreaterEqual(len(self.apo["adjacent_seeds"]), 5)
        self.assertLessEqual(self.apo["min_core_count"], self.apo["max_core_count"])

    def test_apo_always_includes_silver_bullet_seed(self) -> None:
        slugs = [s["slug"] for s in self.apo["core_seeds"]]
        self.assertIn("silver-bullet", slugs)

    def test_apo_hard_excludes_coding_agents(self) -> None:
        slugs = {e["slug"] for e in self.apo["hard_exclusions"]}
        for banned in ("cline", "aider", "coderabbit", "linear"):
            self.assertIn(banned, slugs)


class CategoryPackLoaderTests(unittest.TestCase):
    def test_load_category_pack(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        self.assertEqual(pack["category_id"], "agentic-sdlc-process-orchestrator")
        self.assertIn("AI-DLC", pack_prompt_block(pack))

    def test_load_invalid_pack_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            load_category_pack("nonexistent-pack")

    def test_resolve_pack_from_need_profile(self) -> None:
        need = {
            "category_pack_id": "agentic-sdlc-process-orchestrator",
            "must_research": ["custom-orchestrator"],
            "hard_vetoes": ["tembo"],
            "allow_adjacent_section": False,
        }
        merged = resolve_pack_from_need_profile(need)
        self.assertIn("custom-orchestrator", merged["must_research"])
        self.assertIn("tembo", merged["hard_exclusion_slugs"])
        self.assertFalse(merged["allow_adjacent_section"])

    def test_resolve_missing_pack_id_raises(self) -> None:
        with self.assertRaises(ValueError):
            resolve_pack_from_need_profile({"category": "x"})

    def test_must_research_slugs_from_core_seeds(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        slugs = get_must_research_slugs(pack)
        self.assertIn("ai-dlc", slugs)
        self.assertIn("agentsys", slugs)

    def test_aliases_and_dedupe(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        aliases = get_product_aliases(pack)
        self.assertEqual(aliases["augment-code"], "augment-cosmos")
        self.assertEqual(resolve_canonical_slug("cognition", pack), "devin")
        deduped = apply_parent_child_dedupe(["cognition", "devin", "ai-dlc"], pack)
        self.assertEqual(deduped, ["devin", "ai-dlc"])
        deduped_lg = apply_parent_child_dedupe(["langchain", "langgraph", "ai-dlc"], pack)
        self.assertEqual(deduped_lg, ["langgraph", "ai-dlc"])

    def test_hard_exclusions_include_sunset(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        slugs = get_hard_exclusion_slugs(pack)
        self.assertIn("autogen", slugs)
        self.assertIn("copilot-workspace", slugs)

    def test_core_seed_slugs_unique(self) -> None:
        pack = load_category_pack("agentic-sdlc-process-orchestrator")
        slugs = get_core_seed_slugs(pack)
        self.assertEqual(len(slugs), len(set(slugs)))


if __name__ == "__main__":
    unittest.main()

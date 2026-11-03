"""Pool completeness hard-fail and resolution tests for DR live runner."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
REPO_ROOT = SKILL_ROOT.parents[1]

sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(REPO_ROOT / "skills" / "silver-multi-ai-task" / "scripts"))

from dr_live_runner import validate_pool_completeness  # noqa: E402
from multi_ai_core import PoolSelection, resolve_pool  # noqa: E402


class PoolResolutionTests(unittest.TestCase):
    def test_lite_default_resolves_eleven(self) -> None:
        resolved = resolve_pool(PoolSelection(ocg_pool="lite", cursor_pool="default"))
        self.assertEqual(len(resolved), 11)
        ids = {item["logical_model_id"] for item in resolved}
        self.assertIn("composer-2.5", ids)
        self.assertIn("ocg-kimi-k2.7-code", ids)

    def test_include_only_subset_resolves_n(self) -> None:
        subset = ["composer-2.5", "grok-4.5", "ocg-kimi-k2.7-code"]
        resolved = resolve_pool(
            PoolSelection(ocg_pool="lite", cursor_pool="default", include_only=subset)
        )
        self.assertEqual(len(resolved), 3)
        self.assertEqual({item["logical_model_id"] for item in resolved}, set(subset))


class PoolCompletenessTests(unittest.TestCase):
    def test_validate_accepts_full_completion(self) -> None:
        resolved = [{"logical_model_id": "a"}, {"logical_model_id": "b"}]
        phase_results = [
            {
                "phase_id": "DR-RETRIEVE",
                "workers": [
                    {"logical_model_id": "a", "has_envelope": True, "status": "completed"},
                    {"logical_model_id": "b", "has_envelope": True, "status": "completed"},
                ],
            },
            {
                "phase_id": "DR-TRIANGULATE",
                "workers": [
                    {"logical_model_id": "a", "has_envelope": True, "status": "completed"},
                    {"logical_model_id": "b", "has_envelope": True, "status": "completed"},
                ],
            },
        ]
        ok, errors = validate_pool_completeness(resolved, phase_results)
        self.assertTrue(ok)
        self.assertEqual(errors, [])

    def test_validate_rejects_partial_completion(self) -> None:
        resolved = [{"logical_model_id": "a"}, {"logical_model_id": "b"}]
        phase_results = [
            {
                "phase_id": "DR-RETRIEVE",
                "workers": [
                    {"logical_model_id": "a", "has_envelope": True, "status": "completed"},
                    {"logical_model_id": "b", "has_envelope": False, "status": "failed"},
                ],
            },
        ]
        ok, errors = validate_pool_completeness(resolved, phase_results)
        self.assertFalse(ok)
        self.assertEqual(len(errors), 1)
        self.assertIn("b", errors[0])


if __name__ == "__main__":
    unittest.main()



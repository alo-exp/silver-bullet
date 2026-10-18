"""Unit tests for scripts/lib/apo_multi_ai_catalog.py."""
from __future__ import annotations

import unittest

from sbtest import load_module

ma = load_module("scripts/lib/apo_multi_ai_catalog.py")


def _atomic(**extra):
    flow = {"id": "AF-MULTI-AI-TASK", "execution": {"parallelizable": False}}
    flow.update(extra)
    return flow


class BuildFlowStepsTest(unittest.TestCase):
    def test_steps_follow_order_with_evidence(self):
        steps, evidence = ma.build_multi_ai_flow_steps()
        self.assertEqual([s["id"] for s in steps], ma.MULTI_AI_FLOW_STEP_ORDER)
        self.assertEqual(set(ma.MULTI_AI_FLOW_STEP_ORDER), set(ma.MULTI_AI_STEP_DEFS))
        self.assertEqual(len(evidence), len(steps))
        first = steps[0]
        self.assertEqual(first["v_loop"]["id"], "VL-FS-MULTI-AI-RESOLVE")
        self.assertEqual(first["v_loop"]["evidence_refs"], ["EV-FS-MULTI-AI-RESOLVE"])
        self.assertEqual(first["canonical_catalog_entity"], "AF-MULTI-AI-TASK")
        self.assertEqual(evidence[0]["producer"], "FS-MULTI-AI-RESOLVE")
        self.assertEqual(evidence[0]["satisfies_v_loop_ref"], "VL-FS-MULTI-AI-RESOLVE")
        self.assertEqual(steps[-1]["classification"], "flow-step-skill")


class MergeCatalogTest(unittest.TestCase):
    def _merge(self, atomic_flows, flow_steps=None, step_evidence=None,
               artifacts=None, flow_evidence=None):
        flow_steps = flow_steps if flow_steps is not None else []
        flow_to_steps = {}
        step_evidence = step_evidence if step_evidence is not None else []
        artifacts = artifacts if artifacts is not None else []
        flow_evidence = flow_evidence if flow_evidence is not None else []
        ma.merge_multi_ai_catalog(
            flow_steps, flow_to_steps, step_evidence, atomic_flows, artifacts, flow_evidence
        )
        return flow_steps, flow_to_steps, step_evidence, artifacts, flow_evidence

    def test_merge_replaces_stale_entries_in_place_and_sorts(self):
        flow_steps = [
            {"id": "ZZ-OTHER"},
            {"id": "FS-MULTI-AI-RESOLVE", "stale": True},
            {"id": "AA-OTHER"},
        ]
        step_evidence = [
            {"id": "old", "producer": "FS-MULTI-AI-INDEX"},
            {"id": "keep", "producer": "SOMETHING-ELSE"},
        ]
        artifacts = [{"id": "ART-MULTI_AI_TASK", "stale": True}, {"id": "ART-KEEP"}]
        flow_evidence = [{"id": "EV-AF-MULTI-AI-TASK", "stale": True}, {"id": "EV-KEEP"}]
        steps, f2s, sev, arts, fev = self._merge(
            [], flow_steps, step_evidence, artifacts, flow_evidence
        )
        ids = [s["id"] for s in steps]
        self.assertEqual(ids, sorted(ids))
        self.assertEqual(len(ids), 2 + len(ma.MULTI_AI_FLOW_STEP_ORDER))
        self.assertNotIn(True, [s.get("stale") for s in steps])
        self.assertEqual(f2s["AF-MULTI-AI-TASK"], ma.MULTI_AI_FLOW_STEP_ORDER)
        self.assertIsNot(f2s["AF-MULTI-AI-TASK"], ma.MULTI_AI_FLOW_STEP_ORDER)
        self.assertEqual(sev[0]["id"], "keep")
        self.assertEqual(len(sev), 1 + len(ma.MULTI_AI_FLOW_STEP_ORDER))
        self.assertEqual([a["id"] for a in arts], ["ART-KEEP", "ART-MULTI_AI_TASK"])
        self.assertNotIn("stale", arts[1])
        self.assertEqual(arts[1]["producer"], "AF-MULTI-AI-TASK")
        self.assertEqual([r["id"] for r in fev], ["EV-KEEP", "EV-AF-MULTI-AI-TASK"])
        self.assertEqual(fev[1]["sufficiency_class"], "artifact_review")
        self.assertEqual(fev[1]["artifact_or_tool_ref"], "ART-MULTI_AI_TASK")

    def test_atomic_flow_updated_and_new_v_loop_created(self):
        other = {"id": "AF-OTHER"}
        flow = _atomic()
        self._merge([other, flow])
        self.assertEqual(other, {"id": "AF-OTHER"})
        self.assertEqual(flow["owning_skills"], ["silver-multi-ai-task"])
        self.assertEqual(flow["flow_steps"], ma.MULTI_AI_FLOW_STEP_ORDER)
        self.assertIsNot(flow["flow_steps"], ma.MULTI_AI_FLOW_STEP_ORDER)
        self.assertEqual(flow["artifacts"], ["ART-MULTI_AI_TASK"])
        self.assertTrue(flow["execution"]["parallelizable"])
        self.assertEqual(flow["dedup_gate_status"], "passed")
        self.assertEqual(flow["v_loop"]["evidence_refs"], ["EV-AF-MULTI-AI-TASK"])
        self.assertEqual(set(flow["dedup_gate"]), {
            "equivalence_review", "granularity_review", "usage_review",
            "v_loop_review", "step_review",
        })

    def test_existing_v_loop_refs_preserved_and_not_duplicated(self):
        flow = _atomic(v_loop={"evidence_refs": ["EV-X"], "id": "keep"})
        self._merge([flow])
        self.assertEqual(flow["v_loop"]["evidence_refs"], ["EV-X", "EV-AF-MULTI-AI-TASK"])
        self.assertEqual(flow["v_loop"]["id"], "keep")
        # Idempotent: second merge adds nothing.
        self._merge([flow])
        self.assertEqual(flow["v_loop"]["evidence_refs"], ["EV-X", "EV-AF-MULTI-AI-TASK"])

    def test_null_evidence_refs_treated_as_empty(self):
        flow = _atomic(v_loop={"evidence_refs": None})
        self._merge([flow])
        self.assertEqual(flow["v_loop"]["evidence_refs"], ["EV-AF-MULTI-AI-TASK"])


if __name__ == "__main__":
    unittest.main()

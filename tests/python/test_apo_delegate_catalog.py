"""Unit tests for scripts/lib/apo_catalog_common.py and apo_delegate_catalog.py."""
from __future__ import annotations

import unittest

from sbtest import load_module

common = load_module("scripts/lib/apo_catalog_common.py")
deleg = load_module("scripts/lib/apo_delegate_catalog.py")


class EvidenceRecordTest(unittest.TestCase):
    def test_shape(self):
        rec = common.evidence_record("EV-1", "P", "VL-1", "inspection", "ART-1")
        self.assertEqual(rec, {
            "id": "EV-1",
            "producer": "P",
            "artifact_or_tool_ref": "ART-1",
            "sufficiency_class": "inspection",
            "staleness_key": "catalog-version+entity-contract",
            "satisfies_v_loop_ref": "VL-1",
        })


class BuildDelegateFlowStepsTest(unittest.TestCase):
    def test_steps_follow_order_and_have_evidence(self):
        steps, evidence = deleg.build_delegate_flow_steps()
        self.assertEqual([s["id"] for s in steps], deleg.DELEGATE_FLOW_STEP_ORDER)
        self.assertEqual(len(evidence), len(steps) + 1)
        self.assertEqual(evidence[-1]["id"], "EV-DELEGATE-DEGRADED-FALLBACK")
        self.assertEqual(evidence[-1]["sufficiency_class"], "command_evidence")
        first = steps[0]
        self.assertEqual(first["v_loop"]["id"], "VL-FS-DELEGATE-BRIEF")
        self.assertEqual(first["v_loop"]["evidence_refs"], ["EV-FS-DELEGATE-BRIEF"])
        self.assertEqual(first["canonical_catalog_entity"], "AF-AGENT-DELEGATE")

    def test_every_ordered_step_has_a_definition(self):
        self.assertEqual(set(deleg.DELEGATE_FLOW_STEP_ORDER), set(deleg.DELEGATE_STEP_DEFS))


class MergeDelegateCatalogTest(unittest.TestCase):
    def _merge(self, atomic_flows):
        flow_steps = [
            {"id": "FS-DELEGATE-BRIEF", "stale": True},
            {"id": "FS-SILVER_AGENT_OPENCODE", "reusable_by_flows": ["X"]},
            {"id": "FS-SILVER_AGENT_PI", "reusable_by_flows": ["X"]},
            {"id": "FS-OTHER"},
        ]
        flow_to_steps = {}
        step_evidence = [
            {"producer": "FS-DELEGATE-BRIEF", "id": "old"},
            {"producer": "FS-OTHER", "id": "keep"},
        ]
        artifacts = []
        flow_evidence = [{"id": "EV-AF-AGENT-DELEGATE", "old": True}, {"id": "EV-KEEP"}]
        deleg.merge_delegate_catalog(
            flow_steps, flow_to_steps, step_evidence, atomic_flows, artifacts, flow_evidence
        )
        return flow_steps, flow_to_steps, step_evidence, artifacts, flow_evidence

    def test_merge_replaces_and_updates_delegate_flow(self):
        delegate_flow = {
            "id": "AF-AGENT-DELEGATE",
            "execution": {"parallelizable": True},
            "v_loop": {"evidence_refs": ["EV-AF-AGENT-DELEGATE", "EV-X"]},
        }
        other_flow = {"id": "AF-OTHER"}
        steps, f2s, step_ev, arts, flow_ev = self._merge([other_flow, delegate_flow])

        ids = [s["id"] for s in steps]
        self.assertEqual(ids, sorted(ids))
        self.assertNotIn("stale", [s for s in steps if s["id"] == "FS-DELEGATE-BRIEF"][0])
        self.assertEqual(f2s["AF-AGENT-DELEGATE"], deleg.DELEGATE_FLOW_STEP_ORDER)
        self.assertEqual([r["id"] for r in step_ev if r["id"] in ("old", "keep")], ["keep"])
        self.assertEqual(arts[0]["id"], "ART-AGENT-DELEGATE")
        self.assertEqual([r["id"] for r in flow_ev], ["EV-KEEP", "EV-AF-AGENT-DELEGATE"])
        self.assertNotIn("old", flow_ev[-1])
        self.assertEqual(other_flow, {"id": "AF-OTHER"})
        self.assertFalse(delegate_flow["execution"]["parallelizable"])
        self.assertEqual(delegate_flow["dedup_gate_status"], "passed")
        self.assertEqual(delegate_flow["artifacts"], ["ART-AGENT-DELEGATE"])
        self.assertEqual(
            delegate_flow["v_loop"]["evidence_refs"],
            ["EV-AF-AGENT-DELEGATE", "EV-X", "EV-DELEGATE-DEGRADED-FALLBACK"],
        )
        for sid in ("FS-SILVER_AGENT_OPENCODE", "FS-SILVER_AGENT_PI"):
            step = [s for s in steps if s["id"] == sid][0]
            self.assertEqual(step["reusable_by_flows"], ["AF-AGENT-DELEGATE"])
        self.assertEqual(
            delegate_flow["owning_skills"],
            ["silver-agent-codex", "silver-agent-cursor", "silver-agent-claude"],
        )

    def test_merge_creates_missing_v_loop_with_both_refs(self):
        flow = {"id": "AF-AGENT-DELEGATE", "execution": {}}
        self._merge([flow])
        self.assertEqual(
            flow["v_loop"]["evidence_refs"],
            ["EV-AF-AGENT-DELEGATE", "EV-DELEGATE-DEGRADED-FALLBACK"],
        )

    def test_merge_keeps_refs_when_both_present(self):
        refs = ["EV-AF-AGENT-DELEGATE", "EV-DELEGATE-DEGRADED-FALLBACK"]
        flow = {"id": "AF-AGENT-DELEGATE", "execution": {}, "v_loop": {"evidence_refs": list(refs)}}
        self._merge([flow])
        self.assertEqual(flow["v_loop"]["evidence_refs"], refs)


if __name__ == "__main__":
    unittest.main()

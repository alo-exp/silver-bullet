"""Unit tests for scripts/generate-apo-catalog.py (never rewrites docs/apo-catalog.json)."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

g = load_module("scripts/generate-apo-catalog.py")


class ImportPathTest(unittest.TestCase):
    LIB = str(REPO_ROOT / "scripts" / "lib")

    def test_lib_dir_is_added_to_sys_path_when_absent(self):
        import sys
        trimmed = [p for p in sys.path if p != self.LIB]
        with mock.patch.object(sys, "path", trimmed):
            load_module("scripts/generate-apo-catalog.py", name="gen_catalog_fresh_a")
            self.assertEqual(trimmed[0], self.LIB)

    def test_lib_dir_not_duplicated_when_present(self):
        import sys
        path = [self.LIB] + [p for p in sys.path if p != self.LIB]
        with mock.patch.object(sys, "path", path):
            load_module("scripts/generate-apo-catalog.py", name="gen_catalog_fresh_b")
            self.assertEqual(path.count(self.LIB), 1)


class ClassifySkillTest(unittest.TestCase):
    def test_classes(self):
        self.assertEqual(g.classify_skill("silver-feature"), "precomposed-workflow")
        self.assertEqual(g.classify_skill("silver"), "process-router")
        self.assertEqual(g.classify_skill("silver-orchestrator"), "process-router")
        self.assertEqual(g.classify_skill("review-spec"), "reviewer-pack")
        self.assertEqual(g.classify_skill("artifact-reviewer"), "reviewer-pack")
        self.assertEqual(g.classify_skill("security"), "quality-dimension-step")
        self.assertEqual(g.classify_skill("silver-plan"), "flow-step-skill")


class WorkflowBuilderTest(unittest.TestCase):
    def test_composition_node(self):
        self.assertEqual(g.composition_node("AF-X"), {"kind": "atomic_flow", "ref": "AF-X"})
        self.assertEqual(
            g.composition_node("WF-Y", "workflow", optional=True),
            {"kind": "workflow", "ref": "WF-Y", "optional": True},
        )

    def test_workflow_defaults(self):
        doc = g.workflow("WF-A", "a", "t", [])
        self.assertEqual(doc["triggers"], ["a"])
        self.assertFalse(doc["reusable_as_component"])
        self.assertEqual(doc["allowed_dynamic_operations"],
                         ["prune", "insert", "substitute", "parallelize", "loop"])
        self.assertEqual(doc["final_intent_gate"], "INTENT-GATE-DEFAULT")
        self.assertNotIn("enforcement_queue", doc)
        self.assertNotIn("owning_skill", doc)

    def test_workflow_options(self):
        doc = g.workflow("WF-A", "a", "t", [{"x": 1}], owner="own", reusable=True,
                         triggers=["t1"], queue=["q"], ops=[])
        self.assertEqual(doc["owning_skill"], "own")
        self.assertEqual(doc["enforcement_queue"], ["q"])
        self.assertEqual(doc["triggers"], ["t1"])
        self.assertEqual(doc["allowed_dynamic_operations"], [])  # explicit empty list is honoured
        self.assertTrue(doc["reusable_as_component"])


def _step():
    return {
        "purpose": "p", "outputs": ["o"],
        "v_loop": {"work_product": "w", "verification": {"methods": ["m"], "artifact_refs": ["r"]},
                   "validation": {"target": "t", "methods": ["vm"]}},
    }


class OverridesTest(unittest.TestCase):
    def test_no_override_leaves_step_untouched(self):
        step = _step()
        g.apply_flow_step_overrides(step, "silver-plan")
        self.assertEqual(step, _step())

    def test_full_override(self):
        step = _step()
        g.apply_flow_step_overrides(step, "silver-deep-research")
        self.assertTrue(step["purpose"].startswith("Execute the nested SB deep-research"))
        self.assertIn("vloop-rollup.json", step["outputs"])
        self.assertTrue(step["v_loop"]["work_product"].startswith("Phase-level"))
        self.assertEqual(step["v_loop"]["verification"]["methods"], ["m"])  # merged, not replaced
        self.assertIn(".planning/research/<date>-<slug>/vloop-rollup.json",
                      step["v_loop"]["verification"]["artifact_refs"])
        self.assertEqual(step["v_loop"]["validation"]["target"], "t")
        self.assertEqual(len(step["v_loop"]["validation"]["methods"]), 2)

    def test_partial_overrides(self):
        step = _step()
        with mock.patch.dict(g.FLOW_STEP_OVERRIDES, {"only-purpose": {"purpose": "P2"}}):
            g.apply_flow_step_overrides(step, "only-purpose")
        self.assertEqual(step["purpose"], "P2")
        self.assertEqual(step["outputs"], ["o"])
        self.assertEqual(step["v_loop"], _step()["v_loop"])
        step2 = _step()
        with mock.patch.dict(g.FLOW_STEP_OVERRIDES, {"only-outputs": {"outputs": ["x"], "v_loop": {}}}):
            g.apply_flow_step_overrides(step2, "only-outputs")
        self.assertEqual(step2["outputs"], ["x"])
        self.assertEqual(step2["purpose"], "p")
        step3 = _step()
        with mock.patch.dict(g.FLOW_STEP_OVERRIDES, {"vl": {"v_loop": {"work_product": "WP"}}}):
            g.apply_flow_step_overrides(step3, "vl")
        self.assertEqual(step3["v_loop"]["work_product"], "WP")
        self.assertEqual(step3["v_loop"]["verification"], _step()["v_loop"]["verification"])

    def test_outputs_override_is_copied(self):
        step = _step()
        g.apply_flow_step_overrides(step, "silver-deep-research-multi-ai")
        step["outputs"].append("mutation")
        self.assertNotIn("mutation", g.FLOW_STEP_OVERRIDES["silver-deep-research-multi-ai"]["outputs"])


class BuildStepsAndFlowsTest(unittest.TestCase):
    NAMES = ["silver-plan", "silver-deep-research", "review-spec"]

    def test_build_flow_steps(self):
        steps, f2s, evidence = g.build_flow_steps(self.NAMES)
        self.assertEqual([s["id"] for s in steps], sorted(s["id"] for s in steps))
        by_skill = {s["skill"]: s for s in steps}
        plan = by_skill["silver-plan"]
        self.assertEqual(plan["id"], "FS-SILVER_PLAN")
        self.assertEqual(plan["classification"], "flow-step-skill")
        self.assertEqual(plan["canonical_catalog_entity"], g.SKILL_TO_FLOW["silver-plan"])
        self.assertEqual(plan["v_loop"]["verification"]["methods"], [g.EVIDENCE_CLASSES[0]])
        self.assertEqual(by_skill["review-spec"]["v_loop"]["verification"]["methods"],
                         [g.EVIDENCE_CLASSES[2]])
        self.assertTrue(by_skill["silver-deep-research"]["purpose"].startswith("Execute the nested"))
        self.assertEqual(len(evidence), 3)
        self.assertEqual(evidence[0]["id"], "EV-FS-SILVER_PLAN")
        self.assertEqual(evidence[0]["artifact_or_tool_ref"], "skills/silver-plan/SKILL.md")
        self.assertIn("FS-SILVER_PLAN", f2s[g.SKILL_TO_FLOW["silver-plan"]])
        self.assertEqual(set(f2s), {spec[0] for spec in g.ATOMIC_SPECS})

    def test_build_atomic_flows(self):
        steps, f2s, _ = g.build_flow_steps(self.NAMES)
        flows, evidence = g.build_atomic_flows(steps, f2s)
        self.assertEqual([f["id"] for f in flows], [s[0] for s in g.ATOMIC_SPECS])
        self.assertEqual(len(evidence), len(flows))
        by_id = {f["id"]: f for f in flows}
        self.assertEqual(by_id["AF-DECIDE"]["tools"], ["TP-GRAPHIFY", "TP-SEARCH-CLI"])
        self.assertEqual(by_id["AF-ORIENT"]["tools"], ["TP-GRAPHIFY"])
        self.assertEqual(by_id["AF-ROUTE"]["tools"], [])
        self.assertFalse(by_id["AF-ROUTE"]["execution"]["parallelizable"])
        self.assertFalse(by_id["AF-AGENT-DELEGATE"]["execution"]["parallelizable"])
        self.assertTrue(by_id["AF-PLAN"]["execution"]["parallelizable"])
        for flow_id, templates in g.SKILL_WORKER_TEMPLATES.items():
            self.assertEqual(by_id[flow_id]["execution"]["skill_worker_templates"], templates)
        plain = [f for f in flows if f["id"] not in g.SKILL_WORKER_TEMPLATES]
        self.assertTrue(plain)
        self.assertTrue(all("skill_worker_templates" not in f["execution"] for f in plain))
        decide = by_id["AF-DECIDE"]
        self.assertEqual(decide["flow_steps"], sorted(f2s["AF-DECIDE"]))
        self.assertEqual(decide["owning_skills"], ["silver-deep-research"])
        self.assertEqual(decide["artifacts"], ["ART-DECIDE"])


class BuildCatalogTest(unittest.TestCase):
    def test_matches_committed_catalog(self):
        self.assertEqual(g.build_catalog(), json.loads(g.CATALOG_PATH.read_text(encoding="utf-8")))

    def test_unmapped_skill_aborts(self):
        with tempfile.TemporaryDirectory() as d:
            skills = Path(d)
            for name in ("silver-plan", "brand-new-skill"):
                (skills / name).mkdir()
                (skills / name / "SKILL.md").write_text("x")
            (skills / "no-skill-file").mkdir()
            with mock.patch.object(g, "SKILLS_DIR", skills):
                with self.assertRaises(SystemExit) as cm:
                    g.build_catalog()
        self.assertEqual(str(cm.exception), "missing skill mapping: ['brand-new-skill']")

    def test_agent_worker_skill_is_excluded_from_flow_steps(self):
        cat = g.build_catalog()
        self.assertNotIn("FS-SILVER_AGENT_WORKER", [s["id"] for s in cat["flow_steps"]])
        self.assertIn("silver-agent-worker", cat["migration_map"]["skill_to_entity"])
        ids = [f["id"] for f in cat["atomic_flows"]]
        self.assertEqual(len(ids), len(set(ids)))


class MainTest(unittest.TestCase):
    def test_main_writes_catalog_and_reports_counts(self):
        with tempfile.TemporaryDirectory() as d:
            out_path = Path(d) / "docs" / "apo-catalog.json"
            out_path.parent.mkdir()
            fake = {"atomic_flows": [1, 2], "workflows": [1], "flow_steps": [1, 2, 3]}
            buf = io.StringIO()
            with mock.patch.object(g, "REPO_ROOT", Path(d)), mock.patch.object(g, "CATALOG_PATH", out_path), \
                    mock.patch.object(g, "build_catalog", return_value=fake), contextlib.redirect_stdout(buf):
                rc = g.main()
            self.assertEqual(rc, 0)
            self.assertEqual(out_path.read_text(), json.dumps(fake, indent=2) + "\n")
            self.assertEqual(buf.getvalue(),
                             "wrote docs/apo-catalog.json: 2 atomic flows, 1 workflows, 3 flow steps\n")

    def test_script_entrypoint_regenerates_identical_catalog(self):
        writes = {}

        def capture(self, data, *a, **k):
            writes[str(self)] = data
            return len(data)

        with mock.patch.object(Path, "write_text", capture), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "generate-apo-catalog.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        target = str(REPO_ROOT / "docs" / "apo-catalog.json")
        self.assertEqual(list(writes), [target])
        self.assertEqual(writes[target], (REPO_ROOT / "docs" / "apo-catalog.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()

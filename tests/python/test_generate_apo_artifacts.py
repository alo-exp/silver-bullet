"""Unit tests for scripts/generate-apo-artifacts.py (never writes tracked repo files)."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

g = load_module("scripts/generate-apo-artifacts.py")

CATALOG = {
    "catalog_version": "9.9.9",
    "migration_map": {
        "legacy_flows": {"FLOW 1": "AF-ONE"},
        "runtime_queue_tokens": {"zz": "AF-TWO", "aa": "AF-ONE"},
        "skill_to_entity": {"sb:x": "AF-ONE"},
        "gsd_alias_to_entity": {"gsd-y": "AF-TWO"},
    },
    "atomic_flows": [
        {
            "id": "AF-TWO",
            "capability_class": "B",
            "owning_skills": ["s2", "s3"],
            "execution": {
                "worker_template": "t/two.md",
                "skill_worker_templates": {"s3": "t/s3.md", "s2": "t/s2.md"},
            },
        },
        {
            "id": "AF-ONE",
            "capability_class": "A",
            "execution": {"worker_template": "t/one.md"},
        },
    ],
    "flow_steps": [
        {"id": "FS-1", "skill": "s1", "reusable_by_flows": ["AF-ONE", "AF-TWO"],
         "v_loop": {"evidence_refs": ["EV-1"]}},
        {"id": "FS-2", "skill": "s2"},
    ],
    "workflows": [
        {
            "id": "WF-A", "slug": "wf-a", "type": "workflow", "final_intent_gate": "gate",
            "reusable_as_component": True,
            "allowed_dynamic_operations": ["add", "skip"],
            "enforcement_queue": ["q1", "q2"],
            "composition_tree": [
                {"kind": "flow", "ref": "AF-ONE", "label": "L", "optional": True,
                 "condition": "ui", "children": [{"kind": "step", "ref": "FS-1"}, {"kind": "noref"}]},
            ],
        },
        {
            "id": "WF-B", "slug": "wf-b", "type": "workflow", "final_intent_gate": "g2",
            "composition_tree": [],
        },
    ],
}


class RenderHelpersTest(unittest.TestCase):
    def test_composition_refs_nested_with_modifiers(self):
        lines = g.composition_refs(CATALOG["workflows"][0]["composition_tree"])
        self.assertEqual(lines, [
            "- flow: `AF-ONE` (L) optional when ui",
            "  - step: `FS-1`",
            "  - noref: ``",
        ])

    def test_legacy_table_covers_18_flows_and_missing_entities(self):
        lines = g.render_legacy_flow_table(CATALOG)
        self.assertEqual(len(lines), 2 + 18)
        self.assertEqual(lines[2], "| FLOW 1 | BOOTSTRAP | `AF-ONE` |")
        self.assertEqual(lines[3], "| FLOW 2 | ORIENT | `` |")
        bare = g.render_legacy_flow_table({})
        self.assertEqual(bare[2], "| FLOW 1 | BOOTSTRAP | `` |")

    def test_post_exec_sequencing(self):
        lines = g.render_post_exec_sequencing()
        self.assertEqual(lines[0], "## Post-execution sequencing")
        for item in g.POST_EXEC_SEQUENCING_LINES:
            self.assertIn(item, lines)


class RenderContractsTest(unittest.TestCase):
    def setUp(self):
        self.text = g.render_contracts(CATALOG)

    def test_sections_and_rows(self):
        t = self.text
        self.assertTrue(t.endswith("\n"))
        self.assertIn("| `AF-TWO` | B | `t/two.md` | `s2`, `s3` |", t)
        self.assertIn("| `AF-ONE` | A | `t/one.md` |  |", t)
        self.assertIn("| `AF-TWO` | `s2` | `t/s2.md` |", t)
        self.assertLess(t.index("`s2` | `t/s2.md`"), t.index("`s3` | `t/s3.md`"))
        self.assertIn("### `WF-A`", t)
        self.assertIn("- Slug: `wf-b`", t)
        self.assertIn("- (empty)", t)
        self.assertIn("  - step: `FS-1`", t)
        self.assertLess(t.index("`aa` | `AF-ONE`"), t.index("`zz` | `AF-TWO`"))
        self.assertIn("| `FS-1` | `s1` | `AF-ONE`, `AF-TWO` | `EV-1` |", t)
        self.assertIn("| `FS-2` | `s2` |  |  |", t)
        self.assertIn("| `sb:x` | `AF-ONE` |", t)
        self.assertIn("| `gsd-y` | `AF-TWO` |", t)

    def test_no_skill_templates_omits_section(self):
        cat = copy.deepcopy(CATALOG)
        for flow in cat["atomic_flows"]:
            flow["execution"].pop("skill_worker_templates", None)
        cat["migration_map"] = {}
        text = g.render_contracts(cat)
        self.assertNotIn("Skill-Dispatched Worker Templates", text)
        self.assertIn("## Runtime Queue Tokens", text)

    def test_flow_without_execution_templates_is_tolerated(self):
        cat = copy.deepcopy(CATALOG)
        cat["atomic_flows"] = [{"id": "AF-X", "capability_class": "C", "execution": {"worker_template": "w"}}]
        self.assertIn("| `AF-X` | C | `w` |  |", g.render_contracts(cat))


class RenderMatrixTest(unittest.TestCase):
    def test_rows(self):
        text = g.render_matrix(CATALOG)
        self.assertIn(
            "| `WF-A` | `workflow` | true | `flow:AF-ONE`<br>`step:FS-1` | `add`, `skip` |", text
        )
        self.assertIn("| `WF-B` | `workflow` | false |  |  |", text)


class BuildIndexTest(unittest.TestCase):
    def test_index(self):
        idx = g.build_index(CATALOG)
        self.assertEqual(idx["catalog_version"], "9.9.9")
        self.assertEqual(idx["atomic_flow_ids"], ["AF-ONE", "AF-TWO"])
        self.assertEqual(idx["worker_templates"], {"AF-ONE": "t/one.md", "AF-TWO": "t/two.md"})
        self.assertEqual(idx["skill_worker_templates"], {"AF-TWO": {"s2": "t/s2.md", "s3": "t/s3.md"}})
        self.assertEqual(idx["workflow_enforcement_queues"], {"wf-a": ["q1", "q2"]})
        self.assertEqual(idx["step_to_flows"], {"FS-1": ["AF-ONE", "AF-TWO"], "FS-2": []})
        self.assertEqual(idx["runtime_queue_tokens"], CATALOG["migration_map"]["runtime_queue_tokens"])

    def test_index_without_optional_sections(self):
        cat = {"catalog_version": "1", "atomic_flows": [{"id": "A", "execution": {"worker_template": "w"}}]}
        idx = g.build_index(cat)
        self.assertEqual(idx["step_to_flows"], {})
        self.assertEqual(idx["workflow_enforcement_queues"], {})
        self.assertEqual(idx["runtime_queue_tokens"], {})


class TempRepoCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "docs").mkdir()
        self.paths = {
            "CATALOG_PATH": self.root / "docs" / "apo-catalog.json",
            "CONTRACTS_PATH": self.root / "docs" / "composable-flows-contracts.md",
            "MATRIX_PATH": self.root / "docs" / "workflow-composition-matrix.md",
            "INDEX_PATH": self.root / "docs" / "generated" / "atomic-flow-index.json",
        }
        self.paths["CATALOG_PATH"].write_text(json.dumps(CATALOG))
        patches = [mock.patch.object(g, k, v) for k, v in self.paths.items()]
        patches.append(mock.patch.object(g, "REPO_ROOT", self.root))
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sys, "argv", ["generate-apo-artifacts.py", *args]), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = g.main()
        return rc, out.getvalue(), err.getvalue()


class WriteAndCheckTest(TempRepoCase):
    def test_load_catalog(self):
        self.assertEqual(g.load_catalog()["catalog_version"], "9.9.9")

    def test_write_then_check_roundtrip(self):
        g.write_outputs(CATALOG)
        self.assertEqual(self.paths["CONTRACTS_PATH"].read_text(), g.render_contracts(CATALOG))
        self.assertEqual(self.paths["MATRIX_PATH"].read_text(), g.render_matrix(CATALOG))
        index = json.loads(self.paths["INDEX_PATH"].read_text())
        self.assertEqual(index["atomic_flow_ids"], ["AF-ONE", "AF-TWO"])
        self.assertTrue(self.paths["INDEX_PATH"].read_text().endswith("}\n"))
        self.assertTrue(g.check_outputs(CATALOG))

    def test_check_reports_missing_and_stale_files(self):
        g.write_outputs(CATALOG)
        self.paths["MATRIX_PATH"].write_text("hand edited\n")
        self.paths["INDEX_PATH"].unlink()
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertFalse(g.check_outputs(CATALOG))
        self.assertIn("STALE: docs/workflow-composition-matrix.md", err.getvalue())
        self.assertIn("STALE: docs/generated/atomic-flow-index.json", err.getvalue())
        self.assertNotIn("composable-flows-contracts", err.getvalue())


class MainTest(TempRepoCase):
    def test_write_mode(self):
        rc, out, err = self.run_main()
        self.assertEqual(rc, 0)
        self.assertTrue(self.paths["CONTRACTS_PATH"].exists())
        self.assertTrue(self.paths["INDEX_PATH"].exists())

    def test_check_mode_clean_and_stale(self):
        self.run_main()
        rc, _, err = self.run_main("--check")
        self.assertEqual(rc, 0)
        self.assertEqual(err, "")
        self.paths["CONTRACTS_PATH"].write_text("drift")
        rc, _, err = self.run_main("--check")
        self.assertEqual(rc, 1)
        self.assertIn("STALE: docs/composable-flows-contracts.md", err)
        self.assertEqual(self.paths["CONTRACTS_PATH"].read_text(), "drift")  # check never rewrites


class EntrypointTest(unittest.TestCase):
    def test_script_run_as_main_check_mode_is_read_only(self):
        script = str(REPO_ROOT / "scripts" / "generate-apo-artifacts.py")
        with mock.patch.object(sys, "argv", ["x", "--check"]):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(script, run_name="__main__")
        self.assertEqual(cm.exception.code, 0)


class RealRepoTest(unittest.TestCase):
    def test_committed_outputs_are_current(self):
        # Read-only: same invariant as `generate-apo-artifacts.py --check` in CI.
        self.assertTrue(g.check_outputs(g.load_catalog()))


if __name__ == "__main__":
    unittest.main()

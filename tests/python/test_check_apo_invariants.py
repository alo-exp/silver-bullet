"""Unit tests for scripts/check-apo-invariants.py."""
from __future__ import annotations

import contextlib
import copy
import io
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from sbtest import REPO_ROOT, load_module

c = load_module("scripts/check-apo-invariants.py")
REAL = c.load_catalog()


def fresh():
    return copy.deepcopy(REAL)


def by_label(results):
    return {label: status for status, label, _ in results}


def details(results):
    return {label: detail for _, label, detail in results}


class HelpersTest(unittest.TestCase):
    def test_check_tuple(self):
        self.assertEqual(c.check("n", True), ("PASS", "n", ""))
        self.assertEqual(c.check("n", False, "why"), ("FAIL", "n", "why"))

    def test_walk_nodes_flattens_and_handles_none(self):
        tree = [{"id": 1, "children": [{"id": 2, "children": None}, {"id": 3}]}, {"id": 4}]
        self.assertEqual([n["id"] for n in c.walk_nodes(tree)], [1, 2, 3, 4])
        self.assertEqual(c.walk_nodes(None), [])

    def test_known_entities_skips_missing_ids(self):
        cat = {"processes": [{"id": "P"}, {}], "workflows": [{"id": "W"}], "artifacts": [{"id": None}]}
        self.assertEqual(c.known_entities(cat), {"P", "W"})


class RealCatalogTest(unittest.TestCase):
    """Every named check passes on the committed catalog (read-only)."""

    def test_all_checks_pass_on_repository(self):
        for name, fn in c.CHECKS.items():
            with self.subTest(check=name):
                results = fn(fresh())
                self.assertTrue(results)
                failing = [r for r in results if r[0] != "PASS"]
                self.assertEqual(failing, [])


class DerivedViewsTest(unittest.TestCase):
    def _run(self, generator_body, index_obj):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            gen = d / "gen.py"
            gen.write_text(generator_body)
            idx = d / "index.json"
            idx.write_text(index_obj)
            with mock.patch.object(c, "GENERATOR", gen), mock.patch.object(c, "INDEX_PATH", idx):
                return c.derived_views(fresh())

    def test_stale_generator_and_wrong_index_fail(self):
        res = self._run(
            "import sys\nprint('STALE: x', file=sys.stderr)\nsys.exit(1)\n",
            '{"source_of_truth": "other", "catalog_version": "0"}',
        )
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertIn("STALE: x", details(res)["generated views are fresh"])

    def test_fresh_generator_and_matching_index_pass(self):
        idx = '{"source_of_truth": "docs/apo-catalog.json", "catalog_version": %s}' % (
            __import__("json").dumps(REAL["catalog_version"]))
        res = self._run("import sys\nsys.exit(0)\n", idx)
        self.assertEqual(set(by_label(res).values()), {"PASS"})


class WorkerTemplateParityTest(unittest.TestCase):
    def _res(self, source_names, plugin_names, catalog):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            src, plug = d / "src", d / "plug"
            src.mkdir()
            plug.mkdir()
            for n in source_names:
                (src / n).write_text("x")
            for n in plugin_names:
                (plug / n).write_text("x")
            with mock.patch.object(c, "WORKERS_DIR", src), mock.patch.object(c, "PLUGIN_WORKERS_DIR", plug):
                return c.worker_template_parity(catalog)

    def test_pass_with_composer_only_and_skill_templates(self):
        cat = {"atomic_flows": [
            {"execution": {"worker_template": "t/A.md", "skill_worker_templates": {"s": "t/B.md"}}},
            {"execution": {"worker_template": "t/C.md"}},
        ]}
        names = ["A.md", "B.md", "C.md", "NEW-WORKFLOW.md"]
        self.assertEqual(set(by_label(self._res(names, names, cat)).values()), {"PASS"})

    def test_missing_extra_and_mirror_drift_fail(self):
        cat = {"atomic_flows": [{"execution": {"worker_template": "t/A.md"}}]}
        res = self._res(["B.md"], [], cat)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        d = details(res)
        self.assertIn("missing=['A.md']", d["one source worker template per atomic flow"])
        self.assertIn("extra=['B.md']", d["one source worker template per atomic flow"])
        self.assertIn("missing=['B.md']", d["plugin worker mirror matches source"])


class TripleAlignmentTest(unittest.TestCase):
    def _res(self, guard, state, catalog):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "hooks" / "lib").mkdir(parents=True)
            (d / "hooks" / "workflow-chain-guard.sh").write_text(guard)
            (d / "hooks" / "lib" / "orchestrator-state.sh").write_text(state)
            with mock.patch.object(c, "REPO_ROOT", d):
                return c.triple_alignment(catalog)

    def test_pass(self):
        guard = "silver-feature silver-ui silver-devops silver-bugfix silver-fast silver-release runtime_queue_tokens catalog_entity"
        state = "FLOW-QUALITY-GATE silver-review-request silver-completion-audit"
        cat = {"migration_map": {"runtime_queue_tokens": {"t": "x"}},
               "workflows": [{"id": "W", "enforcement_queue": ["t"]}, {"id": "W2"}]}
        self.assertEqual(set(by_label(self._res(guard, state, cat)).values()), {"PASS"})

    def test_all_fail(self):
        cat = {"migration_map": {"runtime_queue_tokens": {}},
               "workflows": [{"id": "W", "enforcement_queue": ["nope"]}]}
        res = self._res("", "", cat)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertEqual(details(res)["all composer queue tokens map to catalog entities"], "W:nope")


def run_fail(fn, mutate):
    cat = fresh()
    mutate(cat)
    return fn(cat)


class CatalogMutationTest(unittest.TestCase):
    def test_step_vloop_rollup_failures(self):
        def mutate(cat):
            cat["atomic_flows"][0]["execution"]["join_condition"] = "nothing"
            cat["v_loop_rollups"] = []
        res = run_fail(c.step_vloop_runtime_rollup, mutate)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertEqual(details(res)["atomic joins require step V-loop rollup"], REAL["atomic_flows"][0]["id"])

    def test_step_vloop_rollup_bad_dispatch_shape(self):
        def mutate(cat):
            cat["atomic_flows"][0]["execution"]["dispatch_record_shape"] = "nope"
        res = run_fail(c.step_vloop_runtime_rollup, mutate)
        self.assertEqual(by_label(res)["atomic joins require step V-loop rollup"], "FAIL")

    def test_parallel_scheduling_failures(self):
        def mutate(cat):
            for f in cat["atomic_flows"]:
                f["execution"]["parallelizable"] = False
            cat["atomic_flows"][0]["execution"]["mutation_scopes"] = []
            cat["dynamic_rules"] = []
        res = run_fail(c.parallel_scheduling_safety, mutate)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})

    def test_parallel_requires_a_serialized_atom(self):
        def mutate(cat):
            for f in cat["atomic_flows"]:
                f["execution"]["parallelizable"] = True
        res = run_fail(c.parallel_scheduling_safety, mutate)
        self.assertEqual(by_label(res)["catalog has parallelizable and serialized atoms"], "FAIL")

    def test_dynamic_composition_failures(self):
        def mutate(cat):
            cat["dynamic_rules"] = [r for r in cat["dynamic_rules"] if r["operation"] != "loop"]
            cat["composition_logs"] = [
                {"id": "L1", "operations": [{"catalog_rule_ref": "R", "rationale": ""}]},
                {"id": "L2", "operations": [{"catalog_rule_ref": "", "rationale": "x"}]},
                {"id": "L3", "operations": [{"catalog_rule_ref": "R", "rationale": "x"}]},
                {"id": "L4"},
            ]
        res = run_fail(c.dynamic_composition_audit, mutate)
        d = details(res)
        self.assertEqual(by_label(res)["dynamic rules cover prune insert substitute parallelize loop"], "FAIL")
        self.assertEqual(d["dynamic rules cover prune insert substitute parallelize loop"], "loop")
        self.assertEqual(d["composition log operations require rule refs"], "L1, L2")

    def test_nonredundancy_failures(self):
        def mutate(cat):
            cat["atomic_flows"][1]["capability_class"] = cat["atomic_flows"][0]["capability_class"]
            cat["workflows"][1]["composition_tree"] = copy.deepcopy(cat["workflows"][0]["composition_tree"])
        res = run_fail(c.nonredundancy, mutate)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertIn(REAL["atomic_flows"][0]["capability_class"], details(res)["atomic-flow capability classes are unique"])

    def test_canonical_alias_mapping_failures(self):
        def mutate(cat):
            cat["migration_map"]["skill_to_entity"].pop(next(iter(cat["migration_map"]["skill_to_entity"])))
            cat["migration_map"]["legacy_flows"]["FLOW X"] = "AF-NOPE"
        res = run_fail(c.canonical_alias_mapping, mutate)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertIn("legacy_flows:FLOW X->AF-NOPE", details(res)["alias maps resolve to known catalog entities"])

    def test_canonical_alias_mapping_missing_group_is_tolerated(self):
        def mutate(cat):
            cat["migration_map"].pop("gsd_alias_to_entity", None)
        res = run_fail(c.canonical_alias_mapping, mutate)
        self.assertEqual(by_label(res)["alias maps resolve to known catalog entities"], "PASS")

    def test_hierarchy_integrity_failures(self):
        def mutate(cat):
            cat["flow_steps"][0]["id"] = cat["atomic_flows"][0]["id"]
            cat["nesting"] = {}
        res = run_fail(c.hierarchy_integrity, mutate)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertIn("atomic_flow,flow_step", details(res)["each catalog entity occupies one hierarchy level"])

    def test_skill_hierarchy_classification_failures(self):
        def mutate(cat):
            cat["flow_steps"][0]["classification"] = "bogus"
            cat["flow_steps"][1]["hierarchy_level"] = "atomic_flow"
        res = run_fail(c.skill_hierarchy_classification, mutate)
        self.assertEqual(details(res)["all flow steps have valid hierarchy classifications"],
                         f"{REAL['flow_steps'][0]['id']}, {REAL['flow_steps'][1]['id']}")

    def test_composer_purity_failures(self):
        def mutate(cat):
            cat["workflows"][0]["composition_tree"] = [
                {"kind": "atomic_flow", "ref": "AF-NOPE"},
                {"kind": "workflow", "ref": "WF-NOPE"},
                {"kind": "atomic_flow", "ref": cat["atomic_flows"][0]["id"]},
                {"kind": "workflow", "ref": cat["workflows"][0]["id"]},
                {"kind": "other", "ref": "zzz"},
            ]
        res = run_fail(c.composer_purity, mutate)
        wid = REAL["workflows"][0]["id"]
        self.assertEqual(details(res)["composer trees reference only catalog flows/workflows"],
                         f"{wid}:AF-NOPE, {wid}:WF-NOPE")

    def test_opted_in_tool_enforcement_failures(self):
        def mutate(cat):
            cat["tool_policies"][0]["policy_name"] = "other"
            cat["tool_policies"][1]["relevance_rules"] = []
            if len(cat["tool_policies"]) > 2:
                cat["tool_policies"][2]["required_evidence"] = []
            for p in cat["tool_policies"]:
                p["failure_policy"] = "warn"
        res = run_fail(c.opted_in_tool_enforcement, mutate)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})
        self.assertIn(REAL["tool_policies"][0]["id"], details(res)["tool policies use once-opted-in semantics"])

    def test_user_intent_coverage_failures(self):
        def mutate(cat):
            cat["intent_ledgers"] = [
                {"id": "I1", "material_claims": [], "mapped_entities": [], "final_gate_result": "x"},
                {"id": "I2", "material_claims": ["c"], "mapped_entities": ["NOPE"], "final_gate_result": "x"},
                {"id": "I3", "material_claims": ["c"], "mapped_entities": [], "final_gate_result": ""},
                {"id": "I4", "material_claims": ["c"], "final_gate_result": "x"},
            ]
        res = run_fail(c.user_intent_coverage, mutate)
        self.assertEqual(details(res)["intent ledgers cover material claims"], "I1, I2, I3")
        self.assertEqual(by_label(res)["completion and release consume intent ledger"], "FAIL")

    def test_router_coverage_missing_router(self):
        def mutate(cat):
            cat["workflows"] = [w for w in cat["workflows"] if w["id"] != "WF-SILVER-ROUTER"]
        res = run_fail(c.router_coverage, mutate)
        s = by_label(res)
        self.assertEqual(s["router workflow exists"], "FAIL")
        self.assertEqual(s["router starts with AF-ROUTE"], "FAIL")

    def test_router_coverage_wrong_first_ref_and_missing_routes(self):
        def mutate(cat):
            router = next(w for w in cat["workflows"] if w["id"] == "WF-SILVER-ROUTER")
            router["composition_tree"][0]["ref"] = "AF-OTHER"
            cat["workflows"] = [w for w in cat["workflows"] if w["id"] != "WF-SILVER-FAST"]
        res = run_fail(c.router_coverage, mutate)
        s = by_label(res)
        self.assertEqual(s["router workflow exists"], "PASS")
        self.assertEqual(s["router starts with AF-ROUTE"], "FAIL")
        self.assertEqual(details(res)["default public routes are catalog workflows"], "WF-SILVER-FAST")


class SiteDocFreshnessTest(unittest.TestCase):
    def _tree(self, d, silver="APO catalog docs/apo-catalog.json", template=None, site="Atomic Flow APO"):
        d = Path(d)
        (d / "templates").mkdir()
        (d / "site" / "help" / "workflows").mkdir(parents=True)
        (d / "docs").mkdir()
        (d / "silver-bullet.md").write_text(silver)
        (d / "templates" / "silver-bullet.md.base").write_text(
            "APO catalog docs/apo-catalog.json" if template is None else template)
        (d / "site" / "help" / "workflows" / "index.html").write_text(site)
        return d

    def test_clean_tree_passes_and_missing_optional_paths_are_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            root = self._tree(d)
            with mock.patch.object(c, "REPO_ROOT", root):
                res = c.site_doc_freshness({})
        self.assertEqual(set(by_label(res).values()), {"PASS"})

    def test_stale_phrase_and_missing_mentions_fail(self):
        with tempfile.TemporaryDirectory() as d:
            root = self._tree(d, silver="Our 18 Atomic Flows catalog", template="nothing", site="nothing")
            (root / "README.md").write_text("fine text")
            (root / "docs" / "a.md").write_text("The 18-flow catalog")
            with mock.patch.object(c, "REPO_ROOT", root):
                res = c.site_doc_freshness({})
        s = by_label(res)
        self.assertEqual(set(s.values()), {"FAIL"})
        det = details(res)["public docs avoid stale 18-flow atomic-flow count"]
        self.assertIn("silver-bullet.md:18 atomic flows", det)
        self.assertIn("docs/a.md:18-flow catalog", det)
        self.assertNotIn("README.md", det)


class AgentDelegationContractTest(unittest.TestCase):
    def _good(self):
        return {
            "atomic_flows": [{"id": "AF-AGENT-DELEGATE", "execution": {"parallelizable": False}}],
            "workflows": [{"id": "WF-AGENT-DELEGATE-ENTRY"}],
            "artifacts": [{"id": "ART-AGENT-DELEGATE"}],
            "flow_steps": [{"id": i} for i in ("FS-DELEGATE-BRIEF", "FS-DELEGATE-LAUNCH", "FS-DELEGATE-VERIFY")],
            "migration_map": {"skill_to_entity": {
                k: "AF-AGENT-DELEGATE" for k in
                ("silver-agent-worker", "silver-agent-codex", "silver-agent-cursor", "silver-agent-claude")}},
        }

    def _res(self, cat, with_files):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            skills, workers = d / "skills", d / "workers"
            workers.mkdir()
            if with_files:
                (skills / "silver-agent-worker").mkdir(parents=True)
                (skills / "silver-agent-worker" / "SKILL.md").write_text("x")
                (workers / "AGENT-DELEGATE.md").write_text("x")
            with mock.patch.object(c, "SKILLS_DIR", skills), mock.patch.object(c, "WORKERS_DIR", workers):
                return c.agent_delegation_contract(cat)

    def test_all_pass(self):
        res = self._res(self._good(), True)
        self.assertEqual(len(res), 11)
        self.assertEqual(set(by_label(res).values()), {"PASS"})

    def test_all_fail_on_empty_catalog(self):
        cat = {"atomic_flows": []}
        res = self._res(cat, False)
        self.assertEqual(set(by_label(res).values()), {"FAIL"})

    def test_parallelizable_delegate_flow_fails(self):
        cat = self._good()
        cat["atomic_flows"][0]["execution"]["parallelizable"] = True
        self.assertEqual(by_label(self._res(cat, True))["delegation AF not parallelizable"], "FAIL")

    def test_delegate_flow_without_execution_fails(self):
        cat = self._good()
        cat["atomic_flows"][0].pop("execution")
        self.assertEqual(by_label(self._res(cat, True))["delegation AF not parallelizable"], "FAIL")


class MainTest(unittest.TestCase):
    def _run(self, check_name, results):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["check-apo-invariants.py", check_name]), \
                mock.patch.dict(c.CHECKS, {check_name: lambda cat: results}), \
                contextlib.redirect_stdout(out):
            rc = c.main()
        return rc, out.getvalue()

    def test_all_pass_exit_zero_and_detail_rendering(self):
        rc, out = self._run("router-coverage", [("PASS", "a", ""), ("PASS", "b", "note")])
        self.assertEqual(rc, 0)
        self.assertEqual(out, "PASS\ta\nPASS\tb\tnote\n")

    def test_any_failure_exit_one(self):
        rc, out = self._run("router-coverage", [("PASS", "a", ""), ("FAIL", "b", "bad")])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL\tb\tbad", out)

    def test_unknown_check_is_rejected_by_argparse(self):
        with mock.patch.object(sys, "argv", ["x", "nope"]), \
                contextlib.redirect_stderr(io.StringIO()) as err:
            with self.assertRaises(SystemExit) as cm:
                c.main()
        self.assertEqual(cm.exception.code, 2)
        self.assertIn("invalid choice", err.getvalue())

    def test_script_entrypoint(self):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["x", "router-coverage"]), contextlib.redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                runpy.run_path(str(REPO_ROOT / "scripts" / "check-apo-invariants.py"), run_name="__main__")
        self.assertEqual(cm.exception.code, 0)
        self.assertIn("PASS\trouter workflow exists", out.getvalue())


if __name__ == "__main__":
    unittest.main()

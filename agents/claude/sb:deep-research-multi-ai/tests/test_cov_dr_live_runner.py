"""dr_live_runner unit tests with the AI dispatch stubbed (no CLIs, no network)."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import dr_live_runner as drl  # noqa: E402
from multi_ai_core import PoolSelection  # noqa: E402

TWO_AGENTS = ["composer-2.5", "ocg-kimi-k2.7-code"]


def selection(**kw) -> PoolSelection:
    return PoolSelection(ocg_pool=kw.pop("ocg_pool", "lite"), cursor_pool=kw.pop("cursor_pool", "default"),
                         include_only=kw.pop("include_only", list(TWO_AGENTS)), **kw)


def worker(logical, status="completed", envelope=True, phase="DR-RETRIEVE", wid="w", payload=None):
    env = None
    if envelope:
        env = {"phase_id": phase, "work_item_id": wid, "logical_model_id": logical,
               "model_family_id": f"fam-{logical}", "payload": payload if payload is not None else {}}
    return SimpleNamespace(logical_model_id=logical, status=status, backend="cursor", error=None if status == "completed" else "boom",
                           effective_model_id=f"eff-{logical}", envelope=env)


class SmallHelperTests(unittest.TestCase):
    def test_deterministic_work_item_id(self) -> None:
        a = drl.deterministic_work_item_id("run-1", "DR-RETRIEVE")
        self.assertRegex(a, r"^work-[0-9a-f]{32}$")
        self.assertEqual(a, drl.deterministic_work_item_id("run-1", "DR-RETRIEVE"))
        self.assertNotEqual(a, drl.deterministic_work_item_id("run-1", "DR-CRITIQUE"))
        self.assertNotEqual(a, drl.deterministic_work_item_id("run-2", "DR-RETRIEVE"))

    def test_research_brief(self) -> None:
        brief = drl.research_brief("my topic", "solution-compare")
        self.assertTrue(brief.startswith("Research topic: my topic\nResearch type: solution-compare\n"))
        self.assertIn("Primary (APO)", brief)

    def test_write_scope_creates_root_and_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "new" / "root"
            drl.write_scope(root, "topic `x`")
            text = (root / "scope.md").read_text(encoding="utf-8")
            self.assertTrue(text.startswith("# Landscape scope"))
            self.assertIn("Research topic: `topic `x``", text)

    def test_write_need_profile_from_real_pack(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            drl.write_need_profile(Path(tmp))
            need = json.loads((Path(tmp) / "need_profile.json").read_text(encoding="utf-8"))
        self.assertEqual(need["category_pack_id"], "agentic-sdlc-process-orchestrator")
        self.assertTrue(need["interview_complete"])
        self.assertLessEqual(len(need["hard_vetoes"]), 8)
        self.assertGreater(len(need["must_research"]), 0)
        self.assertEqual(need["persona_id"], "startup")

    def test_write_need_profile_pack_without_display_name(self) -> None:
        with mock.patch.object(drl, "load_category_pack", return_value={}):
            with tempfile.TemporaryDirectory() as tmp:
                drl.write_need_profile(Path(tmp))
                need = json.loads((Path(tmp) / "need_profile.json").read_text(encoding="utf-8"))
        self.assertEqual(need["category"], "Agentic SDLC Process Orchestrators")
        self.assertEqual(need["hard_vetoes"], [])
        self.assertEqual(need["must_research"], [])


class BuildPhaseQueryTests(unittest.TestCase):
    def test_variants(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            brief = drl.research_brief("q", "default")
            self.assertEqual(drl.build_phase_query(root, "q", "default"), brief)
            (root / "need_profile.json").write_text("{not json", encoding="utf-8")
            self.assertEqual(drl.build_phase_query(root, "q", "default"), brief)
            (root / "need_profile.json").write_text(json.dumps({"no": "pack"}), encoding="utf-8")
            self.assertEqual(drl.build_phase_query(root, "q", "default"), brief)
            (root / "need_profile.json").write_text(json.dumps({"category_pack_id": "agentic-sdlc-process-orchestrator"}), encoding="utf-8")
            with_pack = drl.build_phase_query(root, "q", "default")
            self.assertTrue(with_pack.startswith(brief + "\n\n[CATEGORY_PACK]\n## Category market contract"))
            with mock.patch.object(Path, "read_text", side_effect=OSError("denied")):
                self.assertEqual(drl.build_phase_query(root, "q", "default"), brief)


class RunManifestTests(unittest.TestCase):
    def manifest(self, **kw):
        base = dict(run_id="run-x", query="q", mode="deep", research_type="default", report_dir="/r",
                    selection=selection(), parallel_phases=["DR-RETRIEVE", "DR-TRIANGULATE"], started_at="t0")
        base.update(kw)
        return drl.build_run_manifest(**base)

    def test_generated_refs_when_none_supplied(self) -> None:
        m = self.manifest()
        wid = drl.deterministic_work_item_id("run-x", "DR-RETRIEVE")
        self.assertEqual(m["multi_ai"]["phases"][0], {"phase_id": "DR-RETRIEVE", "work_item_id": wid, "parallel": True})
        self.assertEqual(len(m["multi_ai"]["work_item_refs"]), 2)
        self.assertEqual(m["multi_ai"]["work_item_refs"][0]["manifest_path"], f"work-items/{wid}/multi-ai-work-item-manifest-v1.json")
        self.assertEqual(m["multi_ai"]["work_item_refs"][0]["manifest_sha256"], "0" * 64)
        self.assertTrue(m["multi_ai"]["budget"]["usage_metered"])
        self.assertIsNone(m["finished_at"])
        pool = m["multi_ai"]["pool_config"]
        self.assertEqual({p["logical_model_id"] for p in pool["resolved_pool"]}, set(TWO_AGENTS))
        self.assertEqual(pool["include_only"], TWO_AGENTS)
        self.assertEqual(m["schema_id"], "deep-research-run-manifest-v4")

    def test_supplied_refs_are_kept(self) -> None:
        refs = [{"work_item_id": "given", "manifest_path": "p", "manifest_sha256": "s"}]
        m = self.manifest(work_item_refs=refs, dispatch_mode="dry", finished_at="t1", budget_stop_reason="cap")
        self.assertEqual(m["multi_ai"]["work_item_refs"], refs)
        self.assertEqual(len(m["multi_ai"]["phases"]), 2)
        self.assertFalse(m["multi_ai"]["budget"]["usage_metered"])
        self.assertEqual(m["multi_ai"]["budget"]["budget_stop_reason"], "cap")
        self.assertEqual(m["finished_at"], "t1")
        self.assertEqual(m["multi_ai"]["pool_config"]["dispatch_mode"], "dry")


class ResultIndexAndCompletenessTests(unittest.TestCase):
    def test_result_index_statuses(self) -> None:
        resolved = [{"logical_model_id": "b"}, {"logical_model_id": "a"}]
        phase_results = [
            {"work_item_id": "w1", "workers": [{"logical_model_id": "a", "status": "completed"}, {"logical_model_id": "b"}]},
            {"work_item_id": "w2"},
        ]
        idx = drl.build_multi_phase_result_index("run-1", {"generation": 3, "head_hash": "H"}, resolved,
                                                 [("P1", "w1"), ("P2", "w2")], phase_results)
        self.assertEqual(idx["ledger_generation"], 3)
        self.assertEqual(idx["ledger_head_hash"], "H")
        self.assertEqual([(e["phase_id"], e["logical_model_id"], e["status"]) for e in idx["entries"]],
                         [("P1", "a", "completed"), ("P1", "b", "pending"), ("P2", "a", "pending"), ("P2", "b", "pending")])
        empty = drl.build_multi_phase_result_index("run-1", {}, [], [], [])
        self.assertEqual(empty["entries"], [])
        self.assertEqual(empty["ledger_generation"], 0)
        self.assertEqual(len(empty["ledger_head_hash"]), 64)

    def test_validate_pool_completeness_edge_cases(self) -> None:
        resolved = [{"logical_model_id": "a"}, {"logical_model_id": "b"}]
        ok, errors = drl.validate_pool_completeness(resolved, [])
        self.assertTrue(ok)
        self.assertEqual(errors, [])
        # a failed worker, a worker without envelope and a phase without workers all count as missing
        phases = [
            {"phase_id": "P1", "workers": [{"logical_model_id": "a", "has_envelope": True, "status": "failed"},
                                           {"logical_model_id": "b", "has_envelope": False}]},
            {"workers": None},
            {"phase_id": "P3", "workers": [{"logical_model_id": "a", "has_envelope": True},
                                           {"logical_model_id": "b", "has_envelope": True, "status": "completed"}]},
        ]
        ok, errors = drl.validate_pool_completeness(resolved, phases)
        self.assertFalse(ok)
        self.assertEqual(errors, ["phase P1: missing envelopes for ['a', 'b']", "phase ?: missing envelopes for ['a', 'b']"])


class RunDrLiveTests(unittest.TestCase):
    def setUp(self) -> None:
        env = mock.patch.dict(os.environ, {}, clear=False)
        env.start()
        self.addCleanup(env.stop)
        os.environ.pop("SB_MULTI_AI_STUB", None)

    def run_live(self, root: Path, dispatch, **kw):
        sel = kw.pop("selection", selection())
        mat = mock.Mock(return_value={"materialized": True})
        syn = mock.Mock(return_value={"synthesized": True})
        with mock.patch.object(drl, "dispatch_phase_parallel", dispatch), \
                mock.patch.object(drl, "materialize_solution_artifacts", mat), \
                mock.patch.object(drl, "synthesize_landscape", syn), \
                mock.patch.object(drl, "detect_host", return_value="cursor"):
            result = drl.run_dr_live(query="the query", output_root=root, selection=sel, **kw)
        return result, mat, syn

    def test_stub_mode_short_circuits(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "out"
            for flag in ("1", "true", "yes"):
                with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": flag}):
                    result = drl.run_dr_live(query="q", output_root=root, selection=selection(), parallel_phases=["DR-RETRIEVE"])
                self.assertEqual(result["error_code"], "DR_MULTI_AI_LIVE_NOT_READY")
                self.assertFalse(result["ok"])
            self.assertFalse(root.exists())

    def test_full_run_writes_artifacts_and_materializes_landscape(self) -> None:
        calls = []

        def dispatch(**kw):
            calls.append(kw)
            payload = {"claim_candidates": [{"text": f"claim from {kw['phase_id']}"}]}
            return [worker(lid["logical_model_id"], phase=kw["phase_id"], wid=kw["work_item_id"], payload=payload)
                    for lid in kw["resolved_pool"]]

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "out"
            result, mat, syn = self.run_live(root, dispatch, parallel_phases=["DR-RETRIEVE", "DR-TRIANGULATE"],
                                             research_type="solution-landscape", timeout_sec=7)
            self.assertTrue(result["ok"])
            self.assertFalse(result["partial"])
            self.assertEqual(result["envelopes_count"], 4)
            self.assertEqual(result["materialize"], {"materialized": True})
            self.assertEqual(result["landscape_synthesis"], {"synthesized": True})
            self.assertEqual(result["host"], "cursor")
            mat.assert_called_once()
            self.assertEqual(len(mat.call_args.kwargs["envelopes"]), 4)
            syn.assert_called_once_with(root, force=True)
            # first phase has no context, second carries the previous payloads (truncated to 2000 chars)
            self.assertEqual(calls[0]["context"], "")
            self.assertIn("claim from DR-RETRIEVE", calls[1]["context"])
            self.assertLessEqual(len(calls[1]["context"]), 2000)
            self.assertEqual(calls[0]["timeout_sec"], 7)
            self.assertEqual(calls[0]["concurrency"], 2)
            self.assertEqual(calls[0]["ocg_pool"], "lite")
            self.assertIn("[CATEGORY_PACK]", calls[0]["query"])
            for rel in ("scope.md", "need_profile.json", "result-index.json", "contributions/all-envelopes.json",
                        "consolidated/consolidation.json", "run_manifest.json"):
                self.assertTrue((root / rel).is_file(), rel)
            manifest = json.loads((root / "run_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["run_id"], result["run_id"])
            self.assertIsNone(manifest["multi_ai"]["budget"]["budget_stop_reason"])
            index_bytes = (root / "result-index.json").read_bytes()
            import hashlib
            self.assertEqual(manifest["multi_ai"]["result_index_sha256"], hashlib.sha256(index_bytes).hexdigest())
            consolidation = json.loads((root / "consolidated" / "consolidation.json").read_text(encoding="utf-8"))
            self.assertEqual(len(consolidation["content_hash"]), 64)
            self.assertEqual(len(json.loads((root / "contributions" / "all-envelopes.json").read_text(encoding="utf-8"))), 4)

    def test_partial_run_default_type_skips_materialization_and_maps_ocg_pool(self) -> None:
        seen = []

        def dispatch(**kw):
            seen.append(kw)
            return [worker(i["logical_model_id"], phase=kw["phase_id"], wid=kw["work_item_id"]) for i in kw["resolved_pool"]]

        with tempfile.TemporaryDirectory() as tmp:
            sel = selection(ocg_pool="none", include_only=["composer-2.5"])
            result, mat, syn = self.run_live(Path(tmp) / "o", dispatch, selection=sel,
                                             parallel_phases=["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"],
                                             max_phases=1, research_type="default")
            self.assertTrue(result["ok"])
            self.assertTrue(result["partial"])
            self.assertEqual(result["phases_run"], ["DR-RETRIEVE"])
            self.assertEqual(len(seen), 1)
            self.assertEqual(seen[0]["ocg_pool"], "lite")  # "none" is not a dispatchable pool
            self.assertIsNone(result["materialize"])
            self.assertIsNone(result["landscape_synthesis"])
            mat.assert_not_called()
            syn.assert_not_called()

    def test_regular_ocg_pool_is_passed_through(self) -> None:
        seen = []

        def dispatch(**kw):
            seen.append(kw["ocg_pool"])
            return [worker(i["logical_model_id"], phase=kw["phase_id"], wid=kw["work_item_id"]) for i in kw["resolved_pool"]]

        with tempfile.TemporaryDirectory() as tmp:
            sel = PoolSelection(ocg_pool="regular", cursor_pool="none")
            self.run_live(Path(tmp) / "o", dispatch, selection=sel, parallel_phases=["DR-RETRIEVE"], research_type="default", max_phases=1)
        self.assertEqual(seen, ["regular"])

    def test_pool_incomplete_is_a_hard_failure_before_consolidation(self) -> None:
        def dispatch(**kw):
            ws = [worker(i["logical_model_id"], phase=kw["phase_id"], wid=kw["work_item_id"]) for i in kw["resolved_pool"]]
            ws[0] = worker(ws[0].logical_model_id, status="failed", envelope=False)
            return ws

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "o"
            result, mat, _ = self.run_live(root, dispatch, parallel_phases=["DR-RETRIEVE"], research_type="solution-landscape")
            self.assertFalse(result["ok"])
            self.assertEqual(result["error_code"], "POOL_INCOMPLETE")
            self.assertEqual(result["resolved_pool_size"], 2)
            self.assertEqual(len(result["pool_errors"]), 1)
            self.assertEqual(result["phase_results"][0]["workers"][0]["authoritative"], False)
            self.assertEqual(result["phase_results"][0]["workers"][0]["error"], "boom")
            self.assertFalse((root / "run_manifest.json").exists())
            self.assertFalse((root / "result-index.json").exists())
            mat.assert_not_called()

    def test_falsy_envelopes_complete_the_pool_but_yield_not_ok_and_partial_stop_reason(self) -> None:
        def dispatch(**kw):
            ws = [worker(i["logical_model_id"]) for i in kw["resolved_pool"]]
            for w in ws:
                w.envelope = {}  # present (pool complete) but empty (not usable evidence)
            return ws

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "o"
            result, mat, syn = self.run_live(root, dispatch, parallel_phases=["DR-RETRIEVE"], research_type="solution-landscape")
            self.assertFalse(result["ok"])
            self.assertEqual(result["envelopes_count"], 0)
            manifest = json.loads((root / "run_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["multi_ai"]["budget"]["budget_stop_reason"], "PARTIAL_LIVE_NO_ENVELOPES")
            mat.assert_not_called()
            syn.assert_not_called()

    def test_no_phases_requested_runs_all_parallel_phases(self) -> None:
        count = []

        def dispatch(**kw):
            count.append(kw["phase_id"])
            return [worker(i["logical_model_id"], phase=kw["phase_id"], wid=kw["work_item_id"]) for i in kw["resolved_pool"]]

        with tempfile.TemporaryDirectory() as tmp:
            result, _, _ = self.run_live(Path(tmp) / "o", dispatch,
                                         parallel_phases=["DR-RETRIEVE", "DR-CRITIQUE"], research_type="default", max_phases=None)
        self.assertEqual(count, ["DR-RETRIEVE", "DR-CRITIQUE"])
        self.assertFalse(result["partial"])


if __name__ == "__main__":
    unittest.main()

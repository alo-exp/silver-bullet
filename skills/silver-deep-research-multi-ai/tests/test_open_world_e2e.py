"""End to end on a topic with no category pack (stub workers, no AI CLI, no network).

An event-streaming research run must discover its vendors from what the workers return,
package successfully and carry no agentic-SDLC wording (R12-02, R12-22).
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import dr_live_runner as runner  # noqa: E402
from multi_ai_core import PoolSelection  # noqa: E402
from package_solution_outputs import package_solution_outputs  # noqa: E402

MODELS = [("claude-x", "claude"), ("gpt-x", "openai"), ("gemini-x", "gemini")]
APO_WORDS = ("SDLC", "APO", "Silver Bullet", "hook-enforced", "Hook-enforced", "Zuvo", "orchestrat", "3-of-7", "Agentic")


def _payload(phase: str, model: str) -> dict:
    ev = [
        {"claim": "Apache Kafka supports exactly-once semantics and SSO via Confluent.", "source_ref": "https://kafka.apache.org/"},
        {"claim": "Redpanda offers managed hosting and is Kafka API compatible.", "source_ref": "https://redpanda.com/"},
        {"claim": "Apache Pulsar provides tiered storage and geo-replication.", "source_ref": "https://pulsar.apache.org/"},
        {"claim": "Confluent Cloud provides managed hosting, SSO and audit logs.", "source_ref": "https://confluent.io/"},
    ]
    cased = {"claude-x": "Exactly-once semantics", "gpt-x": "exactly once  Semantics", "gemini-x": "EXACTLY-ONCE SEMANTICS"}[model]
    rows = [
        {"vendor": "Apache Kafka", "feature": cased, "supported": True, "source_ref": "https://kafka.apache.org/"},
        {"vendor": "Redpanda", "feature": "Managed hosting", "supported": True, "source_ref": "https://redpanda.com/"},
        {"vendor": "Apache Pulsar", "feature": "Tiered storage", "supported": True, "source_ref": "https://pulsar.apache.org/"},
        {"vendor": "Confluent Cloud", "feature": "SSO", "supported": model != "gpt-x", "source_ref": "https://confluent.io/"},
        {"vendor": "Apache Kafka", "feature": "Managed hosting", "supported": False, "source_ref": "https://kafka.apache.org/"},
        {"vendor": "Redpanda", "feature": cased, "supported": model != "gpt-x", "source_ref": "https://redpanda.com/"},
        {"vendor": "Redpanda", "feature": "SSO", "supported": True, "source_ref": "https://redpanda.com/"},
    ]
    if phase == "DR-RETRIEVE":
        return {"evidence": ev, "matrix_entries": rows}
    if phase == "DR-TRIANGULATE":
        return {"claim_candidates": [{"text": e["claim"], "confidence": 0.8} for e in ev], "matrix_entries": rows}
    return {"critiques": [{"finding": "Pulsar operational complexity is higher than Kafka.", "target": "pulsar"}], "matrix_entries": rows}


def _fake_dispatch(*, phase_id, query, run_id, work_item_id, resolved_pool, output_dir, context, **kw):
    workers = []
    for item in resolved_pool:
        model = item["logical_model_id"]
        env = {"schema_id": "dr-phase-contribution-envelope-v1", "version": "1.0.0", "run_id": run_id,
               "work_item_id": work_item_id, "phase_id": phase_id, "logical_model_id": model,
               "attempt_id": "a-" + model, "model_family_id": item["model_family_id"], "payload": _payload(phase_id, model)}
        workers.append(types.SimpleNamespace(envelope=env, logical_model_id=model, status="completed",
                                             backend="stub", error=None, effective_model_id=model))
    return workers


class OpenWorldEndToEndTests(unittest.TestCase):
    def test_non_apo_topic_discovers_vendors_packages_and_has_no_sdlc_wording(self) -> None:
        pool = [{"logical_model_id": m, "backend": "stub", "model_family_id": f} for m, f in MODELS]
        env = {"SB_SKIP_VENDOR_URL_HEALTH": "1", "SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"}
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, env), \
                mock.patch.object(runner, "resolve_pool", return_value=pool), \
                mock.patch.object(runner, "stub_mode", return_value=False), \
                mock.patch.object(runner, "dispatch_phase_parallel", side_effect=_fake_dispatch):
            out = Path(tmp) / "run"
            out.mkdir()
            (out / "need_profile.json").write_text(json.dumps({
                "category": "Event streaming platforms",
                "must_haves": ["Exactly-once semantics", "Managed hosting", "SSO"]}), encoding="utf-8")
            res = runner.run_dr_live(
                query="Event streaming platforms for a fintech startup", output_root=out,
                selection=PoolSelection(ocg_pool="none", cursor_pool="default"),
                parallel_phases=["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"], research_type="solution-landscape")
            self.assertTrue(res.get("ok"), res)
            self.assertGreaterEqual(res["materialize"]["solutions_count"], 4)
            for slug in ("apache-kafka", "redpanda", "apache-pulsar", "confluent-cloud"):
                feats = json.loads((out / "solutions" / slug / "features.json").read_text(encoding="utf-8"))
                self.assertTrue(feats)
            kafka = json.loads((out / "solutions" / "apache-kafka" / "features.json").read_text(encoding="utf-8"))
            text = json.dumps(kafka)
            self.assertIn("Exactly-once semantics", text)
            # three models, three spellings: one rubric row, voted on together (Redpanda 2 yes / 1 no)
            self.assertEqual(text.lower().count("exactly"), 1, text)
            self.assertNotIn("EXACTLY", text)
            redpanda = json.loads((out / "solutions" / "redpanda" / "features.json").read_text(encoding="utf-8"))
            cells = {f["name"]: f["supported"] for c in redpanda["categories"] for f in c["features"]}
            self.assertIs(cells["Exactly-once semantics"], True)
            pkg = package_solution_outputs(out, skip_xlsx=True)
            self.assertEqual(pkg.get("status"), "ok")
            report = (out / "landscape" / "landscape-report.md").read_text(encoding="utf-8")
            html = (out / "landscape-report.html").read_text(encoding="utf-8")
            for word in ("Apache Kafka", "Redpanda", "Exactly-once semantics"):
                self.assertIn(word, report)
            for word in APO_WORDS:
                self.assertNotIn(word, report, f"{word!r} leaked into a non-APO report")
            self.assertNotIn("Hook-enforced gates", html)
            # models split on Confluent Cloud SSO (gpt-x says no): shown as disputed, not hidden
            disputed = json.loads((out / "landscape" / "disputed-cells.json").read_text(encoding="utf-8"))
            self.assertIn({"vendor": "confluent-cloud", "feature": "SSO", "yes": 2, "no": 1}, disputed)
            self.assertIn("### Disputed matrix cells", report)
            self.assertIn("Confluent Cloud — SSO: 2 yes / 1 no", report)

    def _run_and_package(self, need):
        pool = [{"logical_model_id": m, "backend": "stub", "model_family_id": f} for m, f in MODELS]
        env = {"SB_SKIP_VENDOR_URL_HEALTH": "1", "SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"}
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, env), \
                mock.patch.object(runner, "resolve_pool", return_value=pool), \
                mock.patch.object(runner, "stub_mode", return_value=False), \
                mock.patch.object(runner, "dispatch_phase_parallel", side_effect=_fake_dispatch):
            out = Path(tmp) / "run"
            out.mkdir()
            if need is not None:
                (out / "need_profile.json").write_text(json.dumps(need), encoding="utf-8")
            res = runner.run_dr_live(
                query="Event streaming platforms", output_root=out,
                selection=PoolSelection(ocg_pool="none", cursor_pool="default"),
                parallel_phases=["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"], research_type="solution-landscape")
            pkg = package_solution_outputs(out, skip_xlsx=True)
            profile = json.loads((out / "need_profile.json").read_text(encoding="utf-8"))
            return res, pkg, profile

    def test_a_run_with_no_must_haves_still_packages_with_derived_priorities(self) -> None:
        res, pkg, profile = self._run_and_package(None)  # the runner writes an auto profile
        self.assertTrue(res["ok"])
        self.assertEqual(pkg.get("status"), "ok")
        self.assertTrue(profile["auto_assumed"])
        self.assertEqual(set(profile["weights_override"].values()), {"Critical"})
        self.assertIn("Exactly-once semantics", profile["weights_override"])
        self.assertIn("because no must-have matched", profile["weights_override_derived"])
        self.assertIn("derived_critical_features", res["materialize"])

    def test_user_weights_are_kept_and_unmatched_must_haves_still_fail_the_gate(self) -> None:
        _res, _pkg, kept = self._run_and_package({"category": "x", "weights_override": {"SSO": "Critical"}})
        self.assertEqual(kept["weights_override"], {"SSO": "Critical"})
        self.assertNotIn("weights_override_derived", kept)
        # a must-have no vendor offers is a real content gap, reported by the gate, not papered over
        with self.assertRaisesRegex(ValueError, "lacks must-have 'Quantum teleportation'"):
            self._run_and_package({"category": "x", "must_haves": ["Quantum teleportation"]})


if __name__ == "__main__":
    unittest.main()

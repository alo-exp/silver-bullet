"""Regression and mutant-pinning tests added after review of the coverage package."""

from __future__ import annotations

import json
import os
import subprocess
import unittest
from unittest import mock

from cov_helpers import HermeticCase

import cursor_host_adapter as cha
import live_dispatch as ld
import multi_ai_core as core

DEEP = '{"a":' * 100_000 + "1" + "}" * 100_000


def proc(returncode: int = 0, stdout: str = "", stderr: str = "") -> mock.Mock:
    return mock.Mock(returncode=returncode, stdout=stdout, stderr=stderr)


class RecursionTests(HermeticCase):
    def test_extract_json_payload_survives_deep_nesting(self) -> None:
        out = ld.extract_json_payload(DEEP)
        self.assertEqual(list(out), ["raw_text"])
        self.assertEqual(out["raw_text"], DEEP[:8000])

    def test_extract_json_payload_survives_deep_nesting_inside_prose(self) -> None:
        out = ld.extract_json_payload("answer: " + DEEP + " done")
        self.assertEqual(list(out), ["raw_text"])

    def test_sanitize_phase_context_survives_deep_nesting(self) -> None:
        self.assertEqual(ld.sanitize_phase_context(DEEP), DEEP[:2000])

    def test_parse_cohort_output_survives_deep_nesting(self) -> None:
        self.assertIsNone(ld._parse_ocg_cohort_output(DEEP))
        self.assertIsNone(ld._parse_ocg_cohort_output(f'x {{"schema_id": "ocg-pool-cohort-result-v1", "d": {DEEP}}}'))

    def test_deep_cohort_result_file_falls_back_to_stdout(self) -> None:
        delegate = self.tmp / "delegate.sh"
        delegate.write_text("#!/bin/sh\n")
        stdout = json.dumps({"schema_id": "ocg-pool-cohort-result-v1", "contributions": [
            {"logical_model_id": "ocg-minimax-m3", "status": "completed", "payload": {"s": 1}}]})

        def fake(cmd, **kwargs):  # noqa: ANN001
            from pathlib import Path
            Path(cmd[cmd.index("--cohort-output") + 1]).write_text(DEEP)
            return proc(0, stdout)

        with mock.patch.object(ld, "AGENT_OPENCODE_DELEGATE", delegate), mock.patch.object(ld, "_run_cli", side_effect=fake):
            results = ld.run_ocg_pool_cohort(
                ocg_items=[{"logical_model_id": "ocg-minimax-m3"}], phase_id="p", query="q", run_id="r",
                work_item_id="w", output_dir=self.tmp / "ph", context="", pool="lite")
        self.assertEqual(results[0].envelope["payload"], {"s": 1})


class CursorMutantPins(HermeticCase):
    def test_exact_fallback_sequences(self) -> None:
        with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_ALLOW_FALLBACK": "1"}):
            self.assertEqual(
                ld.cursor_models_to_try("gpt-5.6-sol-medium"),
                ["gpt-5.6-sol-medium", "gpt-5.6-sol-low", "gpt-5.6-sol-none", "gpt-5.5-medium"],
            )
            self.assertEqual(ld.cursor_models_to_try("glm-5.2"), ["glm-5.2-high", "glm-5.2-max"])
        # Fallback disabled (the default): the primary only.
        self.assertEqual(ld.cursor_models_to_try("gpt-5.6-sol-medium"), ["gpt-5.6-sol-medium"])

    def _worker(self, responses: list, logical: str = "composer-2.5"):
        calls: list = []
        queue = list(responses)

        def fake(cmd, **kwargs):  # noqa: ANN001
            calls.append((cmd, kwargs))
            return queue.pop(0)

        with mock.patch.object(ld, "_run_cli", side_effect=fake):
            result = ld.run_cursor_worker(logical_model_id=logical, prompt="P", output_dir=self.subdir("o"), timeout_sec=7)
        return result, calls

    def test_retry_uses_the_same_timeout_and_cwd(self) -> None:
        _, calls = self._worker([proc(1, "", "ECONNRESET"), proc(0, "{}")])
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[1][1]["timeout"], 7)
        self.assertEqual(calls[1][1]["cwd"], calls[0][1]["cwd"])
        self.assertEqual(calls[1][0], calls[0][0])

    def test_network_marker_triggers_the_retry(self) -> None:
        result, calls = self._worker([proc(1, "", "network is unreachable"), proc(0, "{}")])
        self.assertEqual(len(calls), 2)
        self.assertEqual(self.sleeps, [3])
        self.assertEqual(result.status, "completed")

    def test_cas_rejects_when_current_is_behind_expected(self) -> None:
        out = cha.cas_select_authoritative_attempt(1, 2, "a")
        self.assertEqual((out["ok"], out["error_code"], out["current_generation"], out["expected_generation"]),
                         (False, "CAS_GENERATION_CONFLICT", 1, 2))


class RegistryHashPins(HermeticCase):
    def test_aliases_are_part_of_the_hash(self) -> None:
        reg = core.load_registry()
        base = core.registry_sha256(reg)
        self.assertNotEqual(core.registry_sha256(dict(reg, aliases={**reg["aliases"], "new-alias": "composer-2.5"})), base)
        self.assertNotEqual(core.registry_sha256({k: v for k, v in reg.items() if k != "aliases"}), base)
        self.assertNotEqual(core.registry_sha256(dict(reg, logical_to_family={})), base)
        self.assertNotEqual(core.registry_sha256(dict(reg, schema_id="other")), base)


if __name__ == "__main__":
    unittest.main()

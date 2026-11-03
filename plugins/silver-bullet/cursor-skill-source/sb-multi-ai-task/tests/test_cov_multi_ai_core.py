"""Behavioral tests for multi_ai_core: ids, money, registry, host gating, pool resolution."""

from __future__ import annotations

import json
import os
import re
import unittest
from decimal import Decimal
from unittest import mock

from cov_helpers import HermeticCase

import multi_ai_core as core
from json_hash import sha256_json


class IdAndMoneyTests(HermeticCase):
    def test_ids_have_prefix_and_are_unique(self) -> None:
        self.assertRegex(core.new_run_id(), r"^run-[0-9a-f]{32}$")
        self.assertRegex(core.new_work_item_id(), r"^work-[0-9a-f]{32}$")
        self.assertRegex(core.new_attempt_id(), r"^attempt-[0-9a-f-]{36}$")
        self.assertNotEqual(core.new_work_item_id(), core.new_work_item_id())
        self.assertNotEqual(core.new_attempt_id(), core.new_attempt_id())

    def test_utc_now_iso_shape(self) -> None:
        self.assertRegex(core.utc_now_iso(), r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")

    def test_usd_to_micro_usd_rounds_half_up(self) -> None:
        self.assertEqual(core.usd_to_micro_usd("25.00"), 25_000_000)
        self.assertEqual(core.usd_to_micro_usd(Decimal("0.0000005")), 1)
        self.assertEqual(core.usd_to_micro_usd("0.0000004"), 0)
        self.assertEqual(core.usd_to_micro_usd(3), 3_000_000)
        with self.assertRaises(Exception):
            core.usd_to_micro_usd("not-a-number")

    def test_budget_policy_defaults(self) -> None:
        budget = core.BudgetPolicy()
        self.assertEqual(budget.max_cost_micro_usd, 25_000_000)
        self.assertEqual((budget.max_total_tokens, budget.max_agents, budget.concurrency), (2_000_000, 11, 6))
        self.assertFalse(budget.allow_unknown_cost)


class RegistryTests(HermeticCase):
    def test_registry_hash_covers_only_identity_keys(self) -> None:
        reg = core.load_registry()
        base = core.registry_sha256(reg)
        self.assertEqual(base, core.registry_sha256())
        noisy = dict(reg, ocg_lite_pool=["something-else"])
        self.assertEqual(core.registry_sha256(noisy), base)
        changed = dict(reg, version="9.9.9")
        self.assertNotEqual(core.registry_sha256(changed), base)
        partial = {"schema_id": "s", "other": 1}
        self.assertEqual(core.registry_sha256(partial), sha256_json({"schema_id": "s"}))

    def test_normalize_and_family(self) -> None:
        self.assertEqual(core.normalize_logical_id("sb-dr-glm-5.2"), "glm-5.2")
        self.assertEqual(core.normalize_logical_id("composer-2.5"), "composer-2.5")
        reg = {"aliases": {"a": "b"}, "logical_to_family": {"b": "fam"}}
        self.assertEqual(core.normalize_logical_id("a", reg), "b")
        self.assertEqual(core.family_for_logical("a", reg), "fam")
        self.assertEqual(core.family_for_logical("composer-2.5"), core.load_registry()["logical_to_family"]["composer-2.5"])
        with self.assertRaisesRegex(ValueError, "unknown logical model id: nope"):
            core.family_for_logical("nope", reg)
        with self.assertRaises(ValueError):
            core.family_for_logical("x", {})


class HostDetectionTests(HermeticCase):
    def host(self, **env: str) -> str:
        with mock.patch.dict(os.environ, env):
            return core.detect_host()

    def test_detect_host_precedence(self) -> None:
        self.assertEqual(self.host(), "unknown")
        self.assertEqual(self.host(CLAUDECODE="1"), "claude-code")
        self.assertEqual(self.host(CLAUDE_CODE="1"), "claude-code")
        # Ambient fail-closed hosts beat a permissive SB_HOST override.
        self.assertEqual(self.host(CLAUDECODE="1", SB_HOST="cursor"), "claude-code")
        self.assertEqual(self.host(CODEX_SANDBOX="seatbelt", SB_HOST="cursor"), "codex")
        self.assertEqual(self.host(SB_AGENT_CODEX_DELEGATE="1"), "codex")
        self.assertEqual(self.host(SB_HOST="Claude"), "claude-code")
        self.assertEqual(self.host(SB_HOST="claude-code"), "claude-code")
        self.assertEqual(self.host(SB_HOST=" CODEX "), "codex")
        self.assertEqual(self.host(SB_HOST="cursor"), "cursor")
        self.assertEqual(self.host(CURSOR_AGENT="1"), "cursor")
        self.assertEqual(self.host(CURSOR_TRACE_ID="t"), "cursor")
        self.assertEqual(self.host(SB_HOST="Weird"), "weird")
        self.assertEqual(self.host(SB_HOST="  "), "unknown")

    def test_host_gate_supported_and_fail_closed(self) -> None:
        with mock.patch.dict(os.environ, {"SB_HOST": "cursor"}):
            self.assertEqual(core.host_gate(), {"ok": True, "host": "cursor"})
        with mock.patch.dict(os.environ, {"CLAUDECODE": "1"}):
            gate = core.host_gate()
        self.assertFalse(gate["ok"])
        self.assertEqual(gate["host"], "claude-code")
        self.assertEqual(gate["error_code"], core.UNSUPPORTED_HOST_ERROR)
        self.assertIn("packaged-fail-closed", gate["message"])

    def test_host_gate_unknown_host_is_unsupported(self) -> None:
        gate = core.host_gate()
        self.assertEqual(gate["host"], "unknown")
        self.assertEqual(gate["error_code"], "SB_MULTI_AI_UNSUPPORTED_HOST")
        self.assertIn("unsupported for multi-ai-task v1", gate["message"])

    def test_host_gate_non_supported_entry_without_error_code_uses_default(self) -> None:
        matrix = self.tmp / "matrix.json"
        matrix.write_text(json.dumps({"hosts": {"cursor": {"status": "beta"}, "codex": {"status": "off", "error_code": "CUSTOM"}}}))
        with mock.patch.object(core, "HOST_MATRIX_PATH", matrix):
            with mock.patch.dict(os.environ, {"SB_HOST": "cursor"}):
                self.assertEqual(core.host_gate()["error_code"], core.UNSUPPORTED_HOST_ERROR)
            with mock.patch.dict(os.environ, {"SB_HOST": "codex"}):
                self.assertEqual(core.host_gate()["error_code"], "CUSTOM")


def ids(resolved: list[dict]) -> list[str]:
    return [r["logical_model_id"] for r in resolved]


class ResolvePoolTests(HermeticCase):
    def test_default_selection(self) -> None:
        resolved = core.resolve_pool(core.PoolSelection())
        reg = core.load_registry()
        expected = list(reg["ocg_lite_pool"]) + [x for x in reg["cursor_default_pool"] if x != "glm-5.2"] + ["glm-5.2"]
        self.assertEqual(ids(resolved), expected)
        by_id = {r["logical_model_id"]: r for r in resolved}
        self.assertEqual(by_id["ocg-minimax-m3"]["backend"], "ocg")
        self.assertEqual(by_id["composer-2.5"]["backend"], "cursor")
        self.assertEqual(by_id["gpt-5.6-luna-medium"]["backend"], "codex")
        self.assertEqual(by_id["claude-opus-4.8-medium"]["backend"], "claude")
        self.assertEqual(by_id["glm-5.2"]["backend"], "cursor")
        self.assertEqual(by_id["glm-5.2"]["effective_model_id"], "glm-5.2")
        for entry in resolved:
            self.assertEqual(entry["requested_model_id"], entry["logical_model_id"])
            self.assertEqual(entry["model_family_registry_version"], reg["version"])
            self.assertEqual(entry["model_family_registry_sha256"], core.registry_sha256(reg))
            self.assertEqual(entry["model_family_id"], reg["logical_to_family"][entry["logical_model_id"]])

    def test_unsubscribed_routes_glm_through_ocg(self) -> None:
        resolved = core.resolve_pool(core.PoolSelection(cursor_subscription="unsubscribed"))
        glm = next(r for r in resolved if r["logical_model_id"] == "glm-5.2")
        self.assertEqual((glm["backend"], glm["effective_model_id"]), ("ocg", "ocg-glm-5.2"))
        # The explicit parameter wins over the selection's own setting.
        resolved = core.resolve_pool(core.PoolSelection(cursor_subscription="unsubscribed"), subscription="subscribed")
        glm = next(r for r in resolved if r["logical_model_id"] == "glm-5.2")
        self.assertEqual(glm["backend"], "cursor")

    def test_invalid_arguments(self) -> None:
        with self.assertRaisesRegex(ValueError, "invalid ocg pool: huge"):
            core.resolve_pool(core.PoolSelection(ocg_pool="huge"))
        with self.assertRaisesRegex(ValueError, "invalid cursor pool: all"):
            core.resolve_pool(core.PoolSelection(cursor_pool="all"))
        with self.assertRaisesRegex(ValueError, "invalid cursor subscription: 'maybe'"):
            core.resolve_pool(core.PoolSelection(cursor_subscription="maybe"))
        with self.assertRaisesRegex(ValueError, "invalid cursor subscription: 'bad'"):
            core.resolve_pool(core.PoolSelection(), subscription="bad")

    def test_unknown_subscription_requires_declaring_glm(self) -> None:
        with self.assertRaisesRegex(ValueError, "cursor subscription unknown"):
            core.resolve_pool(core.PoolSelection(cursor_subscription="unknown"))
        # Excluding glm makes the unknown state harmless.
        resolved = core.resolve_pool(core.PoolSelection(cursor_subscription="unknown", exclude=["glm-5.2"]))
        self.assertNotIn("glm-5.2", ids(resolved))
        # No glm in the candidate set at all is also harmless.
        resolved = core.resolve_pool(core.PoolSelection(ocg_pool="lite", cursor_pool="none", cursor_subscription="unknown"))
        self.assertEqual(ids(resolved), core.load_registry()["ocg_lite_pool"])

    def test_exclude_glm_by_alias_and_other_models(self) -> None:
        resolved = core.resolve_pool(core.PoolSelection(exclude=["sb-dr-glm-5.2", "composer-2.5"]))
        self.assertNotIn("glm-5.2", ids(resolved))
        self.assertNotIn("composer-2.5", ids(resolved))

    def test_include_only(self) -> None:
        resolved = core.resolve_pool(core.PoolSelection(include_only=["composer-2.5", "grok-4.5", "composer-2.5"]))
        self.assertEqual(ids(resolved), ["composer-2.5", "grok-4.5"])
        resolved = core.resolve_pool(core.PoolSelection(include_only=["ocg-glm-5.2", "composer-2.5"]))
        self.assertEqual(ids(resolved), ["composer-2.5", "glm-5.2"])
        self.assertEqual(resolved[1]["backend"], "cursor")
        resolved = core.resolve_pool(core.PoolSelection(include_only=["glm-5.2", "grok-4.5"], exclude=["glm-5.2"]))
        self.assertEqual(ids(resolved), ["grok-4.5"])

    def test_unsubscribed_glm_rules(self) -> None:
        # Lite-only OCG pool: glm is not invented.
        resolved = core.resolve_pool(core.PoolSelection(cursor_pool="none", cursor_subscription="unsubscribed"))
        self.assertNotIn("glm-5.2", ids(resolved))
        # Regular pool surviving glm slot is re-added, routed through OCG.
        resolved = core.resolve_pool(core.PoolSelection(ocg_pool="regular", cursor_pool="none", cursor_subscription="unsubscribed"))
        glm = [r for r in resolved if r["logical_model_id"] == "glm-5.2"]
        self.assertEqual(len(glm), 1)
        self.assertEqual((glm[0]["backend"], glm[0]["effective_model_id"]), ("ocg", "ocg-glm-5.2"))
        self.assertEqual(ids(resolved)[-1], "glm-5.2")

    def test_subscribed_without_cursor_pool_does_not_add_glm(self) -> None:
        resolved = core.resolve_pool(core.PoolSelection(cursor_pool="none", cursor_subscription="subscribed"))
        self.assertNotIn("glm-5.2", ids(resolved))

    def test_empty_resolution_is_an_error(self) -> None:
        with self.assertRaisesRegex(ValueError, "resolved agent set is empty"):
            core.resolve_pool(core.PoolSelection(ocg_pool="none", cursor_pool="none"))
        with self.assertRaisesRegex(ValueError, "resolved agent set is empty"):
            core.resolve_pool(core.PoolSelection(include_only=["composer-2.5"], exclude=["composer-2.5"]))


class DocumentBuilderTests(HermeticCase):
    def test_empty_ledger(self) -> None:
        ledger = core.empty_ledger("run-1")
        self.assertEqual(ledger["run_id"], "run-1")
        self.assertEqual(ledger["generation"], 0)
        self.assertEqual(ledger["entries"], [])
        self.assertEqual(ledger["head_hash"], sha256_json([]))
        self.assertEqual(ledger["spine"], core.SPINE)

    def test_work_item_manifest_budget(self) -> None:
        resolved = core.resolve_pool(core.PoolSelection(include_only=["composer-2.5"]))
        manifest = core.build_work_item_manifest("run-1", "work-1", "hash", resolved, core.BudgetPolicy())
        self.assertEqual((manifest["run_id"], manifest["work_item_id"], manifest["input_hash"]), ("run-1", "work-1", "hash"))
        self.assertEqual(manifest["resolved_logical_ids"], resolved)
        self.assertEqual(manifest["budget"]["currency_micro_usd_cap"], 25_000_000)
        self.assertTrue(manifest["budget"]["price_known"])
        unknown = core.build_work_item_manifest("r", "w", "h", resolved, core.BudgetPolicy(allow_unknown_cost=True))
        self.assertFalse(unknown["budget"]["price_known"])

    def test_result_index_sorted_and_pending(self) -> None:
        resolved = [{"logical_model_id": "b"}, {"logical_model_id": "a"}]
        ledger = {"generation": 4, "head_hash": "abc"}
        index = core.build_result_index("run-1", ledger, resolved, "work-1")
        self.assertEqual([e["logical_model_id"] for e in index["entries"]], ["a", "b"])
        self.assertTrue(all(e["status"] == "pending" and e["work_item_id"] == "work-1" for e in index["entries"]))
        self.assertEqual((index["ledger_generation"], index["ledger_head_hash"]), (4, "abc"))
        bare = core.build_result_index("run-1", {}, resolved, "work-1")
        self.assertEqual((bare["ledger_generation"], bare["ledger_head_hash"]), (0, sha256_json([])))


class DryRunReportTests(HermeticCase):
    def test_ok_report(self) -> None:
        with mock.patch.dict(os.environ, {"SB_HOST": "cursor"}):
            report = core.dry_run_report(core.PoolSelection(include_only=["composer-2.5"]))
        self.assertTrue(report["ok"])
        self.assertEqual(report["host"], "cursor")
        self.assertFalse(report["host_gate_enforced"])
        self.assertTrue(report["dry_run"])
        self.assertEqual(report["resolved_count"], 1)
        self.assertEqual(ids(report["resolved_pool"]), ["composer-2.5"])

    def test_max_agents_exceeded(self) -> None:
        report = core.dry_run_report(core.PoolSelection(), max_agents=2)
        self.assertEqual(report["ok"], False)
        self.assertEqual(report["error_code"], "MAX_AGENTS_EXCEEDED")
        self.assertEqual(report["max_agents"], 2)
        self.assertGreater(report["resolved_count"], 2)
        # Exactly at the limit still passes.
        n = len(core.resolve_pool(core.PoolSelection()))
        self.assertTrue(core.dry_run_report(core.PoolSelection(), max_agents=n)["ok"])

    def test_subscription_argument_is_forwarded(self) -> None:
        report = core.dry_run_report(core.PoolSelection(), subscription="unsubscribed")
        glm = next(r for r in report["resolved_pool"] if r["logical_model_id"] == "glm-5.2")
        self.assertEqual(glm["backend"], "ocg")


if __name__ == "__main__":
    unittest.main()

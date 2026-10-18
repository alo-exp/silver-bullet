"""Behavioral tests for live_dispatch: pure helpers, workers, cohort fan-out, orchestration.

All external CLIs are replaced by ``subprocess.run`` doubles; nothing here starts a
process, touches the network or reads the real HOME.
"""

from __future__ import annotations

import json
import os
import subprocess
import unittest
from pathlib import Path
from unittest import mock

from cov_helpers import HermeticCase

import live_dispatch as ld
from multi_ai_core import PoolSelection


def proc(returncode: int = 0, stdout: str = "", stderr: str = "") -> mock.Mock:
    return mock.Mock(returncode=returncode, stdout=stdout, stderr=stderr)


class CursorHelperTests(HermeticCase):
    def test_stub_mode_values(self) -> None:
        for value, expected in (("1", True), ("true", True), ("yes", True), (" yes ", True), ("0", False), ("", False)):
            with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": value}):
                self.assertIs(ld.stub_mode(), expected, value)

    def test_last_resort_model_off_values_and_custom(self) -> None:
        self.assertIsNone(ld.cursor_last_resort_model())
        for off in ("none", "OFF", "False", "0", "  "):
            with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_LAST_RESORT": off}):
                self.assertIsNone(ld.cursor_last_resort_model(), off)
        with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_LAST_RESORT": " auto "}):
            self.assertEqual(ld.cursor_last_resort_model(), "auto")

    def test_models_to_try_dedupes_last_resort_equal_to_primary(self) -> None:
        with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_LAST_RESORT": "composer-2.5"}):
            self.assertEqual(ld.cursor_models_to_try("composer-2.5"), ["composer-2.5"])

    def test_models_to_try_unknown_logical_id_maps_to_itself(self) -> None:
        self.assertEqual(ld.cursor_models_to_try("brand-new-model"), ["brand-new-model"])

    def test_failure_transient_is_case_insensitive(self) -> None:
        self.assertTrue(ld.cursor_failure_transient("getaddrinfo ENOTFOUND api"))
        self.assertTrue(ld.cursor_failure_transient("CONNECTION LOST"))
        self.assertFalse(ld.cursor_failure_transient("ActionRequiredError: quota"))

    def test_allow_fallback_env(self) -> None:
        self.assertFalse(ld.cursor_allow_model_fallback())
        for on in ("1", "TRUE", " yes "):
            with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_ALLOW_FALLBACK": on}):
                self.assertTrue(ld.cursor_allow_model_fallback(), on)
        with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_ALLOW_FALLBACK": "no"}):
            self.assertFalse(ld.cursor_allow_model_fallback())

    def test_attempt_succeeded_requires_zero_exit_and_clean_output(self) -> None:
        self.assertTrue(ld.cursor_attempt_succeeded(returncode=0, raw="fine"))
        self.assertFalse(ld.cursor_attempt_succeeded(returncode=1, raw="fine"))
        self.assertFalse(ld.cursor_attempt_succeeded(returncode=0, raw="Cannot use this model: x"))
        self.assertTrue(ld.cursor_output_is_failure("You've hit your usage limit"))
        self.assertTrue(ld.cursor_output_is_failure("usage limit for Opus"))

    def test_parse_failure_variants(self) -> None:
        self.assertEqual(ld.parse_cursor_cli_failure("\n  \nActionRequiredError: over quota\n"), "over quota")
        self.assertEqual(
            ld.parse_cursor_cli_failure("\nCannot use this model: x. Available: auto"),
            "Cannot use this model: x. Available: auto",
        )
        self.assertEqual(ld.parse_cursor_cli_failure("  Error: boom  \nmore"), "Error: boom")
        self.assertEqual(ld.parse_cursor_cli_failure("line one\nline two"), "line one line two")
        self.assertEqual(ld.parse_cursor_cli_failure("x" * 900), "x" * 500)
        self.assertEqual(ld.parse_cursor_cli_failure(""), "cursor agent failed")
        self.assertEqual(ld.parse_cursor_cli_failure(" \n \n"), "cursor agent failed")


class PureHelperTests(HermeticCase):
    def test_ocg_model_for(self) -> None:
        self.assertEqual(ld.ocg_model_for("ocg-minimax-m3"), "opencode-go/minimax-m3")
        self.assertEqual(ld.ocg_model_for("ocg-newthing-9"), "opencode-go/newthing-9")
        with self.assertRaises(ValueError):
            ld.ocg_model_for("composer-2.5")

    def test_extract_json_payload(self) -> None:
        self.assertEqual(ld.extract_json_payload("   "), {})
        self.assertEqual(ld.extract_json_payload('{"a": 1}'), {"a": 1})
        self.assertEqual(ld.extract_json_payload('```json\n{"a": 2}\n```'), {"a": 2})
        self.assertEqual(ld.extract_json_payload('here you go {"a": 3} thanks'), {"a": 3})
        # A JSON array is not a payload object.
        self.assertEqual(ld.extract_json_payload("[1, 2]"), {"raw_text": "[1, 2]"})
        # Broken fence and broken braces both fall back to raw_text.
        self.assertEqual(ld.extract_json_payload('```json\n{"a": }\n```'), {"raw_text": '```json\n{"a": }\n```'})
        self.assertEqual(ld.extract_json_payload("x {not json} y"), {"raw_text": "x {not json} y"})
        long = "z" * 9000
        self.assertEqual(ld.extract_json_payload(long), {"raw_text": "z" * 8000})

    def test_sanitize_phase_context(self) -> None:
        self.assertEqual(ld.sanitize_phase_context(""), "")
        ctx = json.dumps([{"a": 1, "raw_text": "noise"}, "skip-me", {"raw_text": "only-noise"}, {"b": 2}])
        cleaned = json.loads(ld.sanitize_phase_context(ctx))
        self.assertEqual(cleaned, [{"a": 1}, {"b": 2}])
        self.assertEqual(ld.sanitize_phase_context('{"raw_text": "kept"}'), '{"raw_text": "kept"}')
        self.assertEqual(ld.sanitize_phase_context("plain not json text"), "plain not json text")
        self.assertEqual(ld.sanitize_phase_context("y" * 50, max_chars=10), "y" * 10)

    def test_build_worker_prompt(self) -> None:
        cursor = ld.build_worker_prompt(phase_id="DR-RETRIEVE", query="Q?", logical_model_id="grok-4.5")
        self.assertIn("(grok-4.5)", cursor)
        self.assertIn("DR-RETRIEVE phase", cursor)
        self.assertIn("Research query: Q?", cursor)
        self.assertNotIn("Do NOT use tools", cursor)
        self.assertNotIn("Prior context", cursor)
        ocg = ld.build_worker_prompt(
            phase_id="DR-CRITIQUE", query="Q?", logical_model_id="ocg-minimax-m3", context="prior", backend="ocg"
        )
        self.assertIn("Do NOT use tools", ocg)
        self.assertIn("Prior context:\nprior", ocg)
        self.assertIn("DR-CRITIQUE phase", ocg)
        unknown = ld.build_worker_prompt(phase_id="DR-ODD", query="Q", logical_model_id="m")
        self.assertIn("Execute phase DR-ODD.", unknown)

    def test_build_envelope_without_and_with_routing(self) -> None:
        plain = ld.build_envelope(
            run_id="r", work_item_id="w", phase_id="DR-RETRIEVE", logical_model_id="grok-4.5", attempt_id="a", payload={"k": 1}
        )
        self.assertNotIn("model_routing", plain)
        self.assertTrue(plain["authoritative"])
        self.assertEqual(plain["schema_id"], "dr-phase-contribution-envelope-v1")
        self.assertEqual(plain["payload"], {"k": 1})
        routed = ld.build_envelope(
            run_id="r",
            work_item_id="w",
            phase_id="DR-RETRIEVE",
            logical_model_id="grok-4.5",
            attempt_id="a",
            payload={},
            effective_model_id="eff",
            authoritative=False,
        )
        self.assertFalse(routed["authoritative"])
        self.assertEqual(
            routed["model_routing"],
            {"requested_model_id": "cursor-grok-4.5-high", "effective_model_id": "eff", "routing_note": None},
        )
        noted = ld.build_envelope(
            run_id="r", work_item_id="w", phase_id="p", logical_model_id="grok-4.5", attempt_id="a", payload={},
            requested_model_id="req", routing_note="n",
        )
        self.assertEqual(noted["model_routing"]["requested_model_id"], "req")
        self.assertEqual(noted["model_routing"]["routing_note"], "n")


class RunCursorWorkerTests(HermeticCase):
    def setUp(self) -> None:
        super().setUp()
        self.out = self.subdir("out")

    def run_worker(self, logical: str, responses: list, **env: str):
        calls: list[tuple[list[str], dict]] = []
        queue = list(responses)

        def fake(cmd, **kwargs):  # noqa: ANN001
            calls.append((cmd, kwargs))
            item = queue.pop(0)
            if isinstance(item, BaseException):
                raise item
            return item

        with mock.patch.dict(os.environ, env):
            with mock.patch.object(ld.subprocess, "run", side_effect=fake):
                result = ld.run_cursor_worker(logical_model_id=logical, prompt="P", output_dir=self.out, timeout_sec=7)
        return result, calls

    def test_primary_success_writes_output_and_merges_stderr(self) -> None:
        result, calls = self.run_worker("composer-2.5", [proc(0, '{"x": 1}', "warn")])
        self.assertEqual(result.status, "completed")
        self.assertIsNone(result.error)
        self.assertEqual(result.effective_model_id, "composer-2.5")
        self.assertEqual(result.raw_output, '{"x": 1}\nwarn')
        cmd, kwargs = calls[0]
        self.assertEqual(cmd[1:4], ["agent", "--print", "--output-format"])
        self.assertEqual(cmd[-1], "P")
        self.assertEqual(kwargs["timeout"], 7)
        self.assertEqual(kwargs["cwd"], str(self.out))
        written = list(self.out.glob("composer-2-5-*.txt"))
        self.assertEqual(len(written), 1)
        self.assertEqual(written[0].read_text(), result.raw_output)

    def test_fallback_success_is_skipped_when_fallback_disallowed_then_fails(self) -> None:
        # Primary fails on quota; the fallback "succeeds" but fallback is disabled; the rest fail.
        models = ld.cursor_models_to_try("gpt-5.6-sol-medium")
        responses = [proc(1, "", "ActionRequiredError: quota"), proc(0, '{"ok": 1}')] + [proc(1, "", "Error: nope")] * (len(models) - 2)
        result, calls = self.run_worker("gpt-5.6-sol-medium", responses)
        self.assertEqual(result.status, "failed")
        self.assertEqual(len(calls), len(models))
        self.assertIn("gpt-5.6-sol-medium: quota", result.error)
        self.assertIn("gpt-5.6-sol-low: fallback disabled (requested gpt-5.6-sol-medium)", result.error)
        self.assertEqual(result.effective_model_id, models[-1])
        self.assertEqual(self.sleeps, [])

    def test_fallback_success_when_allowed(self) -> None:
        result, _ = self.run_worker(
            "gpt-5.6-sol-medium",
            [proc(1, "", "ActionRequiredError: quota"), proc(0, '{"ok": 1}')],
            SB_CURSOR_MODEL_ALLOW_FALLBACK="1",
        )
        self.assertEqual(result.status, "fallback")
        self.assertEqual(result.error, "fallback from gpt-5.6-sol-medium to gpt-5.6-sol-low")
        self.assertEqual(result.effective_model_id, "gpt-5.6-sol-low")

    def test_transient_error_on_last_model_retries_once_and_succeeds(self) -> None:
        result, calls = self.run_worker("composer-2.5", [proc(1, "", "ECONNRESET"), proc(0, '{"ok": 1}')])
        self.assertEqual(result.status, "completed")
        self.assertEqual(result.error, "retry after transient error (composer-2.5)")
        self.assertEqual(len(calls), 2)
        self.assertEqual(self.sleeps, [3])
        self.assertEqual(result.raw_output, '{"ok": 1}')

    def test_transient_retry_success_on_fallback_model_when_allowed(self) -> None:
        models = ld.cursor_models_to_try("gemini-3.5-flash")
        self.assertEqual(models, ["gemini-3.5-flash", "gemini-3-flash"])
        result, calls = self.run_worker(
            "gemini-3.5-flash",
            [proc(1, "", "ActionRequiredError: q"), proc(1, "", "Connection lost"), proc(0, '{"ok": 1}')],
            SB_CURSOR_MODEL_ALLOW_FALLBACK="yes",
        )
        self.assertEqual(result.status, "fallback")
        self.assertEqual(
            result.error,
            "fallback from gemini-3.5-flash to gemini-3-flash; retry after transient error (gemini-3-flash)",
        )
        self.assertEqual(len(calls), 3)

    def test_transient_retry_success_on_fallback_model_disallowed(self) -> None:
        result, _ = self.run_worker(
            "gemini-3.5-flash",
            [proc(1, "", "ActionRequiredError: q"), proc(1, "", "ETIMEDOUT"), proc(0, '{"ok": 1}')],
        )
        self.assertEqual(result.status, "failed")
        self.assertEqual(
            result.error,
            "gemini-3.5-flash: q; gemini-3-flash: fallback disabled after retry (requested gemini-3.5-flash, got gemini-3-flash)",
        )
        self.assertEqual(result.raw_output, '{"ok": 1}')

    def test_transient_retry_failure_reports_retry_output(self) -> None:
        result, _ = self.run_worker(
            "composer-2.5", [proc(1, "", "ENOTFOUND host"), proc(1, "", "Error: still down")]
        )
        self.assertEqual(result.status, "failed")
        self.assertEqual(result.error, "composer-2.5: Error: still down")
        self.assertEqual(result.raw_output, "\nError: still down")
        self.assertEqual(result.effective_model_id, "composer-2.5")

    def test_transient_error_on_non_last_model_does_not_retry(self) -> None:
        models = ld.cursor_models_to_try("gemini-3.5-flash")
        result, calls = self.run_worker(
            "gemini-3.5-flash", [proc(1, "", "network down"), proc(1, "", "Error: x")]
        )
        self.assertEqual(len(calls), len(models))
        self.assertEqual(self.sleeps, [])
        self.assertEqual(result.status, "failed")

    def test_timeout_keeps_partial_stdout(self) -> None:
        exc = subprocess.TimeoutExpired(cmd="x", timeout=1, output=b"par\xffttial")
        result, _ = self.run_worker("composer-2.5", [exc])
        self.assertEqual(result.status, "partial")
        self.assertEqual(result.error, "timeout")
        self.assertEqual(result.raw_output, "par�ttial")
        exc_none = subprocess.TimeoutExpired(cmd="x", timeout=1)
        result, _ = self.run_worker("composer-2.5", [exc_none])
        self.assertEqual(result.raw_output, "")

    def test_missing_cli(self) -> None:
        result, _ = self.run_worker("composer-2.5", [FileNotFoundError("cursor")])
        self.assertEqual((result.status, result.error, result.raw_output), ("failed", "cursor CLI not found", ""))


class DelegateWorkerTests(HermeticCase):
    def setUp(self) -> None:
        super().setUp()
        self.out = self.subdir("out")

    def test_resolve_codex_bin(self) -> None:
        explicit = self.tmp / "my-codex"
        explicit.write_text("#!/bin/sh\n")
        with mock.patch.dict(os.environ, {"CODEX_BIN": str(explicit)}):
            self.assertEqual(ld._resolve_codex_bin(), str(explicit))
        # An explicit value that is not a file falls through to the PATH lookup.
        found = self.subdir("bin") / "codex"
        found.write_text("x")
        with mock.patch.dict(os.environ, {"CODEX_BIN": "/nonexistent/codex"}):
            with mock.patch.object(ld.shutil, "which", return_value=str(found)):
                self.assertEqual(ld._resolve_codex_bin(), str(found))
        # A file on PATH with the wrong name is ignored, and the explicit value is returned.
        other = self.tmp / "bin" / "not-codex"
        other.write_text("x")
        with mock.patch.dict(os.environ, {"CODEX_BIN": "/nonexistent/codex"}):
            with mock.patch.object(ld.shutil, "which", return_value=str(other)):
                self.assertEqual(ld._resolve_codex_bin(), "/nonexistent/codex")
        with mock.patch.object(ld.shutil, "which", return_value=None):
            self.assertEqual(ld._resolve_codex_bin(), "codex")

    def test_delegate_work_dir_is_repo_root(self) -> None:
        self.assertEqual(ld._delegate_work_dir(self.out), ld.REPO_ROOT)
        self.assertTrue((ld.REPO_ROOT / "skills" / "silver-multi-ai-task").is_dir())

    def _run(self, fn, logical: str, outcome, invoke_attr: str):
        # The invoke script is a temp file, so the tests do not depend on the checkout's scripts/.
        invoke = self.tmp / f"{invoke_attr}.sh"
        invoke.write_text("#!/bin/sh\n")
        self.invoke = invoke

        def fake(cmd, **kwargs):  # noqa: ANN001
            self.captured = (cmd, kwargs)
            if isinstance(outcome, BaseException):
                raise outcome
            return outcome

        with mock.patch.object(ld, invoke_attr, invoke), mock.patch.object(ld.subprocess, "run", side_effect=fake):
            return fn(logical_model_id=logical, prompt="PR", output_dir=self.out, timeout_sec=9)

    def test_codex_worker_success_and_environment(self) -> None:
        with mock.patch.object(ld, "_resolve_codex_bin", return_value="/x/codex"):
            result = self._run(ld.run_codex_worker, "gpt-5.6-luna-medium", proc(0, "out", "err"), "AGENT_CODEX_INVOKE")
        self.assertEqual((result.status, result.backend, result.error), ("completed", "codex", None))
        self.assertEqual(result.effective_model_id, "gpt-5.6-luna-medium")
        self.assertEqual(result.raw_output, "out\nerr")
        cmd, kwargs = self.captured
        self.assertEqual(cmd[0], "bash")
        self.assertEqual(cmd[1], str(self.invoke))
        self.assertIn("--use-exec", cmd)
        self.assertEqual(cmd[cmd.index("--prompt") + 1], "PR")
        env = kwargs["env"]
        self.assertEqual(env["CODEX_MODEL"], "gpt-5.6-luna")
        self.assertEqual(env["CODEX_REASONING_EFFORT"], "medium")
        self.assertEqual(env["CODEX_BIN"], "/x/codex")
        self.assertEqual(env["SB_AGENT_CODEX_DELEGATE"], "1")
        self.assertEqual(env["SB_ORCHESTRATOR_PARENT"], "0")
        self.assertEqual(kwargs["cwd"], str(ld.REPO_ROOT))
        self.assertEqual(len(list(self.out.glob("gpt-5-6-luna-medium-*.txt"))), 1)

    def test_codex_worker_unknown_model_defaults_to_medium(self) -> None:
        with mock.patch.object(ld, "_resolve_codex_bin", return_value="codex"):
            result = self._run(ld.run_codex_worker, "other-model", proc(0, "o"), "AGENT_CODEX_INVOKE")
        self.assertEqual(result.effective_model_id, "other-model-medium")

    def test_codex_worker_failure_timeout_and_missing(self) -> None:
        with mock.patch.object(ld, "_resolve_codex_bin", return_value="codex"):
            failed = self._run(ld.run_codex_worker, "gpt-5.6-luna-medium", proc(3, "o", ""), "AGENT_CODEX_INVOKE")
            self.assertEqual((failed.status, failed.error), ("failed", "agent-codex exit 3"))
            self.assertEqual(failed.raw_output, "o")
            timeout = self._run(
                ld.run_codex_worker, "gpt-5.6-luna-medium", subprocess.TimeoutExpired("x", 1, output=b"half"), "AGENT_CODEX_INVOKE"
            )
            self.assertEqual((timeout.status, timeout.error, timeout.raw_output), ("partial", "timeout", "half"))
            timeout_empty = self._run(
                ld.run_codex_worker, "gpt-5.6-luna-medium", subprocess.TimeoutExpired("x", 1), "AGENT_CODEX_INVOKE"
            )
            self.assertEqual(timeout_empty.raw_output, "")
            gone = self._run(ld.run_codex_worker, "gpt-5.6-luna-medium", FileNotFoundError("bash"), "AGENT_CODEX_INVOKE")
            self.assertEqual((gone.status, gone.error), ("failed", "agent-codex invoke not found"))

    def test_codex_worker_missing_invoke_script_does_not_spawn(self) -> None:
        missing = self.tmp / "nope" / "invoke.sh"
        with mock.patch.object(ld, "AGENT_CODEX_INVOKE", missing), mock.patch.object(ld.subprocess, "run") as run:
            result = ld.run_codex_worker(logical_model_id="gpt-5.6-luna-medium", prompt="P", output_dir=self.out)
        run.assert_not_called()
        self.assertEqual((result.status, result.error), ("failed", f"missing {missing}"))

    def test_claude_worker_success_and_environment(self) -> None:
        with mock.patch.dict(os.environ, {"CLAUDE_BIN": "/x/claude"}):
            result = self._run(ld.run_claude_worker, "claude-opus-4.8-medium", proc(0, "out"), "AGENT_CLAUDE_INVOKE")
        self.assertEqual((result.status, result.backend, result.error), ("completed", "claude", None))
        self.assertEqual(result.effective_model_id, "claude-opus-4-8-medium")
        cmd, kwargs = self.captured
        self.assertEqual(cmd[1], str(self.invoke))
        self.assertIn("--use-print", cmd)
        env = kwargs["env"]
        self.assertEqual(env["CLAUDE_BIN"], "/x/claude")
        self.assertEqual(env["CLAUDE_MODEL"], "claude-opus-4-8")
        self.assertEqual(env["CLAUDE_EFFORT"], "medium")
        self.assertEqual(env["SB_AGENT_CLAUDE_DELEGATE"], "1")
        self.assertEqual(len(list(self.out.glob("claude-opus-4-8-medium-*.txt"))), 1)

    def test_claude_worker_binary_falls_back_to_path_lookup(self) -> None:
        with mock.patch.object(ld.shutil, "which", return_value="/found/claude"):
            self._run(ld.run_claude_worker, "claude-opus-4.8-medium", proc(0, "o"), "AGENT_CLAUDE_INVOKE")
        self.assertEqual(self.captured[1]["env"]["CLAUDE_BIN"], "/found/claude")

    def test_claude_worker_unknown_model_defaults_to_sonnet_low(self) -> None:
        result = self._run(ld.run_claude_worker, "mystery", proc(0, "o"), "AGENT_CLAUDE_INVOKE")
        self.assertEqual(result.effective_model_id, "sonnet-low")

    def test_claude_worker_failure_timeout_and_missing(self) -> None:
        failed = self._run(ld.run_claude_worker, "claude-opus-4.8-medium", proc(2, "o", "e"), "AGENT_CLAUDE_INVOKE")
        self.assertEqual((failed.status, failed.error), ("failed", "agent-claude exit 2"))
        self.assertEqual(failed.effective_model_id, "claude-opus-4-8-medium")
        timeout = self._run(
            ld.run_claude_worker, "claude-opus-4.8-medium", subprocess.TimeoutExpired("x", 1, output=b"half"), "AGENT_CLAUDE_INVOKE"
        )
        self.assertEqual((timeout.status, timeout.error, timeout.raw_output), ("partial", "timeout", "half"))
        timeout_empty = self._run(
            ld.run_claude_worker, "claude-opus-4.8-medium", subprocess.TimeoutExpired("x", 1), "AGENT_CLAUDE_INVOKE"
        )
        self.assertEqual(timeout_empty.raw_output, "")
        gone = self._run(ld.run_claude_worker, "claude-opus-4.8-medium", FileNotFoundError("bash"), "AGENT_CLAUDE_INVOKE")
        self.assertEqual((gone.status, gone.error), ("failed", "agent-claude invoke not found"))

    def test_claude_worker_missing_invoke_script_does_not_spawn(self) -> None:
        missing = self.tmp / "nope" / "invoke.sh"
        with mock.patch.object(ld, "AGENT_CLAUDE_INVOKE", missing), mock.patch.object(ld.subprocess, "run") as run:
            result = ld.run_claude_worker(logical_model_id="claude-opus-4.8-medium", prompt="P", output_dir=self.out)
        run.assert_not_called()
        self.assertEqual((result.status, result.error), ("failed", f"missing {missing}"))

    def test_ocg_worker_paths(self) -> None:
        def go(outcome):  # noqa: ANN001
            def fake(cmd, **kwargs):  # noqa: ANN001
                self.captured = (cmd, kwargs)
                if isinstance(outcome, BaseException):
                    raise outcome
                return outcome

            with mock.patch.object(ld, "OPENCODE_BIN", "/oc/opencode"), mock.patch.object(ld.subprocess, "run", side_effect=fake):
                return ld.run_ocg_worker(logical_model_id="ocg-minimax-m3", prompt="P", output_dir=self.out, timeout_sec=5)

        ok = go(proc(0, "o", "e"))
        self.assertEqual((ok.status, ok.backend, ok.error, ok.raw_output), ("completed", "ocg", None, "o\ne"))
        self.assertEqual(self.captured[0], ["/oc/opencode", "run", "--model", "opencode-go/minimax-m3", "P"])
        self.assertEqual(self.captured[1]["timeout"], 5)
        self.assertEqual(len(list(self.out.glob("ocg-minimax-m3-*.txt"))), 1)
        bad = go(proc(4, "o", ""))
        self.assertEqual((bad.status, bad.error), ("failed", "exit 4"))
        part = go(subprocess.TimeoutExpired("x", 1, output=b"half"))
        self.assertEqual((part.status, part.error, part.raw_output), ("partial", "timeout", "half"))
        self.assertEqual(go(subprocess.TimeoutExpired("x", 1)).raw_output, "")
        gone = go(FileNotFoundError("opencode"))
        self.assertEqual((gone.status, gone.error), ("failed", "opencode CLI not found"))


COHORT = "ocg-pool-cohort-result-v1"


class ParseCohortOutputTests(HermeticCase):
    def test_parse_variants(self) -> None:
        good = {"schema_id": COHORT, "contributions": []}
        text = json.dumps(good)
        self.assertIsNone(ld._parse_ocg_cohort_output("  \n"))
        self.assertEqual(ld._parse_ocg_cohort_output(text), good)
        # Valid JSON object of another schema is not a cohort result.
        self.assertIsNone(ld._parse_ocg_cohort_output('{"schema_id": "other"}'))
        self.assertEqual(ld._parse_ocg_cohort_output(f"```json\n{text}\n```"), good)
        self.assertIsNone(ld._parse_ocg_cohort_output('```json\n{"schema_id": "other"}\n```'))
        self.assertIsNone(ld._parse_ocg_cohort_output("```json\n{not json}\n```"))
        self.assertEqual(ld._parse_ocg_cohort_output(f"progress line\n{text}\ntrailer"), good)
        self.assertIsNone(ld._parse_ocg_cohort_output(f'junk {{"schema_id": "{COHORT}", broken}} tail'))
        self.assertIsNone(ld._parse_ocg_cohort_output("no json at all"))


class OcgPoolCohortTests(HermeticCase):
    ITEMS = [{"logical_model_id": "ocg-minimax-m3"}, {"logical_model_id": "ocg-mimo-v2.5"}]

    def setUp(self) -> None:
        super().setUp()
        self.out = self.tmp / "phase"  # intentionally not created: the function makes it
        self.delegate = self.tmp / "delegate.sh"
        self.delegate.write_text("#!/bin/sh\n")
        patcher = mock.patch.object(ld, "AGENT_OPENCODE_DELEGATE", self.delegate)
        patcher.start()
        self.addCleanup(patcher.stop)

    def cohort(self, outcome, *, items=None, write_result=None, timeout_sec=600):
        captured: dict = {}

        def fake(cmd, **kwargs):  # noqa: ANN001
            captured["cmd"], captured["kwargs"] = cmd, kwargs
            if write_result is not None:
                Path(cmd[cmd.index("--cohort-output") + 1]).write_text(write_result)
            if isinstance(outcome, BaseException):
                raise outcome
            return outcome

        with mock.patch.object(ld.subprocess, "run", side_effect=fake):
            results = ld.run_ocg_pool_cohort(
                ocg_items=self.ITEMS if items is None else items,
                phase_id="DR-RETRIEVE",
                query="Q",
                run_id="run-1",
                work_item_id="work-1",
                output_dir=self.out,
                context="ctx",
                pool="lite",
                timeout_sec=timeout_sec,
            )
        self.captured = captured
        return results

    def test_no_items_is_a_noop(self) -> None:
        with mock.patch.object(ld.subprocess, "run") as run:
            self.assertEqual(ld.run_ocg_pool_cohort(
                ocg_items=[], phase_id="p", query="q", run_id="r", work_item_id="w",
                output_dir=self.out, context="", pool="lite"), [])
        run.assert_not_called()
        self.assertFalse(self.out.exists())

    def test_missing_delegate_script_fails_every_item_and_still_writes_request(self) -> None:
        missing = self.tmp / "gone.sh"
        with mock.patch.object(ld, "AGENT_OPENCODE_DELEGATE", missing), mock.patch.object(ld.subprocess, "run") as run:
            results = ld.run_ocg_pool_cohort(
                ocg_items=self.ITEMS, phase_id="DR-RETRIEVE", query="Q", run_id="r", work_item_id="w",
                output_dir=self.out, context="", pool="lite")
        run.assert_not_called()
        self.assertEqual([r.status for r in results], ["failed", "failed"])
        self.assertTrue(all(r.error == f"missing agent-opencode delegate at {missing}" for r in results))
        self.assertEqual(len(list(self.out.glob("ocg-cohort-request-*.json"))), 1)

    def test_success_reads_result_file_and_builds_envelopes(self) -> None:
        body = json.dumps({
            "schema_id": COHORT,
            "contributions": [
                {"logical_model_id": "ocg-minimax-m3", "status": "completed", "payload": {"a": 1},
                 "raw_output_path": "m.raw.txt", "effective_model_id": "opencode-go/minimax-m3"},
                {"logical_model_id": "ocg-mimo-v2.5", "status": "failed", "payload": {}, "error": "exit 1"},
            ],
        })
        with mock.patch.dict(os.environ, {"SB_OCG_PER_MODEL_TIMEOUT_SEC": "100"}):
            results = self.cohort(proc(0, "stdout-noise"), write_result=body, timeout_sec=900)
        ok, bad = results
        self.assertEqual((ok.status, ok.raw_output, ok.effective_model_id), ("completed", "m.raw.txt", "opencode-go/minimax-m3"))
        self.assertEqual(ok.envelope["payload"], {"a": 1})
        self.assertEqual(ok.envelope["logical_model_id"], "ocg-minimax-m3")
        self.assertEqual(ok.envelope["attempt_id"], ok.attempt_id)
        self.assertEqual((bad.status, bad.error), ("failed", "exit 1"))
        self.assertIsNone(bad.envelope)
        cmd = self.captured["cmd"]
        self.assertEqual(cmd[:2], ["bash", str(self.delegate)])
        self.assertEqual(cmd[cmd.index("--delegation-mode") + 1], "multi-ai-pool-v1")
        self.assertEqual(cmd[cmd.index("--multi-ai-pool") + 1], "lite")
        # Cohort timeout is len(items) * per-model timeout (clamped by env) + 300.
        self.assertEqual(self.captured["kwargs"]["timeout"], 2 * 100 + 300)
        request = json.loads(Path(cmd[cmd.index("--cohort-request") + 1]).read_text())
        self.assertEqual(request["timeout_sec"], 100)
        self.assertEqual(request["logical_model_ids"], ["ocg-minimax-m3", "ocg-mimo-v2.5"])
        self.assertEqual(request["context"], "ctx")
        self.assertEqual(request["work_dir"], str(self.out.resolve()))

    def test_partial_contribution_with_payload_gets_envelope(self) -> None:
        body = json.dumps({"schema_id": COHORT, "contributions": [
            {"logical_model_id": "ocg-minimax-m3", "status": "partial", "payload": {"p": 1}, "error": "timeout"}]})
        results = self.cohort(proc(0), items=[self.ITEMS[0]], write_result=body)
        self.assertEqual(results[0].status, "partial")
        self.assertEqual(results[0].envelope["payload"], {"p": 1})
        self.assertEqual(results[0].raw_output, "")

    def test_contribution_without_status_defaults_to_failed(self) -> None:
        body = json.dumps({"schema_id": COHORT, "contributions": [{"logical_model_id": "ocg-minimax-m3", "payload": {"p": 1}}]})
        results = self.cohort(proc(0), items=[self.ITEMS[0]], write_result=body)
        self.assertEqual(results[0].status, "failed")
        self.assertIsNone(results[0].envelope)

    def test_missing_contribution_is_reported(self) -> None:
        body = json.dumps({"schema_id": COHORT, "contributions": [
            {"logical_model_id": "ocg-minimax-m3", "status": "completed", "payload": {"a": 1}}]})
        results = self.cohort(proc(0, "so", "se"), write_result=body)
        self.assertEqual(results[0].status, "completed")
        self.assertEqual((results[1].status, results[1].error, results[1].raw_output), ("failed", "missing cohort contribution", "so\nse"))

    def test_payload_absent_in_payload_less_cohort_result(self) -> None:
        body = json.dumps({"schema_id": COHORT})
        results = self.cohort(proc(0), write_result=body)
        self.assertEqual([r.error for r in results], ["missing cohort contribution"] * 2)

    def test_corrupt_result_file_falls_back_to_stdout(self) -> None:
        stdout = json.dumps({"schema_id": COHORT, "contributions": [
            {"logical_model_id": "ocg-minimax-m3", "status": "completed", "payload": {"s": 1}}]})
        results = self.cohort(proc(0, stdout), items=[self.ITEMS[0]], write_result="{truncated")
        self.assertEqual(results[0].envelope["payload"], {"s": 1})

    def test_unparseable_output_fails_all_with_exit_code(self) -> None:
        results = self.cohort(proc(5, "garbage", "bad"))
        self.assertEqual([r.status for r in results], ["failed", "failed"])
        self.assertEqual(results[0].error, "ocg cohort parse failed (exit 5)")
        self.assertEqual(results[0].raw_output, "garbage\nbad")

    def test_timeout_and_missing_executable(self) -> None:
        results = self.cohort(subprocess.TimeoutExpired("x", 1))
        self.assertEqual([(r.status, r.error) for r in results], [("partial", "ocg cohort timeout")] * 2)
        results = self.cohort(FileNotFoundError("bash"))
        self.assertEqual([(r.status, r.error) for r in results], [("failed", "agent-opencode delegate not found")] * 2)


class DispatchAgentTests(HermeticCase):
    def dispatch(self, item: dict, worker: str, result: ld.WorkerResult):
        with mock.patch.object(ld, worker, return_value=result) as w:
            out = ld.dispatch_agent(
                item, phase_id="DR-RETRIEVE", query="Q", run_id="r", work_item_id="w",
                output_dir=self.tmp, context="c", timeout_sec=11)
        return out, w

    def test_cursor_completed_builds_authoritative_envelope(self) -> None:
        res = ld.WorkerResult("grok-4.5", "cursor", "att", "completed", None, '{"k": 1}', None, effective_model_id="m")
        out, worker = self.dispatch({"logical_model_id": "grok-4.5"}, "run_cursor_worker", res)
        kwargs = worker.call_args.kwargs
        self.assertEqual((kwargs["logical_model_id"], kwargs["timeout_sec"]), ("grok-4.5", 11))
        self.assertIn("Prior context:\nc", kwargs["prompt"])
        self.assertTrue(out.envelope["authoritative"])
        self.assertEqual(out.envelope["model_routing"]["requested_model_id"], "cursor-grok-4.5-high")
        self.assertEqual(out.envelope["model_routing"]["effective_model_id"], "m")

    def test_fallback_status_is_non_authoritative_with_note(self) -> None:
        res = ld.WorkerResult("grok-4.5", "cursor", "att", "fallback", None, '{"k": 1}', "fallback note", effective_model_id="m2")
        out, _ = self.dispatch({"logical_model_id": "grok-4.5", "backend": "cursor"}, "run_cursor_worker", res)
        self.assertFalse(out.envelope["authoritative"])
        self.assertEqual(out.envelope["model_routing"]["routing_note"], "fallback note")

    def test_failed_or_empty_payload_gets_no_envelope(self) -> None:
        failed = ld.WorkerResult("grok-4.5", "cursor", "att", "failed", None, '{"k": 1}', "err")
        out, _ = self.dispatch({"logical_model_id": "grok-4.5"}, "run_cursor_worker", failed)
        self.assertIsNone(out.envelope)
        empty = ld.WorkerResult("grok-4.5", "cursor", "att", "completed", None, "  ", None)
        out, _ = self.dispatch({"logical_model_id": "grok-4.5"}, "run_cursor_worker", empty)
        self.assertIsNone(out.envelope)

    def test_codex_and_claude_routing(self) -> None:
        res = ld.WorkerResult("gpt-5.6-luna-medium", "codex", "a", "partial", None, '{"k": 1}', "timeout")
        out, worker = self.dispatch({"logical_model_id": "gpt-5.6-luna-medium", "backend": "codex"}, "run_codex_worker", res)
        worker.assert_called_once()
        self.assertEqual(out.envelope["model_routing"]["requested_model_id"], "gpt-5.6-luna-medium")
        self.assertFalse(out.envelope["authoritative"])
        res = ld.WorkerResult("claude-opus-4.8-medium", "claude", "a", "completed", None, '{"k": 1}')
        out, worker = self.dispatch({"logical_model_id": "claude-opus-4.8-medium", "backend": "claude"}, "run_claude_worker", res)
        worker.assert_called_once()
        self.assertEqual(out.envelope["model_routing"]["requested_model_id"], "claude-opus-4-8-medium")
        # Unknown ids use the default mapping for requested id in the envelope.
        res = ld.WorkerResult("gpt-5.6-luna-medium", "codex", "a", "completed", None, '{"k": 1}')
        with mock.patch.dict(ld.CODEX_DELEGATE_MODEL, {}, clear=True):
            out, _ = self.dispatch({"logical_model_id": "gpt-5.6-luna-medium", "backend": "codex"}, "run_codex_worker", res)
        self.assertEqual(out.envelope["model_routing"]["requested_model_id"], "gpt-5.6-luna-medium-medium")
        res = ld.WorkerResult("claude-opus-4.8-medium", "claude", "a", "completed", None, '{"k": 1}')
        with mock.patch.dict(ld.CLAUDE_DELEGATE_MODEL, {}, clear=True):
            out, _ = self.dispatch({"logical_model_id": "claude-opus-4.8-medium", "backend": "claude"}, "run_claude_worker", res)
        self.assertEqual(out.envelope["model_routing"]["requested_model_id"], "sonnet-low")

    def test_unknown_backend_uses_cursor_worker_with_own_prompt_backend(self) -> None:
        res = ld.WorkerResult("grok-4.5", "weird", "a", "completed", None, '{"k": 1}')
        out, worker = self.dispatch({"logical_model_id": "grok-4.5", "backend": "weird"}, "run_cursor_worker", res)
        worker.assert_called_once()
        # Not codex/claude/cursor: the requested id stays the logical id.
        self.assertEqual(out.envelope["model_routing"]["requested_model_id"], "grok-4.5")
        self.assertNotIn("Do NOT use tools", worker.call_args.kwargs["prompt"])

    def test_ocg_backend_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "run_ocg_pool_cohort"):
            ld.dispatch_agent({"logical_model_id": "ocg-x", "backend": "ocg"}, phase_id="p", query="q", run_id="r",
                              work_item_id="w", output_dir=self.tmp, context="", timeout_sec=1)


class DispatchPhaseParallelTests(HermeticCase):
    def test_splits_pool_between_agents_and_ocg_cohort(self) -> None:
        pool = [
            {"logical_model_id": "composer-2.5", "backend": "cursor"},
            {"logical_model_id": "no-backend-key"},
            {"logical_model_id": "ocg-minimax-m3", "backend": "ocg"},
            {"logical_model_id": "ocg-mimo-v2.5", "backend": "ocg"},
        ]

        def fake_agent(item, **kwargs):  # noqa: ANN001
            return ld.WorkerResult(item["logical_model_id"], "cursor", "a", "completed", None, "{}")

        def fake_cohort(**kwargs):  # noqa: ANN001
            self.assertEqual(kwargs["pool"], "regular")
            self.assertEqual([i["logical_model_id"] for i in kwargs["ocg_items"]], ["ocg-minimax-m3", "ocg-mimo-v2.5"])
            return [ld.WorkerResult(i["logical_model_id"], "ocg", "a", "completed", None, "") for i in kwargs["ocg_items"]]

        with mock.patch.object(ld, "dispatch_agent", side_effect=fake_agent) as da, \
                mock.patch.object(ld, "run_ocg_pool_cohort", side_effect=fake_cohort) as rc:
            results = ld.dispatch_phase_parallel(
                phase_id="DR-TRIANGULATE", query="Q", run_id="r", work_item_id="w", resolved_pool=pool,
                output_dir=self.tmp, context="c", concurrency=2, timeout_sec=5, ocg_pool="regular")
        self.assertEqual(sorted(r.logical_model_id for r in results),
                         ["composer-2.5", "no-backend-key", "ocg-mimo-v2.5", "ocg-minimax-m3"])
        self.assertEqual(da.call_count, 2)
        self.assertEqual(rc.call_count, 1)
        phase_dir = self.tmp / "phases" / "DR-TRIANGULATE"
        self.assertTrue(phase_dir.is_dir())
        self.assertEqual(da.call_args.kwargs["output_dir"], phase_dir)
        self.assertEqual(da.call_args.kwargs["context"], "c")

    def test_empty_pool_runs_no_workers(self) -> None:
        with mock.patch.object(ld, "dispatch_agent") as da, mock.patch.object(ld, "run_ocg_pool_cohort") as rc:
            self.assertEqual(ld.dispatch_phase_parallel(
                phase_id="DR-RETRIEVE", query="Q", run_id="r", work_item_id="w", resolved_pool=[], output_dir=self.tmp), [])
        da.assert_not_called()
        rc.assert_not_called()


class RunMultiAiLiveTests(HermeticCase):
    def test_stub_mode_short_circuits_without_writing(self) -> None:
        root = self.tmp / "root"
        with mock.patch.dict(os.environ, {"SB_MULTI_AI_STUB": "1"}):
            out = ld.run_multi_ai_live(output_root=root, selection=PoolSelection())
        self.assertEqual(out["error_code"], "MULTI_AI_LIVE_DISPATCH_NOT_READY")
        self.assertFalse(out["ok"])
        self.assertFalse(root.exists())

    def test_end_to_end_writes_artifacts_with_stubbed_cursor(self) -> None:
        root = self.tmp / "root"

        def fake(cmd, **kwargs):  # noqa: ANN001
            model = cmd[cmd.index("--model") + 1]
            if model == "grok-4.5" or model == "cursor-grok-4.5-high":
                return proc(1, "", "Error: broken")
            return proc(0, '{"sources": []}')

        selection = PoolSelection(ocg_pool="none", cursor_pool="none", include_only=["composer-2.5", "grok-4.5"])
        with mock.patch.object(ld.subprocess, "run", side_effect=fake):
            out = ld.run_multi_ai_live(output_root=root, selection=selection, task_prompt="topic", phase_id="DR-CRITIQUE")
        self.assertTrue(out["ok"])
        self.assertEqual(out["phase_id"], "DR-CRITIQUE")
        self.assertEqual(out["resolved_count"], 2)
        self.assertEqual(out["envelopes_count"], 1)
        self.assertTrue(out["live_dispatch"])
        statuses = {w["logical_model_id"]: w["status"] for w in out["worker_results"]}
        self.assertEqual(statuses, {"composer-2.5": "completed", "grok-4.5": "failed"})

        manifest = json.loads(Path(out["manifest_path"]).read_text())
        self.assertEqual(manifest["run_id"], out["run_id"])
        self.assertEqual(len(manifest["attempts"]), 2)
        by_model = {a["logical_model_id"]: a for a in manifest["attempts"]}
        self.assertTrue(by_model["composer-2.5"]["authoritative"])
        self.assertFalse(by_model["grok-4.5"]["authoritative"])
        envelopes = json.loads(Path(out["envelopes_path"]).read_text())
        self.assertEqual([e["logical_model_id"] for e in envelopes], ["composer-2.5"])
        index = json.loads((root / "result-index.json").read_text())
        entries = {e["logical_model_id"]: e for e in index["entries"]}
        self.assertEqual(entries["composer-2.5"]["status"], "completed")
        self.assertEqual(entries["composer-2.5"]["authoritative_attempt_id"], by_model["composer-2.5"]["attempt_id"])
        self.assertEqual(entries["grok-4.5"]["status"], "failed")
        self.assertIsNone(entries["grok-4.5"]["authoritative_attempt_id"])
        self.assertIn("Error: broken", entries["grok-4.5"]["terminal_reason"])
        ledger = json.loads((root / "dispatch-ledger.json").read_text())
        self.assertEqual(ledger["run_id"], out["run_id"])

    def test_defaults_phase_and_clamps_unknown_ocg_pool_to_lite(self) -> None:
        root = self.tmp / "root"
        selection = PoolSelection(ocg_pool="none", cursor_pool="none", include_only=["composer-2.5"])
        with mock.patch.object(ld, "dispatch_phase_parallel", return_value=[]) as dpp:
            out = ld.run_multi_ai_live(output_root=root, selection=selection)
        kwargs = dpp.call_args.kwargs
        self.assertEqual((kwargs["phase_id"], kwargs["query"], kwargs["ocg_pool"]), ("DR-RETRIEVE", "multi-ai-task", "lite"))
        self.assertEqual(out["phase_id"], "DR-RETRIEVE")
        self.assertEqual(out["envelopes_count"], 0)

    def test_regular_ocg_pool_is_forwarded(self) -> None:
        selection = PoolSelection(ocg_pool="regular", cursor_pool="none", include_only=["ocg-minimax-m3"])
        with mock.patch.object(ld, "dispatch_phase_parallel", return_value=[]) as dpp:
            ld.run_multi_ai_live(output_root=self.tmp / "r", selection=selection, task_prompt="t")
        self.assertEqual(dpp.call_args.kwargs["ocg_pool"], "regular")
        self.assertEqual(dpp.call_args.kwargs["query"], "t")


if __name__ == "__main__":
    unittest.main()

"""Unit tests for live_dispatch cursor model routing."""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path
from unittest import mock


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from live_dispatch import (  # noqa: E402
    cursor_attempt_succeeded,
    cursor_model_for,
    cursor_models_to_try,
    cursor_output_is_failure,
    dispatch_agent,
    parse_cursor_cli_failure,
    run_cursor_worker,
)
import live_dispatch  # noqa: E402


class LiveDispatchModelRoutingTests(unittest.TestCase):
    def test_cursor_model_map_hyphenated_slugs(self) -> None:
        self.assertEqual(cursor_model_for("claude-opus-4.8-medium"), "claude-opus-4-8-medium")
        self.assertEqual(cursor_model_for("glm-5.2"), "glm-5.2-high")
        self.assertEqual(cursor_model_for("grok-4.5"), "cursor-grok-4.5-high")

    def test_cursor_models_to_try_excludes_last_resort_by_default(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SB_CURSOR_MODEL_LAST_RESORT", None)
            models = cursor_models_to_try("gpt-5.6-sol-medium")
        self.assertEqual(models[0], "gpt-5.6-sol-medium")
        self.assertIn("gpt-5.6-sol-low", models)
        self.assertNotIn("auto", models)

    def test_cursor_models_to_try_includes_last_resort_when_configured(self) -> None:
        with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_LAST_RESORT": "auto"}, clear=False):
            models = cursor_models_to_try("gpt-5.6-sol-medium")
        self.assertEqual(models[-1], "auto")

    def test_cursor_output_is_failure_action_required(self) -> None:
        raw = "ActionRequiredError: You've hit your usage limit\n"
        self.assertTrue(cursor_output_is_failure(raw))
        self.assertFalse(cursor_attempt_succeeded(returncode=0, raw=raw))

    def test_parse_cursor_cli_failure_action_required(self) -> None:
        raw = "Retry attempt 1...\nActionRequiredError: You've hit your usage limit\n"
        self.assertIn("usage limit", parse_cursor_cli_failure(raw))

    def test_parse_cursor_cli_failure_invalid_model(self) -> None:
        raw = "Cannot use this model: claude-opus-4.8-medium. Available models: auto"
        self.assertIn("Cannot use this model", parse_cursor_cli_failure(raw))

    def test_dispatch_agent_rejects_ocg_backend(self) -> None:
        with self.assertRaises(ValueError):
            dispatch_agent(
                {"logical_model_id": "ocg-mimo-v2.5", "backend": "ocg"},
                phase_id="DR-RETRIEVE",
                query="q",
                run_id="run-test",
                work_item_id="work-test",
                output_dir=Path("/tmp/sb-live-dispatch-test"),
                context="",
                timeout_sec=30,
            )

    def test_run_cursor_worker_tries_fallback_when_allowed(self) -> None:
        calls: list[list[str]] = []

        def fake_run(cmd, **kwargs):  # noqa: ANN001
            calls.append(cmd)
            model = cmd[cmd.index("--model") + 1]
            if model == "gpt-5.6-sol-medium":
                return mock.Mock(returncode=1, stdout="", stderr="ActionRequiredError: quota")
            return mock.Mock(returncode=0, stdout='{"ok": true}', stderr="")

        out_dir = Path("/tmp/sb-live-dispatch-test")
        out_dir.mkdir(parents=True, exist_ok=True)

        with mock.patch.dict(os.environ, {"SB_CURSOR_MODEL_ALLOW_FALLBACK": "1"}, clear=False):
            with mock.patch.object(live_dispatch.subprocess, "run", side_effect=fake_run):
                result = run_cursor_worker(
                    logical_model_id="gpt-5.6-sol-medium",
                    prompt="test",
                    output_dir=out_dir,
                )
        self.assertEqual(result.status, "fallback")
        self.assertGreater(len(calls), 1)
        self.assertIn("--trust", calls[0])

    def test_run_cursor_worker_fails_closed_without_fallback(self) -> None:
        def fake_run(cmd, **kwargs):  # noqa: ANN001
            model = cmd[cmd.index("--model") + 1]
            if model == "gpt-5.6-sol-medium":
                return mock.Mock(returncode=1, stdout="", stderr="ActionRequiredError: quota")
            return mock.Mock(returncode=0, stdout='{"ok": true}', stderr="")

        out_dir = Path("/tmp/sb-live-dispatch-test")
        out_dir.mkdir(parents=True, exist_ok=True)

        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("SB_CURSOR_MODEL_ALLOW_FALLBACK", None)
            with mock.patch.object(live_dispatch.subprocess, "run", side_effect=fake_run):
                result = run_cursor_worker(
                    logical_model_id="gpt-5.6-sol-medium",
                    prompt="test",
                    output_dir=out_dir,
                )
        self.assertEqual(result.status, "failed")


if __name__ == "__main__":
    unittest.main()

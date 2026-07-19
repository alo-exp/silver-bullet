"""Tests for cursor-host-adapter-v1 stub (explicitly not-live)."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
ADAPTER = SCRIPTS / "cursor_host_adapter.py"
sys.path.insert(0, str(SCRIPTS))

from cursor_host_adapter import (  # noqa: E402
    LIVE_STATUS,
    LaunchRequest,
    cancel,
    cas_select_authoritative_attempt,
    launch,
)


class CursorHostAdapterStubTests(unittest.TestCase):
    def setUp(self) -> None:
        import importlib
        import os
        os.environ["SB_MULTI_AI_STUB"] = "1"
        import cursor_host_adapter as cha
        importlib.reload(cha)
        global LIVE_STATUS, cancel, cas_select_authoritative_attempt, launch
        LIVE_STATUS = cha.live_status()
        cancel = cha.cancel
        cas_select_authoritative_attempt = cha.cas_select_authoritative_attempt
        launch = cha.launch

    def tearDown(self) -> None:
        import os
        os.environ.pop("SB_MULTI_AI_STUB", None)
    def test_live_status_is_not_live(self) -> None:
        self.assertEqual(LIVE_STATUS, "not-live")

    def test_launch_returns_not_live_envelope(self) -> None:
        req = LaunchRequest(
            idempotency_key="idem-1",
            run_id="run-" + "a" * 32,
            work_item_id="work-" + "b" * 32,
            logical_model_id="composer-2.5",
            attempt_id="attempt-1",
            requested_model_id="composer-2.5",
            effective_model_id="composer-2.5",
            output_root="/tmp/out",
            deadline="2026-07-17T00:00:00Z",
            hard_token_ceiling=100_000,
        )
        out = launch(req)
        self.assertFalse(out["ok"])
        self.assertEqual(out["live_status"], "not-live")
        self.assertEqual(out["error_code"], "CURSOR_HOST_ADAPTER_NOT_LIVE")
        self.assertEqual(out["launch"]["logical_model_id"], "composer-2.5")

    def test_cancel_is_idempotent_stub(self) -> None:
        out = cancel("attempt-1", "idem-1")
        self.assertTrue(out["ok"])
        self.assertTrue(out["cancellation_acknowledged"])
        self.assertEqual(out["live_status"], "not-live")

    def test_cas_generation_conflict(self) -> None:
        out = cas_select_authoritative_attempt(2, 1, "attempt-1")
        self.assertFalse(out["ok"])
        self.assertEqual(out["error_code"], "CAS_GENERATION_CONFLICT")

    def test_cas_success_increments_generation(self) -> None:
        out = cas_select_authoritative_attempt(1, 1, "attempt-1")
        self.assertTrue(out["ok"])
        self.assertEqual(out["generation"], 2)
        self.assertEqual(out["authoritative_attempt_id"], "attempt-1")

    def test_cli_launch_json(self) -> None:
        payload = {
            "idempotency_key": "idem-1",
            "run_id": "run-" + "c" * 32,
            "work_item_id": "work-" + "d" * 32,
            "logical_model_id": "grok-4.5",
            "attempt_id": "attempt-2",
            "requested_model_id": "grok-4.5",
            "effective_model_id": "grok-4.5",
            "output_root": "/tmp/out",
            "deadline": "2026-07-17T00:00:00Z",
            "hard_token_ceiling": 50_000,
        }
        proc = subprocess.run(
            [sys.executable, str(ADAPTER), "launch", "--request-json", json.dumps(payload)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        body = json.loads(proc.stdout)
        self.assertEqual(body["live_status"], "not-live")


if __name__ == "__main__":
    unittest.main()

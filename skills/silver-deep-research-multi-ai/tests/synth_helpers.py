"""Shared fixtures for the synthesize_landscape unit tests (offline, tempdir based)."""

from __future__ import annotations

import json
import socket
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import synthesize_landscape as sl  # noqa: E402,F401

APO_NEED = {
    "category": "Agentic SDLC Process Orchestrators",
    "category_pack_id": "agentic-sdlc-process-orchestrator",
    "must_haves": ["workflow composition"],
}


class TmpCase(unittest.TestCase):
    """Per-test temp dir and a guard that fails the test on any socket connection."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        spy = mock.patch.object(socket.socket, "connect", side_effect=AssertionError("network used"))
        spy.start()
        self.addCleanup(spy.stop)
        # Vendor URL health probes and PDF rendering are always off in unit tests.
        env = mock.patch.dict("os.environ", {"SB_SKIP_VENDOR_URL_HEALTH": "1", "SB_SKIP_LANDSCAPE_PDF": "1",
                                             "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"})
        env.start()
        self.addCleanup(env.stop)

    def put(self, rel, data):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data if isinstance(data, str) else json.dumps(data), encoding="utf-8")
        return path

"""Shared hermeticity helpers for the multi-ai-task coverage tests.

Every test case built on ``HermeticCase`` runs with network access blocked by a
socket spy, a throwaway HOME/TMPDIR, no ``SB_*`` or CLI-selection environment
leaking in from the caller, and ``time.sleep`` replaced by a recorder.
"""

from __future__ import annotations

import os
import socket
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

_SCRUBBED_PREFIXES = ("SB_", "CLAUDE", "CODEX", "CURSOR")
_SCRUBBED_NAMES = ("HTTPS_PROXY", "HTTP_PROXY")


class NetworkAttempt(AssertionError):
    """Raised by the socket spy when code under test tries to open a connection."""


class HermeticCase(unittest.TestCase):
    def setUp(self) -> None:
        super().setUp()
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.home = self.tmp / "home"
        self.home.mkdir()

        env = {
            k: v
            for k, v in os.environ.items()
            if not k.startswith(_SCRUBBED_PREFIXES) and k not in _SCRUBBED_NAMES
        }
        env["HOME"] = str(self.home)
        env["TMPDIR"] = str(self.tmp)
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

        self.network_attempts: list[object] = []

        def spy(*args: object, **kwargs: object) -> None:
            self.network_attempts.append(args)
            raise NetworkAttempt("network access attempted in a hermetic test")

        for target in ("connect", "connect_ex"):
            p = mock.patch.object(socket.socket, target, spy)
            p.start()
            self.addCleanup(p.stop)
        p = mock.patch.object(socket, "create_connection", spy)
        p.start()
        self.addCleanup(p.stop)
        self.addCleanup(self._assert_no_network)

        import live_dispatch

        self.sleeps: list[float] = []
        p = mock.patch.object(live_dispatch.time, "sleep", self.sleeps.append)
        p.start()
        self.addCleanup(p.stop)

    def _assert_no_network(self) -> None:
        self.assertEqual(self.network_attempts, [])

    def subdir(self, name: str) -> Path:
        path = self.tmp / name
        path.mkdir(parents=True, exist_ok=True)
        return path

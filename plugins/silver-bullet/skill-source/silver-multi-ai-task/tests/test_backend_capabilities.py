"""Tests for backend-capabilities-v1 spike contract."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
SPIKE = SCRIPTS / "capability_spike.py"
FIXTURE = SKILL_ROOT / "tests" / "fixtures" / "backend-capabilities-v1-stub.json"


class BackendCapabilitiesTests(unittest.TestCase):
    def test_fixture_matches_schema_shape(self) -> None:
        data = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(data["schema_id"], "backend-capabilities-v1")
        self.assertEqual(data["spine"], "multi-ai-task-v2")
        self.assertIn("cursor", data["backends"])
        self.assertIn("ocg", data["backends"])

    def test_spike_writes_stub_capabilities(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "capabilities" / "backend-capabilities-v1.json"
            proc = subprocess.run(
                [sys.executable, str(SPIKE), "--output", str(out)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            data = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual(data["backends"]["cursor"]["status"], "stub")

    def test_profile_validation_rejects_unknown(self) -> None:
        proc = subprocess.run(
            [
                sys.executable,
                str(SPIKE),
                "--output",
                "/tmp/unused-capabilities.json",
                "--validate-profile",
                "not-a-real-profile",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()

"""Tests for v3→v4 run manifest migration."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
FIXTURES = SKILL_ROOT / "tests" / "fixtures"
MIGRATE = SCRIPTS / "migrate_run_manifest.py"


class MigrateRunManifestTests(unittest.TestCase):
    def test_strict_v3_migrates_to_v4(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = FIXTURES / "run_manifest_strict_v3.json"
            proc = subprocess.run(
                [
                    sys.executable,
                    str(MIGRATE),
                    "--input",
                    str(src),
                    "--research-root",
                    str(root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            manifest = json.loads((root / "run_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["schema_id"], "deep-research-run-manifest-v4")
            self.assertEqual(manifest["version"], "4.0.0")
            self.assertEqual(manifest["spine"], "multi-ai-task-v2")
            self.assertTrue(manifest["run_id"].startswith("run-"))
            audit = root / "migration" / "run-manifest-migration-audit-v1.jsonl"
            self.assertTrue(audit.exists())
            record = json.loads(audit.read_text(encoding="utf-8").strip().splitlines()[-1])
            self.assertEqual(record["schema_id"], "run-manifest-migration-audit-v1")
            self.assertIn("record_hash", record)

    def test_unknown_version_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.json"
            bad.write_text(json.dumps({"schema_id": "x", "version": "9.9.9"}) + "\n", encoding="utf-8")
            proc = subprocess.run(
                [
                    sys.executable,
                    str(MIGRATE),
                    "--input",
                    str(bad),
                    "--research-root",
                    tmp,
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(proc.returncode, 0)

    def test_refuses_overwrite_existing_v4_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = FIXTURES / "run_manifest_strict_v3.json"
            first = subprocess.run(
                [
                    sys.executable,
                    str(MIGRATE),
                    "--input",
                    str(src),
                    "--research-root",
                    str(root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            second = subprocess.run(
                [
                    sys.executable,
                    str(MIGRATE),
                    "--input",
                    str(src),
                    "--research-root",
                    str(root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(second.returncode, 0)
            self.assertIn("refusing to overwrite", second.stderr)

    def test_force_overwrites_existing_v4(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = FIXTURES / "run_manifest_strict_v3.json"
            for extra in ("", "--force"):
                proc = subprocess.run(
                    [
                        sys.executable,
                        str(MIGRATE),
                        "--input",
                        str(src),
                        "--research-root",
                        str(root),
                        *([] if not extra else [extra]),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(proc.returncode, 0, proc.stderr)


if __name__ == "__main__":
    unittest.main()

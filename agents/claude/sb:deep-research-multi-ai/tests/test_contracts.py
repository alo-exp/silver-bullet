"""Contract tests for deep-research-multi-ai composer."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
REPO_ROOT = SKILL_ROOT.parents[1]


class DrMultiAiContractTests(unittest.TestCase):
    def test_parallel_phases_deep_default(self) -> None:
        cfg = json.loads((SKILL_ROOT / "reference" / "parallel-phases-v1.json").read_text())
        phases = cfg["by_research_type"]["default"]["deep"]
        self.assertEqual(phases, ["DR-RETRIEVE", "DR-TRIANGULATE", "DR-CRITIQUE"])

    def test_run_manifest_v4_spine(self) -> None:
        schema = json.loads((SKILL_ROOT / "schemas" / "run-manifest-v4.schema.json").read_text())
        self.assertEqual(schema["properties"]["spine"]["const"], "multi-ai-task-v2")

    def test_dry_run_cli(self) -> None:
        proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "dr_multi_ai_cli.py"),
                "test query",
                "--dry-run",
            ],
            capture_output=True,
            text=True,
            check=False,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        report = json.loads(proc.stdout)
        self.assertTrue(report["ok"])
        self.assertIn("parallel_phases", report)

    def test_dry_run_solution_compare_includes_packaging(self) -> None:
        proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "dr_multi_ai_cli.py"),
                "compare IDPs",
                "--research-type",
                "solution-compare",
                "--dry-run",
            ],
            capture_output=True,
            text=True,
            check=False,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        report = json.loads(proc.stdout)
        self.assertIn("solution_packaging", report)
        self.assertEqual(report["solution_packaging"]["script"], "package_solution_outputs.py")

    def test_package_only_requires_solution_type(self) -> None:
        proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "dr_multi_ai_cli.py"),
                "default query",
                "--research-type",
                "default",
                "--package-only",
                "--output-root",
                "/tmp/sb-dr-package-contract",
            ],
            capture_output=True,
            text=True,
            check=False,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(proc.returncode, 2, proc.stdout)
        report = json.loads(proc.stdout)
        self.assertEqual(report["error_code"], "SOLUTION_PACKAGING_TYPE_MISMATCH")

    def test_consolidation_rejects_forbidden(self) -> None:
        proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "consolidate.py"),
                "--envelopes",
                str(SKILL_ROOT / "tests" / "fixtures" / "forbidden_envelope.json"),
                "--index",
                str(SKILL_ROOT / "tests" / "fixtures" / "minimal_index.json"),
                "--output",
                "/tmp/consolidation-out.json",
                "--resolved-pool",
                "2",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()

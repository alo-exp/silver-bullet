"""SPA profile routing tests for validate_spa_report.py."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
VALIDATOR = REPO_ROOT / "skills" / "silver-deep-research" / "scripts" / "validate_spa_report.py"
GEN_GENERAL = REPO_ROOT / "skills" / "silver-deep-research-multi-ai" / "scripts" / "generate_report.py"
GEN_LANDSCAPE = REPO_ROOT / "skills" / "silver-deep-research-multi-ai" / "scripts" / "generate_landscape_report.py"


class SpaProfileRoutingTests(unittest.TestCase):
    def test_general_profile_validates_dr_multi_ai_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "run_manifest.json").write_text(
                json.dumps({"query": "q", "research_type": "default", "mode": "deep"}) + "\n",
                encoding="utf-8",
            )
            subprocess.run([sys.executable, str(GEN_GENERAL), "--dir", str(root)], check=True)
            report = root / "report.html"
            proc = subprocess.run(
                [sys.executable, str(VALIDATOR), "--report", str(report), "--profile", "general"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn('"status": "pass"', proc.stdout)

    def test_landscape_profile_validates_landscape_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "run_manifest.json").write_text(
                json.dumps({"query": "q", "research_type": "solution-landscape", "mode": "deep"}) + "\n",
                encoding="utf-8",
            )
            subprocess.run(
                [sys.executable, str(GEN_LANDSCAPE), "--dir", str(root)],
                check=True,
                env={**os.environ, "SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"},
            )
            report = root / "landscape-report.html"
            proc = subprocess.run(
                [sys.executable, str(VALIDATOR), "--report", str(report), "--profile", "landscape"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_default_profile_validates_general_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "run_manifest.json").write_text(
                json.dumps({"query": "q", "research_type": "default", "mode": "deep"}) + "\n",
                encoding="utf-8",
            )
            subprocess.run([sys.executable, str(GEN_GENERAL), "--dir", str(root)], check=True)
            report = root / "report.html"
            proc = subprocess.run(
                [sys.executable, str(VALIDATOR), "--report", str(report)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_general_profile_does_not_require_multai_landscape_markers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "run_manifest.json").write_text(
                json.dumps({"query": "q", "research_type": "default", "mode": "deep"}) + "\n",
                encoding="utf-8",
            )
            subprocess.run([sys.executable, str(GEN_GENERAL), "--dir", str(root)], check=True)
            report = root / "report.html"
            text = report.read_text(encoding="utf-8")
            self.assertNotIn("data-sb-landscape-viewer", text)
            self.assertNotIn('id="sidebar"', text)
            proc = subprocess.run(
                [sys.executable, str(VALIDATOR), "--report", str(report), "--profile", "general"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "run_manifest.json").write_text(
                json.dumps({"query": "q", "research_type": "default", "mode": "deep"}) + "\n",
                encoding="utf-8",
            )
            proc = subprocess.run(
                [sys.executable, str(GEN_LANDSCAPE), "--dir", str(root)],
                capture_output=True,
                text=True,
                check=False,
                env={**os.environ, "SB_SKIP_LANDSCAPE_PDF": "1", "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1"},
            )
            self.assertNotEqual(proc.returncode, 0, proc.stdout)
            self.assertIn('"status": "error"', proc.stderr)


if __name__ == "__main__":
    unittest.main()



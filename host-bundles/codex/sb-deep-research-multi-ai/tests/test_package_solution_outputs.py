"""Package solution outputs for DR-multi-AI."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
PACKAGE = REPO_ROOT / "skills" / "silver-deep-research-multi-ai" / "scripts" / "package_solution_outputs.py"
COMPARE = REPO_ROOT / "skills" / "silver-deep-research" / "scripts" / "compare_solutions.py"


def _has_openpyxl() -> bool:
    try:
        import openpyxl  # noqa: F401

        return True
    except ImportError:
        return False


class PackageSolutionOutputsTests(unittest.TestCase):
    def _seed(self, root: Path) -> None:
        (root / "contributions").mkdir(parents=True)
        (root / "contributions" / "all-envelopes.json").write_text(
            json.dumps([
                {
                    "phase_id": "DR-RETRIEVE",
                    "logical_model_id": "test",
                    "payload": {
                        "evidence": [
                            {"claim": "alpha provides SSO."},
                            {"claim": "silver-bullet provides SSO."},
                            {"claim": "aider provides SSO."},
                        ]
                    },
                }
            ]) + "\n",
            encoding="utf-8",
        )
        (root / "run_manifest.json").write_text(
            json.dumps(
                {
                    "query": "Compare IDPs",
                    "research_type": "solution-compare",
                    "mode": "deep",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        (root / "need_profile.json").write_text(
            json.dumps(
                {
                    "category": "IDP",
                    "audience": "CTO",
                    "must_haves": [],
                    "persona_id": "startup",
                    "license_preference": "mixed",
                    "interview_complete": True,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        for name in ("alpha", "beta"):
            sol = root / "solutions" / name
            sol.mkdir(parents=True)
            (sol / "features.json").write_text(
                json.dumps(
                    {
                        "solution_name": name,
                        "categories": [
                            {
                                "name": "Core",
                                "features": [
                                    {"name": feature, "supported": True}
                                    for feature in (
                                        "Workflow composition",
                                        "Atomic flow catalog",
                                        "Parent/child agent delegation",
                                        "Hook-enforced gates",
                                        "Self-serve signup",
                                        "Quick onboarding",
                                        "IDE-native integration",
                                        "Skill/plugin marketplace",
                                        "Predictable pricing",
                                        "Free tier / OSS core",
                                        "Per-seat transparency",
                                        "Managed hosting",
                                        "Prebuilt SDLC templates",
                                        "Zero-infra bootstrap",
                                        "Automated review loops",
                                        "CI integration",
                                        "Visual/E2E verification",
                                        "SSO",
                                        "RBAC",
                                        "Audit log",
                                    )
                                ],
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

    @unittest.skipUnless(_has_openpyxl(), "openpyxl not installed")
    def test_package_emits_xlsx_and_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed(root)
            proc = subprocess.run(
                [sys.executable, str(PACKAGE), "--dir", str(root)],
                capture_output=True,
                text=True,
                check=False,
                env={
                    **os.environ,
                    "SB_SKIP_LANDSCAPE_PDF": "1",
                    "SB_ALLOW_SKIP_LANDSCAPE_PDF": "1",
                },
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            data = json.loads(proc.stdout)
            self.assertEqual(data["status"], "ok")
            slug = root.name
            self.assertTrue(
                (root / "comparison" / f"{slug}-comparison-matrix.xlsx").is_file()
            )
            self.assertTrue((root / "report.html").is_file())
            self.assertTrue((root / "landscape-report.html").is_file())


if __name__ == "__main__":
    unittest.main()

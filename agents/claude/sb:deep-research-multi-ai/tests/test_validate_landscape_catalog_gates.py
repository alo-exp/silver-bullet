"""Gate fail fixtures for catalog audit quality rules."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from validate_landscape_content import validate_landscape_content  # noqa: E402


def _minimal_comparison(*, rankings: list[dict] | None = None) -> dict:
    return {
        "winner": "silver-bullet",
        "rankings": rankings
        or [
            {"solution": "silver-bullet", "score": 25},
            {"solution": "ai-dlc", "score": 20},
        ],
        "rows": [
            {
                "type": "feature",
                "name": "Workflow composition",
                "priority": "Critical",
                "solutions": {"silver-bullet": True, "ai-dlc": True},
            },
            {
                "type": "feature",
                "name": "Hook-enforced gates",
                "priority": "Critical",
                "solutions": {"silver-bullet": True, "ai-dlc": False},
            },
            {
                "type": "feature",
                "name": "Atomic flow catalog",
                "priority": "Critical",
                "solutions": {"silver-bullet": True, "ai-dlc": True},
            },
        ],
    }


class CatalogGateFailTests(unittest.TestCase):
    def _write_fixture(
        self,
        root: Path,
        *,
        comparison: dict | None = None,
        audit: dict | None = None,
        md_extra: str = "",
        chart_mq: list | None = None,
    ) -> None:
        (root / "landscape").mkdir(parents=True)
        need = {
            "category": "Agentic SDLC Process Orchestrators",
            "category_pack_id": "agentic-sdlc-process-orchestrator",
            "must_haves": ["workflow composition"],
        }
        (root / "need_profile.json").write_text(json.dumps(need), encoding="utf-8")
        (root / "comparison" / "comparison.json").parent.mkdir(parents=True, exist_ok=True)
        (root / "comparison" / "comparison.json").write_text(
            json.dumps(comparison or _minimal_comparison()),
            encoding="utf-8",
        )
        audit = audit or {
            "pack_id": "agentic-sdlc-process-orchestrator",
            "core": ["silver-bullet", "ai-dlc"],
            "adjacent": ["devin"],
            "excluded": ["cline"],
            "sunset": [],
            "gaps": [],
            "counts": {},
        }
        (root / "landscape" / "catalog_audit.json").write_text(json.dumps(audit), encoding="utf-8")
        md = (
            "# Report\n\n## 1. Market Definition & Scope\n\n"
            "Out of scope: coding agents and host runtimes excluded from core.\n\n"
            "## 2. Market Overview\n\n## 3. Competitive Positioning\n\n### 3A.\n\n### 3B.\n\n"
            "## 4. Key Industry Trends\n\n## 5. Top Commercial\n\n## 6. Top OSS\n\n"
            "## 7. Adjacent Markets\n\n## 8. Explicitly Excluded\n\n"
            "## 9. Buying Guidance\n\n## 10. Future Outlook\n\n## 11. Source Reliability Assessment\n"
            + md_extra
        )
        (root / "landscape" / "landscape-report.md").write_text(md, encoding="utf-8")
        chart = {
            "mq_data": chart_mq or [{"label": "Silver Bullet", "x": 7, "y": 7, "q": "Leaders"}],
            "gmq_data": [{"label": "Silver Bullet", "x": 6, "y": 8, "q": "Leaders"}],
            "wave_data": [{"label": "Silver Bullet", "offering": 3, "strategy": 3, "presence": 2}],
            "titles": {"vc": "3D · Blue Ocean Value Curve (Leaders Radar)"},
        }
        (root / "landscape" / "chart-data.json").write_text(json.dumps(chart), encoding="utf-8")

    def test_passes_clean_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_fixture(root)
            result = validate_landscape_content(root)
            forbidden_errors = [e for e in result["errors"] if "forbidden slug" in e]
            self.assertEqual(forbidden_errors, [])

    def test_fails_forbidden_in_rankings(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            comp = _minimal_comparison(
                rankings=[
                    {"solution": "silver-bullet", "score": 25},
                    {"solution": "cline", "score": 10},
                ]
            )
            self._write_fixture(root, comparison=comp)
            result = validate_landscape_content(root)
            self.assertTrue(any("cline" in e and "forbidden" in e for e in result["errors"]))

    def test_fails_missing_catalog_audit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_fixture(root)
            (root / "landscape" / "catalog_audit.json").unlink()
            result = validate_landscape_content(root)
            self.assertTrue(any("catalog_audit.json missing" in e for e in result["errors"]))

    def test_fails_must_research_gaps_without_ack(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            audit = {
                "pack_id": "agentic-sdlc-process-orchestrator",
                "core": ["silver-bullet"],
                "adjacent": [],
                "excluded": [],
                "sunset": [],
                "gaps": ["zuvo", "agentsys"],
                "counts": {},
            }
            self._write_fixture(root, audit=audit)
            result = validate_landscape_content(root)
            self.assertTrue(any("must_research gaps" in e for e in result["errors"]))


if __name__ == "__main__":
    unittest.main()

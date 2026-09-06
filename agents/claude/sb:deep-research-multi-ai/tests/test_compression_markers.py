"""Compression marker sanitizer and packaging gate tests."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from compression_markers import (  # noqa: E402
    assert_no_compression_markers,
    contains_compression_markers,
    sanitize_compression_markers,
)
from landscape_preview_render import collect_landscape_payload  # noqa: E402
from synthesize_landscape import build_report_markdown  # noqa: E402


MARKER_SAMPLE = """landscape-report.md [838L]
Agentic SDLC orchestration Market Landscape Report
[444 more lines]
## 9. Source Reliability Assessment
... [lean-ctx: omitted 3 lines]
- Consensus claim with [Archived] marker
"""


class CompressionMarkerTests(unittest.TestCase):
    def test_contains_detects_lean_ctx_markers(self) -> None:
        self.assertTrue(contains_compression_markers(MARKER_SAMPLE))

    def test_sanitize_removes_marker_lines(self) -> None:
        cleaned = sanitize_compression_markers(MARKER_SAMPLE)
        self.assertFalse(contains_compression_markers(cleaned))
        self.assertIn("Source Reliability Assessment", cleaned)

    def test_assert_raises_on_markers(self) -> None:
        with self.assertRaises(ValueError):
            assert_no_compression_markers(MARKER_SAMPLE, context="test")

    def test_build_report_markdown_strips_consolidation_markers(self) -> None:
        consolidation = {
            "consensus": [{"text": "... [lean-ctx: omitted 2 lines] real consensus"}],
            "divergence": [{"text": "plain divergence"}],
        }
        md = build_report_markdown(
            category="Agentic SDLC Orchestration",
            platform_list="composer-2.5",
            scope_text="Scope without markers. Keep real consensus.",
            need={},
            comparison={"rows": [], "rankings": []},
            consolidation=consolidation,
            envelopes=[{"logical_model_id": "composer-2.5", "payload": {}}],
            claims=[],
            root=Path("/tmp/unused"),
            report_date="July 19, 2026",
        )
        self.assertFalse(contains_compression_markers(md))
        self.assertIn("real consensus", md)

    def test_collect_landscape_payload_sanitizes_marked_markdown(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            landscape = root / "landscape"
            landscape.mkdir(parents=True)
            (landscape / "landscape-report.md").write_text(MARKER_SAMPLE, encoding="utf-8")
            (root / "run_manifest.json").write_text(
                json.dumps({"research_type": "solution-landscape", "query": "q"}) + "\n",
                encoding="utf-8",
            )
            payload = collect_landscape_payload(root)
            self.assertFalse(contains_compression_markers(payload["markdown"]))

    def test_validate_landscape_content_fails_on_markers(self) -> None:
        from validate_landscape_content import validate_landscape_content

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            landscape = root / "landscape"
            landscape.mkdir(parents=True)
            (landscape / "landscape-report.md").write_text(MARKER_SAMPLE, encoding="utf-8")
            (root / "comparison").mkdir()
            (root / "comparison" / "comparison.json").write_text(
                json.dumps({"rows": [], "rankings": [{"solution": "alpha", "score": 1}]})
                + "\n",
                encoding="utf-8",
            )
            result = validate_landscape_content(root)
            self.assertEqual(result["status"], "fail")
            self.assertTrue(any("compression markers" in err for err in result["errors"]))


if __name__ == "__main__":
    unittest.main()

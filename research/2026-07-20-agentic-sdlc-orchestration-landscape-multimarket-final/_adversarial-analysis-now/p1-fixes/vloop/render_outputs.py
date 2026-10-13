#!/usr/bin/env python3
"""Regenerate landscape HTML+PDF after P1 plotted_slugs lockstep."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(REPO / "skills/silver-deep-research-multi-ai/scripts"))

from landscape_preview_render import render_landscape_outputs  # noqa: E402

ROOT = REPO / "research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final"


def main() -> int:
    result = render_landscape_outputs(ROOT)
    slim = {k: result[k] for k in result if k != "markers"}
    print(json.dumps(slim, indent=2))
    out = Path(__file__).resolve().parent / "render-result.json"
    out.write_text(json.dumps(slim, indent=2) + "\n", encoding="utf-8")
    return 0 if result.get("status") == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())

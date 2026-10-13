#!/usr/bin/env python3
"""Compatibility wrapper — landscape HTML+PDF via render_landscape_outputs()."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from skill_paths import ensure_multi_ai_scripts_on_path

ensure_multi_ai_scripts_on_path()
from landscape_preview_render import render_landscape_outputs  # noqa: E402


def _require_landscape_type(root: Path) -> None:
    manifest_path = root / "run_manifest.json"
    research_type = None
    if manifest_path.is_file():
        try:
            payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            payload = {}
        if isinstance(payload, dict):
            research_type = payload.get("research_type")
    if research_type not in {"solution-landscape", "solution-compare"}:
        raise ValueError(f"landscape report only for solution types, got {research_type!r}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate landscape-report.html + sibling PDF via render_landscape_outputs()"
    )
    parser.add_argument("--dir", required=True, help="Research root")
    parser.add_argument("--out", help="Output HTML path (default: <dir>/landscape-report.html)")
    parser.add_argument(
        "--profile",
        choices=["landscape"],
        default="landscape",
        help="Accepted for compatibility; landscape is the only profile",
    )
    args = parser.parse_args(argv)
    root = Path(args.dir)
    out = Path(args.out) if args.out else None
    try:
        _require_landscape_type(root)
        result = render_landscape_outputs(root, out=out)
    except (ValueError, FileNotFoundError) as exc:
        print(json.dumps({"status": "error", "reason": str(exc)}), file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

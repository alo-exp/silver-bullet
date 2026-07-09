#!/usr/bin/env python3
"""Static checks for serverless report.html — no localhost/http.server."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

FORBIDDEN = re.compile(
    r"http\.server|localhost:\d+|launch_report",
    re.IGNORECASE,
)
REQUIRED_MARKERS = [
    'id="report-data"',
    "data-tab-marker",
    "panel-overview",
    "panel-matrix",
]


def validate(path: Path) -> dict:
    errors: list[str] = []
    if not path.exists():
        return {"status": "fail", "errors": ["report.html missing"]}

    text = path.read_text(encoding="utf-8")
    if FORBIDDEN.search(text):
        errors.append("forbidden server/localhost reference in report.html")

    for marker in REQUIRED_MARKERS:
        if marker not in text:
            errors.append(f"missing tab/data marker: {marker}")

    if 'type="application/json"' not in text and "report-data" not in text:
        errors.append("missing inline JSON payload")

    return {"status": "pass" if not errors else "fail", "errors": errors}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, help="Path to report.html")
    args = parser.parse_args()
    result = validate(Path(args.report))
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "pass" else 1)


if __name__ == "__main__":
    main()

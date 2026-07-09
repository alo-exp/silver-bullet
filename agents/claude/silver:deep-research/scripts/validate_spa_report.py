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
SUBSTANTIVE_KEYS = frozenset({
    "title",
    "research_type",
    "need_profile",
    "comparison",
    "scrs",
})


def _extract_json_payload(text: str) -> tuple[str | None, str | None]:
    """Return (raw_json, error) from report-data script tag."""
    match = re.search(
        r'<script\s+type="application/json"\s+id="report-data">(.*?)</script>',
        text,
        re.DOTALL | re.IGNORECASE,
    )
    if not match:
        return None, "missing type=application/json report-data script block"
    return match.group(1).strip(), None


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

    raw_json, extract_err = _extract_json_payload(text)
    if extract_err:
        errors.append(extract_err)
    elif raw_json is not None:
        try:
            payload = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            errors.append(f"report-data JSON not parseable: {exc}")
        else:
            if not isinstance(payload, dict):
                errors.append("report-data payload must be a JSON object")
            elif not SUBSTANTIVE_KEYS.intersection(payload.keys()):
                errors.append(
                    "report-data JSON lacks substantive keys "
                    f"(expected one of: {', '.join(sorted(SUBSTANTIVE_KEYS))})"
                )

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

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
REQUIRED_MARKERS_GENERAL = [
    'id="report-data"',
    "data-tab-marker",
    "panel-overview",
    "panel-matrix",
]
REQUIRED_MARKERS_LANDSCAPE = [
    'id="report-data"',
    "data-sb-landscape-viewer",
    'id="sidebar"',
    'id="toc"',
    'id="exportBar"',
    "chart-frame",
    "landscape-matrix-panel",
]
# Profile routing: general (report.html) or landscape (landscape-report.html).
SUBSTANTIVE_KEYS_GENERAL = frozenset({
    "title",
    "research_type",
    "need_profile",
    "comparison",
    "scrs",
    "consolidation",
})
SUBSTANTIVE_KEYS_LANDSCAPE = frozenset({
    "title",
    "research_type",
    "need_profile",
    "comparison",
    "landscape",
    "markdown",
    "chart_data",
})
TABLE_DECLARE = re.compile(r"\b(?:let|var)\s+table\s*=")
INLINE_SCRIPT = re.compile(r"<script>(.*?)</script>", re.DOTALL | re.IGNORECASE)


def _check_matrix_js(text: str) -> list[str]:
    """Ensure matrix panel JS declares table before += concatenation."""
    errors: list[str] = []
    scripts = INLINE_SCRIPT.findall(text)
    if not scripts:
        return errors
    matrix_js = scripts[-1]
    if re.search(r"table\s*\+=", matrix_js) and not TABLE_DECLARE.search(matrix_js):
        errors.append("matrix JS uses table += without let/var table declaration")
    return errors


def _check_safe_json_escaping(raw_json: str, payload: dict) -> list[str]:
    """Assert safe_json_payload escaping for script-breaking characters."""
    errors: list[str] = []
    canonical = json.dumps(payload, ensure_ascii=False)
    if "<" in canonical and "<" in raw_json:
        errors.append("report-data must escape < as \\u003c in embedded JSON")
    if "\u2028" in canonical and "\\u2028" not in raw_json:
        errors.append("report-data must escape U+2028 as \\u2028 in embedded JSON")
    if "\u2029" in canonical and "\\u2029" not in raw_json:
        errors.append("report-data must escape U+2029 as \\u2029 in embedded JSON")
    return errors


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


def validate(path: Path, profile: str | None = None) -> dict:
    errors: list[str] = []
    if not path.exists():
        return {"status": "fail", "errors": ["report.html missing"]}

    text = path.read_text(encoding="utf-8")
    if FORBIDDEN.search(text):
        errors.append("forbidden server/localhost reference in report.html")

    if profile == "landscape":
        required = REQUIRED_MARKERS_LANDSCAPE
    elif profile == "general":
        required = REQUIRED_MARKERS_GENERAL
    else:
        required = REQUIRED_MARKERS_GENERAL

    for marker in required:
        if marker not in text:
            errors.append(f"missing tab/data marker: {marker}")

    if profile in {None, "general"}:
        errors.extend(_check_matrix_js(text))

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
            elif not (SUBSTANTIVE_KEYS_LANDSCAPE if profile == "landscape" else SUBSTANTIVE_KEYS_GENERAL).intersection(payload.keys()):
                errors.append(
                    "report-data JSON lacks substantive keys "
                    f"(expected one of: {', '.join(sorted(SUBSTANTIVE_KEYS_LANDSCAPE if profile == 'landscape' else SUBSTANTIVE_KEYS_GENERAL))})"
                )
            else:
                errors.extend(_check_safe_json_escaping(raw_json, payload))

    return {
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "profile": profile or "legacy-general",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, help="Path to report.html or landscape-report.html")
    parser.add_argument(
        "--profile",
        choices=["general", "landscape"],
        default="general",
        help="Validation profile (general for report.html, landscape for landscape-report.html)",
    )
    args = parser.parse_args()

    result = validate(Path(args.report), profile=args.profile)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "pass" else 1)


if __name__ == "__main__":
    main()



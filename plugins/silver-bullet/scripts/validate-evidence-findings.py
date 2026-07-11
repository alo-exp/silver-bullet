#!/usr/bin/env python3
"""Validate normalized finding tables in SB quality artifacts."""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# Allow import from scripts/lib when invoked as a script.
_LIB = Path(__file__).resolve().parent / "lib"
if str(_LIB) not in sys.path:
    sys.path.insert(0, str(_LIB))

from evidence_common import normalize_text  # noqa: E402

SEVERITY = {"BLOCK", "WARN", "INFO"}
CONFIDENCE = {"HIGH", "MEDIUM", "LOW"}
BLOCKING = {
    "blocks ship",
    "blocks release",
    "does not block",
    "needs user decision",
}

COLUMN_ALIASES: dict[str, set[str]] = {
    "domain": {"domain", "pack", "surface"},
    "scope": {"scope", "file", "target", "area", "location"},
    "severity": {"severity", "sev"},
    "confidence": {"confidence", "conf"},
    "evidence": {"evidence", "proof", "pointer"},
    "finding": {"finding", "issue", "description", "summary"},
    "required_action": {"required action", "required_action", "action", "required fix"},
    "owner_workflow": {"owner workflow", "owner_workflow", "owner", "workflow"},
    "blocking_status": {
        "blocking status",
        "blocking_status",
        "blocking",
        "ship impact",
    },
    "backlog_decision": {
        "backlog decision",
        "backlog_decision",
        "backlog",
        "deferral",
    },
}

REQUIRED_COLUMNS = [
    "domain",
    "scope",
    "severity",
    "confidence",
    "evidence",
    "finding",
    "required_action",
    "owner_workflow",
    "blocking_status",
]

ARTIFACT_GLOBS = [
    ".planning/**/DOMAIN-AUDIT.md",
    ".planning/**/REVIEW.md",
    ".planning/**/QUALITY-GATES.md",
    ".planning/**/SECURITY.md",
    ".planning/**/VERIFICATION.md",
    ".planning/**/UI-REVIEW.md",
    ".planning/**/TEST-ENGINEERING.md",
]

FINDING_SECTION_MARKERS = (
    "## findings",
    "## finding",
    "## quality findings",
    "## threat findings",
    "## gap findings",
    "## anti-pattern findings",
)


@dataclass
class Issue:
    level: str  # warn | error
    path: str
    message: str


@dataclass
class ValidationResult:
    issues: list[Issue] = field(default_factory=list)
    tables_checked: int = 0
    artifacts_scanned: int = 0

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "warn"]

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "error"]


def canonical_header(cell: str) -> str | None:
    key = normalize_text(cell.replace("_", " "))
    for canonical, aliases in COLUMN_ALIASES.items():
        if key in aliases:
            return canonical
    return None


def split_row(line: str) -> list[str]:
    inner = line.strip().strip("|")
    return [part.strip() for part in inner.split("|")]


def is_separator_row(cells: list[str]) -> bool:
    if not cells:
        return False
    return all(re.fullmatch(r":?-{3,}:?", c.replace(" ", "")) for c in cells if c)


def parse_table(lines: list[str], start: int) -> tuple[list[str], list[list[str]], int] | None:
    if start + 1 >= len(lines):
        return None
    header_cells = split_row(lines[start])
    if len(header_cells) < 3:
        return None
    sep_cells = split_row(lines[start + 1])
    if not is_separator_row(sep_cells):
        return None
    rows: list[list[str]] = []
    idx = start + 2
    while idx < len(lines):
        raw = lines[idx].strip()
        if not raw.startswith("|"):
            break
        cells = split_row(raw)
        if cells and any(cells):
            rows.append(cells)
        idx += 1
    return header_cells, rows, idx


def looks_like_finding_table(headers: list[str]) -> bool:
    canon = {canonical_header(h) for h in headers}
    canon.discard(None)
    return {"severity", "finding", "evidence"}.issubset(canon)


def in_findings_section(text: str, offset: int) -> bool:
    before = text[:offset].lower()
    for marker in FINDING_SECTION_MARKERS:
        if marker in before:
            # Only tables after the last findings marker count.
            return before.rfind(marker) > before.rfind("\n## ", 0, before.rfind(marker))
    return False


def discover_artifacts(root: Path) -> list[Path]:
    found: list[Path] = []
    for pattern in ARTIFACT_GLOBS:
        found.extend(sorted(root.glob(pattern)))
    # De-dupe while preserving order.
    seen: set[Path] = set()
    unique: list[Path] = []
    for path in found:
        if path in seen:
            continue
        seen.add(path)
        unique.append(path)
    return unique


def validate_table(
    result: ValidationResult,
    rel_path: str,
    headers: list[str],
    rows: list[list[str]],
    strict: bool,
) -> None:
    result.tables_checked += 1
    mapped: dict[int, str] = {}
    for idx, header in enumerate(headers):
        canon = canonical_header(header)
        if canon:
            mapped[idx] = canon

    present = set(mapped.values())
    missing = [col for col in REQUIRED_COLUMNS if col not in present]
    level = "error" if strict else "warn"
    if missing:
        result.issues.append(
            Issue(
                level=level,
                path=rel_path,
                message=f"finding table missing required columns: {', '.join(missing)}",
            )
        )

    for row_num, row in enumerate(rows, start=1):
        if all(not normalize_text(c) or normalize_text(c) in {"-", "n/a", "na", "tbd"} for c in row):
            continue
        values: dict[str, str] = {}
        for idx, cell in enumerate(row):
            if idx in mapped:
                values[mapped[idx]] = cell.strip()

        sev = values.get("severity", "").upper()
        if sev and sev not in SEVERITY:
            result.issues.append(
                Issue(
                    level=level,
                    path=rel_path,
                    message=f"row {row_num}: invalid severity '{values.get('severity', '')}'",
                )
            )

        conf = values.get("confidence", "").upper()
        if conf and conf not in CONFIDENCE:
            result.issues.append(
                Issue(
                    level=level,
                    path=rel_path,
                    message=f"row {row_num}: invalid confidence '{values.get('confidence', '')}'",
                )
            )

        blocking = normalize_text(values.get("blocking_status", ""))
        if blocking and blocking not in BLOCKING:
            result.issues.append(
                Issue(
                    level=level,
                    path=rel_path,
                    message=f"row {row_num}: invalid blocking_status '{values.get('blocking_status', '')}'",
                )
            )

        for required in ("finding", "evidence"):
            if required in present and not normalize_text(values.get(required, "")):
                result.issues.append(
                    Issue(
                        level=level,
                        path=rel_path,
                        message=f"row {row_num}: empty required field '{required}'",
                    )
                )


def validate_file(root: Path, path: Path, strict: bool, result: ValidationResult) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = str(path.relative_to(root))
    result.artifacts_scanned += 1
    lines = text.splitlines()
    idx = 0
    while idx < len(lines):
        line = lines[idx]
        if not line.strip().startswith("|"):
            idx += 1
            continue
        parsed = parse_table(lines, idx)
        if not parsed:
            idx += 1
            continue
        headers, rows, next_idx = parsed
        offset = sum(len(l) + 1 for l in lines[:idx])
        if looks_like_finding_table(headers) and (
            in_findings_section(text, offset) or looks_like_finding_table(headers)
        ):
            validate_table(result, rel, headers, rows, strict)
        idx = next_idx


def validate_repo(root: Path, strict: bool = False) -> ValidationResult:
    result = ValidationResult()
    for artifact in discover_artifacts(root):
        if artifact.is_file():
            validate_file(root, artifact, strict, result)
    return result


def format_text(result: ValidationResult) -> str:
    if not result.issues:
        return (
            f"Evidence schema validation passed "
            f"({result.artifacts_scanned} artifacts, {result.tables_checked} finding tables)."
        )
    lines = [
        f"Evidence schema validation: {len(result.warnings)} warning(s), "
        f"{len(result.errors)} error(s) "
        f"({result.artifacts_scanned} artifacts, {result.tables_checked} finding tables).",
    ]
    for issue in result.issues:
        prefix = "WARN" if issue.level == "warn" else "ERROR"
        lines.append(f"{prefix}: {issue.path} — {issue.message}")
    return "\n".join(lines)


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate SB evidence finding tables.")
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root (default: current directory)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat schema gaps as errors (default: warn-only)",
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    args = parser.parse_args(list(argv) if argv is not None else None)

    root = Path(args.root).resolve()
    result = validate_repo(root, strict=args.strict)

    if args.json:
        payload = {
            "passed": not result.errors and (args.strict or not result.warnings),
            "strict": args.strict,
            "artifacts_scanned": result.artifacts_scanned,
            "tables_checked": result.tables_checked,
            "warnings": [
                {"path": i.path, "message": i.message} for i in result.warnings
            ],
            "errors": [
                {"path": i.path, "message": i.message} for i in result.errors
            ],
        }
        print(json.dumps(payload, indent=2))
    else:
        print(format_text(result))

    if result.errors:
        return 1
    if args.strict and result.warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

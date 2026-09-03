#!/usr/bin/env python3
"""Canonical RFL issue ledger for review briefs (Policy G).

Residual-only means do not re-report ledger rows — not "file only one new ID."
The encoder emits the ledger from ISSUE-LEDGER.md and POLICY-C*.json so
launchers do not hand-maintain brief tables.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Iterable

LEDGER_COLUMNS = ("id", "severity", "decision", "resolved", "sha", "summary")
SEVERITIES = ("HIGH", "MED", "LOW", "NIT")
DECISIONS = ("ACCEPT", "REJECT")

_SHA_RE = re.compile(
    r"Freeze SHA after APPLY:\s*`([0-9a-fA-F]{8,64})`",
    re.IGNORECASE,
)
_HEADER_RE = re.compile(
    r"^\|\s*ID\s*\|\s*Severity\s*\|\s*Status\s*\|\s*Summary",
    re.IGNORECASE,
)
_SEP_RE = re.compile(r"^\|[\s:|-]+\|\s*$")
_POLICY_C_NAME_RE = re.compile(r"^POLICY-C(?:[-_].+)?\.json$", re.IGNORECASE)

RESIDUAL_ONLY_RULES = (
    "`--write-review-brief` is the **only legal review brief**. "
    "Hand-written one-ID briefs are non-compliant.",
    "Residual-only means **do not re-report ledger rows**, not "
    '"file only one new ID."',
    "File **all** valid residuals at the current SHA, **all severities** "
    "(HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if "
    "nothing valid remains.",
    "Triage still REJECTS invalid items (already encoded, false cite, "
    "KEEP REJECT collision). All **ACCEPT**ed items — including nits — "
    "are **APPLY'd as a pack** that pass (order-dependent findings together).",
    "Orthogonal to Policy F (ladder completion): 2 consecutive CLEAN on "
    "unchanged SHA; `accept-apply` still resets that rung's streak to 0.",
)


def _md_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def _norm_severity(raw: str) -> str:
    key = (raw or "").strip().upper()
    aliases = {"MEDIUM": "MED", "NITPICK": "NIT", "NITPICKS": "NIT", "LOW-NIT": "NIT"}
    key = aliases.get(key, key)
    return key if key in SEVERITIES else "LOW"


def _norm_decision(raw: str) -> str:
    key = (raw or "").strip().upper()
    if key in {"REJECT-AS-WRONG", "REJECT_AS_WRONG", "WRONG"}:
        return "REJECT"
    if key in DECISIONS:
        return key
    if "REJECT" in key:
        return "REJECT"
    if "ACCEPT" in key:
        return "ACCEPT"
    return key or "ACCEPT"


def _norm_resolved(raw: Any) -> str:
    if isinstance(raw, bool):
        return "yes" if raw else "no"
    key = str(raw or "").strip().lower()
    if key in {"yes", "y", "true", "applied", "done"}:
        return "yes"
    if key in {"n/a", "na", "—", "-"}:
        return "n/a"
    if key in {"no", "n", "false", "pending", ""}:
        return "no" if key else "no"
    return key


def _short_sha(sha: str) -> str:
    text = (sha or "").strip()
    if len(text) > 12:
        return text[:12]
    return text


def normalize_ledger_row(row: dict[str, Any]) -> dict[str, str]:
    summary = row.get("summary") or row.get("title") or row.get("one_line") or ""
    return {
        "id": str(row.get("id") or "").strip(),
        "severity": _norm_severity(str(row.get("severity") or "")),
        "decision": _norm_decision(str(row.get("decision") or row.get("status") or "")),
        "resolved": _norm_resolved(row.get("resolved")),
        "sha": str(row.get("sha") or row.get("apply_sha") or "").strip(),
        "summary": str(summary).strip().replace("\n", " "),
    }


def merge_ledger_rows(rows: Iterable[dict[str, Any]]) -> list[dict[str, str]]:
    by_id: dict[str, dict[str, str]] = {}
    extras: list[dict[str, str]] = []
    for raw in rows:
        row = normalize_ledger_row(raw)
        if not row["id"]:
            continue
        existing = by_id.get(row["id"])
        if existing is None:
            by_id[row["id"]] = row
            continue
        for key in LEDGER_COLUMNS:
            if key == "id":
                continue
            if key == "resolved":
                if existing["resolved"] != "yes" and row["resolved"] == "yes":
                    existing["resolved"] = "yes"
                elif existing["resolved"] in {"", "no"} and row["resolved"]:
                    existing["resolved"] = row["resolved"]
                continue
            if row[key] and (not existing[key] or len(row[key]) >= len(existing[key])):
                existing[key] = row[key]
    ordered = list(by_id.values()) + extras
    return ordered


def parse_issue_ledger_markdown(text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    current_sha = ""
    in_table = False
    for line in text.splitlines():
        sha_match = _SHA_RE.search(line)
        if sha_match:
            current_sha = sha_match.group(1)
        if _HEADER_RE.search(line):
            in_table = True
            continue
        if in_table and _SEP_RE.match(line):
            continue
        if in_table and line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 4:
                in_table = False
                continue
            ident, severity, status, summary = cells[0], cells[1], cells[2], cells[3]
            if ident in {"ID", "—", "-"} or ident.startswith("-"):
                continue
            rows.append(
                normalize_ledger_row(
                    {
                        "id": ident,
                        "severity": severity,
                        "decision": status,
                        "status": status,
                        "resolved": "yes" if _norm_decision(status) == "ACCEPT" else "n/a",
                        "sha": current_sha,
                        "summary": summary,
                    }
                )
            )
            continue
        if in_table:
            in_table = False
    return rows


def _iter_policy_c_files(run_dir: Path) -> list[Path]:
    files: list[Path] = []
    if not run_dir.is_dir():
        return files
    for path in sorted(run_dir.rglob("POLICY-C*.json")):
        if _POLICY_C_NAME_RE.match(path.name):
            files.append(path)
    return files


def parse_policy_c_payload(payload: dict[str, Any]) -> list[dict[str, str]]:
    sha = str(payload.get("apply_sha") or "").strip()
    titles: dict[str, str] = {}
    issues = payload.get("issues") or {}
    if isinstance(issues, dict):
        for sev, items in issues.items():
            if items is None or items in ("none", ""):
                continue
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                ident = str(item.get("id") or "").strip()
                if ident:
                    titles[ident] = str(item.get("title") or item.get("summary") or "")
    resolved_map: dict[str, str] = {}
    for item in payload.get("resolved") or []:
        if not isinstance(item, dict):
            continue
        ident = str(item.get("id") or "").strip()
        if ident:
            resolved_map[ident] = _norm_resolved(item.get("resolved"))
            titles.setdefault(ident, str(item.get("title") or item.get("summary") or ""))
    rows: list[dict[str, str]] = []
    triage = payload.get("triage") or []
    seen: set[str] = set()
    if isinstance(triage, list):
        for item in triage:
            if not isinstance(item, dict):
                continue
            ident = str(item.get("id") or "").strip()
            if not ident:
                continue
            seen.add(ident)
            rows.append(
                normalize_ledger_row(
                    {
                        "id": ident,
                        "severity": item.get("severity") or "",
                        "decision": item.get("decision") or "",
                        "resolved": resolved_map.get(ident, "no"),
                        "sha": sha,
                        "summary": titles.get(ident) or item.get("reason") or "",
                    }
                )
            )
    for ident, title in titles.items():
        if ident in seen:
            continue
        rows.append(
            normalize_ledger_row(
                {
                    "id": ident,
                    "severity": "",
                    "decision": "ACCEPT",
                    "resolved": resolved_map.get(ident, "no"),
                    "sha": sha,
                    "summary": title,
                }
            )
        )
    return rows


def collect_issue_ledger(
    *,
    run_dir: Path | None = None,
    rows: list[dict[str, Any]] | None = None,
) -> list[dict[str, str]]:
    collected: list[dict[str, str]] = []
    if rows:
        collected.extend(normalize_ledger_row(r) for r in rows if isinstance(r, dict))
    if run_dir is not None:
        ledger_md = Path(run_dir) / "ISSUE-LEDGER.md"
        if ledger_md.is_file():
            collected.extend(parse_issue_ledger_markdown(ledger_md.read_text(encoding="utf-8")))
        for policy_path in _iter_policy_c_files(Path(run_dir)):
            try:
                payload = json.loads(policy_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if isinstance(payload, dict):
                collected.extend(parse_policy_c_payload(payload))
        status_path = Path(run_dir) / "LADDER-STATUS.json"
        if status_path.is_file():
            try:
                status = json.loads(status_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                status = None
            if isinstance(status, dict):
                freeze = status.get("freeze") or {}
                freeze_sha = ""
                if isinstance(freeze, dict):
                    freeze_sha = str(freeze.get("sha256") or freeze.get("apply_sha") or "")
                for row in collected:
                    if freeze_sha and not row.get("sha"):
                        row["sha"] = freeze_sha
    return merge_ledger_rows(collected)


def render_issue_ledger(rows: list[dict[str, str]]) -> str:
    parts = [
        "## Issue ledger (already identified)",
        "",
        "| ID | Severity | Decision | Resolved | SHA | One-line |",
        "|----|----------|----------|----------|-----|----------|",
    ]
    if not rows:
        parts.append("| — | — | — | — | — | **none** |")
    else:
        for row in rows:
            parts.append(
                "| "
                f"{_md_cell(row.get('id', ''))} | "
                f"{_md_cell(row.get('severity', ''))} | "
                f"{_md_cell(row.get('decision', ''))} | "
                f"{_md_cell(row.get('resolved', ''))} | "
                f"{_md_cell(_short_sha(row.get('sha', '')))} | "
                f"{_md_cell(row.get('summary', ''))} |"
            )
    parts.append("")
    return "\n".join(parts)


def render_review_brief(rows: list[dict[str, str]]) -> str:
    parts = [
        "## Hop review (Policy G / pack-ledger)",
        "",
        *[f"- {rule}" for rule in RESIDUAL_ONLY_RULES],
        "",
        render_issue_ledger(rows).rstrip(),
        "",
        "Do **not** re-file ledger IDs unless a residual defect remains in **this** freeze.",
        "CLEAN only if the re-read finds nothing valid beyond the ledger.",
        "",
    ]
    return "\n".join(parts)


def write_review_brief(path: Path, rows: list[dict[str, str]]) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_review_brief(rows), encoding="utf-8")
    return path

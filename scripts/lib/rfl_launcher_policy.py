#!/usr/bin/env python3
"""RFL launcher policy: launch retry/skip, issue tables, ladder-complete matrix (pure library)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

RFL_SEVERITIES = ("HIGH", "MED", "LOW", "NIT")
LAUNCH_FAIL_OUTCOMES = frozenset({"cannot_launch", "timeout"})
LAUNCHER_MANDATORY_STEPS = (
    "policy_c_artifact",
    "issue_table",
    "launcher_triage",
    "triage_table",
    "launcher_fix",
    "resolved_table",
    "issue_ledger_brief",
    "ladder_complete_matrix",
)

SEVERITY_ALIASES: dict[str, str] = {
    "HIGH": "HIGH",
    "HIGHS": "HIGH",
    "BLOCKER": "HIGH",
    "BLOCKERS": "HIGH",
    "MED": "MED",
    "MEDIUM": "MED",
    "MEDIUMS": "MED",
    "LOW": "LOW",
    "LOWS": "LOW",
    "NIT": "NIT",
    "NITS": "NIT",
    "NITPICK": "NIT",
    "NITPICKS": "NIT",
}


def next_launch_action(
    *,
    attempts: int,
    outcome: str,
    phase: str = "rung",
) -> dict[str, Any]:
    """Launch/timeout retry: retry once immediately, then skip."""
    outcome_n = (outcome or "").strip().lower()
    phase_n = (phase or "rung").strip().lower()
    if attempts < 1:
        raise ValueError("attempts must be >= 1")
    if phase_n not in {"rung", "post_ladder"}:
        raise ValueError(f"unsupported phase {phase!r}")
    if outcome_n == "success":
        return {
            "action": "recovered" if phase_n == "post_ladder" else "continue",
            "outcome": outcome_n,
            "phase": phase_n,
            "attempts": attempts,
            "skipped": False,
            "retry": False,
            "retry_kind": None,
            "post_ladder_retry_pending": False,
            "post_ladder_retry_done": phase_n == "post_ladder",
        }
    if outcome_n not in LAUNCH_FAIL_OUTCOMES:
        raise ValueError(f"unsupported outcome {outcome!r}")
    if phase_n == "rung":
        if attempts <= 1:
            return {
                "action": "retry_immediate",
                "outcome": outcome_n,
                "phase": phase_n,
                "attempts": attempts,
                "skipped": False,
                "retry": True,
                "retry_kind": "immediate",
                "post_ladder_retry_pending": False,
                "post_ladder_retry_done": False,
            }
        return {
            "action": "skip",
            "outcome": outcome_n,
            "phase": phase_n,
            "attempts": attempts,
            "skipped": True,
            "retry": False,
            "retry_kind": None,
            "post_ladder_retry_pending": True,
            "post_ladder_retry_done": False,
        }
    return {
        "action": "remain_skipped",
        "outcome": outcome_n,
        "phase": phase_n,
        "attempts": attempts,
        "skipped": True,
        "retry": False,
        "retry_kind": None,
        "post_ladder_retry_pending": False,
        "post_ladder_retry_done": True,
    }


def skip_retry_artifact(
    *,
    rung: str | int,
    event: str,
    outcome: str,
    attempts: int,
    next_rung: str | int | None = None,
    phase: str = "rung",
) -> dict[str, Any]:
    """JSON + SKIPPED.md body for `.planning/rfl-*/rung-*/` so the launcher can present skip/retry."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    policy = next_launch_action(attempts=attempts, outcome=outcome, phase=phase)
    payload: dict[str, Any] = {
        "rung": rung,
        "next_rung": next_rung,
        "event": event or policy["action"],
        "outcome": outcome,
        "attempts": attempts,
        "phase": phase,
        "timestamp": now,
        **policy,
        "skipped_md": (
            (
                f"# SKIPPED — rung {rung}\n\n"
                f"- reason: `{outcome}`\n"
                f"- event: `{policy['action']}`\n"
                f"- attempts: {attempts}\n"
                f"- phase: `{phase}`\n"
                f"- timestamp: {now}\n"
                f"- next_rung: {next_rung if next_rung is not None else 'n/a'}\n"
                f"- post_ladder_retry_pending: {policy['post_ladder_retry_pending']}\n"
            )
        ),
    }
    return payload


def normalize_severity(raw: str) -> str:
    key = (raw or "").strip().upper()
    return SEVERITY_ALIASES.get(key, key if key in RFL_SEVERITIES else "LOW")


def _md_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def render_issue_table(issues: list[dict[str, Any]]) -> str:
    grouped: dict[str, list[dict[str, Any]]] = {sev: [] for sev in RFL_SEVERITIES}
    for issue in issues:
        sev = normalize_severity(str(issue.get("severity", "LOW")))
        grouped.setdefault(sev, []).append(issue)
    parts = ["## Reported issues (by severity)", ""]
    for sev in RFL_SEVERITIES:
        rows = grouped.get(sev, [])
        parts.append(f"### {sev}")
        parts.append("")
        parts.append("| ID | Title |")
        parts.append("|----|-------|")
        if not rows:
            parts.append("| — | **none** |")
        else:
            for issue in rows:
                parts.append(
                    f"| {_md_cell(issue.get('id', ''))} | {_md_cell(issue.get('title', ''))} |"
                )
        parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def render_triage_table(rows: list[dict[str, Any]]) -> str:
    parts = [
        "## Triage (launcher, not rung model)",
        "",
        "| ID | Severity | Decision | Reason |",
        "|----|----------|----------|--------|",
    ]
    if not rows:
        parts.append("| — | — | — | **none** |")
    else:
        for row in rows:
            decision = str(row.get("decision", "")).strip().upper()
            parts.append(
                "| "
                f"{_md_cell(row.get('id', ''))} | "
                f"{_md_cell(normalize_severity(str(row.get('severity', ''))))} | "
                f"{_md_cell(decision)} | "
                f"{_md_cell(row.get('reason', ''))} |"
            )
    parts.append("")
    return "\n".join(parts)


def render_resolved_table(rows: list[dict[str, Any]]) -> str:
    parts = [
        "## Resolved (after launcher ACCEPT fixes)",
        "",
        "| ID | Severity | Title | Decision | Resolved |",
        "|----|----------|-------|----------|----------|",
    ]
    if not rows:
        parts.append("| — | — | — | — | **none** |")
    else:
        for row in rows:
            resolved = row.get("resolved", "")
            if isinstance(resolved, bool):
                resolved = "yes" if resolved else "no"
            parts.append(
                "| "
                f"{_md_cell(row.get('id', ''))} | "
                f"{_md_cell(normalize_severity(str(row.get('severity', ''))))} | "
                f"{_md_cell(row.get('title', ''))} | "
                f"{_md_cell(str(row.get('decision', '')).upper())} | "
                f"{_md_cell(resolved)} |"
            )
    parts.append("")
    return "\n".join(parts)


def render_ladder_complete_matrix(rungs: list[dict[str, Any]]) -> str:
    parts = [
        "## Ladder-complete matrix",
        "",
        "| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |",
        "|------|----------|------|-----|-----|-----|----------|----------|",
    ]
    footnotes: list[str] = []
    tot_high = tot_med = tot_low = tot_nit = tot_reported = tot_accepted = 0
    for row in rungs:
        high = int(row.get("high", 0) or 0)
        med = int(row.get("med", 0) or 0)
        low = int(row.get("low", 0) or 0)
        nit = int(row.get("nit", 0) or 0)
        reported = int(row.get("reported", high + med + low + nit) or 0)
        accepted = int(row.get("accepted", 0) or 0)
        parts.append(
            "| "
            f"{_md_cell(row.get('rung', ''))} | "
            f"{_md_cell(row.get('reviewer', ''))} | "
            f"{high} | {med} | {low} | {nit} | {reported} | {accepted} |"
        )
        tot_high += high
        tot_med += med
        tot_low += low
        tot_nit += nit
        tot_reported += reported
        tot_accepted += accepted
        notes = []
        if row.get("clean"):
            notes.append("CLEAN")
        if row.get("id_collision"):
            notes.append("ID collision")
        if row.get("skipped_then_retried"):
            notes.append("skipped-then-retried")
        if notes:
            footnotes.append(f"- Rung {_md_cell(row.get('rung', ''))}: {'; '.join(notes)}")
    parts.append(
        f"| TOTAL | — | {tot_high} | {tot_med} | {tot_low} | {tot_nit} | "
        f"{tot_reported} | {tot_accepted} |"
    )
    parts.append("")
    parts.append(
        "Severity columns are reported counts. **Accepted** is after launcher triage "
        "(rejects excluded)."
    )
    parts.append("")
    if footnotes:
        parts.append("Footnotes:")
        parts.extend(footnotes)
        parts.append("")
    else:
        parts.append("Footnotes: none.")
        parts.append("")
    return "\n".join(parts)


def launcher_mandatory_steps() -> list[str]:
    return list(LAUNCHER_MANDATORY_STEPS)

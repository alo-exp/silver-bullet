"""Shared matrix scoring constants for compare_solutions and XLSX tools."""

from __future__ import annotations

from typing import Any

WEIGHTS: dict[str, int] = {
    "Critical": 5,
    "Very High": 4,
    "High": 3,
    "Medium": 2,
    "Low": 1,
}

TICK = "\u2714"


def priority_weight(priority: str) -> int:
    return WEIGHTS.get(priority, 1)


def score_solutions_from_rows(
    rows: list[dict[str, Any]],
    solutions: list[str],
) -> dict[str, int]:
    """Sum weighted ticks per solution from comparison row dicts."""
    scores = {s: 0 for s in solutions}
    for row in rows:
        if row.get("type") != "feature":
            continue
        wt = priority_weight(str(row.get("priority", "Medium")))
        sol_cells = row.get("solutions") or {}
        for sol in solutions:
            if sol_cells.get(sol) == TICK:
                scores[sol] += wt
    return scores

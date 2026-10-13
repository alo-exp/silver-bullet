#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
out = []
for i, line in enumerate(lines, 1):
    if any(k in line for k in (
        "known dead", "session.json", "classifies fresh", "retry -->",
        "exactly one", "escalated", "tui-unavailable", "probe",
        "--attach", "max-turns", "max-wall", "SB_AGENT_INTERACTION_MODE",
    )):
        out.append(f"{i}|{line}")
Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-02-deepseek-v4-pro-max/plan-hits.md").write_text("\n".join(out) + "\n")
print(len(out), "hits")

#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
for i, line in enumerate(lines, 1):
    if any(k in line for k in ("prior_result", "0-token", "D3 now true")):
        print(f"{i}|{line}")

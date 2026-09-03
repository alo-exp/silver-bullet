#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
for i, line in enumerate(lines, 1):
    if line.startswith("- **D") or line.strip().startswith("- NI:") or "Least overhead" in line:
        print(f"{i}|{line[:300]}")

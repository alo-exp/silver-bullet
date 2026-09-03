#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
for start, end in [(120, 175), (240, 290), (320, 360)]:
    print(f"\n===== {start}-{end} =====")
    for i in range(start-1, min(end, len(lines))):
        print(f"{i+1}|{lines[i]}")

#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
for n in range(8, 16):
    print(f"{n+1}|{lines[n]}")
print("====")
for n in [51, 72, 73, 74, 75, 77, 79]:
    print(f"{n+1}|{lines[n]}")
print("====80-85")
for n in range(79, 86):
    print(f"{n+1}|{lines[n]}")

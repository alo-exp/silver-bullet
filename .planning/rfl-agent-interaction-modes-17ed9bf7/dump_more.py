#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
for i in range(168, 195):
    print(f"{i+1}|{lines[i]}")
print("==== 248-295 ====")
for i in range(247, min(295, len(lines))):
    print(f"{i+1}|{lines[i]}")
print("==== 328-347 ====")
for i in range(327, min(347, len(lines))):
    print(f"{i+1}|{lines[i]}")

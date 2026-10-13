#!/usr/bin/env python3
from pathlib import Path
p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
lines = p.read_text().splitlines()
for i in range(8, 16):
    print(f"{i+1}|{lines[i]}")
print("---")
for i in range(50, 87):
    print(f"{i+1}|{lines[i]}")
print("---6---")
for i, line in enumerate(lines, start=1):
    if "6.2" in line or "SB_AGENT_MODE" in line or "Control directory" in line or "events.jsonl" in line or "AF-AGENT" in line or "interaction_mode" in line:
        print(f"{i}|{line[:240]}")

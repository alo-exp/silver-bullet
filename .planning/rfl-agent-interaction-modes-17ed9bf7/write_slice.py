#!/usr/bin/env python3
from pathlib import Path
src = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
lines = src.read_text().splitlines()
out = Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/plan-slice-275-340.md")
chunk = "\n".join(f"{i}|{lines[i-1]}" for i in range(175, 210)) + "\n\n" + "\n".join(f"{i}|{lines[i-1]}" for i in range(248, 340))
out.write_text(chunk + "\n")
print("wrote", out, "chars", len(chunk))

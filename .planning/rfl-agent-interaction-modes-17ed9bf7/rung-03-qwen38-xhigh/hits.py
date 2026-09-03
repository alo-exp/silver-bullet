#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
hits = []
for i, line in enumerate(lines, 1):
    if any(k in line.lower() for k in ("allow-mode-fallback", "clarify", "0-token", "prior_result", "escalation.md", "mode.json", "pid", "ctl.sh")):
        hits.append(f"{i}|{line[:240]}")
Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh/hits.md").write_text("\n".join(hits)+"\n")
print(len(hits))

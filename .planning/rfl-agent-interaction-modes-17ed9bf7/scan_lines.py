#!/usr/bin/env python3
from pathlib import Path
lines = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text().splitlines()
for i, line in enumerate(lines, 1):
    low = line.lower()
    if any(s in low for s in (
        "6.2.1", "invalid pair", "control-dir", "allow-mode-fallback",
        "interaction_mode", "auto_policy", "reply.fifo", "cmd.fifo",
        "sb_agent_", "mode.json", "### 5.1", "### 6.2", "### 6.3",
        "directive gains", "redact", "hook-trust",
    )):
        print(f"{i}|{line[:260]}")

#!/usr/bin/env python3
from pathlib import Path
text = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
for s in ["auto_policy", "hook-trust", "reply.fifo", "allow_mode_fallback", "process is known dead", "exactly one", "escalated", "retry -->", "Pi", "max-turns", "--attach"]:
    print(s, text.count(s))

#!/usr/bin/env python3
from pathlib import Path
text = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
for s in ["prior_result", "0-token", "zero_tokens", "D3 now true", "wave", "expect", "opencode"]:
    print(s, text.count(s))

#!/usr/bin/env python3
from pathlib import Path
t = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
print("D3 now true", "D3 now true" in t)
print("inherits", "inherits" in t and "wave" in t)
print("0-token", "0-token" in t)
print("prior_result.md", "prior_result.md" in t)
print("in-flight", "in-flight" in t)

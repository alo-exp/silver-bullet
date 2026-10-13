#!/usr/bin/env python3
from pathlib import Path
text = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
keys = [
    "6.2.1", "prior wave", "task-id", "events.jsonl", "mode.json", "reply.fifo",
    "auto_policy", "hook-trust", "allow-mode-fallback", "control-dir",
    "delegation-mode", "redact", "SB_AGENT_NO_ESCALATE", "no_escalate",
    "tui-unavailable", "sticky",
]
for k in keys:
    print(k, text.lower().count(k.lower()))
print("---- headings ----")
for i, line in enumerate(text.splitlines(), 1):
    if line.startswith("##") or line.startswith("###"):
        print(f"{i}|{line}")

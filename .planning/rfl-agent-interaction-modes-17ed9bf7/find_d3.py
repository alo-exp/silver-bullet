#!/usr/bin/env python3
from pathlib import Path
text = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
idx = text.find("D3")
print("idx", idx)
print(repr(text[idx-20:idx+80]) if idx>=0 else "no")
print("emdash count", text.count("\u2014"), "hyphen-D3", "D3 -" in text)

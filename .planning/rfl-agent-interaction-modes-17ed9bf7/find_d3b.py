#!/usr/bin/env python3
from pathlib import Path
text = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
needle = "Session continuity requires interactive"
idx = text.find(needle)
print("idx", idx)
print(repr(text[idx-30:idx+40]) if idx>=0 else "missing")
idx2 = text.find("**D3")
print("D3 bold", idx2, repr(text[idx2:idx2+60]) if idx2>=0 else "")

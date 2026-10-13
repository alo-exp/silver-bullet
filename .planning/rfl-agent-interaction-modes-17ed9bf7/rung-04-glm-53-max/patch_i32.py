#!/usr/bin/env python3
from pathlib import Path
p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
t = p.read_text()
# tighten D6: classifier-only NI fallback
old = None
for line in t.splitlines():
    if line.startswith("- **D6 —"):
        old = line
        break
if not old:
    raise SystemExit("no D6")
if "I-32" not in t[t.find(old):t.find(old)+800]:
    extra = " **D3 live-session (resolver step before classifier) is mandatory interactive:** TUI/session-id miss → `mode-unavailable`, not silent NI (I-32). Classifier-picked interactive without a live session may still NI `tui-unavailable`."
    t = t.replace(old, old.rstrip() + extra, 1)
    print("patched D6")
else:
    print("D6 already")
p.write_text(t)
print("len", len(t))

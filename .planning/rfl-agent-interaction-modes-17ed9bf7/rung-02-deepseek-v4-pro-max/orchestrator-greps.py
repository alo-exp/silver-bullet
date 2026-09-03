#!/usr/bin/env python3
import re
from pathlib import Path
plan = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
checks = [
    ("I-18 split liveness", r"resume-token|OS child still running"),
    ("I-19 escalate-unavailable", r"escalate-unavailable"),
    ("I-20 auto attach", r"interaction-mode auto.*attach|Interactive pin"),
    ("I-21 env auto not pin", r"requested-auto"),
    ("I-22 mermaid", r"retry --> pass"),
    ("I-23 Pi 2s probe", r"2s timeout"),
    ("I-24 wave-scoped wall", r"wave-scoped|wave_started_at"),
]
print("| ID | result |")
print("|----|--------|")
for name, pat in checks:
    print(f"| {name} | {'PASS' if re.search(pat, plan, re.I|re.S) else 'FAIL'} |")

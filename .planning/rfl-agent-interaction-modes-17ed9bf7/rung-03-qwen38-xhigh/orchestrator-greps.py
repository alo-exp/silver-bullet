#!/usr/bin/env python3
import re
from pathlib import Path
plan = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
for name, pat in [
    ("I-25 pin-only fallback", r"Not valid on D4|pin-only"),
    ("I-26 clarify/zero_tokens", r"clarify|zero_tokens"),
    ("I-27 classified null", r"classified` is `null`"),
    ("I-28 escalation.md NEXT", r"NEXT_RETRY_PROMPT"),
    ("I-30 pid kill -0", r"kill -0"),
    ("I-31 ctl status abort", r"status\|abort"),
]:
    print(name, "PASS" if re.search(pat, plan) else "FAIL")

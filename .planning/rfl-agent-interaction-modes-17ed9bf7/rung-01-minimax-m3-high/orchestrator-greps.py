#!/usr/bin/env python3
import re
from pathlib import Path

plan = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md").read_text()
checks = [
    ("V1 dual modes", r"non-interactive|interactive"),
    ("V2 auto default / pin", r"Default is auto|explicit pin|--interaction-mode"),
    ("V3 session continuity", r"Session continuity|live session"),
    ("V4 NI escalate", r"Auto NI miss|one interactive retry|auto-escalat"),
    ("V5 D7 overhead", r"Least overhead|native one-shot|No extra tmux"),
    ("V6 five hosts", r"Claude|Codex|Cursor|OpenCode|Pi"),
    ("V7 control interactive-only", r"Control directory \(interactive only|do not create `control/` in NI"),
    ("V8 mode_resolved", r"mode_resolved|mode\.json"),
    ("V9 no silent IX→NI", r"No silent interactive|mode-unavailable"),
    ("V10 impl deferred", r"after spec approval|Do not implement in this planning turn"),
    ("F-I1 interaction-mode flag", r"--interaction-mode"),
    ("F-I1 permission --mode", r"permission.*permissive\|strict|permissive\|strict"),
    ("F-I2 first-wave NI", r"first-wave implement\+test|Not a D3 signal"),
    ("F-I4 reset task-id", r"resets\*\* the task-id|classifies fresh"),
    ("F-I7 tui-unavailable", r"tui-unavailable"),
    ("F-I8 reliability wrappers", r"quota-retry|tail-idle"),
    ("F-I12 conflict table", r"6\.2\.1 Conflicting flag"),
    ("F-M1 auto_policy surface", r"--auto-policy|SB_AGENT_AUTO_POLICY"),
    ("F-M6 reply.fifo", r"reply\.fifo"),
    ("F-hook-trust catalog", r"hook-trust"),
]
print("| ID | result |")
print("|----|--------|")
for name, pat in checks:
    ok = re.search(pat, plan, re.I) is not None
    print(f"| {name} | {'PASS' if ok else 'FAIL'} |")

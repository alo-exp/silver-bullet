"""Exit 0 (printing "adapter") when a command is one literal SB skill-adapter call.

Usage: skill_adapter_invocation.py COMMAND | skill_adapter_invocation.py [-] < command.txt
Only ``[env] [NAME=value...] .../scripts/silver-bullet invoke-skill ...`` with literal
words qualifies: no second command, pipe, redirection or substitution ($(...), `...`).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

if not shell_analysis.is_skill_adapter_invocation(shell_analysis.read_input(sys.argv, 1)):
    raise SystemExit(1)
print("adapter")

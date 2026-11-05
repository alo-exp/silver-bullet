"""Exit 0 (printing "read-only") only when a shell command cannot change anything.

Usage: command_looks_read_only.py COMMAND | command_looks_read_only.py [-] < command.txt

This is an allowlist: every command, including those in substitutions, pipelines and
`sh -c` / `eval` code, must be a known read-only program with read-only arguments, and
nothing may be redirected into a file. Plain test-runner invocations (npm test, node
--test, jest...) also pass, as they always have; snapshot updates and inline code do not.
Anything unparseable or dynamic exits 1.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

if not shell_analysis.analyze_command(shell_analysis.read_input(sys.argv, 1))["read_only_legacy"]:
    raise SystemExit(1)
print("read-only")

"""Print the shell command of a hook payload.

Usage: tool_command_string.py PAYLOAD | tool_command_string.py [-] < payload.json
The payload is read from stdin when the argument is absent or "-": a payload larger
than the per-argument limit (128 KiB on Linux) cannot be passed on argv.
"""

import json
import shlex
import sys

if len(sys.argv) > 1 and sys.argv[1] != "-":
    raw = sys.argv[1]
else:
    raw = sys.stdin.read()

try:
    payload = json.loads(raw or "{}")
except ValueError:
    raise SystemExit(0)

tool_input = payload.get("tool_input") if isinstance(payload, dict) else None
if not isinstance(tool_input, dict):
    raise SystemExit(0)

command = tool_input.get("command")
if command is None:
    command = tool_input.get("cmd")
if isinstance(command, str):
    sys.stdout.write(command)
elif isinstance(command, list):
    sys.stdout.write(" ".join(shlex.quote(str(part)) for part in command))

import json
import shlex
import sys

try:
    payload = json.loads(sys.argv[1] or "{}")
except Exception:
    raise SystemExit(0)

tool_input = payload.get("tool_input")
if not isinstance(tool_input, dict):
    raise SystemExit(0)

command = tool_input.get("command")
if command is None:
    command = tool_input.get("cmd")
if isinstance(command, str):
    sys.stdout.write(command)
elif isinstance(command, list):
    sys.stdout.write(" ".join(shlex.quote(str(part)) for part in command))

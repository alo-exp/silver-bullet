import json
import re
import sys

try:
    payload = json.loads(sys.argv[1] or "{}")
except Exception:
    raise SystemExit(0)

tool_input = payload.get("tool_input")
if tool_input is None:
    raise SystemExit(0)

texts = []

def collect(value):
    if isinstance(value, str):
        texts.append(value)
    elif isinstance(value, dict):
        for item in value.values():
            collect(item)
    elif isinstance(value, list):
        for item in value:
            collect(item)

collect(tool_input)

seen = set()
for text in texts:
    for line in text.splitlines():
        match = re.match(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$", line)
        if not match:
            match = re.match(r"^\*\*\* Move to: (.+)$", line)
        if not match:
            continue
        path = match.group(1).strip()
        if path and path not in seen:
            seen.add(path)
            print(path)

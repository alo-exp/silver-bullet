"""Print the paths an apply_patch payload names (Add/Update/Delete File, Move to).

Usage: patch_paths.py PAYLOAD | patch_paths.py [-] < payload.json
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shell_analysis  # noqa: E402

try:
    payload = json.loads(shell_analysis.read_input(sys.argv, 1) or "{}")
except ValueError:
    raise SystemExit(0)

if isinstance(payload, dict) and payload.get("tool_input") is not None:
    for path in shell_analysis.patch_paths(payload["tool_input"]):
        print(path)

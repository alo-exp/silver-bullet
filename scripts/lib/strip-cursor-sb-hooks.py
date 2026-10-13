#!/usr/bin/env python3
"""Remove Silver Bullet hook entries from ~/.cursor/hooks.json; preserve non-SB hooks."""

from __future__ import annotations

import json
import os
import pathlib
import re
import sys

settings_path = pathlib.Path(
    sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), ".cursor", "hooks.json")
)

SB_HOOK_RE = re.compile(r"/silver-bullet/[^/]+/hooks/")
DEV_CHECKOUT_RE = re.compile(r"/plugins/silver-bullet/hooks/")


def is_sb_hook(entry: dict) -> bool:
    command = entry.get("command", "")
    if "codex-hook-adapter" in command and "cursor-hook-bridge" in command:
        return True
    if "${CURSOR_PLUGIN_ROOT}/hooks/" in command:
        return True
    if DEV_CHECKOUT_RE.search(command):
        return True
    return bool(SB_HOOK_RE.search(command))


if not settings_path.is_file():
    print(f"SKIP: no hooks file at {settings_path}")
    raise SystemExit(0)

data = json.loads(settings_path.read_text())
hooks_by_event = data.get("hooks", {})
changed = False

for event_name in list(hooks_by_event.keys()):
    entries = hooks_by_event[event_name]
    if not isinstance(entries, list):
        continue
    kept = [entry for entry in entries if not is_sb_hook(entry)]
    if len(kept) != len(entries):
        changed = True
    if kept:
        hooks_by_event[event_name] = kept
    else:
        del hooks_by_event[event_name]
        changed = True

if changed:
    settings_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"SB hooks stripped from {settings_path}")
else:
    print(f"No SB hooks found in {settings_path}")

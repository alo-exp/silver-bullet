#!/usr/bin/env python3
"""Idempotently merge Silver Bullet hooks from cursor-hooks.json into $HOME/.codex/hooks.json."""

from __future__ import annotations

import json
import os
import pathlib
import re
import shutil
import sys

install_path = sys.argv[1] if len(sys.argv) > 1 else ""
if not install_path:
    raise SystemExit("usage: merge-cursor-hooks.py <sb_install_path>")

hooks_src = os.path.join(install_path, "hooks", "cursor-hooks.json")
settings_path = os.path.join(os.path.expanduser("~"), ".cursor", "hooks.json")


def stable_install_path(raw_install_path: str) -> str:
    match = re.match(r"^(.*?/silver-bullet)/(\d+\.\d+\.\d+)$", raw_install_path)
    if not match:
        return raw_install_path
    versioned_path = pathlib.Path(raw_install_path)
    alias_path = pathlib.Path(match.group(1)) / "current"
    try:
        alias_path.parent.mkdir(parents=True, exist_ok=True)
        if alias_path.exists() or alias_path.is_symlink():
            if alias_path.is_dir() and not alias_path.is_symlink():
                shutil.rmtree(alias_path)
            else:
                alias_path.unlink()
        alias_path.symlink_to(versioned_path)
        return str(alias_path)
    except OSError:
        return raw_install_path


install_path = stable_install_path(install_path)
with open(hooks_src, encoding="utf-8") as handle:
    src = json.load(handle)

sb_hooks = src.get("hooks", {})


def sub_path(obj, root: str):
    if isinstance(obj, str):
        return obj.replace("${CURSOR_PLUGIN_ROOT}", root)
    if isinstance(obj, list):
        return [sub_path(item, root) for item in obj]
    if isinstance(obj, dict):
        return {key: sub_path(value, root) for key, value in obj.items()}
    return obj


sb_hooks = sub_path(sb_hooks, install_path)
SB_HOOK_RE = re.compile(r"/silver-bullet/[^/]+/hooks/")


def is_stale_sb_hook(entry: dict) -> bool:
    command = entry.get("command", "")
    if "${CURSOR_PLUGIN_ROOT}/hooks/" in command:
        return True
    return bool(SB_HOOK_RE.search(command)) and install_path not in command


if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as handle:
        settings = json.load(handle)
else:
    settings = {"version": 1, "hooks": {}}

settings.setdefault("version", 1)
existing_hooks = settings.setdefault("hooks", {})

for event, entries in list(existing_hooks.items()):
    if not isinstance(entries, list):
        continue
    cleaned = [entry for entry in entries if not is_stale_sb_hook(entry)]
    if cleaned:
        existing_hooks[event] = cleaned
    else:
        del existing_hooks[event]

for event, entries in sb_hooks.items():
    event_list = existing_hooks.setdefault(event, [])
    for new_entry in entries:
        new_cmd = new_entry.get("command", "")
        if not any(entry.get("command", "") == new_cmd for entry in event_list):
            event_list.append(new_entry)

pathlib.Path(settings_path).parent.mkdir(parents=True, exist_ok=True)
with open(settings_path, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2)
    handle.write("\n")

print("SB hooks registered in $HOME/.codex/hooks.json")

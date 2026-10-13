#!/usr/bin/env python3
"""Idempotently merge Silver Bullet hooks from cursor-hooks.json into ~/.cursor/hooks.json."""

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
DEV_CHECKOUT_RE = re.compile(r"/plugins/silver-bullet/hooks/")


def is_malformed_sb_hook(entry: dict) -> bool:
    command = entry.get("command", "")
    if "codex-hook-adapter" in command:
        return True
    return 'codex-hook-adapter.sh"' in command and "cursor-hook-bridge" in command


def is_stale_sb_hook(entry: dict) -> bool:
    command = entry.get("command", "")
    if is_malformed_sb_hook(entry):
        return True
    if "${CURSOR_PLUGIN_ROOT}/hooks/" in command:
        return True
    if DEV_CHECKOUT_RE.search(command) and install_path not in command:
        return True
    return bool(SB_HOOK_RE.search(command)) and install_path not in command


if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as handle:
        settings = json.load(handle)
else:
    settings = {"version": 1, "hooks": {}}

settings.setdefault("version", 1)
existing_hooks = settings.setdefault("hooks", {})


def merge_matchers(entries: list[dict]) -> str | None:
    """Return the union of Cursor matchers, or None for an unrestricted hook."""
    alternatives: list[str] = []
    for entry in entries:
        matcher = entry.get("matcher")
        if not matcher or matcher == ".*":
            return None
        for part in str(matcher).split("|"):
            part = part.strip()
            if part and part not in alternatives:
                alternatives.append(part)
    return "|".join(alternatives) or None


def deduplicate_hook_entries(entries: list) -> list:
    """Collapse repeated commands while preserving the union of their matchers."""
    result: list = []
    indexes: dict[str, int] = {}
    grouped: dict[str, list[dict]] = {}
    for item in entries:
        if not isinstance(item, dict) or not item.get("command"):
            result.append(item)
            continue
        command = str(item["command"])
        if command not in indexes:
            indexes[command] = len(result)
            grouped[command] = []
            result.append(item)
        grouped[command].append(item)

    for command, items in grouped.items():
        if len(items) == 1:
            continue
        merged = result[indexes[command]]
        matcher = merge_matchers(items)
        if matcher is None:
            merged.pop("matcher", None)
        else:
            merged["matcher"] = matcher
        timeouts = [
            item.get("timeout")
            for item in items
            if isinstance(item.get("timeout"), (int, float))
        ]
        if timeouts:
            merged["timeout"] = max(timeouts)
    return result


for event, entries in list(existing_hooks.items()):
    if not isinstance(entries, list):
        continue
    cleaned = [entry for entry in entries if not is_stale_sb_hook(entry)]
    cleaned = deduplicate_hook_entries(cleaned)
    if cleaned:
        existing_hooks[event] = cleaned
    else:
        del existing_hooks[event]


def hook_entry_key(entry: dict) -> tuple[str, str]:
    return (entry.get("command", ""), entry.get("matcher", ""))


for event, entries in sb_hooks.items():
    event_list = existing_hooks.setdefault(event, [])
    for new_entry in entries:
        new_key = hook_entry_key(new_entry)
        if not any(hook_entry_key(entry) == new_key for entry in event_list):
            event_list.append(new_entry)

pathlib.Path(settings_path).parent.mkdir(parents=True, exist_ok=True)
with open(settings_path, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2)
    handle.write("\n")

print("SB hooks registered in ~/.cursor/hooks.json")

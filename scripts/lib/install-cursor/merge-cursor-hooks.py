#!/usr/bin/env python3
"""Merge Silver Bullet's Cursor hooks into the user's hooks.json.

Usage: merge-cursor-hooks.py <sb_install_path>

Target: $CURSOR_HOME/hooks.json, default ~/.cursor/hooks.json. Every entry Silver Bullet
owns is removed and the install's hooks/cursor-hooks.json is appended as-is, so the merge
is idempotent (running it twice is a no-op), drops hooks a release removed and picks up
changed timeouts and matchers. An entry is Silver Bullet's when the program its command
runs lives in a Silver Bullet hooks directory (sb_host_config.is_sb_hook_command) or when
it calls codex-hook-adapter (left by an earlier, malformed merge). Every other entry is
kept exactly as it was, in order.

The file is written atomically (a symlink is followed, the mode kept, the previous content
saved as hooks.json.sb-backup) and only when it changes. An unparseable or wrongly typed
file is refused: exit 1, file untouched.
"""

from __future__ import annotations

import os
import pathlib
import re
import shutil
import sys

LIB_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LIB_DIR))
from sb_host_config import ConfigError, command_program, is_sb_hook_command, read_json, sb_hook_names, write_json  # noqa: E402

PLACEHOLDER = "${CURSOR_PLUGIN_ROOT}"
REPO_HOOKS = LIB_DIR.parents[1] / "hooks"


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


def shell_escaped(root: str) -> str:
    """``root`` with the characters a shell still expands inside double quotes escaped."""
    return re.sub(r'(["\\$`])', r"\\\1", root)


def sub_path(obj, root: str):
    if isinstance(obj, str):
        return obj.replace(PLACEHOLDER, root)
    if isinstance(obj, list):
        return [sub_path(item, root) for item in obj]
    if isinstance(obj, dict):
        return {key: sub_path(value, root) for key, value in obj.items()}
    return obj


def entry_command(entry) -> str:
    """Return the entry's command, or "" for non-dict entries / non-string commands."""
    if not isinstance(entry, dict):
        return ""
    command = entry.get("command", "")
    return command if isinstance(command, str) else ""


def json_member(data: dict, key: str, kind: type, label: str):
    """Return ``data[key]`` as ``kind``; repair missing/null/empty, refuse other wrong types."""
    value = data.get(key)
    if isinstance(value, kind):
        return value
    if value is None or value == {} or value == []:
        value = kind()
        data[key] = value
        return value
    name = "object" if kind is dict else "array"
    raise ConfigError(f"{label}: {key} must be a JSON {name}; left unchanged")


def cursor_hooks_path() -> tuple[str, str]:
    """The hooks.json to update and how to name it in messages."""
    default = os.path.join(os.path.expanduser("~"), ".cursor")
    cursor_home = os.environ.get("CURSOR_HOME") or default
    path = os.path.join(cursor_home, "hooks.json")
    return path, ("~/.cursor/hooks.json" if cursor_home == default else path)


def merge(raw_install_path: str) -> str:
    manifest_path = os.path.join(raw_install_path, "hooks", "cursor-hooks.json")
    manifest = read_json(manifest_path)
    if manifest is None:
        raise ConfigError(f"{manifest_path}: Silver Bullet hook manifest not found")
    sb_hooks = json_member(manifest, "hooks", dict, manifest_path)
    for event in sb_hooks:
        if not isinstance(sb_hooks[event], list):
            raise ConfigError(f"{manifest_path}: {event} must be a JSON array; nothing merged")

    install_path = stable_install_path(raw_install_path)
    sb_hooks = sub_path(sb_hooks, shell_escaped(install_path))
    install_roots = (install_path, raw_install_path, os.path.realpath(raw_install_path))
    names = sb_hook_names(pathlib.Path(raw_install_path) / "hooks", REPO_HOOKS)

    settings_path, display = cursor_hooks_path()
    settings = read_json(settings_path, default={"version": 1, "hooks": {}})
    settings.setdefault("version", 1)
    existing = json_member(settings, "hooks", dict, settings_path)

    def is_sb_entry(entry) -> bool:
        command = entry_command(entry)
        if "codex-hook-adapter" in command and "cursor-hook-bridge" in command:
            return True  # an earlier malformed merge (same rule as strip-cursor-sb-hooks.py)
        if os.path.basename(command_program(command)) == "codex-hook-adapter.sh":
            return True  # SB's adapter script (never a user script that merely shares a prefix)
        return is_sb_hook_command(command, hook_names=names, install_roots=install_roots)

    for event, entries in list(existing.items()):
        if not isinstance(entries, list):
            continue
        kept = [entry for entry in entries if not is_sb_entry(entry)]
        if kept:
            existing[event] = kept
        else:
            del existing[event]

    for event, entries in sb_hooks.items():
        json_member(existing, event, list, settings_path).extend(entries)

    write_json(settings_path, settings)
    return display


def main(argv) -> int:
    install_path = argv[1] if len(argv) > 1 else ""
    if not install_path:
        raise SystemExit("usage: merge-cursor-hooks.py <sb_install_path>")
    try:
        display = merge(install_path)
    except ConfigError as exc:
        raise SystemExit(f"merge-cursor-hooks: ERROR: {exc}") from exc
    print(f"SB hooks registered in {display}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

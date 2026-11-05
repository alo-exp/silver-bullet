#!/usr/bin/env python3
"""Remove stale Silver Bullet hook entries from a Claude settings.json.

Usage: prune-claude-settings.py <settings.json>

A hook entry is removed only when both hold:
  * Silver Bullet owns it: the program its command runs lives in a Silver Bullet hooks
    directory (sb_host_config.is_sb_hook_command), and
  * it is stale: that program no longer exists (an uninstalled or upgraded plugin cache), or
    it is the unexpanded ${CLAUDE_PLUGIN_ROOT} placeholder, which never resolves in user
    settings.
Every other hook stays: hooks whose paths use $HOME, ${CLAUDE_PROJECT_DIR} or a relative
path, and other tools' hooks (GSD's gsd-*.sh included), whatever their names.

A changed file is written atomically (a symlink is followed, the mode kept, the previous
content saved as settings.json.sb-backup) as a normalised JSON document: 2-space indent,
numbers re-serialised (2.50 -> 2.5) and duplicate keys collapsed to the last value. A file
with nothing to prune is not touched. Exit 1, file unchanged, on an unreadable or wrongly
typed file.
"""

from __future__ import annotations

import os
import pathlib
import sys

LIB_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(LIB_DIR))
from sb_host_config import (  # noqa: E402
    ConfigError,
    command_program,
    is_sb_hook_command,
    read_json,
    sb_hook_names,
    write_json,
)

HOOK_NAMES = sb_hook_names(LIB_DIR.parents[1] / "hooks")
PLACEHOLDER = "${CLAUDE_PLUGIN_ROOT}"


def stale_sb_hook(hook) -> bool:
    if not isinstance(hook, dict):
        return False
    command = hook.get("command")
    if not is_sb_hook_command(command, hook_names=HOOK_NAMES):
        return False
    program = command_program(command)
    if program.startswith(PLACEHOLDER):
        return True
    expanded = os.path.expandvars(os.path.expanduser(program))
    if "$" in expanded or not os.path.isabs(expanded):
        return False  # cannot be judged here: keep it
    return not os.path.isfile(expanded)


def prune(path: str) -> int:
    doc = read_json(path)
    if doc is None:
        return 0
    hooks = doc.get("hooks")
    if hooks is not None and not isinstance(hooks, dict):
        raise ConfigError(f'{path}: "hooks" is not an object; left unchanged')
    removed = 0
    for event, groups in list((hooks or {}).items()):
        if not isinstance(groups, list):
            continue
        kept_groups = []
        for group in groups:
            inner = group.get("hooks") if isinstance(group, dict) else None
            if not isinstance(inner, list) or not inner:
                kept_groups.append(group)  # not a populated hook group: foreign data
                continue
            kept = [hook for hook in inner if not stale_sb_hook(hook)]
            removed += len(inner) - len(kept)
            if len(kept) == len(inner):
                kept_groups.append(group)
            elif kept:
                kept_groups.append({**group, "hooks": kept})
        hooks[event] = kept_groups
    if removed:
        write_json(path, doc)
    return removed


def main(argv) -> int:
    path = argv[1]
    try:
        removed = prune(path)
    except (ConfigError, OSError) as exc:
        print(f"prune-stale-claude-user-hooks: ERROR: {exc}; {path} left unchanged", file=sys.stderr)
        return 1
    if removed:
        print(f"prune-stale-claude-user-hooks: removed {removed} stale Silver Bullet hook(s) from {path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

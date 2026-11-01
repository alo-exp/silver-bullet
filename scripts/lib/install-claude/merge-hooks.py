#!/usr/bin/env python3
"""Keep Silver Bullet's hooks in Claude Code's user settings correct (sb:init Phase 3.7.5).

Usage: merge-hooks.py <sb_install_path>

Claude Code loads an installed plugin's hooks/hooks.json by itself, and its documentation
says a plugin's copy of a handler stays separate from an identical settings handler; a copy
in settings.json therefore runs every hook a second time. So:

  * Silver Bullet is in Claude Code's plugin registry (<config>/plugins/installed_plugins.json):
    the plugin delivers the hooks. Silver Bullet's entries are removed from settings.json and
    nothing is added (R7-21).
  * Otherwise (a manual install or a workspace clone run from <sb_install_path>): every
    (event, matcher, command) of hooks/hooks.json is registered under its own matcher, after
    Silver Bullet's previous entries are removed (R7-29: a hook registered under several
    matchers keeps all of them).

<config> is $CLAUDE_CONFIG_DIR, default ~/.claude. An install path inside another host's
directory (.codex, .cursor) is not merged into Claude's settings. Silver Bullet's entries are
the ones whose program lives in a Silver Bullet hooks directory
(sb_host_config.is_sb_hook_command); every other entry is kept as it is. The settings file is
written atomically (symlink followed, mode kept, previous content in settings.json.sb-backup)
and only when it changes; an unparseable or wrongly typed one is refused (exit 1).
"""

from __future__ import annotations

import os
import pathlib
import re
import shutil
import sys

LIB_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LIB_DIR))
from sb_host_config import (  # noqa: E402
    ConfigError,
    is_sb_hook_command,
    read_json,
    remove_hooks,
    sb_hook_names,
    write_json,
)

PLACEHOLDER = "${CLAUDE_PLUGIN_ROOT}"
OTHER_HOST_RE = re.compile(r"/\.(?:codex|cursor)(?:/|$)")


def stable_install_path(raw_install_path: str) -> str:
    """Normalize versioned plugin cache paths to a stable alias."""
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


def sub_path(obj, root: str):
    if isinstance(obj, str):
        return obj.replace(PLACEHOLDER, root)
    if isinstance(obj, list):
        return [sub_path(item, root) for item in obj]
    if isinstance(obj, dict):
        return {key: sub_path(value, root) for key, value in obj.items()}
    return obj


def json_member(data: dict, key: str, kind: type, label: str):
    """Return data[key] as kind; repair missing/null/empty, refuse other wrong types."""
    value = data.get(key)
    if isinstance(value, kind):
        return value
    if value is None or value == {} or value == []:
        value = kind()
        data[key] = value
        return value
    name = "object" if kind is dict else "array"
    raise ConfigError(f"{label}: {key} must be a JSON {name}; left unchanged")


def plugin_delivered(config_dir: pathlib.Path) -> bool:
    registry = read_json(config_dir / "plugins" / "installed_plugins.json", default={})
    plugins = registry.get("plugins")
    return isinstance(plugins, dict) and any(str(key).split("@", 1)[0] == "silver-bullet" for key in plugins)


def merge(raw_install_path: str) -> str:
    if OTHER_HOST_RE.search(raw_install_path):
        return f"{raw_install_path} belongs to another host; Claude settings left unchanged"
    config_dir = pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude"))
    settings_path = config_dir / "settings.json"
    manifest_path = pathlib.Path(raw_install_path) / "hooks" / "hooks.json"
    manifest = read_json(manifest_path)
    if manifest is None:
        raise ConfigError(f"{manifest_path}: Silver Bullet hook manifest not found")
    sb_hooks = json_member(manifest, "hooks", dict, str(manifest_path))
    for event in sb_hooks:
        if not isinstance(sb_hooks[event], list):
            raise ConfigError(f"{manifest_path}: {event} must be a JSON array; nothing merged")

    delivered = plugin_delivered(config_dir)
    install_path = raw_install_path if delivered else stable_install_path(raw_install_path)
    names = sb_hook_names(pathlib.Path(raw_install_path) / "hooks", LIB_DIR.parents[1] / "hooks")
    roots = (install_path, raw_install_path, os.path.realpath(raw_install_path))

    settings = read_json(settings_path, default={})
    existing = json_member(settings, "hooks", dict, str(settings_path))
    for event in list(existing):
        json_member(existing, event, list, str(settings_path))
    removed = remove_hooks(existing, lambda hook: is_sb_hook_command(
        hook.get("command"), hook_names=names, install_roots=roots))

    if delivered:
        write_json(settings_path, settings)
        return (f"SB hooks are delivered by the Claude Code plugin; removed {removed} duplicate "
                f"settings entr{'y' if removed == 1 else 'ies'} from {settings_path}")

    for event, groups in sub_path(sb_hooks, install_path).items():
        event_list = json_member(existing, event, list, str(settings_path))
        for group in groups:
            event_list.append({"matcher": group.get("matcher", ""), "hooks": list(group.get("hooks", []))})
    write_json(settings_path, settings)
    return f"SB hooks registered in {settings_path}"


def main(argv) -> int:
    if len(argv) < 2 or not argv[1]:
        raise SystemExit("usage: merge-hooks.py <sb_install_path>")
    try:
        message = merge(argv[1])
    except ConfigError as exc:
        raise SystemExit(f"merge-hooks: ERROR: {exc}") from exc
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

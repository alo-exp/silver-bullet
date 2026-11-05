#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh

# Point Silver Bullet's record in Codex's installed_plugins.json at the stable
# cache/alo-labs-codex/silver-bullet/current alias, at the version just installed (the one
# `current` resolves to; the newest version directory when there is no alias yet). Only
# silver-bullet@alo-labs-codex is touched: other plugins' records, versions and cache
# directories belong to Codex and their authors (R7-08). An unparseable registry is refused.
sync_codex_installed_plugin_registry_paths() {
  local registry_file="${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json"

  [[ -f "$registry_file" ]] || return 0

  python3 - "$registry_file" "$CODEX_HOME_ROOT" "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import pathlib
import re
import shutil
import sys

registry_path = pathlib.Path(sys.argv[1])
home_root = pathlib.Path(sys.argv[2]).expanduser()
updated_at = sys.argv[3]
sys.path.insert(0, sys.argv[4])
from sb_host_config import ConfigError, read_json, write_json  # noqa: E402

plugin_id = "silver-bullet@alo-labs-codex"
plugin_root = home_root / ".codex" / "plugins" / "cache" / "alo-labs-codex" / "silver-bullet"
alias = plugin_root / "current"

try:
    data = read_json(registry_path, default={})
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}")
plugins = data.get("plugins")
entries = plugins.get(plugin_id) if isinstance(plugins, dict) else None
if not isinstance(entries, list) or not plugin_root.is_dir():
    sys.exit(0)


def version_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))


installed = alias.resolve() if alias.is_symlink() else None
if installed is None or not installed.is_dir() or installed.parent != plugin_root.resolve():
    versions = sorted(
        (path for path in plugin_root.iterdir()
         if path.name != "current" and path.is_dir() and not path.is_symlink()),
        key=version_key,
    )
    if not versions:
        sys.exit(0)
    installed = versions[-1]
    if alias.is_symlink() or alias.is_file():
        alias.unlink()
    elif alias.is_dir():
        shutil.rmtree(alias)  # a real directory left by an older Silver Bullet layout
    alias.symlink_to(installed)

for entry in entries:
    if isinstance(entry, dict):
        entry["installPath"] = str(alias)
        entry["version"] = installed.name
        entry["lastUpdated"] = updated_at
write_json(registry_path, data)
PY
}

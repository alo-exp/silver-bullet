#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
sync_codex_installed_plugin_registry_paths() {
  local registry_file="${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json"
  local updated_at
  local plugin_id
  local plugin_name
  local marketplace
  local current_path
  local stable_path
  local updates=()
  updated_at="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

  [[ -f "$registry_file" ]] || return 0

  updates=()
  while IFS= read -r plugin_id; do
    [[ -n "$plugin_id" ]] || continue
    [[ "$plugin_id" == *"@"* ]] || continue

    plugin_name="${plugin_id%@*}"
    marketplace="${plugin_id#*@}"
    current_path=""
    stable_path=""

    local cache_root="${CODEX_HOME_ROOT}/.codex/plugins/cache"
    if [[ -d "${cache_root}/${marketplace}/${plugin_name}" ]]; then
      current_path="$(find "${cache_root}/${marketplace}/${plugin_name}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    fi

    [[ -n "$current_path" ]] || continue
    python3 - "$current_path" "$marketplace" "$plugin_name" "$CODEX_HOME_ROOT" <<'PY'
import pathlib
import shutil
import sys

current_path = pathlib.Path(sys.argv[1])
marketplace = sys.argv[2]
plugin_name = sys.argv[3]
home_root = pathlib.Path(sys.argv[4]).expanduser()

alias_roots = [
    home_root / ".codex" / "plugins" / "cache" / marketplace / plugin_name / "current",
]

def refresh_alias(alias_path: pathlib.Path, target_path: pathlib.Path) -> None:
    alias_path.parent.mkdir(parents=True, exist_ok=True)
    if alias_path.exists() or alias_path.is_symlink():
        if alias_path.is_dir() and not alias_path.is_symlink():
            shutil.rmtree(alias_path)
        else:
            alias_path.unlink()
    alias_path.symlink_to(target_path)

target_path = current_path.resolve()
for alias_path in alias_roots:
    refresh_alias(alias_path, target_path)
PY
      stable_path="${CODEX_HOME_ROOT}/.codex/plugins/cache/${marketplace}/${plugin_name}/current"
      updates+=("${plugin_id}=${stable_path}|${current_path##*/}")
    done < <(python3 - "$registry_file" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
if not registry_path.is_file():
    sys.exit(0)

data = json.loads(registry_path.read_text())
for plugin_id in data.get("plugins", {}):
    print(plugin_id)
PY
    )

    [[ "${#updates[@]}" -gt 0 ]] || return 0

    python3 - "$registry_file" "$updated_at" "${updates[@]}" <<'PY'
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
updated_at = sys.argv[2]
updates = {}

for item in sys.argv[3:]:
    if "=" not in item:
        continue
    plugin_id, new_path = item.split("=", 1)
    updates[plugin_id] = new_path

data = json.loads(registry_path.read_text())
changed = False

for plugin_id, entries in data.get("plugins", {}).items():
    update = updates.get(plugin_id)
    if update is None:
        continue

    path_value, version = update.split("|", 1)
    new_path = pathlib.Path(path_value)
    if not new_path.is_dir():
        continue

    for entry in entries:
        entry["installPath"] = str(new_path)
        entry["version"] = version
        entry["lastUpdated"] = updated_at
        changed = True

if changed:
    registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}



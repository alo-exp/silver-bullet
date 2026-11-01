#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
install_silver_bullet_codex_cli() {
  local bin_dir="${CODEX_HOME_ROOT}/.codex/bin"
  local cli_path="${bin_dir}/silver-bullet"
  local package_root="${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet"
  local target_path="${package_root}/current/scripts/silver-bullet"
  local latest_dir

  if [[ ! -f "$target_path" ]]; then
    latest_dir="$(find "$package_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
    target_path="${latest_dir}/scripts/silver-bullet"
  fi

  [[ -f "$target_path" ]] || return 0

  mkdir -p "$bin_dir"
  cat > "$cli_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$target_path" "\$@"
EOF
  chmod 700 "$cli_path"
}


ensure_silver_bullet_registry_entry() {
  local registry_file="${CODEX_HOME_ROOT}/.codex/plugins/installed_plugins.json"

  python3 - "$registry_file" "$CODEX_HOME_ROOT" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" <<'PY'
import datetime
import json
import pathlib
import re
import shutil
import sys

registry_path = pathlib.Path(sys.argv[1])
home = pathlib.Path(sys.argv[2]).expanduser()
sys.path.insert(0, sys.argv[3])
from sb_host_config import ConfigError, read_json, write_json  # noqa: E402

now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
plugin_id = "silver-bullet@alo-labs-codex"
plugin_root = home / ".codex" / "plugins" / "cache" / "alo-labs-codex" / "silver-bullet"

if not plugin_root.exists():
    sys.exit(0)

# Refuse an unparseable or wrongly typed registry before touching anything: replacing it
# would drop every other plugin's record (R7-14).
try:
    data = read_json(registry_path, default={"version": 2, "plugins": {}})
    plugins = data.setdefault("plugins", {})
    if not isinstance(plugins, dict):
        raise ConfigError(f"{registry_path}: 'plugins' must be an object; left unchanged")
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}. Repair or move the file aside, then re-run install-codex.sh.")


def version_sort_key(path: pathlib.Path):
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))


version_dirs = sorted(
    [path for path in plugin_root.iterdir() if path.is_dir() and path.name != "current"],
    key=version_sort_key,
)
if not version_dirs:
    sys.exit(0)

target_path = version_dirs[-1]
current_path = plugin_root / "current"
if current_path.exists() or current_path.is_symlink():
    if current_path.is_dir() and not current_path.is_symlink():
        shutil.rmtree(current_path)
    else:
        current_path.unlink()
current_path.symlink_to(target_path)

plugin_version = target_path.name
plugin_json = target_path / ".codex-plugin" / "plugin.json"
if plugin_json.is_file():
    try:
        plugin_version = json.loads(plugin_json.read_text()).get("version", plugin_version)
    except Exception:
        pass

existing = plugins.get(plugin_id)
prior = existing[0] if isinstance(existing, list) and existing and isinstance(existing[0], dict) else {}
entry = {
    "scope": "user",
    "installPath": str(current_path),
    "version": plugin_version,
    "installedAt": prior.get("installedAt", now),
    "lastUpdated": now,
}

if prior:
    prior.update(entry)
    prior.pop("projectPath", None)
else:
    plugins[plugin_id] = [entry]

write_json(registry_path, data)
PY
}


# config.toml edits go through sb_host_config.TomlDocument (R7-09): tables are found by
# their key path whatever the header spacing, comments and other keys are kept, and a
# result that would not parse is never written.
#   _sb_codex_edit_config <file> set <table...> <key> <toml literal>
#   _sb_codex_edit_config <file> set-string <table...> <key> <string, escaped here>
#   _sb_codex_edit_config <file> remove <table...>
_sb_codex_edit_config() {
  local config_file="$1" action="$2"
  shift 2
  python3 - "$config_file" "$action" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" "$@" <<'PY'
import sys

config_path, action = sys.argv[1], sys.argv[2]
sys.path.insert(0, sys.argv[3])
args = sys.argv[4:]
from sb_host_config import ConfigError, read_toml, toml_string, write_toml  # noqa: E402

try:
    doc = read_toml(config_path)
    if action == "remove":
        doc.remove(lambda path: path[: len(args)] == tuple(args))
    else:
        literal = toml_string(args[-1]) if action == "set-string" else args[-1]
        doc.set_value(tuple(args[:-2]), args[-2], literal)
    write_toml(config_path, doc)
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}")
PY
}


ensure_plugin_enabled() {
  local plugin_spec="$1"
  _sb_codex_edit_config "$(resolve_codex_config_file)" set plugins "$plugin_spec" enabled true
}


ensure_feature_enabled() {
  local feature_name="$1"
  _sb_codex_edit_config "$(resolve_codex_config_file)" set features "$feature_name" true
}


remove_plugin_enabled() {
  local plugin_spec="$1"
  local config_file

  config_file="$(resolve_codex_config_file)"
  [[ -f "$config_file" ]] || return 0
  _sb_codex_edit_config "$config_file" remove plugins "$plugin_spec"
}

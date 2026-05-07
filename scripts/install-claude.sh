#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PURGE_LEGACY_PLUGINS=0
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/Users/shafqat/.local/bin/claude")}"
CLAUDE_GIT_HTTPS_REWRITE="${CLAUDE_GIT_HTTPS_REWRITE:-1}"
SB_MARKETPLACE_NAME="${SB_MARKETPLACE_NAME:-alo-labs}"
CLAUDE_SB_MARKETPLACE_SOURCE="${CLAUDE_SB_MARKETPLACE_SOURCE:-$REPO_ROOT}"
CLAUDE_SB_MARKETPLACE_PLUGIN="${CLAUDE_SB_MARKETPLACE_PLUGIN:-silver-bullet}"
CLAUDE_KW_MARKETPLACE_SOURCE="${CLAUDE_KW_MARKETPLACE_SOURCE:-https://github.com/anthropics/knowledge-work-plugins}"
CLAUDE_KW_MARKETPLACE_NAME="${CLAUDE_KW_MARKETPLACE_NAME:-knowledge-work-plugins}"
CLAUDE_KW_MARKETPLACE_PLUGINS=(
  "engineering"
  "design"
  "product-management"
)
SUPERPOWERS_MARKETPLACE_SOURCE="${SUPERPOWERS_MARKETPLACE_SOURCE:-https://github.com/obra/superpowers-marketplace.git}"
SUPERPOWERS_MARKETPLACE_NAME="${SUPERPOWERS_MARKETPLACE_NAME:-superpowers-marketplace}"
SUPERPOWERS_MARKETPLACE_PLUGIN="${SUPERPOWERS_MARKETPLACE_PLUGIN:-superpowers}"
LEGACY_PLUGINS=(
  "data-engineering@claude-plugins-official"
  "frontend-design@claude-plugins-official"
  "product-tracking-skills@claude-plugins-official"
)
TARGET_PLUGINS=(
  "superpowers@superpowers-marketplace"
  "engineering@knowledge-work-plugins"
  "design@knowledge-work-plugins"
  "product-management@knowledge-work-plugins"
  "silver-bullet@alo-labs"
)

usage() {
  cat <<'USAGE'
Usage: scripts/install-claude.sh [--purge-legacy-plugins]

Registers the Claude knowledge-work marketplaces, refreshes the Silver Bullet
plugin set, and optionally removes the legacy alias installs previously used
for Claude.

Options:
  --purge-legacy-plugins  Remove old alias plugin installs from Claude before reinstalling
USAGE
}

installed_plugins_json() {
  local cli="$1"
  "$cli" plugin list --json 2>/dev/null || printf '[]'
}

plugin_scopes() {
  local cli="$1"
  local plugin_id="$2"

  installed_plugins_json "$cli" \
    | jq -r --arg id "$plugin_id" '.[]? | select(.id == $id) | .scope' 2>/dev/null || true
}

marketplace_registered() {
  local marketplace="$1"
  local state_file="${HOME}/.claude/plugins/known_marketplaces.json"

  [[ -f "$state_file" ]] || return 1
  jq -e --arg name "$marketplace" 'has($name)' "$state_file" >/dev/null 2>&1
}

marketplace_catalog_has_plugin() {
  local marketplace="$1"
  local plugin_name="$2"
  local marketplace_json="${HOME}/.claude/plugins/marketplaces/${marketplace}/.claude-plugin/marketplace.json"

  [[ -f "$marketplace_json" ]] || return 1
  jq -e --arg name "$plugin_name" 'any(.plugins[]?; .name == $name)' "$marketplace_json" >/dev/null 2>&1
}

marketplace_source_matches() {
  local marketplace="$1"
  local source="$2"
  local state_file="${HOME}/.claude/plugins/known_marketplaces.json"

  [[ -f "$state_file" ]] || return 1

  if [[ "$source" == /* ]]; then
    jq -e --arg name "$marketplace" --arg path "$source" '
      has($name) and .[$name].source.source == "directory" and .[$name].source.path == $path
    ' "$state_file" >/dev/null 2>&1
    return $?
  fi

  jq -e --arg name "$marketplace" --arg source "$source" '
    has($name) and (
      (.[$name].source.source == "github" and (.[$name].source.repo == $source or ("https://github.com/" + .[$name].source.repo) == $source)) or
      (.[$name].source.source == "git" and .[$name].source.url == $source)
    )
  ' "$state_file" >/dev/null 2>&1
}

ensure_marketplace_ready() {
  local marketplace="$1"
  local source="$2"
  shift 2
  local plugin_name
  local source_matches=0
  local has_expected_plugin=1

  if marketplace_registered "$marketplace" && marketplace_source_matches "$marketplace" "$source"; then
    source_matches=1
    has_expected_plugin=0
    for plugin_name in "$@"; do
      if ! marketplace_catalog_has_plugin "$marketplace" "$plugin_name"; then
        has_expected_plugin=1
        break
      fi
    done
  fi

  if [[ "$source_matches" -eq 0 || "$has_expected_plugin" -eq 1 ]]; then
    if marketplace_registered "$marketplace"; then
      "$CLAUDE_BIN" plugin marketplace remove "$marketplace" >/dev/null 2>&1 || true
    fi
    "$CLAUDE_BIN" plugin marketplace add "$source"
  else
    "$CLAUDE_BIN" plugin marketplace update "$marketplace" >/dev/null
  fi
}

uninstall_plugin_scope() {
  local plugin_id="$1"
  local scope="$2"

  "$CLAUDE_BIN" plugin uninstall "$plugin_id" --scope "$scope" >/dev/null 2>&1 || true
}

purge_legacy_plugins() {
  local plugin_id
  local scope

  for plugin_id in "${LEGACY_PLUGINS[@]}"; do
    while IFS= read -r scope; do
      [[ -n "$scope" ]] || continue
      uninstall_plugin_scope "$plugin_id" "$scope"
    done < <(plugin_scopes "$CLAUDE_BIN" "$plugin_id")
  done
}

purge_plugin_cache() {
  local plugin_id="$1"
  local marketplace="${plugin_id#*@}"
  local name="${plugin_id%@*}"
  local cache_dir="${HOME}/.claude/plugins/cache/${marketplace}/${name}"

  rm -rf "$cache_dir"
}

sync_silver_bullet_settings_paths() {
  local settings_file="${HOME}/.claude/settings.json"
  local plugin_cache_root="${HOME}/.claude/plugins/cache/alo-labs/silver-bullet"
  local current_version_dir=""

  [[ -f "$settings_file" ]] || return 0
  [[ -d "$plugin_cache_root" ]] || return 0

  current_version_dir="$(find "$plugin_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
  [[ -n "$current_version_dir" ]] || return 0

  python3 - "$settings_file" "$plugin_cache_root" "$current_version_dir" <<'PY'
import json
import pathlib
import re
import sys

settings_path = pathlib.Path(sys.argv[1])
cache_root = sys.argv[2].rstrip("/")
current_version_dir = sys.argv[3].rstrip("/")

try:
    data = json.loads(settings_path.read_text())
except Exception:
    sys.exit(0)

path_pattern = re.compile(re.escape(cache_root) + r"/[^/\"]+")

def rewrite(value):
    if isinstance(value, str):
        return path_pattern.sub(current_version_dir, value)
    if isinstance(value, list):
        return [item for item in (rewrite(item) for item in value) if item is not None]
    if isinstance(value, dict):
        rewritten = {}
        for key, item in value.items():
            new_item = rewrite(item)
            if new_item is None:
                continue
            if key == "hooks" and isinstance(new_item, list):
                new_item = [hook for hook in new_item if hook is not None]
                if not new_item:
                    continue
            rewritten[key] = new_item
        return rewritten
    return value

updated = rewrite(data)
settings_path.write_text(json.dumps(updated, indent=2) + "\n")
PY
}

refresh_plugin_install() {
  local plugin_id="$1"
  local scope

  while IFS= read -r scope; do
    [[ -n "$scope" ]] || continue
    uninstall_plugin_scope "$plugin_id" "$scope"
  done < <(plugin_scopes "$CLAUDE_BIN" "$plugin_id")

  purge_plugin_cache "$plugin_id"
  "$CLAUDE_BIN" plugin install "$plugin_id" --scope user >/dev/null
}

ensure_legacy_skill_alias() {
  local alias_name="$1"
  local marketplace="$2"
  local plugin_name="$3"
  local cache_root="${HOME}/.claude/plugins/cache"
  local target_root="${cache_root}/${marketplace}/${plugin_name}"
  local alias_root="${cache_root}/${alias_name}"
  local version_dir=""

  if [[ ! -d "$target_root" ]]; then
    return 0
  fi

  version_dir="$(find "$target_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
  if [[ -z "$version_dir" || ! -d "${version_dir}/skills" ]]; then
    return 0
  fi

  mkdir -p "$alias_root"
  ln -sfn "${version_dir}/skills" "${alias_root}/skills"
}

sync_silver_bullet_hook_cache() {
  local cache_root="${HOME}/.claude/plugins/cache/alo-labs/silver-bullet"
  local current_version_dir=""

  [[ -d "$cache_root" ]] || return 0
  current_version_dir="$(find "$cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
  [[ -n "$current_version_dir" ]] || return 0

  install -d -m 755 "${current_version_dir}/hooks"
  install -m 755 "${REPO_ROOT}/hooks/session-start" "${current_version_dir}/hooks/session-start"
  install -m 755 "${REPO_ROOT}/hooks/spec-session-record.sh" "${current_version_dir}/hooks/spec-session-record.sh"
}

ensure_github_https_rewrite() {
  [[ "$CLAUDE_GIT_HTTPS_REWRITE" == "1" ]] || return 0

  local rewrite_value
  rewrite_value='https://github.com/'

  if ! git config --global --get-all url."${rewrite_value}".insteadOf | grep -qx 'git@github.com:'; then
    git config --global --add url."${rewrite_value}".insteadOf 'git@github.com:'
  fi

  if ! git config --global --get-all url."${rewrite_value}".insteadOf | grep -qx 'ssh://git@github.com/'; then
    git config --global --add url."${rewrite_value}".insteadOf 'ssh://git@github.com/'
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-legacy-plugins) PURGE_LEGACY_PLUGINS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$CLAUDE_BIN" ]] || [[ ! -x "$CLAUDE_BIN" ]]; then
  printf 'ERROR: claude CLI not found in PATH\n' >&2
  exit 1
fi

ensure_github_https_rewrite
ensure_marketplace_ready "$SB_MARKETPLACE_NAME" "$CLAUDE_SB_MARKETPLACE_SOURCE" "$CLAUDE_SB_MARKETPLACE_PLUGIN"
ensure_marketplace_ready "$CLAUDE_KW_MARKETPLACE_NAME" "$CLAUDE_KW_MARKETPLACE_SOURCE" "${CLAUDE_KW_MARKETPLACE_PLUGINS[@]}"
ensure_marketplace_ready "$SUPERPOWERS_MARKETPLACE_NAME" "$SUPERPOWERS_MARKETPLACE_SOURCE" "$SUPERPOWERS_MARKETPLACE_PLUGIN"

if [[ "$PURGE_LEGACY_PLUGINS" -eq 1 ]]; then
  purge_legacy_plugins
fi

for plugin_id in "${TARGET_PLUGINS[@]}"; do
  refresh_plugin_install "$plugin_id"
done

sync_silver_bullet_hook_cache
sync_silver_bullet_settings_paths

ensure_legacy_skill_alias "product-management" "knowledge-work-plugins" "product-management"
ensure_legacy_skill_alias "engineering" "knowledge-work-plugins" "engineering"
ensure_legacy_skill_alias "design" "knowledge-work-plugins" "design"

printf 'Claude marketplaces registered from %s\n' "$REPO_ROOT"

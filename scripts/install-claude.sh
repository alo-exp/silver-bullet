#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${REPO_ROOT}/hooks/lib/rtk-compat.sh"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
# shellcheck source=scripts/lib/plugin-cache-version.sh
source "${REPO_ROOT}/scripts/lib/plugin-cache-version.sh"
PURGE_LEGACY_PLUGINS=0
PUBLIC_RELEASE_ONLY=0
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
CLAUDE_SETTINGS_HOME="${CLAUDE_SETTINGS_HOME:-${HOME}/.claude}"
CLAUDE_SB_PLUGIN_CACHE="${CLAUDE_SB_PLUGIN_CACHE:-${CLAUDE_HOME}/plugins/cache/alo-labs/silver-bullet}"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/Users/shafqat/.local/bin/claude")}"
CLAUDE_GIT_HTTPS_REWRITE="${CLAUDE_GIT_HTTPS_REWRITE:-1}"
SB_MARKETPLACE_NAME="${SB_MARKETPLACE_NAME:-alo-labs}"
CLAUDE_SB_MARKETPLACE_SOURCE="${CLAUDE_SB_MARKETPLACE_SOURCE:-$REPO_ROOT}"
CLAUDE_SB_PUBLIC_MARKETPLACE_SOURCE="${CLAUDE_SB_PUBLIC_MARKETPLACE_SOURCE:-https://github.com/alo-labs/agent-plugins.git}"
CLAUDE_SB_MARKETPLACE_PLUGIN="${CLAUDE_SB_MARKETPLACE_PLUGIN:-silver-bullet}"
LEGACY_PLUGINS=(
  "data-engineering@claude-plugins-official"
  "frontend-design@claude-plugins-official"
  "product-tracking-skills@claude-plugins-official"
)
TARGET_PLUGINS=(
  "silver-bullet@alo-labs"
)
AGENT_RENDERER="${REPO_ROOT}/scripts/render-agent-bundle.py"

usage() {
  cat <<'USAGE'
Usage: scripts/install-claude.sh [--purge-legacy-plugins] [--public-release]

Registers the Silver Bullet Claude marketplace, refreshes the Silver Bullet
plugin set, and optionally removes legacy alias installs previously used for
Claude.

Options:
  --purge-legacy-plugins  Remove old alias plugin installs from Claude before reinstalling
  --public-release        Refresh from the published marketplace instead of the local checkout
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
  local state_file="${CLAUDE_HOME}/plugins/known_marketplaces.json"

  [[ -f "$state_file" ]] || return 1
  jq -e --arg name "$marketplace" 'has($name)' "$state_file" >/dev/null 2>&1
}

marketplace_catalog_has_plugin() {
  local marketplace="$1"
  local plugin_name="$2"
  local marketplace_json="${CLAUDE_HOME}/plugins/marketplaces/${marketplace}/.claude-plugin/marketplace.json"

  [[ -f "$marketplace_json" ]] || return 1
  jq -e --arg name "$plugin_name" 'any(.plugins[]?; .name == $name)' "$marketplace_json" >/dev/null 2>&1
}

marketplace_source_matches() {
  local marketplace="$1"
  local source="$2"
  local state_file="${CLAUDE_HOME}/plugins/known_marketplaces.json"

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

# Materialize Silver Bullet into the Claude plugin cache from a local checkout when
# `claude plugin install` cannot fetch GitHub (schema drift, offline, etc.).
materialize_local_silver_bullet_plugin_cache() {
  local version plugin_cache_root version_dir stable_alias registry
  version="$(jq -r '.version // "0.0.0"' "${REPO_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || echo 0.0.0)"
  plugin_cache_root="${CLAUDE_SB_PLUGIN_CACHE}"
  version_dir="${plugin_cache_root}/${version}"
  stable_alias="${plugin_cache_root}/current"
  registry="${CLAUDE_HOME}/plugins/installed_plugins.json"

  mkdir -p "$version_dir/.claude-plugin" "${version_dir}/agents/claude" "${version_dir}/hooks"
  install -m 644 "${REPO_ROOT}/.claude-plugin/plugin.json" "${version_dir}/.claude-plugin/plugin.json"
  rsync -a --delete "${REPO_ROOT}/hooks/" "${version_dir}/hooks/"
  rsync -a --delete "${REPO_ROOT}/agents/claude/" "${version_dir}/agents/claude/"
  ln -sfn "agents/claude" "${version_dir}/skills"
  rm -rf "${version_dir}/commands" 2>/dev/null || true
  prune_claude_cross_host_agent_surfaces "$version_dir"

  python3 - "$registry" "$version" "$stable_alias" <<'PY'
import json
import pathlib
import sys

registry = pathlib.Path(sys.argv[1])
version = sys.argv[2]
stable = pathlib.Path(sys.argv[3]).resolve()

data = {"plugins": {}}
if registry.is_file():
    try:
        data = json.loads(registry.read_text())
    except Exception:
        data = {"plugins": {}}
plugins = data.setdefault("plugins", {})
plugins["silver-bullet@alo-labs"] = [{
    "version": version,
    "installPath": str(stable),
    "scope": "user",
}]
registry.parent.mkdir(parents=True, exist_ok=True)
registry.write_text(json.dumps(data, indent=2) + "\n")
PY

  refresh_silver_bullet_install_alias
}

render_agent_bundle() {
  local agent="$1"

  mkdir -p "${REPO_ROOT}/agents"
  python3 "$AGENT_RENDERER" render \
    --agent "$agent" \
    --source-root "${REPO_ROOT}/skills" \
    --dest-root "${REPO_ROOT}/agents/${agent}"
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
  local cache_dir="${CLAUDE_HOME}/plugins/cache/${marketplace}/${name}"
  local attempt=0

  # Drop stable alias before purge — concurrent install / claude CLI can race with plain rm.
  rm -f "${cache_dir}/current" 2>/dev/null || true

  while (( attempt < 5 )); do
    if rm -rf "$cache_dir" 2>/dev/null; then
      return 0
    fi
    sleep 0.3
    attempt=$((attempt + 1))
  done
  rm -rf "$cache_dir" || true
}

sync_silver_bullet_settings_paths() {
  local settings_file plugin_cache_root stable_install_path current_version_dir

  plugin_cache_root="${CLAUDE_SB_PLUGIN_CACHE}"
  stable_install_path="${plugin_cache_root}/current"
  [[ -d "$plugin_cache_root" ]] || return 0
  current_version_dir="$(sb_plugin_cache_latest_version_dir "$plugin_cache_root" 2>/dev/null || true)"
  [[ -n "$current_version_dir" ]] || return 0

  for settings_file in "${CLAUDE_SETTINGS_HOME}/settings.json" "${CLAUDE_HOME}/settings.json"; do
    [[ -f "$settings_file" ]] || continue

  python3 - "$settings_file" "$plugin_cache_root" "$stable_install_path" <<'PY'
import json
import pathlib
import re
import sys

settings_path = pathlib.Path(sys.argv[1])
cache_root = sys.argv[2].rstrip("/")
stable_install_path = sys.argv[3].rstrip("/")

try:
    data = json.loads(settings_path.read_text())
except Exception:
    sys.exit(0)

path_pattern = re.compile(re.escape(cache_root) + r"/[^/\"]+")
sb_hook_pattern = re.compile(r"/silver-bullet/[^/]+/hooks/")

def rewrite(value):
    if isinstance(value, str):
        return path_pattern.sub(stable_install_path, value)
    if isinstance(value, list):
        return [item for item in (rewrite(item) for item in value) if item is not None]
    if isinstance(value, dict):
        rewritten = {}
        for key, item in value.items():
            new_item = rewrite(item)
            if new_item is None:
                continue
            if key == "hooks" and isinstance(new_item, list):
                filtered_hooks = []
                for hook in new_item:
                    if hook is None:
                        continue
                    if isinstance(hook, dict):
                        command = hook.get("command", "")
                        if "${CLAUDE_PLUGIN_ROOT}/hooks/" in command:
                            continue
                        if sb_hook_pattern.search(command) and stable_install_path not in command:
                            continue
                    filtered_hooks.append(hook)
                new_item = filtered_hooks
                if not new_item:
                    continue
            rewritten[key] = new_item
        return rewritten
    return value

updated = rewrite(data)
settings_path.write_text(json.dumps(updated, indent=2) + "\n")
PY
  done
}

refresh_silver_bullet_install_alias() {
  local plugin_cache_root="${CLAUDE_SB_PLUGIN_CACHE}"
  [[ -d "$plugin_cache_root" ]] || return 0
  sb_plugin_cache_prune_orphaned_dirs "$plugin_cache_root"
  sb_plugin_cache_refresh_current_alias "$plugin_cache_root"
}

refresh_plugin_install() {
  local plugin_id="$1"
  local scope

  while IFS= read -r scope; do
    [[ -n "$scope" ]] || continue
    uninstall_plugin_scope "$plugin_id" "$scope"
  done < <(plugin_scopes "$CLAUDE_BIN" "$plugin_id")

  purge_plugin_cache "$plugin_id"
  if "$CLAUDE_BIN" plugin install "$plugin_id" --scope user >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 && "$CLAUDE_SB_MARKETPLACE_SOURCE" == /* ]]; then
    materialize_local_silver_bullet_plugin_cache
    return 0
  fi
  return 1
}

sync_silver_bullet_hook_cache() {
  local cache_root="${CLAUDE_SB_PLUGIN_CACHE}"
  local current_version_dir=""

  [[ -d "$cache_root" ]] || return 0
  current_version_dir="$(sb_plugin_cache_latest_version_dir "$cache_root" 2>/dev/null || true)"
  [[ -n "$current_version_dir" ]] || return 0

  install -d -m 755 "${current_version_dir}/hooks"
  # Sync full local hook tree so PostToolUse fixes (e.g. hookEventName) reach live TUI cache.
  rsync -a --chmod=Du=rwx,go=rx,Fu=rx,Fgo=rx \
    "${REPO_ROOT}/hooks/" "${current_version_dir}/hooks/"
}

prune_claude_cross_host_agent_surfaces() {
  local plugin_root="$1"
  [[ -n "$plugin_root" && -d "$plugin_root" ]] || return 0
  rm -rf \
    "${plugin_root}/agents/codex" \
    "${plugin_root}/agents/cursor"
  # host-bundles/ is canonical Codex/Cursor source in the dev repo — prune only from live plugin cache.
  if [[ "$(cd "$plugin_root" && pwd -P)" != "$(cd "$REPO_ROOT" && pwd -P)" ]]; then
    rm -rf "${plugin_root}/host-bundles"
  fi
  if [[ -d "${plugin_root}/agents" ]]; then
    find "${plugin_root}/agents" -mindepth 1 -maxdepth 1 -type d ! -name 'claude' -exec rm -rf {} +
  fi
}

sync_silver_bullet_skill_cache() {
  local cache_root="${CLAUDE_SB_PLUGIN_CACHE}"
  local current_version_dir=""
  local source_root
  source_root="$(sb_agent_bundle_root "$REPO_ROOT" claude)"

  [[ -d "$cache_root" ]] || return 0
  current_version_dir="$(sb_plugin_cache_latest_version_dir "$cache_root" 2>/dev/null || true)"
  [[ -n "$current_version_dir" ]] || return 0

  rm -rf "${current_version_dir}/commands"
  prune_claude_cross_host_agent_surfaces "$current_version_dir"

  if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 && -d "$source_root" ]]; then
    rm -rf "${current_version_dir}/skills"
    mkdir -p "${current_version_dir}/agents/claude"
    rsync -a --delete "${source_root}/" "${current_version_dir}/agents/claude/"
  elif [[ -d "${current_version_dir}/skills" && ! -L "${current_version_dir}/skills" ]]; then
    rm -rf "${current_version_dir}/skills"
  fi

  prune_claude_cross_host_agent_surfaces "$current_version_dir"

  if [[ -d "${current_version_dir}/agents/claude" ]]; then
    ln -sfn "agents/claude" "${current_version_dir}/skills"
  fi
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
    --public-release) PUBLIC_RELEASE_ONLY=1; shift ;;
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

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  CLAUDE_SB_MARKETPLACE_SOURCE="$CLAUDE_SB_PUBLIC_MARKETPLACE_SOURCE"
fi

ensure_github_https_rewrite
ensure_marketplace_ready "$SB_MARKETPLACE_NAME" "$CLAUDE_SB_MARKETPLACE_SOURCE" "$CLAUDE_SB_MARKETPLACE_PLUGIN"
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  render_agent_bundle "claude"
  prune_claude_cross_host_agent_surfaces "$REPO_ROOT"
fi

if [[ "$PURGE_LEGACY_PLUGINS" -eq 1 ]]; then
  purge_legacy_plugins
fi

for plugin_id in "${TARGET_PLUGINS[@]}"; do
  refresh_plugin_install "$plugin_id"
done

refresh_silver_bullet_install_alias
sync_silver_bullet_settings_paths
if [[ -x "${REPO_ROOT}/scripts/prune-stale-claude-user-hooks.sh" ]]; then
  bash "${REPO_ROOT}/scripts/prune-stale-claude-user-hooks.sh" >&2 || true
fi
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  sync_silver_bullet_hook_cache
fi
sync_silver_bullet_skill_cache

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  printf 'Claude marketplace refreshed from public source %s\n' "$CLAUDE_SB_MARKETPLACE_SOURCE"
else
  printf 'Claude marketplaces registered from %s\n' "$REPO_ROOT"
fi

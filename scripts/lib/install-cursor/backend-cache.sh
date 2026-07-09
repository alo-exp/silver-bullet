#!/usr/bin/env bash
# Cursor backend marketplace cache + agent-plugins clone seeding for install-cursor.sh
set -euo pipefail

CURSOR_AGENT_PLUGINS_REPO_URL="${CURSOR_AGENT_PLUGINS_REPO_URL:-https://github.com/alo-labs/agent-plugins.git}"
CURSOR_AGENT_PLUGINS_GITPATH_ROOT="${CURSOR_AGENT_PLUGINS_GITPATH_ROOT:-${CURSOR_HOME}/plugins/marketplaces/github.com/alo-labs/agent-plugins}"

cursor_backend_plugin_cache_root() {
  printf '%s/plugins/cache/%s/silver-bullet\n' "$CURSOR_HOME" "$CURSOR_BACKEND_MARKETPLACE_NAME"
}

cursor_cursor_logs_root() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    printf '%s/Library/Application Support/Cursor/logs\n' "$HOME"
    return 0
  fi
  printf '%s/.config/Cursor/logs\n' "$HOME"
}

discover_cursor_backend_plugin_shas() {
  local log_root latest_sha
  log_root="$(cursor_cursor_logs_root)"
  if [[ ! -d "$log_root" ]]; then
    return 0
  fi

  latest_sha="$(
    find "$log_root" -name 'Cursor Plugins*.log' -type f -print0 2>/dev/null \
      | xargs -0 grep -h 'Adding enabled plugin: silver-bullet from ' 2>/dev/null \
      | sed -n 's/.*silver-bullet from \([0-9a-f]\{40\}\).*/\1/p' \
      | tail -1
  )"
  [[ -n "$latest_sha" ]] && printf '%s\n' "$latest_sha"
  find "$log_root" -name 'Cursor Plugins*.log' -type f -print0 2>/dev/null \
    | xargs -0 grep -h 'Adding enabled plugin: silver-bullet from ' 2>/dev/null \
    | sed -n 's/.*silver-bullet from \([0-9a-f]\{40\}\).*/\1/p' \
    | sort -u
}

collect_cursor_plugin_seed_shas() {
  {
    printf '%s\n' "$1" "$2"
    read_installed_plugins_git_sha
    read_marketplace_manifest_sha
    resolve_remote_github_head_sha
    collect_cursor_marketplace_cache_shas
    discover_cursor_backend_plugin_shas
  } | awk 'NF && !seen[$0]++'
}

resolve_cursor_backend_plugin_sha() {
  local discovered manifest_sha install_sha
  discovered="$(discover_cursor_backend_plugin_shas | head -1)"
  if [[ -n "$discovered" ]]; then
    printf '%s\n' "$discovered"
    return 0
  fi
  manifest_sha="$(read_marketplace_manifest_sha)"
  if [[ -n "$manifest_sha" ]]; then
    printf '%s\n' "$manifest_sha"
    return 0
  fi
  printf '%s\n' "${1:-}"
}

materialize_cursor_plugin_surface_into_dir() {
  local source_dest="$1"
  local target_root="$2"

  mkdir -p "${target_root}/.cursor-plugin"
  if [[ -d "${source_dest}/commands" ]]; then
    mkdir -p "${target_root}/commands"
    rsync -a --delete "${source_dest}/commands/" "${target_root}/commands/"
  else
    rm -rf "${target_root}/commands"
  fi
  if [[ -d "${source_dest}/agents/cursor" ]]; then
    mkdir -p "${target_root}/agents/cursor"
    rsync -a --delete "${source_dest}/agents/cursor/" "${target_root}/agents/cursor/"
  fi
  if [[ -d "${source_dest}/skill-source" ]]; then
    mkdir -p "${target_root}/skill-source"
    rsync -a --delete "${source_dest}/skill-source/" "${target_root}/skill-source/"
  else
    rm -rf "${target_root}/skill-source"
  fi
  if [[ -f "${source_dest}/cursor-hooks.json" ]]; then
    install -m 644 "${source_dest}/cursor-hooks.json" "${target_root}/cursor-hooks.json"
  fi
  if [[ -f "${source_dest}/.cursor-plugin/plugin.json" ]]; then
    install -m 644 "${source_dest}/.cursor-plugin/plugin.json" "${target_root}/.cursor-plugin/plugin.json"
  fi
}

ensure_cursor_backend_plugin_cache_dir() {
  local dest="$1"
  local commit_sha="$2"
  local cache_path

  [[ -n "$commit_sha" ]] || return 0

  cache_path="$(cursor_backend_plugin_cache_root)/${commit_sha}"
  mkdir -p "$(cursor_backend_plugin_cache_root)"

  if [[ -L "$cache_path" ]]; then
    rm -f "$cache_path"
  fi
  if [[ -e "$cache_path" && ! -d "$cache_path" ]]; then
    rm -f "$cache_path"
  fi
  mkdir -p "$cache_path"

  materialize_cursor_plugin_surface_into_dir "$dest" "$cache_path"
  : > "${cache_path}/.cache-complete"
}

cursor_backend_plugin_cache_ready() {
  local dest="$1"
  local commit_sha="$2"
  local cache_path resolved_dest

  [[ -n "$commit_sha" ]] || return 1
  cache_path="$(cursor_backend_plugin_cache_root)/${commit_sha}"
  [[ -d "$cache_path" ]] || return 1
  [[ -f "${cache_path}/.cache-complete" ]] || return 1
  [[ -f "${cache_path}/commands/init.md" ]] || return 1
  [[ -f "${cache_path}/.cursor-plugin/plugin.json" ]] || return 1
  jq -e '.commands == "./commands"' "${cache_path}/.cursor-plugin/plugin.json" >/dev/null 2>&1 || return 1
  resolved_dest="$(cd "$dest" && pwd -P)"
  [[ "$(jq -r '.version // empty' "${cache_path}/.cursor-plugin/plugin.json")" == "$(jq -r '.version // empty' "${resolved_dest}/.cursor-plugin/plugin.json")" ]]
}

ensure_agent_plugins_marketplace_clone() {
  local head_sha dest_root tmp

  head_sha="$(git ls-remote "$CURSOR_AGENT_PLUGINS_REPO_URL" HEAD 2>/dev/null | awk 'NR==1 {print $1}')"
  [[ -n "$head_sha" ]] || return 0

  dest_root="${CURSOR_AGENT_PLUGINS_GITPATH_ROOT}/${head_sha}"
  if [[ -d "${dest_root}/.git" ]] && git -C "$dest_root" cat-file -e "${head_sha}^{commit}" >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "$(dirname "$CURSOR_AGENT_PLUGINS_GITPATH_ROOT")"
  if [[ -d "$dest_root" ]]; then
    rm -rf "$dest_root"
  fi

  if ! git clone --depth 1 "$CURSOR_AGENT_PLUGINS_REPO_URL" "$dest_root" >/dev/null 2>&1; then
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-agent-plugins-clone.XXXXXX")"
    if git clone --depth 1 "$CURSOR_AGENT_PLUGINS_REPO_URL" "$tmp" >/dev/null 2>&1; then
      mkdir -p "$(dirname "$dest_root")"
      mv "$tmp" "$dest_root"
    else
      rm -rf -- "$tmp"
      return 0
    fi
  fi
}

cursor_plugin_gitpath_root_surface_ready() {
  local commit_sha="$1"
  local gitpath_root

  cursor_plugin_gitpath_ready "$commit_sha" || return 1
  gitpath_root="$(cursor_github_marketplace_gitpath_for_sha "$commit_sha")"
  [[ -f "${gitpath_root}/commands/init.md" ]] || return 1
  [[ -f "${gitpath_root}/.cursor-plugin/plugin.json" ]] || return 1
  jq -e '.commands == "./commands"' "${gitpath_root}/.cursor-plugin/plugin.json" >/dev/null 2>&1
}

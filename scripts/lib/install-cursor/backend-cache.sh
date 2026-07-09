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

cursor_github_commit_reachable() {
  local sha="$1"
  local source_root="${2:-${REPO_ROOT:-.}}"

  [[ -n "$sha" ]] || return 1
  if git -C "$source_root" cat-file -e "${sha}^{commit}" >/dev/null 2>&1; then
    return 0
  fi
  git ls-remote --exit-code "$CURSOR_GITHUB_REPO_URL" "$sha" >/dev/null 2>&1
}

prune_stale_cursor_marketplace_cache_links() {
  local keep_sha="${1:-}"
  local cache_root entry name

  cache_root="$(cursor_marketplace_plugin_cache_root)"
  [[ -d "$cache_root" ]] || return 0

  for entry in "$cache_root"/*; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" =~ ^[0-9a-f]{40}$ ]] || continue
    if [[ -n "$keep_sha" && "$name" == "$keep_sha" ]]; then
      continue
    fi
    if cursor_github_commit_reachable "$name"; then
      continue
    fi
    rm -f "$entry"
    printf 'Note: pruned stale Cursor marketplace cache symlink for unreachable commit %s\n' "${name:0:8}" >&2
  done
}

prune_stale_cursor_marketplace_gitpaths() {
  local keep_sha="${1:-}"
  local base_root entry name

  if declare -F cursor_github_marketplace_gitpath_root >/dev/null 2>&1; then
    base_root="$(cursor_github_marketplace_gitpath_root)"
  else
    base_root="${CURSOR_HOME}/plugins/marketplaces/github.com/${CURSOR_GITHUB_REPO_SLUG:-alo-exp/silver-bullet}"
  fi
  [[ -d "$base_root" ]] || return 0

  for entry in "$base_root"/*; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" =~ ^[0-9a-f]{40}$ ]] || continue
    if [[ -n "$keep_sha" && "$name" == "$keep_sha" ]]; then
      continue
    fi
    if cursor_github_commit_reachable "$name"; then
      continue
    fi
    rm -rf "$entry"
    printf 'Note: pruned stale Cursor gitPath checkout for unreachable commit %s\n' "${name:0:8}" >&2
  done
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

collect_cursor_plugin_required_shas() {
  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    if cursor_github_commit_reachable "$sha"; then
      printf '%s\n' "$sha"
    fi
  done < <(
    {
      printf '%s\n' "$1" "$2"
      read_installed_plugins_git_sha
      read_marketplace_manifest_sha
      discover_cursor_backend_plugin_shas
    } | awk 'NF && !seen[$0]++'
  )
}


prune_agents_from_all_cursor_backend_caches() {
  local cache_root entry
  cache_root="$(cursor_backend_plugin_cache_root)"
  [[ -d "$cache_root" ]] || return 0
  for entry in "$cache_root"/*; do
    [[ -d "$entry" ]] || continue
    if [[ -d "${entry}/agents" ]]; then
      rm -rf "${entry}/agents"
      printf 'Note: pruned agents/ from Cursor backend cache %s (commands-only / picker)\n' "$(basename "$entry" | cut -c1-8)" >&2
    fi
  done
}

collect_cursor_plugin_seed_shas() {
  local primary_sha="${1:-}"
  local backend_sha="${2:-}"

  prune_stale_cursor_marketplace_cache_links "$primary_sha"
  prune_stale_cursor_marketplace_gitpaths "$primary_sha"
  # Stale backend SHA dirs may still contain agents/cursor from older installs;
  # cursor-agent loads every enabled backend cache into the / picker.
  prune_agents_from_all_cursor_backend_caches

  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    if cursor_github_commit_reachable "$sha"; then
      printf '%s\n' "$sha"
    fi
  done < <(
    {
      collect_cursor_plugin_required_shas "$primary_sha" "$backend_sha"
      resolve_remote_github_head_sha
      collect_cursor_marketplace_cache_shas
    } | awk 'NF && !seen[$0]++'
  )
}

resolve_cursor_backend_plugin_sha() {
  local discovered manifest_sha install_sha
  while IFS= read -r discovered; do
    [[ -n "$discovered" ]] || continue
    if cursor_github_commit_reachable "$discovered"; then
      printf '%s\n' "$discovered"
      return 0
    fi
  done < <(discover_cursor_backend_plugin_shas)
  manifest_sha="$(read_marketplace_manifest_sha)"
  if [[ -n "$manifest_sha" ]] && cursor_github_commit_reachable "$manifest_sha"; then
    printf '%s\n' "$manifest_sha"
    return 0
  fi
  if [[ -n "${1:-}" ]] && cursor_github_commit_reachable "${1}"; then
    printf '%s\n' "${1}"
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
  # agents/cursor must not ship — cursor-agent TUI auto-discovers it for / picker.
  rm -rf "${target_root}/agents/cursor" "${target_root}/agents"
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
  [[ -f "${cache_path}/commands/silver:init.md" ]] || return 1
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
  [[ -f "${gitpath_root}/commands/silver:init.md" ]] || return 1
  [[ -f "${gitpath_root}/.cursor-plugin/plugin.json" ]] || return 1
  jq -e '.commands == "./commands"' "${gitpath_root}/.cursor-plugin/plugin.json" >/dev/null 2>&1 || return 1
  [[ ! -f "${gitpath_root}/skills/silver-feature/SKILL.md" ]]
}

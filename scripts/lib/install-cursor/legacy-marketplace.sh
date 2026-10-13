#!/usr/bin/env bash
# Legacy alo-labs/alo-labs-cursor-marketplace migration helpers for install-cursor.sh
set -euo pipefail

CURSOR_LEGACY_MARKETPLACE_SLUG="${CURSOR_LEGACY_MARKETPLACE_SLUG:-alo-labs/alo-labs-cursor-marketplace}"
CURSOR_UNIFIED_MARKETPLACE_SOURCE="${CURSOR_UNIFIED_MARKETPLACE_SOURCE:-https://github.com/alo-labs/agent-plugins.git}"

cursor_legacy_marketplace_gitpath_root() {
  printf '%s/plugins/marketplaces/github.com/%s\n' "$CURSOR_HOME" "$CURSOR_LEGACY_MARKETPLACE_SLUG"
}

legacy_cursor_marketplace_active() {
  [[ -d "$(cursor_legacy_marketplace_gitpath_root)" ]]
}

remove_legacy_cursor_marketplace_clones() {
  local root
  root="$(cursor_legacy_marketplace_gitpath_root)"
  if [[ ! -d "$root" ]]; then
    return 0
  fi
  rm -rf "$root"
  printf 'Removed legacy Cursor marketplace clone at %s\n' "$root" >&2
}

collect_cursor_marketplace_cache_shas() {
  local cache_root entry name
  cache_root="$(cursor_marketplace_plugin_cache_root)"
  [[ -d "$cache_root" ]] || return 0
  for entry in "$cache_root"/*; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" =~ ^[0-9a-f]{40}$ ]] || continue
    printf '%s\n' "$name"
  done
}

print_cursor_marketplace_migration_notice() {
  cat >&2 <<'NOTICE'

Cursor is still using the legacy alo-labs/alo-labs-cursor-marketplace source.
Switch to the unified marketplace in Cursor Settings → Plugins:
  1. Remove the legacy "alo-labs-cursor" marketplace (alo-labs-cursor-marketplace repo)
  2. Add marketplace: https://github.com/alo-labs/agent-plugins
  3. Install or re-enable silver-bullet from the alo-labs-cursor catalog
  4. Reload the window

Until you switch, install-cursor.sh seeds gitPath for legacy HEAD resolutions only.

NOTICE
}

resolve_cursor_registry_git_commit_sha() {
  local install_sha="$1"
  local legacy_mode="${2:-0}"
  local manifest_sha remote_sha cache_sha preferred=""
  local backend_sha

  backend_sha=""
  while IFS= read -r discovered; do
    [[ -n "$discovered" ]] || continue
    if cursor_github_commit_reachable "$discovered"; then
      backend_sha="$discovered"
      break
    fi
  done < <(discover_cursor_backend_plugin_shas)
  manifest_sha="$(read_marketplace_manifest_sha)"
  remote_sha="$(resolve_remote_github_head_sha)"

  if [[ "$legacy_mode" -eq 1 ]]; then
    if cursor_plugin_gitpath_ready "$install_sha"; then
      printf '%s\n' "$install_sha"
      return 0
    fi
    while IFS= read -r cache_sha; do
      [[ -n "$cache_sha" ]] || continue
      if cursor_plugin_gitpath_ready "$cache_sha"; then
        preferred="$cache_sha"
      fi
    done < <(collect_cursor_marketplace_cache_shas)
    if [[ -n "$preferred" ]]; then
      printf '%s\n' "$preferred"
      return 0
    fi
    [[ -n "$remote_sha" ]] && printf '%s\n' "$remote_sha" && return 0
    printf '%s\n' "$install_sha"
    return 0
  fi

  # Prefer the commit we just installed. Stale Cursor Plugins log SHAs and
  # marketplace pins must not win over a fresh local/public install SHA —
  # that mismatch produced registry version X with installPath/cache at X-1.
  if [[ -n "$install_sha" ]]; then
    printf '%s\n' "$install_sha"
    return 0
  fi

  if [[ -n "$backend_sha" ]]; then
    printf '%s\n' "$backend_sha"
    return 0
  fi
  if [[ -n "$manifest_sha" ]]; then
    printf '%s\n' "$manifest_sha"
    return 0
  fi
  [[ -n "$remote_sha" ]] && printf '%s\n' "$remote_sha" && return 0
  printf '%s\n' "$install_sha"
}

seed_cursor_marketplace_gitpaths_extended() {
  local dest="$1"
  local primary_sha="$2"
  local source_root="$3"
  local sha

  while IFS= read -r sha; do
    [[ -n "$sha" ]] || continue
    ensure_cursor_github_marketplace_gitpath "$sha" "$source_root" || continue
    materialize_cursor_plugin_surface_in_gitpath "$dest" "$sha"
    ensure_cursor_marketplace_plugin_cache_symlink "$dest" "$sha"
  done < <(collect_cursor_plugin_seed_shas "$primary_sha" "$(resolve_cursor_backend_plugin_sha "$primary_sha")")
}

#!/usr/bin/env bash
# Host-scoped rendered skill bundle paths (relative to repo root).
#
# Claude plugin auto-discovers every subdirectory of plugin-root `agents/` as an
# agent namespace (`silver-bullet:<subdir>:...`). Only Claude bundles may live
# under `agents/`; Codex and Cursor bundles use `host-bundles/<host>/`.

sb_agent_bundle_rel() {
  case "${1:-}" in
    claude) printf '%s\n' 'agents/claude' ;;
    codex) printf '%s\n' 'host-bundles/codex' ;;
    cursor) printf '%s\n' 'host-bundles/cursor' ;;
    *)
      printf 'sb_agent_bundle_rel: unknown host: %s\n' "${1:-}" >&2
      return 1
      ;;
  esac
}

sb_agent_bundle_root() {
  local repo_root="${1:-}"
  local host="${2:-}"
  local rel=""

  rel="$(sb_agent_bundle_rel "$host")" || return 1
  if [[ -z "$repo_root" ]]; then
    printf '%s\n' "$rel"
  else
    printf '%s/%s\n' "$repo_root" "$rel"
  fi
}

# Host bundle path inside an installed plugin cache (differs from source checkout).
sb_agent_cache_rel() {
  case "${1:-}" in
    claude) printf '%s\n' 'agents/claude' ;;
    codex) printf '%s\n' 'skill-source' ;;
    cursor) printf '%s\n' 'agents/cursor' ;;
    *)
      printf 'sb_agent_cache_rel: unknown host: %s\n' "${1:-}" >&2
      return 1
      ;;
  esac
}

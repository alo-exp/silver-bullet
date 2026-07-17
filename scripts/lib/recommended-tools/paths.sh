# shellcheck shell=bash
# Runtime path resolution for reconciliation state (heartbeats, receipts).
# Sources hooks/lib/runtime-paths.sh for SB_RUNTIME_STATE_DIR.

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "${BASH_SOURCE[0]}")/../../../hooks/lib/runtime-paths.sh"
fi

rt_state_root() {
  printf '%s/recommended-tools' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
}

rt_heartbeat_root() {
  printf '%s/heartbeats' "$(rt_state_root)"
}

rt_heartbeat_dir() {
  local project_id="${1:-}" worktree_id="${2:-}"
  [[ -n "$project_id" && -n "$worktree_id" ]] || return 1
  printf '%s/%s/%s' "$(rt_heartbeat_root)" "$project_id" "$worktree_id"
}

rt_sanitize_path_segment() {
  local raw="${1:-}"
  local empty_fallback="${2:-unknown}"
  local hash_prefix="${3:-seg}"
  [[ -n "$raw" ]] || { printf '%s' "$empty_fallback"; return 0; }
  if [[ "$raw" != *"/"* && "$raw" != *".."* && "$raw" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf '%s' "$raw"
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    printf '%s-%s' "$hash_prefix" "$(printf '%s' "$raw" | shasum -a 256 | awk '{print substr($1,1,16)}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s-%s' "$hash_prefix" "$(printf '%s' "$raw" | sha256sum | awk '{print substr($1,1,16)}')"
  else
    printf '%s-%s' "$empty_fallback" "$(date +%s)"
  fi
}

rt_sanitize_session_id() {
  rt_sanitize_path_segment "${1:-}" "unknown" "sid"
}

rt_heartbeat_path() {
  local project_id="${1:-}" worktree_id="${2:-}" session_id="${3:-}"
  [[ -n "$session_id" ]] || return 1
  session_id="$(rt_sanitize_session_id "$session_id")"
  printf '%s/%s.json' "$(rt_heartbeat_dir "$project_id" "$worktree_id")" "$session_id"
}

rt_reload_receipt_root() {
  printf '%s/reload-receipts' "$(rt_state_root)"
}

rt_reload_receipt_host_dir() {
  local host
  host="$(rt_sanitize_path_segment "${1:-cursor}" "cursor")"
  printf '%s/%s' "$(rt_reload_receipt_root)" "$host"
}

rt_reload_receipt_scope_dir() {
  local host project_id worktree_id scope sanitized_wid
  host="$(rt_sanitize_path_segment "${1:-cursor}" "cursor")"
  project_id="$(rt_sanitize_path_segment "${2:-}" "")"
  worktree_id="$(rt_sanitize_path_segment "${3:-}" "")"
  scope="${4:-project}"
  case "$scope" in
    host-global)
      printf '%s/_host-global/_host-global' "$(rt_reload_receipt_host_dir "$host")"
      ;;
    host)
      sanitized_wid="$(rt_sanitize_path_segment "${3:-_host-global}" "_host-global")"
      printf '%s/_host-global/%s' "$(rt_reload_receipt_host_dir "$host")" "$sanitized_wid"
      ;;
    project|*)
      [[ -n "$project_id" && -n "$worktree_id" ]] || return 1
      printf '%s/%s/%s' "$(rt_reload_receipt_host_dir "$host")" "$project_id" "$worktree_id"
      ;;
  esac
}

rt_reload_receipt_path() {
  local host project_id worktree_id receipt_id scope
  host="$(rt_sanitize_path_segment "${1:-cursor}" "cursor")"
  project_id="$(rt_sanitize_path_segment "${2:-}" "")"
  worktree_id="$(rt_sanitize_path_segment "${3:-}" "")"
  receipt_id="$(rt_sanitize_path_segment "${4:-}" "")"
  scope="${5:-project}"
  [[ -n "$receipt_id" ]] || return 1
  printf '%s/%s.json' "$(rt_reload_receipt_scope_dir "$host" "$project_id" "$worktree_id" "$scope")" "$receipt_id"
}

rt_reload_receipt_lock_dir() {
  local host project_id worktree_id scope
  host="$(rt_sanitize_path_segment "${1:-cursor}" "cursor")"
  project_id="$(rt_sanitize_path_segment "${2:-}" "")"
  worktree_id="$(rt_sanitize_path_segment "${3:-}" "")"
  scope="${4:-project}"
  printf '%s/.lock' "$(rt_reload_receipt_scope_dir "$host" "$project_id" "$worktree_id" "$scope")"
}

# Resolve scripts/lib/<rel> from project root, plugin root, or reconciler repo.
rt_resolve_lib_script() {
  local rel="${1:-}" project_root="${2:-${RT_PROJECT_ROOT:-}}"
  local candidate=""
  [[ -n "$rel" ]] || return 1
  if [[ -n "$project_root" && -f "${project_root}/scripts/lib/${rel}" ]]; then
    candidate="${project_root}/scripts/lib/${rel}"
  elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/scripts/lib/${rel}" ]]; then
    candidate="${CLAUDE_PLUGIN_ROOT}/scripts/lib/${rel}"
  elif [[ -n "${RT_REPO_ROOT:-}" && -f "${RT_REPO_ROOT}/scripts/lib/${rel}" ]]; then
    candidate="${RT_REPO_ROOT}/scripts/lib/${rel}"
  elif [[ -n "${REPO_ROOT:-}" && -f "${REPO_ROOT}/scripts/lib/${rel}" ]]; then
    candidate="${REPO_ROOT}/scripts/lib/${rel}"
  else
    local walk="${project_root:-$PWD}"
    while [[ -n "$walk" && "$walk" != "/" ]]; do
      if [[ -f "${walk}/scripts/lib/${rel}" ]]; then
        candidate="${walk}/scripts/lib/${rel}"
        break
      fi
      walk="$(dirname "$walk")"
    done
  fi
  [[ -n "$candidate" && -f "$candidate" ]] || return 1
  printf '%s' "$candidate"
}

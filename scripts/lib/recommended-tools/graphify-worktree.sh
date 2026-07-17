# shellcheck shell=bash
# Worktree-local graphify-out/ index bootstrap with per-worktree lock.

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

RT_GRAPHIFY_UPDATE_TIMEOUT=120

rt_graphify_worktree_root() {
  local start="${1:-${RT_PROJECT_ROOT:-}}"
  rt_git_toplevel "$start"
}

rt_probe_graphify_index_stale() {
  local root="${RT_PROJECT_ROOT:-}" cfg graph_path
  cfg="$(rt_project_config)" || return 1
  graph_path="$(sb_graphify_abs_graph_path "$root" "$cfg")"
  [[ -f "$graph_path" ]] || return 1
  local head_commit
  head_commit="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$head_commit" ]] || return 1
  if [[ ! -f "${root}/graphify-out/.build-commit" ]]; then
    return 0
  fi
  local built
  built="$(cat "${root}/graphify-out/.build-commit" 2>/dev/null || true)"
  [[ "$built" == "$head_commit" ]] || return 0
  return 1
}

rt_graphify_reject_symlink() {
  local root="${1:-}"
  [[ -n "$root" ]] || return 1
  [[ -L "${root}/graphify-out" ]] && return 1
  [[ -L "${root}/graphify-out/graph.json" ]] && return 1
  return 0
}

rt_graphify_lock_path() {
  local root="${1:-}"
  printf '%s/graphify-out/.sb-index.lock' "${root%/}"
}

rt_graphify_record_build_commit() {
  local root="${1:-}"
  local commit
  commit="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$commit" ]] || return 0
  mkdir -p "${root}/graphify-out" 2>/dev/null || true
  printf '%s' "$commit" >"${root}/graphify-out/.build-commit"
}

rt_graphify_worktree_build_index() {
  local root="${1:-${RT_PROJECT_ROOT:-}}"
  root="$(rt_graphify_worktree_root "$root")"
  [[ -n "$root" ]] || return 1
  rt_graphify_reject_symlink "$root" || return 1
  local cfg lock_path
  cfg="$(rt_project_config)" || return 1
  if sb_graphify_index_exists "$root" "$cfg" 2>/dev/null; then
    if ! rt_probe_graphify_index_stale 2>/dev/null; then
      return 0
    fi
  fi
  command -v graphify >/dev/null 2>&1 || return 1
  lock_path="$(rt_graphify_lock_path "$root")"
  rt_with_lock "$lock_path" "$RT_GRAPHIFY_UPDATE_TIMEOUT" bash -c "
    set -euo pipefail
    cd \"${root}\"
    if command -v timeout >/dev/null 2>&1; then
      timeout ${RT_GRAPHIFY_UPDATE_TIMEOUT}s graphify update . --no-cluster
    else
      graphify update . --no-cluster
    fi
  " || return 1
  rt_graphify_record_build_commit "$root"
  return 0
}

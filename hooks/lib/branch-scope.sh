# shellcheck shell=bash
# Branch + git worktree scope — shared by session-start and stop-check.

sb_branch_scope_file() {
  printf '%s' "${SILVER_BULLET_BRANCH_FILE:-${SB_RUNTIME_STATE_DIR:-/tmp}/branch}"
}

sb_branch_scope_git_toplevel() {
  local root="${1:-$PWD}"
  git -C "$root" rev-parse --show-toplevel 2>/dev/null || true
}

# Read stored branch (line 1) and optional git toplevel (line 2).
sb_branch_scope_read() {
  local file="${1:-$(sb_branch_scope_file)}"
  SB_BRANCH_SCOPE_STORED_BRANCH=""
  SB_BRANCH_SCOPE_STORED_TOPLEVEL=""
  [[ -f "$file" && ! -L "$file" ]] || return 1
  SB_BRANCH_SCOPE_STORED_BRANCH="$(sed -n '1p' "$file" 2>/dev/null | tr -d '\n' || true)"
  SB_BRANCH_SCOPE_STORED_TOPLEVEL="$(sed -n '2p' "$file" 2>/dev/null | tr -d '\n' || true)"
  [[ -n "$SB_BRANCH_SCOPE_STORED_BRANCH" ]]
}

sb_branch_scope_write() {
  local branch="${1:-}" toplevel="${2:-}" file
  [[ -n "$branch" ]] || return 1
  file="$(sb_branch_scope_file)"
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "$file" 2>/dev/null || true
  fi
  if [[ -n "$toplevel" ]]; then
    printf '%s\n%s\n' "$branch" "$toplevel" >"$file" 2>/dev/null || true
  else
    printf '%s\n' "$branch" >"$file" 2>/dev/null || true
  fi
}

# True when branch name or git worktree toplevel diverges from stored scope.
sb_branch_scope_mismatch() {
  local current_branch="${1:-}" current_toplevel="${2:-}" stored_branch="" stored_toplevel=""
  [[ -n "$current_branch" ]] || return 1
  sb_branch_scope_read "$(sb_branch_scope_file)" || return 1
  stored_branch="$SB_BRANCH_SCOPE_STORED_BRANCH"
  stored_toplevel="$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
  [[ -n "$stored_branch" ]] || return 1
  if [[ "$stored_branch" != "$current_branch" ]]; then
    return 0
  fi
  if [[ -n "$stored_toplevel" && -n "$current_toplevel" && "$stored_toplevel" != "$current_toplevel" ]]; then
    return 0
  fi
  return 1
}

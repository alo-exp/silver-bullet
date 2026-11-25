# shellcheck shell=bash
# Branch + git worktree scope — shared by session-start and stop-check.
#
# API:
#   sb_branch_scope_file                    the validated branch file: SILVER_BULLET_BRANCH_FILE
#                                           when it resolves inside the runtime state root,
#                                           else $SB_RUNTIME_STATE_DIR/branch. Status 1 (no
#                                           output) when there is no state dir: never /tmp.
#   sb_branch_scope_read [FILE]             stored branch (line 1) and toplevel (line 2) into
#                                           SB_BRANCH_SCOPE_STORED_{BRANCH,TOPLEVEL}.
#   sb_branch_scope_write BRANCH [TOPLEVEL] [FILE]
#                                           store the scope in FILE (a path the caller already
#                                           validated) or sb_branch_scope_file. Status 1 for an
#                                           empty BRANCH, no path, or a symlinked file (refused
#                                           without exiting the caller).
#   sb_branch_scope_current_ref [DIR]       the branch to scope state by: the symbolic ref (works on an
#                                           unborn branch), or the branch being rebased while HEAD is
#                                           detached by a rebase. Empty for a plain detached HEAD,
#                                           which callers treat as "do not touch state".
#   sb_branch_scope_mismatch BRANCH [TOPLEVEL]  true when the stored scope differs.

if ! declare -f sb_runtime_state_path >/dev/null 2>&1; then
  _sb_branch_scope_rp="${BASH_SOURCE[0]:-$0}"
  _sb_branch_scope_rp="${_sb_branch_scope_rp%/*}/runtime-paths.sh"
  if [[ -f "$_sb_branch_scope_rp" ]]; then
    # shellcheck source=runtime-paths.sh
    source "$_sb_branch_scope_rp"
  fi
  unset _sb_branch_scope_rp
fi

sb_branch_scope_file() {
  local file=""
  if [[ -n "${SILVER_BULLET_BRANCH_FILE:-}" ]] && declare -f sb_runtime_state_path >/dev/null 2>&1; then
    file="$(sb_runtime_state_path "$SILVER_BULLET_BRANCH_FILE" || true)"
  fi
  [[ -n "$file" ]] || {
    [[ -n "${SB_RUNTIME_STATE_DIR:-}" ]] || return 1
    file="${SB_RUNTIME_STATE_DIR}/branch"
  }
  printf '%s' "$file"
}

sb_branch_scope_current_ref() {
  local root="${1:-$PWD}" ref="" gd="" headfile=""
  ref="$(git -C "$root" symbolic-ref -q --short HEAD 2>/dev/null || true)"
  if [[ -z "$ref" ]]; then
    gd="$(git -C "$root" rev-parse --git-dir 2>/dev/null || true)"
    if [[ -n "$gd" && "$gd" != /* ]]; then gd="$root/$gd"; fi
    for headfile in "$gd/rebase-merge/head-name" "$gd/rebase-apply/head-name"; do
      if [[ -n "$gd" && -f "$headfile" ]]; then
        ref="$(sed -n '1p' "$headfile" | tr -d '\n')"
        ref="${ref#refs/heads/}"
        break
      fi
    done
    [[ "$ref" != "detached HEAD" ]] || ref=""
  fi
  printf '%s' "$ref"
}

sb_branch_scope_git_toplevel() {
  local root="${1:-$PWD}"
  git -C "$root" rev-parse --show-toplevel 2>/dev/null || true
}

# Read stored branch (line 1) and optional git toplevel (line 2).
sb_branch_scope_read() {
  local file="${1:-}"
  SB_BRANCH_SCOPE_STORED_BRANCH=""
  SB_BRANCH_SCOPE_STORED_TOPLEVEL=""
  [[ -n "$file" ]] || file="$(sb_branch_scope_file)" || return 1
  [[ -f "$file" && ! -L "$file" ]] || return 1
  SB_BRANCH_SCOPE_STORED_BRANCH="$(sed -n '1p' "$file" 2>/dev/null | tr -d '\n' || true)"
  SB_BRANCH_SCOPE_STORED_TOPLEVEL="$(sed -n '2p' "$file" 2>/dev/null | tr -d '\n' || true)"
  [[ -n "$SB_BRANCH_SCOPE_STORED_BRANCH" ]]
}

sb_branch_scope_write() {
  local branch="${1:-}" toplevel="${2:-}" file="${3:-}"
  [[ -n "$branch" ]] || return 1
  [[ -n "$file" ]] || file="$(sb_branch_scope_file)" || return 1
  [[ ! -L "$file" ]] || return 1
  if [[ -n "$toplevel" ]]; then
    printf '%s\n%s\n' "$branch" "$toplevel" 2>/dev/null >"$file" || true
  else
    printf '%s\n' "$branch" 2>/dev/null >"$file" || true
  fi
}

# True when branch name or git worktree toplevel diverges from stored scope.
sb_branch_scope_mismatch() {
  local current_branch="${1:-}" current_toplevel="${2:-}" stored_branch="" stored_toplevel=""
  [[ -n "$current_branch" ]] || return 1
  sb_branch_scope_read "$(sb_branch_scope_file)" || return 1
  stored_branch="$SB_BRANCH_SCOPE_STORED_BRANCH"
  stored_toplevel="$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
  if [[ "$stored_branch" != "$current_branch" ]]; then
    return 0
  fi
  if [[ -n "$stored_toplevel" && -n "$current_toplevel" && "$stored_toplevel" != "$current_toplevel" ]]; then
    return 0
  fi
  return 1
}

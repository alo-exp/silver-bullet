#!/usr/bin/env bash
# The session epoch (STATE_DIR/session-start-time) and the agent write trace keyed by it (files-written.<epoch>,
# hooks/lib/agent-writes.sh). The two stay paired, so the trace can neither be orphaned by a restamp nor leak into
# the next session.
#
# When the epoch rotates (hooks/session-start):
#   - on Claude's `startup` and on `clear` of every host. On other hosts (Codex fires `startup` on every process
#     restart of one session) `startup` rotates only when the payload's session_id differs from the one stored in
#     STATE_DIR/session-start-sid. A payload without a session id (the repo holds no real Codex capture to confirm
#     the id is always present) rotates on `startup` only when the epoch is older than 24 hours, else on `clear`.
#     Never in a worker session, never on resume or compact.
#   - every trace (any epoch, `unknown`) is merged, de-duplicated and capped like agent-writes.sh (500 entries, then
#     `*`), into the new epoch's trace, so running session-start by hand, or by two windows at once, does not erase
#     the evidence that the agent wrote source. The merge is idempotent, and the traces it reads are removed only
#     after the merged trace was written (a failed write keeps them and the old epoch). An entry appended between
#     the read and the removal can be lost (a window of milliseconds).
#   - ONE rule decides what a rotation keeps (hooks/lib/tool-input/trace_filter.py). An entry stays only when its
#     path is under the project root, is still dirty there (modified or untracked per `git status`) and is not part
#     of the HEAD move since the previous rotation (`git diff --name-only old new`, empty when HEAD did not move);
#     `d`, `t` and glob entries cover the paths below them; `*` entries cannot be checked against a path and are
#     dropped. So a new chat-only session over the user's own edits is not blocked by an earlier session's stale
#     entries, while the agent's own still-uncommitted source stays on record. STATE_DIR/session-start-head holds
#     the repository identity (device:inode of the git common dir) and the HEAD of the previous rotation; a trace
#     recorded for another repository, or a record in an older one-line layout, is dropped whole.
# session-log-init never replaces a valid epoch; the autonomous-mode relaunch restamps it (the sentinel timer
# restarts) and merges the traces the same way.
# Residual: running session-start by hand is out of scope for the integrity record (integrity.sh). A hand-run
# session-start therefore loses a trace that holds only `*` entries (and entries for changes that were committed),
# and keeps the dirty source files the agent wrote.
#
# API:
#   sb_session_epoch_restamp FILE STATE_DIR [drop]    write a new epoch to FILE; merge every trace into its trace
#                                                     (with `drop`, delete them instead); status 1 when the merge failed
#   sb_session_epoch_collect FILE STATE_DIR           merge every other trace into the current epoch's trace
#   sb_session_epoch_should_rotate SOURCE RUNTIME SID STATE_DIR [EPOCH_FILE]   status 0 when a start with this payload is a new session
#   sb_session_epoch_rotate FILE STATE_DIR ROOT MODE SID          the rule above (MODE rotate|keep)

SB_SE_MAX=500

# _sb_se_write FILE TEXT: replace FILE with TEXT through a temp file in its directory (never through a link or a
# directory); status 1 when it could not be written
_sb_se_write() {
  local file="$1" tmp
  [[ ! -L "$file" && ! -d "$file" ]] || return 1
  tmp="$(mktemp "$file.XXXXXX" 2>/dev/null)" || return 1
  if printf '%s\n' "$2" >"$tmp" 2>/dev/null && mv -f -- "$tmp" "$file" 2>/dev/null; then return 0; fi
  rm -f -- "$tmp" 2>/dev/null
  return 1
}

# _sb_se_merge STATE_DIR TARGET: the entries of every regular files-written.* (TARGET included), de-duplicated,
# become TARGET; the others are removed. Nothing is created when there is nothing to merge.
_sb_se_merge() {
  local sd="$1" target="$2" f merged="" n
  local -a srcs=()
  for f in "$sd"/files-written.*; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    srcs+=("$f")
  done
  [[ ${#srcs[@]} -gt 0 ]] || return 0
  if merged="$(cat -- "${srcs[@]}" 2>/dev/null | awk 'NF && !seen[$0]++')"; then :; fi
  if n="$(printf '%s' "$merged" | grep -c .)"; then :; fi
  if (( n > SB_SE_MAX )); then
    merged="$(printf '%s\n' "$merged" | head -n "$SB_SE_MAX")"$'\n''*'
  fi
  [[ -n "$merged" ]] || return 0
  _sb_se_write "$target" "$merged" || return 1
  for f in "${srcs[@]}"; do
    [[ "$f" == "$target" ]] || rm -f -- "$f" 2>/dev/null
  done
  return 0
}

sb_session_epoch_restamp() {
  local file="${1:-}" sd="${2:-}" drop="${3:-}" new
  [[ -n "$file" && -n "$sd" && ! -L "$file" ]] || return 0
  new="$(date +%s)"
  if [[ "$drop" == drop ]]; then
    find "$sd" -maxdepth 1 \( -type f -o -type l \) -name 'files-written.*' -delete 2>/dev/null && :
  else
    # a failed merge keeps the old epoch and the traces as they are: they stay paired
    _sb_se_merge "$sd" "$sd/files-written.$new" || return 1
  fi
  _sb_se_write "$file" "$new" || return 1
  # two rotations that interleave can leave the trace under the epoch the other one wrote: merge again
  sb_session_epoch_collect "$file" "$sd" && :
  return 0
}

sb_session_epoch_collect() {
  local file="${1:-}" sd="${2:-}" epoch=""
  [[ -f "$file" && ! -L "$file" ]] && epoch="$(<"$file")"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 0
  _sb_se_merge "$sd" "$sd/files-written.$epoch"
  return 0
}

sb_session_epoch_should_rotate() {
  local source="${1:-}" runtime="${2:-}" sid="${3:-}" sd="${4:-}" stored="" epoch=""
  [[ "$source" == clear ]] && return 0
  [[ "$source" == startup ]] || return 1
  [[ "$runtime" == claude ]] && return 0
  if [[ -z "$sid" ]]; then
    # no session id (cannot tell a restart from a new session): rotate once the epoch is a day old
    if epoch="$(cat "${5:-$sd/session-start-time}" 2>/dev/null)"; then :; fi
    [[ "$epoch" =~ ^[0-9]+$ ]] && (( $(date +%s) - epoch > 86400 ))
    return
  fi
  [[ ! -L "$sd/session-start-sid" ]] || return 1
  [[ ! -f "$sd/session-start-sid" ]] || stored="$(<"$sd/session-start-sid")"
  [[ "$sid" != "$stored" ]]
}

# _sb_se_repo ROOT: the identity of ROOT's repository: device and inode of its git common directory (a worktree
# shares its repository's; unlike a path it does not depend on how the directory was spelled)
_sb_se_repo() {
  local dir out
  if dir="$(cd "$1" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)"; then
    [[ "$dir" == /* ]] || dir="$1/$dir"
    if out="$(stat -c '%d:%i' "$dir" 2>/dev/null || stat -f '%d:%i' "$dir" 2>/dev/null)"; then printf '%s' "$out"; fi
  fi
}

# The rule applied to the merged trace on every rotation (see the header): hooks/lib/tool-input/trace_filter.py.
# A failing helper (no python3, an error) leaves the trace whole.
_sb_se_filter() {
  python3 "${BASH_SOURCE[0]%/*}/tool-input/trace_filter.py" "$1" "$2" "$3" "$4" 2>/dev/null && :
  return 0
}

sb_session_epoch_rotate() {
  local file="${1:-}" sd="${2:-}" root="${3:-}" mode="${4:-rotate}" sid="${5:-}"
  local headfile="$sd/session-start-head" oldid="" oldhead="" curid curhead=""
  if [[ -f "$headfile" && ! -L "$headfile" ]]; then
    oldid="$(sed -n 1p "$headfile")"
    oldhead="$(sed -n 2p "$headfile")"
    # a record without a repository line (an older layout) says nothing about this project: it is foreign
    [[ -n "$oldhead" ]] || oldid="legacy"
  fi
  curid="$(_sb_se_repo "$root")"
  if curhead="$(git -C "$root" rev-parse HEAD 2>/dev/null)"; then :; fi
  if [[ "$mode" == rotate ]]; then
    if [[ -n "$oldid" && "$oldid" != "$curid" ]]; then
      sb_session_epoch_restamp "$file" "$sd" drop && :
    else
      sb_session_epoch_restamp "$file" "$sd" && :
      if [[ -f "$file" && -f "$sd/files-written.$(<"$file")" ]]; then
        _sb_se_filter "$root" "$oldhead" "$curhead" "$sd/files-written.$(<"$file")"
      fi
    fi
    _sb_se_write "$headfile" "$curid"$'\n'"$curhead" && :
  else
    sb_session_epoch_collect "$file" "$sd" && :
    [[ -f "$headfile" ]] || _sb_se_write "$headfile" "$curid"$'\n'"$curhead" && :
  fi
  if [[ -n "$sid" ]]; then _sb_se_write "$sd/session-start-sid" "$sid" && :; fi
  return 0
}

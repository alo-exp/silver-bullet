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
#   - STATE_DIR/session-start-head records the repository (git common dir) and the HEAD the carried trace was
#     written against. A trace of ANOTHER repository (or a record without a repository whose HEAD is not in this
#     one) is dropped: it says nothing about this project. In the same repository a HEAD that did not move, moved
#     back or sideways (checkout, detach, reset), or cannot be read keeps the trace whole. A HEAD that moved
#     FORWARD (the recorded one is an ancestor of the current one) keeps only the entries whose path is still dirty
#     and was not part of the move (`git diff --name-only old new`): work that was committed, or the user's own
#     later edits to it, is not the agent's pending write, so a new chat-only session over the user's edits is not
#     blocked, while the agent's own uncommitted edits stay on record. `*` entries cannot be checked against a
#     path and are dropped on a forward move.
# session-log-init never replaces a valid epoch; the autonomous-mode relaunch restamps it (the sentinel timer
# restarts) and merges the traces the same way.
# Residual: running session-start by hand is out of scope for the integrity record (integrity.sh); an agent that
# commits its own change and edits it no further loses that part of its trace on a forward move.
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
    epoch="$(cat "${5:-$sd/session-start-time}" 2>/dev/null || true)"
    [[ "$epoch" =~ ^[0-9]+$ ]] && (( $(date +%s) - epoch > 86400 ))
    return
  fi
  [[ ! -L "$sd/session-start-sid" ]] || return 1
  [[ ! -f "$sd/session-start-sid" ]] || stored="$(<"$sd/session-start-sid")"
  [[ "$sid" != "$stored" ]]
}

# _sb_se_repo ROOT: the canonical git common directory of ROOT (a worktree shares its repository's)
_sb_se_repo() {
  (cd "$1" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P) || true
}

# _sb_se_filter ROOT OLD NEW TRACE: keep the entries of TRACE whose path is still dirty and not in `git diff OLD NEW`
_sb_se_filter() {
  local root="$1" old="$2" new="$3" trace="$4" dirty moved line path keep="" p
  dirty="$(git -C "$root" status --porcelain -z 2>/dev/null | tr '\0' '\n' | cut -c4-)"
  moved="$(git -C "$root" diff --name-only -z "$old" "$new" 2>/dev/null | tr '\0' '\n')"
  while IFS= read -r line; do
    [[ "$line" == '*' || -z "$line" ]] && continue
    path="${line:1}"
    path="${path#"${root%/}"/}"
    # a file entry is its own path; a directory entry (d) covers every path below it
    if [[ "${line:0:1}" == d ]]; then
      p="$(printf '%s\n' "$dirty" | grep -c "^${path%/}/" || true)"
      [[ "$p" -gt 0 ]] || continue
      p="$(printf '%s\n' "$moved" | grep -c "^${path%/}/" || true)"
      [[ "$p" -eq 0 ]] || continue
    else
      printf '%s\n' "$dirty" | grep -qxF -- "$path" || continue
      ! printf '%s\n' "$moved" | grep -qxF -- "$path" || continue
    fi
    keep="${keep}${line}"$'\n'
  done <"$trace"
  if [[ -n "$keep" ]]; then
    _sb_se_write "$trace" "${keep%$'\n'}" || return 1
  else
    rm -f -- "$trace" 2>/dev/null
  fi
  return 0
}

sb_session_epoch_rotate() {
  local file="${1:-}" sd="${2:-}" root="${3:-}" mode="${4:-rotate}" sid="${5:-}"
  local headfile="$sd/session-start-head" oldid="" oldhead="" curid curhead how=keep l1="" l2="" foreign
  if [[ -f "$headfile" && ! -L "$headfile" ]]; then
    { IFS= read -r l1; IFS= read -r l2; } <"$headfile" || true
    # a record without a repository line (older state) is the HEAD alone
    if [[ -z "$l2" ]]; then oldhead="$l1"; else oldid="$l1"; oldhead="$l2"; fi
  fi
  curid="$(_sb_se_repo "$root")"
  curhead="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$mode" == rotate ]]; then
    if [[ -n "$oldhead" ]]; then
      foreign=0
      if [[ -n "$oldid" ]]; then
        [[ "$oldid" == "$curid" ]] || foreign=1
      elif ! git -C "$root" cat-file -e "$oldhead^{commit}" 2>/dev/null; then
        foreign=1
      fi
      if [[ "$foreign" == 1 ]]; then
        how=drop
      elif [[ -n "$curhead" && "$curhead" != "$oldhead" ]] && git -C "$root" merge-base --is-ancestor "$oldhead" "$curhead" 2>/dev/null; then
        how=filter
      fi
    fi
    if [[ "$how" == drop ]]; then
      sb_session_epoch_restamp "$file" "$sd" drop && :
    else
      sb_session_epoch_restamp "$file" "$sd" && :
      if [[ "$how" == filter && -f "$file" ]]; then
        _sb_se_filter "$root" "$oldhead" "$curhead" "$sd/files-written.$(<"$file")" && :
      fi
    fi
    # the HEAD a carried trace was written against is kept (a detour and back is not a forward move)
    if [[ "$how" != keep ]] || ! compgen -G "$sd/files-written.*" >/dev/null; then oldhead=""; fi
  else
    sb_session_epoch_collect "$file" "$sd" && :
  fi
  # repository and HEAD the trace was written against: recorded when there is none yet or none is carried
  if [[ -z "$oldhead" ]]; then _sb_se_write "$headfile" "$curid"$'\n'"$curhead" && :; fi
  if [[ -n "$sid" ]]; then _sb_se_write "$sd/session-start-sid" "$sid" && :; fi
  return 0
}

#!/usr/bin/env bash
# The session epoch (STATE_DIR/session-start-time) and the agent write trace keyed by it (files-written.<epoch>,
# hooks/lib/agent-writes.sh). The two stay paired, so the trace can neither be orphaned by a restamp nor leak into
# the next session.
#
# When the epoch rotates (hooks/session-start):
#   - on Claude's `startup` and on `clear` of every host. On other hosts (Codex fires `startup` on every process
#     restart of one session) `startup` rotates only when the payload's session_id differs from the one stored in
#     STATE_DIR/session-start-sid; a payload without a session id keeps the epoch, so such a host rotates on `clear`
#     only. Never in a worker session, never on resume or compact.
#   - every trace (any epoch, `unknown`) is merged, de-duplicated and capped like agent-writes.sh (500 entries, then
#     `*`), into the new epoch's trace, so running session-start by hand, or by two windows at once, does not erase
#     the evidence that the agent wrote source. The merge is idempotent: a second rotation merges the first one's
#     trace again instead of orphaning it.
#   - the traces are dropped instead when HEAD moved FORWARD since the epoch began (the HEAD recorded in
#     session-start-head, where the carried trace began, is an ancestor of the current one: work was committed
#     through the gated commit path), so a new chat-only session
#     over the user's own edits is not blocked. A HEAD that moved back or sideways (checkout, detach, reset), or one
#     that cannot be read, keeps the traces.
# session-log-init never replaces a valid epoch; the autonomous-mode relaunch restamps it (the sentinel timer
# restarts) and merges the traces the same way.
# Residual: an agent that makes a gated commit and then runs session-start by hand drops its trace; running
# session-start by hand is out of scope for the integrity record (integrity.sh) anyway.
#
# API:
#   sb_session_epoch_restamp FILE STATE_DIR [drop]    write a new epoch to FILE; merge every trace into its trace
#                                                     (with `drop`, delete them instead)
#   sb_session_epoch_collect FILE STATE_DIR           merge every other trace into the current epoch's trace
#   sb_session_epoch_should_rotate SOURCE RUNTIME SID STATE_DIR   status 0 when a start with this payload is a new session
#   sb_session_epoch_rotate FILE STATE_DIR ROOT MODE SID          the rule above (MODE rotate|keep); HEAD where the
#                                                     epoch began is kept in STATE_DIR/session-start-head

SB_SE_MAX=500

# _sb_se_write FILE TEXT: replace FILE with TEXT through a temp file in its directory (never through a link)
_sb_se_write() {
  local file="$1" tmp
  [[ ! -L "$file" ]] || return 0
  tmp="$(mktemp "$file.XXXXXX" 2>/dev/null)" || return 0
  if printf '%s\n' "$2" >"$tmp" 2>/dev/null && mv -f -- "$tmp" "$file" 2>/dev/null; then return 0; fi
  rm -f -- "$tmp" 2>/dev/null
  return 0
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
  merged="$(cat -- "${srcs[@]}" 2>/dev/null | awk 'NF && !seen[$0]++' || true)"
  n="$(printf '%s' "$merged" | grep -c . || true)"
  if (( n > SB_SE_MAX )); then
    merged="$(printf '%s\n' "$merged" | head -n "$SB_SE_MAX")"$'\n''*'
  fi
  [[ -n "$merged" ]] && _sb_se_write "$target" "$merged"
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
    _sb_se_merge "$sd" "$sd/files-written.$new"
  fi
  _sb_se_write "$file" "$new"
  # two rotations that interleave can leave the trace under the epoch the other one wrote: merge again
  sb_session_epoch_collect "$file" "$sd"
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
  local source="${1:-}" runtime="${2:-}" sid="${3:-}" sd="${4:-}" stored=""
  [[ "$source" == clear ]] && return 0
  [[ "$source" == startup ]] || return 1
  [[ "$runtime" == claude ]] && return 0
  [[ -n "$sid" && ! -L "$sd/session-start-sid" ]] || return 1
  [[ ! -f "$sd/session-start-sid" ]] || stored="$(<"$sd/session-start-sid")"
  [[ "$sid" != "$stored" ]]
}

sb_session_epoch_rotate() {
  local file="${1:-}" sd="${2:-}" root="${3:-}" mode="${4:-rotate}" sid="${5:-}" oldhead="" curhead="" headfile drop=""
  headfile="$sd/session-start-head"
  [[ ! -f "$headfile" || -L "$headfile" ]] || oldhead="$(<"$headfile")"
  curhead="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$mode" == rotate ]]; then
    if [[ -n "$curhead" && -n "$oldhead" && "$curhead" != "$oldhead" ]] \
      && git -C "$root" merge-base --is-ancestor "$oldhead" "$curhead" 2>/dev/null; then
      drop=drop
    fi
    sb_session_epoch_restamp "$file" "$sd" "$drop"
    # a carried trace keeps the HEAD it was written against, so a detour (detach, reset) and back is not a forward move
    if [[ -n "$drop" ]] || ! compgen -G "$sd/files-written.*" >/dev/null; then oldhead=""; fi
  else
    sb_session_epoch_collect "$file" "$sd"
  fi
  # HEAD the trace was written against: recorded when there is none yet, and again whenever no trace is carried
  [[ -n "$oldhead" ]] || _sb_se_write "$headfile" "$curhead"
  [[ -z "$sid" ]] || _sb_se_write "$sd/session-start-sid" "$sid"
  return 0
}

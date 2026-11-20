#!/usr/bin/env bash
# The session epoch (STATE_DIR/session-start-time) and the agent write trace keyed by it (files-written.<epoch>,
# hooks/lib/agent-writes.sh). The two stay paired, so the trace can neither be orphaned by a restamp nor leak into
# the next session:
#   - session-start rotates the epoch on a genuine new session (startup, clear), never in a worker session and never
#     on resume or compact. The trace is carried to the new epoch while HEAD is where the previous epoch began, so
#     running session-start by hand does not erase the evidence that the agent wrote source. When HEAD has moved
#     (the earlier session's work was committed, and a commit has to pass the planning floor) the trace is dropped,
#     so a new chat-only session over the user's own edits is not blocked by an earlier session.
#   - session-log-init never replaces a valid epoch; only the autonomous-mode relaunch restamps it (the sentinel
#     timer starts again) and then carries the trace.
# Residual: an agent that commits (with the planning skills recorded) and then runs session-start by hand drops its
# trace; the commit itself had to pass the floor.
#
# API:
#   sb_session_epoch_restamp FILE STATE_DIR OLD [drop]   write a new epoch to FILE; carry the trace of OLD to it
#                                                        (with `drop`, delete every trace instead)
#   sb_session_epoch_rotate FILE STATE_DIR ROOT [rotate|keep]   the session-start rule above (keep: only record HEAD
#                                                        once); HEAD is kept in STATE_DIR/session-start-head

sb_session_epoch_restamp() {
  local file="${1:-}" sd="${2:-}" old="${3:-}" drop="${4:-}" new
  [[ -n "$file" && -n "$sd" && ! -L "$file" ]] || return 0
  new="$(date +%s)"
  if [[ "$drop" == drop ]]; then
    find "$sd" -maxdepth 1 \( -type f -o -type l \) -name 'files-written.*' -delete 2>/dev/null && :
  elif [[ "$old" =~ ^[0-9]+$ && "$old" != "$new" && -f "$sd/files-written.$old" && ! -L "$sd/files-written.$old" \
    && ! -e "$sd/files-written.$new" ]]; then
    mv -f -- "$sd/files-written.$old" "$sd/files-written.$new" 2>/dev/null && :
  fi
  { printf '%s\n' "$new" >"$file"; } 2>/dev/null && :
  return 0
}

sb_session_epoch_rotate() {
  local file="${1:-}" sd="${2:-}" root="${3:-}" mode="${4:-rotate}" old="" oldhead="" curhead="" headfile drop=""
  headfile="$sd/session-start-head"
  [[ ! -f "$file" ]] || old="$(<"$file")"
  [[ ! -f "$headfile" || -L "$headfile" ]] || oldhead="$(<"$headfile")"
  curhead="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$mode" == rotate ]]; then
    if [[ -n "$curhead" && -n "$oldhead" && "$curhead" != "$oldhead" ]]; then drop=drop; fi
    sb_session_epoch_restamp "$file" "$sd" "$old" "$drop"
    oldhead=""
  fi
  # HEAD where the epoch began: written at a rotation, and once by a start that keeps the epoch
  [[ -n "$oldhead" || -L "$headfile" ]] || { printf '%s\n' "$curhead" >"$headfile"; } 2>/dev/null && :
  return 0
}

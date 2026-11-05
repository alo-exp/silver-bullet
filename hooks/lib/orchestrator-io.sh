# shellcheck shell=bash
# Orchestrator state I/O — atomic writes (refuse symlinks) and a short-lived mkdir lock for
# read-modify-write sequences (R4-18). Parallel workers finishing together used to lose joins:
# every writer read orchestrator.json, computed a new document and moved ${file}.tmp over it.

# sb_orchestrator_atomic_write FILE CONTENT: write CONTENT plus a newline to FILE through a
# unique temp file in the same directory, then rename. Refuses a symlink or directory target.
sb_orchestrator_atomic_write() {
  local file="$1" content="$2" dir tmp
  [[ -n "$file" ]] || return 1
  [[ -L "$file" || -d "$file" ]] && return 1
  dir="$(dirname "$file")"
  mkdir -p "$dir" 2>/dev/null || true
  tmp="$(mktemp "${file}.XXXXXX" 2>/dev/null)" || return 1
  if printf '%s\n' "$content" >"$tmp" 2>/dev/null && mv -f "$tmp" "$file" 2>/dev/null; then
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null || true
  return 1
}

# Lock directory beside the state file. SB_ORCHESTRATOR_LOCK_WAIT_TENTHS (default 50 = 5 s)
# bounds the wait; a lock older than SB_ORCHESTRATOR_LOCK_STALE_MINUTES (default 1) belongs to
# a hook that died and is taken over. After the wait the caller proceeds unlocked: a hook
# must never hang the agent, and a lost update is recoverable where a hung session is not.
sb_orchestrator_lock_dir() {
  printf '%s/orchestrator.lock' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

# sb_orchestrator_with_lock CMD [ARG...]: run CMD (a shell function) holding the lock.
# Re-entrant within one process tree (a subshell inherits the held state).
sb_orchestrator_with_lock() {
  if [[ "${_SB_ORCH_LOCK_HELD:-0}" == "1" ]]; then
    "$@"
    return $?
  fi
  local lock waited=0 max rc=0 got=0
  lock="$(sb_orchestrator_lock_dir)"
  max="${SB_ORCHESTRATOR_LOCK_WAIT_TENTHS:-50}"
  mkdir -p "$(dirname "$lock")" 2>/dev/null || true
  while (( waited <= max )); do
    if mkdir "$lock" 2>/dev/null; then
      got=1
      break
    fi
    # A lock older than the stale age belongs to a hook that died: take it over. If it cannot
    # be removed this round still counts toward the wait, so the loop always ends.
    if [[ -n "$(find "$lock" -maxdepth 0 -mmin +"${SB_ORCHESTRATOR_LOCK_STALE_MINUTES:-1}" 2>/dev/null)" ]]; then
      rmdir "$lock" 2>/dev/null || true
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  _SB_ORCH_LOCK_HELD=1
  "$@" && rc=0 || rc=$?
  _SB_ORCH_LOCK_HELD=0
  [[ "$got" == 1 ]] && { rmdir "$lock" 2>/dev/null || true; }
  return "$rc"
}

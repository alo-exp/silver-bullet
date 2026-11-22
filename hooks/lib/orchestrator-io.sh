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

# The lock: a directory beside the state file. A holder created it, wrote a claim file
# "claim.<pid>.<nonce>" into it and then found that claim to be the only entry (the protocol of
# the consent lock in user-consent.sh, adapted). Only the holder removes its own claim (a unique
# name) and, after it, the directory; a holder whose claim was reclaimed from under it releases
# nothing, because the directory is no longer its own. A waiter reclaims only what is provably
# abandoned, and only by removing a claim BY NAME: a claim whose process is gone (kill -0 and
# ps -p both fail), a claim older than SB_ORCHESTRATOR_LOCK_STALE_MINUTES (default 10, a reused
# pid), a claim file without a pid or an empty directory older than a minute. The age of the
# directory alone never makes a live holder's lock stale, and nothing removes a directory
# recursively (the lost-update race of the earlier find -mmin + rmdir takeover: two waiters
# both judged one stale lock stale, one retook it and the other removed the fresh lock).
# A lock path that is a symlink, not a directory or not owned by the caller is never touched.
#
# Wait budget: SB_ORCHESTRATOR_LOCK_WAIT_TENTHS (default 40 = 4 s, jittered 0.05-0.09 s polls)
# is shared by every lock call of one process and is also capped in wall-clock seconds. The
# smallest timeout of a hook that takes the lock is 10 s (hooks/hooks.json), so the budget is
# 40% of it and a hook that waited out its budget still has time to do its work.
# When the budget runs out (or the lock path is refused) the caller proceeds UNLOCKED with one
# line on stderr. Failing instead would lose the update for certain and a hook must never hang
# the agent; proceeding loses it only if a live holder is still mid-update, and a holder keeps
# the lock for milliseconds, so a busy lock after seconds means a stuck holder.
sb_orchestrator_lock_dir() {
  printf '%s/orchestrator.lock' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

_sb_orch_lock_sane() { # LOCK: status 0 unless LOCK exists as something other than our own plain directory
  local lock="$1"
  [[ -L "$lock" ]] && return 1
  # Other holders create and remove the directory while this runs: one that vanishes between
  # the tests is absent, not refused.
  if [[ -d "$lock" ]]; then
    [[ -O "$lock" ]] && return 0
    [[ ! -e "$lock" ]]
    return
  fi
  [[ ! -e "$lock" ]]
}

_sb_orch_claim_name() { # NAME: status 0 for a claim file name this protocol writes
  [[ "$1" =~ ^claim\.[0-9]+\.[0-9]+$ ]]
}

_sb_orch_claim_stale() { # CLAIM: status 0 when the process that wrote CLAIM is gone or it is far too old
  local claim="$1" pid="" age="${SB_ORCHESTRATOR_LOCK_STALE_MINUTES:-10}"
  [[ "$age" =~ ^[0-9]+$ ]] || age=10
  { read -r pid _ <"$claim"; } 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    # kill -0 also fails for a live process of another user (EPERM): only a pid ps does not list is dead
    if ! kill -0 "$pid" 2>/dev/null && ! ps -p "$pid" >/dev/null 2>&1; then return 0; fi
    [[ -n "$(find "$claim" -maxdepth 0 -mmin +"$age" 2>/dev/null)" ]]
  else
    [[ -n "$(find "$claim" -maxdepth 0 -mmin +1 2>/dev/null)" ]]
  fi
}

_sb_orch_lock_reclaim() { # LOCK: drop abandoned claims; status 0 when LOCK was left gone
  local lock="$1" entry seen=0 live=0
  _sb_orch_lock_sane "$lock" || return 1
  for entry in "$lock"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    seen=1
    # Only regular files named like a claim are ever removed; anything else keeps the lock held.
    if [[ -f "$entry" && ! -L "$entry" ]] && _sb_orch_claim_name "${entry##*/}" \
      && _sb_orch_claim_stale "$entry"; then
      rm -f -- "$entry"
    else
      live=1
    fi
  done
  ((live == 0)) || return 1
  if ((seen == 0)) && [[ -z "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
    return 1 # no claim yet: a holder is between mkdir and writing its claim, or the lock is gone
  fi
  rmdir "$lock" 2>/dev/null
}

_sb_orch_lock_try() { # LOCK: one attempt; status 0 holding it (the claim is in _SB_ORCH_LOCK_CLAIM)
  local lock="$1" claim entry names="" pid
  mkdir "$lock" 2>/dev/null || return 1
  # BASHPID is this (sub)shell; $$ is the top-level shell and the only choice before Bash 4
  pid="$$"; [[ "${BASHPID:-}" =~ ^[0-9]+$ ]] && pid="$BASHPID"
  claim="${lock}/claim.${pid}.${RANDOM}${RANDOM}"
  if { printf '%s' "$pid" >"$claim"; } 2>/dev/null; then
    for entry in "$lock"/*; do
      [[ -e "$entry" ]] && names="${names}${entry##*/} "
    done
    if [[ "$names" == "${claim##*/} " ]]; then
      _SB_ORCH_LOCK_CLAIM="$claim"
      return 0
    fi
  fi
  rm -f -- "$claim"
  rmdir "$lock" 2>/dev/null
  return 1
}

# _sb_orch_lock_acquire LOCK: status 0 holding the lock (claim in _SB_ORCH_LOCK_CLAIM); status 1
# when the lock path is refused or the budget ran out (a diagnostic goes to stderr).
_SB_ORCH_LOCK_WAITED=0 # tenths of a second this process has spent waiting, across calls
_sb_orch_lock_acquire() {
  local lock="$1" max="${SB_ORCHESTRATOR_LOCK_WAIT_TENTHS:-40}" spins=0 start=$SECONDS limit
  [[ "$max" =~ ^[0-9]+$ ]] || max=40
  limit=$(((max + 9) / 10))
  # A refusal must persist across short pauses: a directory another holder is making or removing
  # can look wrong for an instant.
  until _sb_orch_lock_sane "$lock"; do
    if ((spins++ >= 3)); then
      printf 'silver-bullet: %s is not a plain directory of yours; updating orchestrator state without the lock\n' "$lock" >&2
      return 1
    fi
    sleep 0.05
  done
  spins=0
  until _sb_orch_lock_try "$lock"; do
    if _sb_orch_lock_reclaim "$lock" && ((spins++ < 1000)); then continue; fi
    if ((_SB_ORCH_LOCK_WAITED >= max || SECONDS - start >= limit)); then
      printf 'silver-bullet: orchestrator lock %s stayed busy for %s.%ss; updating without it\n' \
        "$lock" "$((_SB_ORCH_LOCK_WAITED / 10))" "$((_SB_ORCH_LOCK_WAITED % 10))" >&2
      return 1
    fi
    sleep "0.0$((5 + RANDOM % 5))"
    _SB_ORCH_LOCK_WAITED=$((_SB_ORCH_LOCK_WAITED + 1))
  done
}

# sb_orchestrator_with_lock CMD [ARG...]: run CMD (a shell function) holding the lock.
# Re-entrant within one process tree (a subshell inherits the held state).
sb_orchestrator_with_lock() {
  if [[ "${_SB_ORCH_LOCK_HELD:-0}" == "1" ]]; then
    "$@"
    return $?
  fi
  local lock claim="" rc=0
  lock="$(sb_orchestrator_lock_dir)"
  mkdir -p "$(dirname "$lock")" 2>/dev/null || true
  if _sb_orch_lock_acquire "$lock"; then claim="$_SB_ORCH_LOCK_CLAIM"; fi
  _SB_ORCH_LOCK_HELD=1
  "$@" && rc=0 || rc=$?
  _SB_ORCH_LOCK_HELD=0
  # Release only a lock still ours: our claim is present. A holder whose claim was reclaimed
  # (its process judged dead, or the claim far too old) leaves the directory to its new owner.
  if [[ -n "$claim" && -f "$claim" ]]; then
    rm -f -- "$claim"
    rmdir "$lock" 2>/dev/null || true
  fi
  return "$rc"
}

#!/usr/bin/env bash
# scripts/phase-lock.sh, the plugin's copy of the phase-lock helper (R3-03, R3-16, R3-17).
# Re-runs the original helper suites against it, then covers what differs: empty and corrupt
# lock files, session-bound ownership and the wider runtime tag list.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/phase-lock.sh"
DEFAULT_CFG="$TL_REPO_ROOT/templates/silver-bullet.config.json.default"
WORK="$TL_TMP/work"; mkdir -p "$WORK/.planning"
export SB_PHASE_LOCK_FILE="$WORK/.planning/locks.json" SB_DEFAULT_CONFIG="$DEFAULT_CFG"
unset SB_PHASE_LOCK_INHERITED SB_PHASE_LOCK_SESSION
export GIT_CEILING_DIRECTORIES="$TL_TMP"
pl() { tl_run bash "$SCRIPT" "$@"; }
reset() { rm -rf "$SB_PHASE_LOCK_FILE" "$SB_PHASE_LOCK_FILE.lock" "$SB_PHASE_LOCK_FILE.lock.d"; }

# the original suites, pointed at this copy
for suite in test-phase-lock.sh test-phase-lock-edges.sh; do
  tl_run env PL_SCRIPT="$SCRIPT" bash "$TL_REPO_ROOT/tests/scripts/$suite"
  assert_eq "$suite passes against the plugin copy" 0 "$TL_STATUS"
done

# R3-16: an empty lock file is {}; a corrupt one fails every operation and is left untouched
reset; : >"$SB_PHASE_LOCK_FILE"
pl claim 7 claude t
assert_eq "empty lock file: claim works" 0 "$TL_STATUS"
assert_eq "empty lock file: the lock is recorded" claude "$(jq -r '."007".agent_runtime' "$SB_PHASE_LOCK_FILE")"
for bad in 'not json' '[1,2]'; do
  printf '%s\n' "$bad" >"$SB_PHASE_LOCK_FILE"
  for op in "claim 7 claude t" "heartbeat 7 claude" "release 7 claude" "peek 7"; do
    # shellcheck disable=SC2086
    pl $op
    assert_eq "corrupt lock file ($bad): $op fails" 1 "$TL_STATUS"
  done
  assert_eq "corrupt lock file ($bad) is left untouched" "$bad" "$(cat "$SB_PHASE_LOCK_FILE")"
done

# a failing update never truncates the lock file
reset; pl claim 7 claude t
REALJQ="$(command -v jq)"
tl_stub jq "for a in \"\$@\"; do [[ \"\$a\" == *'last_heartbeat_at = '* ]] && exit 1; done; exec $REALJQ \"\$@\""
hash -r
pl heartbeat 7 claude
rm -f "$TL_BIN/jq"; hash -r
assert_eq "failed update: heartbeat fails" 1 "$TL_STATUS"
assert_contains "failed update: refused, not written" "$TL_ERR" "refusing to write"
assert_eq "failed update: the lock is intact" claude "$(jq -r '."007".agent_runtime' "$SB_PHASE_LOCK_FILE")"

# R3-17: session-bound ownership
reset
SB_PHASE_LOCK_SESSION=sessA pl claim 7 claude t
assert_eq "session A claims" 0 "$TL_STATUS"
assert_contains "the owner id names the session" "$(jq -r '."007".owner_id' "$SB_PHASE_LOCK_FILE")" "-sessA"
SB_PHASE_LOCK_SESSION=sessA pl claim 7 claude t
assert_eq "session A re-claims its own lock" 0 "$TL_STATUS"
SB_PHASE_LOCK_SESSION=sessB pl claim 7 claude t
assert_eq "session B is refused" 2 "$TL_STATUS"
SB_PHASE_LOCK_SESSION=sessB pl heartbeat 7 claude
assert_eq "session B cannot heartbeat A's lock" 2 "$TL_STATUS"
SB_PHASE_LOCK_SESSION=sessB pl release 7 claude
assert_eq "session B cannot release A's lock" 2 "$TL_STATUS"
SB_PHASE_LOCK_SESSION=sessA pl heartbeat 7 claude
assert_eq "session A heartbeats" 0 "$TL_STATUS"
# a stolen-stale lock is not touched by its old owner
jq '."007".last_heartbeat_at = "2000-01-01T00:00:00Z"' "$SB_PHASE_LOCK_FILE" >"$SB_PHASE_LOCK_FILE.n" && mv "$SB_PHASE_LOCK_FILE.n" "$SB_PHASE_LOCK_FILE"
SB_PHASE_LOCK_SESSION=sessB pl claim 7 claude t
assert_eq "session B steals the stale lock" 0 "$TL_STATUS"
SB_PHASE_LOCK_SESSION=sessA pl release 7 claude
assert_eq "the old owner cannot release the new owner's lock" 2 "$TL_STATUS"
SB_PHASE_LOCK_SESSION=sessB pl release 7 claude
assert_eq "the new owner releases" 0 "$TL_STATUS"

# every runtime Silver Bullet runs under may hold a lock
for rt in claude codex opencode pi goose hermes; do
  reset; pl claim 9 "$rt" t
  assert_eq "runtime $rt may claim" 0 "$TL_STATUS"
done
reset; pl claim 9 martian t
assert_eq "an unknown runtime is still refused" 3 "$TL_STATUS"

tl_results

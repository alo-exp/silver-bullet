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


# ===== repository-controlled input never reaches arithmetic or a write through a symlink (R3-03) =====
export HOME="$TL_TMP/home"
PRJ="$TL_TMP/prj"
mkproj() { # [ttl-json-value]
  rm -rf "$PRJ"; mkdir -p "$PRJ/.planning/phases/001-x"
  git -C "$PRJ" init -q
  jq -n --argjson t "${1:-1800}" '{multi_agent:{stale_lock_ttl_seconds:$t}}' >"$PRJ/.silver-bullet.json"
  printf '{"001":{"owner_id":"claude-other-1","agent_runtime":"claude","claimed_at":"2026-01-01T00:00:00Z","last_heartbeat_at":"2026-01-01T00:00:00Z","host":"x","pid":1,"intent":"x"}}\n' >"$PRJ/.planning/.phase-locks.json"
}
inprj() { tl_run env -u SB_PHASE_LOCK_FILE -u SB_DEFAULT_CONFIG bash -c 'cd "$1" && shift && exec "$@"' _ "$PRJ" bash "$SCRIPT" "$@"; }
HOSTILE_TTLS=('"BASH_VERSINFO[$(touch '"$TL_TMP"'/PWNED-ttl)]"' '"a[$(touch '"$TL_TMP"'/PWNED-ttl)]"' '"1+$(touch '"$TL_TMP"'/PWNED-ttl)"' '"99999999999"' '"-5"' '"0x10"' '"1e400"' 'null' '{"x":1}')
for ttl in "${HOSTILE_TTLS[@]}"; do
  mkproj "$ttl"
  for op in "claim 1 claude t" "heartbeat 1 claude" "release 1 claude" "peek 1"; do
    # shellcheck disable=SC2086
    inprj $op
    assert_file_absent "hostile ttl $ttl: '$op' runs nothing" "$TL_TMP/PWNED-ttl"
  done
  mkproj "$ttl"
  inprj peek 1
  assert_contains "hostile ttl $ttl falls back to the default (the 2026-01-01 lock is stale)" "$TL_OUT" '"expired":true'
done
mkproj '"0010"'
inprj peek 1
assert_contains "a zero-padded ttl is read as decimal" "$TL_OUT" '"expired":true'
mkproj 99999999
inprj peek 1
assert_not_contains "a large valid ttl keeps the lock fresh" "$TL_OUT" 'expired'

# hostile values inside the lock entry itself
mkproj 1800
jq --arg h "BASH_VERSINFO[\$(touch $TL_TMP/PWNED-hb)]" '."001".last_heartbeat_at=$h | ."001".owner_id=$h | ."001".host=$h' "$PRJ/.planning/.phase-locks.json" >"$PRJ/.planning/x" && mv "$PRJ/.planning/x" "$PRJ/.planning/.phase-locks.json"
for op in "claim 1 claude t" "peek 1" "heartbeat 1 claude" "release 1 claude"; do
  # shellcheck disable=SC2086
  inprj $op
  assert_file_absent "hostile lock-entry values: '$op' runs nothing" "$TL_TMP/PWNED-hb"
done
# the stop-check peek trap
mkproj '"BASH_VERSINFO[$(touch '"$TL_TMP"'/PWNED-ttl)]"'
tl_run bash -c 'cd "$1/.planning/phases/001-x" && source "$2/hooks/lib/runtime-paths.sh" && source "$2/hooks/lib/phase-path.sh" && _phase_lock_peek_on_exit' _ "$PRJ" "$TL_REPO_ROOT"
assert_file_absent "the peek exit trap runs nothing for a hostile ttl" "$TL_TMP/PWNED-ttl"
# the claim hook end to end
mkproj '"BASH_VERSINFO[$(touch '"$TL_TMP"'/PWNED-ttl)]"'
git -C "$PRJ" add -A >/dev/null; git -C "$PRJ" -c user.email=a@b -c user.name=a commit -qm x
PAY="$(jq -cn --arg f "$PRJ/.planning/phases/001-x/001-PLAN.md" '{hook_event_name:"PreToolUse",tool_name:"Edit",session_id:"s1",tool_input:{file_path:$f}}')"
tl_run_stdin "$PAY" bash -c 'cd "$1" && exec bash "$2"' _ "$PRJ" "$TL_REPO_ROOT/hooks/phase-lock-claim.sh"
assert_file_absent "the claim hook runs nothing for a hostile ttl" "$TL_TMP/PWNED-ttl"

# a project's templates/ is repository content: never a config source
mkproj 1800
mkdir -p "$PRJ/templates"
printf '{"multi_agent":{"identity_tags":["gamma"],"stale_lock_ttl_seconds":5}}\n' >"$PRJ/templates/silver-bullet.config.json.default"
jq 'del(.multi_agent)' "$PRJ/.silver-bullet.json" >"$PRJ/x" && mv "$PRJ/x" "$PRJ/.silver-bullet.json"
inprj claim 2 gamma t
assert_eq "tags from the project's templates/ are ignored" 3 "$TL_STATUS"

# never write through a symlink at any file the helper touches (SEC-02)
precious() { printf 'precious user data\n' >"$TL_TMP/victim"; }
sym_case() { # name setup-command...
  local name="$1"; shift
  mkproj 1800; rm -f "$PRJ/.planning/.phase-locks.json"; precious
  "$@"
  for op in "claim 1 claude t" "heartbeat 1 claude" "release 1 claude" "peek 1"; do
    # shellcheck disable=SC2086
    inprj $op
    assert_eq "$name: '$op' refuses" 1 "$TL_STATUS"
    assert_eq "$name: '$op' leaves the target untouched" "precious user data" "$(cat "$TL_TMP/victim")"
  done
  assert_contains "$name: the refusal is explained" "$TL_ERR" "refusing to use a symlink"
}
sym_case "symlinked sidecar" ln -s "$TL_TMP/victim" "$PRJ/.planning/.phase-locks.json.lock"
sym_case "symlinked lock file" ln -s "$TL_TMP/victim" "$PRJ/.planning/.phase-locks.json"
sym_case "symlinked mkdir mutex" ln -s "$TL_TMP/victim" "$PRJ/.planning/.phase-locks.json.lock.d"
mkproj 1800; precious; mkdir -p "$TL_TMP/realplan"; rm -rf "$PRJ/.planning"; ln -s "$TL_TMP/realplan" "$PRJ/.planning"
inprj claim 1 claude t
assert_eq "symlinked .planning: refused" 1 "$TL_STATUS"
assert_eq "symlinked .planning: nothing written behind it" "" "$(ls -A "$TL_TMP/realplan")"
# the claim hook (fail-open) leaves the target alone as well
mkproj 1800; rm -f "$PRJ/.planning/.phase-locks.json"; precious; ln -s "$TL_TMP/victim" "$PRJ/.planning/.phase-locks.json.lock"
tl_run_stdin "$PAY" bash -c 'cd "$1" && exec bash "$2"' _ "$PRJ" "$TL_REPO_ROOT/hooks/phase-lock-claim.sh"
assert_eq "claim hook: exits 0 (fail-open)" 0 "$TL_STATUS"
assert_eq "claim hook: the symlink target is untouched" "precious user data" "$(cat "$TL_TMP/victim")"
# an ordinary run leaves no predictable temp file behind and writes only the lock file and sidecar
mkproj 1800; rm -f "$PRJ/.planning/.phase-locks.json"
inprj claim 1 claude t
assert_eq "an honest claim succeeds" 0 "$TL_STATUS"
assert_eq "only the lock file and its sidecar exist" ".phase-locks.json .phase-locks.json.lock phases" "$(ls -A "$PRJ/.planning" | tr '\n' ' ' | sed 's/ $//')"

# config fallbacks: a bare plugin tree (no templates/) and a project without config
BARE="$TL_TMP/bare"; mkdir -p "$BARE/scripts"; ln -s "$SCRIPT" "$BARE/scripts/phase-lock.sh"
mkproj 1800; rm -f "$PRJ/.silver-bullet.json"
bare() { tl_run env -u SB_PHASE_LOCK_FILE -u SB_DEFAULT_CONFIG bash -c 'cd "$1" && shift && exec "$@"' _ "$PRJ" bash "$BARE/scripts/phase-lock.sh" "$@"; }
bare claim 2 martian t
assert_eq "no template anywhere: unknown runtime refused" 3 "$TL_STATUS"
assert_contains "no template anywhere: the built-in tag list" "$TL_ERR" "allowed: claude codex opencode pi goose hermes forge"
bare peek 1
assert_contains "no template anywhere: the default ttl of 1800 s applies" "$TL_OUT" '"expired":true'

tl_results

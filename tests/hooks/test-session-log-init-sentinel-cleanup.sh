#!/usr/bin/env bash
# hooks/session-log-init.sh: stopping the autonomous timeout sentinel stops its sleep too.
# The sentinel pid recorded in sentinel-pid is what every cleanup path signals (a new
# session, a failed lock, test teardown); the sleep it waits on must not outlive it.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"

HOOK="$TL_REPO_ROOT/hooks/session-log-init.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset PROJECT_ROOT_OVERRIDE SESSION_LOG_TEST_DIR

ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
ec_freeze_date "2026-01-15"
PAYLOAD="$(jq -cn --arg c "echo autonomous > $SB_RUNTIME_HOME_ROOT/.silver-bullet/mode" '{tool_name:"Bash",tool_input:{command:$c}}')"
# A sleep length no other process on the machine uses, so the child can be found by it.
SECS=4171

sentinel_children() { # pid -> the sleep processes it started
  ps -A -o pid= -o ppid= -o args= | awk -v p="$1" -v n="$SECS" '$2 == p && $3 == "sleep" && $4 == n && NF == 4 { print $1 }'
}
stray_sleeps() {
  ps -A -o pid= -o args= | awk -v n="$SECS" '$2 == "sleep" && $3 == n && NF == 3 { print $1 }'
}
cleanup() {
  local p
  for p in $(stray_sleeps); do kill "$p" 2>/dev/null || true; done
  tl_cleanup
}
trap cleanup EXIT

mkdir -p "$SD"
printf 'autonomous' >"$SD/mode"
SENTINEL_SLEEP_OVERRIDE=$SECS tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_contains "autonomous session log created" "$TL_OUT" "Session log created"
sentinel="$(cut -d: -f1 "$SD/sentinel-pid")"
child=""
for _ in $(seq 1 50); do child="$(sentinel_children "$sentinel")"; [[ -n "$child" ]] && break; command -p sleep 0.1; done
assert_match "the sentinel waits on its own sleep" '^[0-9]+$' "$child"

kill "$sentinel"
for _ in $(seq 1 50); do kill -0 "$child" 2>/dev/null || break; command -p sleep 0.1; done
assert_eq "stopping the sentinel stops its sleep" "1" "$(kill -0 "$child" 2>/dev/null && echo 0 || echo 1)"
assert_file_absent "a stopped sentinel writes no timeout" "$SD/timeout"
# R3-18: the sentinel removes its own lock when it is stopped, so a recycled pid has no lock and
# the cleanup path never signals an unrelated process.
for _ in $(seq 1 50); do ls "$SD"/sentinel-lock-* >/dev/null 2>&1 || break; command -p sleep 0.1; done
assert_eq "a stopped sentinel removes its lock" "0" "$(ls "$SD"/sentinel-lock-* 2>/dev/null | wc -l | tr -d ' ')"

# A sentinel that reaches its timeout removes the lock too (and writes the marker).
rm -f "$SD/sentinel-pid" "$SD/timeout"
rm -rf "${EC_PROJ:?}/docs/sessions"
SENTINEL_SLEEP_OVERRIDE=1 tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
for _ in $(seq 1 60); do [[ -f "$SD/timeout" ]] && break; command -p sleep 0.1; done
assert_eq "the timeout marker is written" "TIMEOUT" "$(cat "$SD/timeout" 2>/dev/null || true)"
for _ in $(seq 1 50); do ls "$SD"/sentinel-lock-* >/dev/null 2>&1 || break; command -p sleep 0.1; done
assert_eq "a timed-out sentinel removes its lock" "0" "$(ls "$SD"/sentinel-lock-* 2>/dev/null | wc -l | tr -d ' ')"

# A recycled pid whose lock is gone is never signalled: start an unrelated process, record its
# pid as a stale sentinel, and run the hook again.
bystander_sleep=4172
sleep "$bystander_sleep" &
bystander=$!
printf '%s:%s\n' "$bystander" "stale-token" >"$SD/sentinel-pid"
rm -rf "${EC_PROJ:?}/docs/sessions"
tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$HOOK"
assert_eq "an unrelated process with a stale sentinel record survives" "0" "$(kill -0 "$bystander" 2>/dev/null && echo 0 || echo 1)"
kill "$bystander" 2>/dev/null || true

tl_results

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

tl_results

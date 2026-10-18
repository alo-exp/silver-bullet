#!/usr/bin/env bash
# monitor-enterprise-e2e-supervisor.sh: restarts a dead matrix monitor, logs state changes and UX/quota
# notes, exits on COMPLETE / max runtime / TERM. The monitor, kill, sleep and date are stubs; the
# stub sleep ends the loop by terminating the supervisor (and only a process running this script).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f4-helpers.sh"
tl_init
f4_setup

R="$TL_TMP/root"
f4_stage "$R"
SUP="$R/scripts/monitor-enterprise-e2e-supervisor.sh"
e2e_stage_override "$R" scripts/monitor-enterprise-e2e-matrix.sh 'echo "monitor-started" >>"$F4_CTL/monitor-ran"'
PIDF="$R/.e2e-matrix-monitor.pid"
LOGF="$R/.e2e-matrix-supervisor.log"
STATUS="$R/.e2e-matrix-monitor-status.txt"

export F4_LOOP_SLEEP=4242 F4_PARENT_MARK=monitor-enterprise-e2e-supervisor.sh
export SB_E2E_SUPERVISOR_INTERVAL=4242

reset() {
  rm -f "$PIDF" "$LOGF" "$STATUS" "$F4_CTL"/loop-count "$F4_CTL"/monitor-ran "$F4_CTL"/alive
  : >"$F4_CALLS"
  unset F4_LOOP_MAX
}
sup() { tl_run timeout 20 bash "$SUP"; }

# --- cd into the SB root fails: exits non-zero before doing anything ---
reset
tl_run env F4_CD_FAIL="$R" timeout 20 bash "$SUP"
assert_eq "cd failure exits 1" "1" "$TL_STATUS"
assert_file_absent "cd failure writes no log" "$LOGF"
assert_file_absent "cd failure starts no monitor" "$F4_CTL/monitor-ran"

# --- max runtime reached before the first poll: no monitor is started ---
reset
tl_run env SB_E2E_SUPERVISOR_MAX_SEC=-1 timeout 20 bash "$SUP"
assert_eq "max runtime exits 0" "0" "$TL_STATUS"
assert_contains "max runtime logged" "$(cat "$LOGF")" "max runtime -1s reached"
assert_file_absent "max runtime starts no monitor" "$F4_CTL/monitor-ran"
assert_contains "max runtime echoed to stdout via tee" "$TL_OUT" "max runtime -1s reached"

# --- dead monitor is restarted, state change logged once, TERM exits cleanly ---
reset
printf 'batch PID: 77 — RUNNING\ncurrent row (log): 5\nother\n' >"$STATUS"
sup
assert_eq "dead monitor run exits 0 on TERM" "0" "$TL_STATUS"
f4_wait_file "$F4_CTL/monitor-ran"
assert_eq "monitor started once" "monitor-started" "$(cat "$F4_CTL/monitor-ran")"
log="$(cat "$LOGF")"
assert_contains "restart logged" "$log" "monitor dead — restarting"
assert_contains "start logged" "$log" "starting monitor"
assert_contains "pid logged" "$log" "monitor pid="
assert_match "pid file holds a number" '^[0-9]+$' "$(tr -d '[:space:]' <"$PIDF")"
assert_contains "state change logged" "$log" "state change: batch PID: 77 — RUNNING current row (log): 5"
assert_contains "signal exit logged" "$log" "supervisor signal — exiting"
assert_contains "interval sleep used" "$(cat "$F4_CALLS")" "sleep 4242"

# --- alive monitor is left alone; empty/blank pid file counts as dead ---
reset
echo 31337 >"$PIDF"
f4_alive 31337
sup
assert_eq "alive monitor run exits 0" "0" "$TL_STATUS"
assert_file_absent "alive monitor not restarted" "$F4_CTL/monitor-ran"
assert_not_contains "no restart logged" "$(cat "$LOGF")" "monitor dead"
assert_contains "liveness probed with kill -0" "$(cat "$F4_CALLS")" "kill -0 31337"

reset
printf '  \n' >"$PIDF"
sup
f4_wait_file "$F4_CTL/monitor-ran"
assert_contains "blank pid file means dead" "$(cat "$LOGF")" "monitor dead — restarting"

reset
echo 424242 >"$PIDF"
sup
f4_wait_file "$F4_CTL/monitor-ran"
assert_contains "pid not in alive list means dead" "$(cat "$LOGF")" "monitor dead — restarting"

# --- UX note is logged once even over several polls ---
reset
echo 31337 >"$PIDF"
f4_alive 31337
echo 'row 3: hookEventName seen' >"$STATUS"
F4_LOOP_MAX=3 sup
assert_eq "ux run exits 0" "0" "$TL_STATUS"
assert_eq "three polls happened" "3" "$(cat "$F4_CTL/loop-count")"
assert_eq "UX note logged exactly once" "1" "$(grep -c 'UX note' "$LOGF")"
reset
echo 31337 >"$PIDF"
f4_alive 31337
echo 'Stop hook error in turn' >"$STATUS"
sup
assert_contains "Stop hook error also triggers the UX note" "$(cat "$LOGF")" "UX note: hookEventName/Stop hook seen"

# --- quota note ---
reset
echo 31337 >"$PIDF"
f4_alive 31337
echo 'API Error 429 from provider' >"$STATUS"
sup
assert_contains "429 noted" "$(cat "$LOGF")" "state: quota/429 noted"
reset
echo 31337 >"$PIDF"
f4_alive 31337
echo 'token QUOTA exhausted' >"$STATUS"
sup
assert_contains "QUOTA noted" "$(cat "$LOGF")" "state: quota/429 noted"

# --- COMPLETE exits before sleeping ---
reset
echo 31337 >"$PIDF"
f4_alive 31337
echo 'current row: all - COMPLETE' >"$STATUS"
sup
assert_eq "complete exits 0" "0" "$TL_STATUS"
assert_contains "complete logged" "$(cat "$LOGF")" "matrix COMPLETE — supervisor exiting"
assert_not_contains "complete does not reach the interval sleep" "$(cat "$F4_CALLS")" "sleep 4242"

# --- missing status file: no state change text, still runs ---
reset
echo 31337 >"$PIDF"
f4_alive 31337
sup
assert_eq "no status file exits 0" "0" "$TL_STATUS"
assert_not_contains "no UX note without status" "$(cat "$LOGF")" "UX note"

tl_results

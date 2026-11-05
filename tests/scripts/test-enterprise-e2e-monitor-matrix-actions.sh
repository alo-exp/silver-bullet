#!/usr/bin/env bash
# monitor-enterprise-e2e-matrix.sh, restart paths: incomplete-row selection, the forced-batch environment,
# auto-restart off, BSD stat fallbacks and loop resilience. Stubs: tests/lib/enterprise-e2e-f4-helpers.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f4-helpers.sh"
tl_init claude
f4_setup
f4_mon_setup

NOW=1000000
P="$F4_CTL"
batch_ran() { f4_wait_file "$P/batch-ran" && cat "$P/batch-ran"; }
roster() {
  local spec
  : >"$MLOG"
  for spec in "$@"; do
    printf '=== Row %s: wf ===\n' "${spec%%:*}" >>"$MLOG"
    [[ "${spec#*:}" == none ]] || printf '  %s: x\n' "${spec#*:}" >>"$MLOG"
  done
}
live_batch() { echo "${1:-7000}" >"$BPID"; f4_alive "${1:-7000}"; }
# idle_state SECONDS: the matrix log has not grown for SECONDS, row attempt log is fresh
idle_state() {
  printf 'LAST_GROWTH_EPOCH=%s\nLAST_GROWTH_BYTES=%s\nLAST_ROW_BYTES=3\n' "$((NOW - $1))" "$(wc -c <"$MLOG" | tr -d ' ')" >"$STATE"
}

# --- dead batch: incomplete rows are restarted with the forced-batch environment ---
f4_mon_reset
{
  printf '=== Row 1: a ===\n  PASS: x\n'
  printf '=== Row 5: b ===\n  SKIP: x\n'
  printf '=== Row 7: c ===\n  DRY RUN PASS\n'
  printf '=== Row 8: d ===\n  PASS: x\n  FAIL: later\n'
  printf '=== Row 9: e ===\n'
  printf '=== Row 10: f ===\n  PASS: x\n'
  printf '=== Row 21: g PASS ===\n'
} >"$MLOG"
f4_mon_run SB_E2E_MATRIX_ROWS="1 5 7 8 9 10 21" SB_E2E_MATRIX_DRY_RUN=1
out="$(batch_ran)"
assert_contains "incomplete rows passed (FAIL after PASS, empty; 21 via PASS ===; 22 appended)" "$out" "rows=[8 9 22]"
assert_contains "batch runs from the SB root" "$out" "pwd=$R "
assert_contains "forced host" "$out" "host=claude"
assert_contains "ledger forwarded" "$out" "ledger=$LEDGER"
assert_contains "lock file forwarded" "$out" "lock=$R/.e2e-live-test.lock"
assert_contains "batch pid file forwarded" "$out" "pidfile=$BPID"
assert_contains "settings export forced on, force batch, clean env off" "$out" "force=1 skipexp=0 clean=0"
assert_contains "matrix log and fixture forwarded" "$out" "log=$MLOG fixture=$APP"
assert_contains "inherited DRY_RUN stripped" "$out" "dry=unset"
assert_contains "api key strategy" "$out" "strategy=arrow"
assert_match "new batch pid recorded" '^[0-9]+$' "$(tr -d '[:space:]' <"$BPID")"
assert_contains "start logged" "$(cat "$POLL")" "ACTION: starting batch rows: 8 9 22"
assert_contains "restart logged" "$(cat "$POLL")" "ACTION: batch not running — restarting incomplete rows"
assert_contains "state has batch start" "$(cat "$STATE")" "LAST_BATCH_START=2026-01-01T00:00:00Z"
assert_contains "state has growth epoch" "$(cat "$STATE")" "LAST_GROWTH_EPOCH=$NOW"
assert_contains "status says RESTARTED" "$(cat "$STATUS")" "— RESTARTED"
# a restarted state key is replaced, not duplicated
assert_eq "state keys unique" "1" "$(grep -c '^LAST_GROWTH_EPOCH=' "$STATE")"

# fixture default: with SB_TEST_ENTERPRISE_APP_ROOT unset and a host without test_app_root in hosts.json (codex),
# the batch gets the sibling of the SB root's parent
f4_mon_reset
roster 1:PASS 5:none
f4_mon_run -u SB_TEST_ENTERPRISE_APP_ROOT SB_E2E_LIVE_RUNTIME=codex
want_fixture="$(cd "$R/../.." && pwd)/enterprise-grade-test-app"
assert_contains "unset fixture env defaults to <SB_ROOT/../..>/enterprise-grade-test-app" "$(batch_ran)" "fixture=$want_fixture "

# row 21/22 completion needs the PASS ===  marker for rows listed in the row args
f4_mon_reset
roster 1:PASS
printf '=== Row 21: a FAIL ===\n' >>"$MLOG"
f4_mon_run SB_E2E_MATRIX_ROWS="1 21 22"
assert_contains "rows 21/22 without PASS === are restarted" "$(batch_ran)" "rows=[21 22 21 22]"
f4_mon_reset
roster 1:PASS
printf '=== Row 21: a PASS ===\n=== Row 22: b PASS ===\n' >>"$MLOG"
f4_mon_run SB_E2E_MATRIX_ROWS="1 21 22"
assert_file_absent "everything done: nothing to start" "$P/batch-ran"
assert_contains "all-done state reported from reconcile" "$(cat "$STATUS")" "— STALE"

# existing ledger / lock / pidfile env variants
f4_mon_reset
roster 1:none
f4_mon_run SB_E2E_LIVE_TEST_LOCK_FILE="$TL_TMP/my.lock"
assert_contains "explicit lock file forwarded" "$(batch_ran)" "lock=$TL_TMP/my.lock"

# --- auto restart off: the operator owns the batch ---
f4_mon_reset
roster 1:none
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_file_absent "auto-restart off starts nothing" "$P/batch-ran"
assert_contains "operator wait" "$(cat "$STATUS")" "— WAIT_OPERATOR"
f4_mon_reset
roster 1:none
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=false
assert_file_absent "'false' also disables restarts" "$P/batch-ran"

# --- BSD stat fallbacks ---
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
idle_state 3000
printf 'abc' >"$R/.e2e-row5-attempt.log"
touch -d "@$((NOW - 4000))" "$R/.e2e-row5-attempt.log"
f4_bsd_stat
f4_mon_run
assert_contains "BSD stat: epoch read through -f %m" "$(cat "$POLL")" "STALL: row=5 idle=3000s"
assert_contains "BSD stat: formatted mtime through -f %Sm -t" "$(cat "$STATUS")" "row5-attempt.log: 3 bytes (BSD-TIME)"
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
idle_state 3000
printf 'abc' >"$R/.e2e-row5-attempt.log"
f4_mon_run F4_STAT_MODE=fail
assert_contains "stat failing everywhere: mtime unknown" "$(cat "$STATUS")" "row5-attempt.log: 3 bytes (?)"
assert_contains "stat failing: epoch 0 means very old, so the log idle decides" "$(cat "$POLL")" "STALL: row=5 idle=3000s"
rm -f "$TL_BIN/stat"

# --- main loop keeps going when poll_once fails and when the first sleep fails ---
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
f4_mon_run F4_PRINTF_FAIL_MATCH='batch=RUNNING' F4_LOOP_MAX=2
assert_eq "monitor survives failing poll_once" "0" "$TL_STATUS"
assert_eq "two polls ran" "2" "$(cat "$P/loop-count")"
assert_eq "poll_once failure noted each time" "2" "$(grep -c 'poll_once error (continuing)' "$POLL")"
assert_not_contains "the failing summary line was not written" "$(cat "$POLL")" "batch=RUNNING"
assert_contains "status still written" "$(cat "$STATUS")" "batch PID: 7000 — RUNNING"

f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
touch "$P/loop-sleep-fail-first"
f4_mon_run F4_LOOP_MAX=2
assert_eq "failed first sleep is retried" "2" "$(cat "$P/loop-count")"

tl_results

#!/usr/bin/env bash
# monitor-enterprise-e2e-matrix.sh, ledger and issue paths: row completion, ledger reconciliation (COMPLETE /
# mismatch / stale) and issue detection (429, network, hook notes). Stubs: tests/lib/enterprise-e2e-f4-helpers.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f4-helpers.sh"
tl_init claude
f4_setup
f4_mon_setup

NOW=1000000
pollhas() { grep -qF -- "$1" "$POLL"; }
roster() { # roster ROW:STATUS...  -> matrix log with rows in order
  local spec
  : >"$MLOG"
  for spec in "$@"; do
    printf '=== Row %s: wf ===\n' "${spec%%:*}" >>"$MLOG"
    [[ "${spec#*:}" == none ]] || printf '  %s: x\n' "${spec#*:}" >>"$MLOG"
  done
}
live_batch() { # a running batch recorded in the pid file
  echo "${1:-7000}" >"$BPID"
  f4_alive "${1:-7000}"
}

# --- completion and ledger reconciliation ---
complete_log() {
  roster 1:PASS 5:PASS 21:none 22:none
  printf 'Total: 22 / 22\n' >>"$MLOG"
}
f4_mon_reset
live_batch 7000
complete_log
f4_mon_ledger Pass
f4_mon_run
assert_eq "complete exits 0 on its own" "0" "$TL_STATUS"
assert_contains "complete logged" "$(cat "$POLL")" "COMPLETE: matrix 22/22 — ledger reconcile OK — monitor exiting"
assert_contains "complete status" "$(cat "$STATUS")" "— COMPLETE"
assert_file_absent "batch pid file removed on completion" "$BPID"
assert_not_contains "completion exits before sleeping" "$(cat "$F4_CALLS")" "sleep 4242"

f4_mon_reset
live_batch 7000
complete_log
f4_mon_ledger Fail
f4_mon_run
assert_contains "ledger mismatch keeps monitor alive" "$(cat "$POLL")" "LEDGER_MISMATCH: matrix log 22/22 but ledger is not 22 PASS — not exiting"
assert_contains "monitor kept polling" "$(cat "$F4_CALLS")" "sleep 4242"

f4_mon_reset
live_batch 7000
complete_log
f4_mon_run
assert_contains "missing ledger also not complete" "$(cat "$POLL")" "LEDGER_MISMATCH: matrix log 22/22"

# rows all complete but log has no 22/22 summary: stale or in-progress depending on the ledger
all_rows_log() { roster 1:PASS 5:PASS; printf '=== Row 21: x PASS ===\n=== Row 22: y PASS ===\n' >>"$MLOG"; }
f4_mon_reset
live_batch 7000
all_rows_log
f4_mon_run
assert_contains "no ledger -> stale" "$(cat "$POLL")" "STALE: matrix log complete but ledger missing/stale — not exiting"

f4_mon_reset
live_batch 7000
all_rows_log
f4_mon_ledger Pass
f4_mon_run
assert_contains "valid ledger but no 22/22 line -> in progress" "$(cat "$POLL")" "IN_PROGRESS: matrix log complete; ledger reconcile=IN_PROGRESS"

# --- issue handling ---
f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
printf '429 usage limit hit\n' >>"$MLOG"
f4_mon_run
assert_contains "429 triggers a wait" "$(cat "$POLL")" "ACTION: 429 detected — waiting 7s"
assert_contains "429 sleeps the quota interval" "$(cat "$F4_CALLS")" "sleep 7"
assert_contains "quota time recorded" "$(cat "$STATE")" "LAST_QUOTA_ACTION=$NOW"

f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
printf 'Token plan exhausted\n' >>"$MLOG"
f4_mon_run
assert_contains "token plan wording is a 429 too" "$(cat "$POLL")" "ACTION: 429 detected"

f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
printf '429 usage limit hit\n' >>"$MLOG"
echo "LAST_QUOTA_ACTION=$((NOW - 3))" >"$STATE"
f4_mon_run
assert_not_contains "recent 429 action is not repeated" "$(cat "$POLL")" "ACTION: 429 detected"

f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
printf 'ENOTFOUND api.example\n' >>"$MLOG"
f4_mon_run
assert_contains "network error waits the random interval" "$(cat "$POLL")" "ACTION: network error — waiting 11s"
assert_contains "network sleep" "$(cat "$F4_CALLS")" "sleep 11"
assert_contains "network time recorded" "$(cat "$STATE")" "LAST_NET_ACTION=$NOW"

f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
printf 'Unable to connect\n' >>"$MLOG"
echo "LAST_NET_ACTION=$((NOW - 3))" >"$STATE"
f4_mon_run
assert_not_contains "recent network action not repeated" "$(cat "$POLL")" "network error"

f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
printf 'Stop hook error x\nhookEventName y\n  FAIL: z\n' >>"$MLOG"
f4_mon_run
assert_contains "stop-hook noted" "$(cat "$POLL")" "NOTE: detected stop-hook in recent log (no auto-kill)"
assert_contains "hookEventName noted" "$(cat "$POLL")" "NOTE: detected hookEventName in recent log (no auto-kill)"
assert_contains "FAIL noted" "$(cat "$POLL")" "NOTE: detected FAIL in recent log (no auto-kill)"
assert_not_contains "notes never kill anything" "$(cat "$F4_CALLS")" "pkill"

# only the recent window is scanned
f4_mon_reset
live_batch 7000
{ printf '429 old\n'; for ((i = 0; i < 400; i++)); do echo filler; done; } >"$MLOG"
printf '=== Row 5: wf ===\n' >>"$MLOG"
f4_mon_run
assert_not_contains "old 429 outside the window ignored" "$(cat "$POLL")" "429 detected"

tl_results

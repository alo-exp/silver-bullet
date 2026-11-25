#!/usr/bin/env bash
# monitor-enterprise-e2e-matrix.sh, discovery and stall paths: startup bookkeeping, status block, batch
# discovery and adoption (pgrep, live-test driver, operator batch), growth/stall bookkeeping, per-host agent
# lookups. Stubs: tests/lib/enterprise-e2e-f4-helpers.sh; the stub sleep ends the loop by terminating the monitor.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f4-helpers.sh"
tl_init claude
f4_setup
f4_mon_setup

NOW=1000000
P="$F4_CTL" # shorthand for pgrep/ps fixtures (recreated by f4_mon_reset)
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
  f4_trust "$BPID" "${1:-7000}"
}

# --- startup bookkeeping ---
f4_mon_reset
live_batch
roster 1:PASS
f4_mon_run
assert_eq "monitor exits 0 on TERM" "0" "$TL_STATUS"
assert_match "monitor pid file holds its pid" '^[0-9]+$' "$(tr -d '[:space:]' <"$MPID")"
assert_contains "start banner" "$(head -1 "$POLL")" "=== monitor started 2026-01-01T00:00:00Z pid=$(cat "$MPID") interval=4242s log=$MLOG ==="
assert_contains "signal exit logged" "$(cat "$POLL")" "monitor $(cat "$MPID") received signal — exiting"
assert_contains "interval sleep" "$(cat "$F4_CALLS")" "sleep 4242"

# --- status block with a running batch ---
f4_mon_reset
live_batch 7000
echo '  42:10' >"$P/ps.7000.etime"
printf '1234 /usr/bin/claude-interactive-invoke.expect\n' >"$P/pgrep.claude-interactive"
roster 1:PASS 5:none
printf '  FAIL: broken\n429 too many\n' >>"$MLOG"
f4_mon_run
st="$(cat "$STATUS")"
assert_contains "status header" "$st" "=== Matrix monitor poll 2026-01-01T00:00:00Z ==="
assert_contains "batch pid and state" "$st" "batch PID: 7000 — RUNNING"
assert_contains "elapsed from ps" "$st" "elapsed batch: 42:10"
assert_contains "current row from log" "$st" "current row (log): 5"
assert_contains "issues summarised" "$st" "issues (recent): 429,FAIL"
assert_contains "agent children listed" "$st" "  1234 /usr/bin/claude-interactive-invoke.expect"
assert_contains "retry policy line" "$st" "retry policy: 429→7s; ENOTFOUND→11-11s; DRY_RUN unset"
assert_contains "intervals line" "$st" "poll interval: 4242s; stall=2700s; hung=5400s"
assert_contains "log tail indented" "$st" "    PASS: x"
assert_eq "status file equals poll block" "0" "$(grep -c 'poll_once error' "$POLL" || true)"
assert_eq "running batch pid kept in pid file" "7000" "$(cat "$BPID")"
assert_contains "poll summary line" "$(cat "$POLL")" "poll 2026-01-01T00:00:00Z row=5 batch=RUNNING"

# ps failing for etime -> "?"
f4_mon_reset
live_batch 7000
roster 1:PASS
f4_mon_run
assert_contains "elapsed unknown when ps fails" "$(cat "$STATUS")" "elapsed batch: ?"
assert_contains "no agent children shown as blank" "$(cat "$STATUS")" "claude/expect:"

# row-attempt log sizes are listed per row
f4_mon_reset
live_batch 7000
roster 1:PASS
printf 'abc' >"$R/.e2e-row5-attempt.log"
printf 'abcdef' >"$R/.e2e-row12-attempt.log"
touch -d '@1700000000' "$R/.e2e-row5-attempt.log" "$R/.e2e-row12-attempt.log"
f4_mon_run TZ=UTC
assert_contains "row 5 attempt log listed with its mtime" "$(cat "$STATUS")" "  row5-attempt.log: 3 bytes (2023-11-14 22:13)"
assert_contains "row 12 attempt log listed with its mtime" "$(cat "$STATUS")" "  row12-attempt.log: 6 bytes (2023-11-14 22:13)"
assert_not_contains "missing attempt logs not listed" "$(cat "$STATUS")" "row7-attempt.log"

# --- R14-10: a runner is never adopted by command-line matching ---
# a runner of another checkout, found by every matching pgrep pattern, is neither adopted nor signalled
f4_mon_reset
roster 1:PASS
printf '\n100\n101\n' >"$P/pgrep.(run-enterprise-e2e-matrix"
echo 1 >"$P/ps.100.ppid"
echo "bash scripts/run-enterprise-e2e-matrix.sh 1 5" >"$P/ps.100.command"
printf '102\n' >"$P/pgrep.-P 100"
echo "/opt/bin/claude --model opus" >"$P/ps.102.command"
f4_alive 100 101 102
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_file_absent "foreign runner is not adopted into the pid file" "$BPID"
assert_contains "status shows no adopted batch" "$(cat "$STATUS")" "batch PID: none — WAIT_OPERATOR"
assert_not_contains "foreign runner and its claude child are never signalled" "$(cat "$F4_CALLS")" "kill -TERM 10"

# a bare pid file (no identity record) is not trusted even when the pid is alive
f4_mon_reset
roster 1:PASS
echo 7000 >"$BPID"
f4_alive 7000
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "a bare pid is not a running batch" "$(cat "$STATUS")" "batch PID: none — WAIT_OPERATOR"

# a reused pid (same number, different start time) is not our runner
f4_mon_reset
roster 1:PASS
f4_trust "$BPID" 7000
echo "Tue Feb  2 12:00:00 2026" >"$P/ps.7000.lstart"
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "a reused pid is not a running batch" "$(cat "$STATUS")" "batch PID: none — WAIT_OPERATOR"
# ... nor when only the process group differs
f4_mon_reset
roster 1:PASS
f4_trust "$BPID" 7000
echo 1 >"$P/ps.7000.pgid"
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "a different process group is not our batch" "$(cat "$STATUS")" "batch PID: none — WAIT_OPERATOR"
# ... nor when the record names another pid
f4_mon_reset
roster 1:PASS
f4_trust "$BPID" 7000
echo 7001 >"$BPID"
f4_alive 7001
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "a record for another pid is not trusted" "$(cat "$STATUS")" "batch PID: none — WAIT_OPERATOR"

# --- live-test driver active: its runner is trusted only through its own identity record ---
f4_mon_reset
roster 1:PASS
echo "9000 run-enterprise-e2e-live-test.sh" >"$P/pgrep.live-test"
f4_mon_run
assert_contains "live driver without a trusted runner defers" "$(cat "$POLL")" "defer restart: live-test driver active"
assert_contains "state WAIT_LIVE_TEST" "$(cat "$STATUS")" "— WAIT_LIVE_TEST"
assert_file_absent "no batch started" "$P/batch-ran"

f4_mon_reset
roster 1:PASS
echo "9000 run-enterprise-e2e-live-test.sh" >"$P/pgrep.live-test"
live_batch 700
f4_mon_run
assert_contains "the driver's own runner (identity record) is RUNNING" "$(cat "$STATUS")" "batch PID: 700 — RUNNING"

# --- growth / stall bookkeeping ---
f4_mon_reset
live_batch 7000
roster 1:PASS 5:none
bytes="$(wc -c <"$MLOG" | tr -d ' ')"
f4_mon_run
assert_contains "growth epoch recorded" "$(cat "$STATE")" "LAST_GROWTH_EPOCH=$NOW"
assert_contains "growth bytes recorded" "$(cat "$STATE")" "LAST_GROWTH_BYTES=$bytes"

STALL_SETUP() { # idle for $1 seconds, log unchanged, row 5 running with an attempt log of mtime age $2
  f4_mon_reset
  live_batch 7000
  roster 1:PASS 5:none
  printf '1234 claude-interactive-invoke.expect\n' >"$P/pgrep.claude-interactive"
  printf 'LAST_GROWTH_EPOCH=%s\nLAST_GROWTH_BYTES=%s\n' "$((NOW - $1))" "$(wc -c <"$MLOG" | tr -d ' ')" >"$STATE"
  printf 'abc' >"$R/.e2e-row5-attempt.log"
  touch -d "@$((NOW - $2))" "$R/.e2e-row5-attempt.log"
  echo "LAST_ROW_BYTES=3" >>"$STATE"
}
STALL_SETUP 3000 4000
f4_mon_run
assert_contains "idle log and idle attempt log is a stall" "$(cat "$POLL")" "STALL: row=5 idle=3000s (threshold 2700)"
assert_not_contains "stall below hung threshold does not kill" "$(cat "$F4_CALLS")" "pkill"

# boundary: idle exactly at the stall threshold acts, one second less does not
STALL_SETUP 2700 4000
f4_mon_run
assert_contains "idle == STALL_SEC is a stall" "$(cat "$POLL")" "STALL: row=5 idle=2700s (threshold 2700)"
STALL_SETUP 2699 4000
f4_mon_run
assert_not_contains "idle == STALL_SEC-1 is not a stall" "$(cat "$POLL")" "STALL:"
STALL_SETUP 2700 4000
f4_mon_run SB_E2E_MATRIX_STALL_SEC=2701
assert_not_contains "threshold is configurable (2701 > idle 2700)" "$(cat "$POLL")" "STALL:"

STALL_SETUP 3000 10
f4_mon_run
assert_not_contains "recent attempt log output clears the stall" "$(cat "$POLL")" "STALL:"
assert_contains "poll completes (mtime parsed as a number)" "$(cat "$POLL")" "poll 2026-01-01T00:00:00Z row=5 batch=RUNNING"
assert_contains "monitor reached its sleep" "$(cat "$F4_CALLS")" "sleep 4242"

STALL_SETUP 3000 4000
echo "LAST_ROW_BYTES=1" >>"$STATE" # attempt log size changed since last poll
f4_mon_run
assert_not_contains "attempt log growth clears the stall" "$(cat "$POLL")" "STALL:"
assert_contains "attempt bytes recorded" "$(cat "$STATE")" "LAST_ROW_BYTES=3"

STALL_SETUP 3000 4000
rm -f "$R/.e2e-row5-attempt.log"
f4_mon_run
assert_contains "no attempt log: log idle alone stalls" "$(cat "$POLL")" "STALL: row=5 idle=3000s"

STALL_SETUP 100 4000
f4_mon_run
assert_not_contains "short idle is no stall" "$(cat "$POLL")" "STALL:"

# stall needs a known row and a running batch
f4_mon_reset
live_batch 7000
: >"$MLOG"
printf 'LAST_GROWTH_EPOCH=1\nLAST_GROWTH_BYTES=0\n' >"$STATE"
f4_mon_run
assert_not_contains "unknown row never stalls" "$(cat "$POLL")" "STALL:"
assert_contains "current row unknown in poll summary" "$(cat "$POLL")" "row=? batch=RUNNING"

# --- missing log is recreated; byte count falls back when the library helper is gone ---
f4_mon_reset
live_batch 7000
f4_mon_run
assert_file_exists "matrix log recreated" "$MLOG"

f4_mon_reset
live_batch 7000
roster 1:PASS
bytes="$(wc -c <"$MLOG" | tr -d ' ')"
f4_mon_run F4_NO_LOGBYTES=1
assert_contains "fallback byte count used" "$(cat "$STATUS")" "matrix log bytes: $bytes"

f4_mon_reset
live_batch 7000
tl_run env F4_NO_LOGBYTES=1 timeout 30 bash -c "$F4_LAUNCH" _ "$MON"
assert_contains "fallback byte count is 0 without a log" "$(cat "$STATUS")" "matrix log bytes: 0"

# --- agent children are looked up per host ---
h=codex
  f4_mon_reset
  live_batch 7000
  roster 1:PASS
  echo "4321 $h-process" >"$P/pgrep.codex-interactive"
  f4_mon_run SB_E2E_LIVE_RUNTIME=$h
  assert_contains "$h children listed" "$(cat "$STATUS")" "  4321 $h-process"
  f4_mon_reset
  live_batch 7000
  roster 1:PASS
  f4_mon_run SB_E2E_LIVE_RUNTIME=$h
  assert_contains "$h without children tolerated" "$(cat "$STATUS")" "batch PID: 7000 — RUNNING"

# --- cd failure ---
f4_mon_reset
tl_run env F4_CD_FAIL="$R" timeout 30 bash -c "$F4_LAUNCH" _ "$MON"
assert_eq "cd failure exits 1" "1" "$TL_STATUS"
assert_file_absent "cd failure leaves no monitor pid file" "$MPID"

tl_results

#!/usr/bin/env bash
# monitor-enterprise-e2e-matrix.sh, hung/no-agent/failure paths: agent-child kills per host, restarts and
# deferrals, quota and network waits, failing helpers. Stubs: tests/lib/enterprise-e2e-f4-helpers.sh (nothing
# here can signal a host process).
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

# --- hung batch: kill agent children (per host), then restart / defer ---
hung_setup() { # batch alive, log idle 6000s (hung), row 5 running with a fresh-looking attempt log? no: stale
  f4_mon_reset
  roster 1:PASS 5:none
  live_batch 7000
  echo "1234 agent" >"$P/pgrep.claude-interactive"
  echo "1234 agent" >"$P/pgrep.codex-interactive"
  echo "1234 agent" >"$P/pgrep.cursor-agent"
  idle_state 6000
  printf 'abc' >"$R/.e2e-row5-attempt.log"
  touch -d "@$((NOW - 7000))" "$R/.e2e-row5-attempt.log"
}
hung_setup
f4_mon_run
calls="$(cat "$F4_CALLS")"
assert_contains "hung logged" "$(cat "$POLL")" "HUNG: killing claude children after 6000s idle"
assert_contains "claude: TERM expect wrapper" "$calls" "pkill -TERM -f claude-interactive-invoke\\.expect"
assert_contains "claude: TERM claude binary" "$calls" "pkill -TERM -f /claude --model"
assert_contains "claude: KILL expect wrapper" "$calls" "pkill -KILL -f claude-interactive-invoke\\.expect"
assert_contains "claude: KILL claude binary" "$calls" "pkill -KILL -f /claude --model"
assert_contains "grace sleep between TERM and KILL" "$calls" "sleep 3"
assert_not_contains "claude host never pkills other agents" "$calls" "cursor-agent"
assert_eq "TERM precedes KILL" "TERM" "$(grep -m1 '^pkill' "$F4_CALLS" | awk '{print $2}' | sed 's/^-//')"
assert_contains "live batch is not restarted" "$(cat "$STATE")" "LAST_GROWTH_EPOCH=$NOW"
assert_file_absent "alive batch -> no restart" "$P/batch-ran"

hung_setup
f4_mon_run SB_E2E_LIVE_RUNTIME=codex
calls="$(cat "$F4_CALLS")"
assert_contains "codex: TERM wrapper" "$calls" "pkill -TERM -f codex-interactive-invoke\\.expect"
assert_contains "codex: KILL wrapper" "$calls" "pkill -KILL -f codex-interactive-invoke\\.expect"
assert_not_contains "codex host leaves claude alone" "$calls" "pkill -TERM -f /claude"

hung_setup
f4_mon_run SB_E2E_LIVE_RUNTIME=cursor
calls="$(cat "$F4_CALLS")"
assert_contains "cursor: TERM cursor-agent" "$calls" "pkill -TERM -f cursor-agent"
assert_contains "cursor: TERM /agent -p" "$calls" "pkill -TERM -f /agent -p"
assert_contains "cursor: KILL cursor-agent" "$calls" "pkill -KILL -f cursor-agent"
assert_contains "cursor: KILL /agent -p" "$calls" "pkill -KILL -f /agent -p"
assert_contains "cursor agent children listed in status" "$(cat "$STATUS")" "  1234 agent"

# hung while a live-test driver runs: no restart, clock reset
hung_setup
echo "9000 run-enterprise-e2e-live-test.sh" >"$P/pgrep.live-test"
f4_mon_run
assert_contains "live driver defers the hung restart" "$(cat "$POLL")" "defer hung restart: live-test driver active"
assert_contains "hung clock reset to now" "$(cat "$STATE")" "LAST_GROWTH_EPOCH=$NOW"
assert_not_contains "old growth epoch replaced" "$(cat "$STATE")" "LAST_GROWTH_EPOCH=$((NOW - 6000))"
assert_file_absent "no batch while live driver active" "$P/batch-ran"

# hung and the batch pid file vanished / points at a dead process: restart incomplete rows
hung_setup
echo 'rm -f "$BPID_FOR_HOOK"' >"$P/on-pkill"
f4_mon_run BPID_FOR_HOOK="$BPID"
assert_contains "pid file gone -> hung restart" "$(batch_ran)" "rows=[5 21 22]"
assert_contains "hung restart logged" "$(cat "$POLL")" "ACTION: starting batch rows: 5 21 22"

hung_setup
echo 'echo 424242 >"$BPID_FOR_HOOK"' >"$P/on-pkill"
f4_mon_run BPID_FOR_HOOK="$BPID"
assert_contains "dead batch pid -> hung restart" "$(batch_ran)" "rows=[5 21 22]"

hung_setup
echo 'rm -f "$BPID_FOR_HOOK"' >"$P/on-pkill"
f4_mon_run BPID_FOR_HOOK="$BPID" SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "auto-restart off defers the hung restart" "$(cat "$POLL")" "defer hung restart: SB_E2E_MONITOR_AUTO_RESTART=0"
assert_file_absent "nothing started" "$P/batch-ran"

# boundary: idle exactly HUNG_SEC kills the agent children, one second less only stalls
hung_setup
idle_state 5400
f4_mon_run
assert_contains "idle == HUNG_SEC is hung" "$(cat "$POLL")" "HUNG: killing claude children after 5400s idle"
assert_contains "idle == HUNG_SEC kills" "$(cat "$F4_CALLS")" "pkill -TERM"
hung_setup
idle_state 5399
f4_mon_run
assert_contains "idle == HUNG_SEC-1 still stalls" "$(cat "$POLL")" "STALL: row=5 idle=5399s"
assert_not_contains "idle == HUNG_SEC-1 is not hung" "$(cat "$POLL")" "HUNG:"
assert_not_contains "idle == HUNG_SEC-1 kills nothing" "$(cat "$F4_CALLS")" "pkill"

# stall without hang kills nothing; thresholds are configurable
hung_setup
idle_state 3000
f4_mon_run
assert_contains "stall logged" "$(cat "$POLL")" "STALL: row=5 idle=3000s (threshold 2700)"
assert_not_contains "stall below hung kills nothing" "$(cat "$F4_CALLS")" "pkill"
hung_setup
idle_state 3000
f4_mon_run SB_E2E_MATRIX_HUNG_SEC=2800
assert_contains "lowered hung threshold kills" "$(cat "$F4_CALLS")" "pkill -TERM"

# --- agent child gone while the batch runs ---
nochild_setup() { # attempt log is fresh (no stall) but the matrix log is idle 6000s and no agent runs
  f4_mon_reset
  roster 1:PASS 5:none
  live_batch 7000
  idle_state 6000
  printf 'abc' >"$R/.e2e-row5-attempt.log"
  touch -d "@$((NOW - 5))" "$R/.e2e-row5-attempt.log"
}
nochild_setup
f4_mon_run
assert_contains "no agent: batch restarted" "$(cat "$POLL")" "ACTION: no claude child 6000s — restarting batch"
assert_contains "old batch terminated by pid" "$(cat "$F4_CALLS")" "kill -TERM 7000"
assert_contains "restart grace sleep" "$(cat "$F4_CALLS")" "sleep 5"
assert_contains "incomplete rows relaunched" "$(batch_ran)" "rows=[5 21 22]"
assert_contains "status marks the no-agent restart" "$(cat "$STATUS")" "— RESTARTED(no-claude)"

nochild_setup
echo "9000 run-enterprise-e2e-live-test.sh" >"$P/pgrep.live-test"
f4_mon_run
assert_contains "live driver defers the no-agent restart" "$(cat "$POLL")" "defer no-claude restart: live-test driver active"
assert_not_contains "no kill of the batch" "$(cat "$F4_CALLS")" "kill -TERM"

# boundary: no-agent restart at exactly HUNG_SEC idle, none one second earlier
nochild_setup
idle_state 5400
f4_mon_run
assert_contains "no-agent idle == HUNG_SEC restarts" "$(cat "$POLL")" "ACTION: no claude child 5400s — restarting batch"
nochild_setup
idle_state 5399
f4_mon_run
assert_not_contains "no-agent idle == HUNG_SEC-1 does not restart" "$(cat "$POLL")" "no claude child"

nochild_setup
f4_mon_run SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "auto-restart off defers the no-agent restart" "$(cat "$POLL")" "defer no-claude restart: SB_E2E_MONITOR_AUTO_RESTART=0"

nochild_setup
echo "1234 agent" >"$P/pgrep.claude-interactive"
f4_mon_run
assert_not_contains "an agent child present means no restart" "$(cat "$POLL")" "no claude child"

nochild_setup
idle_state 100
f4_mon_run
assert_not_contains "short idle -> no restart" "$(cat "$POLL")" "no claude child"

nochild_setup
roster 1:PASS 5:PASS
idle_state 6000
f4_mon_run
assert_not_contains "completed row needs no agent" "$(cat "$POLL")" "no claude child"

nochild_setup
: >"$MLOG"
idle_state 6000
f4_mon_run
assert_not_contains "unknown row -> no agent check restart" "$(cat "$POLL")" "no claude child"

# --- quota and network waits expose a QUOTA_WAIT status first ---
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
printf '429 limit\n' >>"$MLOG"
echo 'cp "$STATUS_FOR_HOOK" "$F4_CTL/status-during-wait"' >"$P/on-sleep.7"
f4_mon_run STATUS_FOR_HOOK="$STATUS"
assert_contains "quota wait status written before sleeping" "$(cat "$P/status-during-wait")" "batch PID: 7000 — QUOTA_WAIT"

f4_mon_reset
roster 1:PASS 5:none
printf '429 limit\n' >>"$MLOG"
echo 'cp "$STATUS_FOR_HOOK" "$F4_CTL/status-during-wait"' >"$P/on-sleep.7"
f4_mon_run STATUS_FOR_HOOK="$STATUS" SB_E2E_MONITOR_AUTO_RESTART=0
assert_contains "quota wait without a pid file reports none" "$(cat "$P/status-during-wait")" "batch PID: none — QUOTA_WAIT"

# random network wait stays inside the configured window
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
printf 'ConnectionRefused\n' >>"$MLOG"
f4_mon_run SB_E2E_MATRIX_NETWORK_WAIT_MIN=20 SB_E2E_MATRIX_NETWORK_WAIT_MAX=25
w="$(grep -o 'waiting [0-9]*s' "$POLL" | head -1 | tr -dc '0-9')"
assert_match "network wait within 20..25" '^2[0-5]$' "$w"

# --- fallbacks of failing helper commands ---
# pkill matching nothing (status 1) and kill failing for an exited batch are tolerated
hung_setup
echo 1 >"$P/pkill-status"
f4_mon_run
assert_contains "pkill finding nothing does not stop the hung handling" "$(cat "$POLL")" "poll 2026-01-01T00:00:00Z row=5 batch=RUNNING"
assert_eq "all four claude-host pkill calls were attempted" "4" "$(grep -c '^pkill' "$F4_CALLS")"
for h in codex cursor; do
  hung_setup
  rm -f "$P/pgrep.codex-interactive" "$P/pgrep.cursor-agent" "$P/pgrep.claude-interactive"
  echo 1 >"$P/pkill-status"
  f4_mon_run SB_E2E_LIVE_RUNTIME=$h
  assert_contains "$h: no agent lines and no pkill match are tolerated" "$(cat "$POLL")" "HUNG: killing claude children after 6000s idle"
done

nochild_setup
f4_mon_run F4_KILL_FAIL=1
assert_contains "kill failing for a vanished batch is tolerated" "$(cat "$POLL")" "ACTION: no claude child 6000s — restarting batch"
assert_contains "restart still happens" "$(batch_ran)" "rows=[5 21 22]"

# the restart subshell cannot cd into the SB root: no batch runs
nochild_setup
f4_mon_run F4_CD_FAIL="$R" F4_CD_FAIL_IN=start_batch
assert_file_absent "failed cd in the batch subshell runs nothing" "$P/batch-ran"
assert_match "launcher pid still recorded" '^[0-9]+$' "$(tr -d '[:space:]' <"$BPID")"

# a hung batch with every row done restarts nothing (no rows)
f4_mon_reset
roster 1:PASS 5:PASS
printf '=== Row 21: a PASS ===\n=== Row 22: b PASS ===\n' >>"$MLOG"
live_batch 7000
idle_state 6000
printf 'abc' >"$R/.e2e-row5-attempt.log"
touch -d "@$((NOW - 7000))" "$R/.e2e-row5-attempt.log"
echo 'rm -f "$BPID_FOR_HOOK"' >"$P/on-pkill"
f4_mon_run BPID_FOR_HOOK="$BPID"
assert_contains "nothing to restart is logged" "$(cat "$POLL")" "start_batch: no incomplete rows — skip"
assert_file_absent "no batch started" "$P/batch-ran"

# the reconcile status helper failing is read as an unreadable ledger (first status printf fails)
f4_mon_reset
roster 1:PASS 5:PASS 21:none 22:none
printf 'Total: 22 / 22\n' >>"$MLOG"
f4_mon_ledger Pass
live_batch 7000
f4_mon_run F4_PRINTF_FAIL_MATCH="COMPLETE" F4_PRINTF_FAIL_ONCE=1
assert_contains "failed reconcile status is treated as not complete" "$(cat "$POLL")" "LEDGER_MISMATCH: matrix log 22/22 but ledger is not 22 PASS — not exiting"
assert_not_contains "no completion on a failed ledger read" "$(cat "$POLL")" "monitor exiting"

# library helpers failing: ensure-log and row-log lookups fall back quietly
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
f4_mon_run F4_ENSURE_FAIL=1 F4_ROWLOG_FAIL=1
assert_contains "poll completes without the helper libraries" "$(cat "$POLL")" "poll 2026-01-01T00:00:00Z row=5 batch=RUNNING"

# tail failing (e.g. unreadable log) yields empty windows
f4_mon_reset
roster 1:PASS 5:none
printf '429 limit\n' >>"$MLOG"
live_batch 7000
tl_stub tail 'exit 1'
f4_mon_run
rm -f "$TL_BIN/tail"
assert_not_contains "no issues seen through a failing tail" "$(cat "$POLL")" "429 detected"
assert_contains "poll still completes" "$(cat "$POLL")" "poll 2026-01-01T00:00:00Z"

# a corrupt state file does not stop the poll; the leading assignments still apply
f4_mon_reset
roster 1:PASS 5:none
live_batch 7000
printf 'LAST_QUOTA_ACTION=%s\nthis is ( not valid\n' "$((NOW - 1))" >"$STATE"
printf '429 limit\n' >>"$MLOG"
f4_mon_run
assert_contains "poll completes with a corrupt state file" "$(cat "$POLL")" "poll 2026-01-01T00:00:00Z"
assert_not_contains "valid leading assignment applied (recent quota action)" "$(cat "$POLL")" "429 detected"

tl_results

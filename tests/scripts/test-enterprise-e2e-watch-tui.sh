#!/usr/bin/env bash
# watch-enterprise-e2e-tui.sh: monitor liveness, batch discovery, incremental log scanning, finding
# classification, ledger UX rows, hung/status records and the exit conditions. pgrep/pkill/ps/kill/
# sleep/date are stubs; the monitor is a recording stub; the stub sleep ends the loop by terminating
# the watcher (only a process running this script).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f4-helpers.sh"
tl_init claude
f4_setup
tl_stub strings 'cat'

R="$TL_TMP/root"
f4_stage "$R"
W="$R/scripts/watch-enterprise-e2e-tui.sh"
e2e_stage_override "$R" scripts/monitor-enterprise-e2e-matrix.sh \
  'printf "log=%s ledger=%s auto=%s\n" "$SB_E2E_MATRIX_LOG" "$SB_E2E_LEDGER_FILE" "$SB_E2E_MONITOR_AUTO_RESTART" >>"$F4_CTL/monitor-ran"'
mkdir -p "$TL_TMP/app"
# live-common wrapper: F4_ROWLOG_FAIL makes the row-attempt-log lookup fail (fallback path)
rm -f "$R/scripts/lib/enterprise-e2e-live-common.sh"
cat >"$R/scripts/lib/enterprise-e2e-live-common.sh" <<EOS
source "$TL_REPO_ROOT/scripts/lib/enterprise-e2e-live-common.sh"
[[ -z "\${F4_ROWLOG_FAIL:-}" ]] || enterprise_e2e_row_attempt_log() { return 1; }
EOS
REAL_PY="$(command -v python3)"

FIND="$TL_TMP/findings.jsonl"
OFFS="$TL_TMP/offsets.json"
WLOG="$TL_TMP/watch.log"
WPID="$TL_TMP/watch.pid"
BPID="$TL_TMP/batch.pid"
MPID="$TL_TMP/monitor.pid"
MLOG="$TL_TMP/matrix.log"
LEDGER="$TL_TMP/ledger.md"
ROW5="$R/.e2e-row5-attempt.log"

export F4_LOOP_SLEEP=4242 F4_PARENT_MARK=watch-enterprise-e2e-tui.sh
export SB_E2E_TUI_OFFSETS="$OFFS" SB_E2E_TUI_FINDINGS="$FIND" SB_E2E_TUI_WATCH_LOG="$WLOG" SB_E2E_TUI_WATCH_PID="$WPID"
export SB_E2E_MATRIX_BATCH_PID_FILE="$BPID" SB_E2E_MATRIX_MONITOR_PID_FILE="$MPID" SB_E2E_MATRIX_LOG="$MLOG"
export SB_E2E_LEDGER_FILE="$LEDGER" SB_TEST_ENTERPRISE_APP_ROOT="$TL_TMP/app" SB_E2E_LIVE_RUNTIME=claude
export SB_E2E_TUI_POLL_MIN=4242 SB_E2E_TUI_POLL_MAX=4242
export SB_E2E_TUI_STATUS_INTERVAL=99999999 SB_E2E_TUI_HUNG_SEC=99999999
unset SB_E2E_MONITOR_AUTO_RESTART SB_E2E_LEDGER_NO_UX_APPEND SB_E2E_MATRIX_EXPECTED_ROWS F4_NOW_STEP F4_CD_FAIL || true

reset() {
  rm -rf "$FIND" "$OFFS" "$WLOG" "$WPID" "$BPID" "$MPID" "$MLOG" "$LEDGER" "$R"/.e2e-row*.log "$F4_CTL"
  mkdir -p "$F4_CTL"
  : >"$F4_CALLS"
  unset F4_LOOP_MAX
  f4_alive 31337
  echo 31337 >"$MPID" # a live monitor unless a scenario says otherwise
  printf '| # | sev | comp | quote | note |\n' >"$LEDGER"
}
watch() { tl_run timeout 30 bash "$W"; }
# fcount JQ-FILTER: number of findings-file records matching the filter
fcount() { jq -s "[.[] | select($1)] | length" "$FIND"; }

# --- cd failure and max runtime ---
reset
tl_run env F4_CD_FAIL="$R" timeout 30 bash "$W"
assert_eq "cd failure exits 1" "1" "$TL_STATUS"
assert_file_absent "cd failure writes no pid file" "$WPID"

reset
tl_run env SB_E2E_TUI_MAX_SEC=-1 timeout 30 bash "$W"
assert_eq "max runtime exits 0" "0" "$TL_STATUS"
assert_contains "start line" "$(cat "$WLOG")" "tui-watch started pid="
assert_contains "start line shows host and poll window" "$(cat "$WLOG")" "host=claude max_runtime=-1s poll=4242-4242s"
assert_match "pid file is a number" '^[0-9]+$' "$(tr -d '[:space:]' <"$WPID")"
assert_eq "offsets file initialised" "{}" "$(cat "$OFFS")"
assert_eq "max runtime final record" '{"type":"final","ts":"2026-01-01T00:00:00Z","reason":"max_runtime","issues":0}' "$(cat "$FIND")"
assert_contains "max runtime logged" "$(cat "$WLOG")" "max runtime -1s — exiting"
assert_contains "finished line" "$(cat "$WLOG")" "tui-watch finished issues=0"
assert_not_contains "monitor probed no pgrep before runtime check" "$(cat "$F4_CALLS")" "pgrep"

# existing offsets/findings are preserved, not reset
reset
echo '{"keep":1}' >"$OFFS"
echo '{"type":"old"}' >"$FIND"
tl_run env SB_E2E_TUI_MAX_SEC=-1 timeout 30 bash "$W"
assert_eq "existing offsets kept" '{"keep":1}' "$(cat "$OFFS")"
assert_eq "existing findings kept and appended to" "2" "$(wc -l <"$FIND" | tr -d ' ')"

# --- matrix completion ---
reset
printf '  PASS: a\n  PASS: b\nMATRIX COMPLETE\n' >"$MLOG"
watch
assert_eq "complete-by-text exits 0" "0" "$TL_STATUS"
assert_eq "complete-by-text final record" "matrix_complete" "$(jq -r .reason "$FIND")"
assert_eq "complete-by-text counts passes" "2" "$(jq -r .passes "$FIND")"
assert_contains "complete logged" "$(cat "$WLOG")" "matrix complete — exiting"
assert_eq "alive monitor not restarted" "0" "$(grep -c monitor-ran <<<"$(ls "$F4_CTL")")"

reset
printf 'All rows passed\n' >"$MLOG"
watch
assert_eq "All rows passed also completes" "matrix_complete" "$(jq -r .reason "$FIND")"
assert_eq "no PASS lines counted as 0" "0" "$(jq -r .passes "$FIND")"

# pass count reaches the expected rows and no batch runs -> complete; a live batch keeps it going
reset
printf '  PASS: a\n  PASS: b\n' >"$MLOG"
tl_run env SB_E2E_MATRIX_EXPECTED_ROWS=2 timeout 30 bash "$W"
assert_eq "passes>=expected without batch completes" "matrix_complete" "$(jq -r .reason "$FIND")"
assert_eq "no batch pid file created" "no" "$([[ -e "$BPID" ]] && echo yes || echo no)"

reset
printf '  PASS: a\n  PASS: b\n' >"$MLOG"
echo 7777 >"$BPID"
f4_alive 7777
tl_run env SB_E2E_MATRIX_EXPECTED_ROWS=2 SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
assert_eq "live batch keeps the watcher running until signalled" "0" "$TL_STATUS"
assert_contains "signal exit logged" "$(cat "$WLOG")" "tui-watch signal — exiting"
assert_eq "no final record while batch alive" "0" "$(fcount '.type=="final"')"
assert_eq "status record carries the batch pid" "7777" "$(jq -rs '[.[]|select(.type=="status")][0].batch_pid' "$FIND")"
assert_eq "status record carries passes" "2" "$(jq -rs '[.[]|select(.type=="status")][0].passes' "$FIND")"
assert_contains "status logged" "$(cat "$WLOG")" "status row=0 passes=2 issues=0 batch=7777"

# batch pid discovery through pgrep: first (lowest) live pid wins and is persisted
reset
printf '  PASS: a\n' >"$MLOG"
printf '9999\n8888\n' >"$F4_CTL/pgrep.run-enterprise-e2e-matrix"
f4_alive 8888 9999
tl_run env SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
assert_eq "pgrep batch persisted lowest pid" "8888" "$(cat "$BPID")"
assert_eq "pgrep batch in status" "8888" "$(jq -rs '[.[]|select(.type=="status")][0].batch_pid' "$FIND")"
assert_contains "pgrep pattern used" "$(cat "$F4_CALLS")" "pgrep -f bash scripts/run-enterprise-e2e-matrix.sh"

# stale batch pid file and a pgrep pid that is not alive -> no batch, status says none
reset
echo 5555 >"$BPID"
printf '6666\n' >"$F4_CTL/pgrep.run-enterprise-e2e-matrix"
tl_run env SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
assert_eq "dead batch -> none" "none" "$(jq -rs '[.[]|select(.type=="status")][0].batch_pid' "$FIND")"
assert_contains "dead batch logged as dead" "$(cat "$WLOG")" "batch=dead"
assert_eq "dead pgrep pid not persisted" "5555" "$(cat "$BPID")"

# --- monitor liveness ---
reset
echo 424242 >"$MPID"
printf '5150\n5151\n' >"$F4_CTL/pgrep.monitor-enterprise-e2e-matrix.sh"
printf 'MATRIX COMPLETE\n' >"$MLOG"
watch
assert_eq "monitor found by pgrep is recorded" "5150" "$(cat "$MPID")"
assert_file_absent "no monitor restart when pgrep finds one" "$F4_CTL/monitor-ran"

reset
echo 424242 >"$MPID"
printf 'MATRIX COMPLETE\n' >"$MLOG"
watch
f4_wait_file "$F4_CTL/monitor-ran"
assert_eq "dead monitor restarted with matrix env (auto-restart off)" "log=$MLOG ledger=$LEDGER auto=0" "$(cat "$F4_CTL/monitor-ran")"
assert_contains "restart logged" "$(cat "$WLOG")" "monitor dead — restarting (no duplicate matrix)"
assert_contains "restart pid logged" "$(cat "$WLOG")" "monitor restarted pid="
assert_match "restart pid recorded" '^[0-9]+$' "$(tr -d '[:space:]' <"$MPID")"

reset
rm -f "$MPID"
printf 'MATRIX COMPLETE\n' >"$MLOG"
tl_run env SB_E2E_MONITOR_AUTO_RESTART=1 timeout 30 bash "$W"
f4_wait_file "$F4_CTL/monitor-ran"
assert_contains "missing monitor pid file restarts with auto=1" "$(cat "$F4_CTL/monitor-ran")" "auto=1"

reset
printf '  \n' >"$MPID"
printf 'MATRIX COMPLETE\n' >"$MLOG"
watch
f4_wait_file "$F4_CTL/monitor-ran"
assert_contains "blank monitor pid file counts as dead" "$(cat "$WLOG")" "monitor dead"

# --- scanning: classification of one chunk ---
reset
: >"$MLOG"
{
  printf 'SILVER BULLET \xe2\x96\xba ROUTING sb:feature\n'
  printf 'SILVER BULLET > ROUTING sb:release\n'
  printf 'orchestrator skill is not registered\n'
  printf 'Unknown skill foo\n'
  printf '\033[31mStop hook error: boom\033[0m\n'
  printf 'planning-file-guard denied the write\n'
  printf '%0120d\n' 0
  printf 'planning-file-guard: SB OVERRIDE if needed\n'
  printf '%0120d\n' 0
  printf 'Not logged in\n'
  printf 'API Error: 429 slow down\n'
  printf 'ENOTFOUND api.example\n'
} >"$ROW5"
tl_run env SB_E2E_MATRIX_EXPECTED_ROWS=99 timeout 30 bash "$W"
assert_eq "scan run exits 0" "0" "$TL_STATUS"
assert_eq "routing info records" "2" "$(fcount '.category=="routing" and .severity=="info"')"
assert_eq "unexpected route is an annoyance" "1" "$(fcount '.category=="routing" and .severity=="annoyance" and (.message|test("sb:release"))')"
assert_eq "expected route is not an annoyance" "0" "$(fcount '.category=="routing" and .severity=="annoyance" and (.message|test("sb:feature"))')"
assert_eq "unregistered skill blocker (two patterns) + unknown skill" "3" "$(fcount '.category=="skill" and .severity=="blocker"')"
assert_eq "stop hook error annoyance" "1" "$(fcount '.category=="hook" and .severity=="annoyance" and .message=="Stop hook error"')"
assert_eq "planning-file-guard real block is a blocker" "1" "$(fcount '.category=="hook" and .severity=="blocker" and (.excerpt|test("denied the write"))')"
assert_eq "planning-file-guard override mention is an annoyance" "1" "$(fcount '.category=="hook" and .severity=="annoyance" and (.excerpt|test("SB OVERRIDE"))')"
assert_eq "auth info" "1" "$(fcount '.category=="auth"')"
assert_eq "quota info" "1" "$(fcount '.category=="quota"')"
assert_eq "network info" "1" "$(fcount '.category=="network"')"
assert_eq "ANSI codes stripped from excerpts" "0" "$(fcount '(.excerpt // "")|test("\u001b")')"
assert_eq "all findings are for row 5" "0" "$(fcount '.type != "final" and .row != 5')"
assert_eq "offset advanced to the log size" "$(wc -c <"$ROW5" | tr -d ' ')" "$(jq -r '.[".e2e-row5-attempt.log"]' "$OFFS")"
assert_contains "ledger gained blocker rows" "$(cat "$LEDGER")" "| 5 | blocker | skill | Unknown skill | tui-watch"
assert_not_contains "ledger has no annoyance rows" "$(cat "$LEDGER")" "annoyance"

# other findings: orchestrator confusion heuristics, stalls, harness timeouts
reset
: >"$MLOG"
{
  echo 'ORCHESTRATOR PARENT is forbidden to edit'
  echo 'parent must not implement inline'
  echo 'timed out waiting for Claude'
  echo 'agent shows 0 tokens'
  echo 'silver-orchestrator will Write the file'
  echo 'orchestrator considers /sb:feature as a parent Task'
} >"$ROW5"
tl_run env SB_E2E_MATRIX_EXPECTED_ROWS=99 timeout 30 bash "$W"
assert_eq "orchestrator forbidden annoyance" "1" "$(fcount '.category=="orchestrator" and .severity=="annoyance" and (.message|test("FORBIDDEN";"i"))')"
assert_eq "parent inline info" "1" "$(fcount '.category=="orchestrator" and .severity=="info"')"
assert_eq "harness timeout blocker" "1" "$(fcount '.category=="harness" and .severity=="blocker"')"
assert_eq "zero tokens stall annoyance" "1" "$(fcount '.category=="stall" and .severity=="annoyance"')"
assert_eq "inline implementation + dual orchestrator heuristics" "2" "$(fcount '.category=="orchestrator" and .severity=="annoyance" and (.message|test("implementing inline|deliberation"))')"
assert_contains "harness blocker reached the ledger" "$(cat "$LEDGER")" "| 5 | blocker | harness | timed out waiting for Claude"

# --- ledger UX rows: opt-out and de-duplication ---
reset
: >"$MLOG"
echo 'Unknown skill foo' >"$ROW5"
tl_run env SB_E2E_LEDGER_NO_UX_APPEND=1 timeout 30 bash "$W"
assert_eq "NO_UX_APPEND leaves the ledger alone" "1" "$(wc -l <"$LEDGER" | tr -d ' ')"
assert_eq "finding still recorded with NO_UX_APPEND" "1" "$(fcount '.category=="skill"')"

reset
echo 'Unknown skill foo' >"$ROW5"
cat >"$F4_CTL/on-loop-sleep" <<EOS2
[[ "\$1" == 1 ]] && echo 'Unknown skill foo' >>"$ROW5"
EOS2
F4_LOOP_MAX=2 watch
assert_eq "second run scanned both chunks" "2" "$(fcount '.category=="skill"')"
assert_eq "the same blocker is written to the ledger once" "1" "$(grep -c '| 5 | blocker | skill |' "$LEDGER")"

# --- incremental offsets, truncation, newest log selection ---
reset
echo 'Unknown skill A' >"$ROW5"
cat >"$F4_CTL/on-loop-sleep" <<EOS2
[[ "\$1" == 1 ]] && echo 'Unknown skill B' >>"$ROW5"
[[ "\$1" == 2 ]] && echo 'Not logged in' >"$ROW5"
EOS2
F4_LOOP_MAX=3 watch
assert_eq "appended chunk scanned once" "2" "$(fcount '.category=="skill"')"
assert_eq "truncated log is re-read from the start" "1" "$(fcount '.category=="auth"')"
assert_eq "no re-scan of old bytes" "3" "$(fcount '.type != "final" and .type != "status"')"

reset
: >"$MLOG"
echo 'Not logged in' >"$R/.e2e-row3-attempt.log"
echo 'Unknown skill' >"$R/.e2e-row9-attempt.log"
echo 'noise' >"$R/.e2e-rowX-attempt.log"
touch -d '2020-01-01' "$R/.e2e-row9-attempt.log"
touch -d '2021-01-01' "$R/.e2e-row3-attempt.log"
tl_run env SB_E2E_MATRIX_EXPECTED_ROWS=99 timeout 30 bash "$W"
assert_eq "each log scanned under its own row" "3" "$(jq -rs '[.[]|select(.category=="auth")][0].row' "$FIND")"
assert_eq "row 9 finding" "9" "$(jq -rs '[.[]|select(.category=="skill")][0].row' "$FIND")"

reset
echo 'x' >"$R/.e2e-row3-attempt.log"
echo 'y' >"$R/.e2e-row9-attempt.log"
touch -d '2020-01-01' "$R/.e2e-row3-attempt.log"
touch -d '2021-01-01' "$R/.e2e-row9-attempt.log"
tl_run env SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
assert_eq "newest log is the active row" "9" "$(jq -rs '[.[]|select(.type=="status")][0].active_row' "$FIND")"
assert_contains "status carries the last interaction text" "$(jq -rs '[.[]|select(.type=="status")][0].last_interaction' "$FIND")" "y"

reset
echo 'x' >"$R/.e2e-rowX-attempt.log"
tl_run env SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
assert_eq "unparseable log name maps to row 0" "0" "$(jq -rs '[.[]|select(.type=="status")][0].active_row' "$FIND")"

# no logs at all
reset
tl_run env SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
assert_eq "no logs -> row 0" "0" "$(jq -rs '[.[]|select(.type=="status")][0].active_row' "$FIND")"
assert_eq "no logs -> empty last interaction" "" "$(jq -rs '[.[]|select(.type=="status")][0].last_interaction' "$FIND" | sed 's/^""$//')"

# a blank line in the analyzer output is skipped, not recorded
reset
: >"$MLOG"
echo 'Unknown skill foo' >"$ROW5"
tl_stub python3 "real='$REAL_PY'"'
out="$("$real" "$@")"; rc=$?
printf "%s\n" "$out"
[[ $# -eq 3 && $2 =~ ^[0-9]+$ ]] && echo
exit $rc'
tl_run env SB_E2E_MATRIX_EXPECTED_ROWS=99 timeout 30 bash "$W"
rm -f "$TL_BIN/python3"
assert_eq "blank analyzer line not written to findings" "0" "$(grep -c '^$' "$FIND")"
assert_eq "finding still recorded" "1" "$(fcount '.category=="skill"')"

# --- codex host uses the host-specific log names ---
reset
: >"$MLOG"
echo 'Not logged in' >"$R/.e2e-row4-codex-attempt.log"
echo 'Unknown skill' >"$R/.e2e-row6-attempt.log"
tl_run env SB_E2E_LIVE_RUNTIME=codex SB_E2E_MATRIX_EXPECTED_ROWS=99 timeout 30 bash "$W"
assert_contains "codex host in start line" "$(cat "$WLOG")" "host=codex"
assert_eq "codex log scanned" "4" "$(jq -rs '[.[]|select(.category=="auth")][0].row' "$FIND")"
assert_eq "claude-named log ignored for codex" "0" "$(fcount '.category=="skill"')"

# tr failing on the batch pid file leaves the pid empty: discovery falls back to pgrep
reset
echo 7777 >"$BPID"
f4_alive 7777
printf '8888\n' >"$F4_CTL/pgrep.run-enterprise-e2e-matrix"
f4_alive 8888
REAL_TR="$(command -v tr)"
tl_stub tr "in=\"\$(cat)\"; [[ \"\$in\" == 7777* ]] && exit 1; printf '%s' \"\$in\" | $REAL_TR \"\$@\""
tl_run env SB_E2E_TUI_STATUS_INTERVAL=0 timeout 30 bash "$W"
rm -f "$TL_BIN/tr"
assert_eq "tr failure falls back to pgrep discovery" "8888" "$(cat "$BPID")"

# --- hung detection: no growth for longer than the threshold ---
reset
echo 'quiet' >"$ROW5"
tl_run env F4_NOW_STEP=500 F4_LOOP_MAX=2 SB_E2E_TUI_HUNG_SEC=100 timeout 30 bash "$W"
assert_eq "hung blocker recorded after the threshold" "1" "$(fcount '.category=="stall" and .severity=="blocker"')"
assert_contains "hung warning logged" "$(cat "$WLOG")" "WARN hung: row 5 no growth 100s (not killing claude)"
assert_not_contains "hung watcher never signals or kills anything" "$(cat "$F4_CALLS")" "kill -TERM"
assert_not_contains "hung watcher never pkills" "$(cat "$F4_CALLS")" "pkill"

reset
echo 'quiet' >"$ROW5"
tl_run env F4_NOW_STEP=1 F4_LOOP_MAX=3 SB_E2E_TUI_HUNG_SEC=100 timeout 30 bash "$W"
assert_eq "no hung record below the threshold" "0" "$(fcount '.category=="stall" and .severity=="blocker"')"

# the row-attempt-log lookup failing falls back to the conventional path
reset
echo 'quiet' >"$ROW5"
tl_run env F4_ROWLOG_FAIL=1 F4_NOW_STEP=500 F4_LOOP_MAX=2 SB_E2E_TUI_HUNG_SEC=100 timeout 30 bash "$W"
assert_eq "fallback log path still drives hung detection" "1" "$(fcount '.category=="stall" and .row==5')"

# growth resets the hung clock
reset
echo 'quiet' >"$ROW5"
cat >"$F4_CTL/on-loop-sleep" <<EOS2
echo 'more' >>"$ROW5"
EOS2
tl_run env F4_NOW_STEP=500 F4_LOOP_MAX=3 SB_E2E_TUI_HUNG_SEC=100 timeout 30 bash "$W"
assert_eq "growing log is not hung" "0" "$(fcount '.category=="stall" and .severity=="blocker"')"

tl_results

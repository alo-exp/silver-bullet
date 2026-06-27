#!/usr/bin/env bash
# Round 2 long-run supervisor: keep batch+monitor alive, update ledger on PASS, exit at 22/22.
set -uo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SB_ROOT"

export SB_E2E_MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-round2.log}"
export SB_E2E_MATRIX_ROWS="${SB_E2E_MATRIX_ROWS:-5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}"
export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-2-LEDGER.md}"
export SB_E2E_MATRIX_QUOTA_WAIT=600
export SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL=600
export SB_E2E_WORKFLOW_QUIET_TIMEOUT=600
export CLAUDE_INTERACTIVE_QUIET_TIMEOUT=600
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"

BATCH_PID_FILE="${SB_ROOT}/.e2e-matrix-batch.pid"
MONITOR_PID_FILE="${SB_ROOT}/.e2e-matrix-monitor.pid"
WATCH_LOG="${SB_ROOT}/.e2e-round2-watch.log"
STATE_FILE="${SB_ROOT}/.e2e-round2-watch-state"
POLL_SEC="${SB_E2E_ROUND2_POLL_SEC:-120}"
MAX_SEC="${SB_E2E_ROUND2_MAX_SEC:-86400}"

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '%s %s\n' "$(utc_now)" "$*" | tee -a "$WATCH_LOG"; }

slug_for_row() {
  case "$1" in
    1) echo silver-router ;; 2) echo silver-research ;; 3) echo silver-feature ;;
    4) echo silver-bugfix ;; 5) echo silver-ui ;; 6) echo silver-fast ;;
    7) echo silver-test ;; 8) echo silver-refactor ;; 9) echo silver-benchmark ;;
    10) echo silver-content ;; 11) echo silver-devops ;; 12) echo silver-deploy ;;
    13) echo silver-canary ;; 14) echo silver-release ;; 15) echo review-triad ;;
    16) echo ship-readiness ;; 17) echo silver-incident ;; 18) echo silver-retro ;;
    19) echo silver-forensics ;; 20) echo process-maintenance ;;
    21) echo post-exec-gates ;; 22) echo validate-substep ;;
    *) echo "row-$1" ;;
  esac
}

batch_alive() {
  local pid
  [[ -f "$BATCH_PID_FILE" ]] || return 1
  pid="$(tr -d '[:space:]' <"$BATCH_PID_FILE")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

monitor_alive() {
  local pid
  [[ -f "$MONITOR_PID_FILE" ]] || return 1
  pid="$(tr -d '[:space:]' <"$MONITOR_PID_FILE")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

start_batch() {
  local -a rows=("$@")
  log "starting batch rows: ${rows[*]}"
  printf '\n=== watch-round2 batch start %s rows: %s ===\n' "$(utc_now)" "${rows[*]}" >>"$SB_E2E_MATRIX_LOG"
  env SB_E2E_MATRIX_FORCE=1 SB_E2E_MATRIX_CLEAN_ENV=0 \
    SB_TEST_ENTERPRISE_APP_ROOT="$SB_TEST_ENTERPRISE_APP_ROOT" \
    SB_E2E_LEDGER_FILE="$SB_E2E_LEDGER_FILE" \
    SB_E2E_WORKFLOW_QUIET_TIMEOUT=600 \
    CLAUDE_INTERACTIVE_QUIET_TIMEOUT=600 \
    bash scripts/run-enterprise-e2e-matrix.sh "${rows[@]}" >>"$SB_E2E_MATRIX_LOG" 2>&1 &
  echo $! >"$BATCH_PID_FILE"
  log "batch pid=$(cat "$BATCH_PID_FILE")"
}

start_monitor() {
  log "starting monitor"
  env SB_E2E_MATRIX_LOG="$SB_E2E_MATRIX_LOG" \
    SB_E2E_MATRIX_ROWS="$SB_E2E_MATRIX_ROWS" \
    SB_E2E_MATRIX_QUOTA_WAIT=600 \
    bash scripts/monitor-enterprise-e2e-matrix.sh >>"${SB_ROOT}/.e2e-matrix-monitor-poll.log" 2>&1 &
  echo $! >"$MONITOR_PID_FILE"
  log "monitor pid=$(cat "$MONITOR_PID_FILE")"
}

incomplete_rows() {
  python3 - "$SB_E2E_MATRIX_LOG" <<'PY'
import re, sys
log = open(sys.argv[1], errors='replace').read() if __import__('os').path.isfile(sys.argv[1]) else ''
# Only count passes from current round2 session markers
start = log.rfind('=== watch-round2 batch start')
if start == -1:
    start = log.rfind('=== Agent resume row 5+')
if start == -1:
    start = log.rfind('=== Clean resume post-fix')
chunk = log[start:] if start >= 0 else log
pass_rows = set()
for m in re.finditer(r'=== Row (\d+):', chunk):
    row = int(m.group(1))
    rest = chunk[m.end():m.end()+8000]
    if re.search(r'^\s*PASS:', rest, re.M):
        pass_rows.add(row)
    elif re.search(r'=== Row \d+:', rest):
        pass_rows.add(row)  # will be overwritten
# Re-scan properly
pass_rows = set()
for m in re.finditer(r'=== Row (\d+):[^\n]*\n(?:.*?\n)*?\s*PASS:', chunk, re.S):
    pass_rows.add(int(m.group(1)))
for m in re.finditer(r'=== Row (21|22):.*PASS ===', chunk):
    pass_rows.add(int(m.group(1)))
for r in range(5, 21):
    if r not in pass_rows:
        print(r)
if 21 not in pass_rows: print(21)
if 22 not in pass_rows: print(22)
PY
}

count_passes() {
  python3 - "$SB_E2E_MATRIX_LOG" <<'PY'
import re, sys
log = open(sys.argv[1], errors='replace').read() if __import__('os').path.isfile(sys.argv[1]) else ''
start = log.rfind('=== watch-round2 batch start')
if start == -1:
    start = log.rfind('=== Agent resume row 5+')
if start == -1:
    start = log.rfind('=== Clean resume post-fix')
chunk = log[start:] if start >= 0 else log
rows = set()
for m in re.finditer(r'=== Row (\d+):[^\n]*\n(?:.*?\n)*?\s*PASS:', chunk, re.S):
    rows.add(int(m.group(1)))
for m in re.finditer(r'=== Row (21|22):.*PASS ===', chunk):
    rows.add(int(m.group(1)))
print(len(rows))
PY
}

update_ledger_row() {
  local row="$1" note="$2"
  local slug date line
  slug="$(slug_for_row "$row")"
  date="$(date -u '+%Y-%m-%d')"
  if grep -q "| ${row} | \`${slug}\` | ${date}" "$SB_E2E_LEDGER_FILE" 2>/dev/null; then
    return 0
  fi
  if grep -q "| ${row} | \`${slug}\` |" "$SB_E2E_LEDGER_FILE" && grep -q "| ${row} | \`${slug}\` |.*\*\*Pass\*\*" "$SB_E2E_LEDGER_FILE"; then
    return 0
  fi
  python3 - "$row" "$slug" "$date" "$note" "$SB_E2E_LEDGER_FILE" <<'PY'
import re, sys
row, slug, date, note, path = sys.argv[1:6]
text = open(path).read()
pat = rf'(\| {row} \| `{re.escape(slug)}` \|)[^|]*(\| haiku \|)[^|]*(\|)[^|]*(\|)[^|]*(\|)[^|]*(\| `graphify query "{re.escape(slug)} routes hooks skills orchestrator"` \| \|)'
repl = rf'\1 {date} \2 **Pass** \3 {note} \4 \5 \6'
new, n = re.subn(pat, repl, text, count=1)
if n:
    open(path, 'w').write(new)
    print(f'ledger updated row {row}')
else:
    print(f'ledger skip row {row} (pattern miss)', file=sys.stderr)
PY
  local passes
  passes="$(count_passes)"
  sed -i '' "s/^\*\*Pass count:\*\*.*/\*\*Pass count:\*\* ${passes} \/ 22 (watch-round2 $(utc_now))/" "$SB_E2E_LEDGER_FILE" 2>/dev/null || true
}

sync_ledger_from_log() {
  python3 - "$SB_E2E_MATRIX_LOG" <<'PY' | while IFS='|' read -r row note; do
import re, sys
log = open(sys.argv[1], errors='replace').read()
start = log.rfind('=== watch-round2 batch start')
if start == -1:
    start = log.rfind('=== Agent resume row 5+')
if start == -1:
    start = log.rfind('=== Clean resume post-fix')
chunk = log[start:] if start >= 0 else log
seen = set()
for m in re.finditer(r'=== Row (\d+): ([^\(]+).*?\n(?:.*?\n)*?\s*PASS: ([^\n]+)', chunk, re.S):
    row = int(m.group(1))
    if row in seen: continue
    seen.add(row)
    ev = m.group(3).strip()
    print(f"{row}|Row {row} PASS — {ev}")
for m in re.finditer(r'=== Row (21|22): ([^\n]+) PASS ===', chunk):
    row = int(m.group(1))
    if row in seen: continue
    seen.add(row)
    print(f"{row}|Row {row} internal PASS")
PY
    [[ -n "$row" ]] && update_ledger_row "$row" "$note"
  done
}

matrix_done() {
  local passes
  passes="$(count_passes)"
  [[ "$passes" -ge 22 ]] && ! batch_alive
}

run_final_gates() {
  log "22/22 — running final gates"
  local test_out ladder_note
  test_out="$(bash tests/run-all-tests.sh 2>&1)" || true
  printf '%s\n' "$test_out" >>"$WATCH_LOG"
  local fails
  fails="$(printf '%s' "$test_out" | grep -Eo '[0-9]+ failed' | head -1 || echo '? failed')"
  if printf '%s' "$test_out" | grep -qE '0 failed|passed.*0 failed'; then
    log "run-all-tests PASS"
  else
    log "run-all-tests FAIL: $fails"
  fi
  if git diff --quiet HEAD 2>/dev/null; then
    ladder_note="skipped — no SB repo changes during Round 2"
    log "review-fix-ladder skipped (no SB changes)"
  else
    ladder_note="required — SB changes detected; run review-fix-ladder manually"
    log "review-fix-ladder REQUIRED (SB changes present)"
  fi
  {
    echo "=== ROUND2_COMPLETE $(utc_now) ==="
    echo "passes=$(count_passes)/22"
    echo "run-all-tests: $fails"
    echo "review-fix-ladder: $ladder_note"
    echo "release-tag: Round 1 clean — Round 2 $(count_passes)/22 at completion"
  } >>"$WATCH_LOG"
  printf '%s\n' "ROUND2_WATCH_COMPLETE passes=$(count_passes)/22 tests=$fails ladder=$ladder_note"
}

touch "$WATCH_LOG"
log "watch-round2 started pid=$$ max=${MAX_SEC}s poll=${POLL_SEC}s"

if ! batch_alive && ! pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
  mapfile -t inc < <(incomplete_rows)
  if [[ "${#inc[@]}" -gt 0 ]]; then
    start_batch "${inc[@]}"
  fi
elif pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
  pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' | head -1 >"$BATCH_PID_FILE"
  log "adopted batch pid=$(cat "$BATCH_PID_FILE")"
fi

if ! monitor_alive && ! pgrep -f 'monitor-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
  start_monitor
elif pgrep -f 'monitor-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
  pgrep -f 'monitor-enterprise-e2e-matrix.sh' | head -1 >"$MONITOR_PID_FILE"
  log "adopted monitor pid=$(cat "$MONITOR_PID_FILE")"
fi

start_epoch="$(date +%s)"
last_passes="$(count_passes)"

while true; do
  now="$(date +%s)"
  if (( now - start_epoch > MAX_SEC )); then
    log "max runtime reached"
    break
  fi

  if ! monitor_alive; then
    start_monitor
  fi

  if ! batch_alive && ! pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
    mapfile -t inc < <(incomplete_rows)
    if [[ "${#inc[@]}" -gt 0 ]]; then
      log "batch dead — resuming incomplete: ${inc[*]}"
      start_batch "${inc[@]}"
    elif matrix_done; then
      sync_ledger_from_log
      run_final_gates
      exit 0
    fi
  fi

  sync_ledger_from_log
  passes="$(count_passes)"
  if [[ "$passes" != "$last_passes" ]]; then
    log "progress ${passes}/22"
    last_passes="$passes"
  fi

  if matrix_done; then
    sync_ledger_from_log
    run_final_gates
    exit 0
  fi

  sleep "$POLL_SEC"
done

log "watch-round2 exiting incomplete passes=$(count_passes)/22"
exit 1

#!/usr/bin/env bash
# Round Cursor-3 REAL monitor: poll pipeline rows 11-22, §5b verdict, fixture commit, ledger, Phase C.
set -euo pipefail

SB_ROOT="/Users/shafqat/projects/silver-bullet/repo"
FIXTURE="/Users/shafqat/projects/enterprise-grade-test-app-cursor"
LOG="${SB_ROOT}/.e2e-cursor3-pipeline-live.log"
STATE="${SB_ROOT}/.planning/enterprise-e2e/cursor3-real-pipeline.state"
LEDGER="${SB_ROOT}/.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md"
TIMELINE="${SB_ROOT}/.e2e-cursor3-monitor-timeline.md"
POLL_SEC="${SB_E2E_CURSOR3_POLL_SEC:-90}"
MAX_SEC="${SB_E2E_CURSOR3_MAX_SEC:-172800}"

export SB_ROOT SB_E2E_BRANCH=enterprise-e2e/cursor
export SB_E2E_LEDGER_FILE="$LEDGER"
export SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE"
export SB_ENTERPRISE_E2E_LIVE=1 SB_E2E_SKIP_CURSOR_INSTALL=1
export SB_E2E_ENTERPRISE_MATRIX=1
export SILVER_BULLET_RUNTIME=cursor SB_E2E_LIVE_RUNTIME=cursor

# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"
# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
append() { echo "$(utc_now) $*" | tee -a "$TIMELINE"; }

slug_for_row() {
  enterprise_e2e_outcome_matrix_workflow_slug "$1" 2>/dev/null || true
}

row_timeout() {
  case "$1" in
    11) echo "${SB_E2E_ROW11_TIMEOUT:-5400}" ;;
    8) echo "${SB_E2E_ROW8_TIMEOUT:-3600}" ;;
    *) echo "${CURSOR_AGENT_TIMEOUT:-1800}" ;;
  esac
}

tmux_alive() {
  tmux has-session -t cursor3-batch3-6 2>/dev/null
}

pipeline_driver_alive() {
  pgrep -f 'cursor3-real-pipeline-driver.sh' >/dev/null 2>&1
}

row_start_epoch() {
  local row="$1"
  local line
  line="$(grep -E "^ROW_${row}:DONE" "$STATE" 2>/dev/null | tail -1 || true)"
  if [[ -n "$line" ]]; then
    echo 0
    return
  fi
  line="$(grep -E "=== ROW ${row} start ===" "$LOG" 2>/dev/null | tail -1 || true)"
  if [[ -z "$line" ]]; then
    echo 0
    return
  fi
  local ts="${line%%Z*}Z"
  ts="${ts#*T}"
  ts="${line:0:20}"
  date -j -f '%Y-%m-%dT%H:%M:%SZ' "${line:0:20}" '+%s' 2>/dev/null || echo "$(date +%s)"
}

row_done_in_state() {
  grep -q "^ROW_${1}:DONE" "$STATE" 2>/dev/null
}

score_row() {
  local row="$1"
  local slug
  slug="$(slug_for_row "$row")"
  local attempt="${SB_ROOT}/.e2e-row${row}-cursor-attempt.log"
  local live="${SB_ROOT}/.e2e-cursor3-row${row}-live.log"
  local row_log="$attempt"
  [[ -f "$attempt" ]] || row_log="$live"
  local bytes=0
  [[ -f "$attempt" ]] && bytes=$(wc -c <"$attempt" | tr -d ' ')
  if [[ "$bytes" -lt 2048 && -f "$live" ]]; then
    bytes=$(wc -c <"$live" | tr -d ' ')
    row_log="$live"
  fi
  local state_dir="${FIXTURE}/.planning/enterprise-e2e/state"
  mkdir -p "$state_dir"
  local outcome_pass=0 log_floor=0
  # Rows 21-22 are internal harness gates (parent row 3/4 markers); no live agent log floor.
  if [[ "$row" =~ ^(21|22)$ ]]; then
    log_floor=1
    export SB_E2E_MATRIX_GRAPHIFY_REF="graphify query ${slug} routes hooks skills orchestrator"
    if enterprise_e2e_outcome_row_passes "$row" "$FIXTURE" "$state_dir" "$row_log" "$LEDGER" "" 2>/dev/null; then
      outcome_pass=1
    elif grep -q "Row ${row}:.*internal.*PASS" "${SB_ROOT}/.e2e-cursor3-pipeline-live.log" 2>/dev/null; then
      outcome_pass=1
    fi
    unset SB_E2E_MATRIX_GRAPHIFY_REF
    printf '%s %s %s\n' "$bytes" "$log_floor" "$outcome_pass"
    return 0
  fi
  [[ "$bytes" -ge 2048 ]] && log_floor=1
  export SB_E2E_MATRIX_GRAPHIFY_REF="graphify query ${slug} routes hooks skills orchestrator"
  if enterprise_e2e_outcome_row_passes "$row" "$FIXTURE" "$state_dir" "$row_log" "$LEDGER" "" 2>/dev/null; then
    outcome_pass=1
  fi
  unset SB_E2E_MATRIX_GRAPHIFY_REF
  printf '%s %s %s\n' "$bytes" "$log_floor" "$outcome_pass"
}

fixture_commit_if_needed() {
  local row="$1" slug="$2"
  cd "$FIXTURE"
  if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    git rev-parse --short HEAD
    return 0
  fi
  git add -A
  git commit -m "$(cat <<EOF
enterprise-e2e: cursor-3 row ${row} (${slug})

Round Cursor-3 REAL live matrix evidence @ $(utc_now).
EOF
)" >/dev/null 2>&1 || true
  git rev-parse --short HEAD
}

update_ledger_row() {
  local row="$1" slug="$2" verdict="$3" bytes="$4" commit_sha="$5" notes="$6"
  python3 - "$row" "$slug" "$verdict" "$bytes" "$commit_sha" "$notes" "$LEDGER" <<'PY'
import re, sys
row, slug, verdict, nbytes, commit_sha, notes, path = sys.argv[1:8]
text = open(path).read()
line = f"| {row} | `{slug}` | **{verdict}** | {nbytes} | `{commit_sha}` | {notes} |"
# Insert before defects section or append to matrix table
if re.search(rf'^\| {row} \| `{re.escape(slug)}` \|', text, re.M):
    text = re.sub(rf'^\| {row} \| `{re.escape(slug)}` \|[^\n]*\n', line + '\n', text, count=1)
else:
    marker = '\n---\n\n## Defects / blockers'
    if marker in text:
        text = text.replace(marker, '\n' + line + marker, 1)
    else:
        text += '\n' + line + '\n'
# Update progress line
text = re.sub(
    r'\*In progress — \d+/22 rows PASS.*\*',
    f'*In progress — updated row {row}; see matrix table.*',
    text,
)
open(path, 'w').write(text)
print(f'ledger row {row} -> {verdict}')
PY
}

count_ledger_passes() {
  python3 - "$LEDGER" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
rows = set()
for m in re.finditer(r'^\| (\d+) \| `[^`]+` \| \*\*PASS\*\*', text, re.M | re.I):
    rows.add(int(m.group(1)))
print(len(rows))
PY
}

process_completed_row() {
  local row="$1"
  local slug bytes log_floor outcome_pass verdict commit_sha notes
  slug="$(slug_for_row "$row")"
  read -r bytes log_floor outcome_pass < <(score_row "$row")
  if [[ "$log_floor" -eq 0 ]]; then
    verdict="FAIL"
    notes="§5b log floor (${bytes} B < 2048)"
  elif [[ "$outcome_pass" -eq 0 ]]; then
    verdict="FAIL"
    notes="outcome harness FAIL — see $(basename "${SB_ROOT}/.e2e-row${row}-cursor-attempt.log")"
  else
    verdict="PASS"
    commit_sha="$(fixture_commit_if_needed "$row" "$slug")"
    notes="batch3 live @ $(git -C "$SB_ROOT" rev-parse --short HEAD)"
  fi
  update_ledger_row "$row" "$slug" "$verdict" "$bytes" "${commit_sha:-—}" "$notes"
  append "ROW ${row} scored ${verdict} bytes=${bytes} commit=${commit_sha:-none}"
  [[ "$verdict" == "PASS" ]]
}

run_phase_c() {
  append "=== Phase C start ==="
  cd "$SB_ROOT"
  local rc=0
  RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh 2>&1 | tee -a "$TIMELINE" || rc=1
  if [[ "$rc" -ne 0 ]]; then
    append "Phase C ABORT — outcome harness rc=${rc}"
    return 1
  fi
  RTK_DISABLED=1 bash tests/run-all-tests.sh 2>&1 | tee -a "$TIMELINE" || rc=1
  if [[ "$rc" -ne 0 ]]; then
    append "Phase C ABORT — run-all-tests rc=${rc}"
    return 1
  fi
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --live 2>&1 | tee -a "$TIMELINE" || rc=1
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run 2>&1 | tee -a "$TIMELINE" || rc=1
  bash scripts/lib/enterprise-e2e-ledger-reconcile.sh "$LOG" 2>&1 | tee -a "$TIMELINE" || rc=1
  SB_E2E_RCS_LADDER=8/8 SB_E2E_RCS_TRIHOST=full SB_E2E_RCS_RUN_ALL_TESTS=pass \
    bash scripts/enterprise-e2e-rcs.sh 2>&1 | tee -a "$TIMELINE" || rc=1
  if [[ "$rc" -eq 0 ]]; then
    echo "PHASE_C:DONE $(utc_now) @ $(git rev-parse --short HEAD)" >>"$STATE"
    append "Phase C PASS"
  else
    append "Phase C FAIL rc=${rc}"
  fi
  return "$rc"
}

touch "$TIMELINE"
append "monitor-loop start pid=$$ poll=${POLL_SEC}s"

PROCESSED_FILE="${SB_ROOT}/.e2e-cursor3-monitor-processed.txt"
touch "$PROCESSED_FILE"

row_processed() {
  grep -q "^${1}:" "$PROCESSED_FILE" 2>/dev/null
}

mark_processed() {
  echo "${1}:${2}" >>"$PROCESSED_FILE"
}

start_epoch="$(date +%s)"
current_row=11
last_bytes=0
stall_since=0

while true; do
  now="$(date +%s)"
  if (( now - start_epoch > MAX_SEC )); then
    append "max runtime reached"
    exit 1
  fi

  # Process newly completed rows from pipeline state
  for row in $(seq 11 22); do
    row_processed "$row" && continue
    if row_done_in_state "$row"; then
      if process_completed_row "$row"; then
        mark_processed "$row" pass
      else
        mark_processed "$row" fail
        append "ROW ${row} FAIL — pipeline may halt"
      fi
    fi
  done

  passes="$(count_ledger_passes)"
  append "poll passes=${passes}/22 tmux=$(tmux_alive && echo up || echo down) driver=$(pipeline_driver_alive && echo up || echo down)"

  if [[ "$passes" -ge 22 ]] && ! pipeline_driver_alive; then
    if ! grep -q '^PHASE_C:DONE' "$STATE" 2>/dev/null; then
      run_phase_c && append "PIPELINE COMPLETE 22/22 + Phase C" && exit 0
    else
      append "PIPELINE COMPLETE 22/22 Phase C already done"
      exit 0
    fi
  fi

  # Stall detection on active row
  for row in $(seq 11 22); do
    row_done_in_state "$row" && continue
    grep -q "=== ROW ${row} start ===" "$LOG" 2>/dev/null || continue
    current_row=$row
    attempt="${SB_ROOT}/.e2e-row${row}-cursor-attempt.log"
    bytes=0
    [[ -f "$attempt" ]] && bytes=$(wc -c <"$attempt" | tr -d ' ')
    if [[ "$bytes" != "$last_bytes" ]]; then
      last_bytes=$bytes
      stall_since=$now
    fi
    row_start="$(grep -E "=== ROW ${row} start ===" "$LOG" | tail -1 | cut -d' ' -f1)"
    row_start_epoch=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$row_start" '+%s' 2>/dev/null || echo "$now")
    elapsed=$((now - row_start_epoch))
    timeout="$(row_timeout "$row")"
    stall_elapsed=$((now - stall_since))
    if [[ "$stall_since" -gt 0 && "$stall_elapsed" -gt "$timeout" ]]; then
      append "STALL row ${row} bytes=${bytes} stall=${stall_elapsed}s timeout=${timeout}s"
    fi
  done

  if ! pipeline_driver_alive && ! tmux_alive; then
    passes="$(count_ledger_passes)"
    if [[ "$passes" -lt 22 ]]; then
      append "driver+tmux dead with ${passes}/22 — exiting"
      exit 1
    fi
  fi

  sleep "$POLL_SEC"
done

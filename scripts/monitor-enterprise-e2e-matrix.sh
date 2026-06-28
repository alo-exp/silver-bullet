#!/usr/bin/env bash
# Always-on monitor for enterprise E2E Claude matrix batches.
# Polls batch health, detects stalls/errors, restarts on failure.
#
# Usage (from SB repo root, in a persistent Cursor background shell):
#   bash scripts/monitor-enterprise-e2e-matrix.sh &
#   echo $! > .e2e-matrix-monitor.pid
#
# Tail status: tail -f .e2e-matrix-monitor-status.txt
# Poll history: tail -f .e2e-matrix-monitor-poll.log
set -uo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${SB_ROOT}/hooks/lib/rtk-compat.sh"
cd "$SB_ROOT" || exit
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
sb_prepend_harness_path
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"

MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-rows5-7-22-resume2.log}"
BATCH_PID_FILE="${SB_E2E_MATRIX_BATCH_PID_FILE:-${SB_ROOT}/.e2e-matrix-batch.pid}"
MONITOR_PID_FILE="${SB_E2E_MATRIX_MONITOR_PID_FILE:-${SB_ROOT}/.e2e-matrix-monitor.pid}"
POLL_LOG="${SB_E2E_MATRIX_MONITOR_POLL_LOG:-${SB_ROOT}/.e2e-matrix-monitor-poll.log}"
STATUS_FILE="${SB_E2E_MATRIX_MONITOR_STATUS_FILE:-${SB_ROOT}/.e2e-matrix-monitor-status.txt}"
STATE_FILE="${SB_ROOT}/.e2e-matrix-monitor-state"

POLL_INTERVAL="${SB_E2E_MATRIX_MONITOR_INTERVAL:-300}"
STALL_SEC="${SB_E2E_MATRIX_STALL_SEC:-2700}"
HUNG_SEC="${SB_E2E_MATRIX_HUNG_SEC:-5400}"
QUOTA_WAIT="${SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-${SB_E2E_MATRIX_QUOTA_WAIT:-60}}"
NETWORK_WAIT_MIN="${SB_E2E_MATRIX_NETWORK_WAIT_MIN:-120}"
NETWORK_WAIT_MAX="${SB_E2E_MATRIX_NETWORK_WAIT_MAX:-300}"

FIXTURE_DIR="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
# shellcheck disable=SC2206
MATRIX_ROW_ARGS=(${SB_E2E_MATRIX_ROWS:-1 5 7 8 9 10 12 13 17 18 19 20})

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log_poll() {
  printf '%s\n' "$*" >>"$POLL_LOG"
}

write_status() {
  printf '%s\n' "$*" >"$STATUS_FILE"
}

batch_elapsed() {
  local pid="$1"
  ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ' || echo "?"
}

discover_batch_pid() {
  local pid p ppid cmd
  if [[ -f "$BATCH_PID_FILE" ]]; then
    pid="$(tr -d '[:space:]' <"$BATCH_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
      return 0
    fi
  fi
  # Pick shallowest (root) matrix runner for this row set.
  pid=""
  while read -r p; do
    [[ -z "$p" ]] && continue
    ppid="$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ')"
    cmd="$(ps -p "$ppid" -o command= 2>/dev/null || true)"
    if [[ "$cmd" != *run-enterprise-e2e-matrix.sh* ]]; then
      pid="$p"
      break
    fi
  done < <(pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' 2>/dev/null | sort -n)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    printf '%s\n' "$pid" >"$BATCH_PID_FILE"
    printf '%s\n' "$pid"
    return 0
  fi
  return 1
}

is_batch_running() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

live_test_driver_running() {
  pgrep -f 'run-enterprise-e2e-live-test\.sh' >/dev/null 2>&1
}

any_matrix_runner_pid() {
  pgrep -f 'bash scripts/run-enterprise-e2e-matrix\.sh' 2>/dev/null | head -1 || true
}

claude_child_lines() {
  pgrep -fl 'claude-interactive-invoke\.expect|/claude --model' 2>/dev/null \
    | grep -v grep || true
}

current_row_from_log() {
  local row
  row="$(grep -E '^=== Row [0-9]+:' "$MATRIX_LOG" 2>/dev/null | tail -1 | sed -n 's/^=== Row \([0-9]*\):.*/\1/p')"
  if [[ -n "$row" ]]; then
    printf '%s\n' "$row"
    return 0
  fi
  # In-progress row without header yet — last completed + 1 from args (rough).
  printf '%s\n' "?"
}

row_attempt_log() {
  local row="$1"
  local f="${SB_ROOT}/.e2e-row${row}-attempt.log"
  [[ -f "$f" ]] && printf '%s\n' "$f"
}

log_bytes() {
  [[ -f "$1" ]] && wc -c <"$1" | tr -d ' ' || echo 0
}

log_mtime_epoch() {
  [[ -f "$1" ]] && stat -f '%m' "$1" 2>/dev/null || echo 0
}

read_state() {
  local key="$1" default="${2:-}"
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE" 2>/dev/null || true
  fi
  printf '%s\n' "${!key:-$default}"
}

write_state_kv() {
  local key="$1" val="$2"
  touch "$STATE_FILE"
  if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
    # portable-ish in-place on macOS
    local tmp="${STATE_FILE}.tmp.$$"
    sed "s/^${key}=.*/${key}=${val}/" "$STATE_FILE" >"$tmp" && mv "$tmp" "$STATE_FILE"
  else
    printf '%s=%s\n' "$key" "$val" >>"$STATE_FILE"
  fi
}

row_is_complete() {
  local row="$1"
  if [[ "$row" == "21" || "$row" == "22" ]]; then
    grep -qE "Row ${row}:.*PASS ===" "$MATRIX_LOG" 2>/dev/null
    return $?
  fi
  awk -v target="$row" '
    /^=== Row [0-9]+:/ {
      if (cur == target && (pass || skip)) { done = 1 }
      cur = $3
      sub(/:$/, "", cur)
      pass = 0
      skip = 0
    }
    cur == target && /^  PASS:/ { pass = 1 }
    cur == target && /^  SKIP:/ { skip = 1 }
    cur == target && /^  DRY RUN PASS/ { pass = 1 }
    cur == target && /^  FAIL:/ { pass = 0; skip = 0 }
    END { exit (done || pass || skip) ? 0 : 1 }
  ' "$MATRIX_LOG" 2>/dev/null
}

incomplete_rows() {
  local row out=()
  for row in "${MATRIX_ROW_ARGS[@]}"; do
    if ! row_is_complete "$row"; then
      out+=("$row")
    fi
  done
  # Internal rows 21-22
  if ! grep -q 'Row 21:.*PASS' "$MATRIX_LOG" 2>/dev/null; then
    out+=(21)
  fi
  if ! grep -q 'Row 22:.*PASS' "$MATRIX_LOG" 2>/dev/null; then
    out+=(22)
  fi
  if (( ${#out[@]} > 0 )); then
    printf '%s\n' "${out[@]}"
  fi
}

matrix_log_reports_complete() {
  grep -qE 'Total: 22 / 22|Pass:  22' "$MATRIX_LOG" 2>/dev/null
}

matrix_all_done() {
  if matrix_log_reports_complete; then
    return 0
  fi
  local inc
  inc="$(incomplete_rows | wc -l | tr -d ' ')"
  [[ "$inc" -eq 0 ]]
}

# Monitor must agree with human-auditable ledger before emitting COMPLETE.
matrix_reconcile_state() {
  local log_done ledger_status
  log_done=0
  matrix_log_reports_complete && log_done=1
  ledger_status="$(enterprise_e2e_ledger_reconcile_status 2>/dev/null || echo UNREADABLE)"
  if [[ "$log_done" -eq 1 && "$ledger_status" == "COMPLETE" ]]; then
    printf '%s\n' "COMPLETE"
    return 0
  fi
  if [[ "$log_done" -eq 1 ]]; then
    printf '%s\n' "LEDGER_MISMATCH"
    return 1
  fi
  if [[ "$ledger_status" == "STALE" || "$ledger_status" == "UNREADABLE" ]]; then
    printf '%s\n' "STALE"
    return 1
  fi
  printf '%s\n' "IN_PROGRESS"
  return 1
}

parse_recent_issues() {
  local window="${1:-200}"
  local chunk
  chunk="$(tail -n "$window" "$MATRIX_LOG" 2>/dev/null || true)"
  local issues=()
  if printf '%s\n' "$chunk" | grep -qiE '429|token[[:space:]]+plan|usage[[:space:]]+limit'; then
    issues+=("429")
  fi
  if printf '%s\n' "$chunk" | grep -qiE 'ENOTFOUND|ConnectionRefused|Unable to connect'; then
    issues+=("network")
  fi
  if printf '%s\n' "$chunk" | grep -qiE 'Stop hook error'; then
    issues+=("stop-hook")
  fi
  if printf '%s\n' "$chunk" | grep -qiE 'hookEventName'; then
    issues+=("hookEventName")
  fi
  if printf '%s\n' "$chunk" | grep -qE '^  FAIL:'; then
    issues+=("FAIL")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '%s\n' "${issues[@]}"
  fi
}

random_network_wait() {
  local range=$((NETWORK_WAIT_MAX - NETWORK_WAIT_MIN + 1))
  echo $((NETWORK_WAIT_MIN + RANDOM % range))
}

kill_claude_children() {
  local sig="${1:-TERM}"
  pkill "-$sig" -f 'claude-interactive-invoke\.expect' 2>/dev/null || true
  pkill "-$sig" -f '/claude --model' 2>/dev/null || true
  sleep 3
  pkill -KILL -f 'claude-interactive-invoke\.expect' 2>/dev/null || true
  pkill -KILL -f '/claude --model' 2>/dev/null || true
}

start_batch() {
  local -a rows=("$@")
  if [[ "${#rows[@]}" -eq 0 ]]; then
    log_poll "$(utc_now) start_batch: no incomplete rows — skip"
    return 1
  fi
  log_poll "$(utc_now) ACTION: starting batch rows: ${rows[*]}"
  (
    cd "$SB_ROOT" || exit
    env -u SB_E2E_MATRIX_DRY_RUN \
      SB_E2E_MATRIX_FORCE=1 \
      SB_E2E_MATRIX_CLEAN_ENV=0 \
      SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE_DIR" \
      bash scripts/run-enterprise-e2e-matrix.sh "${rows[@]}" >>"$MATRIX_LOG" 2>&1
  ) &
  local newpid=$!
  printf '%s\n' "$newpid" >"$BATCH_PID_FILE"
  write_state_kv LAST_BATCH_START "$(utc_now)"
  write_state_kv LAST_GROWTH_EPOCH "$(date +%s)"
  write_state_kv LAST_GROWTH_BYTES "$(log_bytes "$MATRIX_LOG")"
  log_poll "$(utc_now) batch started pid=${newpid}"
  return 0
}

build_status_block() {
  local batch_pid="$1" batch_state="$2"
  local row log_bytes elapsed claude_lines row_logs tail_block issues
  row="$(current_row_from_log)"
  log_bytes="$(log_bytes "$MATRIX_LOG")"
  elapsed="$(batch_elapsed "$batch_pid" 2>/dev/null || echo '?')"
  claude_lines="$(claude_child_lines)"
  row_logs=""
  local f r bytes mtime
  for r in 1 5 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    f="$(row_attempt_log "$r" || true)"
    if [[ -n "$f" && -f "$f" ]]; then
      bytes="$(log_bytes "$f")"
      mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null || echo '?')"
      row_logs+="  row${r}-attempt.log: ${bytes} bytes (${mtime})"$'\n'
    fi
  done
  tail_block="$(tail -20 "$MATRIX_LOG" 2>/dev/null | sed 's/^/  /' || true)"
  issues="$(parse_recent_issues 300 | sort -u | tr '\n' ',' | sed 's/,$//')"

  cat <<EOF
=== Matrix monitor poll $(utc_now) ===
batch PID: ${batch_pid:-none} — ${batch_state}
elapsed batch: ${elapsed}
current row (log): ${row}
matrix log bytes: ${log_bytes}
issues (recent): ${issues:-none}
claude/expect:
$(printf '%s\n' "$claude_lines" | sed 's/^/  /')
${row_logs}log tail:

${tail_block}
retry policy: 429→${QUOTA_WAIT}s; ENOTFOUND→${NETWORK_WAIT_MIN}-${NETWORK_WAIT_MAX}s; DRY_RUN unset
monitor PID: $$
poll interval: ${POLL_INTERVAL}s; stall=${STALL_SEC}s; hung=${HUNG_SEC}s
EOF
}

handle_quota() {
  log_poll "$(utc_now) ACTION: 429 detected — waiting ${QUOTA_WAIT}s"
  write_status "$(build_status_block "$(cat "$BATCH_PID_FILE" 2>/dev/null || echo none)" "QUOTA_WAIT")"
  sleep "$QUOTA_WAIT"
}

handle_network() {
  local wait_secs
  wait_secs="$(random_network_wait)"
  log_poll "$(utc_now) ACTION: network error — waiting ${wait_secs}s"
  sleep "$wait_secs"
}

on_stall_detected() {
  local row="$1" idle_sec="$2"
  log_poll "$(utc_now) STALL: row=${row} idle=${idle_sec}s (threshold ${STALL_SEC})"
  if [[ "$idle_sec" -ge "$HUNG_SEC" ]]; then
    log_poll "$(utc_now) HUNG: killing claude children after ${idle_sec}s idle"
    kill_claude_children TERM
    if live_test_driver_running; then
      log_poll "$(utc_now) defer hung restart: live-test driver active"
      write_state_kv LAST_GROWTH_EPOCH "$(date +%s)"
      return 0
    fi
    local inc
    enterprise_e2e_read_lines_to_array inc incomplete_rows
    # If batch dead, full restart; else row will retry via harness quota loop
    local bpid
    bpid="$(cat "$BATCH_PID_FILE" 2>/dev/null || true)"
    if [[ -z "$bpid" ]] || ! kill -0 "$bpid" 2>/dev/null; then
      start_batch "${inc[@]}"
    fi
    write_state_kv LAST_GROWTH_EPOCH "$(date +%s)"
  fi
}

poll_once() {
  local batch_pid batch_state="STOPPED"
  batch_pid="$(discover_batch_pid 2>/dev/null || true)"

  if matrix_all_done; then
    local reconcile_state
    reconcile_state="$(matrix_reconcile_state)"
    case "$reconcile_state" in
      COMPLETE)
        log_poll "$(utc_now) COMPLETE: matrix 22/22 — ledger reconcile OK — monitor exiting"
        write_status "$(build_status_block "${batch_pid:-done}" "COMPLETE")"
        rm -f "$BATCH_PID_FILE"
        exit 0
        ;;
      LEDGER_MISMATCH)
        log_poll "$(utc_now) LEDGER_MISMATCH: matrix log 22/22 but ledger is not 22 PASS — not exiting"
        write_status "$(build_status_block "${batch_pid:-done}" "LEDGER_MISMATCH")"
        ;;
      STALE)
        log_poll "$(utc_now) STALE: matrix log complete but ledger missing/stale — not exiting"
        write_status "$(build_status_block "${batch_pid:-done}" "STALE")"
        ;;
      *)
        log_poll "$(utc_now) IN_PROGRESS: matrix log complete; ledger reconcile=$reconcile_state"
        write_status "$(build_status_block "${batch_pid:-done}" "IN_PROGRESS")"
        ;;
    esac
  fi

  local now_epoch last_growth_epoch last_bytes cur_bytes idle_sec row attempt_log
  now_epoch="$(date +%s)"
  cur_bytes="$(log_bytes "$MATRIX_LOG")"
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE" 2>/dev/null || true
  fi
  last_growth_epoch="${LAST_GROWTH_EPOCH:-0}"
  last_bytes="${LAST_GROWTH_BYTES:-0}"

  if [[ "$cur_bytes" != "$last_bytes" ]]; then
    write_state_kv LAST_GROWTH_EPOCH "$now_epoch"
    write_state_kv LAST_GROWTH_BYTES "$cur_bytes"
    last_growth_epoch="$now_epoch"
  else
    idle_sec=$((now_epoch - last_growth_epoch))
    row="$(current_row_from_log)"
    if is_batch_running "$batch_pid" && [[ "$row" != "?" ]]; then
      attempt_log="$(row_attempt_log "$row" || true)"
      if [[ -n "$attempt_log" && -f "$attempt_log" ]]; then
        local attempt_bytes attempt_mtime attempt_idle
        attempt_bytes="$(log_bytes "$attempt_log")"
        attempt_mtime="$(log_mtime_epoch "$attempt_log")"
        attempt_idle=$((now_epoch - attempt_mtime))
        if [[ "$attempt_idle" -lt "$idle_sec" ]]; then
          idle_sec="$attempt_idle"
        fi
        if [[ "$attempt_bytes" != "${LAST_ROW_BYTES:-}" ]]; then
          write_state_kv LAST_ROW_BYTES "$attempt_bytes"
          idle_sec=0
        fi
      fi
      if [[ "$idle_sec" -ge "$STALL_SEC" ]]; then
        on_stall_detected "$row" "$idle_sec"
      fi
    fi
  fi

  local issues=() issue line
  while IFS= read -r line; do
    [[ -n "$line" ]] && issues+=("$line")
  done < <(parse_recent_issues 150 | sort -u)
  if [[ ${#issues[@]} -gt 0 ]]; then
  for issue in "${issues[@]}"; do
    case "$issue" in
      429)
        if [[ "${LAST_QUOTA_ACTION:-0}" -lt $((now_epoch - QUOTA_WAIT)) ]]; then
          handle_quota
          write_state_kv LAST_QUOTA_ACTION "$now_epoch"
        fi
        ;;
      network)
        if [[ "${LAST_NET_ACTION:-0}" -lt $((now_epoch - NETWORK_WAIT_MIN)) ]]; then
          handle_network
          write_state_kv LAST_NET_ACTION "$now_epoch"
        fi
        ;;
      stop-hook|hookEventName|FAIL)
        log_poll "$(utc_now) NOTE: detected ${issue} in recent log (no auto-kill)"
        ;;
    esac
  done
  fi

  if is_batch_running "$batch_pid"; then
    batch_state="RUNNING"
    printf '%s\n' "$batch_pid" >"$BATCH_PID_FILE"
  else
    batch_state="STOPPED"
    if live_test_driver_running; then
      local adopted
      adopted="$(any_matrix_runner_pid)"
      if [[ -n "$adopted" ]] && kill -0 "$adopted" 2>/dev/null; then
        batch_pid="$adopted"
        batch_state="RUNNING"
        printf '%s\n' "$batch_pid" >"$BATCH_PID_FILE"
        log_poll "$(utc_now) defer restart: live-test driver active — adopted matrix pid ${batch_pid}"
      else
        log_poll "$(utc_now) defer restart: live-test driver pre-matrix (skip duplicate FORCE batch)"
        batch_state="WAIT_LIVE_TEST"
      fi
    else
      log_poll "$(utc_now) ACTION: batch not running — restarting incomplete rows"
      local inc
      enterprise_e2e_read_lines_to_array inc incomplete_rows
      if [[ "${#inc[@]}" -gt 0 ]]; then
        start_batch "${inc[@]}"
        batch_pid="$(cat "$BATCH_PID_FILE")"
        batch_state="RESTARTED"
      else
        batch_state="$(matrix_reconcile_state 2>/dev/null || echo IN_PROGRESS)"
      fi
    fi
  fi

  # Claude child health during active batch
  if is_batch_running "$batch_pid"; then
  if [[ -z "$(claude_child_lines)" ]]; then
    row="$(current_row_from_log)"
    if [[ "$row" != "?" ]] && ! row_is_complete "$row"; then
      idle_sec=$((now_epoch - last_growth_epoch))
      if [[ "$idle_sec" -ge "$HUNG_SEC" ]]; then
        if live_test_driver_running; then
          log_poll "$(utc_now) defer no-claude restart: live-test driver active"
        else
        log_poll "$(utc_now) ACTION: no claude child ${idle_sec}s — restarting batch"
        kill -TERM "$batch_pid" 2>/dev/null || true
        sleep 5
        enterprise_e2e_read_lines_to_array inc incomplete_rows
        start_batch "${inc[@]}"
        batch_pid="$(cat "$BATCH_PID_FILE")"
        batch_state="RESTARTED(no-claude)"
        fi
      fi
    fi
  fi
  fi

  local block
  block="$(build_status_block "${batch_pid:-none}" "$batch_state")"
  write_status "$block"
  log_poll "$block"
  log_poll "poll $(utc_now) row=$(current_row_from_log) batch=${batch_state}"
}

cleanup() {
  log_poll "$(utc_now) monitor $$ received signal — exiting"
  exit 0
}

main() {
  echo $$ >"$MONITOR_PID_FILE"
  log_poll "=== monitor started $(utc_now) pid=$$ interval=${POLL_INTERVAL}s log=${MATRIX_LOG} ==="
  trap cleanup INT TERM
  trap '' HUP

  # Adopt running batch if present
  discover_batch_pid >/dev/null 2>&1 || true

  while true; do
    poll_once || log_poll "$(utc_now) poll_once error (continuing)"
    sleep "$POLL_INTERVAL" || sleep "$POLL_INTERVAL"
  done
}

main "$@"

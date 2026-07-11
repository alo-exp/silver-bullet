#!/usr/bin/env bash
# Supervisor: restarts matrix monitor if it dies; logs state changes every 10 min.
# Run in persistent Cursor background shell alongside the monitor.
set -uo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SB_ROOT" || exit

MONITOR_SCRIPT="${SB_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh"
MONITOR_PID_FILE="${SB_ROOT}/.e2e-matrix-monitor.pid"
SUPERVISOR_LOG="${SB_ROOT}/.e2e-matrix-supervisor.log"
STATUS_FILE="${SB_ROOT}/.e2e-matrix-monitor-status.txt"
# shellcheck disable=SC2034  # documented default ledger path for operators
LEDGER="${SB_ROOT}/.planning/enterprise-e2e/ROUND-1-LEDGER.md"

INTERVAL="${SB_E2E_SUPERVISOR_INTERVAL:-600}"
MAX_RUNTIME="${SB_E2E_SUPERVISOR_MAX_SEC:-14400}"

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '%s %s\n' "$(utc_now)" "$*" | tee -a "$SUPERVISOR_LOG"; }

monitor_alive() {
  local pid
  [[ -f "$MONITOR_PID_FILE" ]] || return 1
  pid="$(tr -d '[:space:]' <"$MONITOR_PID_FILE")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

start_monitor() {
  log "starting monitor"
  bash "$MONITOR_SCRIPT" &
  echo $! >"$MONITOR_PID_FILE"
  log "monitor pid=$(cat "$MONITOR_PID_FILE")"
}

note_ux_if_needed() {
  local status
  status="$(cat "$STATUS_FILE" 2>/dev/null || true)"
  if printf '%s\n' "$status" | grep -qiE 'hookEventName|Stop hook error'; then
    if ! grep -q 'monitor-supervisor.*hookEventName' "$SUPERVISOR_LOG" 2>/dev/null; then
      log "UX note: hookEventName/Stop hook seen — see UX friction log in ROUND-1-LEDGER.md"
    fi
  fi
  if printf '%s\n' "$status" | grep -qiE '429|QUOTA'; then
    log "state: quota/429 noted — monitor handles wait+retry"
  fi
  if printf '%s\n' "$status" | grep -qiE 'COMPLETE'; then
    log "matrix COMPLETE — supervisor exiting"
    exit 0
  fi
}

start_epoch="$(date +%s)"
last_state=""
trap '' HUP
trap 'log "supervisor signal — exiting"; exit 0' INT TERM

while true; do
  now="$(date +%s)"
  if (( now - start_epoch > MAX_RUNTIME )); then
    log "max runtime ${MAX_RUNTIME}s reached — exiting"
    exit 0
  fi

  if ! monitor_alive; then
    log "monitor dead — restarting"
    start_monitor
  fi

  cur_state="$(grep -E '^batch PID:|^current row' "$STATUS_FILE" 2>/dev/null | tr '\n' ' ')"
  if [[ "$cur_state" != "$last_state" ]]; then
    log "state change: ${cur_state}"
    last_state="$cur_state"
  fi

  note_ux_if_needed
  sleep "$INTERVAL"
done

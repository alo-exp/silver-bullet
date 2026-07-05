#!/usr/bin/env bash
# Poll a codex FORCE batch PID; on exit log and optionally chain resume.
# Usage: .codex-r3-poll-watch.sh <batch_pid> [poll_interval_sec]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BATCH_PID="${1:?batch pid required}"
INTERVAL="${2:-75}"
LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-poll-watch.log"
NOHUP_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-watch-nohup.log"

codex_matrix_env() {
  export SB_ROOT="$ROOT"
  export SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md
  export SB_E2E_MATRIX_LOG=.e2e-matrix-codex-live.log
  export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-codex-batch.pid
  export SILVER_BULLET_RUNTIME=codex
  export SB_E2E_LIVE_RUNTIME=codex
  export RTK_DISABLED=1
  export SB_E2E_MATRIX_FORCE=1
  export SB_E2E_MATRIX_CLEAN_ENV=0
  export CODEX_INTERACTIVE_IDLE_TIMEOUT="${CODEX_INTERACTIVE_IDLE_TIMEOUT:-1800}"
}

batch_child_matrix() {
  local pid="$1"
  ps -o command= -p "$pid" 2>/dev/null | grep -q 'enterprise-e2e/matrix.sh' || return 1
  return 0
}

log_line() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"
}

log_line "WATCH start batch=${BATCH_PID} interval=${INTERVAL}s"

while kill -0 "$BATCH_PID" 2>/dev/null; do
  child=""
  child="$(pgrep -P "$BATCH_PID" 2>/dev/null | head -1 || true)"
  if [[ -n "$child" ]] && batch_child_matrix "$child"; then
    log_line "BATCH=${BATCH_PID} RUNNING child=${child} row~?"
  else
    log_line "BATCH=${BATCH_PID} RUNNING"
  fi
  sleep "$INTERVAL"
done

log_line "BATCH=${BATCH_PID} EXIT — watcher resume hook disabled (caller launches resume)"

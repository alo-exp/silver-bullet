#!/usr/bin/env bash
# Detached launcher for Round-3 retry batch TUI monitor (survives agent shell SIGHUP).
set -euo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SB_ROOT"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
enterprise_e2e_prepend_harness_path
export SB_E2E_LEDGER_NO_UX_APPEND=1
export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-5-LEDGER.md}"
export SB_E2E_MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-round5-live.log}"
enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"
LOG=".planning/enterprise-e2e/.tui-monitor-agent-run.log"
PIDFILE=".planning/enterprise-e2e/.tui-monitor-agent-run.pid"
SCRIPT=".planning/enterprise-e2e/.tui-monitor-batch-continuation.py"
pid="$(sb_run_detached --log "$LOG" -- python3 "$SCRIPT")"
printf '%s\n' "$pid" >"$PIDFILE"
printf 'tui-monitor-batch-continuation pid=%s log=%s\n' "$pid" "$LOG"

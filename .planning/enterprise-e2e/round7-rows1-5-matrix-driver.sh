#!/usr/bin/env bash
set -euo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MATRIX_BRANCH="${SB_E2E_MATRIX_BRANCH:-enterprise-e2e/multi-host}"
cd "$SB_ROOT"
if git rev-parse --verify "$MATRIX_BRANCH" >/dev/null 2>&1; then
  current_branch="$(git branch --show-current 2>/dev/null || true)"
  if [[ "$current_branch" != "$MATRIX_BRANCH" ]]; then
    echo "round7-rows1-5-matrix-driver: checkout ${MATRIX_BRANCH} (was: ${current_branch:-detached})"
    git checkout "$MATRIX_BRANCH"
  fi
fi
cd "$SB_ROOT"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
sb_prepend_harness_path
enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_STATE_DIR:-/tmp}"
enterprise_e2e_quiesce_orchestrator_queue "$SB_ROOT" || true

export SB_E2E_LEDGER_NO_UX_APPEND=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
export SB_E2E_MONITOR_AUTO_RESTART=0
export RTK_DISABLED=1
export SB_E2E_SESSION0_SKIP=1
export SB_E2E_SESSION0_SKIP_REASON="Round 7 rows 1-5 FORCE; Session 0 satisfied in prior rounds"
export SB_E2E_LEDGER_FILE="${SB_ROOT}/.planning/enterprise-e2e/ROUND-7-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export SB_E2E_MATRIX_LOG="${SB_ROOT}/.e2e-matrix-round7-rows1-5.log"
export SB_E2E_MATRIX_BATCH_PID_FILE="${SB_ROOT}/.e2e-matrix-round7-rows1-5-batch.pid"
export SB_E2E_MATRIX_MONITOR_PID_FILE="${SB_ROOT}/.e2e-matrix-round7-rows1-5-monitor.pid"
export SB_E2E_MATRIX_MONITOR_POLL_LOG="${SB_ROOT}/.e2e-matrix-round7-rows1-5-monitor-poll.log"
export SB_E2E_MATRIX_MONITOR_STATUS_FILE="${SB_ROOT}/.e2e-matrix-round7-rows1-5-monitor-status.txt"
export SB_ENTERPRISE_E2E_LIVE=1
# OUT-SURFACE-01: host-bundles relocation pending — documented skip per ROUND-7-GATES.md
export SB_E2E_SURFACE_SKIP=1

ROWS=(1 2 3 4 5)
printf '\n=== round7 rows1-5 FORCE %s rows %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${ROWS[*]}"

exec env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight "${ROWS[@]}" \
  2>&1 | tee -a "$SB_E2E_MATRIX_LOG"

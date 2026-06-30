#!/usr/bin/env bash
# Round 6 full live matrix driver — survives agent session detach.
# Allocates a pseudo-TTY when launched without one (install-claude / Claude TUI).
set -euo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MATRIX_BRANCH="${SB_E2E_MATRIX_BRANCH:-enterprise-e2e/round6}"
cd "$SB_ROOT"
if git rev-parse --verify "$MATRIX_BRANCH" >/dev/null 2>&1; then
  current_branch="$(git branch --show-current 2>/dev/null || true)"
  if [[ "$current_branch" != "$MATRIX_BRANCH" ]]; then
    echo "round6-matrix-driver: checkout ${MATRIX_BRANCH} (was: ${current_branch:-detached})"
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
enterprise_e2e_quiesce_orchestrator_queue "$SB_ROOT"

export SB_E2E_LEDGER_NO_UX_APPEND=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
export SB_E2E_MONITOR_AUTO_RESTART=0
export RTK_DISABLED=1
export SB_E2E_SESSION0_SKIP=1
export SB_E2E_SESSION0_SKIP_REASON="Round 6; Session 0 satisfied in prior rounds"
export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-6-LEDGER.md}"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export SB_E2E_MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-round6-live.log}"
export SB_ENTERPRISE_E2E_LIVE=1

DRIVER_LOG="${SB_E2E_ROUND6_DRIVER_LOG:-${SB_ROOT}/.e2e-round6-driver.log}"
LIVE_ARGS=(--skip-code-intel-preflight)
if (("$#" > 0)); then
  LIVE_ARGS+=("$@")
else
  LIVE_ARGS+=(--resume)
fi

if sb_detach_has_controlling_tty; then
  exec env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh "${LIVE_ARGS[@]}" \
    2>&1 | tee -a "$SB_E2E_MATRIX_LOG"
fi

driver_pid="$(sb_run_detached_pty --log "$DRIVER_LOG" -- \
  env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh "${LIVE_ARGS[@]}")"
printf '%s\n' "$driver_pid" >"${SB_ROOT}/.e2e-round6-driver.pid"
echo "round6-matrix-driver: detached pid ${driver_pid} (log ${DRIVER_LOG})"

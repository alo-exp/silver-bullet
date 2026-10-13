#!/usr/bin/env bash
# Round 9 Claude honest smoke/full matrix driver.
set -euo pipefail
MAIN="${SB_E2E_MAIN_REPO:-/Users/shafqat/projects/silver-bullet/repo}"
# shellcheck source=scripts/lib/enterprise-e2e-sb-root-resolve.sh
source "${MAIN}/scripts/lib/enterprise-e2e-sb-root-resolve.sh"
SB_ROOT="${SB_ROOT:-$(enterprise_e2e_resolve_sb_root)}"
export SB_ROOT SB_E2E_MAIN_REPO="$MAIN"
cd "$SB_ROOT"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
sb_prepend_harness_path
enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"
enterprise_e2e_quiesce_orchestrator_queue "$SB_ROOT" || true

unset SB_E2E_SKIP_INSTALL_CLAUDE
export SB_E2E_LEDGER_NO_UX_APPEND=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
export SB_E2E_MONITOR_AUTO_RESTART=0
export RTK_DISABLED=1
export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${MAIN}/.planning/enterprise-e2e/ROUND-9-LEDGER.md}"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app-round9-claude}"
export SB_E2E_TEST_APP_ROUND=9
export SB_E2E_TEST_APP_BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-9-claude}"
export SB_E2E_TEST_APP_BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-8482e60}"
export SB_E2E_MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-r9-claude-matrix-live.log}"
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_SURFACE_SKIP=0
export SILVER_BULLET_RUNTIME=claude
export SB_E2E_LIVE_RUNTIME=claude

DRIVER_LOG="${SB_E2E_ROUND9_DRIVER_LOG:-${SB_ROOT}/.e2e-r9-claude-driver.log}"
LIVE_ARGS=()
if (("$#" > 0)); then
  LIVE_ARGS+=("$@")
else
  LIVE_ARGS+=(1 3 6 11 21 22)
fi

printf '\n=== round9 smoke matrix %s SB_E2E_SURFACE_SKIP=%s branch=%s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SB_E2E_SURFACE_SKIP}" "${SB_E2E_TEST_APP_BRANCH}"

if sb_detach_has_controlling_tty; then
  exec env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh "${LIVE_ARGS[@]}" \
    2>&1 | tee -a "$SB_E2E_MATRIX_LOG"
fi

driver_pid="$(sb_run_detached_pty --log "$DRIVER_LOG" -- \
  env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh "${LIVE_ARGS[@]}")"
printf '%s\n' "$driver_pid" >"${MAIN}/.e2e-r9-claude-driver.pid"
echo "round9-matrix-driver: detached pid ${driver_pid} (log ${DRIVER_LOG})"

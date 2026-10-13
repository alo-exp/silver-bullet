#!/usr/bin/env bash
# Codex Round 8 Tier B→C continuation — ONE driver, fixture pin, SB_E2E_SURFACE_SKIP=0.
set -euo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
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
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_SURFACE_SKIP=0
export RTK_DISABLED=1
export SB_E2E_SESSION0_SKIP=1
export SB_E2E_SESSION0_SKIP_REASON="codex-r8 Tier B→C @ bb380667+"
export SB_E2E_LEDGER_FILE="${SB_ROOT}/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export SB_E2E_TEST_APP_BRANCH="${SB_E2E_TEST_APP_BRANCH:-enterprise-e2e/round-8-codex}"
export SB_E2E_TEST_APP_BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-baadf87}"
export SB_E2E_MATRIX_LOG="${SB_ROOT}/.e2e-matrix-codex-live.log"
export SB_E2E_MATRIX_BATCH_PID_FILE="${SB_ROOT}/.e2e-matrix-codex-batch.pid"
export SB_ENTERPRISE_E2E_LIVE=1
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export CODEX_INTERACTIVE_IDLE_TIMEOUT="${CODEX_INTERACTIVE_IDLE_TIMEOUT:-1800}"

# Tier B smoke first, then force4 failures + remainder (bbf97fd9 idle watchdog active).
ROWS=(1 3 6 15 16 4 5 8 9 11 12 13 14 17 18 19 20 2 10)
printf '\n=== codex-r8-tierbc FORCE %s rows %s @ %s fixture %s@%s ===\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${ROWS[*]}" "$(git rev-parse --short HEAD)" \
  "${SB_E2E_TEST_APP_BRANCH}" "${SB_E2E_TEST_APP_BASELINE_SHA}"

exec env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight "${ROWS[@]}" \
  2>&1 | tee -a "$SB_E2E_MATRIX_LOG"

#!/usr/bin/env bash
# Round 5 full live matrix driver — survives agent session detach.
set -euo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SB_ROOT"
# shellcheck source=tests/live/lib/detach-background.sh
source "${SB_ROOT}/tests/live/lib/detach-background.sh"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
sb_prepend_harness_path
enterprise_e2e_reset_tui_monitor_offsets "$SB_ROOT"

export SB_E2E_LEDGER_NO_UX_APPEND=1
export SB_E2E_MATRIX_FORCE=1
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=0
export CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=arrow
export SB_E2E_MONITOR_AUTO_RESTART=1
export RTK_DISABLED=1
export SB_E2E_SESSION0_SKIP=1
export SB_E2E_SESSION0_SKIP_REASON="Round 5; Session 0 satisfied in prior rounds"
export SB_E2E_LEDGER_FILE="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-5-LEDGER.md}"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export SB_E2E_MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-round5-live.log}"
export SB_ENTERPRISE_E2E_LIVE=1

bash scripts/run-enterprise-e2e-live-test.sh --resume 2>&1 | tee -a "$SB_E2E_MATRIX_LOG"

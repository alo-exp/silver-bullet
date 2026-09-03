#!/usr/bin/env bash
set -euo pipefail
SB_ROOT=/private/tmp/sb-main-row11-fp
MAIN=/Users/shafqat/projects/silver-bullet/repo
RESUME_LOG="$SB_ROOT/.e2e-r8-claude-resume-fp-live.log"
ORCH_LOG="$MAIN/.e2e-r8-resume-after-47290-orchestrator.log"
TEST_APP=/Users/shafqat/projects/enterprise-grade-test-app
export SB_E2E_INSTALL_FP=claude@89e2ab8f96a1+724a435c9991
export SB_ROOT SB_E2E_INSTALL_FP
export SB_TEST_ENTERPRISE_APP_ROOT="$TEST_APP"
export SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-8-claude
export SB_E2E_TEST_APP_BASELINE_SHA=8482e60
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
export SB_E2E_MATRIX_LOG="$RESUME_LOG"
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_ENTERPRISE_E2E_LIVE=1
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_SESSION0_SKIP=1
export RTK_DISABLED=1
export SILVER_BULLET_RUNTIME=claude
export SB_E2E_LIVE_RUNTIME=claude
export SB_E2E_MATRIX_FORCE=1
ROWS=(2 5 8 9 10 12 14 15 16 17 18 19 20)
git -C "$TEST_APP" checkout enterprise-e2e/round-8-claude -q
git -C "$TEST_APP" reset --hard 8482e60 -q
cd "$SB_ROOT"
exec bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight "${ROWS[@]}" 2>&1 | tee -a "$RESUME_LOG"

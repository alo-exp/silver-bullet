#!/usr/bin/env bash
# Round Codex-2 Tier A — offline structural gates (no TUI).
# Run all green before SB_ENTERPRISE_E2E_LIVE=1 Tier B smoke.
set -euo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SB_ROOT"
export RTK_DISABLED=1
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="${SB_ROOT}/.planning/enterprise-e2e/ROUND-CODEX-2-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
LOG="${SB_ROOT}/.planning/enterprise-e2e/.codex-r2-tiera-offline.log"
: >"$LOG"

run_check() {
  local label="$1"
  shift
  printf '\n=== Tier A: %s ===\n' "$label" | tee -a "$LOG"
  if "$@" >>"$LOG" 2>&1; then
    printf 'PASS: %s\n' "$label" | tee -a "$LOG"
  else
    printf 'FAIL: %s\n' "$label" | tee -a "$LOG"
    exit 1
  fi
}

printf '=== Round Codex-2 Tier A offline @ %s branch=%s ===\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD)" | tee -a "$LOG"

run_check "structural harness" bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh
run_check "outcome harness" bash tests/scripts/test-outcome-assessment.sh
run_check "validation overlay dry-run" bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
run_check "pre-release overlay dry-run" bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
if [[ -x "${SB_ROOT}/scripts/validate-host-install-surface.sh" ]]; then
  run_check "host install surface" bash scripts/validate-host-install-surface.sh --repo-root "$SB_ROOT" --host codex
else
  printf 'SKIP: validate-host-install-surface.sh absent (covered by validate-host-skill-surface + tri-host)\n' | tee -a "$LOG"
fi
run_check "tri-host smoke codex" bash scripts/run-tri-host-install-smoke.sh --host codex
run_check "hook delivery preflight" bash tests/e2e-live/hook-delivery-preflight.sh
run_check "ladder smoke" env SILVER_BULLET_RUNTIME=codex bash tests/live/test-live-review-fix-ladder-smoke.sh
run_check "host preflight" bash scripts/run-enterprise-e2e-live-test.sh --host codex --preflight-only
run_check "dry-run matrix" env SB_E2E_MATRIX_DRY_RUN=1 bash scripts/run-enterprise-e2e-matrix.sh

printf '\n=== Tier A COMPLETE @ %s ===\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOG"

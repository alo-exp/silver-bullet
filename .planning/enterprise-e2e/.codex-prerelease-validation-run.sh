#!/usr/bin/env bash
# Codex branch pre-release validation harness (NO release actions).
# Logs to .planning/enterprise-e2e/.codex-prerelease-validation.log
set -uo pipefail

SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SB_ROOT"
LOG="${SB_ROOT}/.planning/enterprise-e2e/.codex-prerelease-validation.log"

export RTK_DISABLED=1
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export SB_LIVE_AGENT=codex
export SB_E2E_LIVE_AGENT=codex
export SB_LIVE_RUNTIMES=codex
export SB_E2E_LIVE_RUNTIMES=codex
export SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1
export SB_E2E_LEDGER_FILE="${SB_ROOT}/.planning/enterprise-e2e/ROUND-CODEX-2-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-alo-exp/silver-bullet}"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
declare -a FAILURES=()
declare -a SKIPS=()

: >"$LOG"

log() { printf '%s\n' "$*" | tee -a "$LOG"; }

run_check() {
  local label="$1"
  shift
  log ""
  log "=== CHECK: ${label} ==="
  log "CMD: $*"
  local start end rc
  start=$(date +%s)
  if "$@" >>"$LOG" 2>&1; then
    rc=0
    log "RESULT: PASS (${label})"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    rc=$?
    log "RESULT: FAIL (${label}) exit=${rc}"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILURES+=("${label}")
  fi
  end=$(date +%s)
  log "DURATION: $((end - start))s"
  return "$rc"
}

run_check_allow_fail() {
  run_check "$@" || true
}

run_skip() {
  local label="$1"
  local reason="$2"
  log ""
  log "=== SKIP: ${label} ==="
  log "REASON: ${reason}"
  TOTAL_SKIP=$((TOTAL_SKIP + 1))
  SKIPS+=("${label}: ${reason}")
}

log "=== Codex Pre-Release Validation @ $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
log "BRANCH: $(git branch --show-current 2>/dev/null || echo unknown)"
log "HEAD: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
log "SB_ROOT: ${SB_ROOT}"
log ""

# --- Core test suite ---
run_check_allow_fail "run-all-tests.sh" bash tests/run-all-tests.sh

# --- Enterprise E2E Tier A (codex offline bundle) ---
run_check_allow_fail "Tier A codex-r2-tiera-offline" bash .planning/enterprise-e2e/codex-r2-tiera-offline.sh

# --- Tier A extras from ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md ---
run_check_allow_fail "validation overlay structural test" \
  bash tests/enterprise-e2e-live/test-enterprise-e2e-validation-overlay.sh
if [[ -f "${SB_ROOT}/tests/scripts/test-validate-host-install-surface.sh" ]]; then
  run_check_allow_fail "validate-host-install-surface test" \
    bash tests/scripts/test-validate-host-install-surface.sh
else
  run_skip "validate-host-install-surface test" \
    "tests/scripts/test-validate-host-install-surface.sh absent (covered by validate-host-skill-surface + tri-host)"
fi
run_check_allow_fail "enterprise-e2e test-app branch" \
  bash tests/scripts/test-enterprise-e2e-test-app-branch.sh

# --- Stage 4a site freshness (pre-release-quality-gate.md) ---
run_check_allow_fail "site content freshness" bash tests/scripts/test-site-content-freshness.sh
run_check_allow_fail "site doc freshness" bash tests/scripts/test-site-doc-freshness.sh

# --- Stage 4b overlays (pre-release-quality-gate.md) ---
run_check_allow_fail "pre-release overlay dry-run" \
  bash scripts/run-enterprise-e2e-pre-release-overlay.sh --dry-run
run_check_allow_fail "pre-release overlay with tri-host smoke" \
  bash scripts/run-enterprise-e2e-pre-release-overlay.sh --with-tri-host-smoke
run_check_allow_fail "validation overlay dry-run" \
  bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run

# --- Pre-release host smoke (Stage 4b + Live Matrix Gate) ---
if [[ -n "${CURSOR_API_KEY:-}" ]]; then
  run_check_allow_fail "pre-release host smoke (tri-host)" \
    env AGENT_CLI_CREDENTIAL_STORE=memory bash scripts/run-pre-release-host-smoke.sh
else
  run_check_allow_fail "pre-release host smoke (codex-only, no CURSOR_API_KEY)" \
    bash scripts/run-pre-release-host-smoke.sh --host codex
  run_skip "pre-release host smoke (cursor/claude full tri-host)" \
    "CURSOR_API_KEY unset — codex-only smoke ran above"
fi

# --- Quality gate validators (optional automated checks) ---
run_check_allow_fail "validate-launch-review.sh" bash scripts/validate-launch-review.sh
run_check_allow_fail "validate-sentinel-skills-manifest.sh" bash scripts/validate-sentinel-skills-manifest.sh

# --- CI gate check (validation only, no tag/release) ---
run_check_allow_fail "verify-release-commit-ci.sh" bash scripts/verify-release-commit-ci.sh

# --- Summary ---
log ""
log "========================================"
log "PRE-RELEASE VALIDATION SUMMARY"
log "========================================"
log "PASS: ${TOTAL_PASS}"
log "FAIL: ${TOTAL_FAIL}"
log "SKIP: ${TOTAL_SKIP}"
if ((${#FAILURES[@]} > 0)); then
  log ""
  log "FAILING CHECKS:"
  for f in "${FAILURES[@]}"; do
    log "  - ${f}"
  done
fi
if ((${#SKIPS[@]} > 0)); then
  log ""
  log "SKIPPED CHECKS:"
  for s in "${SKIPS[@]}"; do
    log "  - ${s}"
  done
fi
log ""
log "LOG: ${LOG}"
log "COMPLETED: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

[[ $TOTAL_FAIL -eq 0 ]]

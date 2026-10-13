#!/usr/bin/env bash
# Structural tests for enterprise E2E preflight + smoke harness scripts.
set -euo pipefail

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle]"
  fi
}

for script in \
  preflight-round.sh \
  smoke-matrix.sh \
  strict-clean-check.sh \
  enterprise-e2e-checkpoint.sh; do
  assert_executable "${REPO_ROOT}/scripts/enterprise-e2e/${script}" "${script} executable"
done

assert_contains "preflight gate 0 surface" \
  "${REPO_ROOT}/scripts/enterprise-e2e/preflight-round.sh" \
  "validate-host-install-surface"

assert_contains "preflight gate 1 dry-run matrix" \
  "${REPO_ROOT}/scripts/enterprise-e2e/preflight-round.sh" \
  "SB_E2E_MATRIX_DRY_RUN=1"

assert_contains "smoke rows 1 3 6 11 21 22" \
  "${REPO_ROOT}/scripts/enterprise-e2e/smoke-matrix.sh" \
  "SMOKE_ROWS=(1 3 6 11 21 22)"

assert_contains "strict-clean rejects surface skip" \
  "${REPO_ROOT}/scripts/enterprise-e2e/strict-clean-check.sh" \
  "SB_E2E_SURFACE_SKIP"

assert_contains "checkpoint unified table" \
  "${REPO_ROOT}/scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh" \
  "Poll checkpoint"

checkpoint_output=""
if checkpoint_output="$(bash "${REPO_ROOT}/scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh" 2>/dev/null)" \
  && grep -qF 'Driver PID' <<<"$checkpoint_output"; then
  pass "checkpoint emits markdown block"
else
  fail "checkpoint emits markdown block"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

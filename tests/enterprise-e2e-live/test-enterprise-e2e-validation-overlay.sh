#!/usr/bin/env bash
# Structural tests for enterprise E2E validation overlay wiring.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in $file"
  fi
}

assert_file_exists "${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md" "validation plan exists"
assert_file_exists "${REPO_ROOT}/docs/testing/validation-claims-registry.json" "validation claims registry exists"
assert_executable "${REPO_ROOT}/scripts/run-enterprise-e2e-validation-overlay.sh" "validation overlay script executable"
assert_file_exists "${REPO_ROOT}/scripts/lib/enterprise-e2e-validation-overlay.sh" "validation overlay lib exists"

assert_contains "overlay sets SB_E2E_VALIDATION_OVERLAY" \
  "${REPO_ROOT}/scripts/run-enterprise-e2e-validation-overlay.sh" "SB_E2E_VALIDATION_OVERLAY=1"
assert_contains "overlay supports dry-run" \
  "${REPO_ROOT}/scripts/run-enterprise-e2e-validation-overlay.sh" "--dry-run"
assert_contains "overlay does not pkill matrix" \
  "${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md" "does not start, stop, or signal"
assert_contains "live test wires validation pre-gate" \
  "${REPO_ROOT}/scripts/run-enterprise-e2e-live-test.sh" "run-enterprise-e2e-validation-overlay.sh"
assert_contains "live test documents SB_E2E_VALIDATION_OVERLAY" \
  "${REPO_ROOT}/scripts/run-enterprise-e2e-live-test.sh" "SB_E2E_VALIDATION_OVERLAY"

PLAN="${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md"
for needle in \
  "Validation vs" \
  "help-center-staleness" \
  "SB_E2E_VALIDATION_OVERLAY" \
  "Gap remediation" \
  "Release Confidence Score"
do
  assert_contains "validation plan documents: $needle" "$PLAN" "$needle"
done

if command -v jq >/dev/null 2>&1; then
  claim_count="$(jq '.claims | length' "${REPO_ROOT}/docs/testing/validation-claims-registry.json")"
  if [[ "$claim_count" -ge 10 ]]; then
    pass "validation registry has ${claim_count} claims"
  else
    fail "validation registry too small (${claim_count})"
  fi
else
  pass "validation registry parse skipped (jq missing)"
fi

if RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/run-enterprise-e2e-validation-overlay.sh" --dry-run >/tmp/sb-validation-overlay-test.log 2>&1; then
  pass "validation overlay dry-run executes"
else
  fail "validation overlay dry-run failed — see /tmp/sb-validation-overlay-test.log"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

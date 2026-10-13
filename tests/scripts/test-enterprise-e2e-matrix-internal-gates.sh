#!/usr/bin/env bash
# Smoke rows 21-22 internal gates must pass when parent rows 3/4 were not run live.
set -euo pipefail

PASS=0
FAIL=0

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
FIXTURE="$(mktemp -d "${TMPDIR}/sb-matrix-internal-gates.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.planning/workflows" "$FIXTURE/.planning/enterprise-e2e"

out="$(SB_E2E_MATRIX_DRY_RUN=1 \
  SB_E2E_TEST_APP_BRANCH_ENFORCE=0 \
  SB_E2E_FIXTURE_BRANCH_LOCK=0 \
  SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE" \
  SB_E2E_ROW_PASS_REGISTRY="$FIXTURE/.planning/enterprise-e2e/.row-pass-registry.json" \
  bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 22 2>&1)" || true

assert_ok "dry-run row 22 internal PASS" grep -q 'validate-substep (internal) PASS' <<<"$out"
assert_ok "bugfix-health.md seeded with validate-substep" \
  grep -q 'validate-substep' "$FIXTURE/.planning/workflows/bugfix-health.md"

out21="$(SB_E2E_MATRIX_DRY_RUN=1 \
  SB_E2E_TEST_APP_BRANCH_ENFORCE=0 \
  SB_E2E_FIXTURE_BRANCH_LOCK=0 \
  SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE" \
  SB_E2E_ROW_PASS_REGISTRY="$FIXTURE/.planning/enterprise-e2e/.row-pass-registry.json" \
  bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 21 2>&1)" || true

assert_ok "dry-run row 21 internal PASS" grep -q 'post-exec-gates (internal) PASS' <<<"$out21"
assert_ok "feature-currency.md seeded with post-exec-gates" \
  grep -q 'post-exec-gates' "$FIXTURE/.planning/workflows/feature-currency.md"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

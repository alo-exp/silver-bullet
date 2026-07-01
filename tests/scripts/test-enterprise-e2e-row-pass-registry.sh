#!/usr/bin/env bash
# Structural tests for install-version row pass registry.
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="$(mktemp -d "${TMPDIR}/sb-row-pass-registry.XXXXXX")"
REGISTRY="${STATE_DIR}/.row-pass-registry.json"
trap 'rm -rf "$STATE_DIR"' EXIT

export SB_ROOT="$REPO_ROOT"
export SB_E2E_ROW_PASS_REGISTRY="$REGISTRY"
export SB_E2E_INSTALL_FP="claude:0.49.1-test"
export SB_E2E_LIVE_RUNTIME=claude
export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"

# shellcheck source=scripts/enterprise-e2e/lib/row-pass-registry.sh
source "${REPO_ROOT}/scripts/enterprise-e2e/lib/row-pass-registry.sh"

if [[ "$(enterprise_e2e_install_fingerprint)" == "claude:0.49.1-test" ]]; then
  pass "install_fp honors SB_E2E_INSTALL_FP override"
else
  fail "install_fp override"
fi

enterprise_e2e_row_pass_registry_record 3 ".e2e-row3-attempt.log" true
if enterprise_e2e_row_pass_registry_has_pass 3; then
  pass "record + lookup row 3"
else
  fail "record + lookup row 3"
fi

if ! enterprise_e2e_row_pass_registry_has_pass 4; then
  pass "row 4 not registered"
else
  fail "row 4 should be absent"
fi

if [[ "$(enterprise_e2e_row_pass_registry_pass_count)" == "1" ]]; then
  pass "pass count = 1"
else
  fail "pass count expected 1 got $(enterprise_e2e_row_pass_registry_pass_count)"
fi

rows="$(enterprise_e2e_row_pass_registry_list_rows | tr '\n' ' ')"
if [[ "$rows" == "3 " || "$rows" == "3" ]]; then
  pass "list_rows returns 3"
else
  fail "list_rows got '${rows}'"
fi

# Matrix dry-run: registry skip counts as PASS not SKIP
export SB_E2E_MATRIX_DRY_RUN=1
export SB_ENTERPRISE_E2E_LIVE=1
MATRIX_OUT="$(bash "${REPO_ROOT}/scripts/run-enterprise-e2e-matrix.sh" 3 2>&1)" || true
if printf '%s\n' "$MATRIX_OUT" | grep -q 'ROW_ALREADY_PASSED_SAME_INSTALL'; then
  pass "matrix emits ROW_ALREADY_PASSED_SAME_INSTALL for registered row"
else
  fail "matrix registry skip message missing"
fi
if printf '%s\n' "$MATRIX_OUT" | grep -q 'Pass:  1'; then
  pass "registry skip increments Pass not Skip"
else
  fail "registry skip should count as Pass"
fi

if [[ "$FAIL" -eq 0 ]]; then
  echo ""
  echo "All ${PASS} tests passed"
  exit 0
fi

echo ""
echo "${FAIL} test(s) failed, ${PASS} passed"
exit 1

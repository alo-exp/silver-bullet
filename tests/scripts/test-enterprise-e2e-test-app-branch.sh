#!/usr/bin/env bash
# Structural tests for test-app branch policy helpers (no live git mutations).
set -euo pipefail

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=scripts/enterprise-e2e/lib/test-app-branch.sh
source "${REPO_ROOT}/scripts/enterprise-e2e/lib/test-app-branch.sh"
# shellcheck source=scripts/enterprise-e2e/lib/core.sh
source "${REPO_ROOT}/scripts/enterprise-e2e/lib/core.sh"

assert_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    pass "$desc"
  else
    fail "$desc — want [$want] got [$got]"
  fi
}

[[ -f "${REPO_ROOT}/scripts/enterprise-e2e/lib/test-app-branch.sh" ]] \
  && pass "test-app-branch.sh exists" \
  || fail "test-app-branch.sh missing"

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle]"
  fi
}

assert_contains "live-test calls branch preflight" \
  "${REPO_ROOT}/scripts/enterprise-e2e/live-test.sh" \
  "enterprise_e2e_assert_test_app_branch"

assert_contains "matrix calls branch preflight" \
  "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" \
  "enterprise_e2e_assert_test_app_branch"

assert_contains "test app branch assert helper" \
  "${REPO_ROOT}/scripts/enterprise-e2e/lib/test-app-branch.sh" \
  "enterprise_e2e_assert_test_app_branch"

assert_contains "hosts.json cursor test app root worktree" \
  "${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json" \
  "enterprise-grade-test-app-cursor"

assert_contains "hosts.json cursor test app branch" \
  "${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json" \
  "enterprise-e2e/round-1-cursor"

assert_contains "policy doc exists" \
  "${REPO_ROOT}/.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md" \
  "enterprise-e2e/round-1-cursor"

export SB_E2E_LEDGER_FILE="${REPO_ROOT}/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
export SB_E2E_LIVE_RUNTIME=claude
assert_eq "round from ROUND-8 ledger" "8" "$(enterprise_e2e_test_app_round_from_ledger)"

unset SB_E2E_TEST_APP_BRANCH
export SB_E2E_LIVE_RUNTIME=cursor
enterprise_e2e_apply_test_app_branch_defaults
assert_eq "hosts.json default cursor test app branch" \
  "enterprise-e2e/round-1-cursor" \
  "${SB_E2E_TEST_APP_BRANCH:-}"

unset SB_E2E_TEST_APP_BRANCH SB_E2E_TEST_APP_ROUND SB_E2E_LEDGER_FILE
export SB_E2E_LIVE_RUNTIME=claude
export SB_E2E_TEST_APP_ROUND=8
assert_eq "expected branch claude r8 derived" \
  "enterprise-e2e/round-8-claude" \
  "$(enterprise_e2e_test_app_expected_branch)"

unset SB_E2E_TEST_APP_BRANCH SB_E2E_TEST_APP_ROUND SB_E2E_LEDGER_FILE
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_TEST_APP_ROUND=2
assert_eq "expected branch codex r2 derived" \
  "enterprise-e2e/round-2-codex" \
  "$(enterprise_e2e_test_app_expected_branch)"

unset SB_E2E_TEST_APP_BRANCH SB_E2E_TEST_APP_ROUND SB_E2E_LEDGER_FILE
export SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_TEST_APP_ROUND=1
assert_eq "expected branch cursor r1 derived" \
  "enterprise-e2e/round-1-cursor" \
  "$(enterprise_e2e_test_app_expected_branch)"

assert_eq "default baseline sha" "8482e60" "$(enterprise_e2e_test_app_default_baseline_sha)"

# --- install-version single-pass skip (structural) ---
TMP_E2E="$(mktemp -d)"
trap 'rm -rf "$TMP_E2E"' EXIT
export SB_ROOT="$TMP_E2E"
mkdir -p "$TMP_E2E/.planning/enterprise-e2e"
cat >"$TMP_E2E/.e2e-cursor-install-version.txt" <<'VER'
SB_CURSOR_PLUGIN_VERSION=0.48.9
SB_INSTALL_SHA=abc1234
SB_INSTALL_VERSION_KEY=0.48.9@abc1234
VER
cat >"$TMP_E2E/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md" <<'LED'
| SB repo SHA | `abc1234` |
| # | WF slug | Pass/Fail |
| 1 | `silver-router` | **Pass** |
| 3 | `silver-feature` | **Pass** |
LED
assert_eq "install version key from file" "0.48.9@abc1234" "$(enterprise_e2e_sb_install_version_key)"
enterprise_e2e_matrix_force_active && fail "force inactive by default" || pass "force inactive by default"
enterprise_e2e_row_passed_at_install_version 1 && pass "row 1 pass @ install version from ledger" \
  || fail "row 1 pass @ install version from ledger"
enterprise_e2e_matrix_should_skip_row_at_version 1 && pass "matrix skip row 1 @ version" \
  || fail "matrix skip row 1 @ version"
export SB_E2E_MATRIX_FORCE=1
enterprise_e2e_matrix_should_skip_row_at_version 1 && pass "FORCE=1 does not bypass install registry" \
  || fail "FORCE=1 should not bypass install registry"
export SB_E2E_MATRIX_FORCE_ALL=1
enterprise_e2e_matrix_should_skip_row_at_version 1 && fail "FORCE_ALL overrides skip" \
  || pass "FORCE_ALL overrides skip"
unset SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_FORCE_ALL
enterprise_e2e_row_passed_at_install_version 2 && fail "row 2 not pass" || pass "row 2 not pass @ version"

assert_contains "matrix.sh install-version skip" \
  "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" \
  "ROW_ALREADY_PASSED_SAME_INSTALL"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

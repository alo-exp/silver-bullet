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

HARNESS_CONFIG="${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json"
HARNESS_CORE="${REPO_ROOT}/scripts/enterprise-e2e/lib/core.sh"
METHODOLOGY="${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md"

assert_contains "test app branch assert helper" \
  "${REPO_ROOT}/scripts/enterprise-e2e/lib/test-app-branch.sh" \
  "enterprise_e2e_assert_test_app_branch"
assert_contains "core lib defines enterprise_e2e_fixture_branch" "$HARNESS_CORE" "enterprise_e2e_fixture_branch()"
assert_contains "core lib defines enterprise_e2e_fixture_ensure_branch" "$HARNESS_CORE" "enterprise_e2e_fixture_ensure_branch()"
assert_contains "core lib defines enterprise_e2e_fixture_assert_branch_lock" "$HARNESS_CORE" "enterprise_e2e_fixture_assert_branch_lock()"
assert_contains "core lib defines enterprise_e2e_assert_row_product_commit_delta" "$HARNESS_CORE" "enterprise_e2e_assert_row_product_commit_delta()"

# --- §5b cumulative product-work (FP re-pilot) ---
TMP_CUM="$(mktemp -d)"
export SB_E2E_TEST_APP_BASELINE_SHA=8482e60
export SB_E2E_PRODUCT_WORK_CUMULATIVE=1
git -C "$TMP_CUM" init -q
git -C "$TMP_CUM" config user.email "e2e@test"
git -C "$TMP_CUM" config user.name "e2e"
echo base >"$TMP_CUM/README.md"
git -C "$TMP_CUM" add README.md
git -C "$TMP_CUM" commit -q -m "baseline"
BASE_SHA="$(git -C "$TMP_CUM" rev-parse HEAD)"
export SB_E2E_TEST_APP_BASELINE_SHA="$BASE_SHA"
echo product >>"$TMP_CUM/README.md"
git -C "$TMP_CUM" add README.md
git -C "$TMP_CUM" commit -q -m "product"
HEAD_SHA="$(git -C "$TMP_CUM" rev-parse HEAD)"
if enterprise_e2e_assert_row_product_commit_delta 11 "$HEAD_SHA" "$TMP_CUM"; then
  pass "§5b cumulative allows unchanged HEAD when baseline commits exist"
else
  fail "§5b cumulative should pass row 11 rescore on fixture with product commit"
fi
unset SB_E2E_PRODUCT_WORK_CUMULATIVE SB_E2E_TEST_APP_BASELINE_SHA
rm -rf "$TMP_CUM"

assert_contains "core lib defines enterprise_e2e_assert_row_matrix_baseline_rev_increase" "$HARNESS_CORE" "enterprise_e2e_assert_row_matrix_baseline_rev_increase()"
assert_contains "matrix calls baseline rev gate before product delta" "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" "enterprise_e2e_assert_row_matrix_baseline_rev_increase"
assert_contains "matrix calls fixture_ensure_branch before row invoke" "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" "enterprise_e2e_fixture_ensure_branch"
assert_contains "matrix calls fixture_assert_branch_lock post-invoke" "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" "post-invoke fixture branch"
assert_contains "methodology documents fixture branch pattern" "$METHODOLOGY" "enterprise-e2e/round-"
assert_contains "methodology documents SB_E2E_TEST_APP_BRANCH" "$METHODOLOGY" "SB_E2E_TEST_APP_BRANCH"

assert_contains "hosts.json cursor test app root worktree" \
  "${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json" \
  "enterprise-grade-test-app-cursor"

assert_contains "hosts.json cursor test app branch" \
  "${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json" \
  "enterprise-e2e/round-1-cursor"

assert_contains "hosts.json codex honest baseline sha" \
  "${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json" \
  '"test_app_git_baseline_sha": "09f8d1a"'

assert_contains "hosts.json codex test app branch" \
  "${REPO_ROOT}/scripts/enterprise-e2e/config/hosts.json" \
  '"test_app_git_branch": "enterprise-e2e/round-9-codex"'

assert_contains "policy doc exists" \
  "${REPO_ROOT}/.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md" \
  "enterprise-e2e/round-1-cursor"

export SB_E2E_LIVE_RUNTIME=codex
export SILVER_BULLET_RUNTIME=codex
codex_branch="$(enterprise_e2e_fixture_branch)"
if [[ "$codex_branch" == "enterprise-e2e/round-9-codex" ]]; then
  pass "enterprise_e2e_fixture_branch resolves codex → $codex_branch"
else
  fail "enterprise_e2e_fixture_branch codex expected enterprise-e2e/round-9-codex (got: ${codex_branch:-empty})"
fi

export SB_E2E_LEDGER_FILE="${REPO_ROOT}/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
export SB_E2E_LIVE_RUNTIME=claude
assert_eq "round from ROUND-8 ledger" "8" "$(enterprise_e2e_test_app_round_from_ledger)"

unset SB_E2E_TEST_APP_BRANCH SB_E2E_LEDGER_FILE
export SB_E2E_LIVE_RUNTIME=cursor
enterprise_e2e_apply_test_app_branch_defaults
assert_eq "hosts.json default cursor test app branch" \
  "enterprise-e2e/round-1-cursor" \
  "${SB_E2E_TEST_APP_BRANCH:-}"

unset SB_E2E_TEST_APP_BRANCH SB_E2E_TEST_APP_ROUND SB_E2E_LEDGER_FILE
export SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_LEDGER_FILE="${REPO_ROOT}/.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md"
enterprise_e2e_apply_test_app_branch_defaults
assert_eq "hosts.json wins over ledger cursor round-3" \
  "enterprise-e2e/round-1-cursor" \
  "${SB_E2E_TEST_APP_BRANCH:-}"

unset SB_E2E_TEST_APP_BRANCH SB_E2E_TEST_APP_ROUND SB_E2E_LEDGER_FILE
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="${REPO_ROOT}/.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md"
enterprise_e2e_apply_test_app_branch_defaults
assert_eq "hosts.json wins over ledger codex round-3" \
  "enterprise-e2e/round-9-codex" \
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

assert_eq "default baseline sha (legacy)" "8482e60" "$(enterprise_e2e_test_app_default_baseline_sha)"

unset SB_E2E_TEST_APP_BASELINE_SHA
export SB_E2E_PRODUCT_WORK_GATE=1
assert_eq "default baseline sha (product gate)" "09f8d1a" "$(enterprise_e2e_test_app_default_baseline_sha)"
unset SB_E2E_PRODUCT_WORK_GATE

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

DEFAULT_FIXTURE_ROOT="$(cd "${REPO_ROOT}/../.." && pwd)/enterprise-grade-test-app"
FIXTURE_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-$DEFAULT_FIXTURE_ROOT}"
if [[ "${SB_TEST_ENTERPRISE_FIXTURE_STATE:-0}" != "1" ]]; then
  pass "external fixture state checks skipped (set SB_TEST_ENTERPRISE_FIXTURE_STATE=1 to enable)"
elif [[ -d "${FIXTURE_ROOT}/.git" ]]; then
  if git -C "$FIXTURE_ROOT" show-ref --verify --quiet "refs/heads/enterprise-e2e/round-9-codex" 2>/dev/null; then
    pass "fixture repo has enterprise-e2e/round-9-codex branch"
  else
    fail "fixture repo missing enterprise-e2e/round-9-codex branch"
  fi
  baseline_sha="09f8d1a"
  if git -C "$FIXTURE_ROOT" merge-base --is-ancestor "$baseline_sha" enterprise-e2e/round-9-codex 2>/dev/null; then
    pass "round-9-codex contains baseline $baseline_sha"
  else
    fail "round-9-codex must contain baseline $baseline_sha (Codex-3 REAL seed — see ROUND-CODEX-3-LEDGER.md)"
  fi
  if git -C "$FIXTURE_ROOT" rev-parse enterprise-e2e/round-9-codex 2>/dev/null | grep -q .; then
    head_sha="$(git -C "$FIXTURE_ROOT" rev-parse --short enterprise-e2e/round-9-codex 2>/dev/null || true)"
    if git -C "$FIXTURE_ROOT" merge-base --is-ancestor 826cb5c enterprise-e2e/round-9-codex 2>/dev/null; then
      fail "round-9-codex must not include pre-seed 826cb5c (got HEAD $head_sha)"
    else
      pass "round-9-codex excludes pre-seed 826cb5c (honest product baseline)"
    fi
  fi
else
  fail "external fixture state check requested but no git repository exists at $FIXTURE_ROOT"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

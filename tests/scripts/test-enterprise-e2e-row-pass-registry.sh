#!/usr/bin/env bash
# Tests for install-version row pass registry (enterprise E2E matrix).
set -euo pipefail

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export SB_ROOT="$TMP"
export SB_E2E_LIVE_RUNTIME=claude
mkdir -p "$TMP/hooks" "$TMP/.planning/enterprise-e2e"
printf '{"version":"0.48.9-test"}\n' >"$TMP/package.json"
printf '{}\n' >"$TMP/hooks/hooks.json"
git -C "$TMP" init -q
git -C "$TMP" config user.email "e2e@test.local"
git -C "$TMP" config user.name "e2e"
git -C "$TMP" add -A
git -C "$TMP" commit -q -m "init"

# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"
# shellcheck source=scripts/enterprise-e2e/lib/core.sh
source "${REPO_ROOT}/scripts/enterprise-e2e/lib/core.sh"

fp="$(enterprise_e2e_install_fingerprint)"
[[ "$fp" == claude@* ]] && pass "install fingerprint has host prefix" || fail "install fingerprint host prefix"

enterprise_e2e_row_pass_registry_record 3 ".e2e-row3.log" true "test"
enterprise_e2e_row_pass_registry_has_pass 3 && pass "registry has row 3 pass" \
  || fail "registry has row 3 pass"
enterprise_e2e_row_pass_registry_has_pass 4 && fail "row 4 not registered" \
  || pass "row 4 not registered"

enterprise_e2e_row_pass_registry_should_skip 3 && pass "should skip row 3" \
  || fail "should skip row 3"
export SB_E2E_MATRIX_FORCE=1
enterprise_e2e_row_pass_registry_should_skip 3 && pass "FORCE=1 does not bypass registry" \
  || fail "FORCE=1 does not bypass registry"
unset SB_E2E_MATRIX_FORCE
export SB_E2E_MATRIX_FORCE_ALL=1
enterprise_e2e_row_pass_registry_should_skip 3 && fail "FORCE_ALL bypasses registry" \
  || pass "FORCE_ALL bypasses registry"
unset SB_E2E_MATRIX_FORCE_ALL

enterprise_e2e_matrix_should_skip_row_at_version 3 && pass "matrix skip via registry" \
  || fail "matrix skip via registry"

assert_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — missing [$needle]"
  fi
}

assert_contains "matrix ROW_ALREADY_PASSED_SAME_INSTALL" \
  "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" \
  "ROW_ALREADY_PASSED_SAME_INSTALL"

assert_contains "matrix FAIL_ON_SKIP excludes install pass" \
  "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh" \
  "INSTALL_PASS_SKIP_ROWS"

assert_contains "strict-clean checks registry" \
  "${REPO_ROOT}/scripts/enterprise-e2e/strict-clean-check.sh" \
  "enterprise_e2e_row_pass_registry_pass_count"

assert_contains "methodology documents registry" \
  "${REPO_ROOT}/docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md" \
  "Install-version row pass registry"

reg="${REPO_ROOT}/.planning/enterprise-e2e/.row-pass-registry.json"
[[ -f "$reg" ]] && pass "seed registry exists" || fail "seed registry exists"
if jq -e '.installs["claude@30558b37c1ac+9a58159041c7"].rows["1"]' "$reg" >/dev/null 2>&1; then
  pass "seed registry has row 1 @ 30558b37"
else
  fail "seed registry has row 1 @ 30558b37"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

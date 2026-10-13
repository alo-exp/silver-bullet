#!/usr/bin/env bash
# Structural tests for Round 9 Gate 3 one-command driver.
set -euo pipefail

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_executable() {
  [[ -x "$1" ]] && pass "$2" || fail "$2 — not executable: $1"
}

assert_file_exists() {
  [[ -f "$1" ]] && pass "$2" || fail "$2 — missing $1"
}

DRIVER="${REPO_ROOT}/scripts/enterprise-e2e/round9-gate3-driver.sh"
RESOLVE="${REPO_ROOT}/scripts/lib/enterprise-e2e-sb-root-resolve.sh"
MIGRATE="${REPO_ROOT}/scripts/enterprise-e2e/registry-migrate-install.sh"

assert_executable "$DRIVER" "round9-gate3-driver.sh executable"
assert_executable "$MIGRATE" "registry-migrate-install.sh executable"
assert_file_exists "$RESOLVE" "enterprise-e2e-sb-root-resolve.sh exists"

if bash -n "$DRIVER" 2>/dev/null; then
  pass "round9-gate3-driver.sh bash -n"
else
  fail "round9-gate3-driver.sh bash -n"
fi

# shellcheck source=scripts/lib/enterprise-e2e-sb-root-resolve.sh
source "$RESOLVE"
resolved="$(SB_E2E_MAIN_REPO="$REPO_ROOT" enterprise_e2e_resolve_sb_root)"
if [[ "$resolved" == "$REPO_ROOT" ]]; then
  pass "resolve_sb_root returns main repo"
else
  fail "resolve_sb_root expected $REPO_ROOT got $resolved"
fi

if RTK_DISABLED=1 bash "$DRIVER" --help >/dev/null 2>&1; then
  pass "round9-gate3-driver --help"
else
  fail "round9-gate3-driver --help"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

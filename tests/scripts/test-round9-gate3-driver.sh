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

# Default fixture path: with SB_TEST_ENTERPRISE_APP_ROOT unset it is <MAIN/../..>/enterprise-grade-test-app-round9-claude.
# A temp copy of the harness is nested two levels down so MAIN/../.. is a directory this test controls.
LAYOUT="$(mktemp -d)"
trap 'rm -rf "$LAYOUT"' EXIT
H="$LAYOUT/outer/inner/harness"
mkdir -p "$H/scripts/enterprise-e2e" "$H/scripts/lib" "$H/tests/live" "$H/hooks" "$H/.git" "$H/.planning/enterprise-e2e"
cp -R "$REPO_ROOT"/scripts/enterprise-e2e/. "$H/scripts/enterprise-e2e/"
cp "$REPO_ROOT"/scripts/lib/*.sh "$H/scripts/lib/"
ln -s "$REPO_ROOT/tests/live/lib" "$H/tests/live/lib"
ln -s "$REPO_ROOT/hooks/lib" "$H/hooks/lib"
touch "$H/scripts/run-enterprise-e2e-live-test.sh" "$H/.planning/enterprise-e2e/ROUND-9-LEDGER.md"
want_fixture="$LAYOUT/outer/enterprise-grade-test-app-round9-claude"
rc=0
out="$(env -u SB_TEST_ENTERPRISE_APP_ROOT -u SB_ROOT -u SB_E2E_MAIN_REPO -u SB_E2E_SB_ROOT_CANDIDATES RTK_DISABLED=1 \
  bash "$H/scripts/enterprise-e2e/round9-gate3-driver.sh" --preflight-only 2>&1)" || rc=$?
if [[ "$rc" -ne 0 ]] && grep -qxF "  fixture=${want_fixture}" <<<"$out" \
  && grep -qF "PREFLIGHT FAIL: fixture missing: ${want_fixture} " <<<"$out"; then
  pass "default fixture resolves to <MAIN/../..>/enterprise-grade-test-app-round9-claude"
else
  fail "default fixture expected ${want_fixture} (rc=$rc): $out"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
# shellcheck source=hooks/lib/branch-scope.sh
source "$REPO_ROOT/hooks/lib/branch-scope.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SILVER_BULLET_BRANCH_FILE="$TMP/branch"

echo "=== branch-scope.sh tests ==="

sb_branch_scope_write "feature-a" "/repo/main"
sb_branch_scope_read || fail "read after write"
if [[ "$SB_BRANCH_SCOPE_STORED_BRANCH" == "feature-a" && "$SB_BRANCH_SCOPE_STORED_TOPLEVEL" == "/repo/main" ]]; then
  pass "write/read branch + toplevel"
else
  fail "write/read branch + toplevel"
fi

if sb_branch_scope_mismatch "feature-a" "/repo/worktree-a"; then
  pass "worktree toplevel mismatch detected"
else
  fail "worktree toplevel mismatch detected"
fi

if ! sb_branch_scope_mismatch "feature-a" "/repo/main"; then
  pass "same scope no mismatch"
else
  fail "same scope no mismatch"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1

#!/usr/bin/env bash
# Regression: runtime hook bridges must fail-open on unexpected errors (R1-L01).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

assert_trap_present() {
  local label="$1" file="$2"
  if grep -q "trap 'exit 0' ERR" "$file"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label — missing trap 'exit 0' ERR in $file"
    FAIL=$((FAIL + 1))
  fi
}

assert_trap_present "kay bridge ERR trap" "${REPO_ROOT}/hooks/kay-project-hook-bridge.sh"
assert_trap_present "cursor bridge ERR trap" "${REPO_ROOT}/hooks/cursor-hook-bridge.sh"
assert_trap_present "codex adapter ERR trap" "${REPO_ROOT}/hooks/codex-hook-adapter.sh"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]

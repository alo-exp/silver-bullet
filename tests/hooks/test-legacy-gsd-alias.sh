#!/usr/bin/env bash
# Tests for hooks/lib/legacy-gsd-alias.sh (L-03).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/legacy-gsd-alias.sh"
PASS=0
FAIL=0

# shellcheck source=/dev/null
source "$LIB"

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_eq "gsd:plan-phase -> silver-plan" "silver-plan" "$(sb_legacy_gsd_alias_normalize 'gsd:plan-phase')"
assert_eq "gsd-fast -> silver-fast" "silver-fast" "$(sb_legacy_gsd_alias_normalize 'gsd-fast')"
assert_eq "silver:ship -> silver-ship" "silver-ship" "$(sb_legacy_gsd_alias_normalize 'silver:ship')"
assert_eq "gsd-complete-milestone -> silver-release" "silver-release" "$(sb_legacy_gsd_alias_normalize 'gsd-complete-milestone')"
assert_eq "silver-plan passthrough" "silver-plan" "$(sb_legacy_gsd_alias_normalize 'silver-plan')"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

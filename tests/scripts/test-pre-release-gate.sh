#!/usr/bin/env bash
# Smoke tests for scripts/pre-release-gate.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/scripts/pre-release-gate.sh"
PASS=0
FAIL=0

assert_pass() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

[[ -x "$GATE" ]] || chmod +x "$GATE"

assert_pass "skip env exits 0" \
  env SB_SKIP_PRE_RELEASE_GATE=1 bash "$GATE"

assert_pass "gate script is executable" test -x "$GATE"

grep -q 'run-all-tests.sh' "$GATE"
assert_pass "gate invokes run-all-tests.sh" test $? -eq 0

grep -q 'v0.51.0' "$GATE"
assert_pass "gate documents v0.51.0 counterexample" test $? -eq 0

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

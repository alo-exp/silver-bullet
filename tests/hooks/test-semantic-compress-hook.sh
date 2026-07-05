#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then echo "PASS: $desc"; (( PASS++ )) || true
  else echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true; fi
}

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/semantic-compress.sh"

# Test 1: non-phase skill → no output, exit 0
result=$(printf '{"tool_input":{"skill":"superpowers:brainstorming"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "non-phase skill: no output" "" "$result"

# Test 2: silver:execute → hook delegates (no .planning/ = no output)
result=$(printf '{"tool_input":{"skill":"silver:execute"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "silver:execute without planning: no output" "" "$result"

# Test 3: silver:plan → same
result=$(printf '{"tool_input":{"skill":"silver:plan"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "silver:plan without planning: no output" "" "$result"

# Test 4: silver:context → same
result=$(printf '{"tool_input":{"skill":"silver:context"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "silver:context without planning: no output" "" "$result"

# Test 5: silver:deep-research → same
result=$(printf '{"tool_input":{"skill":"silver:deep-research"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "silver:deep-research without planning: no output" "" "$result"

# Test 6: hyphenated silver-execute → same
result=$(printf '{"tool_input":{"skill":"silver-execute"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "silver-execute without planning: no output" "" "$result"

# Test 7: hyphenated silver-plan → same
result=$(printf '{"tool_input":{"skill":"silver-plan"}}' | "$HOOK" 2>/dev/null || true)
assert_eq "silver-plan without planning: no output" "" "$result"

# Test 8: missing skill field → no output, no crash
result=$(printf '{"tool_input":{}}' | "$HOOK" 2>/dev/null || true)
assert_eq "missing skill field: no output" "" "$result"

# Test 9: empty stdin → no output, no crash
result=$(printf '' | "$HOOK" 2>/dev/null || true)
assert_eq "empty stdin: no output" "" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]

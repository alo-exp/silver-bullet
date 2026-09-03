#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"; (( PASS++ )) || true
  else
    echo "FAIL: $desc"; echo "  expected: [$expected]"; echo "  actual:   [$actual]"; (( FAIL++ )) || true
  fi
}

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/extract-phase-goal.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Test 1: no .planning/ directory
result=$(cd "$TMP" && "$SCRIPT")
assert_eq "no planning dir returns empty" "" "$result"

# Test 2: .planning/ exists but no phase files
mkdir -p "$TMP/.planning"
result=$(cd "$TMP" && "$SCRIPT")
assert_eq "empty planning dir returns empty" "" "$result"

# Test 3: CONTEXT.md with heading
echo "# Implement login validation" > "$TMP/.planning/phase1-CONTEXT.md"
result=$(cd "$TMP" && "$SCRIPT")
assert_eq "extracts heading from CONTEXT.md" "Implement login validation" "$result"

# Test 3b: CONTEXT.md with heading that has trailing whitespace
rm "$TMP/.planning/phase1-CONTEXT.md" 2>/dev/null || true
printf '# Implement login validation   \n' > "$TMP/.planning/phase1-CONTEXT.md"
result=$(cd "$TMP" && "$SCRIPT")
assert_eq "strips trailing whitespace from heading" "Implement login validation" "$result"
rm "$TMP/.planning/phase1-CONTEXT.md" 2>/dev/null || true

# Test 4: PLAN.md without heading (first non-empty line)
rm "$TMP/.planning/phase1-CONTEXT.md" 2>/dev/null || true
printf 'Implement auth middleware\nSome details here\n' > "$TMP/.planning/phase1-PLAN.md"
result=$(cd "$TMP" && "$SCRIPT")
assert_eq "extracts first line from PLAN.md" "Implement auth middleware" "$result"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]

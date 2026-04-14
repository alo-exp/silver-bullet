#!/usr/bin/env bash
# Tests for hooks/spec-floor-check.sh
# Tests spec floor enforcement for gsd-plan-phase (hard block) and gsd-fast/gsd-quick (advisory)

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/spec-floor-check.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"

cleanup_all() { true; }
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/.planning"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

run_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== spec-floor-check.sh tests ==="

# Test 1: Unrelated command passes silently
echo "--- Group 1: Command filtering ---"
setup
out=$(run_hook "ls -la")
assert_passes "unrelated command passes silently" "$out"
teardown

setup
out=$(run_hook "git commit -m 'test'")
assert_passes "git commit passes silently" "$out"
teardown

# Test 2: gsd-plan-phase blocked when no SPEC.md
echo "--- Group 2: gsd-plan-phase hard block ---"
setup
out=$(run_hook "gsd-plan-phase")
assert_blocks "gsd-plan-phase blocked when no SPEC.md" "$out"
assert_contains "block message contains SPEC FLOOR VIOLATION" "$out" "SPEC FLOOR VIOLATION"
assert_contains "block uses permissionDecision deny" "$out" "permissionDecision"
teardown

# Test 3: gsd-plan-phase blocked when SPEC.md missing Overview section
echo "--- Group 3: Incomplete SPEC.md ---"
setup
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
spec-version: 1.0

## Acceptance Criteria
- [ ] Feature works
EOF
out=$(run_hook "gsd-plan-phase")
assert_blocks "gsd-plan-phase blocked when SPEC.md missing ## Overview" "$out"
assert_contains "block mentions missing section" "$out" "SPEC FLOOR VIOLATION"
teardown

# Test 4: gsd-plan-phase blocked when SPEC.md missing Acceptance Criteria
setup
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
spec-version: 1.0

## Overview
This is the overview.
EOF
out=$(run_hook "gsd-plan-phase")
assert_blocks "gsd-plan-phase blocked when SPEC.md missing ## Acceptance Criteria" "$out"
assert_contains "block mentions missing section" "$out" "SPEC FLOOR VIOLATION"
teardown

# Test 5: gsd-plan-phase passes when SPEC.md has both required sections
echo "--- Group 4: Valid SPEC.md ---"
setup
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
spec-version: 1.0

## Overview
This is the overview.

## Acceptance Criteria
- [ ] Feature works
EOF
out=$(run_hook "gsd-plan-phase")
assert_passes "gsd-plan-phase passes with valid SPEC.md" "$out"
teardown

# Test 6: gsd-fast without SPEC.md — advisory only, NOT blocked
echo "--- Group 5: gsd-fast advisory ---"
setup
out=$(run_hook "gsd-fast")
assert_passes "gsd-fast NOT blocked when no SPEC.md (advisory only)" "$out"
assert_contains "output contains ADVISORY warning" "$out" "ADVISORY"
teardown

# Test 7: gsd-quick without SPEC.md — advisory only, NOT blocked
setup
out=$(run_hook "gsd-quick")
assert_passes "gsd-quick NOT blocked when no SPEC.md (advisory only)" "$out"
assert_contains "output contains ADVISORY warning" "$out" "ADVISORY"
teardown

# ── WORKFLOW.md advisory mode tests ──────────────────────────────────────────
echo ""
echo "=== WORKFLOW.md advisory mode ==="

# WF1: WORKFLOW.md with FLOW 4 excluded -> advisory (no block)
echo "--- WF1: FLOW 4 excluded -> advisory ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Composition
Paths: 0 → 1 → 5 → 7 → 11 → 13

## Flow Log
| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 1 | ORIENT | complete |
| 5 | PLAN | complete |
WFEOF
# FLOW 4 (SPECIFY) not in composition -> spec floor should be advisory
out=$(run_hook "gsd-plan-phase")
# Should NOT block (advisory mode)
if echo "$out" | grep -q '"exitCode":1\|BLOCK\|HARD STOP'; then
  FAIL=$((FAIL + 1)); printf 'FAIL: WF1: FLOW 4 excluded should be advisory\n'
else
  PASS=$((PASS + 1)); printf 'PASS: WF1: FLOW 4 excluded -> advisory\n'
fi
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

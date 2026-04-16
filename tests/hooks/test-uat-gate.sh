#!/usr/bin/env bash
# Tests for hooks/uat-gate.sh
# Tests UAT gate enforcement for gsd-complete-milestone skill

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/uat-gate.sh"
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
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
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
echo "=== uat-gate.sh tests ==="

# Test 1: Non-gsd-complete-milestone skill passes silently
echo "--- Group 1: Skill filtering ---"
setup
out=$(run_hook "silver-quality-gates")
assert_passes "non-gsd-complete-milestone skill passes silently" "$out"
teardown

setup
out=$(run_hook "code-review")
assert_passes "code-review skill passes silently" "$out"
teardown

# Test 2: gsd-complete-milestone blocked when UAT.md missing
echo "--- Group 2: UAT.md existence check ---"
setup
out=$(run_hook "gsd-complete-milestone")
assert_blocks "gsd-complete-milestone blocked when UAT.md missing" "$out"
assert_contains "block message contains UAT GATE" "$out" "UAT GATE"
assert_contains "block uses permissionDecision deny" "$out" "permissionDecision"
teardown

# Test 3: gsd-complete-milestone blocked when UAT.md has FAIL results
echo "--- Group 3: FAIL results check ---"
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Checklist

| ID | Criterion | Result |
|----|-----------|--------|
| 1  | Login works | PASS |
| 2  | Logout works | FAIL |
EOF
out=$(run_hook "gsd-complete-milestone")
assert_blocks "gsd-complete-milestone blocked with FAIL results" "$out"
assert_contains "block message mentions FAIL" "$out" "FAIL"
teardown

# Test 4: gsd-complete-milestone passes when UAT.md has only PASS results
echo "--- Group 4: All PASS ---"
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Checklist

| ID | Criterion | Result |
|----|-----------|--------|
| 1  | Login works | PASS |
| 2  | Logout works | PASS |
EOF
out=$(run_hook "gsd-complete-milestone")
assert_passes "gsd-complete-milestone passes with all PASS results" "$out"
teardown

# Test 5: gsd-complete-milestone with NOT-RUN — advisory only, not blocked
echo "--- Group 5: NOT-RUN advisory ---"
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Checklist

| ID | Criterion | Result |
|----|-----------|--------|
| 1  | Login works | PASS |
| 2  | Optional feature | NOT-RUN |
EOF
out=$(run_hook "gsd-complete-milestone")
assert_passes "gsd-complete-milestone NOT blocked with NOT-RUN (advisory only)" "$out"
assert_contains "output mentions NOT-RUN advisory" "$out" "NOT-RUN"
teardown

# Test 6: Spec version mismatch — blocked
echo "--- Group 6: Spec version mismatch ---"
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Checklist

| ID | Criterion | Result |
|----|-----------|--------|
| 1  | Works | PASS |
EOF
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
spec-version: 2.0
# Spec
EOF
out=$(run_hook "gsd-complete-milestone")
assert_blocks "gsd-complete-milestone blocked when spec version mismatches" "$out"
assert_contains "block mentions version mismatch" "$out" "v1.0"
teardown

# Test 7: gsd:complete-milestone (colon variant) also triggers the gate
echo "--- Group 7: Colon variant ---"
setup
out=$(run_hook "gsd:complete-milestone")
assert_blocks "gsd:complete-milestone (colon form) also blocked when UAT.md missing" "$out"
teardown

# Test 8: Summary table with FAIL column header — must NOT block
echo "--- Group 8: Summary table FAIL header (HOOK-01) ---"
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Summary

| # | Criterion | PASS | FAIL | NOT-RUN | Total |
|----|-----------|------|------|---------|-------|
| 1  | Login     | 3    | 0    | 0       | 3     |
| 2  | Logout    | 2    | 0    | 1       | 3     |
EOF
out=$(run_hook "gsd-complete-milestone")
assert_passes "HOOK-01: FAIL in header row only — must NOT block" "$out"
teardown

# Test 9: Summary table with FAIL header AND FAIL data row — must block
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Results

| # | Criterion | PASS | FAIL | NOT-RUN | Total |
|----|-----------|------|------|---------|-------|
| 1  | Login     | 3    | 0    | 0       | 3     |

| ID | Criterion | Result |
|----|-----------|--------|
| 1  | Login works | PASS |
| 2  | Logout works | FAIL |
EOF
out=$(run_hook "gsd-complete-milestone")
assert_blocks "HOOK-01: FAIL header + FAIL data row — must block" "$out"
teardown

# Test 10: Summary table header with Result column — not blocked
setup
cat > "$TMPDIR_TEST/.planning/UAT.md" << 'EOF'
spec-version: 1.0
# UAT Summary

| Status | Result | PASS | FAIL |
|--------|--------|------|------|
| Done   | OK     | 5    | 0    |
EOF
out=$(run_hook "gsd-complete-milestone")
assert_passes "HOOK-01: header row with Status/Result + FAIL — must NOT block" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

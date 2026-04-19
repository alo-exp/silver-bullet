#!/usr/bin/env bash
set -euo pipefail
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/ci-status-check.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

# The hook hardcodes trivial_file to ${HOME}/.claude/.silver-bullet/trivial
TRIVIAL_FILE="${SB_TEST_DIR}/trivial"

cleanup_all() { rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" "$TRIVIAL_FILE"; }
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  # Create a minimal .silver-bullet.json so the hook recognises this as a SB project
  cat > "${TMPDIR_TEST}/.silver-bullet.json" << EOF
{
  "project": {},
  "state": { "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" "$TRIVIAL_FILE"
}

run_hook() {
  local cmd="$1"
  local gh_output="$2"
  local input
  input=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | GH_STATUS_OVERRIDE="$gh_output" bash "$HOOK" 2>/dev/null )
}

run_hook_no_project() {
  local cmd="$1"
  local gh_output="$2"
  # Run from a temp dir with NO .silver-bullet.json (non-GSD project)
  local bare_dir
  bare_dir=$(mktemp -d)
  local out
  out=$( cd "$bare_dir" && printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" \
    | GH_STATUS_OVERRIDE="$gh_output" bash "$HOOK" 2>/dev/null) || true
  rm -rf "$bare_dir"
  printf '%s' "$out"
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'; then
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

echo "=== ci-status-check.sh tests ==="

# Test 1: git commit + failed CI — must emit warning (within SB project)
echo "--- Group 1: CI status checks ---"
setup
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_contains "failed CI emits CI warning" "$out" "CI"
teardown

# Test 2: git commit + passing CI — must be silent
setup
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"success"}')
assert_passes "passing CI is silent" "$out"
teardown

# Test 3: unrelated command + failed CI — must be silent (no command match)
setup
out=$(run_hook "npm install" '{"status":"completed","conclusion":"failure"}')
assert_passes "unrelated command ignored even with failed CI" "$out"
teardown

# Test 4: non-GSD project — must exit silently even with failed CI
echo "--- Group 2: Non-GSD project guard ---"
out=$(run_hook_no_project "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_passes "non-GSD project: hook exits silently despite failed CI" "$out"

# Test 5: trivial bypass — must exit silently
echo "--- Group 3: Trivial bypass ---"
setup
touch "$TRIVIAL_FILE"
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_passes "trivial bypass suppresses CI check" "$out"
teardown

# Test 6: CI failure message includes ci-red-override escape instruction (HOOK-03)
echo "--- Group 4: Escape instruction in CI failure message ---"
setup
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_contains "HOOK-03: CI failure message includes ci-red-override escape instruction" "$out" "touch ~/.claude/.silver-bullet/ci-red-override"
teardown

# Test 7: CI cancelled message also includes ci-red-override escape instruction
setup
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"cancelled"}')
assert_contains "HOOK-03: CI cancelled message includes ci-red-override escape instruction" "$out" "touch ~/.claude/.silver-bullet/ci-red-override"
teardown

# Test 8: trivial file as CI-red override emits deprecation warning (backward compat)
echo "--- Group 5: Backward-compat trivial CI-red override deprecation ---"
setup
touch "$TRIVIAL_FILE"
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_contains "trivial-as-CI-override emits deprecation notice" "$out" "deprecation"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

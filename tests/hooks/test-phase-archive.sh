#!/usr/bin/env bash
# Tests for hooks/phase-archive.sh
# Tests archiving of phase directories before any `phases clear` command

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK_HELPERS="$(cd "$(dirname "$0")" && pwd)/helpers/common.sh"
if [[ -f "$HOOK_HELPERS" ]]; then
  # shellcheck source=helpers/common.sh
  source "$HOOK_HELPERS"
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/phase-archive.sh"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() { true; }
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  hook_test_stamp_sb_scaffold "$TMPDIR_TEST"
  git -C "$TMPDIR_TEST" init -q
  git -C "$TMPDIR_TEST" config user.email "test@test.com"
  git -C "$TMPDIR_TEST" config user.name "Test"
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
echo "=== phase-archive.sh tests ==="

# Test 1: Unrelated command passes silently
echo "--- Group 1: Command filtering ---"
setup
out=$(run_hook "ls -la")
assert_passes "unrelated command passes silently" "$out"
teardown

# Test 2: Non-phases command passes silently
setup
out=$(run_hook "npm run build")
assert_passes "non-phases command passes silently" "$out"
teardown

# Test 3: phases clear with no PROJECT.md exits silently
echo "--- Group 2: PROJECT.md handling ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
out=$(run_hook "silver-bullet phases clear")
assert_passes "phases clear without PROJECT.md passes silently" "$out"
teardown

# Test 4: phases clear with PROJECT.md and phases dir — archives
setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
echo "dummy file" > "$TMPDIR_TEST/.planning/phases/01-test/plan.md"
cat > "$TMPDIR_TEST/.planning/PROJECT.md" << 'EOF'
# Project
Current Milestone: v1.0
EOF
out=$(run_hook "silver-bullet phases clear")
assert_passes "phases clear with valid setup passes" "$out"
assert_contains "archive message contains 'archive'" "$out" "archive"
# Verify the archive directory was actually created
if [[ -d "$TMPDIR_TEST/.planning/archive/v1.0/01-test" ]]; then
  echo "  ✅ archive directory created correctly"
  PASS=$((PASS + 1))
else
  echo "  ❌ archive directory not created — expected .planning/archive/v1.0/01-test"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 5: phases clear when archive already exists — skips with message
echo "--- Group 3: Idempotency ---"
setup
mkdir -p "$TMPDIR_TEST/.planning/phases/01-test"
echo "dummy" > "$TMPDIR_TEST/.planning/phases/01-test/plan.md"
cat > "$TMPDIR_TEST/.planning/PROJECT.MD" << 'EOF'
# Project
Current Milestone: v1.0
EOF
cat > "$TMPDIR_TEST/.planning/PROJECT.md" << 'EOF'
# Project
Current Milestone: v1.0
EOF
# Pre-create archive with a file so it's non-empty
mkdir -p "$TMPDIR_TEST/.planning/archive/v1.0"
echo "existing" > "$TMPDIR_TEST/.planning/archive/v1.0/existing-file.txt"
out=$(run_hook "silver-bullet phases clear")
assert_passes "phases clear with existing archive passes" "$out"
assert_contains "output mentions already exists" "$out" "already exists"
teardown

# Test 6: phases clear with no phases directory — passes silently
echo "--- Group 4: Empty phases ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/PROJECT.md" << 'EOF'
# Project
Current Milestone: v2.0
EOF
out=$(run_hook "silver-bullet phases clear")
assert_passes "phases clear with no phases dir passes silently" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

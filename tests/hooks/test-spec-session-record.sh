#!/usr/bin/env bash
# Tests for hooks/spec-session-record.sh
# Tests spec session capture from SPEC.md at session start

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

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/spec-session-record.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
SPEC_SESSION_FILE="${SB_TEST_DIR}/spec-session"

cleanup_all() {
  rm -f "$SPEC_SESSION_FILE"
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  hook_test_stamp_sb_scaffold "$TMPDIR_TEST"
  mkdir -p "$TMPDIR_TEST/.planning"
  # Remove spec-session before each test for clean state
  rm -f "$SPEC_SESSION_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$SPEC_SESSION_FILE"
}

run_hook() {
  local input
  input='{"hook_event_name":"SessionStart"}'
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

assert_passes() {
  local label="$1"
  local output="$2"
  # passes = not blocked (no deny/block in output)
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

assert_session_contains() {
  local label="$1"
  local needle="$2"
  if grep -q "$needle" "$SPEC_SESSION_FILE" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$needle' in spec-session: $(cat "$SPEC_SESSION_FILE" 2>/dev/null || echo '(missing)')"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== spec-session-record.sh tests ==="

# Test 1: No SPEC.md — exits silently
echo "--- Group 1: No SPEC.md ---"
setup
out=$(run_hook)
assert_passes "no SPEC.md exits silently" "$out"
# Should produce no output (or empty)
if [[ -z "$out" ]]; then
  echo "  ✅ output is empty when no SPEC.md"
  PASS=$((PASS + 1))
else
  echo "  ❌ expected empty output when no SPEC.md, got: $out"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 2: SPEC.md with spec-version and jira-id — writes spec-session file
echo "--- Group 2: Full SPEC.md ---"
setup
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
spec-version: 1.2.0
jira-id: PROJ-42
# Spec Title

## Overview
Some overview.
EOF
out=$(run_hook)
assert_passes "SPEC.md with version and jira-id passes" "$out"
assert_contains "output includes SessionStart hookEventName" "$out" '"hookEventName":"SessionStart"'
assert_contains "output contains version" "$out" "v1.2.0"
assert_contains "output contains JIRA ID" "$out" "PROJ-42"
assert_session_contains "spec-session has spec-version" "spec-version=1.2.0"
assert_session_contains "spec-session has jira-id" "jira-id=PROJ-42"
teardown

# Test 3: SPEC.md with spec-version but no jira-id
echo "--- Group 3: Version without JIRA ID ---"
setup
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
spec-version: 2.0.1
# Spec Title

## Overview
Some overview.
EOF
out=$(run_hook)
assert_passes "SPEC.md with version but no jira-id passes" "$out"
assert_contains "output contains version" "$out" "v2.0.1"
assert_contains "output contains n/a for missing JIRA" "$out" "n/a"
assert_session_contains "spec-session has spec-version" "spec-version=2.0.1"
assert_session_contains "spec-session has empty jira-id" "jira-id="
teardown

# Test 4: SPEC.md with neither field — writes spec-session with unknown/empty
echo "--- Group 4: SPEC.md with no frontmatter fields ---"
setup
cat > "$TMPDIR_TEST/.planning/SPEC.md" << 'EOF'
# Spec Title

## Overview
Some overview without frontmatter.
EOF
out=$(run_hook)
assert_passes "SPEC.md with no frontmatter fields passes" "$out"
assert_contains "output contains 'unknown' for missing version" "$out" "unknown"
if [[ -f "$SPEC_SESSION_FILE" ]]; then
  echo "  ✅ spec-session file created even without frontmatter"
  PASS=$((PASS + 1))
else
  echo "  ❌ spec-session file not created"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

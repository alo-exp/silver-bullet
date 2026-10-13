#!/usr/bin/env bash
# Tests for hooks/pr-traceability.sh
# Tests early-exit paths of the PR traceability PostToolUse hook

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

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/pr-traceability.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
SPEC_SESSION_FILE="${SB_TEST_DIR}/spec-session"

cleanup_all() {
  rm -f "${SB_TEST_DIR}/spec-session-test-${TEST_RUN_ID}"
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  hook_test_stamp_sb_scaffold "$TMPDIR_TEST"
  # Remove any leftover spec-session from prior tests
  rm -f "$SPEC_SESSION_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$SPEC_SESSION_FILE"
}

run_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
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
echo "=== pr-traceability.sh tests ==="

# Test 1: Non-gh-pr-create command passes silently (exits early)
echo "--- Group 1: Command filtering ---"
setup
out=$(run_hook "git push origin main")
assert_passes "non-gh-pr-create command passes silently" "$out"
# Should be empty — hook exits 0 with no output for non-matching commands
if [[ -z "$out" ]]; then
  echo "  ✅ output empty for non-matching command"
  PASS=$((PASS + 1))
else
  echo "  ❌ expected empty output for non-matching command, got: $out"
  FAIL=$((FAIL + 1))
fi
teardown

setup
out=$(run_hook "ls -la")
assert_passes "ls command passes silently" "$out"
teardown

# Test 2: gh pr create without spec-session file — exits silently (no crash)
echo "--- Group 2: Missing spec-session ---"
setup
# Ensure no spec-session file exists
rm -f "$SPEC_SESSION_FILE"
# Override PATH to remove real gh (so hook hits gh-not-found or no-gh path)
out=$(PATH="" run_hook "gh pr create --title 'test'" 2>/dev/null || true)
# Hook should either: output gh-not-found advisory, or exit silently.
# Either way it must NOT crash (exit non-zero uncaught)
assert_passes "gh pr create without spec-session exits cleanly" "$out"
teardown

# Test 3: gh pr create with spec-session but no active PR — hook outputs traceability advisory
echo "--- Group 3: spec-session present, no open PR ---"
setup
# Create a spec-session so the hook gets past the spec-session guard.
# The hook will find gh (hardcoded fallback paths), attempt gh pr view, fail to find a PR,
# and output "Could not determine PR URL — traceability block skipped."
printf 'spec-version=1.0\njira-id=TEST-123\n' > "$SPEC_SESSION_FILE"
out=$(run_hook "gh pr create --title 'feat: my feature'" 2>/dev/null || true)
assert_passes "gh pr create with spec-session exits cleanly" "$out"
# The hook should output some traceability-related advisory (either no-gh or no-PR-URL message)
if printf '%s' "$out" | grep -qE 'gh CLI not found|Could not determine PR URL|traceability'; then
  echo "  ✅ output contains expected traceability advisory"
  PASS=$((PASS + 1))
else
  echo "  ❌ expected traceability advisory, got: $out"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

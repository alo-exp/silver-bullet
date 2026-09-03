#!/usr/bin/env bash
# Tests for hooks/instruction-file-guard.sh
# Verifies Silver Bullet blocks synthesizing brand-new root CLAUDE.md / AGENTS.md
# in an active SB project, while allowing edits to existing files and staying
# inert outside SB projects.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/instruction-file-guard.sh"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/instruction-guard-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  cat > "${TMPDIR_TEST}/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "${TMPDIR_TEST}/.silver-bullet.json" <<EOF
{
  "project": { "name": "test" },
  "state": { "state_file": "${SB_TEST_DIR}/instruction-guard-${TEST_RUN_ID}" }
}
EOF
}

setup_non_sb() {
  TMPDIR_TEST=$(mktemp -d)
}

run_hook() {
  local tool_name="$1"
  local file_path="$2"
  local input
  input=$(jq -n --arg t "$tool_name" --arg f "$file_path" \
    '{hook_event_name:"PreToolUse", tool_name:$t, tool_input:{file_path:$f}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_apply_patch() {
  local patch="$1"
  local input
  input=$(jq -n --arg p "$patch" \
    '{hook_event_name:"PreToolUse", tool_name:"apply_patch", tool_input:{patch:$p}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"'
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

echo "=== instruction-file-guard.sh tests ==="

setup
out=$(run_hook "Write" "CLAUDE.md")
assert_blocks "Fresh root CLAUDE.md creation is blocked" "$out"

out=$(run_hook "Write" "AGENTS.md")
assert_blocks "Fresh root AGENTS.md creation is blocked" "$out"

out=$(run_hook_apply_patch "*** Begin Patch
*** Add File: AGENTS.md
+# Agent Instructions
*** End Patch")
assert_blocks "Fresh root AGENTS.md creation through apply_patch is blocked" "$out"

touch "${TMPDIR_TEST}/CLAUDE.md"
out=$(run_hook "Write" "CLAUDE.md")
assert_passes "Existing root CLAUDE.md may be updated" "$out"

setup_non_sb
out=$(run_hook "Write" "CLAUDE.md")
assert_passes "Non-SB repo stays inert" "$out"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
# Tests for hooks/trivial-file-guard.sh
# Verifies Codex cannot arm the legacy trivial bypass marker from tool calls.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/trivial-file-guard.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/trivial-guard-${TEST_RUN_ID}" 2>/dev/null || true
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
  "state": { "trivial_file": "${SB_TEST_DIR}/trivial-guard-${TEST_RUN_ID}" }
}
EOF
}

run_hook_edit() {
  local filepath="$1"
  local input
  input=$(jq -n --arg f "$filepath" '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old", new_string:"new"}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_bash() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:$c}}')
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

echo "=== trivial-file-guard.sh tests ==="

setup
trivial_path="${SB_TEST_DIR}/trivial-guard-${TEST_RUN_ID}"
out=$(run_hook_edit "$trivial_path")
assert_blocks "Edit to trivial marker is blocked" "$out"

out=$(run_hook_bash "touch $trivial_path")
assert_blocks "Bash touch to trivial marker is blocked" "$out"

out=$(run_hook_bash "rm -f $trivial_path")
assert_passes "Bash rm -f on trivial marker is allowed" "$out"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
# Tests for hooks/workflow-chain-guard.sh
# Verifies composed Silver Bullet workflows block implementation edits until
# the downstream dependency markers are actually recorded.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/workflow-chain-guard.sh"
WORKFLOWS_SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/workflows.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "$TMPDIR_TEST/.planning"
  mkdir -p "$TMPDIR_TEST/src"
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "state": { "state_file": "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}" }
}
EOF
  touch "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}"
}

teardown() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}" 2>/dev/null || true
}

start_workflow() {
  local composer="$1"
  local intent="$2"
  local flows="$3"
  ( cd "$TMPDIR_TEST" && bash "$WORKFLOWS_SCRIPT" start "$composer" "$intent" "$flows" >/dev/null )
}

write_state_markers() {
  local markers=("$@")
  : > "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}"
  for marker in "${markers[@]}"; do
    printf '%s\n' "$marker" >> "${SB_TEST_DIR}/workflow-chain-state-${TEST_RUN_ID}"
  done
}

run_hook_edit() {
  local file_path="$1"
  local input
  input=$(jq -n --arg f "$file_path" '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old", new_string:"new"}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_denied() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"|"decision"\s*:\s*"block"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== workflow-chain-guard.sh tests ==="

# Feature workflow: missing pre-execution SB+GSD markers should block implementation edits.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:feature" "feature gate test" "bootstrap,design,execute,verify"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:feature blocks without SB+GSD pre-execution markers" "$out"
write_state_markers silver-quality-gates gsd-discuss-phase gsd-plan-phase
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:feature passes after SB+GSD pre-execution markers exist" "$out"
teardown

# UI workflow: UI-specific pre-execution SB+GSD markers must be present.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:ui" "ui gate test" "orient,design,plan,execute,review,verify"
write_state_markers gsd-discuss-phase gsd-ui-phase gsd-plan-phase
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:ui blocks until UI pre-execution markers are present" "$out"
write_state_markers silver-quality-gates gsd-discuss-phase gsd-ui-phase gsd-plan-phase
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:ui passes after UI pre-execution markers exist" "$out"
teardown

# Research workflow: clarify marker is required.
setup
touch "$TMPDIR_TEST/src/app.js"
start_workflow "/silver:research" "research gate test" "clarify,research,hand-off"
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_blocks "silver:research blocks without clarify marker" "$out"
write_state_markers silver-clarify
out=$(run_hook_edit "$TMPDIR_TEST/src/app.js")
assert_passes "silver:research passes after clarify marker exists" "$out"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

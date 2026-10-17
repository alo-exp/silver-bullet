#!/usr/bin/env bash
# Tests for hooks/compression-marker-guard.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/hooks/compression-marker-guard.sh"
PASS=0
FAIL=0

run_hook() {
  local payload="$1"
  ( cd "$REPO_ROOT" && printf '%s' "$payload" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -n "$output" ]] && printf '%s' "$output" | grep -qE '"permissionDecision"\s*:\s*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
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
  if ! is_blocked "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

echo "compression-marker-guard tests"

payload_write_clean=$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:"/tmp/example.md",content:"---\nname: Example\n---\n\nBody text."}}')
assert_passes "clean Write passes" "$(run_hook "$payload_write_clean")"

payload_write_marker=$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:"/tmp/example.plan.md",content:"example.plan.md [120L]\n---\n... [lean-ctx: omitted 1 lines]\noverview: broken"}}')
assert_blocks "Write with lean-ctx marker blocked" "$(run_hook "$payload_write_marker")"

payload_edit_marker=$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"/tmp/example.md",old_string:"old",new_string:"... [lean-ctx: omitted 3 lines]"}}')
assert_blocks "Edit with lean-ctx marker blocked" "$(run_hook "$payload_edit_marker")"

payload_bash=$(jq -n '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"echo hi"}}')
assert_passes "Bash ignored" "$(run_hook "$payload_bash")"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

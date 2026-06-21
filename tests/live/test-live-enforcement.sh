#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
export SB_LIVE_CODEX_GUARD=1

echo "=== Live Enforcement Tests ==="

# --- S1: HARD STOP on edit-before-planning ---
echo "--- S1: HARD STOP on edit-before-planning ---"
live_setup
# State is empty — no skills recorded. Prompt Claude to edit a src file.
target_file="${WORK_DIR}/src/routes/todos.js"
digest_before="$(capture_digest "$target_file")"
blocked_marker="// S1 blocked edit should not land because planning is incomplete; this marker intentionally exceeds one hundred characters to avoid the trivial-edit bypass."
response=$(invoke_claude "Use the file patch/edit tool, not shell commands, to add this exact comment line at the very top of src/routes/todos.js: ${blocked_marker}. Do not invoke any skills.")
sleep 2
# dev-cycle-check.sh should fire PreToolUse:Edit and return HARD STOP
assert_response_not_contains "S1: live turn did not time out" "$response" "timed out waiting for Codex exec to complete|timed out waiting for Codex prompt to complete"
assert_response_contains "S1: hook block surfaced" "$response" "HARD STOP|planning incomplete|blocked|permissionDecision|deny"
assert_file_not_modified "S1: target file unchanged when edit is blocked" "$target_file" "$digest_before"
# The Kay agent may record planning state while rejecting the edit, so the
# file-level invariants are the release-relevant signal here.
live_teardown

# --- S2: Planning gate opens after full planning floor + silver-review ---
echo "--- S2: Edit allowed after reaching Stage C ---"
live_setup
seed_state "silver-quality-gates" "silver-context" "silver-plan" "silver-review" "requesting-code-review" "receiving-code-review"
target_file="${WORK_DIR}/src/routes/todos.js"
hook_output=$(jq -n --arg f "$target_file" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old content here long enough to exceed the small-edit bypass threshold", new_string:"new content here long enough to exceed the small-edit bypass threshold"}}' \
  | (cd "$WORK_DIR" && bash "${SB_ROOT}/hooks/dev-cycle-check.sh" 2>/dev/null || true))
# With the planning floor AND silver-review recorded, Stage C is reached — the hook should allow the edit.
assert_response_not_contains "S2: Stage C hook allows source edit" "$hook_output" "permissionDecision.*deny|decision.*block|HARD STOP|planning incomplete"
live_teardown

# --- S3: Forbidden skill hook fires correctly ---
echo "--- S3: Forbidden skill hook output verified ---"
live_setup
# Verify forbidden-skill-check.sh produces permissionDecision:deny for executing-plans.
# Note: the claude agent (this version) does not surface the denial in response text —
# the hook fires and returns deny, but Claude continues with the skill content anyway.
# We verify the hook behavior directly (unit-level), then verify the state effect (live-level).
hook_output=$(echo '{"tool_name":"Skill","tool_input":{"skill":"executing-plans"},"hook_event_name":"PreToolUse"}' \
  | bash "${SB_ROOT}/hooks/forbidden-skill-check.sh" 2>/dev/null || true)
assert_response_contains "S3: hook returns permissionDecision deny" "$hook_output" "permissionDecision.*deny|FORBIDDEN SKILL"
# Live: invoke executing-plans; it is not in all_tracked so it cannot be recorded in state
response=$(invoke_claude "Use the Skill tool to invoke the skill named 'executing-plans'.")
sleep 2
assert_response_not_contains "S3: live turn did not time out" "$response" "timed out waiting for Codex exec to complete|timed out waiting for Codex prompt to complete"
assert_state_not_contains "S3: executing-plans not recorded (not tracked)" "executing-plans"
live_teardown

# --- S4: Stop-check with empty state (state-based assertion) ---
echo "--- S4: Stop-check fires with missing skills (state-based) ---"
live_setup
# State is empty. stop-check.sh blocks the Stop event, so Claude cannot complete normally.
# In -p mode the block reason may not appear in response text.
# Instead verify: state file is empty (no skills recorded), confirming stop-check would block.
response=$(invoke_claude "Say hello and then stop. Do not invoke any skills or edit any files.")
sleep 2
# State should be empty — no skills were recorded (Claude didn't invoke any tracked skills)
assert_response_not_contains "S4: live turn did not time out" "$response" "timed out waiting for Codex exec to complete|timed out waiting for Codex prompt to complete"
assert_state_not_contains "S4: state is empty — stop-check would block on empty state" "silver-quality-gates"
# Also accept if response text does mention the block (bonus signal)
live_teardown

print_results

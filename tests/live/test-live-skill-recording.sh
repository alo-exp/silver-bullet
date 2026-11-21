#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
export SB_LIVE_CODEX_GUARD=1

echo "=== Live Skill Recording Tests ==="

# --- S5: record-skill hook correctly records tracked skills ---
echo "--- S5: record-skill hook records silver-quality-gates ---"
live_setup
live_hook_audit_enable
# In -p mode, Claude reads skill files via Read tool (not the Skill tool), so
# record-skill.sh PostToolUse:Skill hook does not fire automatically during a skill invocation.
# Instead, verify record-skill.sh works correctly at the unit level, then verify the
# state file mechanism used by dev-cycle-check.sh is correct (integration-level).

# Unit test: call record-skill.sh directly with a silver-quality-gates PostToolUse event
hook_out=$(cd "$WORK_DIR" && printf '{"tool_name":"Skill","tool_input":{"skill":"silver-quality-gates"},"hook_event_name":"PostToolUse"}' \
  | bash "${SB_ROOT}/hooks/record-skill.sh" 2>/dev/null || true)
assert_response_contains "S5: record-skill.sh outputs Skill recorded" "$hook_out" "Skill recorded|silver-quality-gates"

# Verify skill is now in state (hook wrote it)
assert_state_contains "S5: silver-quality-gates recorded in state after direct hook call" "silver-quality-gates"

# Integration test: with planning and review state, dev-cycle-check.sh allows edits to src files.
# Seeding the review markers keeps this scenario focused on the hook allow path
# instead of letting the prompt router turn a direct edit into an extra fast-path model turn.
# This verifies the full loop: state → hook reads state → enforcement decision
seed_state "silver-quality-gates" "silver-context" "silver-plan" "silver-review" "requesting-code-review" "receiving-code-review"
target_file="${WORK_DIR}/src/routes/todos.js"
hook_output=$(jq -n --arg f "$target_file" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old content here long enough to exceed the small-edit bypass threshold", new_string:"new content here long enough to exceed the small-edit bypass threshold"}}' \
  | (cd "$WORK_DIR" && SILVER_BULLET_HOOK_AUDIT_LOG="$LIVE_HOOK_AUDIT_FILE" bash "${SB_ROOT}/hooks/dev-cycle-check.sh" 2>/dev/null || true))
assert_hook_audit_entry "S5: state-driven hook records an allow for the source edit" "dev-cycle-check" "allow" 'review recorded|Planning verified|Implementation edits allowed' 5
assert_response_not_contains "S5: state-driven hook output carries no deny" "$hook_output" "permissionDecision.*deny|decision.*block|HARD STOP|planning incomplete"

live_teardown

# --- S6: compliance-status shows progress ---
echo "--- S6: compliance-status shows progress ---"
live_setup
seed_state "silver-quality-gates"
# compliance-status.sh answers a PostToolUse payload with the PLANNING n/m progress line. It is
# checked against the shipped hook directly: whether the agent echoes the line is not observable.
hook_output=$(cd "$WORK_DIR" && printf '{"tool_name":"Bash","tool_input":{"command":"echo hello"},"hook_event_name":"PostToolUse"}' \
  | bash "${SB_ROOT}/hooks/compliance-status.sh" 2>/dev/null || true)
assert_response_contains "S6: compliance-status reports the planning progress line" "$hook_output" "PLANNING [0-9]+/[0-9]+"
live_teardown

print_results

#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
export SB_LIVE_CODEX_GUARD=1

echo "=== Live Full Scenario Tests ==="

# --- S7: Session state initialized ---
echo "--- S7: Session initialization ---"
live_setup
# The SessionStart hook stamps <state dir>/session-start-time. Remove it first so only a real
# SessionStart inside the agent's turn can bring it back (the state directory itself is created by
# live_setup and proves nothing).
rm -f "${SB_TEST_DIR}/session-start-time"
response=$(invoke_claude_permissive "Say hello. What is 2+2?")
assert_response_not_contains "S7: live turn did not time out" "$response" "timed out waiting for Codex exec to complete|timed out waiting for Codex prompt to complete"
assert_file_contains "S7: SessionStart hook stamped session-start-time" "${SB_TEST_DIR}/session-start-time" "^[0-9]+$"
live_teardown

# --- S8: Abbreviated lifecycle (silver-quality-gates -> silver-review -> edit) ---
echo "--- S8: Abbreviated lifecycle ---"
live_setup
live_hook_audit_enable

# Step 1: record silver-quality-gates via hook directly (record-skill.sh PostToolUse:Skill
# does not fire in -p mode since Claude reads skill files via Read, not Skill tool)
echo "  S8.1: Recording silver-quality-gates via hook..."
(cd "$WORK_DIR" && printf '{"tool_name":"Skill","tool_input":{"skill":"silver-quality-gates"},"hook_event_name":"PostToolUse"}' \
  | bash "${SB_ROOT}/hooks/record-skill.sh" 2>/dev/null || true) >/dev/null
assert_state_contains "S8.1: silver-quality-gates recorded" "silver-quality-gates"

echo "  S8.2: Seeding planning floor and silver-review state..."
seed_state "silver-quality-gates" "silver-context" "silver-plan" "silver-review" "requesting-code-review" "receiving-code-review"
assert_state_contains "S8.2: silver-review in state" "silver-review"

# Step 3: verify edit gate (should allow at Stage C)
echo "  S8.3: Verifying edit gate at Stage C..."
target_file="${WORK_DIR}/src/routes/todos.js"
hook_output=$(jq -n --arg f "$target_file" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old content here long enough to exceed the small-edit bypass threshold", new_string:"new content here long enough to exceed the small-edit bypass threshold"}}' \
  | (cd "$WORK_DIR" && SILVER_BULLET_HOOK_AUDIT_LOG="$LIVE_HOOK_AUDIT_FILE" bash "${SB_ROOT}/hooks/dev-cycle-check.sh" 2>/dev/null || true))
assert_hook_audit_entry "S8.3: Stage C hook records an allow for the lifecycle edit" "dev-cycle-check" "allow" 'review recorded|Planning verified|Implementation edits allowed' 5
assert_response_not_contains "S8.3: Stage C hook output carries no deny" "$hook_output" "permissionDecision.*deny|decision.*block|HARD STOP|planning incomplete"

live_teardown

print_results

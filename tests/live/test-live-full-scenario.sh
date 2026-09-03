#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
export SB_LIVE_CODEX_GUARD=1

echo "=== Live Full Scenario Tests ==="

# --- S7: Session state initialized ---
echo "--- S7: Session initialization ---"
live_setup
response=$(invoke_claude_permissive "Say hello. What is 2+2?")
sleep 2
# session-start hook fires and creates state directory
assert_file_exists "S7: SB state directory exists" "$SB_TEST_DIR"
assert_response_contains "S7: response contains a greeting or answer" "$response" "Hello|hello|hi|4|four|2\+2|answer"
live_teardown

# --- S8: Abbreviated lifecycle (silver-quality-gates -> silver-review -> edit) ---
echo "--- S8: Abbreviated lifecycle ---"
live_setup

# Step 1: record silver-quality-gates via hook directly (record-skill.sh PostToolUse:Skill
# does not fire in -p mode since Claude reads skill files via Read, not Skill tool)
echo "  S8.1: Recording silver-quality-gates via hook..."
hook_out=$(cd "$WORK_DIR" && printf '{"tool_name":"Skill","tool_input":{"skill":"silver-quality-gates"},"hook_event_name":"PostToolUse"}' \
  | bash "${SB_ROOT}/hooks/record-skill.sh" 2>/dev/null || true)
assert_state_contains "S8.1: silver-quality-gates recorded" "silver-quality-gates"

echo "  S8.2: Seeding planning floor and silver-review state..."
seed_state "silver-quality-gates" "silver-context" "silver-plan" "silver-review" "requesting-code-review" "receiving-code-review"
assert_state_contains "S8.2: silver-review in state" "silver-review"

# Step 3: verify edit gate (should allow at Stage C)
echo "  S8.3: Verifying edit gate at Stage C..."
target_file="${WORK_DIR}/src/routes/todos.js"
hook_output=$(jq -n --arg f "$target_file" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old content here long enough to exceed the small-edit bypass threshold", new_string:"new content here long enough to exceed the small-edit bypass threshold"}}' \
  | (cd "$WORK_DIR" && bash "${SB_ROOT}/hooks/dev-cycle-check.sh" 2>/dev/null || true))
assert_response_not_contains "S8.3: Stage C hook allows lifecycle edit" "$hook_output" "permissionDecision.*deny|decision.*block|HARD STOP|planning incomplete"

live_teardown

print_results

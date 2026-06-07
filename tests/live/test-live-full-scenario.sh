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

# --- S8: Abbreviated lifecycle (silver-quality-gates -> gsd-code-review -> edit) ---
echo "--- S8: Abbreviated lifecycle ---"
live_setup

# Step 1: record silver-quality-gates via hook directly (record-skill.sh PostToolUse:Skill
# does not fire in -p mode since Claude reads skill files via Read, not Skill tool)
echo "  S8.1: Recording silver-quality-gates via hook..."
hook_out=$(cd "$WORK_DIR" && printf '{"tool_name":"Skill","tool_input":{"skill":"silver-quality-gates"},"hook_event_name":"PostToolUse"}' \
  | bash "${SB_ROOT}/hooks/record-skill.sh" 2>/dev/null || true)
assert_state_contains "S8.1: silver-quality-gates recorded" "silver-quality-gates"

# Step 2: seed the planning floor, gsd-code-review, and related review skills (saves cost vs real invocation)
echo "  S8.2: Seeding planning floor and gsd-code-review state..."
seed_state "silver-quality-gates" "gsd-discuss-phase" "gsd-plan-phase" "gsd-code-review" "requesting-code-review" "receiving-code-review"
assert_state_contains "S8.2: gsd-code-review in state" "gsd-code-review"

# Step 3: attempt edit (should succeed at Stage C)
echo "  S8.3: Attempting edit at Stage C..."
target_file="${WORK_DIR}/src/routes/todos.js"
digest_before="$(capture_digest "$target_file")"
comment_marker="// S8 lifecycle test ${TEST_RUN_ID}"
response3=$(invoke_claude_permissive "Use apply_patch to add this exact comment line at the very top of src/routes/todos.js: ${comment_marker}.")
sleep 2
assert_response_not_contains "S8.3: live turn did not time out" "$response3" "timed out waiting for Codex exec to complete|timed out waiting for Codex prompt to complete"
assert_file_changed "S8.3: target file modified at Stage C" "$target_file" "$digest_before"
assert_file_contains "S8.3: target file contains lifecycle comment" "$target_file" "S8 lifecycle test ${TEST_RUN_ID}"

live_teardown

print_results

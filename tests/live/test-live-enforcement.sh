#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
export SB_LIVE_CODEX_GUARD=1

echo "=== Live Enforcement Tests ==="

# Every assertion below needs a real hook decision: an audit entry written by the hook while the
# agent ran (S1) or by the shipped hook invoked with a real payload (S2, S3). A regex over the
# agent's reply, an empty hook output or an unchanged state file is never evidence (R14-11).

# --- S1: HARD STOP on edit-before-planning ---
echo "--- S1: HARD STOP on edit-before-planning ---"
live_setup
live_hook_audit_enable
# State is empty — no skills recorded. Prompt the agent to edit a src file.
target_file="${WORK_DIR}/src/routes/todos.js"
digest_before="$(capture_digest "$target_file")"
blocked_marker="// S1 blocked edit should not land because planning is incomplete; this marker intentionally exceeds one hundred characters to avoid the trivial-edit bypass."
response=$(invoke_claude "Use the file patch/edit tool, not shell commands, to add this exact comment line at the very top of src/routes/todos.js: ${blocked_marker}. Do not invoke any skills.")
assert_response_not_contains "S1: live turn did not time out" "$response" "timed out waiting for Codex exec to complete|timed out waiting for Codex prompt to complete"
assert_hook_audit_entry "S1: dev-cycle-check denied the edit during the live turn" "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete' 30
assert_file_not_modified "S1: target file unchanged when edit is blocked" "$target_file" "$digest_before"
live_teardown

# --- S2: Planning gate opens after full planning floor + silver-review ---
echo "--- S2: Edit allowed after reaching Stage C ---"
live_setup
live_hook_audit_enable
seed_state "silver-quality-gates" "silver-context" "silver-plan" "silver-review" "requesting-code-review" "receiving-code-review"
target_file="${WORK_DIR}/src/routes/todos.js"
hook_output=$(jq -n --arg f "$target_file" \
  '{hook_event_name:"PreToolUse", tool_name:"Edit", tool_input:{file_path:$f, old_string:"old content here long enough to exceed the small-edit bypass threshold", new_string:"new content here long enough to exceed the small-edit bypass threshold"}}' \
  | (cd "$WORK_DIR" && SILVER_BULLET_HOOK_AUDIT_LOG="$LIVE_HOOK_AUDIT_FILE" bash "${SB_ROOT}/hooks/dev-cycle-check.sh" 2>/dev/null || true))
# With the planning floor AND silver-review recorded, Stage C is reached: the hook must record an allow.
assert_hook_audit_entry "S2: Stage C hook records an allow for the source edit" "dev-cycle-check" "allow" 'review recorded|Planning verified|Implementation edits allowed' 5
assert_response_not_contains "S2: Stage C hook output carries no deny" "$hook_output" "permissionDecision.*deny|decision.*block|HARD STOP|planning incomplete"
live_teardown

# --- S3: Forbidden skill hook fires correctly ---
echo "--- S3: Forbidden skill hook output verified ---"
live_setup
# forbidden-skill-check.sh must answer a real PreToolUse:Skill payload for a forbidden skill with a
# well-formed deny. Delivery inside the agent session is not observable (the hook writes no audit
# entry and the agent does not surface the denial), so no live turn is run for it.
hook_output=$(echo '{"tool_name":"Skill","tool_input":{"skill":"executing-plans"},"hook_event_name":"PreToolUse"}' \
  | bash "${SB_ROOT}/hooks/forbidden-skill-check.sh" 2>/dev/null || true)
assert_hook_json_decision "S3: hook returns a well-formed permissionDecision deny" "$hook_output" "deny"
assert_response_contains "S3: deny names the forbidden skill" "$hook_output" "FORBIDDEN SKILL"
live_teardown

print_results

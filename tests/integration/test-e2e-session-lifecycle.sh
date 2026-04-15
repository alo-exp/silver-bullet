#!/usr/bin/env bash
# Integration test: E2E session lifecycle
# Tests session transitions and state management
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: E2E Session Lifecycle ==="

# Scenario 1: Session start creates infrastructure (no crash)
echo "--- Scenario 1: Session start ---"
integration_setup
write_default_config

out=$(run_session_start)
assert_allowed "S1.1: session-start exits 0 (no block)" "$out"

integration_teardown

# Scenario 2: Branch mismatch warning
echo "--- Scenario 2: Branch mismatch warning ---"
integration_setup
write_default_config

# Write a stored branch name that differs from current
echo "some-other-branch" > "${HOME}/.claude/.silver-bullet/branch"
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
# The hook emits a warning then continues — not a block for the mismatch itself.
# It will be blocked by Stage A (no planning), which means a block IS expected.
assert_blocked "S2.1: dev-cycle-check runs (Stage A block still fires after branch warning)" "$out"

# Clean up branch file
rm -f "${HOME}/.claude/.silver-bullet/branch"

integration_teardown

# Scenario 3: Session reset (clear state file resets progress)
echo "--- Scenario 3: State reset clears enforcement ---"
integration_setup
write_default_config

# Record some skills
run_record_skill "silver-quality-gates" >/dev/null
run_record_skill "code-review" >/dev/null

# stop-check still blocks (not all skills)
out=$(run_stop_check "Stop")
assert_blocked "S3.1: stop-check blocks with partial skills" "$out"

# Clear state (simulate /compact reset)
> "$TMPSTATE"
out=$(run_stop_check "Stop")
assert_blocked "S3.2: stop-check blocks after state reset" "$out"

# Verify dev-cycle-check blocks again (planning gone)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S3.3: dev-cycle-check blocks after state reset" "$out"

integration_teardown

# Scenario 4: Timeout check fires without crashing
echo "--- Scenario 4: Timeout check graceful ---"
integration_setup
write_default_config

out=$(run_timeout_check)
assert_allowed "S4.1: timeout-check exits 0 (no block)" "$out"

integration_teardown

# Scenario 5: Prompt reminder fires and returns valid output
echo "--- Scenario 5: Prompt reminder ---"
integration_setup
write_default_config

out=$(run_prompt_reminder)
assert_allowed "S5.1: prompt-reminder exits 0 (no block)" "$out"

integration_teardown

# Scenario 6: Non-logic file bypass (css, md, etc.)
echo "--- Scenario 6: Non-logic file bypass ---"
integration_setup
write_default_config
# No planning skills recorded — enforcement active for logic files

# CSS file in src/ is bypassed
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/styles.css")
assert_allowed "S6.1: .css edit allowed (non-logic file)" "$out"

# Markdown file in src/ is bypassed
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/README.md")
assert_allowed "S6.2: .md edit allowed (non-logic file)" "$out"

# JSON file in src/ is bypassed in full-dev-cycle
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/config.json")
assert_allowed "S6.3: .json edit allowed in full-dev-cycle (non-logic)" "$out"

# JS file in src/ is NOT bypassed — must be blocked (no planning)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S6.4: .js edit blocked (logic file, no planning)" "$out"

integration_teardown

# Scenario 7: Small edit bypass
echo "--- Scenario 7: Small edit bypass ---"
integration_setup
write_default_config
# No planning — would normally block a large edit

# Short combined string (< 100 chars) => bypassed
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js" "a" "b")
assert_allowed "S7.1: small edit allowed (2 chars combined)" "$out"

# Long combined strings (> 100 chars) => blocked
long_old="This is old content that is definitely longer than fifty characters by quite a bit"
long_new="This is new content that is definitely longer than fifty characters by quite a bit"
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js" "$long_old" "$long_new")
assert_blocked "S7.2: large edit blocked (no planning, long strings)" "$out"

integration_teardown

print_results

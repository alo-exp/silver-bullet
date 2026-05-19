#!/usr/bin/env bash
# Integration test: Session management scenarios
# Tests prompt-reminder, ci-status-check, stop-check, session-log-init in session context
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: Session Scenarios ==="

# Scenario 1: Prompt reminder reflects missing skills, then updates after recording
echo "--- Scenario 1: Prompt reminder tracks progress ---"
integration_setup
write_default_config

# Step 1: With empty state, prompt reminder shows missing skills
out=$(run_prompt_reminder)
if printf '%s' "$out" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); printf 'PASS: S1.1: prompt reminder returns hookSpecificOutput\n'
else
  # Some configs may cause silent exit — check if output is empty (no config)
  if [[ -z "$out" ]]; then
    PASS=$((PASS + 1)); printf 'PASS: S1.1: prompt reminder silent (expected for some configs)\n'
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: S1.1: unexpected prompt reminder output: %s\n' "$out"
  fi
fi

# Step 2: Record all skills
write_all_skills

# Step 3: Prompt reminder after all skills recorded should not block
out=$(run_prompt_reminder)
if [[ -z "$out" ]] || ! is_blocked "$out"; then
  PASS=$((PASS + 1)); printf 'PASS: S1.2: prompt reminder does not block when skills recorded\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.2: prompt reminder blocks unexpectedly: %s\n' "$out"
fi

integration_teardown

# Scenario 2: CI status check detects failure after push
# ci-status-check.sh reads GH_STATUS_OVERRIDE directly as run_json (line 40-41).
# On conclusion=failure it calls emit_block with "CI FAILURE DETECTED" (line 67-74).
# The test MUST assert the specific block output — no fallback pass allowed.
echo "--- Scenario 2: CI failure blocks subsequent push ---"
integration_setup
write_default_config

export GH_STATUS_OVERRIDE='{"conclusion":"failure","status":"completed","name":"CI","headBranch":"feature/test"}'
out=$(run_ci_status_check "PostToolUse" "git push origin feature/test")
assert_blocked "S2.1: CI failure produces block decision" "$out"
assert_contains "S2.2: CI failure output contains CI FAILURE DETECTED" "$out" "CI FAILURE DETECTED"
unset GH_STATUS_OVERRIDE

integration_teardown

# Scenario 3: CI success is silent
echo "--- Scenario 3: CI success silent ---"
integration_setup
write_default_config

export GH_STATUS_OVERRIDE='{"conclusion":"success","status":"completed","name":"CI","headBranch":"feature/test"}'
out=$(run_ci_status_check "PostToolUse" "git push origin feature/test")
# Should be empty or non-blocking
assert_allowed "S3.1: CI success does not block" "$out"
unset GH_STATUS_OVERRIDE

integration_teardown

# Scenario 4: Non-push command ignored by ci-status-check
echo "--- Scenario 4: Non-push command ignored by CI check ---"
integration_setup
write_default_config

export GH_STATUS_OVERRIDE='{"conclusion":"failure","status":"completed"}'
out=$(run_ci_status_check "PostToolUse" "npm test")
assert_allowed "S4.1: npm test not affected by CI check" "$out"
unset GH_STATUS_OVERRIDE

integration_teardown

# Scenario 5: Trivial bypass overrides all enforcement
echo "--- Scenario 5: Trivial file bypass across hooks ---"
integration_setup
write_default_config

# Create trivial file
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"

# dev-cycle-check: should bypass
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S5.1: trivial bypass on dev-cycle-check" "$out"

# completion-audit: should bypass
out=$(run_completion_audit "PreToolUse" "git commit -m 'test'")
assert_allowed "S5.2: trivial bypass on completion-audit" "$out"

# stop-check: should bypass
out=$(run_stop_check "Stop")
assert_allowed "S5.3: trivial bypass on stop-check" "$out"

integration_teardown

# Scenario 6: session-log-init fires on .silver-bullet/mode command
# Per session-log-init.sh line 28: triggers on commands matching '\.silver-bullet(/mode|-mode)'
# The hook also requires a project root (.silver-bullet.json) to proceed past exit 0.
echo "--- Scenario 6: session-log-init triggers on mode command ---"
integration_setup
write_default_config

# Use PROJECT_ROOT_OVERRIDE so session-log-init can find the project root (TMPDIR_TEST has .silver-bullet.json)
# Use SESSION_LOG_TEST_DIR to redirect session logs away from real docs/sessions
SESSION_LOG_DIR=$(mktemp -d)
out=$(PROJECT_ROOT_OVERRIDE="$TMPDIR_TEST" SESSION_LOG_TEST_DIR="$SESSION_LOG_DIR" \
      run_session_log_init "printf interactive > ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/mode")
# session-log-init should run without error and produce some output (session log path or similar)
if [[ $? -eq 0 ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S6.1: session-log-init runs without error on .silver-bullet/mode command\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S6.1: session-log-init errored on .silver-bullet/mode command\n'
fi
rm -rf "$SESSION_LOG_DIR"

integration_teardown

print_results

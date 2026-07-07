#!/usr/bin/env bash
# E2E test: Full SDLC lifecycle simulation (tags feature on todo-app)
# Simulates all 20 SDLC steps in sequence across 8 scenarios
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== E2E: Full SDLC Lifecycle ==="

# Scenario 1: Session start and mode configuration
echo "--- Scenario 1: Session start and mode configuration ---"
integration_setup
write_default_config

out=$(run_session_start)
assert_allowed "S1.1: session-start exits without blocking" "$out"

out=$(run_prompt_reminder)
assert_allowed "S1.2: prompt-reminder fires on first user prompt" "$out"
assert_contains "S1.3: prompt-reminder returns hookSpecificOutput" "$out" "hookSpecificOutput"

# Before any skills: dev-cycle-check should block (Stage A)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.4: source edit blocked before planning" "$out"

integration_teardown

# Scenario 2: Planning phase — discuss, silver-quality-gates, plan
echo "--- Scenario 2: Planning phase ---"
integration_setup
write_default_config

# Record SB planning phase skills
run_record_skill "silver-context" >/dev/null
run_record_skill "silver-quality-gates" >/dev/null
run_record_skill "silver-plan" >/dev/null

# Compliance status should show planning progress
out=$(run_compliance_status)
assert_contains "S2.1: compliance shows planning progress" "$out" "PLANNING 3/3"

# Stage B allows implementation edits after planning; final delivery remains gated.
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S2.2: edit allowed at Stage B before silver-review" "$out"
assert_contains "S2.3: mentions code review remains required" "$out" "Code review"

out=$(run_compliance_status)
assert_contains "S2.4: lifecycle phases incrementing" "$out" "LIFECYCLE"

integration_teardown

# Scenario 3: Code review unlocks source editing
echo "--- Scenario 3: Code review unlocks source editing ---"
integration_setup
write_default_config

printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' > "$TMPSTATE"

# Still allowed before silver-review because implementation can continue.
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S3.1: edit allowed before silver-review" "$out"

# Record code-review
run_record_skill "silver-review" >/dev/null

# Now allowed at Stage C
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S3.2: edit allowed after silver-review (Stage C)" "$out"
assert_contains "S3.3: compliance shows REVIEW progress" "$(run_compliance_status)" "REVIEW 1/3"

integration_teardown

# Scenario 4: Execute phase — TDD, atomic commits allowed
echo "--- Scenario 4: Execute phase with atomic commits ---"
integration_setup
write_default_config

printf 'silver-quality-gates\nsilver-context\nsilver-plan\nsilver-review\n' > "$TMPSTATE"

# Intermediate commits allowed with planning only
out=$(run_completion_audit "PreToolUse" "git commit -m 'feat: add tags'")
assert_allowed "S4.1: intermediate commit allowed with planning" "$out"

# Record TDD skill
run_record_skill "silver-tdd" >/dev/null

# dev-cycle-check PostToolUse on Bash commit is also fine
out=$(run_dev_cycle_bash "PostToolUse" "git commit -m 'feat: tags'")
assert_allowed "S4.2: dev-cycle-check allows Bash commit (PostToolUse)" "$out"

# Execute phase SB skills
run_record_skill "silver-execute" >/dev/null
out=$(run_compliance_status)
assert_contains "S4.3: compliance shows execute tracked" "$out" "LIFECYCLE"

integration_teardown

# Scenario 5: Verify and review loop
echo "--- Scenario 5: Verify and review loop ---"
integration_setup
write_default_config

printf 'silver-quality-gates\nsilver-context\nsilver-plan\nsilver-review\nsilver-tdd\n' > "$TMPSTATE"

run_record_skill "silver-verify" >/dev/null
run_record_skill "silver-review-request" >/dev/null
run_record_skill "silver-review-triage" >/dev/null
run_record_skill "silver-completion-audit" >/dev/null

# PR create still blocked — missing finalization skills
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat: tags'")
assert_blocked "S5.1: PR create blocked (finalization skills missing)" "$out"

# Compliance should show REVIEW progress
out=$(run_compliance_status)
assert_contains "S5.2: compliance shows REVIEW progress" "$out" "REVIEW 3/3"

integration_teardown

# Scenario 6: Finalization — record all remaining skills, then PR create allowed
echo "--- Scenario 6: Finalization skills unlock delivery ---"
integration_setup
write_default_config

# Write all skills except delivery finalization
printf 'silver-quality-gates\nsilver-context\nsilver-plan\nsilver-review-request\nsilver-review\nsilver-review-triage\ntdd\nsilver-completion-audit\n' > "$TMPSTATE"

# PR still blocked
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat: tags'")
assert_blocked "S6.1: PR create blocked before finalization" "$out"

# Record remaining required deploy skills
for skill in silver-execute silver-verify silver-ship security silver-secure silver-validate \
             silver-triage silver-branch-finish verify-tests; do
  run_record_skill "$skill" >/dev/null
done
seed_lifecycle_artifacts
append_pre_ship_quality_gates_marker

# PR create now allowed
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat: tags'")
assert_allowed "S6.2: PR create allowed after all required_deploy skills" "$out"

# Compliance shows finalization complete
out=$(run_compliance_status)
assert_contains "S6.3: FINALIZATION 4/4 in compliance" "$out" "FINALIZATION 4/4"

integration_teardown

# Scenario 7: Ship and release
echo "--- Scenario 7: Ship and release ---"
integration_setup
write_default_config

write_all_skills

# Record SB ship
run_record_skill "silver-ship" >/dev/null

# Release allowed with all skills
write_release_live_matrix_marker
write_e2e_live_matrix_marker
write_inline_e2e_matrix_marker
write_quality_gate_state_marker
write_release_ci_runs_marker
run_record_skill "silver-create-release" >/dev/null
out=$(run_completion_audit "PreToolUse" "gh release create v1.0.0")
assert_allowed "S7.1: release allowed with all skills" "$out"

# Stop-check passes
out=$(run_stop_check "Stop")
assert_allowed "S7.4: stop-check passes with all skills + stages" "$out"

integration_teardown

# Scenario 8: Final compliance status shows complete
echo "--- Scenario 8: Final compliance status complete ---"
integration_setup
write_default_config

write_all_skills
run_record_skill "silver-create-release" >/dev/null

out=$(run_compliance_status)
assert_contains "S8.1: PLANNING 3/3 complete" "$out" "PLANNING 3/3"
assert_contains "S8.2: REVIEW 3/3 complete" "$out" "REVIEW 3/3"
assert_contains "S8.3: FINALIZATION 4/4 complete" "$out" "FINALIZATION 4/4"
assert_contains "S8.4: RELEASE 1/1 complete" "$out" "RELEASE 1/1"
assert_contains "S8.5: lifecycle phases tracked" "$out" "LIFECYCLE 5/5"

integration_teardown

print_results

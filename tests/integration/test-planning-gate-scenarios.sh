#!/usr/bin/env bash
# Integration test: Planning gate scenarios
# Tests multi-step interactions between dev-cycle-check, compliance-status, and record-skill
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: Planning Gate Scenarios ==="

# Scenario 1: Developer tries to edit source without any planning
# Expected: dev-cycle-check blocks, compliance-status shows 0 progress
echo "--- Scenario 1: Edit without planning blocked, compliance shows zero ---"
integration_setup
write_default_config

# Step 1: Try to edit src — blocked
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.1: edit src without planning is denied" "$out"
assert_contains "S1.1: mentions HARD STOP" "$out" "HARD STOP"

# Step 2: compliance-status reflects zero progress
out=$(run_compliance_status)
assert_contains "S1.2: compliance shows 0 steps" "$out" "0 steps"

integration_teardown

# Scenario 2: Developer completes planning, then edits source (Stage B gate)
# Expected: silver-quality-gates recorded -> implementation edit allowed -> record gsd-code-review -> still allowed
echo "--- Scenario 2: Progressive stage unlocking A->B->C ---"
integration_setup
write_default_config

# Step 1: Record silver-quality-gates skill (simulates /silver-quality-gates invocation)
run_record_skill "silver-quality-gates"

# Step 2: Try edit — allowed at Stage B (no gsd-code-review yet)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S2.1: edit allowed at Stage B (no gsd-code-review)" "$out"
assert_contains "S2.1: mentions code review remains required" "$out" "Code review"

# Step 3: Record code-review
run_record_skill "gsd-code-review"

# Step 4: Try edit — allowed at Stage C (gsd-code-review done, finalization remaining)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S2.2: edit allowed at Stage C after gsd-code-review" "$out"
# Exact string from hooks/dev-cycle-check.sh Stage C message:
assert_contains "S2.2: mentions finalization remaining" "$out" "finalization"

integration_teardown

# Scenario 3: Dev-cycle-check AND completion-audit interact on same state
# Expected: after planning, dev-cycle allows edit but completion-audit blocks commit;
# after full workflow, both allow their respective operations
echo "--- Scenario 3: Cross-hook state interaction (dev-cycle + completion-audit) ---"
integration_setup
write_default_config

# Step 1: Record planning (directly write state — record-skill only records tracked skills)
printf 'silver-quality-gates\ngsd-code-review\n' > "$TMPSTATE"

# Step 2: dev-cycle-check allows edit (Stage C)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S3.1: edit allowed at Stage C" "$out"

# Step 3: completion-audit blocks PR create (only planning done)
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_blocked "S3.2: PR create blocked with partial skills" "$out"

# Step 4: Complete all skills (using config's required_deploy list, without stages)
cat > "$TMPSTATE" << 'EOSKILLS'
silver-quality-gates
requesting-code-review
gsd-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
verify-tests
EOSKILLS
date +%s > "$VERIFY_TESTS_FILE"

# Step 5: completion-audit allows PR create
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_allowed "S3.3: PR create allowed with all skills" "$out"

integration_teardown

# Scenario 4: Phase-skip detection — finalization recorded before gsd-code-review
echo "--- Scenario 4: Phase skip detection ---"
integration_setup
write_default_config

# Record silver-quality-gates then skip to finalization (no gsd-code-review)
printf 'silver-quality-gates\nsilver-create-release\n' > "$TMPSTATE"

# Edit should be allowed so fixes can proceed, while warning that delivery remains blocked.
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S4.1: phase-skip warning allows fixes" "$out"

integration_teardown

print_results

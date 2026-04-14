#!/usr/bin/env bash
# Integration test: Skill tracking scenarios
# Tests forbidden-skill-check, record-skill, compliance-status interactions
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: Skill Tracking Scenarios ==="

# Scenario 1: Forbidden skill is blocked, state unchanged, compliance unaffected
echo "--- Scenario 1: Forbidden skill blocked, state unchanged ---"
integration_setup
write_default_config

# Step 1: Try forbidden skill
out=$(run_forbidden_skill "executing-plans")
assert_blocked "S1.1: executing-plans forbidden" "$out"

# Step 2: State file should not exist or be empty (forbidden skill was not recorded)
if [[ ! -f "$TMPSTATE" ]] || [[ ! -s "$TMPSTATE" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.2: state unchanged after forbidden skill\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.2: state was modified after forbidden skill (contents: %s)\n' "$(cat "$TMPSTATE")"
fi

# Step 3: compliance-status shows 0 progress
out=$(run_compliance_status)
assert_contains "S1.3: compliance shows 0" "$out" "0"

integration_teardown

# Scenario 2: Allowed skill recorded, then compliance reflects it
echo "--- Scenario 2: Skill recorded and reflected in compliance ---"
integration_setup
write_default_config

# Step 1: Record quality-gates
run_record_skill "quality-gates"

# Step 2: Verify it appears in state
if grep -q "quality-gates" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S2.1: quality-gates recorded in state\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.1: quality-gates not found in state\n'
fi

# Step 3: compliance-status reflects progress
out=$(run_compliance_status)
assert_contains "S2.2: compliance shows progress" "$out" "1"

integration_teardown

# Scenario 3: Idempotent skill recording
echo "--- Scenario 3: Duplicate skill not double-recorded ---"
integration_setup
write_default_config

run_record_skill "quality-gates"
run_record_skill "quality-gates"

count=$(grep -c "quality-gates" "$TMPSTATE" 2>/dev/null || echo "0")
if [[ "$count" -eq 1 ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S3.1: skill recorded exactly once (idempotent)\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S3.1: skill recorded %s times (expected 1)\n' "$count"
fi

integration_teardown

# Scenario 4: Namespace-prefixed forbidden skill blocked
echo "--- Scenario 4: Namespace-prefixed forbidden skill ---"
integration_setup
write_default_config

out=$(run_forbidden_skill "superpowers:executing-plans")
assert_blocked "S4.1: namespaced forbidden skill blocked" "$out"

integration_teardown

# Scenario 5: Progressive skill recording builds full compliance
echo "--- Scenario 5: Full skill progression to compliance ---"
integration_setup
write_default_config

# write_all_skills includes all required skills
write_all_skills

# stop-check should pass with all skills + stages recorded
out=$(run_stop_check "Stop")
assert_allowed "S5.1: stop-check passes after recording all skills" "$out"

integration_teardown

print_results

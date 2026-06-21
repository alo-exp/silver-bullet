#!/usr/bin/env bash
# E2E test: all tracked skills from .silver-bullet.json are correctly recorded
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== E2E: Skill Coverage (all tracked skills) ==="

# Tracked skills from the current packaged config. Keep this dynamic so the
# coverage test follows SB-owned lifecycle changes without preserving retired
# dependency-helper names.
ALL_TRACKED_SKILLS=()
while IFS= read -r skill; do
  [[ -n "$skill" ]] || continue
  ALL_TRACKED_SKILLS+=("$skill")
done < <(jq -r '.skills.all_tracked[]' "$DEFAULT_CONFIG_TEMPLATE")

# Scenario 1: All tracked skills recorded successfully
echo "--- Scenario 1: All tracked skills recorded ---"
integration_setup
write_full_config

for skill in "${ALL_TRACKED_SKILLS[@]}"; do
  run_record_skill "$skill" >/dev/null
done

# Count lines in state file (each skill = 1 line, no duplicates)
recorded_count=$(wc -l < "$TMPSTATE" | tr -d ' ')
# Verify all tracked skills are present
all_present=true
for skill in "${ALL_TRACKED_SKILLS[@]}"; do
  if ! grep -qx "$skill" "$TMPSTATE" 2>/dev/null; then
    all_present=false
    printf 'FAIL: S1 — skill not recorded: %s\n' "$skill"
    FAIL=$((FAIL + 1))
  fi
done
if [[ "$all_present" == true ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.1: all tracked skills recorded in state file\n'
fi

expected_count="${#ALL_TRACKED_SKILLS[@]}"
if [[ "$recorded_count" -ge "$expected_count" ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.2: state file has %d skills (>= %d current tracked skills)\n' "$recorded_count" "$expected_count"
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.2: state file has %d skills (expected >= %d)\n' "$recorded_count" "$expected_count"
fi

integration_teardown

# Scenario 2: Idempotent recording — no duplicates
echo "--- Scenario 2: Idempotent recording ---"
integration_setup
write_full_config

run_record_skill "silver-quality-gates" >/dev/null
run_record_skill "silver-quality-gates" >/dev/null
run_record_skill "silver-quality-gates" >/dev/null

count=$(grep -c "^silver-quality-gates$" "$TMPSTATE" 2>/dev/null || echo "0")
if [[ "$count" -eq 1 ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S2.1: silver-quality-gates recorded exactly once (idempotent)\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.1: silver-quality-gates recorded %d times (expected 1)\n' "$count"
fi

integration_teardown

# Scenario 3: Untracked skills rejected
echo "--- Scenario 3: Untracked skills rejected ---"
integration_setup
write_full_config

out=$(run_record_skill "nonexistent-skill")
assert_contains "S3.1: output says no tracked skills found" "$out" "No completed tracked skill invocation found"

if ! grep -q "nonexistent-skill" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S3.2: nonexistent-skill not in state file\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S3.2: nonexistent-skill should not be in state file\n'
fi

integration_teardown

# Scenario 4: Namespace stripping for a generic prefix
echo "--- Scenario 4: Namespace stripping (generic prefix) ---"
integration_setup
write_full_config

# Directly pipe the input with a generic prefix
input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "external:silver-test"}}')
( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null ) >/dev/null

if grep -qx "silver-test" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S4.1: external:silver-test stripped to silver-test\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S4.1: silver-test not found in state after generic prefix\n'
fi

if ! grep -q "external:" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S4.2: generic prefix not in state\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S4.2: generic prefix should not be in state\n'
fi

integration_teardown

# Scenario 5: Retired namespace markers are not default-recordable
echo "--- Scenario 5: retired namespace marker is not recorded by fresh defaults ---"
integration_setup
write_full_config

input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "testing-strategy"}}')
( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null ) >/dev/null

if ! grep -qx "testing-strategy" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S5.1: retired marker is not recorded by fresh defaults\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S5.1: retired marker should not be recorded by fresh defaults\n'
fi

integration_teardown

# Scenario 6: Double namespace stripping
echo "--- Scenario 6: Double namespace stripping ---"
integration_setup
write_full_config

input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "engineering:external:silver-test"}}')
( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null ) >/dev/null

if grep -qx "silver-test" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S6.1: double namespace stripped to silver-test\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S6.1: silver-test not found after double namespace strip\n'
fi

if ! grep -qE "^(engineering|external)" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S6.2: no namespace prefixes in state\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S6.2: namespace prefixes found in state\n'
fi

integration_teardown

# Scenario 8: Compliance status reflects all recorded required_deploy skills
echo "--- Scenario 8: Compliance status with all required_deploy skills ---"
integration_setup
write_default_config

# Record all current required_deploy and release skills
while IFS= read -r skill; do
  run_record_skill "$skill" >/dev/null
done < <(emit_required_deploy_skills required_deploy; emit_required_deploy_skills required_release)

out=$(run_compliance_status)
assert_contains "S8.1: compliance shows PLANNING complete" "$out" "PLANNING 3/3"
assert_contains "S8.2: compliance shows REVIEW complete" "$out" "REVIEW 3/3"
assert_contains "S8.3: compliance shows FINALIZATION complete" "$out" "FINALIZATION 4/4"
assert_contains "S8.4: compliance shows RELEASE complete" "$out" "RELEASE 1/1"

integration_teardown

print_results

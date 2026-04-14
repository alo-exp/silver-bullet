#!/usr/bin/env bash
# E2E test: All 37 tracked skills from .silver-bullet.json are correctly recorded
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== E2E: Skill Coverage (all 37 tracked skills) ==="

# All 37 tracked skills from .silver-bullet.json all_tracked
ALL_37_SKILLS=(
  "quality-gates" "blast-radius" "devops-quality-gates" "devops-skill-router"
  "design-system" "ux-copy"
  "architecture" "system-design"
  "code-review" "requesting-code-review" "receiving-code-review"
  "testing-strategy" "documentation"
  "finishing-a-development-branch" "deploy-checklist"
  "create-release"
  "modularity" "reusability" "scalability" "security"
  "reliability" "usability" "testability" "extensibility"
  "forensics" "silver-init"
  "verification-before-completion"
  "test-driven-development" "tech-debt" "accessibility-review" "incident-response"
  "gsd-new-project" "gsd-new-milestone" "gsd-discuss-phase" "gsd-plan-phase"
  "gsd-execute-phase" "gsd-verify-work" "gsd-ship" "gsd-debug"
  "gsd-ui-phase" "gsd-ui-review" "gsd-secure-phase"
)

# Scenario 1: All 37 tracked skills recorded successfully
echo "--- Scenario 1: All tracked skills recorded ---"
integration_setup
write_full_config

for skill in "${ALL_37_SKILLS[@]}"; do
  run_record_skill "$skill" >/dev/null
done

# Count lines in state file (each skill = 1 line, no duplicates)
recorded_count=$(wc -l < "$TMPSTATE" | tr -d ' ')
# We have 42 items in ALL_37_SKILLS (the array includes extra skills beyond 37)
# Verify all tracked skills are present
all_present=true
for skill in "${ALL_37_SKILLS[@]}"; do
  if ! grep -qx "$skill" "$TMPSTATE" 2>/dev/null; then
    all_present=false
    printf 'FAIL: S1 — skill not recorded: %s\n' "$skill"
    FAIL=$((FAIL + 1))
  fi
done
if [[ "$all_present" == true ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.1: all tracked skills recorded in state file\n'
fi

# Verify count matches expected (all_tracked has 42 skills in full config)
if [[ "$recorded_count" -ge 37 ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S1.2: state file has %d skills (>= 37)\n' "$recorded_count"
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S1.2: state file has %d skills (expected >= 37)\n' "$recorded_count"
fi

integration_teardown

# Scenario 2: Idempotent recording — no duplicates
echo "--- Scenario 2: Idempotent recording ---"
integration_setup
write_full_config

run_record_skill "quality-gates" >/dev/null
run_record_skill "quality-gates" >/dev/null
run_record_skill "quality-gates" >/dev/null

count=$(grep -c "^quality-gates$" "$TMPSTATE" 2>/dev/null || echo "0")
if [[ "$count" -eq 1 ]]; then
  PASS=$((PASS + 1)); printf 'PASS: S2.1: quality-gates recorded exactly once (idempotent)\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S2.1: quality-gates recorded %d times (expected 1)\n' "$count"
fi

integration_teardown

# Scenario 3: Untracked skills rejected
echo "--- Scenario 3: Untracked skills rejected ---"
integration_setup
write_full_config

out=$(run_record_skill "nonexistent-skill")
assert_contains "S3.1: output says not tracked" "$out" "not tracked"

if ! grep -q "nonexistent-skill" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S3.2: nonexistent-skill not in state file\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S3.2: nonexistent-skill should not be in state file\n'
fi

integration_teardown

# Scenario 4: Namespace stripping for superpowers: prefix
echo "--- Scenario 4: Namespace stripping (superpowers:) ---"
integration_setup
write_full_config

# Directly pipe the input with superpowers: prefix
input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "superpowers:code-review"}}')
( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null ) >/dev/null

if grep -qx "code-review" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S4.1: superpowers:code-review stripped to code-review\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S4.1: code-review not found in state after superpowers: prefix\n'
fi

if ! grep -q "superpowers" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S4.2: superpowers prefix not in state\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S4.2: superpowers prefix should not be in state\n'
fi

integration_teardown

# Scenario 5: GSD namespace conversion (gsd: to gsd-)
echo "--- Scenario 5: GSD namespace conversion ---"
integration_setup
write_full_config

input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "gsd:discuss-phase"}}')
( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null ) >/dev/null

if grep -qx "gsd-discuss-phase" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S5.1: gsd:discuss-phase converted to gsd-discuss-phase\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S5.1: gsd-discuss-phase not found in state\n'
fi

integration_teardown

# Scenario 6: Double namespace stripping
echo "--- Scenario 6: Double namespace stripping ---"
integration_setup
write_full_config

input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: "engineering:superpowers:code-review"}}')
( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null ) >/dev/null

if grep -qx "code-review" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S6.1: double namespace stripped to code-review\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S6.1: code-review not found after double namespace strip\n'
fi

if ! grep -qE "^(engineering|superpowers)" "$TMPSTATE" 2>/dev/null; then
  PASS=$((PASS + 1)); printf 'PASS: S6.2: no namespace prefixes in state\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL: S6.2: namespace prefixes found in state\n'
fi

integration_teardown

# Scenario 8: Compliance status reflects all recorded required_deploy skills
echo "--- Scenario 8: Compliance status with all required_deploy skills ---"
integration_setup
write_default_config

# Record all 12 required_deploy skills
required_deploy_skills=(
  "quality-gates" "code-review" "requesting-code-review" "receiving-code-review"
  "testing-strategy" "documentation" "finishing-a-development-branch" "deploy-checklist"
  "create-release" "verification-before-completion" "test-driven-development" "tech-debt"
)
for skill in "${required_deploy_skills[@]}"; do
  run_record_skill "$skill" >/dev/null
done

out=$(run_compliance_status)
assert_contains "S8.1: compliance shows PLANNING complete" "$out" "PLANNING 1/1"
assert_contains "S8.2: compliance shows REVIEW complete" "$out" "REVIEW 3/3"
assert_contains "S8.3: compliance shows FINALIZATION complete" "$out" "FINALIZATION 4/4"
assert_contains "S8.4: compliance shows RELEASE complete" "$out" "RELEASE 1/1"

integration_teardown

print_results

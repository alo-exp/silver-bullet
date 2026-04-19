#!/usr/bin/env bash
# Integration test: Workflow completion scenarios
# Tests multi-step completion-audit + stop-check + compliance-status interactions
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: Workflow Completion Scenarios ==="

# Scenario 1: Full dev cycle — empty state to successful delivery
# Exercises: record-skill -> compliance-status progress -> completion-audit -> stop-check
echo "--- Scenario 1: Full lifecycle from empty to delivery ---"
integration_setup
write_default_config

# Step 1: Seed with a non-required skill so HOOK-04 (empty-state fail-open) doesn't
# suppress enforcement, then verify stop-check blocks on missing required skills.
printf 'some-unrelated-skill\n' > "$TMPSTATE"
out=$(run_stop_check "Stop")
assert_blocked "S1.1: stop-check blocks when required skills are missing" "$out"

# Step 2: Record all skills progressively
skills=("silver-quality-gates" "code-review" "requesting-code-review" "receiving-code-review"
        "testing-strategy" "documentation" "finishing-a-development-branch"
        "deploy-checklist" "silver-create-release" "verification-before-completion"
        "test-driven-development" "tech-debt")
for skill in "${skills[@]}"; do
  run_record_skill "$skill" >/dev/null
done
# Step 3: stop-check passes now (all skills present)
out=$(run_stop_check "Stop")
assert_allowed "S1.2: stop-check passes with all skills" "$out"

# Step 4: completion-audit allows commit (intermediate tier — only needs silver-quality-gates)
out=$(run_completion_audit "PreToolUse" "git commit -m 'feat: done'")
assert_allowed "S1.3: commit allowed with all skills" "$out"

# Step 5: completion-audit allows PR create (uses config required_deploy, which matches write_all_skills)
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_allowed "S1.4: PR create allowed with all skills" "$out"

integration_teardown

# Scenario 2: Commit gate vs delivery gate thresholds
# Commit needs only planning; PR/merge needs full workflow
echo "--- Scenario 2: Commit allowed early, delivery blocked until complete ---"
integration_setup
write_default_config

# Step 1: With only silver-quality-gates, commit allowed
printf 'silver-quality-gates\n' > "$TMPSTATE"
out=$(run_completion_audit "PreToolUse" "git commit -m 'wip'")
assert_allowed "S2.1: commit allowed with planning only" "$out"

# Step 2: PR create still blocked
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_blocked "S2.2: PR create blocked with only planning" "$out"

# Step 3: gh pr merge also blocked
out=$(run_completion_audit "PreToolUse" "gh pr merge --squash")
assert_blocked "S2.3: PR merge blocked with only planning" "$out"

integration_teardown

# Scenario 3: PR create and release allowed with all skills
echo "--- Scenario 3: PR create and release allowed with all skills ---"
integration_setup
write_default_config

# All skills present
cat > "$TMPSTATE" << 'EOSKILLS'
silver-quality-gates
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOSKILLS

# Step 1: PR create allowed
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_allowed "S3.1: PR create allowed with all skills" "$out"

# Step 2: Release allowed with all skills
out=$(run_completion_audit "PreToolUse" "gh release create v1.0.0")
assert_allowed "S3.2: release allowed with all skills" "$out"

integration_teardown

# Scenario 4: Main branch exemption for finishing-a-development-branch
echo "--- Scenario 4: Main branch finishing exemption ---"
integration_setup
write_default_config

# All skills except finishing-a-development-branch
write_all_skills
# Remove finishing-a-development-branch from state
grep -v '^finishing-a-development-branch$' "$TMPSTATE" > "${TMPSTATE}.tmp" && mv "${TMPSTATE}.tmp" "$TMPSTATE"

# On feature branch: blocked (finishing-a-development-branch missing)
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_blocked "S4.1: PR blocked on feature branch without finishing" "$out"

# Switch to main branch
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true

# On main: allowed (finishing-a-development-branch not required on main)
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'hotfix'")
assert_allowed "S4.2: PR allowed on main without finishing" "$out"

integration_teardown

# Scenario 5: Skill ordering enforcement in delivery tier
echo "--- Scenario 5: Skill ordering enforcement ---"
integration_setup
write_default_config

# Write all skills but with requesting-code-review BEFORE code-review
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF

out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_contains "S5.1: ordering issue detected" "$out" "wrong order"

integration_teardown

# Scenario 6: stop-check + completion-audit agreement
# Both should block/allow consistently based on same state
echo "--- Scenario 6: stop-check and completion-audit consistency ---"
integration_setup
write_default_config

# Seed with unrelated skill (HOOK-04: empty state = non-dev session = fail-open).
# Completion-audit also blocks with missing required skills.
printf 'some-unrelated-skill\n' > "$TMPSTATE"
out_stop=$(run_stop_check "Stop")
out_audit=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_blocked "S6.1: stop-check blocks when required skills are missing" "$out_stop"
assert_blocked "S6.2: completion-audit blocks when required skills are missing" "$out_audit"

# Full state: both allow
write_all_skills
out_stop=$(run_stop_check "Stop")
out_audit=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_allowed "S6.3: stop-check allows with all skills" "$out_stop"
assert_allowed "S6.4: completion-audit allows with all skills" "$out_audit"

integration_teardown

print_results

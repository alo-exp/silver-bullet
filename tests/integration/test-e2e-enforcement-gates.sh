#!/usr/bin/env bash
# Integration test: E2E enforcement gates
# Tests all enforcement violations — both blocked AND allowed paths
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: E2E Enforcement Gates ==="

# Scenario 1: Edit-before-planning (dev-cycle Stage A -> B -> C)
echo "--- Scenario 1: Edit-before-planning gate stages ---"
integration_setup
write_default_config

# No skills: Stage A block
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.1: edit blocked with no planning (Stage A)" "$out"
assert_contains "S1.2: mentions HARD STOP" "$out" "HARD STOP"

# Record silver-quality-gates only: Stage B block (code-review required)
run_record_skill "silver-quality-gates" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.3: edit blocked without code-review (Stage B)" "$out"
assert_contains "S1.4: mentions code-review" "$out" "code-review"

# Record code-review: Stage C — now ALLOWED
run_record_skill "code-review" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S1.5: edit allowed after planning + code-review (Stage C)" "$out"

integration_teardown

# Scenario 2: Commit-without-planning (completion-audit intermediate tier)
echo "--- Scenario 2: Commit gate blocked without planning ---"
integration_setup
write_default_config

# No skills: intermediate commit blocked
out=$(run_completion_audit "PreToolUse" "git commit -m 'wip'")
assert_blocked "S2.1: commit blocked with no planning" "$out"

# Record silver-quality-gates: commit now ALLOWED
run_record_skill "silver-quality-gates" >/dev/null
out=$(run_completion_audit "PreToolUse" "git commit -m 'wip'")
assert_allowed "S2.2: commit allowed after planning" "$out"

integration_teardown

# Scenario 3: PR-create-without-full-workflow (delivery tier)
echo "--- Scenario 3: PR create blocked without full workflow ---"
integration_setup
write_default_config

# Only planning: PR blocked
run_record_skill "silver-quality-gates" >/dev/null
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_blocked "S3.1: PR create blocked with only planning" "$out"

# Record all required_deploy: PR now ALLOWED
for skill in silver-quality-gates code-review requesting-code-review receiving-code-review \
             testing-strategy documentation finishing-a-development-branch deploy-checklist \
             silver-create-release verification-before-completion test-driven-development tech-debt; do
  run_record_skill "$skill" >/dev/null
done
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'feat'")
assert_allowed "S3.2: PR create allowed with all required skills" "$out"

integration_teardown

# Scenario 5: Forbidden skill blocked
echo "--- Scenario 5: Forbidden skill gate ---"
integration_setup
write_default_config

out=$(run_forbidden_skill "executing-plans")
assert_blocked "S5.1: executing-plans is blocked" "$out"

out=$(run_forbidden_skill "subagent-driven-development")
assert_blocked "S5.2: subagent-driven-development is blocked" "$out"

out=$(run_forbidden_skill "code-review")
assert_allowed "S5.3: code-review is allowed (not forbidden)" "$out"

integration_teardown

# Scenario 6: Phase-skip detection
echo "--- Scenario 6: Phase-skip detection (finalization before code-review) ---"
integration_setup
write_default_config

# Record silver-quality-gates + testing-strategy but NOT code-review
run_record_skill "silver-quality-gates" >/dev/null
run_record_skill "testing-strategy" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S6.1: edit blocked due to phase-skip (testing before code-review)" "$out"
assert_contains "S6.2: mentions phase skip" "$out" "Phase skip"

integration_teardown

# Scenario 7: Stop-check blocked without all skills, allowed with all
echo "--- Scenario 7: Stop-check gate ---"
integration_setup
write_default_config

# Empty state: stop blocked
out=$(run_stop_check "Stop")
assert_blocked "S7.1: stop-check blocks with empty state" "$out"

# SubagentStop also blocked
out=$(run_stop_check "SubagentStop")
assert_blocked "S7.2: stop-check blocks SubagentStop with empty state" "$out"

# All skills + stages: stop allowed
write_all_skills
out=$(run_stop_check "Stop")
assert_allowed "S7.3: stop-check allowed with all skills + stages" "$out"

out=$(run_stop_check "SubagentStop")
assert_allowed "S7.4: stop-check allows SubagentStop with all skills + stages" "$out"

integration_teardown

# Scenario 8: Code review ordering enforcement
echo "--- Scenario 8: Code review ordering (requesting before code-review) ---"
integration_setup
write_default_config

# Write state with requesting-code-review BEFORE code-review
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
assert_contains "S8.1: ordering violation detected" "$out" "wrong order"

integration_teardown

# Scenario 9: Trivial file bypass
echo "--- Scenario 9: Trivial file bypass ---"
integration_setup
write_default_config

# No planning skills — normally would block
# Create trivial file: bypass active
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S9.1: edit allowed when trivial file exists" "$out"

# Delete trivial file: enforcement back
rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S9.2: edit blocked after trivial file removed" "$out"

integration_teardown

# Scenario 10: Third-party plugin boundary
echo "--- Scenario 10: Third-party plugin boundary ---"
integration_setup
write_default_config
# All skills so the only block is the plugin boundary check
write_all_skills

plugin_path="$HOME/.claude/plugins/cache/test-plugin/src/index.js"
out=$(run_dev_cycle_edit "PreToolUse" "$plugin_path")
assert_blocked "S10.1: edit blocked targeting plugin cache" "$out"
assert_contains "S10.2: mentions THIRD-PARTY PLUGIN BOUNDARY" "$out" "THIRD-PARTY PLUGIN BOUNDARY"

integration_teardown

print_results

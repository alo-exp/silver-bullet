#!/usr/bin/env bash
# Tests for composable flows (WORKFLOW.md) enforcement scenarios
# Validates dual-mode hook behavior: WORKFLOW.md-first with legacy fallback

set -euo pipefail
source "$(dirname "$0")/helpers/common.sh"

echo "=== Composable Flows Scenarios ==="

# Scenario 1: WORKFLOW.md complete -> all hooks pass
echo "--- S1: Full composition complete → hooks allow ---"
integration_setup
write_default_config
write_all_skills
write_workflow_md_complete

# Dev cycle should allow
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S1.1: dev-cycle allows with complete WORKFLOW.md" "$out"

# Completion audit should allow
out=$(run_completion_audit "PostToolUse" "git commit -m test")
assert_allowed "S1.2: completion-audit allows with complete WORKFLOW.md" "$out"

integration_teardown

# Scenario 2: WORKFLOW.md partial -> enforcement active
echo "--- S2: Partial composition → enforcement gates active ---"
integration_setup
write_default_config
write_workflow_md_partial
# No skills in state

# Dev cycle should block (WORKFLOW.md partial + no skills)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S2.1: dev-cycle blocks with partial WORKFLOW.md and no skills" "$out"

integration_teardown

# Scenario 3: No WORKFLOW.md -> legacy behavior preserved
echo "--- S3: No WORKFLOW.md → legacy enforcement ---"
integration_setup
write_default_config
# No WORKFLOW.md, no skills

out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S3.1: dev-cycle blocks without WORKFLOW.md (legacy)" "$out"

# Add all skills
write_all_skills
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S3.2: dev-cycle allows with all skills (legacy)" "$out"

integration_teardown

# Scenario 4: Malformed WORKFLOW.md -> graceful fallback
echo "--- S4: Malformed WORKFLOW.md → graceful fallback ---"
integration_setup
write_default_config
mkdir -p "$TMPDIR_TEST/.planning"
echo "This is not valid WORKFLOW.md content" > "$TMPDIR_TEST/.planning/WORKFLOW.md"
# No skills -> should fall through to legacy and block
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S4.1: malformed WORKFLOW.md falls through to legacy block" "$out"

# Add all skills -> should pass via legacy
write_all_skills
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S4.2: malformed WORKFLOW.md + all skills -> legacy pass" "$out"

integration_teardown

# Scenario 5: WORKFLOW.md + skills both present -> WORKFLOW.md takes priority
echo "--- S5: WORKFLOW.md + skills → WORKFLOW.md priority ---"
integration_setup
write_default_config
write_all_skills
write_workflow_md_complete

out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S5.1: both present -> passes (WORKFLOW.md complete)" "$out"

integration_teardown

# Scenario 6: WORKFLOW.md symlink -> ignored (security)
echo "--- S6: WORKFLOW.md symlink → ignored ---"
integration_setup
write_default_config
mkdir -p "$TMPDIR_TEST/.planning"
# Create a real file elsewhere and symlink
echo "fake" > "/tmp/fake-workflow-$$.md"
ln -s "/tmp/fake-workflow-$$.md" "$TMPDIR_TEST/.planning/WORKFLOW.md"
# Should fall through to legacy (symlink ignored per hook security)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S6.1: symlinked WORKFLOW.md ignored, legacy blocks" "$out"
rm -f "/tmp/fake-workflow-$$.md"

integration_teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

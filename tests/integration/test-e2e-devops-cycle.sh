#!/usr/bin/env bash
# Integration test: E2E DevOps workflow variant
# Tests the devops-cycle active_workflow — blast-radius + devops-quality-gates replace quality-gates
set -euo pipefail

source "$(dirname "$0")/helpers/common.sh"

echo "=== Integration: E2E DevOps Cycle ==="

# Helper: write devops config (required_planning = blast-radius + devops-quality-gates)
write_devops_config() {
  cat > "$TMPCFG" << EOCFG
{
  "project": { "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\\\.test\\\\.", "active_workflow": "devops-cycle" },
  "skills": {
    "required_planning": ["blast-radius","devops-quality-gates"],
    "required_deploy": ["blast-radius","devops-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["blast-radius","devops-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOCFG
}

# Scenario 1: DevOps planning requires blast-radius + devops-quality-gates
echo "--- Scenario 1: DevOps planning gate (blast-radius + devops-quality-gates) ---"
integration_setup
write_devops_config

# No skills: blocked (blast-radius missing — Stage A)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.1: edit blocked with no devops planning skills" "$out"
assert_contains "S1.2: mentions blast-radius" "$out" "blast-radius"

# Record blast-radius only: still blocked (devops-quality-gates missing)
run_record_skill "blast-radius" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.3: edit blocked with only blast-radius (devops-quality-gates missing)" "$out"

# Record devops-quality-gates: Stage B (code-review still needed)
run_record_skill "devops-quality-gates" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_blocked "S1.4: edit blocked without code-review (Stage B)" "$out"

# Record code-review: Stage C — ALLOWED
run_record_skill "code-review" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/app.js")
assert_allowed "S1.5: edit allowed after blast-radius + devops-quality-gates + code-review" "$out"

integration_teardown

# Scenario 2: DevOps commit gate requires blast-radius
echo "--- Scenario 2: DevOps commit gate ---"
integration_setup
write_devops_config

# No blast-radius: commit blocked
out=$(run_completion_audit "PreToolUse" "git commit -m 'infra: update deploy'")
assert_blocked "S2.1: commit blocked without blast-radius" "$out"

# Record blast-radius + devops-quality-gates: commit ALLOWED
run_record_skill "blast-radius" >/dev/null
run_record_skill "devops-quality-gates" >/dev/null
out=$(run_completion_audit "PreToolUse" "git commit -m 'infra: update deploy'")
assert_allowed "S2.2: commit allowed after devops planning" "$out"

integration_teardown

# Scenario 3: DevOps YAML/JSON files NOT exempt from enforcement
echo "--- Scenario 3: YAML/JSON files not exempt in devops-cycle ---"
integration_setup
write_devops_config
# No planning skills — enforcement should apply to all src/ files including yaml

# YAML file in src/ is NOT exempt in devops-cycle
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/deploy.yml")
assert_blocked "S3.1: .yml edit blocked in devops-cycle (infrastructure code)" "$out"

# JSON file in src/ is also NOT exempt in devops-cycle
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/config.json")
assert_blocked "S3.2: .json edit blocked in devops-cycle (infrastructure code)" "$out"

# Compare: in full-dev-cycle, same YAML file IS exempt
write_default_config
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/deploy.yml")
assert_allowed "S3.3: .yml edit allowed in full-dev-cycle (non-logic bypass)" "$out"

integration_teardown

# Scenario 4: DevOps stop-check uses devops required skills
echo "--- Scenario 4: DevOps stop-check gate ---"
integration_setup
write_devops_config

# Empty state: stop blocked
out=$(run_stop_check "Stop")
assert_blocked "S4.1: stop-check blocks with empty devops state" "$out"

# Record all devops required_deploy skills
for skill in blast-radius devops-quality-gates code-review requesting-code-review \
             receiving-code-review testing-strategy documentation \
             finishing-a-development-branch deploy-checklist create-release \
             verification-before-completion test-driven-development tech-debt; do
  run_record_skill "$skill" >/dev/null
done
out=$(run_stop_check "Stop")
assert_allowed "S4.2: stop-check allowed with all devops skills" "$out"

integration_teardown

# Scenario 5: IaC file detection in devops context (Terraform)
echo "--- Scenario 5: IaC file enforcement in devops context ---"
integration_setup
write_devops_config
# No planning — should block terraform edits

# Terraform file in src/ should be enforced (not bypassed)
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/main.tf")
# .tf files don't match the non-logic bypass list in devops-cycle either — but they
# also don't match in full-dev-cycle. Either way, enforcement applies.
assert_blocked "S5.1: .tf edit blocked in devops-cycle (no devops planning)" "$out"

# Record devops planning + code-review: ALLOWED
run_record_skill "blast-radius" >/dev/null
run_record_skill "devops-quality-gates" >/dev/null
run_record_skill "code-review" >/dev/null
out=$(run_dev_cycle_edit "PreToolUse" "$TMPDIR_TEST/src/main.tf")
assert_allowed "S5.2: .tf edit allowed after devops planning + code-review" "$out"

integration_teardown

# Scenario 6: DevOps PR create blocked without full required_deploy, allowed with all
echo "--- Scenario 6: DevOps PR create gate ---"
integration_setup
write_devops_config

# Only blast-radius: PR blocked
run_record_skill "blast-radius" >/dev/null
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'infra: promote to staging'")
assert_blocked "S6.1: PR blocked with only blast-radius" "$out"

# Record all devops required_deploy
for skill in blast-radius devops-quality-gates code-review requesting-code-review \
             receiving-code-review testing-strategy documentation \
             finishing-a-development-branch deploy-checklist create-release \
             verification-before-completion test-driven-development tech-debt; do
  run_record_skill "$skill" >/dev/null
done
out=$(run_completion_audit "PreToolUse" "gh pr create --title 'infra: promote to staging'")
assert_allowed "S6.2: PR allowed with all devops required skills" "$out"

integration_teardown

print_results

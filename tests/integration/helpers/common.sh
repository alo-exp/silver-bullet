#!/usr/bin/env bash
# Shared helpers for integration tests

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/hooks"
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
PASS=0
FAIL=0

# --- Setup/Teardown ---
integration_setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  rm -f "$TMPSTATE"
  # Git repo required for branch detection
  git -C "$TMPDIR_TEST" init -q
  git -C "$TMPDIR_TEST" config user.email "test@test.com"
  git -C "$TMPDIR_TEST" config user.name "Test"
  touch "$TMPDIR_TEST/.gitkeep"
  git -C "$TMPDIR_TEST" add .gitkeep
  git -C "$TMPDIR_TEST" commit -q -m "init" 2>/dev/null || true
  git -C "$TMPDIR_TEST" checkout -q -b feature/test 2>/dev/null || true
  # Create src dir
  mkdir -p "$TMPDIR_TEST/src"
  touch "$TMPDIR_TEST/src/app.js"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

integration_teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}

write_default_config() {
  local workflow="${1:-full-dev-cycle}"
  cat > "$TMPCFG" << EOCFG
{
  "project": { "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\\\.test\\\\.", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOCFG
}

write_all_skills() {
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
}

# Write a WORKFLOW.md with all paths marked complete
write_workflow_md_complete() {
  local planning_dir="${TMPDIR_TEST}/.planning"
  mkdir -p "$planning_dir"
  cat > "$planning_dir/WORKFLOW.md" << 'WFEOF'
# Composition

**Workflow:** silver:feature
**Mode:** autonomous

## Flow Log

| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 1 | ORIENT | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 11 | VERIFY | complete |
| 12 | QUALITY GATE | complete |
| 13 | SHIP | complete |

## Heartbeat

Last-flow: FLOW 13 SHIP
Last-beat: 2026-04-15T00:00:00Z

## Next Flow

(none — composition complete)
WFEOF
}

# Write a WORKFLOW.md with partial completion
write_workflow_md_partial() {
  local planning_dir="${TMPDIR_TEST}/.planning"
  mkdir -p "$planning_dir"
  cat > "$planning_dir/WORKFLOW.md" << 'WFEOF'
# Composition

**Workflow:** silver:feature
**Mode:** interactive

## Flow Log

| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 1 | ORIENT | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | pending |
| 11 | VERIFY | pending |
| 13 | SHIP | pending |

## Heartbeat

Last-flow: FLOW 5 PLAN
Last-beat: 2026-04-15T00:00:00Z

## Next Flow

FLOW 7 EXECUTE
WFEOF
}

# Write a WORKFLOW.md with FLOW 4 excluded (for spec-floor advisory tests)
write_workflow_md_no_path4() {
  local planning_dir="${TMPDIR_TEST}/.planning"
  mkdir -p "$planning_dir"
  cat > "$planning_dir/WORKFLOW.md" << 'WFEOF'
# Composition

**Workflow:** silver:feature
**Mode:** interactive

## Flow Log

| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 1 | ORIENT | complete |
| 5 | PLAN | pending |
| 7 | EXECUTE | pending |

## Next Flow

FLOW 5 PLAN
WFEOF
}

# --- Hook runners ---
run_dev_cycle_edit() {
  local event="$1" filepath="$2"
  local old_str="${3:-old content here long enough to exceed the small-edit bypass threshold value}"
  local new_str="${4:-new content here long enough to exceed the small-edit bypass threshold value}"
  local input
  input=$(jq -n --arg e "$event" --arg f "$filepath" --arg o "$old_str" --arg n "$new_str" \
    '{hook_event_name: $e, tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/dev-cycle-check.sh" 2>/dev/null )
}

run_completion_audit() {
  local event="$1" cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/completion-audit.sh" 2>/dev/null )
}

run_stop_check() {
  local event="${1:-Stop}"
  local input
  input=$(jq -n --arg e "$event" '{hook_event_name: $e}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/stop-check.sh" 2>/dev/null )
}

run_forbidden_skill() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/forbidden-skill-check.sh" 2>/dev/null )
}

run_compliance_status() {
  local input='{"hook_event_name":"PostToolUse","tool_name":"Edit"}'
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/compliance-status.sh" 2>/dev/null )
}

run_record_skill() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/record-skill.sh" 2>/dev/null )
}

run_prompt_reminder() {
  local input='{"hook_event_name":"UserPromptSubmit","prompt":"hello"}'
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/prompt-reminder.sh" 2>/dev/null )
}

run_ci_status_check() {
  local event="$1" cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/ci-status-check.sh" 2>/dev/null )
}

run_session_log_init() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/session-log-init.sh" 2>/dev/null )
}

run_session_start() {
  local input='{"hook_event_name":"SessionStart"}'
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/session-start" 2>/dev/null )
}

# --- Assertions ---
is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
}

assert_blocked() {
  local label="$1" output="$2"
  if is_blocked "$output"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected block, got: %s)\n' "$label" "$output"
  fi
}

assert_allowed() {
  local label="$1" output="$2"
  if ! is_blocked "$output"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected allow, got: %s)\n' "$label" "$output"
  fi
}

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected "%s" in: %s)\n' "$label" "$needle" "$output"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" needle="$3"
  if ! printf '%s' "$output" | grep -q "$needle"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (unexpected "%s" in: %s)\n' "$label" "$needle" "$output"
  fi
}

print_results() {
  printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
}

# --- Additional hook runners ---

run_uat_gate() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/uat-gate.sh" 2>/dev/null )
}

run_spec_floor_check() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/spec-floor-check.sh" 2>/dev/null )
}

run_phase_archive() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/phase-archive.sh" 2>/dev/null )
}

run_timeout_check() {
  local input='{"hook_event_name":"PostToolUse","tool_name":"Edit"}'
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/timeout-check.sh" 2>/dev/null )
}

run_pr_traceability() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/pr-traceability.sh" 2>/dev/null )
}

run_semantic_compress() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/semantic-compress.sh" 2>/dev/null )
}

run_dev_cycle_bash() {
  local event="$1" cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/dev-cycle-check.sh" 2>/dev/null )
}

write_full_config() {
  local workflow="${1:-full-dev-cycle}"
  cat > "$TMPCFG" << EOCFG
{
  "project": { "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\\\.test\\\\.", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"],
    "all_tracked": ["silver-quality-gates","silver-blast-radius","devops-quality-gates","devops-skill-router","design-system","ux-copy","architecture","system-design","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","modularity","reusability","scalability","security","reliability","usability","testability","extensibility","silver-forensics","silver-init","verification-before-completion","test-driven-development","tech-debt","accessibility-review","incident-response","gsd-new-project","gsd-new-milestone","gsd-discuss-phase","gsd-plan-phase","gsd-execute-phase","gsd-verify-work","gsd-ship","gsd-debug","gsd-ui-phase","gsd-ui-review","gsd-secure-phase"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOCFG
}

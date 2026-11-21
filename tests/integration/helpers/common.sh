#!/usr/bin/env bash
# Shared helpers for integration tests

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/hooks"
# shellcheck source=tests/lib/sandbox-env.sh
source "${REPO_ROOT}/tests/lib/sandbox-env.sh"
# KAY_HOME, PI_CODING_AGENT_DIR, CODEX_HOME, CLAUDE_CONFIG_DIR, ...: nothing may point the runtime paths below,
# or a fixture, at the developer's real install
sb_test_scrub_runtime_env
if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL="${SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL:-1}"
export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME
sb_test_assert_sandboxed || exit 70

# Sourcing creates nothing: the state dir and the plugin-cache stub exist from integration_setup to
# integration_teardown only, so a test file run directly leaves nothing in the developer's runtime home.
SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
TEST_RUN_ID="$$"
PASS=0
FAIL=0
DEFAULT_CONFIG_TEMPLATE="${REPO_ROOT}/templates/silver-bullet.config.json.default"
RELEASE_LIVE_MATRIX_FILE="${SB_TEST_DIR}/release-live-matrix"
E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
INLINE_E2E_MATRIX_FILE="${SB_TEST_DIR}/inline-e2e-matrix"
QUALITY_GATE_FILE="${SB_TEST_DIR}/quality-gate-state"
VERIFY_TESTS_FILE="${SB_TEST_DIR}/verify-tests-state-${TEST_RUN_ID}"
LEGACY_CI_TRIVIAL_FILE="${SB_TEST_DIR}/trivial"
LEGACY_CI_OVERRIDE_FILE="${SB_TEST_DIR}/ci-red-override"

# --- Setup/Teardown ---
integration_setup() {
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/integration-${TEST_RUN_ID}-${RANDOM}"
  SB_TEST_DIR="$SB_RUNTIME_STATE_DIR"
  mkdir -p "$SB_TEST_DIR"
  # a stand-in plugin-cache version (not semver, so version resolution ignores it); removed by teardown
  # only when this setup created it
  _SB_CACHE_STUB="${SB_RUNTIME_HOME_ROOT}/plugins/cache/alo-labs/silver-bullet/test"
  _SB_CACHE_STUB_CREATED=0
  if [[ ! -d "$_SB_CACHE_STUB" ]]; then
    mkdir -p "$_SB_CACHE_STUB"
    _SB_CACHE_STUB_CREATED=1
  fi
  RELEASE_LIVE_MATRIX_FILE="${SB_TEST_DIR}/release-live-matrix"
  E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
  INLINE_E2E_MATRIX_FILE="${SB_TEST_DIR}/inline-e2e-matrix"
  QUALITY_GATE_FILE="${SB_TEST_DIR}/quality-gate-state"
  VERIFY_TESTS_FILE="${SB_TEST_DIR}/verify-tests-state-${TEST_RUN_ID}"
  LEGACY_CI_TRIVIAL_FILE="${SB_TEST_DIR}/trivial"
  LEGACY_CI_OVERRIDE_FILE="${SB_TEST_DIR}/ci-red-override"

  TMPDIR_TEST=$(mktemp -d)
  mkdir -p "${TMPDIR_TEST}.hookrun"
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
  mkdir -p "$TMPDIR_TEST/.planning/phases/001-test"
  cat > "$TMPDIR_TEST/.planning/phases/001-test/001-REVIEW.md" <<'EOF'
# Review

## Findings

No issues found — review completed with evidence.

status: passed
EOF
  cat > "$TMPDIR_TEST/.planning/REVIEW-ROUNDS.md" <<'EOF'
## Round 1
Findings: advisory only — addressed.

## Round 2
No findings — clean pass.
EOF
  cat > "$TMPDIR_TEST/.planning/phases/001-test/001-VERIFICATION.md" <<'EOF'
# Verification

## Command output

```bash
$ npm test
PASS tests/todos.test.js
Tests: 69 passed, 69 total
```
EOF
  cat > "$TMPDIR_TEST/.planning/phases/001-test/001-PLAN.md" <<'EOF'
# Plan

## Goal

Integration fixture plan with substantive body for quality-gates mode detection.

## Tasks

- Task 1: exercise integration delivery gates with realistic PLAN.md body.

## Acceptance criteria

- Delivery hooks allow PR create when all required skills and artifacts are present.

## Verification

- Run `bash tests/run-all-tests.sh` and confirm integration scenarios pass.
EOF

  # SB project marker files
  printf '%s\n' '# Silver Bullet' > "$TMPDIR_TEST/silver-bullet.md"

  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE"
  export SILVER_BULLET_TEST_HOOK_ENFORCED=1
  # Mock branch file so session-start sees "feature/test" without touching
  # the live host runtime branch file.
  TMPBRANCH="${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
  printf 'feature/test' > "$TMPBRANCH"
  export SILVER_BULLET_BRANCH_FILE="$TMPBRANCH"
  rm -f "$E2E_LIVE_MATRIX_FILE"
  rm -f "$INLINE_E2E_MATRIX_FILE"
  rm -f "$VERIFY_TESTS_FILE"
  # Keep integration runs deterministic by removing global legacy CI bypass artifacts.
  rm -f "$LEGACY_CI_TRIVIAL_FILE" "$LEGACY_CI_OVERRIDE_FILE"
}

integration_teardown() {
  local _isolated_dir="$SB_RUNTIME_STATE_DIR"
  rm -rf "$TMPDIR_TEST" "${TMPDIR_TEST}.hookrun"
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" "${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
  rm -f "$RELEASE_LIVE_MATRIX_FILE"
  rm -f "$E2E_LIVE_MATRIX_FILE"
  rm -f "$INLINE_E2E_MATRIX_FILE"
  rm -f "$VERIFY_TESTS_FILE"
  rm -f "${SB_TEST_DIR}/stall-block"
  rm -f "$LEGACY_CI_TRIVIAL_FILE" "$LEGACY_CI_OVERRIDE_FILE"
  unset GH_RUN_LIST_OVERRIDE
  unset SILVER_BULLET_TEST_HOOK_ENFORCED
  rm -rf "$_isolated_dir" 2>/dev/null || true
  if [[ "${_SB_CACHE_STUB_CREATED:-0}" == "1" ]]; then
    rmdir "$_SB_CACHE_STUB" 2>/dev/null || true
    # drop the parents the stub created, never one that holds anything else
    rmdir "${_SB_CACHE_STUB%/*}" "${_SB_CACHE_STUB%/*/*}" "${_SB_CACHE_STUB%/*/*/*}" "${_SB_CACHE_STUB%/*/*/*/*}" 2>/dev/null || true
    _SB_CACHE_STUB_CREATED=0
  fi
}

write_default_config() {
  local workflow="${1:-full-dev-cycle}"
  local config_version required_planning required_deploy all_tracked
  config_version=$(jq -r '.config_version' "$DEFAULT_CONFIG_TEMPLATE")
  if [[ "$workflow" == "devops-cycle" ]]; then
    required_planning=$(jq -c '.skills.required_planning_devops' "$DEFAULT_CONFIG_TEMPLATE")
    required_deploy=$(jq -c '.skills.required_deploy_devops' "$DEFAULT_CONFIG_TEMPLATE")
  else
    required_planning=$(jq -c '.skills.required_planning' "$DEFAULT_CONFIG_TEMPLATE")
    required_deploy=$(jq -c '.skills.required_deploy' "$DEFAULT_CONFIG_TEMPLATE")
  fi
  all_tracked=$(jq -c '.skills.all_tracked' "$DEFAULT_CONFIG_TEMPLATE")
  cat > "$TMPCFG" << EOCFG
{
  "config_version": "${config_version}",
  "sb_initiated": true,
  "sb_enforcement_tier": 2,
  "project": { "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\\\.test\\\\.", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ${required_planning},
    "required_deploy": ${required_deploy},
    "all_tracked": ${all_tracked}
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOCFG
}

emit_required_deploy_skills() {
  local field="${1:-required_deploy}"
  jq -r ".skills.${field}[]" "$DEFAULT_CONFIG_TEMPLATE" | awk '
    $0 == "silver-review" { pending_review = 1; next }
    $0 == "silver-review-request" {
      print
      if (pending_review) {
        print "silver-review"
        pending_review = 0
      }
      next
    }
    { print }
    END {
      if (pending_review) print "silver-review"
    }
  '
}

seed_lifecycle_artifacts() {
  mkdir -p "$TMPDIR_TEST/.planning"
  cat > "$TMPDIR_TEST/.planning/STATE.md" <<'EOF'
# Execution State

status: complete
EOF
  cat > "$TMPDIR_TEST/.planning/UAT.md" <<'EOF'
# UAT

| Scenario | Result |
|---|---|
| Integration fixture | PASS |
EOF
  cat > "$TMPDIR_TEST/.planning/SECURITY.md" <<'EOF'
# Security Verification

status: complete
EOF
  cat > "$TMPDIR_TEST/.planning/VALIDATION.md" <<'EOF'
# Validation

status: complete
EOF
}

# Delivery gates require silver-quality-gates-adversarial when substantive
# VERIFICATION.md exists (see hooks/lib/quality-gates-mode.sh).
append_pre_ship_quality_gates_marker() {
  [[ -f "$TMPSTATE" ]] || return 0
  grep -qx 'silver-quality-gates-adversarial' "$TMPSTATE" 2>/dev/null && return 0
  if grep -qx 'silver-quality-gates' "$TMPSTATE" 2>/dev/null \
     || grep -qx 'devops-quality-gates' "$TMPSTATE" 2>/dev/null; then
    printf 'silver-quality-gates-adversarial\n' >> "$TMPSTATE"
  fi
}

write_all_skills() {
  {
    emit_required_deploy_skills required_deploy
    emit_required_deploy_skills required_release
  } | awk 'NF && !seen[$0]++' > "$TMPSTATE"
  append_pre_ship_quality_gates_marker
  date +%s > "$VERIFY_TESTS_FILE"
  seed_lifecycle_artifacts
}

# Write a WORKFLOW.md with all paths marked complete
write_workflow_md_complete() {
  local planning_dir="${TMPDIR_TEST}/.planning"
  mkdir -p "$planning_dir"
  cat > "$planning_dir/WORKFLOW.md" << 'WFEOF'
# Composition

**Workflow:** sb:feature
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

Last-flow: FLOW 14 SHIP
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

**Workflow:** sb:feature
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

Last-flow: FLOW 6 PLAN
Last-beat: 2026-04-15T00:00:00Z

## Next Flow

FLOW 8 EXECUTE
WFEOF
}

# Write a WORKFLOW.md with FLOW 5 excluded (for spec-floor advisory tests)
write_workflow_md_no_path4() {
  local planning_dir="${TMPDIR_TEST}/.planning"
  mkdir -p "$planning_dir"
  cat > "$planning_dir/WORKFLOW.md" << 'WFEOF'
# Composition

**Workflow:** sb:feature
**Mode:** interactive

## Flow Log

| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 1 | ORIENT | complete |
| 5 | PLAN | pending |
| 7 | EXECUTE | pending |

## Next Flow

FLOW 6 PLAN
WFEOF
}

write_release_live_matrix_marker() {
  mkdir -p "$SB_TEST_DIR"
  cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
}

write_e2e_live_matrix_marker() {
  mkdir -p "$SB_TEST_DIR"
  cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
}

write_inline_e2e_matrix_marker() {
  mkdir -p "$SB_TEST_DIR"
  printf 'matrix=inline-full-surface\ncommit=%s\n' "$(git -C "$TMPDIR_TEST" rev-parse HEAD)" > "$INLINE_E2E_MATRIX_FILE"
}

write_quality_gate_state_marker() {
  mkdir -p "$(dirname "$QUALITY_GATE_FILE")"
  cat > "$QUALITY_GATE_FILE" <<'EOF'
quality-gate-stage-1
quality-gate-stage-2
quality-gate-stage-3
quality-gate-stage-4
full-test-suite-rerun
EOF
}

write_release_ci_runs_marker() {
  export GH_RUN_LIST_OVERRIDE
  GH_RUN_LIST_OVERRIDE=$(jq -n --arg sha "$(git -C "$TMPDIR_TEST" rev-parse HEAD 2>/dev/null || echo unknown)" '[
    {workflowName:"CI", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:01Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"},
    {workflowName:"Deploy to GitHub Pages", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}
  ]')
}

# --- Hook runners ---
# Once the install has made its key (the recorder does it on the first recorded skill) every
# project needs a record, and a state the recorder did not seal counts for nothing
# (hooks/lib/integrity.sh). These scenarios write their fixtures directly, so each gate call is
# preceded by what a session start does: seal the state as it is and record the project as it is.
# shellcheck source=hooks/lib/integrity.sh
source "${REPO_ROOT}/hooks/lib/integrity.sh"
_integ_session() {
  [[ -f "${SB_RUNTIME_STATE_DIR}/seal.key" && -d "${TMPDIR_TEST:-}" ]] || return 0
  if [[ -n "${TMPSTATE:-}" && -f "$TMPSTATE" ]]; then sb_state_seal_write "$TMPSTATE"; fi
  sb_integrity_baseline "$(cd "$TMPDIR_TEST" && pwd -P)" session
  sb_integrity_forget
}
# _run_hook <hook file> <json>: run one hook from the isolated project directory with <json> on stdin.
# Prints the hook's stdout. Its exit status and stderr are kept in files under ${TMPDIR_TEST}.hookrun/
# (callers capture the output in a command substitution, so variables would be lost), keyed by a checksum
# of that stdout: assert_allowed looks up the run whose output it is given, so a later run of another hook
# cannot stand in for it (two runs with identical output share a key; the later one wins). A missing hook
# is status 127.
_run_hook() {
  local hook="$1" input="$2" st=0 out key meta="${TMPDIR_TEST}.hookrun" errf
  mkdir -p "$meta"
  errf="$meta/err.pending"
  if [[ ! -f "${HOOKS_DIR}/${hook}" ]]; then
    out=""
    st=127
    printf 'hook not found: %s/%s\n' "$HOOKS_DIR" "$hook" >"$errf"
  else
    out="$( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "${HOOKS_DIR}/${hook}" 2>"$errf" )" || st=$?
  fi
  key="$(printf '%s' "$out" | cksum | cut -d' ' -f1)"
  echo "$st" >"$meta/status.$key"
  mv -f "$errf" "$meta/err.$key"
  [[ -z "$out" ]] || printf '%s\n' "$out"
  return "$st"
}

# _hook_run_problem <output>: print why the hook run that produced <output> is not an "allow" (non-zero
# status, bash's own diagnostics on stderr); print nothing when it was clean or no hook run produced it.
_hook_run_problem() {
  local key statf errf st err
  key="$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
  statf="${TMPDIR_TEST}.hookrun/status.$key"
  errf="${TMPDIR_TEST}.hookrun/err.$key"
  [[ -f "$statf" ]] || return 0
  st="$(cat "$statf")"
  err="$(cat "$errf" 2>/dev/null || true)"
  rm -f "$statf" "$errf"
  if [[ "$st" != "0" ]]; then
    printf 'hook exited %s: %s' "$st" "${err:0:300}"
  elif grep -qE 'syntax error|unbound variable|command not found|bad substitution' <<<"$err"; then
    printf 'hook reported a shell error: %s' "${err:0:300}"
  fi
}

run_dev_cycle_edit() {
  _integ_session
  local event="$1" filepath="$2"
  local old_str="${3:-old content here long enough to exceed the small-edit bypass threshold value}"
  local new_str="${4:-new content here long enough to exceed the small-edit bypass threshold value}"
  local input
  input=$(jq -n --arg e "$event" --arg f "$filepath" --arg o "$old_str" --arg n "$new_str" \
    '{hook_event_name: $e, tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}')
  _run_hook dev-cycle-check.sh "$input"
}

run_completion_audit() {
  _integ_session
  local event="$1" cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook completion-audit.sh "$input"
}

run_stop_check() {
  _integ_session
  local event="${1:-Stop}"
  local input
  input=$(jq -n --arg e "$event" '{hook_event_name: $e}')
  _run_hook stop-check.sh "$input"
}

run_forbidden_skill() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PreToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  _run_hook forbidden-skill-check.sh "$input"
}

run_compliance_status() {
  local input='{"hook_event_name":"PostToolUse","tool_name":"Edit"}'
  _run_hook compliance-status.sh "$input"
}

run_record_skill() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  _run_hook record-skill.sh "$input"
  if [[ "$skill" == "verify-tests" ]]; then
    date +%s > "$VERIFY_TESTS_FILE"
  fi
}

run_prompt_reminder() {
  _integ_session
  local input='{"hook_event_name":"UserPromptSubmit","prompt":"hello"}'
  _run_hook prompt-reminder.sh "$input"
}

run_ci_status_check() {
  _integ_session
  local event="$1" cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook ci-status-check.sh "$input"
}

run_session_log_init() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook session-log-init.sh "$input"
}

run_session_start() {
  local input='{"hook_event_name":"SessionStart"}'
  _run_hook session-start "$input"
}

# --- Assertions ---
is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"' <<<"$output"
}

assert_blocked() {
  local label="$1" output="$2"
  _hook_run_problem "$output" >/dev/null
  if is_blocked "$output"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected block, got: %s)\n' "$label" "$output"
  fi
}

assert_allowed() {
  local label="$1" output="$2" problem
  problem="$(_hook_run_problem "$output")"
  if [[ -n "$problem" ]]; then
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected allow, but %s)\n' "$label" "$problem"
  elif ! is_blocked "$output"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected allow, got: %s)\n' "$label" "$output"
  fi
}

assert_contains() {
  local label="$1" output="$2" needle="$3"
  if grep -q "$needle" <<<"$output"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s (expected "%s" in: %s)\n' "$label" "$needle" "$output"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" needle="$3"
  if ! grep -q "$needle" <<<"$output"; then
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
  _run_hook uat-gate.sh "$input"
}

run_spec_floor_check() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook spec-floor-check.sh "$input"
}

run_phase_archive() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook phase-archive.sh "$input"
}

run_timeout_check() {
  local input='{"hook_event_name":"PostToolUse","tool_name":"Edit"}'
  _run_hook timeout-check.sh "$input"
}

run_pr_traceability() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook pr-traceability.sh "$input"
}

run_semantic_compress() {
  local skill="$1"
  local input
  input=$(jq -n --arg s "$skill" '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  _run_hook semantic-compress.sh "$input"
}

run_dev_cycle_bash() {
  _integ_session
  local event="$1" cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  _run_hook dev-cycle-check.sh "$input"
}

write_full_config() {
  local workflow="${1:-full-dev-cycle}"
  local config_version required_planning required_deploy all_tracked
  config_version=$(jq -r '.config_version' "$DEFAULT_CONFIG_TEMPLATE")
  if [[ "$workflow" == "devops-cycle" ]]; then
    required_planning=$(jq -c '.skills.required_planning_devops' "$DEFAULT_CONFIG_TEMPLATE")
    required_deploy=$(jq -c '.skills.required_deploy_devops' "$DEFAULT_CONFIG_TEMPLATE")
  else
    required_planning=$(jq -c '.skills.required_planning' "$DEFAULT_CONFIG_TEMPLATE")
    required_deploy=$(jq -c '.skills.required_deploy' "$DEFAULT_CONFIG_TEMPLATE")
  fi
  all_tracked=$(jq -c '.skills.all_tracked' "$DEFAULT_CONFIG_TEMPLATE")
  cat > "$TMPCFG" << EOCFG
{
  "config_version": "${config_version}",
  "sb_initiated": true,
  "sb_enforcement_tier": 2,
  "project": { "src_pattern": "/src/", "src_exclude_pattern": "__tests__|\\\\.test\\\\.", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ${required_planning},
    "required_deploy": ${required_deploy},
    "all_tracked": ${all_tracked}
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOCFG
}

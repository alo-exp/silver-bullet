#!/usr/bin/env bash
# Tests for hooks/completion-audit.sh
# Tests TWO-TIER enforcement: intermediate commits (planning only) vs final delivery (full check)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
# Enterprise policy human-deploy gate is on by default; tests assert delivery gates, not EP.
export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/completion-audit.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ${SB_RUNTIME_HOME_ROOT}/ due to security path validation in hooks.
SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
RELEASE_LIVE_MATRIX_FILE="${SB_TEST_DIR}/release-live-matrix"
E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
INLINE_E2E_MATRIX_FILE="${SB_TEST_DIR}/inline-e2e-matrix"
QUALITY_GATE_FILE="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state-${TEST_RUN_ID}"
SESSION_START_FILE="${SB_TEST_DIR}/test-session-start-${TEST_RUN_ID}"
VERIFY_TESTS_FILE="${SB_TEST_DIR}/verify-tests-state-${TEST_RUN_ID}"

cleanup_all() {
  rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  rm -f "$RELEASE_LIVE_MATRIX_FILE"
  rm -f "$E2E_LIVE_MATRIX_FILE"
  rm -f "$INLINE_E2E_MATRIX_FILE"
  rm -f "$QUALITY_GATE_FILE"
  rm -f "$SESSION_START_FILE"
  rm -f "$VERIFY_TESTS_FILE"
  unset GH_RUN_LIST_OVERRIDE
  unset SILVER_BULLET_SESSION_START_FILE
  unset SILVER_BULLET_VERIFY_TESTS_STATE_FILE
}
trap cleanup_all EXIT

write_cfg() {
  local workflow="${1:-full-dev-cycle}"
cat > "$TMPCFG" << EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "${workflow}" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","silver-review","requesting-code-review","receiving-code-review","finishing-a-development-branch","silver-create-release","verification-before-completion","test-driven-development","verify-tests"],
    "all_tracked": ["silver-quality-gates","silver-review","code-review"]
  },
  "release": {
    "require_plugin_runtime_matrix": true,
    "require_pre_release_quality_gate": true,
    "quality_gate_state_file": "${QUALITY_GATE_FILE}"
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

write_quality_gate_state() {
  cat > "$QUALITY_GATE_FILE" << 'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
}

write_verify_tests_state() {
  mkdir -p "$(dirname "$VERIFY_TESTS_FILE")"
  cat > "$VERIFY_TESTS_FILE" << 'EOF'
verified_at=2026-05-10T00:00:00Z
repo_root=/tmp/test
commands:
  - bash tests/run-all-tests.sh
EOF
}

seed_doc_scheme_marker() {
  mkdir -p "$TMPDIR_TEST/docs"
  cat > "$TMPDIR_TEST/docs/doc-scheme.md" << 'EOF'
# Doc Scheme

## When docs get updated

| Event | What updates |
|---|---|
| Every task | CHANGELOG.md, knowledge/YYYY-MM.md, learnings/YYYY-MM.md |
EOF
  cat > "$TMPDIR_TEST/docs/doc-scheme.json" << 'EOF'
{
  "version": 1,
  "sync": {
    "doc_scheme_md_path": "docs/doc-scheme.md",
    "task_checklist_path": "docs/task-doc-checklist.json"
  },
  "enforcement": {
    "enabled": true,
    "granularity_levels": [2, 3]
  },
  "mandatory_updated_docs": [
    "docs/CHANGELOG.md",
    "docs/knowledge/YYYY-MM.md",
    "docs/learnings/YYYY-MM.md",
    "docs/task-doc-checklist.json"
  ],
  "required_docs": [
    { "key": "docs/CHANGELOG.md", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/knowledge/YYYY-MM.md", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/learnings/YYYY-MM.md", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/task-doc-checklist.json", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/doc-scheme.md", "mandatory_updated": false, "required_sections": [] },
    { "key": "docs/doc-scheme.json", "mandatory_updated": false, "required_sections": [] }
  ],
  "preserved_mappings": [],
  "archive_moves": []
}
EOF
}

seed_doc_scheme_targets_current_month() {
  local month="$1"
  mkdir -p "$TMPDIR_TEST/docs/knowledge" "$TMPDIR_TEST/docs/learnings"
  cat > "$TMPDIR_TEST/docs/CHANGELOG.md" << 'EOF'
# Changelog
EOF
  cat > "$TMPDIR_TEST/docs/knowledge/${month}.md" << EOF
# Knowledge ${month}
EOF
  cat > "$TMPDIR_TEST/docs/learnings/${month}.md" << EOF
# Learnings ${month}
EOF
}

seed_doc_scheme_checklist_current_month() {
  local month="$1"
  mkdir -p "$TMPDIR_TEST/docs"
  cat > "$TMPDIR_TEST/docs/task-doc-checklist.json" << EOF
{
  "task_id": "test-doc-scheme-gate",
  "task_granularity": 3,
  "docs": {
    "docs/CHANGELOG.md": "updated",
    "docs/knowledge/YYYY-MM.md": "updated",
    "docs/learnings/YYYY-MM.md": "updated",
    "docs/task-doc-checklist.json": "updated",
    "docs/doc-scheme.md": "not-needed: scheme unchanged for this task",
    "docs/doc-scheme.json": "not-needed: scheme contract unchanged for this task",
    "docs/ARCHITECTURE.md": "not-needed: no architecture changes in this task",
    "docs/TESTING.md": "not-needed: no testing-doc changes in this task",
    "docs/knowledge/INDEX.md": "not-needed: no docs added or removed in this task",
    "README.md": "not-needed: not a release task",
    "CHANGELOG.md": "n/a: root changelog not used in this project"
  }
}
EOF
}

seed_evidence_validator_scripts() {
  mkdir -p "$TMPDIR_TEST/scripts/lib"
  cp "$REPO_ROOT/scripts/validate-evidence-findings.py" "$TMPDIR_TEST/scripts/"
  cp "$REPO_ROOT/scripts/validate-evidence-findings.sh" "$TMPDIR_TEST/scripts/"
  cp "$REPO_ROOT/scripts/lib/evidence_common.py" "$TMPDIR_TEST/scripts/lib/"
  chmod +x "$TMPDIR_TEST/scripts/validate-evidence-findings.sh"
}

seed_malformed_evidence_artifact() {
  mkdir -p "$TMPDIR_TEST/.planning/phases/056-test"
  cat > "$TMPDIR_TEST/.planning/phases/056-test/DOMAIN-AUDIT.md" <<'EOF'
# Domain Audit

## Findings

| domain | scope | severity | confidence | evidence | finding |
|--------|-------|----------|------------|----------|---------|
| code-health | src/app.ts | BLOCK | HIGH | src/app.ts:1 | missing required columns |
EOF
}

seed_delivery_ready_state() {
  cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
  write_verify_tests_state
}

add_contract_required_key() {
  local key="$1"
  python3 - "$TMPDIR_TEST/docs/doc-scheme.json" "$key" <<'PY'
import json
import sys
path = sys.argv[1]
key = sys.argv[2]
with open(path) as f:
    data = json.load(f)
required = data.setdefault("required_docs", [])
if not any(item.get("key") == key for item in required):
    required.append({"key": key, "mandatory_updated": False, "required_sections": []})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

setup() {
  # Isolate matrix/state paths per test so parallel harness runs cannot stomp
  # shared host-runtime release markers under ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/.
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/completion-audit-${TEST_RUN_ID}"
  mkdir -p "$SB_RUNTIME_STATE_DIR"
  SB_TEST_DIR="$SB_RUNTIME_STATE_DIR"
  RELEASE_LIVE_MATRIX_FILE="${SB_TEST_DIR}/release-live-matrix"
  E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
  INLINE_E2E_MATRIX_FILE="${SB_TEST_DIR}/inline-e2e-matrix"
  SESSION_START_FILE="${SB_TEST_DIR}/test-session-start-${TEST_RUN_ID}"
  VERIFY_TESTS_FILE="${SB_TEST_DIR}/verify-tests-state-${TEST_RUN_ID}"

  # Initialize git directly in TMPDIR_TEST so the hook finds .silver-bullet.json
  # before hitting the .git boundary (both are in the same directory).
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPGIT="$TMPDIR_TEST"   # git repo IS the project dir
  rm -f "$TMPSTATE"
  rm -f "$RELEASE_LIVE_MATRIX_FILE"
  rm -f "$E2E_LIVE_MATRIX_FILE"
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
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
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" config user.email "test@test.com"
  git -C "$TMPGIT" config user.name "Test"
  # Create initial commit so branch name is set
  touch "$TMPGIT/.gitkeep"
  git -C "$TMPGIT" add .gitkeep
  git -C "$TMPGIT" commit -q -m "init" 2>/dev/null || true
  git -C "$TMPGIT" checkout -q -b feature/test 2>/dev/null || true
  write_cfg "full-dev-cycle"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
  export SILVER_BULLET_QUALITY_GATE_STATE_FILE="$QUALITY_GATE_FILE"
  export SILVER_BULLET_SESSION_START_FILE="$SESSION_START_FILE"
  export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE"
  date +%s > "$SESSION_START_FILE"
  export GH_RUN_LIST_OVERRIDE=$(jq -n --arg sha "$(git -C "$TMPGIT" rev-parse HEAD 2>/dev/null || echo unknown)" '[
    {workflowName:"CI", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:01Z"},
    {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"},
    {workflowName:"Deploy to GitHub Pages", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}
  ]')
  mkdir -p "$(dirname "$QUALITY_GATE_FILE")"
  rm -f "$QUALITY_GATE_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  rm -f "$RELEASE_LIVE_MATRIX_FILE"
  rm -f "$E2E_LIVE_MATRIX_FILE"
  rm -f "$INLINE_E2E_MATRIX_FILE"
  rm -f "$SESSION_START_FILE"
  rm -rf "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/completion-audit-${TEST_RUN_ID}" 2>/dev/null || true
  unset SILVER_BULLET_SESSION_START_FILE
}

run_hook() {
  local event="$1"
  local cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  # Use subshell to prevent CWD leak into test script
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_exec_command() {
  local event="$1"
  local shell_cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$shell_cmd" \
    '{hook_event_name: $e, tool_name: "exec_command", tool_input: {command: ["bash", "-lc", $c]}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_exec_array() {
  local event="$1"
  local command_json="$2"
  local input
  input=$(jq -n --arg e "$event" --argjson c "$command_json" \
    '{hook_event_name: $e, tool_name: "exec_command", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  # A block occurs when output contains "block" decision or "deny" permissionDecision
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_blocked "$output"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}


assert_decoded_message_real_newlines() {
  # SB-BUG-B / #248: gate reason/message must decode to real newlines, not literal \n.
  local label="$1"
  local output="$2"
  local decoded
  decoded=$(printf '%s' "$output" | jq -r '
    .reason
    // .permissionDecisionReason
    // .hookSpecificOutput.permissionDecisionReason
    // .hookSpecificOutput.message
    // empty
  ' 2>/dev/null || true)
  if [[ -z "$decoded" ]]; then
    echo "  FAIL: $label — could not decode reason/message from: $output"
    FAIL=$((FAIL + 1))
    return
  fi
  if [[ "$decoded" != *$'\n'* ]]; then
    echo "  FAIL: $label — decoded text has no real newline characters"
    FAIL=$((FAIL + 1))
    return
  fi
  if printf '%s' "$decoded" | grep -qF '\n'; then
    echo "  FAIL: $label — decoded text still contains literal backslash-n"
    FAIL=$((FAIL + 1))
    return
  fi
  echo "  PASS: $label"
  PASS=$((PASS + 1))
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== completion-audit.sh tests ==="

# Test 1: Unrelated command passes silently
echo "--- Group 1: Command classification ---"
setup
out=$(run_hook "PreToolUse" "ls -la")
assert_passes "unrelated command passes" "$out"
teardown

# Test 2: git commit blocked without planning (intermediate tier, empty state)
setup
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_blocks "git commit blocked without silver-quality-gates" "$out"
assert_contains "block message mentions planning" "$out" "COMMIT BLOCKED"
assert_decoded_message_real_newlines "NEWLINE: planning-tier COMMIT BLOCKED uses real newlines not literal \\n" "$out"
teardown

setup
out=$(run_hook_exec_command "PreToolUse" "git commit -m 'test'")
assert_blocks "exec_command git commit blocked without silver-quality-gates" "$out"
assert_contains "exec_command block message mentions planning" "$out" "COMMIT BLOCKED"
teardown

setup
out=$(run_hook_exec_array "PreToolUse" '["git","commit","-m","test"]')
assert_blocks "direct exec_command git commit array blocked without silver-quality-gates" "$out"
assert_contains "direct exec_command block message mentions planning" "$out" "COMMIT BLOCKED"
teardown

# Test 3: git commit allowed with planning complete (intermediate tier)
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_passes "git commit allowed with silver-quality-gates done" "$out"
teardown

setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook_exec_array "PreToolUse" '["git","commit","-m","test"]')
assert_passes "direct exec_command git commit array allowed with silver-quality-gates done" "$out"
teardown

# Test 3b: git commit warns + allows when required planning skill is not installed anywhere invocable
setup
cat > "$TMPCFG" << 'EOF'
{
  "config_version": "CURRENT_CONFIG_VERSION",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["not-a-real-skill"],
    "required_deploy": ["not-a-real-skill"],
    "all_tracked": ["silver-quality-gates","silver-review","code-review"]
  },
  "state": { "state_file": "STATEFILE", "trivial_file": "TRIVIALFILE" }
}
EOF
sed -i.bak "s|CURRENT_CONFIG_VERSION|${CURRENT_CONFIG_VERSION}|g; s|STATEFILE|${TMPSTATE}|g; s|TRIVIALFILE|${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}|g" "$TMPCFG"
rm -f "${TMPCFG}.bak"
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_passes "git commit allowed when required planning skill is uninstalled" "$out"
assert_contains "warning mentions uninstalled planning skill" "$out" "not installed anywhere invocable"
teardown

# Test 4: git push blocked without planning
setup
out=$(run_hook "PreToolUse" "git push origin feature/test")
assert_blocks "git push blocked without silver-quality-gates" "$out"
teardown

# Test 5: git push allowed with planning — even without finalization skills
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "git push origin feature/test")
assert_passes "git push allowed with silver-quality-gates (no finalization needed)" "$out"
teardown

# Test 5b: rtk-wrapped git push still classified (RTK-aware gate regex)
setup
out=$(run_hook "PreToolUse" "rtk git push origin feature/test")
assert_blocks "rtk git push blocked without silver-quality-gates" "$out"
teardown

setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "RTK_DISABLED=1 git push origin feature/test")
assert_passes "RTK_DISABLED git push allowed with planning skill" "$out"
teardown

# Test 6: gh pr create blocked without full required_deploy
echo "--- Group 2: Final delivery tier ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"  # only planning done, not full workflow
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "gh pr create blocked with only silver-quality-gates" "$out"
assert_contains "block message mentions COMPLETION BLOCKED" "$out" "COMPLETION BLOCKED"
assert_decoded_message_real_newlines "NEWLINE: deploy-tier COMPLETION BLOCKED uses real newlines not literal \\n" "$out"
teardown

# Test 7: gh pr create passes with all required_deploy skills
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_passes "gh pr create passes with all required skills" "$out"
teardown

# Test 8: deploy command blocked
setup
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "npm run deploy")
assert_blocks "deploy command blocked without full workflow" "$out"
teardown

# Test 9: gh release create blocked without required workflow skills
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
EOF
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked without full workflow skills" "$out"
assert_contains "release block message mentions plugin runtime gate" "$out" "plugin-runtime release matrix"
teardown

# Test 10: gh release create blocked until live matrix runs
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
write_verify_tests_state
rm -f "$RELEASE_LIVE_MATRIX_FILE"
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked without shared live matrix marker" "$out"
assert_contains "release block mentions live matrix gate" "$out" "plugin-runtime release matrix"
assert_contains "release block mentions release matrix wrapper" "$out" "scripts/run-release-live-matrix.sh"
teardown

# Test 11: gh release create blocked until inline todo-app journey runs
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
write_verify_tests_state
rm -f "$E2E_LIVE_MATRIX_FILE"
rm -f "$INLINE_E2E_MATRIX_FILE"
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked without inline enterprise marker" "$out"
assert_contains "release block mentions enterprise-grade-test-app journey" "$out" "enterprise-grade-test-app journey"
assert_contains "release block mentions inline-e2e-matrix" "$out" "inline-e2e-matrix"
teardown

# Test 12: gh release create blocked until pre-release gate markers and full-suite rerun are recorded
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
write_verify_tests_state
rm -f "$QUALITY_GATE_FILE"
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked without pre-release gate markers" "$out"
assert_contains "release block mentions pre-release quality sequence" "$out" "pre-release quality sequence"
assert_contains "release block mentions adversarial marker" "$out" "adversarial-review-clean"
assert_contains "release block mentions sentinel marker" "$out" "sentinel-skills-clean"
teardown

# Test 12a: gh release create blocked when sentinel-skills-clean marker is missing
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
write_verify_tests_state
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked when sentinel-skills-clean marker missing" "$out"
assert_contains "partial gate block mentions sentinel-skills-clean" "$out" "sentinel-skills-clean"
teardown

# Test 12b: gh release create blocked when verify-tests is recorded but stale
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
rm -f "$VERIFY_TESTS_FILE"
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked when verify-tests freshness marker is missing" "$out"
assert_contains "release block mentions test gate stale" "$out" "TEST GATE STALE"
assert_contains "release block mentions verify-tests path" "$out" "verify-tests-state"
teardown

# Test 13: gh release create passes with all required workflow skills, both live markers, and gate markers
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "release passes with all required workflow skills, live markers, and gate markers" "$out"
teardown

# Test 13b: gh release create passes with codex-only live markers
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "release passes with codex-only live markers" "$out"
teardown

# Test 13b-b: gh release create passes with claude-only live markers
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=claude-only
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=claude-only
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "release passes with claude-only live markers" "$out"
teardown

# Test 13c: gh release create still passes with codex-only live markers when the legacy override is set
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
write_verify_tests_state
export SB_ALLOW_CODEX_ONLY_LIVE_RELEASE=1
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
unset SB_ALLOW_CODEX_ONLY_LIVE_RELEASE
assert_passes "release passes with codex-only live markers when legacy override is set" "$out"
teardown

# Test 13c-b: gh release create passes with cursor-smoke release marker + codex-only e2e
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=cursor-smoke
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=codex-only
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "release passes with cursor-smoke live markers" "$out"
teardown

# Test 13d: gh release create blocked when the latest CI run is still in progress
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
mkdir -p "$SB_TEST_DIR"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
cat > "$QUALITY_GATE_FILE" <<'EOF'
adversarial-review-clean
sentinel-skills-clean
quality-gate-stage-3
full-test-suite-rerun
EOF
write_verify_tests_state
export GH_RUN_LIST_OVERRIDE=$(jq -n --arg sha "$(git -C "$TMPDIR_TEST" rev-parse HEAD 2>/dev/null || echo unknown)" '[
  {workflowName:"CI", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:01Z"},
  {workflowName:"CI", status:"in_progress", conclusion:"", headSha:$sha, createdAt:"2026-05-07T00:00:05Z"},
  {workflowName:"Secret Scan", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:02Z"},
  {workflowName:"Deploy to GitHub Pages", status:"completed", conclusion:"success", headSha:$sha, createdAt:"2026-05-07T00:00:03Z"}
]')
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocks while the latest CI run is still in progress" "$out"
assert_contains "in-progress CI block mentions still running" "$out" "still running"
unset GH_RUN_LIST_OVERRIDE
teardown

# Test 14: finishing-a-development-branch NOT required when on main
echo "--- Group 3: Main branch handling ---"
setup
# Put all required skills EXCEPT finishing-a-development-branch
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
receiving-code-review
testing-strategy
documentation
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
verify-tests
EOF
mkdir -p "$SB_TEST_DIR"
touch "$RELEASE_LIVE_MATRIX_FILE"
write_verify_tests_state
# Ensure we're on main
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
out=$(run_hook "PreToolUse" "gh pr create --title 'hotfix'")
assert_passes "gh pr create passes on main without finishing-a-development-branch" "$out"
teardown

# Test 15: Code review stack ordering detected (GSD review before framing)
echo "--- Group 4: Ordering enforcement ---"
setup
# Put silver-review BEFORE requesting-code-review in the state file
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
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
verify-tests
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_contains "ordering issue blocks wrong sequence" "$out" "ORDERING BLOCKED"
assert_contains "ordering issue mentions wrong order" "$out" "wrong order"
teardown

# Test 16: Correct review-stack order passes cleanly
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_passes "correct review-stack order passes without ordering warning" "$out"
# Should NOT contain "wrong order"
if ! printf '%s' "$out" | grep -q "wrong order"; then
  echo "  ✅ no false ordering warning on correct sequence"
  PASS=$((PASS + 1))
else
  echo "  ❌ false ordering warning on correct sequence: $out"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 17: DevOps workflow uses silver-blast-radius for intermediate check
echo "--- Group 5: DevOps workflow ---"
setup
write_cfg "devops-cycle"
# With empty state, git commit should fail requiring silver-blast-radius + devops-quality-gates
out=$(run_hook "PreToolUse" "git commit -m 'infra'")
assert_blocks "devops: git commit blocked without silver-blast-radius/devops-quality-gates" "$out"
teardown

# Test 17b: devops-cycle uses required_deploy_devops list (not required_deploy)
setup
cat > "$TMPCFG" << EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "devops-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_planning_devops": ["silver-blast-radius", "devops-quality-gates"],
    "required_deploy": ["silver-quality-gates", "verify-tests"],
    "required_deploy_devops": ["silver-blast-radius", "devops-quality-gates", "silver-review", "silver-review-request", "silver-review-triage", "silver-branch-finish", "silver-completion-audit", "verify-tests"],
    "all_tracked": ["silver-quality-gates", "silver-blast-radius", "devops-quality-gates"]
  },
  "release": {
    "require_plugin_runtime_matrix": false,
    "require_pre_release_quality_gate": false,
    "quality_gate_state_file": "${QUALITY_GATE_FILE}"
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
echo "silver-quality-gates" > "$TMPSTATE"
write_verify_tests_state
mkdir -p "$TMPDIR_TEST/.planning/phases/001-test"
cat > "$TMPDIR_TEST/.planning/phases/001-test/001-REVIEW.md" <<'EOF'
# Review
## Findings
No issues found — review completed with evidence.
EOF
cat > "$TMPDIR_TEST/.planning/phases/001-test/001-VERIFICATION.md" <<'EOF'
# Verification
## Command output
```bash
$ npm test
PASS
```
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'infra'")
assert_blocks "devops: PR blocked when only product deploy skills recorded (uses required_deploy_devops)" "$out"
assert_contains "devops deploy list mentions silver-blast-radius" "$out" "silver-blast-radius"
teardown

# Test 18: Trivial file bypass
echo "--- Group 6: Bypass mechanisms ---"
setup
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook "PreToolUse" "git commit -m 'test'")
assert_passes "trivial file bypasses completion check" "$out"
teardown

# Test 19: gh pr merge blocked when skills missing (Tier 2 delivery gate)
echo "--- Group 7: gh pr merge delivery gate ---"
setup
# Only planning done
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook "PreToolUse" "gh pr merge --squash")
assert_blocks "gh pr merge blocked with only silver-quality-gates" "$out"
assert_contains "gh pr merge block mentions COMPLETION BLOCKED" "$out" "COMPLETION BLOCKED"
teardown

# Test 20: gh pr merge passes when all required skills present (review-loop-pass markers
# are NOT required — removed from required_deploy in v0.23.6 — but must not cause
# spurious failures if present in state (e.g. from a pre-upgrade session).
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh pr merge --squash")
assert_passes "gh pr merge passes with all required skills (no review-loop-pass needed)" "$out"
teardown

# ── Delivery doc-scheme gate (option 3) ──────────────────────────────────────
echo "--- Group 8: Delivery doc-scheme gate ---"

# Test 21: docs/doc-scheme.md present + missing checklist/docs blocks delivery
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
seed_doc_scheme_marker
write_verify_tests_state
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "doc-scheme gate blocks delivery when checklist and required docs are missing" "$out"
assert_contains "doc-scheme block message contains gate label" "$out" "DOC-SCHEME GATE"
teardown

# Test 22: stale docs/checklist (pre-session) block delivery
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
seed_doc_scheme_marker
write_verify_tests_state
current_month=$(date '+%Y-%m')
seed_doc_scheme_targets_current_month "$current_month"
seed_doc_scheme_checklist_current_month "$current_month"
sleep 1
date +%s > "$SESSION_START_FILE"
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "doc-scheme gate blocks stale checklist/docs" "$out"
assert_contains "stale doc-scheme block message contains stale marker" "$out" "Stale"
teardown

# Test 23: updated docs + checklist in current session allow delivery
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
seed_doc_scheme_marker
write_verify_tests_state
date +%s > "$SESSION_START_FILE"
current_month=$(date '+%Y-%m')
mkdir -p "$TMPDIR_TEST/docs/knowledge" "$TMPDIR_TEST/docs/learnings"
cat > "$TMPDIR_TEST/docs/CHANGELOG.md" << 'EOF'
# Changelog
EOF
cat > "$TMPDIR_TEST/docs/knowledge/${current_month}-a.md" << EOF
# Knowledge ${current_month}
EOF
cat > "$TMPDIR_TEST/docs/learnings/${current_month}-b.md" << EOF
# Learnings ${current_month}
EOF
seed_doc_scheme_checklist_current_month "$current_month"
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_passes "doc-scheme gate allows delivery when docs and checklist are updated this session" "$out"
teardown

# Test 23b: every concrete docs file must appear in checklist coverage
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
seed_doc_scheme_marker
write_verify_tests_state
date +%s > "$SESSION_START_FILE"
current_month=$(date '+%Y-%m')
mkdir -p "$TMPDIR_TEST/docs/knowledge" "$TMPDIR_TEST/docs/learnings"
cat > "$TMPDIR_TEST/docs/CHANGELOG.md" << 'EOF'
# Changelog
EOF
cat > "$TMPDIR_TEST/docs/knowledge/${current_month}.md" << EOF
# Knowledge ${current_month}
EOF
cat > "$TMPDIR_TEST/docs/learnings/${current_month}.md" << EOF
# Learnings ${current_month}
EOF
cat > "$TMPDIR_TEST/docs/EXTRA.md" << 'EOF'
# Extra governed doc
EOF
add_contract_required_key "docs/EXTRA.md"
seed_doc_scheme_checklist_current_month "$current_month"
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "doc-scheme gate blocks when a concrete docs file is missing from checklist" "$out"
assert_contains "missing checklist entry names extra doc" "$out" "docs/EXTRA.md"
teardown

# Test 24: evidence schema gate warns on delivery when finding tables drift (warn-first)
setup
seed_delivery_ready_state
seed_evidence_validator_scripts
seed_malformed_evidence_artifact
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "evidence schema gate blocks delivery by default when drift present" "$out"
assert_contains "evidence schema block label present" "$out" "EVIDENCE SCHEMA GATE"
teardown

# Test 25: evidence schema warn mode when strict disabled
setup
seed_delivery_ready_state
seed_evidence_validator_scripts
seed_malformed_evidence_artifact
out=$(SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=0 run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_passes "evidence schema gate allows delivery with warnings when strict false" "$out"
assert_contains "evidence schema warn message present" "$out" "EVIDENCE SCHEMA"
teardown

# Test 25b: evidence schema strict env override still blocks
setup
seed_delivery_ready_state
seed_evidence_validator_scripts
seed_malformed_evidence_artifact
out=$(SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "evidence schema strict mode blocks delivery on drift" "$out"
assert_contains "evidence schema strict block label" "$out" "EVIDENCE SCHEMA GATE"
teardown

# ── Composed-workflow gate (Pass 1: deferred — gate falls through to legacy) ──
# The legacy single-file `.planning/WORKFLOW.md` gate was retired (see
# completion-audit.sh for full rationale). v0.29.x replaces it with per-instance
# `.planning/workflows/<id>.md` files; Pass 2 will implement strict
# per-workflow gating. Pass 1 simply ignores WORKFLOW.md and all `.planning/
# workflows/*.md` files and falls through to the legacy required-skills gate.
echo ""
echo "=== Composed-workflow gate (Pass 1: WORKFLOW.md ignored) ==="

# WF-PASS1-A: a stale WORKFLOW.md showing all paths complete must NOT bypass
# the legacy required-skills gate when state is empty.
echo "--- WF-PASS1-A: stale WORKFLOW.md does not bypass empty-state legacy gate ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 13 | SHIP | complete |
WFEOF
# Empty state file (no skills recorded) — legacy gate would normally allow
# (zero state = no enforcement target), so the test specifically asserts that
# the stale WORKFLOW.md doesn't trigger a "delivery allowed" message. Use
# `gh pr create` so legacy completion path also fires.
out=$(run_hook "PreToolUse" "git commit -m test")
# Empty state = legacy gate exits 0 silently. Confirm the stale-WF message is
# NOT in the output (would prove the old gate is gone).
if printf '%s' "$out" | grep -q 'WORKFLOW\.md.*Intermediate commit allowed\|WORKFLOW\.md.*Delivery allowed'; then
  echo "  ❌ WF-PASS1-A: stale WORKFLOW.md still being read — Pass 1 hotfix incomplete"
  FAIL=$((FAIL+1))
else
  echo "  ✅ WF-PASS1-A: stale WORKFLOW.md correctly ignored"
  PASS=$((PASS+1))
fi
teardown

# WF-PASS1-B: `.planning/workflows/<id>.md` files (future format) are also
# ignored by Pass 1 — gate falls through to legacy required-skills check.
echo "--- WF-PASS1-B: workflows/ dir does not bypass legacy gate ---"
setup
write_cfg
mkdir -p "$TMPDIR_TEST/.planning/workflows"
cat > "$TMPDIR_TEST/.planning/workflows/20260428T015523Z-K4F7QA-silver-feature.md" << 'WFEOF'
**Composer:** /sb:feature
**Status:** active
### Flow Log
| # | Flow | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
WFEOF
# Empty state: missing silver-quality-gates → legacy gate must block git commit
echo > "$TMPSTATE"
out=$(run_hook "PreToolUse" "git commit -m test")
# With empty state, completion-audit's legacy gate exits 0 silently
# (see HOOK-04 empty-state behavior). The key assertion: no WORKFLOW.md
# message in the output proves Pass 1 hotfix is engaged.
if printf '%s' "$out" | grep -q 'flows complete\|Delivery allowed\|Intermediate commit allowed'; then
  echo "  ❌ WF-PASS1-B: workflows/ dir incorrectly bypassed legacy gate"
  FAIL=$((FAIL+1))
else
  echo "  ✅ WF-PASS1-B: workflows/ dir correctly ignored (Pass 2 will add gating)"
  PASS=$((PASS+1))
fi
teardown

# ── WF-PASS2: strict SB_WORKFLOW_ID-matched final-delivery gate ──────────────
# When `.planning/workflows/<id>.md` files are present AND the command is a
# final-delivery operation, completion-audit must require:
#   • SB_WORKFLOW_ID env var set
#   • value matches an active workflow file
#   • all Flow Log rows in that file marked complete
# Intermediate commits (`git commit`, `git push`) are unaffected — strict gate
# is final-delivery only.

# Helper to create an active workflow file with given flow rows
_make_workflow() {
  local id="$1"
  local rows="$2"
  mkdir -p "$TMPDIR_TEST/.planning/workflows"
  cat > "$TMPDIR_TEST/.planning/workflows/$id.md" << WFEOF
---
workflow_id: $id
composer: silver-feature
status: active
---
## Flow Log
| # | Path/Skill | Status | Started | Completed |
|---|------------|--------|---------|-----------|
$rows
WFEOF
}

# Full required-deploy state (used to isolate the strict gate from the legacy gate)
_full_state() {
  cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
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
EOF
}

echo "--- WF-PASS2-A: gh release create with no SB_WORKFLOW_ID is BLOCKED ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |"
unset SB_WORKFLOW_ID
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-A: missing SB_WORKFLOW_ID blocks release" "$out"
assert_contains "WF-PASS2-A: error names env var" "$out" "SB_WORKFLOW_ID"
teardown

echo "--- WF-PASS2-B: invalid SB_WORKFLOW_ID format is BLOCKED ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |"
out=$(SB_WORKFLOW_ID="../../etc/passwd" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-B: malformed id blocked" "$out"
assert_contains "WF-PASS2-B: error mentions invalid format" "$out" "invalid format"
teardown

echo "--- WF-PASS2-C: incomplete workflow blocks release ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |
| 2 | plan | pending | - | - |
| 3 | execute | pending | - | - |"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-C: incomplete workflow blocks" "$out"
assert_contains "WF-PASS2-C: error reports 1 of 3" "$out" "1 of 3"
teardown

echo "--- WF-PASS2-D: fully-complete workflow + full skills passes ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |
| 2 | plan | complete | - | now |
| 3 | execute | complete | - | now |
| 4 | ship | complete | - | now |"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
write_quality_gate_state
write_verify_tests_state
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-D: complete workflow + skills allows release" "$out"
teardown

echo "--- WF-PASS2-E: nonexistent SB_WORKFLOW_ID blocks ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | complete | - | now |"
out=$(SB_WORKFLOW_ID="20260101T000000Z-zzzzzz-silver-bugfix" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-E: id not matching any file blocks" "$out"
assert_contains "WF-PASS2-E: error mentions no match" "$out" "No active workflow file matches"
teardown

echo "--- WF-PASS2-F: intermediate commit unaffected by strict gate ---"
setup
# Only planning skill recorded (intermediate-tier requirement)
echo "silver-quality-gates" > "$TMPSTATE"
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | explore | pending | - | - |"
unset SB_WORKFLOW_ID
out=$(run_hook "PreToolUse" "git commit -m test")
assert_passes "WF-PASS2-F: incomplete workflow does not block git commit" "$out"
teardown

echo "--- WF-PASS2-G: no workflows dir → falls through to legacy gate ---"
setup
_full_state
# No .planning/workflows/ created
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
write_quality_gate_state
write_verify_tests_state
unset SB_WORKFLOW_ID
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-G: absent workflows dir → legacy gate (passes with full skills)" "$out"
teardown

echo "--- WF-PASS2-H: digit-row inflation guard — non-Flow-Log digit rows ignored ---"
# S4 regression guard: phase-iteration tables (e.g. | 01 | started | …) must
# NOT be counted as Flow Log rows. Only "^\| <digits> \|" rows count.
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
mkdir -p "$TMPDIR_TEST/.planning/workflows"
cat > "$TMPDIR_TEST/.planning/workflows/$ID.md" << 'WFEOF'
---
workflow_id: 20260428T120000Z-abc123-silver-feature
status: active
---
## Flow Log
| # | Path/Skill | Status | Started | Completed |
|---|------------|--------|---------|-----------|
| 1 | explore | complete | - | now |
| 2 | ship | complete | - | now |

## Phase Iterations (must NOT inflate counts)
| 01 | started | ... |
| 02 | finished | ... |

## Autonomous Decisions (must NOT inflate counts)
| 2026-04-28T12:00 | chose path A | ... |
WFEOF
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
write_quality_gate_state
write_verify_tests_state
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-H: extraneous digit rows ignored — release passes" "$out"
teardown

echo "--- WF-PASS2-I (#86): mixed complete+skipped workflow allows release ---"
# Issue #86: 'skipped' is a valid terminal state for non-applicable flows
# (e.g. FLOW 9 UI QUALITY for a CLI-only tool). Previously the count regex
# matched only 'complete', so skipped rows were treated as incomplete and
# blocked release indefinitely.
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | complete | - | now |
| 2 | orient    | skipped  | - | -   |
| 3 | explore   | skipped  | - | -   |
| 4 | plan      | complete | - | now |
| 5 | execute   | complete | - | now |
| 6 | ui-quality | skipped | - | -   |
| 7 | ship      | complete | - | now |"
cat > "$RELEASE_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$E2E_LIVE_MATRIX_FILE" <<'EOF'
matrix=full-claude-codex
EOF
cat > "$INLINE_E2E_MATRIX_FILE" <<'EOF'
matrix=inline-full-surface
EOF
write_quality_gate_state
write_verify_tests_state
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_passes "WF-PASS2-I (#86): mixed complete/skipped workflow allows release" "$out"
teardown

echo "--- WF-PASS2-K (#86): pending row still blocks (skipped fix didn't loosen) ---"
setup
_full_state
ID="20260428T120000Z-abc123-silver-feature"
rows=$(cat <<'WFROWS'
| 1 | bootstrap | complete | - | now |
| 2 | orient    | skipped  | - | -   |
| 3 | execute   | pending  | - | -   |
WFROWS
)
_make_workflow "$ID" "$rows"
out=$(SB_WORKFLOW_ID="$ID" run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "WF-PASS2-K (#86): pending row still blocks even with skipped present" "$out"
teardown

echo "--- WF-PASS2-L: inline SB_WORKFLOW_ID admits final delivery command ---"
setup
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | complete | - | now |
| 2 | execute | complete | - | now |
| 3 | release | complete | - | now |"
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
requesting-code-review
silver-review
receiving-code-review
finishing-a-development-branch
silver-create-release
verification-before-completion
test-driven-development
verify-tests
EOF
write_verify_tests_state
out=$(run_hook "PreToolUse" "SB_WORKFLOW_ID=$ID gh pr create --title 'feat'")
assert_passes "WF-PASS2-L: inline matching SB_WORKFLOW_ID allows final delivery" "$out"
teardown

echo "--- WF-PASS2-M: inline mismatched SB_WORKFLOW_ID still blocks final delivery ---"
setup
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | complete | - | now |"
out=$(run_hook "PreToolUse" "SB_WORKFLOW_ID=20260101T000000Z-zzzzzz-silver-bugfix gh pr create --title 'feat'")
assert_blocks "WF-PASS2-M: inline mismatched SB_WORKFLOW_ID blocks final delivery" "$out"
assert_contains "WF-PASS2-M: error mentions no match" "$out" "No active workflow file matches"
teardown

echo "--- WF-PASS2-N: SB adapter skill invocation is not classified as deploy delivery ---"
setup
ID="20260428T120000Z-abc123-silver-feature"
_make_workflow "$ID" "| 1 | bootstrap | complete | - | now |"
out=$(run_hook "PreToolUse" "${SB_RUNTIME_HOME_ROOT}/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/scripts/silver-bullet invoke-skill sb:ship 'Ship marker; user did not request push/PR/deploy.'")
assert_passes "WF-PASS2-N: plain silver-bullet invoke-skill sb:ship is not delivery-gated" "$out"
teardown


# ── #282 change-class delivery floor ──────────────────────────────────────────
echo "--- #282: docs-only PR uses light required_deploy subset ---"
setup
mkdir -p "$TMPDIR_TEST/docs"
echo "# notes" > "$TMPDIR_TEST/docs/notes.md"
git -C "$TMPDIR_TEST" add docs/notes.md
git -C "$TMPDIR_TEST" commit -q -m "docs only"
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-context
silver-plan
silver-completion-audit
finishing-a-development-branch
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'docs'")
assert_passes "#282 docs-only PR passes with light floor (no tdd/verify-tests)" "$out"
if printf '%s' "$out" | grep -qE "tdd|verify-tests|test-driven-development|silver-execute"; then
  echo "  FAIL: docs-only still demanding src skills"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: docs-only does not demand tdd/verify-tests/execute"
  PASS=$((PASS + 1))
fi
teardown

echo "--- #282: src change still requires full required_deploy ---"
setup
mkdir -p "$TMPDIR_TEST/src"
echo "console.log(1)" > "$TMPDIR_TEST/src/app.js"
git -C "$TMPDIR_TEST" add src/app.js
git -C "$TMPDIR_TEST" commit -q -m "src change"
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-context
silver-plan
silver-completion-audit
finishing-a-development-branch
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'feat'")
assert_blocks "#282 src PR blocked without full required_deploy" "$out"
assert_contains "#282 src PR reports change class" "$out" "Change class:"
teardown

echo "--- #282: config-only PR uses light floor ---"
setup
git -C "$TMPDIR_TEST" add .silver-bullet.json silver-bullet.md
git -C "$TMPDIR_TEST" commit -q -m "config baseline" 2>/dev/null || true
python3 - "$TMPDIR_TEST/.silver-bullet.json" <<'PY'
import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["compactPrompt"]="config-only-change"
json.dump(d, open(p,"w"), indent=2)
PY
git -C "$TMPDIR_TEST" add .silver-bullet.json
git -C "$TMPDIR_TEST" commit -q -m "config tweak"
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-context
silver-plan
silver-completion-audit
finishing-a-development-branch
EOF
out=$(run_hook "PreToolUse" "gh pr create --title 'config'")
assert_passes "#282 config-only PR passes with light floor" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

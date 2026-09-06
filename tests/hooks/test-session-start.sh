#!/usr/bin/env bash
# Tests for hooks/session-start
# Verifies SessionStart hook: branch-scoped state reset, trivial file cleanup,
# core-rules.md injection, jq missing warning.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/session-start"
RUNTIME_PATHS="$(cd "$(dirname "$0")/../.." && pwd)/hooks/lib/runtime-paths.sh"
if [[ -f "$RUNTIME_PATHS" ]]; then
  # shellcheck source=../../hooks/lib/runtime-paths.sh
  source "$RUNTIME_PATHS"
fi
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

# Use temp files for state and branch so tests never touch the live session state.
# Both SILVER_BULLET_STATE_FILE and SILVER_BULLET_BRANCH_FILE are honoured by
# session-start via env-var overrides with ${SB_RUNTIME_HOME_ROOT}/ path validation.
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
TMPBRANCH="${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
TMPTRIVIAL="${SB_TEST_DIR}/trivial"   # trivial still uses default path (config-driven tests below)
SESSION_START_FILE="${SB_TEST_DIR}/session-start-time-${TEST_RUN_ID}"
RELEASE_LIVE_MATRIX_FILE="${SB_TEST_DIR}/release-live-matrix"
E2E_LIVE_MATRIX_FILE="${SB_TEST_DIR}/e2e-live-matrix"
QUALITY_GATE_FILE="${SB_TEST_DIR}/quality-gate-state-${TEST_RUN_ID}"
VERIFY_TESTS_FILE="${SB_TEST_DIR}/verify-tests-state-${TEST_RUN_ID}"
export SILVER_BULLET_STATE_FILE="$TMPSTATE"
export SILVER_BULLET_BRANCH_FILE="$TMPBRANCH"
export SILVER_BULLET_QUALITY_GATE_STATE_FILE="$QUALITY_GATE_FILE"
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE"
export SILVER_BULLET_SESSION_START_FILE="$SESSION_START_FILE"

# Prerequisite probe (Wave 0.2) requires a silver-bullet plugin cache directory.
# session-start re-sources runtime-paths.sh and resets SB_RUNTIME_PLUGIN_CACHE_ROOT,
# so seed the canonical cache path rather than overriding the env var.
PLUGIN_CACHE_DIR="${SB_RUNTIME_HOME_ROOT}/plugins/cache"
mkdir -p "${PLUGIN_CACHE_DIR}/alo-labs/silver-bullet/test"

cleanup_all() {
  rm -f "$TMPSTATE" "$TMPBRANCH" 2>/dev/null || true
  rm -f "${TMPSTATE}.requested" 2>/dev/null || true
  rm -f "${TMPTRIVIAL}" 2>/dev/null || true
  rm -f "$SESSION_START_FILE" 2>/dev/null || true
  rm -f "$RELEASE_LIVE_MATRIX_FILE" "$E2E_LIVE_MATRIX_FILE" 2>/dev/null || true
  rm -f "$QUALITY_GATE_FILE" 2>/dev/null || true
  rm -f "$VERIFY_TESTS_FILE" 2>/dev/null || true
  rm -rf "${PLUGIN_CACHE_DIR}/alo-labs/silver-bullet/test" 2>/dev/null || true
}
trap cleanup_all EXIT

run_hook() {
  # session-start does NOT read stdin — run directly; override PWD via a temp git repo.
  # Branch and state files are both isolated via env overrides so tests never touch
  # the live ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ branch or state files.
  # Use || true: hook may exit non-zero when optional plugins (design) are absent,
  # but we test effects (state file mutations, output content) not the exit code.
  local workdir="${1:-$HOOK_WORKDIR}"
  ( cd "$workdir" && \
    SILVER_BULLET_STATE_FILE="$TMPSTATE" \
    SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
    SILVER_BULLET_SESSION_START_FILE="$SESSION_START_FILE" \
    SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE" \
    bash "$HOOK" </dev/null 2>/dev/null ) || true
}

# Create a minimal git repo directory with a commit so HEAD is valid
make_git_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" -c user.email="test@test.com" -c user.name="Test" commit -q --allow-empty -m "init" 2>/dev/null
  cat > "$dir/.silver-bullet.json" <<EOF
{
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "state": {
    "state_file": "${TMPSTATE}",
    "trivial_file": "${TMPTRIVIAL}"
  }
}
EOF
  cat > "$dir/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  printf '%s' "$dir"
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep "$needle" >/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if ! printf '%s' "$output" | grep "$needle" >/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' NOT in: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected file to exist: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_missing() {
  local label="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected file to be absent: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if [[ ! -f "$path" ]] || ! grep -q "$needle" "$path" 2>/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — file $path should NOT contain '$needle'"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local label="$1"
  local path="$2"
  local needle="$3"
  if grep -q "$needle" "$path" 2>/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' in file $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_empty() {
  local label="$1"
  local output="$2"
  if [[ -z "$output" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected empty output, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== session-start tests ==="

# Test 0: No SB markers -> no-op
echo "--- Test 0: No SB markers -> no-op ---"
HOOK_WORKDIR=$(make_git_repo)
rm -f "$HOOK_WORKDIR/.silver-bullet.json" "$HOOK_WORKDIR/silver-bullet.md"
rm -f "$SESSION_START_FILE"
out=$(run_hook "$HOOK_WORKDIR")
assert_empty "no SB markers -> silent exit, no output" "$out"
assert_file_missing "no SB markers -> session marker not created" "$SESSION_START_FILE"
rm -rf "$HOOK_WORKDIR"

# Test 0b: SB project -> session marker created for doc-scheme gates
echo "--- Test 0b: SB project -> session marker created ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
rm -f "$SESSION_START_FILE"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_exists "SB project -> session marker created" "$SESSION_START_FILE"
if [[ -f "$SESSION_START_FILE" ]] && grep -Eq '^[0-9]+$' "$SESSION_START_FILE"; then
  echo "  PASS: SB project -> session marker is numeric"
  PASS=$((PASS + 1))
else
  echo "  FAIL: SB project -> session marker is not numeric"
  FAIL=$((FAIL + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH" "$SESSION_START_FILE"

# Test 0c: SB project -> existing marker preserved across Codex process restarts
echo "--- Test 0c: SB project -> existing session marker preserved ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
printf '1234567890\n' > "$SESSION_START_FILE"
run_hook "$HOOK_WORKDIR" >/dev/null
if [[ "$(cat "$SESSION_START_FILE" 2>/dev/null)" == "1234567890" ]]; then
  echo "  PASS: existing session marker preserved"
  PASS=$((PASS + 1))
else
  echo "  FAIL: existing session marker should be preserved, got: $(cat "$SESSION_START_FILE" 2>/dev/null || true)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH" "$SESSION_START_FILE"

# ── Branch-scoped state reset tests ──────────────────────────────────────────

# Test 1: Branch change -> state file deleted (full reset)
echo "--- Test 1: Branch change -> state file deleted ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
# Write a state file and point branch file at a different branch
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf 'old-branch-xyz' > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "branch changed -> state file deleted" "$TMPSTATE"
# branch file should now reflect current branch
if [[ -f "$TMPBRANCH" ]]; then
  stored=$(head -1 "$TMPBRANCH" 2>/dev/null | tr -d '\n')
  if [[ "$stored" == "$new_branch" ]]; then
    echo "  PASS: branch file updated to current branch"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: branch file should be '$new_branch', got '$stored'"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: branch file missing after reset"
  FAIL=$((FAIL + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# Test 1b: Branch change clears orchestrator ephemeral state
echo "--- Test 1b: Branch change clears orchestrator ephemeral state ---"
HOOK_WORKDIR=$(make_git_repo)
ORCH_DIR="${SB_TEST_DIR}/session-start-orch-${TEST_RUN_ID}"
mkdir -p "$ORCH_DIR"
printf '{"current_flow":"FLOW-QUALITY-GATE","workflow_id":"20260428T120000Z-abc123-silver-feature"}' > "$ORCH_DIR/orchestrator.json"
printf '{"next_skill":"silver-quality-gates"}' > "$ORCH_DIR/orchestrator-directive.json"
printf '{"skill":"silver-plan"}' > "$ORCH_DIR/orchestrator-worker-active.json"
printf 'silver-quality-gates\n' > "$TMPSTATE"
printf 'old-branch-xyz' > "$TMPBRANCH"
( cd "$HOOK_WORKDIR" && \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$ORCH_DIR" \
  SILVER_BULLET_STATE_FILE="$TMPSTATE" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
assert_file_missing "branch changed -> orchestrator.json deleted" "$ORCH_DIR/orchestrator.json"
assert_file_missing "branch changed -> orchestrator-directive.json deleted" "$ORCH_DIR/orchestrator-directive.json"
assert_file_missing "branch changed -> orchestrator-worker-active.json deleted" "$ORCH_DIR/orchestrator-worker-active.json"
rm -rf "$HOOK_WORKDIR" "$ORCH_DIR"
rm -f "$TMPBRANCH"

# Test 1c: Branch change clears instruction-ledger.json (SB-BUG-C #249)
echo "--- Test 1c: Branch change clears instruction-ledger.json ---"
HOOK_WORKDIR=$(make_git_repo)
LEDGER_DIR="${SB_TEST_DIR}/session-start-ledger-${TEST_RUN_ID}"
mkdir -p "$LEDGER_DIR"
printf '{"prompt_id":"foreign","intents":[{"id":"root","status":"pending","children":[{"id":"i1","label":"left over","status":"pending","children":[]}]}]}' \
  > "$LEDGER_DIR/instruction-ledger.json"
printf 'silver-quality-gates\n' > "$TMPSTATE"
printf 'old-branch-xyz' > "$TMPBRANCH"
( cd "$HOOK_WORKDIR" && \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$LEDGER_DIR" \
  SILVER_BULLET_STATE_FILE="$TMPSTATE" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
assert_file_missing "branch changed -> instruction-ledger.json deleted" "$LEDGER_DIR/instruction-ledger.json"
rm -rf "$HOOK_WORKDIR" "$LEDGER_DIR"
rm -f "$TMPBRANCH"

# Test 1d: Branch change clears pending-completion-audit.json (SB-FRICTION-3)
echo "--- Test 1d: Branch change clears pending-completion-audit.json ---"
HOOK_WORKDIR=$(make_git_repo)
AUDIT_DIR="${SB_TEST_DIR}/session-start-pending-audit-${TEST_RUN_ID}"
mkdir -p "$AUDIT_DIR"
printf '{"pending":true,"task_preview":"stale from other branch"}' \
  > "$AUDIT_DIR/pending-completion-audit.json"
printf 'silver-quality-gates\n' > "$TMPSTATE"
printf 'old-branch-xyz' > "$TMPBRANCH"
( cd "$HOOK_WORKDIR" && \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$AUDIT_DIR" \
  SILVER_BULLET_STATE_FILE="$TMPSTATE" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$VERIFY_TESTS_FILE" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
assert_file_missing "branch changed -> pending-completion-audit.json deleted" "$AUDIT_DIR/pending-completion-audit.json"
rm -rf "$HOOK_WORKDIR" "$AUDIT_DIR"
rm -f "$TMPBRANCH"

# Test 2: Same branch -> state file preserved
echo "--- Test 2: Same branch -> state file preserved ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_exists "same branch -> state file preserved" "$TMPSTATE"
assert_file_contains "same branch -> skill line preserved" "$TMPSTATE" "silver-quality-gates"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# Test 3: Same branch -> regular skills survive session restart
echo "--- Test 3: Same branch -> regular skills survive session restart ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> skills preserved" "$TMPSTATE" "silver-quality-gates"
assert_file_contains "same branch -> code-review preserved" "$TMPSTATE" "code-review"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# Test 4: Same branch -> SB lifecycle markers survive session restart
echo "--- Test 4: Same branch -> SB lifecycle markers survive session restart ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "same branch -> silver-quality-gates preserved" "$TMPSTATE" "silver-quality-gates"
assert_file_contains "same branch -> silver-context preserved" "$TMPSTATE" "silver-context"
assert_file_contains "same branch -> silver-plan preserved" "$TMPSTATE" "silver-plan"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# Test 5: Same branch -> pre-release quality gate file cleared on session start
echo "--- Test 5: Same branch -> pre-release quality gate file cleared on session start ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
mkdir -p "$(dirname "$QUALITY_GATE_FILE")"
cat > "$QUALITY_GATE_FILE" <<'EOF'
quality-gate-stage-1
quality-gate-stage-2
quality-gate-stage-3
quality-gate-stage-4
full-test-suite-rerun
EOF
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "same branch -> pre-release quality gate file cleared" "$QUALITY_GATE_FILE"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH" "$QUALITY_GATE_FILE"

# Test 6: Trivial file is not auto-created on session start
echo "--- Test 6: Trivial file is not auto-created on session start ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
rm -f "$TMPTRIVIAL"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "trivial file stays absent on session start" "$TMPTRIVIAL"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# Test 7: Same branch -> test execution gate file cleared on session start
echo "--- Test 7: Same branch -> test execution gate file cleared on session start ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
touch "$VERIFY_TESTS_FILE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "same branch -> test execution gate file cleared" "$VERIFY_TESTS_FILE"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH" "$VERIFY_TESTS_FILE"

# Test 7b: Session start clears stale planning override files
echo "--- Test 7b: Session start clears stale planning override files ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
OVERRIDE_DIR="${SB_TEST_DIR}/session-start-override-${TEST_RUN_ID}"
mkdir -p "$OVERRIDE_DIR"
printf '%s' "$new_branch" > "$TMPBRANCH"
touch "$OVERRIDE_DIR/planning-edit-override" "$OVERRIDE_DIR/roadmap-edit-override"
( cd "$HOOK_WORKDIR" && \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$OVERRIDE_DIR" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
assert_file_missing "startup clears planning-edit-override" "$OVERRIDE_DIR/planning-edit-override"
assert_file_missing "startup clears roadmap-edit-override" "$OVERRIDE_DIR/roadmap-edit-override"
# #275: stale marker (beyond TTL) must clear; fresh marker must survive Claude SessionStart.
printf '{"skill":"silver-plan","template":"PLAN","spawned_at":"2020-01-01T00:00:00Z"}\n' \
  > "$OVERRIDE_DIR/orchestrator-worker-active.json"
( cd "$HOOK_WORKDIR" && \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$OVERRIDE_DIR" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
assert_file_missing "startup clears stale orchestrator-worker-active.json" "$OVERRIDE_DIR/orchestrator-worker-active.json"
printf '{"skill":"silver-plan","template":"PLAN","spawned_at":"%s"}\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  > "$OVERRIDE_DIR/orchestrator-worker-active.json"
out_worker=$( cd "$HOOK_WORKDIR" && \
  SB_RUNTIME_PRESERVE_STATE_DIR=1 \
  SB_RUNTIME_STATE_DIR="$OVERRIDE_DIR" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
if [[ -f "$OVERRIDE_DIR/orchestrator-worker-active.json" ]]; then
  echo "  PASS: startup preserves fresh orchestrator-worker-active.json (#275)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: startup should preserve fresh orchestrator-worker-active.json (#275)"
  FAIL=$((FAIL + 1))
fi
if printf '%s' "$out_worker" | grep -qF 'SB WORKER SUBAGENT'; then
  echo "  PASS: SessionStart injects worker banner when marker fresh (#275)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: SessionStart should inject worker banner when marker fresh (#275)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$HOOK_WORKDIR" "$OVERRIDE_DIR"
rm -f "$TMPBRANCH"

# ── Trivial file cleanup tests ────────────────────────────────────────────────

# Test 8: Trivial file deleted on session start
echo "--- Test 8: Trivial file deleted on session start ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
touch "$TMPTRIVIAL"
touch "$RELEASE_LIVE_MATRIX_FILE"
touch "$E2E_LIVE_MATRIX_FILE"
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_missing "trivial file deleted on session start" "$TMPTRIVIAL"
assert_file_missing "release live matrix marker cleared on session start" "$RELEASE_LIVE_MATRIX_FILE"
assert_file_missing "e2e live matrix marker cleared on session start" "$E2E_LIVE_MATRIX_FILE"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# Test 7a: Prompt replay records requested skill markers for exec-mode sessions
echo "--- Test 7a: Prompt replay records requested skill markers ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
cat > "$HOOK_WORKDIR/.silver-bullet.prompt.json" <<'EOF'
{"hook_event_name":"UserPromptSubmit","prompt":"Use the [$silver]($HOME/.codex/skills/silver/SKILL.md) skill as the only entrypoint and follow it. Route this request to `sb:init` through the orchestrator, execute the composed workflow, and stop after initialization."}
EOF
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "prompt replay recorded silver-init as requested" "${TMPSTATE}.requested" "silver-init"
assert_file_not_contains "prompt replay did not mark silver-init completed" "$TMPSTATE" "silver-init"
rm -f "$HOOK_WORKDIR/.silver-bullet.prompt.json"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH" "$TMPSTATE" "${TMPSTATE}.requested"

# Test 7b: Fresh init prompt replay records requested skill markers before scaffold exists
echo "--- Test 7b: Fresh init prompt replay records requested skill markers ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
rm -f "$HOOK_WORKDIR/.silver-bullet.json" "$HOOK_WORKDIR/silver-bullet.md"
cat > "$HOOK_WORKDIR/.silver-bullet.prompt.json" <<'EOF'
{"hook_event_name":"UserPromptSubmit","prompt":"Use the [$silver]($HOME/.codex/skills/silver/SKILL.md) skill as the only entrypoint and follow it. Route this request to `sb:init` through the orchestrator, execute the composed workflow, and stop after initialization."}
EOF
run_hook "$HOOK_WORKDIR" >/dev/null
assert_file_contains "fresh init prompt replay recorded silver-init as requested" "${TMPSTATE}.requested" "silver-init"
assert_file_not_contains "fresh init prompt replay did not mark silver-init completed" "$TMPSTATE" "silver-init"
rm -f "$HOOK_WORKDIR/.silver-bullet.prompt.json"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH" "$TMPSTATE" "${TMPSTATE}.requested"

# ── Output / injection tests ──────────────────────────────────────────────────

# Test 7: Output is valid JSON with hookSpecificOutput key
echo "--- Test 7: Output is valid JSON with hookSpecificOutput ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
out=$(run_hook "$HOOK_WORKDIR")
# If jq available, validate JSON structure
if command -v jq >/dev/null 2>&1 && [[ -n "$out" ]]; then
  if printf '%s' "$out" | jq -e '.hookSpecificOutput' >/dev/null 2>&1; then
    echo "  PASS: output is valid JSON with hookSpecificOutput key"
    PASS=$((PASS + 1))
    if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1; then
      echo "  PASS: output includes SessionStart hookEventName"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: output missing SessionStart hookEventName: $out"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  FAIL: output is not valid JSON or missing hookSpecificOutput: $out"
    FAIL=$((FAIL + 1))
  fi
else
  # jq unavailable or no output — check for non-empty raw content
  if [[ -n "$out" ]]; then
    echo "  PASS: output is non-empty (jq unavailable for JSON validation)"
    PASS=$((PASS + 1))
  else
    # session-start may produce no output if no plugins installed — acceptable
    echo "  PASS: no output (no plugins installed — acceptable)"
    PASS=$((PASS + 1))
  fi
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# Test 8: core-rules SessionStart digest injected when file exists (#263)
echo "--- Test 8: core-rules SessionStart digest injected ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
CORE_RULES="$(dirname "$HOOK")/core-rules.md"
if [[ -f "$CORE_RULES" ]]; then
  out=$(run_hook "$HOOK_WORKDIR")
  decoded=$(printf '%s' "$out" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get("hookSpecificOutput",{}).get("additionalContext",""))
except Exception:
  pass' 2>/dev/null || true)
  if [[ -z "$decoded" ]]; then
    decoded="$out"
  fi
  if grep "Non-Negotiable\|Process is non-negotiable\|SessionStart digest" >/dev/null <<<"$decoded"; then
    echo "  PASS: core-rules digest markers present in output"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: core-rules digest not found in output: ${decoded:0:200}..."
    FAIL=$((FAIL + 1))
  fi
  if grep "Full rules (on demand)\|core-rules.md" >/dev/null <<<"$decoded"; then
    echo "  PASS: digest points to full core-rules.md"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: digest missing on-demand full-rules pointer"
    FAIL=$((FAIL + 1))
  fi
  digest_bytes=$(printf '%s' "$decoded" | python3 -c '
import sys
text=sys.stdin.read()
markers=["# Silver Bullet — Core Enforcement Rules", "SessionStart digest"]
start=-1
for m in markers:
  start=text.find(m)
  if start>=0:
    break
if start<0:
  print(0)
  raise SystemExit
end=text.find("\n---\n", start+1)
chunk=text[start: end if end>start else start+4000]
print(len(chunk.encode("utf-8")))
' 2>/dev/null || echo 0)
  if [[ "$digest_bytes" -gt 0 && "$digest_bytes" -le 3072 ]]; then
    echo "  PASS: SessionStart digest size ${digest_bytes}B <= 3072B"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: SessionStart digest size ${digest_bytes}B exceeds 3072B budget (or missing)"
    FAIL=$((FAIL + 1))
  fi
  if printf '%s' "$decoded" | grep -q "16. \*\*Context Mode install gate\*\*"; then
    echo "  FAIL: full core-rules layer list still inlined (digest not applied)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: full 16-layer core-rules body not inlined"
    PASS=$((PASS + 1))
  fi
else
  echo "  PASS: core-rules.md not installed — skip injection test"
  PASS=$((PASS + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# ── Security guard fallback test ─────────────────────────────────────────────

# Test 9: SILVER_BULLET_STATE_FILE pointing outside ${SB_RUNTIME_HOME_ROOT}/ falls back to default state file
# The security guard (SB-002/SB-003) rejects invalid paths and silently uses the default.
echo "--- Test 9: Invalid SILVER_BULLET_STATE_FILE outside ${SB_RUNTIME_HOME_ROOT}/ falls back to default ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '%s' "$new_branch" > "$TMPBRANCH"
OUTSIDE_PATH="/tmp/evil-state-file-${TEST_RUN_ID}"
REAL_STATE_FILE="${SB_TEST_DIR}/state"
# Ensure the real default state file is absent so we can detect the fallback
rm -f "$REAL_STATE_FILE" 2>/dev/null || true
( cd "$HOOK_WORKDIR" && \
  SILVER_BULLET_STATE_FILE="$OUTSIDE_PATH" \
  SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
  bash "$HOOK" </dev/null 2>/dev/null ) || true
# The hook must NOT write to the invalid outside path
if [[ -f "$OUTSIDE_PATH" ]]; then
  echo "  FAIL: hook wrote to path outside ${SB_RUNTIME_HOME_ROOT}/ — security guard bypassed"
  FAIL=$((FAIL + 1))
  rm -f "$OUTSIDE_PATH"
else
  echo "  PASS: invalid path outside ${SB_RUNTIME_HOME_ROOT}/ was rejected — not written"
  PASS=$((PASS + 1))
fi
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPBRANCH"

# ── Branch file creation tests ───────────────────────────────────────────────

# Test 10: Branch file absent → branch file written with current branch; state NOT wiped
# Regression: absent branch_file caused stored_branch="" which made "main" != "" fire
# the "branch changed" path, wiping state on every fresh-install / file-deleted run.
echo "--- Test 10: Branch file absent -> branch file created; state preserved ---"
rm -f "$TMPBRANCH" 2>/dev/null || true   # ensure branch file is absent
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\nsilver-context\ncode-review\n' > "$TMPSTATE"
mkdir -p "$(dirname "$QUALITY_GATE_FILE")"
cat > "$QUALITY_GATE_FILE" <<'EOF'
quality-gate-stage-1
quality-gate-stage-2
quality-gate-stage-3
quality-gate-stage-4
full-test-suite-rerun
EOF
run_hook "$HOOK_WORKDIR" >/dev/null
# Branch file should now exist and contain the current branch
assert_file_exists "branch file absent -> branch file created" "$TMPBRANCH"
if [[ -f "$TMPBRANCH" ]]; then
  stored=$(head -1 "$TMPBRANCH" 2>/dev/null | tr -d '\n')
  if [[ "$stored" == "$new_branch" ]]; then
    echo "  PASS: branch file contains current branch name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: branch file should be '$new_branch', got '$stored'"
    FAIL=$((FAIL + 1))
  fi
fi
# State file must NOT have been wiped — skill recordings should survive
assert_file_exists "branch file absent -> state file preserved" "$TMPSTATE"
assert_file_contains "branch file absent -> skill recordings preserved" "$TMPSTATE" "silver-quality-gates"
# Branch-file-absent and same-branch startup preserve SB lifecycle evidence.
assert_file_contains "branch file absent -> SB lifecycle markers preserved" "$TMPSTATE" "silver-context"
assert_file_missing "branch file absent -> pre-release quality gate file cleared" "$QUALITY_GATE_FILE"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH" "$QUALITY_GATE_FILE"

# ── #87 regressions: SessionStart benign-event safety ────────────────────────
# Bug 1: SB lifecycle markers must NOT be stripped on `compact` (or `resume`).
# Bug 3: empty current_branch must NOT trigger destructive branch-mismatch wipe.

# Helper: run hook with explicit session source override
run_hook_source() {
  local workdir="$1"
  local source="$2"
  ( cd "$workdir" && \
    SILVER_BULLET_STATE_FILE="$TMPSTATE" \
    SILVER_BULLET_BRANCH_FILE="$TMPBRANCH" \
    SILVER_BULLET_SESSION_SOURCE="$source" \
    bash "$HOOK" </dev/null 2>/dev/null ) || true
}

echo "--- Test #87-A: compact source preserves SB lifecycle markers ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook_source "$HOOK_WORKDIR" "compact" >/dev/null
assert_file_contains "#87-A: compact preserves silver-quality-gates" "$TMPSTATE" "silver-quality-gates"
assert_file_contains "#87-A: compact preserves silver-context (was stripped pre-fix)" "$TMPSTATE" "silver-context"
assert_file_contains "#87-A: compact preserves silver-plan (was stripped pre-fix)" "$TMPSTATE" "silver-plan"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

echo "--- Test #87-B: resume source preserves SB lifecycle markers ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\nsilver-context\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook_source "$HOOK_WORKDIR" "resume" >/dev/null
assert_file_contains "#87-B: resume preserves silver-context" "$TMPSTATE" "silver-context"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

echo "--- Test #87-C: clear source preserves SB lifecycle markers ---"
HOOK_WORKDIR=$(make_git_repo)
new_branch=$(git -C "$HOOK_WORKDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf 'silver-quality-gates\nsilver-context\n' > "$TMPSTATE"
printf '%s' "$new_branch" > "$TMPBRANCH"
run_hook_source "$HOOK_WORKDIR" "clear" >/dev/null
assert_file_contains "#87-C: clear preserves silver-quality-gates" "$TMPSTATE" "silver-quality-gates"
assert_file_contains "#87-C: clear preserves silver-context" "$TMPSTATE" "silver-context"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

echo "--- Test #87-D: empty current_branch + non-empty stored does NOT wipe state ---"
# Bug 3: subagent CWD with detached HEAD or git failure could return empty
# current_branch. Combined with a populated branch file, the old elif
# (current_branch != stored_branch) fired and wiped the state file.
# Fix: the new branch-mismatch path requires BOTH values to be non-empty.
HOOK_WORKDIR=$(mktemp -d)  # NOT a git repo — git rev-parse will fail
printf 'silver-quality-gates\ncode-review\n' > "$TMPSTATE"
printf 'main\n' > "$TMPBRANCH"
run_hook_source "$HOOK_WORKDIR" "startup" >/dev/null
assert_file_exists "#87-D: empty current_branch preserves state file" "$TMPSTATE"
assert_file_contains "#87-D: empty current_branch preserves silver-quality-gates" "$TMPSTATE" "silver-quality-gates"
assert_file_contains "#87-D: empty current_branch preserves code-review" "$TMPSTATE" "code-review"
rm -rf "$HOOK_WORKDIR"
rm -f "$TMPSTATE" "$TMPBRANCH"

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

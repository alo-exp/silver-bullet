#!/usr/bin/env bash
# Tests for hooks/prompt-reminder.sh
# Verifies UserPromptSubmit hook output format and bypass conditions.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/prompt-reminder.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

RUNTIME_PATHS_SH="$REPO_ROOT/hooks/lib/runtime-paths.sh"
if [[ -f "$RUNTIME_PATHS_SH" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$RUNTIME_PATHS_SH"
fi

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ${SB_RUNTIME_HOME_ROOT}/ due to security path validation in hooks.
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() { rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"; }
trap cleanup_all EXIT

write_cfg() {
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
cat > "$TMPCFG" << EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","silver-review","silver-completion-audit","silver-branch-finish"],
    "all_tracked": ["silver-quality-gates","silver-review","silver-completion-audit","silver-branch-finish"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

write_legacy_cfg() {
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "$TMPCFG" << EOF
{
  "config_version": "0.2.0",
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review","testing-strategy","documentation","deploy-checklist","tech-debt"],
    "all_tracked": ["silver-quality-gates","code-review","testing-strategy","documentation","deploy-checklist","tech-debt"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/ups-coalesce-turn" "${SB_TEST_DIR}/ups-coalesce-seen" 2>/dev/null || true
  # Init a git repo so branch-detection tests work (hook silently handles no-git too)
  git -C "$TMPDIR_TEST" init -q
  git -C "$TMPDIR_TEST" config user.email "test@test.com"
  git -C "$TMPDIR_TEST" config user.name "Test"
  touch "$TMPDIR_TEST/.gitkeep"
  git -C "$TMPDIR_TEST" add .gitkeep
  git -C "$TMPDIR_TEST" commit -q -m "init" 2>/dev/null || true
  git -C "$TMPDIR_TEST" checkout -q -b feature/test 2>/dev/null || true
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}

run_hook() {
  local prompt="${1:-}"
  local input
  if [[ -n "$prompt" ]]; then
    input=$(jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit", prompt:$p}')
    ( cd "$TMPDIR_TEST" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="${SB_TEST_DIR}" SILVER_BULLET_STATE_FILE="$TMPSTATE" printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
  else
    ( cd "$TMPDIR_TEST" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="${SB_TEST_DIR}" SILVER_BULLET_STATE_FILE="$TMPSTATE" printf '{}' | bash "$HOOK" 2>/dev/null )
  fi
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
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
  if ! printf '%s' "$output" | grep -q "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' NOT in: $output"
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

assert_noop_json() {
  local label="$1"
  local output="$2"
  if printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and ((.hookSpecificOutput | keys) == ["hookEventName"])' >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected no-op hook JSON, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== prompt-reminder.sh tests ==="

# Test 1: No config file -> exit 0, no-op JSON
echo "--- Test 1: No config file ---"
setup
# No .silver-bullet.json in dir -> no-op JSON for Codex UserPromptSubmit
out=$(run_hook)
assert_noop_json "no config file -> valid no-op hook JSON" "$out"
teardown

# Test 2: All skills complete (H1 two-tier display)
echo "--- Test 2: All skills complete (two-tier) ---"
setup
write_cfg
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-review
silver-completion-audit
silver-branch-finish
EOF
# Delivery-adjacent prompt -> deploy tier; all deploy skills recorded.
out=$(run_hook 'ship this and open the PR')
assert_contains "delivery-adjacent + all deploy recorded -> delivery-complete message" "$out" "all required delivery skills complete"
# Non-delivery prompt -> planning floor tier; planning floor recorded.
out=$(run_hook)
assert_contains "dev (non-delivery) + planning floor recorded -> planning-floor-complete message" "$out" "planning floor complete"
teardown

# Test 3: Missing skills -> "Missing:" and skill names (deploy tier when delivery-adjacent)
echo "--- Test 3: Missing skills -> Missing label and skill name ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
# Delivery-adjacent so the full deploy list is surfaced.
out=$(run_hook 'ship this feature now')
assert_contains "missing skills -> output contains 'Missing:'" "$out" "Missing:"
assert_contains "missing skills -> output contains 'silver-review'" "$out" "silver-review"
# H1: during dev (non-delivery) the deploy-only skills must NOT be surfaced.
out=$(run_hook)
assert_not_contains "dev (non-delivery) -> deploy-only skill silver-review NOT surfaced" "$out" "silver-review"
teardown

# Test 4: Missing skills -> output contains count "(N of M complete)"
echo "--- Test 4: Missing skills -> count format (N of M complete) ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook 'ship this feature now')
assert_contains "missing skills -> output contains 'of' count" "$out" "of"
assert_contains "missing skills -> output contains 'complete'" "$out" "complete"
teardown

# Test 5: Trivial file present -> exit 0, no-op JSON
echo "--- Test 5: Trivial bypass ---"
setup
write_cfg
# No skills recorded — would normally output missing list
rm -f "$TMPSTATE"
# Create trivial file (not a symlink)
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook)
assert_noop_json "trivial file present -> valid no-op hook JSON" "$out"
teardown

# Test 6: Main branch -> finishing-a-development-branch NOT in missing (TD-02)
echo "--- Test 6: Main branch -> finishing-a-development-branch not in missing ---"
setup
write_cfg
# Switch to main branch
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
# Record only silver-quality-gates (leave review and completion missing) so 'Missing:' appears,
# but branch finishing should be exempt on main and not appear in the list.
# Use a delivery-adjacent prompt so the full deploy list (incl. branch-finish) is surfaced.
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook 'ship this and merge to main')
assert_contains "on main: output contains 'Missing:'" "$out" "Missing:"
assert_not_contains "on main: finishing-a-development-branch NOT in missing" "$out" "finishing-a-development-branch"
assert_not_contains "on main: silver-branch-finish NOT in missing" "$out" "silver-branch-finish"
teardown

# Test 7: Path traversal in CLAUDE_PLUGIN_ROOT -> evil core-rules.md not injected (TD-06)
echo "--- Test 7: Path traversal in CLAUDE_PLUGIN_ROOT -> evil core-rules not injected ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
# Create a core-rules.md outside the plugin dir with a canary string
evil_dir=$(mktemp -d)
echo "CANARY_EVIL_RULES" > "$evil_dir/core-rules.md"
# Set CLAUDE_PLUGIN_ROOT to the evil dir and run hook
out=$(cd "$TMPDIR_TEST" && printf '{}' | CLAUDE_PLUGIN_ROOT="$evil_dir" bash "$HOOK" 2>/dev/null)
assert_not_contains "path traversal: evil core-rules not injected" "$out" "CANARY_EVIL_RULES"
rm -rf "$evil_dir"
teardown

# Test 8: Bare end-user work prompt -> inject Silver router-first instruction (host-aware #260)
echo "--- Test 8: Bare work prompt -> route through Silver before direct work ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
export SILVER_BULLET_RUNTIME=cursor
out=$(run_hook 'Add a due date field to todos. Keep it simple: accept dueDate in the API payload and return it in todo responses.')
unset SILVER_BULLET_RUNTIME
assert_contains "bare work prompt: hook identifies bare prompt interception" "$out" "BARE PROMPT INTERCEPTED"
assert_contains "bare work prompt: Claude/Cursor Skill form (#260)" "$out" 'Skill tool with skill'
assert_contains "bare work prompt: names sb skill (#260)" "$out" 'skill \\"sb\\"'
assert_not_contains "bare work prompt: no Codex invoke-skill on cursor" "$out" "invoke-skill sb"
assert_not_contains "bare work prompt: no Codex adapter branding on cursor" "$out" "Codex SB adapter"
assert_contains "bare work prompt: hook forbids direct implementation before routing" "$out" "Do not inspect, edit, run tests, or implement directly before routing"
assert_contains "bare work prompt: original prompt included as router context" "$out" "Add a due date field to todos"
teardown

# Test 8c: Codex host (non-parent worker) still gets invoke-skill adapter form
echo "--- Test 8c: Codex bare prompt -> invoke-skill adapter ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
export SILVER_BULLET_RUNTIME=codex
export SB_ORCHESTRATOR_WORKER=1
out=$(run_hook 'Add a due date field to todos. Keep it simple: accept dueDate in the API payload and return it in todo responses.')
unset SILVER_BULLET_RUNTIME SB_ORCHESTRATOR_WORKER
assert_contains "codex bare prompt: identifies interception" "$out" "BARE PROMPT INTERCEPTED"
assert_contains "codex bare prompt: uses package-local Silver adapter path" "$out" "scripts/silver-bullet"
assert_contains "codex bare prompt: instructs invoke-skill sb" "$out" "invoke-skill sb"
assert_not_contains "codex bare prompt: does not rely on PATH-only adapter" "$out" "  silver-bullet invoke-skill sb"
teardown

# Test 8b: Legacy config required_deploy is normalized to current gates
echo "--- Test 8b: Legacy config -> no retired missing-skill reminders ---"
setup
write_legacy_cfg
echo "silver-quality-gates" > "$TMPSTATE"
# Dev (non-delivery): planning floor is surfaced, normalized to current SB gates.
out=$(run_hook 'Add a due date field to todos. Keep it simple.')
assert_contains "legacy config: inherits current SB planning gate" "$out" "silver-context"
assert_not_contains "legacy config: does not request retired review framing" "$out" "requesting-code-review"
assert_not_contains "legacy config: does not request retired testing-strategy" "$out" "testing-strategy"
assert_not_contains "legacy config: does not request retired deploy-checklist" "$out" "deploy-checklist"
# Delivery-adjacent: deploy tier inherits current SB execution gate (silver-execute), still no retired skills.
out=$(run_hook 'ship this feature and open a pull request')
assert_contains "legacy config (delivery): inherits current SB execution gate" "$out" "silver-execute"
assert_not_contains "legacy config (delivery): no retired testing-strategy" "$out" "testing-strategy"
teardown

# Test 9: Explanatory question -> no bare-prompt router injection
echo "--- Test 9: Explanatory question -> no Silver router interception ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook 'What does Silver Bullet aim to achieve?')
assert_not_contains "explanatory question: no bare prompt interception" "$out" "BARE PROMPT INTERCEPTED"
assert_not_contains "explanatory question: no forced SB router invocation" "$out" "invoke-skill sb"
assert_not_contains "explanatory question: no Skill router injection" "$out" 'Skill tool with skill "sb"'
teardown

# ── Composed-workflow position tests (Pass 1: workflows/ dir) ────────────────
echo ""
echo "=== Composed-workflow position (Pass 1: workflows/ dir) ==="

# WF1: per-instance .planning/workflows/<id>.md files -> include active IDs
echo "--- WF1: lists active composed workflow IDs ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
mkdir -p "$TMPDIR_TEST/.planning/workflows"
touch "$TMPDIR_TEST/.planning/workflows/20260428T015523Z-K4F7QA-silver-feature.md"
touch "$TMPDIR_TEST/.planning/workflows/20260428T021500Z-B2C8RT-silver-bugfix.md"
out=$(run_hook)
assert_contains "WF1: lists active workflow IDs" "$out" "Active composed workflows"
assert_contains "WF1: includes silver-feature ID" "$out" "20260428T015523Z-K4F7QA-silver-feature"
assert_contains "WF1: includes silver-bugfix ID" "$out" "20260428T021500Z-B2C8RT-silver-bugfix"
teardown

# WF2: empty workflows/ dir -> no Active composed workflows line
echo "--- WF2: empty workflows/ dir omits the position line ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
mkdir -p "$TMPDIR_TEST/.planning/workflows"
out=$(run_hook)
if printf '%s' "$out" | grep -q 'Active composed workflows'; then
  echo "  FAIL: WF2: empty dir should not emit position line"
  FAIL=$((FAIL+1))
else
  echo "  PASS: WF2: empty workflows dir correctly omits position line"
  PASS=$((PASS+1))
fi
teardown

# WF3: stale legacy WORKFLOW.md is NOT read (Pass 1 hotfix invariant)
echo "--- WF3: legacy WORKFLOW.md ignored by Pass 1 ---"
setup
write_cfg
echo "silver-quality-gates" > "$TMPSTATE"
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Heartbeat
Last-flow: 7
## Next Flow
FLOW 12: VERIFY
WFEOF
out=$(run_hook)
if printf '%s' "$out" | grep -q 'Composable path'; then
  echo "  FAIL: WF3: legacy WORKFLOW.md still being read — Pass 1 incomplete"
  FAIL=$((FAIL+1))
else
  echo "  PASS: WF3: legacy WORKFLOW.md ignored (Pass 1 invariant holds)"
  PASS=$((PASS+1))
fi
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

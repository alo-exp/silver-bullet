#!/usr/bin/env bash
# Tests for hooks/prompt-reminder.sh
# Verifies UserPromptSubmit hook output format and bypass conditions.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/prompt-reminder.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ~/.claude/ due to security path validation in hooks.
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() { rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"; }
trap cleanup_all EXIT

write_cfg() {
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["quality-gates"],
    "required_deploy": ["quality-gates","code-review","testing-strategy","documentation","finishing-a-development-branch"],
    "all_tracked": ["quality-gates","code-review"]
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
  # prompt-reminder does NOT read stdin — just run script with PWD set to project dir
  ( cd "$TMPDIR_TEST" && bash "$HOOK" 2>/dev/null )
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

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== prompt-reminder.sh tests ==="

# Test 1: No config file -> exit 0, no output
echo "--- Test 1: No config file ---"
setup
# No .silver-bullet.json in dir -> silent exit
out=$(run_hook)
assert_empty "no config file -> silent exit, no output" "$out"
teardown

# Test 2: All skills complete -> output contains "all required skills complete"
echo "--- Test 2: All skills complete ---"
setup
write_cfg
cat > "$TMPSTATE" << 'EOF'
quality-gates
code-review
testing-strategy
documentation
finishing-a-development-branch
EOF
out=$(run_hook)
assert_contains "all skills complete -> contains all-complete message" "$out" "all required skills complete"
teardown

# Test 3: Missing skills -> output contains "Missing:" and the skill names
echo "--- Test 3: Missing skills -> Missing label and skill name ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook)
assert_contains "missing skills -> output contains 'Missing:'" "$out" "Missing:"
assert_contains "missing skills -> output contains 'code-review'" "$out" "code-review"
teardown

# Test 4: Missing skills -> output contains count "(N of M complete)"
echo "--- Test 4: Missing skills -> count format (N of M complete) ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook)
assert_contains "missing skills -> output contains 'of' count" "$out" "of"
assert_contains "missing skills -> output contains 'complete'" "$out" "complete"
teardown

# Test 5: Trivial file present -> exit 0, no output
echo "--- Test 5: Trivial bypass ---"
setup
write_cfg
# No skills recorded — would normally output missing list
rm -f "$TMPSTATE"
# Create trivial file (not a symlink)
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook)
assert_empty "trivial file present -> silent exit, no output" "$out"
teardown

# Test 6: Main branch -> finishing-a-development-branch NOT in missing (TD-02)
echo "--- Test 6: Main branch -> finishing-a-development-branch not in missing ---"
setup
write_cfg
# Switch to main branch
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
# Record only quality-gates (leave code-review and others missing) so 'Missing:' appears,
# but finishing-a-development-branch should be exempt on main and not appear in the list
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook)
assert_contains "on main: output contains 'Missing:'" "$out" "Missing:"
assert_not_contains "on main: finishing-a-development-branch NOT in missing" "$out" "finishing-a-development-branch"
teardown

# Test 7: Path traversal in CLAUDE_PLUGIN_ROOT -> evil core-rules.md not injected (TD-06)
echo "--- Test 7: Path traversal in CLAUDE_PLUGIN_ROOT -> evil core-rules not injected ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
# Create a core-rules.md outside the plugin dir with a canary string
evil_dir=$(mktemp -d)
echo "CANARY_EVIL_RULES" > "$evil_dir/core-rules.md"
# Set CLAUDE_PLUGIN_ROOT to the evil dir and run hook
out=$(cd "$TMPDIR_TEST" && CLAUDE_PLUGIN_ROOT="$evil_dir" bash "$HOOK" 2>/dev/null)
assert_not_contains "path traversal: evil core-rules not injected" "$out" "CANARY_EVIL_RULES"
rm -rf "$evil_dir"
teardown

# ── WORKFLOW.md position tests ───────────────────────────────────────────────
echo ""
echo "=== WORKFLOW.md position ==="

# WF1: WORKFLOW.md present -> includes composition context
echo "--- WF1: includes WORKFLOW.md position ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Composition
Paths: 0 → 5 → 7 → 11 → 13
Mode: autonomous

## Heartbeat
Last-path: 7

## Path Log
| # | Path | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | in_progress |

## Next Path
PATH 11: VERIFY
WFEOF
out=$(run_hook)
assert_contains "WF1: includes WORKFLOW.md context" "$out" "Composable path"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

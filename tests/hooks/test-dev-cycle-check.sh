#!/usr/bin/env bash
# Tests for hooks/dev-cycle-check.sh
# Tests the four-stage workflow gate: A (no planning), B (no code-review),
# C (code-review done, finalization remaining), D (all complete)

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/dev-cycle-check.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ~/.claude/ due to security path validation in hooks.
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() { rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"; }
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPFILE="${TMPDIR_TEST}/src/app.js"
  rm -f "$TMPSTATE"
  mkdir -p "$(dirname "$TMPFILE")"
  touch "$TMPFILE"
  cat > "$TMPCFG" << EOF
{
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\\\.test\\\\.",
    "active_workflow": "full-dev-cycle"
  },
  "skills": { "required_planning": ["quality-gates"] },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}

run_hook_edit() {
  local event="$1"
  local filepath="$2"
  local old_str="${3:-old content}"
  local new_str="${4:-new content}"
  local input
  input=$(jq -n \
    --arg e "$event" \
    --arg f "$filepath" \
    --arg o "$old_str" \
    --arg n "$new_str" \
    '{hook_event_name: $e, tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_write() {
  local event="$1"
  local filepath="$2"
  local input
  input=$(jq -n --arg e "$event" --arg f "$filepath" \
    '{hook_event_name: $e, tool_name: "Write", tool_input: {file_path: $f}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

run_hook_bash() {
  local event="$1"
  local cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
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
echo "=== dev-cycle-check.sh tests ==="

# Test 1: Stage A — no planning skills → HARD STOP on src edit
echo "--- Group 1: Stage A (no planning) ---"
setup
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "Stage A: source edit blocked without quality-gates" "$out"
assert_contains "Stage A block message mentions HARD STOP" "$out" "HARD STOP"
teardown

# Test 2: Stage A — no planning → HARD STOP on Write to src
setup
out=$(run_hook_write "PreToolUse" "$TMPFILE")
assert_blocks "Stage A: Write to src blocked without quality-gates" "$out"
teardown

# Test 3: Stage A — non-src file passes even without planning
setup
out=$(run_hook_edit "PreToolUse" "${TMPDIR_TEST}/README.md" "old" "new")
assert_passes "non-src file passes without quality-gates" "$out"
teardown

# Test 4: Stage A — test file passes even without planning
setup
TEST_FILE="${TMPDIR_TEST}/src/app.test.js"
mkdir -p "$(dirname "$TEST_FILE")"
touch "$TEST_FILE"
out=$(run_hook_edit "PreToolUse" "$TEST_FILE" "old content" "new content")
assert_passes "test file passes without planning (excluded by src_exclude_pattern)" "$out"
teardown

# Test 5: Stage B — planning done but no code-review → BLOCK
echo "--- Group 2: Stage B (planning done, no code-review) ---"
setup
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "Stage B: src edit blocked after planning, before code-review" "$out"
assert_contains "Stage B block message mentions code-review" "$out" "code-review"
teardown

# Test 6: Phase-skip detection — finalization before code-review
setup
echo "quality-gates" > "$TMPSTATE"
echo "testing-strategy" >> "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
# Should mention phase skip AND be blocked at Stage B (no code-review)
assert_blocks "Phase-skip: finalization before code-review is blocked" "$out"
teardown

# Test 7: Stage C — code-review done, finalization remaining → ALLOW with hint
echo "--- Group 3: Stage C (code-review done) ---"
setup
echo "quality-gates" > "$TMPSTATE"
echo "code-review" >> "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "Stage C: src edit allowed after code-review (finalization remaining)" "$out"
assert_contains "Stage C hint mentions finalization" "$out" "Finalization remaining"
teardown

# Test 8: Stage D — all phases complete → ALLOW
echo "--- Group 4: Stage D (all complete) ---"
setup
cat > "$TMPSTATE" << 'EOF'
quality-gates
code-review
requesting-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
EOF
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "Stage D: src edit allowed when all phases complete" "$out"
teardown

# Test 9: Small edit bypass (< 100 chars combined)
echo "--- Group 5: Trivial bypass ---"
setup
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "typo" "typoo")  # 10 chars combined
assert_passes "small edit (<100 chars) bypasses enforcement" "$out"
teardown

# Test 10: Large edit does NOT bypass enforcement (>= 100 chars combined)
setup
old_str="this is old content that is long enough to exceed the threshold value for sure"
new_str="this is new content that is long enough to exceed the threshold value for sure too"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "$old_str" "$new_str")
assert_blocks "large edit (>=100 chars) enforces gate normally" "$out"
teardown

# Test 11: Non-logic file extension bypasses enforcement
setup
CSS_FILE="${TMPDIR_TEST}/src/styles.css"
touch "$CSS_FILE"
out=$(run_hook_edit "PreToolUse" "$CSS_FILE" "old" "new")
assert_passes "CSS file bypasses enforcement (non-logic extension)" "$out"
teardown

# Test 12: Trivial file bypass
setup
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "trivial file bypass works" "$out"
teardown

# Test 13: Plugin cache boundary — blocks edits to ~/.claude/plugins/cache
echo "--- Group 6: Plugin boundary ---"
setup
# Simulate a path within the plugin cache
PLUGIN_PATH="${HOME}/.claude/plugins/cache/test-plugin/skill/SKILL.md"
out=$(run_hook_edit "PreToolUse" "$PLUGIN_PATH" "old" "new")
assert_blocks "plugin cache edit is blocked (§8 boundary)" "$out"
assert_contains "boundary block mentions THIRD-PARTY PLUGIN" "$out" "THIRD-PARTY PLUGIN BOUNDARY"
teardown

# Test 14: DevOps workflow uses blast-radius as required_planning
echo "--- Group 7: DevOps workflow ---"
setup
cat > "$TMPCFG" << 'EOF'
{
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "devops-cycle"
  },
  "skills": { "required_planning": [] },
  "state": { "state_file": "STATEFILE", "trivial_file": "TRIVIALFILE" }
}
EOF
sed -i.bak "s|STATEFILE|${TMPSTATE}|g; s|TRIVIALFILE|${TMPDIR_TEST}/trivial|g" "$TMPCFG"
rm -f "${TMPCFG}.bak"
# Only quality-gates in state (wrong for devops)
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "devops: edit blocked with quality-gates (need blast-radius+devops-quality-gates)" "$out"
teardown

# Test 15: DevOps workflow passes with blast-radius + devops-quality-gates
setup
cat > "$TMPCFG" << 'EOF'
{
  "project": {
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "devops-cycle"
  },
  "skills": { "required_planning": [] },
  "state": { "state_file": "STATEFILE", "trivial_file": "TRIVIALFILE" }
}
EOF
sed -i.bak "s|STATEFILE|${TMPSTATE}|g; s|TRIVIALFILE|${TMPDIR_TEST}/trivial|g" "$TMPCFG"
rm -f "${TMPCFG}.bak"
echo "blast-radius" > "$TMPSTATE"
echo "devops-quality-gates" >> "$TMPSTATE"
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "devops: Stage B — needs code-review even with blast-radius+devops-quality-gates" "$out"
teardown

# Tests 16-17: State file tamper detection
echo "--- Group 8: State tamper detection ---"
setup
# Test 16: General write to state file is blocked
out=$(run_hook_bash "PreToolUse" "echo 'fake-skill' >> ~/.claude/.silver-bullet/state")
assert_blocks "tamper: arbitrary state write is blocked" "$out"
teardown

# Tests 18-22: F-07 plugin boundary — execution vs write distinction
# Use expanded $HOME path so the plugin_cache grep actually fires in the hook
PLUGIN_CACHE_PATH="${HOME}/.claude/plugins/cache"
echo "--- Group 9: F-07 execution vs write (plugin binary) ---"

# Test 18: Running a plugin binary with node should be ALLOWED (execution, not write)
setup
out=$(run_hook_bash "PreToolUse" "node ${PLUGIN_CACHE_PATH}/some-plugin/index.js --run")
assert_passes "F-07: node execution of plugin binary is allowed" "$out"
teardown

# Test 19: node with a redirect into the plugin cache should be BLOCKED (write)
setup
out=$(run_hook_bash "PreToolUse" "node ${PLUGIN_CACHE_PATH}/some-plugin/build.js > ${PLUGIN_CACHE_PATH}/some-plugin/out.js")
assert_blocks "F-07: node with redirect into plugin cache is blocked" "$out"
teardown

# Test 20: python3 execution of plugin binary should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "python3 ${PLUGIN_CACHE_PATH}/some-plugin/tool.py")
assert_passes "F-07: python3 execution of plugin binary is allowed" "$out"
teardown

# Test 21: ruby execution of plugin binary should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "ruby ${PLUGIN_CACHE_PATH}/some-plugin/tool.rb")
assert_passes "F-07: ruby execution of plugin binary is allowed" "$out"
teardown

# Test 22: cp into plugin cache should still be BLOCKED (write op)
setup
out=$(run_hook_bash "PreToolUse" "cp /tmp/patch.js ${PLUGIN_CACHE_PATH}/some-plugin/index.js")
assert_blocks "F-07: cp into plugin cache is still blocked" "$out"
teardown

# Tests 23-26: Hooks self-protection — execution vs write (fallback path, no CLAUDE_PLUGIN_ROOT)
# The fallback uses pattern /silver-bullet[^/]*/hooks/ — use that directly
echo "--- Group 10: Hooks self-protection execution vs write ---"
SB_HOOKS_PATH="/home/user/silver-bullet/hooks"

# Test 23: node execution of something in hooks dir should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "node /home/user/silver-bullet/hooks/some-util.js --check")
assert_passes "hooks-protect: node execution in hooks dir is allowed" "$out"
teardown

# Test 24: node with redirect into hooks dir should be BLOCKED (write)
setup
out=$(run_hook_bash "PreToolUse" "node /home/user/silver-bullet/hooks/build.js > /home/user/silver-bullet/hooks/out.js")
assert_blocks "hooks-protect: node with redirect into hooks dir is blocked" "$out"
teardown

# Test 25: python3 execution in hooks dir should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "python3 /home/user/silver-bullet/hooks/util.py --dry-run")
assert_passes "hooks-protect: python3 execution in hooks dir is allowed" "$out"
teardown

# Test 26: ruby execution in hooks dir should be ALLOWED
setup
out=$(run_hook_bash "PreToolUse" "ruby /home/user/silver-bullet/hooks/util.rb --check")
assert_passes "hooks-protect: ruby execution in hooks dir is allowed" "$out"
teardown

# Test 27: cp into hooks dir should still be BLOCKED
setup
out=$(run_hook_bash "PreToolUse" "cp /tmp/evil.sh /home/user/silver-bullet/hooks/dev-cycle-check.sh")
assert_blocks "hooks-protect: cp into hooks dir is still blocked" "$out"
teardown

# ── WORKFLOW.md-first gate tests ─────────────────────────────────────────────
echo ""
echo "=== WORKFLOW.md-first gate ==="

# WF1: WORKFLOW.md with all paths complete -> allow edit
echo "--- WF1: all workflow paths complete -> allow ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
WFEOF
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "WF1: all workflow paths complete -> allow" "$out"
teardown

# WF2: WORKFLOW.md with partial paths -> falls through to legacy gate
echo "--- WF2: partial workflow paths -> legacy gate ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | in_progress |
WFEOF
# No skills in state -> legacy gate should block
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF2: partial paths + no legacy skills -> block" "$out"
teardown

# WF3: No WORKFLOW.md -> legacy gate only
echo "--- WF3: no WORKFLOW.md -> legacy gate ---"
setup
# No .planning directory at all
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_blocks "WF3: no WORKFLOW.md + no skills -> block" "$out"
teardown

# WF4: WORKFLOW.md with all paths complete -> allow even without legacy skills
echo "--- WF4: all paths complete overrides missing legacy skills ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Path | Status |
|---|------|--------|
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 11 | VERIFY | complete |
| 13 | SHIP | complete |
WFEOF
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "WF4: all workflow paths complete overrides legacy" "$out"
teardown

# WF5: Bug-2 regression — Phase Iterations and Autonomous Decisions rows don't inflate total
echo "--- WF5: Bug-2 regression — digit-starting rows in other sections don't inflate total ---"
setup
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Flow Log
| # | Flow | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | complete |
| 11 | VERIFY | complete |
| 13 | SHIP | complete |

## Phase Iterations
| Phase | Status |
|-------|--------|
| 01 (feature-phase) | FLOW 5 complete, FLOW 7 complete |

## Autonomous Decisions
| Timestamp | Decision | Rationale |
|-----------|----------|-----------|
| 2026-04-15T10:00:00Z | Skipped FLOW 4 | No SPEC.md found |
| 2026-04-15T10:05:00Z | Auto-confirmed | autonomous mode |
WFEOF
out=$(run_hook_edit "PreToolUse" "$TMPFILE" "old content here long enough to exceed the small-edit bypass threshold" "new content here long enough to exceed the small-edit bypass threshold too")
assert_passes "WF5: Phase Iterations and Autonomous Decisions rows don't inflate total (Bug-2 regression)" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

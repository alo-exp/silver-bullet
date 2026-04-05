#!/usr/bin/env bash
# Tests for hooks/record-skill.sh
# Tests skill recording: tracking, dedup, namespace stripping, untracked skills

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/record-skill.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ~/.claude/ due to security path validation in hooks.
# Tests use unique names under ~/.claude/.silver-bullet/ and clean up on exit.
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  rm -f "$TMPSTATE"  # clean slate per test
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["quality-gates"],
    "required_deploy": ["quality-gates","code-review"],
    "all_tracked": ["quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt","blast-radius","devops-quality-gates","gsd-discuss-phase","gsd-plan-phase","gsd-execute-phase","gsd-verify-work","gsd-ship"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
}

# Always clean up on exit
cleanup_all() { rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"; }
trap cleanup_all EXIT

run_hook() {
  local skill_name="$1"
  local input
  input=$(jq -n --arg s "$skill_name" \
    '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null
}

assert_in_state() {
  local label="$1"
  local skill="$2"
  if grep -qx "$skill" "$TMPSTATE" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' not found in state: $(cat "$TMPSTATE" 2>/dev/null || echo '(empty)')"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_in_state() {
  local label="$1"
  local skill="$2"
  if ! grep -qx "$skill" "$TMPSTATE" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' unexpectedly found in state"
    FAIL=$((FAIL + 1))
  fi
}

assert_count() {
  local label="$1"
  local skill="$2"
  local expected="$3"
  local actual
  actual=$(grep -cx "$skill" "$TMPSTATE" 2>/dev/null || echo 0)
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected $expected occurrences, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== record-skill.sh tests ==="

# Test 1: Tracked skill is recorded
echo "--- Group 1: Basic recording ---"
setup
run_hook "quality-gates" >/dev/null
assert_in_state "quality-gates recorded after invocation" "quality-gates"
teardown

# Test 2: Untracked skill is NOT recorded
setup
run_hook "some-unknown-skill" >/dev/null
assert_not_in_state "unknown skill not recorded" "some-unknown-skill"
teardown

# Test 3: Namespace prefix stripped (e.g., superpowers:code-review → code-review)
setup
run_hook "superpowers:code-review" >/dev/null
assert_in_state "namespace-stripped skill recorded (superpowers:code-review → code-review)" "code-review"
assert_not_in_state "namespaced form not recorded" "superpowers:code-review"
teardown

# Test 4: engineering: prefix stripped
setup
run_hook "engineering:testing-strategy" >/dev/null
assert_in_state "engineering:testing-strategy recorded as testing-strategy" "testing-strategy"
teardown

# Test 5: design: prefix stripped
setup
run_hook "design:accessibility-review" >/dev/null
# accessibility-review may not be in all_tracked for this config — just ensure namespace stripping works
# The hook should record if in all_tracked; we check namespace logic by looking for the stripped form
assert_not_in_state "design:accessibility-review not recorded (not in all_tracked)" "design:accessibility-review"
teardown

# Test 6: Deduplication — invoking same skill twice only records once
echo "--- Group 2: Deduplication ---"
setup
run_hook "quality-gates" >/dev/null
run_hook "quality-gates" >/dev/null
assert_count "quality-gates recorded exactly once despite two invocations" "quality-gates" 1
teardown

# Test 7: Multiple different skills all recorded
setup
run_hook "quality-gates" >/dev/null
run_hook "code-review" >/dev/null
run_hook "testing-strategy" >/dev/null
assert_in_state "quality-gates recorded" "quality-gates"
assert_in_state "code-review recorded" "code-review"
assert_in_state "testing-strategy recorded" "testing-strategy"
teardown

# Test 8: State file created if it doesn't exist
echo "--- Group 3: State file management ---"
setup
rm -f "$TMPSTATE"  # ensure it doesn't exist
run_hook "quality-gates" >/dev/null
if [[ -f "$TMPSTATE" ]]; then
  echo "  ✅ state file created when it doesn't exist"
  PASS=$((PASS + 1))
else
  echo "  ❌ state file not created"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 9: Existing state preserved when new skill added
setup
echo "code-review" > "$TMPSTATE"
run_hook "quality-gates" >/dev/null
assert_in_state "existing skill (code-review) preserved" "code-review"
assert_in_state "new skill (quality-gates) added" "quality-gates"
teardown

# Test 10: blast-radius and devops-quality-gates are recorded (devops skills)
echo "--- Group 4: DevOps skills ---"
setup
run_hook "blast-radius" >/dev/null
assert_in_state "blast-radius recorded" "blast-radius"
teardown

setup
run_hook "devops-quality-gates" >/dev/null
assert_in_state "devops-quality-gates recorded" "devops-quality-gates"
teardown

# Test 11: GSD namespace preserved as gsd- prefix (gsd:discuss-phase → gsd-discuss-phase)
echo "--- Group 4b: GSD namespace ---"
setup
run_hook "gsd:discuss-phase" >/dev/null
assert_in_state "gsd:discuss-phase recorded as gsd-discuss-phase" "gsd-discuss-phase"
assert_not_in_state "gsd: form not recorded verbatim" "gsd:discuss-phase"
assert_not_in_state "stripped form discuss-phase not recorded" "discuss-phase"
teardown

setup
run_hook "gsd:execute-phase" >/dev/null
assert_in_state "gsd:execute-phase recorded as gsd-execute-phase" "gsd-execute-phase"
teardown

# Test 12: Non-Skill tool input is silently ignored
echo "--- Group 5: Non-skill input ---"
setup
input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Edit", tool_input: {file_path: "/src/app.js"}}')
cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" >/dev/null 2>/dev/null || true
assert_not_in_state "Edit tool event does not record anything" "Edit"
teardown

# Test 12: Empty skill name is ignored
setup
run_hook "" >/dev/null || true
# State file should either not exist or be empty
skill_count=$(wc -l < "$TMPSTATE" 2>/dev/null || echo 0)
if [[ "$skill_count" -eq 0 ]]; then
  echo "  ✅ empty skill name ignored"
  PASS=$((PASS + 1))
else
  echo "  ❌ empty skill name caused recording: $(cat "$TMPSTATE")"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

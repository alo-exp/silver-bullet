#!/usr/bin/env bash
# Tests for hooks/record-skill.sh
# Tests skill recording: tracking, dedup, namespace stripping, untracked skills

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/record-skill.sh"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
TEST_HOME_CLEANUP=""

if [[ "${SILVER_BULLET_TEST_ISOLATE_HOME:-1}" == "1" ]]; then
  TEST_HOME_CLEANUP="$(mktemp -d)"
  export HOME="$TEST_HOME_CLEANUP"
fi

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ${SB_RUNTIME_HOME_ROOT}/ due to security path validation in hooks.
# Tests use unique names under ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ and clean up on exit.
SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
TMPLOG_PATH_FILE="${SB_TEST_DIR}/session-log-path-${TEST_RUN_ID}"
SESSION_LOG_FILE=""

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  SESSION_LOG_FILE="${TMPDIR_TEST}/docs/sessions/test-state-${TEST_RUN_ID}.md"
  rm -f "$TMPSTATE"  # clean slate per test
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": ["silver-quality-gates","code-review"],
    "all_tracked": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt","silver-blast-radius","devops-quality-gates","silver-context","silver-plan","silver-execute","silver-verify","silver-ship"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
  }
EOF
  mkdir -p "$(dirname "$SESSION_LOG_FILE")"
  cat > "$SESSION_LOG_FILE" <<'EOF'
# Session Log — test

## Active Intent Ledger

- Request [2026-05-19 00:00:00Z]
  > test request
  - [ ] silver-quality-gates

## Agent Teams dispatched

(none)
EOF
  printf '%s\n' "$SESSION_LOG_FILE" > "$TMPLOG_PATH_FILE"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  export SILVER_BULLET_SESSION_LOG_PATH_FILE="$TMPLOG_PATH_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  rm -f "$TMPLOG_PATH_FILE"
  SESSION_LOG_FILE=""
}

# Always clean up on exit
cleanup_all() {
  rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  if [[ -n "$TEST_HOME_CLEANUP" ]]; then
    rm -rf "$TEST_HOME_CLEANUP"
  fi
}
trap cleanup_all EXIT

run_hook() {
  local skill_name="$1"
  local input
  input=$(jq -n --arg s "$skill_name" \
    '{hook_event_name: "PostToolUse", tool_name: "Skill", tool_input: {skill: $s}}')
  cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null
}

run_hook_bash() {
  local command_str="$1"
  local input
  input=$(jq -n --arg c "$command_str" \
    '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')
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

assert_in_loaded_state() {
  local label="$1"
  local skill="$2"
  if grep -qx "$skill" "${TMPSTATE}.loaded" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' not found in loaded state: $(cat "${TMPSTATE}.loaded" 2>/dev/null || echo '(empty)')"
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

assert_in_session_log() {
  local label="$1"
  local needle="$2"
  if grep -qF "$needle" "$SESSION_LOG_FILE" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$needle' not found in session log: $(cat "$SESSION_LOG_FILE" 2>/dev/null || echo '(empty)')"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -F "$needle" >/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$needle' not found in output: $output"
    FAIL=$((FAIL + 1))
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== record-skill.sh tests ==="

# Test 1: Tracked skill is recorded
echo "--- Group 1: Basic recording ---"
setup
run_hook "silver-quality-gates" >/dev/null
assert_in_state "silver-quality-gates recorded after invocation" "silver-quality-gates"
assert_in_session_log "session log marks silver-quality-gates completed" "  - [x] silver-quality-gates"
teardown

# Test 1b: Bootstrap sb:init is recorded even before project config exists
setup
rm -f "$TMPCFG"
run_hook "sb:init" >/dev/null
assert_in_state "sb:init recorded without project config present" "silver-init"
teardown

# Test 2: Untracked skill is NOT recorded
setup
run_hook "some-unknown-skill" >/dev/null
assert_not_in_state "unknown skill not recorded" "some-unknown-skill"
teardown

# Test 2b: Project all_tracked is additive to packaged defaults, not a replacement
setup
run_hook "sb:scan" >/dev/null
assert_in_state "default SB route remains recordable when project config has partial all_tracked" "silver-scan"
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
run_hook "silver-quality-gates" >/dev/null
run_hook "silver-quality-gates" >/dev/null
assert_count "silver-quality-gates recorded exactly once despite two invocations" "silver-quality-gates" 1
teardown

# Test 7: Multiple different skills all recorded
setup
run_hook "silver-quality-gates" >/dev/null
run_hook "code-review" >/dev/null
run_hook "testing-strategy" >/dev/null
assert_in_state "silver-quality-gates recorded" "silver-quality-gates"
assert_in_state "code-review recorded" "code-review"
assert_in_state "testing-strategy recorded" "testing-strategy"
teardown

# Test 8: State file created if it doesn't exist
echo "--- Group 3: State file management ---"
setup
rm -f "$TMPSTATE"  # ensure it doesn't exist
run_hook "silver-quality-gates" >/dev/null
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
run_hook "silver-quality-gates" >/dev/null
assert_in_state "existing skill (code-review) preserved" "code-review"
assert_in_state "new skill (silver-quality-gates) added" "silver-quality-gates"
teardown

# Test 9b: Existing state still closes the active ledger entry
setup
echo "silver-quality-gates" > "$TMPSTATE"
run_hook "silver-quality-gates" >/dev/null
assert_count "existing state remains deduped" "silver-quality-gates" 1
assert_in_session_log "existing state still marks session ledger completed" "  - [x] silver-quality-gates"
teardown

# Test 10: silver-blast-radius and devops-quality-gates are recorded (devops skills)
echo "--- Group 4: DevOps skills ---"
setup
run_hook "silver-blast-radius" >/dev/null
assert_in_state "silver-blast-radius recorded" "silver-blast-radius"
teardown

setup
run_hook "devops-quality-gates" >/dev/null
assert_in_state "devops-quality-gates recorded" "devops-quality-gates"
teardown

# Test 12: Non-Skill tool input is silently ignored
echo "--- Group 5: Non-skill input ---"
setup
input=$(jq -n '{hook_event_name: "PostToolUse", tool_name: "Edit", tool_input: {file_path: "/src/app.js"}}')
cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" >/dev/null 2>/dev/null || true
assert_not_in_state "Edit tool event does not record anything" "Edit"
teardown

# Test 12b: Codex shell reads of SKILL.md are loaded-only, not completed skills
setup
run_hook_bash "cat \"$REPO_ROOT/skills/silver-quality-gates/SKILL.md\"" >/dev/null
assert_not_in_state "Bash SKILL.md read does not record completed skill" "silver-quality-gates"
assert_in_loaded_state "Bash SKILL.md read records loaded-only metadata" "silver-quality-gates"
teardown

# Test 12c: SB-owned Codex invoke-skill adapter records completed skills only with receipt
echo "--- Group 5b: Codex invoke-skill adapter ---"
setup
adapter_cmd_without_receipt="bash \"$REPO_ROOT/scripts/silver-bullet\" invoke-skill sb:quality-gates"
run_hook_bash "$adapter_cmd_without_receipt" >/dev/null
assert_not_in_state "invoke-skill command without adapter receipt is not trusted" "silver-quality-gates"
teardown

setup
adapter_cmd="bash \"$REPO_ROOT/scripts/silver-bullet\" invoke-skill sb:quality-gates"
(cd "$TMPDIR_TEST" && bash "$REPO_ROOT/scripts/silver-bullet" invoke-skill sb:quality-gates >/dev/null 2>/dev/null) || true
run_hook_bash "$adapter_cmd" >/dev/null
assert_in_state "Codex invoke-skill adapter records completed skill after verified receipt" "silver-quality-gates"
assert_in_session_log "Codex invoke-skill adapter marks session ledger completed" "  - [x] silver-quality-gates"
teardown

setup
adapter_cmd="bash \"$REPO_ROOT/scripts/silver-bullet\" invoke-skill sb:quality-gates"
(cd "$TMPDIR_TEST" && bash "$REPO_ROOT/scripts/silver-bullet" invoke-skill sb:quality-gates >/dev/null 2>/dev/null) || true
input=$(jq -n --arg c "$adapter_cmd" \
  '{hook_event_name: "PostToolUse", tool_name: "exec_command", tool_input: {cmd: $c}, tool_response: {exit_code: 0}}')
cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" >/dev/null
assert_in_state "Codex invoke-skill adapter records desktop exec_command cmd payloads" "silver-quality-gates"
teardown

setup
adapter_cmd="bash \"$REPO_ROOT/scripts/silver-bullet\" invoke-skill sb:quality-gates"
mkdir -p "$HOME/.codex/.silver-bullet/skill-invocations"
(
  cd "$TMPDIR_TEST"
  SILVER_BULLET_RUNTIME=codex bash "$REPO_ROOT/scripts/silver-bullet" invoke-skill sb:quality-gates >/dev/null 2>&1
) || true
input=$(jq -n --arg c "$adapter_cmd" \
  '{hook_event_name: "PostToolUse", tool_name: "exec_command", tool_input: {cmd: $c}, tool_response: {exit_code: 0}}')
cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" >/dev/null
assert_in_state "repo hook records desktop exec_command when adapter receipt lives under ~/.codex" "silver-quality-gates"
teardown

setup
adapter_cmd="bash \"$REPO_ROOT/scripts/silver-bullet\" invoke-skill sb:tdd"
(cd "$TMPDIR_TEST" && bash "$REPO_ROOT/scripts/silver-bullet" invoke-skill sb:tdd >/dev/null 2>/dev/null) || true
run_hook_bash "$adapter_cmd" >/dev/null
assert_in_state "Codex invoke-skill adapter canonicalizes silver-tdd to tdd marker" "tdd"
teardown

setup
adapter_output="$(
  cd "$TMPDIR_TEST" && \
    bash "$REPO_ROOT/scripts/silver-bullet" invoke-skill sb 'Add a due date field to todos.' 2>/dev/null
)"
assert_output_contains "Codex invoke-skill adapter surfaces runtime arguments" "$adapter_output" "Runtime arguments for this skill"
assert_output_contains "Codex invoke-skill adapter includes original bare prompt argument" "$adapter_output" "Add a due date field to todos."
teardown

# Test 13: Empty skill name is ignored
setup
run_hook "" >/dev/null || true
# State file should either not exist or be empty
if [[ -f "$TMPSTATE" ]]; then
  skill_count=$(wc -l < "$TMPSTATE" 2>/dev/null || echo 0)
else
  skill_count=0
fi
if [[ "$skill_count" -eq 0 ]]; then
  echo "  ✅ empty skill name ignored"
  PASS=$((PASS + 1))
else
  echo "  ❌ empty skill name caused recording: $(cat "$TMPSTATE")"
  FAIL=$((FAIL + 1))
fi
teardown

# Test 14: Double-namespace stripping (outer:inner:silver-quality-gates → silver-quality-gates)
echo "--- Group 6: Double-namespace stripping (SENTINEL S6-001) ---"
setup
run_hook "outer:inner:silver-quality-gates" >/dev/null
assert_in_state "double-namespaced skill recorded (outer:inner:silver-quality-gates → silver-quality-gates)" "silver-quality-gates"
assert_not_in_state "double-namespaced form not recorded verbatim" "outer:inner:silver-quality-gates"
assert_not_in_state "single-stripped form not recorded" "inner:silver-quality-gates"
teardown

setup
run_hook "a:b:c:code-review" >/dev/null
assert_in_state "triple-namespaced skill recorded (a:b:c:code-review → code-review)" "code-review"
teardown

# Test 15: Arbitrary Kay-looking state roots are rejected unless explicitly allowed.
echo "--- Group 7: Kay isolated state root allowlist ---"
setup
KAY_TMP="$(mktemp -d)"
KAY_STATE="${KAY_TMP}/.kay/.silver-bullet/state"
mkdir -p "$(dirname "$KAY_STATE")"
python3 - "$TMPCFG" "$KAY_STATE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
state = sys.argv[2]
data = json.loads(path.read_text())
data["state"]["state_file"] = state
path.write_text(json.dumps(data, indent=2) + "\n")
PY
unset SILVER_BULLET_STATE_FILE
unset SB_RUNTIME_EXTRA_STATE_ROOTS
DEFAULT_FALLBACK_STATE="${SB_RUNTIME_STATE_DIR}/state"
rm -f "$DEFAULT_FALLBACK_STATE"
group7_hook_out=""
group7_hook_rc=0
group7_hook_out="$(run_hook "silver-quality-gates" 2>&1)" || group7_hook_rc=$?
if ! grep -qx "silver-quality-gates" "$KAY_STATE" 2>/dev/null \
  && grep -qx "silver-quality-gates" "$DEFAULT_FALLBACK_STATE" 2>/dev/null; then
  echo "  ✅ arbitrary Kay-looking .kay state root rejected without allowlist"
  PASS=$((PASS + 1))
else
  echo "  ❌ arbitrary Kay-looking .kay state root was not rejected"
  echo "    Hook rc: $group7_hook_rc"
  echo "    Hook output: ${group7_hook_out:-"(empty)"}"
  echo "    Kay state: $(cat "$KAY_STATE" 2>/dev/null || echo '(empty)')"
  echo "    Default state: $(cat "$DEFAULT_FALLBACK_STATE" 2>/dev/null || echo '(empty)')"
  FAIL=$((FAIL + 1))
fi
rm -f "$DEFAULT_FALLBACK_STATE"
rm -rf "$KAY_TMP"
teardown

# Test 16: Explicitly allowlisted Kay state roots remain independent.
echo "--- Group 8: Multiple allowlisted agent-local state roots ---"
setup
KAY_TMP_A="$(mktemp -d)"
KAY_TMP_B="$(mktemp -d)"
KAY_STATE_A="${KAY_TMP_A}/.kay/.silver-bullet/state"
KAY_STATE_B="${KAY_TMP_B}/.kay/.silver-bullet/state"
mkdir -p "$(dirname "$KAY_STATE_A")" "$(dirname "$KAY_STATE_B")"
write_state_path() {
  python3 - "$TMPCFG" "$1" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
state = sys.argv[2]
data = json.loads(path.read_text())
data["state"]["state_file"] = state
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}
unset SILVER_BULLET_STATE_FILE KAY_HOME KAY_SB_TEST_HOME SB_LIVE_CODEX_ISOLATION_DIR
export SB_RUNTIME_EXTRA_STATE_ROOTS="$(dirname "$KAY_STATE_A"):$(dirname "$KAY_STATE_B")"
write_state_path "$KAY_STATE_A"
run_hook "silver-quality-gates" >/dev/null
write_state_path "$KAY_STATE_B"
run_hook "code-review" >/dev/null
if grep -qx "silver-quality-gates" "$KAY_STATE_A" 2>/dev/null \
  && ! grep -qx "code-review" "$KAY_STATE_A" 2>/dev/null \
  && grep -qx "code-review" "$KAY_STATE_B" 2>/dev/null \
  && ! grep -qx "silver-quality-gates" "$KAY_STATE_B" 2>/dev/null; then
  echo "  ✅ separate Kay-style SB instances keep independent state roots"
  PASS=$((PASS + 1))
else
  echo "  ❌ separate Kay-style state roots were not independent"
  echo "    A: $(cat "$KAY_STATE_A" 2>/dev/null || echo '(empty)')"
  echo "    B: $(cat "$KAY_STATE_B" 2>/dev/null || echo '(empty)')"
  FAIL=$((FAIL + 1))
fi
unset SB_RUNTIME_EXTRA_STATE_ROOTS
rm -rf "$KAY_TMP_A" "$KAY_TMP_B"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
# Tests for hooks/compliance-status.sh
# Verifies PostToolUse compliance progress display hook.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/compliance-status.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ~/.claude/ due to security path validation in hooks.
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  rm -f "${SB_TEST_DIR}/config-cache-"*"-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup_all EXIT

write_cfg() {
  cat > "$TMPCFG" << EOF
{
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["quality-gates"],
    "required_deploy": ["quality-gates","code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release"],
    "all_tracked": ["quality-gates","code-review"]
  },
  "state": { "state_file": "${TMPSTATE}" }
}
EOF
}

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  rm -f "$TMPSTATE"
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  unset SILVER_BULLET_STATE_FILE 2>/dev/null || true
}

run_hook() {
  # compliance-status discards stdin — send empty input
  ( cd "$TMPDIR_TEST" && printf '{}' | bash "$HOOK" 2>/dev/null )
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
echo "=== compliance-status.sh tests ==="

# Test 1: No config file -> silent exit (project not set up)
echo "--- Test 1: No config file -> silent exit ---"
setup
# No .silver-bullet.json in dir
out=$(run_hook)
assert_empty "no config file -> silent exit" "$out"
teardown

# Test 2: Config exists, no state file -> zeros output with Silver Bullet prefix
echo "--- Test 2: No state file -> zeros output ---"
setup
write_cfg
out=$(run_hook)
assert_contains "no state file -> Silver Bullet prefix" "$out" "Silver Bullet"
assert_contains "no state file -> PLANNING 0/" "$out" "PLANNING 0/"
assert_contains "no state file -> GSD 0/5" "$out" "GSD 0/5"
assert_contains "no state file -> REVIEW 0/3" "$out" "REVIEW 0/3"
teardown

# Test 3: State file with planning skill -> PLANNING 1/1
echo "--- Test 3: Planning skill present -> PLANNING 1/1 ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook)
assert_contains "quality-gates in state -> PLANNING 1/1" "$out" "PLANNING 1/1"
teardown

# Test 4: Review skills present -> REVIEW 3/3
echo "--- Test 4: Review skills complete -> REVIEW 3/3 ---"
setup
write_cfg
printf 'quality-gates\ncode-review\nrequesting-code-review\nreceiving-code-review\n' > "$TMPSTATE"
out=$(run_hook)
assert_contains "review skills complete -> REVIEW 3/3" "$out" "REVIEW 3/3"
teardown

# Test 5: GSD skills present -> GSD count increments
echo "--- Test 5: GSD skills increment GSD counter ---"
setup
write_cfg
printf 'gsd-discuss-phase\ngsd-plan-phase\ngsd-execute-phase\n' > "$TMPSTATE"
out=$(run_hook)
assert_contains "3 gsd skills -> GSD 3/5" "$out" "GSD 3/5"
teardown

# Test 6: Next skill shown for first missing planning skill
echo "--- Test 6: Next skill shown when planning incomplete ---"
setup
write_cfg
# No skills recorded -> first missing planning skill is quality-gates
rm -f "$TMPSTATE"
out=$(run_hook)
assert_contains "no skills -> Next shows quality-gates" "$out" "Next:"
assert_contains "no skills -> Next: quality-gates" "$out" "quality-gates"
teardown

# Test 7: Next skill advances past completed planning to review
echo "--- Test 7: Next advances to review phase when planning complete ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
out=$(run_hook)
# Planning done; next should be in review phase
assert_contains "planning done -> Next: code-review" "$out" "code-review"
teardown

# Test 8: Mode file respected — autonomous mode shown in output
echo "--- Test 8: Autonomous mode shown in output ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
printf 'autonomous' > "${HOME}/.claude/.silver-bullet/mode"
out=$(run_hook)
assert_contains "autonomous mode file -> output shows autonomous" "$out" "autonomous"
# Restore mode
printf 'interactive' > "${HOME}/.claude/.silver-bullet/mode"
teardown

# Test 9: Invalid mode value in mode file -> defaults to interactive (injection safety)
echo "--- Test 9: Invalid mode value defaults to interactive ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
printf 'INVALID_MODE; rm -rf /' > "${HOME}/.claude/.silver-bullet/mode"
out=$(run_hook)
assert_contains "invalid mode -> defaults to interactive" "$out" "interactive"
assert_not_contains "invalid mode -> does not echo attack string" "$out" "rm -rf"
printf 'interactive' > "${HOME}/.claude/.silver-bullet/mode"
teardown

# Test 10: Total step count reflects state file line count
echo "--- Test 10: Total step count correct ---"
setup
write_cfg
printf 'quality-gates\ncode-review\nrequesting-code-review\n' > "$TMPSTATE"
out=$(run_hook)
assert_contains "3 lines in state -> Silver Bullet: 3 steps" "$out" "3 steps"
teardown

# Test 11: FINALIZATION phase counted correctly
echo "--- Test 11: Finalization phase counts ---"
setup
write_cfg
printf 'testing-strategy\ndocumentation\nfinishing-a-development-branch\ndeploy-checklist\n' > "$TMPSTATE"
out=$(run_hook)
assert_contains "4 finalization skills -> FINALIZATION 4/4" "$out" "FINALIZATION 4/4"
teardown

# Test 12: RELEASE phase counted correctly
echo "--- Test 12: Release phase counts ---"
setup
write_cfg
printf 'create-release\n' > "$TMPSTATE"
out=$(run_hook)
assert_contains "create-release in state -> RELEASE 1/1" "$out" "RELEASE 1/1"
teardown

# ── WORKFLOW.md path progress tests ──────────────────────────────────────────
echo ""
echo "=== WORKFLOW.md path progress ==="

# WF1: WORKFLOW.md present -> shows PATH N/M
echo "--- WF1: shows PATH progress ---"
setup
write_cfg
echo "quality-gates" > "$TMPSTATE"
mkdir -p "$TMPDIR_TEST/.planning"
cat > "$TMPDIR_TEST/.planning/WORKFLOW.md" << 'WFEOF'
## Path Log
| # | Path | Status |
|---|------|--------|
| 0 | BOOTSTRAP | complete |
| 5 | PLAN | complete |
| 7 | EXECUTE | in_progress |
WFEOF
out=$(run_hook)
assert_contains "WF1: shows PATH progress" "$out" "PATH"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

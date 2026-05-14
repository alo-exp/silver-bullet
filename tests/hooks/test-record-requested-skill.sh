#!/usr/bin/env bash
# Tests for hooks/record-requested-skill.sh
# Verifies UserPromptSubmit route markers are recorded before the skill chain runs.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/record-requested-skill.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() {
  rm -rf "$TMPDIR_TEST" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/requested-skill-${TEST_RUN_ID}" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/requested-skill-${TEST_RUN_ID}.requested" 2>/dev/null || true
}
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/requested-skill-${TEST_RUN_ID}"
  rm -f "$TMPSTATE" "${TMPSTATE}.requested"
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  cat > "$TMPDIR_TEST/.silver-bullet.json" <<EOF
{
  "project": { "name": "test" },
  "state": { "state_file": "${TMPSTATE}" }
}
EOF
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE" "${TMPSTATE}.requested"
}

run_hook() {
  local prompt="$1"
  local input
  input=$(jq -n --arg p "$prompt" '{hook_event_name:"UserPromptSubmit", prompt:$p}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
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

assert_in_requested() {
  local label="$1"
  local skill="$2"
  if grep -qx "$skill" "${TMPSTATE}.requested" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' not found in requested-state: $(cat "${TMPSTATE}.requested" 2>/dev/null || echo '(empty)')"
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

assert_not_in_requested() {
  local label="$1"
  local skill="$2"
  if ! grep -qx "$skill" "${TMPSTATE}.requested" 2>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — '$skill' unexpectedly found in requested-state"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== record-requested-skill.sh tests ==="

setup
run_hook 'Use the [$silver-bullet:silver](path/to/skill) skill as the only entrypoint. Route this request to `silver:scan` and then invoke `gsd:plan-phase`.'
assert_in_requested "silver:scan request recorded as requested, not completed" "silver-scan"
assert_in_requested "gsd:plan-phase request recorded as requested, not completed" "gsd-plan-phase"
assert_not_in_state "silver:scan is not recorded as completed" "silver-scan"
teardown

setup
rm -f "$TMPDIR_TEST/.silver-bullet.json"
rm -f "$TMPDIR_TEST/silver-bullet.md"
run_hook 'Use the [$silver-bullet:silver](path/to/skill) skill as the only entrypoint. Route this request to `silver:init` and then stop.'
assert_in_requested "silver:init request recorded before scaffold exists" "silver-init"
assert_not_in_state "silver:init is not recorded as completed before scaffold exists" "silver-init"
teardown

setup
run_hook 'hello world, no routed skill markers here'
assert_not_in_requested "non-SB prompt does not record requested routes" "silver-scan"
assert_not_in_state "non-SB prompt does not record completed routes" "silver-scan"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

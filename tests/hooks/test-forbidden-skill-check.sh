#!/usr/bin/env bash
# Tests for hooks/forbidden-skill-check.sh
# Verifies that forbidden skills are blocked and allowed skills pass.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/forbidden-skill-check.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ~/.claude/ due to security path validation in hooks.
SB_TEST_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"

cleanup_all() { :; }
trap cleanup_all EXIT

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPGIT="$TMPDIR_TEST"
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" config user.email "test@test.com"
  git -C "$TMPGIT" config user.name "Test"
  touch "$TMPGIT/.gitkeep"
  git -C "$TMPGIT" add .gitkeep
  git -C "$TMPGIT" commit -q -m "init" 2>/dev/null || true
  # Write a basic config with no forbidden list by default
  cat > "$TMPCFG" << 'CFGEOF'
{
  "project": { "src_pattern": "/hooks/|/skills/|/templates/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["quality-gates"],
    "required_deploy": ["quality-gates","code-review"],
    "forbidden": []
  }
}
CFGEOF
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

run_hook() {
  local input="$1"
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_denied() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -q '"permissionDecision".*"deny"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected deny, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_denied "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass (no deny), got: $output"
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
echo "=== forbidden-skill-check.sh tests ==="

# Test 1: No config file → exit 0, no block (project not using SB)
echo "--- Test 1: No config file (project not using SB) ---"
setup
rm -f "$TMPCFG"
out=$(run_hook '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"engineering:code-review"}}')
assert_passes "no config -> skill passes (project not using SB)" "$out"
teardown

# Test 2: Allowed skill → exit 0, no block
echo "--- Test 2: Allowed skill passes ---"
setup
out=$(run_hook '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"engineering:code-review"}}')
assert_passes "allowed skill engineering:code-review -> no deny" "$out"
teardown

# Test 3: Forbidden skill superpowers:executing-plans → block with deny decision
echo "--- Test 3: Forbidden skill executing-plans blocked ---"
setup
out=$(run_hook '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"superpowers:executing-plans"}}')
assert_blocks "superpowers:executing-plans -> permissionDecision deny" "$out"
teardown

# Test 4: Forbidden skill superpowers:subagent-driven-development → block with deny decision
echo "--- Test 4: Forbidden skill subagent-driven-development blocked ---"
setup
out=$(run_hook '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"superpowers:subagent-driven-development"}}')
assert_blocks "superpowers:subagent-driven-development -> permissionDecision deny" "$out"
teardown

# Test 5: Custom forbidden skill from .silver-bullet.json skills.forbidden array → block
echo "--- Test 5: Custom forbidden skill from config ---"
setup
# Override config with a custom forbidden skill
cat > "$TMPCFG" << 'CFGEOF'
{
  "project": { "src_pattern": "/hooks/|/skills/|/templates/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["quality-gates"],
    "required_deploy": ["quality-gates","code-review"],
    "forbidden": ["custom-forbidden-skill"]
  }
}
CFGEOF
out=$(run_hook '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"some-ns:custom-forbidden-skill"}}')
assert_blocks "custom forbidden skill from config -> permissionDecision deny" "$out"
teardown

# Test 6: Double-namespace bypass blocked (TD-03)
echo "--- Test 6: Double-namespace bypass blocked ---"
setup
out=$(run_hook '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"outer:inner:executing-plans"}}')
assert_blocks "outer:inner:executing-plans -> permissionDecision deny" "$out"
teardown

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="${REPO_ROOT}/scripts/multi-ai-task-models.py"
LADDER="${REPO_ROOT}/scripts/review-fix-ladder.py"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

assert_jq_true() {
  local desc="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    pass "$desc"
  else
    fail "$desc"
    printf '%s\n' "$json"
  fi
}

[[ -f "$RESOLVER" ]] && pass "multi-ai-task-models.py exists" || fail "multi-ai-task-models.py exists"

cursor_json="$(python3 "$RESOLVER" --host cursor --json)"
assert_jq_true "cursor plan resolves" '.host == "cursor"' "$cursor_json"
assert_jq_true "cursor uses medium only" '[.models[].reasoning] | all(. == "medium")' "$cursor_json"
assert_jq_true "cursor includes composer-2.5 medium" '[.models[] | select(.model == "composer-2.5")] | length >= 1' "$cursor_json"

claude_json="$(python3 "$RESOLVER" --host claude --json)"
assert_jq_true "claude sonnet medium present" '[.models[] | select(.model == "claude-sonnet-4-6" and .reasoning == "medium")] | length == 1' "$claude_json"

# Claude bundle exposes silver: prefix
if grep -qE '^name: silver:multi-ai-task$' "${REPO_ROOT}/agents/claude/silver:multi-ai-task/SKILL.md" 2>/dev/null; then
  pass "Claude bundle exposes silver:multi-ai-task"
else
  fail "Claude bundle exposes silver:multi-ai-task (run render-agent-bundle)"
fi

if grep -qE '^name: silver-multi-ai-task$' "${REPO_ROOT}/skills/silver-multi-ai-task/SKILL.md"; then
  pass "authoring skill keeps silver-multi-ai-task source name"
else
  fail "authoring skill keeps silver-multi-ai-task source name"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

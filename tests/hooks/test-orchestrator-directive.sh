#!/usr/bin/env bash
# Tests for orchestrator directive lib + guard (P0/P6).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO_ROOT/hooks/orchestrator-directive-guard.sh"
LIB="$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

SB_TEST_DIR="${SB_RUNTIME_STATE_DIR}"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
export SILVER_BULLET_STATE_FILE="$TMPSTATE"
export SB_RUNTIME_STATE_DIR="$SB_TEST_DIR"
export SB_ORCHESTRATOR_WORKER=1

cleanup() {
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/orchestrator-directive.json" "${SB_TEST_DIR}/edit-without-workflow.count" 2>/dev/null || true
  rm -rf "$WORK" 2>/dev/null || true
}
trap cleanup EXIT

assert_true() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF "$needle"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (missing: $needle)"
    FAIL=$((FAIL + 1))
  fi
}

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (got='$got' want='$want')"
    FAIL=$((FAIL + 1))
  fi
}

# shellcheck source=../../hooks/lib/orchestrator-directive.sh
source "$LIB"

make_repo() {
  WORK=$(mktemp -d)
  git -C "$WORK" init -q
  echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$WORK/.silver-bullet.json"
  echo '# SB' >"$WORK/silver-bullet.md"
  mkdir -p "$WORK/.planning/workflows"
}

sb_orchestrator_directive_write "security" "security review" "source-order test" true
assert_eq "directive write loads worker template mapper" "$(jq -r '.next_worker_template // ""' "${SB_TEST_DIR}/orchestrator-directive.json")" "SECURITY"

sb_orchestrator_directive_write "silver-context" "test intent" "unit test" true
assert_true "directive file exists" test -f "${SB_TEST_DIR}/orchestrator-directive.json"
ctx="$(sb_orchestrator_directive_context_block)"
assert_contains "context mentions next_skill" "$ctx" "silver-context"

make_repo
out=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | \
  SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_contains "blocks edit when directive pending" "$out" "ORCHESTRATOR DIRECTIVE"

out_bash=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"gh issue list"}}' | \
  SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_true "worker allows Bash when directive pending" test -z "$out_bash"

out_shell=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Shell","tool_input":{"command":"gh issue list"}}' | \
  SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_true "worker allows Shell when directive pending" test -z "$out_shell"

printf 'silver-context\n' >"$TMPSTATE"
out2=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | \
  SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_true "allows edit after skill recorded" test -z "$out2"

sb_orchestrator_directive_write "silver-plan" "" "test" true
out3=$(cd "$WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"silver-plan"}}' | \
  SB_ORCHESTRATOR_WORKER=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_true "skill tool not blocked" test -z "$out3"

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

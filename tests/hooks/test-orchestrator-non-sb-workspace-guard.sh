#!/usr/bin/env bash
# Non-SB workspace must not get orchestrator parent/directive blocks from stale cache.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"

GUARD="$REPO_ROOT/hooks/orchestrator-directive-guard.sh"
LIB_PARENT="$REPO_ROOT/hooks/lib/orchestrator-parent.sh"
LIB_OD="$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
LIB_GATE="$REPO_ROOT/hooks/lib/sb-project-gate.sh"
PASS=0
FAIL=0

TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/non-sb-guard-${TEST_RUN_ID}"
SB_TEST_DIR="$SB_RUNTIME_STATE_DIR"
mkdir -p "$SB_TEST_DIR"
TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
export SILVER_BULLET_STATE_FILE="$TMPSTATE"

cleanup() {
  rm -f "$TMPSTATE" "${SB_TEST_DIR}/orchestrator-directive.json" \
    "${SB_TEST_DIR}/orchestrator-worker-active.json" "${SB_TEST_DIR}/project-root" \
    "${SB_TEST_DIR}/orchestrator.json" 2>/dev/null || true
  rm -rf "$NON_SB_WORK" "$SB_WORK" 2>/dev/null || true
  rm -rf "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/non-sb-guard-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup EXIT

assert_empty() {
  local name="$1" hay="$2"
  if [[ -z "$hay" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected empty, got: $hay)"
    FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $name"
    PASS=$((PASS + 1))
  fi
}

# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$LIB_GATE"
# shellcheck source=../../hooks/lib/orchestrator-directive.sh
source "$LIB_OD"
# shellcheck source=../../hooks/lib/orchestrator-parent.sh
source "$LIB_PARENT"

# Stale SB project-root cache pointing at a real SB repo layout (not visible from NON_SB cwd).
SB_WORK=$(mktemp -d)
git -C "$SB_WORK" init -q
echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$TMPSTATE"'"}}' >"$SB_WORK/.silver-bullet.json"
echo '# SB' >"$SB_WORK/silver-bullet.md"
printf '%s\n' "$SB_WORK" >"${SB_TEST_DIR}/project-root"

sb_orchestrator_directive_write "silver-plan" "intent" "stale directive from SB session" true "PLAN"
jq -n --arg root "$SB_WORK" --arg flow "FLOW-PLAN" \
  '{repo_root:$root, current_flow:$flow}' >"${SB_TEST_DIR}/orchestrator.json"

# Non-SB project: no .silver-bullet.json / silver-bullet.md in tree.
NON_SB_WORK=$(mktemp -d)
git -C "$NON_SB_WORK" init -q
echo '# vanilla project' >"$NON_SB_WORK/README.md"

if (cd "$NON_SB_WORK" && sb_orchestrator_is_parent_session); then
  echo "FAIL: is_parent_session false in non-SB cwd with stale cache"
  FAIL=$((FAIL + 1))
else
  echo "PASS: is_parent_session false in non-SB cwd with stale cache"
  PASS=$((PASS + 1))
fi

out_bash=$(cd "$NON_SB_WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "non-SB cwd + stale cache does not block Bash" "$out_bash"

out_edit=$(cd "$NON_SB_WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "non-SB cwd + stale directive does not block Edit" "$out_edit"

out_directive=$(cd "$NON_SB_WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test"}}' | \
  env -u SB_ORCHESTRATOR_PARENT SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
assert_empty "non-SB cwd + blocking directive file does not block Bash" "$out_directive"

# Sanity: SB workspace still blocks parent Bash when cache is stale but walk finds config.
out_sb=$(cd "$SB_WORK" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | \
  SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$TMPSTATE" SB_RUNTIME_STATE_DIR="$SB_TEST_DIR" bash "$GUARD" 2>/dev/null || true)
if printf '%s' "$out_sb" | grep -qF 'ORCHESTRATOR PARENT'; then
  echo "PASS: SB cwd still blocks parent Bash"
  PASS=$((PASS + 1))
else
  echo "FAIL: SB cwd should block parent Bash (got: $out_sb)"
  FAIL=$((FAIL + 1))
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

#!/usr/bin/env bash
# Non-SB workspace must not get orchestrator parent/directive blocks from stale cache.
# Covers Claude, Codex, and Cursor runtime state roots plus platform shims (bridge/adapter).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUNTIME_PATHS="$REPO_ROOT/hooks/lib/runtime-paths.sh"
GUARD="$REPO_ROOT/hooks/orchestrator-directive-guard.sh"
SESSION_START="$REPO_ROOT/hooks/session-start"
CURSOR_BRIDGE="$REPO_ROOT/hooks/cursor-hook-bridge.sh"
CODEX_ADAPTER="$REPO_ROOT/hooks/codex-hook-adapter.sh"
LIB_PARENT="$REPO_ROOT/hooks/lib/orchestrator-parent.sh"
LIB_OD="$REPO_ROOT/hooks/lib/orchestrator-directive.sh"
LIB_GATE="$REPO_ROOT/hooks/lib/sb-project-gate.sh"

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

PASS=0
FAIL=0
TEST_RUN_ID="$$"
TMP_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_HOME" 2>/dev/null || true
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

assert_missing() {
  local name="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected missing: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local name="$1" hay="$2" needle="$3"
  if ! printf '%s' "$hay" | grep -qF "$needle"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (unexpected '$needle' in: $hay)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" hay="$2" needle="$3"
  if printf '%s' "$hay" | grep -qF "$needle"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected '$needle' in: $hay)"
    FAIL=$((FAIL + 1))
  fi
}

run_runtime_suite() {
  local runtime="$1"
  echo ""
  echo "=== Runtime: $runtime ==="

  unset SILVER_BULLET_RUNTIME SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_NAME 2>/dev/null || true
  export SILVER_BULLET_RUNTIME="$runtime"
  export HOME="$TMP_HOME"
  # shellcheck source=../../hooks/lib/runtime-paths.sh
  # shellcheck disable=SC1090
  source "$RUNTIME_PATHS"
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${TMP_HOME}/.${runtime}/.silver-bullet/non-sb-guard-${TEST_RUN_ID}"
  local sb_test_dir="$SB_RUNTIME_STATE_DIR"
  mkdir -p "$sb_test_dir"
  local tmpstate="${sb_test_dir}/test-state-${TEST_RUN_ID}"
  export SILVER_BULLET_STATE_FILE="$tmpstate"

  # shellcheck source=../../hooks/lib/sb-project-gate.sh
  source "$LIB_GATE"
  # shellcheck source=../../hooks/lib/orchestrator-directive.sh
  source "$LIB_OD"
  # shellcheck source=../../hooks/lib/orchestrator-parent.sh
  source "$LIB_PARENT"

  local sb_work non_sb_work
  sb_work=$(mktemp -d)
  non_sb_work=$(mktemp -d)
  git -C "$sb_work" init -q
  git -C "$non_sb_work" init -q
  echo '{"sb_initiated":true,"orchestrator_mode":"parent","state":{"state_file":"'"$tmpstate"'"}}' >"$sb_work/.silver-bullet.json"
  echo '# SB' >"$sb_work/silver-bullet.md"
  echo '# vanilla project' >"$non_sb_work/README.md"

  printf '%s\n' "$sb_work" >"${sb_test_dir}/project-root"
  sb_orchestrator_directive_write "silver-plan" "intent" "stale directive from SB session" true "PLAN"
  jq -n --arg root "$sb_work" --arg flow "FLOW-PLAN" \
    '{repo_root:$root, current_flow:$flow}' >"${sb_test_dir}/orchestrator.json"

  if (cd "$non_sb_work" && sb_orchestrator_is_parent_session); then
    echo "FAIL: [$runtime] is_parent_session false in non-SB cwd with stale cache"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: [$runtime] is_parent_session false in non-SB cwd with stale cache"
    PASS=$((PASS + 1))
  fi

  local out_bash out_edit out_directive out_sb
  out_bash=$(cd "$non_sb_work" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | \
    SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$tmpstate" SB_RUNTIME_STATE_DIR="$sb_test_dir" \
    SILVER_BULLET_RUNTIME="$runtime" HOME="$TMP_HOME" bash "$GUARD" 2>/dev/null || true)
  assert_empty "[$runtime] non-SB cwd + stale cache does not block Bash" "$out_bash"

  out_edit=$(cd "$non_sb_work" && printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}' | \
    SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$tmpstate" SB_RUNTIME_STATE_DIR="$sb_test_dir" \
    SILVER_BULLET_RUNTIME="$runtime" HOME="$TMP_HOME" bash "$GUARD" 2>/dev/null || true)
  assert_empty "[$runtime] non-SB cwd + stale directive does not block Edit" "$out_edit"

  out_directive=$(cd "$non_sb_work" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test"}}' | \
    env -u SB_ORCHESTRATOR_PARENT SILVER_BULLET_STATE_FILE="$tmpstate" SB_RUNTIME_STATE_DIR="$sb_test_dir" \
    SILVER_BULLET_RUNTIME="$runtime" HOME="$TMP_HOME" bash "$GUARD" 2>/dev/null || true)
  assert_empty "[$runtime] non-SB cwd + blocking directive file does not block Bash" "$out_directive"

  out_sb=$(cd "$sb_work" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm run build"}}' | \
    SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$tmpstate" SB_RUNTIME_STATE_DIR="$sb_test_dir" \
    SILVER_BULLET_RUNTIME="$runtime" HOME="$TMP_HOME" bash "$GUARD" 2>/dev/null || true)
  assert_contains "[$runtime] SB cwd still blocks parent Bash" "$out_sb" "ORCHESTRATOR PARENT"

  # session-start must clear stale orchestrator markers when cwd has no SB boundary.
  printf '%s\n' "$sb_work" >"${sb_test_dir}/project-root"
  sb_orchestrator_directive_write "silver-plan" "intent" "stale for session-start" true "PLAN"
  printf '{"skill":"FLOW-PLAN"}' >"${sb_test_dir}/orchestrator-worker-active.json"
  (cd "$non_sb_work" && printf '{"source":"startup"}' | \
    SILVER_BULLET_RUNTIME="$runtime" HOME="$TMP_HOME" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$sb_test_dir" \
    bash "$SESSION_START" >/dev/null 2>&1 || true)
  assert_missing "[$runtime] session-start clears stale project-root cache" "${sb_test_dir}/project-root"
  assert_missing "[$runtime] session-start clears stale orchestrator-directive.json" "${sb_test_dir}/orchestrator-directive.json"
  assert_missing "[$runtime] session-start clears stale orchestrator-worker-active.json" "${sb_test_dir}/orchestrator-worker-active.json"

  case "$runtime" in
    cursor)
      local out_bridge
      out_bridge=$(cd "$non_sb_work" && printf '{"command":"ls"}' | \
        SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$tmpstate" SB_RUNTIME_STATE_DIR="$sb_test_dir" \
        SILVER_BULLET_RUNTIME=cursor HOME="$TMP_HOME" \
        bash "$CURSOR_BRIDGE" beforeShellExecution bash "$GUARD" 2>/dev/null || true)
      assert_not_contains "[$runtime] cursor bridge non-SB does not deny Bash" "$out_bridge" "ORCHESTRATOR PARENT"
      assert_not_contains "[$runtime] cursor bridge non-SB permission deny" "$out_bridge" '"permission":"deny"'
      ;;
    codex)
      local out_adapter
      out_adapter=$(cd "$non_sb_work" && printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | \
        SB_ORCHESTRATOR_PARENT=1 SILVER_BULLET_STATE_FILE="$tmpstate" SB_RUNTIME_STATE_DIR="$sb_test_dir" \
        SILVER_BULLET_RUNTIME=codex HOME="$TMP_HOME" \
        bash "$CODEX_ADAPTER" PreToolUse bash "$GUARD" 2>/dev/null || true)
      assert_not_contains "[$runtime] codex adapter non-SB does not deny Bash" "$out_adapter" "ORCHESTRATOR PARENT"
      assert_not_contains "[$runtime] codex adapter non-SB permission deny" "$out_adapter" '"permissionDecision":"deny"'
      ;;
  esac

  rm -rf "$sb_work" "$non_sb_work" 2>/dev/null || true
  rm -rf "${TMP_HOME}/.${runtime}/.silver-bullet/non-sb-guard-${TEST_RUN_ID}" 2>/dev/null || true
}

for runtime in claude codex cursor; do
  run_runtime_suite "$runtime"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

#!/usr/bin/env bash
# Unit tests for hooks/lib/stack-compression-coordinator.sh — surface routing and double-wrap guards
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

COORD_LIB="$REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"
COORD_HOOK="$REPO_ROOT/hooks/stack-compression-coordinator.sh"
READ_DENY_LIB="$REPO_ROOT/hooks/lib/context-mode-read-deny.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0
TMP=""
STATE_DIR=""

cleanup() {
  rm -rf "$TMP" "$STATE_DIR"
  rm -f "${SB_RUNTIME_STATE_DIR}/stack-compression-coordinator" \
    "${SB_RUNTIME_STATE_DIR}/stack-compression-mutex" \
    "${SB_RUNTIME_STATE_DIR}/stack-compression-lifecycle" 2>/dev/null || true
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=hooks/lib/stack-compression-coordinator.sh
source "$COORD_LIB"
# shellcheck source=hooks/lib/context-mode-read-deny.sh
source "$READ_DENY_LIB"

TMP="$(mktemp -d)"
STATE_DIR="$(mktemp -d)"
export SB_RUNTIME_STATE_DIR="$STATE_DIR"
export SB_RUNTIME_PRESERVE_STATE_DIR=1

write_five_tool_cfg() {
  cat >"$TMP/.silver-bullet.json" <<EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "recommended_tools": {
    "leanctx": { "enabled_by_user": true },
    "rtk": { "enabled_by_user": true },
    "context_mode": { "enabled_by_user": true }
  },
  "optimization_profiles": {
    "five_tool_routed": {
      "extends": "synergy_max",
      "stack_mode": "parallel_routed",
      "primary_fts": "context_mode",
      "routes": {
        "sb_wire": "leanctx",
        "sb_read": "leanctx",
        "sb_grep": "context_mode",
        "sb_shell": "rtk",
        "sb_slice": "context_mode",
        "sb_webfetch": "context_mode",
        "sb_graph": "graphify",
        "sb_remember": "agentmemory",
        "sb_pathjail": "leanctx",
        "sb_injection": "leanctx"
      }
    }
  }
}
EOF
}

write_five_tool_cfg
CFG="$TMP/.silver-bullet.json"

sb_stack_coordinator_needed "$CFG" && pass "coordinator needed when leanctx active" || fail "coordinator needed when leanctx active"
[[ "$(sb_stack_surface_owner "$CFG" Read)" == "leanctx" ]] && pass "Read → leanctx" || fail "Read → leanctx"
[[ "$(sb_stack_surface_owner "$CFG" Grep)" == "context_mode" ]] && pass "Grep → context_mode" || fail "Grep → context_mode"
[[ "$(sb_stack_surface_owner "$CFG" Bash)" == "rtk" ]] && pass "Bash → rtk" || fail "Bash → rtk"
[[ "$(sb_stack_surface_owner "$CFG" WebFetch)" == "context_mode" ]] && pass "WebFetch → context_mode" || fail "WebFetch → context_mode"
[[ "$(sb_stack_route_owner "$CFG" sb_graph)" == "graphify" ]] && pass "sb_graph → graphify" || fail "sb_graph → graphify"
[[ "$(sb_stack_route_owner "$CFG" sb_remember)" == "agentmemory" ]] && pass "sb_remember → agentmemory" || fail "sb_remember → agentmemory"

# Grep passthrough: CM read-deny must not intercept Grep when LeanCTX active (conflict #2).
LARGE_FILE="$TMP/large.txt"
python3 - <<PY
with open("${LARGE_FILE}", "w", encoding="utf-8") as handle:
    handle.write("x" * 7000)
PY
grep_input=$(jq -n --arg p "$LARGE_FILE" \
  '{hook_event_name:"PreToolUse", tool_name:"Grep", tool_input:{pattern:"x", path:$p}}')
if sb_context_mode_should_deny_read "$grep_input" "$CFG" "$TMP" >/dev/null 2>&1; then
  fail "Grep passthrough when LeanCTX active"
else
  pass "Grep passthrough when LeanCTX active"
fi

read_input=$(jq -n --arg p "$LARGE_FILE" \
  '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:$p}}')
if sb_context_mode_should_deny_read "$read_input" "$CFG" "$TMP" >/dev/null 2>&1; then
  pass "Read deny still applies for large file"
else
  fail "Read deny still applies for large file"
fi

# Bash double-wrap: RTK rewritten command + LeanCTX shell marker → deny.
sb_stack_should_deny_bash_double_wrap "$CFG" "rtk git status && lean-ctx shell" && pass "RTK+LeanCTX shell double-wrap denied" \
  || fail "RTK+LeanCTX shell double-wrap denied"
sb_stack_should_deny_bash_double_wrap "$CFG" "rtk git status" && fail "RTK-only bash allowed" || pass "RTK-only bash allowed"

# MCP routing blocks.
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_remember" '{"content":"x"}' && pass "lctx_remember denied" \
  || fail "lctx_remember denied"
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_graph" '{"query":"graphify codebase hooks/"}' && pass "lctx_graph code query denied" \
  || fail "lctx_graph code query denied"
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_fetch" '{"url":"https://example.com"}' && pass "lctx_fetch denied (CM owns webfetch)" \
  || fail "lctx_fetch denied (CM owns webfetch)"

# Hook integration: CallMcpTool lctx_remember denied via coordinator hook.
cat >"$TMP/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
git -C "$TMP" init -q
export SILVER_BULLET_PROJECT_ROOT="$TMP"
rm -f "${SB_RUNTIME_STATE_DIR}/project-root" 2>/dev/null || true
mcp_input=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:{server:"leanctx", toolName:"lctx_remember", arguments:{content:"test"}}}')
hook_out="$(cd "$TMP" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$STATE_DIR" \
  printf '%s' "$mcp_input" | bash "$COORD_HOOK" 2>/dev/null || true)"
if printf '%s' "$hook_out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "coordinator hook denies lctx_remember"
else
  fail "coordinator hook denies lctx_remember — got: $hook_out"
fi

# Lifecycle ordering markers.
sb_stack_lifecycle_mark "context_mode_precompact"
sleep 1
sb_stack_lifecycle_mark "agentmemory_snapshot"
sleep 1
sb_stack_lifecycle_mark "leanctx_compact"
sb_stack_lifecycle_order_ok && pass "lifecycle order CM→AM→LeanCTX" || fail "lifecycle order CM→AM→LeanCTX"

# RED-1: mutex violation → compliant ctx_search clears → subsequent Read allowed.
sb_stack_record_double_compression "$CFG" "sb_shell" "leanctx" "rtk"
sb_stack_mutual_exclusion_is_clean "$CFG" && fail "RED-1: mutex dirty after seeded violation" \
  || pass "RED-1: mutex dirty after seeded violation"

recovery_mcp=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:{server:"context-mode", toolName:"ctx_search", arguments:{queries:["test"]}}}')
recovery_out="$(cd "$TMP" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$STATE_DIR" \
  printf '%s' "$recovery_mcp" | bash "$COORD_HOOK" 2>/dev/null || true)"
if printf '%s' "$recovery_out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  fail "RED-1: compliant ctx_search denied during recovery — got: $recovery_out"
else
  pass "RED-1: compliant ctx_search allowed during recovery"
fi
sb_stack_mutual_exclusion_is_clean "$CFG" && pass "RED-1: mutex clean after recovery MCP" \
  || fail "RED-1: mutex clean after recovery MCP"

read_after=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:"README.md"}}')
read_out="$(cd "$TMP" && SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$STATE_DIR" \
  printf '%s' "$read_after" | bash "$COORD_HOOK" 2>/dev/null || true)"
if printf '%s' "$read_out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
  && printf '%s' "$read_out" | grep -q 'sb_stack_double_compression'; then
  fail "RED-1: Read denied after recovery — got: $read_out"
else
  pass "RED-1: Read allowed after recovery MCP"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1

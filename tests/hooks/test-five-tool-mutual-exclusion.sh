#!/usr/bin/env bash
# Five-tool mutual-exclusion — RTK shell + LeanCTX MCP blocks; coordinator denies wrong-owner lctx_* tools
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

COORD_LIB="$REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"
COORD_HOOK="$REPO_ROOT/hooks/stack-compression-coordinator.sh"
TOOL_INPUT_LIB="$REPO_ROOT/hooks/lib/tool-input.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0
TMP=""
STATE_DIR=""

cleanup() {
  rm -rf "$TMP" "$STATE_DIR"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=hooks/lib/stack-compression-coordinator.sh
source "$COORD_LIB"
# shellcheck source=hooks/lib/tool-input.sh
source "$TOOL_INPUT_LIB"

TMP="$(mktemp -d)"
STATE_DIR="$(mktemp -d)"
export SB_RUNTIME_STATE_DIR="$STATE_DIR"

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
      "stack_mode": "parallel_routed",
      "primary_fts": "context_mode",
      "routes": {
        "sb_read": "leanctx",
        "sb_grep": "context_mode",
        "sb_shell": "rtk",
        "sb_slice": "context_mode",
        "sb_webfetch": "context_mode",
        "sb_graph": "graphify",
        "sb_remember": "agentmemory"
      }
    }
  }
}
EOF
cat >"$TMP/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
git -C "$TMP" init -q
CFG="$TMP/.silver-bullet.json"
export SILVER_BULLET_PROJECT_ROOT="$TMP"

assert_deny_hook() {
  local label="$1" input="$2" needle="${3:-STACK ROUTING}"
  local out
  out="$(cd "$TMP" && printf '%s' "$input" | bash "$COORD_HOOK" 2>/dev/null || true)"
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
    && printf '%s' "$out" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label — got: $out"
  fi
}

sb_stack_mutual_exclusion_is_clean "$CFG" && pass "mutex clean before violation" || fail "mutex clean before violation"

# Lib-level: RTK rewrite + LeanCTX shell marker on same command.
sb_stack_should_deny_bash_double_wrap "$CFG" "rtk git status && lean-ctx shell" \
  && pass "lib denies RTK+LeanCTX shell on same Bash" \
  || fail "lib denies RTK+LeanCTX shell on same Bash"

# Record RTK ownership then attempt LeanCTX shell on subsequent command.
sb_stack_record_surface_owner "$CFG" "sb_shell" "rtk"
sb_stack_should_deny_bash_double_wrap "$CFG" "SB_LEANCTX_SHELL=1 git status" \
  && pass "lib denies LeanCTX shell after RTK recorded" \
  || fail "lib denies LeanCTX shell after RTK recorded"

# MCP blocks via lib.
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_remember" '{"content":"decision"}' \
  && pass "lib denies lctx_remember" || fail "lib denies lctx_remember"
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_graph" '{"query":"explain hooks/lib dependency import"}' \
  && pass "lib denies lctx_graph code query" || fail "lib denies lctx_graph code query"
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_shell" '{"command":"git status"}' \
  && pass "lib denies lctx_shell (RTK owns sb_shell)" || fail "lib denies lctx_shell (RTK owns sb_shell)"
sb_stack_should_deny_mcp_tool "$CFG" "leanctx" "lctx_fetch" '{"url":"https://example.com"}' \
  && pass "lib denies lctx_fetch (CM owns sb_webfetch)" || fail "lib denies lctx_fetch (CM owns sb_webfetch)"

# Hook-level integration.
bash_input=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{command:"rtk git status && lean-ctx shell"}}')
assert_deny_hook "hook denies Bash double-wrap" "$bash_input" "double-compression"

remember_input=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:{server:"leanctx", toolName:"lctx_remember", arguments:{content:"note"}}}')
assert_deny_hook "hook denies lctx_remember" "$remember_input" "lctx_remember"

graph_input=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:{server:"leanctx", toolName:"lctx_graph", arguments:{query:"graphify codebase symbol dependency"}}}')
assert_deny_hook "hook denies lctx_graph code path" "$graph_input" "lctx_graph"

# Mutual-exclusion state records violation and blocks subsequent coordinator passes.
sb_stack_record_double_compression "$CFG" "sb_shell" "leanctx" "rtk"
sb_stack_mutual_exclusion_is_clean "$CFG" && fail "mutex dirty after violation" || pass "mutex dirty after violation"

allow_input=$(jq -n \
  '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:"README.md"}}')
allow_out="$(cd "$TMP" && printf '%s' "$allow_input" | bash "$COORD_HOOK" 2>/dev/null || true)"
if printf '%s' "$allow_out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
  && printf '%s' "$allow_out" | grep -q 'sb_stack_double_compression'; then
  pass "hook blocks when mutex state dirty"
else
  fail "hook blocks when mutex state dirty — got: $allow_out"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1

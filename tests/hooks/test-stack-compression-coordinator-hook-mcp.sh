#!/usr/bin/env bash
# Behavior tests for hooks/stack-compression-coordinator.sh: MCP routing and helper-failure paths
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
tg2_install_jq_stub

HOOK=hooks/stack-compression-coordinator.sh
COORD="$SB_RUNTIME_STATE_DIR/stack-compression-coordinator"
MUTEX="$SB_RUNTIME_STATE_DIR/stack-compression-mutex"
LEAN_CFG='{"sb_initiated":true,
 "recommended_tools":{"leanctx":{"enabled_by_user":true},"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}},
 "optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx","sb_shell":"rtk","sb_graph":"graphify","sb_remember":"agentmemory","sb_webfetch":"context_mode","sb_slice":"context_mode","sb_grep":"context_mode"}}}}'

reset() { rm -f "$COORD" "$MUTEX" "$SB_RUNTIME_STATE_DIR/project-root"; tg2_cfg "$LEAN_CFG"; }
dirty_mutex() { printf '{"violations":[{"route":"sb_shell","attempted":"leanctx","incumbent":"rtk","reason":"x","epoch":1}]}' >"$MUTEX"; }
mutex_count() { [[ -f "$MUTEX" ]] && jq -r '.violations | length' "$MUTEX" || echo "none"; }
owner_of() { [[ -f "$COORD" ]] && jq -r --arg r "$1" '.surfaces[$r].owner // ""' "$COORD" || true; }
mcp_input() { # tool [server] [arguments-json]
  jq -cn --arg t "$1" --arg s "${2:-}" --argjson a "${3:-null}" \
    '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:({toolName:$t} + (if $s != "" then {server:$s} else {} end) + (if $a != null then {arguments:$a} else {} end))}'
}
tool_input() { jq -cn --arg t "$1" --arg f "${2:-}" '{hook_event_name:"PreToolUse", tool_name:$t, tool_input:{file_path:$f}}'; }


# ----------------------------------------------------------------------- MCP
reset
for t in lctx_remember lctx_shell lctx_fetch lctx_webfetch; do
  tg2_run "$HOOK" "$(mcp_input "$t" leanctx)"
  assert_denied "MCP $t is denied on a surface owned by another tool" "STACK ROUTING"
done
assert_contains "MCP denial names the tool and route" "$(tg2_reason)" "lctx_webfetch blocked on sb_webfetch (owner: context_mode)"
tg2_run "$HOOK" "$(mcp_input lctx_graph leanctx '{"query":"which symbol imports hooks/foo.sh"}')"
assert_denied "code-looking lctx_graph query is denied" "STACK ROUTING"
tg2_run "$HOOK" "$(mcp_input lctx_graph leanctx '{"query":"what is the weather"}')"
assert_silent_ok "non-code lctx_graph query is allowed"
tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"MCP", tool_input:{name:"lctx_graph", mcpServer:"leanctx", args:{query:"dependency graph of the codebase"}}}')"
assert_denied "MCP/name/mcpServer/args field aliases are understood" "STACK ROUTING"
tg2_run "$HOOK" "$(mcp_input lctx_graph leanctx '{"query":"which symbol imports hooks/foo.sh"}')" JQ_FAIL='.tool_input.arguments'
assert_silent_ok "unreadable MCP arguments are treated as empty"
reset; tg2_run "$HOOK" "$(mcp_input lctx_read_ast leanctx)"
assert_silent_ok "routed MCP read is allowed"
assert_eq "routed MCP read is recorded" "leanctx" "$(owner_of sb_read)"
tg2_run "$HOOK" "$(mcp_input ctx_execute context-mode)" JQ_FAIL='.tool_input.server'
assert_silent_ok "unreadable MCP server name does not matter"
assert_eq "ctx_execute is recorded under sb_slice" "context_mode" "$(owner_of sb_slice)"
reset; tg2_run "$HOOK" "$(mcp_input browser_click)"
assert_silent_ok "unrouted MCP tool is ignored"
assert_file_absent "unrouted MCP tool records nothing" "$COORD"
tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:{}}')"
assert_silent_ok "MCP call without a tool name is ignored"
tg2_run "$HOOK" "$(mcp_input lctx_read_ast leanctx)" JQ_FAIL='.tool_input.toolName'
assert_silent_ok "unreadable MCP tool name is ignored"
assert_file_absent "unreadable MCP tool name records nothing" "$COORD"
reset; printf '{"surfaces":{"sb_read":{"owner":"context_mode","epoch":1}}}' >"$COORD"
tg2_run "$HOOK" "$(mcp_input lctx_read_ast leanctx)"
assert_denied "MCP tool whose route has a different recorded owner is denied" "STACK ROUTING"

# ----------------------------------- library functions failing under set -e
# A coordinator-library wrapper that re-defines selected helpers to fail, to prove the hook
# tolerates helper failures (every substitution is guarded) and degrades to "no owner".
# DEFENSIVE-PATH COVERAGE: with the real library these helpers never fail for the routes the
# hook passes them (every known route has a default owner), so the STUB_* overrides below do
# not model a reachable production state; they only prove the `|| true` guards hold under
# `set -e` if a future library change makes a helper fail.
reset; tg2_farm failing-helpers "$HOOK" stack-compression-coordinator.sh
tg2_farm_stub stack-compression-coordinator.sh "source \"$TL_REPO_ROOT/hooks/lib/stack-compression-coordinator.sh\"
[[ -z \"\${STUB_NO_ROUTE_OWNER:-}\" ]] || sb_stack_route_owner() { return 1; }
[[ -z \"\${STUB_NO_SURFACE_OWNER:-}\" ]] || sb_stack_surface_owner() { return 1; }
[[ -z \"\${STUB_NO_MCP_ROUTE:-}\" ]] || sb_stack_mcp_tool_route() { return 1; }
[[ -z \"\${STUB_ALWAYS_DENY_MCP:-}\" ]] || sb_stack_should_deny_mcp_tool() { return 0; }"
farm_run() { reset; TG2_REPO="$TG2_FARM" tg2_run "$HOOK" "$@"; }
farm_run "$(tg2_bash_input 'ls')" STUB_NO_ROUTE_OWNER=1
assert_silent_ok "shell route without an owner records nothing"
assert_file_absent "no shell owner means no coordinator state" "$COORD"
farm_run "$(tool_input Read /x)" STUB_NO_SURFACE_OWNER=1
assert_silent_ok "Read without a surface owner records nothing"
assert_file_absent "no Read owner means no coordinator state" "$COORD"
farm_run "$(tool_input WebFetch)" STUB_NO_SURFACE_OWNER=1
assert_silent_ok "WebFetch without a surface owner records nothing"
assert_file_absent "no WebFetch owner means no coordinator state" "$COORD"
farm_run "$(mcp_input lctx_read_ast leanctx)" STUB_NO_MCP_ROUTE=1
assert_silent_ok "MCP tool whose route cannot be resolved is ignored"
assert_file_absent "unresolvable MCP route records nothing" "$COORD"
farm_run "$(mcp_input lctx_read_ast leanctx)" STUB_NO_ROUTE_OWNER=1
assert_silent_ok "MCP route without an owner records nothing"
assert_file_absent "MCP route without an owner leaves no coordinator state" "$COORD"
farm_run "$(mcp_input lctx_read_ast leanctx)" STUB_ALWAYS_DENY_MCP=1 STUB_NO_MCP_ROUTE=1 STUB_NO_ROUTE_OWNER=1
assert_denied "a denial with unresolved route and owner still produces a deny" "STACK ROUTING"

tl_results

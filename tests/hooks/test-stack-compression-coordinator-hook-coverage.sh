#!/usr/bin/env bash
# Behavior tests for hooks/stack-compression-coordinator.sh (PreToolUse stack routing gate)
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
TWO_CFG='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}}}'
ONE_CFG='{"sb_initiated":true,"recommended_tools":{"rtk":{"enabled_by_user":true}}}'
EDIT="$(tg2_edit_input)"

reset() { rm -f "$COORD" "$MUTEX" "$SB_RUNTIME_STATE_DIR/project-root"; tg2_cfg "${1:-$LEAN_CFG}"; }
dirty_mutex() { printf '{"violations":[{"route":"sb_shell","attempted":"leanctx","incumbent":"rtk","reason":"x","epoch":1}]}' >"$MUTEX"; }
mutex_count() { [[ -f "$MUTEX" ]] && jq -r '.violations | length' "$MUTEX" || echo "none"; }
owner_of() { [[ -f "$COORD" ]] && jq -r --arg r "$1" '.surfaces[$r].owner // ""' "$COORD" || true; }
mcp_input() { # tool [server] [arguments-json]
  jq -cn --arg t "$1" --arg s "${2:-}" --argjson a "${3:-null}" \
    '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:({toolName:$t} + (if $s != "" then {server:$s} else {} end) + (if $a != null then {arguments:$a} else {} end))}'
}
tool_input() { jq -cn --arg t "$1" --arg f "${2:-}" '{hook_event_name:"PreToolUse", tool_name:$t, tool_input:{file_path:$f}}'; }

tg2_scenario_block() { reset; dirty_mutex; }
tg2_scenario_off() {
  case "$1" in
    optout) jq '.recommended_tools |= with_entries(.value.enabled_by_user=false)' <<<"$LEAN_CFG" >"$TG2_CFG" ;;
    suspended) jq '.recommended_tools |= with_entries(.value.enforcement_suspended=true)' <<<"$LEAN_CFG" >"$TG2_CFG" ;;
  esac
}
# While the mutex is dirty every tool call except a compliant recovery is blocked, including
# payloads whose tool cannot be determined.
TG2_GARBAGE_DENIES=yes tg2_gate_suite "$HOOK" stack-compression-coordinator "$EDIT" "STACK COMPRESSION CONFLICT" "$TG2_PROJ/src/app.js" no yes

# ------------------------------------------------------------- not needed
reset "$ONE_CFG"; dirty_mutex
tg2_run "$HOOK" "$EDIT"
assert_silent_ok "a single compression tool does not need the coordinator"
reset "$TWO_CFG"
tg2_run "$HOOK" "$(tg2_bash_input 'ls')"
assert_silent_ok "two tools without leanctx: shell command passes"
assert_eq "two-tool profile records rtk as shell owner" "rtk" "$(owner_of sb_shell)"
tg2_run "$HOOK" "$(tool_input Read /x)"
assert_eq "two-tool profile routes Read to context_mode" "context_mode" "$(owner_of sb_read)"

# ----------------------------------------------------------------- mutex handling
reset; dirty_mutex
tg2_run "$HOOK" "$(tool_input Read /x)"
assert_denied "dirty mutex: native Read cannot recover" "STACK COMPRESSION CONFLICT"
tg2_run "$HOOK" "$(tool_input WebFetch)"
assert_denied "dirty mutex: WebFetch cannot recover" "STACK COMPRESSION CONFLICT"
tg2_run "$HOOK" "$(mcp_input lctx_remember agentmemory)"
assert_denied "dirty mutex: wrong-owner MCP tool cannot recover" "STACK COMPRESSION CONFLICT"
tg2_run "$HOOK" "$(mcp_input browser_click)"
assert_denied "dirty mutex: unrouted MCP tool cannot recover" "STACK COMPRESSION CONFLICT"
assert_eq "failed recovery keeps the violation" "1" "$(mutex_count)"
tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"CallMcpTool", tool_input:{}}')"
assert_denied "dirty mutex: MCP call without a tool name cannot recover" "STACK COMPRESSION CONFLICT"

reset; dirty_mutex
tg2_run "$HOOK" "$(tg2_bash_input 'ls -la')"
assert_silent_ok "dirty mutex: a compliant shell command recovers"
assert_eq "recovery clears the violations" "none" "$(mutex_count)"
assert_eq "recovery records the shell owner" "rtk" "$(owner_of sb_shell)"
reset; dirty_mutex
tg2_run "$HOOK" "$(mcp_input lctx_read_ast leanctx)"
assert_silent_ok "dirty mutex: a routed MCP read recovers"
assert_eq "MCP recovery clears the violations" "none" "$(mutex_count)"
assert_eq "MCP recovery records the read owner" "leanctx" "$(owner_of sb_read)"

# -------------------------------------------------------- bash double wrapping
reset; printf '{"surfaces":{"sb_shell":{"owner":"rtk","epoch":1}}}' >"$COORD"
tg2_run "$HOOK" "$(tg2_bash_input 'lean-ctx shell ls')"
assert_denied "leanctx shell wrap on an rtk-owned surface is denied" "Bash double-compression blocked"
assert_eq "double wrap records a violation" "1" "$(mutex_count)"
for tool in Shell shell exec_command; do
  reset; printf '{"surfaces":{"sb_shell":{"owner":"rtk","epoch":1}}}' >"$COORD"
  tg2_run "$HOOK" "$(tg2_bash_input 'SB_LEANCTX_SHELL=1 ls' "$tool")"
  assert_denied "$tool: SB_LEANCTX_SHELL marker is denied" "STACK ROUTING"
done
reset; tg2_run "$HOOK" "$(tg2_bash_input 'lean-ctx shell ls')"
assert_silent_ok "leanctx shell wrap without an rtk incumbent is allowed"
reset; tg2_run "$HOOK" "$(tg2_bash_input 'git status')"
assert_silent_ok "plain shell command is allowed"
assert_eq "plain shell command records rtk as owner" "rtk" "$(owner_of sb_shell)"
assert_eq "plain shell command leaves the mutex clean" "none" "$(mutex_count)"
reset; tg2_run "$HOOK" "$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Bash", tool_input:{}}')"
assert_silent_ok "shell call without a command is ignored"
assert_file_absent "shell call without a command records nothing" "$COORD"

# ------------------------------------------------------------ Read/Grep/WebFetch
reset; tg2_run "$HOOK" "$(tool_input Read /x)"
assert_silent_ok "Read is routed silently"
assert_eq "Read is recorded under sb_read for leanctx" "leanctx" "$(owner_of sb_read)"
tg2_run "$HOOK" "$(tool_input Grep)"
assert_eq "Grep is recorded under sb_grep for context_mode" "context_mode" "$(owner_of sb_grep)"
tg2_run "$HOOK" "$(tool_input WebFetch)"
assert_eq "WebFetch is recorded under sb_webfetch for context_mode" "context_mode" "$(owner_of sb_webfetch)"
reset; dirty_mutex >/dev/null; rm -f "$MUTEX"; printf '{"violations":[]}' >"$MUTEX"
tg2_run "$HOOK" "$(tool_input Read /x)"
assert_eq "a clean-state routed success keeps the mutex empty/removed" "none" "$(mutex_count)"
reset; tg2_run "$HOOK" "$(tool_input Edit /x)"
assert_silent_ok "other tools pass through untouched"
assert_file_absent "other tools record nothing" "$COORD"

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

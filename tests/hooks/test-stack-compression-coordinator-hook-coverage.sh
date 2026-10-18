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

tl_results

#!/usr/bin/env bash
# Shared PreToolUse gate assertions, part a (deny, audit, bridge, input shapes) for hooks/stack-compression-coordinator.sh (tg2_gate_suite)
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
tg2_install_jq_stub

HOOK=hooks/stack-compression-coordinator.sh
# Coordinator state is scoped to one project and one host session (R5-13); the payloads carry no session id.
COORD="$(source "$TL_REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"; SB_STACK_SESSION=""; export SB_STACK_SESSION; sb_stack_coordinator_state_path "$TG2_CFG")"
MUTEX="$(source "$TL_REPO_ROOT/hooks/lib/stack-compression-coordinator.sh"; SB_STACK_SESSION=""; export SB_STACK_SESSION; sb_stack_mutex_state_path "$TG2_CFG")"
LEAN_CFG='{"sb_initiated":true,
 "recommended_tools":{"leanctx":{"enabled_by_user":true},"rtk":{"enabled_by_user":true},"context_mode":{"enabled_by_user":true}},
 "optimization_profiles":{"five_tool_routed":{"routes":{"sb_read":"leanctx","sb_shell":"rtk","sb_graph":"graphify","sb_remember":"agentmemory","sb_webfetch":"context_mode","sb_slice":"context_mode","sb_grep":"context_mode"}}}}'
# The coordinator guards the compression surfaces (Read, Grep, WebFetch, Bash, MCP); edits are not its business.
EDIT="$(jq -cn '{hook_event_name:"PreToolUse", tool_name:"Read", tool_input:{file_path:"/x"}}')"

reset() { rm -f "$COORD" "$MUTEX" "$SB_RUNTIME_STATE_DIR/project-root"; tg2_cfg "$LEAN_CFG"; }
dirty_mutex() { mkdir -p "$(dirname "$MUTEX")"; printf '{"violations":[{"route":"sb_shell","attempted":"leanctx","incumbent":"rtk","reason":"x","epoch":1}]}' >"$MUTEX"; }
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
# While the mutex is dirty the compression surfaces are blocked except for a compliant recovery;
# a payload that cannot be parsed is never blocked.
TG2_SUITE_PART=a tg2_gate_suite "$HOOK" stack-compression-coordinator "$EDIT" "STACK COMPRESSION CONFLICT" "" no yes

tl_results

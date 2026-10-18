#!/usr/bin/env bash
# Shared PreToolUse gate assertions, part a (deny, audit, bridge, input shapes) for hooks/stack-compression-coordinator.sh (tg2_gate_suite)
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
EDIT="$(tg2_edit_input)"

reset() { rm -f "$COORD" "$MUTEX" "$SB_RUNTIME_STATE_DIR/project-root"; tg2_cfg "$LEAN_CFG"; }
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
TG2_GARBAGE_DENIES=yes TG2_SUITE_PART=a tg2_gate_suite "$HOOK" stack-compression-coordinator "$EDIT" "STACK COMPRESSION CONFLICT" "$TG2_PROJ/src/app.js" no yes

tl_results

#!/usr/bin/env bash
# Behavior tests for the PostToolUse usage recorders (record-graphify-query.sh, record-recommended-mcp.sh)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project

AM_STATE="$SB_RUNTIME_STATE_DIR/agentmemory-usage"
GF_STATE="$SB_RUNTIME_STATE_DIR/graphify-query"
LC_STATE="$SB_RUNTIME_STATE_DIR/leanctx-usage"
RTK_STATE="$SB_RUNTIME_STATE_DIR/rtk-usage"
all_cfg='{"sb_initiated":true,"recommended_tools":{
  "agentmemory":{"enabled_by_user":true},
  "graphify":{"enabled_by_user":true},
  "leanctx":{"enabled_by_user":true},
  "rtk":{"enabled_by_user":true,"install_status":"installed"}}}'
reset() { rm -f "$AM_STATE" "$GF_STATE" "$LC_STATE" "$RTK_STATE" "$SB_RUNTIME_STATE_DIR/project-root"; tg2_cfg "$all_cfg"; }
msg() { printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message // ""' 2>/dev/null || true; }
state_is_epoch() { [[ -f "$1" && "$(<"$1")" =~ ^[0-9]+$ ]]; }
assert_recorded() { # name state
  if state_is_epoch "$2" && [[ "$TL_STATUS" == 0 ]]; then tl_pass "$1"; else tl_fail "$1 (state '$2' missing/invalid, status=$TL_STATUS out=$TL_OUT)"; fi
}
assert_not_recorded() { # name state
  if [[ ! -e "$2" && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} state_exists=$([[ -e "$2" ]] && echo y || echo n))"; fi
}

# prologue_suite <hook> <state> <good-input> <good-message> <tool-id> [bash-exit-semantics]
prologue_suite() {
  local hook="$1" state="$2" good="$3" message="$4" tool="$5" name
  name="${hook##*/}"
  reset
  tg2_run "$hook" "$good"
  assert_recorded "$name: baseline records usage" "$state"
  assert_eq "$name: baseline confirmation" "$message" "$(msg)"

  reset; tg2_run "$hook" ""
  assert_not_recorded "$name: empty stdin is a no-op" "$state"

  reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$hook" "$good"
  assert_not_recorded "$name: missing jq is a no-op" "$state"

  reset; tg2_run "$hook" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Read", tool_input:{file_path:"/x"}}')"
  assert_not_recorded "$name: unrelated tool is a no-op" "$state"

  reset; TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$hook" "$good"
  assert_not_recorded "$name: outside any SB project is a no-op" "$state"

  reset; rm -f "$TG2_CFG"; tg2_run "$hook" "$good"
  assert_not_recorded "$name: missing project config is a no-op" "$state"

  reset; jq --arg t "$tool" '.recommended_tools[$t].enabled_by_user = false' <<<"$all_cfg" >"$TG2_CFG"
  tg2_run "$hook" "$good"
  assert_not_recorded "$name: opted-out tool is a no-op" "$state"

  reset; jq --arg t "$tool" '.recommended_tools[$t].enforcement_suspended = true' <<<"$all_cfg" >"$TG2_CFG"
  tg2_run "$hook" "$good"
  assert_not_recorded "$name: suspended enforcement is a no-op" "$state"

  # Library farm: without sb-project-gate.sh the hook walks upward itself.
  reset; tg2_farm gate "hooks/$name" sb-project-gate.sh project-active.sh
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TG2_PROJ/src" tg2_run "hooks/$name" "$good"
  assert_recorded "$name: farm without gate lib still records via its own walk-up" "$state"
  # Without any lib dir the hook cannot source anything and stays inert (fail-open).
  reset; tg2_farm nolib "hooks/$name" -
  TG2_REPO="$TG2_FARM" tg2_run "hooks/$name" "$good"
  assert_not_recorded "$name: missing lib dir fails open" "$state"
}

# Walk-up fallback (no sb-project-gate.sh): finds config in a parent, stops at .git / root.
walkup_suite() { # hook state good tool-with-gate-libs-note
  local hook="$1" state="$2" good="$3" name="${1##*/}"
  reset; tg2_farm walk "hooks/$name" sb-project-gate.sh project-active.sh
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TG2_PROJ/src" tg2_run "hooks/$name" "$good"
  if state_is_epoch "$state"; then tl_pass "$name: walk-up fallback finds parent config"; else tl_fail "$name: walk-up fallback did not record (status=$TL_STATUS err=$TL_ERR)"; fi
  reset
  mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q 2>/dev/null
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TL_TMP/gitonly/sub" tg2_run "hooks/$name" "$good"
  assert_not_recorded "$name: walk-up stops at .git boundary" "$state"
  reset
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TL_TMP/outside" tg2_run "hooks/$name" "$good"
  assert_not_recorded "$name: walk-up stops at filesystem root" "$state"
}

# ------------------------------------------------------------------ graphify
GFH=hooks/record-graphify-query.sh
gf_cmd="$(tg2_bash_input 'graphify query "how does X work"' Bash PostToolUse)"
prologue_suite "$GFH" "$GF_STATE" "$gf_cmd" "✅ Graphify query recorded" graphify
walkup_suite "$GFH" "$GF_STATE" "$gf_cmd"
reset; tg2_run "$GFH" "$(tg2_bash_input 'graphify query x' Bash PostToolUse 2)"
assert_not_recorded "graphify: failed query is not recorded" "$GF_STATE"
reset; tg2_run "$GFH" "$(tg2_bash_input 'graphify update .' Bash PostToolUse)"
assert_not_recorded "graphify: index build is not a retrieval" "$GF_STATE"
reset; tg2_run "$GFH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{}}')"
assert_not_recorded "graphify: shell tool without command is a no-op" "$GF_STATE"
reset; tg2_run "$GFH" "$(tg2_bash_input 'graphify explain Y' shell PostToolUse)"
assert_recorded "graphify: shell tool name records" "$GF_STATE"
reset; mkdir -p "$SB_RUNTIME_STATE_DIR/gf-dir"
jq --arg p "$SB_RUNTIME_STATE_DIR/gf-dir" '.recommended_tools.graphify.query_state_file=$p' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$GFH" "$gf_cmd"
assert_silent_ok "graphify: failed state write is silent"
rmdir "$SB_RUNTIME_STATE_DIR/gf-dir"
reset; tg2_farm notoolinput-gf "$GFH" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$GFH" "$gf_cmd"
assert_recorded "graphify: jq fallbacks record without tool-input.sh" "$GF_STATE"

# ------------------------------------------------------ recommended MCP usage
RMH=hooks/record-recommended-mcp.sh
reset; tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_recorded "recommended-mcp: agentmemory server + memory tool records" "$AM_STATE"
assert_eq "recommended-mcp: confirmation" "✅ recommended MCP usage recorded" "$(msg)"
reset; tg2_run "$RMH" "$(tg2_mcp_input agentmemory list_files MCP)"
assert_recorded "recommended-mcp: agentmemory server alone records" "$AM_STATE"
reset; tg2_run "$RMH" "$(tg2_mcp_input some-server save_memory CallMcpTool)"
assert_recorded "recommended-mcp: memory tool on another server records" "$AM_STATE"
reset; tg2_run "$RMH" "$(tg2_mcp_input some-server store_note CallMcpTool)"
assert_recorded "recommended-mcp: store* tool records" "$AM_STATE"
reset; tg2_run "$RMH" "$(tg2_mcp_input some-server list_files CallMcpTool)"
assert_not_recorded "recommended-mcp: unrelated server and tool is a no-op" "$AM_STATE"
reset; tg2_run "$RMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"CallMcpTool", tool_input:{server:"agentmemory"}}')"
assert_not_recorded "recommended-mcp: missing tool name is a no-op" "$AM_STATE"
reset; tg2_run "$RMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"CallMcpTool", tool_input:{toolName:"search"}}')"
assert_not_recorded "recommended-mcp: missing server is a no-op" "$AM_STATE"
reset; tg2_run "$RMH" "$(tg2_bash_input 'agentmemory search x' Bash PostToolUse)"
assert_not_recorded "recommended-mcp: non-MCP tool is a no-op" "$AM_STATE"
reset; tg2_run "$RMH" ""
assert_not_recorded "recommended-mcp: empty stdin is a no-op" "$AM_STATE"
reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: missing jq is a no-op" "$AM_STATE"
reset; TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: outside SB project is a no-op" "$AM_STATE"
reset; mkdir -p "$TL_TMP/gitonly2/sub"; git -C "$TL_TMP/gitonly2" init -q 2>/dev/null
TG2_CWD="$TL_TMP/gitonly2/sub" TG2_PROJECT_ROOT="" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: walk stops at .git boundary" "$AM_STATE"
reset; TG2_CWD="$TG2_PROJ/src" TG2_PROJECT_ROOT="" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_recorded "recommended-mcp: walk finds config in parent dir" "$AM_STATE"
reset; jq '.recommended_tools.agentmemory.enabled_by_user=false' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: opted-out agentmemory is a no-op" "$AM_STATE"
reset; tg2_farm rm-nogate "$RMH" agentmemory-gate.sh
TG2_REPO="$TG2_FARM" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: without agentmemory-gate.sh no usage can be recorded" "$AM_STATE"
reset; tg2_farm rm-nolib "$RMH" -
TG2_REPO="$TG2_FARM" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: missing lib dir fails open" "$AM_STATE"
reset; tg2_farm rm-notoolinput "$RMH" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_recorded "recommended-mcp: jq fallback tool-name parse records" "$AM_STATE"
reset; mkdir -p "$SB_RUNTIME_STATE_DIR/am-dir"
jq --arg p "$SB_RUNTIME_STATE_DIR/am-dir" '.recommended_tools.agentmemory.usage_state_file=$p' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$RMH" "$(tg2_mcp_input agentmemory save_memory CallMcpTool)"
assert_silent_ok "recommended-mcp: failed state write is silent"
rmdir "$SB_RUNTIME_STATE_DIR/am-dir"

# ------------------------------------------------ injected library faults
# A farm whose tool-input.sh answers from env (so unparsable JSON still routes to a tool)
# exercises the "jq failed -> default" fallbacks; a farm whose project-active.sh reports
# "not initiated" exercises the initiation guards.
stub_tool_input='sb_tool_name() { printf "%s" "${STUB_TOOL_NAME:-}"; }
sb_tool_command_string() { printf "%s" "${STUB_CMD:-}"; }
sb_tool_file_path() { printf "%s" "${STUB_FILE:-}"; }'
stub_inactive='sb_project_active() { return 1; }
sb_project_is_initiated() { return 1; }
sb_project_gate_or_exit() { exit 0; }'

fault_suite() { # hook state bash-cmd mcp-tool-env-ok
  local hook="$1" state="$2" cmd="$3" name="${1##*/}"
  reset; TG2_STDIN_UNREADABLE=1 tg2_run "$hook" ""
  assert_not_recorded "$name: unreadable stdin is a no-op" "$state"
  if [[ -n "$cmd" ]]; then
    reset; tg2_farm "ti-$name" "$hook" tool-input.sh; tg2_farm_stub tool-input.sh "$stub_tool_input"
    TG2_REPO="$TG2_FARM" tg2_run "$hook" "not json" STUB_TOOL_NAME=Bash "STUB_CMD=$cmd"
    assert_recorded "$name: unparsable exit_code defaults to success" "$state"
  fi
  reset; tg2_farm "inactive-$name" "$hook" project-active.sh; tg2_farm_stub project-active.sh "$stub_inactive"
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$4" STUB_TOOL_NAME="${5:-Bash}" "STUB_CMD=$cmd"
  assert_not_recorded "$name: not-initiated project is a no-op" "$state"
}
fault_suite "$GFH" "$GF_STATE" 'graphify query x' "$gf_cmd"
reset; tg2_farm ti-rm "$RMH" tool-input.sh; tg2_farm_stub tool-input.sh "$stub_tool_input"
TG2_REPO="$TG2_FARM" tg2_run "$RMH" "not json" STUB_TOOL_NAME=CallMcpTool
assert_not_recorded "recommended-mcp: unparsable MCP payload records nothing" "$AM_STATE"
reset; TG2_STDIN_UNREADABLE=1 tg2_run "$RMH" ""
assert_not_recorded "recommended-mcp: unreadable stdin is a no-op" "$AM_STATE"
reset; tg2_farm inactive-rm "$RMH" project-active.sh; tg2_farm_stub project-active.sh "$stub_inactive"
TG2_REPO="$TG2_FARM" tg2_run "$RMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "recommended-mcp: not-initiated project is a no-op" "$AM_STATE"

tl_results

#!/usr/bin/env bash
# Behavior tests for the PostToolUse usage recorders (record-leanctx-usage.sh, record-token-compression-usage.sh)
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

# -------------------------------------------------------------------- leanctx
LCH=hooks/record-leanctx-usage.sh
lc_cmd="$(tg2_bash_input 'lean-ctx read src/app.js' Bash PostToolUse)"
prologue_suite "$LCH" "$LC_STATE" "$lc_cmd" "✅ LeanCTX usage recorded" leanctx
walkup_suite "$LCH" "$LC_STATE" "$lc_cmd"
reset; tg2_run "$LCH" "$(tg2_bash_input 'lean-ctx read x' Bash PostToolUse 1)"
assert_not_recorded "leanctx: failed CLI command is not recorded" "$LC_STATE"
reset; tg2_run "$LCH" "$(tg2_bash_input 'ls' Bash PostToolUse)"
assert_not_recorded "leanctx: non-LeanCTX command is not recorded" "$LC_STATE"
reset; tg2_run "$LCH" "$(tg2_mcp_input user-leanctx lctx_read_ast CallMcpTool)"
assert_recorded "leanctx: matching server and tool records" "$LC_STATE"
assert_eq "leanctx: MCP confirmation" "✅ LeanCTX usage recorded" "$(msg)"
reset; tg2_run "$LCH" "$(tg2_mcp_input some-other-server lctx_wire MCP)"
assert_recorded "leanctx: lctx_* tool on a foreign server still records" "$LC_STATE"
reset; tg2_run "$LCH" "$(tg2_mcp_input leanctx read_file CallMcpTool)"
assert_not_recorded "leanctx: non-lctx tool on leanctx server does not record" "$LC_STATE"
reset; tg2_run "$LCH" "$(tg2_mcp_input other read_file CallMcpTool)"
assert_not_recorded "leanctx: unrelated MCP call does not record" "$LC_STATE"
reset; mkdir -p "$SB_RUNTIME_STATE_DIR/lc-dir"
jq --arg p "$SB_RUNTIME_STATE_DIR/lc-dir" '.recommended_tools.leanctx.usage_state_file=$p' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$LCH" "$lc_cmd"
assert_silent_ok "leanctx: failed state write is silent (command path)"
tg2_run "$LCH" "$(tg2_mcp_input user-leanctx lctx_wire CallMcpTool)"
assert_silent_ok "leanctx: failed state write is silent (matching server path)"
tg2_run "$LCH" "$(tg2_mcp_input other lctx_wire CallMcpTool)"
assert_silent_ok "leanctx: failed state write is silent (foreign server path)"
rmdir "$SB_RUNTIME_STATE_DIR/lc-dir"
reset; tg2_farm notoolinput-lc "$LCH" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$LCH" "$lc_cmd"
assert_recorded "leanctx: jq fallbacks record without tool-input.sh" "$LC_STATE"

# --------------------------------------------------- token compression (rtk)
TCH=hooks/record-token-compression-usage.sh
tc_cmd="$(tg2_bash_input 'rtk gain' Bash PostToolUse)"
tc_msg="$(source "$TL_REPO_ROOT/hooks/lib/recommended-tools-registry.sh"; printf '✅ %s usage recorded' "$(sb_recommended_tool_display_name rtk)")"
reset; tg2_run "$TCH" "$tc_cmd"
assert_recorded "token-compression: rtk CLI use is recorded" "$RTK_STATE"
assert_eq "token-compression: confirmation names the tool" "$tc_msg" "$(msg)"
reset; tg2_run "$TCH" ""
assert_not_recorded "token-compression: empty stdin is a no-op" "$RTK_STATE"
reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: missing jq is a no-op" "$RTK_STATE"
reset; tg2_run "$TCH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Read", tool_input:{file_path:"/x"}}')"
assert_not_recorded "token-compression: non-shell tool is a no-op" "$RTK_STATE"
reset; TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: outside SB project is a no-op" "$RTK_STATE"
reset; rm -f "$TG2_CFG"; tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: missing config is a no-op" "$RTK_STATE"
reset; tg2_run "$TCH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{}}')"
assert_not_recorded "token-compression: shell tool without command is a no-op" "$RTK_STATE"
reset; tg2_run "$TCH" "$(tg2_bash_input 'rtk gain' Bash PostToolUse 3)"
assert_not_recorded "token-compression: failed command is not recorded" "$RTK_STATE"
reset; tg2_run "$TCH" "$(tg2_bash_input 'ls -la' Bash PostToolUse)"
assert_not_recorded "token-compression: command without the CLI is not recorded" "$RTK_STATE"
reset; jq '.recommended_tools.rtk.enabled_by_user=false' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: opted-out rtk is a no-op" "$RTK_STATE"
reset; jq '.recommended_tools.rtk.install_status="failed"' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: not-installed rtk is a no-op" "$RTK_STATE"
reset; jq '.recommended_tools.rtk.cli_command="myrtk"' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$TCH" "$(tg2_bash_input 'myrtk gain' exec_command PostToolUse)"
assert_recorded "token-compression: configured CLI name is honoured" "$RTK_STATE"
reset; tg2_farm tc-noti "$TCH" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$TCH" "$tc_cmd"
assert_recorded "token-compression: jq fallbacks record without tool-input.sh" "$RTK_STATE"
reset; tg2_farm tc-nogate "$TCH" sb-project-gate.sh project-active.sh
TG2_REPO="$TG2_FARM" tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: no project-config finder fails open" "$RTK_STATE"
reset; tg2_farm tc-nolib "$TCH" -
TG2_REPO="$TG2_FARM" tg2_run "$TCH" "$tc_cmd"
assert_not_recorded "token-compression: missing lib dir fails open" "$RTK_STATE"

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
fault_suite "$LCH" "$LC_STATE" 'lean-ctx read x' "$lc_cmd"
fault_suite "$TCH" "$RTK_STATE" 'rtk gain' "$tc_cmd"
reset; tg2_farm ti-lc-mcp "$LCH" tool-input.sh; tg2_farm_stub tool-input.sh "$stub_tool_input"
TG2_REPO="$TG2_FARM" tg2_run "$LCH" "not json" STUB_TOOL_NAME=CallMcpTool
assert_not_recorded "leanctx: unparsable MCP payload records nothing" "$LC_STATE"

tl_results

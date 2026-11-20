#!/usr/bin/env bash
# Behavior tests for the PostToolUse usage recorders (record-agentmemory-usage.sh)
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

  # Without sb-project-gate.sh the hook cannot find its project: inert (fail-open), never an error.
  reset; tg2_farm gate "hooks/$name" sb-project-gate.sh project-active.sh
  TG2_REPO="$TG2_FARM" TG2_PROJECT_ROOT="" TG2_CWD="$TG2_PROJ/src" tg2_run "hooks/$name" "$good"
  assert_not_recorded "$name: farm without the project-gate lib is inert" "$state"
  assert_eq "$name: farm without the project-gate lib exits 0" "0" "$TL_STATUS"

  # A project recommendation without the user's consent records nothing.
  reset; TG2_PROJECT_ROOT="$TG2_PROJ" tg2_run "$hook" "$good" XDG_CONFIG_HOME="$TL_TMP/no-consent"
  assert_not_recorded "$name: no user consent is a no-op" "$state"
  # Without any lib dir the hook cannot source anything and stays inert (fail-open).
  reset; tg2_farm nolib "hooks/$name" -
  TG2_REPO="$TG2_FARM" tg2_run "hooks/$name" "$good"
  assert_not_recorded "$name: missing lib dir fails open" "$state"
}

# ---------------------------------------------------------------- agentmemory
AMH=hooks/record-agentmemory-usage.sh
am_cmd="$(tg2_bash_input 'agentmemory search "auth flow"' Bash PostToolUse)"
prologue_suite "$AMH" "$AM_STATE" "$am_cmd" "✅ agentmemory usage recorded" agentmemory

reset; tg2_run "$AMH" "$(tg2_bash_input 'agentmemory search x' Bash PostToolUse 1)"
assert_not_recorded "agentmemory: failed retrieval command is not recorded" "$AM_STATE"
reset; tg2_run "$AMH" "$(tg2_bash_input 'ls -la' Bash PostToolUse)"
assert_not_recorded "agentmemory: non-retrieval command is not recorded" "$AM_STATE"
reset; tg2_run "$AMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{}}')"
assert_not_recorded "agentmemory: shell tool without command is a no-op" "$AM_STATE"
reset; tg2_run "$AMH" "$(tg2_bash_input 'curl -s http://localhost:3111/agentmemory/recall' exec_command PostToolUse)"
assert_recorded "agentmemory: exec_command HTTP recall is recorded" "$AM_STATE"
# R5-10: a word in another program's arguments, a pipe, a foreign host or a non-retrieval endpoint never records
for c in 'echo agentmemory search x' 'agentmemory search x | head' 'agentmemory search x || true' \
  'curl -s http://evil.example/agentmemory/recall' 'curl -s http://localhost:3111/agentmemory/health' \
  'curl -s -o /tmp/x http://localhost:3111/agentmemory/recall' 'curl -s localhost:3111/agentmemory/recall'; do
  reset; tg2_run "$AMH" "$(tg2_bash_input "$c" Bash PostToolUse)"
  assert_not_recorded "agentmemory: not a retrieval: $c" "$AM_STATE"
done
# A missing exit code is never taken as success; output alone (no error flag) is
reset; tg2_run "$AMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"agentmemory search x"}}')"
assert_not_recorded "agentmemory: no exit code and no output is not success" "$AM_STATE"
reset; tg2_run "$AMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"agentmemory search x"}, tool_response:{stdout:"3 results"}}')"
assert_recorded "agentmemory: output without an exit code counts" "$AM_STATE"
reset; tg2_run "$AMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"agentmemory search x"}, tool_response:{stdout:"x", interrupted:true}}')"
assert_not_recorded "agentmemory: an interrupted command is not success" "$AM_STATE"
reset; tg2_run "$AMH" "$(jq -cn '{hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"agentmemory search x"}, tool_response:"oops"}')"
assert_not_recorded "agentmemory: a non-object response is not success" "$AM_STATE"
# MCP retrievals are recorded by record-recommended-mcp.sh, not by this Bash recorder
reset; tg2_run "$AMH" "$(tg2_mcp_input agentmemory memory_recall CallMcpTool)"
assert_not_recorded "agentmemory: the Bash recorder ignores MCP calls" "$AM_STATE"
# Unwritable state path (a directory) -> record fails, hook stays silent and exits 0.
reset; mkdir -p "$SB_RUNTIME_STATE_DIR/am-dir-usage"
jq --arg p "$SB_RUNTIME_STATE_DIR/am-dir-usage" '.recommended_tools.agentmemory.usage_state_file=$p' <<<"$all_cfg" >"$TG2_CFG"
tg2_run "$AMH" "$am_cmd"
assert_silent_ok "agentmemory: failed state write is silent (command path)"
rmdir "$SB_RUNTIME_STATE_DIR/am-dir-usage"
# jq-free farm: no tool-input.sh -> jq fallbacks parse the payload.
reset; tg2_farm notoolinput "$AMH" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$AMH" "$am_cmd"
assert_recorded "agentmemory: jq fallbacks record without tool-input.sh" "$AM_STATE"
reset; TG2_REPO="$TG2_FARM" tg2_run "$AMH" "$(tg2_bash_input 'ls' Bash PostToolUse)"
assert_not_recorded "agentmemory: jq fallbacks still skip non-retrieval" "$AM_STATE"

# ------------------------------------------------ injected library faults
# A farm whose tool-input.sh answers from env (so unparsable JSON still routes to a tool)
# exercises the "jq failed -> default" fallbacks; a farm whose project-active.sh reports
# "not initiated" exercises the initiation guards.
stub_inactive='sb_project_active() { return 1; }
sb_project_is_initiated() { return 1; }
sb_project_gate_or_exit() { exit 0; }'

fault_suite() { # hook state bash-cmd mcp-tool-env-ok
  local hook="$1" state="$2" cmd="$3" name="${1##*/}"
  reset; TG2_STDIN_UNREADABLE=1 tg2_run "$hook" ""
  assert_not_recorded "$name: unreadable stdin is a no-op" "$state"
  reset; tg2_run "$hook" "not json"
  assert_not_recorded "$name: unparsable payload records nothing" "$state"
  reset; tg2_farm "inactive-$name" "$hook" project-active.sh; tg2_farm_stub project-active.sh "$stub_inactive"
  TG2_REPO="$TG2_FARM" tg2_run "$hook" "$4" STUB_TOOL_NAME="${5:-Bash}" "STUB_CMD=$cmd"
  assert_not_recorded "$name: not-initiated project is a no-op" "$state"
}
fault_suite "$AMH" "$AM_STATE" 'agentmemory search x' "$am_cmd"

tl_results

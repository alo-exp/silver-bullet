#!/usr/bin/env bash
# Behavior tests for hooks/record-site-visual-evidence.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project

tg2_install_jq_stub

SS="$SB_RUNTIME_STATE_DIR/site-session.json"
VE="$SB_RUNTIME_STATE_DIR/site-visual-evidence.json"
VL="$SB_RUNTIME_STATE_DIR/site-vloops.json"
EVIDENCE_HOOK=hooks/record-site-visual-evidence.sh
cfg='{"sb_initiated":true}'
reset() {
  rm -f "$SS" "$VE" "$VL" "$SB_RUNTIME_STATE_DIR/project-root" \
    "$SB_RUNTIME_STATE_DIR/live-publish-evidence.json" "$SB_RUNTIME_STATE_DIR/subagent-spawns.jsonl"
  tg2_cfg "$cfg"
}
prompt_input() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit", prompt:$p}'; }
post_input() { # tool tool_input-json
  jq -cn --arg t "$1" --argjson i "$2" '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:$i}'
}
sj() { jq -r "$1" "$SS" 2>/dev/null || true; }
assert_no_session() { # name
  if [[ ! -e "$SS" && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} session=$([[ -e "$SS" ]] && echo present || echo absent))"; fi
}

# ================================================== record-site-visual-evidence
shot_input() { # tool response-json [tool_input-json]
  jq -cn --arg t "$1" --argjson r "$2" --argjson i "${3:-{\}}" \
    '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:$i, tool_response:$r}'
}
mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q 2>/dev/null
ve_path() { jq -r '.paths[0] // ""' "$VE" 2>/dev/null || true; }
assert_no_evidence() {
  if [[ ! -e "$VE" && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} evidence=$([[ -e "$VE" ]] && echo present || echo absent))"; fi
}
ve_msg() { printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.message // ""' 2>/dev/null || true; }

reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/shot-1.png"}')"
assert_eq "evidence: screenshot tool records the path" "/tmp/shot-1.png" "$(ve_path)"
assert_eq "evidence: confirmation message" "✅ site visual evidence recorded" "$(ve_msg)"
assert_eq "evidence: record carries viewport" "1280" "$(jq -r .viewport "$VE")"
assert_eq "evidence: visual V-loop step is marked done" "done" "$(jq -r '.steps[] | select(.id=="visual") | .status' "$VL")"
assert_eq "evidence: V-loop evidence ref is the path" "/tmp/shot-1.png" "$(jq -r '.steps[] | select(.id=="visual") | .evidence_ref' "$VL")"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"filename":"shots/a.png"}')"
assert_eq "evidence: filename fallback is recorded" "shots/a.png" "$(ve_path)"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{}')"
assert_no_evidence "evidence: screenshot without a path records nothing"

for mcp_tool in browser_take_screenshot take_screenshot screenshot; do
  reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input CallMcpTool '{"path":"/tmp/m.png"}' "{\"toolName\":\"$mcp_tool\"}")"
  assert_eq "evidence: MCP $mcp_tool records response.path" "/tmp/m.png" "$(ve_path)"
done
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input MCP '{"result":{"path":"/tmp/nested.png"}}' '{"name":"screenshot"}')"
assert_eq "evidence: MCP result.path is recorded" "/tmp/nested.png" "$(ve_path)"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input CallMcpTool '{"path":"/tmp/m.png"}' '{"toolName":"browser_click"}')"
assert_no_evidence "evidence: non-screenshot MCP tool is ignored"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input CallMcpTool '{}' '{"toolName":"screenshot"}')"
assert_no_evidence "evidence: MCP screenshot without a path records nothing"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input Bash '{"path":"/tmp/x.png"}')"
assert_no_evidence "evidence: unrelated tool is ignored"
reset; printf 'not json' >"$VL"
tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/shot-2.png"}')"
assert_eq "evidence: corrupt V-loop file does not stop evidence being recorded" "/tmp/shot-2.png" "$(ve_path)"
assert_eq "evidence: confirmation still printed with corrupt V-loop file" "✅ site visual evidence recorded" "$(ve_msg)"

reset; tg2_run "$EVIDENCE_HOOK" ""
assert_no_evidence "evidence: empty stdin is a no-op"
reset; TG2_STDIN_UNREADABLE=1 tg2_run "$EVIDENCE_HOOK" ""
assert_no_evidence "evidence: unreadable stdin is a no-op"
reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_no_evidence "evidence: missing jq is a no-op"
reset; TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_no_evidence "evidence: outside an SB project is a no-op"
reset; TG2_CWD="$TL_TMP/gitonly/sub" TG2_PROJECT_ROOT="" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_no_evidence "evidence: walk-up stops at the .git boundary"
reset; TG2_CWD="$TG2_PROJ/src" TG2_PROJECT_ROOT="" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_eq "evidence: walk-up finds the config in a parent dir" "/tmp/s.png" "$(ve_path)"
reset; tg2_farm ve-gate "$EVIDENCE_HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_active() { return 1; }
sb_project_gate_or_exit() { return 1; }'
TG2_REPO="$TG2_FARM" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_no_evidence "evidence: failing project gate is a no-op"
reset; tg2_farm ve-noti "$EVIDENCE_HOOK" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_eq "evidence: jq fallback tool-name parse records the path" "/tmp/s.png" "$(ve_path)"
reset; tg2_farm ve-nolib "$EVIDENCE_HOOK" -
TG2_REPO="$TG2_FARM" tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/s.png"}')"
assert_no_evidence "evidence: missing lib dir fails open"

reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input browser_take_screenshot '{"path":"/tmp/a.png"}')" JQ_FAIL='.tool_response.filename'
assert_no_evidence "evidence: failed screenshot-path extraction records nothing"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input CallMcpTool '{"path":"/tmp/a.png"}' '{"toolName":"screenshot"}')" JQ_FAIL='.tool_input.toolName'
assert_no_evidence "evidence: failed MCP tool-name extraction records nothing"
reset; tg2_run "$EVIDENCE_HOOK" "$(shot_input CallMcpTool '{"path":"/tmp/a.png"}' '{"toolName":"screenshot"}')" JQ_FAIL='.tool_response.result.path'
assert_no_evidence "evidence: failed MCP path extraction records nothing"


tl_results

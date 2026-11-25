#!/usr/bin/env bash
# Behavior tests for hooks/record-site-visual-evidence.sh (R9-03): real MCP tool names, an existing file, a
# session with site edits.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

ST="$SB_RUNTIME_STATE_DIR"
SS="$ST/site-session.json"
VE="$ST/site-visual-evidence.json"
VL="$ST/site-vloops.json"
H=hooks/record-site-visual-evidence.sh
P="$TL_TMP/proj"
dg_project "$P" '{"sb_initiated":true,"site_profile":{"enabled":true,"dir":"site"}}'
rm -rf "$P/.git"
git -C "$P" init -q -b main
P_REAL="$(cd "$P" && pwd -P)"
mkdir -p "$P/shots" "$TL_TMP/outside"
shot="$P/shots/home.png"
printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR' >"$shot"
printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR' >"$TL_TMP/dark.png"
reset() {
  rm -f "$VE" "$VL"
  jq -n --arg sc "$P_REAL" '{active:true,scope:$sc,edit_seq:2,nonce:"n1",touch_reason:"edit:site/index.html"}' >"$SS"
}
shot_input() { # tool response-json [tool_input-json]
  jq -cn --arg t "$1" --argjson r "$2" --argjson i "${3:-{\}}" \
    '{hook_event_name:"PostToolUse", tool_name:$t, tool_input:$i, tool_response:$r}'
}
ve_path() { jq -r '.paths[0] // ""' "$VE" 2>/dev/null || true; }
assert_no_evidence() {
  if [[ ! -e "$VE" && "$TL_STATUS" == 0 && -z "$TL_OUT" ]]; then tl_pass "$1"; else tl_fail "$1 (status=$TL_STATUS out=${TL_OUT:0:200} evidence=$([[ -e "$VE" ]] && echo present || echo absent))"; fi
}
ve_msg() { printf '%s' "$TL_OUT" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null || true; }

# The Claude Playwright MCP tool is mcp__playwright__browser_take_screenshot: it must match the hooks.json matcher
# and be recorded; the old registration (Bash) and bare name never fired at runtime.
matcher="$(jq -r '.hooks.PostToolUse[] | select(.hooks[]?.command | endswith("record-site-visual-evidence.sh\"")) | .matcher' "$TL_REPO_ROOT/hooks/hooks.json")"
if [[ "mcp__playwright__browser_take_screenshot" =~ ^(${matcher})$ ]]; then tl_pass "evidence: the hooks.json matcher matches the real Playwright tool name"; else tl_fail "evidence: matcher '$matcher' does not match mcp__playwright__browser_take_screenshot"; fi
if [[ "Bash" =~ ^(${matcher})$ ]]; then tl_fail "evidence: the matcher still includes Bash"; else tl_pass "evidence: the matcher does not run on every shell command"; fi

reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_eq "evidence: the real MCP tool name records the path" "$shot" "$(ve_path)"
assert_eq "evidence: confirmation names the hook event" "PostToolUse" "$(printf '%s' "$TL_OUT" | jq -r .hookSpecificOutput.hookEventName)"
assert_eq "evidence: confirmation message" "site visual evidence recorded" "$(ve_msg)"
assert_eq "evidence: record carries the project" "$P_REAL" "$(jq -r .project "$VE")"
assert_eq "evidence: record carries the counted edit it covers" "2" "$(jq -r .edit_seq "$VE")"
assert_eq "evidence: record carries viewport" "1280" "$(jq -r .viewport "$VE")"
assert_eq "evidence: visual V-loop step is marked done" "done" "$(jq -r '.steps[] | select(.id=="visual") | .status' "$VL")"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$TL_TMP/dark.png\"}")"
assert_eq "evidence: a second screenshot of the same edit is added" "2" "$(jq -r '.paths | length' "$VE")"
jq '.edit_seq = 3' "$SS" >"$ST/s.t" && mv "$ST/s.t" "$SS"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_eq "evidence: a screenshot after a newer edit starts the list afresh" "1" "$(jq -r '.paths | length' "$VE")"

reset; dg_run "$P" "$H" "$(shot_input browser_take_screenshot "{\"filename\":\"$shot\"}")"
assert_eq "evidence: response.filename is recorded" "$shot" "$(ve_path)"
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot '{}' '{"filename":"shots/home.png"}')"
assert_eq "evidence: the requested filename is resolved against the project" "$shot" "$(ve_path)"
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "[{\"type\":\"text\",\"text\":\"Took the screenshot ![x]($shot)\"}]")"
assert_eq "evidence: an image path in the result text is recorded" "$shot" "$(ve_path)"
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot '{}')"
assert_no_evidence "evidence: screenshot without a path records nothing"
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot '{"path":"/nonexistent/forged.png"}')"
assert_no_evidence "evidence: a path that is not a file records nothing (R9-03)"
ln -sf "$shot" "$P/shots/link.png"
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$P/shots/link.png\"}")"
assert_no_evidence "evidence: a symlink records nothing"
reset; rm -f "$SS"; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: no site session, nothing to prove"
reset; jq '.edit_seq=0' "$SS" >"$ST/s.t" && mv "$ST/s.t" "$SS"; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: a session without site edits has nothing to prove"


# review r1: only a real image, under the project or a temporary directory, written after the latest edit
reset; printf 'not an image' >"$P/shots/fake.png"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$P/shots/fake.png\"}")"
assert_no_evidence "evidence: a text file named .png is not a screenshot"
reset; dg_run "$P" "$H" "$(shot_input mcp__shop__theme_screenshot '{}' '{"filename":"/etc/hostname"}')"
assert_no_evidence "evidence: an arbitrary readable path such as /etc/hostname is not a screenshot"
reset; dg_run "$P" "$H" "$(shot_input mcp__shop__theme_screenshot "{\"path\":\"/etc/hostname\"}")"
assert_no_evidence "evidence: nor is one named by the tool's own response"
reset; jq '.last_edit_epoch = 4102444800' "$SS" >"$ST/s.t" && mv "$ST/s.t" "$SS"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: a screenshot older than the latest site edit is not evidence"
reset; jq '.last_edit_epoch = 1' "$SS" >"$ST/s.t" && mv "$ST/s.t" "$SS"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_eq "evidence: one taken after the edit is" "$shot" "$(ve_path)"
assert_eq "evidence: the record carries the session nonce" "n1" "$(jq -r .nonce "$VE")"
reset; jpg="$P/shots/p.jpg"; printf '\xff\xd8\xff\xe0\0\x10JFIF\0' >"$jpg"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$jpg\"}")"
assert_eq "evidence: a JPEG is accepted" "$jpg" "$(ve_path)"
mkdir -p "$TL_TMP/elsewhere"; 
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot '{"path":"/usr/share/zoneinfo/UTC"}')"
assert_no_evidence "evidence: a path outside the project and the temporary directories is refused"

for mcp_tool in browser_take_screenshot take_screenshot screenshot; do
  reset; dg_run "$P" "$H" "$(shot_input MCP "{\"path\":\"$shot\"}" "{\"toolName\":\"$mcp_tool\"}")"
  assert_eq "evidence: MCP $mcp_tool records response.path" "$shot" "$(ve_path)"
done
reset; dg_run "$P" "$H" "$(shot_input MCP "{\"result\":{\"path\":\"$shot\"}}" '{"name":"screenshot"}')"
assert_eq "evidence: MCP result.path is recorded" "$shot" "$(ve_path)"
reset; dg_run "$P" "$H" "$(shot_input MCP "{\"path\":\"$shot\"}" '{"toolName":"browser_click"}')"
assert_no_evidence "evidence: non-screenshot MCP tool is ignored"
reset; dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_click "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: another MCP tool is ignored"
reset; dg_run "$P" "$H" "$(shot_input Bash "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: unrelated tool is ignored"
reset; dg_run "$P" "$H" "$(jq -cn --arg p "$shot" '{hook_event_name:"PreToolUse",tool_name:"mcp__playwright__browser_take_screenshot",tool_response:{path:$p}}')"
assert_no_evidence "evidence: only PostToolUse is recorded"
reset; printf 'not json' >"$VL"
dg_run "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_eq "evidence: corrupt V-loop file does not stop evidence being recorded" "$shot" "$(ve_path)"
assert_eq "evidence: confirmation still printed with corrupt V-loop file" "site visual evidence recorded" "$(ve_msg)"

reset; dg_run "$P" "$H" ""
assert_no_evidence "evidence: empty stdin is a no-op"
reset; dg_run "$P" "$H" "not json"
assert_no_evidence "evidence: unparsable stdin defaults to PostToolUse and records nothing"
reset; dg_run_closed_stdin "$P" "$H"
assert_no_evidence "evidence: unreadable stdin is a no-op"
reset; dg_run_nojq "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: missing jq is a no-op"
reset; dg_run "$TL_TMP/outside" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: outside an SB project is a no-op"
reset; dg_run "$P/shots" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"home.png\"}")"
assert_eq "evidence: a relative path resolves against the working directory" "$P/shots/home.png" "$(ve_path)"
reset; dg_run_gate_missing "$P" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: failing project gate is a no-op"
reset; dg_run_nolib "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: missing lib dir fails open"
dg_project "$TL_TMP/plain" '{"sb_initiated":true}'
reset; dg_run "$TL_TMP/plain" "$H" "$(shot_input mcp__playwright__browser_take_screenshot "{\"path\":\"$shot\"}")"
assert_no_evidence "evidence: a project without a site_profile records nothing"

tl_results

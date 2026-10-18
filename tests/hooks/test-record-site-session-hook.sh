#!/usr/bin/env bash
# Behavior tests for hooks/record-site-session.sh
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
SESSION_HOOK=hooks/record-site-session.sh
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

# ============================================================ record-site-session
reset; tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_eq "session: site/ edit status" "0" "$TL_STATUS"
assert_eq "session: site/ edit activates session" "true" "$(sj .active)"
assert_eq "session: site/ edit touch reason" "edit:site/index.html" "$(sj .touch_reason)"
assert_eq "session: site/ edit leaves push_intent false" "false" "$(sj .push_intent)"
assert_eq "session: site/ edit writes nothing to stdout" "" "$TL_OUT"

reset; tg2_run "$SESSION_HOOK" "$(post_input Write "{\"file_path\":\"$TG2_PROJ/site/help/a.html\"}")"
assert_eq "session: absolute site path inside repo is recorded" "edit:$TG2_PROJ/site/help/a.html" "$(sj .touch_reason)"
# second touch updates the existing session instead of recreating it
tg2_run "$SESSION_HOOK" "$(post_input MultiEdit '{"file_path":"site/b.html"}')"
assert_eq "session: second edit updates touch reason" "edit:site/b.html" "$(sj .touch_reason)"

reset; tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"src/app.js"}')"
assert_no_session "session: non-site edit leaves no session"
reset; tg2_run "$SESSION_HOOK" "$(post_input apply_patch '{"input":"*** Begin Patch\n*** Update File: site/x.html\n@@\n-a\n+b\n*** End Patch"}')"
assert_eq "session: apply_patch to site/ file is recorded" "true" "$(sj .active)"

reset; tg2_run "$SESSION_HOOK" "$(post_input Bash '{"command":"git push origin main"}')"
assert_eq "session: git push marks push intent" "true" "$(sj .push_intent)"
assert_eq "session: git push activates session" "true" "$(sj .active)"
reset; tg2_run "$SESSION_HOOK" "$(post_input exec_command '{"command":"git status"}')"
assert_no_session "session: other shell commands are ignored"
reset; tg2_run "$SESSION_HOOK" "$(post_input Read '{"file_path":"site/index.html"}')"
assert_no_session "session: unrelated tools are ignored"

# agent delegation spawns are not site sessions (and clear stale state)
reset; tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
printf '{}' >"$VE"
tg2_run "$SESSION_HOOK" "$(post_input Task '{"prompt":"run silver-agent-codex on the site"}')"
assert_file_absent "session: delegation spawn clears the site session" "$SS"
assert_file_absent "session: delegation spawn clears visual evidence" "$VE"
reset; tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
tg2_run "$SESSION_HOOK" "$(post_input Agent '{"prompt":"review the layout"}')"
assert_eq "session: non-delegation agent spawn keeps the session" "true" "$(sj .active)"
tg2_run "$SESSION_HOOK" "$(post_input Subagent '{"prompt":"AF-AGENT-DELEGATE now"}')"
assert_file_absent "session: AF-AGENT-DELEGATE spawn clears the session" "$SS"

# UserPromptSubmit
reset; tg2_run "$SESSION_HOOK" "$(prompt_input 'please update the help center page')"
assert_eq "session: site-intent prompt marks session" "site-intent" "$(sj .touch_reason)"
assert_eq "session: plain site prompt has no live claim" "false" "$(sj .live_claim_pending)"
reset; tg2_run "$SESSION_HOOK" "$(prompt_input 'edit site/index.html and publish it live')"
assert_eq "session: live claim prompt sets live_claim_pending" "true" "$(sj .live_claim_pending)"
assert_eq "session: live claim prompt activates session" "true" "$(sj .active)"
reset; tg2_run "$SESSION_HOOK" "$(prompt_input 'refactor the parser module')"
assert_no_session "session: unrelated prompt is ignored"
reset; tg2_run "$SESSION_HOOK" "$(prompt_input 'use silver-agent-codex to update the homepage')"
assert_no_session "session: delegation prompt is not site intent"
reset; tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
tg2_run "$SESSION_HOOK" "$(prompt_input 'delegate with silver-agent-cursor to fix the homepage')"
assert_file_absent "session: delegation prompt clears stale session" "$SS"

# other events and invalid input
reset; tg2_run "$SESSION_HOOK" "$(jq -cn '{hook_event_name:"Stop", tool_name:"Edit", tool_input:{file_path:"site/a.html"}}')"
assert_no_session "session: events other than PostToolUse/UserPromptSubmit are ignored"
reset; tg2_run "$SESSION_HOOK" "not json at all"
assert_no_session "session: unparsable stdin is a no-op"
reset; tg2_run "$SESSION_HOOK" ""
assert_no_session "session: empty stdin is a no-op"
reset; TG2_STDIN_UNREADABLE=1 tg2_run "$SESSION_HOOK" ""
assert_no_session "session: unreadable stdin is a no-op"
reset; TG2_PATH="$(tl_path_without jq)" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: missing jq is a no-op"
reset; TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: outside an SB project is a no-op"
reset; mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q 2>/dev/null
TG2_CWD="$TL_TMP/gitonly/sub" TG2_PROJECT_ROOT="" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: walk-up stops at the .git boundary"
reset; TG2_CWD="$TG2_PROJ/src" TG2_PROJECT_ROOT="" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_eq "session: walk-up finds the config in a parent dir" "true" "$(sj .active)"
reset; tg2_farm gate-fails "$SESSION_HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_active() { return 1; }
sb_project_gate_or_exit() { return 1; }'
TG2_REPO="$TG2_FARM" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: failing project gate is a no-op"
reset; tg2_farm no-tool-input "$SESSION_HOOK" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: without tool-input.sh the tool is unknown and nothing is recorded"
reset; tg2_farm no-lib "$SESSION_HOOK" -
TG2_REPO="$TG2_FARM" tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
assert_no_session "session: missing lib dir fails open"
reset; tg2_farm bad-event "$SESSION_HOOK" tool-input.sh
TG2_REPO="$TG2_FARM" tg2_run "$SESSION_HOOK" "not json"
assert_no_session "session: unparsable event defaults to PostToolUse and records nothing"

# single failing jq calls fall back to empty values
reset; tg2_run "$SESSION_HOOK" "$(prompt_input 'update the help center')" JQ_FAIL='.prompt'
assert_no_session "session: failed prompt extraction is treated as an empty prompt"
reset; tg2_run "$SESSION_HOOK" "$(post_input Edit '{"file_path":"site/index.html"}')"
tg2_run "$SESSION_HOOK" "$(post_input Task '{"prompt":"silver-agent-codex go"}')" JQ_FAIL='.tool_input // {}'
assert_eq "session: failed spawn preview is treated as an empty object (session kept)" "true" "$(sj .active)"
reset; tg2_farm cmd-fails "$SESSION_HOOK" tool-input.sh
tg2_farm_stub tool-input.sh 'sb_tool_name() { printf "Bash"; }
sb_tool_file_path() { printf ""; }
sb_tool_command_string() { return 1; }'
TG2_REPO="$TG2_FARM" tg2_run "$SESSION_HOOK" "$(post_input Bash '{"command":"git push"}')"
assert_no_session "session: unreadable shell command never counts as a push"


tl_results

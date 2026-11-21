#!/usr/bin/env bash
# R9-01 / R9-02 / R9-12: the site gates are inert unless the project opts in with a site_profile, a plain
# push never starts a site session, and prompt words never start or wipe one.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

ST="$SB_RUNTIME_STATE_DIR"
SESS="$ST/site-session.json"
HK=hooks
stop_json='{"hook_event_name":"Stop"}'
decision() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // .decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
all_stop_gates_quiet() { # label dir
  local g
  for g in site-regression-gate live-publish-evidence-gate v-loop-rollup-gate site-visual-evidence-gate; do
    dg_run "$2" "$HK/$g.sh" "$stop_json"
    assert_eq "$1: $g does not block Stop" "none" "$(decision)"
  done
}

# --- a downstream project without a site profile ------------------------------------------------
P="$TL_TMP/plain"
dg_project "$P"
git -C "$P" init -q 2>/dev/null || true
dg_run "$P" "$HK/site-regression-gate.sh" "$(tl_hook_json PreToolUse Bash 'git push -u origin feature-x')"
assert_eq "R9-01: a plain push is not denied in a project with no site work" "none" "$(decision)"
[[ ! -e "$SESS" ]] && tl_pass "R9-01: a plain push creates no site session" || tl_fail "R9-01: a plain push created a site session"
all_stop_gates_quiet "R9-01 after a push" "$P"

mkdir -p "$P/site"
dg_run "$P" "$HK/record-site-session.sh" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:"site/index.html"}}')"
[[ ! -e "$SESS" ]] && tl_pass "R9-02: a site/ edit starts no session without a site_profile" || tl_fail "R9-02: site/ edit started a session without a profile"
all_stop_gates_quiet "R9-02 after a site edit" "$P"
tl_stub curl 'printf 500'
dg_run "$P" "$HK/site-preview-preflight.sh" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:"site/index.html"}}')" SB_ORCHESTRATOR_PARENT=0
assert_eq "R9-02: the preview preflight is inert without a site_profile" "none" "$(decision)"
dg_run "$P" "$HK/site-chrome-guard.sh" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:"site/help/a.html",content:"<nav class=\"nav-inner\">"}}')"
assert_eq "R9-02: the chrome guard is inert without a site_profile" "none" "$(decision)"

# --- an explicit profile, with the project living under a directory that happens to be called site ----
P2="$TL_TMP/clients/site/app"
mkdir -p "$P2"
dg_project "$P2" '{"sb_initiated":true,"site_profile":{"enabled":true,"dir":"site"}}'
git -C "$P2" init -q 2>/dev/null || true
dg_run "$P2" "$HK/record-site-session.sh" "$(jq -cn --arg p "$P2/src/main.py" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
[[ ! -e "$SESS" ]] && tl_pass "R9-02: a project under a directory called site is not a site edit" || tl_fail "R9-02: path under /site/ outside the site dir started a session"
dg_run "$P2" "$HK/record-site-session.sh" "$(jq -cn '{hook_event_name:"UserPromptSubmit",prompt:"refactor the homepage service class in api/"}')"
[[ ! -e "$SESS" ]] && tl_pass "R9-02: a prompt word alone never starts a session" || tl_fail "R9-02: a prompt started a session"
dg_run "$P2" "$HK/record-site-session.sh" "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:"site/index.html"}}')"
[[ -e "$SESS" ]] && tl_pass "R9-02: a real site/ edit starts a session under an explicit profile" || tl_fail "R9-02: profile project did not record a site edit"

tl_results

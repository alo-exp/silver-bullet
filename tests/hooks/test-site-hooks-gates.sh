#!/usr/bin/env bash
# Behavior tests for the site hooks: chrome guard, preview preflight, regression gate,
# visual evidence gate and live-publish evidence gate.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

P="$TL_TMP/proj"
PROFILE='{"sb_initiated":true,"site_profile":{"enabled":true,"dir":"site","preview_port":8765,"stop_block_limit":1000,"preview_script":"site/serve.sh","live_url":"https://site.example/","regression_scripts":["tests/scripts/test-site-chrome-regression.sh","tests/scripts/test-site-doc-freshness.sh","tests/scripts/test-site-content-freshness.sh"]}}'
dg_project "$P" "$PROFILE"
rm -rf "$P/.git"
git -C "$P" init -q -b main
mkdir -p "$P/sub" "$TL_TMP/outside"
ST="$SB_RUNTIME_STATE_DIR"
SESS="$ST/site-session.json"
P_REAL="$(cd "$P" && pwd -P)"
commit_all() { git -C "$P" add -A >/dev/null 2>&1; git -C "$P" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "${1:-c}"; }
commit_all init
scope() { printf '%s' "$P_REAL"; }
# site_session REASON PUSH LIVE EDITS: a session in the current scope (EDITS = edit_seq, 1 by default).
site_session() { jq -n --arg r "${1:-site-intent}" --arg sc "$(scope)" --argjson e "${4:-1}" '{active:true,scope:$sc,nonce:"n1",touch_reason:$r,edit_seq:$e,regression_passed_seq:0,push_intent:'"${2:-false}"',live_claim_pending:'"${3:-false}"'}' >"$SESS"; }

edit_json() { # tool path content
  jq -cn --arg t "$1" --arg p "$2" --arg c "$3" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$p,new_string:$c}}'
}
shell_json() { # command [cwd]: a shell payload whose cwd is the project (tl_hook_json carries the runner's cwd)
  jq -cn --arg c "$1" --arg d "${2:-$P}" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}'
}
decision() {
  [[ -n "$TL_OUT" ]] || { echo none; return; }
  jq -r '.hookSpecificOutput.permissionDecision // .decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none
}

# ===================== site-chrome-guard.sh ==============================
H=hooks/site-chrome-guard.sh
dg_run_nolib "$H" "$(edit_json Edit site/tokens.css '@font-face{}')"
assert_eq "chrome: lib-dir fallback is inert" "" "$TL_OUT"
dg_assert_ok "chrome: lib-dir fallback is inert: exits 0"
assert_eq "chrome: lib-dir fallback exits 0" 0 "$TL_STATUS"
dg_run_nojq "$P" "$H" "$(edit_json Edit site/tokens.css '@font-face{}')"
assert_eq "chrome: no jq => allow silently" "" "$TL_OUT"
dg_assert_ok "chrome: no jq => allow silently: exits 0"
dg_run "$P" "$H" ""
assert_eq "chrome: empty input => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse","tool_name":"Edit"}'
assert_eq "chrome: non PreToolUse ignored" "" "$TL_OUT"
dg_assert_ok "chrome: non PreToolUse ignored: exits 0"
dg_run "$P" "$H" "$(edit_json Bash site/tokens.css '@font-face{}')"
assert_eq "chrome: non-edit tool ignored" "" "$TL_OUT"
dg_assert_ok "chrome: non-edit tool ignored: exits 0"
dg_run "$TL_TMP/outside" "$H" "$(edit_json Edit site/tokens.css '@font-face{}')"
assert_eq "chrome: outside an SB project => inert" "" "$TL_OUT"
dg_assert_ok "chrome: outside an SB project => inert: exits 0"
dg_run "$P/sub" "$H" "$(edit_json Edit "$P/site/tokens.css" '@font-face{}')"
assert_eq "chrome: project found by walking up => font-face denied" "deny" "$(decision)"
assert_contains "chrome: deny reason names the override" "$TL_OUT" "SB FONT TOKEN OVERRIDE"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" 'font-family: Comic Sans')"
assert_eq "chrome: raw font-family denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" 'font-family: verdana, sans-serif')"
assert_eq "chrome: a named font starting with v is still denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" '--space-1: 4px;')"
assert_eq "chrome: tokens.css edit without any font-family allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" 'font-family:var(--font-body)')"
assert_eq "chrome: var() without a space allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" $'--a: 1;\nfont-family: var(--f);\nfont-family: Arial;')"
assert_eq "chrome: one raw font-family among var() ones is denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" 'font-family: var(--font-body)')"
assert_eq "chrome: font-family var() allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/tokens.css" '@font-face{} /* SB FONT TOKEN OVERRIDE */')"
assert_eq "chrome: override marker allows font edit" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write "$P/site/help/a.html" '<nav class="nav-inner">x</nav>')"
assert_eq "chrome: inline nav in help html denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write "$P/site/help/a.html" '<footer class="x footer-inner">')"
assert_eq "chrome: inline footer denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write "$P/site/help/a.html" '<p>plain</p>')"
assert_eq "chrome: clean site html allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write "$P/src/a.html" '<nav class="nav-inner">')"
assert_eq "chrome: non-site file allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write "$P/site/index.html" '<nav class="nav-inner">x</nav>')"
assert_eq "chrome: a non-help site page is checked too (R9-10)" "deny" "$(decision)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/site/help/a.html" '{hook_event_name:"PreToolUse",tool_name:"MultiEdit",tool_input:{file_path:$p,edits:[{old_string:"a",new_string:"<nav class=\"nav-inner\">"}]}}')"
assert_eq "chrome: MultiEdit edits[].new_string is read (R9-10)" "deny" "$(decision)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/site/help/a.html" '{hook_event_name:"PreToolUse",tool_name:"MultiEdit",tool_input:{file_path:$p,edits:[{old_string:"<nav class=\"nav-inner\">",new_string:"x"}]}}')"
assert_eq "chrome: removing an inline nav is allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/site/help/a.html" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{command:("*** Begin Patch\n*** Update File: "+$p+"\n@@\n-old\n+<nav class=\"nav-inner\">\n*** End Patch")}}')"
assert_eq "chrome: apply_patch added lines are read (R9-10)" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write "$P/node_modules/x/site/readme.html" '<nav class="nav-inner">')"
assert_eq "chrome: a site/ directory elsewhere in the project is not the site" "none" "$(decision)"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}'
assert_eq "chrome: missing file_path allowed" "" "$TL_OUT"
dg_assert_ok "chrome: missing file_path allowed: exits 0"
dg_run "$P" "$H" "$(edit_json Write "$P/site/help/a.html" '<nav class="nav-inner">')" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "chrome: bridge mode exits 2" 2 "$TL_STATUS"
assert_contains "chrome: bridge mode explains on stderr" "$TL_ERR" "single-source guard"

dg_run_closed_stdin "$P" "$H"
assert_eq "chrome: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json"
assert_eq "chrome: invalid JSON => inert" "" "$TL_OUT"
dg_assert_ok "chrome: invalid JSON => inert: exits 0"
dg_run_gate_missing "$P" "$H" "$(edit_json Write "$P/site/help/a.html" '<nav class="nav-inner">')"
assert_eq "chrome: missing project gate => fail open" "" "$TL_OUT"
dg_assert_ok "chrome: missing project gate => fail open: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":"oops"}'
assert_eq "chrome: non-object tool_input => allow" "" "$TL_OUT"
dg_assert_ok "chrome: non-object tool_input => allow: exits 0"

# ===================== site-preview-preflight.sh =========================
H=hooks/site-preview-preflight.sh
tl_stub curl 'printf 500'
dg_run_nolib "$H" "$(edit_json Edit "$P/site/a.html" x)"
assert_eq "preflight: lib-dir fallback inert" "" "$TL_OUT"
dg_assert_ok "preflight: lib-dir fallback inert: exits 0"
dg_run_nojq "$P" "$H" "$(edit_json Edit "$P/site/a.html" x)"
assert_eq "preflight: no jq => allow" "" "$TL_OUT"
dg_assert_ok "preflight: no jq => allow: exits 0"
dg_run "$P" "$H" ""
assert_eq "preflight: empty input" 0 "$TL_STATUS"
dg_run "$P" "$H" '{"hook_event_name":"Stop"}'
assert_eq "preflight: non PreToolUse ignored" "" "$TL_OUT"
dg_assert_ok "preflight: non PreToolUse ignored: exits 0"
dg_run "$P" "$H" "$(edit_json Bash "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: non-edit tool ignored" "" "$TL_OUT"
dg_assert_ok "preflight: non-edit tool ignored: exits 0"
dg_run "$TL_TMP/outside" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: outside project inert" "" "$TL_OUT"
dg_assert_ok "preflight: outside project inert: exits 0"
dg_run "$P/sub" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=1
assert_eq "preflight: parent orchestrator session skipped" "" "$TL_OUT"
dg_assert_ok "preflight: parent orchestrator session skipped: exits 0"
dg_run "$P/sub" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: unhealthy preview denies site edit" "deny" "$(decision)"
assert_contains "preflight: reason points at the profile preview script" "$TL_OUT" "site/serve.sh"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/site/a.html" '{hook_event_name:"PreToolUse",tool_name:"MultiEdit",tool_input:{file_path:$p,edits:[]}}')" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: MultiEdit on the site is gated" "deny" "$(decision)"
dg_run "$P" "$H" "$(jq -cn --arg p "$P/site/a.html" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{command:("*** Begin Patch\n*** Update File: "+$p+"\n@@\n-a\n+b\n*** End Patch")}}')" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: apply_patch on the site is gated (R9-10)" "deny" "$(decision)"
dg_run "$P" "$H" "$(shell_json 'printf x > site/a.html')" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: a shell write into the site is gated" "deny" "$(decision)"
dg_run "$P" "$H" "$(shell_json 'ls site')" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: a read of the site is not" "" "$TL_OUT"
dg_run "$P" "$H" "$(edit_json Edit "$P/src/a.sh" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: non-site path ignored" "" "$TL_OUT"
dg_assert_ok "preflight: non-site path ignored: exits 0"
tl_stub curl 'printf 200'
dg_run "$P" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: healthy preview allows" "" "$TL_OUT"
dg_assert_ok "preflight: healthy preview allows: exits 0"
tl_stub curl 'printf 500'
dg_run "$P" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0 SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "preflight: bridge mode exits 2" 2 "$TL_STATUS"

dg_run_closed_stdin "$P" "$H" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: invalid JSON => inert" "" "$TL_OUT"
dg_assert_ok "preflight: invalid JSON => inert: exits 0"
dg_run_gate_missing "$P" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: missing project gate => fail open" "" "$TL_OUT"
dg_assert_ok "preflight: missing project gate => fail open: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":"oops"}' SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: non-object tool_input => allow" "" "$TL_OUT"
dg_assert_ok "preflight: non-object tool_input => allow: exits 0"

dg_project "$P" "$(jq -c 'del(.site_profile.preview_port)' <<<"$PROFILE")"
dg_run "$P" "$H" "$(edit_json Edit "$P/site/a.html" x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: a profile without a preview port has nothing to probe" "" "$TL_OUT"
dg_assert_ok "preflight: a profile without a preview port: exits 0"
dg_project "$P" "$PROFILE"
tl_stub curl 'printf 500'

# ===================== site-visual-evidence-gate.sh ======================
H=hooks/site-visual-evidence-gate.sh
stop_json='{"hook_event_name":"Stop"}'
shot="$TL_TMP/shot.png"
printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR' >"$shot"
visual_evidence() { jq -n --arg r "$P_REAL" --arg p "$shot" --argjson e 1 '{captured_at:"t",project:$r,nonce:"n1",edit_seq:$e,paths:[$p]}' >"$ST/site-visual-evidence.json"; }
rm -f "$SESS"
dg_run_nolib "$H" "$stop_json"
assert_eq "visual: lib-dir fallback inert" "" "$TL_OUT"
dg_assert_ok "visual: lib-dir fallback inert: exits 0"
dg_run_nojq "$P" "$H" "$stop_json"
assert_eq "visual: no jq => allow" "" "$TL_OUT"
dg_assert_ok "visual: no jq => allow: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse"}'
assert_eq "visual: other events ignored" "" "$TL_OUT"
dg_assert_ok "visual: other events ignored: exits 0"
site_session
dg_run "$TL_TMP/outside" "$H" "$stop_json"
assert_eq "visual: outside project inert" "" "$TL_OUT"
dg_assert_ok "visual: outside project inert: exits 0"
dg_run "$P/sub" "$H" "$stop_json"
assert_eq "visual: Stop with site work but no evidence blocks" "block" "$(decision)"
assert_contains "visual: block reason" "$TL_OUT" "screenshot"
dg_run "$P" "$H" "$stop_json" 
assert_eq "visual: the delegation flag does not switch the gate off (R9-04)" "block" "$(decision)"
echo '{"active":true,"mode":"codex"}' >"$ST/agent-delegation-active.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: an active delegation does not switch the gate off (R9-04)" "block" "$(decision)"
rm -f "$ST/agent-delegation-active.json"
dg_run "$P" "$H" '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_eq "visual: stop_hook_active alone does not release a condition the agent can clear" "block" "$(decision)"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}' SB_ORCHESTRATOR_PARENT=0
assert_eq "visual: SubagentStop in worker session skipped" "" "$TL_OUT"
dg_assert_ok "visual: SubagentStop in worker session skipped: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}'
assert_eq "visual: SubagentStop in parent session blocks" "block" "$(decision)"
visual_evidence
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: valid evidence allows" "" "$TL_OUT"
dg_assert_ok "visual: valid evidence allows: exits 0"
site_session site-intent false false 2
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: a screenshot older than the latest edit does not count" "block" "$(decision)"
site_session
visual_evidence
rm -f "$shot"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: evidence naming a file that is gone does not count" "block" "$(decision)"
printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR' >"$shot"
jq '.project="/other/project"' "$ST/site-visual-evidence.json" >"$ST/v.t" && mv "$ST/v.t" "$ST/site-visual-evidence.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: evidence left by another project does not count (R9-08)" "block" "$(decision)"
rm -f "$ST/site-visual-evidence.json"
: >"$ST/trivial"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: trivial marker bypasses" "" "$TL_OUT"
dg_assert_ok "visual: trivial marker bypasses: exits 0"
rm -f "$ST/trivial"
site_session edit false false 0
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: session without site edits allowed" "" "$TL_OUT"
dg_assert_ok "visual: session without site edits allowed: exits 0"
site_session
jq '.scope="/elsewhere"' "$SESS" >"$ST/s.t" && mv "$ST/s.t" "$SESS"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: a session left by another project or branch is not this one's (R9-08)" "" "$TL_OUT"
rm -f "$SESS"

dg_run_closed_stdin "$P" "$H"
assert_eq "visual: closed stdin defaults to Stop and is inert" "" "$TL_OUT"
dg_assert_ok "visual: closed stdin defaults to Stop and is inert: exits 0"
dg_run "$P" "$H" "not json"
assert_eq "visual: invalid JSON defaults to Stop and is inert without session" "" "$TL_OUT"
dg_assert_ok "visual: invalid JSON defaults to Stop and is inert without session: exits 0"

# ===================== live-publish-evidence-gate.sh =====================
H=hooks/live-publish-evidence-gate.sh
head_sha="$(git -C "$P" rev-parse HEAD)"
live_evidence() { # [status] [sha] [epoch offset]
  jq -n --arg st "${1:-LIVE}" --arg sha "${2:-$head_sha}" --arg r "$P_REAL" --argjson e "$(( $(date +%s) + ${3:-0} ))" \
    '{status:$st,commit_sha:$sha,project:$r,urls:["https://x"],markers_matched:["m"],verified_at:"t",verified_epoch:$e}' >"$ST/live-publish-evidence.json"
}
dg_run_nolib "$H" "$stop_json"
assert_eq "live: lib-dir fallback inert" "" "$TL_OUT"
dg_assert_ok "live: lib-dir fallback inert: exits 0"
dg_run_nojq "$P" "$H" "$stop_json"
assert_eq "live: no jq => allow" "" "$TL_OUT"
dg_assert_ok "live: no jq => allow: exits 0"
dg_run "$P" "$H" ""
assert_eq "live: empty input" 0 "$TL_STATUS"
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse"}'
assert_eq "live: unrelated event ignored" "" "$TL_OUT"
dg_assert_ok "live: unrelated event ignored: exits 0"
dg_run "$TL_TMP/outside" "$H" "$stop_json"
assert_eq "live: outside project inert" "" "$TL_OUT"
dg_assert_ok "live: outside project inert: exits 0"
site_session site-intent true
dg_run "$P" "$H" "$(shell_json 'git push origin main')"
assert_eq "live: the PreToolUse push is not gated: evidence cannot exist before the deploy" "" "$TL_OUT"
dg_assert_ok "live: the PreToolUse push is not gated: exits 0"
dg_run "$P/sub" "$H" "$stop_json"
assert_eq "live: Stop with push intent and no evidence blocks" "block" "$(decision)"
assert_contains "live: the reason names the sanctioned writer" "$TL_OUT" "scripts/site-live-evidence.sh"
dg_run "$P" "$H" '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_eq "live: stop_hook_active alone does not release a condition the agent can clear" "block" "$(decision)"
site_session site-intent false true
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop with live claim pending blocks" "block" "$(decision)"
dg_run "$P" "$H" "$stop_json" SB_ORCHESTRATOR_PARENT=0
assert_eq "live: a Stop is always the parent's, even with the worker env (R9-05)" "block" "$(decision)"
echo '{"active":true}' >"$ST/agent-delegation-active.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: an active delegation does not switch the gate off (R9-04)" "block" "$(decision)"
rm -f "$ST/agent-delegation-active.json"
site_session site-intent false false
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop without push intent or claim allowed" "" "$TL_OUT"
dg_assert_ok "live: Stop without push intent or claim allowed: exits 0"
rm -f "$SESS"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop without a site session allowed" "" "$TL_OUT"
dg_assert_ok "live: Stop without a site session allowed: exits 0"
site_session site-intent true
live_evidence
dg_run "$P" "$H" "$stop_json"
assert_eq "live: valid evidence for HEAD allows Stop" "" "$TL_OUT"
dg_assert_ok "live: valid evidence for HEAD allows Stop: exits 0"
live_evidence NOT_LIVE
dg_run "$P" "$H" "$stop_json"
assert_eq "live: an honest NOT_LIVE report allows Stop" "" "$TL_OUT"
live_evidence LIVE deadbeef
dg_run "$P" "$H" "$stop_json"
assert_eq "live: evidence for another commit does not count (R9-08)" "block" "$(decision)"
live_evidence LIVE "$head_sha" -100000
dg_run "$P" "$H" "$stop_json"
assert_eq "live: stale evidence does not count (R9-08)" "block" "$(decision)"
live_evidence LIVE "$head_sha" 100000
dg_run "$P" "$H" "$stop_json"
assert_eq "live: evidence dated in the future does not count" "block" "$(decision)"
live_evidence
jq '.project="/other"' "$ST/live-publish-evidence.json" >"$ST/l.t" && mv "$ST/l.t" "$ST/live-publish-evidence.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: evidence from another project does not count" "block" "$(decision)"
echo '{"status":"LIVE","commit_sha":"abc","urls":["https://x"],"verified_at":"t","markers_matched":["m"]}' >"$ST/live-publish-evidence.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: the old hand-written shape (no HEAD, no epoch) does not count" "block" "$(decision)"
live_evidence
: >"$ST/trivial"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: trivial marker bypasses" "" "$TL_OUT"
dg_assert_ok "live: trivial marker bypasses: exits 0"
rm -f "$ST/trivial" "$ST/live-publish-evidence.json"
dg_project "$P" "$(jq -c '.site_profile.live_url=""' <<<"$PROFILE")"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: a profile without live_url has nothing to verify" "" "$TL_OUT"
dg_project "$P" "$PROFILE"
rm -f "$SESS"

dg_run_closed_stdin "$P" "$H"
assert_eq "live: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json"
assert_eq "live: invalid JSON defaults to Stop, inert without session" "" "$TL_OUT"
dg_assert_ok "live: invalid JSON defaults to Stop, inert without session: exits 0"

# ===================== site-regression-gate.sh ===========================
H=hooks/site-regression-gate.sh
mkdir -p "$P/tests/scripts"
suite() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$P/tests/scripts/test-site-$1.sh"; }
good_suites() { local x; for x in chrome-regression doc-freshness content-freshness; do suite "$x" 'echo ok'; done; commit_all suites; }
good_suites
dg_run_nolib "$H" "$stop_json"
assert_eq "regression: lib-dir fallback inert" "" "$TL_OUT"
dg_assert_ok "regression: lib-dir fallback inert: exits 0"
dg_run_nojq "$P" "$H" "$stop_json"
assert_eq "regression: no jq => allow" "" "$TL_OUT"
dg_assert_ok "regression: no jq => allow: exits 0"
dg_run "$P" "$H" ""
assert_eq "regression: empty input" 0 "$TL_STATUS"
dg_run "$TL_TMP/outside" "$H" "$stop_json"
assert_eq "regression: outside project inert" "" "$TL_OUT"
dg_assert_ok "regression: outside project inert: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PostToolUse"}'
assert_eq "regression: unrelated event ignored" "" "$TL_OUT"
dg_assert_ok "regression: unrelated event ignored: exits 0"
site_session
: >"$ST/e2e-matrix-routing-row"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: a routing row marker without the matrix switch exempts nothing" "" "$TL_OUT"
dg_assert_ok "regression: a routing row marker without the matrix switch: exits 0"
rm -f "$ST/e2e-matrix-routing-row"
# the enterprise matrix routing row exempts Stop (marker plus the matrix switch)
# shellcheck source=../../hooks/lib/e2e-matrix-routing.sh
source "$TL_REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
site_session
suite doc-freshness 'exit 7'; commit_all failing-for-routing
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: without the routing row a failing suite blocks" "block" "$(decision)"
SB_E2E_ENTERPRISE_MATRIX=1 sb_e2e_matrix_set_routing_row_marker
dg_run "$P" "$H" "$stop_json" SB_E2E_ENTERPRISE_MATRIX=1
assert_eq "regression: the enterprise routing row exempts Stop" "" "$TL_OUT"
SB_E2E_ENTERPRISE_MATRIX=1 sb_e2e_matrix_clear_routing_row_marker
suite doc-freshness 'echo ok'; commit_all fixed-after-routing

dg_run "$P/sub" "$H" "$stop_json"
assert_eq "regression: passing suites allow Stop" "" "$TL_OUT"
dg_assert_ok "regression: passing suites allow Stop: exits 0"
assert_eq "regression: the pass is recorded against the counted edit" "1" "$(jq -r '.regression_passed_seq' "$SESS")"
assert_match "regression: pass time recorded" '^20' "$(jq -r '.regression_passed_at' "$SESS")"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: current pass short-circuits" "" "$TL_OUT"
dg_assert_ok "regression: current pass short-circuits: exits 0"

site_session
suite doc-freshness 'echo FAILED-DOC; exit 2'
commit_all failing
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: failing suite blocks Stop" "block" "$(decision)"
assert_contains "regression: block says suites failed" "$TL_OUT" "suites ran and failed"
assert_contains "regression: block cites a log file" "$TL_OUT" "site-regression."
assert_contains "regression: block lists the profile's scripts" "$TL_OUT" "bash tests/scripts/test-site-doc-freshness.sh"
dg_run "$P" "$H" '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_eq "regression: stop_hook_active alone does not release a failing suite" "block" "$(decision)"
echo '{"active":true}' >"$ST/agent-delegation-active.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: an active delegation does not switch the gate off (R9-04)" "block" "$(decision)"
rm -f "$ST/agent-delegation-active.json"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}'
assert_eq "regression: SubagentStop in parent session blocks too" "block" "$(decision)"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}' SB_ORCHESTRATOR_PARENT=0
assert_eq "regression: SubagentStop in worker session skipped" "" "$TL_OUT"
dg_assert_ok "regression: SubagentStop in worker session skipped: exits 0"

dg_run "$P" "$H" "$(shell_json 'git push origin feature/x')"
assert_eq "regression: PreToolUse git push with failing suites denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(shell_json 'git push origin feature/x')" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "regression: bridge deny exits 2" 2 "$TL_STATUS"
dg_run "$P" "$H" "$(shell_json 'git -C . push origin main')"
assert_eq "regression: a global option does not hide a push (R9-06)" "deny" "$(decision)"
dg_run "$P" "$H" "$(shell_json 'git  push')"
assert_eq "regression: doubled spaces do not hide a push (R9-06)" "deny" "$(decision)"
dg_run "$P" "$H" "$(shell_json "grep -rn 'git push' docs/")"
assert_eq "regression: a command that only mentions git push is not a push (R9-06)" "" "$TL_OUT"
dg_assert_ok "regression: mention of git push: exits 0"
[[ "$(jq -r '.push_intent' "$SESS")" == false ]] && tl_pass "regression: the PreToolUse attempt records no push intent (R9-06)" || tl_fail "regression: PreToolUse recorded push intent"
dg_run "$P" "$H" "$(shell_json 'git status')"
assert_eq "regression: non-push command ignored" "" "$TL_OUT"
dg_assert_ok "regression: non-push command ignored: exits 0"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Read /x)"
assert_eq "regression: non-shell tool ignored" "" "$TL_OUT"
dg_assert_ok "regression: non-shell tool ignored: exits 0"

# R9-07: a script edited in the work tree (or swapped for `exit 0` without a commit) is not trusted
good_suites
site_session
suite chrome-regression 'exit 0'
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: a regression script changed against HEAD is not trusted (R9-07)" "block" "$(decision)"
assert_contains "regression: the untrusted script is named" "$TL_OUT" "test-site-chrome-regression.sh"
assert_contains "regression: the untrusted message says to commit" "$TL_OUT" "not committed as it stands"
good_suites
printf '#!/usr/bin/env bash\nexit 0\n' >"$P/tests/scripts/test-site-new-extra.sh"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: an unrelated untracked file does not matter" "" "$TL_OUT"
rm -f "$P/tests/scripts/test-site-new-extra.sh"
site_session
mv "$P/tests/scripts/test-site-doc-freshness.sh" "$TL_TMP/doc.sh"
ln -s "$TL_TMP/doc.sh" "$P/tests/scripts/test-site-doc-freshness.sh"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: a symlinked script is not trusted" "block" "$(decision)"
rm -f "$P/tests/scripts/test-site-doc-freshness.sh"
git -C "$P" checkout -q -- tests/scripts

site_session
suite doc-freshness 'rm -f "$SB_RUNTIME_STATE_DIR"/site-regression.*.log; exit 5'
commit_all vanish
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: vanished log is a setup problem" "block" "$(decision)"
assert_contains "regression: vanished log message" "$TL_OUT" "without a usable log file"

site_session
rm -rf "$P/tests/scripts/test-site-content-freshness.sh"
dg_run "$P" "$H" "$stop_json"
assert_contains "regression: a configured script that is missing is a setup problem" "$TL_OUT" "is missing"
git -C "$P" checkout -q -- tests/scripts

# log allocation impossible => rc 91
good_suites
site_session
mkdir -p "$TL_TMP/fallback"
tl_stub mktemp 'exit 1'
printf '%s' "$stop_json" | (cd "$P" && TMPDIR="$TL_TMP/no-such-dir" SB_SITE_REGRESSION_FALLBACK_DIR="$TL_TMP/fallback" bash -c 'mkdir -p "$SB_SITE_REGRESSION_FALLBACK_DIR/site-regression-$$.log"; echo "$$" >"$1"; exec bash "$0"' "$TL_REPO_ROOT/$H" "$TL_TMP/hookpid") >"$TL_TMP/.out" 2>/dev/null || true
rmdir "$TL_TMP/fallback/site-regression-$(cat "$TL_TMP/hookpid").log"
rm -f "$TL_BIN/mktemp"
TL_OUT="$(cat "$TL_TMP/.out")"
assert_contains "regression: unallocatable log reported" "$TL_OUT" "failed to create a log file"

# short-circuit when regression already current
jq -n --arg sc "$(scope)" '{active:true,scope:$sc,touch_reason:"edit",edit_seq:3,regression_passed_seq:3}' >"$SESS"
suite doc-freshness 'exit 9'
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: current pass exits before running suites" "" "$TL_OUT"
dg_assert_ok "regression: current pass exits before running suites: exits 0"
good_suites
site_session

# an empty script list is nothing to run: a pass
dg_project "$P" "$(jq -c '.site_profile.regression_scripts=[]' <<<"$PROFILE")"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: a profile with no scripts has nothing to run" "" "$TL_OUT"
assert_eq "regression: and records the pass" "1" "$(jq -r '.regression_passed_seq' "$SESS")"
dg_project "$P" "$(jq -c '.site_profile.regression_scripts=["../escape.sh","/abs.sh","tests/scripts/test-site-chrome-regression.sh"]' <<<"$PROFILE")"
site_session
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: profile paths that escape the project are ignored" "" "$TL_OUT"
dg_project "$P" "$PROFILE"
site_session

dg_run_closed_stdin "$P" "$H"
assert_eq "regression: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json"
assert_eq "regression: invalid JSON defaults to Stop and still gates" "" "$TL_OUT"
suite doc-freshness 'exit 9'
commit_all fail9
site_session
dg_run "$P" "$H" "not json"
assert_eq "regression: invalid JSON defaults to Stop and still gates when suites fail" "block" "$(decision)"
good_suites
site_session
dg_run_gate_missing "$P" "$H" "$stop_json"
assert_eq "regression: missing project gate => fail open" "" "$TL_OUT"
dg_assert_ok "regression: missing project gate => fail open: exits 0"
dg_run_nolib_in "$P" "$H" "$(shell_json 'git push origin x')"
assert_eq "regression: tool helpers unavailable => ignore" "" "$TL_OUT"
dg_assert_ok "regression: tool helpers unavailable => ignore: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}'
assert_eq "regression: no command in the payload => ignore" "" "$TL_OUT"
dg_assert_ok "regression: no command in the payload => ignore: exits 0"
site_session
echo 'not json' >"$SESS"
dg_run "$P" "$H" "$(shell_json 'git push origin x')"
assert_eq "regression: unreadable session on push => no block" "" "$TL_OUT"
dg_assert_ok "regression: unreadable session on push => no block: exits 0"
site_session
echo blocker >"$TL_TMP/blocker"
dg_run "$P" "$H" "$stop_json" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub"
assert_eq "regression: state dir under a file tolerated" "" "$TL_OUT"
dg_assert_ok "regression: state dir under a file tolerated: exits 0"

# sanity: existing session untouched by non-site Stop
rm -f "$SESS"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: no session => allow" "" "$TL_OUT"
dg_assert_ok "regression: no session => allow: exits 0"

# ===================== a branch switch keeps the session (review r1) ====
site_session
suite doc-freshness 'exit 7'; commit_all failing-for-branch
git -C "$P" checkout -q -b tmpx
dg_run "$P" hooks/site-regression-gate.sh "$(shell_json 'git push origin tmpx:main')"
assert_eq "branch: a push of tmpx:main still runs the regression gate after a branch switch" "deny" "$(decision)"
dg_run "$P" hooks/site-regression-gate.sh "$stop_json"
assert_eq "branch: Stop still blocks on the other branch" "block" "$(decision)"
git -C "$P" checkout -q main
suite doc-freshness 'echo ok'; commit_all fixed-after-branch

# ===================== bounded loop breaker (R9-03, review r1) =========
dg_project "$P" "$(jq -c '.site_profile.stop_block_limit=2' <<<"$PROFILE")"
good_suites
site_session site-intent true
rm -f "$ST/site-stop-loop.json" "$ST/stop-loop-release.log" "$ST/live-publish-evidence.json" "$ST/site-visual-evidence.json"
active_stop='{"hook_event_name":"Stop","stop_hook_active":true}'
for g in live-publish-evidence-gate site-visual-evidence-gate; do
  dg_run "$P" "hooks/$g.sh" "$stop_json"
  assert_eq "loop: $g blocks the first Stop" "block" "$(decision)"
  dg_run "$P" "hooks/$g.sh" "$active_stop"
  assert_eq "loop: $g blocks the repeat Stop too (the agent can still clear it)" "block" "$(decision)"
  dg_run "$P" "hooks/$g.sh" "$active_stop"
  assert_eq "loop: $g releases a condition that did not change after the limit" "" "$TL_OUT"
  assert_contains "loop: the release is logged" "$(cat "$ST/stop-loop-release.log")" "$g released: unchanged after 2 consecutive blocks"
done
# a changed condition (another counted edit) starts the count again
site_session site-intent true false 2
dg_run "$P" hooks/site-visual-evidence-gate.sh "$stop_json"
assert_eq "loop: a new edit makes the same gate block again" "block" "$(decision)"
# a cleared condition resets the count
visual_evidence; jq '.edit_seq=2' "$ST/site-visual-evidence.json" >"$ST/v.t" && mv "$ST/v.t" "$ST/site-visual-evidence.json"
dg_run "$P" hooks/site-visual-evidence-gate.sh "$stop_json"
assert_eq "loop: evidence clears the gate" "" "$TL_OUT"
rm -f "$ST/site-visual-evidence.json"
dg_run "$P" hooks/site-visual-evidence-gate.sh "$stop_json"
dg_run "$P" hooks/site-visual-evidence-gate.sh "$stop_json"
assert_eq "loop: the count restarted after the pass (still blocking on the 2nd identical block)" "block" "$(decision)"
# regression: a failing suite is clearable, a missing script is a setup problem released on the host's repeat
site_session
suite doc-freshness 'exit 7'; commit_all failing-loop
rm -f "$ST/site-stop-loop.json"
dg_run "$P" hooks/site-regression-gate.sh "$stop_json"
dg_run "$P" hooks/site-regression-gate.sh "$active_stop"
assert_eq "loop: a failing suite is blocked on the repeat" "block" "$(decision)"
dg_run "$P" hooks/site-regression-gate.sh "$active_stop"
assert_eq "loop: and released only once it did not change after the limit" "" "$TL_OUT"
site_session
rm -f "$P/tests/scripts/test-site-content-freshness.sh"
dg_run "$P" hooks/site-regression-gate.sh "$stop_json"
assert_eq "loop: a setup problem blocks the first Stop" "block" "$(decision)"
dg_run "$P" hooks/site-regression-gate.sh "$active_stop"
assert_eq "loop: a setup problem the agent cannot clear is released on the host's repeat" "" "$TL_OUT"
assert_contains "loop: and logged as a setup problem" "$(cat "$ST/stop-loop-release.log")" "gate setup problem (rc=90) (stop_hook_active)"
git -C "$P" checkout -q -- tests/scripts
# the v-loop gate
site_session
rm -f "$ST/site-stop-loop.json" "$ST/site-vloops.json"
dg_run "$P" hooks/v-loop-rollup-gate.sh "$stop_json"
dg_run "$P" hooks/v-loop-rollup-gate.sh "$stop_json"
assert_eq "loop: the V-loop gate blocks twice" "block" "$(decision)"
dg_run "$P" hooks/v-loop-rollup-gate.sh "$stop_json"
assert_eq "loop: and then releases" "" "$TL_OUT"
dg_project "$P" "$PROFILE"

tl_results

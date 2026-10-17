#!/usr/bin/env bash
# Behavior tests for the site hooks: chrome guard, preview preflight, regression gate,
# visual evidence gate and live-publish evidence gate.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/sub" "$TL_TMP/outside"
ST="$SB_RUNTIME_STATE_DIR"
SESS="$ST/site-session.json"
site_session() { jq -n --arg r "${1:-site-intent}" '{active:true,touch_reason:$r,push_intent:'"${2:-false}"',live_claim_pending:'"${3:-false}"'}' >"$SESS"; }

edit_json() { # tool path content
  jq -cn --arg t "$1" --arg p "$2" --arg c "$3" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$p,new_string:$c}}'
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
dg_run "$P/sub" "$H" "$(edit_json Edit site/tokens.css '@font-face{}')"
assert_eq "chrome: project found by walking up => font-face denied" "deny" "$(decision)"
assert_contains "chrome: deny reason names the override" "$TL_OUT" "SB FONT TOKEN OVERRIDE"
dg_run "$P" "$H" "$(edit_json Edit site/tokens.css 'font-family: Comic Sans')"
assert_eq "chrome: raw font-family denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit site/tokens.css 'font-family: verdana, sans-serif')"
assert_eq "chrome: a named font starting with v is still denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit site/tokens.css '--space-1: 4px;')"
assert_eq "chrome: tokens.css edit without any font-family allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit site/tokens.css 'font-family:var(--font-body)')"
assert_eq "chrome: var() without a space allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit site/tokens.css $'--a: 1;\nfont-family: var(--f);\nfont-family: Arial;')"
assert_eq "chrome: one raw font-family among var() ones is denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit site/tokens.css 'font-family: var(--font-body)')"
assert_eq "chrome: font-family var() allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Edit /abs/site/tokens.css '@font-face{} /* SB FONT TOKEN OVERRIDE */')"
assert_eq "chrome: override marker allows font edit" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write site/help/a.html '<nav class="nav-inner">x</nav>')"
assert_eq "chrome: inline nav in help html denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write site/help/a.html '<footer class="x footer-inner">')"
assert_eq "chrome: inline footer denied" "deny" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write site/help/a.html '<p>plain</p>')"
assert_eq "chrome: clean site html allowed" "none" "$(decision)"
dg_run "$P" "$H" "$(edit_json Write src/a.html '<nav class="nav-inner">')"
assert_eq "chrome: non-site file allowed" "none" "$(decision)"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{}}'
assert_eq "chrome: missing file_path allowed" "" "$TL_OUT"
dg_assert_ok "chrome: missing file_path allowed: exits 0"
dg_run "$P" "$H" "$(edit_json Write site/help/a.html '<nav class="nav-inner">')" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "chrome: bridge mode exits 2" 2 "$TL_STATUS"
assert_contains "chrome: bridge mode explains on stderr" "$TL_ERR" "single-source guard"

dg_run_closed_stdin "$P" "$H"
assert_eq "chrome: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json"
assert_eq "chrome: invalid JSON => inert" "" "$TL_OUT"
dg_assert_ok "chrome: invalid JSON => inert: exits 0"
dg_run_gate_missing "$P" "$H" "$(edit_json Write site/help/a.html '<nav class="nav-inner">')"
assert_eq "chrome: missing project gate => fail open" "" "$TL_OUT"
dg_assert_ok "chrome: missing project gate => fail open: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":"oops"}'
assert_eq "chrome: non-object tool_input => allow" "" "$TL_OUT"
dg_assert_ok "chrome: non-object tool_input => allow: exits 0"

# ===================== site-preview-preflight.sh =========================
H=hooks/site-preview-preflight.sh
tl_stub curl 'printf 500'
dg_run_nolib "$H" "$(edit_json Edit site/a.html x)"
assert_eq "preflight: lib-dir fallback inert" "" "$TL_OUT"
dg_assert_ok "preflight: lib-dir fallback inert: exits 0"
dg_run_nojq "$P" "$H" "$(edit_json Edit site/a.html x)"
assert_eq "preflight: no jq => allow" "" "$TL_OUT"
dg_assert_ok "preflight: no jq => allow: exits 0"
dg_run "$P" "$H" ""
assert_eq "preflight: empty input" 0 "$TL_STATUS"
dg_run "$P" "$H" '{"hook_event_name":"Stop"}'
assert_eq "preflight: non PreToolUse ignored" "" "$TL_OUT"
dg_assert_ok "preflight: non PreToolUse ignored: exits 0"
dg_run "$P" "$H" "$(edit_json Bash site/a.html x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: non-edit tool ignored" "" "$TL_OUT"
dg_assert_ok "preflight: non-edit tool ignored: exits 0"
dg_run "$TL_TMP/outside" "$H" "$(edit_json Edit site/a.html x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: outside project inert" "" "$TL_OUT"
dg_assert_ok "preflight: outside project inert: exits 0"
dg_run "$P/sub" "$H" "$(edit_json Edit site/a.html x)"
assert_eq "preflight: parent orchestrator session skipped" "" "$TL_OUT"
dg_assert_ok "preflight: parent orchestrator session skipped: exits 0"
dg_run "$P/sub" "$H" "$(edit_json Edit site/a.html x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: unhealthy preview denies site edit" "deny" "$(decision)"
assert_contains "preflight: reason points at serve.sh" "$TL_OUT" "site/serve.sh"
dg_run "$P" "$H" "$(edit_json Edit src/a.sh x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: non-site path ignored" "" "$TL_OUT"
dg_assert_ok "preflight: non-site path ignored: exits 0"
tl_stub curl 'printf 200'
dg_run "$P" "$H" "$(edit_json Edit site/a.html x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: healthy preview allows" "" "$TL_OUT"
dg_assert_ok "preflight: healthy preview allows: exits 0"
tl_stub curl 'printf 500'
dg_run "$P" "$H" "$(edit_json Edit site/a.html x)" SB_ORCHESTRATOR_PARENT=0 SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "preflight: bridge mode exits 2" 2 "$TL_STATUS"

dg_run_closed_stdin "$P" "$H" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: invalid JSON => inert" "" "$TL_OUT"
dg_assert_ok "preflight: invalid JSON => inert: exits 0"
dg_run_gate_missing "$P" "$H" "$(edit_json Edit site/a.html x)" SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: missing project gate => fail open" "" "$TL_OUT"
dg_assert_ok "preflight: missing project gate => fail open: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":"oops"}' SB_ORCHESTRATOR_PARENT=0
assert_eq "preflight: non-object tool_input => allow" "" "$TL_OUT"
dg_assert_ok "preflight: non-object tool_input => allow: exits 0"

# ===================== site-visual-evidence-gate.sh ======================
H=hooks/site-visual-evidence-gate.sh
stop_json='{"hook_event_name":"Stop"}'
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
assert_contains "visual: block reason" "$TL_OUT" "1280px"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}' SB_ORCHESTRATOR_PARENT=0
assert_eq "visual: SubagentStop in worker session skipped" "" "$TL_OUT"
dg_assert_ok "visual: SubagentStop in worker session skipped: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}'
assert_eq "visual: SubagentStop in parent session blocks" "block" "$(decision)"
echo '{"paths":["a.png"],"captured_at":"t"}' >"$ST/site-visual-evidence.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: valid evidence allows" "" "$TL_OUT"
dg_assert_ok "visual: valid evidence allows: exits 0"
rm -f "$ST/site-visual-evidence.json"
: >"$ST/trivial"
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: trivial marker bypasses" "" "$TL_OUT"
dg_assert_ok "visual: trivial marker bypasses: exits 0"
rm -f "$ST/trivial"
site_session edit
dg_run "$P" "$H" "$stop_json"
assert_eq "visual: session without site work allowed" "" "$TL_OUT"
dg_assert_ok "visual: session without site work allowed: exits 0"
rm -f "$SESS"

dg_run_closed_stdin "$P" "$H"
assert_eq "visual: closed stdin defaults to Stop and is inert" "" "$TL_OUT"
dg_assert_ok "visual: closed stdin defaults to Stop and is inert: exits 0"
dg_run "$P" "$H" "not json"
assert_eq "visual: invalid JSON defaults to Stop and is inert without session" "" "$TL_OUT"
dg_assert_ok "visual: invalid JSON defaults to Stop and is inert without session: exits 0"

# ===================== live-publish-evidence-gate.sh =====================
H=hooks/live-publish-evidence-gate.sh
push_json="$(tl_hook_json PreToolUse Bash 'git push origin main')"
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
dg_run "$P/sub" "$H" "$push_json"
assert_eq "live: push to main without evidence is denied" "deny" "$(decision)"
assert_contains "live: reason names evidence file" "$TL_OUT" "live-publish-evidence.json"
dg_run "$P" "$H" "$push_json" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "live: bridge mode exits 2" 2 "$TL_STATUS"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Read /x)"
assert_eq "live: non-shell tool ignored" "" "$TL_OUT"
dg_assert_ok "live: non-shell tool ignored: exits 0"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git push origin feature/x')"
assert_eq "live: push to feature branch ignored" "" "$TL_OUT"
dg_assert_ok "live: push to feature branch ignored: exits 0"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop with push intent and no evidence blocks" "block" "$(decision)"
site_session site-intent false true
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop with live claim pending blocks" "block" "$(decision)"
dg_run "$P" "$H" "$stop_json" SB_ORCHESTRATOR_PARENT=0
assert_eq "live: Stop in worker session skipped" "" "$TL_OUT"
dg_assert_ok "live: Stop in worker session skipped: exits 0"
site_session site-intent false false
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop without push intent or claim allowed" "" "$TL_OUT"
dg_assert_ok "live: Stop without push intent or claim allowed: exits 0"
rm -f "$SESS"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: Stop without a site session allowed" "" "$TL_OUT"
dg_assert_ok "live: Stop without a site session allowed: exits 0"
site_session site-intent true
echo '{"status":"LIVE","commit_sha":"abc","urls":["https://x"],"verified_at":"t","markers_matched":["m"]}' >"$ST/live-publish-evidence.json"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: valid evidence allows Stop" "" "$TL_OUT"
dg_assert_ok "live: valid evidence allows Stop: exits 0"
rm -f "$ST/live-publish-evidence.json"
: >"$ST/trivial"
dg_run "$P" "$H" "$stop_json"
assert_eq "live: trivial marker bypasses" "" "$TL_OUT"
dg_assert_ok "live: trivial marker bypasses: exits 0"
rm -f "$ST/trivial" "$SESS"

dg_run_closed_stdin "$P" "$H"
assert_eq "live: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json"
assert_eq "live: invalid JSON defaults to Stop, inert without session" "" "$TL_OUT"
dg_assert_ok "live: invalid JSON defaults to Stop, inert without session: exits 0"

# ===================== site-regression-gate.sh ===========================
H=hooks/site-regression-gate.sh
mkdir -p "$P/tests/scripts"
suite() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$P/tests/scripts/test-site-$1.sh"; }
for s in chrome-regression doc-freshness content-freshness; do suite "$s" 'echo ok'; done
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
assert_eq "regression: e2e routing row exempts Stop" "" "$TL_OUT"
dg_assert_ok "regression: e2e routing row exempts Stop: exits 0"
rm -f "$ST/e2e-matrix-routing-row"

dg_run "$P/sub" "$H" "$stop_json"
assert_eq "regression: passing suites allow Stop" "" "$TL_OUT"
dg_assert_ok "regression: passing suites allow Stop: exits 0"
assert_match "regression: pass recorded in session" '^20' "$(jq -r '.regression_passed_at' "$SESS")"
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: current pass short-circuits" "" "$TL_OUT"
dg_assert_ok "regression: current pass short-circuits: exits 0"

site_session
suite doc-freshness 'echo FAILED-DOC; exit 2'
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: failing suite blocks Stop" "block" "$(decision)"
assert_contains "regression: block says suites failed" "$TL_OUT" "suites ran and failed"
assert_contains "regression: block cites a log file" "$TL_OUT" "site-regression."
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}'
assert_eq "regression: SubagentStop in parent session blocks too" "block" "$(decision)"
dg_run "$P" "$H" '{"hook_event_name":"SubagentStop"}' SB_ORCHESTRATOR_PARENT=0
assert_eq "regression: SubagentStop in worker session skipped" "" "$TL_OUT"
dg_assert_ok "regression: SubagentStop in worker session skipped: exits 0"

dg_run "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git push origin feature/x')"
assert_eq "regression: PreToolUse git push with failing suites denied" "deny" "$(decision)"
assert_eq "regression: push marks push_intent" "true" "$(jq -r .push_intent "$SESS")"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git push origin feature/x')" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "regression: bridge deny exits 2" 2 "$TL_STATUS"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git status')"
assert_eq "regression: non-push command ignored" "" "$TL_OUT"
dg_assert_ok "regression: non-push command ignored: exits 0"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Read /x)"
assert_eq "regression: non-shell tool ignored" "" "$TL_OUT"
dg_assert_ok "regression: non-shell tool ignored: exits 0"

site_session
suite doc-freshness 'rm -f "$SB_RUNTIME_STATE_DIR"/site-regression.*.log; exit 5'
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: vanished log is a setup problem" "block" "$(decision)"
assert_contains "regression: vanished log message" "$TL_OUT" "without a usable log file"

site_session
rm -rf "$P/tests"
dg_run "$P" "$H" "$stop_json"
assert_contains "regression: missing tests dir is a setup problem" "$TL_OUT" "no tests directory"

# log allocation impossible => rc 91
mkdir -p "$P/tests/scripts"
for s in chrome-regression doc-freshness content-freshness; do suite "$s" 'echo ok'; done
site_session
mkdir -p "$TL_TMP/fallback"
tl_stub mktemp 'exit 1'
printf '%s' "$stop_json" | (cd "$P" && TMPDIR="$TL_TMP/no-such-dir" SB_SITE_REGRESSION_FALLBACK_DIR="$TL_TMP/fallback" bash -c 'mkdir -p "$SB_SITE_REGRESSION_FALLBACK_DIR/site-regression-$$.log"; echo "$$" >"$1"; exec bash "$0"' "$TL_REPO_ROOT/$H" "$TL_TMP/hookpid") >"$TL_TMP/.out" 2>/dev/null || true
rmdir "$TL_TMP/fallback/site-regression-$(cat "$TL_TMP/hookpid").log"
rm -f "$TL_BIN/mktemp"
TL_OUT="$(cat "$TL_TMP/.out")"
assert_contains "regression: unallocatable log reported" "$TL_OUT" "failed to create a log file"

# short-circuit when regression already current
jq -n '{active:true,touch_reason:"site-intent",last_touch_at:"2026-01-01T00:00:10Z",regression_passed_at:"2026-01-01T00:00:20Z"}' >"$SESS"
suite doc-freshness 'exit 9'
dg_run "$P" "$H" "$stop_json"
assert_eq "regression: current pass exits before running suites" "" "$TL_OUT"
dg_assert_ok "regression: current pass exits before running suites: exits 0"
site_session

dg_run_closed_stdin "$P" "$H"
assert_eq "regression: closed stdin => exit 0" 0 "$TL_STATUS"
dg_run "$P" "$H" "not json"
assert_eq "regression: invalid JSON defaults to Stop and still gates" "block" "$(decision)"
dg_run_gate_missing "$P" "$H" "$stop_json"
assert_eq "regression: missing project gate => fail open" "" "$TL_OUT"
dg_assert_ok "regression: missing project gate => fail open: exits 0"
dg_run_nolib_in "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git push origin x')"
assert_eq "regression: tool helpers unavailable => ignore" "" "$TL_OUT"
dg_assert_ok "regression: tool helpers unavailable => ignore: exits 0"
tl_stub python3 'exit 1'
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git push origin x')"
assert_eq "regression: command extraction failure => ignore" "" "$TL_OUT"
dg_assert_ok "regression: command extraction failure => ignore: exits 0"
rm -f "$TL_BIN/python3"
site_session
echo 'not json' >"$SESS"
dg_run "$P" "$H" "$(tl_hook_json PreToolUse Bash 'git push origin x')"
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

tl_results

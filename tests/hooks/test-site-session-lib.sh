#!/usr/bin/env bash
# Unit tests for hooks/lib/site-session.sh (site session state, vloops, evidence helpers).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# shellcheck source=../../hooks/lib/site-session.sh
source "$TL_REPO_ROOT/hooks/lib/site-session.sh"

export SB_RUNTIME_STATE_DIR="$TL_TMP/state"
mkdir -p "$SB_RUNTIME_STATE_DIR"
SESS="$SB_RUNTIME_STATE_DIR/site-session.json"

PROJ="$TL_TMP/proj"
mkdir -p "$PROJ/site" "$PROJ/sub/deeper" "$PROJ/.git"
echo '{}' >"$PROJ/.silver-bullet.json"
echo '# sb' >"$PROJ/silver-bullet.md"

rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
reset() { rm -f "$SB_RUNTIME_STATE_DIR"/*.json "$SB_RUNTIME_STATE_DIR"/*.jsonl "$SB_RUNTIME_STATE_DIR"/*.log 2>/dev/null || true; }

# --- repo root + path_is_site ---------------------------------------------
cd "$PROJ/sub/deeper"
assert_eq "repo_root walks up from nested dir" "$PROJ" "$(sb_site_session_repo_root)"
assert_eq "path_is_site: empty path" 1 "$(rc sb_site_session_path_is_site "")"
assert_eq "path_is_site: relative site/ path" 0 "$(rc sb_site_session_path_is_site "site/index.html")"
assert_eq "path_is_site: nested */site/*" 0 "$(rc sb_site_session_path_is_site "/elsewhere/site/x.css")"
assert_eq "path_is_site: not site" 1 "$(rc sb_site_session_path_is_site "$PROJ/src/a.sh")"
assert_eq "path_is_site: other absolute path" 1 "$(rc sb_site_session_path_is_site "/etc/passwd")"
assert_eq "path_is_site: relative non-site path" 1 "$(rc sb_site_session_path_is_site "docs/a.md")"
cd /
assert_eq "repo_root fails outside a project" 1 "$(rc sb_site_session_repo_root)"
assert_eq "path_is_site: no repo root and non-site path" 1 "$(rc sb_site_session_path_is_site "/tmp/x/a.sh")"
cd "$PROJ"
mkdir -p "$TL_TMP/gitonly/.git"
cd "$TL_TMP/gitonly"
assert_eq "repo_root stops at .git without SB files" 1 "$(rc sb_site_session_repo_root)"
cd "$PROJ"

# --- intent detectors -----------------------------------------------------
assert_eq "site intent: empty prompt" 1 "$(rc sb_site_prompt_is_site_intent "")"
assert_eq "site intent: matches Help Center (case-insens)" 0 "$(rc sb_site_prompt_is_site_intent "Update the HELP CENTER")"
assert_eq "site intent: unrelated prompt" 1 "$(rc sb_site_prompt_is_site_intent "fix the parser")"
assert_eq "delegation intent: empty" 1 "$(rc sb_site_text_is_agent_delegation_intent "")"
assert_eq "delegation intent: silver-agent-codex" 0 "$(rc sb_site_text_is_agent_delegation_intent "run silver-agent-codex now")"
assert_eq "delegation intent: plain text" 1 "$(rc sb_site_text_is_agent_delegation_intent "hello")"
assert_eq "prompt delegation wrapper true" 0 "$(rc sb_site_prompt_is_agent_delegation_intent "AF-AGENT-DELEGATE x")"
assert_eq "prompt delegation wrapper false" 1 "$(rc sb_site_prompt_is_agent_delegation_intent "plain")"

# --- touch / mark ---------------------------------------------------------
reset
sb_site_session_touch
assert_eq "touch creates active session with default reason" "edit" "$(jq -r .touch_reason "$SESS")"
assert_eq "touch new file: push_intent false" "false" "$(jq -r .push_intent "$SESS")"
sb_site_session_touch "edit:site/a.html"
assert_eq "touch updates existing reason" "edit:site/a.html" "$(jq -r .touch_reason "$SESS")"
assert_eq "touch keeps active" "true" "$(jq -r .active "$SESS")"
reset
sb_site_session_mark_site_intent
assert_eq "mark_site_intent reason" "site-intent" "$(jq -r .touch_reason "$SESS")"
reset
sb_site_session_mark_push_intent
assert_eq "mark_push_intent sets flag" "true" "$(jq -r .push_intent "$SESS")"
assert_eq "mark_push_intent reason" "push-intent" "$(jq -r .touch_reason "$SESS")"
reset
sb_site_session_mark_live_claim_pending
assert_eq "live_claim_pending created+set" "true" "$(jq -r .live_claim_pending "$SESS")"
sb_site_session_mark_live_claim_pending
assert_eq "live_claim_pending idempotent on existing file" "true" "$(jq -r .live_claim_pending "$SESS")"

# jq missing: touch is a no-op, others return 0 without creating state
reset
NOJQ="$(tl_path_without jq)"
assert_eq "touch without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_touch x)"
assert_file_absent "touch without jq writes nothing" "$SESS"
echo '{"active":true}' >"$SESS"
assert_eq "mark_push_intent without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_mark_push_intent)"
assert_eq "mark_live_claim without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_mark_live_claim_pending)"
assert_eq "active without jq is false" 1 "$(PATH="$NOJQ" rc sb_site_session_active)"
assert_eq "has_site_work without jq is false" 1 "$(PATH="$NOJQ" rc sb_site_session_has_site_work)"
assert_eq "regression_current without jq is false" 1 "$(PATH="$NOJQ" rc sb_site_session_regression_current)"
assert_eq "mark_regression_pass without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_mark_regression_pass)"
assert_eq "vloop_mark without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_vloop_mark preflight)"
assert_eq "init_vloops without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_init_vloops)"
assert_file_absent "init_vloops without jq writes nothing" "$(sb_site_session_vloop_file)"
assert_eq "mark_visual_evidence without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_mark_visual_evidence p)"
assert_eq "mark_pending_audit without jq returns 0" 0 "$(PATH="$NOJQ" rc sb_site_session_mark_pending_completion_audit p)"
assert_eq "live evidence valid without jq false" 1 "$(PATH="$NOJQ" rc sb_live_publish_evidence_valid)"
assert_eq "visual valid without jq false" 1 "$(PATH="$NOJQ" rc sb_site_session_visual_evidence_valid)"
assert_eq "pending audit without jq false" 1 "$(PATH="$NOJQ" rc sb_site_session_pending_completion_audit)"
assert_eq "vloop_pending without jq false" 1 "$(PATH="$NOJQ" rc sb_site_session_vloop_pending)"
echo '{}' >"$(sb_site_session_vloop_file)"
assert_eq "vloop_pending_summary without jq returns 0 silently" "" "$(PATH="$NOJQ" sb_site_session_vloop_pending_summary)"
reset

# --- active / has_site_work / gates_apply ---------------------------------
assert_eq "active: no file" 1 "$(rc sb_site_session_active)"
assert_eq "has_site_work: no file" 1 "$(rc sb_site_session_has_site_work)"
echo '{"active":true,"touch_reason":"edit"}' >"$SESS"
assert_eq "active: true" 0 "$(rc sb_site_session_active)"
assert_eq "has_site_work: bare edit reason is not site work" 1 "$(rc sb_site_session_has_site_work)"
for r in site-intent push-intent live-claim regression "edit:site/a.html" "edit:/x/site/a.html"; do
  jq -n --arg r "$r" '{active:true,touch_reason:$r}' >"$SESS"
  assert_eq "has_site_work: reason $r" 0 "$(rc sb_site_session_has_site_work)"
done
echo '{"active":true,"touch_reason":"edit:other","push_intent":true}' >"$SESS"
assert_eq "has_site_work: push_intent flag" 0 "$(rc sb_site_session_has_site_work)"
echo '{"active":true,"touch_reason":"edit:other","live_claim_pending":true}' >"$SESS"
assert_eq "has_site_work: live_claim flag" 0 "$(rc sb_site_session_has_site_work)"
echo '{"active":true,"touch_reason":"edit:a/site/b"}' >"$SESS"
assert_eq "has_site_work: edit:*/site/* reason" 0 "$(rc sb_site_session_has_site_work)"
echo '{"active":true,"touch_reason":"edit:xsite/b"}' >"$SESS"
assert_eq "has_site_work: edit:xsite is not site work" 1 "$(rc sb_site_session_has_site_work)"

echo '{"active":false,"touch_reason":"site-intent"}' >"$SESS"
assert_eq "gates_apply: inactive session" 1 "$(rc sb_site_session_gates_apply)"
echo '{"active":true,"touch_reason":"edit"}' >"$SESS"
assert_eq "gates_apply: active but no site work" 1 "$(rc sb_site_session_gates_apply)"
echo '{"active":true,"touch_reason":"site-intent"}' >"$SESS"
assert_eq "gates_apply: genuine site session" 0 "$(rc sb_site_session_gates_apply)"
# delegation active suppresses gates
echo '{"active":true}' >"$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"
assert_eq "gates_apply: suppressed while agent delegation active" 1 "$(rc sb_site_session_gates_apply)"
rm -f "$SB_RUNTIME_STATE_DIR/agent-delegation-active.json"

# --- subagent input detection --------------------------------------------
assert_eq "subagent related: empty" 1 "$(rc sb_site_session_subagent_input_is_site_related "")"
assert_eq "subagent related: delegation text excluded" 1 "$(rc sb_site_session_subagent_input_is_site_related "silver-agent-codex edit site/a.html")"
assert_eq "subagent related: site path" 0 "$(rc sb_site_session_subagent_input_is_site_related "edit site/help/a.html")"
assert_eq "subagent related: unrelated" 1 "$(rc sb_site_session_subagent_input_is_site_related "refactor parser")"

# --- regression_current ---------------------------------------------------
reset
assert_eq "regression_current: no file" 1 "$(rc sb_site_session_regression_current)"
echo '{"last_touch_at":"2026-01-01T00:00:10Z","regression_passed_at":"2026-01-01T00:00:20Z"}' >"$SESS"
assert_eq "regression_current: passed after touch" 0 "$(rc sb_site_session_regression_current)"
echo '{"last_touch_at":"2026-01-01T00:00:30Z","regression_passed_at":"2026-01-01T00:00:20Z"}' >"$SESS"
assert_eq "regression_current: stale pass" 1 "$(rc sb_site_session_regression_current)"
echo '{"last_touch_at":"2026-01-01T00:00:30Z"}' >"$SESS"
assert_eq "regression_current: never passed" 1 "$(rc sb_site_session_regression_current)"
echo '{"last_touch_at":"2026-01-01T00:00:10Z","regression_passed_at":"2026-01-01T00:00:20Z"}' >"$SESS"
assert_eq "regression_current: outside project root" 1 "$(cd / && rc sb_site_session_regression_current)"

# --- mark_regression_pass -------------------------------------------------
reset
sb_site_session_mark_regression_pass
assert_eq "mark_regression_pass creates session with reason" "regression" "$(jq -r .touch_reason "$SESS")"
assert_match "mark_regression_pass records timestamp" '^20[0-9]{2}-' "$(jq -r .regression_passed_at "$SESS")"

# --- run_regression_tests -------------------------------------------------
reset
assert_eq "run_regression: missing tests dir => 90" 90 "$(rc sb_site_session_run_regression_tests "$TL_TMP/none")"
assert_eq "run_regression: empty root => 90" 90 "$(rc sb_site_session_run_regression_tests "")"
mkdir -p "$PROJ/tests/scripts"
for s in chrome-regression doc-freshness content-freshness; do
  printf '#!/usr/bin/env bash\necho ran-%s\n' "$s" >"$PROJ/tests/scripts/test-site-$s.sh"
done
log="$(sb_site_session_run_regression_tests "$PROJ")"
assert_match "run_regression: log file under state dir with .log" '/site-regression\.[A-Za-z0-9]+\.log$' "$log"
assert_contains "run_regression: log captures suite output" "$(cat "$log")" "ran-content-freshness"
assert_match "run_regression: pass marks regression time" '^20' "$(jq -r .regression_passed_at "$SESS")"
printf '#!/usr/bin/env bash\necho boom; exit 3\n' >"$PROJ/tests/scripts/test-site-doc-freshness.sh"
reset
r=0; log="$(sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_eq "run_regression: suite failure rc propagated" 3 "$r"
assert_contains "run_regression: failure log content" "$(cat "$log")" "boom"
assert_file_absent "run_regression: failure does not mark pass" "$SESS"
# state dir not creatable -> falls back to TMPDIR pid log
reset
echo blocker >"$TL_TMP/blocker"
mkdir -p "$TL_TMP/tmpd"
r=0; log="$(SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub" TMPDIR="$TL_TMP/tmpd" sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_match "run_regression: mktemp failure falls back to TMPDIR pid log" "^$TL_TMP/tmpd/site-regression-[0-9]+\\.log\$" "$log"
rm -f "$log"
# TMPDIR unwritable too -> fallback-dir pid log (sandboxed through the seam variable)
mkdir -p "$TL_TMP/fallback"
r=0; log="$(SB_SITE_REGRESSION_FALLBACK_DIR="$TL_TMP/fallback" SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub" TMPDIR="$TL_TMP/blocker/nope" sb_site_session_run_regression_tests "$PROJ")" || r=$?
assert_match "run_regression: second fallback is the fallback-dir pid log" "^$TL_TMP/fallback/site-regression-[0-9]+\\.log\$" "$log"
rm -f "$log"
# default fallback directory is /tmp (documented, not exercised: it would write outside the sandbox)
assert_contains "run_regression: fallback default is /tmp" "$(grep -c 'SB_SITE_REGRESSION_FALLBACK_DIR:-/tmp' "$TL_REPO_ROOT/hooks/lib/site-session.sh")" "1"
# both unwritable -> 91 (':' redirect fails when the pid log path is a directory)
mkdir -p "$TL_TMP/fallback/site-regression-$$.log"
r=0; SB_SITE_REGRESSION_FALLBACK_DIR="$TL_TMP/fallback" SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub" TMPDIR="$TL_TMP/blocker/nope" sb_site_session_run_regression_tests "$PROJ" >/dev/null 2>&1 || r=$?
rmdir "$TL_TMP/fallback/site-regression-$$.log"
assert_eq "run_regression: no log can be allocated => 91" 91 "$r"
# mv of the base log fails -> keeps the base name
mkdir -p "$TL_TMP/mvfail"
tl_stub mv 'exit 1'; hash -r
r=0; log="$(SB_RUNTIME_STATE_DIR="$TL_TMP/mvfail" sb_site_session_run_regression_tests "$PROJ")" || r=$?
rm -f "$TL_BIN/mv"; hash -r
assert_match "run_regression: mv failure keeps un-suffixed log" '/site-regression\.[A-Za-z0-9]+$' "$log"

# cd failure inside the regression subshell is reported as a suite failure
eval 'cd() { return 1; }'
r=0; log="$(SB_RUNTIME_STATE_DIR="$TL_TMP/mvfail" sb_site_session_run_regression_tests "$PROJ")" || r=$?
unset -f cd
assert_eq "run_regression: cd into repo failing => rc 1" 1 "$r"

# --- push_targets_main ----------------------------------------------------
assert_eq "push main: origin main" 0 "$(rc sb_site_session_push_targets_main "git push origin main")"
assert_eq "push main: HEAD:master" 0 "$(rc sb_site_session_push_targets_main "git push origin HEAD:master")"
assert_eq "push main: feature branch" 1 "$(rc sb_site_session_push_targets_main "git push origin feature/x")"
assert_eq "push main: not a push" 1 "$(rc sb_site_session_push_targets_main "git status main")"
sb_shell_command_unwrap_rtk() { printf '%s' "${1#rtk }"; }
assert_eq "push main: unwrap hook applied" 0 "$(rc sb_site_session_push_targets_main "rtk git push origin main")"
sb_shell_command_unwrap_rtk() { return 1; }
assert_eq "push main: unwrap failure falls back to raw command" 0 "$(rc sb_site_session_push_targets_main "git push origin main")"
unset -f sb_shell_command_unwrap_rtk

# --- live publish evidence ------------------------------------------------
EV="$(sb_site_session_live_evidence_file)"
reset
assert_eq "live evidence: missing" 1 "$(rc sb_live_publish_evidence_valid)"
echo '{"status":"LIVE","commit_sha":"abc","urls":["https://x"],"verified_at":"t","markers_matched":["m"]}' >"$EV"
assert_eq "live evidence: complete" 0 "$(rc sb_live_publish_evidence_valid)"
echo '{"status":"LIVE","commit_sha":"abc","urls":[],"verified_at":"t","markers_matched":["m"]}' >"$EV"
assert_eq "live evidence: no urls" 1 "$(rc sb_live_publish_evidence_valid)"
echo '{"status":"MAYBE","commit_sha":"abc","urls":["u"],"verified_at":"t","markers_matched":["m"]}' >"$EV"
assert_eq "live evidence: bad status" 1 "$(rc sb_live_publish_evidence_valid)"
rm -f "$EV"; echo '{"status":"LIVE"}' >"$TL_TMP/real-ev.json"; ln -s "$TL_TMP/real-ev.json" "$EV"
assert_eq "live evidence: symlink refused" 1 "$(rc sb_live_publish_evidence_valid)"
rm -f "$EV"

# --- subagent log ---------------------------------------------------------
reset
assert_eq "subagents_spawned: no log" 1 "$(rc sb_site_session_subagents_spawned)"
sb_site_session_record_subagent_spawn ""
assert_file_absent "record_spawn: empty input writes nothing" "$(sb_site_session_subagent_log)"
sb_site_session_record_subagent_spawn "update site/help/x.html"
LOG="$(sb_site_session_subagent_log)"
assert_eq "record_spawn: site_related true" "true" "$(jq -r .site_related "$LOG")"
assert_eq "record_spawn: site input touches session" "subagent-site" "$(jq -r .touch_reason "$SESS")"
assert_eq "subagents_spawned: non-empty log" 0 "$(rc sb_site_session_subagents_spawned)"
reset
sb_site_session_record_subagent_spawn "refactor parser"
assert_file_absent "record_spawn: unrelated input does not touch session" "$SESS"
assert_eq "record_spawn: unrelated site_related false" "false" "$(jq -r .site_related "$LOG")"
PATH="$NOJQ" sb_site_session_record_subagent_spawn "plain"
assert_contains "record_spawn: jq-less fallback line" "$(tail -n1 "$LOG")" '"spawned_at"'
: >"$LOG"
assert_eq "subagents_spawned: empty log" 1 "$(rc sb_site_session_subagents_spawned)"
sb_site_session_clear_subagent_log
assert_file_absent "clear_subagent_log removes log" "$LOG"

# --- vloops ---------------------------------------------------------------
reset
VL="$(sb_site_session_vloop_file)"
assert_eq "vloop_pending: no file" 1 "$(rc sb_site_session_vloop_pending)"
assert_eq "vloop_mark: empty id => 1" 1 "$(rc sb_site_session_vloop_mark "")"
sb_site_session_vloop_mark "preflight" "ref1"
assert_eq "vloop_mark initialises file and marks" "done" "$(jq -r '.steps[]|select(.id=="preflight").status' "$VL")"
assert_eq "vloop_mark stores evidence ref" "ref1" "$(jq -r '.steps[]|select(.id=="preflight").evidence_ref' "$VL")"
sb_site_session_vloop_mark "preflight" ""
assert_eq "vloop_mark empty ref keeps old ref" "ref1" "$(jq -r '.steps[]|select(.id=="preflight").evidence_ref' "$VL")"
assert_eq "vloop_pending: required steps remain (no push intent)" 0 "$(rc sb_site_session_vloop_pending)"
for s in implement regression visual; do sb_site_session_vloop_mark "$s"; done
assert_eq "vloop_pending: only optional publish left => not pending" 1 "$(rc sb_site_session_vloop_pending)"
echo '{"push_intent":true}' >"$SESS"
sb_site_session_vloop_mark publish
jq '(.steps[]|select(.id=="publish")).status="pending" | (.steps[]|select(.id=="publish")).required=true' "$VL" >"$VL.t" && mv "$VL.t" "$VL"
assert_eq "vloop_pending: push intent makes publish count" 0 "$(rc sb_site_session_vloop_pending)"
sb_site_session_vloop_mark publish
assert_eq "vloop_pending: all done with push intent" 1 "$(rc sb_site_session_vloop_pending)"
assert_eq "vloop summary: complete => empty" "" "$(sb_site_session_vloop_pending_summary)"
sb_site_session_init_vloops
assert_contains "vloop summary lists pending step" "$(sb_site_session_vloop_pending_summary)" "Preflight regression (preflight): pending"
rm -f "$VL"
assert_eq "vloop summary: no file => empty" "" "$(sb_site_session_vloop_pending_summary)"

# --- sync_vloops_from_state ----------------------------------------------
reset
sb_site_session_sync_vloops_from_state
assert_eq "sync: inactive session creates pending vloops" "pending" "$(jq -r '.steps[]|select(.id=="implement").status' "$VL")"
reset
jq -n '{active:true,last_touch_at:"2026-01-01T00:00:10Z",regression_passed_at:"2026-01-01T00:00:20Z",push_intent:false}' >"$SESS"
echo '{"status":"LIVE","commit_sha":"abc","urls":["u"],"verified_at":"t","markers_matched":["m"]}' >"$EV"
echo '{"paths":["p"],"captured_at":"t"}' >"$(sb_site_session_visual_evidence_file)"
sb_site_session_sync_vloops_from_state
for s in preflight regression implement publish visual; do
  assert_eq "sync: $s marked done" "done" "$(jq -r --arg s "$s" '.steps[]|select(.id==$s).status' "$VL")"
done
assert_eq "sync: publish stays optional without push intent" "false" "$(jq -r '.steps[]|select(.id=="publish").required' "$VL")"
jq '.push_intent=true' "$SESS" >"$SESS.t" && mv "$SESS.t" "$SESS"
sb_site_session_sync_vloops_from_state
assert_eq "sync: push intent makes publish required" "true" "$(jq -r '.steps[]|select(.id=="publish").required' "$VL")"

# --- visual evidence / pending audit -------------------------------------
reset
VE="$(sb_site_session_visual_evidence_file)"
assert_eq "visual valid: missing" 1 "$(rc sb_site_session_visual_evidence_valid)"
sb_site_session_mark_visual_evidence "shot.png"
assert_eq "mark_visual_evidence records path" "shot.png" "$(jq -r '.paths[0]' "$VE")"
assert_eq "mark_visual_evidence records viewport" "1280" "$(jq -r .viewport "$VE")"
assert_eq "mark_visual_evidence marks vloop visual" "done" "$(jq -r '.steps[]|select(.id=="visual").status' "$VL")"
assert_eq "visual valid: good" 0 "$(rc sb_site_session_visual_evidence_valid)"
echo '{"paths":[],"captured_at":"t"}' >"$VE"
assert_eq "visual valid: empty paths" 1 "$(rc sb_site_session_visual_evidence_valid)"
rm -f "$VE"; ln -s "$TL_TMP/real-ev.json" "$VE"
assert_eq "visual valid: symlink refused" 1 "$(rc sb_site_session_visual_evidence_valid)"
rm -f "$VE"

reset
assert_eq "pending audit: none" 1 "$(rc sb_site_session_pending_completion_audit)"
sb_site_session_mark_pending_completion_audit "$(printf 'x%.0s' $(seq 1 400))"
assert_eq "pending audit: marked" 0 "$(rc sb_site_session_pending_completion_audit)"
assert_eq "pending audit: preview truncated to 300" 300 "$(jq -r '.task_preview|length' "$(sb_site_session_pending_audit_file)")"
sb_site_session_clear_pending_completion_audit
assert_eq "pending audit: cleared" 1 "$(rc sb_site_session_pending_completion_audit)"
PA="$(sb_site_session_pending_audit_file)"
ln -s "$TL_TMP/real-ev.json" "$PA"
assert_eq "pending audit: symlink refused" 1 "$(rc sb_site_session_pending_completion_audit)"
rm -f "$PA"

# --- clear_all ------------------------------------------------------------
echo '{}' >"$SESS"; echo '{}' >"$VL"; echo '{}' >"$EV"
sb_site_session_clear_all
assert_file_absent "clear_all removes session" "$SESS"
assert_file_absent "clear_all removes vloops" "$VL"
assert_file_absent "clear_all removes live evidence" "$EV"

# --- fault injection: unusable state dir, invalid state JSON, failing rm ----
reset
BROKEN="$TL_TMP/blocker/sub"
(
  export SB_RUNTIME_STATE_DIR="$BROKEN"
  sb_site_session_touch "x"
  sb_site_session_mark_push_intent
  sb_site_session_init_vloops
  sb_site_session_mark_visual_evidence "p"
  sb_site_session_mark_pending_completion_audit "p"
  sb_site_session_record_subagent_spawn "site/a.html"
) >/dev/null 2>&1 || true
assert_file_absent "broken state dir: nothing created" "$BROKEN"
assert_eq "broken state dir: touch still returns 0" 0 "$(SB_RUNTIME_STATE_DIR="$BROKEN" rc sb_site_session_touch x)"
assert_eq "broken state dir: push intent returns 0" 0 "$(SB_RUNTIME_STATE_DIR="$BROKEN" rc sb_site_session_mark_push_intent)"

echo 'not json' >"$SESS"
assert_eq "has_site_work: unparsable state is not site work" 1 "$(rc sb_site_session_has_site_work)"
assert_eq "regression_current: unparsable state false" 1 "$(rc sb_site_session_regression_current)"
echo 'not json' >"$(sb_site_session_vloop_file)"
assert_eq "vloop_pending_summary: unparsable file prints nothing" "" "$(sb_site_session_vloop_pending_summary)"
reset

echo '{}' >"$SESS"; echo '{}' >"$(sb_site_session_vloop_file)"
echo '{}' >"$(sb_site_session_live_evidence_file)"; echo '{}' >"$(sb_site_session_visual_evidence_file)"
echo '{"pending":true}' >"$(sb_site_session_pending_audit_file)"
assert_eq "live evidence: jq missing with file present" 1 "$(PATH="$NOJQ" rc sb_live_publish_evidence_valid)"
assert_eq "visual valid: jq missing with file present" 1 "$(PATH="$NOJQ" rc sb_site_session_visual_evidence_valid)"
assert_eq "pending audit: jq missing with file present" 1 "$(PATH="$NOJQ" rc sb_site_session_pending_completion_audit)"
assert_eq "vloop_pending: jq missing with file present" 1 "$(PATH="$NOJQ" rc sb_site_session_vloop_pending)"
mkdir -p "$TL_TMP/failbin"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/failbin/rm"; chmod +x "$TL_TMP/failbin/rm"
assert_eq "clear_all tolerates rm failure" 0 "$(PATH="$TL_TMP/failbin:$PATH" rc sb_site_session_clear_all)"
assert_eq "clear_subagent_log tolerates rm failure" 0 "$(PATH="$TL_TMP/failbin:$PATH" rc sb_site_session_clear_subagent_log)"
assert_eq "clear_pending_audit tolerates rm failure" 0 "$(PATH="$TL_TMP/failbin:$PATH" rc sb_site_session_clear_pending_completion_audit)"
mkdir -p "$(sb_site_session_subagent_log)"
assert_eq "record_spawn: unwritable log tolerated" 0 "$(rc sb_site_session_record_subagent_spawn "plain text")"
rmdir "$(sb_site_session_subagent_log)"
reset

# --- preview health -------------------------------------------------------
tl_stub curl 'echo -n 200'
assert_eq "preview healthy: curl 200" 0 "$(rc sb_site_preview_healthy)"
tl_stub curl 'echo -n 500'
assert_eq "preview healthy: curl 500" 1 "$(rc sb_site_preview_healthy)"
tl_stub curl 'exit 7'
assert_eq "preview healthy: curl failure" 1 "$(rc sb_site_preview_healthy)"
rm -f "$TL_BIN/curl"
NOCURL="$(tl_path_without curl lsof)"
assert_eq "preview healthy: no curl, no lsof" 1 "$(PATH="$NOCURL" rc sb_site_preview_healthy)"
mkdir -p "$TL_TMP/lsofbin"
printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/lsofbin/lsof"; chmod +x "$TL_TMP/lsofbin/lsof"
assert_eq "preview healthy: lsof listening" 0 "$(PATH="$TL_TMP/lsofbin:$NOCURL" rc sb_site_preview_healthy)"
printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/lsofbin/lsof"
assert_eq "preview healthy: lsof not listening" 1 "$(PATH="$TL_TMP/lsofbin:$NOCURL" rc sb_site_preview_healthy)"

tl_results

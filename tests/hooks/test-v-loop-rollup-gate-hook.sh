#!/usr/bin/env bash
# End-to-end tests for hooks/v-loop-rollup-gate.sh (Stop: site-session V-loop rollup).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/v-loop-rollup-gate.sh
export SB_RUNTIME_PRESERVE_STATE_DIR=1
ST="$SB_RUNTIME_STATE_DIR"
SITE="$ST/site-session.json"
VLOOPS="$ST/site-vloops.json"
P="$TL_TMP/proj"
dg_project "$P" '{"sb_initiated":true,"site_profile":{"enabled":true,"dir":"site","live_url":"https://site.example/"}}'
rm -rf "$P/.git"
git -C "$P" init -q -b main
git -C "$P" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
P_REAL="$(cd "$P" && pwd -P)"
HEAD_SHA="$(git -C "$P" rev-parse HEAD)"
mkdir -p "$P/sub" "$TL_TMP/outside"
shot="$TL_TMP/shot.png"
printf 'png' >"$shot"
stop_json() { jq -cn --arg e "${1:-Stop}" '{hook_event_name:$e}'; }
blocked() { jq -r '.decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo bad; }
session() { # [json to merge]
  local extra="${1:-}"
  [[ -n "$extra" ]] || extra='{}'
  jq -n --arg sc "$P_REAL|main" --argjson x "$extra" '{active:true,scope:$sc,edit_seq:1,regression_passed_seq:0,touch_reason:"edit:site/index.html"} + $x' >"$SITE"
}
reset() { rm -f "$SITE" "$VLOOPS" "$ST/live-publish-evidence.json" "$ST/site-visual-evidence.json" "$ST/agent-delegation-active.json" "$ST/trivial" "$ST/orchestrator-worker-active.json"; }
evidence() { jq -n --arg r "$P_REAL" --arg p "$shot" --argjson e 1 '{captured_at:"t",project:$r,edit_seq:$e,paths:[$p]}' >"$ST/site-visual-evidence.json"; }
live() { jq -n --arg sha "$HEAD_SHA" --arg r "$P_REAL" --argjson e "$(date +%s)" '{status:"LIVE",commit_sha:$sha,project:$r,urls:["u"],markers_matched:["m"],verified_at:"t",verified_epoch:$e}' >"$ST/live-publish-evidence.json"; }
step() { jq -r --arg id "$1" '.steps[]|select(.id==$id)|.status' "$VLOOPS"; }

echo "=== early exits ==="
reset; session
dg_run_nojq "$P" "$H" "$(stop_json)"
assert_eq "no jq: silent" "0|" "$TL_STATUS|$TL_OUT"
dg_run "$P" "$H" "$(stop_json PostToolUse)"
assert_eq "non-Stop event: silent" "0|" "$TL_STATUS|$TL_OUT"
dg_run "$TL_TMP/outside" "$H" "$(stop_json)"
assert_eq "outside an SB project: silent" "0|" "$TL_STATUS|$TL_OUT"
dg_run_nolib "$H" "$(stop_json)"
assert_eq "plugin without its libs: fails open" "0|" "$TL_STATUS|$TL_OUT"
dg_run_gate_missing "$P" "$H" "$(stop_json)"
assert_eq "refusing project gate: silent" "0|" "$TL_STATUS|$TL_OUT"
# R9-05: a Stop is always the parent's; a fresh spawn record or a worker env must not skip the gate.
dg_run "$P" "$H" "$(stop_json)" SB_ORCHESTRATOR_WORKER=1
assert_contains "Stop with a worker env still gated (R9-05)" "$TL_OUT" '"decision":"block"'
printf '{"spawned_at":"%s"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$ST/orchestrator-worker-active.json"
dg_run "$P" "$H" "$(stop_json)"
assert_contains "Stop with a fresh spawn marker still gated (R9-05)" "$TL_OUT" '"decision":"block"'
rm -f "$ST/orchestrator-worker-active.json"
: >"$ST/trivial"
dg_run "$P" "$H" "$(stop_json)"
assert_eq "legacy trivial marker bypasses the gate" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$ST/trivial"

echo "=== the gate only applies to genuine site sessions of a profile project ==="
reset
dg_run "$P" "$H" "$(stop_json)"
assert_eq "no site session: silent" "0|" "$TL_STATUS|$TL_OUT"
session '{"edit_seq":0}'
dg_run "$P" "$H" "$(stop_json)"
assert_eq "active session without site edits: silent" "0|" "$TL_STATUS|$TL_OUT"
session
jq '.scope="/other|main"' "$SITE" >"$ST/s.t" && mv "$ST/s.t" "$SITE"
dg_run "$P" "$H" "$(stop_json)"
assert_eq "a session left by another project: silent (R9-08)" "0|" "$TL_STATUS|$TL_OUT"
session
jq -n '{active:true,host:"codex",task_id:"T1",work_dir:"/x",ownership_scope:[]}' >"$ST/agent-delegation-active.json"
dg_run "$P" "$H" "$(stop_json)"
assert_eq "an active agent delegation does not switch the gate off (R9-04)" block "$(blocked)"
rm -f "$ST/agent-delegation-active.json"
dg_project "$TL_TMP/plain" '{"sb_initiated":true}'
git -C "$TL_TMP/plain" init -q 2>/dev/null || true
dg_run "$TL_TMP/plain" "$H" "$(stop_json)"
assert_eq "a project without a site_profile: silent (R9-02)" "0|" "$TL_STATUS|$TL_OUT"

echo "=== pending V-loops block Stop ==="
session
dg_run "$P" "$H" "$(stop_json)"
assert_eq "incomplete V-loops: block" block "$(blocked)"
reason="$(jq -r .reason <<<"$TL_OUT")"
assert_contains "block names the gate" "$reason" "Site V-loop rollup gate"
assert_contains "block lists incomplete steps" "$reason" "Site V-loop rollup — incomplete steps:"
assert_contains "block lists the preflight step" "$reason" "(preflight): pending"
assert_contains "block explains how to proceed" "$reason" "Complete sb:content batch steps"
dg_run "$P" "$H" '{}'
assert_eq "an empty event name defaults to Stop" block "$(blocked)"
dg_run "$P" "$H" 'not json'
assert_eq "invalid JSON defaults to Stop" block "$(blocked)"
dg_run "$P/sub" "$H" "$(stop_json)"
assert_eq "gate resolves the project from a subdirectory" block "$(blocked)"
dg_run "$P" "$H" '{"hook_event_name":"Stop","stop_hook_active":true}'
assert_eq "a Stop already continuing because of a Stop hook is released (R9-03)" "0|" "$TL_STATUS|$TL_OUT"
assert_contains "the release is audited" "$(cat "$ST/stop-loop-release.log")" "v-loop-rollup-gate"
rm -f "$ST/stop-loop-release.log"

echo "=== rollup is derived from the evidence, never remembered ==="
session '{"regression_passed_seq":1}'
dg_run "$P" "$H" "$(stop_json)"
assert_eq "regression done, visual missing: block" block "$(blocked)"
assert_contains "remaining step named" "$(jq -r .reason <<<"$TL_OUT")" "(visual): pending"
assert_not_contains "completed steps are not listed" "$(jq -r .reason <<<"$TL_OUT")" "(preflight)"
evidence
dg_run "$P" "$H" "$(stop_json)"
assert_eq "all required steps done (publish optional): allowed" "0|" "$TL_STATUS|$TL_OUT"
session '{"regression_passed_seq":1,"edit_seq":2}'
dg_run "$P" "$H" "$(stop_json)"
assert_eq "a later edit un-does the regression and visual steps (R9-08)" block "$(blocked)"
assert_eq "the visual step is pending again, not remembered" pending "$(step visual)"
session '{"regression_passed_seq":1,"push_intent":true}'
dg_run "$P" "$H" "$(stop_json)"
assert_eq "push intent makes the publish step required" block "$(blocked)"
assert_contains "publish step named" "$(jq -r .reason <<<"$TL_OUT")" "(publish): pending"
live
dg_run "$P" "$H" "$(stop_json)"
assert_eq "publish done by valid live evidence: allowed" "0|" "$TL_STATUS|$TL_OUT"
rm -f "$VLOOPS"
dg_run "$P" "$H" "$(stop_json)"
assert_eq "a missing V-loop file is rebuilt from the evidence" "0|" "$TL_STATUS|$TL_OUT"
assert_eq "implement step derived from the active session" "done" "$(step implement)"

echo "=== sync failures do not break Stop ==="
session '{"push_intent":true}'
printf 'garbage' >"$VLOOPS"
dg_run "$P" "$H" "$(stop_json)"
assert_eq "corrupt V-loop file is rebuilt, the gate still decides" block "$(blocked)"

session '{"push_intent":true}'
rm -f "$VLOOPS"; mkdir "$VLOOPS"
dg_run "$P" "$H" "$(stop_json)"
assert_eq "an unusable V-loop file fails open" "0|" "$TL_STATUS|$TL_OUT"
rmdir "$VLOOPS"

echo "=== unreadable stdin ==="
dg_run_closed_stdin "$P" "$H"
assert_eq "stdin that cannot be read yields no event name: block or silent without crashing" 0 "$TL_STATUS"

tl_results

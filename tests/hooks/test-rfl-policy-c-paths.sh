#!/usr/bin/env bash
# Path coverage for hooks/rfl-policy-c-gate.sh and hooks/lib/rfl-policy-c-assert.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/scripts" "$P/.planning/rfl-1" "$TL_TMP/outside" "$P/sub"
echo '{"status": "active"}' >"$P/.planning/rfl-1/LADDER-STATUS.json"
# Stub resolver: echoes $PC_JSON and records its argv.
cat >"$P/scripts/review-fix-ladder.py" <<'PY'
import os, sys
open(os.environ.get("PC_ARGV", "/dev/null"), "w").write(" ".join(sys.argv[1:]))
sys.stdout.write(os.environ.get("PC_JSON", ""))
PY
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // .decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
NOJQ="$(tl_path_without jq)"

# ======================= lib: assert =======================================
# shellcheck source=../../hooks/lib/rfl-policy-c-assert.sh
source "$TL_REPO_ROOT/hooks/lib/rfl-policy-c-assert.sh"
assert_eq "gate flag default on" 1 "$(rc sb_rfl_policy_c_gate_disabled)"
assert_eq "gate flag off" 0 "$(SB_RFL_POLICY_C_GATE=0 rc sb_rfl_policy_c_gate_disabled)"
assert_eq "resolver: project copy preferred" "$P/scripts/review-fix-ladder.py" "$(sb_rfl_policy_c_resolver "$P")"
assert_match "resolver: falls back to the bundled script" 'scripts/review-fix-ladder\.py$' "$(sb_rfl_policy_c_resolver "$TL_TMP/outside")"
assert_match "resolver: empty root falls back too" 'scripts/review-fix-ladder\.py$' "$(sb_rfl_policy_c_resolver "")"
S1="$TL_TMP/s1"; mkdir -p "$S1/hooks/lib"; cp "$TL_REPO_ROOT/hooks/lib/rfl-policy-c-assert.sh" "$S1/hooks/lib/"
assert_eq "resolver: none available" 1 "$(bash -c 'source "$0"; sb_rfl_policy_c_resolver "$1" >/dev/null; echo $?' "$S1/hooks/lib/rfl-policy-c-assert.sh" "$TL_TMP/outside")"
assert_eq "run_assert: no resolver => allow" 0 "$(bash -c 'source "$0"; sb_rfl_policy_c_run_assert "$1" task x >/dev/null; echo $?' "$S1/hooks/lib/rfl-policy-c-assert.sh" "$TL_TMP/outside")"
S2="$TL_TMP/s2"; mkdir -p "$S2/hooks/lib"; cp "$TL_REPO_ROOT/hooks/lib/rfl-policy-c-assert.sh" "$S2/hooks/lib/"
assert_eq "resolver: hook dir unresolvable" 1 "$(bash -c 'cd() { return 1; }; source "$0"; sb_rfl_policy_c_resolver "" >/dev/null; echo $?' "$S2/hooks/lib/rfl-policy-c-assert.sh")"

assert_eq "active run: yes" 0 "$(rc sb_rfl_policy_c_has_active_run "$P")"
assert_eq "active run: empty root" 1 "$(rc sb_rfl_policy_c_has_active_run "")"
assert_eq "active run: no .planning" 1 "$(rc sb_rfl_policy_c_has_active_run "$TL_TMP/outside")"
echo '{"status": "completed"}' >"$P/.planning/rfl-1/LADDER-STATUS.json"
assert_eq "active run: completed ladder" 1 "$(rc sb_rfl_policy_c_has_active_run "$P")"
mkdir -p "$P/.planning/rfl-2"; echo '{"status":"active"}' >"$P/.planning/rfl-2/LADDER-STATUS.json"
assert_eq "active run: second ladder active" 0 "$(rc sb_rfl_policy_c_has_active_run "$P")"
rm -rf "$P/.planning/rfl-2"; echo '{"status": "active"}' >"$P/.planning/rfl-1/LADDER-STATUS.json"

for c in "verify_2 now:verify_2" "VERIFY-2:verify_2" "run verify_1:verify_1" "verify-1:verify_1" "go to next rung:next_rung_review" "n+1_review:next_rung_review" "mark-ladder-status x:mark_completed" "mark_ladder_status:mark_completed" "other thing:task"; do
  assert_eq "infer '${c%%:*}'" "${c##*:}" "$(sb_rfl_policy_c_infer_action PreToolUse "${c%%:*}")"
done
assert_eq "infer: Stop event default" stop "$(sb_rfl_policy_c_infer_action Stop "nothing")"
assert_eq "infer: stop event (lowercase) default" stop "$(sb_rfl_policy_c_infer_action stop "nothing")"

export PC_ARGV="$TL_TMP/argv"
PC_JSON='{"ok": true}' sb_rfl_policy_c_run_assert "$P" verify_1 "the prompt" >/dev/null
assert_eq "run_assert: ok => allow" 0 "$(PC_JSON='{"ok": true}' rc sb_rfl_policy_c_run_assert "$P" verify_1 "the prompt")"
assert_eq "run_assert: resolver args" "--assert-rfl-advance --project-root $P --next-action verify_1 --prompt the prompt" "$(cat "$PC_ARGV")"
out="$(PC_JSON='{"ok": false, "errors": ["a","b"]}' sb_rfl_policy_c_run_assert "$P" task p || echo "rc=$?")"
assert_contains "run_assert: failure prints JSON" "$out" '"errors"'
assert_contains "run_assert: failure status 1" "$out" "rc=1"
assert_eq "run_assert: empty resolver output => allow" 0 "$(PC_JSON='' rc sb_rfl_policy_c_run_assert "$P" task p)"
assert_eq "run_assert: no python3 => allow" 0 "$(PATH="$(tl_path_without python3)" PC_JSON='{"ok":false}' rc sb_rfl_policy_c_run_assert "$P" task p)"
assert_eq "run_assert(no jq): ok json allows" 0 "$(PATH="$NOJQ" PC_JSON='{"ok": true}' rc sb_rfl_policy_c_run_assert "$P" task p)"
assert_eq "run_assert(no jq): failing json rejected" 1 "$(PATH="$NOJQ" PC_JSON='{"ok": false}' rc sb_rfl_policy_c_run_assert "$P" task p)"
assert_eq "reason: joined errors" "RFL Policy C / failure-management gate: a; b" "$(sb_rfl_policy_c_reason_from_json '{"errors":["a","b"]}')"
assert_contains "reason: unparsable JSON => generic text" "$(sb_rfl_policy_c_reason_from_json 'not json')" "gate failed. Write POLICY-C"
assert_contains "reason: no jq => generic text" "$(PATH="$NOJQ" sb_rfl_policy_c_reason_from_json '{"errors":["a"]}')" "gate failed. Write POLICY-C"

# ======================= hook: rfl-policy-c-gate.sh ===========================
H=hooks/rfl-policy-c-gate.sh
bash_in() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
FAIL='{"ok": false, "errors": ["POLICY-C missing"]}'
run() { dg_run "$P" "$H" "$1" PC_JSON="$FAIL" PC_ARGV="$TL_TMP/hargv" "${@:2}"; }

run "$(bash_in 'bash scripts/mark-ladder-status completed')" SB_RFL_POLICY_C_GATE=0
assert_eq "gate disabled by env" "" "$TL_OUT"
dg_assert_ok "gate disabled by env: exits 0"
dg_run_nojq "$P" "$H" "$(bash_in 'mark-ladder-status x')" PC_JSON="$FAIL"
assert_eq "no jq: inert" "" "$TL_OUT"
dg_assert_ok "no jq: inert: exits 0"
run ""
assert_eq "empty input: inert" "" "$TL_OUT"
dg_assert_ok "empty input: inert: exits 0"
dg_run "$TL_TMP/outside" "$H" "$(bash_in 'mark-ladder-status x')" PC_JSON="$FAIL"
assert_eq "outside an SB project: inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project: inert: exits 0"
dg_run_nolib_in "$P" "$H" "$(bash_in 'mark-ladder-status x')" PC_JSON="$FAIL"
assert_eq "no libs: inert (no project resolution)" "" "$TL_OUT"
dg_assert_ok "no libs: inert (no project resolution): exits 0"
dg_run_gate_missing "$P" "$H" "$(bash_in 'mark-ladder-status x')" PC_JSON="$FAIL"
assert_eq "project gate function unavailable: walk-resolved project still gated" "deny" "$(dec)"
S0="$TL_TMP/s0"; dg_stage_hooks "$S0" project-active.sh
dg_run_with_fn "$P" "$S0/hooks/rfl-policy-c-gate.sh" "$(bash_in 'mark-ladder-status x')" 'sb_project_gate_or_exit() { return 1; }; export -f sb_project_gate_or_exit' PC_JSON="$FAIL"
assert_eq "project gate reporting inactive: fails open" "" "$TL_OUT"
dg_assert_ok "project gate reporting inactive: fails open: exits 0"

run "$(bash_in 'bash scripts/mark-ladder-status completed')"
assert_eq "Bash advance without POLICY-C denied" "deny" "$(dec)"
assert_contains "deny reason carries resolver errors" "$TL_OUT" "POLICY-C missing"
dg_run "$P/sub" "$H" "$(bash_in 'verify_2 run')" PC_JSON="$FAIL" PC_ARGV="$TL_TMP/hargv"
assert_eq "gate works from a sub-directory" "deny" "$(dec)"
assert_eq "action inferred from command" "--assert-rfl-advance --project-root $P --next-action verify_2 --prompt verify_2 run" "$(cat "$TL_TMP/hargv")"
run "$(bash_in 'ls -la')"
assert_eq "unrelated Bash command ignored" "" "$TL_OUT"
dg_assert_ok "unrelated Bash command ignored: exits 0"
run "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Task",tool_input:{prompt:"Run verify_1 for the ladder"}}')"
assert_eq "Task prompt gated" "deny" "$(dec)"
run "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:"sb:review",args:"next rung"}}')"
assert_eq "Skill invocation gated" "deny" "$(dec)"
assert_eq "skill + args forwarded as prompt" "--assert-rfl-advance --project-root $P --next-action next_rung_review --prompt sb:review next rung" "$(cat "$TL_TMP/hargv")"
run "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{}}')"
assert_eq "other PreToolUse tools ignored" "" "$TL_OUT"
dg_assert_ok "other PreToolUse tools ignored: exits 0"
run "$(jq -cn '{hook_event_name:"Stop",tool_name:"Read"}')"
assert_eq "Stop evaluated: block decision" "block" "$(dec)"
run "$(jq -cn '{hookEventName:"stop"}')"
assert_eq "camelCase lowercase stop evaluated" "block" "$(dec)"
run "$(bash_in 'verify_1')" PC_JSON='{"ok": true}'
assert_eq "passing assert allows" "" "$TL_OUT"
dg_assert_ok "passing assert allows: exits 0"
run "$(bash_in 'verify_1')" SB_ORCHESTRATOR_PARENT=0
assert_eq "worker sessions exempt" "" "$TL_OUT"
dg_assert_ok "worker sessions exempt: exits 0"
echo '{"status":"completed"}' >"$P/.planning/rfl-1/LADDER-STATUS.json"
run "$(bash_in 'verify_1')"
assert_eq "no active ladder: allow" "" "$TL_OUT"
dg_assert_ok "no active ladder: allow: exits 0"
echo '{"status": "active"}' >"$P/.planning/rfl-1/LADDER-STATUS.json"
run "not json"
assert_eq "unparsable input defaults to PreToolUse with no tool: ignored" "" "$TL_OUT"
dg_assert_ok "unparsable input defaults to PreToolUse with no tool: ignored: exits 0"
dg_run_closed_stdin "$P" "$H"
assert_eq "unreadable stdin: inert" "" "$TL_OUT"
dg_assert_ok "unreadable stdin: inert: exits 0"
for t in Task Skill Bash; do
  run "$(jq -cn --arg t "$t" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:"oops"}')"
  assert_eq "$t with a non-object tool_input does not crash the gate" 0 "$TL_STATUS"
done
S3="$TL_TMP/s3"; dg_stage_hooks "$S3" hook-audit.sh
dg_run "$P" "$S3/hooks/rfl-policy-c-gate.sh" "$(bash_in 'verify_1')" PC_JSON="$FAIL"
assert_eq "no audit lib: still denies" "deny" "$(dec)"
dg_run "$P" "$H" "$(bash_in 'verify_1')" PC_JSON="$FAIL" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "bridge env does not change the deny" "deny" "$(dec)"

tl_results

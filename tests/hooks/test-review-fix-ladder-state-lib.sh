#!/usr/bin/env bash
# Unit tests for hooks/lib/review-fix-ladder-state.sh (ladder state machine).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/hooks/lib/sb-project-gate.sh"
# shellcheck source=../../hooks/lib/review-fix-ladder-state.sh
source "$TL_REPO_ROOT/hooks/lib/review-fix-ladder-state.sh"

export SB_RUNTIME_STATE_DIR="$TL_TMP/state"; mkdir -p "$SB_RUNTIME_STATE_DIR"
SF="$(sb_rfl_state_file)"
P="$TL_TMP/proj"; mkdir -p "$P/scripts"
export SB_RFL_PROJECT_ROOT="$P"
RES="$P/scripts/review-fix-ladder.py"
cat >"$RES" <<'PY'
import os, sys
sys.stdout.write(os.environ.get("RFL_JSON", '{"total_rungs":3,"rungs":[{"subagent_name":"sb-gpt-5","model_param":"gpt-x"},{"subagent_name":"","model_param":"m2"},{}]}'))
PY
NOJQ="$(tl_path_without jq)"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
f() { jq -r --arg k "$1" '.[$k]' "$SF"; }
st() { # json
  printf '%s\n' "$1" >"$SF"
}
base='"active":true,"rung":1,"total_rungs":3,"phase":"review","rung_model":"m1","host_model":"h1","pm_filed":false,"compliance_stop":false'

# --- basics -----------------------------------------------------------------
assert_eq "state file path" "$SB_RUNTIME_STATE_DIR/review-fix-ladder-state.json" "$SF"
assert_eq "guard enabled by default" 1 "$(rc sb_rfl_guard_disabled)"
assert_eq "guard disabled by env" 0 "$(SB_REVIEW_FIX_LADDER_GUARD=0 rc sb_rfl_guard_disabled)"
rm -f "$SF"
assert_eq "active: no state" 1 "$(rc sb_rfl_is_active)"
st '{"active":false}'; assert_eq "active: false flag" 1 "$(rc sb_rfl_is_active)"
st '{"active":true}'; assert_eq "active: true flag" 0 "$(rc sb_rfl_is_active)"
assert_eq "active: guard disabled wins" 1 "$(SB_REVIEW_FIX_LADDER_GUARD=0 rc sb_rfl_is_active)"
assert_eq "active (no jq): grep fallback true" 0 "$(PATH="$NOJQ" rc sb_rfl_is_active)"
st '{"active":false}'; assert_eq "active (no jq): grep fallback false" 1 "$(PATH="$NOJQ" rc sb_rfl_is_active)"

st '{"phase":"triage","n":0}'
assert_eq "read_field: value" triage "$(sb_rfl_read_field phase x)"
assert_eq "read_field: default for missing key" dflt "$(sb_rfl_read_field nothing dflt)"
assert_eq "read_field: empty field name" dflt "$(sb_rfl_read_field "" dflt)"
assert_eq "read_field: no jq returns default" dflt "$(PATH="$NOJQ" sb_rfl_read_field phase dflt)"
echo 'not json' >"$SF"; assert_eq "read_field: unparsable state returns default" dflt "$(sb_rfl_read_field phase dflt)"
rm -f "$SF"; assert_eq "read_field: no state returns default" dflt "$(sb_rfl_read_field phase dflt)"

SB_RUNTIME_STATE_DIR="$TL_TMP/other/deep" sb_rfl_write_state '{"a":1}'
assert_eq "write_state creates the directory" '{"a":1}' "$(cat "$TL_TMP/other/deep/review-fix-ladder-state.json")"

# --- project root / resolver ---------------------------------------------------
assert_eq "project_root: env override" "$P" "$(sb_rfl_project_root)"
unset SB_RFL_PROJECT_ROOT
dg_pr="$TL_TMP/walkproj"; mkdir -p "$dg_pr/.git" "$dg_pr/sub"; echo '{}' >"$dg_pr/.silver-bullet.json"; echo x >"$dg_pr/silver-bullet.md"
assert_eq "project_root: found by walking up" "$dg_pr" "$(cd "$dg_pr/sub" && sb_rfl_project_root)"
plain="$TL_TMP/plainwd"; mkdir -p "$plain"
assert_eq "project_root: falls back to PWD" "$plain" "$(cd "$plain" && sb_rfl_project_root)"
export SB_RFL_PROJECT_ROOT="$P"
assert_eq "resolver_json: defaults root from env" '{"total_rungs":3' "$(sb_rfl_resolver_json | cut -c1-16)"
assert_eq "resolver_json: explicit root" '{"total_rungs":3' "$(sb_rfl_resolver_json "$P" | cut -c1-16)"
assert_eq "resolver_json: missing resolver => {} and status 1" "{}|1" "$(r=0; o="$(sb_rfl_resolver_json "$TL_TMP/nowhere")" || r=$?; echo "$o|$r")"
cp "$RES" "$RES.bak"; printf 'import sys\nsys.exit(2)\n' >"$RES"
assert_eq "resolver_json: failing resolver => {}" "{}" "$(sb_rfl_resolver_json "$P")"
mv "$RES.bak" "$RES"
assert_eq "total_rungs: from field" 3 "$(sb_rfl_total_rungs_from_resolver '{"total_rungs":3}')"
assert_eq "total_rungs: from rungs length" 2 "$(sb_rfl_total_rungs_from_resolver '{"rungs":[1,2]}')"
assert_eq "total_rungs: default" 6 "$(sb_rfl_total_rungs_from_resolver '{}')"
assert_eq "total_rungs (no jq)" 6 "$(PATH="$NOJQ" sb_rfl_total_rungs_from_resolver '{"total_rungs":3}')"
assert_eq "rung_from_resolver: by index" '{"a":2}' "$(sb_rfl_rung_from_resolver '{"rungs":[{"a":1},{"a":2}]}' 2)"
assert_eq "rung_from_resolver: default index 1" '{"a":1}' "$(sb_rfl_rung_from_resolver '{"rungs":[{"a":1}]}')"
assert_eq "rung_from_resolver: out of range" '{}' "$(sb_rfl_rung_from_resolver '{"rungs":[]}' 3)"
assert_eq "rung_from_resolver (no jq)" '{}' "$(PATH="$NOJQ" sb_rfl_rung_from_resolver '{"rungs":[{"a":1}]}' 1)"

# --- project without scripts/review-fix-ladder.py (every downstream SB project) ---
NP="$TL_TMP/noresolver"; mkdir -p "$NP"
rm -f "$SF"
# hooks run under `set -e`; an `||` list would mask the abort, so use a separate errexit shell
out="$(SB_RFL_PROJECT_ROOT="$NP" bash -c 'set -e; source "$0"; sb_rfl_activate; echo reached-end' "$TL_REPO_ROOT/hooks/lib/review-fix-ladder-state.sh" 2>/dev/null || true)"
assert_eq "activate without a resolver survives errexit" reached-end "$out"
out="$(SB_RFL_PROJECT_ROOT="$NP" bash -c 'set -e; source "$0"; sb_rfl_sync_rung_metadata 1; echo reached-end' "$TL_REPO_ROOT/hooks/lib/review-fix-ladder-state.sh" 2>/dev/null || true)"
assert_eq "sync_rung_metadata without a resolver survives errexit" reached-end "$out"
rm -f "$SF"
r=0; SB_RFL_PROJECT_ROOT="$NP" sb_rfl_activate || r=$?
assert_eq "activate without a resolver succeeds" 0 "$r"
assert_eq "activate without a resolver writes active state" true "$(f active)"
assert_eq "activate without a resolver defaults to 6 rungs" 6 "$(f total_rungs)"
r=0; SB_RFL_PROJECT_ROOT="$NP" sb_rfl_advance_rung || r=$?
assert_eq "advance without a resolver returns 0" 0 "$r"
assert_eq "advance without a resolver moves to rung 2" 2 "$(f rung)"
r=0; SB_RFL_PROJECT_ROOT="$NP" sb_rfl_sync_rung_metadata 1 || r=$?
assert_eq "sync_rung_metadata with an empty rung returns 0" 0 "$r"
st "{$base}"
r=0; sb_rfl_sync_rung_metadata 3 || r=$?
assert_eq "sync_rung_metadata with a rung lacking subagent/model returns 0" 0 "$r"
r=0; st "{$base,\"grep_after_verify\":1}"; sb_rfl_mark_orchestrator_grep || r=$?
assert_eq "mark_orchestrator_grep advancing the rung returns 0" 0 "$r"

# --- activate / deactivate / reset ---------------------------------------------
rm -f "$SF"; sb_rfl_activate
assert_eq "activate: active" true "$(f active)"
assert_eq "activate: total rungs from resolver" 3 "$(f total_rungs)"
assert_eq "activate: subagent from rung 1" sb-gpt-5 "$(f subagent_name)"
assert_eq "activate: rung model from resolver" gpt-x "$(f rung_model)"
assert_eq "activate: default host model" composer-2.5 "$(f host_model)"
assert_eq "activate: phase review" review "$(f phase)"
sb_rfl_activate 2 "" hm
assert_eq "activate: rung 2 has no subagent" null "$(f subagent_name)"
assert_eq "activate: rung 2 model" m2 "$(f rung_model)"
assert_eq "activate: host model argument" hm "$(f host_model)"
sb_rfl_activate 3 "explicit" hm
assert_eq "activate: explicit rung model kept" explicit "$(f rung_model)"
assert_eq "activate: rung 3 model_param null" null "$(f model_param)"
RFL_JSON='{}' sb_rfl_activate 1
assert_eq "activate: unresolvable rung falls back to composer-2.5" composer-2.5 "$(f rung_model)"
assert_eq "activate: default total rungs" 6 "$(f total_rungs)"
PATH="$NOJQ" sb_rfl_activate 2 "" hm
assert_eq "activate (no jq): state written" true "$(f active)"
assert_eq "activate (no jq): default rung model" composer-2.5 "$(f rung_model)"
PATH="$NOJQ" sb_rfl_activate 2 "given" hm
assert_eq "activate (no jq): given rung model" given "$(f rung_model)"
sb_rfl_deactivate; assert_file_absent "deactivate removes state" "$SF"
sb_rfl_deactivate
sb_rfl_reset 2 rm hm
assert_eq "reset: re-activated at rung" 2 "$(f rung)"
assert_eq "reset: explicit rung model" rm "$(f rung_model)"
sb_rfl_reset
assert_eq "reset: defaults to rung 1" 1 "$(f rung)"

# --- set_field / set_bool --------------------------------------------------------
rm -f "$SF"
assert_eq "set_field: no state" 1 "$(rc sb_rfl_set_field k v)"
assert_eq "set_bool: no state" 1 "$(rc sb_rfl_set_bool k true)"
st '{"active":true}'
assert_eq "set_field: no jq" 1 "$(PATH="$NOJQ" rc sb_rfl_set_field k v)"
assert_eq "set_bool: no jq" 1 "$(PATH="$NOJQ" rc sb_rfl_set_bool k true)"
sb_rfl_set_field k v; assert_eq "set_field: stores string" v "$(f k)"
sb_rfl_set_bool b true; assert_eq "set_bool: stores bool" true "$(jq -r .b "$SF")"
assert_eq "set_bool: bad value fails" nonzero "$([[ "$(rc sb_rfl_set_bool b notjson)" -ne 0 ]] && echo nonzero || echo zero)"

# --- sync metadata ------------------------------------------------------------------
st "{$base}"
sb_rfl_sync_rung_metadata 1
assert_eq "sync: subagent" sb-gpt-5 "$(f subagent_name)"
assert_eq "sync: model_param" gpt-x "$(f model_param)"
assert_eq "sync: rung_model" gpt-x "$(f rung_model)"
st "{$base}"; sb_rfl_sync_rung_metadata 3
assert_eq "sync: empty rung leaves fields unset" null "$(f subagent_name)"
assert_eq "sync: no jq no-op" 0 "$(PATH="$NOJQ" rc sb_rfl_sync_rung_metadata 1)"

# --- pm filed / grep marks / advance ----------------------------------------------------
st "{$base,\"phase\":\"file_valid_issues\"}"; sb_rfl_mark_pm_filed
assert_eq "pm_filed: set" true "$(f pm_filed)"; assert_eq "pm_filed: moves to fix_parallel" fix_parallel "$(f phase)"
st "{$base,\"phase\":\"triage\"}"; sb_rfl_mark_pm_filed || true
assert_eq "pm_filed: other phase unchanged" triage "$(f phase)"
st "{$base,\"phase\":\"orchestrator_grep_1\",\"grep_after_verify\":0}"; sb_rfl_mark_orchestrator_grep
assert_eq "grep mark 1: counter" 1 "$(f grep_after_verify)"; assert_eq "grep mark 1: verify_2" verify_2 "$(f phase)"
st "{$base,\"phase\":\"orchestrator_grep_2\",\"grep_after_verify\":1}"; sb_rfl_mark_orchestrator_grep
assert_eq "grep mark 2: next rung" 2 "$(f rung)"; assert_eq "grep mark 2: review phase" review "$(f phase)"
st "{$base,\"grep_after_verify\":2}"; sb_rfl_mark_orchestrator_grep
assert_eq "grep mark 3: ignored" 1 "$(f rung)"
st "{$base,\"rung\":3}"; sb_rfl_advance_rung
assert_file_absent "advance at last rung deactivates" "$SF"
rm -f "$SF"; assert_eq "advance: no state" 1 "$(rc sb_rfl_advance_rung)"
st "{$base}"; assert_eq "advance: no jq" 1 "$(PATH="$NOJQ" rc sb_rfl_advance_rung)"
st "{$base,\"pm_filed\":true,\"verify_pass\":2}"; sb_rfl_advance_rung
assert_eq "advance: rung incremented" 2 "$(f rung)"; assert_eq "advance: pm_filed reset" false "$(f pm_filed)"
assert_eq "advance: metadata synced for the new rung" m2 "$(f model_param)"
st "{$base}"; sb_rfl_compliance_stop "because"
assert_eq "compliance_stop: flag" true "$(f compliance_stop)"; assert_eq "compliance_stop: reason" because "$(f stop_reason)"

# --- prompt analysis ------------------------------------------------------------------------
hint() { sb_rfl_prompt_phase_hint "$1"; }
assert_eq "hint: review (rung_1_review)" review "$(hint 'do rung_1_review now')"
assert_eq "hint: review (raw findings only)" review "$(hint 'RAW FINDINGS ONLY please')"
assert_eq "hint: triage" triage "$(hint 'run /sb:triage')"
assert_eq "hint: triage (classify)" triage "$(hint 'classify them')"
assert_eq "hint: fix" fix "$(hint 'spawn the fix subagent')"
assert_eq "hint: verify_2" verify_2 "$(hint 'second verify pass')"
assert_eq "hint: verify_1" verify_1 "$(hint 'verify-only run')"
assert_eq "hint: unknown" unknown "$(hint 'hello')"
assert_eq "combined verify: yes" 0 "$(rc sb_rfl_prompt_has_combined_verify 'do verify_1 and then verify_2')"
assert_eq "combined verify: no" 1 "$(rc sb_rfl_prompt_has_combined_verify 'just verify_1')"
assert_eq "review+triage mix: both" 0 "$(rc sb_rfl_prompt_has_review_triage_mix 'review-only then sb:triage')"
assert_eq "review+triage mix: review only" 1 "$(rc sb_rfl_prompt_has_review_triage_mix 'review-only')"
assert_eq "review+triage mix: triage only" 1 "$(rc sb_rfl_prompt_has_review_triage_mix 'triage_pass')"
assert_eq "review+triage mix: neither" 1 "$(rc sb_rfl_prompt_has_review_triage_mix 'x')"
assert_eq "subscription-first: gpt" 0 "$(rc sb_rfl_subagent_requires_subscription_first sb-gpt-5)"
assert_eq "subscription-first: opus" 0 "$(rc sb_rfl_subagent_requires_subscription_first sb-opus-1)"
assert_eq "subscription-first: claude" 0 "$(rc sb_rfl_subagent_requires_subscription_first sb-claude-x)"
assert_eq "subscription-first: other" 1 "$(rc sb_rfl_subagent_requires_subscription_first composer)"
assert_eq "pm filing detection: yes" 0 "$(rc sb_rfl_detect_pm_filing_command 'gh issue create -t x')"
assert_eq "pm filing detection: no" 1 "$(rc sb_rfl_detect_pm_filing_command 'ls')"

# --- subscription quota fallback -------------------------------------------------------------
rm -f "$SF"
assert_eq "mark quota: no state" 1 "$(rc sb_rfl_mark_subscription_quota_fallback codex sig)"
assert_eq "clear quota: no state is fine" 0 "$(rc sb_rfl_clear_subscription_quota_fallback)"
st "{$base}"
sb_rfl_mark_subscription_quota_fallback codex "limit hit"
assert_eq "mark quota: flag" true "$(f subscription_quota_fallback)"
assert_eq "mark quota: host" codex "$(f subscription_quota_host)"; assert_eq "mark quota: signal" "limit hit" "$(f subscription_quota_signal)"
st "{$base}"; sb_rfl_mark_subscription_quota_fallback
assert_eq "mark quota: no host/signal recorded" null "$(f subscription_quota_host)"
sb_rfl_mark_subscription_quota_fallback codex sig
sb_rfl_clear_subscription_quota_fallback
assert_eq "clear quota: flag reset" false "$(f subscription_quota_fallback)"; assert_eq "clear quota: host cleared" "" "$(f subscription_quota_host)"
assert_eq "cursor task denied: gpt agent without fallback" 0 "$(rc sb_rfl_subscription_cursor_task_denied sb-gpt-5)"
assert_eq "cursor task denied: other agent" 1 "$(rc sb_rfl_subscription_cursor_task_denied composer)"
sb_rfl_mark_subscription_quota_fallback codex sig
assert_eq "cursor task denied: allowed after quota fallback" 1 "$(rc sb_rfl_subscription_cursor_task_denied sb-gpt-5)"
st "{$base}"
assert_eq "deny unqualified: empty name" 0 "$(rc sb_rfl_deny_unqualified_subscription_task "")"
assert_eq "deny unqualified: allowed agent" 0 "$(rc sb_rfl_deny_unqualified_subscription_task composer)"
o="$(sb_rfl_deny_unqualified_subscription_task sb-opus-1 || echo "rc=$?")"
assert_contains "deny unqualified: message" "$o" "requires subscription-first"; assert_contains "deny unqualified: status 1" "$o" "rc=1"

# --- validate_task_spawn ------------------------------------------------------------------------
v() { RC=0; out="$(sb_rfl_validate_task_spawn "$@")" || RC=$?; }
rm -f "$SF"; v 'x'; assert_eq "validate: inactive ladder allows" 0 "$RC"
st "{$base,\"compliance_stop\":true}"; v 'x'; assert_eq "validate: compliance stop short-circuits" 0 "$RC"
st "{$base}"
v 'verify_1 then verify_2'; assert_eq "validate: combined verify forbidden" 1 "$RC"; assert_contains "msg" "$out" "combined verify"
v 'run /sb:triage'; assert_eq "validate review: triage hint" 1 "$RC"; assert_contains "msg" "$out" "must be review-only"
v 'apply accept fix_pass'; assert_eq "validate review: fix hint" 1 "$RC"
v 'review-only; raw findings; also sb:triage'; assert_eq "validate review: mix" 1 "$RC" ; assert_contains "msg" "$out" "must not triage"
v 'rung_1_review please' m1; assert_eq "validate review: plain review ok" 0 "$RC"
v 'rung_1_review' other; assert_eq "validate review: wrong rung model" 1 "$RC"; assert_contains "msg" "$out" "requires rung model m1"
v 'rung_1_review' m1; assert_eq "validate review: matching model ok" 0 "$RC"
v 'rung_2_review' m1; assert_eq "validate review: parallel rung blocked" 1 "$RC"; assert_contains "msg" "$out" "parallel rung launch blocked"
st "{$base,\"subagent_name\":\"sb-x\"}"
v 'rung_1_review'; assert_eq "validate review: subagent required" 1 "$RC"; assert_contains "msg" "$out" "requires subagent_type sb-x."
v 'rung_1_review' '' '' other; assert_eq "validate review: wrong subagent" 1 "$RC"; assert_contains "msg" "$out" "(got other)"
v 'rung_1_review' wrongmodel '' sb-x; assert_eq "validate review: right subagent skips model check" 0 "$RC"
st "{$base,\"subagent_name\":\"sb-gpt-5\"}"
v 'rung_1_review' '' '' sb-gpt-5; assert_eq "validate review: subscription agent denied before quota" 1 "$RC"; assert_contains "msg" "$out" "subscription-first"
st "{$base,\"phase\":\"triage\"}"
v 'review-only'; assert_eq "validate triage: review-only Task denied" 1 "$RC"; assert_contains "msg" "$out" "do not spawn a review-only"
v 'x' m1; assert_eq "validate triage: rung model instead of host denied" 1 "$RC"; assert_contains "msg" "$out" "host model h1"
v 'x' h1; assert_eq "validate triage: host model ok" 0 "$RC"
st "{$base,\"phase\":\"file_valid_issues\"}"; v 'x'; assert_eq "validate file_valid_issues: no Task" 1 "$RC"
st "{$base,\"phase\":\"fix_parallel\"}"
v 'x'; assert_eq "validate fix_parallel: PM not filed" 1 "$RC"; assert_contains "msg" "$out" "file valid issues"
st "{$base,\"phase\":\"fix_parallel\",\"pm_filed\":true}"
v 'review-only'; assert_eq "validate fix_parallel: review Task denied" 1 "$RC"; v 'rung_1_fix'; assert_eq "validate fix_parallel: fix Task ok" 0 "$RC"
v 'triage_pass'; assert_eq "validate fix_parallel: triage Task denied" 1 "$RC"
for ph in verify_1 verify_2; do
  pr='ladder_pass'; [[ "$ph" == verify_2 ]] && pr='verify_2 pass'
  st "{$base,\"phase\":\"$ph\"}"
  v 'x'; assert_eq "validate $ph: not readonly" 1 "$RC"; assert_contains "msg" "$out" "readonly: true"
  v "$pr" '' true; assert_eq "validate $ph: readonly ok" 0 "$RC"
  v "$pr" '' True; assert_eq "validate $ph: readonly True ok" 0 "$RC"
  st "{$base,\"phase\":\"$ph\",\"subagent_name\":\"sb-x\"}"
  v "$pr" '' true; assert_eq "validate $ph: subagent required" 1 "$RC"
  v "$pr" '' true bad; assert_eq "validate $ph: wrong subagent" 1 "$RC"
  v "$pr" '' true sb-x; assert_eq "validate $ph: right subagent" 0 "$RC"
  st "{$base,\"phase\":\"$ph\",\"subagent_name\":\"sb-gpt-5\"}"
  v "$pr" '' true sb-gpt-5; assert_eq "validate $ph: subscription agent denied" 1 "$RC"
done
st "{$base,\"phase\":\"verify_1\"}"
v 'fix_pass' '' true; assert_eq "validate verify_1: fix hint denied" 1 "$RC"; v 'triage_pass' '' true; assert_eq "validate verify_1: triage hint denied" 1 "$RC"
v 'verify_2' '' true; assert_eq "validate verify_1: verify_2 hint denied" 1 "$RC"
st "{$base,\"phase\":\"verify_2\"}"
v 'fix_pass' '' true; assert_eq "validate verify_2: fix hint denied" 1 "$RC"; v 'verify_1' '' true; assert_eq "validate verify_2: verify_1 hint denied" 1 "$RC"
for ph in orchestrator_grep_1 orchestrator_grep_2; do st "{$base,\"phase\":\"$ph\"}"; v 'x'; assert_eq "validate $ph: no Task" 1 "$RC"; done
st "{$base,\"phase\":\"mystery\"}"; v 'x'; assert_eq "validate: unknown phase allowed" 0 "$RC"

# --- advance_after_task --------------------------------------------------------------------------
adv() { st "{$base,\"phase\":\"$1\",\"subscription_quota_fallback\":true}"; sb_rfl_advance_after_task "$2"; f phase; }
rm -f "$SF"; assert_eq "advance_after_task: inactive" 0 "$(rc sb_rfl_advance_after_task x)"
st "{$base,\"compliance_stop\":true,\"phase\":\"review\"}"; sb_rfl_advance_after_task 'x'; assert_eq "after_task: compliance stop frozen" review "$(f phase)"
assert_eq "after_task: review -> triage" triage "$(adv review 'rung_1_review')"
assert_eq "after_task: review unknown hint -> triage" triage "$(adv review 'hello')"
assert_eq "after_task: review with other hint stays" review "$(adv review 'apply accept fix_pass')"
assert_eq "after_task: quota fallback cleared after review" false "$(f subscription_quota_fallback)"
assert_eq "after_task: triage -> file_valid_issues" file_valid_issues "$(adv triage 'sb:triage')"
assert_eq "after_task: triage wrong hint stays" triage "$(adv triage 'review-only')"
assert_eq "after_task: fix_parallel -> verify_1" verify_1 "$(adv fix_parallel 'rung_1_fix')"
assert_eq "after_task: fix_parallel wrong hint stays" fix_parallel "$(adv fix_parallel 'review-only')"
assert_eq "after_task: verify_1 -> grep_1" orchestrator_grep_1 "$(adv verify_1 'verify-only')"
assert_eq "after_task: verify_1 wrong hint stays" verify_1 "$(adv verify_1 'rung_1_fix')"
assert_eq "after_task: verify_2 -> grep_2" orchestrator_grep_2 "$(adv verify_2 'verify_2')"
assert_eq "after_task: verify_2 wrong hint stays" verify_2 "$(adv verify_2 'rung_1_fix')"
assert_eq "after_task: other phase untouched" orchestrator_grep_1 "$(adv orchestrator_grep_1 'x')"

# --- failure tolerance -----------------------------------------------------------------------------
mkdir -p "$TL_TMP/rmfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/rmfail/rm"; chmod +x "$TL_TMP/rmfail/rm"
st "{$base}"
assert_eq "deactivate tolerates rm failure" 0 "$(PATH="$TL_TMP/rmfail:$PATH" rc sb_rfl_deactivate)"
assert_file_exists "deactivate: state kept when rm fails" "$SF"
real_jq="$(command -v jq)"
tl_stub jq "if [[ \"\$*\" == *'--arg f '*'--arg v '* ]]; then exit 1; fi; exec $real_jq \"\$@\""; hash -r
assert_eq "clear quota tolerates set_field failures" 0 "$(rc sb_rfl_clear_subscription_quota_fallback)"
rm -f "$TL_BIN/jq"; hash -r

# --- skill invocation --------------------------------------------------------------------------------
rm -f "$SF"; sb_rfl_on_skill_invoke other-skill; assert_file_absent "on_skill_invoke: unrelated skill" "$SF"
for s in silver-review-fix-ladder sb:review-fix-ladder review-fix-ladder; do
  rm -f "$SF"; sb_rfl_on_skill_invoke "$s"; assert_eq "on_skill_invoke: $s activates" true "$(f active)"
done

tl_results

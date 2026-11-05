#!/usr/bin/env bash
# Path coverage for hooks/review-fix-ladder-guard.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/review-fix-ladder-guard.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/sub" "$P/scripts" "$TL_TMP/outside"
echo 'print("{\"total_rungs\":3,\"rungs\":[{}]}")' >"$P/scripts/review-fix-ladder.py"
ST="$SB_RUNTIME_STATE_DIR"
SF="$ST/review-fix-ladder-state.json"
base='"active":true,"rung":1,"total_rungs":3,"phase":"review","rung_model":"m1","host_model":"h1","pm_filed":false,"compliance_stop":false'
state() { printf '{%s%s}\n' "$base" "${1:+,$1}" >"$SF"; }
ev() { jq -cn --arg e "$1" --arg t "$2" --argjson i "$3" '{hook_event_name:$e,tool_name:$t,tool_input:$i}'; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // .decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
f() { jq -r --arg k "$1" '.[$k]' "$SF"; }
run() { dg_run "$P" "$H" "$@"; }

# --- activation by Skill -----------------------------------------------------
rm -f "$SF"
run "$(ev PreToolUse Skill '{"skill":"sb:review-fix-ladder"}')"
assert_eq "PreToolUse Skill activates the ladder" true "$(f active)"
rm -f "$SF"
run "$(ev PostToolUse Skill '{"skill":"silver-review-fix-ladder"}')"
assert_eq "PostToolUse Skill activates the ladder" true "$(f active)"
rm -f "$SF"
run "$(ev PreToolUse Skill '{"name":"other"}')"
assert_file_absent "unrelated skill does not activate" "$SF"
run "$(ev PreToolUse Skill '{"skill":"review-fix-ladder"}')" PATH="$PATH"
S1="$TL_TMP/s1"; dg_stage_hooks "$S1" skill-discovery.sh
rm -f "$SF"
dg_run "$P" "$S1/hooks/review-fix-ladder-guard.sh" "$(ev PreToolUse Skill '{"skill":"review-fix-ladder"}')"
assert_eq "skill name used verbatim when no canonicaliser: activates" true "$(f active)"

# optional skill-name canonicaliser (host-provided function)
CANON='sb_skill_canonical_name() { printf "silver-review-fix-ladder"; }; export -f sb_skill_canonical_name'
for evn in PreToolUse PostToolUse; do
  rm -f "$SF"
  dg_run_with_fn "$P" "$H" "$(ev "$evn" Skill '{"skill":"sb:alias"}')" "$CANON"
  assert_eq "$evn: canonicalised skill name activates the ladder" true "$(f active)"
  rm -f "$SF"
  dg_run_with_fn "$P" "$H" "$(ev "$evn" Skill '{"skill":"sb:review-fix-ladder"}')" 'sb_skill_canonical_name() { return 1; }; export -f sb_skill_canonical_name'
  assert_eq "$evn: failing canonicaliser falls back to the raw name" true "$(f active)"
done

# --- guards -------------------------------------------------------------------
state
dg_run_nojq "$P" "$H" "$(ev PreToolUse Task '{"prompt":"x"}')"
assert_eq "no jq: inert" "" "$TL_OUT"
dg_assert_ok "no jq: inert: exits 0"
run ""
assert_eq "empty input: inert" "" "$TL_OUT"
dg_assert_ok "empty input: inert: exits 0"
dg_run_closed_stdin "$P" "$H"
assert_eq "unreadable stdin: exit 0" 0 "$TL_STATUS"
rm -f "$ST/project-root"
dg_run "$TL_TMP/outside" "$H" "$(ev PreToolUse Task '{"prompt":"x"}')"
assert_eq "outside an SB project: inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project: inert: exits 0"
dg_run_nolib_in "$P" "$H" "$(ev PreToolUse Task '{"prompt":"x"}')"
assert_eq "no libs: inert" "" "$TL_OUT"
dg_assert_ok "no libs: inert: exits 0"
S0="$TL_TMP/s0"; dg_stage_hooks "$S0" project-active.sh
dg_run_with_fn "$P" "$S0/hooks/review-fix-ladder-guard.sh" "$(ev PreToolUse Task '{"prompt":"x"}')" 'sb_project_gate_or_exit() { return 1; }; export -f sb_project_gate_or_exit'
assert_eq "project gate failing: exit 0" "" "$TL_OUT"
dg_assert_ok "project gate failing: exit 0: exits 0"
rm -f "$SF"
run "$(ev PreToolUse Task '{"prompt":"x"}')"
assert_eq "no ladder state: allow" "" "$TL_OUT"
dg_assert_ok "no ladder state: allow: exits 0"
state; run "$(ev PreToolUse Task '{"prompt":"rung_1_review"}')" SB_REVIEW_FIX_LADDER_GUARD=0
assert_eq "guard disabled: allow" "" "$TL_OUT"
dg_assert_ok "guard disabled: allow: exits 0"
echo blocker >"$TL_TMP/blocker"
dg_run "$P" "$H" "$(ev PreToolUse Task '{"prompt":"x"}')" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub"
assert_eq "unusable state dir tolerated" 0 "$TL_STATUS"
dg_run "$P/sub" "$H" "$(ev PreToolUse Task '{"prompt":"review-only and triage_pass","subagent_type":"x"}')"
assert_eq "gate works from a sub-directory" "deny" "$(dec)"
state

# --- compliance stop -------------------------------------------------------------
state '"compliance_stop":true,"stop_reason":"custom stop reason"'
run "$(ev PreToolUse Read '{}')"
assert_eq "compliance stop denies PreToolUse" "deny" "$(dec)"
assert_contains "compliance stop reason" "$TL_OUT" "custom stop reason"
run "$(ev Stop Read '{}')"
assert_eq "compliance stop blocks Stop events" "block" "$(dec)"
state '"compliance_stop":true'
run "$(ev PreToolUse Read '{}')"
assert_contains "default compliance reason" "$TL_OUT" "compliance STOP"
run "$(ev PreToolUse Read '{}')" SB_KAY_HOOK_BRIDGE_INVOKED=1
assert_eq "bridge env does not change the decision" "deny" "$(dec)"
S2="$TL_TMP/s2"; dg_stage_hooks "$S2" hook-audit.sh
dg_run "$P" "$S2/hooks/review-fix-ladder-guard.sh" "$(ev PreToolUse Read '{}')"
assert_eq "no audit lib: still denies" "deny" "$(dec)"

# --- malformed tool inputs never crash the gate ---------------------------------------
state
for evn in PreToolUse PostToolUse; do
  for t in Skill Task Bash; do
    run "$(jq -cn --arg e "$evn" --arg t "$t" '{hook_event_name:$e,tool_name:$t,tool_input:"oops"}')"
    assert_eq "$evn $t with a non-object tool_input exits 0" 0 "$TL_STATUS"
  done
done
run "$(ev PreToolUse Skill '{}')"
assert_eq "Skill without a name is ignored" 0 "$TL_STATUS"
run "$(ev PostToolUse Skill '{}')"
assert_eq "PostToolUse Skill without a name is ignored" 0 "$TL_STATUS"

# --- other events after activation ----------------------------------------------
state
run "$(ev Stop Task '{"prompt":"x"}')"
assert_eq "non-Pre/Post events are allowed when not in compliance stop" "" "$TL_OUT"
dg_assert_ok "non-Pre/Post events are allowed when not in compliance stop: exits 0"

# --- PostToolUse bookkeeping ---------------------------------------------------------
state
run "$(ev PostToolUse Task '{"prompt":"rung_1_review output"}')"
assert_eq "PostToolUse Task advances review -> triage" triage "$(f phase)"
state; run "$(ev PostToolUse Task '{"prompt":"rung_1_review"}')" SB_ORCHESTRATOR_PARENT=0
assert_eq "PostToolUse Task in worker session ignored" review "$(f phase)"
state '"phase":"file_valid_issues"'
run "$(ev PostToolUse Bash '{"command":"gh issue create -t x"}')"
assert_eq "PM filing command moves to fix_parallel" fix_parallel "$(f phase)"
assert_eq "PM filing recorded" true "$(f pm_filed)"
state '"phase":"triage"'
run "$(ev PostToolUse Bash '{"command":"gh issue create -t x"}')"
assert_eq "PM filing in the wrong phase ignored" triage "$(f phase)"
state '"phase":"file_valid_issues"'
run "$(ev PostToolUse Bash '{"command":"ls"}')"
assert_eq "ordinary command ignored" file_valid_issues "$(f phase)"
run "$(ev PostToolUse Read '{}')"
assert_eq "other PostToolUse tools ignored" 0 "$TL_STATUS"

# --- PreToolUse validation --------------------------------------------------------------
state
run "$(ev PreToolUse Task '{"prompt":"rung_1_review","model":"m1"}')"
assert_eq "valid review Task allowed" "" "$TL_OUT"
dg_assert_ok "valid review Task allowed: exits 0"
run "$(ev PreToolUse Task '{"prompt":"run /sb:triage","model":"m1"}')"
assert_eq "triage in review phase denied" "deny" "$(dec)"
assert_contains "violation text surfaced" "$TL_OUT" "must be review-only"
assert_eq "violation recorded as compliance stop" true "$(f compliance_stop)"
assert_contains "violation stored as stop reason" "$(f stop_reason)" "review-only"
state
run "$(ev PreToolUse Task '{"prompt":"rung_1_review","model":"m1"}')" SB_ORCHESTRATOR_PARENT=0
assert_eq "worker session Tasks are not gated" "" "$TL_OUT"
dg_assert_ok "worker session Tasks are not gated: exits 0"
state
run "$(ev PreToolUse Subagent '{"description":"verify_1 and verify_2","readonly":true}')"
assert_eq "Subagent combined verify denied" "deny" "$(dec)"
state; mkdir -p "$TL_TMP/rofail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/rofail/mv"; chmod +x "$TL_TMP/rofail/mv"
dg_run "$P" "$H" "$(ev PreToolUse Agent '{"prompt":"run /sb:triage","subagent":"x"}')" PATH="$TL_TMP/rofail:$PATH"
assert_eq "state recording failure still denies (fail closed)" "deny" "$(dec)"

# Bash: orchestrator grep progression
state '"phase":"orchestrator_grep_1","grep_after_verify":0'
run "$(ev PreToolUse Bash '{"command":"git diff --stat"}')"
assert_eq "grep after first verify advances to verify_2" verify_2 "$(f phase)"
state '"phase":"orchestrator_grep_2","grep_after_verify":1'
run "$(ev PreToolUse Bash '{"command":"rg charter docs"}')"
assert_eq "grep after second verify advances the rung" 2 "$(f rung)"
state '"phase":"orchestrator_grep_1","grep_after_verify":0'
run "$(ev PreToolUse Bash '{"command":"echo hi"}')"
assert_eq "non-grep command does not advance" orchestrator_grep_1 "$(f phase)"
state
run "$(ev PreToolUse Bash '{"command":"grep x y"}')"
assert_eq "grep outside grep phases ignored" review "$(f phase)"

# Edit/Write in verify phases
for ph in verify_1 verify_2 orchestrator_grep_1 orchestrator_grep_2; do
  state "\"phase\":\"$ph\""
  run "$(ev PreToolUse Edit '{"file_path":"/x"}')" SB_ORCHESTRATOR_PARENT=0
  assert_eq "worker edit in $ph denied" "deny" "$(dec)"
  run "$(ev PreToolUse Write '{"file_path":"/x"}')"
  assert_eq "parent edit in $ph allowed" "" "$TL_OUT"
done
state
run "$(ev PreToolUse Edit '{"file_path":"/x"}')" SB_ORCHESTRATOR_PARENT=0
assert_eq "worker edit in review phase allowed" "" "$TL_OUT"
dg_assert_ok "worker edit in review phase allowed: exits 0"
run "$(ev PreToolUse Read '{}')"
assert_eq "unrelated tools allowed" "" "$TL_OUT"
dg_assert_ok "unrelated tools allowed: exits 0"

tl_results

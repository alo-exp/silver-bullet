#!/usr/bin/env bash
# Path coverage for hooks/outcomes-check.sh (UserPromptSubmit seeding + Stop outcome gate).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/outcomes-check.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/sub" "$P/.planning" "$TL_TMP/outside"
ST="$SB_RUNTIME_STATE_DIR"
OF="$ST/outcomes-session.json"
STATE="$ST/state"
ups() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p}'; }
ev() { jq -cn --arg e "$1" '{hook_event_name:$e}'; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
clean() { rm -f "$OF" "$STATE" "$ST/trivial" "$ST"/ups-coalesce-* "$ST/stop-coalesce-block" "$ST/orchestrator-intent.txt" "$P/.planning/orchestrator-override-log.jsonl"; rm -rf "$P/.planning/workflows" "$P/.planning/phases"; }
run() { dg_run "$P" "$H" "$@" SILVER_BULLET_STATE_FILE="$STATE"; }

# --- UserPromptSubmit ----------------------------------------------------------
clean
run "$(ups "")"
assert_eq "empty prompt: nothing" "" "$TL_OUT"
assert_file_absent "empty prompt: no outcomes" "$OF"
dg_run "$P/sub" "$H" "$(ups "build the thing")" SILVER_BULLET_STATE_FILE="$STATE"
assert_contains "prompt seeds outcomes and injects summary" "$(ctx)" "Outstanding per-prompt outcomes"
assert_eq "three outcomes pending" 3 "$(jq '[.outcomes[]|select(.status=="pending")]|length' "$OF")"
assert_eq "prompt recorded as orchestrator intent" "build the thing" "$(cat "$ST/orchestrator-intent.txt")"
run "$(ups "build the thing")"
assert_eq "same-turn duplicate is coalesced" "" "$(ctx)"
clean
S1="$TL_TMP/s1"; dg_stage_hooks "$S1" ups-coalesce.sh stop-coalesce.sh
dg_run "$P" "$S1/hooks/outcomes-check.sh" "$(ups "build the thing")" SILVER_BULLET_STATE_FILE="$STATE"
assert_contains "no coalesce lib: plain additionalContext" "$(ctx)" "Outstanding per-prompt outcomes"
clean
rm -f "$ST/orchestrator-directive.json"
run "$(ups "SB OVERRIDE: waive the directive. keep going")"
assert_file_exists "override is logged" "$P/.planning/orchestrator-override-log.jsonl"
assert_contains "override reason captured" "$(cat "$P/.planning/orchestrator-override-log.jsonl")" "waive the directive. keep going"
clean
run "$(ups "yes")"
assert_contains "orchestrator follow-up still seeds outcomes" "$(ctx)" "Outstanding"
clean
run "$(ups "implement feature X in detail please")"
assert_contains "ordinary prompt seeds" "$(ctx)" "Outstanding"
S2="$TL_TMP/s2"; dg_stage_hooks "$S2" orchestrator-directive.sh orchestrator-state.sh prompt-classifier.sh
clean
dg_run "$P" "$S2/hooks/outcomes-check.sh" "$(ups "build the thing")" SILVER_BULLET_STATE_FILE="$STATE"
assert_contains "no orchestrator libs: outcomes still seeded" "$(ctx)" "Outstanding"
S3="$TL_TMP/s3"; dg_stage_hooks "$S3" orchestrator-parent.sh
clean
dg_run "$P" "$S3/hooks/outcomes-check.sh" "$(ups "SB OVERRIDE: because")" SILVER_BULLET_STATE_FILE="$STATE"
assert_file_exists "no parent lib: override still logged" "$P/.planning/orchestrator-override-log.jsonl"
S4="$TL_TMP/s4"; dg_stage_hooks "$S4" sb-project-gate.sh
clean
dg_run "$P" "$S4/hooks/outcomes-check.sh" "$(ups "build the thing")" SILVER_BULLET_STATE_FILE="$STATE"
assert_contains "no project-gate lib: still works" "$(ctx)" "Outstanding"

# --- guards -----------------------------------------------------------------------
clean
rm -f "$ST/project-root"
dg_run "$TL_TMP/outside" "$H" "$(ups "build the thing")"
assert_eq "outside an SB project: inert" "" "$TL_OUT"
dg_run_gate_missing "$P" "$H" "$(ups "build the thing")"
assert_eq "project gate unavailable: fails open" "" "$TL_OUT"
dg_run_nolib_in "$P" "$H" "$(ups "build the thing")"
assert_eq "no libs: fails open" "" "$TL_OUT"
dg_run_closed_stdin "$P" "$H"
assert_eq "unreadable stdin: exits 0" 0 "$TL_STATUS"
run "not json"
assert_eq "unparsable input defaults to UserPromptSubmit with empty prompt" "" "$TL_OUT"
echo blocker >"$TL_TMP/blocker"
dg_run "$P" "$H" "$(ups "x y z")" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub"
assert_eq "unusable state dir tolerated" 0 "$TL_STATUS"

# --- Stop / SubagentStop ------------------------------------------------------------------
clean
run "$(ev Stop)"
assert_eq "Stop without state: allowed" "" "$TL_OUT"
run "$(ups "build the thing")" >/dev/null
printf 'silver-quality-gates\n' >"$STATE"
run "$(ev Stop)"
assert_eq "Stop with pending outcomes blocks" "block" "$(dec)"
assert_contains "block lists outcomes" "$TL_OUT" "per-prompt outcome checklist incomplete"
assert_file_exists "block recorded for coalescing" "$ST/stop-coalesce-block"
run "$(ev Stop)"
assert_eq "secondary block suppressed" "" "$TL_OUT"
rm -f "$ST/stop-coalesce-block"
run "$(ev SubagentStop)" SB_ORCHESTRATOR_PARENT=0
assert_eq "worker SubagentStop skipped" "" "$TL_OUT"
run "$(ev SubagentStop)"
assert_eq "parent SubagentStop blocks" "block" "$(dec)"
rm -f "$ST/stop-coalesce-block"
: >"$ST/trivial"
run "$(ev Stop)"
assert_eq "trivial marker bypasses" "" "$TL_OUT"
rm -f "$ST/trivial"
printf 'silver-feature\nsilver-verify\nsilver-execute\n' >"$STATE"
run "$(ev Stop)"
assert_eq "evidence auto-completes outcomes: Stop allowed" "" "$TL_OUT"
assert_eq "outcomes all done" 0 "$(jq '[.outcomes[]|select(.status!="done")]|length' "$OF")"
ln -s "$TL_TMP/real-state" "$ST/state-link"; printf 'silver-feature\n' >"$TL_TMP/real-state"
clean; run "$(ups "build the thing")" >/dev/null
dg_run "$P" "$H" "$(ev Stop)" SILVER_BULLET_STATE_FILE="$ST/state-link"
assert_eq "symlinked state file is not read: Stop allowed (no state)" "" "$TL_OUT"
rm -f "$ST/state-link"
dg_run "$P" "$S1/hooks/outcomes-check.sh" "$(ev Stop)" SILVER_BULLET_STATE_FILE="$STATE"
printf 'silver-quality-gates\n' >"$STATE"
dg_run "$P" "$S1/hooks/outcomes-check.sh" "$(ev Stop)" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no coalesce lib: Stop blocks" "block" "$(dec)"
S5="$TL_TMP/s5"; dg_stage_hooks "$S5" orchestrator-parent.sh
dg_run "$P" "$S5/hooks/outcomes-check.sh" "$(ev SubagentStop)" SILVER_BULLET_STATE_FILE="$STATE" SB_ORCHESTRATOR_PARENT=0
assert_eq "no parent lib: SubagentStop evaluated as parent" "block" "$(dec)"

# directive write failures and unreadable state are tolerated
clean
mkdir -p "$TL_TMP/mvfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/mvfail/mv"; chmod +x "$TL_TMP/mvfail/mv"
dg_run "$P" "$H" "$(ups "implement feature X in detail please")" SILVER_BULLET_STATE_FILE="$STATE" PATH="$TL_TMP/mvfail:$PATH"
assert_contains "directive write failure does not stop outcome seeding" "$(ctx)" "Outstanding"
clean; run "$(ups "build the thing")" >/dev/null; printf 'silver-quality-gates\n' >"$STATE"
mkdir -p "$TL_TMP/catfail"
printf '#!/bin/sh\nif [ "$#" -eq 0 ]; then exec %s; fi\nexit 1\n' "$(command -v cat)" >"$TL_TMP/catfail/cat"; chmod +x "$TL_TMP/catfail/cat"
dg_run "$P" "$H" "$(ev Stop)" SILVER_BULLET_STATE_FILE="$STATE" PATH="$TL_TMP/catfail:$PATH"
assert_eq "unreadable state file counts as no state: Stop allowed" "" "$TL_OUT"

# --- degraded jq ---------------------------------------------------------------------------
clean; run "$(ups "build the thing")" >/dev/null; printf 'silver-quality-gates\n' >"$STATE"
dg_run_nojq "$P" "$H" "$(ups "build the thing")" SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no jq: UserPromptSubmit cannot seed => exit 0 silently" "" "$TL_OUT"
rm -f "$ST/stop-coalesce-block"
dg_run_nojq "$P" "$H" '{"hook_event_name":"Stop"}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no jq: Stop with pending outcomes still blocks" "block" "$(jq -r .decision <<<"$TL_OUT")"
assert_contains "no jq: block carries the fallback summary" "$TL_OUT" "jq unavailable"
rm -f "$ST/stop-coalesce-block"
dg_run_nojq "$P" "$S1/hooks/outcomes-check.sh" '{"hook_event_name":"SubagentStop"}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no jq, no coalesce lib: SubagentStop blocks" "block" "$(jq -r .decision <<<"$TL_OUT")"
tl_stub jq 'exit 1'; hash -r
dg_run "$P" "$H" '{"hook_event_name":"Stop"}' SILVER_BULLET_STATE_FILE="$STATE"
rm -f "$TL_BIN/jq"; hash -r
assert_eq "broken jq behaves like missing jq" "block" "$(jq -r .decision <<<"$TL_OUT")"
jq '.outcomes |= map(.status="done")' "$OF" >"$OF.t" && mv "$OF.t" "$OF"
dg_run_nojq "$P" "$H" '{"hook_event_name":"Stop"}' SILVER_BULLET_STATE_FILE="$STATE"
assert_eq "no jq, nothing pending: Stop allowed" "" "$TL_OUT"

tl_results

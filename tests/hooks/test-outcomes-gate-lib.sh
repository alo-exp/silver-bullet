#!/usr/bin/env bash
# Unit tests for hooks/lib/outcomes-gate.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/outcomes-gate.sh
source "$TL_REPO_ROOT/hooks/lib/outcomes-gate.sh"

export SB_RUNTIME_STATE_DIR="$TL_TMP/state"; mkdir -p "$SB_RUNTIME_STATE_DIR"
OF="$(sb_outcomes_session_file)"
W="$TL_TMP/work"; mkdir -p "$W"; cd "$W"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
st() { jq -r --arg i "$1" '.outcomes[]|select(.id==$i).status' "$OF"; }
ev() { jq -r --arg i "$1" '.outcomes[]|select(.id==$i).evidence' "$OF"; }
NOJQ="$(tl_path_without jq)"
real_jq="$(command -v jq)"
mkdir -p "$TL_TMP/mvfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/mvfail/mv"; chmod +x "$TL_TMP/mvfail/mv"
mkdir -p "$TL_TMP/mkfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/mkfail/mktemp"; chmod +x "$TL_TMP/mkfail/mktemp"
reseed() { rm -f "$OF"; sb_outcomes_seed_for_prompt "fix the build"; }

assert_eq "session file location" "$SB_RUNTIME_STATE_DIR/outcomes-session.json" "$OF"

# --- jq_update ------------------------------------------------------------------
echo '{"a":1}' >"$TL_TMP/u.json"
assert_eq "jq_update: missing file" 0 "$(rc sb_outcomes_jq_update "$TL_TMP/none.json" .)"
PATH="$NOJQ" sb_outcomes_jq_update "$TL_TMP/u.json" '.a=2'
assert_eq "jq_update: no jq no-op" 1 "$(jq .a "$TL_TMP/u.json")"
PATH="$TL_TMP/mkfail:$PATH" sb_outcomes_jq_update "$TL_TMP/u.json" '.a=2'
assert_eq "jq_update: mktemp failure no-op" 1 "$(jq .a "$TL_TMP/u.json")"
sb_outcomes_jq_update "$TL_TMP/u.json" '.a=(' || true
assert_eq "jq_update: bad filter keeps file" 1 "$(jq .a "$TL_TMP/u.json")"
left=("$TL_TMP"/u.json.*)
assert_eq "jq_update: bad filter cleans temp" "$TL_TMP/u.json.*" "${left[*]}"
PATH="$TL_TMP/mvfail:$PATH" sb_outcomes_jq_update "$TL_TMP/u.json" '.a=3'
assert_eq "jq_update: mv failure keeps file" 1 "$(jq .a "$TL_TMP/u.json")"
sb_outcomes_jq_update "$TL_TMP/u.json" '.a=4'
assert_eq "jq_update: applies" 4 "$(jq .a "$TL_TMP/u.json")"

# --- prompt id ---------------------------------------------------------------------
assert_match "prompt id: 12 hex" '^[0-9a-f]{12}$' "$(sb_outcomes_prompt_id "x")"
assert_match "prompt id: cksum fallback" '^[0-9]+$' "$(PATH="$(tl_path_without shasum)" sb_outcomes_prompt_id "x")"

# --- seeding --------------------------------------------------------------------------
rm -f "$OF"
sb_outcomes_seed_for_prompt "fix the build"
assert_eq "seed: three pending outcomes" "pending pending pending" "$(st route) $(st scope) $(st verify)"
assert_eq "seed: not informational" null "$(jq -r '.informational // null' "$OF")"
started="$(jq -r .started_at "$OF")"
sb_outcomes_seed_for_prompt "fix the build"
assert_eq "seed: idempotent per prompt" "$started" "$(jq -r .started_at "$OF")"
jq '.outcomes[0].status="done"' "$OF" >"$OF.t" && mv "$OF.t" "$OF"
sb_outcomes_seed_for_prompt "a different prompt"
assert_eq "seed: new prompt resets outcomes" pending "$(st route)"
echo 'not json' >"$OF"
sb_outcomes_seed_for_prompt "fix the build"
assert_eq "seed: unreadable file replaced" pending "$(st route)"
sb_prompt_is_informational_query() { return 0; }
rm -f "$OF"; sb_outcomes_seed_for_prompt "what is x?"
assert_eq "seed: informational query pre-completes" "done done done" "$(st route) $(st scope) $(st verify)"
assert_eq "seed: informational flag" true "$(jq -r .informational "$OF")"
sb_prompt_is_informational_query() { return 1; }
reseed
assert_eq "seed: non-informational by classifier" pending "$(st route)"
unset -f sb_prompt_is_informational_query
rm -f "$OF"
PATH="$NOJQ" sb_outcomes_seed_for_prompt "fix"
assert_file_absent "seed: no jq writes nothing" "$OF"
tl_stub shasum 'exit 0'; hash -r
sb_outcomes_seed_for_prompt "fix"
assert_file_absent "seed: empty prompt id aborts" "$OF"
rm -f "$TL_BIN/shasum"; hash -r
SB_RUNTIME_STATE_DIR="$TL_TMP/no-such" sb_outcomes_seed_for_prompt "fix"
assert_file_absent "seed: unwritable location tolerated" "$TL_TMP/no-such/outcomes-session.json"
sb_prompt_is_informational_query() { return 0; }
SB_RUNTIME_STATE_DIR="$TL_TMP/no-such" sb_outcomes_seed_for_prompt "what?"
assert_file_absent "seed: informational + unwritable tolerated" "$TL_TMP/no-such/outcomes-session.json"
unset -f sb_prompt_is_informational_query

# --- auto evaluate ----------------------------------------------------------------------
reseed
TRIV="$TL_TMP/trivial"; : >"$TRIV"
sb_outcomes_auto_evaluate "silver-feature" "$TRIV"
assert_eq "evaluate: trivial marker skips" pending "$(st route)"
rm -f "$TRIV"
sb_outcomes_auto_evaluate "" "$TRIV"
assert_eq "evaluate: empty state skips" pending "$(st route)"
rm -f "$OF"; assert_eq "evaluate: no outcomes file ok" 0 "$(rc sb_outcomes_auto_evaluate "silver" "$TRIV")"
reseed
assert_eq "evaluate: no jq ok" 0 "$(PATH="$NOJQ" rc sb_outcomes_auto_evaluate "silver" "$TRIV")"
assert_eq "evaluate: no jq changes nothing" pending "$(st route)"
sb_outcomes_auto_evaluate $'silver-quality-gates\nsilver-plan\n' "$TRIV"
assert_eq "evaluate: planning-floor skills do not route" pending "$(st route)"
sb_outcomes_auto_evaluate $'silver-quality-gates\nsilver-feature\n' "$TRIV"
assert_eq "evaluate: composer routes" "done" "$(st route)"
assert_eq "evaluate: route evidence" "workflow composer or /sb router recorded" "$(ev route)"
assert_eq "evaluate: verify untouched" pending "$(st verify)"
sb_outcomes_auto_evaluate $'verify-tests\n' "$TRIV"
assert_eq "evaluate: verify-tests marks verify" "done" "$(st verify)"
reseed
sb_outcomes_auto_evaluate $'silver-verify\n' "$TRIV"
assert_eq "evaluate: silver-verify marks verify" "done" "$(st verify)"
reseed
sb_outcomes_auto_evaluate $'silver-execute\n' "$TRIV"
assert_eq "evaluate: silver-execute marks scope" "done" "$(st scope)"

reseed
mkdir -p .planning/workflows
echo "# only a heading" >.planning/workflows/a.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: heading-only workflow is not scope" pending "$(st scope)"
ln -s "$TL_TMP/elsewhere.md" .planning/workflows/link.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: symlinked workflow ignored" pending "$(st scope)"
printf -- '---\ncomposer: /sb:feature\n---\n' >.planning/workflows/b.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: workflow with composer marks scope" "done" "$(st scope)"
reseed
rm -f .planning/workflows/b.md
printf 'real body text\n' >.planning/workflows/c.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: workflow with a body marks scope" "done" "$(st scope)"
rm -rf .planning/workflows

reseed
mkdir -p .planning/phases/01-a
printf '# Plan only a heading\n' >.planning/PLAN.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: heading-only PLAN.md is not scope" pending "$(st scope)"
printf '# Plan\n\nnothing\n' >.planning/PLAN.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: PLAN.md without substance keywords is not scope" pending "$(st scope)"
printf '# Plan\n\n- Task 1: build it\n' >.planning/phases/01-a/PLAN.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: phase PLAN.md with tasks marks scope" "done" "$(st scope)"
reseed
rm -f .planning/phases/01-a/PLAN.md; rm -f .planning/PLAN.md
ln -s "$TL_TMP/p.md" .planning/PLAN.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: symlinked PLAN.md ignored" pending "$(st scope)"
rm -f .planning/PLAN.md
printf '# P\n\nAcceptance criteria\n' >.planning/PLAN.md
sb_outcomes_auto_evaluate $'x\n' "$TRIV"
assert_eq "evaluate: root PLAN.md with acceptance marks scope" "done" "$(st scope)"
rm -rf .planning

# --- summary / all_done -------------------------------------------------------------------------
rm -f "$OF"
assert_eq "summary: no file" "" "$(sb_outcomes_pending_summary)"
assert_eq "all_done: no file" 0 "$(rc sb_outcomes_all_done)"
reseed
assert_eq "summary: jq missing" "" "$(PATH="$NOJQ" sb_outcomes_pending_summary)"
s="$(sb_outcomes_pending_summary)"
assert_contains "summary: heading" "$s" "Outstanding per-prompt outcomes:"
assert_contains "summary: lists route" "$s" "- Route via /sb or approved workflow composer"
jq '.outcomes[0].evidence="because"' "$OF" >"$OF.t" && mv "$OF.t" "$OF"
assert_contains "summary: evidence shown" "$(sb_outcomes_pending_summary)" "(because)"
assert_eq "all_done: pending" 1 "$(rc sb_outcomes_all_done)"
assert_eq "all_done: no jq with pending marker fails closed" 1 "$(PATH="$NOJQ" rc sb_outcomes_all_done)"
jq '.outcomes |= map(.status="done")' "$OF" >"$OF.t" && mv "$OF.t" "$OF"
assert_eq "summary: all done is empty" "" "$(sb_outcomes_pending_summary)"
assert_eq "all_done: complete" 0 "$(rc sb_outcomes_all_done)"
assert_eq "all_done: no jq without pending marker passes" 0 "$(PATH="$NOJQ" rc sb_outcomes_all_done)"
echo 'not json' >"$OF"
assert_eq "all_done: unparsable file fails closed" 1 "$(rc sb_outcomes_all_done)"
assert_eq "summary: unparsable file prints nothing" "" "$(sb_outcomes_pending_summary)"
: "$real_jq"

tl_results

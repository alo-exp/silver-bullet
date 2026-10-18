#!/usr/bin/env bash
# Unit tests for hooks/lib/instruction-ledger.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/instruction-ledger.sh
source "$TL_REPO_ROOT/hooks/lib/instruction-ledger.sh"

export SB_RUNTIME_STATE_DIR="$TL_TMP/state"; mkdir -p "$SB_RUNTIME_STATE_DIR"
LF="$(sb_instruction_ledger_file)"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
G="$TL_TMP/repo"; tl_git_repo "$G"
PLAIN="$TL_TMP/plain"; mkdir -p "$PLAIN"
NOJQ="$(tl_path_without jq)"
mkdir -p "$TL_TMP/failbin"
for c in rm mv mktemp; do printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/failbin/$c"; chmod +x "$TL_TMP/failbin/$c"; done
FAILPATH="$TL_TMP/failbin:$PATH"

ledger() { # branch worktree [status]
  jq -n --arg b "$1" --arg w "$2" '{prompt_id:"p",scope:{branch:$b,worktree:$w},intents:[{id:"root",label:"R",status:"pending",evidence:"",children:[
    {id:"c1",label:"first task",status:"pending",evidence:"",children:[]},
    {id:"c2",label:"second task",status:"pending",evidence:"",children:[]}]}]}' >"$LF"
}

# --- file/clear ---------------------------------------------------------
assert_eq "ledger file under the state dir" "$SB_RUNTIME_STATE_DIR/instruction-ledger.json" "$LF"
echo '{}' >"$LF"; sb_instruction_ledger_clear
assert_file_absent "clear removes ledger" "$LF"
echo '{}' >"$LF"; PATH="$FAILPATH" sb_instruction_ledger_clear
assert_file_exists "clear tolerates rm failure" "$LF"; rm -f "$LF"

# --- current_scope ------------------------------------------------------
sb_instruction_ledger_current_scope "$G"
assert_eq "scope: branch" "feature/test" "$SB_INSTRUCTION_LEDGER_SCOPE_BRANCH"
assert_eq "scope: worktree toplevel (fallback git lookup)" "$G" "$SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE"
source "$TL_REPO_ROOT/hooks/lib/branch-scope.sh"
sb_instruction_ledger_current_scope "$G"
assert_eq "scope: worktree via branch-scope helper" "$G" "$SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE"
sb_instruction_ledger_current_scope "$PLAIN"
assert_eq "scope: non-git dir has no branch" "" "$SB_INSTRUCTION_LEDGER_SCOPE_BRANCH"
tl_stub git 'echo "bad branch!"'
sb_instruction_ledger_current_scope "$G"
assert_eq "scope: unsafe branch name discarded" "" "$SB_INSTRUCTION_LEDGER_SCOPE_BRANCH"
rm -f "$TL_BIN/git"; hash -r

unset -f sb_branch_scope_git_toplevel
sb_instruction_ledger_current_scope "$PLAIN"
assert_eq "scope: non-git dir has no worktree (fallback lookup fails quietly)" "" "$SB_INSTRUCTION_LEDGER_SCOPE_WORKTREE"
source "$TL_REPO_ROOT/hooks/lib/branch-scope.sh"

# --- scope_mismatch / drop ---------------------------------------------
cd "$G"
assert_eq "mismatch: no ledger" 1 "$(rc sb_instruction_ledger_scope_mismatch)"
ledger feature/test "$G"
assert_eq "mismatch: same scope" 1 "$(rc sb_instruction_ledger_scope_mismatch)"
assert_eq "mismatch: jq missing" 1 "$(PATH="$NOJQ" rc sb_instruction_ledger_scope_mismatch)"
ledger other/branch "$G"
assert_eq "mismatch: different branch" 0 "$(rc sb_instruction_ledger_scope_mismatch)"
ledger feature/test /elsewhere
assert_eq "mismatch: different worktree" 0 "$(rc sb_instruction_ledger_scope_mismatch)"
ledger "" ""
assert_eq "mismatch: legacy unscoped ledger" 1 "$(rc sb_instruction_ledger_scope_mismatch)"
ledger feature/test ""
assert_eq "mismatch: worktree not stamped" 1 "$(rc sb_instruction_ledger_scope_mismatch)"
echo 'not json' >"$LF"
assert_eq "mismatch: unparsable ledger is not a mismatch" 1 "$(rc sb_instruction_ledger_scope_mismatch)"
ledger feature/test ""
assert_eq "mismatch: no branch in cwd" 1 "$(cd "$PLAIN" && rc sb_instruction_ledger_scope_mismatch)"
assert_eq "mismatch: explicit root argument" 1 "$(rc sb_instruction_ledger_scope_mismatch "$PLAIN")"
ledger other/branch "$G"
assert_eq "drop: foreign ledger cleared" 0 "$(rc sb_instruction_ledger_drop_if_scope_mismatch)"
assert_file_absent "drop: file removed" "$LF"
ledger feature/test "$G"
assert_eq "drop: matching ledger kept" 1 "$(rc sb_instruction_ledger_drop_if_scope_mismatch)"
assert_file_exists "drop: file kept" "$LF"

# --- prompt id -------------------------------------------------------------
id1="$(sb_instruction_ledger_prompt_id "hello")"
assert_match "prompt id (shasum) is 12 hex chars" '^[0-9a-f]{12}$' "$id1"
assert_eq "prompt id deterministic" "$id1" "$(sb_instruction_ledger_prompt_id "hello")"
NOSHA="$(tl_path_without shasum)"
id2="$(PATH="$NOSHA" sb_instruction_ledger_prompt_id "hello")"
assert_match "prompt id (cksum fallback) is numeric" '^[0-9]+$' "$id2"

# --- jq_update -------------------------------------------------------------
echo '{"a":1}' >"$TL_TMP/u.json"
assert_eq "jq_update: missing file ok" 0 "$(rc sb_instruction_ledger_jq_update "$TL_TMP/none.json" '.')"
PATH="$NOJQ" sb_instruction_ledger_jq_update "$TL_TMP/u.json" '.a = 2'
assert_eq "jq_update: no jq leaves file" 1 "$(jq .a "$TL_TMP/u.json")"
PATH="$FAILPATH" sb_instruction_ledger_jq_update "$TL_TMP/u.json" '.a = 2'
assert_eq "jq_update: mktemp failure leaves file" 1 "$(jq .a "$TL_TMP/u.json")"
sb_instruction_ledger_jq_update "$TL_TMP/u.json" '.a = (' || true
assert_eq "jq_update: bad filter leaves file" 1 "$(jq .a "$TL_TMP/u.json")"
leftovers=("$TL_TMP"/u.json.*)
assert_eq "jq_update: bad filter leaves no temp files" "$TL_TMP/u.json.*" "${leftovers[*]}"
sb_instruction_ledger_jq_update "$TL_TMP/u.json" '.a = 2'
assert_eq "jq_update: applies filter" 2 "$(jq .a "$TL_TMP/u.json")"
mkdir -p "$TL_TMP/mvfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/mvfail/mv"; chmod +x "$TL_TMP/mvfail/mv"
PATH="$TL_TMP/mvfail:$PATH" sb_instruction_ledger_jq_update "$TL_TMP/u.json" '.a = 3'
assert_eq "jq_update: mv failure leaves original" 2 "$(jq .a "$TL_TMP/u.json")"

# --- bullets -----------------------------------------------------------------
P1=$'Do these:\n- alpha\n* beta\n• gamma\n1. delta\n2) epsilon\nplain line\n'
assert_eq "bullets: all marker styles" '["alpha","beta","gamma","delta","epsilon"]' "$(sb_instruction_ledger_parse_bullets "$P1" | jq -c .)"
P2=$'- one\n```\n- quoted\n```\n- two\n'
assert_eq "bullets: fenced block skipped" '["one","two"]' "$(sb_instruction_ledger_parse_bullets "$P2" | jq -c .)"
P3=$'- one\n```\n- quoted\n- more\n'
assert_eq "bullets: unterminated fence skips the rest" '["one"]' "$(sb_instruction_ledger_parse_bullets "$P3" | jq -c .)"
assert_eq "bullets: no jq fails" 1 "$(PATH="$NOJQ" rc sb_instruction_ledger_parse_bullets "- a")"
assert_eq "bullet_count" 5 "$(sb_instruction_ledger_bullet_count "$P1")"
assert_eq "bullet_count: no jq degrades to 0" 0 "$(PATH="$NOJQ" sb_instruction_ledger_bullet_count "$P1")"

# --- agent report detection ---------------------------------------------------
assert_eq "report: empty" 1 "$(rc sb_prompt_is_agent_report "")"
assert_eq "report: single marker is not enough" 1 "$(rc sb_prompt_is_agent_report $'Report from agent')"
assert_eq "report: two markers" 0 "$(rc sb_prompt_is_agent_report $'Report from agent\nResults: 12 passed')"
assert_eq "report: commit range + porcelain" 0 "$(rc sb_prompt_is_agent_report $'git status --porcelain\nabc1234..def5678')"
assert_eq "report: ordinary request" 1 "$(rc sb_prompt_is_agent_report "please fix the bug")"

# --- seeding --------------------------------------------------------------------
PB=$'Please:\n- one\n- two\n- three\n'
rm -f "$LF"
sb_instruction_ledger_seed_from_prompt ""
assert_file_absent "seed: empty prompt" "$LF"
PATH="$NOJQ" sb_instruction_ledger_seed_from_prompt "$PB"
assert_file_absent "seed: no jq" "$LF"
sb_instruction_ledger_seed_from_prompt $'- a\n- b\n'
assert_file_absent "seed: fewer than 3 bullets" "$LF"
sb_instruction_ledger_seed_from_prompt $'Report from x\nResults: 3 passed\n- a\n- b\n- c\n'
assert_file_absent "seed: agent report not enrolled" "$LF"
sb_prompt_is_informational_query() { return 0; }
sb_instruction_ledger_seed_from_prompt "$PB"
assert_file_absent "seed: informational query skipped" "$LF"
sb_prompt_is_informational_query() { return 1; }
sb_instruction_ledger_seed_from_prompt "$PB"
assert_eq "seed: root with 3 pending children" 3 "$(jq '.intents[0].children|length' "$LF")"
assert_eq "seed: scope stamped with branch" "feature/test" "$(jq -r .scope.branch "$LF")"
assert_eq "seed: scope stamped with worktree" "$G" "$(jq -r .scope.worktree "$LF")"
assert_eq "seed: child status pending" pending "$(jq -r '.intents[0].children[0].status' "$LF")"
first_started="$(jq -r .started_at "$LF")"
sb_instruction_ledger_seed_from_prompt "$PB"
assert_eq "seed: same prompt is idempotent" "$first_started" "$(jq -r .started_at "$LF")"
sb_instruction_ledger_seed_from_prompt $'- x\n- y\n- z\n- w\n'
assert_eq "seed: new prompt replaces ledger" 4 "$(jq '.intents[0].children|length' "$LF")"
ledger other/branch "$G"
sb_instruction_ledger_seed_from_prompt "$PB"
assert_eq "seed: foreign ledger dropped before seeding" "feature/test" "$(jq -r .scope.branch "$LF")"
rm -f "$LF"
tl_stub shasum 'exit 0'
sb_instruction_ledger_seed_from_prompt "$PB"
assert_file_absent "seed: empty prompt id aborts" "$LF"
rm -f "$TL_BIN/shasum"; hash -r
dg_real_jq="$(command -v jq)"
tl_stub jq "if [[ \"\$*\" == *'@base64'* ]]; then exit 1; fi; exec $dg_real_jq \"\$@\""; hash -r
sb_instruction_ledger_seed_from_prompt "$PB"
assert_eq "seed: child construction failure yields empty children" 0 "$(jq '.intents[0].children|length' "$LF")"
rm -f "$TL_BIN/jq"; hash -r; rm -f "$LF"
SB_RUNTIME_STATE_DIR="$TL_TMP/no-such-dir" sb_instruction_ledger_seed_from_prompt "$PB"
assert_file_absent "seed: unwritable ledger location tolerated" "$TL_TMP/no-such-dir/instruction-ledger.json"

# jq failures inside seeding degrade safely
dg_real_jq="$(command -v jq)"
jqfail() { tl_stub jq "if [[ \"\$*\" == *'$1'* ]]; then exit 1; fi; exec $dg_real_jq \"\$@\""; hash -r; }
jqunstub() { rm -f "$TL_BIN/jq"; hash -r; }
rm -f "$LF"
jqfail 'split('
sb_instruction_ledger_seed_from_prompt "$PB"
jqunstub
assert_file_absent "seed: bullet parsing failure enrols nothing" "$LF"
jqfail 'length'
assert_eq "seed: bullet count failure enrols nothing" 0 "$(sb_instruction_ledger_bullet_count "$PB")"
sb_instruction_ledger_seed_from_prompt "$PB"
jqunstub
assert_file_absent "seed: count failure enrols nothing" "$LF"
echo 'not json' >"$LF"
sb_instruction_ledger_seed_from_prompt "$PB"
assert_eq "seed: unreadable existing ledger is replaced" 3 "$(jq '.intents[0].children|length' "$LF")"
rm -f "$LF"

# --- all_resolved / summary ------------------------------------------------------
rm -f "$LF"
assert_eq "all_resolved: no ledger" 0 "$(rc sb_instruction_ledger_all_resolved)"
assert_eq "summary: no ledger prints nothing" "" "$(sb_instruction_ledger_pending_summary)"
ledger feature/test "$G"
assert_eq "all_resolved: pending items" 1 "$(rc sb_instruction_ledger_all_resolved)"
assert_eq "all_resolved: jq missing" 0 "$(PATH="$NOJQ" rc sb_instruction_ledger_all_resolved)"
assert_eq "summary: jq missing prints nothing" "" "$(PATH="$NOJQ" sb_instruction_ledger_pending_summary)"
s="$(sb_instruction_ledger_pending_summary)"
assert_contains "summary: lists leaf c1" "$s" "- [c1] first task"
assert_contains "summary: lists leaf c2" "$s" "- [c2] second task"
assert_contains "summary: resolve hint" "$s" "resolve-instruction-ledger.sh done"
assert_not_contains "summary: root not listed when it has children" "$s" "[root]"
echo 'not json' >"$LF"
assert_eq "summary: unparsable ledger prints nothing" "" "$(sb_instruction_ledger_pending_summary)"
ledger feature/test "$G"
jq '.intents[0].children |= []' "$LF" >"$LF.t" && mv "$LF.t" "$LF"
assert_contains "summary: childless pending root listed" "$(sb_instruction_ledger_pending_summary)" "- [root] R"

# --- resolve_item ------------------------------------------------------------------
ledger feature/test "$G"
assert_eq "resolve: empty selector" 1 "$(rc sb_instruction_ledger_resolve_item "" "done" ev)"
assert_eq "resolve: bad status" 1 "$(rc sb_instruction_ledger_resolve_item c1 maybe ev)"
assert_eq "resolve: missing evidence" 1 "$(rc sb_instruction_ledger_resolve_item c1 "done" "")"
assert_eq "resolve: jq missing" 1 "$(PATH="$NOJQ" rc sb_instruction_ledger_resolve_item c1 "done" ev)"
assert_eq "resolve: no match" 1 "$(rc sb_instruction_ledger_resolve_item nothing-like-this "done" ev)"
assert_eq "resolve: ambiguous substring" 1 "$(rc sb_instruction_ledger_resolve_item task "done" ev)"
assert_eq "resolve: mktemp failure" 1 "$(PATH="$FAILPATH" rc sb_instruction_ledger_resolve_item c1 "done" ev)"
assert_eq "resolve: mv failure" 1 "$(PATH="$TL_TMP/mvfail:$PATH" rc sb_instruction_ledger_resolve_item c1 "done" ev)"
assert_eq "resolve: by id" 0 "$(rc sb_instruction_ledger_resolve_item c1 "done" "tests green")"
assert_eq "resolve: status stored" "done" "$(jq -r '.intents[0].children[0].status' "$LF")"
assert_eq "resolve: evidence stored" "tests green" "$(jq -r '.intents[0].children[0].evidence' "$LF")"
assert_eq "resolve: root stays pending while a child is pending" pending "$(jq -r '.intents[0].status' "$LF")"
assert_eq "resolve: by unique label substring (deferred)" 0 "$(rc sb_instruction_ledger_resolve_item "second" deferred "later")"
assert_eq "resolve: root auto-resolved" "done" "$(jq -r '.intents[0].status' "$LF")"
assert_eq "all_resolved: after resolution" 0 "$(rc sb_instruction_ledger_all_resolved)"
ledger other/branch "$G"
assert_eq "resolve: foreign ledger refused" 1 "$(rc sb_instruction_ledger_resolve_item c1 "done" ev)"
assert_file_absent "resolve: foreign ledger dropped" "$LF"
rm -f "$LF"
assert_eq "resolve: missing ledger" 1 "$(rc sb_instruction_ledger_resolve_item c1 "done" ev)"
ledger feature/test "$G"
tl_stub jq "if [[ \"\$*\" == *'update_node'* ]]; then exit 1; fi; exec $dg_real_jq \"\$@\""; hash -r
assert_eq "resolve: update filter failure" 1 "$(rc sb_instruction_ledger_resolve_item c1 "done" ev)"
rm -f "$TL_BIN/jq"; hash -r
assert_eq "resolve: failed update leaves ledger intact" pending "$(jq -r '.intents[0].children[0].status' "$LF")"
jqfail 'def leaves'
assert_eq "resolve: match lookup failure" 1 "$(rc sb_instruction_ledger_resolve_item c1 "done" ev)"
jqunstub
jqfail 'length'
assert_eq "resolve: match count failure" 1 "$(rc sb_instruction_ledger_resolve_item c1 "done" ev)"
jqunstub
mkdir -p "$TL_TMP/rmfail"; printf '#!/bin/sh\nexit 1\n' >"$TL_TMP/rmfail/rm"; chmod +x "$TL_TMP/rmfail/rm"
jqfail 'resolve_node'
assert_eq "resolve: parent auto-resolve failure does not fail the resolve" 0 "$(PATH="$TL_TMP/rmfail:$PATH" rc sb_instruction_ledger_resolve_item c1 "done" ev)"
jqunstub
assert_eq "auto_resolve: no ledger ok" 0 "$(SB_RUNTIME_STATE_DIR="$TL_TMP/nope" rc sb_instruction_ledger_auto_resolve_parents)"
assert_eq "auto_resolve: no jq ok" 0 "$(PATH="$NOJQ" rc sb_instruction_ledger_auto_resolve_parents)"

tl_results

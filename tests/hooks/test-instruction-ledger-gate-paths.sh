#!/usr/bin/env bash
# Path coverage for hooks/instruction-ledger-gate.sh (UserPromptSubmit seeding + Stop gate).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/instruction-ledger-gate.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/sub" "$TL_TMP/outside"
git -C "$P" init -q -b feature/test 2>/dev/null || true
ST="$SB_RUNTIME_STATE_DIR"
LF="$ST/instruction-ledger.json"
ups() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p}'; }
stop() { jq -cn --arg e "${1:-Stop}" '{hook_event_name:$e}'; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.decision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
PB=$'Please do:\n- one\n- two\n- three\n'
clean() { rm -f "$LF" "$ST"/ups-coalesce-* "$ST"/stop-coalesce-block "$ST/trivial" "$ST/e2e-matrix-routing-row"; }

# --- UserPromptSubmit ------------------------------------------------------
clean
dg_run "$P" "$H" "$(ups "")"
assert_eq "empty prompt: nothing" "" "$TL_OUT"
dg_assert_ok "empty prompt: nothing: exits 0"
assert_file_absent "empty prompt: no ledger" "$LF"
dg_run "$P" "$H" "$(ups $'- a\n- b\n')"
assert_eq "two bullets: no ledger, no output" "" "$TL_OUT"
dg_assert_ok "two bullets: no ledger, no output: exits 0"
dg_run "$P/sub" "$H" "$(ups "$PB")"
assert_contains "three bullets: summary injected" "$(ctx)" "Instruction ledger — unresolved items"
assert_contains "summary lists a leaf" "$(ctx)" "- ["
assert_eq "ledger seeded" 3 "$(jq '.intents[0].children|length' "$LF")"
dg_run "$P" "$H" "$(ups "$PB")"
assert_eq "same turn re-submit is coalesced (event only)" "" "$(ctx)"
clean
S1="$TL_TMP/s1"; dg_stage_hooks "$S1" ups-coalesce.sh stop-coalesce.sh
dg_run "$P" "$S1/hooks/instruction-ledger-gate.sh" "$(ups "$PB")"
assert_contains "no coalesce lib: plain additionalContext" "$(ctx)" "unresolved items"
clean
dg_run "$P" "$H" '{"prompt":"x"}'
assert_eq "missing event name defaults to UserPromptSubmit (too few bullets)" "" "$TL_OUT"
dg_assert_ok "missing event name defaults to UserPromptSubmit (too few bullets): exits 0"
dg_run "$P" "$H" "not json"
assert_eq "unparsable input: defaults, nothing seeded" "" "$TL_OUT"
dg_assert_ok "unparsable input: defaults, nothing seeded: exits 0"
dg_run_closed_stdin "$P" "$H"
assert_eq "unreadable stdin: exits 0" 0 "$TL_STATUS"

# --- guards ------------------------------------------------------------------
dg_run_nojq "$P" "$H" "$(ups "$PB")"
assert_eq "no jq: inert" "" "$TL_OUT"
dg_assert_ok "no jq: inert: exits 0"
rm -f "$ST/project-root"
dg_run "$TL_TMP/outside" "$H" "$(ups "$PB")"
assert_eq "outside an SB project: inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project: inert: exits 0"
dg_run_gate_missing "$P" "$H" "$(ups "$PB")"
assert_eq "project gate unavailable: fails open" "" "$TL_OUT"
dg_assert_ok "project gate unavailable: fails open: exits 0"
dg_run_nolib_in "$P" "$H" "$(ups "$PB")"
assert_eq "no libs: fails open" "" "$TL_OUT"
dg_assert_ok "no libs: fails open: exits 0"
assert_file_absent "no libs: nothing seeded" "$LF"

# --- Stop / SubagentStop --------------------------------------------------------
clean
dg_run "$P" "$H" "$(stop)"
assert_eq "no ledger: Stop allowed" "" "$TL_OUT"
dg_assert_ok "no ledger: Stop allowed: exits 0"
dg_run "$P" "$H" "$(ups "$PB")"
dg_run "$P" "$H" "$(stop)"
assert_eq "unresolved ledger blocks Stop" "block" "$(dec)"
assert_contains "block names the unresolved items" "$TL_OUT" "instruction ledger has unresolved items"
assert_contains "block points to the sanctioned resolver" "$TL_OUT" "resolve-instruction-ledger.sh"
assert_file_exists "block recorded for coalescing" "$ST/stop-coalesce-block"
dg_run "$P" "$H" "$(stop)"
assert_eq "secondary block suppressed once a Stop gate already blocked" "" "$TL_OUT"
dg_assert_ok "secondary block suppressed once a Stop gate already blocked: exits 0"
rm -f "$ST/stop-coalesce-block"
dg_run "$P" "$H" "$(stop SubagentStop)" SB_ORCHESTRATOR_PARENT=0
assert_eq "SubagentStop in a worker session is skipped" "" "$TL_OUT"
dg_assert_ok "SubagentStop in a worker session is skipped: exits 0"
dg_run "$P" "$H" "$(stop SubagentStop)"
assert_eq "SubagentStop in a parent session blocks" "block" "$(dec)"
rm -f "$ST/stop-coalesce-block"
dg_run_nojq "$P" "$H" "$(stop)"
assert_eq "Stop without jq is inert" "" "$TL_OUT"
dg_assert_ok "Stop without jq is inert: exits 0"
: >"$ST/e2e-matrix-routing-row"
dg_run "$P" "$H" "$(stop)"
assert_eq "e2e routing row exempts Stop" "" "$TL_OUT"
dg_assert_ok "e2e routing row exempts Stop: exits 0"
rm -f "$ST/e2e-matrix-routing-row"
: >"$ST/trivial"
dg_run "$P" "$H" "$(stop)"
assert_eq "trivial marker bypasses" "" "$TL_OUT"
dg_assert_ok "trivial marker bypasses: exits 0"
rm -f "$ST/trivial"

# foreign-scope ledger is dropped rather than deadlocking Stop
jq '.scope.branch="other/branch"' "$LF" >"$LF.t" && mv "$LF.t" "$LF"
dg_run "$P" "$H" "$(stop)"
assert_eq "foreign branch ledger does not block" "" "$TL_OUT"
dg_assert_ok "foreign branch ledger does not block: exits 0"
assert_file_absent "foreign ledger removed" "$LF"

# fully resolved ledger lets Stop through
dg_run "$P" "$H" "$(ups "$PB")"
jq '.intents[0].children |= map(.status="done") | .intents[0].status="done"' "$LF" >"$LF.t" && mv "$LF.t" "$LF"
dg_run "$P" "$H" "$(stop)"
assert_eq "resolved ledger: Stop allowed" "" "$TL_OUT"
dg_assert_ok "resolved ledger: Stop allowed: exits 0"
# auto-resolution of the parent when all children are resolved
jq '.intents[0].status="pending"' "$LF" >"$LF.t" && mv "$LF.t" "$LF"
dg_run "$P" "$H" "$(stop)"
assert_eq "all children done: parent auto-resolved, Stop allowed" "" "$TL_OUT"
dg_assert_ok "all children done: parent auto-resolved, Stop allowed: exits 0"
assert_eq "parent marked done" "done" "$(jq -r '.intents[0].status' "$LF")"

# staged copy without coalesce libs: Stop still blocks
clean
dg_run "$P" "$H" "$(ups "$PB")"
dg_run "$P" "$S1/hooks/instruction-ledger-gate.sh" "$(stop)"
assert_eq "no coalesce libs: Stop blocks" "block" "$(dec)"
S2="$TL_TMP/s2"; dg_stage_hooks "$S2" orchestrator-parent.sh instruction-ledger.sh
dg_run "$P" "$S2/hooks/instruction-ledger-gate.sh" "$(stop SubagentStop)" SB_ORCHESTRATOR_PARENT=0
assert_eq "no ledger lib: gate fails open" "" "$TL_OUT"
dg_assert_ok "no ledger lib: gate fails open: exits 0"

# unusable state dir: tolerated, nothing recorded
echo blocker >"$TL_TMP/blocker"
dg_run "$P" "$H" "$(ups "$PB")" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/blocker/sub"
assert_eq "unusable state dir: no ledger, exit 0" 0 "$TL_STATUS"
assert_eq "unusable state dir: no output" "" "$TL_OUT"
dg_assert_ok "unusable state dir: no output: exits 0"

tl_results

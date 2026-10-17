#!/usr/bin/env bash
# Path coverage for hooks/dependency-skill-check.sh (compatibility no-op gate).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/dependency-skill-check.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/sub" "$TL_TMP/outside"
skill() { jq -cn --arg s "$1" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s}}'; }

for s in sb:plan superpowers:brainstorming design:design-critique engineering:code-review product-management:write-spec multai:x code-review clarify test-driven-development systematic-debugging write-spec unknown-skill; do
  dg_run "$P/sub" "$H" "$(skill "$s")"
  assert_eq "skill '$s' is never blocked" "" "$TL_OUT"
  assert_eq "skill '$s' exits 0" 0 "$TL_STATUS"
done
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{}}'
assert_eq "missing skill name: exit 0" 0 "$TL_STATUS"
assert_eq "missing skill name: silent" "" "$TL_OUT"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run "$TL_TMP/outside" "$H" "$(skill sb:plan)"
assert_eq "outside an SB project: silent" "" "$TL_OUT"
mkdir -p "$TL_TMP/gitonly/.git"
dg_run "$TL_TMP/gitonly" "$H" "$(skill sb:plan)"
assert_eq "git root without SB config: silent" "" "$TL_OUT"
dg_run "$P" "$H" "not json"
assert_contains "unparsable input: ERR trap notice" "$TL_OUT" "internal error; continuing without blocking"
assert_eq "unparsable input: exit 0" 0 "$TL_STATUS"
dg_run_nojq "$P" "$H" "$(skill sb:plan)"
assert_contains "no jq: visible warning" "$TL_OUT" "ENFORCEMENT INACTIVE"
dg_run_nolib_in "$P" "$H" "$(skill sb:plan)"
assert_eq "no libs: still a silent no-op" "" "$TL_OUT"
for s in superpowers:x design:y engineering:z product-management:w multai:v code-review write-spec other; do
  dg_run_nolib_in "$P" "$H" "$(skill "$s")"
  assert_eq "no libs: raw skill '$s' passes through silently" "" "$TL_OUT"
done
dg_run_with_fn "$P" "$H" "$(skill sb:plan)" 'sb_project_gate_or_exit() { exit 0; }; export -f sb_project_gate_or_exit'
assert_eq "project gate exit honoured" "" "$TL_OUT"
S1="$TL_TMP/s1"; dg_stage_hooks "$S1" sb-project-gate.sh skill-discovery.sh
dg_run "$P" "$S1/hooks/dependency-skill-check.sh" "$(skill sb:plan)"
assert_eq "no gate/discovery libs: still a silent no-op" "" "$TL_OUT"

tl_results

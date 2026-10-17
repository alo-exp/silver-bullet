#!/usr/bin/env bash
# Path coverage for hooks/uat-gate.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/uat-gate.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning"
skill() { jq -cn --arg s "$1" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s}}'; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$TL_OUT"; }

dg_run "$P" "$H" "$(skill sb:ship)"
assert_eq "non-release skill ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(skill "")"
assert_eq "empty skill ignored" "" "$TL_OUT"

dg_run "$P" "$H" "$(skill sb:release)"
assert_eq "missing UAT.md denies" "deny" "$(dec)"
assert_contains "missing UAT.md reason" "$(reason)" "UAT.md not found"
dg_run "$P" "$H" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skillName:"silver-release"}}')"
assert_eq "skillName alias recognised" "deny" "$(dec)"

HDR='| # | Criterion | Status |
|---|-----------|--------|'
printf '%s\n| 1 | a | PASS |\n| 2 | b | FAIL |\n| 3 | c | FAIL |\n' "$HDR" >"$P/.planning/UAT.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_eq "FAIL rows deny" "deny" "$(dec)"
assert_contains "FAIL count reported" "$(reason)" "2 criterion/criteria marked FAIL"

printf '%s\n| 1 | a | PASS |\n| 2 | b | NOT-RUN |\n' "$HDR" >"$P/.planning/UAT.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_eq "NOT-RUN rows deny" "deny" "$(dec)"
assert_contains "NOT-RUN count reported" "$(reason)" "1 criterion/criteria marked NOT-RUN"
assert_contains "NOT-RUN mentions audited waiver" "$(reason)" "SB OVERRIDE"

printf '| Total | PASS | FAIL | NOT-RUN |\n| 3 | 3 | 0 | 0 |\n%s\n| 1 | a | PASS |\n' "$HDR" >"$P/.planning/UAT.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_eq "all PASS and no spec: allow" "none" "$(dec)"
assert_contains "pass message" "$TL_OUT" "UAT gate passed"

printf -- '---\nspec-version: "1.0"\n---\n| 1 | a | PASS |\n' >"$P/.planning/UAT.md"
printf -- '---\nspec-version: 2.0\n---\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_eq "stale spec version denies" "deny" "$(dec)"
assert_contains "stale spec versions named" "$(reason)" "spec v1.0 but current SPEC.md is v2.0"
printf -- '---\nspec-version: 1.0\n---\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_contains "matching spec versions pass" "$TL_OUT" "UAT gate passed"
printf -- '---\nspec-version: bogus;x\n---\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_contains "invalid spec version skips check" "$TL_OUT" "UAT gate passed"
printf -- '---\nspec-version: 1.0\n---\n' >"$P/.planning/SPEC.md"
printf '| 1 | a | PASS |\n' >"$P/.planning/UAT.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_contains "UAT without version skips check" "$TL_OUT" "UAT gate passed"
printf -- '---\nspec-version: bogus\n---\n| 1 | a | PASS |\n' >"$P/.planning/UAT.md"
printf '# no version\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_contains "SPEC without version skips check" "$TL_OUT" "UAT gate passed"
printf -- '---\nspec-version: 1.0\n---\n| 1 | a | PASS |\n' >"$P/.planning/UAT.md"
dg_run "$P" "$H" "$(skill sb:release)"
assert_contains "UAT version without SPEC version skips check" "$TL_OUT" "UAT gate passed"

mkdir -p "$TL_TMP/outside"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run "$TL_TMP/outside" "$H" "$(skill sb:release)"
assert_eq "outside an SB project: inert" "" "$TL_OUT"

dg_run "$P" "$H" "not json"
assert_contains "unparsable input: ERR trap reports and exits 0" "$TL_OUT" "uat-gate: hook error"
assert_eq "unparsable input exit status" 0 "$TL_STATUS"

# --- jq missing --------------------------------------------------------------
dg_run_nojq "$P" "$H" "$(skill sb:release)"
assert_eq "no jq in an SB project: fail closed" "deny" "$(dec 2>/dev/null || true)"
assert_contains "no jq: static reason when jq cannot encode" "$TL_OUT" "jq required for Silver Bullet enforcement"
dg_run_nolib_in "$P" "$H" "$(skill sb:release)" PATH="$(tl_path_without jq)"
assert_contains "no libs and no jq: visible warning, fail open" "$TL_OUT" "hooks require jq"
dg_run_nolib_in "$P" "$H" "$(skill silver-release)"
assert_contains "no libs: still gates UAT via plain jq" "$TL_OUT" "UAT gate passed"

tl_results

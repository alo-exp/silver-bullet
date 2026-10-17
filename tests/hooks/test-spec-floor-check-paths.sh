#!/usr/bin/env bash
# Extra path coverage for hooks/spec-floor-check.sh: Skill tool events, PostToolUse output
# shape, degraded (library-less) operation and jq-less operation.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/spec-floor-check.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning"
skill_json() { jq -cn --arg e "$1" --arg s "$2" '{hook_event_name:$e,tool_name:"Skill",tool_input:{skill:$s}}'; }
bash_json() { jq -cn --arg e "$1" --arg c "$2" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}'; }

# --- Skill tool: sb:plan hard block -------------------------------------
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "skill sb:plan without SPEC denies" "deny" "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "deny names the missing file" "$TL_OUT" "SPEC.md is missing"
dg_run "$P" "$H" "$(skill_json PostToolUse silver-plan)"
assert_eq "PostToolUse uses decision/block shape" "block" "$(jq -r .decision <<<"$TL_OUT")"
assert_contains "PostToolUse also carries a hook message" "$(jq -r .hookSpecificOutput.message <<<"$TL_OUT")" "SPEC FLOOR VIOLATION"
printf '# Spec\n\n## Overview\n\ntext\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "missing Acceptance Criteria section denied" "$TL_OUT" "## Acceptance Criteria"
printf '# Spec\n\n## Acceptance Criteria\n\nx\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "missing Overview section denied" "$TL_OUT" "## Overview"
printf '# Spec\n\n## Overview\n\nx\n\n## Acceptance Criteria\n\ny\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "complete SPEC allows plan" "" "$TL_OUT"
assert_eq "complete SPEC exits 0" 0 "$TL_STATUS"
rm -f "$P/.planning/SPEC.md"

# --- Skill tool: sb:fast advisory ---------------------------------------
dg_run "$P" "$H" "$(skill_json PreToolUse sb:fast)"
assert_contains "sb:fast without SPEC warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
assert_not_contains "advisory does not deny" "$TL_OUT" "permissionDecision"
printf '# s\n' >"$P/.planning/SPEC.fast.md"
dg_run "$P" "$H" "$(skill_json PreToolUse silver-fast)"
assert_eq "fast spec present => no advisory" "" "$TL_OUT"
rm -f "$P/.planning/SPEC.fast.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:other)"
assert_eq "unrelated skill ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(skill_json PreToolUse "")"
assert_eq "empty skill name ignored" "" "$TL_OUT"

# --- Bash command routing -----------------------------------------------
dg_run "$P" "$H" "$(bash_json PreToolUse 'FOO=1 silver-plan --x')"
assert_contains "env-prefixed silver-plan command is gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse '/sb:plan')"
assert_contains "slash route /sb:plan is gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse '/silver-plan')"
assert_contains "slash route /silver-plan is gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse '/sb:fast')"
assert_contains "slash route /sb:fast warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run "$P" "$H" "$(bash_json PreToolUse '/silver-fast')"
assert_contains "slash route /silver-fast warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run "$P" "$H" "$(bash_json PreToolUse 'silver-fast')"
assert_contains "plain silver-fast command warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run "$P" "$H" "$(bash_json PreToolUse 'grep silver-plan README.md')"
assert_eq "read-only grep mentioning skill ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json PreToolUse 'ls -la')"
assert_eq "unrelated command ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json PreToolUse '')"
assert_eq "empty command ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{file_path:"/x"}}')"
assert_eq "non-shell, non-skill tool ignored" "" "$TL_OUT"

# --- project gate / jq absence ------------------------------------------
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
mkdir -p "$TL_TMP/outside"
dg_run "$TL_TMP/outside" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "outside an SB project the hook is inert" "" "$TL_OUT"
dg_run_nojq "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "no jq => visible enforcement-inactive warning" "$TL_OUT" "ENFORCEMENT INACTIVE"
assert_eq "no jq => exit 0" 0 "$TL_STATUS"

# --- degraded: helper libraries unavailable ------------------------------
dg_run_nolib_in "$P" "$H" "$(skill_json PreToolUse silver-plan)"
assert_contains "no libs: Skill route still gated via jq" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run_nolib_in "$P" "$H" "$(bash_json PreToolUse 'silver-plan')"
assert_contains "no libs: Bash route still gated via jq" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run_nolib_in "$P" "$H" "$(bash_json PreToolUse '/sb:plan')"
assert_contains "no libs: literal /sb:plan slash route still gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run_nolib_in "$P" "$H" "$(bash_json PreToolUse '/sb:fast')"
assert_contains "no libs: literal /sb:fast slash route still warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run_nolib_in "$P" "$H" "$(bash_json PreToolUse '')"
assert_eq "no libs: empty command ignored" "" "$TL_OUT"

tl_results

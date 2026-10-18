#!/usr/bin/env bash
# Path coverage for hooks/forbidden-skill-check.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/forbidden-skill-check.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/sub/deeper"
skill() { jq -cn --arg s "$1" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s}}'; }
dec() { [[ -n "$TL_OUT" ]] && jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$TL_OUT"; }
NS="$(printf '%s%s' gs d)"   # retired namespace, assembled so this file never spells it

dg_run "$P" "$H" "$(skill sb:plan)"
assert_eq "ordinary skill allowed silently" "" "$TL_OUT"
dg_assert_ok "ordinary skill allowed silently: exits 0"
dg_run "$P" "$H" "$(skill "")"
assert_eq "empty skill allowed" "" "$TL_OUT"
dg_assert_ok "empty skill allowed: exits 0"
dg_run "$P" "$H" '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{}}'
assert_eq "missing skill field allowed" "" "$TL_OUT"
dg_assert_ok "missing skill field allowed: exits 0"
dg_run "$P" "$H" "$(skill ":::")"
assert_eq "colon-only skill name matches nothing" "" "$TL_OUT"
dg_assert_ok "colon-only skill name matches nothing: exits 0"

dg_run "$P" "$H" "$(skill "${NS}:plan-phase")"
assert_eq "retired namespace (colon) denied" "deny" "$(dec)"
assert_contains "retired namespace reason" "$(reason)" "lifecycle skills were removed"
dg_run "$P" "$H" "$(skill "${NS}-execute")"
assert_eq "retired namespace (hyphen) denied" "deny" "$(dec)"

dg_run "$P" "$H" "$(skill executing-plans)"
assert_eq "hardcoded forbidden skill denied" "deny" "$(dec)"
assert_contains "hardcoded reason" "$(reason)" "blocked by Silver Bullet"
dg_run "$P" "$H" "$(skill subagent-driven-development)"
assert_eq "second hardcoded skill denied" "deny" "$(dec)"
dg_run "$P" "$H" "$(skill "outer:inner:executing-plans")"
assert_eq "nested namespace prefixes stripped" "deny" "$(dec)"

printf '{"skills":{"forbidden":["", "my-bad-skill"]}}\n' >"$P/.silver-bullet.json"
dg_run "$P/sub/deeper" "$H" "$(skill ns:my-bad-skill)"
assert_eq "config forbidden skill denied (config found from sub-dir)" "deny" "$(dec)"
assert_contains "config reason" "$(reason)" "project configuration"
dg_run "$P" "$H" "$(skill other-skill)"
assert_eq "skill not in config list allowed" "" "$TL_OUT"
dg_assert_ok "skill not in config list allowed: exits 0"
echo 'not json' >"$P/.silver-bullet.json"
dg_run "$P" "$H" "$(skill other-skill)"
assert_eq "unparsable config tolerated" "" "$TL_OUT"
dg_assert_ok "unparsable config tolerated: exits 0"
dg_run "$P" "$H" "$(skill executing-plans)"
assert_eq "hardcoded list still applies with a broken config" "deny" "$(dec)"
echo '{"sb_initiated":true}' >"$P/.silver-bullet.json"

dg_run_closed_stdin "$P" "$H"
dg_assert_ok "unreadable stdin (ERR trap before the skill check): exits 0"
dg_run "$P" "$H" "not json"
assert_contains "unparsable input: ERR trap warns" "$TL_OUT" "unexpected error"
assert_eq "unparsable input exits 0" 0 "$TL_STATUS"

mkdir -p "$TL_TMP/outside"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
dg_run "$TL_TMP/outside" "$H" "$(skill executing-plans)"
assert_eq "outside an SB project: inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project: inert: exits 0"

# project known only through the root cache; the walk from a plain git dir finds no config
dg_run "$P" "$H" "$(skill sb:plan)"
mkdir -p "$TL_TMP/gitonly/.git"
dg_run "$TL_TMP/gitonly" "$H" "$(skill executing-plans)"
assert_eq "cached project, cwd without config: hardcoded list still applies" "deny" "$(dec)"

# --- jq missing ----------------------------------------------------------------
dg_run_nojq "$P" "$H" "$(skill executing-plans)"
assert_eq "no jq in an SB project: deny" "deny" "$(dec)"
assert_contains "no jq: static reason" "$TL_OUT" "jq required for Silver Bullet enforcement"
dg_run_nolib_in "$P" "$H" "$(skill executing-plans)" PATH="$(tl_path_without jq)"
assert_contains "no libs and no jq: visible warning" "$TL_OUT" "ENFORCEMENT INACTIVE"
assert_eq "no libs and no jq: exit 0" 0 "$TL_STATUS"
dg_run_nolib_in "$P" "$H" "$(skill executing-plans)"
assert_eq "no libs: hardcoded list still enforced" "deny" "$(dec)"

tl_results

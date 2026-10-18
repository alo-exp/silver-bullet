#!/usr/bin/env bash
# hooks/lib/enterprise-policy.sh: guard clauses, session-mode defaults, delivery blocking.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL
# shellcheck source=../../hooks/lib/enterprise-policy.sh
source "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh"
# shellcheck source=../../hooks/lib/nofollow-guard.sh
source "$TL_REPO_ROOT/hooks/lib/nofollow-guard.sh"

CFG="$TL_TMP/c.json"
SD="${SB_RUNTIME_STATE_DIR:?}"
profile() { # key json-fields
  printf '{"enterprise_policy":{"active_profile":"%s","profiles":{"%s":%s}}}' "$1" "$1" "${2:-{\}}" >"$CFG"
}
t() { if "$@"; then return 0; else return 1; fi; }
ok() { if t "${@:2}"; then tl_pass "$1"; else tl_fail "$1"; fi; }
nok() { if t "${@:2}"; then tl_fail "$1"; else tl_pass "$1"; fi; }

assert_eq "allowed session modes" "interactive autonomous" "$(sb_enterprise_policy_allowed_session_modes)"

# ---- read_active / profile_field guards -------------------------------------
nok "no config: no active profile" sb_enterprise_policy_read_active ""
nok "missing config file: no active profile" sb_enterprise_policy_read_active "$TL_TMP/absent.json"
printf '{}' >"$CFG"
nok "no profile configured" sb_enterprise_policy_read_active "$CFG"
printf '{"enterprise_policy":{"active_profile":null}}' >"$CFG"
nok "null profile" sb_enterprise_policy_read_active "$CFG"
profile supervised '{"label":"Supervised"}'
nok "jq missing: no active profile" env PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_enterprise_policy_read_active "$2"' _ "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh" "$CFG"
assert_eq "active profile" "supervised" "$(sb_enterprise_policy_read_active "$CFG")"
assert_eq "profile field" "Supervised" "$(sb_enterprise_policy_profile_field "$CFG" supervised label)"
nok "empty config arg" sb_enterprise_policy_profile_field "" supervised label
nok "empty profile arg" sb_enterprise_policy_profile_field "$CFG" "" label
nok "empty field arg" sb_enterprise_policy_profile_field "$CFG" supervised ""
nok "unknown field" sb_enterprise_policy_profile_field "$CFG" supervised nothing
nok "jq missing: no profile field" env PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_enterprise_policy_profile_field "$2" supervised label' _ "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh" "$CFG"

# ---- session mode default ---------------------------------------------------
assert_eq "no profile: interactive" "interactive" "$(sb_enterprise_policy_session_mode_default "$TL_TMP/absent.json")"
profile supervised '{"session_mode_default":"autonomous"}'
assert_eq "autonomous default" "autonomous" "$(sb_enterprise_policy_session_mode_default "$CFG")"
profile supervised '{"session_mode_default":"reckless"}'
assert_eq "unknown mode coerced" "interactive" "$(sb_enterprise_policy_session_mode_default "$CFG")"
profile supervised '{}'
assert_eq "missing mode defaults" "interactive" "$(sb_enterprise_policy_session_mode_default "$CFG")"

# ---- host tier safety -------------------------------------------------------
ok "tier 2 host is safe" sb_enterprise_policy_host_tier_safe "$CFG"
printf '{"enterprise_policy":{"active_profile":"autonomous_safe","profiles":{"autonomous_safe":{"session_mode_default":"autonomous"}}},"sb_enforcement_tier":1}' >"$CFG"
nok "configured tier 1 is not safe" sb_enterprise_policy_host_tier_safe "$CFG"
nok "unsafe tier: no auto session mode" sb_enterprise_policy_should_auto_set_session_mode "$CFG"
ec_stage_hooks "$TL_TMP/notier" enforcement-tier-gate.sh
nok "tier library absent is not safe" bash -c 'source "$1"; sb_enterprise_policy_host_tier_safe "$2"' _ "$TL_TMP/notier/hooks/lib/enterprise-policy.sh" "$CFG"

# ---- auto-set decisions -----------------------------------------------------
printf '{"enterprise_policy":{"active_profile":"autonomous_safe","profiles":{"autonomous_safe":{"session_mode_default":"autonomous"}}}}' >"$CFG"
nok "no config: no auto mode" sb_enterprise_policy_should_auto_set_session_mode "$TL_TMP/absent.json"
ok "autonomous_safe auto-sets autonomous" sb_enterprise_policy_should_auto_set_session_mode "$CFG"
profile supervised '{"session_mode_default":"autonomous"}'
nok "supervised profile never auto-sets" sb_enterprise_policy_should_auto_set_session_mode "$CFG"
profile internal_dogfood '{"session_mode_default":"interactive"}'
nok "dogfood with interactive default: no auto" sb_enterprise_policy_should_auto_set_session_mode "$CFG"

# ---- apply_session_mode_default ---------------------------------------------
M="$TL_TMP/state"
mkdir -p "$M"
printf '{"enterprise_policy":{"active_profile":"autonomous_safe","profiles":{"autonomous_safe":{"session_mode_default":"autonomous"}}}}' >"$CFG"
sb_enterprise_policy_apply_session_mode_default "" "$M"
assert_file_absent "no config: nothing written" "$M/mode"
sb_enterprise_policy_apply_session_mode_default "$CFG" ""
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M"
assert_eq "autonomous profile writes autonomous" "autonomous" "$(cat "$M/mode")"
printf 'autonomous' >"$M/mode"
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" clear
assert_eq "existing autonomous kept" "autonomous" "$(cat "$M/mode")"
printf ' interactive \n' >"$M/mode"
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" startup
assert_eq "interactive choice respected on startup" "interactive" "$(tr -d '[:space:]' <"$M/mode")"
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" clear
assert_eq "clear resets to the profile default" "autonomous" "$(cat "$M/mode")"
printf 'weird' >"$M/mode"
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" startup
assert_eq "unrecognised content is replaced" "autonomous" "$(cat "$M/mode")"
rm -f "$M/mode"
ln -s "$TL_TMP/elsewhere" "$M/mode"
( sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" startup ) 2>/dev/null || true
assert_file_absent "symlinked mode file is not written through" "$TL_TMP/elsewhere"
rm -f "$M/mode"

profile supervised '{"session_mode_default":"interactive"}'
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M"
assert_eq "supervised profile defaults interactive when absent" "interactive" "$(cat "$M/mode")"
printf 'autonomous' >"$M/mode"
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M"
assert_eq "supervised profile keeps an existing mode" "autonomous" "$(cat "$M/mode")"
rm -f "$M/mode"
profile supervised '{"session_mode_default":"autonomous"}'
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M"
assert_file_absent "supervised with autonomous default writes nothing" "$M/mode"
ln -s "$TL_TMP/elsewhere" "$M/mode"
profile supervised '{"session_mode_default":"interactive"}'
( sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" ) 2>/dev/null || true
assert_file_absent "symlink guard on the interactive path" "$TL_TMP/elsewhere"
rm -f "$M/mode"
# without the nofollow guard function the write still happens
bash -c 'source "$1"; sb_enterprise_policy_apply_session_mode_default "$2" "$3"' _ "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh" "$CFG" "$M"
assert_eq "no guard function: interactive written" "interactive" "$(cat "$M/mode")"
rm -f "$M/mode"
printf '{"enterprise_policy":{"active_profile":"autonomous_safe","profiles":{"autonomous_safe":{"session_mode_default":"autonomous"}}}}' >"$CFG"
bash -c 'source "$1"; sb_enterprise_policy_apply_session_mode_default "$2" "$3"' _ "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh" "$CFG" "$M"
assert_eq "no guard function: autonomous written" "autonomous" "$(cat "$M/mode")"
rm -f "$M/mode"

# ---- evidence schema --------------------------------------------------------
nok "evidence strict: no config" sb_enterprise_policy_evidence_schema_strict ""
nok "evidence strict: missing config" sb_enterprise_policy_evidence_schema_strict "$TL_TMP/absent.json"
printf '{}' >"$CFG"
ok "absent hooks key defaults to strict" sb_enterprise_policy_evidence_schema_strict "$CFG"
nok "jq missing: not strict" env PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_enterprise_policy_evidence_schema_strict "$2"' _ "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh" "$CFG"
assert_eq "evidence marker text" "Enterprise policy: evidence_schema_strict active — delivery gates enforce evidence schema (not warn-only)." "$(sb_enterprise_policy_evidence_strict_marker "$CFG")"
printf '{"hooks":{"evidence_schema":{"strict":false}}}' >"$CFG"
assert_eq "relaxed: no marker" "" "$(sb_enterprise_policy_evidence_strict_marker "$CFG")"

# ---- delivery blocking ------------------------------------------------------
profile supervised '{"production_deploy_requires_human":true}'
nok "no config: not blocked" sb_enterprise_policy_delivery_blocked "" "gh pr create"
nok "empty command: not blocked" sb_enterprise_policy_delivery_blocked "$CFG" ""
nok "non-delivery command: not blocked" sb_enterprise_policy_delivery_blocked "$CFG" "git status"
ok "gh pr create blocked" sb_enterprise_policy_delivery_blocked "$CFG" "gh pr create --fill"
ok "gh release create blocked" sb_enterprise_policy_delivery_blocked "$CFG" "gh release create v1"
ok "deploy blocked" sb_enterprise_policy_delivery_blocked "$CFG" "make deploy"
profile supervised '{"production_deploy_requires_human":false}'
nok "human gate disabled: not blocked" sb_enterprise_policy_delivery_blocked "$CFG" "gh pr create"
profile supervised '{"production_deploy_requires_human":true,"non_production_deploy_autonomy":true}'
nok "non-production deploy autonomy allows staging" sb_enterprise_policy_delivery_blocked "$CFG" "deploy to staging"
ok "production deploy still blocked" sb_enterprise_policy_delivery_blocked "$CFG" "deploy to prod"
profile supervised '{"production_deploy_requires_human":true}'
SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1 nok "env approval unblocks" sb_enterprise_policy_delivery_blocked "$CFG" "gh pr create"
ok "marker absent: blocked" sb_enterprise_policy_delivery_blocked "$CFG" "gh pr create"
: >"$(sb_enterprise_policy_human_deploy_marker_file)"
nok "human marker unblocks" sb_enterprise_policy_delivery_blocked "$CFG" "gh pr create"
rm -f "$(sb_enterprise_policy_human_deploy_marker_file)"
ln -s "$TL_TMP/target" "$(sb_enterprise_policy_human_deploy_marker_file)"
ok "symlinked marker is not an approval" sb_enterprise_policy_delivery_blocked "$CFG" "gh pr create"
rm -f "$(sb_enterprise_policy_human_deploy_marker_file)"

msg="$(sb_enterprise_policy_delivery_block_message "$CFG")"
assert_contains "block message names the profile" "$msg" "Profile supervised (supervised)"
assert_contains "block message names the marker" "$msg" "touch $SD/enterprise-human-deploy-approved"
profile supervised '{"label":"Supervised mode"}'
assert_contains "block message uses the label" "$(sb_enterprise_policy_delivery_block_message "$CFG")" "(Supervised mode)"
assert_contains "block message without config" "$(sb_enterprise_policy_delivery_block_message "$TL_TMP/absent.json")" "Profile supervised (supervised)"

# ---- clarify hint, active marker, banner ------------------------------------
profile supervised '{"clarify_auto":true}'
assert_contains "clarify hint" "$(sb_enterprise_policy_clarify_hint_block "$CFG")" "clarify_auto enabled"
profile supervised '{}'
assert_eq "no clarify hint when off" "" "$(sb_enterprise_policy_clarify_hint_block "$CFG")"

sb_enterprise_policy_persist_active_marker "$CFG" ""
profile supervised '{}'
sb_enterprise_policy_persist_active_marker "$CFG" "$M"
assert_eq "active marker written" "supervised" "$(cat "$M/enterprise-policy-active")"
printf '{}' >"$CFG"
sb_enterprise_policy_persist_active_marker "$CFG" "$M"
assert_file_absent "marker removed when no profile is active" "$M/enterprise-policy-active"
profile supervised '{}'
ln -s "$TL_TMP/elsewhere2" "$M/enterprise-policy-active"
( sb_enterprise_policy_persist_active_marker "$CFG" "$M" ) 2>/dev/null || true
assert_file_absent "marker not written through a symlink" "$TL_TMP/elsewhere2"
rm -f "$M/enterprise-policy-active"
assert_eq "default marker dir is the runtime state dir" "supervised" "$(sb_enterprise_policy_persist_active_marker "$CFG" && cat "$SD/enterprise-policy-active")"

printf '{}' >"$CFG"
assert_eq "banner without profile" "" "$(sb_enterprise_policy_session_banner "$CFG" "$M")"
profile supervised '{"label":"Lbl","clarify_auto":true,"session_mode_default":"interactive"}'
printf 'interactive' >"$M/mode"
banner="$(sb_enterprise_policy_session_banner "$CFG" "$M")"
assert_contains "banner profile and label" "$banner" "Enterprise policy profile: supervised (Lbl)"
assert_contains "banner interactive default" "$banner" "Session mode defaulted to interactive (supervised profile)."
assert_contains "banner runtime markers" "$banner" "clarify_auto=on;"
assert_contains "banner evidence marker" "$banner" "evidence_schema_strict=on;"
assert_contains "banner human gate" "$banner" "production_deploy_human_gate=on;"
rm -f "$M/mode"
profile supervised '{"session_mode_default":"autonomous","production_deploy_requires_human":false}'
banner="$(sb_enterprise_policy_session_banner "$CFG" "$M")"
assert_contains "banner recommended mode" "$banner" "Recommended session mode: autonomous."
assert_contains "banner label falls back to the profile name" "$banner" "supervised (supervised)"
assert_not_contains "banner omits the disabled human gate" "$banner" "production_deploy_human_gate"
printf '{"enterprise_policy":{"active_profile":"autonomous_safe","profiles":{"autonomous_safe":{"session_mode_default":"autonomous"}}}}' >"$CFG"
printf 'autonomous' >"$M/mode"
assert_contains "banner after auto-set" "$(sb_enterprise_policy_session_banner "$CFG" "$M")" "Session mode auto-set to autonomous"

# ---- a config that is not JSON ---------------------------------------------
printf '{not json' >"$CFG"
nok "invalid JSON config: no active profile" sb_enterprise_policy_read_active "$CFG"
ok "invalid JSON config: evidence schema fails closed (strict)" sb_enterprise_policy_evidence_schema_strict "$CFG"

tl_results

#!/usr/bin/env bash
# hooks/lib/required-skills.sh: default lists, legacy-config detection and alias handling.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
LIB="$TL_REPO_ROOT/hooks/lib/required-skills.sh"
TEMPLATE="$TL_REPO_ROOT/templates/silver-bullet.config.json.default"
unset SB_DEFAULT_CONFIG
# shellcheck source=../../hooks/lib/required-skills.sh
source "$LIB"

# ---- defaults from the template ---------------------------------------------
assert_eq "planning default from template" "$(jq -r '.skills.required_planning | join(" ")' "$TEMPLATE")" "$DEFAULT_PLANNING"
assert_eq "deploy default from template" "$(jq -r '.skills.required_deploy | join(" ")' "$TEMPLATE")" "$DEFAULT_REQUIRED"
assert_eq "devops planning from template" "$(jq -r '.skills.required_planning_devops | join(" ")' "$TEMPLATE")" "$DEVOPS_DEFAULT_PLANNING"
assert_eq "all-tracked from template" "$(jq -r '(.skills.all_tracked // []) | join(" ")' "$TEMPLATE")" "$DEFAULT_ALL_TRACKED"

# ---- custom default config / fallbacks --------------------------------------
CUSTOM="$TL_TMP/custom.json"
printf '{"config_version":"9.9.9","skills":{"required_planning":["p1","p2"],"required_planning_devops":["dp"],"required_deploy":["d1"],"required_deploy_devops":["dd"],"required_release":["r1"],"required_release_devops":["rd"],"all_tracked":["t1","t2"]}}' >"$CUSTOM"
out="$(SB_DEFAULT_CONFIG="$CUSTOM" bash -c 'source "$1"; printf "%s|%s|%s|%s|%s|%s|%s" "$DEFAULT_PLANNING" "$DEVOPS_DEFAULT_PLANNING" "$DEFAULT_REQUIRED" "$DEVOPS_DEFAULT_REQUIRED" "$DEFAULT_RELEASE_REQUIRED" "$DEVOPS_DEFAULT_RELEASE_REQUIRED" "$DEFAULT_ALL_TRACKED"' _ "$LIB")"
assert_eq "env override config populates every list" "p1 p2|dp|d1|dd|r1|rd|t1 t2" "$out"
out="$(SB_DEFAULT_CONFIG="$CUSTOM" bash -c 'source "$1"; __sb_rs_default_version' _ "$LIB")"
assert_eq "default version read" "9.9.9" "$out"

# an empty config falls back to the built-ins
printf '{}' >"$TL_TMP/empty.json"
out="$(SB_DEFAULT_CONFIG="$TL_TMP/empty.json" bash -c 'source "$1"; printf "%s|%s|%s|%s|%s|%s|%s" "$DEFAULT_PLANNING" "$DEVOPS_DEFAULT_PLANNING" "$DEFAULT_REQUIRED" "$DEVOPS_DEFAULT_REQUIRED" "$DEFAULT_RELEASE_REQUIRED" "$DEVOPS_DEFAULT_RELEASE_REQUIRED" "$DEFAULT_ALL_TRACKED"' _ "$LIB")"
assert_eq "empty config: built-in fallbacks" "silver-quality-gates silver-context silver-plan|silver-blast-radius devops-quality-gates silver-context silver-plan|silver-quality-gates silver-completion-audit verify-tests|silver-quality-gates silver-completion-audit verify-tests|silver-create-release|silver-create-release|silver-quality-gates silver-quality-gates-design silver-quality-gates-adversarial verify-tests" "$out"
# no jq: every lookup fails, fallbacks apply
NOJQ="$(tl_path_without jq)"
out="$(PATH="$NOJQ" bash -c 'source "$1"; printf "%s" "$DEFAULT_PLANNING"; __sb_rs_load_all_tracked || printf " tracked-fail"; __sb_rs_default_version || printf " version-fail"' _ "$LIB")"
assert_eq "no jq: fallback planning, failing lookups" "silver-quality-gates silver-context silver-plan tracked-fail version-fail" "$out"
# the library copy without the templates directory next to it finds no default config
mkdir -p "$TL_TMP/isolated/hooks/lib"
cp "$LIB" "$TL_TMP/isolated/hooks/lib/required-skills.sh"
out="$(bash -c 'source "$1"; printf "%s" "$DEFAULT_PLANNING"; __sb_rs_find_default_config || printf " no-config"' _ "$TL_TMP/isolated/hooks/lib/required-skills.sh")"
assert_eq "no adjacent template: fallback planning" "silver-quality-gates silver-context silver-plan no-config" "$out"

# ---- version comparison -----------------------------------------------------
lt() { __sb_rs_version_lt "$1" "$2"; }
if lt 0.9.0 0.10.0; then tl_pass "0.9.0 < 0.10.0"; else tl_fail "0.9.0 < 0.10.0"; fi
if lt 1.0.0 1.0.0; then tl_fail "equal versions are not less"; else tl_pass "equal versions are not less"; fi
if lt 2.0.0 1.9.9; then tl_fail "2.0.0 is not < 1.9.9"; else tl_pass "2.0.0 is not < 1.9.9"; fi
if lt 1.2.3 1.2.4; then tl_pass "patch comparison"; else tl_fail "patch comparison"; fi
if lt "" 1.0.0; then tl_fail "empty left"; else tl_pass "empty left"; fi
if lt 1.0.0 ""; then tl_fail "empty right"; else tl_pass "empty right"; fi
assert_eq "version part strips suffix" "3" "$(__sb_rs_version_part 1.2.3-rc1 3)"
assert_eq "missing version part is 0" "0" "$(__sb_rs_version_part 1.2 3)"

# ---- legacy detection -------------------------------------------------------
CFG="$TL_TMP/proj.json"
legacy() { sb_required_skills_config_is_legacy "$1"; }
if legacy ""; then tl_fail "no config is not legacy"; else tl_pass "no config is not legacy"; fi
if legacy "$TL_TMP/absent.json"; then tl_fail "missing config is not legacy"; else tl_pass "missing config is not legacy"; fi
printf '{}' >"$CFG"
if legacy "$CFG"; then tl_pass "config without a version is legacy"; else tl_fail "config without a version is legacy"; fi
printf '{"version":"0.0.1"}' >"$CFG"
if legacy "$CFG"; then tl_pass "old .version is legacy"; else tl_fail "old .version is legacy"; fi
printf '{"config_version":"99.0.0"}' >"$CFG"
if legacy "$CFG"; then tl_fail "newer config is not legacy"; else tl_pass "newer config is not legacy"; fi
if PATH="$NOJQ" bash -c 'source "$1"; sb_required_skills_config_is_legacy "$2"' _ "$LIB" "$CFG"; then tl_fail "no jq: not legacy"; else tl_pass "no jq: not legacy"; fi
if SB_DEFAULT_CONFIG="$TL_TMP/empty.json" bash -c 'source "$1"; sb_required_skills_config_is_legacy "$2"' _ "$LIB" "$CFG"; then tl_fail "no default version: not legacy"; else tl_pass "no default version: not legacy"; fi

# ---- aliases and recorded checks --------------------------------------------
assert_eq "plain skill is its own alias" "silver-verify" "$(sb_required_skill_aliases silver-verify | tr '\n' ' ' | sed 's/ $//')"
assert_eq "tdd aliases" "silver-tdd tdd test-driven-development" "$(sb_required_skill_aliases silver-tdd | tr '\n' ' ' | sed 's/ $//')"
assert_eq "plan alias" "silver-plan writing-plans" "$(sb_required_skill_aliases silver-plan | tr '\n' ' ' | sed 's/ $//')"
for pair in "silver-review:code-review" "silver-secure:security" "silver-debug:systematic-debugging" "silver-review-request:requesting-code-review" "silver-review-triage:receiving-code-review" "silver-branch-finish:finishing-a-development-branch" "silver-completion-audit:verification-before-completion"; do
  assert_contains "alias of ${pair%%:*}" "$(sb_required_skill_aliases "${pair%%:*}")" "${pair#*:}"
done
if sb_required_skill_is_virtual_marker silver-plan; then tl_pass "virtual marker"; else tl_fail "virtual marker"; fi
if sb_required_skill_is_virtual_marker random-skill; then tl_fail "not a virtual marker"; else tl_pass "not a virtual marker"; fi
STATE=$'code-review\nother\n'
if sb_required_skill_is_recorded "$STATE" silver-review; then tl_pass "alias satisfies the requirement"; else tl_fail "alias satisfies the requirement"; fi
if sb_required_skill_is_recorded "$STATE" silver-verify; then tl_fail "unrecorded skill"; else tl_pass "unrecorded skill"; fi
assert_eq "earliest alias line wins" "2" "$(sb_required_skill_line $'x\nsilver-plan\nwriting-plans\n' silver-plan)"
assert_eq "no match: line 0" "0" "$(sb_required_skill_line $'x\n' silver-plan)"

# ---- filtering and normalising ----------------------------------------------
retired_ns_hyphen="gsd-thing"
retired_ns_colon="gsd:thing"
assert_eq "retired names, namespaces and blanks are dropped" "keep-me also-keep" "$(sb_required_skills_filter_retired keep-me code-review "" "$retired_ns_hyphen" "$retired_ns_colon" documentation also-keep)"
assert_eq "dedupe preserves order and skips blanks" "a b c" "$(sb_required_skills_dedupe a "" b a c b)"
assert_eq "empty configured list uses defaults" "x y" "$(sb_required_skills_normalize_configured_list "$CFG" "" "x y")"
assert_eq "current config keeps its own list" "mine" "$(sb_required_skills_normalize_configured_list "$CFG" "mine" "x y")"
printf '{}' >"$CFG"
assert_eq "legacy config: defaults first, retired names filtered, duplicates removed" "x y mine" "$(sb_required_skills_normalize_configured_list "$CFG" "mine code-review x" "x y")"

tl_results

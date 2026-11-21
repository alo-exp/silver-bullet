#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh: library farms, injected faults, debug log
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

# ------------------------------------------------- lib farms and injected faults
reset; tg2_farm farm-noguard "$HOOK" nofollow-guard.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "without nofollow-guard.sh the inline guard still lets records through" "$STATE" silver-plan
reset; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$STATE"
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_contains "inline fallback guard refuses a symlinked state file" "$TL_ERR" "refusing to write through symlink"
assert_eq "inline fallback guard exits non-zero" "1" "$TL_STATUS"
assert_eq "inline fallback guard never writes through the link" "" "$(<"$TL_TMP/target")"
rm -f "$STATE"
reset; tg2_farm farm-nolib "$HOOK" -
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_eq "missing lib dir: hook exits 0" "0" "$TL_STATUS"
assert_in "missing lib dir: tracked skills still record via the template and jq fallbacks" "$STATE" silver-plan
reset; tg2_farm farm-notoolinput "$HOOK" tool-input.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "jq fallbacks work without tool-input.sh (Skill)" "$STATE" silver-plan
reset; TG2_REPO="$TG2_FARM" rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')"
assert_eq "without tool-input.sh a Bash payload is not shell-like (nothing recorded)" "$NOTHING" "$(msg)"
reset; tg2_farm farm-nodisc "$HOOK" skill-discovery.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input legacy:plugin:silver-plan)"
assert_in "without skill-discovery.sh namespaces are stripped by sed" "$STATE" silver-plan
reset; tg2_farm farm-norequired "$HOOK" required-skills.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "without required-skills.sh the tracked list is read from the template" "$STATE" silver-plan
reset; tg2_farm farm-notemplate "$HOOK" required-skills.sh
rm -f "$TG2_FARM/templates"
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)"
assert_in "without library and template the built-in fallback list is used" "$STATE" silver-quality-gates
rm -f "$STATE"
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_not_in "built-in fallback list is minimal" "$STATE" silver-plan
reset; tg2_farm farm-badtemplate "$HOOK" required-skills.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)" JQ_FAIL='silver-bullet.config.json.default'
assert_in "unreadable template falls back to the built-in tracked list" "$STATE" silver-quality-gates
reset; tg2_farm farm-nohookout "$HOOK" hook-output.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_file_exists "missing hook-output.sh: skill still recorded" "$STATE"

# bash functions can be exported: make the hook's own `cd <dir>/..` probe fail. This pins the
# documented degraded mode: when the repo dir cannot be resolved the hook has no template to
# read, so only the built-in minimal list (silver-quality-gates and its mode markers,
# verify-tests) is tracked; every other skill is silently untracked.
cd_fail='cd() { if [[ "${1:-}" == */.. && "${BASH_SOURCE[1]:-}" == *record-skill.sh ]]; then return 1; fi; builtin cd "$@"; }'
reset; tg2_farm farm-cdfail "$HOOK" required-skills.sh
( eval "$cd_fail"; export -f cd; TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)" )
assert_in "unresolvable repo dir falls back to the built-in tracked list" "$STATE" silver-quality-gates
rm -f "$STATE"
( eval "$cd_fail"; export -f cd; TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)" )
assert_not_in "the built-in fallback list does not include other skills" "$STATE" silver-plan

# debug log
reset; rs "$(skill_input silver-plan)" SILVER_BULLET_DEBUG_RECORD_SKILL=1
DBG="$SB_RUNTIME_STATE_DIR/record-skill.debug.log"
assert_file_exists "debug mode writes the debug log" "$DBG"
assert_in "debug mode still records the skill" "$STATE" silver-plan
assert_contains "debug log carries the skill" "$(lines "$DBG")" "raw_skill=silver-plan"
assert_contains "debug log lists the skills to record" "$(lines "$DBG")" "skills_to_record=silver-plan"
assert_contains "debug log carries the config file" "$(lines "$DBG")" "config_file=$TG2_CFG"
reset; rs "$(skill_input silver-plan)"
assert_file_absent "no debug log unless enabled" "$DBG"
reset; : >"$TL_TMP/afile2"
rs "$(skill_input silver-plan)" SILVER_BULLET_DEBUG_RECORD_SKILL=1 SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/afile2/.silver-bullet"
assert_eq "an unwritable debug log never breaks the hook" "0" "$TL_STATUS"
assert_file_absent "unwritable debug log is not created" "$TL_TMP/afile2/.silver-bullet/record-skill.debug.log"

tl_results

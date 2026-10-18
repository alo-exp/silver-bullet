#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh: recording, tracked lists, quality-gates markers, SKILL.md reads
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

# ===================================================== recording completed skills
reset; rs "$(skill_input silver-context)"
assert_eq "tracked skill: status" "0" "$TL_STATUS"
assert_eq "tracked skill: message" "$RECORDED" "$(msg)"
assert_in "tracked skill is appended to the state file" "$STATE" silver-context
reset; rs "$(skill_input silver-context)"; rs "$(skill_input silver-context)"
assert_eq "re-recording a skill is reported as nothing new" "$NOTHING" "$(msg)"
assert_eq "re-recording does not duplicate the state line" "1" "$(grep -Fxc silver-context "$STATE")"
reset; rs "$(skill_input some-untracked-skill)"
assert_eq "untracked skill is reported as nothing recorded" "$NOTHING" "$(msg)"
assert_file_absent "untracked skill creates no state file" "$STATE"
reset; rs "$(skill_input plugin:ns:silver-plan)"
assert_in "namespace prefixes are stripped" "$STATE" silver-plan
reset; rs "$(skill_input sb:feature)"
assert_in "sb:feature is canonicalised to silver-feature" "$STATE" silver-feature
reset; rs "$(skill_input silver-tdd)"
assert_in "silver-tdd is recorded as the canonical tdd marker" "$STATE" tdd
reset; rs "$(skill_input test-driven-development)"
assert_in "test-driven-development is recorded as the canonical tdd marker" "$STATE" tdd
reset; jq '.skills.all_tracked=["my-custom-skill"]' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input my-custom-skill)"
assert_in "custom tracked skills from the project config are recorded" "$STATE" my-custom-skill
rs "$(skill_input silver-plan)"
assert_in "custom tracked skills are additive to the packaged defaults" "$STATE" silver-plan

# --------------------------------------------------- quality-gates mode markers
reset; rs "$(skill_input silver-quality-gates)"
assert_in "silver-quality-gates is recorded" "$STATE" silver-quality-gates
assert_in "pre-plan quality gates add the design marker" "$STATE" silver-quality-gates-design
reset; mkdir -p "$TG2_PROJ/.planning"
printf '# Plan\n\nreal body\n' >"$TG2_PROJ/.planning/PLAN.md"
printf '# Verification\n\nstatus: passed\n' >"$TG2_PROJ/.planning/VERIFICATION.md"
rs "$(skill_input silver-quality-gates)"
assert_in "verified plan switches quality gates to adversarial mode" "$STATE" silver-quality-gates-adversarial
reset; rs "$(skill_input devops-quality-gates)"
assert_in "devops quality gates add the devops design marker" "$STATE" devops-quality-gates-design
reset; mkdir -p "$TG2_PROJ/.planning"
printf '# Plan\n\nreal body\n' >"$TG2_PROJ/.planning/PLAN.md"
printf '# Verification\n\nstatus: passed\n' >"$TG2_PROJ/.planning/VERIFICATION.md"
rs "$(skill_input devops-quality-gates)"
assert_in "devops quality gates add the adversarial marker when verified" "$STATE" devops-quality-gates-adversarial
reset; rm -f "$TG2_CFG" "$TG2_PROJ/silver-bullet.md"; mkdir -p "$TL_TMP/outside/.planning"
printf '# Plan\n\nreal body\n' >"$TL_TMP/outside/.planning/PLAN.md"
printf '# Verification\n\nstatus: passed\n' >"$TL_TMP/outside/.planning/VERIFICATION.md"
TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" rs "$(skill_input silver-quality-gates)"
assert_in "without a project config quality-gates mode is read from the cwd" "$STATE" silver-quality-gates-adversarial
rm -f "$STATE"
TG2_CWD="$TL_TMP/outside" TG2_PROJECT_ROOT="" rs "$(skill_input devops-quality-gates)"
assert_in "without a project config devops mode is read from the cwd" "$STATE" devops-quality-gates-adversarial
printf '# Silver Bullet\n' >"$TG2_PROJ/silver-bullet.md"
reset; tg2_farm no-qg "$HOOK" quality-gates-mode.sh
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-quality-gates)"
assert_in "without the mode library the plain marker is still recorded" "$STATE" silver-quality-gates
assert_not_in "without the mode library no mode marker is added" "$STATE" silver-quality-gates-design
TG2_REPO="$TG2_FARM" rs "$(skill_input devops-quality-gates)"
assert_not_in "without the mode library no devops mode marker is added" "$STATE" devops-quality-gates-design

# ------------------------------------------------------------- SKILL.md reads
reset; rs "$(bash_input 'cat /plugins/silver-bullet/skills/silver-plan/SKILL.md')"
assert_eq "reading SKILL.md is not a completed skill" "$NOTHING" "$(msg)"
assert_in "reading SKILL.md records loaded-only metadata" "$LOADED" silver-plan
assert_file_absent "reading SKILL.md leaves the completed state untouched" "$STATE"
rs "$(bash_input 'cat /p/skills/silver-plan/SKILL.md')"
assert_eq "loaded marker is not duplicated" "1" "$(grep -Fxc silver-plan "$LOADED")"
reset; rs "$(bash_input 'head -5 "/x/skills/silver-context/SKILL.md"; tail (/y/skills/silver-plan/SKILL.md)' exec_command)"
assert_in "double-quoted/parenthesised SKILL.md tokens are normalised" "$LOADED" silver-context
assert_in "parenthesised token is normalised" "$LOADED" silver-plan
reset; rs "$(bash_input "cat '/x/skills/silver-feature/SKILL.md'")"
assert_in "single-quoted SKILL.md token is normalised" "$LOADED" silver-feature
reset; rs "$(bash_input 'cat /x/skills/not-tracked-thing/SKILL.md')"
assert_file_absent "untracked skill reads are not recorded as loaded" "$LOADED"
reset; rs "$(bash_input 'cat ./SKILL.md')"
assert_file_absent "SKILL.md outside a skills/<name>/ dir is ignored" "$LOADED"
reset; rs "$(bash_input 'echo SKILL.md')"
assert_eq "a bare SKILL.md mention (no message)" "" "$TL_OUT"
reset; rs "$(bash_input 'ls -la')"
assert_eq "an ordinary shell command (no message)" "" "$TL_OUT"
reset; rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md' Read)"
assert_eq "non-shell tools without a skill name record nothing (no message)" "" "$TL_OUT"

tl_results

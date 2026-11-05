#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh: project discovery, state-file wiring and symlink refusal
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

# --------------------------------------------------------- project / state wiring
reset; tg2_farm inactive "$HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_active() { return 1; }'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_file_absent "inactive project records nothing" "$STATE"
reset; tg2_farm uninit "$HOOK" project-active.sh
tg2_farm_stub project-active.sh 'sb_project_is_initiated() { return 1; }'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_file_absent "uninitiated project (legacy gate) records nothing" "$STATE"
reset; tg2_farm nogatefn "$HOOK" project-active.sh
tg2_farm_stub project-active.sh ':'
TG2_REPO="$TG2_FARM" rs "$(skill_input silver-plan)"
assert_in "no gate function means no gating" "$STATE" silver-plan
reset; TG2_CWD="$TG2_PROJ/src" TG2_PROJECT_ROOT="" rs "$(skill_input silver-plan)"
assert_in "walk-up finds the config from a subdirectory" "$STATE" silver-plan
reset; rm -f "$TG2_CFG"; mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q 2>/dev/null
TG2_CWD="$TL_TMP/gitonly/sub" TG2_PROJECT_ROOT="" rs "$(skill_input silver-plan)"
assert_in "no project config: skills still record to the default state" "$STATE" silver-plan
reset; jq --arg p "$SB_RUNTIME_STATE_DIR/cfg-state" '.state.state_file=$p' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input silver-plan)"
assert_in "config state_file is honoured" "$SB_RUNTIME_STATE_DIR/cfg-state" silver-plan
rm -f "$SB_RUNTIME_STATE_DIR/cfg-state"
reset; jq --arg p "~${SB_RUNTIME_STATE_DIR#"$HOME"}/tilde-state" '.state.state_file=$p' <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input silver-plan)"
assert_in "tilde in config state_file expands to HOME" "$SB_RUNTIME_STATE_DIR/tilde-state" silver-plan
rm -f "$SB_RUNTIME_STATE_DIR/tilde-state"
reset; jq '.state.state_file=$p' --arg p "$TL_TMP/outside-state-root" <<<"$BASE_CFG" >"$TG2_CFG"
rs "$(skill_input silver-plan)"
assert_in "state file outside the runtime root falls back to the default" "$STATE" silver-plan
assert_file_absent "out-of-scope state path is never written" "$TL_TMP/outside-state-root"
reset; rs "$(skill_input silver-plan)" SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/env-state"
assert_in "SILVER_BULLET_STATE_FILE overrides the config" "$SB_RUNTIME_STATE_DIR/env-state" silver-plan
rm -f "$SB_RUNTIME_STATE_DIR/env-state"
reset; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$STATE"
rs "$(skill_input silver-plan)"
assert_eq "symlinked state file is refused with exit status 1" "1" "$TL_STATUS"
assert_eq "symlink target is never written" "" "$(<"$TL_TMP/target")"
assert_contains "symlink refusal is reported on stderr" "$TL_ERR" "refusing to write through symlink"
rm -f "$STATE"
reset; : >"$TL_TMP/target"; ln -s "$TL_TMP/target" "$LOADED"
rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')"
assert_eq "symlinked loaded file is never written through" "" "$(<"$TL_TMP/target")"
rm -f "$LOADED"
reset; : >"$SB_RUNTIME_STATE_DIR/afile"
rs "$(skill_input silver-plan)" SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/afile/state"
assert_eq "uncreatable state dir fails open (completed path)" "0" "$TL_STATUS"
assert_eq "uncreatable state dir emits no message" "" "$TL_OUT"
rs "$(bash_input 'cat /x/skills/silver-plan/SKILL.md')" SILVER_BULLET_STATE_FILE="$SB_RUNTIME_STATE_DIR/afile/state"
assert_eq "uncreatable state dir fails open (loaded path)" "0" "$TL_STATUS"
rm -f "$SB_RUNTIME_STATE_DIR/afile"
reset; : >"$TL_TMP/afile"
rs "$(skill_input silver-plan)" SB_RUNTIME_PRESERVE_STATE_DIR=1 SB_RUNTIME_STATE_DIR="$TL_TMP/afile/.silver-bullet"
assert_eq "uncreatable runtime state dir fails open" "0" "$TL_STATUS"

tl_results

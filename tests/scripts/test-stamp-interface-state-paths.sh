#!/usr/bin/env bash
# scripts/stamp-interface-state.sh: UI detection signals, template lookup, force/exists handling.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/stamp-interface-state.sh"
PROJ="$TL_TMP/proj"
fresh() { rm -rf "$PROJ"; mkdir -p "$PROJ"; }
DEST="$PROJ/.planning/interface/STATE.md"

# --- detection signals (script's own template used) ---
fresh; echo '{"project":{"tech_stack":"Node / Svelte","active_workflow":"x"}}' >"$PROJ/.silver-bullet.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "tech_stack match stamps" 0 "$TL_STATUS"
assert_eq "tech_stack match output" "stamped:$DEST" "$TL_OUT"
assert_contains "template content copied from repo template" "$(cat "$DEST")" "Design Tokens"

fresh; echo '{"project":{"tech_stack":"Go","active_workflow":"silver-ui"}}' >"$PROJ/.silver-bullet.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "ui workflow stamps even for non-UI stack" "stamped:$DEST" "$TL_OUT"

fresh; echo '{"project":{"tech_stack":"Go","active_workflow":"full-dev-cycle"}}' >"$PROJ/.silver-bullet.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "non-UI stack and workflow skips" "skip:not-ui-project" "$TL_OUT"
assert_file_absent "nothing stamped when skipped" "$DEST"

fresh; echo '{"dependencies":{"vue":"3"}}' >"$PROJ/package.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "package.json framework stamps (no config)" "stamped:$DEST" "$TL_OUT"

fresh; echo '{"dependencies":{"left-pad":"1"}}' >"$PROJ/package.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "package.json without UI framework skips" "skip:not-ui-project" "$TL_OUT"

# unreadable / invalid config: jq failure is tolerated, package.json still decides
fresh; echo '{broken' >"$PROJ/.silver-bullet.json"; echo '{"dependencies":{"next":"1"}}' >"$PROJ/package.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "invalid config tolerated, package.json decides" "stamped:$DEST" "$TL_OUT"
fresh; echo '{broken' >"$PROJ/.silver-bullet.json"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "invalid config alone skips" "skip:not-ui-project" "$TL_OUT"

# jq missing behaves like unreadable config
fresh; echo '{"project":{"tech_stack":"React"}}' >"$PROJ/.silver-bullet.json"
PATH="$(tl_path_without jq)" tl_run bash "$SCRIPT" "$PROJ"
assert_eq "no jq: React in config is not seen" "skip:not-ui-project" "$TL_OUT"

# --- existing STATE.md and FORCE ---
fresh; echo '{"project":{"tech_stack":"React"}}' >"$PROJ/.silver-bullet.json"
mkdir -p "$PROJ/.planning/interface"; echo "custom" >"$DEST"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "existing STATE.md kept" "skip:exists" "$TL_OUT"
assert_eq "existing STATE.md content untouched" "custom" "$(cat "$DEST")"
SILVER_BULLET_FORCE_INTERFACE_STATE=1 tl_run bash "$SCRIPT" "$PROJ"
assert_eq "FORCE=1 overwrites" "stamped:$DEST" "$TL_OUT"
assert_contains "overwritten with template" "$(cat "$DEST")" "Design Tokens"
echo custom >"$DEST"
SILVER_BULLET_FORCE_INTERFACE_STATE=0 tl_run bash "$SCRIPT" "$PROJ"
assert_eq "FORCE=0 keeps existing" "skip:exists" "$TL_OUT"

# --- template lookup: project template wins; missing everywhere is an error ---
fresh; echo '{"project":{"tech_stack":"React"}}' >"$PROJ/.silver-bullet.json"
mkdir -p "$PROJ/templates/interface"; echo "PROJECT TEMPLATE" >"$PROJ/templates/interface/STATE.md.base"
tl_run bash "$SCRIPT" "$PROJ"
assert_eq "project template used" "PROJECT TEMPLATE" "$(cat "$DEST")"

mkdir -p "$TL_TMP/fx/scripts"; cp "$SCRIPT" "$TL_TMP/fx/scripts/"
fresh; echo '{"project":{"tech_stack":"React"}}' >"$PROJ/.silver-bullet.json"
tl_run bash "$TL_TMP/fx/scripts/stamp-interface-state.sh" "$PROJ"
assert_eq "no template anywhere fails" 1 "$TL_STATUS"
assert_eq "template-missing message" "error:template-missing" "$TL_ERR"
assert_file_absent "no STATE.md written without a template" "$DEST"
assert_file_absent "no interface dir created without a template" "$PROJ/.planning/interface"

# default target is the current directory
fresh; echo '{"project":{"tech_stack":"React"}}' >"$PROJ/.silver-bullet.json"
cd "$PROJ"
tl_run bash "$SCRIPT"
assert_eq "defaults to PWD" "stamped:$PROJ/.planning/interface/STATE.md" "$TL_OUT"

tl_results

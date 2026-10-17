#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are consumed by the sourcing tests
# shellcheck shell=bash

HOOK="$TL_REPO_ROOT/hooks/dev-cycle-check.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

SKILLS="$TL_TMP/skills"
for s in inst-a inst-b; do
  mkdir -p "$SKILLS/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done
STATE="$SB_RUNTIME_STATE_DIR/state-test"
BRANCHF="$SB_RUNTIME_STATE_DIR/branch-test"
export SILVER_BULLET_STATE_FILE="$STATE"
export SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_BRANCH_FILE="$BRANCHF"
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test"

_dc_tpl() {
  if [[ -z "${_DC_TPL:-}" ]]; then
    _DC_TPL="$TL_TMP/.tpl"
    tl_git_repo "$_DC_TPL"
    mkdir -p "$_DC_TPL/src"
    : >"$_DC_TPL/src/app.js"
  fi
}
# mkproj <name> [jq filter]: SB project with a git repo, src/ files and a config.
mkproj() {
  PROJ="$TL_TMP/$1"
  _dc_tpl
  cp -a "$_DC_TPL" "$PROJ"
  printf '# SB\n' >"$PROJ/silver-bullet.md"
  jq -n --arg v "$CFG_VERSION" "{config_version:\$v, sb_initiated:true,
      project:{src_pattern:\"/src/\", active_workflow:\"full-dev-cycle\"},
      skills:{required_planning:[\"inst-a\"], required_deploy:[\"inst-a\",\"inst-b\"]}} | ${2:-.}" >"$PROJ/.silver-bullet.json"
  : >"$STATE"
  printf 'feature/test\n' >"$BRANCHF"
  rm -f "$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
}
state() { printf '%s\n' "$@" >"$STATE"; }

# run_dc <json> [env...]: run the hook in $PROJ.
run_dc() {
  local json="$1"
  shift
  tl_run_stdin "$json" env "$@" bash -c 'cd "$1" && exec bash "${HOOK_UNDER_TEST:-$2}"' _ "${RUN_DIR:-$PROJ}" "$HOOK"
}
edit_json() { jq -cn --arg e "${3:-PreToolUse}" --arg f "$1" --arg t "${2:-Edit}" --arg o "${4:-}" --arg n "${5:-}" \
  '{hook_event_name:$e,tool_name:$t,tool_input:({file_path:$f}+(if $o!="" then {old_string:$o,new_string:$n} else {} end))}'; }
bash_json() { jq -cn --arg e "${2:-PreToolUse}" --arg c "$1" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}'; }
# The hook can print several JSON objects (advisories, then a verdict): judge by the last one
# and search all messages.
decision() {
  if [[ -z "$TL_OUT" ]]; then echo none; return; fi
  jq -rs 'last | if .hookSpecificOutput.permissionDecision then .hookSpecificOutput.permissionDecision
         elif .decision then .decision else "allow" end' <<<"$TL_OUT" 2>/dev/null || echo invalid
}
message() { jq -rs 'map(.reason // .hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // "") | join("\n")' <<<"$TL_OUT"; }
BIG_OLD="$(printf 'x%.0s' {1..80})"
BIG_NEW="$(printf 'y%.0s' {1..80})"

PATCH_SRC=$'*** Begin Patch\n*** Update File: src/app.js\n@@\n-a\n+b\n*** End Patch'
NOCFG="$TL_TMP/nocfg"; tl_git_repo "$NOCFG"; mkdir -p "$NOCFG/src"
dc_cmd() { run_dc "$(bash_json "$1" "${2:-PreToolUse}")" "${@:3}"; }
edit() { run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"; }

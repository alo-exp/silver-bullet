#!/usr/bin/env bash
# hooks/dev-cycle-check.sh: jq-less blocking, lib-less fallbacks, plugin/state protection,
# config validation, shell write detection and the four-stage planning gate.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

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

# mkproj <name> [jq filter]: SB project with a git repo, src/ files and a config.
mkproj() {
  PROJ="$TL_TMP/$1"
  tl_git_repo "$PROJ"
  mkdir -p "$PROJ/src"
  : >"$PROJ/src/app.js"
  printf '# SB\n' >"$PROJ/silver-bullet.md"
  jq -n --arg v "$CFG_VERSION" '{config_version:$v, sb_initiated:true,
      project:{src_pattern:"/src/", active_workflow:"full-dev-cycle"},
      skills:{required_planning:["inst-a"], required_deploy:["inst-a","inst-b"]}}' \
    | jq "${2:-.}" >"$PROJ/.silver-bullet.json"
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
decision() {
  if [[ -z "$TL_OUT" ]]; then echo none; return; fi
  jq -r 'if .hookSpecificOutput.permissionDecision then .hookSpecificOutput.permissionDecision
         elif .decision then .decision else "allow" end' <<<"$TL_OUT" 2>/dev/null || echo invalid
}
message() { jq -r '.reason // .hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // ""' <<<"$TL_OUT"; }
BIG_OLD="$(printf 'x%.0s' {1..80})"
BIG_NEW="$(printf 'y%.0s' {1..80})"

# ── jq missing ───────────────────────────────────────────────────────────────
mkproj nojq
NOJQ="$(tl_path_without jq)"
run_dc "$(edit_json "$PROJ/src/app.js")" PATH="$NOJQ"
assert_eq "no jq in an initiated project: edit is denied" "deny" "$(decision)"
assert_contains "jq-less denial explains the cause" "$(message)" "jq is required"
assert_eq "jq-less denial exits 0" 0 "$TL_STATUS"
NOJQPY="$(tl_path_without jq python3)"
run_dc "$(edit_json "$PROJ/src/app.js")" PATH="$NOJQPY"
assert_eq "no jq and no python3: still denied" "deny" "$(decision)"
UNINIT="$TL_TMP/uninit"; mkdir -p "$UNINIT"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
RUN_DIR="$UNINIT" run_dc "$(edit_json "$UNINIT/src/app.js")" PATH="$NOJQ"
assert_contains "no jq outside a project: warning only" "$TL_OUT" "Silver Bullet hooks require jq"
assert_eq "warning exits 0" 0 "$TL_STATUS"
unset RUN_DIR

tl_results

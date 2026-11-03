#!/usr/bin/env bash
# State paths from repository config must stay inside the runtime state root
# (R2-28, R3-05, R5-01): '..' and symlinked components used to pass the string-prefix
# check, so a cloned repository's .silver-bullet.json could make session-start delete,
# and the recorders write, files anywhere in the user's home.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
source "$TL_REPO_ROOT/tests/lib/c-toolgates-2-helpers.sh"

export SILVER_BULLET_TEST_HOOK_ENFORCED=1
export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
unset SILVER_BULLET_SESSION_SOURCE SILVER_BULLET_PROMPT_FILE SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT

SD="${SB_RUNTIME_STATE_DIR:?}"
ROOT_REL="~"/".${SB_RUNTIME_NAME}/.silver-bullet"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"

victim() { # name: create $HOME/<name> with known content, print its path
  printf 'precious\n' >"$HOME/$1"
  printf '%s' "$HOME/$1"
}
assert_untouched() { # name path
  if [[ -f "$2" && "$(cat "$2")" == "precious" ]]; then tl_pass "$1"; else tl_fail "$1 ($2: $(cat "$2" 2>/dev/null || echo MISSING))"; fi
}

# ---- session-start deletes only state-root files ------------------------------
ec_project
run_ss() {
  tl_run_stdin '{"hook_event_name":"SessionStart","source":"startup"}' bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$TL_REPO_ROOT/hooks/session-start"
}

v="$(victim trivial-victim)"
ec_cfg "$(jq -cn --arg t "$SD/../../trivial-victim" '{config_version:"0.40.0",sb_initiated:true,state:{trivial_file:$t}}')"
printf 'x' >"$SD/trivial"
run_ss
assert_untouched "session-start: '..' trivial_file outside the root is not deleted" "$v"
assert_file_absent "session-start: falls back to the default trivial marker" "$SD/trivial"

mkdir -p "$HOME/elsewhere"
ln -sfn "$HOME/elsewhere" "$SD/linkdir"
printf 'precious\n' >"$HOME/elsewhere/marker"
ec_cfg "$(jq -cn --arg t "$SD/linkdir/marker" '{config_version:"0.40.0",sb_initiated:true,state:{trivial_file:$t}}')"
run_ss
assert_untouched "session-start: trivial_file through a symlinked directory is not deleted" "$HOME/elsewhere/marker"
rm -f "$SD/linkdir"

# Branch/worktree change clears tool usage state; the configured paths must not escape.
g="$(victim graphify-victim)"
a="$(victim agentmemory-victim)"
ec_cfg "$(jq -cn --arg g "$ROOT_REL/../../graphify-victim" --arg a '${SB_RUNTIME_HOME_ROOT}/.silver-bullet/../../agentmemory-victim' \
  '{config_version:"0.40.0",sb_initiated:true,recommended_tools:{graphify:{query_state_file:$g},agentmemory:{usage_state_file:$a}}}')"
printf 'old-branch\n' >"$SD/branch"
printf '1\n' >"$SD/graphify-query"
printf '1\n' >"$SD/agentmemory-usage"
run_ss
assert_contains "branch change detected" "$TL_OUT" "git scope changed"
assert_untouched "session-start: graphify query_state_file with '..' is not deleted" "$g"
assert_untouched "session-start: agentmemory usage_state_file with '..' is not deleted" "$a"
assert_file_absent "session-start: default graphify state cleared instead" "$SD/graphify-query"
assert_file_absent "session-start: default agentmemory state cleared instead" "$SD/agentmemory-usage"

# Honest configuration still works: a configured trivial marker inside the root is cleared.
printf 'x' >"$SD/custom-trivial"
mkdir -p "$SD/sub"
ec_cfg "$(jq -cn --arg t "$SD/sub/../custom-trivial" '{config_version:"0.40.0",sb_initiated:true,state:{trivial_file:$t}}')"
run_ss
assert_file_absent "session-start: in-root trivial_file with an inner '..' is still cleared" "$SD/custom-trivial"

# ---- recorders write only inside the root ------------------------------------
tg2_init_project
skill_input() { jq -cn --arg s "$1" '{hook_event_name:"PostToolUse", tool_name:"Skill", tool_input:{skill:$s}}'; }
prompt_input() { jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit", prompt:$p}'; }
rm -f "$SD/state" "$SD/state.requested"

p="$(victim profile-victim)"
tg2_cfg "$(jq -cn --arg s "$ROOT_REL/../../profile-victim" '{sb_initiated:true,state:{state_file:$s}}')"
tg2_run hooks/record-skill.sh "$(skill_input silver-plan)"
assert_untouched "record-skill: '..' state_file outside the root is not appended to" "$p"
assert_contains "record-skill: skill recorded in the default state file" "$(cat "$SD/state" 2>/dev/null)" "silver-plan"

tg2_run hooks/record-requested-skill.sh "$(prompt_input 'please run `sb:feature` now')"
assert_file_absent "record-requested-skill: no <state>.requested outside the root" "$p.requested"
assert_contains "record-requested-skill: request recorded beside the default state" "$(cat "$SD/state.requested" 2>/dev/null)" "silver-feature"

# Honest configuration: a custom state file inside the root keeps working.
rm -f "$SD/state" "$SD/state.requested"
tg2_cfg "$(jq -cn --arg s "$ROOT_REL/custom-state" '{sb_initiated:true,state:{state_file:$s}}')"
tg2_run hooks/record-skill.sh "$(skill_input silver-plan)"
assert_contains "record-skill: in-root custom state file honoured" "$(cat "$SD/custom-state" 2>/dev/null)" "silver-plan"
assert_file_absent "record-skill: default state file untouched" "$SD/state"

# ---- tool usage state paths (graphify, agentmemory, leanctx) -----------------
CFG="$TL_TMP/tools.json"
jq -cn --arg g "$ROOT_REL/../../g" --arg a '${SB_RUNTIME_STATE_DIR}/../../a' --arg l "$SD/../x/../../l" \
  '{recommended_tools:{graphify:{query_state_file:$g},agentmemory:{usage_state_file:$a},leanctx:{usage_state_file:$l}}}' >"$CFG"
lib_path() { # lib function
  bash -c 'source "$1"; source "$2"; "$3" "$4"' _ "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$TL_REPO_ROOT/hooks/lib/$1" "$2" "$CFG"
}
assert_eq "graphify: escaping query_state_file falls back" "$SD/graphify-query" "$(lib_path graphify-gate.sh sb_graphify_query_state_path)"
assert_eq "agentmemory: escaping usage_state_file falls back" "$SD/agentmemory-usage" "$(lib_path agentmemory-gate.sh sb_agentmemory_usage_state_path)"
assert_eq "leanctx: escaping usage_state_file falls back" "$SD/leanctx-usage" "$(lib_path leanctx-gate.sh sb_leanctx_usage_state_path)"

tl_results

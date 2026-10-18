#!/usr/bin/env bash
# hooks/session-start: every best-effort step keeps the session going when its helper fails.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
HOOK="$TL_REPO_ROOT/hooks/session-start"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SILVER_BULLET_SESSION_SOURCE SILVER_BULLET_PROMPT_FILE SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT SILVER_BULLET_UPDATE_CHECK_DISABLED
export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
SD="${SB_RUNTIME_STATE_DIR:?}"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"
ec_project
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
run_ss() { # [hook] [stdin-file]
  tl_run bash -c 'cd "$1" && exec bash "$2" <"${3:-/dev/null}"' _ "${EC_RUN_DIR:-$EC_PROJ}" "${1:-$HOOK}" "${2:-}"
}
survived() { # label: the hook ran to its end despite the fault (an early ERR-trap exit would fail these)
  assert_eq "$1: exit 0" "0" "$TL_STATUS"
  assert_contains "$1: core rules still injected" "$(ctx)" "Non-Negotiable Rules"
  assert_file_exists "$1: ran to the end (session-rules marker written)" "$SD/session-rules-injected"
}
fresh() {
  local f
  for f in state branch trivial session-start-time stall-block orchestrator.json orchestrator-directive.json orchestrator-worker-active.json project-root session-rules-injected graphify-query agentmemory-usage; do
    rm -f "${SD:?}/${f:?}"
  done
  rm -rf "${EC_PROJ:?}/.planning" "${EC_PROJ:?}/scripts"
  EC_RUN_DIR="$EC_PROJ"
  ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
}

# ---- every sourced helper library failing ------------------------------------
ec_stage_hooks "$TL_TMP/failing" sb-project-gate.sh graphify-gate.sh agentmemory-gate.sh capability-tier.sh \
  enforcement-tier-gate.sh enterprise-policy.sh orchestrator-directive.sh orchestrator-state.sh orchestrator-parent.sh check-sb-update.sh
L="$TL_TMP/failing/hooks/lib"
printf '%s\n' 'sb_project_root_cache_write() { return 1; }' >"$L/sb-project-gate.sh"
printf '%s\n' 'sb_graphify_clear_query_state() { return 1; }' >"$L/graphify-gate.sh"
printf '%s\n' 'sb_agentmemory_clear_usage_state() { return 1; }' >"$L/agentmemory-gate.sh"
printf '%s\n' 'sb_capability_tier_banner() { return 1; }' 'sb_capability_runtime_name() { return 1; }' 'sb_capability_tier_number() { return 1; }' >"$L/capability-tier.sh"
printf '%s\n' 'sb_enforcement_tier_effective() { return 1; }' 'sb_enforcement_tier_persist() { return 1; }' 'sb_enforcement_tier_session_banner() { printf "TIER-BANNER-%s" "$1"; }' >"$L/enforcement-tier-gate.sh"
printf '%s\n' 'sb_enterprise_policy_persist_active_marker() { return 1; }' 'sb_enterprise_policy_apply_session_mode_default() { return 1; }' \
  'sb_enterprise_policy_session_banner() { return 1; }' 'sb_enterprise_policy_clarify_hint_block() { return 1; }' 'sb_enterprise_policy_evidence_strict_marker() { return 1; }' >"$L/enterprise-policy.sh"
printf '%s\n' 'sb_orchestrator_directive_context_block() { return 1; }' >"$L/orchestrator-directive.sh"
printf '%s\n' 'sb_orchestrator_sync_directive_from_state() { return 1; }' >"$L/orchestrator-state.sh"
printf '%s\n' 'sb_orchestrator_is_worker_session() { return 1; }' 'sb_orchestrator_is_parent_session() { return 0; }' 'sb_orchestrator_parent_context_block() { return 1; }' >"$L/orchestrator-parent.sh"
printf '%s\n' 'sb_check_sb_update_prompt_block() { return 1; }' >"$L/check-sb-update.sh"
fresh
printf 'old-branch\n' >"$SD/branch"
printf 'x' >"$SD/state"
unset SILVER_BULLET_UPDATE_CHECK_DISABLED
run_ss "$TL_TMP/failing/hooks/session-start"
export SILVER_BULLET_UPDATE_CHECK_DISABLED=1
survived "failing helper libraries"
assert_contains "failing helper libraries: the tier banner still renders with tier 0" "$(ctx)" "TIER-BANNER-0"
assert_contains "failing helper libraries: core rules still injected" "$(ctx)" "Non-Negotiable Rules"
assert_file_absent "failing helper libraries: the branch reset still happened" "$SD/state"
assert_file_absent "failing helper libraries: cached root not written" "$SD/project-root"

# ---- recommended-tools scripts that fail --------------------------------------
fresh
RT="$EC_PROJ/scripts/lib/recommended-tools"
mkdir -p "$RT"
printf '%s\n' 'rt_resolve_lib_script() { return 1; }' >"$RT/paths.sh"
printf '%s\n' 'rt_heartbeat_write() { return 1; }' >"$RT/heartbeat.sh"
printf '%s\n' 'return 1' >"$RT/session-verify.sh"
run_ss
survived "failing recommended-tools scripts"
assert_contains "failing recommended-tools scripts: rules still injected" "$(ctx)" "Non-Negotiable Rules"
rm -f "$RT/paths.sh"
printf '%s\n' 'rt_heartbeat_write() { return 1; }' >"$RT/heartbeat.sh"
printf '%s\n' 'rt_session_verify_block() { return 1; }' >"$RT/session-verify.sh"
ec_fail jq '*"sb_initiated"*'
run_ss
ec_unfail jq
assert_eq "unreadable sb_initiated: heartbeat skipped, exit 0" "0" "$TL_STATUS"
rm -f "${SD:?}/hb"
printf '%s\n' 'rt_heartbeat_write() { return 1; }' >"$RT/heartbeat.sh"
run_ss
survived "heartbeat write failing"
rm -rf "${EC_PROJ:?}/scripts"

# ---- unreadable stdin / failing mkdir / rm / jq / stat ------------------------
fresh
run_ss "$HOOK" "$TL_TMP"
assert_eq "unreadable stdin payload: exit 0" "0" "$TL_STATUS"
assert_file_exists "unreadable stdin payload: ran to the end" "$SD/session-rules-injected"
assert_contains "unreadable stdin payload: rules injected" "$(ctx)" "Non-Negotiable Rules"
fresh
ec_fail mkdir '*"-p"*'
run_ss
ec_unfail mkdir
survived "failing mkdir"
assert_file_exists "failing mkdir: session-start-time still written" "$SD/session-start-time"
fresh
printf 'x' >"$SD/orchestrator-directive.json"
mkdir -p "$TL_TMP/plain"
EC_RUN_DIR="$TL_TMP/plain"
ec_fail rm '*"orchestrator-directive"*'
run_ss
ec_unfail rm
assert_eq "non-SB workspace with a failing rm: exit 0" "0" "$TL_STATUS"
assert_file_exists "non-SB workspace with a failing rm: the stale directive is still there" "$SD/orchestrator-directive.json"
assert_eq "non-SB workspace with a failing rm: nothing injected" "" "$TL_OUT"
EC_RUN_DIR="$EC_PROJ"
# prompt replay with failing jq / failing recorder
ec_stage_hooks "$TL_TMP/rec"
rm -f "$TL_TMP/rec/hooks/record-requested-skill.sh"
printf '#!/usr/bin/env bash\nexit 1\n' >"$TL_TMP/rec/hooks/record-requested-skill.sh"
chmod +x "$TL_TMP/rec/hooks/record-requested-skill.sh"
fresh
printf 'seed\n' >"$TL_TMP/seed.txt"
SILVER_BULLET_PROMPT_FILE="$TL_TMP/seed.txt" run_ss "$TL_TMP/rec/hooks/session-start"
survived "failing recorder"
ec_fail jq '*"-Rs"*'
SILVER_BULLET_PROMPT_FILE="$TL_TMP/seed.txt" run_ss "$TL_TMP/rec/hooks/session-start"
ec_unfail jq
assert_eq "jq failing on the prompt seed: exit 0" "0" "$TL_STATUS"
assert_file_exists "jq failing on the prompt seed: ran to the end (session-rules marker written)" "$SD/session-rules-injected"
assert_eq "jq failing on the prompt seed: the context cannot be encoded, so nothing is emitted" "" "$TL_OUT"
# session-start-time that cannot be written
fresh
mkdir -p "$SD/ss-dir"
SILVER_BULLET_SESSION_START_FILE="$SD/ss-dir" run_ss
survived "session start file is a directory"
assert_not_contains "session start file is a directory: no redirect diagnostics" "$TL_ERR" "Is a directory"
rmdir "$SD/ss-dir"
# prerequisite block with jq unable to encode it
fresh
rm -rf "${SB_RUNTIME_PLUGIN_CACHE_ROOT:?}/alo-labs"
ec_fail jq '*"-Rs"*'
run_ss
ec_unfail jq
assert_eq "prerequisite block that cannot be encoded: silent" "" "$TL_OUT"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"

# ---- branch handling fallbacks -------------------------------------------------
ec_stage_hooks "$TL_TMP/nobs" branch-scope.sh nofollow-guard.sh
fresh
printf 'old-branch\n' >"$SD/branch"
ec_fail head '*"/branch"*'
run_ss "$TL_TMP/nobs/hooks/session-start"
ec_unfail head
survived "unreadable branch file"
fresh
SILVER_BULLET_BRANCH_FILE="$SD/missing-dir/branch" run_ss "$TL_TMP/nobs/hooks/session-start"
assert_contains "unwritable branch file (plain write): warning" "$TL_ERR" "branch file write failed"
assert_not_contains "unwritable branch file (plain write): no redirect diagnostics" "$TL_ERR" "No such file"
# fallback symlink handling: a symlinked state file is replaced, never followed
fresh
printf 'precious' >"$TL_TMP/target"
rm -f "${SD:?}/state"
ln -s "$TL_TMP/target" "$SD/state"
printf 'old-branch\n' >"$SD/branch"
run_ss "$TL_TMP/nobs/hooks/session-start"
assert_eq "state symlink target untouched" "precious" "$(cat "$TL_TMP/target")"
assert_file_absent "state symlink removed" "$SD/state"
# reset path with a failing rm and a failing graphify-query removal
fresh
printf 'old-branch\n' >"$SD/branch"
printf 'x' >"$SD/state"
ec_fail rm '*"pending-completion-audit"*'
run_ss
ec_unfail rm
survived "failing rm in the reset path"
assert_file_absent "failing rm in the reset path: the state was still reset" "$SD/state"
fresh
printf 'old-branch\n' >"$SD/branch"
printf 'x' >"$SD/state"
ec_fail rm '*"state"*'
run_ss
ec_unfail rm
survived "failing state removal"
assert_file_exists "failing state removal: the state file is kept" "$SD/state"

# ---- every cleanup rm of a branch reset may fail without ending the hook ---------------------------------
for victim in trivial release-live-matrix e2e-live-matrix quality-gate-state verify-tests-state; do
  fresh
  printf 'old-branch\n' >"$SD/branch"
  printf 'x' >"$SD/$victim"
  ec_fail rm "*\"$victim\"*"
  run_ss
  ec_unfail rm
  survived "failing removal of $victim"
  assert_file_exists "failing removal of $victim: the file is kept" "$SD/$victim"
done

# ---- workflow archive / trivial / overrides --------------------------------------
fresh
mkdir -p "$EC_PROJ/.planning/workflows"
printf o >"$EC_PROJ/.planning/workflows/old.md"
touch -d '10 days ago' "$EC_PROJ/.planning/workflows/old.md"
ec_fail mkdir '*".archive"*'
run_ss
ec_unfail mkdir
assert_file_exists "archive mkdir failing: the workflow stays" "$EC_PROJ/.planning/workflows/old.md"
ec_fail mv '*"old.md"*'
run_ss
ec_unfail mv
assert_file_exists "archive mv failing: the workflow stays" "$EC_PROJ/.planning/workflows/old.md"
ec_fail stat '*"-c"*'
run_ss
ec_unfail stat
survived "stat -c failing"
fresh
ec_fail jq '*"state.trivial_file"*'
run_ss
ec_unfail jq
survived "unreadable trivial_file config"
fresh
ec_fail rm '*"planning-edit-override"*'
run_ss
ec_unfail rm
survived "failing override removal"
fresh
printf '{}' >"$SD/orchestrator-worker-active.json"
ec_fail rm '*"orchestrator-worker-active"*'
run_ss
ec_unfail rm
survived "failing worker marker removal"
ec_fail rm '*"doc-scheme-gaps"*'
run_ss
ec_unfail rm
survived "failing doc-scheme-gaps removal"

# ---- gate libraries absent and their plain-file cleanup failing ---------------------
ec_stage_hooks "$TL_TMP/nogates" graphify-gate.sh agentmemory-gate.sh
for victim in graphify-query agentmemory-usage; do
  fresh
  printf 'old-branch\n' >"$SD/branch"
  printf 'x' >"$SD/state"
  printf 'q' >"$SD/$victim"
  ec_fail rm "*\"$victim\"*"
  run_ss "$TL_TMP/nogates/hooks/session-start"
  ec_unfail rm
  survived "failing removal of $victim without its gate library"
done

# ---- a branch file that cannot be rewritten (printf failing after the file was opened) ---------
fresh
printf 'old-branch\n' >"$SD/branch"
printf 'x' >"$SD/state"
tl_run bash -c 'printf() { if [[ "${1:-}" == "%s\n" && "${2:-}" == "feature/test" ]]; then return 1; fi; builtin printf "$@"; }; export -f printf; cd "$1" && exec bash "$2" </dev/null' _ "$EC_PROJ" "$TL_TMP/nobs/hooks/session-start"
assert_contains "reset path: unwritable branch file is reported" "$TL_ERR" "branch file write failed"
assert_not_contains "reset path: unwritable branch file: no redirect diagnostics" "$TL_ERR" "Permission denied"

# ---- capability helpers that fail for a cursor host ---------------------------------------------
ec_stage_hooks "$TL_TMP/curfail" capability-tier.sh
printf '%s\n' 'sb_capability_tier_banner() { printf "B"; }' 'sb_capability_runtime_name() { printf cursor; }' 'sb_capability_tier_number() { return 1; }' >"$TL_TMP/curfail/hooks/lib/capability-tier.sh"
fresh
run_ss "$TL_TMP/curfail/hooks/session-start"
assert_contains "cursor with an unknown tier gets the manifest note" "$(ctx)" "Task host: merge host hooks manifest"

# ---- recommended-tools scripts: verify script failing to load, consent helper failing ------------
fresh
RT="$EC_PROJ/scripts/lib/recommended-tools"
mkdir -p "$RT"
printf '%s\n' 'return 1' >"$RT/session-verify.sh"
run_ss
survived "session-verify.sh that cannot be loaded"
assert_contains "session-verify.sh that cannot be loaded: rules still injected" "$(ctx)" "Non-Negotiable Rules"
rm -rf "${EC_PROJ:?}/scripts"
ec_stage_hooks "$TL_TMP/consentfail" recommended-tools.sh
printf '%s\n' 'sb_recommended_tool_consent_prompt_block() { return 1; }' >"$TL_TMP/consentfail/hooks/lib/recommended-tools.sh"
fresh
run_ss "$TL_TMP/consentfail/hooks/session-start"
survived "consent prompt helper failing"

# ---- session-rules marker that cannot be written ----------------------------------------------------
fresh
mkdir -p "$SD/session-rules-injected"
run_ss
rmdir "$SD/session-rules-injected"
assert_eq "session-rules marker is a directory: exit 0" "0" "$TL_STATUS"
assert_not_contains "session-rules marker is a directory: no redirect diagnostics" "$TL_ERR" "Is a directory"
assert_contains "session-rules marker is a directory: context still injected" "$(ctx)" "Non-Negotiable Rules"

# ---- prerequisites missing: the block is reported when jq works ---------------------------------
fresh
rm -rf "${SB_RUNTIME_PLUGIN_CACHE_ROOT:?}/alo-labs"
run_ss
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/test"
assert_contains "missing plugin cache: prerequisites block reported" "$(ctx)" "prerequisites missing"

# ---- a parent orchestrator context block is injected ---------------------------------------------
ec_stage_hooks "$TL_TMP/parent" orchestrator-parent.sh
printf '%s\n' 'sb_orchestrator_is_worker_session() { return 1; }' 'sb_orchestrator_is_parent_session() { return 0; }' 'sb_orchestrator_parent_context_block() { printf "PARENT-CTX"; }' >"$TL_TMP/parent/hooks/lib/orchestrator-parent.sh"
fresh
run_ss "$TL_TMP/parent/hooks/session-start"
assert_contains "parent session: the parent context block is injected" "$(ctx)" "PARENT-CTX"

# ---- a pending orchestrator directive is appended to the context --------------------------------------
ec_stage_hooks "$TL_TMP/odctx" orchestrator-directive.sh
printf '%s\n' 'sb_orchestrator_directive_context_block() { printf "OD-DIRECTIVE-CTX"; }' >"$TL_TMP/odctx/hooks/lib/orchestrator-directive.sh"
fresh
run_ss "$TL_TMP/odctx/hooks/session-start"
assert_contains "pending directive: appended to the injected context" "$(ctx)" "OD-DIRECTIVE-CTX"
assert_contains "pending directive: the core rules are still first" "$(ctx)" "Non-Negotiable Rules"

# ---- script directory that cannot be resolved ------------------------------------
fresh
cd() {
  case "${1:-}" in */hooks) return 1 ;; esac
  builtin cd "$@"
}
export -f cd
run_ss
unset -f cd
assert_eq "script dir unresolvable: exit 0" "0" "$TL_STATUS"
assert_file_absent "script dir unresolvable: stopped before the rules marker" "$SD/session-rules-injected"
assert_eq "script dir unresolvable: nothing injected" "" "$TL_OUT"

# ---- core-rules path escaping the plugin directory ---------------------------------
# Make the second resolution of the hooks directory report a different place.
fresh
rm -f "$TL_TMP/hooks-cd-count"
cd() {
  case "${1:-}" in
    */hooks) echo $(( $(cat "$TL_TMP/hooks-cd-count" 2>/dev/null || echo 0) + 1 )) >"$TL_TMP/hooks-cd-count" ;;
  esac
  builtin cd "$@"
}
pwd() {
  if [[ "$(cat "$TL_TMP/hooks-cd-count" 2>/dev/null || echo 0)" -ge 2 ]]; then
    printf '/elsewhere'
  else
    builtin pwd "$@"
  fi
}
export -f cd pwd
export TL_TMP
run_ss
unset -f cd pwd
assert_eq "core rules resolving outside the plugin dir: exit 0" "0" "$TL_STATUS"
assert_file_exists "core rules resolving outside the plugin dir: ran to the end" "$SD/session-rules-injected"
assert_not_contains "core rules resolving outside the plugin dir: not injected" "$(ctx)" "Non-Negotiable Rules"
assert_contains "core rules resolving outside the plugin dir: the rest of the context is still built" "$(ctx)" "Silver Bullet capability"

tl_results

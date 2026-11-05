#!/usr/bin/env bash
# hooks/stop-check.sh: best-effort steps and orchestrator helpers that fail.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
HOOK="$TL_REPO_ROOT/hooks/stop-check.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT
ec_project
SD="${SB_RUNTIME_STATE_DIR:?}"
reason() { jq -r '.reason // ""' <<<"$TL_OUT"; }
run_stop() { # [hook] [json]
  tl_run_stdin "${2:-{\"hook_event_name\":\"Stop\"\}}" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "${1:-$HOOK}"
}
reset() {
  rm -f "${SD:?}/orchestrator.json" "${SD:?}/branch"
  printf 'silver-context\n' >"$SD/state"
  ec_cfg '{"config_version":"0.40.0","sb_initiated":true}'
  : >"$EC_PROJ/dirty.txt"
}

# ---- helper failing during a worker's SubagentStop ------------------------------
ec_stage_hooks "$TL_TMP/worker" orchestrator-parent.sh
printf '%s\n' 'sb_orchestrator_is_worker_session() { return 0; }' 'sb_orchestrator_clear_worker_marker() { return 1; }' >"$TL_TMP/worker/hooks/lib/orchestrator-parent.sh"
reset
run_stop "$TL_TMP/worker/hooks/stop-check.sh" '{"hook_event_name":"SubagentStop"}'
assert_eq "worker stop with a failing marker cleanup: silent allow" "0:" "$TL_STATUS:$TL_OUT"

# ---- parent block with helpers that yield nothing -------------------------------
ec_stage_hooks "$TL_TMP/orch" orchestrator-parent.sh orchestrator-state.sh orchestrator-directive.sh orchestrator-scheduler.sh
OL="$TL_TMP/orch/hooks/lib"
printf '%s\n' 'sb_orchestrator_is_parent_session() { return 0; }' 'sb_orchestrator_state_applies_to_project() { return 0; }' 'sb_orchestrator_is_worker_session() { return 1; }' >"$OL/orchestrator-parent.sh"
printf '%s\n' "sb_orchestrator_state_file() { printf '%s' '$TL_TMP/orch-state.json'; }" 'sb_orchestrator_flow_to_skill() { return 1; }' >"$OL/orchestrator-state.sh"
printf '%s\n' "sb_orchestrator_directive_file() { printf '%s' '$TL_TMP/orch-directive.json'; }" >"$OL/orchestrator-directive.sh"
: >"$OL/orchestrator-scheduler.sh"
reset
printf '{"current_flow":"FLOW-X"}' >"$TL_TMP/orch-state.json"
printf '{}' >"$TL_TMP/orch-directive.json"
run_stop "$TL_TMP/orch/hooks/stop-check.sh"
assert_contains "parent block: unmapped flow falls back to the generic skill" "$(reason)" "(FLOW-X). Spawn Task worker (WORKER.md) for /next-skill"
ec_fail jq '*"current_flow"*'
run_stop "$TL_TMP/orch/hooks/stop-check.sh"
ec_unfail jq
assert_contains "parent block: unreadable flow reported as unknown" "$(reason)" "(unknown)"
ec_fail jq '*"next_worker_template"*'
run_stop "$TL_TMP/orch/hooks/stop-check.sh"
ec_unfail jq
assert_contains "parent block: unreadable template: generic worker" "$(reason)" "WORKER.md"
ec_fail jq '*"next_skill"*'
run_stop "$TL_TMP/orch/hooks/stop-check.sh"
ec_unfail jq
assert_contains "parent block: unreadable skill: generic skill" "$(reason)" "/next-skill"
printf '%s\n' "sb_orchestrator_state_file() { return 1; }" 'sb_orchestrator_flow_to_skill() { return 1; }' >"$OL/orchestrator-state.sh"
printf '%s\n' "sb_orchestrator_directive_file() { return 1; }" >"$OL/orchestrator-directive.sh"
run_stop "$TL_TMP/orch/hooks/stop-check.sh"
assert_contains "parent block: no state or directive file" "$(reason)" "(unknown). Spawn Task worker (WORKER.md) for /next-skill"

# ---- scheduler block with failing reason / event helpers --------------------------
printf '%s\n' 'sb_orchestrator_is_parent_session() { return 0; }' 'sb_orchestrator_state_applies_to_project() { return 1; }' 'sb_orchestrator_is_worker_session() { return 1; }' >"$OL/orchestrator-parent.sh"
printf '%s\n' 'sb_scheduler_parent_stop_blocked() { return 0; }' 'sb_scheduler_parent_stop_block_reason() { return 1; }' 'sb_orchestrator_event_record_stop_block() { return 1; }' >"$OL/orchestrator-scheduler.sh"
run_stop "$TL_TMP/orch/hooks/stop-check.sh"
assert_contains "scheduler block: default reason when the helper fails" "$(reason)" "Orchestrator scheduler: pending batch dispatch or join."

# ---- git / head failures -----------------------------------------------------------
reset
ec_fail git '*"--show-toplevel"*'
run_stop
ec_unfail git
assert_contains "unknown toplevel: still enforces" "$(reason)" "missing required skills"
ec_stage_hooks "$TL_TMP/nobs" branch-scope.sh
printf 'feature/test\n' >"$SD/branch"
ec_fail head '*"/branch"*'
run_stop "$TL_TMP/nobs/hooks/stop-check.sh"
ec_unfail head
assert_contains "unreadable branch file (plain read): treated as no stored branch" "$(reason)" "missing required skills"

# ---- script directory resolved only on the second try -----------------------------
ec_stage_hooks "$TL_TMP/bare" -
reset
cd() {
  case "${1:-}" in
    */lib)
      n=$(cat "$TL_TMP/cd-count" 2>/dev/null || echo 0)
      echo $((n + 1)) >"$TL_TMP/cd-count"
      if [[ "$n" -lt 2 ]]; then return 1; fi
      ;;
  esac
  builtin cd "$@"
}
export -f cd
export TL_TMP
rm -f "$TL_TMP/cd-count"
run_stop
unset -f cd
assert_eq "lib dir found on the third resolution: normal enforcement" "0" "$TL_STATUS"
assert_contains "lib dir found on the third resolution: skills checked" "$(reason)" "missing required skills"

tl_results

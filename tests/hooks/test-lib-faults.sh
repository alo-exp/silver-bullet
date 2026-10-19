#!/usr/bin/env bash
# hooks/lib: best-effort writes, reads and helper calls that fail.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
LIB="$TL_REPO_ROOT/hooks/lib"
SD="${SB_RUNTIME_STATE_DIR:?}"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
unset SILVER_BULLET_BRANCH_FILE SILVER_BULLET_HOOK_AUDIT_LOG SILVER_BULLET_SESSION_LOG_PATH_FILE PROJECT_ROOT_OVERRIDE
ok() { if "$@"; then tl_pass "$*"; else tl_fail "$*"; fi; }
nok() { if "$@"; then tl_fail "NOT: $*"; else tl_pass "NOT: $*"; fi; }
ec_project
BLOCKER="$TL_TMP/blocker"     # a regular file: any path below it cannot be created
: >"$BLOCKER"

# ---- ups-coalesce: unwritable state directory ----------------------------------
(
  export SB_RUNTIME_STATE_DIR="$BLOCKER/state"
  # shellcheck source=../../hooks/lib/ups-coalesce.sh
  source "$LIB/ups-coalesce.sh"
  sb_ups_coalesce_reset
  sb_ups_coalesce_begin
  if sb_ups_coalesce_claim "payload"; then echo claimed; else echo refused; fi
) >"$TL_TMP/ups.out" 2>&1
assert_eq "ups-coalesce: unwritable state dir never aborts and still claims" "claimed" "$(tail -1 "$TL_TMP/ups.out")"
# unreadable turn file / seen file that cannot be created
(
  # shellcheck source=../../hooks/lib/ups-coalesce.sh
  source "$LIB/ups-coalesce.sh"
  printf '%s' "$(date +%s)" >"$(sb_ups_coalesce_turn_file)"
  rm -f "$(sb_ups_coalesce_seen_file)"
  mkdir -p "$(sb_ups_coalesce_seen_file)"
  sb_ups_coalesce_begin
  printf '%s' "$(date +%s)" >"$(sb_ups_coalesce_turn_file)"
  ec_fail cat '*"ups-coalesce-turn"*'
  sb_ups_coalesce_begin
  ec_unfail cat
  echo 'done'
) >"$TL_TMP/ups2.out" 2>&1
assert_eq "ups-coalesce: unreadable turn file / unwritable seen list tolerated" "done" "$(tail -1 "$TL_TMP/ups2.out")"
rmdir "$SD/ups-coalesce-seen" 2>/dev/null || true

# ---- stop-coalesce / e2e-matrix-routing: failing rm / mkdir ----------------------
# shellcheck source=../../hooks/lib/stop-coalesce.sh
source "$LIB/stop-coalesce.sh"
# shellcheck source=../../hooks/lib/e2e-matrix-routing.sh
source "$LIB/e2e-matrix-routing.sh"
ec_fail rm '*"stop-coalesce-block"*'
ok sb_stop_coalesce_reset
ec_unfail rm
ec_fail rm '*"e2e-matrix-routing-row"*'
ok sb_e2e_matrix_clear_routing_row_marker
ec_unfail rm
ec_fail mkdir '*"-p"*'
ok sb_e2e_matrix_set_routing_row_marker
ec_unfail mkdir
sb_e2e_matrix_clear_routing_row_marker

# ---- sb-project-gate: unreadable cache ----------------------------------------------
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$LIB/sb-project-gate.sh"
sb_project_root_cache_write "$EC_PROJ"
ec_fail sed '*"-n"*'
nok sb_project_root_cache_read
ec_unfail sed

# ---- failed best-effort writes are silent (the 2>/dev/null must precede the redirect) -------------
err="$(SB_RUNTIME_STATE_DIR="$BLOCKER/x" sb_e2e_matrix_set_routing_row_marker 2>&1 >/dev/null || true)"
assert_eq "e2e-matrix-routing: unwritable marker location: no diagnostics" "" "$err"
assert_file_absent "e2e-matrix-routing: unwritable marker location: nothing created" "$BLOCKER/x/e2e-matrix-routing-row"
err="$(SB_RUNTIME_STATE_DIR="$BLOCKER/x" SB_PROJECT_ROOT_CACHE_FILE="$BLOCKER/x/project-root" sb_project_root_cache_write "$EC_PROJ" 2>&1 >/dev/null || true)"
assert_eq "sb-project-gate: unwritable cache location: no diagnostics" "" "$err"
SB_RUNTIME_STATE_DIR="$BLOCKER/x" SB_PROJECT_ROOT_CACHE_FILE="$BLOCKER/x/project-root" ok sb_project_root_cache_write "$EC_PROJ"

# ---- project-active: config vanishing between lookup and check ----------------------------
out="$(bash -c 'source "$1"; sb_find_project_config() { printf "%s" "$2/gone.json"; }; sb_project_active_or_exit; echo continued' _ "$LIB/project-active.sh" "$TL_TMP")"
assert_eq "project-active: config path that no longer exists exits" "" "$out"

# ---- core-rules-integrity ------------------------------------------------------------------
# shellcheck source=../../hooks/lib/core-rules-integrity.sh
source "$LIB/core-rules-integrity.sh"
nok sb_core_rules_expected_hash ""

# ---- check-sb-update ---------------------------------------------------------------------------
# shellcheck source=../../hooks/lib/check-sb-update.sh
source "$LIB/check-sb-update.sh"
out="$(SILVER_BULLET_UPDATE_CHECK_LATEST=2.0.0 SILVER_BULLET_INSTALLED_PLUGINS_FILE="$TL_TMP/none.json" sb_check_sb_update_prompt_block)"
assert_contains "update prompt block still works" "$out" "SB UPDATE AVAILABLE"
printf '{"plugins":{"silver-bullet@alo-labs":[{"version":"9.9.9"}]}}' >"$TL_TMP/reg.json"
ec_fail jq '*"--arg id"*'
nok sb_update_resolve_installed_version "$TL_TMP/reg.json"
ec_unfail jq

# ---- runtime-paths blank entries ---------------------------------------------------------------
# shellcheck source=../../hooks/lib/runtime-paths.sh
source "$LIB/runtime-paths.sh"
SB_RUNTIME_EXTRA_STATE_ROOTS="::/kay/.silver-bullet" ok sb_runtime_path_is_state_scoped "/kay/.silver-bullet/x"
assert_eq "receipt dirs with an empty state dir skip it" "0" "$(SB_RUNTIME_STATE_DIR="" sb_runtime_skill_receipt_dirs | grep -c '^/skill-invocations$' || true)"

# ---- session-ledger ----------------------------------------------------------------------------
unset PROJECT_ROOT_OVERRIDE
# shellcheck source=../../hooks/lib/session-ledger.sh
source "$LIB/session-ledger.sh"
printf '/dev/null' >"$SD/session-log-path"
ec_fail cat '*"session-log-path"*'
nok sb_session_ledger_log_path
ec_unfail cat
rm -f "$SD/session-log-path"

# ---- required-skills ----------------------------------------------------------------------------
# shellcheck source=../../hooks/lib/required-skills.sh
source "$LIB/required-skills.sh"
nok sb_required_skill_is_recorded $'a\n' ""
assert_eq "line of an empty skill name is 0" "0" "$(sb_required_skill_line $'a\n' "")"
printf '{"config_version":"0.0.1"}' >"$TL_TMP/p.json"
ec_fail jq '*"p.json"*'
ok sb_required_skills_config_is_legacy "$TL_TMP/p.json"   # unreadable version counts as legacy
ec_unfail jq

# ---- hook-audit: unwritable sinks ----------------------------------------------------------------
# shellcheck source=../../hooks/lib/hook-audit.sh
source "$LIB/hook-audit.sh"
mkdir -p "$SD/sink-dir"
SILVER_BULLET_HOOK_AUDIT_LOG="$SD/sink-dir" sb_hook_audit_record h Stop allow
assert_eq "audit: a directory as the sink is tolerated (jq path)" "0" "$?"
SILVER_BULLET_HOOK_AUDIT_LOG="$SD/sink-dir" PATH="$(tl_path_without jq)" sb_hook_audit_record h Stop allow
assert_eq "audit: a directory as the sink is tolerated (printf path)" "0" "$?"

# ---- branch-scope: unreadable and unwritable ----------------------------------------------------------
# shellcheck source=../../hooks/lib/branch-scope.sh
source "$LIB/branch-scope.sh"
printf 'feature/x\n/top\n' >"$SD/branch"
ec_fail sed '*"1p"*'
nok sb_branch_scope_read "$SD/branch"
ec_unfail sed
ec_fail sed '*"2p"*'
ok sb_branch_scope_read "$SD/branch"
ec_unfail sed
assert_eq "toplevel unreadable: empty" "" "$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
SILVER_BULLET_BRANCH_FILE="$SD/no-such-dir/branch" sb_branch_scope_write feature/x
SILVER_BULLET_BRANCH_FILE="$SD/no-such-dir/branch" sb_branch_scope_write feature/x /top
assert_file_absent "unwritable scope file: nothing created" "$SD/no-such-dir/branch"

# ---- enterprise-policy -------------------------------------------------------------------------------------
# shellcheck source=../../hooks/lib/enterprise-policy.sh
source "$LIB/enterprise-policy.sh"
CFG="$TL_TMP/ep.json"
printf '{"enterprise_policy":{"active_profile":"autonomous_safe","profiles":{"autonomous_safe":{"session_mode_default":"autonomous","label":"L"}}}}' >"$CFG"
ec_fail jq '*"--arg p"*'
nok sb_enterprise_policy_profile_field "$CFG" autonomous_safe label
ec_unfail jq
M="$TL_TMP/ep-state"
mkdir -p "$M"
printf 'autonomous' >"$M/mode"
ec_fail tr '*"[:space:]"*'
sb_enterprise_policy_apply_session_mode_default "$CFG" "$M" clear
ec_unfail tr
assert_eq "unreadable mode content is rewritten" "autonomous" "$(cat "$M/mode")"
ec_fail tr '*"[:space:]"*'
banner="$(sb_enterprise_policy_session_banner "$CFG" "$M")"
ec_unfail tr
assert_contains "banner with an unreadable mode file still renders" "$banner" "Enterprise policy profile: autonomous_safe"
sb_enterprise_policy_apply_session_mode_default "$CFG" "$TL_TMP/no-state-dir"
sb_enterprise_policy_persist_active_marker "$CFG" "$TL_TMP/no-state-dir"
assert_file_absent "marker not written into a missing directory" "$TL_TMP/no-state-dir/enterprise-policy-active"
printf '{}' >"$TL_TMP/ep-none.json"
ec_fail rm '*"enterprise-policy-active"*'
sb_enterprise_policy_persist_active_marker "$TL_TMP/ep-none.json" "$M"
ec_unfail rm
profile_cfg="$TL_TMP/ep2.json"
printf '{"enterprise_policy":{"active_profile":"supervised","profiles":{"supervised":{"session_mode_default":"interactive"}}}}' >"$profile_cfg"
rm -f "$M/mode"
sb_enterprise_policy_apply_session_mode_default "$profile_cfg" "$TL_TMP/no-state-dir"
SB_RUNTIME_STATE_DIR="" sb_enterprise_policy_persist_active_marker "$CFG" ""
# tier probe failing during the host-tier check
ec_stage_hooks "$TL_TMP/tierfail" enforcement-tier-gate.sh
printf '%s\n' 'sb_enforcement_tier_effective() { return 1; }' >"$TL_TMP/tierfail/hooks/lib/enforcement-tier-gate.sh"
nok bash -c 'source "$1"; sb_enterprise_policy_host_tier_safe "$2"' _ "$TL_TMP/tierfail/hooks/lib/enterprise-policy.sh" "$CFG"

# ---- enforcement-tier-gate -----------------------------------------------------------------------------------
# shellcheck source=../../hooks/lib/enforcement-tier-gate.sh
source "$LIB/enforcement-tier-gate.sh"
printf '{}' >"$TL_TMP/nojq.json"
assert_eq "no jq: tier reads as 0" "0" "$(PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_enforcement_tier_read_config "$2"' _ "$LIB/enforcement-tier-gate.sh" "$TL_TMP/nojq.json")"
printf 'not json' >"$TL_TMP/bad.json"
assert_eq "unparsable config reads as no tier" "" "$(sb_enforcement_tier_read_config "$TL_TMP/bad.json")"
ec_stage_hooks "$TL_TMP/probefail" capability-tier.sh
printf '%s\n' 'sb_capability_tier_name() { return 1; }' >"$TL_TMP/probefail/hooks/lib/capability-tier.sh"
assert_eq "probe falling back to guidance-only when the tier name fails" "0" "$(bash -c 'source "$1"; sb_enforcement_tier_probe' _ "$TL_TMP/probefail/hooks/lib/enforcement-tier-gate.sh")"

# ---- best-effort writes must be quiet on stderr when they fail --------------------------------------
quiet() { # label cmd...  -> asserts the command prints nothing on stderr
  local label="$1" err
  shift
  err="$("$@" 2>&1 >/dev/null || true)"
  assert_eq "quiet failure: $label" "" "$err"
}
quiet "branch-scope write (branch only)" env SILVER_BULLET_BRANCH_FILE="$SD/no-such-dir/branch" bash -c 'source "$1"; sb_branch_scope_write feature/x' _ "$LIB/branch-scope.sh"
quiet "branch-scope write (with toplevel)" env SILVER_BULLET_BRANCH_FILE="$SD/no-such-dir/branch" bash -c 'source "$1"; sb_branch_scope_write feature/x /top' _ "$LIB/branch-scope.sh"
quiet "enterprise mode write (autonomous)" bash -c 'source "$1"; sb_enterprise_policy_apply_session_mode_default "$2" "$3"' _ "$LIB/enterprise-policy.sh" "$CFG" "$TL_TMP/absent-dir"
quiet "enterprise mode write (interactive)" bash -c 'source "$1"; sb_enterprise_policy_apply_session_mode_default "$2" "$3"' _ "$LIB/enterprise-policy.sh" "$profile_cfg" "$TL_TMP/absent-dir"
quiet "enterprise marker write" bash -c 'source "$1"; sb_enterprise_policy_persist_active_marker "$2" "$3"' _ "$LIB/enterprise-policy.sh" "$CFG" "$TL_TMP/absent-dir"
quiet "hook audit append (jq)" env SILVER_BULLET_HOOK_AUDIT_LOG="$SD/sink-dir" bash -c 'source "$1"; sb_hook_audit_record h Stop allow' _ "$LIB/hook-audit.sh"
quiet "hook audit append (printf)" env SILVER_BULLET_HOOK_AUDIT_LOG="$SD/sink-dir" PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_hook_audit_record h Stop allow' _ "$LIB/hook-audit.sh"
quiet "ups-coalesce writes" env SB_RUNTIME_STATE_DIR="$BLOCKER/state" bash -c 'source "$1"; sb_ups_coalesce_reset; sb_ups_coalesce_begin; sb_ups_coalesce_claim x' _ "$LIB/ups-coalesce.sh"

# the probe maps a "live-tested" capability tier to 3 (staged capability lib)
ec_stage_hooks "$TL_TMP/live" capability-tier.sh
printf '%s\n' 'sb_capability_tier_name() { printf live-tested; }' >"$TL_TMP/live/hooks/lib/capability-tier.sh"
assert_eq "probe: live-tested is tier 3" "3" "$(bash -c 'source "$1"; sb_enforcement_tier_probe' _ "$TL_TMP/live/hooks/lib/enforcement-tier-gate.sh")"

# ---- the real GitHub lookup path (curl stubbed) ----------------------------------------------------
unset SILVER_BULLET_UPDATE_CHECK_LATEST
tl_stub curl 'printf "{\"tag_name\":\"v9.8.7\"}"'
assert_eq "latest release parsed from the API reply" "9.8.7" "$(sb_update_fetch_latest_version)"
SILVER_BULLET_INSTALLED_PLUGINS_FILE="$TL_TMP/none.json" sb_check_sb_update
assert_eq "update available from the live lookup" "update_available" "$SB_UPDATE_CHECK_RESULT"
tl_stub curl 'printf "{\"tag_name\":\"not-a-version\"}"'
nok sb_update_fetch_latest_version
tl_stub curl 'exit 22'
nok sb_update_fetch_latest_version
SILVER_BULLET_INSTALLED_PLUGINS_FILE="$TL_TMP/none.json" sb_check_sb_update
assert_eq "failing lookup is check_failed" "check_failed" "$SB_UPDATE_CHECK_RESULT"
ec_unfail curl

tl_results

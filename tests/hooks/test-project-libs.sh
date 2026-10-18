#!/usr/bin/env bash
# hooks/lib: branch-scope, sb-project-gate, project-active, hook-audit, quality-gates-mode,
# e2e-matrix-routing and the update-check fetch guard.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
LIB="$TL_REPO_ROOT/hooks/lib"
SD="${SB_RUNTIME_STATE_DIR:?}"
unset SILVER_BULLET_BRANCH_FILE SILVER_BULLET_HOOK_AUDIT_LOG SILVER_BULLET_PROJECT_ROOT
ok() { if "$@"; then tl_pass "$*"; else tl_fail "$*"; fi; }
nok() { if "$@"; then tl_fail "NOT: $*"; else tl_pass "NOT: $*"; fi; }

# ---- branch-scope -----------------------------------------------------------
# shellcheck source=../../hooks/lib/branch-scope.sh
source "$LIB/branch-scope.sh"
ec_project
assert_eq "toplevel of a repo" "$EC_PROJ" "$(sb_branch_scope_git_toplevel "$EC_PROJ")"
assert_eq "toplevel outside a repo is empty" "" "$(sb_branch_scope_git_toplevel "$TL_TMP")"
assert_eq "toplevel defaults to PWD" "$EC_PROJ" "$(cd "$EC_PROJ" && sb_branch_scope_git_toplevel)"
assert_eq "scope file default" "$SD/branch" "$(sb_branch_scope_file)"
assert_eq "scope file override" "/x/b" "$(SILVER_BULLET_BRANCH_FILE=/x/b sb_branch_scope_file)"
nok sb_branch_scope_write ""
BF="$SD/branch"
rm -f "$BF"
sb_branch_scope_write feature/x /top/dir
assert_eq "branch and toplevel written" $'feature/x\n/top/dir' "$(cat "$BF")"
sb_branch_scope_write feature/y
assert_eq "branch alone written" "feature/y" "$(cat "$BF")"
ok sb_branch_scope_read "$BF"
assert_eq "stored branch" "feature/y" "$SB_BRANCH_SCOPE_STORED_BRANCH"
assert_eq "stored toplevel empty" "" "$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
sb_branch_scope_write feature/x /top/dir
ok sb_branch_scope_read "$BF"
assert_eq "stored toplevel" "/top/dir" "$SB_BRANCH_SCOPE_STORED_TOPLEVEL"
nok sb_branch_scope_read "$TL_TMP/absent"
assert_eq "stale values cleared on a failed read" "" "$SB_BRANCH_SCOPE_STORED_BRANCH"
: >"$BF"
nok sb_branch_scope_read "$BF"
ln -sf "$TL_TMP/target" "$TL_TMP/linked-branch"
nok sb_branch_scope_read "$TL_TMP/linked-branch"
sb_branch_scope_write feature/x /top/dir
nok sb_branch_scope_mismatch "" /top/dir
ok sb_branch_scope_mismatch other /top/dir
nok sb_branch_scope_mismatch feature/x /top/dir
ok sb_branch_scope_mismatch feature/x /different
nok sb_branch_scope_mismatch feature/x ""
sb_branch_scope_write feature/y
nok sb_branch_scope_mismatch feature/y /anything
rm -f "$BF"
nok sb_branch_scope_mismatch feature/y /anything
# a symlinked scope file is not written through
rm -f "$BF"
ln -s "$TL_TMP/target" "$BF"
( source "$LIB/nofollow-guard.sh"; sb_branch_scope_write feature/z ) 2>/dev/null || true
assert_file_absent "scope write refuses a symlink" "$TL_TMP/target"
rm -f "$BF"

# ---- sb-project-gate / project-active ---------------------------------------
# shellcheck source=../../hooks/lib/sb-project-gate.sh
source "$LIB/sb-project-gate.sh"
cd "$EC_PROJ"
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
nok sb_project_root_cache_write ""
nok sb_project_root_cache_write "$TL_TMP/plain"
mkdir -p "$TL_TMP/plain"
nok sb_project_root_cache_write "$TL_TMP/plain"
ok sb_project_root_cache_write "$EC_PROJ/"
assert_eq "root cached" "$EC_PROJ" "$(sed -n 1p "$SB_PROJECT_ROOT_CACHE_FILE")"
assert_eq "cache read" "$EC_PROJ" "$(sb_project_root_cache_read)"
# a cache file that cannot be moved into place leaves nothing behind
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
ec_fail mv '*"project-root"*'
ok sb_project_root_cache_write "$EC_PROJ"
ec_unfail mv
assert_file_absent "failed move: the cache was not created" "$SB_PROJECT_ROOT_CACHE_FILE"
assert_eq "failed move: the temporary file was removed" "0" "$(find "$SD" -maxdepth 1 -name 'project-root.*' | wc -l | tr -d ' ')"
( unset SB_RUNTIME_STATE_DIR; sb_project_root_cache_write "$EC_PROJ" ) && tl_pass "no state dir: nothing to cache, still succeeds"
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
nok sb_project_root_cache_read
printf '/no/such/root\n' >"$SB_PROJECT_ROOT_CACHE_FILE"
nok sb_project_root_cache_read
: >"$SB_PROJECT_ROOT_CACHE_FILE"
nok sb_project_root_cache_read
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
assert_eq "config found by walking up" "$EC_CFG" "$(cd "$EC_PROJ" && sb_find_project_config)"
assert_eq "project root helper" "$EC_PROJ" "$(cd "$EC_PROJ" && sb_find_project_root)"
mkdir -p "$EC_PROJ/s/t"
assert_eq "walk-only config from a subdir" "$EC_CFG" "$(cd "$EC_PROJ/s/t" && sb_find_project_config_walk_only)"
assert_eq "walk-only root from a subdir" "$EC_PROJ" "$(cd "$EC_PROJ/s/t" && sb_find_project_root_walk_only)"
assert_eq "SILVER_BULLET_PROJECT_ROOT wins" "$EC_CFG" "$(cd "$TL_TMP/plain" && SILVER_BULLET_PROJECT_ROOT="$EC_PROJ/" sb_find_project_config_walk_only)"
# cache-backed discovery from outside, but walk-only helpers stay strict
sb_project_root_cache_write "$EC_PROJ"
assert_eq "cache serves discovery outside the project" "$EC_CFG" "$(cd "$TL_TMP/plain" && sb_find_project_config)"
assert_eq "cache serves the root helper" "$EC_PROJ" "$(cd "$TL_TMP/plain" && sb_find_project_root)"
if (cd "$TL_TMP/plain" && sb_find_project_config_walk_only >/dev/null); then tl_fail "walk-only ignores the cache"; else tl_pass "walk-only ignores the cache"; fi
if (cd "$TL_TMP/plain" && sb_find_project_root_walk_only >/dev/null); then tl_fail "walk-only root ignores the cache"; else tl_pass "walk-only root ignores the cache"; fi
rm -f "$SB_PROJECT_ROOT_CACHE_FILE"
if (cd "$TL_TMP/plain" && sb_find_project_root >/dev/null); then tl_fail "no root without config or cache"; else tl_pass "no root without config or cache"; fi

ok sb_project_active "$EC_CFG"
nok sb_project_active ""
nok sb_project_active "$TL_TMP/absent.json"
ok sb_project_is_initiated "$EC_CFG"
nok sb_config_marked_initiated ""
nok sb_config_marked_initiated "$TL_TMP/absent.json"
ok sb_config_marked_initiated "$EC_CFG"
printf '{"sb_initiated":false}' >"$TL_TMP/off.json"
nok sb_config_marked_initiated "$TL_TMP/off.json"
printf 'not json' >"$TL_TMP/bad.json"
nok sb_config_marked_initiated "$TL_TMP/bad.json"
nok env PATH="$(tl_path_without jq)" bash -c 'source "$1"; sb_config_marked_initiated "$2"' _ "$LIB/project-active.sh" "$EC_CFG"
out="$(cd "$TL_TMP/plain" && rm -f "$SB_PROJECT_ROOT_CACHE_FILE" && bash -c 'source "$1"; sb_project_active_or_exit; echo continued' _ "$LIB/project-active.sh")"
assert_eq "no config: active_or_exit exits" "" "$out"
out="$(cd "$EC_PROJ" && bash -c 'source "$1"; sb_project_active_or_exit; echo continued' _ "$LIB/project-active.sh")"
assert_eq "config present: continues" "continued" "$out"
out="$(cd "$EC_PROJ" && bash -c 'source "$1"; sb_project_gate_or_exit; echo continued' _ "$LIB/project-active.sh")"
assert_eq "gate alias continues" "continued" "$out"

# ---- hook-audit -------------------------------------------------------------
# shellcheck source=../../hooks/lib/hook-audit.sh
source "$LIB/hook-audit.sh"
nok sb_hook_audit_log_path
LOGP="$SD/audit.jsonl"
assert_eq "explicit state-scoped path" "$LOGP" "$(SILVER_BULLET_HOOK_AUDIT_LOG="$LOGP" sb_hook_audit_log_path)"
nok env SILVER_BULLET_HOOK_AUDIT_LOG=/etc/elsewhere.jsonl bash -c "source '$LIB/runtime-paths.sh'; source '$LIB/hook-audit.sh'; sb_hook_audit_log_path"
assert_eq "explicit path without the scope helper is accepted" "/x/y.jsonl" "$(env SILVER_BULLET_HOOK_AUDIT_LOG=/x/y.jsonl bash -c "source '$LIB/hook-audit.sh'; sb_hook_audit_log_path")"
assert_eq "tilde expanded" "$HOME/a.jsonl" "$(SILVER_BULLET_HOOK_AUDIT_LOG="$(printf "%s" "~")/a.jsonl" bash -c "source '$LIB/hook-audit.sh'; sb_hook_audit_log_path")"
nok env -u SB_RUNTIME_STATE_DIR bash -c "source '$LIB/hook-audit.sh'; sb_hook_audit_log_path"
: >"$SD/hook-audit-enabled"
assert_eq "enabled flag selects the default sink" "$SD/hook-audit.jsonl" "$(sb_hook_audit_log_path)"
rm -f "$SD/hook-audit-enabled"
ln -s "$TL_TMP/target" "$SD/hook-audit-enabled"
nok sb_hook_audit_log_path
rm -f "$SD/hook-audit-enabled"

rm -f "$LOGP"
SILVER_BULLET_HOOK_AUDIT_LOG="$LOGP" sb_hook_audit_record my-hook PreToolUse deny "why" "/t/x"
assert_eq "audit record decision" "deny" "$(jq -r .decision "$LOGP")"
assert_eq "audit record hook name" "my-hook" "$(jq -r .hook_name "$LOGP")"
assert_eq "audit record target" "/t/x" "$(jq -r .target "$LOGP")"
assert_eq "audit record cwd" "$PWD" "$(jq -r .cwd "$LOGP")"
assert_eq "audit record runtime" "$SB_RUNTIME_NAME" "$(jq -r .runtime "$LOGP")"
SILVER_BULLET_HOOK_AUDIT_LOG="$LOGP" sb_hook_audit_record h Stop allow
assert_eq "defaults for optional fields" "" "$(tail -1 "$LOGP" | jq -r .detail)"
rm -f "$LOGP"
SILVER_BULLET_HOOK_AUDIT_LOG="$LOGP" PATH="$(tl_path_without jq)" sb_hook_audit_record h Stop allow "d" "t"
assert_eq "no jq: printf-built record is valid JSON" "allow" "$(jq -r .decision "$LOGP")"
assert_eq "no jq: detail kept" "d" "$(jq -r .detail "$LOGP")"
rm -f "$LOGP"
sb_hook_audit_record h Stop allow
assert_file_absent "disabled: nothing written" "$LOGP"
ln -s "$TL_TMP/target" "$LOGP"
SILVER_BULLET_HOOK_AUDIT_LOG="$LOGP" sb_hook_audit_record h Stop allow
assert_file_absent "symlinked sink is not written" "$TL_TMP/target"
rm -f "$LOGP"
SILVER_BULLET_HOOK_AUDIT_LOG="$SD/new/deeper/log.jsonl" sb_hook_audit_record h Stop allow
assert_file_exists "sink directory created" "$SD/new/deeper/log.jsonl"
touch "$TL_TMP/a-file"
SILVER_BULLET_HOOK_AUDIT_LOG="$SD/blocked-parent/log.jsonl" bash -c "source '$LIB/runtime-paths.sh'; source '$LIB/hook-audit.sh'; ln -s '$TL_TMP/a-file' '$SD/blocked-parent'; sb_hook_audit_record h Stop allow" || true
assert_file_absent "unusable sink directory: silently skipped" "$SD/blocked-parent/log.jsonl"

# ---- quality-gates-mode ------------------------------------------------------
# shellcheck source=../../hooks/lib/quality-gates-mode.sh
source "$LIB/quality-gates-mode.sh"
R="$TL_TMP/qg"
mkdir -p "$R/.planning/phases/01-x"
nok sb_qg_find_artifact "$R" PLAN.md
printf '# T\n\nBody line\n' >"$R/.planning/PLAN.md"
assert_eq "artifact in .planning" "$R/.planning/PLAN.md" "$(sb_qg_find_artifact "$R" PLAN.md)"
rm -f "$R/.planning/PLAN.md"
printf 'x\n' >"$R/.planning/phases/01-x/PLAN.md"
assert_eq "artifact in a phase dir" "$R/.planning/phases/01-x/PLAN.md" "$(sb_qg_find_artifact "$R" PLAN.md)"
rm -f "$R/.planning/phases/01-x/PLAN.md"
printf 'x\n' >"$R/.planning/phases/01-x/01-PLAN.md"
assert_eq "prefixed artifact in a phase dir" "$R/.planning/phases/01-x/01-PLAN.md" "$(sb_qg_find_artifact "$R" PLAN.md)"
rm -f "$R/.planning/phases/01-x/01-PLAN.md"
ln -s "$TL_TMP/target" "$R/.planning/PLAN.md"
nok sb_qg_find_artifact "$R" PLAN.md
rm -f "$R/.planning/PLAN.md"

printf '# Only headings\n\n| --- | :-: |\n' >"$R/body.md"
nok sb_qg_artifact_has_body "$R/body.md"
printf '# H\nreal content\n' >"$R/body.md"
ok sb_qg_artifact_has_body "$R/body.md"
nok sb_qg_artifact_has_body "$R/no-such-file.md"
printf 'status: PASSED\n' >"$R/v.md"
ok sb_qg_verification_passed "$R/v.md"
printf 'status: failed\n' >"$R/v.md"
nok sb_qg_verification_passed "$R/v.md"

assert_eq "no artifacts: design mode" "design" "$(sb_qg_detect_mode "$R")"
printf '# Plan\nsteps\n' >"$R/.planning/PLAN.md"
printf '# V\nstatus: passed\nok\n' >"$R/.planning/VERIFICATION.md"
assert_eq "plan + passing verification: adversarial" "adversarial" "$(sb_qg_detect_mode "$R")"
ok sb_qg_repo_requires_pre_ship_marker "$R"
printf '# V\nstatus: failed\nok\n' >"$R/.planning/VERIFICATION.md"
assert_eq "failing verification: design" "design" "$(sb_qg_detect_mode "$R")"
nok sb_qg_repo_requires_pre_ship_marker "$R"
rm -f "$R/.planning/VERIFICATION.md"
nok sb_qg_repo_requires_pre_ship_marker "$R"

assert_eq "adversarial marker" "silver-quality-gates-adversarial" "$(sb_qg_mode_marker adversarial)"
assert_eq "design marker" "silver-quality-gates-design" "$(sb_qg_mode_marker design)"
assert_eq "default marker" "silver-quality-gates-design" "$(sb_qg_mode_marker)"
assert_eq "devops adversarial marker" "devops-quality-gates-adversarial" "$(sb_dqg_mode_marker adversarial)"
assert_eq "devops design marker" "devops-quality-gates-design" "$(sb_dqg_mode_marker design)"
assert_eq "devops default marker" "devops-quality-gates-design" "$(sb_dqg_mode_marker)"
ok sb_qg_state_has_marker $'a\nb\n' b
nok sb_qg_state_has_marker $'a\nbb\n' b
ok sb_qg_preplan_marker_recorded $'silver-quality-gates-design\n'
ok sb_qg_preplan_marker_recorded $'silver-quality-gates\n'
nok sb_qg_preplan_marker_recorded $'other\n'
ok sb_qg_pre_ship_marker_recorded $'silver-quality-gates-adversarial\n'
nok sb_qg_pre_ship_marker_recorded $'silver-quality-gates-design\n'
ok sb_dqg_preplan_marker_recorded $'devops-quality-gates-design\n'
ok sb_dqg_preplan_marker_recorded $'devops-quality-gates\n'
nok sb_dqg_preplan_marker_recorded $'other\n'
ok sb_dqg_pre_ship_marker_recorded $'devops-quality-gates-adversarial\n'
nok sb_dqg_pre_ship_marker_recorded $'x\n'

# ---- e2e-matrix-routing -----------------------------------------------------
# shellcheck source=../../hooks/lib/e2e-matrix-routing.sh
source "$LIB/e2e-matrix-routing.sh"
nok sb_e2e_matrix_routing_row_active
sb_e2e_matrix_set_routing_row_marker
ok sb_e2e_matrix_routing_row_active
sb_e2e_matrix_clear_routing_row_marker
nok sb_e2e_matrix_routing_row_active
M="$(sb_e2e_matrix_routing_row_marker_file)"
ln -s "$TL_TMP/target" "$M"
nok sb_e2e_matrix_routing_row_active
sb_e2e_matrix_clear_routing_row_marker
assert_file_absent "clear removes a symlinked marker" "$M"
assert_eq "marker dir created on set" "1" "$( rm -rf "${SD:?}"; sb_e2e_matrix_set_routing_row_marker; mkdir -p "$SD"; echo 1)"
assert_eq "default marker dir without a state dir" "/tmp/e2e-matrix-routing-row" "$(env -u SB_RUNTIME_STATE_DIR bash -c "source '$LIB/e2e-matrix-routing.sh'; sb_e2e_matrix_routing_row_marker_file")"

# ---- update-check fetch guard -----------------------------------------------
# shellcheck source=../../hooks/lib/check-sb-update.sh
source "$LIB/check-sb-update.sh"
unset SILVER_BULLET_UPDATE_CHECK_LATEST
nok env PATH="$(tl_path_without curl)" bash -c "source '$LIB/check-sb-update.sh'; sb_update_fetch_latest_version"
nok env PATH="$(tl_path_without jq)" bash -c "source '$LIB/check-sb-update.sh'; sb_update_fetch_latest_version"
REG="$TL_TMP/reg.json"
printf 'not json' >"$REG"
nok sb_update_resolve_installed_version "$REG"

tl_results

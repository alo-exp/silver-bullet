#!/usr/bin/env bash
# Behaviour tests for scripts/enterprise-e2e/lib/host.sh and the three host adapters.
# Everything runs against temp dirs; no agent CLI, git remote or network is touched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

HOST_LIB="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/host.sh"
CORE_LIB="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
ADAPTERS="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/adapters"

# Neutralise ambient host selection so each case controls it explicitly.
NOHOST=(-u SB_E2E_LIVE_RUNTIME -u SILVER_BULLET_RUNTIME -u SB_ROOT -u SB_TEST_ENTERPRISE_APP_ROOT)

CFG="$TL_TMP/hosts.json"
cat >"$CFG" <<'JSON'
{
  "default_host": "codex",
  "hosts": {
    "claude": {"lock_file": ".lock-claude", "git_branch": "main", "test_app_root": "/abs/claude-app", "tags": ["a", "b"]},
    "codex":  {"lock_file": ".lock-codex", "matrix_log": ".codex.log", "git_branch": "track-codex", "test_app_root": "apps/codex-app"},
    "cursor": {"lock_file": ".lock-cursor"}
  }
}
JSON

# --- harness root / config file --------------------------------------------
e2e_call "$HOST_LIB" -- enterprise_e2e_harness_root
assert_eq "harness root is scripts/enterprise-e2e" "$TL_REPO_ROOT/scripts/enterprise-e2e" "$TL_OUT"
e2e_call "$HOST_LIB" -u SB_E2E_HOSTS_CONFIG -- enterprise_e2e_hosts_config_file
assert_eq "default hosts config" "$TL_REPO_ROOT/scripts/enterprise-e2e/config/hosts.json" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_HOSTS_CONFIG=$CFG" -- enterprise_e2e_hosts_config_file
assert_eq "hosts config override" "$CFG" "$TL_OUT"

# --- host_config_get --------------------------------------------------------
e2e_call "$HOST_LIB" "SB_E2E_HOSTS_CONFIG=$TL_TMP/absent.json" -- enterprise_e2e_host_config_get lock_file codex
assert_eq "missing config file returns 1" 1 "$TL_STATUS"
e2e_call "$HOST_LIB" "SB_E2E_HOSTS_CONFIG=$CFG" -- enterprise_e2e_host_config_get lock_file codex
assert_eq "named host string field" ".lock-codex" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_HOSTS_CONFIG=$CFG" -- enterprise_e2e_host_config_get tags claude
assert_eq "list field is space-joined" "a b" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_HOSTS_CONFIG=$CFG" -- enterprise_e2e_host_config_get nope claude
assert_eq "absent field returns 1" 1 "$TL_STATUS"
e2e_call "$HOST_LIB" "SB_E2E_HOSTS_CONFIG=$CFG" "SB_E2E_LIVE_RUNTIME=cursor" -- enterprise_e2e_host_config_get lock_file
assert_eq "host defaults to the active matrix host" ".lock-cursor" "$TL_OUT"

# --- matrix_host ------------------------------------------------------------
e2e_call "$HOST_LIB" "${NOHOST[@]}" "SB_E2E_HOSTS_CONFIG=$CFG" -- enterprise_e2e_matrix_host
assert_eq "no env: default_host from config" "codex" "$TL_OUT"
e2e_call "$HOST_LIB" "${NOHOST[@]}" "SB_E2E_HOSTS_CONFIG=$TL_TMP/absent.json" -- enterprise_e2e_matrix_host
assert_eq "no env, no config: claude" "claude" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=cursor" "SILVER_BULLET_RUNTIME=codex" -- enterprise_e2e_matrix_host
assert_eq "SB_E2E_LIVE_RUNTIME wins" "cursor" "$TL_OUT"
e2e_call "$HOST_LIB" -u SB_E2E_LIVE_RUNTIME "SILVER_BULLET_RUNTIME=codex" -- enterprise_e2e_matrix_host
assert_eq "SILVER_BULLET_RUNTIME is honoured" "codex" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=bogus" -- enterprise_e2e_matrix_host
assert_eq "unknown host collapses to claude" "claude" "$TL_OUT"

# --- apply_host_path_default ------------------------------------------------
# SB_ROOT must exist for the cd inside the function: use a real directory.
mkdir -p "$TL_TMP/sbroot"
e2e_script "source '$HOST_LIB'; enterprise_e2e_apply_host_path_default MY_VAR lock_file; echo \"MY_VAR=\${MY_VAR:-unset}\"" \
  "SB_ROOT=$TL_TMP/sbroot" "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "path default exported under SB_ROOT" "MY_VAR=$TL_TMP/sbroot/.lock-codex" "$TL_OUT"
e2e_script "source '$HOST_LIB'; enterprise_e2e_apply_host_path_default MY_VAR lock_file; echo \"MY_VAR=\${MY_VAR:-unset}\"" \
  "SB_ROOT=$TL_TMP/sbroot" "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG" "MY_VAR=preset"
assert_eq "preset variable is left alone" "MY_VAR=preset" "$TL_OUT"
e2e_script "source '$HOST_LIB'; enterprise_e2e_apply_host_path_default MY_VAR no_such_field; echo \"MY_VAR=\${MY_VAR:-unset}\"" \
  "SB_ROOT=$TL_TMP/sbroot" "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "field absent from config leaves variable unset" "MY_VAR=unset" "$TL_OUT"
# SB_ROOT unset and enterprise_e2e_sb_root undefined: falls back to the harness root.
e2e_script "source '$HOST_LIB'; enterprise_e2e_apply_host_path_default MY_VAR lock_file; echo \"MY_VAR=\${MY_VAR:-unset}\"" \
  "${NOHOST[@]}" "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "harness-root fallback when SB_ROOT and sb_root() are absent" \
  "MY_VAR=$TL_REPO_ROOT/scripts/.lock-codex" "$TL_OUT"

# --- apply_test_app_fixture_default ----------------------------------------
fixture_default() {  # fixture_default CODE-PREFIX ENV...
  local prefix="$1"
  shift
  e2e_script "source '$HOST_LIB'; $prefix enterprise_e2e_apply_test_app_fixture_default; echo \"APP=\${SB_TEST_ENTERPRISE_APP_ROOT:-unset}\"" "$@"
}
fixture_default "" "SB_TEST_ENTERPRISE_APP_ROOT=/preset" "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "preset app root is kept" "APP=/preset" "$TL_OUT"
fixture_default "" -u SB_TEST_ENTERPRISE_APP_ROOT "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "host without test_app_root leaves it unset" "APP=unset" "$TL_OUT"
fixture_default "" -u SB_TEST_ENTERPRISE_APP_ROOT "SB_E2E_LIVE_RUNTIME=claude" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "absolute test_app_root is exported verbatim" "APP=/abs/claude-app" "$TL_OUT"
fixture_default "" -u SB_TEST_ENTERPRISE_APP_ROOT "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG" "SB_ROOT=/some/root"
assert_eq "relative test_app_root joins SB_ROOT" "APP=/some/root/apps/codex-app" "$TL_OUT"
fixture_default "" -u SB_TEST_ENTERPRISE_APP_ROOT -u SB_ROOT "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "relative root without SB_ROOT uses the harness parent" \
  "APP=$TL_REPO_ROOT/scripts/apps/codex-app" "$TL_OUT"
fixture_default "enterprise_e2e_sb_root() { echo /fake/sb; };" -u SB_TEST_ENTERPRISE_APP_ROOT -u SB_ROOT \
  "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "relative root without SB_ROOT prefers enterprise_e2e_sb_root" "APP=/fake/sb/apps/codex-app" "$TL_OUT"

# --- apply_matrix_host_defaults --------------------------------------------
SBR="$TL_TMP/sbr"
mkdir -p "$SBR/hooks/lib"
cat >"$SBR/hooks/lib/runtime-paths.sh" <<'RP'
E2E_RUNTIME_PATHS_SOURCED=1
RP
cat >"$TL_TMP/dump.sh" <<'DUMP'
source "$1"
enterprise_e2e_apply_matrix_host_defaults
echo "SB_ROOT=$SB_ROOT"
echo "RT=$SB_E2E_LIVE_RUNTIME/$SILVER_BULLET_RUNTIME"
echo "SRC=${E2E_RUNTIME_PATHS_SOURCED:-no}"
echo "LOCK=${SB_E2E_LIVE_TEST_LOCK_FILE:-}"
echo "MLOG=${SB_E2E_MATRIX_LOG:-}"
echo "APP=${SB_TEST_ENTERPRISE_APP_ROOT:-unset}"
DUMP
tl_run env -u SB_E2E_LIVE_RUNTIME -u SB_TEST_ENTERPRISE_APP_ROOT -u SB_E2E_LIVE_TEST_LOCK_FILE -u SB_E2E_MATRIX_LOG \
  "SB_ROOT=$SBR" "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG" bash "$TL_TMP/dump.sh" "$HOST_LIB"
assert_contains "defaults keep explicit SB_ROOT" "$TL_OUT" "SB_ROOT=$SBR"
assert_contains "defaults pin runtime variables to the host" "$TL_OUT" "RT=codex/codex"
assert_contains "defaults source the repo runtime-paths helper" "$TL_OUT" "SRC=1"
assert_contains "defaults export per-host lock file" "$TL_OUT" "LOCK=$SBR/.lock-codex"
assert_contains "defaults export per-host matrix log" "$TL_OUT" "MLOG=$SBR/.codex.log"
assert_contains "defaults export per-host fixture" "$TL_OUT" "APP=$SBR/apps/codex-app"
# No SB_ROOT, no sb_root(): derived from the harness root; runtime-paths helper absent in that tree is fine.
tl_run env -u SB_ROOT -u SB_TEST_ENTERPRISE_APP_ROOT "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_HOSTS_CONFIG=$CFG" bash "$TL_TMP/dump.sh" "$HOST_LIB"
assert_contains "SB_ROOT derived from harness root" "$TL_OUT" "SB_ROOT=$TL_REPO_ROOT/scripts"
assert_contains "no runtime-paths helper there: not sourced" "$TL_OUT" "SRC=no"
mkdir -p "$TL_TMP/viafn"
tl_run env -u SB_ROOT -u SB_TEST_ENTERPRISE_APP_ROOT "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_HOSTS_CONFIG=$CFG" \
  bash -c 'source "$1"; enterprise_e2e_sb_root() { echo "'"$TL_TMP"'/viafn"; }; enterprise_e2e_apply_matrix_host_defaults 2>/dev/null; echo "SB_ROOT=$SB_ROOT"' _ "$HOST_LIB"
assert_contains "SB_ROOT prefers enterprise_e2e_sb_root when defined" "$TL_OUT" "SB_ROOT=$TL_TMP/viafn"

# --- assert_host_git_branch -------------------------------------------------
e2e_call "$HOST_LIB" "SB_E2E_HOST_GIT_BRANCH_ENFORCE=0" -- enterprise_e2e_assert_host_git_branch
assert_eq "enforcement off exits 0" 0 "$TL_STATUS"
assert_contains "enforcement off says so" "$TL_OUT" "skipped (SB_E2E_HOST_GIT_BRANCH_ENFORCE=0)"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_HOSTS_CONFIG=$CFG" -- enterprise_e2e_assert_host_git_branch
assert_eq "host without git_branch: nothing to enforce" 0 "$TL_STATUS"
assert_eq "host without git_branch: silent" "" "$TL_OUT"

BR_ROOT="$TL_TMP/harness-git"
tl_git_repo "$BR_ROOT"
git -C "$BR_ROOT" checkout -q -b track-codex
branch_check() {  # branch_check ROOT ENV...
  local root="$1"
  shift
  e2e_script "source '$HOST_LIB'; enterprise_e2e_preflight_fail() { echo \"PF: \$*\" >&2; return 1; }; enterprise_e2e_assert_host_git_branch" \
    "SB_ROOT=$root" "SB_E2E_HOSTS_CONFIG=$CFG" "$@"
}
branch_check "$BR_ROOT" "SB_E2E_LIVE_RUNTIME=codex"
assert_eq "on the track branch: ok" 0 "$TL_STATUS"
assert_contains "reports want/have" "$TL_OUT" "want=track-codex have=track-codex host=codex"
assert_match "reports short sha" 'OK on track-codex @ [0-9a-f]{7,}' "$TL_OUT"
git -C "$BR_ROOT" checkout -q main
branch_check "$BR_ROOT" "SB_E2E_LIVE_RUNTIME=codex"
assert_eq "wrong branch fails" 1 "$TL_STATUS"
assert_contains "wrong branch names both branches" "$TL_ERR" "SB harness on 'main' — expected 'track-codex' for host=codex"
git -C "$BR_ROOT" checkout -q --detach
branch_check "$BR_ROOT" "SB_E2E_LIVE_RUNTIME=codex"
assert_eq "detached HEAD fails" 1 "$TL_STATUS"
assert_contains "detached HEAD is reported" "$TL_OUT" "have=detached"
mkdir -p "$TL_TMP/not-git"
branch_check "$TL_TMP/not-git" "SB_E2E_LIVE_RUNTIME=codex"
assert_eq "non-git harness fails" 1 "$TL_STATUS"
assert_contains "non-git harness named" "$TL_ERR" "SB harness is not a git repo: $TL_TMP/not-git"
# SB_ROOT unset and no sb_root(): derived from harness root (scripts/, which is not a git root).
e2e_script "source '$HOST_LIB'; enterprise_e2e_preflight_fail() { echo \"PF: \$*\" >&2; return 1; }; enterprise_e2e_assert_host_git_branch" \
  -u SB_ROOT "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_eq "SB_ROOT derived from harness root: scripts/ has no .git" 1 "$TL_STATUS"
assert_contains "derived root reported" "$TL_ERR" "SB harness is not a git repo: $TL_REPO_ROOT/scripts"
e2e_script "source '$HOST_LIB'; enterprise_e2e_sb_root() { echo '$BR_ROOT'; }; enterprise_e2e_preflight_fail() { echo \"PF: \$*\" >&2; return 1; }; enterprise_e2e_assert_host_git_branch" \
  -u SB_ROOT "SB_E2E_LIVE_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG"
assert_contains "enterprise_e2e_sb_root() is preferred for the root" "$TL_OUT" "have=detached"

# --- row attempt logs -------------------------------------------------------
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=claude" "SB_ROOT=/r" -- enterprise_e2e_row_attempt_log 5
assert_eq "claude attempt 1 legacy name" "/r/.e2e-row5-attempt.log" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=claude" "SB_ROOT=/r" -- enterprise_e2e_row_attempt_log 5 3
assert_eq "claude attempt 3 legacy name" "/r/.e2e-row5-attempt3.log" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=codex" "SB_ROOT=/r" -- enterprise_e2e_row_attempt_log 7
assert_eq "codex attempt 1 host name" "/r/.e2e-row7-codex-attempt.log" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=cursor" "SB_ROOT=/r" -- enterprise_e2e_row_attempt_log 7 2
assert_eq "cursor attempt 2 host name" "/r/.e2e-row7-cursor-attempt2.log" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=claude" "SB_ROOT=/r" -- enterprise_e2e_row_attempt_log_glob
assert_eq "claude glob" "/r/.e2e-row*-attempt.log" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=cursor" "SB_ROOT=/r" -- enterprise_e2e_row_attempt_log_glob
assert_eq "cursor glob" "/r/.e2e-row*-cursor-attempt.log" "$TL_OUT"

# --- routing state / runtime state dir -------------------------------------
e2e_call "$HOST_LIB" -u SB_RUNTIME_STATE_DIR -u SB_ROOT -u SB_E2E_ISOLATED_CLAUDE_CONFIG "HOME=/h" -- enterprise_e2e_routing_state_file
assert_eq "routing state falls back to ~/.claude" "/h/.claude/.silver-bullet/state" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_RUNTIME_STATE_DIR=/custom/state" -- enterprise_e2e_routing_state_file
assert_eq "routing state honours SB_RUNTIME_STATE_DIR" "/custom/state/state" "$TL_OUT"
e2e_call "$HOST_LIB" -u SB_RUNTIME_STATE_DIR "SB_ROOT=$SBR" "HOME=/h" -- enterprise_e2e_routing_state_file
assert_eq "routing state sources the helper when it exists (stub sets nothing)" "/h/.claude/.silver-bullet/state" "$TL_OUT"
e2e_call "$HOST_LIB" -u SB_RUNTIME_STATE_DIR "SB_ROOT=$TL_REPO_ROOT" "SILVER_BULLET_RUNTIME=codex" "HOME=/h" -- enterprise_e2e_routing_state_file
assert_eq "routing state from real runtime-paths (codex)" "/h/.codex/.silver-bullet/state" "$TL_OUT"
# Isolated Claude config: core.sh provides apply_isolated_claude_runtime_paths.
mkdir -p "$TL_TMP/cfgdir/.claude"
tl_run env -u SB_RUNTIME_STATE_DIR -u SB_ROOT -u SB_RUNTIME_EXTRA_STATE_ROOTS "SB_E2E_ISOLATED_CLAUDE_CONFIG=1" "CLAUDE_CONFIG_DIR=$TL_TMP/cfgdir" \
  bash -c 'source "$1"; enterprise_e2e_routing_state_file' _ "$CORE_LIB"
assert_eq "isolated config pins routing state under CLAUDE_CONFIG_DIR/.claude" "$TL_TMP/cfgdir/.claude/.silver-bullet/state" "$TL_OUT"
# Isolated flag set but host.sh alone: the missing helper is tolerated.
e2e_call "$HOST_LIB" -u SB_RUNTIME_STATE_DIR -u SB_ROOT "SB_E2E_ISOLATED_CLAUDE_CONFIG=1" "CLAUDE_CONFIG_DIR=$TL_TMP/cfgdir" "HOME=/h" -- enterprise_e2e_routing_state_file
assert_eq "missing isolated helper tolerated" "/h/.claude/.silver-bullet/state" "$TL_OUT"

e2e_call "$HOST_LIB" -u SB_RUNTIME_STATE_DIR -u SB_ROOT "HOME=/h" -- enterprise_e2e_runtime_state_dir
assert_eq "runtime state dir fallback" "/h/.claude/.silver-bullet" "$TL_OUT"
e2e_call "$HOST_LIB" -u SB_RUNTIME_STATE_DIR "SB_ROOT=$TL_REPO_ROOT" "SILVER_BULLET_RUNTIME=codex" "HOME=/h" -- enterprise_e2e_runtime_state_dir
assert_eq "runtime state dir from real runtime-paths (codex)" "/h/.codex/.silver-bullet" "$TL_OUT"
e2e_call "$HOST_LIB" "SB_RUNTIME_STATE_DIR=/preset/sd" -- enterprise_e2e_runtime_state_dir
assert_eq "runtime state dir honours preset" "/preset/sd" "$TL_OUT"

# --- route translation ------------------------------------------------------
route() { e2e_call "$HOST_LIB" "SB_E2E_LIVE_RUNTIME=$1" -- enterprise_e2e_matrix_host_route "$2"; }
route claude "/sb:plan";   assert_eq "claude route unchanged" "/sb:plan" "$TL_OUT"
route codex "/sb:plan";    assert_eq "codex route uses \$ prefix" '$sb:plan' "$TL_OUT"
route codex "plain text";  assert_eq "codex non-/sb route unchanged" "plain text" "$TL_OUT"
route cursor "/sb";        assert_eq "cursor bare /sb kept" "/sb" "$TL_OUT"
route cursor "/sb:plan";   assert_eq "cursor strips /sb: prefix" "plan" "$TL_OUT"
route cursor "/other";     assert_eq "cursor other route unchanged" "/other" "$TL_OUT"

# --- adapter sourcing -------------------------------------------------------
e2e_script "source '$HOST_LIB'; enterprise_e2e_source_host_adapter && declare -f enterprise_e2e_adapter_preflight >/dev/null && echo SOURCED" "SB_E2E_LIVE_RUNTIME=cursor"
assert_eq "existing adapter is sourced" "SOURCED" "$TL_OUT"
mkdir -p "$TL_TMP/fakeharness/lib"
ln -s "$HOST_LIB" "$TL_TMP/fakeharness/lib/host.sh"
e2e_call "$TL_TMP/fakeharness/lib/host.sh" "SB_E2E_LIVE_RUNTIME=codex" -- enterprise_e2e_source_host_adapter
assert_eq "missing adapter returns 1" 1 "$TL_STATUS"
assert_contains "missing adapter warns" "$TL_ERR" "WARN: missing host adapter $TL_TMP/fakeharness/lib/adapters/codex.sh"

# --- adapters ---------------------------------------------------------------
# claude: thin wrappers around core helpers (replaced with recorders here).
e2e_script "source '$ADAPTERS/claude.sh'
enterprise_e2e_run_install_claude() { echo \"install:\$1\"; }
enterprise_e2e_preflight_claude_token_gateway() { echo \"preflight:\$1\"; }
enterprise_e2e_adapter_install /explicit
enterprise_e2e_adapter_install
enterprise_e2e_adapter_preflight /pre
enterprise_e2e_adapter_preflight" "SB_ROOT=/envroot"
assert_eq "claude adapter forwards roots" $'install:/explicit\ninstall:/envroot\npreflight:/pre\npreflight:/envroot' "$TL_OUT"

# cursor adapter
mkdir -p "$TL_TMP/cur/scripts"
cat >"$TL_TMP/cur/scripts/install-cursor.sh" <<'S'
echo "cursor-installer ran in $(pwd) args=$*"
S
e2e_call "$ADAPTERS/cursor.sh" -- enterprise_e2e_adapter_install ""
assert_eq "cursor install without a root fails" 1 "$TL_STATUS"
e2e_call "$ADAPTERS/cursor.sh" -- enterprise_e2e_adapter_install "$TL_TMP/no-such-dir"
assert_eq "cursor install with a missing dir fails" 1 "$TL_STATUS"
e2e_call "$ADAPTERS/cursor.sh" -- enterprise_e2e_adapter_install "$TL_TMP/cur"
assert_eq "cursor install ok" 0 "$TL_STATUS"
assert_contains "cursor install announces itself" "$TL_OUT" "Plugin install (Cursor):"
assert_contains "cursor installer ran from the SB root" "$TL_OUT" "cursor-installer ran in $TL_TMP/cur args="
e2e_call "$ADAPTERS/cursor.sh" -- enterprise_e2e_adapter_preflight
assert_contains "cursor preflight message" "$TL_OUT" "Cursor preflight: cursor-agent CLI or CURSOR_API_KEY required"

# codex adapter
mkdir -p "$TL_TMP/cdx/scripts"
cat >"$TL_TMP/cdx/scripts/install-codex.sh" <<'S'
echo "codex-installer args=$*"
S
e2e_call "$ADAPTERS/codex.sh" -- enterprise_e2e_adapter_install ""
assert_eq "codex install without a root fails" 1 "$TL_STATUS"
e2e_call "$ADAPTERS/codex.sh" "SB_E2E_SKIP_CODEX_INSTALL=1" -- enterprise_e2e_adapter_install "$TL_TMP/cdx"
assert_eq "codex install skip exits 0" 0 "$TL_STATUS"
assert_contains "codex install skip announced" "$TL_OUT" "SKIP: Codex plugin install (SB_E2E_SKIP_CODEX_INSTALL=1"
assert_not_contains "codex installer not run when skipped" "$TL_OUT" "codex-installer"
e2e_call "$ADAPTERS/codex.sh" -u SB_E2E_SKIP_CODEX_INSTALL -- enterprise_e2e_adapter_install "$TL_TMP/cdx"
assert_contains "codex installer receives --purge-legacy-skills" "$TL_OUT" "codex-installer args=--purge-legacy-skills"
e2e_call "$ADAPTERS/codex.sh" -- enterprise_e2e_adapter_preflight
assert_contains "codex preflight message" "$TL_OUT" "Codex preflight: native CLI required"

# before_matrix_row
e2e_call "$ADAPTERS/codex.sh" -- enterprise_e2e_adapter_before_matrix_row ""
assert_eq "before-row without a root is a no-op" 0 "$TL_STATUS"
assert_eq "before-row without a root prints nothing" "" "$TL_OUT"

BR="$TL_TMP/before"
mkdir -p "$BR/hooks/lib" "$BR/scripts/enterprise-e2e/lib/deterministic"
echo 'echo "runtime-paths sourced rt=$SILVER_BULLET_RUNTIME"' >"$BR/hooks/lib/runtime-paths.sh"
cat >"$BR/scripts/enterprise-e2e/lib/deterministic/matrix-quiesce.sh" <<'S'
enterprise_e2e_matrix_quiesce_orchestrator_queue() { echo "quiesce:$1"; }
S
cat >"$BR/scripts/install-codex.sh" <<'S'
echo "seed args=$*" >>"$SEED_LOG"
S
before_row() { e2e_script "source '$ADAPTERS/codex.sh'; $1; enterprise_e2e_adapter_before_matrix_row '$BR'; echo \"RT=\$SILVER_BULLET_RUNTIME\"" -u SILVER_BULLET_RUNTIME "SEED_LOG=$TL_TMP/seed.log"; }
rm -f "$TL_TMP/seed.log"
before_row ":"
assert_eq "before-row ok" 0 "$TL_STATUS"
assert_contains "runtime defaults to codex" "$TL_OUT" "RT=codex"
assert_contains "runtime-paths helper sourced" "$TL_OUT" "runtime-paths sourced rt=codex"
assert_contains "orchestrator queue quiesced" "$TL_OUT" "quiesce:$BR"
assert_eq "hook trust seed requested" "seed args=--hook-trust-seed-only" "$(cat "$TL_TMP/seed.log")"
before_row "enterprise_e2e_fixture_ensure_branch() { echo ensure-branch; }"
assert_contains "fixture branch pin is invoked when defined" "$TL_OUT" "ensure-branch"
before_row "enterprise_e2e_fixture_ensure_branch() { return 1; }"
assert_eq "a failing branch pin aborts the row" 1 "$TL_STATUS"
assert_not_contains "aborted before quiesce" "$TL_OUT" "quiesce:"
# Without helper scripts the hook seed failure is swallowed.
BR2="$TL_TMP/before2"
mkdir -p "$BR2"
e2e_script "source '$ADAPTERS/codex.sh'; enterprise_e2e_adapter_before_matrix_row '$BR2'; echo done"  "E2E_CALL=1"
assert_eq "bare root: seed script missing is tolerated" 0 "$TL_STATUS"
assert_contains "bare root completes" "$TL_OUT" "done"

tl_results

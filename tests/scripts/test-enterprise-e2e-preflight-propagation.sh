#!/usr/bin/env bash
# Regression: enterprise_e2e_preflight_fail returns 1 instead of exiting, and bash ignores
# errexit inside a function called from an `||` list or an `if` condition. Every gate that
# reports a failure through it must therefore return non-zero itself, otherwise callers such as
# `enterprise_e2e_assert_host_git_branch || exit 1` print the error and carry on.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
CFG="$TL_TMP/hosts.json"
echo '{"hosts": {"codex": {"git_branch": "track-codex"}}}' >"$CFG"
BASE_ENV=("SILVER_BULLET_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG" -u SB_E2E_TEST_APP_BRANCH -u SB_E2E_TEST_APP_ROUND
  -u SB_E2E_LEDGER_FILE -u SB_E2E_TEST_APP_BRANCH_ENFORCE -u SB_E2E_HOST_GIT_BRANCH_ENFORCE -u SB_E2E_LIVE_RUNTIME
  -u SB_E2E_TEST_APP_BASELINE_SHA -u SB_TEST_ENTERPRISE_APP_ROOT -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT
  -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u CLAUDE_CONFIG_DIR)

# gate CODE ENV...: run CODE (a gate call) the way matrix.sh does: `CODE || exit 1`, then print a marker.
gate() {
  local code="$1"
  shift
  e2e_script "source '$CORE'; $code || { echo \"GATE-FAILED rc=\$?\"; exit 1; }; echo CONTINUED-PAST-GATE" "${BASE_ENV[@]}" "$@"
}
expect_blocked() {  # expect_blocked NAME
  assert_contains "$1: the gate reports failure to its caller" "$TL_OUT" "GATE-FAILED rc=1"
  assert_not_contains "$1: the caller does not continue" "$TL_OUT" "CONTINUED-PAST-GATE"
}

# --- harness branch gate (host.sh) -------------------------------------------
HARNESS="$TL_TMP/harness"
tl_git_repo "$HARNESS"
git -C "$HARNESS" checkout -q -b not-the-track
gate "enterprise_e2e_assert_host_git_branch" "SB_ROOT=$HARNESS"
expect_blocked "harness on the wrong branch"
assert_not_contains "wrong branch never prints OK" "$TL_OUT" "  OK on"
mkdir -p "$TL_TMP/not-git"
gate "enterprise_e2e_assert_host_git_branch" "SB_ROOT=$TL_TMP/not-git"
expect_blocked "harness that is not a git repo"
git -C "$HARNESS" checkout -q -b track-codex
gate "enterprise_e2e_assert_host_git_branch" "SB_ROOT=$HARNESS"
assert_contains "harness on the track branch passes the gate" "$TL_OUT" "CONTINUED-PAST-GATE"

# A linked git worktree has a .git file, not a directory; it is still a repo on its track branch.
MAIN_REPO="$TL_TMP/main-repo"
tl_git_repo "$MAIN_REPO"
git -C "$MAIN_REPO" worktree add -q -b track-codex "$TL_TMP/linked-worktree"
assert_eq "fixture: the worktree's .git is a file" "file" "$([[ -f "$TL_TMP/linked-worktree/.git" ]] && echo file || echo other)"
gate "enterprise_e2e_assert_host_git_branch" "SB_ROOT=$TL_TMP/linked-worktree"
assert_contains "harness in a linked worktree on the track branch passes" "$TL_OUT" "CONTINUED-PAST-GATE"

# --- test-app branch gates (test-app-branch.sh) -----------------------------
APP="$TL_TMP/app"
e2e_git_app "$APP"
gate "enterprise_e2e_assert_test_app_branch '$TL_TMP/absent'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/r-codex"
expect_blocked "assert: missing fixture"
gate "enterprise_e2e_assert_test_app_branch '$TL_TMP/not-git'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/r-codex"
expect_blocked "assert: fixture not a git repo"
gate "enterprise_e2e_assert_test_app_branch '$APP'" "SB_E2E_TEST_APP_BRANCH=main"
expect_blocked "assert: main as the target"
gate "enterprise_e2e_assert_test_app_branch '$APP'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/r-codex"
expect_blocked "assert: fixture on another branch"
gate "enterprise_e2e_ensure_test_app_branch '$TL_TMP/not-git'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/r-codex"
expect_blocked "ensure: fixture not a git repo"
gate "enterprise_e2e_ensure_test_app_branch '$APP'" "SB_E2E_TEST_APP_BRANCH=master"
expect_blocked "ensure: master as the target"
echo dirty >>"$APP/seed.txt"
gate "enterprise_e2e_ensure_test_app_branch '$APP'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/r-codex"
expect_blocked "ensure: dirty tree on another branch"
git -C "$APP" checkout -q -- seed.txt
gate "enterprise_e2e_ensure_test_app_branch '$APP'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/r-codex" "SB_E2E_TEST_APP_BASELINE_SHA=0000000"
expect_blocked "ensure: baseline sha missing"
assert_eq "ensure: nothing was checked out on failure" "main" "$(git -C "$APP" branch --show-current)"

# --- Claude token gateway (core.sh) -------------------------------------------
echo '{"env": {}}' >"$TL_TMP/settings-empty.json"
gate "enterprise_e2e_preflight_claude_token_gateway ''" "SB_ROOT="
expect_blocked "gateway: SB_ROOT missing"
gate "enterprise_e2e_preflight_claude_token_gateway '$TL_REPO_ROOT'" "CLAUDE_SETTINGS_FILE=$TL_TMP/settings-empty.json"
expect_blocked "gateway: no credentials"

tl_results

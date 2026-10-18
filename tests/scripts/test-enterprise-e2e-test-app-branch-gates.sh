#!/usr/bin/env bash
# Behaviour tests for scripts/enterprise-e2e/lib/test-app-branch.sh against temp git repos.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
CLEAN=(-u SB_E2E_TEST_APP_BRANCH -u SB_E2E_TEST_APP_ROUND -u SB_E2E_LEDGER_FILE -u SB_E2E_TEST_APP_BASELINE_SHA
  -u SB_E2E_PRODUCT_WORK_GATE -u SB_E2E_TEST_APP_BRANCH_ENFORCE -u SB_E2E_TEST_APP_ALLOW_DIRTY
  -u SB_E2E_TEST_APP_BRANCH_CREATE_ONLY -u SB_TEST_ENTERPRISE_APP_ROOT -u SB_E2E_LIVE_RUNTIME)

EMPTY_CFG="$TL_TMP/empty-hosts.json"
echo '{"hosts": {}}' >"$EMPTY_CFG"
BR_CFG="$TL_TMP/branch-hosts.json"
cat >"$BR_CFG" <<'JSON'
{"hosts": {"codex": {"test_app_git_branch": "enterprise-e2e/from-config", "test_app_git_baseline_sha": "cafe123"}}}
JSON

# call FN ARGS... with env in CALL_ENV (array); host pinned to codex with the empty config.
call() {
  e2e_call "$CORE" "${CLEAN[@]}" "SILVER_BULLET_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=${HOSTS_CFG:-$EMPTY_CFG}" "${CALL_ENV[@]}" -- "$@"
}
CALL_ENV=("E2E_X=1")

# --- default baseline sha ---------------------------------------------------
call enterprise_e2e_test_app_default_baseline_sha
assert_eq "default baseline" "8482e60" "$TL_OUT"
CALL_ENV=("SB_E2E_PRODUCT_WORK_GATE=1"); call enterprise_e2e_test_app_default_baseline_sha
assert_eq "product-work gate baseline" "09f8d1a" "$TL_OUT"
CALL_ENV=("SB_E2E_PRODUCT_WORK_GATE=1" "SB_E2E_TEST_APP_BASELINE_SHA=abc1234"); call enterprise_e2e_test_app_default_baseline_sha
assert_eq "explicit baseline wins" "abc1234" "$TL_OUT"
CALL_ENV=("E2E_X=1")

# --- ledger -> round --------------------------------------------------------
call enterprise_e2e_test_app_round_from_ledger ""
assert_eq "no ledger: rc 1" 1 "$TL_STATUS"
call enterprise_e2e_test_app_round_from_ledger "/x/ROUND-9-LEDGER.md"
assert_eq "plain round ledger" "9" "$TL_OUT"
call enterprise_e2e_test_app_round_from_ledger "/x/ROUND-CODEX-3-LEDGER.md"
assert_eq "codex round ledger" "3" "$TL_OUT"
call enterprise_e2e_test_app_round_from_ledger "/x/ROUND-CURSOR-4-REAL-LEDGER.md"
assert_eq "cursor round ledger" "4" "$TL_OUT"
call enterprise_e2e_test_app_round_from_ledger "/x/NOTES.md"
assert_eq "unrecognised ledger name: rc 1" 1 "$TL_STATUS"
CALL_ENV=("SB_E2E_LEDGER_FILE=/y/ROUND-7-LEDGER.md"); call enterprise_e2e_test_app_round_from_ledger
assert_eq "ledger defaults to SB_E2E_LEDGER_FILE" "7" "$TL_OUT"
CALL_ENV=("E2E_X=1")

# --- apply defaults ---------------------------------------------------------
defaults() {  # prints BRANCH/BASELINE after enterprise_e2e_apply_test_app_branch_defaults
  e2e_script "source '$CORE'; enterprise_e2e_apply_test_app_branch_defaults; echo \"BRANCH=\${SB_E2E_TEST_APP_BRANCH:-unset} BASE=\${SB_E2E_TEST_APP_BASELINE_SHA:-unset}\"" \
    "${CLEAN[@]}" "SILVER_BULLET_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=${HOSTS_CFG:-$EMPTY_CFG}" "$@"
}
defaults
assert_eq "no inputs: nothing exported" "BRANCH=unset BASE=unset" "$TL_OUT"
defaults "SB_E2E_TEST_APP_ROUND=5"
assert_eq "round env derives branch" "BRANCH=enterprise-e2e/round-5-codex BASE=unset" "$TL_OUT"
defaults "SB_E2E_TEST_APP_BRANCH=keep/me" "SB_E2E_TEST_APP_ROUND=5" "SB_E2E_TEST_APP_BASELINE_SHA=dead000"
assert_eq "explicit branch and baseline untouched" "BRANCH=keep/me BASE=dead000" "$TL_OUT"
defaults "SB_E2E_LEDGER_FILE=/z/ROUND-CODEX-8-LEDGER.md"
assert_eq "ledger derives branch" "BRANCH=enterprise-e2e/round-8-codex BASE=unset" "$TL_OUT"
defaults "SB_E2E_LEDGER_FILE=/z/NOTES.md"
assert_eq "unrecognised ledger exports nothing" "BRANCH=unset BASE=unset" "$TL_OUT"
HOSTS_CFG="$BR_CFG" defaults
assert_eq "hosts.json supplies branch and baseline" "BRANCH=enterprise-e2e/from-config BASE=cafe123" "$TL_OUT"
HOSTS_CFG="$BR_CFG" defaults "SB_E2E_TEST_APP_ROUND=2"
assert_eq "round beats hosts.json" "BRANCH=enterprise-e2e/round-2-codex BASE=cafe123" "$TL_OUT"

# --- expected branch --------------------------------------------------------
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=explicit/b" "SB_E2E_TEST_APP_ROUND=3"); call enterprise_e2e_test_app_expected_branch
assert_eq "expected: explicit branch" "explicit/b" "$TL_OUT"
CALL_ENV=("SB_E2E_TEST_APP_ROUND=3"); call enterprise_e2e_test_app_expected_branch
assert_eq "expected: round" "enterprise-e2e/round-3-codex" "$TL_OUT"
CALL_ENV=("E2E_X=1"); HOSTS_CFG="$BR_CFG" call enterprise_e2e_test_app_expected_branch
assert_eq "expected: hosts.json" "enterprise-e2e/from-config" "$TL_OUT"
CALL_ENV=("SB_E2E_LEDGER_FILE=/q/ROUND-CODEX-6-LEDGER.md"); call enterprise_e2e_test_app_expected_branch
assert_eq "expected: ledger" "enterprise-e2e/round-6-codex" "$TL_OUT"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_test_app_expected_branch
assert_eq "expected: nothing known -> rc 1" 1 "$TL_STATUS"
assert_eq "expected: nothing known -> silent" "" "$TL_OUT"

# --- git helpers ------------------------------------------------------------
APP="$TL_TMP/app"
e2e_git_app "$APP"
call enterprise_e2e_test_app_is_git_repo ""
assert_eq "empty dir arg is not a repo" 1 "$TL_STATUS"
mkdir -p "$TL_TMP/plain"
call enterprise_e2e_test_app_is_git_repo "$TL_TMP/plain"
assert_match "plain dir is not a repo (git rev-parse status)" '^128$' "$TL_STATUS"
call enterprise_e2e_test_app_is_git_repo "$APP"
assert_eq "git repo detected" 0 "$TL_STATUS"
call enterprise_e2e_test_app_is_dirty "$TL_TMP/plain"
assert_eq "non-repo is never dirty" 1 "$TL_STATUS"
call enterprise_e2e_test_app_is_dirty "$APP"
assert_eq "clean repo is not dirty" 1 "$TL_STATUS"
echo changed >>"$APP/seed.txt"
call enterprise_e2e_test_app_is_dirty "$APP"
assert_eq "modified repo is dirty" 0 "$TL_STATUS"
git -C "$APP" checkout -q -- seed.txt

e2e_script "source '$CORE'; enterprise_e2e_test_app_refuse_main_target main" "E2E_CALL=1"
assert_eq "main target refused" 1 "$TL_STATUS"
assert_contains "refusal names the branch" "$TL_ERR" "refusing to target test-app branch 'main'"
e2e_script "source '$CORE'; enterprise_e2e_test_app_refuse_main_target master" "E2E_CALL=1"
assert_eq "master target refused" 1 "$TL_STATUS"
e2e_script "source '$CORE'; enterprise_e2e_test_app_refuse_main_target enterprise-e2e/round-1-codex; echo fine" "E2E_CALL=1"
assert_eq "isolated branch accepted" "fine" "$TL_OUT"

# --- assert_test_app_branch (no checkout) ----------------------------------
CALL_ENV=("SB_E2E_TEST_APP_BRANCH_ENFORCE=0"); call enterprise_e2e_assert_test_app_branch "$APP"
assert_eq "assert: enforcement off exits 0" 0 "$TL_STATUS"
assert_contains "assert: enforcement off message" "$TL_OUT" "skipped (SB_E2E_TEST_APP_BRANCH_ENFORCE=0)"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_assert_test_app_branch "$TL_TMP/missing-app"
assert_eq "assert: missing fixture fails" 1 "$TL_STATUS"
assert_contains "assert: missing fixture message" "$TL_ERR" "test app fixture missing: $TL_TMP/missing-app"
call enterprise_e2e_assert_test_app_branch "$TL_TMP/plain"
assert_eq "assert: non-git fixture fails" 1 "$TL_STATUS"
assert_contains "assert: non-git message" "$TL_ERR" "test app is not a git repo: $TL_TMP/plain"
call enterprise_e2e_assert_test_app_branch "$APP"
assert_eq "assert: no expected branch warns and passes" 0 "$TL_STATUS"
assert_contains "assert: warn text" "$TL_OUT" "WARN: test-app branch assert skipped"
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=main"); call enterprise_e2e_assert_test_app_branch "$APP"
assert_eq "assert: main as target refused" 1 "$TL_STATUS"
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-1-codex"); call enterprise_e2e_assert_test_app_branch "$APP"
assert_eq "assert: wrong branch fails" 1 "$TL_STATUS"
assert_contains "assert: wrong branch states both" "$TL_ERR" "test app on 'main' — expected 'enterprise-e2e/round-1-codex'"
assert_eq "assert never checks out" "main" "$(git -C "$APP" branch --show-current)"
git -C "$APP" checkout -q -b enterprise-e2e/round-1-codex
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-1-codex"); call enterprise_e2e_assert_test_app_branch "$APP"
assert_eq "assert: matching clean branch passes" 0 "$TL_STATUS"
assert_match "assert: clean message carries the sha" 'OK on enterprise-e2e/round-1-codex @ [0-9a-f]{7,}' "$TL_OUT"
echo wip >>"$APP/seed.txt"
call enterprise_e2e_assert_test_app_branch "$APP"
assert_eq "assert: matching dirty branch passes" 0 "$TL_STATUS"
assert_contains "assert: dirty message" "$TL_OUT" "(dirty — matrix/agent work in progress)"
# Default fixture dir argument comes from the harness.
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-1-codex" "SB_TEST_ENTERPRISE_APP_ROOT=$APP"); call enterprise_e2e_assert_test_app_branch
assert_contains "assert: fixture dir defaults to SB_TEST_ENTERPRISE_APP_ROOT" "$TL_OUT" "fixture=$APP"
git -C "$APP" checkout -q -- seed.txt

# --- ensure_test_app_branch (may check out / create) -----------------------
ENS="$TL_TMP/ens"
e2e_git_app "$ENS"
BASE="$(git -C "$ENS" rev-parse --short HEAD)"
ensure() { CALL_ENV=("$@"); call enterprise_e2e_ensure_test_app_branch "$ENS"; }
ensure "SB_E2E_TEST_APP_BRANCH_ENFORCE=0"
assert_contains "ensure: enforcement off" "$TL_OUT" "skipped (SB_E2E_TEST_APP_BRANCH_ENFORCE=0)"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_ensure_test_app_branch "$TL_TMP/plain"
assert_eq "ensure: non-git fails" 1 "$TL_STATUS"
assert_contains "ensure: non-git message" "$TL_ERR" "test app is not a git repo"
ensure "E2E_X=1"
assert_eq "ensure: no expected branch warns and passes" 0 "$TL_STATUS"
assert_contains "ensure: warn text" "$TL_OUT" "WARN: test-app branch policy skipped"
ensure "SB_E2E_TEST_APP_BRANCH=master"
assert_eq "ensure: master refused" 1 "$TL_STATUS"
# Leaving main creates the branch from the baseline.
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-2-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE"
assert_eq "ensure: creates branch from baseline" 0 "$TL_STATUS"
assert_contains "ensure: announces leaving main" "$TL_OUT" "leaving main — creating/checking out enterprise-e2e/round-2-codex from $BASE"
assert_eq "ensure: now on the new branch" "enterprise-e2e/round-2-codex" "$(git -C "$ENS" branch --show-current)"
assert_contains "ensure: reports checkout" "$TL_OUT" "checked out enterprise-e2e/round-2-codex @ "
# Already on it: clean, dirty, dirty+allowed.
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-2-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE"
assert_match "ensure: already on branch (clean)" 'OK on enterprise-e2e/round-2-codex @ [0-9a-f]{7,}' "$TL_OUT"
echo wip >>"$ENS/seed.txt"
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-2-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE"
assert_contains "ensure: already on branch (dirty)" "$TL_OUT" "OK on enterprise-e2e/round-2-codex (dirty — matrix/agent work in progress)"
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-2-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE" "SB_E2E_TEST_APP_ALLOW_DIRTY=1"
assert_contains "ensure: already on branch (dirty allowed)" "$TL_OUT" "dirty allowed via SB_E2E_TEST_APP_ALLOW_DIRTY=1"
# Dirty + elsewhere.
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-3-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE"
assert_eq "ensure: dirty tree on another branch is refused" 1 "$TL_STATUS"
assert_contains "ensure: refusal explains" "$TL_ERR" "with dirty tree — expected 'enterprise-e2e/round-3-codex'. Refusing checkout"
assert_eq "ensure: dirty refusal does not switch" "enterprise-e2e/round-2-codex" "$(git -C "$ENS" branch --show-current)"
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-3-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE" "SB_E2E_TEST_APP_BRANCH_CREATE_ONLY=1"
assert_eq "ensure: create-only while dirty succeeds" 0 "$TL_STATUS"
assert_contains "ensure: create-only created" "$TL_OUT" "created enterprise-e2e/round-3-codex @ $BASE (create-only"
assert_eq "ensure: create-only did not switch" "enterprise-e2e/round-2-codex" "$(git -C "$ENS" branch --show-current)"
git -C "$ENS" rev-parse --verify enterprise-e2e/round-3-codex >/dev/null
tl_pass "ensure: create-only branch exists"
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-3-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE" "SB_E2E_TEST_APP_BRANCH_CREATE_ONLY=1"
assert_contains "ensure: create-only with existing branch" "$TL_OUT" "already exists or baseline missing"
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-4-codex" "SB_E2E_TEST_APP_BASELINE_SHA=0000000" "SB_E2E_TEST_APP_BRANCH_CREATE_ONLY=1"
assert_contains "ensure: create-only with missing baseline" "$TL_OUT" "already exists or baseline missing"
assert_eq "ensure: nothing created without a baseline" "" "$(git -C "$ENS" branch --list enterprise-e2e/round-4-codex)"
git -C "$ENS" checkout -q -- seed.txt
# Clean + existing branch: plain checkout.
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-3-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE"
assert_eq "ensure: checks out the existing branch" "enterprise-e2e/round-3-codex" "$(git -C "$ENS" branch --show-current)"
# Clean + missing branch + missing baseline.
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-5-codex" "SB_E2E_TEST_APP_BASELINE_SHA=0000000"
assert_eq "ensure: missing baseline fails" 1 "$TL_STATUS"
assert_contains "ensure: missing baseline message" "$TL_ERR" "baseline SHA 0000000 not found in test app"
# Clean + missing branch + valid baseline, from a non-main branch (no 'leaving main' line).
ensure "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-6-codex" "SB_E2E_TEST_APP_BASELINE_SHA=$BASE"
assert_not_contains "ensure: no 'leaving main' when not on main" "$TL_OUT" "leaving main"
assert_eq "ensure: created from baseline" "enterprise-e2e/round-6-codex" "$(git -C "$ENS" branch --show-current)"
# Default fixture dir argument.
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-6-codex" "SB_TEST_ENTERPRISE_APP_ROOT=$ENS"); call enterprise_e2e_ensure_test_app_branch
assert_contains "ensure: fixture dir defaults from the harness" "$TL_OUT" "OK on enterprise-e2e/round-6-codex"

tl_results

#!/usr/bin/env bash
# Behaviour tests for the fixture-branch and product-work gates in
# scripts/enterprise-e2e/lib/core.sh, run against temp git repos.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
CLEAN=(-u SB_TEST_ENTERPRISE_APP_ROOT -u SB_TEST_ENTERPRISE_APP_FIXTURE_BRANCH -u SB_E2E_TEST_APP_BRANCH
  -u SB_E2E_FIXTURE_BRANCH_PIN -u SB_E2E_FIXTURE_BRANCH_LOCK -u SB_E2E_TEST_APP_EXCLUDE_ANCESTOR
  -u SB_E2E_PRODUCT_WORK_GATE -u SB_E2E_PRODUCT_WORK_CUMULATIVE -u SB_E2E_OUTCOME_ONLY_ROWS
  -u SB_E2E_TEST_APP_BASELINE_SHA -u SB_E2E_ROW3_PRODUCT_ANCHOR_SHA -u SB_E2E_ROW6_FROZEN_COMMIT
  -u SB_E2E_LIVE_RUNTIME)
CFG="$TL_TMP/hosts.json"
echo '{"hosts": {"codex": {"fixture_branch": "enterprise-e2e/cfg-branch"}}}' >"$CFG"
CALL_ENV=("E2E_X=1")
call() {
  e2e_call "$CORE" "${CLEAN[@]}" "SILVER_BULLET_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=${HOSTS_CFG:-$CFG}" "${CALL_ENV[@]}" -- "$@"
}

# --- read_lines_to_array ----------------------------------------------------
e2e_script "source '$CORE'; enterprise_e2e_read_lines_to_array arr printf 'one\n\ntwo\nthree\n'; echo \"\${#arr[@]}:\${arr[0]}:\${arr[1]}:\${arr[2]}\"" "E2E_CALL=1"
assert_eq "read_lines_to_array skips blanks and fills the array" "3:one:two:three" "$TL_OUT"
e2e_script "source '$CORE'; arr=(stale); enterprise_e2e_read_lines_to_array arr true; echo \"\${#arr[@]}\"" "E2E_CALL=1"
assert_eq "read_lines_to_array resets the array" "0" "$TL_OUT"

# --- roots ------------------------------------------------------------------
call enterprise_e2e_sb_root
assert_eq "sb_root is the repo root" "$TL_REPO_ROOT" "$TL_OUT"
CALL_ENV=("SB_TEST_ENTERPRISE_APP_ROOT=/explicit/app"); call enterprise_e2e_fixture_dir
assert_eq "fixture dir honours SB_TEST_ENTERPRISE_APP_ROOT" "/explicit/app" "$TL_OUT"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_fixture_dir
assert_eq "fixture dir default is two levels above the repo" "$(cd "$TL_REPO_ROOT/../.." && pwd)/enterprise-grade-test-app" "$TL_OUT"

# --- fixture branch resolution ---------------------------------------------
CALL_ENV=("SB_TEST_ENTERPRISE_APP_FIXTURE_BRANCH=env/a" "SB_E2E_TEST_APP_BRANCH=env/b"); call enterprise_e2e_fixture_branch
assert_eq "fixture branch: dedicated env first" "env/a" "$TL_OUT"
CALL_ENV=("SB_E2E_TEST_APP_BRANCH=env/b"); call enterprise_e2e_fixture_branch
assert_eq "fixture branch: SB_E2E_TEST_APP_BRANCH second" "env/b" "$TL_OUT"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_fixture_branch
assert_eq "fixture branch: hosts.json last" "enterprise-e2e/cfg-branch" "$TL_OUT"
echo '{"hosts": {}}' >"$TL_TMP/none.json"
HOSTS_CFG="$TL_TMP/none.json" call enterprise_e2e_fixture_branch
assert_eq "fixture branch: nothing configured is empty and ok" "" "$TL_OUT"
assert_eq "fixture branch: nothing configured exits 0" 0 "$TL_STATUS"

# --- fixture repo -----------------------------------------------------------
APP="$TL_TMP/app"
e2e_git_app "$APP"
SEED_SHA="$(git -C "$APP" rev-parse HEAD)"
SEED_SHORT="$(git -C "$APP" rev-parse --short HEAD)"
mkdir -p "$TL_TMP/plain"
fx() { CALL_ENV=("SB_TEST_ENTERPRISE_APP_ROOT=$APP" "$@"); }

call enterprise_e2e_fixture_is_git_repo "$APP"
assert_eq "is_git_repo: yes" 0 "$TL_STATUS"
call enterprise_e2e_fixture_is_git_repo "$TL_TMP/plain"
assert_match "is_git_repo: no" '^128$' "$TL_STATUS"

# --- ensure_branch ----------------------------------------------------------
fx "SB_E2E_FIXTURE_BRANCH_PIN=0" "SB_E2E_TEST_APP_BRANCH=feat/x"; call enterprise_e2e_fixture_ensure_branch
assert_eq "ensure_branch: pin disabled is a no-op" "" "$TL_OUT"
fx "E2E_X=1"; HOSTS_CFG="$TL_TMP/none.json" call enterprise_e2e_fixture_ensure_branch
assert_eq "ensure_branch: no branch configured is a no-op" "" "$TL_OUT"
CALL_ENV=("SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/plain" "SB_E2E_TEST_APP_BRANCH=feat/x"); call enterprise_e2e_fixture_ensure_branch
assert_eq "ensure_branch: non-repo is tolerated" 0 "$TL_STATUS"
assert_contains "ensure_branch: non-repo warns" "$TL_ERR" "WARN: fixture branch pin skipped — not a git repo: $TL_TMP/plain"
fx "SB_E2E_TEST_APP_BRANCH=main"; call enterprise_e2e_fixture_ensure_branch
assert_match "ensure_branch: already on branch" "^Fixture branch: main @ $SEED_SHORT\$" "$TL_OUT"
fx "SB_E2E_TEST_APP_BRANCH=feat/missing"; call enterprise_e2e_fixture_ensure_branch
assert_eq "ensure_branch: missing branch fails" 1 "$TL_STATUS"
assert_contains "ensure_branch: missing branch message" "$TL_ERR" "ERROR: fixture branch feat/missing missing in $APP"
assert_contains "ensure_branch: announces the attempt" "$TL_OUT" "Fixture branch pin: checkout feat/missing (was: main)"
git -C "$APP" branch feat/present
fx "SB_E2E_TEST_APP_BRANCH=feat/present"; call enterprise_e2e_fixture_ensure_branch
assert_eq "ensure_branch: checks out an existing branch" "feat/present" "$(git -C "$APP" branch --show-current)"
assert_contains "ensure_branch: reports the new branch" "$TL_OUT" "Fixture branch: feat/present @ $SEED_SHORT"
git -C "$APP" checkout -q --detach
fx "SB_E2E_TEST_APP_BRANCH=main"; call enterprise_e2e_fixture_ensure_branch
assert_contains "ensure_branch: detached HEAD named as such" "$TL_OUT" "(was: detached)"
git -C "$APP" checkout -q main

# --- assert_branch_lock -----------------------------------------------------
fx "SB_E2E_FIXTURE_BRANCH_LOCK=0"; call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: disabled by LOCK=0" "" "$TL_OUT"
fx "SB_E2E_FIXTURE_BRANCH_PIN=0"; call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: disabled by PIN=0" "" "$TL_OUT"
fx "E2E_X=1"; HOSTS_CFG="$TL_TMP/none.json" call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: no expected branch is a no-op" 0 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BRANCH=main"; call enterprise_e2e_fixture_assert_branch_lock "$TL_TMP/plain" "custom label"
assert_eq "lock: non-repo fails" 1 "$TL_STATUS"
assert_contains "lock: non-repo message uses the label" "$TL_ERR" "FAIL: custom label — not a git repo: $TL_TMP/plain"
fx "SB_E2E_TEST_APP_BRANCH=other/branch"; call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: wrong branch fails" 1 "$TL_STATUS"
assert_match "lock: wrong branch message" 'fixture branch lock — expected branch other/branch, got main @ [0-9a-f]+' "$TL_ERR"
fx "SB_E2E_TEST_APP_BRANCH=main"; call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: right branch with default (absent) ancestor passes" 0 "$TL_STATUS"
assert_contains "lock: success message" "$TL_OUT" "fixture branch lock: main @ $SEED_SHORT"
e2e_commit "$APP" docs/a.md "second commit"
fx "SB_E2E_TEST_APP_BRANCH=main" "SB_E2E_TEST_APP_EXCLUDE_ANCESTOR=$SEED_SHORT"; call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: forbidden ancestor in history fails" 1 "$TL_STATUS"
assert_contains "lock: contamination message" "$TL_ERR" "HEAD includes forbidden ancestor $SEED_SHORT"
fx "SB_E2E_TEST_APP_BRANCH=main" "SB_E2E_TEST_APP_EXCLUDE_ANCESTOR="; call enterprise_e2e_fixture_assert_branch_lock "$APP"
assert_eq "lock: explicitly empty ancestor disables the check" 0 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BRANCH=main"; call enterprise_e2e_fixture_assert_branch_lock
assert_contains "lock: fixture defaults from the harness" "$TL_OUT" "fixture branch lock: main @"

# --- row classification -----------------------------------------------------
for r in 1 15 21 22; do
  call enterprise_e2e_row_requires_product_commit "$r"
  assert_eq "row $r needs no product commit" 1 "$TL_STATUS"
done
for r in 2 6 20; do
  call enterprise_e2e_row_requires_product_commit "$r"
  assert_eq "row $r needs a product commit" 0 "$TL_STATUS"
done
call enterprise_e2e_row_requires_product_commit
assert_eq "no row number defaults to needing a commit" 0 "$TL_STATUS"
for r in 6 11; do
  call enterprise_e2e_row_uses_matrix_baseline_rev_gate "$r"
  assert_eq "row $r uses the baseline rev gate" 0 "$TL_STATUS"
done
call enterprise_e2e_row_uses_matrix_baseline_rev_gate 3
assert_eq "row 3 does not use the baseline rev gate" 1 "$TL_STATUS"
call enterprise_e2e_row_uses_matrix_baseline_rev_gate
assert_eq "empty row does not use the baseline rev gate" 1 "$TL_STATUS"

# --- baseline counts / snapshots / modes -----------------------------------
fx "E2E_X=1"; call enterprise_e2e_fixture_baseline_rev_count
assert_eq "rev count without baseline prints 0" "0" "$TL_OUT"
assert_eq "rev count without baseline fails" 1 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHORT"; call enterprise_e2e_fixture_baseline_rev_count
assert_eq "rev count since baseline" "1" "$TL_OUT"
fx "SB_E2E_TEST_APP_BASELINE_SHA=deadbeef"; call enterprise_e2e_fixture_baseline_rev_count "$APP"
assert_eq "rev count with unknown baseline falls back to 0" "0" "$TL_OUT"
call enterprise_e2e_fixture_head_snapshot "$APP"
assert_eq "head snapshot is the full sha" "$(git -C "$APP" rev-parse HEAD)" "$TL_OUT"
call enterprise_e2e_fixture_head_snapshot "$TL_TMP/plain"
assert_eq "head snapshot of a non-repo is empty (and ok)" "" "$TL_OUT"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_row_outcome_only_rerun 6
assert_eq "outcome-only: unset list" 1 "$TL_STATUS"
CALL_ENV=("SB_E2E_OUTCOME_ONLY_ROWS=6 11"); call enterprise_e2e_row_outcome_only_rerun 11
assert_eq "outcome-only: listed row" 0 "$TL_STATUS"
call enterprise_e2e_row_outcome_only_rerun 1
assert_eq "outcome-only: row 1 is not a substring match of 11" 1 "$TL_STATUS"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_product_work_cumulative_mode
assert_eq "cumulative mode off by default" 1 "$TL_STATUS"
CALL_ENV=("SB_E2E_PRODUCT_WORK_CUMULATIVE=1"); call enterprise_e2e_product_work_cumulative_mode
assert_eq "cumulative mode on" 0 "$TL_STATUS"

# --- api/currency commit detection -----------------------------------------
e2e_commit "$APP" api/src/currency/convert.ts "currency conversion"          # touches api/src/currency
C_CUR="$(git -C "$APP" rev-parse HEAD)"
e2e_commit "$APP" api/lib/util.ts "tweak currency rounding"                  # api/ + message mentions currency
C_MSG="$(git -C "$APP" rev-parse HEAD)"
e2e_commit "$APP" api/lib/other.ts "refactor helpers"                        # api/ without a keyword
C_API="$(git -C "$APP" rev-parse HEAD)"
e2e_commit "$APP" web/page.tsx "ui polish"                                   # outside api/
C_WEB="$(git -C "$APP" rev-parse HEAD)"
fx "E2E_X=1"
call enterprise_e2e_commit_touches_api_currency "$APP" ""
assert_eq "touches: empty sha" 1 "$TL_STATUS"
call enterprise_e2e_commit_touches_api_currency "$APP" "$C_CUR"
assert_eq "touches: api/src/currency path" 0 "$TL_STATUS"
call enterprise_e2e_commit_touches_api_currency "$APP" "$C_MSG"
assert_eq "touches: api path plus currency in the subject" 0 "$TL_STATUS"
call enterprise_e2e_commit_touches_api_currency "$APP" "$C_API"
assert_eq "touches: api path without keyword" 1 "$TL_STATUS"
call enterprise_e2e_commit_touches_api_currency "$APP" "$C_WEB"
assert_eq "touches: non-api path" 1 "$TL_STATUS"
call enterprise_e2e_commit_touches_api_currency "" "$C_CUR"
assert_eq "touches: empty dir falls back to the harness fixture dir" 0 "$TL_STATUS"

call enterprise_e2e_row3_api_currency_commit_count "$APP" ""
assert_eq "row3 count: needs a from-sha" 1 "$TL_STATUS"
call enterprise_e2e_row3_api_currency_commit_count "$APP" "$SEED_SHA"
assert_eq "row3 count: two matching commits" "2" "$TL_OUT"
assert_eq "row3 count: success when > 0" 0 "$TL_STATUS"
call enterprise_e2e_row3_api_currency_commit_count "$APP" "$C_WEB"
assert_eq "row3 count: none after the last commit" "0" "$TL_OUT"
assert_eq "row3 count: failure when 0" 1 "$TL_STATUS"
call enterprise_e2e_row3_api_currency_commit_count "$APP" "$SEED_SHA" "$C_CUR"
assert_eq "row3 count honours an upper bound" "1" "$TL_OUT"

# assert_row3
call enterprise_e2e_assert_row3_api_currency_commit "$APP"
assert_eq "assert row3: no anchor fails" 1 "$TL_STATUS"
call enterprise_e2e_assert_row3_api_currency_commit "$APP" "$SEED_SHA"
assert_eq "assert row3: explicit anchor passes" 0 "$TL_STATUS"
assert_contains "assert row3: reports count" "$TL_OUT" "§5b row 3: 2 api/currency commit(s) after anchor ${SEED_SHA:0:12}"
fx "SB_E2E_ROW3_PRODUCT_ANCHOR_SHA=$SEED_SHA"; call enterprise_e2e_assert_row3_api_currency_commit "$APP"
assert_eq "assert row3: anchor env" 0 "$TL_STATUS"
fx "SB_E2E_ROW6_FROZEN_COMMIT=$SEED_SHA"; call enterprise_e2e_assert_row3_api_currency_commit "$APP"
assert_eq "assert row3: frozen-commit env" 0 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row3_api_currency_commit "$APP"
assert_eq "assert row3: baseline env" 0 "$TL_STATUS"
call enterprise_e2e_assert_row3_api_currency_commit "$APP" "$C_WEB"
assert_eq "assert row3: no commits after anchor fails" 1 "$TL_STATUS"
assert_contains "assert row3: failure message" "$TL_ERR" "no api/currency fixture commit after anchor ${C_WEB:0:12}"
call enterprise_e2e_assert_row3_api_currency_commit
assert_eq "assert row3: default fixture dir and baseline env" 0 "$TL_STATUS"

# --- rescore ----------------------------------------------------------------
fx "SB_E2E_PRODUCT_WORK_GATE=0"; call enterprise_e2e_assert_row_product_commit_rescore 6 "$APP"
assert_eq "rescore: gate disabled" 0 "$TL_STATUS"
fx "E2E_X=1"; call enterprise_e2e_assert_row_product_commit_rescore 1 "$APP"
assert_eq "rescore: row 1 needs no commit" 0 "$TL_STATUS"
call enterprise_e2e_assert_row_product_commit_rescore 6 "$APP"
assert_eq "rescore row 6 without baseline" 1 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_product_commit_rescore 6 "$APP"
assert_eq "rescore row 6 with commits since baseline" 0 "$TL_STATUS"
assert_contains "rescore row 6 message" "$TL_OUT" "§5b rescore row 6: 5 commit(s) since baseline"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$C_WEB"; call enterprise_e2e_assert_row_product_commit_rescore 6 "$APP"
assert_eq "rescore row 6 without new commits" 1 "$TL_STATUS"
assert_contains "rescore failure message" "$TL_ERR" "FAIL: §5b rescore — no product commit for row 6"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_product_commit_rescore 3 "$APP"
assert_eq "rescore row 3 delegates to the api/currency check" 0 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$C_WEB"; call enterprise_e2e_assert_row_product_commit_rescore 3 "$APP"
assert_eq "rescore row 3 propagates a failure" 1 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_product_commit_rescore 9 "$APP"
assert_contains "rescore other rows count commits since baseline" "$TL_OUT" "§5b rescore row 9: 5 commit(s) since baseline"
fx "E2E_X=1"; call enterprise_e2e_assert_row_product_commit_rescore 9 "$APP"
assert_eq "rescore other rows need a baseline" 1 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$C_WEB"; call enterprise_e2e_assert_row_product_commit_rescore 9 "$APP"
assert_eq "rescore other rows fail without new commits" 1 "$TL_STATUS"
call enterprise_e2e_assert_row_product_commit_rescore 9
assert_eq "rescore default fixture dir is the harness fixture (no new commits)" 1 "$TL_STATUS"

# --- product commit delta ---------------------------------------------------
HEAD_NOW="$(git -C "$APP" rev-parse HEAD)"
fx "SB_E2E_PRODUCT_WORK_GATE=0"; call enterprise_e2e_assert_row_product_commit_delta 6 "$SEED_SHA" "$APP"
assert_eq "delta: gate disabled" 0 "$TL_STATUS"
fx "E2E_X=1"; call enterprise_e2e_assert_row_product_commit_delta 1 "$SEED_SHA" "$APP"
assert_eq "delta: row 1 exempt" 0 "$TL_STATUS"
call enterprise_e2e_assert_row_product_commit_delta 6 "" "$APP"
assert_eq "delta: missing head-before fails" 1 "$TL_STATUS"
assert_contains "delta: missing head message" "$TL_ERR" "cannot read fixture HEAD (row 6)"
call enterprise_e2e_assert_row_product_commit_delta 6 "$HEAD_NOW" "$TL_TMP/plain"
assert_eq "delta: unreadable head-after fails" 1 "$TL_STATUS"
call enterprise_e2e_assert_row_product_commit_delta 6 "$HEAD_NOW" "$APP"
assert_eq "delta: unchanged HEAD fails" 1 "$TL_STATUS"
assert_contains "delta: unchanged message" "$TL_ERR" "no fixture commit after row 6 (HEAD still ${HEAD_NOW:0:12})"
fx "SB_E2E_OUTCOME_ONLY_ROWS=6" "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_product_commit_delta 6 "$HEAD_NOW" "$APP"
assert_eq "delta: outcome-only rerun with rescore passes" 0 "$TL_STATUS"
fx "SB_E2E_OUTCOME_ONLY_ROWS=6" "SB_E2E_TEST_APP_BASELINE_SHA=$C_WEB"; call enterprise_e2e_assert_row_product_commit_delta 6 "$HEAD_NOW" "$APP"
assert_eq "delta: outcome-only rerun without commits still fails" 1 "$TL_STATUS"
fx "SB_E2E_PRODUCT_WORK_CUMULATIVE=1" "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_product_commit_delta 6 "$HEAD_NOW" "$APP"
assert_eq "delta: cumulative mode with rescore passes" 0 "$TL_STATUS"
assert_contains "delta: cumulative message" "$TL_OUT" "(cumulative): HEAD ${HEAD_NOW:0:12} unchanged; rescore OK"
fx "E2E_X=1"; call enterprise_e2e_assert_row_product_commit_delta 3 "$SEED_SHA" "$APP"
assert_eq "delta: row 3 with api/currency commits" 0 "$TL_STATUS"
assert_contains "delta: row 3 message" "$TL_OUT" "§5b product delta row 3: 2 api/currency commit(s)"
call enterprise_e2e_assert_row_product_commit_delta 3 "$C_API" "$APP"
assert_eq "delta: row 3 without api/currency commits fails" 1 "$TL_STATUS"
assert_contains "delta: row 3 failure message" "$TL_ERR" "row 3 requires api/currency commit"
call enterprise_e2e_assert_row_product_commit_delta 8 "$SEED_SHA" "$APP"
assert_eq "delta: ordinary row with a new commit passes" 0 "$TL_STATUS"
assert_contains "delta: reports the subject" "$TL_OUT" "§5b product delta: ${SEED_SHA:0:12} → ${HEAD_NOW:0:12} (ui polish)"
call enterprise_e2e_assert_row_product_commit_delta 8 "$SEED_SHA"
assert_eq "delta: default fixture dir is the harness fixture" 0 "$TL_STATUS"

# --- matrix baseline rev increase -------------------------------------------
fx "SB_E2E_PRODUCT_WORK_GATE=0"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 0 "$APP"
assert_eq "rev increase: gate disabled" 0 "$TL_STATUS"
fx "E2E_X=1"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 3 0 "$APP"
assert_eq "rev increase: row not under the gate" 0 "$TL_STATUS"
call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 0 "$APP"
assert_eq "rev increase: baseline unset fails" 1 "$TL_STATUS"
assert_contains "rev increase: unset message" "$TL_ERR" "SB_E2E_TEST_APP_BASELINE_SHA unset (row 6)"
fx "SB_E2E_OUTCOME_ONLY_ROWS=6"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 0 "$APP"
assert_eq "rev increase: outcome-only rerun passes" 0 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 2 "$APP"
assert_eq "rev increase: count grew" 0 "$TL_STATUS"
assert_contains "rev increase: growth message" "$TL_OUT" "§5b matrix baseline gate row 6: ${SEED_SHA:0:12}..HEAD count 2 → 5"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 11 5 "$APP"
assert_eq "rev increase: unchanged count fails" 1 "$TL_STATUS"
assert_contains "rev increase: failure message" "$TL_ERR" "did not increase (5 → 5;"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA" "SB_E2E_PRODUCT_WORK_CUMULATIVE=1"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 5 "$APP"
assert_eq "rev increase: cumulative mode rescues an unchanged count" 0 "$TL_STATUS"
assert_contains "rev increase: cumulative message" "$TL_OUT" "(cumulative): ${SEED_SHA:0:12}..HEAD count 5 (no per-row Δ; rescore OK)"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$C_WEB" "SB_E2E_PRODUCT_WORK_CUMULATIVE=1"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 0 "$APP"
assert_eq "rev increase: cumulative but nothing since baseline fails" 1 "$TL_STATUS"
fx "SB_E2E_TEST_APP_BASELINE_SHA=$SEED_SHA"; call enterprise_e2e_assert_row_matrix_baseline_rev_increase 6 1
assert_contains "rev increase: default fixture dir is the harness fixture" "$TL_OUT" "count 1 → 5"

tl_results

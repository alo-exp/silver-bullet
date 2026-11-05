#!/usr/bin/env bash
# Fault-injection tests for the harness libraries: git, tr, sed, awk, tail, readlink and mkdir
# are wrapped so a chosen invocation fails (FAIL_<TOOL>=<regex over the arguments>), proving the
# fallbacks around them (`|| true`, `|| echo unknown`, `|| echo 0`) keep the harness going.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
HOST_LIB="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/host.sh"
CFG="$TL_TMP/hosts.json"
echo '{"default_host": "claude", "hosts": {"codex": {"git_branch": "track-codex"}}}' >"$CFG"

mk_passthru() {
  local name="$1" real upper
  real="$(command -v "$name")"
  upper="$(tr '[:lower:]' '[:upper:]' <<<"$name")"
  tl_stub "$name" "if [[ -n \"\${FAIL_${upper}:-}\" && \"\$*\" =~ \${FAIL_${upper}} ]]; then exit 1; fi; exec $real \"\$@\""
}
for t in git tr sed awk tail readlink mkdir; do mk_passthru "$t"; done

BASE_ENV=("SILVER_BULLET_RUNTIME=codex" "SB_E2E_HOSTS_CONFIG=$CFG" -u SB_E2E_LIVE_RUNTIME -u SB_E2E_TEST_APP_BRANCH -u SB_E2E_TEST_APP_ROUND
  -u SB_E2E_LEDGER_FILE -u SB_E2E_TEST_APP_BASELINE_SHA -u SB_E2E_FIXTURE_BRANCH_LOCK -u SB_E2E_FIXTURE_BRANCH_PIN -u SB_E2E_MATRIX_LOG
  -u SB_E2E_MATRIX_BATCH_PID_FILE -u SB_E2E_MATRIX_LOG_FALLBACK -u SB_E2E_MATRIX_DRIVER_LOG -u SB_E2E_LIVE_TEST_LOCK_FILE
  -u SB_E2E_INSTALL_VERSION_KEY -u SB_TEST_ENTERPRISE_APP_FIXTURE_BRANCH -u SB_E2E_ROW_PASS_REGISTRY)
# run_core BODY ENV...: source core.sh and run BODY.
run_core() {
  local body="$1"
  shift
  e2e_script "source '$CORE'; $body" "${BASE_ENV[@]}" "$@"
}

APP="$TL_TMP/app"
e2e_git_app "$APP"
git -C "$APP" branch feat/present
APP_ENV=("SB_TEST_ENTERPRISE_APP_ROOT=$APP")

# --- fixture branch pin ------------------------------------------------------
run_core "enterprise_e2e_fixture_ensure_branch" "${APP_ENV[@]}" "SB_E2E_TEST_APP_BRANCH=feat/present" "FAIL_GIT=branch --show-current"
assert_eq "pin: unreadable current branch is reported as detached" 0 "$TL_STATUS"
assert_contains "pin: detached wording" "$TL_OUT" "checkout feat/present (was: detached)"
git -C "$APP" checkout -q main
run_core "enterprise_e2e_fixture_ensure_branch" "${APP_ENV[@]}" "SB_E2E_TEST_APP_BRANCH=main" "FAIL_GIT=rev-parse --short"
assert_contains "pin: unreadable sha is reported as unknown" "$TL_OUT" "Fixture branch: main @ unknown"

# --- branch lock ----------------------------------------------------------------
run_core "enterprise_e2e_fixture_assert_branch_lock '$APP'" "SB_E2E_TEST_APP_BRANCH=main" "FAIL_GIT=branch --show-current"
assert_eq "lock: unreadable branch fails" 1 "$TL_STATUS"
assert_contains "lock: reported as detached" "$TL_ERR" "got detached"
run_core "enterprise_e2e_fixture_assert_branch_lock '$APP'" "SB_E2E_TEST_APP_BRANCH=main" "FAIL_GIT=rev-parse --short"
assert_eq "lock: unreadable sha is tolerated" 0 "$TL_STATUS"
assert_contains "lock: blank sha in the report" "$TL_OUT" "fixture branch lock: main @ "

# --- product work helpers ------------------------------------------------------------
e2e_commit "$APP" api/src/currency/x.ts "currency work"
SEED="$(git -C "$APP" rev-list --max-parents=0 HEAD)"
HEAD_SHA="$(git -C "$APP" rev-parse HEAD)"
run_core "enterprise_e2e_commit_touches_api_currency '$APP' '$HEAD_SHA'" "FAIL_GIT=diff-tree"
assert_eq "touches: unreadable diff-tree means no match" 1 "$TL_STATUS"
run_core "enterprise_e2e_assert_row_product_commit_rescore 6" "${APP_ENV[@]}" "SB_E2E_TEST_APP_BASELINE_SHA=$SEED" "FAIL_GIT=rev-list --count"
assert_eq "rescore row 6: failing rev-list counts as no commits" 1 "$TL_STATUS"
run_core "enterprise_e2e_assert_row_product_commit_rescore 9" "${APP_ENV[@]}" "SB_E2E_TEST_APP_BASELINE_SHA=$SEED" "FAIL_GIT=rev-list --count"
assert_eq "rescore other row: failing rev-list counts as no commits" 1 "$TL_STATUS"
run_core "enterprise_e2e_assert_row_product_commit_delta 8 '$SEED' '$APP'" "FAIL_GIT=log -1"
assert_eq "delta: a failing git log still passes" 0 "$TL_STATUS"
assert_contains "delta: subject falls back to 'commit'" "$TL_OUT" "($(printf 'commit'))"
run_core "enterprise_e2e_fixture_head_snapshot" "${APP_ENV[@]}"
assert_eq "head snapshot defaults to the harness fixture" "$HEAD_SHA" "$TL_OUT"
run_core "enterprise_e2e_row3_api_currency_commit_count '' '$SEED'" "${APP_ENV[@]}"
assert_eq "row 3 count: empty dir falls back to the harness fixture" "1" "$TL_OUT"
run_core "enterprise_e2e_row3_api_currency_commit_count '$APP' ''" "${APP_ENV[@]}"
assert_eq "row 3 count: still needs a from-sha" 1 "$TL_STATUS"

# --- host.sh git probes --------------------------------------------------------------------
HARNESS="$TL_TMP/harness"
tl_git_repo "$HARNESS"
git -C "$HARNESS" checkout -q -b track-codex
hb() { e2e_script "source '$HOST_LIB'; enterprise_e2e_preflight_fail() { echo \"PF: \$*\" >&2; return 1; }; enterprise_e2e_assert_host_git_branch" "${BASE_ENV[@]}" "SB_ROOT=$HARNESS" "$@"; }
hb "FAIL_GIT=branch --show-current"
assert_eq "host branch: unreadable branch fails the gate" 1 "$TL_STATUS"
assert_contains "host branch: reported as detached" "$TL_OUT" "have=detached"
hb "FAIL_GIT=rev-parse --short"
assert_eq "host branch: unreadable sha still passes" 0 "$TL_STATUS"
assert_contains "host branch: sha shown as unknown" "$TL_OUT" "OK on track-codex @ unknown"

# --- test-app branch probes -----------------------------------------------------------------------
TA="$TL_TMP/ta"
e2e_git_app "$TA"
git -C "$TA" checkout -q -b enterprise-e2e/round-3-codex
ta_assert() { run_core "enterprise_e2e_assert_test_app_branch '$TA'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-3-codex" "$@"; }
ta_ensure() { run_core "enterprise_e2e_ensure_test_app_branch '$TA'" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-3-codex" "$@"; }
ta_assert "FAIL_GIT=branch --show-current"
assert_eq "assert: unreadable branch fails" 1 "$TL_STATUS"
assert_contains "assert: reports detached" "$TL_OUT" "have=detached"
ta_assert "FAIL_GIT=rev-parse --short"
assert_eq "assert: unreadable sha passes" 0 "$TL_STATUS"
assert_contains "assert: sha unknown" "$TL_OUT" "OK on enterprise-e2e/round-3-codex @ unknown"
ta_ensure "FAIL_GIT=rev-parse --short"
assert_contains "ensure: matching branch with unreadable sha" "$TL_OUT" "OK on enterprise-e2e/round-3-codex @ unknown"
ta_ensure "FAIL_GIT=branch --show-current"
assert_eq "ensure: unreadable branch falls through to a checkout" 0 "$TL_STATUS"
assert_contains "ensure: reports detached" "$TL_OUT" "have=detached"
assert_contains "ensure: checks the branch out" "$TL_OUT" "checked out enterprise-e2e/round-3-codex"

# matrix_host failures fall back to claude in the branch naming helpers
fh() { run_core "enterprise_e2e_matrix_host() { return 1; }; $1" "${@:2}"; }
fh "enterprise_e2e_apply_test_app_branch_defaults; echo \"B=\$SB_E2E_TEST_APP_BRANCH\"" "SB_E2E_TEST_APP_ROUND=5"
assert_eq "defaults: failing host lookup names the claude branch" "B=enterprise-e2e/round-5-claude" "$TL_OUT"
fh "enterprise_e2e_test_app_expected_branch" "SB_E2E_TEST_APP_ROUND=6"
assert_eq "expected branch from round: failing host lookup means claude" "enterprise-e2e/round-6-claude" "$TL_OUT"
fh "enterprise_e2e_test_app_expected_branch" "SB_E2E_LEDGER_FILE=/x/ROUND-7-LEDGER.md"
assert_eq "expected branch from ledger: failing host lookup means claude" "enterprise-e2e/round-7-claude" "$TL_OUT"
fh "enterprise_e2e_live_test_lock_file" "SB_ROOT=/sb"
assert_eq "lock file: failing host lookup means claude" "/sb/.e2e-live-test.lock" "$TL_OUT"
mkdir -p "$TL_TMP/tui"
fh "enterprise_e2e_reset_tui_monitor_offsets '$TL_TMP/tui'" "SB_ROOT="
assert_contains "tui offsets: failing host lookup means claude" "$TL_OUT" "-> $TL_TMP/tui/.e2e-tui-watch-offsets.json"
printf 'tiny\n' >"$TL_TMP/fin.log"
fh "enterprise_e2e_matrix_finalize_attempt_log '$TL_TMP/fin.log' 1 '$TL_TMP'; cat '$TL_TMP/fin.log'" "SB_ROOT=$TL_TMP"
assert_eq "finalize: failing host lookup is not cursor, log untouched" "tiny" "$TL_OUT"

# --- pid files / locks / byte counts with a failing tr ---------------------------------------------
PIDF="$TL_TMP/b.pid"
echo 4242 >"$PIDF"
run_core "enterprise_e2e_matrix_batch_pid" "SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "FAIL_TR=."
assert_eq "batch pid: unreadable pid file means no pid" 1 "$TL_STATUS"

BYT="$TL_TMP/bytes"
mkdir -p "$BYT"
printf 'abcde' >"$BYT/real.log"
printf 'driverbytes' >"$BYT/driver.log"
printf 'rowlog' >"$BYT/.e2e-row3-attempt.log"
ln -sf driver.log "$BYT/link.log"
BY_ENV=("SB_ROOT=$BYT" "SB_E2E_MATRIX_BATCH_PID_FILE=$TL_TMP/none.pid")
run_core "enterprise_e2e_matrix_log_bytes '$BYT/real.log'" "${BY_ENV[@]}" "FAIL_TR=."
assert_eq "bytes: failing tr counts zero everywhere" "0" "$TL_OUT"
run_core "enterprise_e2e_matrix_log_bytes '$BYT/link.log'" "${BY_ENV[@]}" "FAIL_TR=."
assert_eq "bytes: symlinked log with failing tr counts zero" "0" "$TL_OUT"
run_core "enterprise_e2e_matrix_log_bytes '$BYT/link.log'" "${BY_ENV[@]}" "FAIL_READLINK=."
assert_eq "bytes: unreadable symlink target means no bytes" "0" "$TL_OUT"
: >"$BYT/empty.log"
run_core "enterprise_e2e_matrix_log_bytes '$BYT/empty.log'" "${BY_ENV[@]}" "SB_E2E_MATRIX_LOG_FALLBACK=$BYT/driver.log" "FAIL_TR=."
assert_eq "bytes: failing tr on the fallback log counts zero" "0" "$TL_OUT"
run_core "enterprise_e2e_row_attempt_log() { return 1; }; enterprise_e2e_matrix_log_bytes '$BYT/empty.log'" "${BY_ENV[@]}"
assert_eq "bytes: failing row-log lookup uses the default claude name" "6" "$TL_OUT"
run_core "enterprise_e2e_row_attempt_log() { return 1; }; enterprise_e2e_matrix_log_bytes '$BYT/empty.log'" "${BY_ENV[@]}" "FAIL_TR=."
assert_eq "bytes: failing tr on a row log counts zero" "0" "$TL_OUT"
# default log path arguments
run_core "enterprise_e2e_ensure_matrix_log; echo \"ensured:\$SB_E2E_MATRIX_LOG\"" "SB_E2E_MATRIX_LOG=$BYT/default-ensure.log" "SB_E2E_MATRIX_BATCH_PID_FILE=$TL_TMP/none.pid"
assert_eq "ensure log: default path" "ensured:$BYT/default-ensure.log" "$TL_OUT"
assert_file_exists "ensure log: default path created" "$BYT/default-ensure.log"
run_core "enterprise_e2e_assert_matrix_log_mutable" "SB_E2E_MATRIX_LOG=$BYT/default-ensure.log" "SB_E2E_MATRIX_BATCH_PID_FILE=$TL_TMP/none.pid"
assert_eq "mutable: default path" 0 "$TL_STATUS"

# finalize: failing tr while waiting / after waiting
printf 'tiny\n' >"$TL_TMP/fin2.log"
tl_stub sleep 'exit 0'
run_core "enterprise_e2e_matrix_finalize_attempt_log '$TL_TMP/fin2.log' 1 '$TL_TMP'; echo \"size=\$(wc -c <'$TL_TMP/fin2.log' | awk '{print \$1}')\"" "SB_ROOT=$TL_TMP" "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_CURSOR_LOG_GROWTH_WAIT=2" "FAIL_TR=."
assert_contains "finalize: failing tr while waiting reads as an empty log" "$TL_OUT" "size="
printf 'tiny\n' >"$TL_TMP/fin3.log"
run_core "enterprise_e2e_matrix_finalize_attempt_log '$TL_TMP/fin3.log' 1 '$TL_TMP'" "SB_ROOT=$TL_TMP" "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_CURSOR_LOG_GROWTH_WAIT=0" "FAIL_TR=."
assert_eq "finalize: failing tr after the wait still finishes" 0 "$TL_STATUS"
# composite sections when sed/git are unhappy
mkdir -p "$TL_TMP/work/.planning"
e2e_git_app "$TL_TMP/work"
echo dirty >>"$TL_TMP/work/seed.txt"
rmdir "$TL_TMP/work/.planning"
printf 'tiny\n' >"$TL_TMP/fin4.log"
run_core "enterprise_e2e_matrix_finalize_attempt_log '$TL_TMP/fin4.log' 1 '$TL_TMP/work'" "SB_ROOT=$TL_TMP" "SB_E2E_LIVE_RUNTIME=cursor" "SB_E2E_CURSOR_LOG_GROWTH_WAIT=0" "FAIL_SED=s/\\^/  /"
assert_eq "finalize: failing sed on the git sections is tolerated" 0 "$TL_STATUS"
assert_contains "finalize: footer still written" "$(cat "$TL_TMP/fin4.log")" "--- end composite transcript ---"

# --- install-version file ------------------------------------------------------------------------------
IV="$TL_TMP/iv"
mkdir -p "$IV"
run_core "enterprise_e2e_write_sb_install_version '$IV'" "SB_ROOT=$IV"
assert_eq "install version: no package.json and no git" "0.0.0@unknown" "$TL_OUT"
rm -f "$IV/.e2e-cursor-install-version.txt"
run_core "enterprise_e2e_write_sb_install_version '$IV' 1.0.0 abc1234" "SB_ROOT=$IV" "FAIL_MKDIR=."
assert_eq "install version: a failing mkdir does not stop the write" "1.0.0@abc1234" "$TL_OUT"
printf 'SB_CURSOR_PLUGIN_VERSION=2.0.0\nfalse\n' >"$IV/.e2e-cursor-install-version.txt"
run_core "enterprise_e2e_sb_install_version_key" "SB_ROOT=$IV"
assert_eq "install version: a version file that exits non-zero is tolerated" "0.0.0@unknown" "$TL_OUT"
rm -f "$IV/.e2e-cursor-install-version.txt"
run_core "enterprise_e2e_record_row_pass_at_install_version 3 /l.md" "SB_ROOT=$IV" "SB_E2E_INSTALL_VERSION_KEY=1.0.0@a" "FAIL_MKDIR=."
assert_eq "record: a failing mkdir is tolerated" 0 "$TL_STATUS"
assert_eq "record: the row is still appended" "1" "$(wc -l <"$IV/.e2e-matrix-pass-at-version.tsv" | tr -d ' ')"
echo 'not json' >"$TL_TMP/bad-registry.json"
run_core "enterprise_e2e_record_row_pass_at_install_version 4 /l.md" "SB_ROOT=$IV" "SB_E2E_INSTALL_VERSION_KEY=1.0.0@a" "SB_E2E_ROW_PASS_REGISTRY=$TL_TMP/bad-registry.json"
assert_eq "record: a corrupt pass registry does not fail the caller" 0 "$TL_STATUS"
# ledger SB sha with a failing awk
e2e_mk_ledger "$TL_TMP/sha-ledger.md" 1:Pass
run_core "enterprise_e2e_ledger_sb_sha '$TL_TMP/sha-ledger.md'" "FAIL_AWK=."
assert_eq "ledger sha: failing awk means no sha" 1 "$TL_STATUS"
# registry lib: a recorded row passes the version check immediately
run_core "enterprise_e2e_record_row_pass_at_install_version 6 /l.md '$TL_TMP/m.log'; enterprise_e2e_row_passed_at_install_version 6" "SB_ROOT=$IV" "SB_E2E_INSTALL_VERSION_KEY=1.0.0@a" "SB_E2E_ROW_PASS_REGISTRY=$TL_TMP/reg/r.json"
assert_eq "passed-at: answered by the registry library" 0 "$TL_STATUS"

# --- live lock with a failing tr -----------------------------------------------------------------------------
LOCK="$TL_TMP/l.lock"
echo "$$" >"$LOCK"
run_core "enterprise_e2e_acquire_live_test_lock; cat '$LOCK'" "SB_E2E_LIVE_TEST_LOCK_FILE=$LOCK" "FAIL_TR=."
assert_contains "acquire: unreadable lock counts as stale" "$TL_OUT" "removing stale live-test lock (pid unknown not running)"
echo "$$" >"$LOCK"
run_core "enterprise_e2e_release_live_test_lock" "SB_E2E_LIVE_TEST_LOCK_FILE=$LOCK" "FAIL_TR=."
assert_eq "release: unreadable lock is left alone" "$$" "$(cat "$LOCK")"

# --- install-claude tail failures ---------------------------------------------------------------------------------
SB="$TL_TMP/sb"
mkdir -p "$SB/scripts" "$SB/tests/live/lib"
echo 'sb_prepend_harness_path() { :; }' >"$SB/tests/live/lib/detach-background.sh"
LOGF="$TL_TMP/install.log"
inst() {  # inst STUB-BODY LOG-CONTENT ENV...
  local stub="$1" content="$2"
  shift 2
  printf '%s' "$content" >"$LOGF"
  run_core "sb_run_detached_pty() { $stub; }; enterprise_e2e_run_install_claude '$SB'" "SB_ROOT=$SB" "SB_E2E_INSTALL_CLAUDE_LOG=$LOGF" "$@"
}
inst ':' $'Claude marketplaces registered\n' "FAIL_TAIL=."
assert_eq "install: cached log with a failing tail still succeeds" 0 "$TL_STATUS"
inst 'echo "Claude marketplace refreshed" >>"$2"; echo $$' "" "FAIL_TAIL=."
assert_eq "install: a failing tail after completion is tolerated" 0 "$TL_STATUS"
DEAD_PID="$(bash -c 'echo $$')"
inst "echo partial >>\"\$2\"; echo $DEAD_PID" "" "FAIL_TAIL=."
assert_eq "install: early exit with a failing tail still reports the failure" 1 "$TL_STATUS"
assert_contains "install: early-exit message" "$TL_ERR" "install-claude exited before completion"
tl_stub grep 'if [[ "$*" == *"Claude marketplaces registered"* ]]; then n=0; [ -f "$GREP_COUNT" ] && n=$(cat "$GREP_COUNT"); n=$((n+1)); echo $n >"$GREP_COUNT"; [ "$n" -le 2 ] && exit 1; fi; exec '"$(command -v grep)"' "$@"'
rm -f "$TL_TMP/grep.count"
inst "echo 'Claude marketplaces registered' >>\"\$2\"; echo $DEAD_PID" "" "FAIL_TAIL=." "GREP_COUNT=$TL_TMP/grep.count"
assert_eq "install: marker appearing after the child exited, failing tail tolerated" 0 "$TL_STATUS"
rm -f "$TL_BIN/grep"
REAL_SLEEP="$(PATH=/usr/bin:/bin command -v sleep)"
: >"$LOGF"
# Timeout: override sleep with a function that advances SECONDS (a real sleep would take 300s).
run_core "sleep() { SECONDS=\$((SECONDS + 200)); }; sb_run_detached_pty() { echo x >>\"\$2\"; '$REAL_SLEEP' 30 >/dev/null 2>&1 & echo \$!; }; enterprise_e2e_run_install_claude '$SB'; rc=\$?; kill %1 2>/dev/null; exit \$rc" "SB_ROOT=$SB" "SB_E2E_INSTALL_CLAUDE_LOG=$LOGF" "FAIL_TAIL=."
assert_eq "install: timeout with a failing tail still fails" 1 "$TL_STATUS"
assert_contains "install: timeout message" "$TL_ERR" "install-claude timed out after 300s"

# --- rtk binary lookup failing --------------------------------------------------------------------------------
run_core "sb_recommended_tool_enforced() { return 0; }; sb_rtk_cli_path() { return 1; }; enterprise_e2e_preflight_rtk '$CFG' h 0" 
assert_eq "rtk: a failing binary lookup is a failed preflight" 1 "$TL_STATUS"
assert_contains "rtk: missing binary message" "$TL_ERR" "rtk CLI missing or wrong binary"

tl_results

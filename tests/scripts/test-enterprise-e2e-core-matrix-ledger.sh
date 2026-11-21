#!/usr/bin/env bash
# Behaviour tests for the matrix-log, ledger, install-version and live-lock helpers in
# scripts/enterprise-e2e/lib/core.sh. Temp dirs only; `sleep` is stubbed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
CLEAN=(-u SB_E2E_MATRIX_LOG -u SB_E2E_MATRIX_BATCH_PID_FILE -u SB_E2E_LIVE_RUNTIME -u SB_E2E_MATRIX_DRIVER_LOG
  -u SB_E2E_MATRIX_LOG_FALLBACK -u SB_E2E_LEDGER_FILE -u SB_E2E_INSTALL_VERSION_KEY -u SB_E2E_MATRIX_FORCE
  -u SB_E2E_FORCE_ROW -u SB_E2E_MATRIX_FORCE_ALL -u SB_E2E_LIVE_TEST_LOCK_FILE -u SB_E2E_ROW_PASS_REGISTRY)
CFG="$TL_TMP/hosts.json"
echo '{"default_host": "claude", "hosts": {}}' >"$CFG"
CALL_ENV=("E2E_X=1")
call() {
  e2e_call "${LIB:-$CORE}" "${CLEAN[@]}" "SILVER_BULLET_RUNTIME=${RT:-claude}" "SB_E2E_HOSTS_CONFIG=$CFG" "${CALL_ENV[@]}" -- "$@"
}
SBR="$TL_TMP/sbr"
mkdir -p "$SBR"

# --- log / pid-file naming --------------------------------------------------
CALL_ENV=("SB_ROOT=$SBR"); RT=claude call enterprise_e2e_matrix_log
assert_eq "claude matrix log" "$SBR/.e2e-matrix-live.log" "$TL_OUT"
RT=codex call enterprise_e2e_matrix_log
assert_eq "codex matrix log is host-named" "$SBR/.e2e-matrix-codex-live.log" "$TL_OUT"
CALL_ENV=("SB_ROOT=$SBR" "SB_E2E_MATRIX_LOG=/explicit.log"); RT=codex call enterprise_e2e_matrix_log
assert_eq "explicit matrix log wins" "/explicit.log" "$TL_OUT"
CALL_ENV=("SB_ROOT=$SBR"); RT=claude call enterprise_e2e_matrix_batch_pid_file
assert_eq "claude batch pid file" "$SBR/.e2e-matrix-batch.pid" "$TL_OUT"
RT=codex call enterprise_e2e_matrix_batch_pid_file
assert_eq "codex batch pid file is host-named" "$SBR/.e2e-matrix-codex-batch.pid" "$TL_OUT"
CALL_ENV=("SB_ROOT=$SBR" "SB_E2E_MATRIX_BATCH_PID_FILE=/p.pid"); RT=codex call enterprise_e2e_matrix_batch_pid_file
assert_eq "explicit batch pid file wins" "/p.pid" "$TL_OUT"

# --- batch pid / running ----------------------------------------------------
PIDF="$TL_TMP/batch.pid"
DEAD_PID="$(bash -c 'echo $$')"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF")
rm -f "$PIDF"
call enterprise_e2e_matrix_batch_pid
assert_eq "batch pid: no file" 1 "$TL_STATUS"
: >"$PIDF"
call enterprise_e2e_matrix_batch_pid
assert_eq "batch pid: empty file" 1 "$TL_STATUS"
printf ' 4242 \n' >"$PIDF"
call enterprise_e2e_matrix_batch_pid
assert_eq "batch pid: whitespace stripped" "4242" "$TL_OUT"
echo "$DEAD_PID" >"$PIDF"
call enterprise_e2e_matrix_batch_running
assert_eq "batch running: dead pid" 1 "$TL_STATUS"
echo "$$" >"$PIDF"
call enterprise_e2e_matrix_batch_running
assert_eq "batch running: live pid" 0 "$TL_STATUS"
rm -f "$PIDF"
call enterprise_e2e_matrix_batch_running
assert_eq "batch running: no pid file" 1 "$TL_STATUS"

# --- ensure_matrix_log ------------------------------------------------------
LOGD="$TL_TMP/logs"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF")
call enterprise_e2e_ensure_matrix_log "$LOGD/sub/m.log"
assert_eq "ensure log: creates dir and file when idle" 0 "$TL_STATUS"
assert_file_exists "ensure log: file created" "$LOGD/sub/m.log"
echo keep >"$LOGD/sub/m.log"
call enterprise_e2e_ensure_matrix_log "$LOGD/sub/m.log"
assert_eq "ensure log: existing file untouched" "keep" "$(cat "$LOGD/sub/m.log")"
echo "$$" >"$PIDF"
rm -f "$LOGD/sub/m.log"
call enterprise_e2e_ensure_matrix_log "$LOGD/sub/m.log"
assert_contains "ensure log: running batch without driver log recreates" "$TL_ERR" "matrix log missing during active batch — recreating"
assert_file_exists "ensure log: recreated" "$LOGD/sub/m.log"
rm -f "$LOGD/sub/m.log"
echo driver >"$LOGD/sub/driver.log"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_E2E_MATRIX_DRIVER_LOG=$LOGD/sub/driver.log")
call enterprise_e2e_ensure_matrix_log "$LOGD/sub/m.log"
assert_contains "ensure log: running batch with driver log symlinks" "$TL_ERR" "matrix log unlinked during active batch — symlink"
assert_eq "ensure log: symlink target" "driver.log" "$(readlink "$LOGD/sub/m.log")"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$SBR"); RT=codex
echo "$$" >"$PIDF"
call enterprise_e2e_assert_matrix_log_mutable "$LOGD/sub/m.log"
assert_eq "mutable: refused while a batch runs" 1 "$TL_STATUS"
assert_contains "mutable: refusal text" "$TL_ERR" "refusing to truncate/delete matrix log $LOGD/sub/m.log while batch is running"
rm -f "$PIDF"
call enterprise_e2e_assert_matrix_log_mutable "$LOGD/sub/m.log"
assert_eq "mutable: allowed when idle" 0 "$TL_STATUS"
RT=claude

# --- matrix_log_bytes -------------------------------------------------------
BYT="$TL_TMP/bytes"
mkdir -p "$BYT"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$BYT")
printf 'abcde' >"$BYT/real.log"
call enterprise_e2e_matrix_log_bytes "$BYT/real.log"
assert_eq "bytes: regular file" "5" "$TL_OUT"
printf 'abcdefgh' >"$BYT/driver.log"
ln -sf driver.log "$BYT/link.log"
call enterprise_e2e_matrix_log_bytes "$BYT/link.log"
assert_eq "bytes: relative symlink resolves to the driver log" "8" "$TL_OUT"
ln -sf "$BYT/driver.log" "$BYT/abs-link.log"
: >"$BYT/fb.log"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$BYT" "SB_E2E_MATRIX_LOG_FALLBACK=$BYT/driver.log")
call enterprise_e2e_matrix_log_bytes "$BYT/abs-link.log"
assert_eq "bytes: absolute symlink skipped, fallback log used" "8" "$TL_OUT"
call enterprise_e2e_matrix_log_bytes "$BYT/fb.log"
assert_eq "bytes: empty log uses SB_E2E_MATRIX_LOG_FALLBACK" "8" "$TL_OUT"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$BYT" "SB_E2E_MATRIX_DRIVER_LOG=$BYT/driver.log")
call enterprise_e2e_matrix_log_bytes "$BYT/fb.log"
assert_eq "bytes: empty log falls back to the driver log" "8" "$TL_OUT"
# Last resort: sum of row attempt logs.
: >"$BYT/fb.log"
printf '123456' >"$BYT/.e2e-row2-attempt.log"
printf '1234' >"$BYT/.e2e-row9-attempt.log"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$BYT" "SB_E2E_MATRIX_LOG_FALLBACK=$BYT/fb.log")
call enterprise_e2e_matrix_log_bytes "$BYT/fb.log"
assert_eq "bytes: empty everywhere sums the row attempt logs" "10" "$TL_OUT"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$TL_TMP/no-rows")
mkdir -p "$TL_TMP/no-rows"
call enterprise_e2e_matrix_log_bytes "$TL_TMP/no-rows/m.log"
assert_eq "bytes: nothing at all is 0" "0" "$TL_OUT"
CALL_ENV=("SB_E2E_MATRIX_BATCH_PID_FILE=$PIDF" "SB_ROOT=$TL_TMP/no-rows" "SB_E2E_MATRIX_LOG=$TL_TMP/no-rows/default.log")
printf 'zz' >"$TL_TMP/no-rows/default.log"
call enterprise_e2e_matrix_log_bytes
assert_eq "bytes: path defaults to the matrix log" "2" "$TL_OUT"

# --- ledger helpers ---------------------------------------------------------
CALL_ENV=("SB_ROOT=$SBR"); call enterprise_e2e_ledger_file
assert_eq "ledger file default" "$SBR/.planning/enterprise-e2e/ROUND-1-LEDGER.md" "$TL_OUT"
CALL_ENV=("SB_ROOT=$SBR" "SB_E2E_LEDGER_FILE=/l.md"); call enterprise_e2e_ledger_file
assert_eq "ledger file override" "/l.md" "$TL_OUT"
call enterprise_e2e_all_row_nums
assert_eq "all rows is 1..20" "$(seq 1 20)" "$TL_OUT"

# row_complete_in_log
RC="$TL_TMP/rows.log"
cat >"$RC" <<'LOG'
=== Row 1: first ===
  PASS: all good
=== Row 2: second ===
  SKIP: not applicable
=== Row 3: third ===
  DRY RUN PASS
=== Row 4: fourth ===
  PASS: looked fine
  FAIL: but then not
=== Row 5: fifth ===
  FAIL: nope
=== Row 6: sixth ===
  PASS: first attempt
=== Row 7: seventh ===
  nothing conclusive
=== Row 6: sixth again ===
  FAIL: second attempt
LOG
rc_check() { call enterprise_e2e_row_complete_in_log "$1" "${2:-$RC}"; }
CALL_ENV=("E2E_X=1")
rc_check 1; assert_eq "row log: PASS" 0 "$TL_STATUS"
rc_check 2; assert_eq "row log: SKIP" 0 "$TL_STATUS"
rc_check 3; assert_eq "row log: DRY RUN PASS" 0 "$TL_STATUS"
rc_check 4; assert_eq "row log: FAIL after PASS cancels" 1 "$TL_STATUS"
rc_check 5; assert_eq "row log: FAIL only" 1 "$TL_STATUS"
rc_check 6; assert_eq "row log: earlier completed attempt counts" 0 "$TL_STATUS"
rc_check 7; assert_eq "row log: inconclusive" 1 "$TL_STATUS"
rc_check 9; assert_eq "row log: absent row" 1 "$TL_STATUS"
rc_check 1 "$TL_TMP/no-such.log"; assert_eq "row log: missing file" 1 "$TL_STATUS"

# ledger_row_is_pass / incomplete_rows
mk_ledger() {  # mk_ledger FILE ROW:STATUS...
  local f="$1"
  shift
  {
    echo "| # | WF slug | Pass/Fail | graphify_query_ref | agentmemory_export_ref |"
    echo "|---|---------|-----------|--------------------|------------------------|"
    local spec
    for spec in "$@"; do
      echo "| ${spec%%:*} | wf-${spec%%:*} | ${spec#*:} | q | m |"
    done
    echo "**Pass count: x**"
  } >"$f"
}
LED="$TL_TMP/ledger.md"
mk_ledger "$LED" 1:Pass 2:Fail 3:"**Pass**"
call enterprise_e2e_ledger_row_is_pass 1 "$LED";  assert_eq "ledger pass row" 0 "$TL_STATUS"
call enterprise_e2e_ledger_row_is_pass 3 "$LED";  assert_eq "ledger bold pass row" 0 "$TL_STATUS"
call enterprise_e2e_ledger_row_is_pass 2 "$LED";  assert_eq "ledger fail row" 1 "$TL_STATUS"
call enterprise_e2e_ledger_row_is_pass 9 "$LED";  assert_eq "ledger absent row" 1 "$TL_STATUS"
call enterprise_e2e_ledger_row_is_pass 1 "";      assert_eq "ledger path empty" 1 "$TL_STATUS"
call enterprise_e2e_ledger_row_is_pass 1 "$TL_TMP/none.md"; assert_eq "ledger missing" 1 "$TL_STATUS"

call enterprise_e2e_incomplete_rows "$RC" "$LED"
assert_eq "incomplete rows via ledger skip passes" "$(seq 2 2; seq 4 20)" "$TL_OUT"
call enterprise_e2e_incomplete_rows "$RC"
assert_eq "incomplete rows via log (no ledger)" "$(printf '%s\n' 4 5 7 8 9 10 11 12 13 14 15 16 17 18 19 20)" "$TL_OUT"
call enterprise_e2e_incomplete_rows "$RC" "$TL_TMP/none.md"
assert_eq "incomplete rows: missing ledger file falls back to the log" "$(printf '%s\n' 4 5 7 8 9 10 11 12 13 14 15 16 17 18 19 20)" "$TL_OUT"
all_pass=()
for n in $(seq 1 20); do all_pass+=("$n:Pass"); done
mk_ledger "$TL_TMP/full.md" "${all_pass[@]}"
call enterprise_e2e_incomplete_rows "$RC" "$TL_TMP/full.md"
assert_eq "incomplete rows: everything passed prints nothing" "" "$TL_OUT"
assert_eq "incomplete rows: everything passed exits 0" 0 "$TL_STATUS"

# --- reconcile library resolution (ledger-reconcile not preloaded) -----------
# Staged tree without scripts/enterprise-e2e/lib/deterministic: core.sh falls back to scripts/lib,
# and without the row-pass registry library the legacy registry code paths are used.
STG="$TL_TMP/stage"
mkdir -p "$STG/scripts/enterprise-e2e/lib" "$STG/scripts/lib"
for f in core.sh host.sh test-app-branch.sh; do ln -s "$TL_REPO_ROOT/scripts/enterprise-e2e/lib/$f" "$STG/scripts/enterprise-e2e/lib/$f"; done
ln -s "$TL_REPO_ROOT/scripts/lib/enterprise-e2e-ledger-reconcile.sh" "$STG/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
LIB="$STG/scripts/enterprise-e2e/lib/core.sh"
CALL_ENV=("SB_ROOT=$STG")
call enterprise_e2e_ledger_row_is_pass 1 "$LED"
assert_eq "fallback reconcile lib: pass row" 0 "$TL_STATUS"
call enterprise_e2e_ledger_row_is_pass 2 "$LED"
assert_eq "fallback reconcile lib: fail row" 1 "$TL_STATUS"
# deterministic/ present (the real tree) is the preferred source.
LIB="$CORE"
CALL_ENV=("SB_ROOT=$SBR")
call enterprise_e2e_ledger_row_is_pass 1 "$LED"
assert_eq "deterministic reconcile lib: pass row" 0 "$TL_STATUS"

# --- install version key / registry ----------------------------------------
IV="$TL_TMP/iv"
mkdir -p "$IV"
echo '{"version": "9.8.7"}' >"$IV/package.json"
git -C "$IV" init -q -b main
git -C "$IV" config user.email e@t; git -C "$IV" config user.name E; git -C "$IV" config commit.gpgsign false
git -C "$IV" add package.json; git -C "$IV" commit -q -m init
IV_SHA="$(git -C "$IV" rev-parse --short HEAD)"
CALL_ENV=("SB_ROOT=$IV"); call enterprise_e2e_install_version_file
assert_eq "install version file" "$IV/.e2e-install-version.txt" "$TL_OUT"
call enterprise_e2e_pass_at_version_registry
assert_eq "pass-at-version registry" "$IV/.e2e-matrix-pass-at-version.tsv" "$TL_OUT"
call enterprise_e2e_sb_install_version_key
assert_eq "key derived from package.json and git sha" "9.8.7@$IV_SHA" "$TL_OUT"
CALL_ENV=("SB_ROOT=$IV" "SB_E2E_INSTALL_VERSION_KEY=forced@key"); call enterprise_e2e_sb_install_version_key
assert_eq "key override" "forced@key" "$TL_OUT"
CALL_ENV=("SB_ROOT=$TL_TMP/no-pkg"); mkdir -p "$TL_TMP/no-pkg"; call enterprise_e2e_sb_install_version_key
assert_eq "key without package.json or git" "0.0.0@unknown" "$TL_OUT"
CALL_ENV=("SB_ROOT=$IV" "SB_E2E_PASS_AT_VERSION_REGISTRY=$IV/elsewhere.tsv"); call enterprise_e2e_pass_at_version_registry
assert_eq "registry override" "$IV/elsewhere.tsv" "$TL_OUT"
CALL_ENV=("E2E_X=1"); call enterprise_e2e_install_version_file
assert_contains "install version file without SB_ROOT derives from the repo" "$TL_OUT" "$TL_REPO_ROOT/.e2e-install-version.txt"
call enterprise_e2e_pass_at_version_registry
assert_contains "registry without SB_ROOT derives from the repo" "$TL_OUT" "$TL_REPO_ROOT/.e2e-matrix-pass-at-version.tsv"

CALL_ENV=("SB_ROOT=$IV"); call enterprise_e2e_write_sb_install_version "$IV"
assert_eq "write version returns the key" "9.8.7@$IV_SHA" "$TL_OUT"
assert_eq "version file content" $'SB_PLUGIN_VERSION=9.8.7\nSB_INSTALL_SHA='"$IV_SHA"$'\nSB_INSTALL_VERSION_KEY=9.8.7@'"$IV_SHA" "$(cat "$IV/.e2e-install-version.txt")"
call enterprise_e2e_sb_install_version_key
assert_eq "key read back from the version file (full key)" "9.8.7@$IV_SHA" "$TL_OUT"
printf 'SB_PLUGIN_VERSION=1.2.3\nSB_INSTALL_SHA=abc\n' >"$IV/.e2e-install-version.txt"
call enterprise_e2e_sb_install_version_key
assert_eq "key from plugin version + sha when no full key" "1.2.3@abc" "$TL_OUT"
printf 'SB_PLUGIN_VERSION=1.2.3\n' >"$IV/.e2e-install-version.txt"
call enterprise_e2e_sb_install_version_key
assert_eq "partial version file falls back to derived key" "9.8.7@$IV_SHA" "$TL_OUT"
rm -f "$IV/.e2e-install-version.txt"
call enterprise_e2e_write_sb_install_version "$TL_TMP/no-such-root"
assert_eq "write version needs an existing root" 1 "$TL_STATUS"
call enterprise_e2e_write_sb_install_version "$IV" 4.5.6 deadbee
assert_eq "write version honours explicit plugin and sha" "4.5.6@deadbee" "$TL_OUT"
rm -f "$IV/.e2e-install-version.txt"
call enterprise_e2e_write_sb_install_version
assert_eq "write version defaults the root from SB_ROOT" "9.8.7@$IV_SHA" "$TL_OUT"
rm -f "$IV/.e2e-install-version.txt"

# force flags
CALL_ENV=("E2E_X=1"); call enterprise_e2e_matrix_force_active
assert_eq "force inactive by default" 1 "$TL_STATUS"
CALL_ENV=("SB_E2E_MATRIX_FORCE=1"); call enterprise_e2e_matrix_force_active
assert_eq "SB_E2E_MATRIX_FORCE activates" 0 "$TL_STATUS"
CALL_ENV=("SB_E2E_FORCE_ROW=1"); call enterprise_e2e_matrix_force_active
assert_eq "SB_E2E_FORCE_ROW activates" 0 "$TL_STATUS"

# record / passed-at-version (no registry library staged: legacy TSV path)
LIB="$STG/scripts/enterprise-e2e/lib/core.sh"
IV2="$TL_TMP/iv2"
cp -R "$IV" "$IV2"
rm -rf "$IV2/.git"
CALL_ENV=("SB_ROOT=$IV2" "SB_E2E_INSTALL_VERSION_KEY=2.0.0@aaa")
call enterprise_e2e_record_row_pass_at_install_version abc
assert_eq "record: non-numeric row rejected" 1 "$TL_STATUS"
call enterprise_e2e_record_row_pass_at_install_version 4 /some/ledger.md
assert_eq "record: ok" 0 "$TL_STATUS"
call enterprise_e2e_record_row_pass_at_install_version 4 /some/ledger.md
assert_eq "record: second record is deduplicated" "1" "$(wc -l <"$IV2/.e2e-matrix-pass-at-version.tsv" | tr -d ' ')"
assert_match "record: tsv row format" $'^4\t2.0.0@aaa\t/some/ledger.md\t[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(cat "$IV2/.e2e-matrix-pass-at-version.tsv")"
call enterprise_e2e_record_row_pass_at_install_version 5
assert_eq "record: another row appended" "2" "$(wc -l <"$IV2/.e2e-matrix-pass-at-version.tsv" | tr -d ' ')"
call enterprise_e2e_row_passed_at_install_version x
assert_eq "passed-at: non-numeric row" 1 "$TL_STATUS"
call enterprise_e2e_row_passed_at_install_version 4
assert_eq "passed-at: recorded row" 0 "$TL_STATUS"
call enterprise_e2e_row_passed_at_install_version 4 "9.9.9@zzz"
assert_eq "passed-at: other version not recorded" 1 "$TL_STATUS"
# Ledger-derived pass: a ledger whose SB SHA matches the version key.
mkdir -p "$IV2/.planning/enterprise-e2e"
{
  echo "| Field | Value |"
  echo "| SB repo SHA | \`feed123\` |"
  echo "| # | WF slug | Pass/Fail | graphify_query_ref | agentmemory_export_ref |"
  echo "|---|---|---|---|---|"
  echo "| 8 | wf | Pass | q | m |"
  echo "**Pass count: 1**"
} >"$IV2/.planning/enterprise-e2e/ROUND-CODEX-9-LEDGER.md"
CALL_ENV=("SB_ROOT=$IV2")
call enterprise_e2e_ledger_sb_sha "$IV2/.planning/enterprise-e2e/ROUND-CODEX-9-LEDGER.md"
assert_eq "ledger sb sha parsed and cleaned" "feed123" "$TL_OUT"
call enterprise_e2e_ledger_sb_sha "$TL_TMP/none.md"
assert_eq "ledger sb sha: missing file" 1 "$TL_STATUS"
call enterprise_e2e_ledger_sb_sha "$LED"
assert_eq "ledger sb sha: absent row" 1 "$TL_STATUS"
call enterprise_e2e_row_passed_at_install_version 8 "3.0.0@feed123"
assert_eq "passed-at: derived from a matching ledger" 0 "$TL_STATUS"
assert_eq "passed-at: derived pass is recorded for the row" "1" "$(grep -c '^8'$'\t' "$IV2/.e2e-matrix-pass-at-version.tsv")"
call enterprise_e2e_row_passed_at_install_version 8 "3.0.0@other"
assert_eq "passed-at: ledger sha mismatch" 1 "$TL_STATUS"
call enterprise_e2e_row_passed_at_install_version 7 "3.0.0@feed123"
assert_eq "passed-at: row not Pass in ledger" 1 "$TL_STATUS"
# ledger without an SB SHA row is skipped
{
  echo "| # | WF slug | Pass/Fail | graphify_query_ref | agentmemory_export_ref |"
  echo "|---|---|---|---|---|"
  echo "| 12 | wf | Pass | q | m |"
  echo "**Pass count: 1**"
} >"$IV2/.planning/enterprise-e2e/ROUND-CODEX-10-LEDGER.md"
call enterprise_e2e_row_passed_at_install_version 12 "3.0.0@feed123"
assert_eq "passed-at: ledger without SB sha is skipped" 1 "$TL_STATUS"
# default version taken from the key function
CALL_ENV=("SB_ROOT=$IV2" "SB_E2E_INSTALL_VERSION_KEY=3.0.0@feed123")
call enterprise_e2e_row_passed_at_install_version 8
assert_eq "passed-at: version defaults to the install key" 0 "$TL_STATUS"

# should_skip (legacy path then registry path)
CALL_ENV=("SB_ROOT=$IV2" "SB_E2E_INSTALL_VERSION_KEY=2.0.0@aaa" "SB_E2E_MATRIX_FORCE_ALL=1")
call enterprise_e2e_matrix_should_skip_row_at_version 4
assert_eq "should-skip: FORCE_ALL never skips" 1 "$TL_STATUS"
CALL_ENV=("SB_ROOT=$IV2" "SB_E2E_INSTALL_VERSION_KEY=2.0.0@aaa")
call enterprise_e2e_matrix_should_skip_row_at_version 4
assert_eq "should-skip (legacy): recorded row skipped" 0 "$TL_STATUS"
call enterprise_e2e_matrix_should_skip_row_at_version 11
assert_eq "should-skip (legacy): unrecorded row runs" 1 "$TL_STATUS"

# With the real registry library loaded
LIB="$CORE"
REG="$TL_TMP/reg/.row-pass-registry.json"
CALL_ENV=("SB_ROOT=$IV2" "SB_E2E_INSTALL_VERSION_KEY=2.0.0@aaa" "SB_E2E_ROW_PASS_REGISTRY=$REG")
call enterprise_e2e_matrix_should_skip_row_at_version 4
assert_eq "should-skip (registry lib): no registry entry runs the row" 1 "$TL_STATUS"
call enterprise_e2e_record_row_pass_at_install_version 6 "" "$TL_TMP/m.log"
assert_eq "record with registry lib ok" 0 "$TL_STATUS"
assert_file_exists "record with registry lib writes the registry" "$REG"
call enterprise_e2e_row_passed_at_install_version 4
assert_eq "passed-at via TSV even with registry lib when registry lacks the row" 0 "$TL_STATUS"

# --- assert_no_auth_mutations ----------------------------------------------
printf '# claude auth login is documented here\necho ok\n' >"$TL_TMP/clean.sh"
printf 'claude auth logout\n' >"$TL_TMP/bad.sh"
printf 'echo setup-token\n' >"$TL_TMP/bad2.sh"
CALL_ENV=("E2E_X=1")
call enterprise_e2e_assert_no_auth_mutations "$TL_TMP/clean.sh"
assert_eq "no-auth: comments are ignored" 0 "$TL_STATUS"
call enterprise_e2e_assert_no_auth_mutations "$TL_TMP/bad.sh"
assert_eq "no-auth: logout command rejected" 1 "$TL_STATUS"
assert_contains "no-auth: message names the script" "$TL_ERR" "$TL_TMP/bad.sh must not invoke login/logout"
call enterprise_e2e_assert_no_auth_mutations "$TL_TMP/bad2.sh"
assert_eq "no-auth: setup-token rejected" 1 "$TL_STATUS"
call enterprise_e2e_assert_no_auth_mutations "$TL_TMP/absent.sh"
assert_eq "no-auth: unreadable script passes" 0 "$TL_STATUS"

# --- live test lock ---------------------------------------------------------
CALL_ENV=("SB_ROOT=$SBR" "SB_E2E_LIVE_TEST_LOCK_FILE=/x.lock"); RT=codex call enterprise_e2e_live_test_lock_file
assert_eq "lock file override" "/x.lock" "$TL_OUT"
CALL_ENV=("SB_ROOT=$SBR"); RT=claude call enterprise_e2e_live_test_lock_file
assert_eq "claude lock file" "$SBR/.e2e-live-test.lock" "$TL_OUT"
RT=codex call enterprise_e2e_live_test_lock_file
assert_eq "codex lock file is host-named" "$SBR/.e2e-live-test-codex.lock" "$TL_OUT"
RT=claude
LOCK="$TL_TMP/live.lock"
CALL_ENV=("SB_E2E_LIVE_TEST_LOCK_FILE=$LOCK")
rm -f "$LOCK"
call enterprise_e2e_release_live_test_lock
assert_eq "release: no lock is fine" 0 "$TL_STATUS"
e2e_script "source '$CORE'; enterprise_e2e_acquire_live_test_lock; echo \"pid=\$\$\"; cat '$LOCK'; enterprise_e2e_release_live_test_lock; [[ -e '$LOCK' ]] && echo STILL || echo RELEASED" "SB_E2E_LIVE_TEST_LOCK_FILE=$LOCK"
assert_eq "acquire writes our pid, release removes it" "RELEASED" "$(tail -1 <<<"$TL_OUT")"
assert_eq "lock holds the acquiring pid" "$(sed -n 1p <<<"$TL_OUT" | sed 's/^pid=//')" "$(sed -n 2p <<<"$TL_OUT")"
echo "$$" >"$LOCK"
call enterprise_e2e_acquire_live_test_lock
assert_eq "acquire: refused while another live pid holds it" 1 "$TL_STATUS"
assert_contains "acquire: refusal names the pid" "$TL_ERR" "already running (pid $$; lock $LOCK)"
call enterprise_e2e_release_live_test_lock
assert_eq "release: foreign lock is kept" "$$" "$(cat "$LOCK")"
echo "$DEAD_PID" >"$LOCK"
e2e_script "source '$CORE'; enterprise_e2e_acquire_live_test_lock; [[ \"\$(cat '$LOCK')\" == \"\$\$\" ]] && echo TAKEN" "SB_E2E_LIVE_TEST_LOCK_FILE=$LOCK"
assert_contains "acquire: stale lock is replaced" "$TL_OUT" "WARN: removing stale live-test lock (pid $DEAD_PID not running)"
assert_contains "acquire: stale lock taken over" "$TL_OUT" "TAKEN"
: >"$LOCK"
e2e_script "source '$CORE'; enterprise_e2e_acquire_live_test_lock" "SB_E2E_LIVE_TEST_LOCK_FILE=$LOCK"
assert_contains "acquire: empty lock file counts as stale (unknown pid)" "$TL_OUT" "pid unknown not running"

tl_results

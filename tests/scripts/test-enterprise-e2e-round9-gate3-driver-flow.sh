#!/usr/bin/env bash
# round9-gate3-driver.sh: preflight failures, registry-driven row selection, migrate, tmux and
# detached launch paths against a staged SB root with recording stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init

R="$TL_TMP/root"
f2_stage_root "$R"
mkdir -p "$R/.planning/enterprise-e2e"
printf '{"hooks":{}}\n' >"$R/hooks/hooks.json"
printf '{"version":"1.2.3"}\n' >"$R/package.json"
git -C "$R" config user.email t@example.com
git -C "$R" config user.name t
git -C "$R" add -A >/dev/null 2>&1 || true
git -C "$R" commit -qm init --allow-empty

# replace the linked detach helper with a recording stub (TTY presence is steered by F2_TTY)
rm -f "$R/tests/live/lib"
mkdir -p "$R/tests/live/lib"
cat >"$R/tests/live/lib/detach-background.sh" <<'EOS'
sb_prepend_harness_path() { :; }
sb_detach_has_controlling_tty() { [[ "${F2_TTY:-0}" == 1 ]]; }
sb_run_detached_pty() { printf 'pty %s\n' "$*" >>"${F2_CALLS:?}"; printf '4343\n'; }
EOS

cp "$TL_REPO_ROOT/scripts/enterprise-e2e/round9-gate3-driver.sh" "$R/scripts/enterprise-e2e/"
export F2_CALLS="$TL_TMP/calls"
for s in scripts/run-enterprise-e2e-live-test.sh scripts/enterprise-e2e/strict-clean-check.sh scripts/enterprise-e2e/registry-migrate-install.sh; do
  f2_stub_script "$R/$s" "$s"
done
DRIVER="$R/scripts/enterprise-e2e/round9-gate3-driver.sh"

APP="$TL_TMP/app"
mkdir -p "$APP"
git -C "$APP" init -q -b enterprise-e2e/round-9-claude
git -C "$APP" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
LEDGER="$R/.planning/enterprise-e2e/ROUND-9-LEDGER.md"
REG="$R/.planning/enterprise-e2e/.row-pass-registry.json"
: >"$LEDGER"
tl_stub claude 'exit 0'

unset SB_E2E_MAIN_REPO SB_ROOT SB_E2E_LEDGER_FILE SB_E2E_ROW_PASS_REGISTRY SB_TEST_ENTERPRISE_APP_ROOT \
  SB_E2E_REGISTRY_MIGRATE_FROM SB_E2E_MATRIX_LOG SB_E2E_TEST_APP_BRANCH SB_E2E_MATRIX_FORCE_ALL F2_FAIL_STEP F2_TTY
export SB_TEST_ENTERPRISE_APP_ROOT="$APP"
export SB_E2E_MAIN_REPO="$R"

run() { : >"$F2_CALLS"; tl_run "$@"; CALLS="$(cat "$F2_CALLS")"; }

# --- arguments ----------------------------------------------------------------------
run bash "$DRIVER" --help
assert_eq "help exit" "0" "$TL_STATUS"
assert_contains "help prints the header comment" "$TL_OUT" "Round 9 Claude Gate 3"
run bash "$DRIVER" bogus
assert_eq "non-numeric arg exit" "2" "$TL_STATUS"
assert_contains "non-numeric arg message" "$TL_ERR" "Unknown arg: bogus"

# --- preflight failures -----------------------------------------------------------
rm -f "$LEDGER"
run bash "$DRIVER" --preflight-only
assert_eq "missing ledger exit" "1" "$TL_STATUS"
assert_contains "missing ledger message" "$TL_ERR" "PREFLIGHT FAIL: ledger missing: $LEDGER"
: >"$LEDGER"

run env SB_TEST_ENTERPRISE_APP_ROOT="$TL_TMP/nope" bash "$DRIVER" --preflight-only
assert_eq "missing fixture exit" "1" "$TL_STATUS"
assert_contains "missing fixture message" "$TL_ERR" "PREFLIGHT FAIL: fixture missing: $TL_TMP/nope"

run env PATH="$(tl_path_without claude)" bash "$DRIVER" --preflight-only
assert_eq "missing claude exit" "1" "$TL_STATUS"
assert_contains "missing claude message" "$TL_ERR" "PREFLIGHT FAIL: claude CLI not on PATH"

jqless="$(tl_path_without jq)"
run env PATH="$TL_BIN:$jqless" bash "$DRIVER" --preflight-only
assert_eq "missing jq exit" "1" "$TL_STATUS"
assert_contains "missing jq message" "$TL_ERR" "PREFLIGHT FAIL: jq required"

# --- preflight-only run ----------------------------------------------------------------
run bash "$DRIVER" --preflight-only
assert_eq "preflight-only exit" "0" "$TL_STATUS"
assert_contains "header" "$TL_OUT" "=== Round 9 Gate 3 driver "
assert_contains "MAIN echoed" "$TL_OUT" "  MAIN=$R"
assert_contains "SB_ROOT echoed with sha" "$TL_OUT" "  SB_ROOT=$R @ "
assert_contains "fixture echoed" "$TL_OUT" "  fixture=$APP"
assert_contains "default ledger echoed" "$TL_OUT" "  ledger=$LEDGER"
assert_contains "registry count zero" "$TL_OUT" "registry_pass_count=0/22 @ current install_fp"
assert_contains "all rows scheduled" "$TL_OUT" "rows_to_run: 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22"
assert_contains "preflight ok" "$TL_OUT" "PREFLIGHT OK — launch full matrix without --preflight-only"
assert_contains "offline preflight ran live-test --preflight-only" "$CALLS" "scripts/run-enterprise-e2e-live-test.sh --preflight-only"
assert_not_contains "no branch warning when branch matches" "$TL_OUT" "WARN: fixture on"
install_fp="$(sed -n 's/^  install_fp=//p' <<<"$TL_OUT")"
assert_match "install fingerprint printed" '^claude@[0-9a-f]{12}\+[0-9a-f]{12}$' "$install_fp"

# wrong fixture branch only warns
git -C "$APP" checkout -q -b other-branch
run bash "$DRIVER" --preflight-only
assert_eq "wrong branch still proceeds" "0" "$TL_STATUS"
assert_contains "wrong branch warning" "$TL_OUT" "WARN: fixture on 'other-branch' — want enterprise-e2e/round-9-claude"
git -C "$APP" checkout -q enterprise-e2e/round-9-claude

# offline preflight failure
run env F2_FAIL_STEP=scripts/run-enterprise-e2e-live-test.sh bash "$DRIVER" --preflight-only
assert_eq "live-test preflight failure exit" "1" "$TL_STATUS"
assert_contains "live-test preflight failure message" "$TL_ERR" "PREFLIGHT FAIL: live-test --preflight-only"

# --- registry-driven row selection ---------------------------------------------------------
jq -n --arg fp "$install_fp" '{installs: {($fp): {rows: {"1": {outcome_pass: true}, "3": {outcome_pass: true}, "6": {outcome_pass: false}}}}}' >"$REG"
run bash "$DRIVER" --preflight-only
assert_contains "registry count reflects passes" "$TL_OUT" "registry_pass_count=2/22 @ current install_fp"
assert_contains "passed row 1 skipped" "$TL_OUT" "skip row 1 (registry pass on current install_fp)"
assert_contains "passed row 3 skipped" "$TL_OUT" "skip row 3 (registry pass on current install_fp)"
assert_contains "row 6 (no outcome pass) still runs" "$TL_OUT" "rows_to_run: 2 4 5 6 7"
run env SB_E2E_MATRIX_FORCE_ALL=1 bash "$DRIVER" --preflight-only
assert_contains "FORCE_ALL ignores the registry" "$TL_OUT" "rows_to_run: 1 2 3"

# explicit rows bypass registry selection
run bash "$DRIVER" --preflight-only 2 4 5 7
assert_contains "explicit rows used" "$TL_OUT" "rows_to_run: 2 4 5 7"
assert_not_contains "no skip lines for explicit rows" "$TL_OUT" "skip row"

# all 22 rows already passed: strict-clean decides
jq -n --arg fp "$install_fp" '{installs: {($fp): {rows: ([range(1;23)] | map({key: (.|tostring), value: {outcome_pass: true}}) | from_entries)}}}' >"$REG"
run bash "$DRIVER"
assert_eq "all rows passed + strict-clean pass exit" "0" "$TL_STATUS"
assert_contains "complete registry message" "$TL_OUT" "All 22 rows already in registry @ $install_fp — run strict-clean-check"
assert_contains "strict-clean pass reported" "$TL_OUT" "STRICT-CLEAN: PASS"
assert_contains "strict-clean invoked with ledger" "$CALLS" "scripts/enterprise-e2e/strict-clean-check.sh --ledger $LEDGER"
assert_not_contains "no matrix launch when complete" "$CALLS" "run-enterprise-e2e-live-test.sh"
run env F2_FAIL_STEP=scripts/enterprise-e2e/strict-clean-check.sh bash "$DRIVER"
assert_eq "strict-clean fail exit" "1" "$TL_STATUS"
assert_contains "strict-clean fail guidance" "$TL_ERR" "Registry complete but strict-clean FAIL"
rm -f "$REG"

# --- registry migrate -------------------------------------------------------------------------
run env SB_E2E_REGISTRY_MIGRATE_FROM="claude@old+111" bash "$DRIVER" --preflight-only
assert_contains "migrate announced" "$TL_OUT" "Registry migrate: claude@old+111 -> $install_fp"
assert_contains "migrate args" "$CALLS" "scripts/enterprise-e2e/registry-migrate-install.sh --from claude@old+111 --to $install_fp --rows 1,3,6,11,21,22 --source-note gate3-driver"
run env SB_E2E_REGISTRY_MIGRATE_FROM="claude@old+111" F2_FAIL_STEP=scripts/enterprise-e2e/registry-migrate-install.sh bash "$DRIVER" --preflight-only
assert_eq "migrate failure exit" "1" "$TL_STATUS"
assert_contains "migrate failure message" "$TL_ERR" "PREFLIGHT FAIL: registry migrate failed"

# --- matrix launch: detached (no controlling tty) ---------------------------------------------
run bash "$DRIVER" 2 4
assert_eq "detached launch exit" "0" "$TL_STATUS"
assert_contains "matrix banner" "$TL_OUT" "=== R9 Gate3 matrix "
assert_contains "matrix banner rows" "$TL_OUT" "rows=2 4 ==="
assert_contains "detached pid reported" "$TL_OUT" "Gate3 driver detached pid 4343 (log $R/.e2e-r9-gate3-driver.log)"
assert_contains "monitor hint uses default matrix log" "$TL_OUT" "Monitor: tail -f $R/.e2e-r9-gate3-matrix-live.log"
assert_eq "driver pid recorded" "4343" "$(cat "$R/.e2e-r9-gate3-driver.pid")"
assert_contains "pty launch of live test" "$CALLS" "pty --log $R/.e2e-r9-gate3-driver.log -- env RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh 2 4"

# --- matrix launch: with a controlling tty (exec + tee into the matrix log) -------------------
LOG="$TL_TMP/matrix.log"
: >"$LOG"
cat >"$R/scripts/run-enterprise-e2e-live-test.sh" <<'EOS'
#!/usr/bin/env bash
printf 'LIVE-TEST-OUTPUT rows=%s\n' "$*"
printf 'live-test %s\n' "$*" >>"$F2_CALLS"
[[ "${F2_FAIL_STEP:-}" == live && "${1:-}" != --preflight-only ]] && exit 7
exit 0
EOS
run env F2_TTY=1 SB_E2E_MATRIX_LOG="$LOG" bash "$DRIVER" 5
assert_eq "tty launch exit" "0" "$TL_STATUS"
assert_contains "live test output teed to terminal" "$TL_OUT" "LIVE-TEST-OUTPUT rows=5"
assert_contains "live test output appended to matrix log" "$(cat "$LOG")" "LIVE-TEST-OUTPUT rows=5"
assert_eq "live test launched exactly once under a tty" "1" "$(grep -c '^live-test 5' <<<"$CALLS")"
assert_not_contains "no second detached launch under a tty" "$CALLS" "pty "
assert_not_contains "no detached pid message under a tty" "$TL_OUT" "detached pid"
run env F2_TTY=1 F2_FAIL_STEP=live SB_E2E_MATRIX_LOG="$LOG" bash "$DRIVER" 5
assert_eq "live test failure propagates under a tty" "7" "$TL_STATUS"

# --- environment contract exported to children --------------------------------------------------
cat >"$R/scripts/run-enterprise-e2e-live-test.sh" <<'EOS'
#!/usr/bin/env bash
if [[ "${1:-}" != "--preflight-only" ]]; then
  printf 'ENV rt=%s surf=%s force=%s round=%s branch=%s base=%s ledger=%s skipinstall=%s\n' \
    "$SILVER_BULLET_RUNTIME" "$SB_E2E_SURFACE_SKIP" "$SB_E2E_MATRIX_FORCE" "$SB_E2E_TEST_APP_ROUND" \
    "$SB_E2E_TEST_APP_BRANCH" "$SB_E2E_TEST_APP_BASELINE_SHA" "$SB_E2E_LEDGER_FILE" "${SB_E2E_SKIP_INSTALL_CLAUDE-unset}" >>"$F2_CALLS"
fi
EOS
run env F2_TTY=1 SB_E2E_SKIP_INSTALL_CLAUDE=1 SB_E2E_MATRIX_LOG="$LOG" bash "$DRIVER" 1
assert_contains "env contract" "$CALLS" "ENV rt=claude surf=0 force=1 round=9 branch=enterprise-e2e/round-9-claude base=8482e60 ledger=$LEDGER skipinstall=unset"
f2_stub_script "$R/scripts/run-enterprise-e2e-live-test.sh" scripts/run-enterprise-e2e-live-test.sh

# --- tmux mode -----------------------------------------------------------------------------------
tl_stub tmux 'printf "tmux %s\n" "$*" >>"$F2_CALLS"'
run bash "$DRIVER" --tmux 3 8
assert_eq "tmux exit" "0" "$TL_STATUS"
assert_contains "tmux session announced" "$TL_OUT" "tmux session r9-gate3 started — attach: tmux attach -t r9-gate3"
assert_contains "stale session killed first" "$CALLS" "tmux kill-session -t r9-gate3"
assert_contains "session created detached" "$CALLS" "tmux new-session -d -s r9-gate3 cd '$R' && RTK_DISABLED=1 bash '$R/scripts/enterprise-e2e/round9-gate3-driver.sh' 3 8 2>&1 | tee -a '$R/.e2e-r9-gate3-matrix-live.log'"
assert_not_contains "matrix not launched directly under tmux" "$CALLS" "pty "
rm -f "$TL_BIN/tmux"
run env PATH="$(tl_path_without tmux)" bash "$DRIVER" --tmux 3
assert_eq "missing tmux exit" "1" "$TL_STATUS"
assert_contains "missing tmux message" "$TL_ERR" "PREFLIGHT FAIL: tmux required for --tmux"

tl_results

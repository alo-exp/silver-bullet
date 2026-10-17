#!/usr/bin/env bash
# live-test.sh: opt-in gates, preflight sequence, resume selection, overlay gate, monitor launch
# and consecutive-round check, against a staged SB root with recording stubs (no agent CLI, no network).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-f2-helpers.sh"
tl_init

R="$TL_TMP/root"
f2_stage_root "$R"
mkdir -p "$R/.planning/enterprise-e2e" "$R/tests/e2e-live/lib"

# own detach helper (records background launches) and own deterministic/ dir with a stub rounds check
rm -f "$R/tests/live/lib"
mkdir -p "$R/tests/live/lib"
cat >"$R/tests/live/lib/detach-background.sh" <<'EOS'
sb_prepend_harness_path() { :; }
sb_run_detached() { printf 'detach %s\n' "$*" >>"${F2_CALLS:?}"; printf '5151\n'; }
EOS
rm -f "$R/scripts/enterprise-e2e/lib"
mkdir -p "$R/scripts/enterprise-e2e/lib/deterministic"
for f in "$TL_REPO_ROOT"/scripts/enterprise-e2e/lib/*; do
  [[ "$(basename "$f")" == deterministic ]] && continue
  ln -s "$f" "$R/scripts/enterprise-e2e/lib/$(basename "$f")"
done
for f in "$TL_REPO_ROOT"/scripts/enterprise-e2e/lib/deterministic/*; do
  [[ "$(basename "$f")" == consecutive-rounds.sh ]] && continue
  ln -s "$(readlink -f "$f")" "$R/scripts/enterprise-e2e/lib/deterministic/$(basename "$f")"
done

cp "$TL_REPO_ROOT/scripts/enterprise-e2e/live-test.sh" "$R/scripts/enterprise-e2e/"
export F2_CALLS="$TL_TMP/calls"
for s in scripts/run-enterprise-e2e-validation-overlay.sh scripts/enterprise-e2e/lib/deterministic/consecutive-rounds.sh \
         scripts/monitor-enterprise-e2e-matrix.sh scripts/watch-enterprise-e2e-tui.sh scripts/run-enterprise-e2e-matrix.sh; do
  f2_stub_script "$R/$s" "$s"
done
# matrix.sh records its args and a few env variables
cat >"$R/scripts/enterprise-e2e/matrix.sh" <<'EOS'
#!/usr/bin/env bash
printf 'matrix args=[%s] pwd=%s dry=%s skipexp=%s clean=%s force=%s forceall=%s fixture=%s ledger=%s\n' "$*" "$PWD" \
  "${SB_E2E_MATRIX_DRY_RUN-unset}" "$SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT" "$SB_E2E_MATRIX_CLEAN_ENV" \
  "${SB_E2E_MATRIX_FORCE-}" "${SB_E2E_MATRIX_FORCE_ALL-}" "$SB_TEST_ENTERPRISE_APP_ROOT" "$SB_E2E_LEDGER_FILE" >>"$F2_CALLS"
echo "MATRIX-OUTPUT"
[[ "${F2_FAIL_STEP:-}" == matrix ]] && exit 7
exit 0
EOS
# hook-delivery preflight: fails the first $F2_HOOK_FAILS attempts
cat >"$R/tests/e2e-live/hook-delivery-preflight.sh" <<'EOS'
#!/usr/bin/env bash
n="$(cat "$F2_CALLS.hook" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$F2_CALLS.hook"
printf 'hook-delivery attempt=%s skipbootstrap=%s\n' "$n" "${SB_E2E_HOOK_DELIVERY_SKIP_BOOTSTRAP:-}" >>"$F2_CALLS"
(( n > ${F2_HOOK_FAILS:-0} ))
EOS
cat >"$R/tests/e2e-live/lib/session-start-preflight.sh" <<'EOS'
printf 'session-start-preflight runtime=%s\n' "$SILVER_BULLET_RUNTIME" >>"$F2_CALLS"
EOS

APP="$TL_TMP/app"
mkdir -p "$APP"
git -C "$APP" init -q
tl_stub npm 'printf "npm %s cwd=%s\n" "$*" "$PWD" >>"$F2_CALLS"; exit "${F2_NPM_RC:-0}"'
tl_stub sleep 'printf "sleep %s\n" "$*" >>"$F2_CALLS"'
tl_stub pgrep 'printf "pgrep %s\n" "$*" >>"$F2_CALLS"; [[ -n "${F2_PGREP_HIT:-}" ]]'
tl_stub pkill 'printf "pkill %s\n" "$*" >>"$F2_CALLS"'

LIVE="$R/scripts/enterprise-e2e/live-test.sh"
LEDGER="$TL_TMP/ledger.md"
LOG="$TL_TMP/matrix.log"
HEADER='| # | WF slug | Workflow | Pass/Fail | graphify_query_ref | agentmemory_export_ref |'
mk_ledger() { # mk_ledger PASS_ROWS...
  local i status
  {
    printf '%s\n|---|---|---|---|---|---|\n' "$HEADER"
    for ((i = 1; i <= 22; i++)); do
      status=Fail
      for p in "$@"; do [[ "$p" == "$i" ]] && status=Pass; done
      printf '| %d | s%d | wf | %s | g | a |\n' "$i" "$i" "$status"
    done
    printf '\n**Pass count: x/22**\n'
  } >"$LEDGER"
}
mk_ledger

unset SB_E2E_LIVE_RUNTIME SB_E2E_VALIDATION_OVERLAY SB_E2E_VALIDATION_PRE_GATE SB_E2E_MATRIX_MONITOR SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS \
  SB_ENTERPRISE_E2E_LIVE F2_HOOK_FAILS F2_NPM_RC F2_PGREP_HIT F2_FAIL_STEP F2_RECORD_HEAVY F2_HOSTBRANCH_FAIL SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_FORCE_ALL
export SILVER_BULLET_RUNTIME=claude
export F2_RECORD_HEAVY=1
export SB_TEST_ENTERPRISE_APP_ROOT="$APP"
export SB_E2E_LEDGER_FILE="$LEDGER"
export SB_E2E_MATRIX_LOG="$LOG"
export SB_E2E_HOST_GIT_BRANCH_ENFORCE=0
export SB_E2E_TEST_APP_BRANCH_ENFORCE=0
export SB_E2E_LIVE_TEST_LOCK_FILE="$TL_TMP/live.lock"
export SB_E2E_MATRIX_MONITOR_PID_FILE="$TL_TMP/monitor.pid"
export SB_E2E_TUI_WATCH_PID="$TL_TMP/watch.pid"
export SB_E2E_MATRIX_BATCH_PID_FILE="$TL_TMP/batch.pid"
export SB_E2E_MATRIX_MONITOR_STATUS_FILE="$TL_TMP/monitor-status.txt"
export SB_E2E_TUI_FINDINGS="$TL_TMP/findings.jsonl"
export SB_E2E_TUI_OFFSETS="$TL_TMP/offsets.json"
rm -f "$LOG"

run() { : >"$F2_CALLS"; rm -f "$F2_CALLS.hook"; tl_run "$@"; CALLS="$(cat "$F2_CALLS")"; }

# ------------------------------------------------------------------ usage / gates
run bash "$LIVE" --help
assert_eq "help exit" "0" "$TL_STATUS"
assert_contains "help usage" "$TL_OUT" "Usage: live-test.sh [--host claude|codex|cursor] [--preflight-only]"
run bash "$LIVE" -h
assert_eq "-h exit" "0" "$TL_STATUS"

run bash "$LIVE"
assert_eq "live opt-in missing exit" "2" "$TL_STATUS"
assert_contains "live opt-in message" "$TL_ERR" "set SB_ENTERPRISE_E2E_LIVE=1 to run live enterprise E2E"
assert_file_absent "no lock taken before opt-in check" "$TL_TMP/live.lock"

run env SB_ENTERPRISE_E2E_LIVE=1 F2_HOSTBRANCH_FAIL=1 bash "$LIVE"
assert_eq "host branch assertion failure exits 1" "1" "$TL_STATUS"

run env SB_ENTERPRISE_E2E_LIVE=1 SB_TEST_ENTERPRISE_APP_ROOT="$TL_TMP/nofixture" bash "$LIVE"
assert_eq "missing fixture exit" "1" "$TL_STATUS"
assert_contains "missing fixture message" "$TL_ERR" "ERROR: fixture not found at $TL_TMP/nofixture"
assert_file_absent "lock released on early exit" "$TL_TMP/live.lock"

# auth mutations in a collaborating script are refused
cp "$R/scripts/run-enterprise-e2e-matrix.sh" "$TL_TMP/matrix.keep"
printf '#!/usr/bin/env bash\nclaude auth login\n' >"$R/scripts/run-enterprise-e2e-matrix.sh"
run env SB_ENTERPRISE_E2E_LIVE=1 bash "$LIVE"
assert_eq "auth mutation refused exit" "1" "$TL_STATUS"
assert_contains "auth mutation message" "$TL_ERR" "must not invoke login/logout"
cp "$TL_TMP/matrix.keep" "$R/scripts/run-enterprise-e2e-matrix.sh"
printf '#!/usr/bin/env bash\nsetup-token\n' >"$R/scripts/monitor-enterprise-e2e-matrix.sh"
run env SB_ENTERPRISE_E2E_LIVE=1 bash "$LIVE"
assert_eq "auth mutation in monitor refused" "1" "$TL_STATUS"
f2_stub_script "$R/scripts/monitor-enterprise-e2e-matrix.sh" scripts/monitor-enterprise-e2e-matrix.sh

# lock contention
/bin/sleep 30 &
holder=$!
printf '%s\n' "$holder" >"$TL_TMP/live.lock"
run env SB_ENTERPRISE_E2E_LIVE=1 bash "$LIVE"
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
assert_eq "running driver blocks a second one" "1" "$TL_STATUS"
assert_contains "lock contention message" "$TL_ERR" "enterprise E2E live test already running (pid $holder"
assert_eq "foreign lock left intact" "$holder" "$(tr -d '[:space:]' <"$TL_TMP/live.lock")"
rm -f "$TL_TMP/live.lock"

# ------------------------------------------------------------------ preflight-only
run bash "$LIVE" --preflight-only
assert_eq "preflight-only exit" "0" "$TL_STATUS"
assert_contains "banner" "$TL_OUT" "=== Enterprise E2E Live Test ==="
assert_contains "fixture shown" "$TL_OUT" "Fixture:     $APP"
assert_contains "ledger shown" "$TL_OUT" "Ledger:      $LEDGER"
assert_contains "matrix log shown" "$TL_OUT" "Matrix log:  $LOG"
assert_contains "host shown" "$TL_OUT" "Host:        claude"
assert_contains "dry run unset" "$TL_OUT" "DRY_RUN:     unset (live)"
assert_contains "test-app branch preflight ran" "$TL_OUT" "Test-app branch preflight: skipped"
assert_contains "preflight-only message" "$TL_OUT" "Preflight complete (--preflight-only)."
assert_file_absent "preflight-only takes no lock" "$TL_TMP/live.lock"
assert_contains "code-intel preflight ran with fixture" "$CALLS" "code-intel $R $APP 0"
assert_contains "hook delivery bootstrap skipped" "$CALLS" "hook-delivery attempt=1 skipbootstrap=1"
assert_contains "npm test ran in the fixture" "$CALLS" "npm test cwd=$APP"
assert_contains "session-start preflight sourced as cursor" "$CALLS" "session-start-preflight runtime=cursor"
assert_contains "host install ran" "$CALLS" "install-host $R"
assert_contains "host preflight ran" "$CALLS" "preflight-host $R"
assert_not_contains "no session 0 gate in preflight-only" "$CALLS" "session0"
assert_not_contains "no matrix in preflight-only" "$CALLS" "matrix args"

# --host selects the runtime; skipping code-intel
run bash "$LIVE" --preflight-only --host codex --skip-code-intel-preflight
assert_eq "codex preflight exit" "0" "$TL_STATUS"
assert_contains "codex host shown" "$TL_OUT" "Host:        codex"
assert_contains "code-intel skip warning" "$TL_OUT" "WARN: skipping code-intel preflight (--skip-code-intel-preflight; debug only)"
assert_not_contains "code-intel not run when skipped" "$CALLS" "code-intel"

# hook-delivery retries: two failures then success; three failures abort
run env F2_HOOK_FAILS=2 bash "$LIVE" --preflight-only
assert_eq "hook delivery succeeds on third attempt" "0" "$TL_STATUS"
assert_contains "retry warning 1" "$TL_ERR" "WARN: hook-delivery preflight attempt 1/3 failed; retrying..."
assert_contains "retry warning 2" "$TL_ERR" "WARN: hook-delivery preflight attempt 2/3 failed; retrying..."
assert_eq "slept between attempts" "2" "$(grep -c '^sleep 2$' <<<"$CALLS")"
run env F2_HOOK_FAILS=3 bash "$LIVE" --preflight-only
assert_eq "hook delivery exhausted exits 1" "1" "$TL_STATUS"
assert_not_contains "install not reached after hook failure" "$CALLS" "install-host"

# fixture test failure aborts; absent session-start preflight is skipped
run env F2_NPM_RC=1 bash "$LIVE" --preflight-only
assert_eq "fixture npm test failure aborts" "1" "$TL_STATUS"
mv "$R/tests/e2e-live/lib/session-start-preflight.sh" "$TL_TMP/ssp.keep"
run bash "$LIVE" --preflight-only
assert_eq "no session-start preflight is fine" "0" "$TL_STATUS"
assert_not_contains "session-start preflight skipped when absent" "$CALLS" "session-start-preflight"
mv "$TL_TMP/ssp.keep" "$R/tests/e2e-live/lib/session-start-preflight.sh"

# ------------------------------------------------------------------ live run with explicit rows
export SB_ENTERPRISE_E2E_LIVE=1
run bash "$LIVE" 3 6
assert_eq "explicit-row live run exit" "0" "$TL_STATUS"
assert_contains "session 0 gate" "$CALLS" "session0 $APP $LEDGER"
assert_contains "validation overlay default-on header" "$TL_OUT" "--- Validation overlay pre-matrix gate (dry-run) ---"
assert_contains "validation overlay ran in dry-run" "$CALLS" "scripts/run-enterprise-e2e-validation-overlay.sh --dry-run"
assert_contains "validation overlay pass" "$TL_OUT" "Validation overlay pre-matrix gate: PASS"
assert_contains "monitor start announced" "$TL_OUT" "matrix-monitor: starting in background..."
assert_contains "monitor pid shown" "$TL_OUT" "matrix-monitor: pid 5151"
assert_contains "watch started" "$TL_OUT" "tui-watch: pid 5151"
assert_eq "monitor pid file" "5151" "$(cat "$TL_TMP/monitor.pid")"
assert_eq "watch pid file" "5151" "$(cat "$TL_TMP/watch.pid")"
assert_contains "monitor script launched detached" "$CALLS" "detach -- bash $R/scripts/monitor-enterprise-e2e-matrix.sh"
assert_contains "watch script launched detached" "$CALLS" "detach -- bash $R/scripts/watch-enterprise-e2e-tui.sh"
assert_contains "mcp env prepared for claude" "$CALLS" "mcp-env $APP"
assert_contains "launch banner" "$TL_OUT" "--- Launching interactive matrix (live) ---"
assert_contains "monitor tail hint" "$TL_OUT" "Monitor: tail -f $TL_TMP/monitor-status.txt"
assert_contains "watch findings hint" "$TL_OUT" "Watch findings: tail -f $TL_TMP/findings.jsonl"
assert_contains "matrix launched with rows from SB root" "$CALLS" "matrix args=[3 6] pwd=$R dry=unset skipexp=0 clean=0 force= forceall= fixture=$APP ledger=$LEDGER"
assert_contains "matrix output teed to the log" "$(cat "$LOG")" "MATRIX-OUTPUT"
assert_contains "gate checklist printed" "$TL_OUT" "--- Round gate checklist (manual before release) ---"
assert_contains "checklist item" "$TL_OUT" "[ ] 22/22 PASS in ledger with graphify + agentmemory refs"
assert_not_contains "no resume message with explicit rows" "$TL_OUT" "Resume rows"
assert_file_absent "lock released after run" "$TL_TMP/live.lock"
assert_not_contains "consecutive rounds not required by default" "$CALLS" "consecutive-rounds.sh"

# FORCE flags are forwarded; matrix failure propagates (tee pipeline under pipefail)
run env SB_E2E_MATRIX_FORCE=1 SB_E2E_MATRIX_FORCE_ALL=1 bash "$LIVE" 1
assert_contains "force flags forwarded" "$CALLS" "force=1 forceall=1"
run env F2_FAIL_STEP=matrix bash "$LIVE" 1
assert_eq "matrix failure propagates" "7" "$TL_STATUS"

# an existing monitor/watch instance is replaced
run env F2_PGREP_HIT=1 bash "$LIVE" 2
assert_contains "monitor replaced" "$TL_OUT" "matrix-monitor: replacing existing instance (driver-owned harness)"
assert_contains "watch replaced" "$TL_OUT" "tui-watch: replacing existing instance (driver-owned harness)"
assert_contains "pkill used for monitor" "$CALLS" "pkill -f monitor-enterprise-e2e-matrix.sh"
assert_contains "pkill used for watch" "$CALLS" "pkill -f watch-enterprise-e2e-tui.sh"

# monitor disabled
run env SB_E2E_MATRIX_MONITOR=0 bash "$LIVE" 2
assert_contains "monitor skipped message" "$TL_OUT" "matrix-monitor: skipped (SB_E2E_MATRIX_MONITOR=0)"
assert_not_contains "no background launch when monitor disabled" "$CALLS" "detach"

# non-claude host: no mcp env, rows exported to children via SB_E2E_MATRIX_ROWS
run bash "$LIVE" --host codex 4 5
assert_not_contains "no mcp env prep for codex" "$CALLS" "mcp-env"
assert_contains "codex matrix launched" "$CALLS" "matrix args=[4 5]"

# ------------------------------------------------------------------ resume logic
mk_ledger 1 2 3
run bash "$LIVE"
assert_eq "no-arg run with incomplete ledger rows" "0" "$TL_STATUS"
assert_contains "resume announced" "$TL_OUT" "Resume rows (ledger-incomplete): 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20"
assert_contains "matrix gets incomplete rows" "$CALLS" "matrix args=[4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]"

run bash "$LIVE" --resume
assert_contains "--resume with incomplete rows resumes" "$TL_OUT" "Resume rows (ledger-incomplete): 4 5"

mk_ledger 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
run bash "$LIVE" --resume
assert_eq "complete ledger exits 0" "0" "$TL_STATUS"
assert_contains "nothing to resume" "$TL_OUT" "All rows Pass in ledger — nothing to resume."
assert_contains "force hint" "$TL_OUT" "Set SB_E2E_MATRIX_FORCE=1 or pass explicit row numbers to re-run."
assert_not_contains "matrix not started when nothing to resume" "$CALLS" "matrix args"
assert_file_absent "lock released when nothing to resume" "$TL_TMP/live.lock"

# without --resume and with all rows passing the whole matrix is launched (no row filter)
run bash "$LIVE"
assert_eq "no resume needed run exit" "0" "$TL_STATUS"
assert_contains "matrix launched without rows" "$CALLS" "matrix args=[] pwd=$R"

# matrix log is created when missing (resume path)
rm -f "$LOG"
mk_ledger 1
run bash "$LIVE"
assert_file_exists "matrix log created" "$LOG"

# ------------------------------------------------------------------ overlay gate switches
run env SB_E2E_VALIDATION_OVERLAY=0 bash "$LIVE" 1
assert_not_contains "overlay disabled" "$TL_OUT" "Validation overlay pre-matrix gate"
assert_not_contains "overlay not run" "$CALLS" "validation-overlay"
run env SB_E2E_VALIDATION_OVERLAY=0 SB_E2E_VALIDATION_PRE_GATE=1 bash "$LIVE" 1
assert_contains "pre-gate forces the overlay" "$CALLS" "validation-overlay.sh --dry-run"
run env F2_FAIL_STEP=scripts/run-enterprise-e2e-validation-overlay.sh bash "$LIVE" 1
assert_eq "overlay failure exits 1" "1" "$TL_STATUS"
assert_contains "overlay failure message" "$TL_ERR" "ERROR: validation overlay pre-matrix gate failed — fix before launching matrix"
assert_contains "overlay failure hint" "$TL_ERR" "(skip: SB_E2E_VALIDATION_OVERLAY=0; force: SB_E2E_VALIDATION_PRE_GATE=1)"
assert_not_contains "matrix not launched after overlay failure" "$CALLS" "matrix args"
assert_file_absent "lock released after overlay failure" "$TL_TMP/live.lock"

# ------------------------------------------------------------------ consecutive rounds gate
run env SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1 bash "$LIVE" 1
assert_eq "consecutive rounds pass" "0" "$TL_STATUS"
assert_contains "consecutive header" "$TL_OUT" "--- Consecutive strict-clean round pair (P2 harness) ---"
assert_contains "consecutive check for host" "$CALLS" "scripts/enterprise-e2e/lib/deterministic/consecutive-rounds.sh --host claude"
run env SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1 F2_FAIL_STEP=scripts/enterprise-e2e/lib/deterministic/consecutive-rounds.sh bash "$LIVE" 1
assert_eq "consecutive rounds failure exits 1" "1" "$TL_STATUS"
assert_contains "consecutive failure message" "$TL_ERR" "consecutive strict-clean round pair check failed (SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1)"
assert_not_contains "no checklist after failed rounds check" "$TL_OUT" "Round gate checklist"

tl_results

#!/usr/bin/env bash
# Behaviour tests for scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh. The driver process
# lookup (pgrep) is stubbed and the script runs from a staged tree so row logs stay in a temp dir.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

STAGE="$TL_TMP/stage"
e2e_stage_scripts "$STAGE"
SCRIPT="$STAGE/scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh"
APP="$TL_TMP/app"
e2e_git_app "$APP"
git -C "$APP" checkout -q -b enterprise-e2e/round-9-codex
APP_SHA="$(git -C "$APP" rev-parse --short HEAD)"
DEAD_PID="$(bash -c 'echo $$')"
FULL="$TL_TMP/full.md"
mapfile -t FULL_SPECS < <(e2e_all_pass_specs 22)
e2e_mk_ledger "$FULL" "${FULL_SPECS[@]}"
PART="$TL_TMP/part.md"
e2e_mk_ledger "$PART" 1:Pass 2:Pass 3:Fail
NOREF="$TL_TMP/noref.md"
{
  echo "| # | WF slug | Pass/Fail |"
  echo "|---|---|---|"
  for n in $(seq 1 22); do echo "| $n | wf | Pass |"; done
  echo "**Pass count: 22**"
} >"$NOREF"

tl_stub pgrep 'if [[ -n "${PGREP_OUT:-}" ]]; then printf "%s\n" $PGREP_OUT; exit 0; fi; exit 1'
COMMON=(-u SB_E2E_CHECKPOINT_DRIVER_PID -u SB_E2E_CHECKPOINT_EXIT_REASON -u SB_E2E_CHECKPOINT_LAST_ROW -u SB_E2E_TEST_APP_BASELINE_SHA
  -u SB_E2E_LIVE_RUNTIME -u SB_E2E_TEST_APP_ROUND -u PGREP_OUT "SILVER_BULLET_RUNTIME=claude"
  "SB_TEST_ENTERPRISE_APP_ROOT=$APP" "SB_E2E_TEST_APP_BRANCH=enterprise-e2e/round-9-codex")
cp_run() {  # cp_run ARGS... -- ENV...   (ARGS before --, env after)
  local args=()
  while [[ "${1:-}" != "--" ]]; do
    args+=("$1")
    shift
  done
  shift
  _e2e_split_env "${COMMON[@]}" "$@"
  tl_run env "${E2E_ENV_ARGS[@]}" bash "$SCRIPT" ${args[@]+"${args[@]}"}
}

# --- argument handling -------------------------------------------------------
cp_run -h -- "SB_E2E_LEDGER_FILE=$FULL"
assert_eq "help exits 0" 0 "$TL_STATUS"
assert_eq "help text" "Usage: enterprise-e2e-checkpoint.sh [--append LEDGER.md]" "$TL_OUT"
cp_run --help -- "SB_E2E_LEDGER_FILE=$FULL"
assert_contains "long help" "$TL_OUT" "Usage:"
cp_run --bogus -- "SB_E2E_LEDGER_FILE=$FULL"
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument message" "$TL_ERR" "Unknown arg: --bogus"

# --- block content: complete ledger, driver alive ----------------------------
cp_run -- "SB_E2E_LEDGER_FILE=$FULL" "SB_E2E_CHECKPOINT_DRIVER_PID=$$" "SB_E2E_CHECKPOINT_LAST_ROW=7"
assert_eq "complete run exits 0" 0 "$TL_STATUS"
assert_match "block heading has a UTC timestamp" '## Poll checkpoint [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$TL_OUT"
assert_contains "driver pid from env, alive" "$TL_OUT" "| Driver PID | **$$** — **ALIVE** |"
assert_contains "no exit reason while alive" "$TL_OUT" "| Exit reason | — |"
assert_contains "complete ledger finishes the batch" "$TL_OUT" "| Batch DONE | **YES** |"
assert_contains "ledger pass count and reconcile status" "$TL_OUT" "| Ledger pass | **22/22** (reconcile: COMPLETE) |"
assert_contains "test-app have/want" "$TL_OUT" "| Test-app | \`enterprise-e2e/round-9-codex@$APP_SHA\` — want \`enterprise-e2e/round-9-codex@8482e60\` |"
assert_contains "last row from env" "$TL_OUT" "| Last row ~ | 7 |"
assert_contains "all rows passed: gate C" "$TL_OUT" "| Methodology gate | C |"
assert_contains "poll-only reminder" "$TL_OUT" "While driver alive:** poll-only"

# --- driver discovery -----------------------------------------------------------
cp_run -- "SB_E2E_LEDGER_FILE=$PART" "SB_E2E_CHECKPOINT_DRIVER_PID=$DEAD_PID" "PGREP_OUT=$$ 99999999"
assert_contains "dead env pid falls back to pgrep (first match)" "$TL_OUT" "| Driver PID | **$$** — **ALIVE** |"
cp_run -- "SB_E2E_LEDGER_FILE=$PART"
assert_contains "no driver found" "$TL_OUT" "| Driver PID | **none** — **DEAD** |"
assert_contains "dead driver is reported as driver_exit" "$TL_OUT" "| Exit reason | driver_exit |"
cp_run -- "SB_E2E_LEDGER_FILE=$PART" "SB_E2E_CHECKPOINT_EXIT_REASON=quota stop"
assert_contains "explicit exit reason wins" "$TL_OUT" "| Exit reason | quota stop |"
cp_run -- "SB_E2E_LEDGER_FILE=$PART" "SB_E2E_CHECKPOINT_DRIVER_PID=$$" "SB_E2E_CHECKPOINT_EXIT_REASON=manual"
assert_contains "explicit exit reason with a live driver" "$TL_OUT" "| Exit reason | manual |"
cp_run -- "SB_E2E_LEDGER_FILE=$PART" "PGREP_OUT=$DEAD_PID"
assert_contains "pgrep pid that is not running is DEAD" "$TL_OUT" "**$DEAD_PID** — **DEAD**"

# --- batch / gate classification ------------------------------------------------
cp_run -- "SB_E2E_LEDGER_FILE=$PART" "SB_E2E_CHECKPOINT_DRIVER_PID=$$"
assert_contains "partial ledger: batch not done" "$TL_OUT" "| Batch DONE | **NO** |"
assert_contains "partial ledger: pass count" "$TL_OUT" "| Ledger pass | **2/22** (reconcile: STALE) |"
assert_contains "partial ledger: gate B-in-progress" "$TL_OUT" "| Methodology gate | B-in-progress |"
cp_run -- "SB_E2E_LEDGER_FILE=$TL_TMP/absent.md" "SB_E2E_CHECKPOINT_DRIVER_PID=$$"
assert_contains "missing ledger: zero passes" "$TL_OUT" "| Ledger pass | **0/22** (reconcile: UNREADABLE) |"
assert_contains "missing ledger: gate A" "$TL_OUT" "| Methodology gate | A |"
cp_run -- "SB_E2E_LEDGER_FILE=$NOREF" "SB_E2E_CHECKPOINT_DRIVER_PID=$$"
assert_contains "22 passes but not reconciled, driver alive: not done" "$TL_OUT" "| Batch DONE | **NO** |"
cp_run -- "SB_E2E_LEDGER_FILE=$NOREF"
assert_contains "22 passes, driver dead: done even if unreconciled" "$TL_OUT" "| Batch DONE | **YES** |"
assert_contains "unreconciled 22 passes still gate C" "$TL_OUT" "| Methodology gate | C |"

# --- last row discovery from row logs --------------------------------------------
touch "$STAGE/.e2e-row3-attempt.log" "$STAGE/.e2e-row11-attempt.log"
cp_run -- "SB_E2E_LEDGER_FILE=$PART"
assert_contains "last row is the highest row with an attempt log" "$TL_OUT" "| Last row ~ | 11 |"
rm -f "$STAGE/.e2e-row3-attempt.log" "$STAGE/.e2e-row11-attempt.log"
cp_run -- "SB_E2E_LEDGER_FILE=$PART"
assert_contains "no attempt logs: unknown row" "$TL_OUT" "| Last row ~ | ? |"

# --- test-app facts -----------------------------------------------------------------
echo '{"hosts": {}}' >"$TL_TMP/no-hosts.json"
cp_run -- "SB_E2E_LEDGER_FILE=$PART" "SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/no-such-app" "SB_E2E_TEST_APP_BRANCH=" "SB_E2E_HOSTS_CONFIG=$TL_TMP/no-hosts.json" "SB_E2E_TEST_APP_BASELINE_SHA=abc1234"
assert_contains "missing app: detached/unknown, baseline from env" "$TL_OUT" "| Test-app | \`detached@unknown\` — want \`unset@abc1234\` |"

# --- --append ---------------------------------------------------------------------------
OUT_LEDGER="$TL_TMP/deep/dir/LEDGER.md"
cp_run --append "$OUT_LEDGER" -- "SB_E2E_LEDGER_FILE=$FULL" "SB_E2E_CHECKPOINT_DRIVER_PID=$$"
assert_eq "append exits 0" 0 "$TL_STATUS"
assert_contains "append announces the target" "$TL_OUT" "Appended checkpoint to $OUT_LEDGER"
assert_file_exists "append creates missing directories" "$OUT_LEDGER"
assert_contains "appended file holds the block" "$(cat "$OUT_LEDGER")" "| Ledger pass | **22/22** (reconcile: COMPLETE) |"
cp_run --append "$OUT_LEDGER" -- "SB_E2E_LEDGER_FILE=$PART" "SB_E2E_CHECKPOINT_DRIVER_PID=$$"
assert_eq "a second append keeps both blocks" "2" "$(grep -c '^## Poll checkpoint' "$OUT_LEDGER")"

tl_results

#!/usr/bin/env bash
# Behaviour tests for scripts/enterprise-e2e-rcs.sh (Release Confidence Score). The script runs
# from a staged tree with stubbed claims-audit and consecutive-rounds checks.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

STAGE="$TL_TMP/stage"
e2e_stage_scripts "$STAGE"
SCRIPT="$STAGE/scripts/enterprise-e2e-rcs.sh"
e2e_stage_override "$STAGE" scripts/claims-audit.sh 'echo "claims-audit rtk=${RTK_DISABLED:-}" >>"${CLAIMS_LOG:-/dev/null}"; exit "${CLAIMS_RC:-0}"'
e2e_stage_override "$STAGE" scripts/lib/enterprise-e2e-consecutive-rounds-check.sh 'echo "consecutive args=$*" >>"${CONSEC_LOG:-/dev/null}"; exit "${CONSEC_RC:-0}"'
mkdir -p "$STAGE/tests/enterprise-e2e-live" "$STAGE/tests/tui-contract"
touch "$STAGE/tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh" "$STAGE/tests/tui-contract/test-bypass-disclaimer.sh"

FULL="$TL_TMP/full.md"
mapfile -t SPECS < <(e2e_all_pass_specs 22)
e2e_mk_ledger "$FULL" "${SPECS[@]}"
TWENTY="$TL_TMP/twenty.md"
e2e_mk_ledger "$TWENTY" "${SPECS[@]:0:20}"
TEN="$TL_TMP/ten.md"
{
  mapfile -t TEN_SPECS < <(e2e_all_pass_specs 10)
  e2e_mk_ledger "$TEN" "${TEN_SPECS[@]}" 11:Fail 12:Fail 13:Fail 14:Fail 15:Fail 16:Fail 17:Fail 18:Fail 19:Fail 20:Fail 21:Fail 22:Fail
}

NOISE=(-u SB_E2E_RCS_RUN_ALL_TESTS -u SB_E2E_RCS_LADDER -u SB_E2E_RCS_VALIDATION_OVERLAY -u SB_E2E_RCS_TRIHOST -u SB_E2E_LEDGER_FILE
  -u SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS -u SB_E2E_LIVE_RUNTIME -u CLAIMS_RC -u CONSEC_RC)
rcs() {  # rcs ARGS... -- ENV...
  local args=()
  while [[ "${1:-}" != "--" ]]; do
    args+=("$1")
    shift
  done
  shift
  _e2e_split_env "${NOISE[@]}" "$@"
  tl_run env "${E2E_ENV_ARGS[@]}" bash "$SCRIPT" ${args[@]+"${args[@]}"}
}
BEST=("SB_E2E_RCS_RUN_ALL_TESTS=pass" "SB_E2E_RCS_LADDER=8/8" "SB_E2E_RCS_TRIHOST=full" "SB_E2E_RCS_VALIDATION_OVERLAY=pass")

# --- CLI ---------------------------------------------------------------------
rcs -h --
assert_eq "help exits 0" 0 "$TL_STATUS"
assert_contains "help mentions the pass threshold" "$TL_OUT" "Pass threshold for release consideration: RCS >= 85"
assert_contains "help documents --ledger" "$TL_OUT" "--ledger PATH"
rcs --nope --
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument message" "$TL_ERR" "Unknown arg: --nope"
rcs --ledger --
assert_eq "--ledger without a value exits 2" 2 "$TL_STATUS"
assert_contains "--ledger message" "$TL_ERR" "Missing value for --ledger"

# --- perfect score -----------------------------------------------------------
rcs --ledger "$FULL" -- "${BEST[@]}"
assert_eq "a perfect run passes" 0 "$TL_STATUS"
assert_contains "total" "$TL_OUT" "Release Confidence Score: 100/100"
assert_contains "run-all component" "$TL_OUT" "run-all-tests:        20/20"
assert_contains "structural component" "$TL_OUT" "structural/contract:  15/15"
assert_contains "ladder component" "$TL_OUT" "ladder:               15/15"
assert_contains "matrix component" "$TL_OUT" "matrix ledger:        25/25 (22/22 pass, reconcile=COMPLETE)"
assert_contains "claims component" "$TL_OUT" "claims audit:         15/15 (validation overlay 5/5 advisory)"
assert_contains "tri-host component" "$TL_OUT" "tri-host smoke:       10/10"

# --- JSON ----------------------------------------------------------------------
rcs --json --ledger "$FULL" -- "${BEST[@]}"
assert_eq "json total" "100" "$(jq -r .rcs <<<"$TL_OUT")"
assert_eq "json components" '{"run_all_tests":20,"structural_contract":15,"ladder":15,"matrix_ledger":25,"claims_audit":15,"tri_host_smoke":10,"validation_overlay":5}' "$(jq -c .components <<<"$TL_OUT")"
assert_eq "json ledger pass" "22/22" "$(jq -r .ledger_pass <<<"$TL_OUT")"
assert_eq "json reconcile status" "COMPLETE" "$(jq -r .ledger_reconcile <<<"$TL_OUT")"
assert_eq "json mode has no human summary" "0" "$(grep -c 'Release Confidence Score' <<<"$TL_OUT" || true)"

# --- defaults: nothing known -----------------------------------------------------
rcs -- "CLAIMS_RC=1"
assert_eq "an empty run fails the threshold" 1 "$TL_STATUS"
assert_contains "default run-all is 10" "$TL_OUT" "run-all-tests:        10/20"
assert_contains "default ladder is 8" "$TL_OUT" "ladder:               8/15"
assert_contains "missing default ledger scores 0 (UNREADABLE)" "$TL_OUT" "matrix ledger:        0/25 (0/22 pass, reconcile=UNREADABLE)"
assert_contains "failed claims get only the advisory overlay points" "$TL_OUT" "claims audit:         2/15 (validation overlay 2/5 advisory)"
assert_contains "default tri-host is 3" "$TL_OUT" "tri-host smoke:       3/10"
assert_contains "total of the defaults" "$TL_OUT" "Release Confidence Score: 38/100"

# default ledger location and env override
mkdir -p "$STAGE/.planning/enterprise-e2e"
cp "$FULL" "$STAGE/.planning/enterprise-e2e/ROUND-1-LEDGER.md"
rcs -- "CLAIMS_RC=1"
assert_contains "default ledger is ROUND-1-LEDGER.md under SB_ROOT" "$TL_OUT" "matrix ledger:        25/25 (22/22 pass, reconcile=COMPLETE)"
rcs -- "SB_E2E_LEDGER_FILE=$TWENTY" "CLAIMS_RC=1"
assert_contains "SB_E2E_LEDGER_FILE is honoured" "$TL_OUT" "(20/22 pass"

# --- matrix scoring -----------------------------------------------------------
rcs --ledger "$TWENTY" -- "${BEST[@]}"
assert_contains "20 passes: 20 points, reconcile penalty 80% -> 16" "$TL_OUT" "matrix ledger:        16/25 (20/22 pass, reconcile=STALE)"
rcs --ledger "$TEN" -- "${BEST[@]}"
assert_contains "10 passes: proportional 11 points, penalised to 8" "$TL_OUT" "matrix ledger:        8/25 (10/22 pass, reconcile=LEDGER_MISMATCH)"

# --- ladder -------------------------------------------------------------------
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_LADDER=4/8"
assert_contains "partial ladder is proportional" "$TL_OUT" "ladder:               7/15"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_LADDER=garbage"
assert_contains "unparseable ladder gets the default" "$TL_OUT" "ladder:               8/15"

# --- run-all / trihost ----------------------------------------------------------
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_RUN_ALL_TESTS=fail"
assert_contains "failed run-all scores 0" "$TL_OUT" "run-all-tests:        0/20"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_TRIHOST=partial"
assert_contains "partial tri-host" "$TL_OUT" "tri-host smoke:       5/10"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_TRIHOST=claude-only"
assert_contains "claude-only tri-host" "$TL_OUT" "tri-host smoke:       3/10"

# --- claims / validation overlay -------------------------------------------------
rcs --ledger "$FULL" -- "${BEST[@]}" "CLAIMS_RC=1"
assert_contains "failed audit with a passing overlay: 5 points" "$TL_OUT" "claims audit:         5/15 (validation overlay 5/5 advisory)"
rcs --ledger "$FULL" -- "${BEST[@]}" "CLAIMS_RC=1" "SB_E2E_RCS_VALIDATION_OVERLAY=fail"
assert_contains "failed audit with a failed overlay: 0 points" "$TL_OUT" "claims audit:         0/15 (validation overlay 0/5 advisory)"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_VALIDATION_OVERLAY=fail"
assert_contains "passing audit is unaffected by a failed overlay" "$TL_OUT" "claims audit:         15/15 (validation overlay 0/5 advisory)"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_VALIDATION_OVERLAY=unknown" "CLAIMS_LOG=$TL_TMP/claims.log"
assert_contains "passing audit is capped at 15" "$TL_OUT" "claims audit:         15/15 (validation overlay 2/5 advisory)"
assert_contains "the audit runs with RTK disabled" "$(cat "$TL_TMP/claims.log")" "claims-audit rtk=1"

# --- structural files ----------------------------------------------------------------
mv "$STAGE/tests/tui-contract/test-bypass-disclaimer.sh" "$TL_TMP/hold.sh"
rcs --ledger "$FULL" -- "${BEST[@]}"
assert_contains "a missing structural test costs the 15 points" "$TL_OUT" "structural/contract:  0/15"
assert_contains "…leaving exactly the pass threshold" "$TL_OUT" "Release Confidence Score: 85/100"
assert_eq "a score of exactly 85 passes" 0 "$TL_STATUS"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_RCS_TRIHOST=partial"
assert_contains "just under the threshold" "$TL_OUT" "Release Confidence Score: 80/100"
assert_eq "a score of 80 fails" 1 "$TL_STATUS"
mv "$TL_TMP/hold.sh" "$STAGE/tests/tui-contract/test-bypass-disclaimer.sh"

# --- consecutive strict-clean rounds gate ------------------------------------------------
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1" "CONSEC_LOG=$TL_TMP/consec.log"
assert_eq "consecutive gate satisfied" 0 "$TL_STATUS"
assert_eq "consecutive check defaults to the claude host" "consecutive args=--host claude" "$(cat "$TL_TMP/consec.log")"
rm -f "$TL_TMP/consec.log"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1" "SB_E2E_LIVE_RUNTIME=codex" "CONSEC_LOG=$TL_TMP/consec.log"
assert_eq "consecutive check receives the live host" "consecutive args=--host codex" "$(cat "$TL_TMP/consec.log")"
rcs --ledger "$FULL" -- "${BEST[@]}" "SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1" "CONSEC_RC=1"
assert_eq "an unmet consecutive gate blocks the release" 1 "$TL_STATUS"
assert_contains "block message" "$TL_ERR" "RCS blocked: consecutive strict-clean round pair not satisfied (SB_E2E_REQUIRE_CONSECUTIVE_ROUNDS=1)"
rcs --ledger "$FULL" -- "${BEST[@]}" "CONSEC_RC=1"
assert_eq "the consecutive gate is opt-in" 0 "$TL_STATUS"

tl_results

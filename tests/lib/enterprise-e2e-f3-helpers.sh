# shellcheck shell=bash
# Helpers for the enterprise E2E outcome-assessment library tests (package F-enterprise-3).
# Source after testlib.sh, enterprise-e2e-helpers.sh and tl_init.

OA_LIB="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-outcome-assessment.sh"
OA_ROOT="$TL_TMP/oa-sbroot"
mkdir -p "$OA_ROOT"

# Every env switch the library reads, unset unless a test sets it.
OA_BASE_ENV=()
for _v in SB_E2E_ENTERPRISE_MATRIX SB_E2E_OUTCOME_ASSESS_FIXTURE SB_E2E_OUTCOME_SCORE_MATRIX \
  SB_TEST_ENTERPRISE_APP_ROOT SB_TRI_CRITERIA_RUN_DIR SB_TRI_CRITERIA_SESSION_LOG \
  SB_E2E_MATRIX_GRAPHIFY_REF SB_E2E_LEDGER_FILE SB_E2E_REVIEW_LADDER_LEDGER SB_E2E_OUTCOME_REGISTRY \
  SB_TRI_CRITERIA_MIN_WORKFLOW_IDS SB_RUNTIME_STATE_DIR; do
  OA_BASE_ENV+=(-u "$_v")
done
unset _v
OA_BASE_ENV+=("SB_ROOT=$OA_ROOT")

# oa [ENV-ARG...] -- FUNCTION [ARGS...]: run a library function in a fresh bash (errexit on).
oa() {
  local envs=()
  while [[ "${1:-}" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  e2e_call "$OA_LIB" "${OA_BASE_ENV[@]}" ${envs[@]+"${envs[@]}"} -- "$@"
}

# oa_sh BODY [ENV-ARG...]: run a bash snippet with the library sourced.
oa_sh() {
  local body="$1"
  shift
  e2e_script "source '$OA_LIB'; $body" "${OA_BASE_ENV[@]}" "$@"
}

# oa_registry FILE JSON: write a registry fixture and echo the path.
oa_registry() {
  printf '%s\n' "$2" >"$1"
}

# oa_log FILE LINE...: write a row log with one LINE per argument.
oa_log() {
  local f="$1"
  shift
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$@" >"$f"
}

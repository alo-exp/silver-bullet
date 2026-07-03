#!/usr/bin/env bash
# Strict-clean eligibility checker — harness truth vs release strict-clean.
#
# Fails when:
#   - SB_E2E_SURFACE_SKIP=1 (install surface bypass)
#   - Ledger Pass rows lack outcome assessment pass (evidence-only / ledger-only)
#   - Ledger reconcile != COMPLETE for 22/22
#
# Usage:
#   bash scripts/enterprise-e2e/strict-clean-check.sh
#   bash scripts/enterprise-e2e/strict-clean-check.sh --ledger path/to/ROUND-N-LEDGER.md
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_ROOT
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"
# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"

LEDGER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledger) LEDGER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--ledger PATH]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$LEDGER" ]] && export SB_E2E_LEDGER_FILE="$LEDGER"
LEDGER="$(enterprise_e2e_ledger_file_path)"

FAILURES=()
record_fail() { FAILURES+=("$1"); }

echo "Strict-clean check — ledger=${LEDGER}"

if [[ "${SB_E2E_SURFACE_SKIP:-}" == "1" ]]; then
  record_fail "SB_E2E_SURFACE_SKIP=1 — install surface bypassed (OUT-SURFACE-01 / D16)"
fi

if [[ ! -f "$LEDGER" ]]; then
  record_fail "ledger missing: ${LEDGER}"
  printf '%s\n' "${FAILURES[@]}" >&2
  exit 1
fi

reconcile_status="$(enterprise_e2e_ledger_reconcile_status)"
read -r pass_count total_count _ < <(enterprise_e2e_ledger_pass_summary "$ledger")

echo "Ledger reconcile status: ${reconcile_status}"
echo "Ledger Pass rows: ${pass_count:-0}/${total_count:-0}"

if [[ "$reconcile_status" != "COMPLETE" ]]; then
  record_fail "ledger not COMPLETE — got ${reconcile_status} (${pass_count:-0}/22 Pass with refs)"
fi

fixture="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
state_dir="${SB_ROOT}/.planning/enterprise-e2e"
outcome_pass=0

while read -r row status; do
  [[ -z "$row" ]] && continue
  [[ "$status" == "pass" ]] || continue
  row_log="${SB_ROOT}/.e2e-row${row}-attempt.log"
  [[ -f "$row_log" ]] || row_log=""
  if enterprise_e2e_outcome_row_passes "$row" "$fixture" "$state_dir" "$row_log" "$LEDGER" "" 2>/dev/null; then
    outcome_pass=$((outcome_pass + 1))
  else
    record_fail "row ${row} ledger Pass but outcome assessment FAIL (evidence-only / scorer drift)"
  fi
done < <(enterprise_e2e_ledger_matrix_rows "$LEDGER")

echo "Outcome strict-clean rows: ${outcome_pass}/22"

registry_pass=0
if declare -f enterprise_e2e_row_pass_registry_pass_count >/dev/null 2>&1; then
  registry_pass="$(enterprise_e2e_row_pass_registry_pass_count)"
  install_fp="$(enterprise_e2e_install_fingerprint)"
  echo "Install-version registry: ${registry_pass}/22 (install_fp=${install_fp})"
  if [[ "${registry_pass:-0}" -lt 22 ]]; then
    record_fail "install-version registry incomplete — ${registry_pass:-0}/22 rows passed @ ${install_fp}"
  fi
fi

if [[ "${pass_count:-0}" -lt 22 ]]; then
  record_fail "matrix incomplete — ${pass_count:-0}/22 ledger Pass"
fi

if [[ "$outcome_pass" -lt 22 ]]; then
  record_fail "outcome incomplete — ${outcome_pass}/22 strict-clean rows"
fi

if [[ "${#FAILURES[@]}" -gt 0 ]]; then
  echo ""
  echo "NOT STRICT-CLEAN:" >&2
  printf '  - %s\n' "${FAILURES[@]}" >&2
  exit 1
fi

echo ""
echo "STRICT-CLEAN ELIGIBLE — ledger 22/22 + outcome 22/22 + install registry 22/22 + no surface skip"
exit 0

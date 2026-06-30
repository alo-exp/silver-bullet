#!/usr/bin/env bash
# sb-doctor.sh — Silver Bullet install + project activation audit (silver:doctor)
# Exit 0 only when zero FAIL checks (WARN allowed).
#
# Check modules: scripts/lib/sb-doctor/checks.sh implements D1-D17.
# D8 orchestrator rule when runtime is cursor. D13 cross-host plugin path contamination.
# hooks/lib/runtime-paths.sh is sourced from checks.sh.
#
# Usage:
#   bash scripts/sb-doctor.sh [PROJECT_ROOT]
#   bash scripts/sb-doctor.sh --fix [PROJECT_ROOT]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"

_sb_doctor_lib="${REPO_ROOT}/scripts/lib/sb-doctor"
for _mod in core fix checks summary; do
  # shellcheck source=/dev/null
  source "${_sb_doctor_lib}/${_mod}.sh"
done

main() {
  parse_args "$@"
  run_doctor_checks
  if [[ "$DOCTOR_FIX_APPLIED" -eq 1 ]]; then
    [[ "$FORMAT" != "json" ]] && echo && echo "sb-doctor: re-running checks after --fix"
    # shellcheck disable=SC2034
    PASS=0
    FAIL=0
    # shellcheck disable=SC2034
    WARN=0
    # shellcheck disable=SC2034
    REPORT_LINES=()
    # shellcheck disable=SC2034
    FAILED_CHECK_IDS=()
    run_doctor_checks
  fi
  doctor_print_summary
  [[ "$FAIL" -eq 0 ]]
}

main "$@"

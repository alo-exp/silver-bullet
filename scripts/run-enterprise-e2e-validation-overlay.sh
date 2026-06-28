#!/usr/bin/env bash
# Enterprise E2E validation overlay — user-outcome / claims layer ON TOP of 22-row matrix.
#
# Does NOT start or stop matrix drivers. Safe to run alongside active matrix (e.g. PID 7484).
#
# Usage:
#   RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh
#   SB_E2E_VALIDATION_OVERLAY=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
#   SB_E2E_VALIDATION_OVERLAY=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --json
#   SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-3-LEDGER.md bash scripts/run-enterprise-e2e-validation-overlay.sh
#
# Environment:
#   SB_E2E_VALIDATION_OVERLAY=1   Opt-in marker (set automatically by this script)
#   SB_E2E_VALIDATION_OVERLAY_DRY_RUN=1   Structural + contract only (default for CI)
#   SB_E2E_LEDGER_FILE              Optional ledger for matrix-row claim overlay
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_ROOT
export SB_RTK_COMPAT_MODE=verbatim
export SB_E2E_VALIDATION_OVERLAY=1

JSON_OUT=0
DRY_RUN="${SB_E2E_VALIDATION_OVERLAY_DRY_RUN:-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --live) DRY_RUN=0; shift ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help)
      cat <<'EOF'
Enterprise E2E validation overlay — homepage + help center claims vs product behavior.

Runs structural/contract checks by default (--dry-run). Does not invoke Claude TUI.
Safe alongside an active matrix driver; does not pkill or touch matrix PIDs.

Options:
  --dry-run   Structural + contract checks only (default)
  --live      Include matrix-row claim overlay from ledger (still no TUI)
  --json      Machine-readable summary

See docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

export SB_E2E_VALIDATION_OVERLAY_DRY_RUN="$DRY_RUN"

# shellcheck source=scripts/lib/enterprise-e2e-validation-overlay.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-validation-overlay.sh"
# shellcheck source=scripts/lib/enterprise-e2e-token-telemetry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-token-telemetry.sh"

VALIDATION_OVERLAY_PASS=0
VALIDATION_OVERLAY_FAIL=0
VALIDATION_OVERLAY_SKIP=0

echo "=== Enterprise E2E Validation Overlay ==="
echo "SB_ROOT=${SB_ROOT}"
echo "mode=$([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo live-overlay)"
echo ""

validation_overlay_check_registry "$SB_ROOT"
validation_overlay_check_apo_catalog_counts "$SB_ROOT"
validation_overlay_check_help_version_sync "$SB_ROOT"
validation_overlay_check_help_workflow_coverage "$SB_ROOT"
validation_overlay_check_help_catalog_sot "$SB_ROOT"
validation_overlay_check_help_tri_host "$SB_ROOT"
validation_overlay_check_tri_host_install "$SB_ROOT"
validation_overlay_check_hook_surface "$SB_ROOT"
validation_overlay_check_sb_diagnostics "$SB_ROOT"
validation_overlay_check_claims_audit "$SB_ROOT"
validation_overlay_check_apo_invariants "$SB_ROOT"

if [[ "$DRY_RUN" == 0 ]]; then
  validation_overlay_matrix_row_claims "$SB_ROOT"
fi

total=$((VALIDATION_OVERLAY_PASS + VALIDATION_OVERLAY_FAIL + VALIDATION_OVERLAY_SKIP))
echo ""
echo "Validation overlay: ${VALIDATION_OVERLAY_PASS} passed, ${VALIDATION_OVERLAY_FAIL} failed, ${VALIDATION_OVERLAY_SKIP} skipped (${total} checks)"

if [[ "$JSON_OUT" -eq 1 ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --argjson pass "$VALIDATION_OVERLAY_PASS" \
      --argjson fail "$VALIDATION_OVERLAY_FAIL" \
      --argjson skip "$VALIDATION_OVERLAY_SKIP" \
      --arg mode "$([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo live-overlay)" \
      '{pass: $pass, fail: $fail, skip: $skip, mode: $mode, overlay: "SB_E2E_VALIDATION_OVERLAY=1"}'
  fi
fi

enterprise_e2e_telemetry_append "validation_overlay"

[[ "$VALIDATION_OVERLAY_FAIL" -eq 0 ]]

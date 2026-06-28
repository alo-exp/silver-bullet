#!/usr/bin/env bash
# Enterprise E2E pre-release overlay — feature-level claims (install, catalog, hooks, tri-host).
#
# Does NOT start or stop matrix drivers. Safe alongside active matrix (e.g. PID 7484).
#
# Usage:
#   RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh
#   RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --with-tri-host-smoke
#   SB_E2E_LEDGER_FILE=.planning/enterprise-e2e/ROUND-3-LEDGER.md bash scripts/run-enterprise-e2e-pre-release-overlay.sh --live
#
# Environment:
#   SB_E2E_PRE_RELEASE_OVERLAY=1   Opt-in marker (set automatically)
#   SB_E2E_LEDGER_FILE             Optional ledger for matrix row 1 feature claims
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SB_ROOT
export SB_RTK_COMPAT_MODE=verbatim
export SB_E2E_PRE_RELEASE_OVERLAY=1

DRY_RUN="${SB_E2E_PRE_RELEASE_OVERLAY_DRY_RUN:-1}"
WITH_TRI_HOST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --live) DRY_RUN=0; shift ;;
    --with-tri-host-smoke) WITH_TRI_HOST=1; shift ;;
    -h|--help)
      cat <<'EOF'
Enterprise E2E pre-release overlay — feature-level homepage/help claims.

Runs structural/contract checks for catalog counts, hooks, install scripts, help
coverage, and optional tri-host install smoke. Feature claims are NOT in the
validation overlay (see docs/testing/pre-release-claims-registry.json).

Options:
  --dry-run              Structural + contract only (default)
  --live                 Include matrix row 1 feature claim overlay from ledger
  --with-tri-host-smoke  Also run scripts/run-tri-host-install-smoke.sh

See docs/testing/ENTERPRISE-E2E-VALIDATION-PLAN.md
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

export SB_E2E_PRE_RELEASE_OVERLAY_DRY_RUN="$DRY_RUN"

# shellcheck source=scripts/lib/enterprise-e2e-pre-release-overlay.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-pre-release-overlay.sh"

VALIDATION_OVERLAY_PASS=0
VALIDATION_OVERLAY_FAIL=0
VALIDATION_OVERLAY_SKIP=0

echo "=== Enterprise E2E Pre-Release Overlay ==="
echo "SB_ROOT=${SB_ROOT}"
echo "mode=$([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo live-overlay)"
echo ""

pre_release_overlay_run_feature_checks "$SB_ROOT"
pre_release_overlay_check_router_help_page "$SB_ROOT"

if [[ "$DRY_RUN" == 0 ]]; then
  pre_release_overlay_matrix_row_claims "$SB_ROOT"
fi

if [[ "$WITH_TRI_HOST" -eq 1 ]]; then
  echo ""
  echo "--- Tri-host install smoke ---"
  if RTK_DISABLED=1 bash "${SB_ROOT}/scripts/run-tri-host-install-smoke.sh"; then
    pre_release_overlay_pass "tri-host install smoke green"
  else
    pre_release_overlay_fail "tri-host install smoke failed"
  fi
fi

total=$((VALIDATION_OVERLAY_PASS + VALIDATION_OVERLAY_FAIL + VALIDATION_OVERLAY_SKIP))
echo ""
echo "Pre-release overlay: ${VALIDATION_OVERLAY_PASS} passed, ${VALIDATION_OVERLAY_FAIL} failed, ${VALIDATION_OVERLAY_SKIP} skipped (${total} checks)"

[[ "$VALIDATION_OVERLAY_FAIL" -eq 0 ]]

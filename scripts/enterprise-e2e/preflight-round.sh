#!/usr/bin/env bash
# Gate 0+1 preflight before live enterprise E2E matrix.
#
# Gate 0 — Install contracts: validate-host-install-surface (OUT-SURFACE-01 / D16)
# Gate 1 — Harness structural: offline suite subset, outcome harness, test-app branch, dry-run matrix
#
# Usage:
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/preflight-round.sh
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/preflight-round.sh --harness-only
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/preflight-round.sh --host cursor
#
# Environment:
#   SB_E2E_LIVE_RUNTIME          claude | codex | cursor (default: claude)
#   SB_E2E_PREFLIGHT_SKIP_SURFACE=1   Skip Gate 0 install surface (harness-only bring-up)
#   SB_E2E_SURFACE_SKIP=1        Anti-pattern for live — strict-clean-check fails if set
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_ROOT
export SB_RTK_COMPAT_MODE=verbatim
# shellcheck source=hooks/lib/rtk-compat.sh
source "${SB_ROOT}/hooks/lib/rtk-compat.sh"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=scripts/enterprise-e2e/lib/host.sh
source "${SB_ROOT}/scripts/enterprise-e2e/lib/host.sh"
# shellcheck source=scripts/enterprise-e2e/lib/test-app-branch.sh
source "${SB_ROOT}/scripts/enterprise-e2e/lib/test-app-branch.sh"

HOST="$(enterprise_e2e_matrix_host)"
HARNESS_ONLY=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--harness-only] [--host claude|codex|cursor]

Gate 0: install contracts (surface + tri-host smoke)
Gate 1: harness structural (offline suite, outcome, test-app branch, dry-run matrix)

See docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --harness-only) HARNESS_ONLY=1; shift ;;
    --host)
      export SB_E2E_LIVE_RUNTIME="${2:-}"
      export SILVER_BULLET_RUNTIME="${2:-}"
      HOST="$(enterprise_e2e_matrix_host)"
      shift 2
      ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "${SB_E2E_SURFACE_SKIP:-}" == "1" ]]; then
  echo "WARN: SB_E2E_SURFACE_SKIP=1 — install surface bypassed (not strict-clean eligible)" >&2
fi

run_step() {
  local label="$1"
  shift
  echo ""
  echo "=== ${label} ==="
  "$@"
}

echo "Enterprise E2E preflight — host=${HOST} harness_only=${HARNESS_ONLY}"

# --- Gate 0: Install contracts ---
if [[ "$HARNESS_ONLY" != "1" && "${SB_E2E_PREFLIGHT_SKIP_SURFACE:-0}" != "1" && "${SB_E2E_SURFACE_SKIP:-}" != "1" ]]; then
  run_step "Gate 0: validate-host-install-surface (D16 / OUT-SURFACE-01)" \
    bash "${SB_ROOT}/scripts/validate-host-install-surface.sh" --repo-root "$SB_ROOT" --host "$HOST"
  run_step "Gate 0: tri-host install smoke" \
    bash "${SB_ROOT}/scripts/run-tri-host-install-smoke.sh" --host "$HOST"
  # install-claude prune removes host-bundles/ — restore before Gate 1 structural checks
  run_step "Gate 0: sync host-bundles after install smoke" \
    bash "${SB_ROOT}/scripts/sync-codex-package.sh"
else
  echo "Gate 0: SKIPPED (--harness-only or SB_E2E_PREFLIGHT_SKIP_SURFACE=1 or SB_E2E_SURFACE_SKIP=1)"
fi

# --- Gate 1: Harness structural ---
run_step "Gate 1: enterprise E2E live structural suite" \
  bash "${SB_ROOT}/tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh"

run_step "Gate 1: outcome assessment harness" \
  bash "${SB_ROOT}/tests/scripts/test-outcome-assessment.sh"

if [[ -f "${SB_ROOT}/tests/scripts/test-enterprise-e2e-test-app-branch.sh" ]]; then
  run_step "Gate 1: test-app branch structural" \
    bash "${SB_ROOT}/tests/scripts/test-enterprise-e2e-test-app-branch.sh"
fi

if [[ -f "${SB_ROOT}/tests/scripts/test-validate-host-install-surface.sh" ]]; then
  run_step "Gate 1: validate-host-install-surface structural" \
    bash "${SB_ROOT}/tests/scripts/test-validate-host-install-surface.sh"
fi

if [[ "$HARNESS_ONLY" == "1" ]]; then
  echo "Gate 1: test-app branch assert skipped (--harness-only; structural test already ran)"
else
  run_step "Gate 1: test-app branch assert (before driver)" \
    enterprise_e2e_assert_test_app_branch
fi

run_step "Gate 1: dry-run matrix" \
  env SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME="$HOST" SILVER_BULLET_RUNTIME="$HOST" \
    bash "${SB_ROOT}/scripts/run-enterprise-e2e-matrix.sh"

run_step "Gate 1: host live preflight" \
  bash "${SB_ROOT}/scripts/run-enterprise-e2e-live-test.sh" --preflight-only

echo ""
echo "PREFLIGHT OK — Gate 0+1 green for host=${HOST}"

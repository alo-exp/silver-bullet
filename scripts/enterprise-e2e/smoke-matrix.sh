#!/usr/bin/env bash
# Tier B live smoke matrix — rows 1, 3, 6, 11, 21, 22.
#
# Runs Gate 0+1 preflight, pins test-app branch, then invokes live matrix subset.
#
# Usage:
#   SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=1 bash scripts/enterprise-e2e/smoke-matrix.sh
#   SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=1 bash scripts/enterprise-e2e/smoke-matrix.sh --harness-only
#
# See docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md §3 Tier B
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_ROOT

SMOKE_ROWS=(1 3 6 11 21 22)
HARNESS_ONLY=0
PREFLIGHT_ARGS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [--harness-only] [--host claude|codex|cursor]

Smoke rows: ${SMOKE_ROWS[*]}

Requires SB_ENTERPRISE_E2E_LIVE=1 unless --harness-only (preflight only).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --harness-only) HARNESS_ONLY=1; PREFLIGHT_ARGS+=(--harness-only); shift ;;
    --host) PREFLIGHT_ARGS+=(--host "$2"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

HOST="${SB_E2E_LIVE_RUNTIME:-${SILVER_BULLET_RUNTIME:-claude}}"

echo "=== Enterprise E2E smoke matrix (rows ${SMOKE_ROWS[*]}) host=${HOST} ==="

bash "${SB_ROOT}/scripts/enterprise-e2e/preflight-round.sh" "${PREFLIGHT_ARGS[@]}"

if [[ "$HARNESS_ONLY" == "1" ]]; then
  echo "Smoke matrix: harness-only — live rows skipped"
  exit 0
fi

if [[ "${SB_ENTERPRISE_E2E_LIVE:-}" != "1" ]]; then
  echo "ERROR: set SB_ENTERPRISE_E2E_LIVE=1 for live smoke rows" >&2
  exit 2
fi

if [[ "${SB_E2E_SURFACE_SKIP:-}" == "1" ]]; then
  echo "ERROR: SB_E2E_SURFACE_SKIP=1 — smoke live requires install surface (use --harness-only for structural only)" >&2
  exit 2
fi

export SB_E2E_LIVE_RUNTIME="$HOST"
export SILVER_BULLET_RUNTIME="$HOST"
export RTK_DISABLED="${RTK_DISABLED:-1}"

echo ""
echo "=== Live smoke rows ${SMOKE_ROWS[*]} ==="
exec bash "${SB_ROOT}/scripts/run-enterprise-e2e-matrix.sh" "${SMOKE_ROWS[@]}"

#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

assert_ok() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: $desc"
    ((PASS++)) || true
  else
    echo "FAIL: $desc"
    ((FAIL++)) || true
  fi
}

script_body="$(cat "${REPO_ROOT}/scripts/enterprise-e2e/matrix.sh")"

if grep -qF 'matrix_force_rerun()' <<<"$script_body"; then
  echo "PASS: matrix defines matrix_force_rerun helper"
  ((PASS++)) || true
else
  echo "FAIL: matrix defines matrix_force_rerun helper"
  ((FAIL++)) || true
fi

if grep -qF 'SB_E2E_MATRIX_FORCE_ALL' <<<"$script_body"; then
  echo "PASS: matrix documents SB_E2E_MATRIX_FORCE_ALL"
  ((PASS++)) || true
else
  echo "FAIL: matrix documents SB_E2E_MATRIX_FORCE_ALL"
  ((FAIL++)) || true
fi

if grep -qF 'if ! matrix_force_rerun && verify_row_success' <<<"$script_body"; then
  echo "PASS: skip gate uses matrix_force_rerun"
  ((PASS++)) || true
else
  echo "FAIL: skip gate uses matrix_force_rerun"
  ((FAIL++)) || true
fi

if grep -qF "trap \"rm -f '\$_matrix_batch_pid_file'; cleanup_workspace\" EXIT" <<<"$script_body"; then
  echo "PASS: batch pid EXIT trap captures path at registration"
  ((PASS++)) || true
else
  echo "FAIL: batch pid EXIT trap captures path at registration"
  ((FAIL++)) || true
fi

# Behavioral check via extracted helper (avoid sourcing matrix.sh main)
matrix_force_rerun() {
  [[ "${SB_E2E_MATRIX_FORCE:-}" == "1" || "${SB_E2E_MATRIX_FORCE_ALL:-}" == "1" ]]
}
unset SB_E2E_MATRIX_FORCE SB_E2E_MATRIX_FORCE_ALL
  if ! matrix_force_rerun; then
    echo "PASS: matrix_force_rerun false when unset"
    ((PASS++)) || true
  else
    echo "FAIL: matrix_force_rerun false when unset"
    ((FAIL++)) || true
  fi
  export SB_E2E_MATRIX_FORCE_ALL=1
  if matrix_force_rerun; then
    echo "PASS: matrix_force_rerun true for FORCE_ALL=1"
    ((PASS++)) || true
  else
    echo "FAIL: matrix_force_rerun true for FORCE_ALL=1"
    ((FAIL++)) || true
  fi
  unset SB_E2E_MATRIX_FORCE_ALL
  export SB_E2E_MATRIX_FORCE=1
  if matrix_force_rerun; then
    echo "PASS: matrix_force_rerun true for FORCE=1"
    ((PASS++)) || true
  else
    echo "FAIL: matrix_force_rerun true for FORCE=1"
  ((FAIL++)) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

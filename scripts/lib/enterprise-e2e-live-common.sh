#!/usr/bin/env bash
# Shared helpers for enterprise E2E live test operator runs.
# Sourced by scripts/run-enterprise-e2e-live-test.sh and tests/enterprise-e2e-live/*.
set -euo pipefail

enterprise_e2e_sb_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

enterprise_e2e_fixture_dir() {
  printf '%s\n' "${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
}

enterprise_e2e_matrix_log() {
  printf '%s\n' "${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-live.log}"
}

enterprise_e2e_ledger_file() {
  printf '%s\n' "${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-1-LEDGER.md}"
}

# Rows 1-20 explicit; 21-22 are internal (verified via parent rows).
enterprise_e2e_all_row_nums() {
  printf '%s\n' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
}

enterprise_e2e_row_complete_in_log() {
  local row="$1" log="$2"
  [[ -f "$log" ]] || return 1
  awk -v target="$row" '
    /^=== Row [0-9]+:/ {
      if (cur == target && (pass || skip)) { done = 1 }
      cur = $3
      sub(/:$/, "", cur)
      pass = 0
      skip = 0
    }
    cur == target && /^  PASS:/ { pass = 1 }
    cur == target && /^  SKIP:/ { skip = 1 }
    cur == target && /^  DRY RUN PASS/ { pass = 1 }
    cur == target && /^  FAIL:/ { pass = 0; skip = 0 }
    END { exit (done || pass || skip) ? 0 : 1 }
  ' "$log"
}

# Resume from first incomplete row after last PASS/SKIP — never restart at row 1.
enterprise_e2e_incomplete_rows() {
  local log="$1" row out=()
  for row in $(enterprise_e2e_all_row_nums); do
    if ! enterprise_e2e_row_complete_in_log "$row" "$log"; then
      out+=("$row")
    fi
  done
  if ((${#out[@]} > 0)); then
    printf '%s\n' "${out[@]}"
  fi
}

enterprise_e2e_assert_no_auth_mutations() {
  local script="$1"
  if grep -qE 'claude auth (login|logout)|claude /logout|setup-token|/login|/logout' "$script" 2>/dev/null; then
    echo "ERROR: $script must not invoke login/logout (API key auth only)" >&2
    return 1
  fi
  return 0
}

enterprise_e2e_export_live_defaults() {
  export SB_E2E_MATRIX_CLEAN_ENV="${SB_E2E_MATRIX_CLEAN_ENV:-0}"
  export SB_E2E_MATRIX_DRY_RUN="${SB_E2E_MATRIX_DRY_RUN:-}"
  unset SB_E2E_MATRIX_DRY_RUN 2>/dev/null || true
  export SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL="${SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL:-600}"
  export SB_E2E_WORKFLOW_QUIET_TIMEOUT="${SB_E2E_WORKFLOW_QUIET_TIMEOUT:-600}"
  export CLAUDE_MODEL="${CLAUDE_MODEL:-haiku}"
  export SILVER_BULLET_RUNTIME=claude
  export SB_E2E_LIVE_RUNTIME=claude
}
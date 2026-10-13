#!/usr/bin/env bash
# Emit unified enterprise E2E monitor checkpoint markdown block.
#
# Usage:
#   bash scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh
#   bash scripts/enterprise-e2e/enterprise-e2e-checkpoint.sh --append .planning/enterprise-e2e/ROUND-8-LEDGER.md
#
# Environment (optional overrides):
#   SB_E2E_CHECKPOINT_DRIVER_PID
#   SB_E2E_CHECKPOINT_EXIT_REASON
#   SB_E2E_CHECKPOINT_LAST_ROW
#   SB_E2E_LEDGER_FILE
#   SB_E2E_TEST_APP_BRANCH
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_ROOT
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
# shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"

APPEND_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --append) APPEND_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--append LEDGER.md]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

discover_driver_pid() {
  local pid="${SB_E2E_CHECKPOINT_DRIVER_PID:-}"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    printf '%s\n' "$pid"
    return 0
  fi
  pid="$(pgrep -f 'run-enterprise-e2e-matrix\.sh' 2>/dev/null | head -1 || true)"
  [[ -n "$pid" ]] && printf '%s\n' "$pid" || printf '%s\n' "none"
}

driver_pid="$(discover_driver_pid)"
driver_status="DEAD"
if [[ "$driver_pid" != "none" ]] && kill -0 "$driver_pid" 2>/dev/null; then
  driver_status="ALIVE"
fi

ledger="$(enterprise_e2e_ledger_file_path)"
reconcile_status="$(enterprise_e2e_ledger_reconcile_status 2>/dev/null || echo UNKNOWN)"
read -r pass_count total_count _ < <(enterprise_e2e_ledger_pass_summary "$ledger" 2>/dev/null || echo "0 0")

fixture_dir="$(enterprise_e2e_fixture_dir)"
have_branch="$(git -C "$fixture_dir" branch --show-current 2>/dev/null || echo detached)"
have_sha="$(git -C "$fixture_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
want_branch="$(enterprise_e2e_test_app_expected_branch 2>/dev/null || echo unset)"
want_sha="$(enterprise_e2e_test_app_default_baseline_sha)"

batch_done="NO"
if [[ "$reconcile_status" == "COMPLETE" ]]; then
  batch_done="YES"
elif [[ "$driver_status" == "DEAD" && "$pass_count" -ge 22 ]]; then
  batch_done="YES"
fi

last_row="${SB_E2E_CHECKPOINT_LAST_ROW:-}"
if [[ -z "$last_row" ]]; then
  for n in $(seq 22 -1 1); do
    row_log="$(enterprise_e2e_row_attempt_log "$n" 2>/dev/null || true)"
    if [[ -n "$row_log" && -f "$row_log" ]]; then
      last_row="$n"
      break
    fi
  done
fi
[[ -n "$last_row" ]] || last_row="?"

exit_reason="${SB_E2E_CHECKPOINT_EXIT_REASON:-}"
if [[ -z "$exit_reason" && "$driver_status" == "DEAD" ]]; then
  exit_reason="driver_exit"
fi

methodology_gate="B"
if [[ "$pass_count" -ge 22 ]]; then
  methodology_gate="C"
elif [[ "$pass_count" -gt 0 ]]; then
  methodology_gate="B-in-progress"
else
  methodology_gate="A"
fi

block="$(cat <<EOF
## Poll checkpoint $(utc_now)

| Field | Value |
|-------|-------|
| Driver PID | **${driver_pid}** — **${driver_status}** |
| Exit reason | ${exit_reason:-—} |
| Batch DONE | **${batch_done}** |
| Ledger pass | **${pass_count}/22** (reconcile: ${reconcile_status}) |
| Test-app | \`${have_branch}@${have_sha}\` — want \`${want_branch}@${want_sha}\` |
| Last row ~ | ${last_row} |
| Methodology gate | ${methodology_gate} |

**While driver alive:** poll-only; no duplicate FORCE; do not kill healthy driver (<45m mid-row).

EOF
)"

printf '%s\n' "$block"

if [[ -n "$APPEND_FILE" ]]; then
  mkdir -p "$(dirname "$APPEND_FILE")"
  printf '\n%s\n' "$block" >>"$APPEND_FILE"
  echo "Appended checkpoint to ${APPEND_FILE}"
fi

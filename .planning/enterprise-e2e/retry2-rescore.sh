#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export SB_ROOT="$PWD"
export SB_E2E_ENTERPRISE_MATRIX=1
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_RUNTIME=cursor
# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source scripts/lib/enterprise-e2e-outcome-assessment.sh
# shellcheck source=scripts/enterprise-e2e/lib/host.sh
source scripts/enterprise-e2e/lib/host.sh

FIXTURE="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
export SB_TEST_ENTERPRISE_APP_ROOT="$FIXTURE"
LEDGER=".planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md"
STATE="$(enterprise_e2e_runtime_state_dir)"
OUTCOME_DIR="${FIXTURE}/.planning/enterprise-e2e/outcomes"
mkdir -p "$OUTCOME_DIR"
pass=0
fail=0

row_log() {
  local r="$1"
  local log="${SB_ROOT}/.e2e-row${r}-cursor-attempt.log"
  if [[ -f "$log" && $(wc -c <"$log") -gt 80 ]]; then
    printf '%s\n' "$log"
    return 0
  fi
  log="${SB_ROOT}/.e2e-row${r}-attempt.log"
  [[ -f "$log" ]] && printf '%s\n' "$log" || printf '\n'
}

row_evidence() {
  enterprise_e2e_outcome_matrix_evidence_path "$1"
}

for r in $(seq 1 20); do
  log="$(row_log "$r")"
  ev="$(row_evidence "$r")"
  if [[ -n "$log" ]] && enterprise_e2e_outcome_row_passes "$r" "$FIXTURE" "$STATE" "$log" "$LEDGER" "$ev"; then
    printf 'row %2d: PASS\n' "$r"
    pass=$((pass + 1))
    enterprise_e2e_outcome_write_workflow_checklist "$r" \
      "${OUTCOME_DIR}/row-${r}-outcomes.md" \
      "$FIXTURE" "$STATE" "$log" "$LEDGER" "$ev" 2>/dev/null || true
  else
    fails="$(enterprise_e2e_outcome_row_failures "$r" "$FIXTURE" "$STATE" "$log" "$LEDGER" "$ev" 2>/dev/null | tr '\n' ' ')"
    printf 'row %2d: FAIL %s\n' "$r" "$fails"
    fail=$((fail + 1))
  fi
done

for r in 21 22; do
  marker=""
  [[ "$r" == "21" ]] && marker='post-exec-gates'
  [[ "$r" == "22" ]] && marker='validate-substep'
  if find "$FIXTURE/.planning/workflows" -name '*.md' -exec grep -l "$marker" {} + 2>/dev/null | grep -q .; then
    printf 'row %2d: PASS (internal)\n' "$r"
    pass=$((pass + 1))
  else
    printf 'row %2d: FAIL (internal missing %s)\n' "$r" "$marker"
    fail=$((fail + 1))
  fi
done

printf '\nTOTAL: %d pass / %d fail (of 22)\n' "$pass" "$fail"

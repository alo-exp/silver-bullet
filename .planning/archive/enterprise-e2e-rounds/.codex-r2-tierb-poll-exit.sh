#!/usr/bin/env bash
# Poll Round Codex-2 Tier B smoke driver until exit; rescore rows 1,3,6 + internal 21,22.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DRIVER_PID="${1:?driver pid required}"
INTERVAL="${2:-75}"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r2-tierb-poll.log"
RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r2-tierb-rescore.log"
MATRIX_LOG="${ROOT}/.e2e-matrix-codex-live.log"
LEDGER="${ROOT}/.planning/enterprise-e2e/ROUND-CODEX-2-LEDGER.md"
CHECKPOINT="${ROOT}/.planning/enterprise-e2e/.codex-r2-tierb-checkpoint.md"

log_line() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$POLL_LOG"
}

run_tierb_rescore() {
  export SB_ROOT="$ROOT"
  export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
  export SILVER_BULLET_RUNTIME=codex
  export SB_E2E_LIVE_RUNTIME=codex
  export SB_E2E_LEDGER_FILE="$LEDGER"
  export SB_E2E_ENTERPRISE_MATRIX=1
  # shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
  source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
  # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
  source "${ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"

  local WORK_DIR="$SB_TEST_ENTERPRISE_APP_ROOT"
  local STATE_DIR row row_log evidence pass=0 fail_rows=()
  STATE_DIR="$(enterprise_e2e_runtime_state_dir)"

  : >"$RESCORE_LOG"
  for row in 1 3 6; do
    case "$row" in
      1) evidence=".planning/workflows/router-session.md" ;;
      3) evidence=".planning/workflows/feature-currency.md" ;;
      6) evidence=".planning/workflows/fast-readme.md" ;;
    esac
    row_log="$(ls -t "${ROOT}/.e2e-row${row}-codex-attempt"*.log 2>/dev/null | head -1 || true)"
    [[ -z "$row_log" ]] && row_log="${ROOT}/.e2e-row${row}-codex-attempt.log"
    if [[ ! -f "$row_log" ]]; then
      printf 'row %d SKIP no log\n' "$row" >>"$RESCORE_LOG"
      continue
    fi
    if enterprise_e2e_outcome_row_passes "$row" "$WORK_DIR" "$STATE_DIR" "$row_log" "$LEDGER" "$evidence"; then
      printf 'row %d PASS\n' "$row" >>"$RESCORE_LOG"
      pass=$((pass + 1))
    else
      local fails=""
      fails="$(enterprise_e2e_outcome_row_failures "$row" "$WORK_DIR" "$STATE_DIR" "$row_log" "$LEDGER" "$evidence" 2>/dev/null | tr '\n' ' ' || true)"
      printf 'row %d FAIL: %s\n' "$row" "$fails" >>"$RESCORE_LOG"
      fail_rows+=("$row")
    fi
  done
  printf 'TIERB_RESCORE pass=%d/3 fail_rows=%s\n' "$pass" "${fail_rows[*]:-none}" >>"$RESCORE_LOG"
  printf '%d\n' "$pass"
}

log_line "POLL-EXIT start driver=${DRIVER_PID} interval=${INTERVAL}s branch=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

while kill -0 "$DRIVER_PID" 2>/dev/null; do
  row="$(strings "$MATRIX_LOG" 2>/dev/null | grep '^=== Row ' | tail -1 || true)"
  child="$(pgrep -P "$DRIVER_PID" 2>/dev/null | head -1 || true)"
  log_line "DRIVER=${DRIVER_PID} RUNNING ${row} child=${child}"
  sleep "$INTERVAL"
done

log_line "DRIVER=${DRIVER_PID} EXIT"
pass_count="$(run_tierb_rescore)"
log_line "TIERB rescore pass=${pass_count}/3 log=${RESCORE_LOG}"

{
  printf '# Round Codex-2 Tier B checkpoint\n\n'
  printf -- '- **When:** %s *(EXIT)*\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- **Branch:** enterprise-e2e/codex @ %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf -- '- **Driver PID:** %s EXITED\n' "$DRIVER_PID"
  printf -- '- **Tier B rescore:** %s/3 — [.codex-r2-tierb-rescore.log](./.codex-r2-tierb-rescore.log)\n' "$pass_count"
} >"$CHECKPOINT"

{
  printf '\n### Poll checkpoint %s (Round Codex-2 Tier B exit)\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '| Field | Value |\n|-------|-------|\n'
  printf '| **Driver** | EXITED PID **%s** |\n' "$DRIVER_PID"
  printf '| **Tier B rescore** | **%s/3** — [.codex-r2-tierb-rescore.log](./.codex-r2-tierb-rescore.log) |\n' "$pass_count"
  if [[ "$pass_count" -eq 3 ]]; then
    printf '| **Tier C** | **READY** — launch [codex-r2-matrix-driver.sh](./codex-r2-matrix-driver.sh) |\n'
  else
    printf '| **Tier C** | **BLOCKED** — fix Tier B failures first |\n'
  fi
} >>"$LEDGER"

log_line "POLL-EXIT done tierb=${pass_count}/3"

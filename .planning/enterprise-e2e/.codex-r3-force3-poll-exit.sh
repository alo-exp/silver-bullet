#!/usr/bin/env bash
# Poll codex-r3-force3 driver until exit; frozen row 1 PASS + rescore rows 3,6 with §5b gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DRIVER_PID="${1:?driver pid required}"
INTERVAL="${2:-75}"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-poll.log"
RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-rescore.log"
TIERB_RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-tierb-rescore.log"
FROZEN_SHA="${SB_E2E_FROZEN_BASELINE_SHA:-4412bb01}"
MATRIX_LOG="${ROOT}/.e2e-matrix-codex-live.log"
LEDGER="${ROOT}/.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md"
CHECKPOINT="${ROOT}/.planning/enterprise-e2e/.codex-r3-force3-checkpoint.md"

log_line() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$POLL_LOG"
}

resume_friction_monitor() {
  export SB_ROOT="$ROOT"
  export SB_E2E_LEDGER_FILE="$LEDGER"
  export SB_E2E_MATRIX_LOG="$MATRIX_LOG"
  export SB_E2E_LEDGER_NO_UX_APPEND=1
  # shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
  source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
  enterprise_e2e_reset_tui_monitor_offsets "$ROOT" || true
  local mon_pid=""
  if [[ -f "${ROOT}/.planning/enterprise-e2e/.tui-monitor-agent-run.pid" ]]; then
    mon_pid="$(tr -d '[:space:]' <"${ROOT}/.planning/enterprise-e2e/.tui-monitor-agent-run.pid")"
  fi
  if [[ -n "$mon_pid" ]] && kill -0 "$mon_pid" 2>/dev/null; then
    log_line "FRICTION monitor already running pid=${mon_pid}"
    return 0
  fi
  mon_pid="$(bash "${ROOT}/.planning/enterprise-e2e/tui-monitor-batch-continuation-launch.sh" | awk '{print $NF}')"
  log_line "FRICTION monitor relaunched pid=${mon_pid}"
}

latest_row_log() {
  local row="$1" f newest=""
  shopt -s nullglob
  local files=("${ROOT}/.e2e-row${row}-codex-attempt.log" "${ROOT}/.e2e-row${row}-codex-attempt"[0-9]*.log)
  for f in "${files[@]}"; do
    if [[ -z "$newest" || "$f" -nt "$newest" ]]; then newest="$f"; fi
  done
  printf '%s\n' "$newest"
}

frozen_row1_passes() {
  if [[ -f "$TIERB_RESCORE_LOG" ]] && grep -qE '^row 1 PASS' "$TIERB_RESCORE_LOG"; then
    return 0
  fi
  local row_log
  row_log="$(latest_row_log 1)"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  export SB_ROOT="$ROOT"
  export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
  export SILVER_BULLET_RUNTIME=codex
  export SB_E2E_LIVE_RUNTIME=codex
  export SB_E2E_LEDGER_FILE="$LEDGER"
  export SB_E2E_ENTERPRISE_MATRIX=1
  export SB_E2E_PRODUCT_WORK_GATE=1
  # shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
  source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
  # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
  source "${ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"
  local STATE_DIR
  STATE_DIR="$(enterprise_e2e_runtime_state_dir)"
  enterprise_e2e_outcome_row_passes 1 "$SB_TEST_ENTERPRISE_APP_ROOT" "$STATE_DIR" \
    "$row_log" "$LEDGER" ".planning/workflows/router-session.md"
}

run_tierb_rescore() {
  export SB_ROOT="$ROOT"
  export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
  export SILVER_BULLET_RUNTIME=codex
  export SB_E2E_LIVE_RUNTIME=codex
  export SB_E2E_LEDGER_FILE="$LEDGER"
  export SB_E2E_ENTERPRISE_MATRIX=1
  export SB_E2E_PRODUCT_WORK_GATE=1
  export SB_E2E_TEST_APP_BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-09f8d1a}"
  export SB_E2E_ROW6_FROZEN_COMMIT="${SB_E2E_ROW6_FROZEN_COMMIT:-b22b730}"
  export SB_E2E_ROW3_PRODUCT_ANCHOR_SHA="${SB_E2E_ROW6_FROZEN_COMMIT}"
  # shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
  source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
  # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
  source "${ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"

  local WORK_DIR="$SB_TEST_ENTERPRISE_APP_ROOT"
  local STATE_DIR row row_log evidence pass=0 fail_rows=()
  STATE_DIR="$(enterprise_e2e_runtime_state_dir)"

  : >"$RESCORE_LOG"
  if frozen_row1_passes; then
    printf 'row 1 PASS (frozen@%s)\n' "$FROZEN_SHA" >>"$RESCORE_LOG"
    pass=$((pass + 1))
  else
    printf 'row 1 FAIL (not frozen)\n' >>"$RESCORE_LOG"
    fail_rows+=(1)
  fi

  for row in 3 6; do
    case "$row" in
      3) evidence=".planning/workflows/feature-currency.md" ;;
      6) evidence=".planning/workflows/fast-readme.md" ;;
    esac
    row_log="$(latest_row_log "$row")"
    if [[ -z "$row_log" || ! -f "$row_log" ]]; then
      printf 'row %d SKIP no log\n' "$row" >>"$RESCORE_LOG"
      fail_rows+=("$row")
      continue
    fi
    if ! enterprise_e2e_assert_row_product_commit_rescore "$row" "$WORK_DIR" >>"$RESCORE_LOG" 2>&1; then
      printf 'row %d FAIL: §5b product commit\n' "$row" >>"$RESCORE_LOG"
      fail_rows+=("$row")
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

log_line "POLL-EXIT start driver=${DRIVER_PID} interval=${INTERVAL}s branch=$(git rev-parse --short HEAD 2>/dev/null || echo unknown) frozen_row1@${FROZEN_SHA}"
resume_friction_monitor

while kill -0 "$DRIVER_PID" 2>/dev/null; do
  row="$(strings "$MATRIX_LOG" 2>/dev/null | grep '^=== Row ' | tail -1 || true)"
  child="$(pgrep -P "$DRIVER_PID" 2>/dev/null | head -1 || true)"
  log_line "DRIVER=${DRIVER_PID} RUNNING ${row:-pending} child=${child:-none}"
  sleep "$INTERVAL"
done

log_line "DRIVER=${DRIVER_PID} EXIT"
pass_count="$(run_tierb_rescore)"
log_line "TIERB rescore pass=${pass_count}/3 log=${RESCORE_LOG}"

{
  printf '# codex-r3-force3 checkpoint\n\n'
  printf -- '- **When:** %s *(EXIT)*\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- **Branch:** enterprise-e2e/codex @ %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf -- '- **Frozen row 1:** PASS @ `%s`\n' "$FROZEN_SHA"
  printf -- '- **Row 6 anchor:** `%s`\n' "${SB_E2E_ROW6_FROZEN_COMMIT:-b22b730}"
  printf -- '- **Driver PID:** %s EXITED\n' "$DRIVER_PID"
  printf -- '- **Tier B rescore:** %s/3 — [.codex-r3-force3-rescore.log](./.codex-r3-force3-rescore.log)\n' "$pass_count"
} >"$CHECKPOINT"

{
  printf '\n### Poll checkpoint %s (force3 exit @ %s)\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf '| Field | Value |\n|-------|-------|\n'
  printf '| **Policy** | One pass — frozen row **1** PASS; FORCE rows **3,6**; row6 outcome-only @ `%s` |\n' "${SB_E2E_ROW6_FROZEN_COMMIT:-b22b730}"
  printf '| **Driver** | EXITED PID **%s** |\n' "$DRIVER_PID"
  printf '| **Tier B rescore** | **%s/3** — [.codex-r3-force3-rescore.log](./.codex-r3-force3-rescore.log) |\n' "$pass_count"
  if [[ "$pass_count" -eq 3 ]]; then
    printf '| **Tier C** | **READY** — launch [codex-r3-matrix-driver.sh](./codex-r3-matrix-driver.sh) |\n'
  else
    printf '| **Tier C** | **BLOCKED** — fix Tier B failures first |\n'
  fi
} >>"$LEDGER"

log_line "POLL-EXIT done tierb=${pass_count}/3"

if [[ "$pass_count" -eq 3 ]]; then
  log_line "TIER_C launching codex-r3-matrix-driver.sh"
  tmux kill-session -t codex-r3-matrix 2>/dev/null || true
  tmux new-session -d -s codex-r3-matrix -c "$ROOT" \
    "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/codex-r3-matrix-driver.sh 2>&1 | tee -a .planning/enterprise-e2e/.codex-r3-matrix-launch.log'"
  sleep 2
  MATRIX_DRIVER_PID="$(tmux list-panes -t codex-r3-matrix -F '#{pane_pid}' | head -1)"
  matrix_cwd="$(lsof -p "$MATRIX_DRIVER_PID" 2>/dev/null | awk '/cwd/ {print $NF}' || true)"
  if [[ "$matrix_cwd" != "$ROOT" ]]; then
    log_line "TIER_C ABORT matrix driver cwd=${matrix_cwd:-unknown} expected=${ROOT}"
  elif kill -0 "$MATRIX_DRIVER_PID" 2>/dev/null; then
    log_line "TIER_C matrix driver=${MATRIX_DRIVER_PID} cwd=${ROOT}"
    tmux new-window -t codex-r3-matrix -n poll -c "$ROOT" \
      "bash -lc 'cd \"$ROOT\" && exec bash .planning/enterprise-e2e/.codex-r3-matrix-poll-exit.sh ${MATRIX_DRIVER_PID} 75'"
    log_line "TIER_C matrix poll-exit launched for driver=${MATRIX_DRIVER_PID}"
  else
    log_line "TIER_C matrix driver failed to start"
  fi
fi

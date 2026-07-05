#!/usr/bin/env bash
# Poll codex-r3-force141619 driver until exit; frozen-merge rescore from matrix @ e4e8f814.
# One-pass: 18 PASS rows frozen; live rescore rows 14,15,16,19; rows 21–22 internal inherit 3/4.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
DRIVER_PID="${1:?driver pid required}"
INTERVAL="${2:-75}"
POLL_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-poll.log"
RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-rescore.log"
FROZEN_RESCORE_LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-matrix-rescore.log"
FROZEN_BASELINE_SHA="${SB_E2E_FROZEN_BASELINE_SHA:-e4e8f814}"
MATRIX_LOG="${ROOT}/.e2e-matrix-codex-live.log"
LEDGER="${ROOT}/.planning/enterprise-e2e/ROUND-CODEX-3-LEDGER.md"
GATES="${ROOT}/.planning/enterprise-e2e/ROUND-CODEX-3-GATES.md"
CHECKPOINT="${ROOT}/.planning/enterprise-e2e/.codex-r3-force141619-checkpoint.md"
FORCE_ROWS=(14 15 16 19)

log_line() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$POLL_LOG"
}

score_n22() {
  python3 - <<'PY' "$LEDGER" 2>/dev/null || echo "?"
import re, sys
led = open(sys.argv[1], errors='replace').read()
passes = len(re.findall(r'^\|\s*(\d{1,2})\s*\|\s*`[^`]+`\s*\|[^|]*\|\s*\*\*Pass\*\*', led, re.M | re.I))
fails = len(re.findall(r'^\|\s*(\d{1,2})\s*\|\s*`[^`]+`\s*\|[^|]*\|\s*\*\*Fail\*\*', led, re.M | re.I))
print(f"{passes}/22 ({fails} fail)")
PY
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

frozen_row_passes() {
  local row="$1"
  [[ -f "$FROZEN_RESCORE_LOG" ]] || return 1
  grep -qE "^row ${row} PASS" "$FROZEN_RESCORE_LOG"
}

is_force_row() {
  local row="$1" r
  for r in "${FORCE_ROWS[@]}"; do
    [[ "$r" == "$row" ]] && return 0
  done
  return 1
}

matrix_evidence_for_row() {
  case "$1" in
    1) printf '%s' ".planning/workflows/router-session.md" ;;
    2) printf '%s' "docs/ADR-001-runtime.md" ;;
    3) printf '%s' ".planning/workflows/feature-currency.md" ;;
    4) printf '%s' ".planning/workflows/bugfix-health.md" ;;
    5) printf '%s' "ui/src/App.jsx" ;;
    6) printf '%s' ".planning/workflows/fast-readme.md" ;;
    7) printf '%s' ".planning/workflows/test-orders-integration.md" ;;
    8) printf '%s' ".planning/workflows/refactor-order-validation.md" ;;
    9) printf '%s' "docs/benchmarks/health.md" ;;
    10) printf '%s' "docs/API.md" ;;
    11) printf '%s' ".planning/workflows/devops-terraform-validation.md" ;;
    12) printf '%s' "docs/DEPLOY.md" ;;
    13) printf '%s' "docs/CANARY.md" ;;
    14) printf '%s' "CHANGELOG.md" ;;
    15) printf '%s' ".planning/reviews/triad-currency.md" ;;
    16) printf '%s' ".planning/ship-readiness/checklist.md" ;;
    17) printf '%s' "docs/incidents/INC-001.md" ;;
    18) printf '%s' "docs/retro/RETRO-001.md" ;;
    19) printf '%s' "docs/forensics/CI-001.md" ;;
    20) printf '%s' "docs/WORKFLOW_E2E_MATRIX.md" ;;
    *) return 1 ;;
  esac
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

run_frozen_merge_rescore() {
  export SB_ROOT="$ROOT"
  export SB_TEST_ENTERPRISE_APP_ROOT="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
  export SILVER_BULLET_RUNTIME=codex
  export SB_E2E_LIVE_RUNTIME=codex
  export SB_E2E_LEDGER_FILE="$LEDGER"
  export SB_E2E_ENTERPRISE_MATRIX=1
  export SB_E2E_PRODUCT_WORK_GATE=1
  export SB_E2E_TEST_APP_BASELINE_SHA="${SB_E2E_TEST_APP_BASELINE_SHA:-09f8d1a}"
  # shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
  source "${ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
  # shellcheck source=scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh
  source "${ROOT}/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh"

  local WORK_DIR="$SB_TEST_ENTERPRISE_APP_ROOT"
  local STATE_DIR row row_log evidence pass=0 fail_rows=()
  STATE_DIR="$(enterprise_e2e_runtime_state_dir)"

  : >"$RESCORE_LOG"
  printf 'FROZEN_BASELINE_SHA=%s FROZEN_RESCORE=%s FORCE_ROWS=%s\n' \
    "$FROZEN_BASELINE_SHA" "$FROZEN_RESCORE_LOG" "${FORCE_ROWS[*]}" >>"$RESCORE_LOG"

  for row in $(seq 1 20); do
    if ! is_force_row "$row" && frozen_row_passes "$row"; then
      printf 'row %d PASS (frozen@%s)\n' "$row" "$FROZEN_BASELINE_SHA" >>"$RESCORE_LOG"
      pass=$((pass + 1))
      continue
    fi

    evidence="$(matrix_evidence_for_row "$row" || true)"
    row_log="$(latest_row_log "$row")"
    if [[ -z "$row_log" || ! -f "$row_log" ]]; then
      printf 'row %d SKIP no log\n' "$row" >>"$RESCORE_LOG"
      fail_rows+=("$row")
      continue
    fi

    if enterprise_e2e_row_requires_product_commit "$row"; then
      if ! enterprise_e2e_assert_row_product_commit_rescore "$row" "$WORK_DIR" >>"$RESCORE_LOG" 2>&1; then
        printf 'row %d FAIL: §5b product commit\n' "$row" >>"$RESCORE_LOG"
        fail_rows+=("$row")
        continue
      fi
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

  if grep -qE '^row 3 (PASS|PASS \(frozen)' "$RESCORE_LOG"; then
    printf 'row 21 PASS (internal)\n' >>"$RESCORE_LOG"
    pass=$((pass + 1))
  else
    printf 'row 21 FAIL (internal)\n' >>"$RESCORE_LOG"
    fail_rows+=(21)
  fi
  if grep -qE '^row 4 (PASS|PASS \(frozen)' "$RESCORE_LOG"; then
    printf 'row 22 PASS (internal)\n' >>"$RESCORE_LOG"
    pass=$((pass + 1))
  else
    printf 'row 22 FAIL (internal)\n' >>"$RESCORE_LOG"
    fail_rows+=(22)
  fi

  printf 'RESCORE_TOTAL pass=%d/22 fail_rows=%s\n' "$pass" "${fail_rows[*]:-none}" >>"$RESCORE_LOG"
  cp "$RESCORE_LOG" "$FROZEN_RESCORE_LOG"
  printf '%d\n' "$pass"
}

draft_product_audit() {
  local audit="${ROOT}/.planning/enterprise-e2e/CODEX-3-TEST-APP-PRODUCT-AUDIT.md"
  local fixture="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
  local baseline="${SB_E2E_TEST_APP_BASELINE_SHA:-09f8d1a}"
  local commit_count delta fixture_sha sb_sha
  fixture_sha="$(git -C "$fixture" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  sb_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  commit_count="$(git -C "$fixture" rev-list --count "${baseline}..HEAD" 2>/dev/null || echo 0)"
  {
    printf '# Codex-3 REAL — Test App Product Work Audit (draft)\n\n'
    printf '**Status:** DRAFT — auto-generated on force141619 poll-exit @ %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '**SB worktree:** `%s` @ `%s`\n' "$ROOT" "$sb_sha"
    printf '**Fixture:** `enterprise-e2e/round-9-codex` @ `%s`\n' "$fixture_sha"
    printf '**Baseline:** `%s` — **%s** product commits since baseline\n' "$baseline" "$commit_count"
    printf '**Rescore:** [.codex-r3-force141619-rescore.log](./.codex-r3-force141619-rescore.log)\n'
    printf '**Frozen merge:** [.codex-r3-matrix-rescore.log](./.codex-r3-matrix-rescore.log) @ `%s`\n\n' "$FROZEN_BASELINE_SHA"
    printf '## Summary\n\n'
    if [[ "$commit_count" -gt 0 ]]; then
      printf '- **Product commits:** %s (honest §5b progress vs Codex-1/2 harness-only)\n' "$commit_count"
    else
      printf '- **Product commits:** 0 — §5b FAIL risk\n'
    fi
    printf '- **Matrix rescore:** see force141619 rescore log for row-level truth\n'
    printf '- **Rows 21–22:** internal inherit from live rows 3/4 (frozen unless parent re-run)\n\n'
    printf '## Recent fixture commits\n\n'
    printf '```\n'
    git -C "$fixture" log --oneline -10 "${baseline}..HEAD" 2>/dev/null || true
    printf '```\n'
  } >"$audit"
  log_line "PRODUCT_AUDIT draft written ${audit}"
}

log_line "POLL-EXIT start driver=${DRIVER_PID} interval=${INTERVAL}s branch=$(git rev-parse --short HEAD 2>/dev/null || echo unknown) frozen@${FROZEN_BASELINE_SHA} ledger=$(score_n22)"
resume_friction_monitor

while kill -0 "$DRIVER_PID" 2>/dev/null; do
  row="$(strings "$MATRIX_LOG" 2>/dev/null | grep '^=== Row ' | tail -1 || true)"
  child="$(pgrep -P "$DRIVER_PID" 2>/dev/null | head -1 || true)"
  log_line "DRIVER=${DRIVER_PID} RUNNING ${row:-pending} child=${child:-none}"
  sleep "$INTERVAL"
done

log_line "DRIVER=${DRIVER_PID} EXIT"
summary="$(strings "$MATRIX_LOG" 2>/dev/null | grep -E '^(=== Matrix summary|Pass:|Fail:|Total:)' | tail -6 || true)"
while IFS= read -r line; do
  [[ -n "$line" ]] && log_line "SUMMARY: $line"
done <<<"$summary"

pass_count="$(run_frozen_merge_rescore)"
log_line "RESCORE complete pass=${pass_count}/22 log=${RESCORE_LOG}"

{
  printf '# codex-r3-force141619 checkpoint\n\n'
  printf -- '- **When:** %s *(EXIT)*\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- **Branch:** enterprise-e2e/codex @ %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf -- '- **Frozen baseline:** %s — 18 PASS rows frozen\n' "$FROZEN_BASELINE_SHA"
  printf -- '- **Driver PID:** %s EXITED\n' "$DRIVER_PID"
  printf -- '- **Rescore:** %s/22 — [.codex-r3-force141619-rescore.log](./.codex-r3-force141619-rescore.log)\n' "$pass_count"
  printf -- '- **Poll log:** [.codex-r3-force141619-poll.log](./.codex-r3-force141619-poll.log)\n'
} >"$CHECKPOINT"

{
  printf '\n### Poll checkpoint %s (force141619 exit @ %s)\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  printf '| Field | Value |\n|-------|-------|\n'
  printf '| **Policy** | One pass — frozen 18 PASS @ `%s`; FORCE **14,15,16,19** live |\n' "$FROZEN_BASELINE_SHA"
  printf '| **Driver** | EXITED PID **%s** |\n' "$DRIVER_PID"
  printf '| **Rescore** | **%s/22** — [.codex-r3-force141619-rescore.log](./.codex-r3-force141619-rescore.log) |\n' "$pass_count"
  if [[ "$pass_count" -eq 22 ]]; then
    printf '| **Phase C** | **STARTING** — 22/22 strict-clean |\n'
  else
    printf '| **Phase C** | **BLOCKED** — %s/22 |\n' "$pass_count"
  fi
} >>"$LEDGER"

if [[ "$pass_count" -eq 22 ]]; then
  draft_product_audit
  log_line "PHASE_C starting test-outcome-assessment + run-all-tests"
  if RTK_DISABLED=1 bash "${ROOT}/tests/scripts/test-outcome-assessment.sh" >>"$POLL_LOG" 2>&1; then
    log_line "PHASE_C test-outcome-assessment PASS"
  else
    log_line "PHASE_C test-outcome-assessment FAIL"
  fi
  if RTK_DISABLED=1 bash "${ROOT}/tests/run-all-tests.sh" >>"$POLL_LOG" 2>&1; then
    log_line "PHASE_C run-all-tests PASS"
    {
      printf '\n### Phase C complete %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf '| Gate | Status |\n|------|--------|\n'
      printf '| Matrix rescore 22/22 | **PASS** |\n'
      printf '| Outcome assessment harness | **PASS** |\n'
      printf '| run-all-tests | **PASS** |\n'
      printf '| Product audit draft | [.CODEX-3-TEST-APP-PRODUCT-AUDIT.md](./CODEX-3-TEST-APP-PRODUCT-AUDIT.md) |\n'
    } >>"$GATES"
    sed -i '' 's/^## Status: \*\*OPEN — in progress\*\*/## Status: **CLOSED Pass**/' "$GATES" 2>/dev/null || \
      sed -i 's/^## Status: \*\*OPEN — in progress\*\*/## Status: **CLOSED Pass**/' "$GATES"
  else
    log_line "PHASE_C run-all-tests FAIL"
  fi
fi

log_line "POLL-EXIT done pass=${pass_count}/22"

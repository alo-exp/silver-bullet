#!/usr/bin/env bash
# Append-only token/cost telemetry for enterprise E2E (V-02 analysis — no pass/fail gate).
# Sourced by overlay and matrix harness; does not touch matrix PIDs.
set -euo pipefail

enterprise_e2e_telemetry_file() {
  local root="${1:-${SB_ROOT:-.}}"
  local primary="${root}/.planning/enterprise-e2e/token-telemetry.jsonl"
  local mirror_dir="${root}/docs/testing/telemetry"
  mkdir -p "$(dirname "$primary")" "$mirror_dir"
  printf '%s\n' "$primary"
}

enterprise_e2e_telemetry_extract_row_log_tokens() {
  local log_file="${1:-}"
  [[ -n "$log_file" && -f "$log_file" ]] || return 0
  # TUI footer often shows "NNNNN tokens" — take the max seen in the log.
  local max_tokens
  max_tokens="$(grep -oE '[0-9]{1,9}[[:space:]]+tokens' "$log_file" 2>/dev/null \
    | grep -oE '^[0-9]+' | sort -n | tail -1 || true)"
  [[ -n "$max_tokens" ]] && printf '%s\n' "$max_tokens"
}

enterprise_e2e_telemetry_rtk_snapshot() {
  if ! command -v rtk >/dev/null 2>&1; then
    return 0
  fi
  local raw
  raw="$(RTK_DISABLED=1 rtk stats 2>/dev/null || true)"
  [[ -n "$raw" ]] || return 0
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$raw" | jq -c . 2>/dev/null && return 0
  fi
  printf '%s' "$raw" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g'
}

enterprise_e2e_telemetry_matrix_driver_pid() {
  pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' 2>/dev/null | sort -n | head -1 || true
}

enterprise_e2e_telemetry_append() {
  local root="${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local event_source="${1:-unknown}"
  shift || true

  local telemetry_file row_num row_slug row_result row_log ledger_file model
  local overlay_mode overlay_pass overlay_fail overlay_skip
  local tokens_max rtk_snapshot driver_pid ts record mirror_file

  telemetry_file="$(enterprise_e2e_telemetry_file "$root")"
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  row_num="${SB_E2E_TELEMETRY_ROW:-}"
  row_slug="${SB_E2E_TELEMETRY_ROW_SLUG:-}"
  row_result="${SB_E2E_TELEMETRY_ROW_RESULT:-}"
  row_log="${SB_E2E_TELEMETRY_ROW_LOG:-}"
  ledger_file="${SB_E2E_LEDGER_FILE:-}"
  model="${CLAUDE_MODEL:-${CURSOR_MODEL:-unknown}}"
  overlay_mode="${SB_E2E_VALIDATION_OVERLAY_DRY_RUN:-}"
  overlay_pass="${VALIDATION_OVERLAY_PASS:-}"
  overlay_fail="${VALIDATION_OVERLAY_FAIL:-}"
  overlay_skip="${VALIDATION_OVERLAY_SKIP:-}"
  tokens_max="$(enterprise_e2e_telemetry_extract_row_log_tokens "$row_log")"
  rtk_snapshot="$(enterprise_e2e_telemetry_rtk_snapshot || true)"
  driver_pid="$(enterprise_e2e_telemetry_matrix_driver_pid)"

  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  record="$(jq -nc \
    --arg ts "$ts" \
    --arg event_source "$event_source" \
    --arg sb_root "$root" \
    --arg row_num "$row_num" \
    --arg row_slug "$row_slug" \
    --arg row_result "$row_result" \
    --arg row_log "$row_log" \
    --arg ledger_file "$ledger_file" \
    --arg model "$model" \
    --arg overlay_mode "$([[ "$overlay_mode" == 1 ]] && echo dry-run || echo live-overlay)" \
    --argjson overlay_pass "${overlay_pass:-null}" \
    --argjson overlay_fail "${overlay_fail:-null}" \
    --argjson overlay_skip "${overlay_skip:-null}" \
    --arg tokens_max "${tokens_max:-}" \
    --arg rtk_snapshot "${rtk_snapshot:-}" \
    --arg matrix_driver_pid "${driver_pid:-}" \
    --arg validation_scope "telemetry_only" \
    --arg claim_ref "V-02" \
    '{
      ts: $ts,
      event_source: $event_source,
      sb_root: $sb_root,
      claim_ref: $claim_ref,
      validation_scope: $validation_scope,
      gate: "none",
      row: (if $row_num != "" then {num: ($row_num|tonumber?), slug: $row_slug, result: $row_result, log: $row_log} else null end),
      ledger_file: (if $ledger_file != "" then $ledger_file else null end),
      model: $model,
      tokens: {
        tui_max: (if $tokens_max != "" then ($tokens_max|tonumber) else null end),
        input: null,
        output: null,
        total: null
      },
      overlay: (if $overlay_pass != null then {mode: $overlay_mode, pass: $overlay_pass, fail: $overlay_fail, skip: $overlay_skip} else null end),
      rtk_stats: (if $rtk_snapshot != "" then $rtk_snapshot else null end),
      matrix_driver_pid: (if $matrix_driver_pid != "" then ($matrix_driver_pid|tonumber) else null end),
      notes: "Telemetry only — V-02 10x cost claim excluded from validation gates; fields for later 10x/60x analysis"
    }')"

  printf '%s\n' "$record" >>"$telemetry_file"

  mirror_file="${root}/docs/testing/telemetry/token-telemetry.jsonl"
  printf '%s\n' "$record" >>"$mirror_file"
}

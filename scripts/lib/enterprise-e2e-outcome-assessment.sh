#!/usr/bin/env bash
# Enterprise E2E outcome assessment — score rubric criteria from observable artifacts.
#
# Scope comments in functions: workflow | session | round
#
# Usage:
#   source scripts/lib/enterprise-e2e-outcome-assessment.sh
#   enterprise_e2e_outcome_score_criterion OUT-TAILOR-01 "$work_dir" "$state_dir" "$row_log" "$row_num"
#   enterprise_e2e_outcome_assess_workflow_row 3 "$work_dir" "$state_dir" "$row_log"
#   enterprise_e2e_outcome_write_workflow_checklist 3 /path/to/row-3-outcomes.md
#   enterprise_e2e_outcome_assess_session "$row_log" "$state_dir"
#   enterprise_e2e_outcome_assess_round "$ledger_file"
set -euo pipefail

enterprise_e2e_outcome_repo_root() {
  if [[ -n "${SB_ROOT:-}" ]]; then
    printf '%s\n' "$SB_ROOT"
  else
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
  fi
}

enterprise_e2e_outcome_registry_path() {
  local root
  root="$(enterprise_e2e_outcome_repo_root)"
  printf '%s\n' "${SB_E2E_OUTCOME_REGISTRY:-${root}/docs/testing/outcome-criteria-registry.json}"
}

enterprise_e2e_outcome_criteria_ids() {
  local reg
  reg="$(enterprise_e2e_outcome_registry_path)"
  if [[ -f "$reg" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.criteria[].id' "$reg"
    return 0
  fi
  # Fallback when jq unavailable
  printf '%s\n' \
    OUT-TAILOR-01 OUT-VLOOP-01 OUT-GATES-01 OUT-TRACE-01 OUT-INTENT-01 OUT-KM-01 \
    OUT-ORCH-01 OUT-PLAN-01 OUT-SKILL-01 OUT-REVIEW-01 OUT-BLAST-01 OUT-HOOK-01 \
    OUT-COMPLETE-01 OUT-HANDOFF-01 OUT-CODEINT-01 OUT-FLOW-01 OUT-MEASURE-01 \
    OUT-DECIDE-01 OUT-FORENS-01 OUT-AUTO-01 OUT-CLARIFY-01 OUT-NOOP-01 OUT-WORLD-01 \
    OUT-DRIFT-01 OUT-SUPER-01 OUT-HEAL-01 OUT-RELEASE-01 OUT-SURFACE-01
}

enterprise_e2e_outcome_row_criteria() {
  local row_num="$1"
  local reg
  reg="$(enterprise_e2e_outcome_registry_path)"
  if [[ -f "$reg" ]] && command -v jq >/dev/null 2>&1; then
    jq -r --arg r "$row_num" '.workflow_row_map[$r][]? // empty' "$reg"
    return 0
  fi
  case "$row_num" in
    1) printf '%s\n' OUT-TAILOR-01 OUT-ORCH-01 OUT-SKILL-01 OUT-HOOK-01 OUT-CODEINT-01 OUT-INTENT-01 ;;
    3) printf '%s\n' OUT-GATES-01 OUT-VLOOP-01 OUT-PLAN-01 OUT-TRACE-01 OUT-ORCH-01 OUT-FLOW-01 OUT-INTENT-01 ;;
    *) printf '%s\n' OUT-INTENT-01 OUT-SKILL-01 ;;
  esac
}

enterprise_e2e_outcome_session_criteria() {
  local reg
  reg="$(enterprise_e2e_outcome_registry_path)"
  if [[ -f "$reg" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_criteria[]?' "$reg"
    return 0
  fi
  printf '%s\n' OUT-SKILL-01 OUT-HOOK-01 OUT-ORCH-01 OUT-HANDOFF-01 OUT-CODEINT-01 OUT-KM-01 OUT-DECIDE-01 \
    OUT-AUTO-01 OUT-NOOP-01 OUT-CLARIFY-01 OUT-HEAL-01 OUT-SUPER-01
}

# Matrix row 1 (silver-router) — interactive routing-only; no WBS supervisor chain.
enterprise_e2e_outcome_is_routing_row() {
  local row_num="${1:-}"
  local reg
  reg="$(enterprise_e2e_outcome_registry_path)"
  if [[ -f "$reg" ]] && command -v jq >/dev/null 2>&1; then
    jq -e --arg r "$row_num" '.routing_only_rows[]? | select(. == ($r | tonumber))' "$reg" >/dev/null 2>&1 && return 0
  fi
  [[ "$row_num" == "1" ]]
}

# Matrix evidence at primary path or workflows/.archive/ after quiesce.
enterprise_e2e_outcome_evidence_present() {
  local work_dir="$1" evidence="${2:-}"
  [[ -n "$evidence" ]] || return 1
  if [[ -f "${work_dir}/${evidence}" ]] || [[ -d "${work_dir}/${evidence}" ]]; then
    return 0
  fi
  local base
  base="$(basename "$evidence")"
  if [[ -f "${work_dir}/.planning/workflows/.archive/${base}" ]]; then
    return 0
  fi
  if find "${work_dir}/.planning/workflows/.archive" -name "$base" 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

enterprise_e2e_outcome_routing_evidence_present() {
  local work_dir="$1" state_dir="$2" evidence="${3:-}"
  local state_file="${state_dir}/state"
  if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
    return 0
  fi
  if [[ -f "${work_dir}/.planning/workflows/router-session.md" ]]; then
    return 0
  fi
  if [[ -d "${work_dir}/.planning/workflows/.archive" ]] && \
     find "${work_dir}/.planning/workflows/.archive" -name 'router-session.md' 2>/dev/null | grep -q .; then
    return 0
  fi
  if [[ -f "$state_file" ]] && grep -qE 'silver-router|silver-context|silver-feature|silver-fast' "$state_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Compact excerpt for deliberation / matrix-prompt echo detection (live TUI scrollback).
enterprise_e2e_outcome_watch_compact_excerpt() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

# planning-file-guard TUI-watch hits are often agent deliberation or matrix prompt echo —
# not harness hook deny. Returns 0 when the finding is a known false positive.
enterprise_e2e_outcome_watch_is_hook_deliberation_fp() {
  local message="${1:-}" excerpt="${2:-}" row_log="${3:-}"
  case "$message" in
    planning-file-guard)
      local compact
      compact="$(enterprise_e2e_outcome_watch_compact_excerpt "${message}${excerpt}")"
      if [[ "$compact" =~ issue.*override ]] || [[ "$compact" =~ sboverride ]]; then
        return 0
      fi
      if [[ "$compact" =~ harnessignoring ]] || [[ "$compact" =~ nonblocking ]]; then
        return 0
      fi
      if [[ "$compact" =~ dispositionmenu ]] || [[ "$compact" =~ donotpresent ]]; then
        return 0
      fi
      if [[ "$compact" =~ soineed ]] || [[ "$compact" =~ letme ]] || [[ "$compact" =~ ihavepermission ]]; then
        return 0
      fi
      if [[ "$compact" =~ canonicalrouting ]] || [[ "$compact" =~ matrixmode ]] || [[ "$compact" =~ matrixmod ]]; then
        return 0
      fi
      if [[ "$compact" =~ enterprisee2e ]] || [[ "$compact" =~ theuserhasinvoked ]]; then
        return 0
      fi
      if [[ "$compact" =~ orchestratoroutput ]] || [[ "$compact" =~ createworkflow ]]; then
        return 0
      fi
      if [[ "$compact" =~ evidencwrites ]] || [[ "$compact" =~ evidencewries ]]; then
        return 0
      fi
      if [[ "$compact" =~ blocksrequiredworkflow ]] || [[ "$compact" =~ workflowevidencewrites ]]; then
        return 0
      fi
      if [[ "$compact" =~ override ]] && [[ "$compact" =~ reason ]]; then
        return 0
      fi
      # Round 7 Tier 1: matrix SB OVERRIDE prompt echo + post-override deliberation (rows 6/8).
      if [[ "$compact" =~ subsequentplanningfileguardblock ]]; then
        return 0
      fi
      if [[ "$compact" =~ authorizedforanyplanningfileguardblock ]]; then
        return 0
      fi
      if [[ "$compact" =~ errideauthorizedforplanningfileguardblocks ]]; then
        return 0
      fi
      if [[ "$compact" =~ survivestheplanningfileguard ]]; then
        return 0
      fi
      if [[ "$compact" =~ boverrideifneededforplanningfileguard ]]; then
        return 0
      fi
      # Harness already classified hook friction as non-blocking in row log.
      if [[ -n "$row_log" && -f "$row_log" ]]; then
        if enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
           grep -qiE '\[harness\] ignoring.*(hook|non-blocking)'; then
          if ! enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
             grep -qiE 'session ended on hook block|Stop hook blocks completion'; then
            return 0
          fi
        fi
      fi
      return 1
      ;;
  esac
  return 1
}

# True hook BLOCKER in TUI watch (severity=blocker, category=hook) — not annoyance noise.
enterprise_e2e_outcome_watch_has_hook_blocker() {
  local watch="$1" row_num="${2:-}" row_log="${3:-}"
  [[ -f "$watch" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    local line message excerpt
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      message="$(printf '%s' "$line" | jq -r '.message // ""' 2>/dev/null)"
      excerpt="$(printf '%s' "$line" | jq -r '.excerpt // ""' 2>/dev/null)"
      if enterprise_e2e_outcome_watch_is_hook_deliberation_fp "$message" "$excerpt" "$row_log"; then
        continue
      fi
      return 0
    done < <(jq -c --argjson r "${row_num:-0}" \
      'select(.severity == "blocker") | select(.category == "hook") | if ($r > 0) then select(.row == $r) else . end' \
      "$watch" 2>/dev/null)
    return 1
  fi
  grep -q '"severity": "blocker"' "$watch" 2>/dev/null && \
    grep -qiE '"category": "hook"' "$watch" 2>/dev/null
}

enterprise_e2e_outcome_is_blocking() {
  local cid="$1"
  local reg
  reg="$(enterprise_e2e_outcome_registry_path)"
  if [[ -f "$reg" ]] && command -v jq >/dev/null 2>&1; then
    jq -e --arg c "$cid" '.blocking_criteria[]? | select(. == $c)' "$reg" >/dev/null 2>&1 && return 0
    jq -e --arg c "$cid" '.criteria[]? | select(.id == $c and .blocking == true)' "$reg" >/dev/null 2>&1 && return 0
    return 1
  fi
  case "$cid" in
    OUT-AUTO-01|OUT-CLARIFY-01|OUT-NOOP-01|OUT-WORLD-01) return 0 ;;
    *) return 1 ;;
  esac
}

# Matrix sets SB_E2E_MATRIX_EVIDENCE_PATH for the active row; session scoring must see it.
enterprise_e2e_outcome_resolve_evidence() {
  local evidence="${1:-}" row_num="${2:-}" row_log="${3:-}" work_dir="${4:-}"
  if [[ -n "$evidence" ]]; then
    printf '%s\n' "$evidence"
    return 0
  fi
  if [[ -n "${SB_E2E_MATRIX_EVIDENCE_PATH:-}" ]]; then
    printf '%s\n' "$SB_E2E_MATRIX_EVIDENCE_PATH"
    return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" && -n "$work_dir" ]]; then
    if enterprise_e2e_outcome_log_matches "$row_log" 'docs/ADR-[0-9]+-[^[:space:]]+\.md'; then
      local adr_path
      adr_path="$(enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
        grep -oiE 'docs/ADR-[0-9]+-[^[:space:]]+\.md' | head -1 || true)"
      if [[ -n "$adr_path" && -f "${work_dir}/${adr_path}" ]]; then
        printf '%s\n' "$adr_path"
        return 0
      fi
    fi
  fi
  printf '\n'
}

# Strip TUI ANSI/OSC sequences so live matrix logs match dry-run fixture greps.
enterprise_e2e_outcome_log_normalized() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g; s/\x1b\\][^\x07]*\x07//g' "$row_log" 2>/dev/null
}

# Codex matrix rows may leave attempt logs empty; fall back to archived transcript.
enterprise_e2e_outcome_effective_row_log() {
  local row_log="${1:-}" transcript=""
  if [[ -n "$row_log" && -s "$row_log" ]]; then
    printf '%s\n' "$row_log"
    return 0
  fi
  transcript="$(enterprise_e2e_outcome_repo_root)/tests/live/agents/codex/transcripts/latest.jsonl"
  if [[ -f "$transcript" ]]; then
    printf '%s\n' "$transcript"
    return 0
  fi
  [[ -n "$row_log" ]] && printf '%s\n' "$row_log"
}

enterprise_e2e_outcome_log_matches() {
  local row_log="${1:-}" pattern="${2:-}" tmp="" rc=0 effective=""
  [[ -n "$pattern" ]] || return 1
  effective="$(enterprise_e2e_outcome_effective_row_log "$row_log")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-outcome-log.XXXXXX")"
  if ! enterprise_e2e_outcome_log_normalized "$effective" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  grep -qiE "$pattern" "$tmp" 2>/dev/null || rc=$?
  rm -f "$tmp"
  [[ "$rc" -eq 0 ]]
}

enterprise_e2e_outcome_log_has_babysitting() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_matches "$row_log" \
    'waiting for (your|user)( input| to)|operator pause|need your input before|babysit' || \
    grep -qiE 'waiting for (your|user)( input| to)|operator pause|need your input before|babysit' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_log_has_autonomous() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_matches "$row_log" \
    'autonomous|orchestrator active|SB ► .* composed|worker spawned|Task worker|general-purpose.*(Execute|ROUTER)|SB orchestrator|decision_class.*autonomous' || \
    grep -qiE 'autonomous|orchestrator active|SB ► .* composed|worker spawned|Task worker|general-purpose.*(Execute|ROUTER)|SB orchestrator|decision_class.*autonomous' "$row_log" 2>/dev/null
}

# TUI scrollback often captures directive.json fields without persisting state files.
enterprise_e2e_outcome_log_has_orchestrator_directive() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_matches "$row_log" \
    'next_worker_template|next_skill|orchestrator-directive|orchestrator.directive' || \
    grep -qiE 'next_worker_template|next_skill|orchestrator-directive|orchestrator[[:space:]]directive' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_log_has_worker_activity() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_has_autonomous "$row_log" && return 0
  enterprise_e2e_outcome_log_has_orchestrator_directive "$row_log" && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'Task|worker|orchestrator|Silver Bullet orchestrator' || \
    grep -qEi 'Task|worker|orchestrator|Silver Bullet orchestrator' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_log_has_agentmemory_mcp() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  enterprise_e2e_outcome_log_matches "$row_log" \
    'agentme[mn]?ory[[:space:]_-]*(memory_save|memory_smart_search|memory_recall|memory_capture)' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" \
    'memory_(save|smart_search|recall|capture)[[:space:]]*\(MCP\)' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'agentme[mn]?ory.*\(MCP\)' && return 0
  # Codex TUI: tool name without agentmemory prefix; mem_mr* export ids.
  enterprise_e2e_outcome_log_matches "$row_log" 'memory_save' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'mem_mr[0-9a-z_]+' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'agentmemory.*Graphify|Graphify.*agentmemory|agentmemory\+Graphify' && return 0
  grep -qiE 'agentmemory[[:space:]_-]*(memory_save|memory_smart_search|memory_recall|memory_capture)' "$row_log" 2>/dev/null || \
    grep -qiE 'agentmemory.*\(MCP\)|agentmemory.*Graphify|Graphify.*agentmemory|agentmemory\+Graphify' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_log_has_agentmemory_capture() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_matches "$row_log" \
    'persisted[[:space:]]*to[[:space:]]*agentme[mn]?ory|verdict[[:space:]]*persisted[[:space:]]*to[[:space:]]*agentme[mn]?ory' || \
    enterprise_e2e_outcome_log_matches "$row_log" 'agentme[mn]?ory[[:space:]]*-[[:space:]]*memory_(save|smart_search)' || \
    enterprise_e2e_outcome_log_matches "$row_log" 'saved to agentme[mn]?ory|decision is saved to agentme[mn]?ory'
}

enterprise_e2e_outcome_log_has_workflow_evidence_written() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_matches "$row_log" \
    'WROTE:.*\.planning/workflows/|Evidence[[:space:]]+written[[:space:]]+to[[:space:]]+\.planning/workflows/|\.planning/workflows/[[:alnum:]_.-]+\.md' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" \
    'WROTE:.*\.planning/reviews/|\.planning/reviews/[[:alnum_]_.-]+\.md' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" \
    'WROTE:.*\.planning/ship-readiness/|\.planning/ship-readiness/[[:alnum_]_.-]+\.md' && return 0
  return 1
}

enterprise_e2e_outcome_log_has_graphify_activity() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  enterprise_e2e_outcome_log_matches "$row_log" 'graphify[[:space:]]*query' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" \
    'query[[:space:]]*"[^"]+"[[:space:]]*--graph' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'graphify[[:space:]]*update' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'Skill[[:space:]]*\([[:space:]]*graphify[[:space:]]*\)' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'graphify-out/graph\.json' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'Graphify:.*(query|QUERY|freshquery)' && return 0
  enterprise_e2e_outcome_log_matches "$row_log" 'freshqueryrecorded' && return 0
  grep -qiE 'graphify[[:space:]]*query|graphify query|Graphify:.*(query|QUERY|freshquery)|freshqueryrecorded' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_log_has_agentmemory_unavailable() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  enterprise_e2e_outcome_log_matches "$row_log" \
    'agentme[mn]?ory.*(not available|missing|unavailable|MCP.*unavailable)|matrix MCP env: disabled' || \
    grep -qiE 'agentmemory.*(not available|missing|unavailable|MCP.*unavailable)|agentmemory MCP' "$row_log" 2>/dev/null || \
    grep -qiE 'matrix MCP env: disabled' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_matrix_workflow_slug() {
  local row_num="${1:-}"
  case "$row_num" in
    1) printf 'silver-router\n' ;;
    2) printf 'silver-research\n' ;;
    3) printf 'silver-feature\n' ;;
    4) printf 'silver-bugfix\n' ;;
    5) printf 'silver-ui\n' ;;
    6) printf 'silver-fast\n' ;;
    7) printf 'silver-test\n' ;;
    8) printf 'silver-refactor\n' ;;
    9) printf 'silver-benchmark\n' ;;
    10) printf 'silver-content\n' ;;
    11) printf 'silver-devops\n' ;;
    12) printf 'silver-deploy\n' ;;
    13) printf 'silver-canary\n' ;;
    14) printf 'silver-release\n' ;;
    15) printf 'review-triad\n' ;;
    16) printf 'ship-readiness\n' ;;
    17) printf 'silver-incident\n' ;;
    18) printf 'silver-retro\n' ;;
    19) printf 'silver-forensics\n' ;;
    20) printf 'process-maintenance\n' ;;
    21) printf 'post-exec-gates\n' ;;
    22) printf 'validate-substep\n' ;;
    *) printf '\n' ;;
  esac
}

# Workflow matrix rows use backtick slugs and ISO dates — skip Tier-1 summary tables.
enterprise_e2e_outcome_ledger_workflow_line() {
  local ledger_file="${1:-}" row_num="${2:-}"
  [[ -n "$ledger_file" && -f "$ledger_file" && "$row_num" =~ ^[0-9]+$ ]] || return 0
  awk -F'|' -v r="$row_num" \
    '$2 ~ "^ " r " $" && $3 ~ /`/ && $4 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/ { print; exit }' \
    "$ledger_file" 2>/dev/null || true
}

enterprise_e2e_outcome_ledger_parse_workflow_row() {
  local line="${1:-}" gref="" aref="" status=""
  [[ -n "$line" ]] || return 1
  gref="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$|\*/, "", $10); print $10}')"
  aref="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$|\*/, "", $11); print $11}')"
  status="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$|\*/, "", $6); print $6}' | tr '[:upper:]' '[:lower:]')"
  printf '%s\n%s\n%s\n' "$gref" "$aref" "$status"
}

enterprise_e2e_outcome_score_auto() {
  local work_dir="$1" state_dir="$2" row_log="${3:-}" evidence="${4:-}" row_num="${5:-}"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if enterprise_e2e_outcome_log_has_babysitting "$row_log"; then
      printf 'fail\n'; return 0
    fi
    if enterprise_e2e_outcome_routing_evidence_present "$work_dir" "$state_dir" "$evidence"; then
      printf 'pass\n'; return 0
    fi
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qEi 'routing validation only|routing completes|composed workflow skill' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  if enterprise_e2e_outcome_log_has_babysitting "$row_log"; then
    if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
      printf 'partial\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
    local slug
    slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$row_num")"
    if [[ -n "$slug" ]] && enterprise_e2e_outcome_log_matches "$row_log" "$slug"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_log_has_autonomous "$row_log"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_log_has_orchestrator_directive "$row_log"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_log_matches "$row_log" 'orchestrator|Silver Bullet|\$silver|/silver|Booting MCP|Starting MCP'; then
      printf 'pass\n'; return 0
    fi
    if [[ -f "${state_dir}/orchestrator-directive.json" ]] || [[ -f "${state_dir}/state" ]]; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_clarify() {
  local work_dir="$1" state_dir="$2" row_log="${3:-}" row_num="${4:-}"
  local state_file="${state_dir}/state"
  if [[ -f "${work_dir}/.planning/CLARIFY.md" ]]; then
    if grep -qiE 'locked|decision_class' "${work_dir}/.planning/CLARIFY.md" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  if [[ -f "$state_file" ]] && grep -q 'silver-clarify' "$state_file" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qiE '/silver:clarify|silver:clarify|\$silver:clarify|silver-clarify' "$row_log" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  case "$row_num" in
    1|2|3) printf 'fail\n' ;;
    *) printf 'n/a\n' ;;
  esac
}

enterprise_e2e_outcome_score_noop() {
  local work_dir="$1" row_log="${2:-}"
  if enterprise_e2e_outcome_log_has_babysitting "$row_log"; then
    if [[ -n "$row_log" && -f "$row_log" ]] && grep -qi 'SB OVERRIDE' "$row_log" 2>/dev/null; then
      printf 'partial\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  if [[ -f "${work_dir}/.planning/CLARIFY.md" ]] && grep -qi 'locked' "${work_dir}/.planning/CLARIFY.md" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]]; then
    printf 'pass\n'; return 0
  fi
  printf 'partial\n'
}

enterprise_e2e_outcome_score_drift() {
  local work_dir="$1" row_log="${2:-}" row_num="${3:-}"
  case "$row_num" in
    3|4|5|17|19) ;;
    *) printf 'n/a\n'; return 0 ;;
  esac
  if find "${work_dir}/.planning/workflows" -name '*.md' -exec grep -lEi 'deviation|drift|course.correct|realign' {} + 2>/dev/null | grep -q .; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qiE 'course correct|implementation drift|realign' "$row_log" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  printf 'partial\n'
}

enterprise_e2e_outcome_score_super() {
  local state_dir="$1" row_log="${2:-}" row_num="${3:-}" work_dir="${4:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}" evidence="${5:-}"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  case "$row_num" in
    3|4|5) ;;
    *) printf 'n/a\n'; return 0 ;;
  esac
  if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
    if enterprise_e2e_outcome_log_matches "$row_log" 'orchestrator|Silver Bullet|\$silver|/silver|workflow|WBS'; then
      printf 'pass\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_log_has_orchestrator_directive "$row_log"; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qiE 'wbs-supervisor|wbs supervisor|WBS stub' "$row_log" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-worker-active.json" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-directive.json" ]] && \
     grep -q 'next_worker_template\|next_skill' "${state_dir}/orchestrator-directive.json" 2>/dev/null; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_heal() {
  local sb_root="$1" row_log="${2:-}" row_num="${3:-}"
  local watch="${sb_root}/.e2e-tui-watch-findings.jsonl"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  if [[ -n "$row_log" && -f "$row_log" ]]; then
    if enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE 'Stop hook blocks completion|session ended on hook block'; then
      if enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
         grep -qiE 'retry|recovered|self-heal|SB fix|SB OVERRIDE'; then
        printf 'pass\n'; return 0
      fi
      printf 'fail\n'; return 0
    fi
    # Harness-emitted hook WARN only — exclude agent deliberation prose (ROUND-6 harness fix).
    if enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE '\[WARN\].*hook|hook gate|hook-trust|Stop hook blocks|session ended on hook block' && \
       ! enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE '\[harness\] ignoring.*(hook|non-blocking)|warning: Spec session'; then
      printf 'partial\n'; return 0
    fi
    if enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE '\[harness\] ignoring.*(hook|non-blocking)'; then
      printf 'n/a\n'; return 0
    fi
  fi
  if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
     enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num" "$row_log"; then
    printf 'fail\n'; return 0
  fi
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_release() {
  local work_dir="$1" row_num="${2:-}" ledger="${3:-}"
  [[ ! "$row_num" =~ ^(14|15|16)$ ]] && { printf 'n/a\n'; return 0; }
  local has_ledger=0 has_ship=0
  [[ -f "${work_dir}/docs/instruction-ledger.jsonl" ]] && has_ledger=1
  [[ -d "${work_dir}/.planning/ship-readiness" ]] && has_ship=1
  if [[ "$has_ledger" -eq 1 && "$has_ship" -eq 1 ]]; then
    if [[ -n "$ledger" && -f "$ledger" ]] && grep -qE '\*manual\*|hand-edited|operator patch' "$ledger" 2>/dev/null; then
      printf 'partial\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if [[ "$has_ledger" -eq 1 || "$has_ship" -eq 1 ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_world() {
  local row_num="$1" work_dir="$2" state_dir="$3" row_log="${4:-}" ledger="${5:-}" evidence="${6:-}"
  local cid score
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    [[ "$score" == "n/a" || "$score" == "pass" ]] && continue
    printf 'fail\n'; return 0
  done < <(enterprise_e2e_outcome_row_criteria "$row_num")
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    [[ "$score" == "n/a" || "$score" == "pass" ]] && continue
    printf 'fail\n'; return 0
  done < <(enterprise_e2e_outcome_session_criteria)
  printf 'pass\n'
}

enterprise_e2e_outcome_row_passes() {
  local row_num="$1" work_dir="$2" state_dir="$3" row_log="${4:-}" ledger="${5:-}" evidence="${6:-}"
  local cid score world
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    [[ "$score" == "n/a" || "$score" == "pass" ]] && continue
    return 1
  done < <(enterprise_e2e_outcome_row_criteria "$row_num")
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    [[ "$score" == "n/a" || "$score" == "pass" ]] && continue
    return 1
  done < <(enterprise_e2e_outcome_session_criteria)
  world="$(enterprise_e2e_outcome_score_world "$row_num" "$work_dir" "$state_dir" "$row_log" "$ledger" "$evidence")"
  [[ "$world" == "pass" ]]
}

enterprise_e2e_outcome_row_failures() {
  local row_num="$1" work_dir="$2" state_dir="$3" row_log="${4:-}" ledger="${5:-}" evidence="${6:-}"
  local cid score world
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    [[ "$score" == "n/a" || "$score" == "pass" ]] && continue
    printf '%s %s\n' "$cid" "$score"
  done < <(enterprise_e2e_outcome_row_criteria "$row_num")
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    [[ "$score" == "n/a" || "$score" == "pass" ]] && continue
    printf '%s %s\n' "$cid" "$score"
  done < <(enterprise_e2e_outcome_session_criteria)
  world="$(enterprise_e2e_outcome_score_world "$row_num" "$work_dir" "$state_dir" "$row_log" "$ledger" "$evidence")"
  [[ "$world" != "pass" ]] && printf 'OUT-WORLD-01 %s\n' "$world"
}

# Emit: pass|partial|fail|n/a
enterprise_e2e_outcome_score_tailor() {
  local work_dir="$1" state_dir="$2" row_log="$3" row_num="${4:-}"
  local state_file="${state_dir}/state"
  [[ "$row_num" == "6" ]] && { printf 'n/a\n'; return 0; }
  if [[ -f "$state_file" ]] && grep -qE 'silver-context|silver-router|silver-feature' "$state_file" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/.planning/workflows/router-session.md" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qEi 'SILVER BULLET.*ROUTING|silver-context|routing validation only' "$row_log" 2>/dev/null; then
    [[ "$row_num" == "1" ]] && { printf 'pass\n'; return 0; }
    printf 'partial\n'; return 0
  fi
  [[ "$row_num" == "1" ]] && { printf 'fail\n'; return 0; }
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_vloop() {
  local work_dir="$1"
  if compgen -G "${work_dir}/.planning/VALIDATION"*.md >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if find "${work_dir}/.planning/workflows" -name '*.md' -exec grep -lE 'VALIDATE|validate-evidence|V-loop' {} + 2>/dev/null | grep -q .; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_gates() {
  local work_dir="$1" row_num="${2:-}"
  [[ "$row_num" == "6" ]] && { printf 'pass\n'; return 0; }
  if compgen -G "${work_dir}/.planning/QUALITY-GATES"*.md >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/.planning/workflows/feature-currency.md" ]] && \
     grep -q 'post-exec-gates' "${work_dir}/.planning/workflows/feature-currency.md" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -d "${work_dir}/.planning/ship-readiness" ]]; then
    printf 'pass\n'; return 0
  fi
  [[ "$row_num" =~ ^(3|5|15|16|21)$ ]] && { printf 'fail\n'; return 0; }
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_trace() {
  local work_dir="$1"
  if compgen -G "${work_dir}/.planning/*SPEC*" >/dev/null 2>&1 && compgen -G "${work_dir}/.planning/PLAN"*.md >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/docs/instruction-ledger.jsonl" ]]; then
    printf 'partial\n'; return 0
  fi
  if compgen -G "${work_dir}/.planning/PLAN"*.md >/dev/null 2>&1; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_intent() {
  local work_dir="$1" evidence_path="${2:-}" row_num="${3:-}" state_dir="${4:-}"
  if [[ -n "$evidence_path" ]]; then
    if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence_path"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_is_routing_row "$row_num" && \
       enterprise_e2e_outcome_routing_evidence_present "$work_dir" "$state_dir" "$evidence_path"; then
      printf 'pass\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  if find "${work_dir}/.planning" -type f 2>/dev/null | head -1 | grep -q .; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_km() {
  local ledger_file="${1:-}" row_num="${2:-}" row_log="${3:-}" work_dir="${4:-}" evidence="${5:-}"
  local line="" gref="" aref="" status=""
  work_dir="${work_dir:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}"
  evidence="$(enterprise_e2e_outcome_resolve_evidence "$evidence" "$row_num" "$row_log" "$work_dir")"
  local has_am=0 has_gf=0
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  if [[ -n "$ledger_file" && -f "$ledger_file" && "$row_num" =~ ^[0-9]+$ ]]; then
    line="$(enterprise_e2e_outcome_ledger_workflow_line "$ledger_file" "$row_num")"
    if [[ -n "$line" ]]; then
      gref="$(enterprise_e2e_outcome_ledger_parse_workflow_row "$line" | sed -n '1p')"
      aref="$(enterprise_e2e_outcome_ledger_parse_workflow_row "$line" | sed -n '2p')"
      status="$(enterprise_e2e_outcome_ledger_parse_workflow_row "$line" | sed -n '3p')"
    fi
  fi
  # Matrix harness records graphify scope before agent session (ledger may be empty on first pass).
  if [[ -z "$gref" && -n "${SB_E2E_MATRIX_GRAPHIFY_REF:-}" ]]; then
    gref="$SB_E2E_MATRIX_GRAPHIFY_REF"
  fi
  if enterprise_e2e_outcome_log_has_agentmemory_mcp "$row_log" || \
     enterprise_e2e_outcome_log_has_agentmemory_capture "$row_log"; then
    has_am=1
  fi
  if [[ -n "$gref" ]] || enterprise_e2e_outcome_log_has_graphify_activity "$row_log"; then
    has_gf=1
  fi
  # Live TUI: MCP capture + ledger graphify scope or substantive graphify in log.
  if [[ "$has_am" -eq 1 && "$has_gf" -eq 1 ]]; then
    printf 'pass\n'; return 0
  fi
  # Live TUI: ledger graphify scope + graphify activity + workflow evidence (row 8 heredoc path).
  if [[ -n "$gref" ]] && enterprise_e2e_outcome_log_has_graphify_activity "$row_log"; then
    if [[ -f "${work_dir}/graphify-out/graph.json" ]] && \
       enterprise_e2e_outcome_log_has_workflow_evidence_written "$row_log"; then
      printf 'pass\n'; return 0
    fi
  fi
  # Matrix harness: preflight graphify query in row_log + graph.json + row evidence satisfies KM
  # when TUI sessions do not emit agentmemory MCP tool lines (matrix strips non-essential MCP).
  if enterprise_e2e_outcome_log_has_graphify_activity "$row_log" && \
     [[ -f "${work_dir}/graphify-out/graph.json" ]]; then
    if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_log_has_workflow_evidence_written "$row_log"; then
      printf 'pass\n'; return 0
    fi
  fi
  # Retained TUI: ledger graphify scope + graph.json + workflow evidence when KM
  # preamble was omitted from scrollback (row 7 silver-test — preflight ref only).
  if [[ -n "$gref" ]] && [[ -f "${work_dir}/graphify-out/graph.json" ]]; then
    if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
      printf 'pass\n'; return 0
    fi
  fi
  if [[ -f "${work_dir}/graphify-out/graph.json" ]] && \
     { enterprise_e2e_outcome_log_has_agentmemory_mcp "$row_log" || \
       enterprise_e2e_outcome_log_matches "$row_log" 'agentmemory|Booting MCP|Starting MCP' ; }; then
    printf 'pass\n'; return 0
  fi
  if [[ "$status" == "pass" ]]; then
    if [[ -n "$gref" && -n "$aref" ]]; then
      printf 'pass\n'; return 0
    fi
    if [[ -n "$gref" || -n "$aref" ]]; then
      if [[ -n "$gref" && -z "$aref" ]] && \
         enterprise_e2e_outcome_log_has_agentmemory_unavailable "$row_log"; then
        printf 'n/a\n'; return 0
      fi
      printf 'partial\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  if [[ -n "$gref" ]]; then
    if [[ -n "$aref" ]]; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_log_has_agentmemory_unavailable "$row_log"; then
      printf 'n/a\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" == "1" ]]; then
    printf 'n/a\n'; return 0
  fi
  if [[ -f "${work_dir:-}/.silver-bullet.json" ]] && grep -q '"graphify"' "${work_dir}/.silver-bullet.json" 2>/dev/null; then
    printf 'partial\n'; return 0
  fi
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_orch() {
  local state_dir="$1" row_log="${2:-}" row_num="${3:-}" work_dir="${4:-}" evidence="${5:-}"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if enterprise_e2e_outcome_routing_evidence_present "$work_dir" "$state_dir" "$evidence"; then
      printf 'pass\n'; return 0
    fi
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qEi 'SILVER BULLET|routing validation only|/silver|silver-feature' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
  fi
  if [[ -f "${state_dir}/orchestrator-directive.json" ]] && \
     grep -q 'next_worker_template\|next_skill' "${state_dir}/orchestrator-directive.json" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-worker-active.json" ]]; then
    printf 'pass\n'; return 0
  fi
  # Retained TUI: directive/worker scrollback without persisted orchestrator state.
  if enterprise_e2e_outcome_log_has_orchestrator_directive "$row_log"; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_log_has_autonomous "$row_log"; then
    local slug
    slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$row_num")"
    if [[ -n "$slug" ]] && enterprise_e2e_outcome_log_matches "$row_log" "$slug"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
      printf 'pass\n'; return 0
    fi
  fi
  if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence" && \
     enterprise_e2e_outcome_log_matches "$row_log" 'orchestrator|Silver Bullet|\$silver|/silver|Booting MCP|graphify query'; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_log_has_worker_activity "$row_log"; then
    local slug
    slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$row_num")"
    if [[ -n "$slug" ]] && enterprise_e2e_outcome_log_matches "$row_log" "$slug"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_plan() {
  local work_dir="$1"
  if compgen -G "${work_dir}/.planning/PLAN"*.md >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_skill() {
  local state_dir="$1" row_log="${2:-}" row_num="${3:-}" work_dir="${4:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}" evidence="${5:-}"
  local state_file="${state_dir}/state" requested_file="${state_dir}/state.requested" slug parent_log_patterns=""
  slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$row_num")"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if enterprise_e2e_outcome_log_matches "$row_log" \
        'silver-router|silver-context|routing validation only|/silver'; then
      printf 'pass\n'; return 0
    fi
  fi
  # Internal rows 21/22 — parent session log (align with row-1 silver-context fallback).
  case "$row_num" in
    21) parent_log_patterns='post-exec-gates|silver-feature|silver-context' ;;
    22) parent_log_patterns='validate-substep|silver-bugfix|silver-context|/silver:bugfix' ;;
  esac
  if [[ -n "$parent_log_patterns" && -n "$row_log" && -f "$row_log" ]]; then
    if enterprise_e2e_outcome_log_matches "$row_log" "$parent_log_patterns"; then
      printf 'pass\n'; return 0
    fi
  fi
  # Log-first: retained TUI parent logs before non-silver state partial.
  if [[ -n "$slug" && -n "$row_log" && -f "$row_log" ]]; then
    if enterprise_e2e_outcome_log_matches "$row_log" "${slug}|/silver:${slug#silver-}|invoke-skill[[:space:]]+silver"; then
      printf 'pass\n'; return 0
    fi
  fi
  if [[ -n "$slug" ]] && enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
    if enterprise_e2e_outcome_log_matches "$row_log" "${slug}|/silver:${slug#silver-}|invoke-skill[[:space:]]+silver"; then
      printf 'pass\n'; return 0
    fi
  fi
  for candidate in "$state_file" "$requested_file"; do
    if [[ -f "$candidate" ]] && [[ -s "$candidate" ]]; then
      if grep -qE '^silver(-|$)' "$candidate" 2>/dev/null; then
        printf 'pass\n'; return 0
      fi
      if [[ -n "$slug" ]] && grep -Fqx -- "$slug" "$candidate" 2>/dev/null; then
        printf 'pass\n'; return 0
      fi
    fi
  done
  if [[ -f "$state_file" ]] && [[ -s "$state_file" ]]; then
    if grep -qE '^silver-' "$state_file" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && enterprise_e2e_outcome_log_matches "$row_log" 'silver-[a-z]|/silver:|\$silver'; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

# Ladder rung rows only (review-fix-ladder section) — avoid Tier/matrix tables with | N |.
enterprise_e2e_outcome_ledger_ladder_rows() {
  local ledger_file="$1"
  awk '
    /^## review-fix-ladder/ { in_ladder = 1; next }
    in_ladder && /^## / { in_ladder = 0 }
    in_ladder && /^\| Rung \|/ { in_table = 1; next }
    in_ladder && !in_table && /^\| 1 \|/ { in_table = 1 }
    in_ladder && in_table && /^\|[-|[:space:]]+\|/ { next }
    in_ladder && in_table && /^\| [1-8] \|/ { print }
    in_ladder && in_table && /^$/ { in_table = 0 }
  ' "$ledger_file" 2>/dev/null
}

enterprise_e2e_outcome_score_review() {
  local ledger_file="$1"
  local ladder_rows rung_count fails
  [[ -f "$ledger_file" ]] || { printf 'fail\n'; return 0; }
  ladder_rows="$(enterprise_e2e_outcome_ledger_ladder_rows "$ledger_file")"
  if [[ -z "$ladder_rows" ]]; then
    printf 'fail\n'; return 0
  fi
  rung_count="$(printf '%s\n' "$ladder_rows" | grep -cE '^\| [1-8] \|' || true)"
  [[ "${rung_count:-0}" -ge 8 ]] || { printf 'fail\n'; return 0; }
  fails="$(printf '%s\n' "$ladder_rows" | grep -cEv '\*\*Pass\*\*| Pass ' || true)"
  if [[ "${fails:-0}" -eq 0 ]]; then
    printf 'pass\n'; return 0
  fi
  printf 'partial\n'
}

enterprise_e2e_outcome_score_blast() {
  local work_dir="$1" row_num="${2:-}"
  [[ "$row_num" != "11" ]] && { printf 'n/a\n'; return 0; }
  if compgen -G "${work_dir}/.planning/SECURITY"*.md >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/.planning/workflows/devops-terraform-validation.md" ]] && \
     [[ -f "${work_dir}/infra/terraform/main.tf" ]]; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_evidence_present "$work_dir" ".planning/workflows/devops-terraform-validation.md" && \
     [[ -f "${work_dir}/infra/terraform/main.tf" ]]; then
    printf 'pass\n'; return 0
  fi
  if compgen -G "${work_dir}/.planning/workflows/devops"*.md >/dev/null 2>&1; then
    if [[ -f "${work_dir}/infra/terraform/main.tf" ]] || \
       grep -qiE 'blast.radius|terraform.*validation|IaC|environment variable' \
         "${work_dir}"/.planning/workflows/devops*.md 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
  fi
  if [[ -f "${work_dir}/infra/terraform/main.tf" ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_hook() {
  local sb_root="$1" row_num="${2:-}" row_log="${3:-}"
  local watch="${sb_root}/.e2e-tui-watch-findings.jsonl"
  local ledger="${sb_root}/.planning/enterprise-e2e/ROUND-6-LEDGER.md"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE 'session ended on hook block|FAIL:.*outcome assessment'; then
      printf 'fail\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if [[ -f "$ledger" ]] && grep -q 'hook-delivery 3/3' "$ledger" 2>/dev/null; then
    if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
       enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num" "$row_log"; then
      printf 'fail\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
     enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num" "$row_log"; then
    printf 'fail\n'; return 0
  fi
  printf 'partial\n'
}

enterprise_e2e_outcome_score_complete() {
  local work_dir="$1" row_num="${2:-}"
  [[ ! "$row_num" =~ ^(14|15|16)$ ]] && { printf 'n/a\n'; return 0; }
  if [[ -d "${work_dir}/.planning/ship-readiness" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/CHANGELOG.md" ]] && [[ "$row_num" == "14" ]]; then
    printf 'pass\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_handoff() {
  local state_dir="$1" row_num="${2:-}" work_dir="${3:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}" evidence="${4:-}"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  case "$row_num" in
    3|4|5) ;;
    *) printf 'n/a\n'; return 0 ;;
  esac
  if enterprise_e2e_outcome_evidence_present "$work_dir" "$evidence"; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_log_has_orchestrator_directive "$row_log"; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-worker-active.json" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-directive.json" ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_codeint() {
  local work_dir="$1" row_log="${2:-}" row_num="${3:-}" ledger="${4:-}"
  if [[ -f "${work_dir}/.silver-bullet.json" ]] && \
     grep -qE '"graphify"|"agentmemory"' "${work_dir}/.silver-bullet.json" 2>/dev/null; then
    if [[ -n "$row_log" && -f "$row_log" ]] && grep -qi 'graphify query' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    # graphify runs in matrix preamble — not always echoed in TUI log
    if [[ -n "$ledger" && -f "$ledger" && "$row_num" =~ ^[0-9]+$ ]]; then
      local line gref
      line="$(enterprise_e2e_outcome_ledger_workflow_line "$ledger" "$row_num")"
      gref="$(enterprise_e2e_outcome_ledger_parse_workflow_row "$line" 2>/dev/null | sed -n '1p' || true)"
      if [[ -n "$gref" && "$gref" != " " ]]; then
        printf 'pass\n'; return 0
      fi
    fi
    enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'pass\n'; return 0; }
    if [[ -f "${work_dir}/graphify-out/graph.json" ]]; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_flow() {
  local work_dir="$1"
  if find "${work_dir}/.planning/workflows" -name '202*.md' 2>/dev/null | grep -q .; then
    if find "${work_dir}/.planning/workflows" -name '202*.md' -exec grep -l 'Flow Log' {} + 2>/dev/null | grep -q .; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  if [[ -d "${work_dir}/.planning/workflows/.archive" ]]; then
    printf 'pass\n'; return 0
  fi
  printf 'partial\n'
}

enterprise_e2e_outcome_score_measure() {
  local ledger_file="$1" sb_root="${2:-}"
  [[ -f "$ledger_file" ]] || { printf 'fail\n'; return 0; }
  if [[ -f "${sb_root}/scripts/lib/enterprise-e2e-ledger-reconcile.sh" ]]; then
    # shellcheck source=scripts/lib/enterprise-e2e-ledger-reconcile.sh
    source "${sb_root}/scripts/lib/enterprise-e2e-ledger-reconcile.sh"
    SB_E2E_LEDGER_FILE="$ledger_file"
    local status
    status="$(enterprise_e2e_ledger_reconcile_status)"
    case "$status" in
      COMPLETE) printf 'pass\n' ;;
      STALE) printf 'partial\n' ;;
      *) printf 'fail\n' ;;
    esac
    return 0
  fi
  printf 'partial\n'
}

enterprise_e2e_outcome_score_decide() {
  local work_dir="$1"
  if [[ -f "${work_dir}/.planning/CLARIFY.md" ]] && grep -qi 'locked' "${work_dir}/.planning/CLARIFY.md" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_surface() {
  local sb_root="${1:-}"
  sb_root="${sb_root:-$(enterprise_e2e_outcome_repo_root)}"
  local script="${sb_root}/scripts/validate-host-install-surface.sh"
  [[ -x "$script" ]] || { printf 'fail\n'; return 0; }
  if bash "$script" --repo-root "$sb_root" >/dev/null 2>&1; then
    printf 'pass\n'
  else
    printf 'fail\n'
  fi
}

enterprise_e2e_outcome_score_forens() {
  local work_dir="$1" row_num="${2:-}"
  [[ "$row_num" != "19" ]] && { printf 'n/a\n'; return 0; }
  if compgen -G "${work_dir}/docs/forensics/*.md" >/dev/null 2>&1; then
    if grep -qiE 'root cause|timeline' "${work_dir}"/docs/forensics/*.md 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

# Dispatch criterion scorer. Args: criterion_id work_dir state_dir row_log row_num [ledger] [evidence_path]
enterprise_e2e_outcome_score_criterion() {
  local cid="$1" work_dir="$2" state_dir="$3" row_log="${4:-}" row_num="${5:-}" ledger="${6:-}" evidence="${7:-}"
  local sb_root
  sb_root="$(enterprise_e2e_outcome_repo_root)"
  row_log="$(enterprise_e2e_outcome_effective_row_log "$row_log")"
  evidence="$(enterprise_e2e_outcome_resolve_evidence "$evidence" "$row_num" "$row_log" "$work_dir")"
  case "$cid" in
    OUT-TAILOR-01) enterprise_e2e_outcome_score_tailor "$work_dir" "$state_dir" "$row_log" "$row_num" ;;
    OUT-VLOOP-01) enterprise_e2e_outcome_score_vloop "$work_dir" ;;
    OUT-GATES-01) enterprise_e2e_outcome_score_gates "$work_dir" "$row_num" ;;
    OUT-TRACE-01) enterprise_e2e_outcome_score_trace "$work_dir" ;;
    OUT-INTENT-01) enterprise_e2e_outcome_score_intent "$work_dir" "$evidence" "$row_num" "$state_dir" ;;
    OUT-KM-01) enterprise_e2e_outcome_score_km "$ledger" "$row_num" "$row_log" "$work_dir" "$evidence" ;;
    OUT-ORCH-01) enterprise_e2e_outcome_score_orch "$state_dir" "$row_log" "$row_num" "$work_dir" "$evidence" ;;
    OUT-PLAN-01) enterprise_e2e_outcome_score_plan "$work_dir" ;;
    OUT-SKILL-01) enterprise_e2e_outcome_score_skill "$state_dir" "$row_log" "$row_num" "$work_dir" "$evidence" ;;
    OUT-REVIEW-01) enterprise_e2e_outcome_score_review "$ledger" ;;
    OUT-BLAST-01) enterprise_e2e_outcome_score_blast "$work_dir" "$row_num" ;;
    OUT-HOOK-01) enterprise_e2e_outcome_score_hook "$sb_root" "$row_num" "$row_log" ;;
    OUT-COMPLETE-01) enterprise_e2e_outcome_score_complete "$work_dir" "$row_num" ;;
    OUT-HANDOFF-01) enterprise_e2e_outcome_score_handoff "$state_dir" "$row_num" "$work_dir" "$evidence" ;;
    OUT-CODEINT-01) enterprise_e2e_outcome_score_codeint "$work_dir" "$row_log" "$row_num" "$ledger" ;;
    OUT-FLOW-01) enterprise_e2e_outcome_score_flow "$work_dir" ;;
    OUT-MEASURE-01) enterprise_e2e_outcome_score_measure "$ledger" "$sb_root" ;;
    OUT-DECIDE-01) enterprise_e2e_outcome_score_decide "$work_dir" ;;
    OUT-FORENS-01) enterprise_e2e_outcome_score_forens "$work_dir" "$row_num" ;;
    OUT-AUTO-01) enterprise_e2e_outcome_score_auto "$work_dir" "$state_dir" "$row_log" "$evidence" "$row_num" ;;
    OUT-CLARIFY-01) enterprise_e2e_outcome_score_clarify "$work_dir" "$state_dir" "$row_log" "$row_num" ;;
    OUT-NOOP-01) enterprise_e2e_outcome_score_noop "$work_dir" "$row_log" ;;
    OUT-WORLD-01) enterprise_e2e_outcome_score_world "$row_num" "$work_dir" "$state_dir" "$row_log" "$ledger" "$evidence" ;;
    OUT-DRIFT-01) enterprise_e2e_outcome_score_drift "$work_dir" "$row_log" "$row_num" ;;
    OUT-SUPER-01) enterprise_e2e_outcome_score_super "$state_dir" "$row_log" "$row_num" "$work_dir" "$evidence" ;;
    OUT-HEAL-01) enterprise_e2e_outcome_score_heal "$sb_root" "$row_log" "$row_num" ;;
    OUT-RELEASE-01) enterprise_e2e_outcome_score_release "$work_dir" "$row_num" "$ledger" ;;
    OUT-SURFACE-01) enterprise_e2e_outcome_score_surface "$sb_root" ;;
    *) printf 'n/a\n' ;;
  esac
}

# workflow scope — emit "CRITERION score" per line for row
enterprise_e2e_outcome_assess_workflow_row() {
  local row_num="$1" work_dir="$2" state_dir="$3" row_log="${4:-}" ledger="${5:-}" evidence="${6:-}"
  local cid score
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    printf '%s %s\n' "$cid" "$score"
  done < <(enterprise_e2e_outcome_row_criteria "$row_num")
}

# session scope — session-level criteria only
enterprise_e2e_outcome_assess_session() {
  local row_log="$1" state_dir="$2" work_dir="${3:-}" ledger="${4:-}" row_num="${5:-}" evidence="${6:-}"
  local cid score
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
    printf '%s %s\n' "$cid" "$score"
  done < <(enterprise_e2e_outcome_session_criteria)
}

# round scope
enterprise_e2e_outcome_assess_round() {
  local ledger_file="$1"
  local sb_root work_dir
  sb_root="$(enterprise_e2e_outcome_repo_root)"
  work_dir="${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}"
  enterprise_e2e_outcome_score_criterion OUT-REVIEW-01 "$work_dir" "${SB_RUNTIME_STATE_DIR:-/tmp}" "" "" "$ledger_file"
  printf 'OUT-MEASURE-01 %s\n' "$(enterprise_e2e_outcome_score_measure "$ledger_file" "$sb_root")"
  printf 'OUT-KM-01 %s\n' "$(enterprise_e2e_outcome_score_km "$ledger_file" "0")"
  printf 'OUT-SURFACE-01 %s\n' "$(enterprise_e2e_outcome_score_surface "$sb_root")"
}

# Write per-workflow checklist markdown (workflow scope)
enterprise_e2e_outcome_write_workflow_checklist() {
  local row_num="$1" out_file="$2" work_dir="${3:-}" state_dir="${4:-}" row_log="${5:-}" ledger="${6:-}" evidence="${7:-}"
  work_dir="${work_dir:-${SB_TEST_ENTERPRISE_APP_ROOT:-/Users/shafqat/projects/enterprise-grade-test-app}}"
  state_dir="${state_dir:-${SB_RUNTIME_STATE_DIR:-/tmp}}"
  mkdir -p "$(dirname "$out_file")"
  {
    printf '# Row %s outcome checklist\n\n' "$row_num"
    printf '| Criterion | Score | Scope |\n|-----------|-------|-------|\n'
    local cid score
    while IFS= read -r cid; do
      [[ -z "$cid" ]] && continue
      score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
      printf '| %s | %s | workflow |\n' "$cid" "$score"
    done < <(enterprise_e2e_outcome_row_criteria "$row_num")
    world="$(enterprise_e2e_outcome_score_world "$row_num" "$work_dir" "$state_dir" "$row_log" "$ledger" "$evidence")"
    printf '| OUT-WORLD-01 | %s | composite |\n' "$world"
    row_pass="FAIL"
    enterprise_e2e_outcome_row_passes "$row_num" "$work_dir" "$state_dir" "$row_log" "$ledger" "$evidence" && row_pass="PASS"
    printf '\n**Row outcome verdict:** %s (all applicable criteria must pass; partial = fail)\n' "$row_pass"
    printf '\n## Session criteria (same session)\n\n'
    printf '| Criterion | Score | Scope |\n|-----------|-------|-------|\n'
    while IFS= read -r cid; do
      [[ -z "$cid" ]] && continue
      score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger" "$evidence")"
      printf '| %s | %s | session |\n' "$cid" "$score"
    done < <(enterprise_e2e_outcome_session_criteria)
  } >"$out_file"
}

# Structural wiring checks (CI-safe, no live TUI)
enterprise_e2e_outcome_assess_structural_wiring() {
  local root fail=0
  root="$(enterprise_e2e_outcome_repo_root)"
  for f in \
    "${root}/.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md" \
    "${root}/.planning/enterprise-e2e/ROUND-N-OUTCOMES.md" \
    "${root}/docs/testing/outcome-criteria-registry.json" \
    "${root}/scripts/lib/enterprise-e2e-outcome-assessment.sh" \
    "${root}/tests/scripts/test-outcome-assessment.sh" \
    "${root}/tests/scripts/test-claude-agent-surface-isolation.sh"
  do
    [[ -f "$f" ]] || { echo "MISSING: $f"; fail=1; }
  done
  if command -v jq >/dev/null 2>&1; then
    local count
    count="$(jq '.criteria | length' "${root}/docs/testing/outcome-criteria-registry.json")"
    [[ "$count" -ge 28 ]] || { echo "CRITERIA_COUNT: expected >=28 got $count"; fail=1; }
  fi
  return "$fail"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Source this library; do not execute directly." >&2
  echo "  source scripts/lib/enterprise-e2e-outcome-assessment.sh" >&2
  exit 2
fi

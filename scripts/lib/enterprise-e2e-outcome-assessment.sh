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
    OUT-DRIFT-01 OUT-SUPER-01 OUT-HEAL-01 OUT-RELEASE-01
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

enterprise_e2e_outcome_routing_evidence_present() {
  local work_dir="$1" state_dir="$2" evidence="${3:-}"
  local state_file="${state_dir}/state"
  if [[ -n "$evidence" ]] && { [[ -f "${work_dir}/${evidence}" ]] || [[ -d "${work_dir}/${evidence}" ]]; }; then
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

# True hook BLOCKER in TUI watch (severity=blocker, category=hook) — not annoyance noise.
enterprise_e2e_outcome_watch_has_hook_blocker() {
  local watch="$1" row_num="${2:-}"
  [[ -f "$watch" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    if [[ -n "$row_num" ]]; then
      jq -e --argjson r "$row_num" \
        'select(.row == $r) | select(.severity == "blocker") | select(.category == "hook")' \
        "$watch" 2>/dev/null | grep -q .
      return $?
    fi
    jq -e 'select(.severity == "blocker") | select(.category == "hook")' \
      "$watch" 2>/dev/null | grep -q .
    return $?
  fi
  grep -q '"severity": "blocker"' "$watch" 2>/dev/null && \
    grep -qiE '"category": "hook"|false.positive' "$watch" 2>/dev/null
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

enterprise_e2e_outcome_log_has_babysitting() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  grep -qiE 'waiting for (your|user)|ask the user|operator pause|need your input|babysit' "$row_log" 2>/dev/null
}

enterprise_e2e_outcome_log_has_autonomous() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  grep -qiE 'autonomous|orchestrator active|SB ► .* composed|worker spawned|Task worker' "$row_log" 2>/dev/null
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
    if [[ -n "$evidence" ]] && [[ -f "${work_dir}/${evidence}" || -d "${work_dir}/${evidence}" ]]; then
      printf 'partial\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  if [[ -n "$evidence" ]] && [[ -f "${work_dir}/${evidence}" || -d "${work_dir}/${evidence}" ]]; then
    if enterprise_e2e_outcome_log_has_autonomous "$row_log"; then
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
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qiE '/silver:clarify|silver:clarify' "$row_log" 2>/dev/null; then
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
  local state_dir="$1" row_log="${2:-}" row_num="${3:-}"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  case "$row_num" in
    3|4|5) ;;
    *) printf 'n/a\n'; return 0 ;;
  esac
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
    if grep -qiE 'Stop hook blocks completion|session ended on hook block' "$row_log" 2>/dev/null; then
      if grep -qiE 'retry|recovered|self-heal|SB fix' "$row_log" 2>/dev/null; then
        printf 'pass\n'; return 0
      fi
      printf 'fail\n'; return 0
    fi
    if grep -qiE 'WARN.*hook|hook.*WARN|non-blocking' "$row_log" 2>/dev/null; then
      printf 'partial\n'; return 0
    fi
  fi
  if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
     enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num"; then
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
    if [[ -f "${work_dir}/${evidence_path}" || -d "${work_dir}/${evidence_path}" ]]; then
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
  local ledger_file="${1:-}" row_num="${2:-}"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  if [[ -n "$ledger_file" && -f "$ledger_file" && "$row_num" =~ ^[0-9]+$ ]]; then
    local line gref aref status
    line="$(awk -v r="$row_num" '$0 ~ "^\\| " r " \\|" { print; exit }' "$ledger_file" 2>/dev/null || true)"
    if [[ -n "$line" ]]; then
      gref="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$|\*/, "", $(NF-1)); print $(NF-1)}')"
      aref="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$|\*/, "", $NF); print $NF}')"
      status="$(printf '%s' "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$|\*/, "", $(NF-3)); print $(NF-3)}' | tr '[:upper:]' '[:lower:]')"
      if [[ "$status" == "pass" ]]; then
        if [[ -n "$gref" && -n "$aref" ]]; then
          printf 'pass\n'; return 0
        fi
        if [[ -n "$gref" || -n "$aref" ]]; then
          printf 'partial\n'; return 0
        fi
        printf 'fail\n'; return 0
      fi
    fi
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
  local state_dir="$1" row_log="${2:-}" row_num="${3:-}" work_dir="${4:-}"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if enterprise_e2e_outcome_routing_evidence_present "$work_dir" "$state_dir" ""; then
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
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qE 'Task|worker|orchestrator' "$row_log" 2>/dev/null; then
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
  local state_dir="$1"
  local state_file="${state_dir}/state"
  if [[ -f "$state_file" ]] && [[ -s "$state_file" ]]; then
    if grep -qE '^silver-' "$state_file" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_review() {
  local ledger_file="$1"
  [[ -f "$ledger_file" ]] || { printf 'fail\n'; return 0; }
  if grep -q 'review-fix-ladder' "$ledger_file" && \
     awk '/^\| [1-8] \|/{c++} END{exit (c>=8?0:1)}' "$ledger_file" 2>/dev/null; then
    if grep -E '^\| [1-8] \|' "$ledger_file" | grep -cvE '\*\*Pass\*\*| Pass ' >/dev/null 2>&1; then
      local fails
      fails="$(grep -E '^\| [1-8] \|' "$ledger_file" | grep -cvE '\*\*Pass\*\*| Pass ' || true)"
      [[ "${fails:-0}" -eq 0 ]] && { printf 'pass\n'; return 0; }
    else
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_blast() {
  local work_dir="$1" row_num="${2:-}"
  [[ "$row_num" != "11" ]] && { printf 'n/a\n'; return 0; }
  if compgen -G "${work_dir}/.planning/SECURITY"*.md >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/infra/terraform/main.tf" ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_hook() {
  local sb_root="$1" row_num="${2:-}"
  local watch="${sb_root}/.e2e-tui-watch-findings.jsonl"
  local ledger="${sb_root}/.planning/enterprise-e2e/ROUND-6-LEDGER.md"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if [[ -n "${3:-}" && -f "${3}" ]] && \
       grep -qiE 'session ended on hook block|FAIL:.*outcome assessment' "${3}" 2>/dev/null; then
      printf 'fail\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if [[ -f "$ledger" ]] && grep -q 'hook-delivery 3/3' "$ledger" 2>/dev/null; then
    if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
       enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num"; then
      printf 'fail\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
     enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num"; then
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
  local state_dir="$1" row_num="${2:-}"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  if [[ -f "${state_dir}/orchestrator-worker-active.json" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-directive.json" ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_codeint() {
  local work_dir="$1" row_log="${2:-}" row_num="${3:-}"
  if [[ -f "${work_dir}/.silver-bullet.json" ]] && \
     grep -qE '"graphify"|"agentmemory"' "${work_dir}/.silver-bullet.json" 2>/dev/null; then
    if [[ -n "$row_log" && -f "$row_log" ]] && grep -qi 'graphify query' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    # graphify runs in matrix preamble for routing row — not always in TUI log
    enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'pass\n'; return 0; }
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
  case "$cid" in
    OUT-TAILOR-01) enterprise_e2e_outcome_score_tailor "$work_dir" "$state_dir" "$row_log" "$row_num" ;;
    OUT-VLOOP-01) enterprise_e2e_outcome_score_vloop "$work_dir" ;;
    OUT-GATES-01) enterprise_e2e_outcome_score_gates "$work_dir" "$row_num" ;;
    OUT-TRACE-01) enterprise_e2e_outcome_score_trace "$work_dir" ;;
    OUT-INTENT-01) enterprise_e2e_outcome_score_intent "$work_dir" "$evidence" "$row_num" "$state_dir" ;;
    OUT-KM-01) enterprise_e2e_outcome_score_km "$ledger" "$row_num" ;;
    OUT-ORCH-01) enterprise_e2e_outcome_score_orch "$state_dir" "$row_log" "$row_num" "$work_dir" ;;
    OUT-PLAN-01) enterprise_e2e_outcome_score_plan "$work_dir" ;;
    OUT-SKILL-01) enterprise_e2e_outcome_score_skill "$state_dir" ;;
    OUT-REVIEW-01) enterprise_e2e_outcome_score_review "$ledger" ;;
    OUT-BLAST-01) enterprise_e2e_outcome_score_blast "$work_dir" "$row_num" ;;
    OUT-HOOK-01) enterprise_e2e_outcome_score_hook "$sb_root" "$row_num" "$row_log" ;;
    OUT-COMPLETE-01) enterprise_e2e_outcome_score_complete "$work_dir" "$row_num" ;;
    OUT-HANDOFF-01) enterprise_e2e_outcome_score_handoff "$state_dir" "$row_num" ;;
    OUT-CODEINT-01) enterprise_e2e_outcome_score_codeint "$work_dir" "$row_log" "$row_num" ;;
    OUT-FLOW-01) enterprise_e2e_outcome_score_flow "$work_dir" ;;
    OUT-MEASURE-01) enterprise_e2e_outcome_score_measure "$ledger" "$sb_root" ;;
    OUT-DECIDE-01) enterprise_e2e_outcome_score_decide "$work_dir" ;;
    OUT-FORENS-01) enterprise_e2e_outcome_score_forens "$work_dir" "$row_num" ;;
    OUT-AUTO-01) enterprise_e2e_outcome_score_auto "$work_dir" "$state_dir" "$row_log" "$evidence" "$row_num" ;;
    OUT-CLARIFY-01) enterprise_e2e_outcome_score_clarify "$work_dir" "$state_dir" "$row_log" "$row_num" ;;
    OUT-NOOP-01) enterprise_e2e_outcome_score_noop "$work_dir" "$row_log" ;;
    OUT-WORLD-01) enterprise_e2e_outcome_score_world "$row_num" "$work_dir" "$state_dir" "$row_log" "$ledger" "$evidence" ;;
    OUT-DRIFT-01) enterprise_e2e_outcome_score_drift "$work_dir" "$row_log" "$row_num" ;;
    OUT-SUPER-01) enterprise_e2e_outcome_score_super "$state_dir" "$row_log" "$row_num" ;;
    OUT-HEAL-01) enterprise_e2e_outcome_score_heal "$sb_root" "$row_log" "$row_num" ;;
    OUT-RELEASE-01) enterprise_e2e_outcome_score_release "$work_dir" "$row_num" "$ledger" ;;
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
  local row_log="$1" state_dir="$2" work_dir="${3:-}" ledger="${4:-}" row_num="${5:-}"
  local cid score
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$row_log" "$row_num" "$ledger")"
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
    "${root}/tests/scripts/test-outcome-assessment.sh"
  do
    [[ -f "$f" ]] || { echo "MISSING: $f"; fail=1; }
  done
  if command -v jq >/dev/null 2>&1; then
    local count
    count="$(jq '.criteria | length' "${root}/docs/testing/outcome-criteria-registry.json")"
    [[ "$count" -ge 27 ]] || { echo "CRITERIA_COUNT: expected >=27 got $count"; fail=1; }
  fi
  return "$fail"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Source this library; do not execute directly." >&2
  echo "  source scripts/lib/enterprise-e2e-outcome-assessment.sh" >&2
  exit 2
fi

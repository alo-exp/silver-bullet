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
    OUT-DECIDE-01 OUT-FORENS-01
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
  printf '%s\n' OUT-SKILL-01 OUT-HOOK-01 OUT-ORCH-01 OUT-HANDOFF-01 OUT-CODEINT-01 OUT-KM-01 OUT-DECIDE-01
}

# Emit: pass|partial|fail|n/a
enterprise_e2e_outcome_score_tailor() {
  local work_dir="$1" state_dir="$2" row_log="$3" row_num="${4:-}"
  local state_file="${state_dir}/state"
  [[ "$row_num" == "6" ]] && { printf 'n/a\n'; return 0; }
  if [[ -f "$state_file" ]] && grep -qE 'silver-context|silver-router' "$state_file" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${work_dir}/.planning/workflows/router-session.md" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qE 'SILVER BULLET.*ROUTING|silver-context' "$row_log" 2>/dev/null; then
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
  local work_dir="$1" evidence_path="${2:-}"
  if [[ -n "$evidence_path" ]]; then
    if [[ -f "${work_dir}/${evidence_path}" || -d "${work_dir}/${evidence_path}" ]]; then
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
  if [[ -f "${work_dir:-}/.silver-bullet.json" ]] && grep -q '"graphify"' "${work_dir}/.silver-bullet.json" 2>/dev/null; then
    printf 'partial\n'; return 0
  fi
  printf 'n/a\n'
}

enterprise_e2e_outcome_score_orch() {
  local state_dir="$1" row_log="${2:-}"
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
  local sb_root="$1"
  local watch="${sb_root}/.e2e-tui-watch-findings.jsonl"
  if [[ -f "$watch" ]] && grep -qi 'false.positive\|hook.*block' "$watch" 2>/dev/null; then
    printf 'fail\n'; return 0
  fi
  if [[ -f "${sb_root}/.planning/enterprise-e2e/ROUND-6-LEDGER.md" ]] && \
     grep -q 'hook-delivery 3/3' "${sb_root}/.planning/enterprise-e2e/ROUND-6-LEDGER.md" 2>/dev/null; then
    printf 'pass\n'; return 0
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
  local state_dir="$1"
  if [[ -f "${state_dir}/orchestrator-worker-active.json" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ -f "${state_dir}/orchestrator-directive.json" ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_codeint() {
  local work_dir="$1" row_log="${2:-}"
  if [[ -f "${work_dir}/.silver-bullet.json" ]] && \
     grep -qE '"graphify"|"agentmemory"' "${work_dir}/.silver-bullet.json" 2>/dev/null; then
    if [[ -n "$row_log" && -f "$row_log" ]] && grep -qi 'graphify query' "$row_log" 2>/dev/null; then
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
    OUT-INTENT-01) enterprise_e2e_outcome_score_intent "$work_dir" "$evidence" ;;
    OUT-KM-01) enterprise_e2e_outcome_score_km "$ledger" "$row_num" ;;
    OUT-ORCH-01) enterprise_e2e_outcome_score_orch "$state_dir" "$row_log" ;;
    OUT-PLAN-01) enterprise_e2e_outcome_score_plan "$work_dir" ;;
    OUT-SKILL-01) enterprise_e2e_outcome_score_skill "$state_dir" ;;
    OUT-REVIEW-01) enterprise_e2e_outcome_score_review "$ledger" ;;
    OUT-BLAST-01) enterprise_e2e_outcome_score_blast "$work_dir" "$row_num" ;;
    OUT-HOOK-01) enterprise_e2e_outcome_score_hook "$sb_root" ;;
    OUT-COMPLETE-01) enterprise_e2e_outcome_score_complete "$work_dir" "$row_num" ;;
    OUT-HANDOFF-01) enterprise_e2e_outcome_score_handoff "$state_dir" ;;
    OUT-CODEINT-01) enterprise_e2e_outcome_score_codeint "$work_dir" "$row_log" ;;
    OUT-FLOW-01) enterprise_e2e_outcome_score_flow "$work_dir" ;;
    OUT-MEASURE-01) enterprise_e2e_outcome_score_measure "$ledger" "$sb_root" ;;
    OUT-DECIDE-01) enterprise_e2e_outcome_score_decide "$work_dir" ;;
    OUT-FORENS-01) enterprise_e2e_outcome_score_forens "$work_dir" "$row_num" ;;
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
    [[ "$count" -ge 18 ]] || { echo "CRITERIA_COUNT: expected >=18 got $count"; fail=1; }
  fi
  return "$fail"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Source this library; do not execute directly." >&2
  echo "  source scripts/lib/enterprise-e2e-outcome-assessment.sh" >&2
  exit 2
fi

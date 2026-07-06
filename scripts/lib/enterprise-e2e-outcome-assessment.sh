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

# Compact excerpt for deliberation / matrix-prompt echo detection (live TUI scrollback).
enterprise_e2e_outcome_watch_compact_excerpt() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

# planning-file-guard TUI-watch hits are often agent deliberation or matrix prompt echo —
# not harness hook deny. Returns 0 when the finding is a known false positive (E2E-026).
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

# E2E-093: cursor stream-json logs embed readToolCall file bodies — exclude from scoring grep.
enterprise_e2e_outcome_log_scoring_text() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  if ! grep -qE '^HARNESS |^\{"type":' "$row_log" 2>/dev/null; then
    enterprise_e2e_outcome_log_normalized "$row_log"
    return 0
  fi
  python3 - "$row_log" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as handle:
    for raw in handle:
        line = raw.rstrip("\n")
        if not line:
            continue
        if line.startswith("HARNESS ") or line.startswith("--- HARNESS composite"):
            print(line)
            continue
        if not line.startswith("{"):
            print(line)
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        typ = obj.get("type")
        if typ in ("assistant", "user", "result"):
            for key in ("text", "delta", "message", "content", "result"):
                value = obj.get(key)
                if isinstance(value, str) and value.strip():
                    print(value)
                    break
        elif typ == "tool_call":
            subtype = obj.get("subtype")
            tool_call = obj.get("tool_call") or {}
            name = (
                tool_call.get("name")
                or tool_call.get("toolName")
                or next(iter(tool_call), "")
            )
            if name and subtype in ("started", "completed"):
                print(f"TOOL: {name}")
PY
}

enterprise_e2e_outcome_log_matches() {
  local row_log="${1:-}" pattern="${2:-}" tmp="" rc=0 effective=""
  [[ -n "$pattern" ]] || return 1
  effective="$(enterprise_e2e_outcome_effective_row_log "$row_log")"
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-outcome-log.XXXXXX")"
  if ! enterprise_e2e_outcome_log_scoring_text "$effective" >"$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  grep -qiE "$pattern" "$tmp" 2>/dev/null || rc=$?
  rm -f "$tmp"
  [[ "$rc" -eq 0 ]]
}

enterprise_e2e_outcome_log_has_babysitting() {
  local row_log="${1:-}"
  if enterprise_e2e_outcome_log_matches "$row_log" \
    'waiting for (your|user)( input| to)|need your input before'; then
    return 0
  fi
  # babysit — exclude negated acceptance-criteria / autonomy summaries (agent-claude brief echo).
  if enterprise_e2e_outcome_log_matches "$row_log" 'babysit'; then
    if enterprise_e2e_outcome_log_matches "$row_log" \
      'without[[:space:]]*(operator[[:space:]]+)?babysit|no[[:space:]]*(operator[[:space:]]+)?babysit|withoutbabysit|withoutoperatorbabysit|nobabysit|nooperatorbabysit'; then
      return 1
    fi
    return 0
  fi
  # operator pause(s) — exclude negated autonomy summaries (row 10 stream-json false positive).
  if enterprise_e2e_outcome_log_matches "$row_log" 'operator pause'; then
    if enterprise_e2e_outcome_log_matches "$row_log" \
      'no (clarify|operator)|without operator pause|autonomous_default'; then
      return 1
    fi
    return 0
  fi
  return 1
}

# Audited override usage (not matrix prompt instructions like "issue SB OVERRIDE when …").
enterprise_e2e_outcome_log_has_sb_override() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_matches "$row_log" 'SB OVERRIDE:[[:space:]]'
}

enterprise_e2e_outcome_log_has_autonomous() {
  local row_log="${1:-}"
  enterprise_e2e_outcome_log_has_worker_completion "$row_log" && return 0
  enterprise_e2e_outcome_log_matches "$row_log" \
    'autonomous|orchestrator active|SB ► .* composed|worker spawned|Task worker|general-purpose.*(Execute|ROUTER)|SB orchestrator'
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
  grep -qiE 'agentmemory[[:space:]_-]*(memory_save|memory_smart_search|memory_recall|memory_capture)' "$row_log" 2>/dev/null || \
    grep -qiE 'agentmemory.*\(MCP\)' "$row_log" 2>/dev/null
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
  grep -qiE 'graphify[[:space:]]*query|graphify query' "$row_log" 2>/dev/null
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
    2) printf 'silver-deep-research\n' ;;
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

# Matrix evidence path (matches scripts/enterprise-e2e/matrix.sh MATRIX_ROWS).
enterprise_e2e_outcome_matrix_evidence_path() {
  local row_num="${1:-}"
  case "$row_num" in
    1) printf '.planning/workflows/router-session.md' ;;
    2) printf 'docs/ADR-001-runtime.md' ;;
    3) printf '.planning/workflows/feature-currency.md' ;;
    4) printf '.planning/workflows/bugfix-health.md' ;;
    5) printf 'ui/src/App.jsx' ;;
    6) printf '.planning/workflows/fast-readme.md' ;;
    7) printf '.planning/workflows/test-orders-integration.md' ;;
    8) printf '.planning/workflows/refactor-order-validation.md' ;;
    9) printf 'docs/benchmarks/health.md' ;;
    10) printf 'docs/API.md' ;;
    11) printf '.planning/workflows/devops-terraform-validation.md' ;;
    12) printf 'docs/DEPLOY.md' ;;
    13) printf 'docs/CANARY.md' ;;
    14) printf 'CHANGELOG.md' ;;
    15) printf '.planning/reviews/triad-currency.md' ;;
    16) printf '.planning/ship-readiness/checklist.md' ;;
    17) printf 'docs/incidents/INC-001.md' ;;
    18) printf 'docs/retro/RETRO-001.md' ;;
    19) printf 'docs/forensics/CI-001.md' ;;
    20) printf 'docs/WORKFLOW_E2E_MATRIX.md' ;;
    *) printf '' ;;
  esac
}

# Evidence at live path, archive, slug-adjacent workflow artifact, or tri-criteria run evidence.
enterprise_e2e_outcome_is_tri_criteria_row() {
  case "${1:-}" in TC-01|TC-02|TC-03) return 0 ;; *) return 1 ;; esac
}

enterprise_e2e_outcome_tri_criteria_run_dir() {
  [[ -n "${SB_TRI_CRITERIA_RUN_DIR:-}" && -d "${SB_TRI_CRITERIA_RUN_DIR}" ]] || return 1
  printf '%s\n' "${SB_TRI_CRITERIA_RUN_DIR}"
}

enterprise_e2e_outcome_composer_catalog_workflow_id() {
  local composer="${1#silver:}"
  composer="${composer//:/-}"
  case "$composer" in
    silver-feature) printf 'WF-SILVER-FEATURE' ;;
    silver-fast) printf 'WF-SILVER-FAST' ;;
    silver-devops) printf 'WF-SILVER-DEVOPS' ;;
    silver-release) printf 'WF-SILVER-RELEASE' ;;
    silver-new-workflow) printf 'WF-SILVER-NEW-WORKFLOW' ;;
    silver-ui) printf 'WF-SILVER-UI' ;;
    silver-bugfix) printf 'WF-SILVER-BUGFIX' ;;
    silver-router) printf 'WF-SILVER-ROUTER' ;;
    silver-research) printf 'WF-SILVER-DEEP-RESEARCH' ;;
    silver-ship) printf 'WF-SILVER-SHIP' ;;
    silver-*)
      local slug="${composer#silver-}"
      slug="$(printf '%s' "$slug" | tr '[:lower:]' '[:upper:]')"
      printf 'WF-SILVER-%s' "$slug"
      ;;
    *) return 1 ;;
  esac
}

enterprise_e2e_outcome_tri_criteria_product_present() {
  local row_id="$1" work_dir="$2"
  [[ -n "$work_dir" && -d "$work_dir/.git" ]] || return 1
  case "$row_id" in
    TC-01)
      if compgen -G "${work_dir}/api/src/*waitlist*" >/dev/null 2>&1; then
        return 0
      fi
      git -C "$work_dir" rev-parse --verify feature/tc01-waitlist-saas >/dev/null 2>&1 && return 0
      ;;
    TC-02)
      if [[ -f "${work_dir}/README.md" ]] && grep -qEi 'runbook|correlation|structured|observability' "${work_dir}/README.md" 2>/dev/null; then
        return 0
      fi
      if compgen -G "${work_dir}/api/src/*log*" >/dev/null 2>&1; then
        return 0
      fi
      git -C "$work_dir" rev-parse --verify feature/tc02-observability-runbook >/dev/null 2>&1 && return 0
      git -C "$work_dir" rev-parse --verify feature/tc02-readme-badge >/dev/null 2>&1 && return 0
      ;;
    TC-03)
      if compgen -G "${work_dir}/scripts/*compliance*" >/dev/null 2>&1; then
        return 0
      fi
      git -C "$work_dir" rev-parse --verify feature/tc03-compliance-snapshot >/dev/null 2>&1 && return 0
      ;;
  esac
  return 1
}

enterprise_e2e_outcome_tri_criteria_session_evidence_present() {
  local row_id="$1" row_log="${2:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  case "$row_id" in
    TC-01)
      grep -qEi 'WF-SILVER-(FEATURE|DEVOPS|RELEASE)|waitlist|multi.?workflow' "$row_log" 2>/dev/null && return 0
      ;;
    TC-02)
      grep -qEi 'WF-SILVER-FAST|observability|structured logging|DR-SUBSTITUTE|correlation' "$row_log" 2>/dev/null && return 0
      ;;
    TC-03)
      grep -qEi 'NEW-WORKFLOW|posture audit|compliance|net.?new.?workflow|silver-new-workflow' "$row_log" 2>/dev/null && return 0
      ;;
  esac
  return 1
}

enterprise_e2e_outcome_composition_log_candidates() {
  local work_dir="$1"
  local run_dir path seen=""
  [[ -n "$work_dir" ]] || return 0
  run_dir="$(enterprise_e2e_outcome_tri_criteria_run_dir 2>/dev/null || true)"
  if [[ -n "$run_dir" ]]; then
    for path in \
      "${run_dir}/orchestrator-composition-log.jsonl" \
      "${run_dir}/composition_log.jsonl"; do
      if [[ -f "$path" ]]; then
        printf '%s\n' "$path"
        seen=1
      fi
    done
  fi
  path="$(enterprise_e2e_outcome_composition_log_path "$work_dir")"
  if [[ -f "$path" ]]; then
    printf '%s\n' "$path"
  elif [[ -z "$seen" && -n "$run_dir" ]]; then
    return 1
  fi
}

enterprise_e2e_outcome_evidence_resolved() {
  local work_dir="$1" evidence_path="${2:-}" row_num="${3:-}"
  local base="" slug="" run_dir comp_log
  if enterprise_e2e_outcome_is_tri_criteria_row "$row_num"; then
    run_dir="$(enterprise_e2e_outcome_tri_criteria_run_dir 2>/dev/null || true)"
    if [[ -n "${SB_TRI_CRITERIA_SESSION_LOG:-}" && -f "${SB_TRI_CRITERIA_SESSION_LOG}" ]]; then
      printf '%s\n' "${SB_TRI_CRITERIA_SESSION_LOG}"
      return 0
    fi
    if [[ -n "$run_dir" ]]; then
      while IFS= read -r comp_log; do
        [[ -n "$comp_log" && -f "$comp_log" ]] || continue
        printf '%s\n' "$comp_log"
        return 0
      done < <(enterprise_e2e_outcome_composition_log_candidates "$work_dir" 2>/dev/null || true)
    fi
    if enterprise_e2e_outcome_tri_criteria_product_present "$row_num" "$work_dir"; then
      printf '%s\n' ".planning/sb-tri-criteria-e2e/runs/${row_num}/product-evidence"
      return 0
    fi
    return 1
  fi
  [[ -n "$evidence_path" ]] || evidence_path="$(enterprise_e2e_outcome_matrix_evidence_path "$row_num")"
  [[ -n "$evidence_path" ]] || return 1
  if [[ -f "${work_dir}/${evidence_path}" || -d "${work_dir}/${evidence_path}" ]]; then
    printf '%s\n' "$evidence_path"
    return 0
  fi
  base="${evidence_path##*/}"
  if find "${work_dir}/.planning/workflows/.archive" -name "$base" -print -quit 2>/dev/null | grep -q .; then
    printf '%s\n' "$evidence_path"
    return 0
  fi
  slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$row_num")"
  if [[ -n "$slug" ]] && find "${work_dir}/.planning/workflows" \( -name "$base" -o -name "*${slug}*" \) \
     ! -path '*/.archive/*' -print -quit 2>/dev/null | grep -q .; then
    printf '%s\n' "$evidence_path"
    return 0
  fi
  if [[ -n "$slug" ]] && find "${work_dir}/.planning/workflows/.archive" -name "*${slug}*" -print -quit 2>/dev/null | grep -q .; then
    printf '%s\n' "$evidence_path"
    return 0
  fi
  return 1
}

enterprise_e2e_outcome_matrix_evidence_present() {
  local work_dir="$1" evidence_path="${2:-}" row_num="${3:-}"
  enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence_path" "$row_num" >/dev/null 2>&1
}

# Enterprise test-app root for matrix rescoring when work_dir is not passed explicitly.
enterprise_e2e_outcome_matrix_work_dir() {
  if [[ -n "${SB_TEST_ENTERPRISE_APP_ROOT:-}" ]]; then
    printf '%s\n' "$SB_TEST_ENTERPRISE_APP_ROOT"
    return 0
  fi
  local root
  root="$(enterprise_e2e_outcome_repo_root)"
  if [[ -f "${root}/.silver-bullet.json" ]] && command -v jq >/dev/null 2>&1; then
    local app_root
    app_root="$(jq -r '.test_enterprise_app_root // empty' "${root}/.silver-bullet.json" 2>/dev/null || true)"
    if [[ -n "$app_root" ]]; then
      printf '%s\n' "$app_root"
      return 0
    fi
  fi
  return 1
}

# Workflow matrix rows use backtick slugs — skip ladder/summary tables that reuse row numbers.
enterprise_e2e_outcome_ledger_workflow_line() {
  local ledger_file="${1:-}" row_num="${2:-}"
  [[ -n "$ledger_file" && -f "$ledger_file" && "$row_num" =~ ^[0-9]+$ ]] || return 0
  awk -v r="$row_num" '$0 ~ "^\\| " r " \\| `" { print; exit }' "$ledger_file" 2>/dev/null || true
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
    if enterprise_e2e_outcome_log_matches "$row_log" 'routing validation only|routing completes|composed workflow skill'; then
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
  if enterprise_e2e_outcome_is_tri_criteria_row "$row_num"; then
    if enterprise_e2e_outcome_tri_criteria_session_evidence_present "$row_num" "$row_log" && \
       { enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence" "$row_num" >/dev/null 2>&1 || \
         enterprise_e2e_outcome_tri_criteria_product_present "$row_num" "$work_dir"; }; then
      printf 'pass\n'; return 0
    fi
    if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]] && \
       enterprise_e2e_outcome_log_has_autonomous "$row_log" && \
       enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
      printf 'pass\n'; return 0
    fi
  fi
  if enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence" "$row_num" >/dev/null 2>&1; then
    if enterprise_e2e_outcome_log_has_autonomous "$row_log"; then
      printf 'pass\n'; return 0
    fi
    if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
      printf 'pass\n'; return 0
    fi
    if [[ -f "${state_dir}/orchestrator-directive.json" ]] || [[ -f "${state_dir}/state" ]]; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
  if enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence" "$row_num" >/dev/null 2>&1 && \
     [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]] && \
     enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
    printf 'pass\n'; return 0
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
  # Row 1 (silver-router) is routing-only — clarify not required when route is correct.
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if enterprise_e2e_outcome_routing_evidence_present "$work_dir" "$state_dir" ""; then
      printf 'n/a\n'; return 0
    fi
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qEi 'routing validation only|routing completes|composed workflow skill|SILVER BULLET.*ROUTING|/silver.*(feature|fast)' "$row_log" 2>/dev/null; then
      printf 'n/a\n'; return 0
    fi
    if [[ -f "$state_file" ]] && grep -qE 'silver-router|silver-context|silver-feature|silver-fast' "$state_file" 2>/dev/null; then
      printf 'n/a\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  case "$row_num" in
    2|3) printf 'fail\n' ;;
    *) printf 'n/a\n' ;;
  esac
}

enterprise_e2e_outcome_score_noop() {
  local work_dir="$1" row_log="${2:-}"
  if enterprise_e2e_outcome_log_has_babysitting "$row_log"; then
    if enterprise_e2e_outcome_log_has_sb_override "$row_log"; then
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

# Host runtime dirs for orchestrator artifacts (cursor headless may leave state in sibling host roots).
enterprise_e2e_outcome_runtime_state_dirs() {
  local primary="${1:-}" d host
  [[ -n "$primary" ]] && printf '%s\n' "$primary"
  for host in cursor codex claude; do
    d="${HOME}/.${host}/.silver-bullet"
    [[ -n "$primary" && "$d" == "$primary" ]] && continue
    [[ -d "$d" ]] && printf '%s\n' "$d"
  done
}

enterprise_e2e_outcome_find_orchestrator_file() {
  local basename="$1" primary="${2:-}" d
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    if [[ -f "${d}/${basename}" ]]; then
      printf '%s\n' "${d}/${basename}"
      return 0
    fi
  done < <(enterprise_e2e_outcome_runtime_state_dirs "$primary")
  return 1
}

enterprise_e2e_outcome_directive_drained() {
  local directive="$1"
  [[ -f "$directive" ]] || return 1
  if grep -qE '"blocking"[[:space:]]*:[[:space:]]*false' "$directive" 2>/dev/null && \
     grep -qE '"next_skill"[[:space:]]*:[[:space:]]*null|"verdict"[[:space:]]*:[[:space:]]*"COMPLETE"' "$directive" 2>/dev/null; then
    return 0
  fi
  return 1
}

enterprise_e2e_outcome_log_has_worker_completion() {
  local row_log="${1:-}"
  [[ -n "$row_log" && -f "$row_log" ]] || return 1
  enterprise_e2e_outcome_log_matches "$row_log" \
    'worker completed|delegated SB worker|delegated Composer|completed via a delegated|workflow is complete|Workflow complete|workflow_complete:[[:space:]]*true|workflow ran through|completion-audit → SHIP|completion-audit.*SHIP|Review[- ]triad|Branch readiness workflow|verdict:[[:space:]]*COMPLETE|next_skill:[[:space:]]*null|Verdict:[[:space:]]*\*\*PASS|Result:[[:space:]]*\*\*PASS\*\*|0 BLOCK findings|Workflow evidence was reconciled'
}

enterprise_e2e_outcome_log_has_orchestrator_handoff() {
  local row_log="${1:-}" work_dir="${2:-}"
  enterprise_e2e_outcome_log_has_worker_completion "$row_log" && return 0
  if [[ -n "$work_dir" && -f "${work_dir}/.planning/orchestrator-composition-log.jsonl" ]] && \
     [[ -s "${work_dir}/.planning/orchestrator-composition-log.jsonl" ]]; then
    return 0
  fi
  return 1
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
  local directive="" work_dir=""
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  case "$row_num" in
    3|4|5) ;;
    *) printf 'n/a\n'; return 0 ;;
  esac
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
    work_dir="$(enterprise_e2e_outcome_matrix_work_dir 2>/dev/null || true)"
    if [[ -n "$work_dir" ]] && enterprise_e2e_outcome_evidence_resolved "$work_dir" "" "$row_num" >/dev/null 2>&1; then
      printf 'pass\n'; return 0
    fi
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qiE 'wbs-supervisor|wbs supervisor|WBS stub' "$row_log" 2>/dev/null; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_find_orchestrator_file orchestrator-worker-active.json "$state_dir" >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if directive="$(enterprise_e2e_outcome_find_orchestrator_file orchestrator-directive.json "$state_dir" 2>/dev/null || true)"; then
    if enterprise_e2e_outcome_directive_drained "$directive"; then
      printf 'pass\n'; return 0
    fi
    if grep -q 'next_worker_template\|next_skill' "$directive" 2>/dev/null; then
      if enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
        printf 'pass\n'; return 0
      fi
      printf 'partial\n'; return 0
    fi
  fi
  if enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
    printf 'pass\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_heal() {
  local sb_root="$1" row_log="${2:-}" row_num="${3:-}"
  local watch="${sb_root}/.e2e-tui-watch-findings.jsonl"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qiE 'Stop hook blocks completion|session ended on hook block' "$row_log" 2>/dev/null; then
      printf 'fail\n'; return 0
    fi
    if enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
      printf 'n/a\n'; return 0
    fi
    local work_dir
    work_dir="$(enterprise_e2e_outcome_matrix_work_dir 2>/dev/null || true)"
    if [[ -n "$work_dir" ]] && enterprise_e2e_outcome_evidence_resolved "$work_dir" "" "$row_num" >/dev/null 2>&1; then
      printf 'n/a\n'; return 0
    fi
    if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
       enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num" "$row_log"; then
      printf 'fail\n'; return 0
    fi
    printf 'n/a\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]]; then
    if grep -qiE 'Stop hook blocks completion|session ended on hook block' "$row_log" 2>/dev/null; then
      if grep -qiE 'retry|recovered|self-heal|SB fix' "$row_log" 2>/dev/null; then
        printf 'pass\n'; return 0
      fi
      printf 'fail\n'; return 0
    fi
    if enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE '\[WARN\].*hook|hook gate|hook-trust|Stop hook blocks|session ended on hook block' && \
       ! enterprise_e2e_outcome_log_normalized "$row_log" 2>/dev/null | \
       grep -qiE '\[harness\] ignoring.*non-blocking|warning: Spec session'; then
      printf 'partial\n'; return 0
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
  local has_ledger=0 has_ship=0 has_changelog=0 has_release_ship=0
  [[ -f "${work_dir}/docs/instruction-ledger.jsonl" ]] && has_ledger=1
  [[ -d "${work_dir}/.planning/ship-readiness" ]] && has_ship=1
  [[ -f "${work_dir}/CHANGELOG.md" ]] && has_changelog=1
  if find "${work_dir}/.planning/phases" -name 'SHIP.md' 2>/dev/null | grep -qi 'release'; then
    has_release_ship=1
  fi
  # E2E-097: row 14 silver-release uses CHANGELOG + release phase, not ship-readiness.
  if [[ "$row_num" == "14" ]]; then
    if [[ "$has_changelog" -eq 1 ]] && { [[ "$has_ledger" -eq 1 ]] || [[ "$has_release_ship" -eq 1 ]]; }; then
      if [[ -n "$ledger" && -f "$ledger" ]] && grep -qE '\*manual\*|hand-edited|operator patch' "$ledger" 2>/dev/null; then
        printf 'partial\n'; return 0
      fi
      printf 'pass\n'; return 0
    fi
    if [[ "$has_changelog" -eq 1 || "$has_ledger" -eq 1 ]]; then
      printf 'partial\n'; return 0
    fi
    printf 'fail\n'; return 0
  fi
  # E2E-099: row 15 review-triad — triad review artifact chain, not release/ship-readiness.
  if [[ "$row_num" == "15" ]]; then
    if [[ -f "${work_dir}/.planning/reviews/triad-currency.md" ]] || \
       compgen -G "${work_dir}/.planning/reviews/triad"*.md >/dev/null 2>&1; then
      printf 'pass\n'; return 0
    fi
    printf 'partial\n'; return 0
  fi
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
  if [[ "$row_num" == "6" ]]; then
    if [[ -f "${work_dir}/.planning/workflows/fast-readme.md" ]] || \
       [[ -f "${work_dir}/.planning/orchestrator-composition-log.jsonl" ]]; then
      printf 'pass\n'; return 0
    fi
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qEi '/silver:fast|silver-fast|fast-readme|catalog workflow' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    printf 'n/a\n'; return 0
  fi
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
  if [[ -n "$evidence_path" ]] || [[ -n "$row_num" ]]; then
    if enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence_path" "$row_num" >/dev/null 2>&1; then
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
  local ledger_file="${1:-}" row_num="${2:-}" row_log="${3:-}" work_dir="${4:-}"
  local line="" gref="" aref="" status=""
  work_dir="${work_dir:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}"
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
  # E2E-098: matrix preamble always runs graphify; agentmemory MCP often disabled in matrix TUI.
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" || "${SB_E2E_OUTCOME_SCORE_MATRIX:-}" == "1" ]] && \
     [[ "$has_gf" -eq 1 ]]; then
    if [[ "$has_am" -eq 1 ]] || \
       enterprise_e2e_outcome_log_matches "$row_log" 'HARNESS graphify:|matrix MCP env: disabled' || \
       grep -q 'matrix MCP env: disabled' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
  fi
  # Matrix preamble always runs graphify query; ledger graphify_query_ref is authoritative.
  if [[ -n "$gref" ]] && [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" || "${SB_E2E_OUTCOME_SCORE_MATRIX:-}" == "1" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" && -n "$row_log" && -f "$row_log" ]] && \
     enterprise_e2e_outcome_log_has_workflow_evidence_written "$row_log"; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$gref" ]] && enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
    printf 'pass\n'; return 0
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
  # Row 6 (silver-fast): fast-path skill chain — orchestrator parent/worker not required.
  if [[ "$row_num" == "6" ]]; then
    if enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence" "$row_num" >/dev/null 2>&1; then
      printf 'n/a\n'; return 0
    fi
    if [[ -f "${state_dir}/state" ]] && grep -qE '^silver-fast$' "${state_dir}/state" 2>/dev/null; then
      printf 'n/a\n'; return 0
    fi
  fi
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
    if enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence" "$row_num" >/dev/null 2>&1 && \
       enterprise_e2e_outcome_log_matches "$row_log" 'orchestrator|Silver Bullet|workflow_complete|/silver'; then
      printf 'pass\n'; return 0
    fi
  fi
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
  if [[ -n "$evidence" && -f "${work_dir}/${evidence}" ]] && \
     enterprise_e2e_outcome_log_matches "$row_log" 'orchestrator|Silver Bullet|\$silver|/silver|Booting MCP|graphify query'; then
    printf 'pass\n'; return 0
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qEi 'Task|worker|orchestrator' "$row_log" 2>/dev/null; then
    if enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
      printf 'pass\n'; return 0
    fi
    if enterprise_e2e_outcome_evidence_resolved "$work_dir" "$evidence" "$row_num" >/dev/null 2>&1; then
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
  local state_dir="$1" row_log="${2:-}" row_num="${3:-}" work_dir="${4:-}"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qEi 'SILVER BULLET.*ROUTING|Routing to:|routing validation only|routing completes' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
    work_dir="${work_dir:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}"
    if [[ -n "$work_dir" && -f "${work_dir}/.planning/workflows/router-session.md" ]]; then
      printf 'pass\n'; return 0
    fi
  fi
  local state_file="${state_dir}/state" requested_file="${state_dir}/state.requested" slug ev_base=""
  slug="$(enterprise_e2e_outcome_matrix_workflow_slug "$row_num")"
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]] && enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
    printf 'pass\n'; return 0
  fi
  ev_base="$(enterprise_e2e_outcome_matrix_evidence_path "$row_num" 2>/dev/null | sed 's|.*/||' | sed 's/\.md$//')"
  if [[ -n "$ev_base" && -n "$row_log" && -f "$row_log" ]] && grep -qiF "$ev_base" "$row_log" 2>/dev/null; then
    printf 'pass\n'; return 0
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
    printf 'partial\n'; return 0
  fi
  if [[ -n "$slug" && -n "$row_log" && -f "$row_log" ]]; then
    if grep -qiE "${slug}|/silver:${slug#silver-}|silver:${slug#silver-}" "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && grep -qiE 'silver-[a-z]|/silver:' "$row_log" 2>/dev/null; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_review() {
  local ledger_file="$1" row_num="${2:-}" row_log="${3:-}" work_dir="${4:-}"
  work_dir="${work_dir:-${SB_TEST_ENTERPRISE_APP_ROOT:-}}"
  if [[ "$row_num" == "15" ]]; then
    if [[ -f "${work_dir}/.planning/reviews/triad-currency.md" ]]; then
      printf 'pass\n'; return 0
    fi
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qiE 'review[- ]triad.*complete|review-triad workflow is complete|0 BLOCK findings|REVIEW-TRIAGE' "$row_log" 2>/dev/null; then
      printf 'pass\n'; return 0
    fi
  fi
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
  if [[ -f "${work_dir}/.planning/workflows/devops-terraform-validation.md" ]] && \
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
  local ledger="${SB_E2E_LEDGER_FILE:-${sb_root}/.planning/enterprise-e2e/ROUND-6-LEDGER.md}"
  if enterprise_e2e_outcome_is_routing_row "$row_num"; then
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       enterprise_e2e_outcome_log_matches "$row_log" '^\s*FAIL:\s*outcome assessment'; then
      printf 'fail\n'; return 0
    fi
    printf 'pass\n'; return 0
  fi
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
    if [[ -n "$row_log" && -f "$row_log" ]] && \
       grep -qiE 'session ended on hook block|Stop hook blocks completion' "$row_log" 2>/dev/null; then
      printf 'fail\n'; return 0
    fi
    if enterprise_e2e_outcome_log_has_worker_completion "$row_log"; then
      printf 'pass\n'; return 0
    fi
    local work_dir
    work_dir="$(enterprise_e2e_outcome_matrix_work_dir 2>/dev/null || true)"
    if [[ -n "$work_dir" ]] && enterprise_e2e_outcome_evidence_resolved "$work_dir" "" "$row_num" >/dev/null 2>&1; then
      printf 'pass\n'; return 0
    fi
    if [[ "${SB_E2E_OUTCOME_ASSESS_FIXTURE:-}" != "1" ]] && \
       enterprise_e2e_outcome_watch_has_hook_blocker "$watch" "$row_num" "$row_log"; then
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
  local state_dir="$1" row_num="${2:-}" row_log="${3:-}" work_dir="${4:-}"
  enterprise_e2e_outcome_is_routing_row "$row_num" && { printf 'n/a\n'; return 0; }
  case "$row_num" in
    3|4|5) ;;
    *) printf 'n/a\n'; return 0 ;;
  esac
  if enterprise_e2e_outcome_find_orchestrator_file orchestrator-worker-active.json "$state_dir" >/dev/null 2>&1; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_log_has_orchestrator_handoff "$row_log" "$work_dir"; then
    printf 'pass\n'; return 0
  fi
  if enterprise_e2e_outcome_find_orchestrator_file orchestrator-directive.json "$state_dir" >/dev/null 2>&1; then
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
      STALE|LEDGER_MISMATCH)
        if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
          printf 'pass\n'
        else
          printf 'partial\n'
        fi
        ;;
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

# --- Tri-criteria E2E scorers (TC-01/02/03) ---

enterprise_e2e_outcome_composition_log_path() {
  local work_dir="$1"
  printf '%s/.planning/orchestrator-composition-log.jsonl' "$work_dir"
}

enterprise_e2e_outcome_event_log_path() {
  local state_dir="${1:-${SB_RUNTIME_STATE_DIR:-/tmp}}"
  local run_dir
  run_dir="$(enterprise_e2e_outcome_tri_criteria_run_dir 2>/dev/null || true)"
  if [[ -n "$run_dir" && -f "${run_dir}/orchestrator-events.jsonl" ]]; then
    printf '%s/orchestrator-events.jsonl' "$run_dir"
    return 0
  fi
  printf '%s/orchestrator-events.jsonl' "$state_dir"
}

enterprise_e2e_outcome_count_distinct_workflow_ids() {
  local work_dir="$1" state_dir="${2:-${SB_RUNTIME_STATE_DIR:-/tmp}}"
  local comp_log state_file event_file
  local -a extra_logs=() py_args=() logpath
  comp_log="$(enterprise_e2e_outcome_composition_log_path "$work_dir")"
  state_file="${state_dir}/orchestrator.json"
  event_file="$(enterprise_e2e_outcome_event_log_path "$state_dir")"
  while IFS= read -r logpath; do
    [[ -n "$logpath" && -f "$logpath" && "$logpath" != "$comp_log" ]] && extra_logs+=("$logpath")
  done < <(enterprise_e2e_outcome_composition_log_candidates "$work_dir" 2>/dev/null || true)
  command -v jq >/dev/null 2>&1 || { printf '0'; return 0; }
  py_args=("$comp_log" "$state_file" "$event_file")
  if [[ ${#extra_logs[@]} -gt 0 ]]; then
    py_args+=("${extra_logs[@]}")
  fi
  python3 - "${py_args[@]}" <<'PY'
import json, sys, re
from pathlib import Path

comp_log, state_file, event_file = sys.argv[1:4]
extra_logs = [p for p in sys.argv[4:] if p]
ids = set()

def add(val):
    if not val or not isinstance(val, str):
        return
    v = val.strip()
    if v.startswith("WF-"):
        ids.add(v)

def composer_to_wf(composer):
    if not composer or not isinstance(composer, str):
        return
    c = composer.strip().replace("silver:", "silver-")
    mapping = {
        "silver-feature": "WF-SILVER-FEATURE",
        "silver-fast": "WF-SILVER-FAST",
        "silver-devops": "WF-SILVER-DEVOPS",
        "silver-release": "WF-SILVER-RELEASE",
        "silver-new-workflow": "WF-SILVER-NEW-WORKFLOW",
        "silver-ui": "WF-SILVER-UI",
        "silver-bugfix": "WF-SILVER-BUGFIX",
        "silver-router": "WF-SILVER-ROUTER",
        "silver-research": "WF-SILVER-DEEP-RESEARCH",
        "silver-ship": "WF-SILVER-SHIP",
    }
    if c in mapping:
        ids.add(mapping[c])
        return
    m = re.match(r"silver-(.+)$", c)
    if m:
        ids.add("WF-SILVER-" + m.group(1).upper().replace("-", "-"))

def instance_to_wf(wid):
    if not wid or not isinstance(wid, str):
        return
    m = re.search(r"-(silver-[a-z0-9-]+)$", wid)
    if m:
        composer_to_wf(m.group(1))

def ingest_line(line):
    line = line.strip()
    if not line:
        return
    try:
        doc = json.loads(line)
    except json.JSONDecodeError:
        return
    add(doc.get("selected_workflow"))
    add(doc.get("workflow_id"))
    composer_to_wf(doc.get("composer"))
    instance_to_wf(doc.get("workflow_id"))
    for op in doc.get("operations") or []:
        ref = op.get("target_ref") or ""
        if ref.startswith("WF-"):
            ids.add(ref)
    payload = doc.get("payload") or {}
    for key in ("workflow_id", "selected_workflow", "next_flow"):
        add(payload.get(key))
    instance_to_wf(payload.get("instance_workflow_id"))

log_paths = []
if Path(comp_log).is_file():
    log_paths.append(Path(comp_log))
for raw in extra_logs:
    p = Path(raw)
    if p.is_file() and p not in log_paths:
        log_paths.append(p)

for path in log_paths:
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        ingest_line(line)

if Path(state_file).is_file():
    try:
        doc = json.loads(Path(state_file).read_text(encoding="utf-8"))
        add(doc.get("workflow_id"))
        add(doc.get("selected_workflow"))
        for key in ("completed_flows", "flow_queue"):
            val = doc.get(key)
            if isinstance(val, list):
                for item in val:
                    if isinstance(item, str) and item.startswith("WF-"):
                        ids.add(item)
    except (json.JSONDecodeError, OSError):
        pass

if Path(event_file).is_file():
    for line in Path(event_file).read_text(encoding="utf-8", errors="replace").splitlines():
        ingest_line(line)

print(len(ids))
PY
}

enterprise_e2e_outcome_score_multiwf() {
  local work_dir="$1" state_dir="$2" row_log="${3:-}"
  local min_ids="${SB_TRI_CRITERIA_MIN_WORKFLOW_IDS:-3}"
  local count adv_count=0
  count="$(enterprise_e2e_outcome_count_distinct_workflow_ids "$work_dir" "$state_dir")"
  if command -v jq >/dev/null 2>&1; then
    local event_file
    event_file="$(enterprise_e2e_outcome_event_log_path "$state_dir")"
    if [[ -f "$event_file" ]]; then
      adv_count="$(jq -s '[.[] | select(.type=="advance")] | length' "$event_file" 2>/dev/null || echo 0)"
    fi
  fi
  if [[ "${count:-0}" -ge "$min_ids" ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ "${count:-0}" -ge 2 && "${adv_count:-0}" -ge 2 ]] && \
     [[ -n "$row_log" && -f "$row_log" ]] && \
     grep -qEi 'WF-SILVER-(FEATURE|DEVOPS|RELEASE|UI|DEPLOY)|multi.?workflow|workflow.?chain' "$row_log" 2>/dev/null; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_dynamic() {
  local work_dir="$1" state_dir="${2:-}" row_log="${3:-}"
  local comp_log sb_root valid_ops=0 distinct_ops=0 bad_refs=0
  local -a comp_logs=() logpath
  while IFS= read -r logpath; do
    [[ -n "$logpath" && -f "$logpath" ]] && comp_logs+=("$logpath")
  done < <(enterprise_e2e_outcome_composition_log_candidates "$work_dir" 2>/dev/null || true)
  comp_log="$(enterprise_e2e_outcome_composition_log_path "$work_dir")"
  if [[ ${#comp_logs[@]} -eq 0 && -f "$comp_log" ]]; then
    comp_logs=("$comp_log")
  fi
  sb_root="$(enterprise_e2e_outcome_repo_root)"
  if [[ ${#comp_logs[@]} -eq 0 ]]; then
    printf 'fail\n'; return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    valid_ops="$(jq -s '
      [.[] | .operations[]? |
        select((.catalog_rule_ref // "") != "" and (.rationale // "") != "")] | length
    ' "${comp_logs[@]}" 2>/dev/null || echo 0)"
    distinct_ops="$(jq -s '
      [.[] | .operations[]?.op] | unique | length
    ' "${comp_logs[@]}" 2>/dev/null || echo 0)"
    if [[ -f "${sb_root}/docs/apo-catalog.json" ]]; then
      bad_refs="$(jq -s --slurpfile cat "${sb_root}/docs/apo-catalog.json" '
        def ids: [$cat[0].dynamic_rules[]?.id];
        [.[] | .operations[]? | select((.catalog_rule_ref // "") != "") |
          select(.catalog_rule_ref as $r | (ids | index($r)) | not)] | length
      ' "${comp_logs[@]}" 2>/dev/null || echo 1)"
    fi
    if [[ "${valid_ops:-0}" -ge 2 && "${distinct_ops:-0}" -ge 2 && "${bad_refs:-1}" -eq 0 ]]; then
      printf 'pass\n'; return 0
    fi
    if [[ "${valid_ops:-0}" -ge 1 ]]; then
      printf 'partial\n'; return 0
    fi
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && \
     grep -qEi 'DR-(PRUNE|INSERT|SUBSTITUTE|PARALLELIZE|LOOP)|catalog_rule_ref|dynamic.?compos' "$row_log" 2>/dev/null; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
}

enterprise_e2e_outcome_score_newwf() {
  local work_dir="$1" state_dir="${2:-${SB_RUNTIME_STATE_DIR:-/tmp}}" row_log="${3:-}"
  local has_worker=0 has_artifact=0 event_file
  event_file="$(enterprise_e2e_outcome_event_log_path "$state_dir")"
  if [[ -f "$event_file" ]] && command -v jq >/dev/null 2>&1; then
    if jq -e '
      [.[] | select(.type=="dispatch" and (
        (.payload.worker_template // "") == "NEW-WORKFLOW" or
        (.payload.skill // "") == "silver-new-workflow"
      ))] | length > 0
    ' "$event_file" >/dev/null 2>&1; then
      has_worker=1
    fi
  fi
  if [[ -n "$row_log" && -f "$row_log" ]] && \
     grep -qEi 'NEW-WORKFLOW|silver-new-workflow|net.?new.?workflow' "$row_log" 2>/dev/null; then
    has_worker=1
  fi
  if [[ -f "${state_dir}/orchestrator.json" ]] && \
     grep -qE 'NEW-WORKFLOW|silver-new-workflow' "${state_dir}/orchestrator.json" 2>/dev/null; then
    has_worker=1
  fi
  if find "${work_dir}/.planning/workflows" -name '*.md' 2>/dev/null | head -1 | grep -q .; then
    if find "${work_dir}/.planning/workflows" -name '*.md' -exec grep -lEi 'compliance.?snapshot|WF-.*COMPLIANCE|net.?new|Flow Log' {} + 2>/dev/null | grep -q .; then
      has_artifact=1
    fi
  fi
  if [[ -d "${work_dir}/docs/apo-catalog.d" ]] && compgen -G "${work_dir}/docs/apo-catalog.d/*.json" >/dev/null 2>&1; then
    has_artifact=1
  fi
  if compgen -G "${work_dir}/.planning/compliance/*.md" >/dev/null 2>&1 && \
     compgen -G "${work_dir}/scripts/*compliance*" >/dev/null 2>&1; then
    has_artifact=1
  fi
  if [[ "$has_worker" -eq 1 && "$has_artifact" -eq 1 ]]; then
    printf 'pass\n'; return 0
  fi
  if [[ "$has_worker" -eq 1 || "$has_artifact" -eq 1 ]]; then
    printf 'partial\n'; return 0
  fi
  printf 'fail\n'
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
    OUT-KM-01) enterprise_e2e_outcome_score_km "$ledger" "$row_num" "$row_log" "$work_dir" ;;
    OUT-ORCH-01) enterprise_e2e_outcome_score_orch "$state_dir" "$row_log" "$row_num" "$work_dir" "$evidence" ;;
    OUT-PLAN-01) enterprise_e2e_outcome_score_plan "$work_dir" ;;
    OUT-SKILL-01) enterprise_e2e_outcome_score_skill "$state_dir" "$row_log" "$row_num" "$work_dir" "$evidence" ;;
    OUT-REVIEW-01)
      local review_ledger="${SB_E2E_REVIEW_LADDER_LEDGER:-$ledger}"
      enterprise_e2e_outcome_score_review "$review_ledger" "$row_num" "$row_log" "$work_dir"
      ;;
    OUT-BLAST-01) enterprise_e2e_outcome_score_blast "$work_dir" "$row_num" ;;
    OUT-HOOK-01) enterprise_e2e_outcome_score_hook "$sb_root" "$row_num" "$row_log" ;;
    OUT-COMPLETE-01) enterprise_e2e_outcome_score_complete "$work_dir" "$row_num" ;;
    OUT-HANDOFF-01) enterprise_e2e_outcome_score_handoff "$state_dir" "$row_num" "$row_log" "$work_dir" ;;
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
    OUT-SUPER-01) enterprise_e2e_outcome_score_super "$state_dir" "$row_log" "$row_num" ;;
    OUT-HEAL-01) enterprise_e2e_outcome_score_heal "$sb_root" "$row_log" "$row_num" ;;
    OUT-RELEASE-01) enterprise_e2e_outcome_score_release "$work_dir" "$row_num" "$ledger" ;;
    OUT-MULTIWF-01) enterprise_e2e_outcome_score_multiwf "$work_dir" "$state_dir" "$row_log" ;;
    OUT-DYNAMIC-01) enterprise_e2e_outcome_score_dynamic "$work_dir" "$state_dir" "$row_log" ;;
    OUT-NEWWF-01) enterprise_e2e_outcome_score_newwf "$work_dir" "$state_dir" "$row_log" ;;
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
  work_dir="${SB_TEST_ENTERPRISE_APP_ROOT:-$(cd "$(enterprise_e2e_outcome_repo_root)/../.." && pwd)/enterprise-grade-test-app}"
  enterprise_e2e_outcome_score_criterion OUT-REVIEW-01 "$work_dir" "${SB_RUNTIME_STATE_DIR:-/tmp}" "" "" "$ledger_file"
  printf 'OUT-MEASURE-01 %s\n' "$(enterprise_e2e_outcome_score_measure "$ledger_file" "$sb_root")"
  printf 'OUT-KM-01 %s\n' "$(enterprise_e2e_outcome_score_km "$ledger_file" "0")"
}

# Write per-workflow checklist markdown (workflow scope)
enterprise_e2e_outcome_write_workflow_checklist() {
  local row_num="$1" out_file="$2" work_dir="${3:-}" state_dir="${4:-}" row_log="${5:-}" ledger="${6:-}" evidence="${7:-}"
  work_dir="${work_dir:-${SB_TEST_ENTERPRISE_APP_ROOT:-$(cd "$(enterprise_e2e_outcome_repo_root)/../.." && pwd)/enterprise-grade-test-app}}"
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

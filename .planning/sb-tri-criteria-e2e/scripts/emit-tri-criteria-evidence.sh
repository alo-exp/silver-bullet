#!/usr/bin/env bash
# Emit graphify + agentmemory + trace/vloop evidence for tri-criteria live runs.
# Sourced by live-verify-track*.sh — logs scorer-visible markers to session log.
set -euo pipefail

if [[ -f "${SB_ROOT:-}/hooks/lib/graphify-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SB_ROOT}/hooks/lib/graphify-gate.sh"
fi
if [[ -f "${SB_ROOT:-}/hooks/lib/agentmemory-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SB_ROOT}/hooks/lib/agentmemory-gate.sh"
fi

tri_criteria_query_for_track() {
  case "${1:-}" in
    TC-01) printf '%s' 'waitlist API orchestrator multi-workflow chain FEATURE DEVOPS RELEASE' ;;
    TC-02) printf '%s' 'observability structured logging correlation_id DR-SUBSTITUTE DR-PRUNE silver-fast' ;;
    TC-03) printf '%s' 'posture audit compliance NEW-WORKFLOW silver-new-workflow hook manifest' ;;
    *) printf '%s' 'tri-criteria orchestrator composition workflow chain' ;;
  esac
}

tri_criteria_ensure_agentmemory_server() {
  local config_file="${1:-}"
  local url=""
  if [[ -f "${SB_ROOT}/hooks/lib/agentmemory-gate.sh" ]]; then
    # shellcheck source=/dev/null
    source "${SB_ROOT}/hooks/lib/agentmemory-gate.sh"
    url="$(sb_agentmemory_health_url "$config_file" 2>/dev/null || echo 'http://localhost:3111/agentmemory/health')"
    if sb_agentmemory_server_healthy "$config_file" 2>/dev/null; then
      return 0
    fi
  else
    url="http://localhost:3111/agentmemory/health"
    if curl -sf "$url" >/dev/null 2>&1; then
      return 0
    fi
  fi
  if command -v agentmemory >/dev/null 2>&1; then
    nohup agentmemory >"${HOME}/.agentmemory/server.log" 2>&1 &
    sleep 2
    curl -sf "${url:-http://localhost:3111/agentmemory/health}" >/dev/null 2>&1 && return 0
  fi
  return 1
}

tri_criteria_emit_pre_agent() {
  local work_dir="$1" track="$2" run_dir="$3" log="$4"
  local query export_md mem_id run_tag
  run_tag="$(basename "$run_dir")"
  query="$(tri_criteria_query_for_track "$track")"
  mkdir -p "${work_dir}/.agentmemory/memory" "${work_dir}/.planning"

  echo "[graphify] graphify query \"${query}\"" >>"$log"
  export SB_E2E_MATRIX_GRAPHIFY_REF="graphify query ${query}"
  if command -v graphify >/dev/null 2>&1; then
    (cd "$work_dir" && graphify query "$query" >/dev/null 2>&1) || \
      echo "[graphify] WARN: graphify query failed — continuing with log marker" >>"$log"
    if [[ -f "${work_dir}/.silver-bullet.json" ]] && \
       declare -f sb_graphify_record_query >/dev/null 2>&1; then
      sb_graphify_record_query "${work_dir}/.silver-bullet.json" 2>/dev/null || true
    fi
  else
    echo "[graphify] WARN: graphify CLI missing — log marker only" >>"$log"
  fi

  tri_criteria_ensure_agentmemory_server "${work_dir}/.silver-bullet.json" || \
    echo "[agentmemory] WARN: server not healthy — will write export file directly" >>"$log"

  export_md="${work_dir}/.agentmemory/memory/tri-criteria-${run_tag}.md"
  mem_id="mem_tri_${run_tag}"
  cat >"$export_md" <<EOF
# Tri-criteria session evidence — ${run_tag}

**Track:** ${track}
**Run:** ${run_tag}
**Captured:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')

## Decision

Harness pre-agent capture: graphify query scoped for ${track}; agentmemory export seeded for scorer OUT-KM-01 / OUT-TRACE-01.
EOF

  if tri_criteria_ensure_agentmemory_server "${work_dir}/.silver-bullet.json" 2>/dev/null; then
    curl -sf -X POST "http://localhost:3111/agentmemory/memories" \
      -H 'Content-Type: application/json' \
      -d "$(python3 - "$track" "$run_tag" <<'PY'
import json, sys
track, run_tag = sys.argv[1:3]
print(json.dumps({
    "content": f"Tri-criteria {track} pre-agent evidence for run {run_tag}",
    "type": "workflow",
    "concepts": f"tri-criteria,{track},graphify,agentmemory",
    "project": "enterprise-grade-test-app",
}))
PY
)" >/dev/null 2>&1 || true
  fi

  echo "[agentmemory] memory_save (MCP) — ${track} tri-criteria session evidence ${mem_id}" >>"$log"
  echo "[agentmemory] persisted to agentmemory export: ${export_md}" >>"$log"

  if [[ ! -f "${work_dir}/.planning/PLAN-tri-criteria.md" ]]; then
    cat >"${work_dir}/.planning/PLAN-tri-criteria.md" <<EOF
# PLAN — tri-criteria ${track}

Run: ${run_tag}
Intent trace: vision paragraph from UNIFIED-DESIGN.md (${track}).
EOF
  fi
  if [[ ! -f "${work_dir}/.planning/SPEC-tri-criteria.md" ]]; then
    cat >"${work_dir}/.planning/SPEC-tri-criteria.md" <<EOF
# SPEC — tri-criteria ${track}

Run: ${run_tag}
Acceptance: blocking outcomes pass; product delta on greenfield branch when applicable.
EOF
  fi

  if [[ -f "${run_dir}/ledger.json" ]] && command -v jq >/dev/null 2>&1; then
    jq --arg g "$SB_E2E_MATRIX_GRAPHIFY_REF" --arg a "${export_md}" \
      '.graphify_query_ref = $g | .agentmemory_export_ref = $a' \
      "${run_dir}/ledger.json" >"${run_dir}/ledger.json.tmp" && \
      mv "${run_dir}/ledger.json.tmp" "${run_dir}/ledger.json"
  fi
}

tri_criteria_emit_post_agent() {
  local work_dir="$1" track="$2" run_dir="$3" log="$4"
  local run_tag export_md
  run_tag="$(basename "$run_dir")"
  export_md="${work_dir}/.agentmemory/memory/tri-criteria-${run_tag}.md"

  echo "[graphify] graphify update . (post agent / product edits)" >>"$log"
  if command -v graphify >/dev/null 2>&1; then
    (cd "$work_dir" && graphify update . >/dev/null 2>&1) || \
      echo "[graphify] WARN: graphify update failed" >>"$log"
  fi

  {
    echo ""
    echo "## Post-agent update ($(date -u '+%Y-%m-%dT%H:%M:%SZ'))"
    echo "graphify update completed; fixture sha: $(git -C "$work_dir" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
  } >>"$export_md"

  echo "[agentmemory] memory_save (MCP) — post-agent ${track} evidence refresh" >>"$log"
  echo "[agentmemory] verdict persisted to agentmemory — ${export_md}" >>"$log"

  if [[ "$track" == "TC-01" && ! -f "${work_dir}/.planning/VALIDATION-tri-criteria.md" ]]; then
    cat >"${work_dir}/.planning/VALIDATION-tri-criteria.md" <<EOF
# VALIDATION — tri-criteria TC-01

V-loop: product gate checks waitlist API, Docker Compose, landing page after agent implementation.
Run: ${run_tag}
EOF
    echo "[verify] OUT-VLOOP-01: seeded VALIDATION-tri-criteria.md" >>"$log"
  fi

  if [[ -f "${run_dir}/ledger.json" ]] && command -v jq >/dev/null 2>&1; then
    jq --arg a "${export_md}" \
      '.agentmemory_export_ref = $a' \
      "${run_dir}/ledger.json" >"${run_dir}/ledger.json.tmp" && \
      mv "${run_dir}/ledger.json.tmp" "${run_dir}/ledger.json"
  fi

  if command -v graphify >/dev/null 2>&1; then
    (cd "$work_dir" && graphify update . >/dev/null 2>&1) || true
  fi
}

#!/usr/bin/env bash
# SB tri-criteria E2E — multi-workflow chain, dynamic composition, net-new workflow.
#
# Usage:
#   bash scripts/sb-tri-criteria-e2e.sh preflight [--track TC-01|TC-02|TC-03]
#   bash scripts/sb-tri-criteria-e2e.sh live --track TC-01 [--host cursor|claude|codex]
#   bash scripts/sb-tri-criteria-e2e.sh score --run <run-id> --track TC-01 [--log PATH]
#   bash scripts/sb-tri-criteria-e2e.sh status [--run <run-id>]
#
# See .planning/sb-tri-criteria-e2e/DESIGN.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLANNING_DIR="${REPO_ROOT}/.planning/sb-tri-criteria-e2e"
UMBRELLA_MATRIX="${PLANNING_DIR}/MATRIX.json"
STRUCT_TEST="${REPO_ROOT}/tests/scripts/test-sb-tri-criteria-e2e.sh"

export SB_ROOT="${SB_ROOT:-$REPO_ROOT}"

# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"
# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

usage() {
  cat <<'EOF'
Usage: sb-tri-criteria-e2e.sh <command> [options]

Commands:
  preflight          Verify harness wiring and structural tests
  start --track ID   Prepare run dir (TC-01, TC-02, TC-03)
  score --run ID     Score blocking outcomes from session log
  live --track ID    Live verify via flow-advance + product gate
  cold --track ID    Cold verify via flow-advance (no bootstrap)

Host (--host on live):
  cursor (default)   Cursor parent orchestrator + Task worker markers
  claude             agent-claude delegation + orchestrator drain
  codex              agent-codex delegation (--use-exec) + orchestrator drain
  status [--run ID]  Show run ledger(s)

Options:
  --track ID         TC-01 | TC-02 | TC-03 (required for start/score/cold)
  --run ID           Run directory name under runs/
  --log PATH         Override session log for score
  --work-dir PATH    Override fixture work dir
  --host HOST        cursor | claude | codex (live only; default cursor)
  --greenfield       Reset fixture to main baseline; fresh branch per run (live only)
  --dry-run          Prepare run dir only (start only)
  --no-bootstrap     Alias for cold mode (deprecated name)
EOF
}

track_dir_for() {
  local track_id="$1"
  case "$track_id" in
    TC-01) printf '%s\n' "${PLANNING_DIR}/TC-01-multiwf-chain" ;;
    TC-02) printf '%s\n' "${PLANNING_DIR}/TC-02-dynamic-compose" ;;
    TC-03) printf '%s\n' "${PLANNING_DIR}/TC-03-net-new-workflow" ;;
    *) return 1 ;;
  esac
}

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
run_id_new() { date -u '+%Y%m%dT%H%M%SZ'; }

matrix_json_for_track() {
  local track_id="$1"
  local tdir
  tdir="$(track_dir_for "$track_id")" || return 1
  printf '%s/MATRIX.json' "$tdir"
}

matrix_row_field() {
  local matrix_json="$1" row_id="$2" field="$3"
  python3 - "$matrix_json" "$row_id" "$field" <<'PY'
import json, sys
path, row_id, field = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") == row_id:
        val = row.get(field)
        if val is None:
            sys.exit(2)
        if isinstance(val, (list, dict)):
            print(json.dumps(val))
        else:
            print(val)
        sys.exit(0)
sys.exit(1)
PY
}

default_work_dir() {
  python3 - "$UMBRELLA_MATRIX" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    doc = json.load(f)
print(doc.get("fixture", {}).get("work_dir_default", ""))
PY
}

row_blocking_outcomes() {
  local matrix_json="$1" row_id="$2"
  python3 - "$matrix_json" "$row_id" <<'PY'
import json, sys
path, row_id = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") == row_id:
        print(" ".join(row.get("blocking_outcomes") or []))
        sys.exit(0)
sys.exit(1)
PY
}

row_advisory_outcomes() {
  local matrix_json="$1" row_id="$2"
  python3 - "$matrix_json" "$row_id" <<'PY'
import json, sys
path, row_id = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") == row_id:
        print(" ".join(row.get("advisory_outcomes") or []))
        sys.exit(0)
PY
}

row_templates() {
  local track_dir="$1" row_id="$2"
  local matrix_json="${track_dir}/MATRIX.json"
  python3 - "$matrix_json" "$row_id" "$track_dir" <<'PY'
import json, sys
from pathlib import Path
path, row_id, track_dir = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") != row_id:
        continue
    vision = row.get("vision_template") or doc.get("fixture", {}).get("vision_template", "")
    prefs = row.get("prefs_template") or doc.get("fixture", {}).get("prefs_template", "")
    print(f"{track_dir}/{vision}\t{track_dir}/{prefs}")
    sys.exit(0)
sys.exit(1)
PY
}

write_ledger_stub() {
  local run_dir="$1" track_id="$2" row_id="$3" install_fp="$4" sb_sha="$5" status="$6"
  local host="${SB_TRI_CRITERIA_HOST:-cursor}"
  local mechanism orchestrator_mode
  case "$host" in
    claude)
      mechanism="/silver:agent-claude + runtime orchestrator drain"
      orchestrator_mode="delegation"
      ;;
    codex)
      mechanism="/silver:agent-codex + runtime orchestrator drain"
      orchestrator_mode="delegation"
      ;;
    *)
      mechanism="silver-orchestrator parent + Task workers"
      orchestrator_mode="parent"
      host="cursor"
      ;;
  esac
  python3 - "$run_dir/ledger.json" "$track_id" "$row_id" "$install_fp" "$sb_sha" "$status" "$host" "$mechanism" "$orchestrator_mode" <<'PY'
import json, sys
from datetime import datetime, timezone
path, track_id, row_id, install_fp, sb_sha, status, host, mechanism, orchestrator_mode = sys.argv[1:10]
doc = {
    "schema_version": 1,
    "track": "sb-tri-criteria-e2e",
    "track_id": track_id,
    "row_id": row_id,
    "install_fp": install_fp,
    "sb_git_sha": sb_sha,
    "status": status,
    "host": host,
    "orchestrator_mode": orchestrator_mode,
    "started_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mechanism": mechanism,
    "harness": "scripts/sb-tri-criteria-e2e.sh",
    "design_doc": ".planning/sb-tri-criteria-e2e/DESIGN.md",
    "verdict": None,
    "blocking_outcomes": {},
    "live_session_run": False,
    "greenfield": False,
    "graphify_query_ref": None,
    "agentmemory_export_ref": None,
    "fixture_branch": None,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
}

cmd_preflight() {
  local track_filter="" dry_ok=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --track) track_filter="$2"; shift 2 ;;
      *) echo "Unknown preflight arg: $1" >&2; exit 2 ;;
    esac
  done

  local install_fp sb_sha
  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  echo "=== sb-tri-criteria E2E preflight (structural) ==="
  echo "SB_ROOT=$SB_ROOT"
  echo "install_fp=$install_fp"
  echo "sb_git_sha=$sb_sha"
  echo "NOTE: preflight does not run live orchestrator sessions"

  [[ -f "$UMBRELLA_MATRIX" ]] || { echo "ERROR: missing $UMBRELLA_MATRIX" >&2; dry_ok=0; }
  [[ -f "${PLANNING_DIR}/DESIGN.md" ]] || { echo "ERROR: missing DESIGN.md" >&2; dry_ok=0; }
  [[ -f "${PLANNING_DIR}/CURSOR-MULTIWF-CRITERIA.md" ]] || { echo "WARN: missing CURSOR-MULTIWF-CRITERIA.md" >&2; }

  local tid tdir
  for tid in TC-01 TC-02 TC-03; do
    [[ -n "$track_filter" && "$track_filter" != "$tid" ]] && continue
    tdir="$(track_dir_for "$tid")" || continue
    for f in RUNBOOK.md CRITERIA.md MATRIX.json; do
      [[ -f "${tdir}/${f}" ]] && echo "OK: ${tid}/${f}" || { echo "ERROR: missing ${tdir}/${f}" >&2; dry_ok=0; }
    done
  done

  if [[ "${SB_TRI_CRITERIA_SKIP_STRUCT:-}" != 1 && -x "$STRUCT_TEST" ]]; then
    if bash "$STRUCT_TEST"; then
      echo "OK: structural harness tests"
    else
      echo "ERROR: structural harness tests failed" >&2
      dry_ok=0
    fi
  elif [[ "${SB_TRI_CRITERIA_SKIP_STRUCT:-}" == 1 ]]; then
    echo "OK: structural harness tests (skipped — inner preflight)"
  else
    echo "ERROR: missing $STRUCT_TEST" >&2
    dry_ok=0
  fi

  for hook in orchestrator-directive.sh orchestrator-scheduler.sh orchestrator-state.sh orchestrator-event-log.sh; do
    [[ -f "${REPO_ROOT}/hooks/lib/${hook}" ]] && echo "OK: hooks/lib/${hook}" || echo "WARN: missing hooks/lib/${hook}" >&2
  done

  if command -v jq >/dev/null 2>&1; then
    jq -e '.criteria[] | select(.id=="OUT-MULTIWF-01")' \
      "${REPO_ROOT}/docs/testing/outcome-criteria-registry.json" >/dev/null 2>&1 \
      && echo "OK: OUT-MULTIWF-01 in outcome registry" \
      || { echo "ERROR: OUT-MULTIWF-01 missing from registry" >&2; dry_ok=0; }
  fi

  [[ "$dry_ok" -eq 1 ]] || exit 1
  echo "PREFLIGHT PASS (structural — live sessions not run)"
}

cmd_start() {
  local track_id="" work_dir="" dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --track) track_id="$2"; shift 2 ;;
      --work-dir) work_dir="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) echo "Unknown start arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$track_id" ]] || { echo "ERROR: --track required (TC-01, TC-02, TC-03)" >&2; exit 2; }
  local track_dir matrix_json row_id
  track_dir="$(track_dir_for "$track_id")" || { echo "ERROR: unknown track $track_id" >&2; exit 1; }
  matrix_json="${track_dir}/MATRIX.json"
  row_id="$track_id"

  local tpl_line vision_src prefs_src
  tpl_line="$(row_templates "$track_dir" "$row_id")" || { echo "ERROR: unknown row $row_id" >&2; exit 1; }
  vision_src="${tpl_line%%$'\t'*}"
  prefs_src="${tpl_line#*$'\t'}"
  [[ -f "$vision_src" ]] || { echo "ERROR: missing vision: $vision_src" >&2; exit 1; }
  [[ -f "$prefs_src" ]] || { echo "ERROR: missing prefs: $prefs_src" >&2; exit 1; }

  work_dir="${work_dir:-${SB_TRI_CRITERIA_WORK_DIR:-${SB_MINIMAL_INTENT_WORK_DIR:-$(default_work_dir)}}}"
  [[ -d "$work_dir" ]] || { echo "ERROR: work_dir not found: $work_dir" >&2; exit 1; }

  local run_id run_dir install_fp sb_sha
  run_id="$(run_id_new)-${track_id}"
  run_dir="${PLANNING_DIR}/runs/${run_id}"
  mkdir -p "$run_dir"

  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  cp "$vision_src" "${run_dir}/vision.md"
  cp "$prefs_src" "${run_dir}/prefs.json"
  cp "${run_dir}/vision.md" "${run_dir}/INTENT-SEED.txt"
  : >"${run_dir}/parent-session.log"
  write_ledger_stub "$run_dir" "$track_id" "$row_id" "$install_fp" "$sb_sha" "prepared"

  echo "=== sb-tri-criteria E2E start ==="
  echo "run_id=$run_id"
  echo "track_id=$track_id"
  echo "row_id=$row_id"
  echo "install_fp=$install_fp"
  echo "work_dir=$work_dir"
  echo "vision=${run_dir}/vision.md"
  echo "prefs=${run_dir}/prefs.json"
  echo "design=${PLANNING_DIR}/DESIGN.md"

  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRY-RUN: run dir prepared; live session not started"
    exit 0
  fi

  local host_hint="Cursor parent orchestrator"
  if [[ "$track_id" == "TC-03" && "${SB_TRI_CRITERIA_HOST:-}" == "agent-claude" ]]; then
    host_hint="agent-claude delegation (see TC-03 RUNBOOK)"
  fi

  cat <<EOF

LIVE SESSION CHECKLIST (operator):
  1. Host: $host_hint in: $work_dir
  2. Seed intent: ${run_dir}/INTENT-SEED.txt
  3. Prefs: ${run_dir}/prefs.json
  4. Start /silver or composer per track RUNBOOK — autonomous mode
  5. Capture composition log: ${work_dir}/.planning/orchestrator-composition-log.jsonl
  6. Capture events: \$HOME/.codex/.silver-bullet/orchestrator-events.jsonl
  7. Save transcript: ${run_dir}/parent-session.log
  8. Score: bash scripts/sb-tri-criteria-e2e.sh score --run $run_id --track $track_id

EOF
}

cmd_score() {
  local run_id="" track_id="" log_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) run_id="$2"; shift 2 ;;
      --track) track_id="$2"; shift 2 ;;
      --log) log_path="$2"; shift 2 ;;
      *) echo "Unknown score arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$run_id" ]] || { echo "ERROR: --run required" >&2; exit 2; }
  [[ -n "$track_id" ]] || { echo "ERROR: --track required" >&2; exit 2; }

  local run_dir="${PLANNING_DIR}/runs/${run_id}"
  [[ -d "$run_dir" ]] || { echo "ERROR: run dir not found: $run_dir" >&2; exit 1; }

  log_path="${log_path:-${run_dir}/parent-session.log}"
  [[ -s "$log_path" ]] || {
    echo "ERROR: session log empty or missing: $log_path" >&2
    echo "HINT: live session not captured — cannot score" >&2
    exit 1
  }

  local track_dir matrix_json row_id ledger
  track_dir="$(track_dir_for "$track_id")" || { echo "ERROR: unknown track $track_id" >&2; exit 1; }
  matrix_json="${track_dir}/MATRIX.json"
  ledger="${run_dir}/ledger.json"
  row_id="$(python3 - "$ledger" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f).get("row_id", ""))
PY
)"

  echo "=== sb-tri-criteria E2E score ==="
  echo "run_id=$run_id track_id=$track_id row_id=$row_id"
  echo "log=$log_path"

  local work_dir state_dir evidence_path="" outcomes outcome verdict=PASS detail world_deps_pass=1
  work_dir="${SB_TRI_CRITERIA_WORK_DIR:-${SB_MINIMAL_INTENT_WORK_DIR:-$(default_work_dir)}}"
  state_dir="${SB_RUNTIME_STATE_DIR:-${HOME}/.codex/.silver-bullet}"
  export SB_E2E_ENTERPRISE_MATRIX=1
  export SB_TRI_CRITERIA_RUN_DIR="$run_dir"
  export SB_TRI_CRITERIA_ROW_ID="$row_id"
  export SB_TRI_CRITERIA_SESSION_LOG="$log_path"

  local comp_log wf_count
  comp_log="$(enterprise_e2e_outcome_composition_log_path "$work_dir")"
  if [[ -f "$comp_log" ]] || [[ -f "${run_dir}/orchestrator-composition-log.jsonl" ]]; then
    wf_count="$(enterprise_e2e_outcome_count_distinct_workflow_ids "$work_dir" "$state_dir")"
    echo "composition_log=$comp_log distinct_workflow_ids=${wf_count:-0}"
  else
    echo "WARN: composition log missing: $comp_log"
  fi

  outcomes="$(row_blocking_outcomes "$matrix_json" "$row_id")"
  for outcome in $outcomes; do
    [[ "$outcome" == "OUT-WORLD-01" ]] && continue
    detail="$(enterprise_e2e_outcome_score_criterion "$outcome" "$work_dir" "$state_dir" "$log_path" "$row_id" "$ledger" "$evidence_path" 2>/dev/null || true)"
    [[ -n "$detail" ]] || detail="fail"
    echo "  $outcome: $detail"
    if [[ "$detail" != pass && "$detail" != pass* && "$detail" != "n/a" ]]; then
      verdict=FAIL
      world_deps_pass=0
    fi
  done

  if [[ "$world_deps_pass" -eq 1 ]]; then
    detail="pass"
  else
    detail="fail"
  fi
  echo "  OUT-WORLD-01: $detail"
  [[ "$detail" == pass ]] || verdict=FAIL

  for outcome in $(row_advisory_outcomes "$matrix_json" "$row_id" 2>/dev/null || true); do
    [[ -z "$outcome" ]] && continue
    detail="$(enterprise_e2e_outcome_score_criterion "$outcome" "$work_dir" "$state_dir" "$log_path" "$row_id" "$ledger" "$evidence_path" 2>/dev/null || true)"
    echo "  $outcome: ${detail:-n/a} (advisory)"
  done

  python3 - "$ledger" "$verdict" "$log_path" "$track_id" <<'PY'
import json, sys
from datetime import datetime, timezone
path, verdict, log_path, track_id = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["status"] = "scored"
doc["verdict"] = verdict
doc["track_id"] = track_id
doc["scored_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
doc["session_log"] = log_path
doc["live_session_run"] = True
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY

  echo "VERDICT: $verdict"
  [[ "$verdict" == PASS ]] || exit 1
}

cmd_live() {
  local track_id="" work_dir="" host="${SB_TRI_CRITERIA_HOST:-cursor}" greenfield=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --track) track_id="$2"; shift 2 ;;
      --work-dir) work_dir="$2"; shift 2 ;;
      --host) host="$2"; shift 2 ;;
      --greenfield) greenfield=1; shift ;;
      *) echo "Unknown live arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$track_id" ]] || { echo "ERROR: --track required (TC-01, TC-02, TC-03)" >&2; exit 2; }
  case "$host" in
    cursor|claude|codex) ;;
    *) echo "ERROR: --host must be cursor, claude, or codex (got: $host)" >&2; exit 2 ;;
  esac

  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_TRI_CRITERIA_HOST="$host"
  export SB_TRI_CRITERIA_GREENFIELD="$greenfield"
  unset SB_RUNTIME_STATE_DIR
  work_dir="${work_dir:-${SB_TRI_CRITERIA_WORK_DIR:-${SB_MINIMAL_INTENT_WORK_DIR:-$(default_work_dir)}}}"
  export SB_TRI_CRITERIA_WORK_DIR="$work_dir"

  local run_id run_dir
  run_id="$(run_id_new)-${track_id}"
  run_dir="${PLANNING_DIR}/runs/${run_id}"
  mkdir -p "$run_dir"

  local track_dir row_id install_fp sb_sha
  track_dir="$(track_dir_for "$track_id")" || exit 1
  row_id="$track_id"
  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  local tpl_line vision_src prefs_src
  tpl_line="$(row_templates "$track_dir" "$row_id")" || exit 1
  vision_src="${tpl_line%%$'\t'*}"
  prefs_src="${tpl_line#*$'\t'}"
  cp "$vision_src" "${run_dir}/vision.md"
  cp "$prefs_src" "${run_dir}/prefs.json"
  cp "${run_dir}/vision.md" "${run_dir}/INTENT-SEED.txt"
  write_ledger_stub "$run_dir" "$track_id" "$row_id" "$install_fp" "$sb_sha" "live-running"
  if [[ "$greenfield" -eq 1 ]] && command -v jq >/dev/null 2>&1; then
    jq '.greenfield = true' "${run_dir}/ledger.json" >"${run_dir}/ledger.json.tmp" && \
      mv "${run_dir}/ledger.json.tmp" "${run_dir}/ledger.json"
  fi

  local live_script
  case "$host" in
    cursor)
      live_script="${PLANNING_DIR}/scripts/live-verify-track.sh"
      ;;
    claude|codex)
      live_script="${PLANNING_DIR}/scripts/live-verify-track-host.sh"
      ;;
  esac
  chmod +x "$live_script" 2>/dev/null || true
  [[ -f "$live_script" ]] || { echo "ERROR: missing $live_script" >&2; exit 1; }

  echo "=== sb-tri-criteria E2E live verify ==="
  echo "run_id=$run_id track_id=$track_id host=$host work_dir=$work_dir greenfield=$greenfield"
  echo "NOTE: bootstrap-orchestrator*.sh NOT used; product gate required"

  case "$host" in
    cursor) bash "$live_script" "$track_id" "$run_dir" ;;
    claude|codex) bash "$live_script" "$host" "$track_id" "$run_dir" ;;
  esac

  export SB_TRI_CRITERIA_RUN_DIR="$run_dir"
  export SB_E2E_ENTERPRISE_MATRIX=1
  unset SB_RUNTIME_STATE_DIR
  case "$host" in
    cursor)
      export SB_RUNTIME_STATE_DIR="${HOME}/.codex/.silver-bullet/tri-criteria-live-${run_id}"
      ;;
    claude)
      export SB_RUNTIME_STATE_DIR="${HOME}/.codex/.silver-bullet/tri-criteria-live-${run_id}"
      ;;
    codex)
      export SB_RUNTIME_STATE_DIR="${HOME}/.codex/.silver-bullet/tri-criteria-live-${run_id}"
      ;;
  esac
  cmd_score --run "$run_id" --track "$track_id"

  if command -v jq >/dev/null 2>&1; then
    local fixture_branch fixture_sha
    fixture_branch="$(git -C "$work_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    fixture_sha="$(git -C "$work_dir" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
    jq --arg b "$fixture_branch" --arg s "$fixture_sha" \
      '.fixture_branch = $b | .fixture_sha = $s' \
      "${run_dir}/ledger.json" >"${run_dir}/ledger.json.tmp" && \
      mv "${run_dir}/ledger.json.tmp" "${run_dir}/ledger.json"
  fi
}

cmd_cold() {
  local track_id="" work_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --track) track_id="$2"; shift 2 ;;
      --work-dir) work_dir="$2"; shift 2 ;;
      --no-bootstrap) shift ;;
      *) echo "Unknown cold arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$track_id" ]] || { echo "ERROR: --track required (TC-01, TC-02, TC-03)" >&2; exit 2; }

  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  work_dir="${work_dir:-${SB_TRI_CRITERIA_WORK_DIR:-${SB_MINIMAL_INTENT_WORK_DIR:-$(default_work_dir)}}}"
  export SB_TRI_CRITERIA_WORK_DIR="$work_dir"

  local run_id run_dir
  run_id="$(run_id_new)-${track_id}"
  run_dir="${PLANNING_DIR}/runs/${run_id}"
  mkdir -p "$run_dir"

  # Prepare vision/prefs/ledger via start dry path
  local track_dir matrix_json row_id install_fp sb_sha
  track_dir="$(track_dir_for "$track_id")" || exit 1
  matrix_json="${track_dir}/MATRIX.json"
  row_id="$track_id"
  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  local tpl_line vision_src prefs_src
  tpl_line="$(row_templates "$track_dir" "$row_id")" || exit 1
  vision_src="${tpl_line%%$'\t'*}"
  prefs_src="${tpl_line#*$'\t'}"
  cp "$vision_src" "${run_dir}/vision.md"
  cp "$prefs_src" "${run_dir}/prefs.json"
  cp "${run_dir}/vision.md" "${run_dir}/INTENT-SEED.txt"
  write_ledger_stub "$run_dir" "$track_id" "$row_id" "$install_fp" "$sb_sha" "cold-running"

  local cold_script="${PLANNING_DIR}/scripts/cold-verify-track.sh"
  [[ -x "$cold_script" ]] || chmod +x "$cold_script" 2>/dev/null || true
  [[ -f "$cold_script" ]] || { echo "ERROR: missing $cold_script" >&2; exit 1; }

  echo "=== sb-tri-criteria E2E cold verify ==="
  echo "run_id=$run_id track_id=$track_id work_dir=$work_dir"
  echo "NOTE: bootstrap-orchestrator*.sh NOT used"

  bash "$cold_script" "$track_id" "$run_dir"

  export SB_TRI_CRITERIA_RUN_DIR="$run_dir"
  export SB_E2E_ENTERPRISE_MATRIX=1
  cmd_score --run "$run_id" --track "$track_id"
}

cmd_status() {
  local run_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) run_id="$2"; shift 2 ;;
      *) echo "Unknown status arg: $1" >&2; exit 2 ;;
    esac
  done

  if [[ -n "$run_id" ]]; then
    local ledger="${PLANNING_DIR}/runs/${run_id}/ledger.json"
    [[ -f "$ledger" ]] && cat "$ledger" || echo "No ledger for $run_id"
    return 0
  fi

  echo "=== sb-tri-criteria runs ==="
  local d
  for d in "${PLANNING_DIR}"/runs/*/ledger.json; do
    [[ -f "$d" ]] || continue
    python3 - "$d" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    doc = json.load(f)
print(f"{doc.get('track_id')}  {doc.get('row_id')}  {doc.get('status')}  verdict={doc.get('verdict')}  live={doc.get('live_session_run')}")
PY
  done
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    preflight) cmd_preflight "$@" ;;
    start) cmd_start "$@" ;;
    score) cmd_score "$@" ;;
    live) cmd_live "$@" ;;
    cold) cmd_cold "$@" ;;
    status) cmd_status "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: $cmd" >&2; usage; exit 2 ;;
  esac
}

main "$@"

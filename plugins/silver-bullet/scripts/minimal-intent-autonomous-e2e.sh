#!/usr/bin/env bash
# Minimal-intent full development E2E — Cursor parent orchestrator track.
#
# Usage:
#   bash scripts/minimal-intent-autonomous-e2e.sh preflight
#   bash scripts/minimal-intent-autonomous-e2e.sh start --row MI-01 [--dry-run]
#   bash scripts/minimal-intent-autonomous-e2e.sh score --run <run-id> [--log PATH]
#   bash scripts/minimal-intent-autonomous-e2e.sh status [--run <run-id>]
#
# See .planning/minimal-intent-e2e/RUNBOOK.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLANNING_DIR="${REPO_ROOT}/.planning/minimal-intent-e2e"
MATRIX_JSON="${PLANNING_DIR}/MATRIX.json"
STRUCT_TEST="${REPO_ROOT}/tests/scripts/test-minimal-intent-autonomous-e2e.sh"

export SB_ROOT="${SB_ROOT:-$REPO_ROOT}"

# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"
# shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

usage() {
  cat <<'EOF'
Usage: minimal-intent-autonomous-e2e.sh <command> [options]

Commands:
  preflight          Verify harness wiring and structural tests (no live session)
  start --row ID     Prepare run dir and intent seed for parent orchestrator session
  score --run ID     Score blocking outcomes from parent-session.log
  status [--run ID]  Show run ledger(s)

Options:
  --row ID           Matrix row (MI-01)
  --run ID           Run directory name under runs/
  --log PATH         Override session log for score
  --work-dir PATH    Override fixture work dir
  --dry-run          Prepare run dir only; do not print live-session checklist
EOF
}

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

run_id_new() { date -u '+%Y%m%dT%H%M%SZ'; }

matrix_row_field() {
  local row_id="$1" field="$2"
  python3 - "$MATRIX_JSON" "$row_id" "$field" <<'PY'
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
  python3 - "$MATRIX_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    doc = json.load(f)
print(doc.get("fixture", {}).get("work_dir_default", ""))
PY
}

row_blocking_outcomes() {
  local row_id="$1"
  python3 - "$MATRIX_JSON" "$row_id" <<'PY'
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

row_templates() {
  local row_id="$1"
  python3 - "$MATRIX_JSON" "$row_id" <<'PY'
import json, sys
path, row_id = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") != row_id:
        continue
    vision = row.get("vision_template") or doc.get("fixture", {}).get("vision_template", "")
    prefs = row.get("prefs_template") or doc.get("fixture", {}).get("prefs_template", "")
    print(f"{vision}\t{prefs}")
    sys.exit(0)
sys.exit(1)
PY
}

cmd_preflight() {
  local install_fp sb_sha dry_ok=1
  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  echo "=== minimal-intent E2E preflight (structural) ==="
  echo "SB_ROOT=$SB_ROOT"
  echo "install_fp=$install_fp"
  echo "sb_git_sha=$sb_sha"
  echo "NOTE: preflight does not run live parent orchestrator session"

  [[ -f "$MATRIX_JSON" ]] || { echo "ERROR: missing $MATRIX_JSON" >&2; dry_ok=0; }
  [[ -x "${BASH_SOURCE[0]}" ]] || true

  if [[ "${SB_MINIMAL_INTENT_SKIP_STRUCT:-}" != 1 && -x "$STRUCT_TEST" ]]; then
    if bash "$STRUCT_TEST"; then
      echo "OK: structural harness tests"
    else
      echo "ERROR: structural harness tests failed" >&2
      dry_ok=0
    fi
  elif [[ "${SB_MINIMAL_INTENT_SKIP_STRUCT:-}" == 1 ]]; then
    echo "OK: structural harness tests (skipped — inner preflight)"
  else
    echo "ERROR: missing $STRUCT_TEST" >&2
    dry_ok=0
  fi

  local work_dir
  work_dir="$(default_work_dir)"
  if [[ -n "$work_dir" && -d "$work_dir" ]]; then
    echo "OK: fixture work_dir exists: $work_dir"
  else
    echo "WARN: fixture work_dir missing: ${work_dir:-<unset>}" >&2
  fi

  for hook in orchestrator-directive.sh orchestrator-scheduler.sh orchestrator-state.sh; do
    if [[ -f "${REPO_ROOT}/hooks/lib/${hook}" ]]; then
      echo "OK: hooks/lib/${hook}"
    else
      echo "WARN: missing hooks/lib/${hook}" >&2
    fi
  done

  [[ "$dry_ok" -eq 1 ]] || exit 1
  echo "PREFLIGHT PASS (structural — live session not run)"
}

write_ledger_stub() {
  local run_dir="$1" row_id="$2" install_fp="$3" sb_sha="$4" status="$5"
  python3 - "$run_dir/ledger.json" "$row_id" "$install_fp" "$sb_sha" "$status" <<'PY'
import json, sys
from datetime import datetime, timezone
path, row_id, install_fp, sb_sha, status = sys.argv[1:6]
doc = {
    "schema_version": 1,
    "track": "minimal-intent-e2e",
    "row_id": row_id,
    "install_fp": install_fp,
    "sb_git_sha": sb_sha,
    "status": status,
    "host": "cursor",
    "orchestrator_mode": "parent",
    "started_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mechanism": "silver-orchestrator parent + Task workers",
    "harness": "scripts/minimal-intent-autonomous-e2e.sh",
    "verdict": None,
    "blocking_outcomes": {},
    "live_session_run": False,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
}

cmd_start() {
  local row_id="" work_dir="" dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --row) row_id="$2"; shift 2 ;;
      --work-dir) work_dir="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) echo "Unknown start arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$row_id" ]] || { echo "ERROR: --row required (MI-01)" >&2; exit 2; }

  local tpl_line vision_tpl prefs_tpl vision_src prefs_src
  tpl_line="$(row_templates "$row_id")" || { echo "ERROR: unknown row $row_id" >&2; exit 1; }
  vision_tpl="${tpl_line%%$'\t'*}"
  prefs_tpl="${tpl_line#*$'\t'}"

  vision_src="${PLANNING_DIR}/${vision_tpl}"
  prefs_src="${PLANNING_DIR}/${prefs_tpl}"
  [[ -f "$vision_src" ]] || { echo "ERROR: missing vision: $vision_src" >&2; exit 1; }
  [[ -f "$prefs_src" ]] || { echo "ERROR: missing prefs: $prefs_src" >&2; exit 1; }

  work_dir="${work_dir:-${SB_MINIMAL_INTENT_WORK_DIR:-$(default_work_dir)}}"
  [[ -d "$work_dir" ]] || { echo "ERROR: work_dir not found: $work_dir" >&2; exit 1; }

  local run_id run_dir install_fp sb_sha
  run_id="$(run_id_new)-${row_id}"
  run_dir="${PLANNING_DIR}/runs/${run_id}"
  mkdir -p "$run_dir"

  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  cp "$vision_src" "${run_dir}/vision.md"
  cp "$prefs_src" "${run_dir}/prefs.json"
  cp "${run_dir}/vision.md" "${run_dir}/INTENT-SEED.txt"
  : >"${run_dir}/parent-session.log"
  write_ledger_stub "$run_dir" "$row_id" "$install_fp" "$sb_sha" "prepared"

  echo "=== minimal-intent E2E start ==="
  echo "run_id=$run_id"
  echo "row_id=$row_id"
  echo "install_fp=$install_fp"
  echo "work_dir=$work_dir"
  echo "vision=${run_dir}/vision.md"
  echo "prefs=${run_dir}/prefs.json"
  echo "log=${run_dir}/parent-session.log"

  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRY-RUN: run dir prepared; live parent session not started"
    exit 0
  fi

  cat <<EOF

LIVE SESSION CHECKLIST (operator):
  1. Open Cursor parent orchestrator session in: $work_dir
  2. Seed intent from: ${run_dir}/INTENT-SEED.txt  (→ orchestrator-intent.txt)
  3. Apply prefs from: ${run_dir}/prefs.json if needed
  4. Start with /silver or /silver:feature — autonomous mode
  5. Do NOT micro-manage workers; blocking decisions only
  6. Save parent session transcript to: ${run_dir}/parent-session.log
  7. Score: bash scripts/minimal-intent-autonomous-e2e.sh score --run $run_id

EOF
}

cmd_score() {
  local run_id="" log_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) run_id="$2"; shift 2 ;;
      --log) log_path="$2"; shift 2 ;;
      *) echo "Unknown score arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$run_id" ]] || { echo "ERROR: --run required" >&2; exit 2; }
  local run_dir="${PLANNING_DIR}/runs/${run_id}"
  [[ -d "$run_dir" ]] || { echo "ERROR: run dir not found: $run_dir" >&2; exit 1; }

  log_path="${log_path:-${run_dir}/parent-session.log}"
  [[ -s "$log_path" ]] || {
    echo "ERROR: session log empty or missing: $log_path" >&2
    echo "HINT: live parent session not captured — cannot score" >&2
    exit 1
  }

  local row_id ledger
  ledger="${run_dir}/ledger.json"
  row_id="$(python3 - "$ledger" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.load(f).get("row_id", ""))
PY
)"

  echo "=== minimal-intent E2E score ==="
  echo "run_id=$run_id row_id=$row_id"
  echo "log=$log_path"

  local outcomes outcome verdict=PASS detail
  local work_dir state_dir evidence_path=""
  work_dir="${SB_MINIMAL_INTENT_WORK_DIR:-$(default_work_dir)}"
  state_dir="${SB_RUNTIME_STATE_DIR:-${HOME}/.codex/.silver-bullet}"
  export SB_E2E_ENTERPRISE_MATRIX=1
  # Product-delta evidence for session scorers (AUTO/WORLD composite).
  if [[ -d "${work_dir}/.planning/phases" ]]; then
    evidence_path="$(find "${work_dir}/.planning/phases" -name 'SUMMARY.md' -print -quit 2>/dev/null | sed "s|^${work_dir}/||" || true)"
  fi
  if [[ -z "$evidence_path" && -f "${work_dir}/.planning/workflows/feature-currency.md" ]]; then
    evidence_path=".planning/workflows/feature-currency.md"
  fi

  outcomes="$(row_blocking_outcomes "$row_id")"
  local world_deps_pass=1
  for outcome in $outcomes; do
    [[ "$outcome" == "OUT-WORLD-01" ]] && continue
    detail="$(enterprise_e2e_outcome_score_criterion "$outcome" "$work_dir" "$state_dir" "$log_path" "" "$ledger" "$evidence_path" 2>/dev/null || true)"
    if [[ -z "$detail" ]]; then
      detail="fail|scorer unavailable"
    fi
    echo "  $outcome: $detail"
    if [[ "$detail" != pass* && "$detail" != "pass" && "$detail" != "n/a" ]]; then
      verdict=FAIL
      world_deps_pass=0
    fi
  done
  # OUT-WORLD-01: composite of MI-01 blocking outcomes (advisory KM/VLOOP/TRACE excluded per CRITERIA.md).
  if [[ "$world_deps_pass" -eq 1 ]]; then
    detail="pass"
  else
    detail="fail"
  fi
  echo "  OUT-WORLD-01: $detail"
  [[ "$detail" == pass ]] || verdict=FAIL

  # Advisory (informational only)
  for outcome in $(matrix_row_field "$row_id" advisory_outcomes 2>/dev/null | tr -d '[],"' || true); do
    [[ -z "$outcome" ]] && continue
    detail="$(enterprise_e2e_outcome_score_criterion "$outcome" "$work_dir" "$state_dir" "$log_path" "" "$ledger" "$evidence_path" 2>/dev/null || true)"
    echo "  $outcome: ${detail:-n/a} (advisory)"
  done

  python3 - "$ledger" "$verdict" "$log_path" <<'PY'
import json, sys
from datetime import datetime, timezone
path, verdict, log_path = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["status"] = "scored"
doc["verdict"] = verdict
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

  echo "=== minimal-intent runs ==="
  local d
  for d in "${PLANNING_DIR}"/runs/*/ledger.json; do
    [[ -f "$d" ]] || continue
    python3 - "$d" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    doc = json.load(f)
print(f"{doc.get('row_id')}  {doc.get('status')}  verdict={doc.get('verdict')}  live={doc.get('live_session_run')}")
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
    status) cmd_status "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: $cmd" >&2; usage; exit 2 ;;
  esac
}

main "$@"

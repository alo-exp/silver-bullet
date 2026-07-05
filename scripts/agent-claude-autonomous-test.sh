#!/usr/bin/env bash
# Fresh autonomous vision test driver for /silver:agent-claude on current install_fp.
#
# Usage:
#   bash scripts/agent-claude-autonomous-test.sh preflight
#   bash scripts/agent-claude-autonomous-test.sh start --row AUTO-C01 [--use-print]
#   bash scripts/agent-claude-autonomous-test.sh score --run <run-id>
#   bash scripts/agent-claude-autonomous-test.sh status [--run <run-id>]
#
# See .planning/agent-claude-autonomous/RUNBOOK.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLANNING_DIR="${REPO_ROOT}/.planning/agent-claude-autonomous"
MATRIX_JSON="${PLANNING_DIR}/MATRIX.json"
INVOKE="${REPO_ROOT}/scripts/agent-claude/invoke.sh"
PREFLIGHT_AC="${REPO_ROOT}/scripts/agent-claude/preflight.sh"
STRUCT_TEST="${REPO_ROOT}/tests/scripts/test-agent-claude-autonomous-test.sh"

export SB_ROOT="${SB_ROOT:-$REPO_ROOT}"
export SB_E2E_LIVE_RUNTIME="${SB_E2E_LIVE_RUNTIME:-claude}"

# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${REPO_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"
# shellcheck source=scripts/agent-claude/lib.sh
source "${REPO_ROOT}/scripts/agent-claude/lib.sh"

usage() {
  cat <<'EOF'
Usage: agent-claude-autonomous-test.sh <command> [options]

Commands:
  preflight          Verify install_fp, agent-claude harness, structural tests
  start --row ID     Launch delegation for matrix row (AUTO-C01|AUTO-C02|AUTO-C03)
  score --run ID     Score blocking outcomes for a completed run
  status [--run ID]  Show run ledger(s)

Options:
  --row ID           Matrix row (start)
  --run ID           Run directory name under runs/
  --use-print        Use claude --print instead of expect TUI
  --tmux             Launch invoke in detached tmux session (TTY-honest TUI)
  --work-dir PATH    Override fixture work dir (default from MATRIX.json)
  --dry-run          Prepare run dir only; do not invoke Claude
EOF
}

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

run_id_new() {
  date -u '+%Y%m%dT%H%M%SZ'
}

matrix_row_brief() {
  local row_id="$1"
  python3 - "$MATRIX_JSON" "$row_id" <<'PY'
import json, sys
path, row_id = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") == row_id:
        tpl = row.get("brief_template")
        if not tpl:
            sys.exit(2)
        print(tpl)
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

# Map track row → enterprise outcome scorer profile (not enterprise matrix row 1 routing).
row_scorer_profile() {
  local row_id="$1"
  python3 - "$MATRIX_JSON" "$row_id" <<'PY'
import json, sys
path, row_id = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
for row in doc.get("rows", []):
    if row.get("id") != row_id:
        continue
    scorer = row.get("scorer") or {}
    row_num = scorer.get("enterprise_row_num")
    if row_num is None:
        analog = (row.get("e2e_analog") or "").lower()
        if "row 6" in analog:
            row_num = 6
        elif "row 3" in analog or "row 1" in analog:
            row_num = 3
        else:
            row_num = 0
    evidence = scorer.get("evidence", "")
    print(f"{row_num}\t{evidence}")
    sys.exit(0)
sys.exit(1)
PY
}

cmd_preflight() {
  local install_fp sb_sha dry_ok=1
  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  echo "=== agent-claude autonomous preflight ==="
  echo "SB_ROOT=$SB_ROOT"
  echo "install_fp=$install_fp"
  echo "sb_git_sha=$sb_sha"

  [[ -f "$MATRIX_JSON" ]] || { echo "ERROR: missing $MATRIX_JSON" >&2; dry_ok=0; }
  [[ -x "$INVOKE" ]] || { echo "ERROR: missing invoke.sh" >&2; dry_ok=0; }

  agent_claude_apply_delegate_env

  if bash "$PREFLIGHT_AC" --sb-root "$SB_ROOT" --dry-run; then
    echo "OK: agent-claude preflight (dry-run)"
  else
    echo "WARN: agent-claude preflight dry-run issues" >&2
    dry_ok=0
  fi

  if [[ -x "$STRUCT_TEST" ]]; then
    if bash "$STRUCT_TEST"; then
      echo "OK: structural harness tests"
    else
      echo "ERROR: structural harness tests failed" >&2
      dry_ok=0
    fi
  fi

  local work_dir
  work_dir="$(default_work_dir)"
  if [[ -n "$work_dir" && -d "$work_dir" ]]; then
    echo "OK: fixture work_dir exists: $work_dir"
  else
    echo "WARN: fixture work_dir missing: ${work_dir:-<unset>}" >&2
  fi

  if command -v graphify >/dev/null 2>&1; then
    echo "OK: graphify on PATH"
  else
    echo "WARN: graphify not on PATH (recommended tool)" >&2
  fi

  [[ "$dry_ok" -eq 1 ]] || exit 1
  echo "PREFLIGHT PASS"
}

write_ledger_stub() {
  local run_dir="$1" row_id="$2" install_fp="$3" sb_sha="$4" status="$5"
  python3 - "$run_dir/ledger.json" "$row_id" "$install_fp" "$sb_sha" "$status" <<'PY'
import json, sys
from datetime import datetime, timezone
path, row_id, install_fp, sb_sha, status = sys.argv[1:6]
doc = {
    "schema_version": 1,
    "track": "agent-claude-autonomous",
    "row_id": row_id,
    "install_fp": install_fp,
    "sb_git_sha": sb_sha,
    "status": status,
    "started_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mechanism": "/silver:agent-claude",
    "harness": "scripts/agent-claude-autonomous-test.sh",
    "verdict": None,
    "blocking_outcomes": {},
    "evidence_gaps": ["fresh_track_not_matrix_certified"],
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
}

cmd_start() {
  local row_id="" use_print=0 use_tmux=0 work_dir="" dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --row) row_id="$2"; shift 2 ;;
      --use-print) use_print=1; shift ;;
      --tmux) use_tmux=1; shift ;;
      --work-dir) work_dir="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      *) echo "Unknown start arg: $1" >&2; exit 2 ;;
    esac
  done

  [[ -n "$row_id" ]] || { echo "ERROR: --row required (AUTO-C01|AUTO-C02|AUTO-C03)" >&2; exit 2; }
  [[ "$row_id" != "AUTO-C03" ]] || { echo "ERROR: AUTO-C03 is score-only; use: score --run <prior-run>" >&2; exit 2; }

  local brief_tpl brief_src run_id run_dir install_fp sb_sha
  brief_tpl="$(matrix_row_brief "$row_id")" || { echo "ERROR: unknown row $row_id" >&2; exit 1; }
  brief_src="${PLANNING_DIR}/${brief_tpl}"
  [[ -f "$brief_src" ]] || { echo "ERROR: missing brief: $brief_src" >&2; exit 1; }

  work_dir="${work_dir:-$(default_work_dir)}"
  [[ -d "$work_dir" ]] || { echo "ERROR: work_dir not found: $work_dir" >&2; exit 1; }

  run_id="$(run_id_new)-${row_id}"
  run_dir="${PLANNING_DIR}/runs/${run_id}"
  mkdir -p "$run_dir"

  install_fp="$(enterprise_e2e_install_fingerprint)"
  sb_sha="$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

  cp "$brief_src" "${run_dir}/brief.md"
  : >"${run_dir}/claude-run.log"
  write_ledger_stub "$run_dir" "$row_id" "$install_fp" "$sb_sha" "started"

  echo "=== agent-claude autonomous start ==="
  echo "run_id=$run_id"
  echo "row_id=$row_id"
  echo "install_fp=$install_fp"
  echo "work_dir=$work_dir"
  echo "brief=${run_dir}/brief.md"
  echo "log=${run_dir}/claude-run.log"

  if [[ "$dry_run" -eq 1 ]]; then
    echo "DRY-RUN: run dir prepared; skipping invoke"
    echo "NEXT: bash scripts/agent-claude-autonomous-test.sh start --row $row_id"
    exit 0
  fi

  export CLAUDE_WORK_DIR="$work_dir"
  agent_claude_apply_delegate_env

  local invoke_args=(
    --work-dir "$work_dir"
    --brief-file "${run_dir}/brief.md"
    --log "${run_dir}/claude-run.log"
  )
  [[ "$use_print" -eq 1 ]] && invoke_args+=(--use-print)

  local launch_log="${run_dir}/launch.log"
  echo "Launching agent-claude invoke (log: $launch_log) ..."

  if [[ "$use_tmux" -eq 1 ]]; then
    command -v tmux >/dev/null 2>&1 || { echo "ERROR: tmux required for --tmux" >&2; exit 1; }
    local session="agent-claude-auto-$(printf '%s' "$row_id" | tr '[:upper:]' '[:lower:]')"
    local invoke_cmd="bash $(printf '%q' "$INVOKE")"
    local arg
    for arg in "${invoke_args[@]}"; do
      invoke_cmd+=" $(printf '%q' "$arg")"
    done
    tmux kill-session -t "$session" 2>/dev/null || true
    tmux new-session -d -s "$session" \
      "cd $(printf '%q' "$REPO_ROOT") && source $(printf '%q' "${REPO_ROOT}/scripts/agent-claude/lib.sh") && export CLAUDE_WORK_DIR=$(printf '%q' "$work_dir") && agent_claude_apply_delegate_env && ${invoke_cmd} >>$(printf '%q' "$launch_log") 2>&1; exit_code=\$?; python3 - $(printf '%q' "$run_dir/ledger.json") \"\$exit_code\" <<'PY'
import json, sys
from datetime import datetime, timezone
path, exit_code = sys.argv[1], int(sys.argv[2])
with open(path, encoding='utf-8') as f:
    doc = json.load(f)
doc['status'] = 'completed' if exit_code == 0 else 'failed'
doc['delegate_exit'] = exit_code
doc['completed_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(doc, f, indent=2)
    f.write('\n')
PY
exit \"\$exit_code\""
    echo "$session" >"${run_dir}/tmux.session"
    python3 - "$run_dir/ledger.json" "$session" <<'PY'
import json, sys
path, session = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["tmux_session"] = session
doc["status"] = "running"
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
    echo "STARTED: tmux session $session"
    echo "ATTACH:  tmux attach -t $session"
    echo "MONITOR: bash scripts/agent-claude/monitor.sh --log ${run_dir}/claude-run.log"
    echo "SCORE:   bash scripts/agent-claude-autonomous-test.sh score --run $run_id"
    return 0
  fi

  # Background launch — TUI sessions are long-running
  (
    set +e
    bash "$INVOKE" "${invoke_args[@]}" >>"$launch_log" 2>&1
    exit_code=$?
    python3 - "$run_dir/ledger.json" "$exit_code" <<'PY'
import json, sys
from datetime import datetime, timezone
path, exit_code = sys.argv[1], int(sys.argv[2])
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["status"] = "completed" if exit_code == 0 else "failed"
doc["delegate_exit"] = exit_code
doc["completed_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
    exit "$exit_code"
  ) &
  local pid=$!
  echo "$pid" >"${run_dir}/delegate.pid"

  python3 - "$run_dir/ledger.json" "$pid" <<'PY'
import json, sys
path, pid = sys.argv[1], int(sys.argv[2])
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["delegate_pid"] = pid
doc["status"] = "running"
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY

  echo "STARTED: delegate PID $pid"
  echo "MONITOR: bash scripts/agent-claude/monitor.sh --log ${run_dir}/claude-run.log"
  echo "SCORE:   bash scripts/agent-claude-autonomous-test.sh score --run $run_id"
}

cmd_score() {
  local run_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run) run_id="$2"; shift 2 ;;
      *) echo "Unknown score arg: $1" >&2; exit 2 ;;
    esac
  done
  [[ -n "$run_id" ]] || { echo "ERROR: --run required" >&2; exit 2; }

  local run_dir="${PLANNING_DIR}/runs/${run_id}"
  local ledger="${run_dir}/ledger.json"
  local log_file="${run_dir}/claude-run.log"
  [[ -f "$ledger" ]] || { echo "ERROR: missing ledger: $ledger" >&2; exit 1; }
  [[ -f "$log_file" ]] || { echo "ERROR: missing log: $log_file" >&2; exit 1; }

  local row_id work_dir scorer_row_num scorer_evidence
  row_id="$(python3 -c "import json; print(json.load(open('$ledger'))['row_id'])")"
  work_dir="$(default_work_dir)"
  IFS=$'\t' read -r scorer_row_num scorer_evidence < <(row_scorer_profile "$row_id")

  # shellcheck source=scripts/lib/enterprise-e2e-outcome-assessment.sh
  source "${REPO_ROOT}/scripts/lib/enterprise-e2e-outcome-assessment.sh"

  local state_dir
  state_dir="$(mktemp -d "${TMPDIR:-/tmp}/aca-score.XXXXXX")"
  mkdir -p "$state_dir"

  echo "=== scoring run $run_id (row $row_id, scorer_row_num=$scorer_row_num) ==="

  if [[ "$row_id" == "AUTO-C03" ]]; then
    local world_score log_bytes log_floor verdict="PASS" verdict_ok=1
    world_score="$(python3 - "$ledger" "${PLANNING_DIR}/runs" <<'PYC03'
import json, sys
ledger_path, runs_root = sys.argv[1:3]
with open(ledger_path, encoding="utf-8") as f:
    doc = json.load(f)
deps = doc.get("composite_runs") or []
if len(deps) < 2:
    print("fail")
    raise SystemExit(0)
for rid in deps:
    lp = f"{runs_root}/{rid}/ledger.json"
    try:
        with open(lp, encoding="utf-8") as f:
            sub = json.load(f)
    except OSError:
        print("fail")
        raise SystemExit(0)
    if sub.get("verdict") != "PASS":
        print("fail")
        raise SystemExit(0)
    for _cid, score in (sub.get("blocking_outcomes") or {}).items():
        if score != "pass":
            print("fail")
            raise SystemExit(0)
print("pass")
PYC03
)"
    echo "  OUT-WORLD-01 => $world_score (composite dependency check)"
    [[ "$world_score" == "pass" ]] || verdict_ok=0
    log_bytes="$(wc -c <"$log_file" | tr -d ' ')"
    log_floor="${SB_AGENT_CLAUDE_LOG_FLOOR:-512}"
    if [[ "$log_bytes" -lt "$log_floor" ]]; then
      echo "WARN: log floor not met ($log_bytes < $log_floor B)"
      verdict_ok=0
    fi
    [[ "$verdict_ok" -eq 1 ]] || verdict="FAIL"
    python3 - "$ledger" "$world_score" "$verdict" "$log_bytes" <<'PY'
import json, sys
path, world, verdict, log_bytes = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["blocking_outcomes"] = {"OUT-WORLD-01": world}
doc["verdict"] = verdict
doc["log_bytes"] = int(log_bytes)
doc["scored_at"] = __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
    rm -rf "$state_dir"
    echo "VERDICT: $verdict (composite — prior row blocking outcomes must be pass)"
    return 0
  fi

  local outcomes verdict_ok=1
  outcomes="$(row_blocking_outcomes "$row_id")"
  local scores_json="{"
  local first=1
  for cid in $outcomes; do
    local score
    score="$(enterprise_e2e_outcome_score_criterion "$cid" "$work_dir" "$state_dir" "$log_file" "$scorer_row_num" "" "$scorer_evidence" 2>/dev/null || echo fail)"
    echo "  $cid => $score"
    [[ "$first" -eq 1 ]] || scores_json+=","
    first=0
    scores_json+="\"$cid\":\"$score\""
    if [[ "$score" != "pass" ]]; then
      verdict_ok=0
    fi
  done
  scores_json+="}"

  local log_bytes
  log_bytes="$(wc -c <"$log_file" | tr -d ' ')"
  local log_floor="${SB_AGENT_CLAUDE_LOG_FLOOR:-512}"
  if [[ "$log_bytes" -lt "$log_floor" ]]; then
    echo "WARN: log floor not met ($log_bytes < $log_floor B)"
    verdict_ok=0
  fi

  local verdict="PASS"
  [[ "$verdict_ok" -eq 1 ]] || verdict="FAIL"

  python3 - "$ledger" "$scores_json" "$verdict" "$log_bytes" <<'PY'
import json, sys
path, scores_json, verdict, log_bytes = sys.argv[1:5]
scores = json.loads(scores_json)
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
doc["blocking_outcomes"] = scores
doc["verdict"] = verdict
doc["log_bytes"] = int(log_bytes)
doc["scored_at"] = __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY

  rm -rf "$state_dir"
  echo "VERDICT: $verdict (conservative — does not upgrade matrix certification)"
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
    [[ -f "$ledger" ]] && cat "$ledger" || echo "missing: $ledger" >&2
    return 0
  fi

  echo "=== agent-claude autonomous runs ==="
  if [[ -d "${PLANNING_DIR}/runs" ]]; then
    ls -1 "${PLANNING_DIR}/runs" 2>/dev/null || echo "(none)"
  else
    echo "(none)"
  fi
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    preflight) cmd_preflight "$@" ;;
    start) cmd_start "$@" ;;
    score) cmd_score "$@" ;;
    status) cmd_status "$@" ;;
    -h|--help|"") usage; exit 0 ;;
    *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"

#!/usr/bin/env bash
# TUI friction monitor agent loop — polls health + findings, appends status every 10min.
set -uo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SB_ROOT"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
enterprise_e2e_prepend_harness_path
export SB_ROOT
enterprise_e2e_apply_matrix_host_defaults
MATRIX_HOST="$(enterprise_e2e_matrix_host)"
ROW_LOG_GLOB="$(enterprise_e2e_row_attempt_log_glob)"

STATUS_FILE=".planning/enterprise-e2e/.tui-monitor-agent-status.jsonl"
OFFSET_FILE=".planning/enterprise-e2e/.tui-monitor-agent-offset.json"
FINDINGS="${SB_E2E_TUI_FINDINGS:-.e2e-tui-watch-findings.jsonl}"
LEDGER="${SB_E2E_LEDGER_FILE:-.planning/enterprise-e2e/ROUND-3-LEDGER.md}"
BATCH_PID_FILE="${SB_E2E_MATRIX_BATCH_PID_FILE:-.e2e-matrix-batch.pid}"
MONITOR_PID_FILE="${SB_E2E_MATRIX_MONITOR_PID_FILE:-.e2e-matrix-monitor.pid}"
MATRIX_LOG="${SB_E2E_MATRIX_LOG:-.e2e-matrix-live.log}"
WATCH_PID_FILE="${SB_E2E_TUI_WATCH_PID:-.e2e-tui-watch.pid}"
LOCK_FILE="${SB_E2E_LIVE_TEST_LOCK_FILE:-.e2e-live-test.lock}"
export WATCH_PID_FILE MONITOR_PID_FILE BATCH_PID_FILE LOCK_FILE MATRIX_LOG
POLL_MIN=60
POLL_MAX=90
STATUS_INTERVAL=600
MAX_RUNTIME=21600
HUNG_SEC=2700
start_epoch=$(date +%s)
last_status_epoch=$start_epoch

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
alive() { local p="$1"; [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null; }

ensure_watch() {
  local pid=""
  [[ -f "$WATCH_PID_FILE" ]] && pid="$(tr -d '[:space:]' <"$WATCH_PID_FILE")"
  if ! alive "$pid"; then
    if ! pgrep -f 'watch-enterprise-e2e-tui.sh' >/dev/null 2>&1; then
      pid="$(sb_run_detached --log .e2e-tui-watch-restart.log -- env SB_E2E_LIVE_RUNTIME="$MATRIX_HOST" SILVER_BULLET_RUNTIME="$MATRIX_HOST" bash scripts/watch-enterprise-e2e-tui.sh)"
      echo "$pid" >"$WATCH_PID_FILE"
    fi
  fi
}

ensure_monitor() {
  local batch_pid="" mon_pid=""
  [[ -f "$BATCH_PID_FILE" ]] && batch_pid="$(tr -d '[:space:]' <"$BATCH_PID_FILE")"
  [[ -f "$MONITOR_PID_FILE" ]] && mon_pid="$(tr -d '[:space:]' <"$MONITOR_PID_FILE")"
  if alive "$batch_pid" && ! alive "$mon_pid" && ! pgrep -f 'monitor-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
    pid="$(sb_run_detached --log .e2e-matrix-monitor-restart.log -- env SB_E2E_LIVE_RUNTIME="$MATRIX_HOST" SILVER_BULLET_RUNTIME="$MATRIX_HOST" bash scripts/monitor-enterprise-e2e-matrix.sh)"
    echo "$pid" >"$MONITOR_PID_FILE"
  fi
}

count_passes() { grep -cE '^\s*PASS:' "$MATRIX_LOG" 2>/dev/null || echo 0; }

append_status() {
  local row="$1" action="$2" new_k="$3"
  local passes blockers_json
  passes="$(count_passes)"
  blockers_json='[]'
  python3 - "$STATUS_FILE" "$row" "$action" "$new_k" "$passes" <<'PY'
import json, os, sys
from datetime import datetime, timezone
status_file, row, action, new_k, passes = sys.argv[1:6]
pids = {}
for name, path in [("watch",os.environ.get("WATCH_PID_FILE",".e2e-tui-watch.pid")),("monitor",os.environ.get("MONITOR_PID_FILE",".e2e-matrix-monitor.pid")),("batch",os.environ.get("BATCH_PID_FILE",".e2e-matrix-batch.pid")),("lock",os.environ.get("LOCK_FILE",".e2e-live-test.lock"))]:
    if os.path.isfile(path):
        pids[name] = open(path).read().strip()
obj = {"ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "row": int(row), "pids": pids,
       "findings_new": int(new_k), "blockers": [], "ledger": f"{passes}/22", "action": action}
with open(status_file, "a") as f:
    f.write(json.dumps(obj) + "\n")
print(json.dumps(obj))
PY
}

while true; do
  now=$(date +%s)
  if (( now - start_epoch > MAX_RUNTIME )); then
    append_status 0 "escalate" 0
    exit 2
  fi

  ensure_watch
  ensure_monitor

  batch_pid=""
  [[ -f "$BATCH_PID_FILE" ]] && batch_pid="$(tr -d '[:space:]' <"$BATCH_PID_FILE")"
  if ! alive "$batch_pid" && ! pgrep -f 'run-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
    append_status 0 "escalate" 0
    exit 1
  fi

  active_row="$(ROW_LOG_GLOB="$ROW_LOG_GLOB" python3 -c "
import glob,os,re
pat=os.environ.get('ROW_LOG_GLOB','.e2e-row*-attempt.log')
logs=glob.glob(pat)
if not logs: print(0); exit()
best=max(logs,key=lambda p:(os.path.getmtime(p),os.path.getsize(p)))
m=re.search(r'row(\d+)',os.path.basename(best))
print(m.group(1) if m else 0)
")"

  active_log="$(enterprise_e2e_row_attempt_log "$active_row" 2>/dev/null || echo ".e2e-row${active_row}-attempt.log")"
  if [[ -f "$active_log" ]]; then
  python3 - "$active_log" "$HUNG_SEC" "$MATRIX_HOST" <<'PY' || true
import os, sys, subprocess, time
log, hung, host = sys.argv[1], int(sys.argv[2]), sys.argv[3]
if not os.path.isfile(log): sys.exit(0)
mtime = os.path.getmtime(log)
if time.time() - mtime < hung: sys.exit(0)
patterns = ["claude-interactive-invoke.expect"]
if host == "cursor":
    patterns.append("cursor-agent")
out = []
for pat in patterns:
    try:
        out += subprocess.check_output(["pgrep","-f", pat], text=True).strip().split()
    except subprocess.CalledProcessError:
        pass
for pid in out:
    subprocess.call(["kill","-TERM", pid])
    print(f"TERM driver {pid} host={host} hung>{hung}s")
PY
  fi

  if (( now - last_status_epoch >= STATUS_INTERVAL )); then
    append_status "$active_row" "watch" 0
    last_status_epoch=$now
  fi

  sleep $((POLL_MIN + RANDOM % (POLL_MAX - POLL_MIN + 1)))
done

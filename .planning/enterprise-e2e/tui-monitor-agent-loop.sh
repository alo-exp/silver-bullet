#!/usr/bin/env bash
# TUI friction monitor agent loop — polls health + findings, appends status every 10min.
set -uo pipefail
SB_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SB_ROOT"
# shellcheck source=scripts/lib/enterprise-e2e-live-common.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-live-common.sh"
enterprise_e2e_prepend_harness_path

STATUS_FILE=".planning/enterprise-e2e/.tui-monitor-agent-status.jsonl"
OFFSET_FILE=".planning/enterprise-e2e/.tui-monitor-agent-offset.json"
FINDINGS=".e2e-tui-watch-findings.jsonl"
LEDGER=".planning/enterprise-e2e/ROUND-3-LEDGER.md"
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
  [[ -f .e2e-tui-watch.pid ]] && pid="$(tr -d '[:space:]' <.e2e-tui-watch.pid)"
  if ! alive "$pid"; then
    if ! pgrep -f 'watch-enterprise-e2e-tui.sh' >/dev/null 2>&1; then
      pid="$(sb_run_detached --log .e2e-tui-watch-restart.log -- bash scripts/watch-enterprise-e2e-tui.sh)"
      echo "$pid" >.e2e-tui-watch.pid
    fi
  fi
}

ensure_monitor() {
  local batch_pid="" mon_pid=""
  [[ -f .e2e-matrix-batch.pid ]] && batch_pid="$(tr -d '[:space:]' <.e2e-matrix-batch.pid)"
  [[ -f .e2e-matrix-monitor.pid ]] && mon_pid="$(tr -d '[:space:]' <.e2e-matrix-monitor.pid)"
  if alive "$batch_pid" && ! alive "$mon_pid" && ! pgrep -f 'monitor-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
    pid="$(sb_run_detached --log .e2e-matrix-monitor-restart.log -- bash scripts/monitor-enterprise-e2e-matrix.sh)"
    echo "$pid" >.e2e-matrix-monitor.pid
  fi
}

count_passes() { grep -cE '^\s*PASS:' .e2e-matrix-live.log 2>/dev/null || echo 0; }

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
for name, path in [("watch",".e2e-tui-watch.pid"),("monitor",".e2e-matrix-monitor.pid"),("batch",".e2e-matrix-batch.pid"),("lock",".e2e-live-test.lock")]:
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
  [[ -f .e2e-matrix-batch.pid ]] && batch_pid="$(tr -d '[:space:]' <.e2e-matrix-batch.pid)"
  if ! alive "$batch_pid" && ! pgrep -f 'run-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
    append_status 0 "escalate" 0
    exit 1
  fi

  active_row="$(python3 -c "
import glob,os,re
logs=glob.glob('.e2e-row*-attempt.log')
if not logs: print(0); exit()
best=max(logs,key=lambda p:(os.path.getmtime(p),os.path.getsize(p)))
m=re.search(r'row(\d+)',os.path.basename(best))
print(m.group(1) if m else 0)
")"

  # hung expect: no log growth >45min
  if [[ -f ".e2e-row${active_row}-attempt.log" ]]; then
  python3 - "$active_row" "$HUNG_SEC" <<'PY' || true
import os, sys, subprocess, time
row, hung = int(sys.argv[1]), int(sys.argv[2])
log = f".e2e-row{row}-attempt.log"
if not os.path.isfile(log): sys.exit(0)
mtime = os.path.getmtime(log)
if time.time() - mtime < hung: sys.exit(0)
# find expect pid
out = subprocess.check_output(["pgrep","-f","claude-interactive-invoke.expect"], text=True).strip().split()
for pid in out:
    subprocess.call(["kill","-TERM", pid])
    print(f"TERM expect {pid} row={row} hung>{hung}s")
PY
  fi

  if (( now - last_status_epoch >= STATUS_INTERVAL )); then
    append_status "$active_row" "watch" 0
    last_status_epoch=$now
  fi

  sleep $((POLL_MIN + RANDOM % (POLL_MAX - POLL_MIN + 1)))
done

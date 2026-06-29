#!/usr/bin/env bash
# Turn-level Claude TUI watcher for enterprise E2E matrix batches.
# Reads incremental tails from .e2e-rowN-attempt.log, detects SB/UX issues,
# appends structured findings, and ensures the host matrix monitor stays alive.
#
# Usage (from SB repo root):
#   bash scripts/watch-enterprise-e2e-tui.sh &
#   echo $! > .e2e-tui-watch.pid
#
# Artifacts:
#   .e2e-tui-watch-offsets.json   — per-log byte offsets
#   .e2e-tui-watch-findings.jsonl — findings + 10-min status lines
#   .e2e-tui-watch.log            — watcher operational log
set -uo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SB_ROOT" || exit

OFFSETS_FILE="${SB_E2E_TUI_OFFSETS:-${SB_ROOT}/.e2e-tui-watch-offsets.json}"
FINDINGS_FILE="${SB_E2E_TUI_FINDINGS:-${SB_ROOT}/.e2e-tui-watch-findings.jsonl}"
WATCH_LOG="${SB_E2E_TUI_WATCH_LOG:-${SB_ROOT}/.e2e-tui-watch.log}"
WATCH_PID_FILE="${SB_E2E_TUI_WATCH_PID:-${SB_ROOT}/.e2e-tui-watch.pid}"
BATCH_PID_FILE="${SB_E2E_MATRIX_BATCH_PID_FILE:-${SB_ROOT}/.e2e-matrix-batch.pid}"
MATRIX_LOG="${SB_E2E_MATRIX_LOG:-${SB_ROOT}/.e2e-matrix-round5-batch-resume.log}"
LEDGER="${SB_E2E_LEDGER_FILE:-${SB_ROOT}/.planning/enterprise-e2e/ROUND-5-LEDGER.md}"
MONITOR_AUTO_RESTART="${SB_E2E_MONITOR_AUTO_RESTART:-0}"
MONITOR_SCRIPT="${SB_ROOT}/scripts/monitor-enterprise-e2e-matrix.sh"
MONITOR_PID_FILE="${SB_E2E_MATRIX_MONITOR_PID_FILE:-${SB_ROOT}/.e2e-matrix-monitor.pid}"

POLL_MIN="${SB_E2E_TUI_POLL_MIN:-60}"
POLL_MAX="${SB_E2E_TUI_POLL_MAX:-120}"
STATUS_INTERVAL="${SB_E2E_TUI_STATUS_INTERVAL:-600}"
MAX_RUNTIME="${SB_E2E_TUI_MAX_SEC:-21600}"
HUNG_SEC="${SB_E2E_TUI_HUNG_SEC:-5400}"

utc_now() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '%s %s\n' "$(utc_now)" "$*" | tee -a "$WATCH_LOG"; }

echo $$ >"$WATCH_PID_FILE"
log "tui-watch started pid=$$ max_runtime=${MAX_RUNTIME}s poll=${POLL_MIN}-${POLL_MAX}s"

[[ -f "$OFFSETS_FILE" ]] || echo '{}' >"$OFFSETS_FILE"
touch "$FINDINGS_FILE"

discover_batch_pid() {
  local pid
  if [[ -f "$BATCH_PID_FILE" ]]; then
    pid="$(tr -d '[:space:]' <"$BATCH_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      printf '%s' "$pid"
      return 0
    fi
  fi
  pid="$(pgrep -f 'bash scripts/run-enterprise-e2e-matrix.sh' 2>/dev/null | sort -n | head -1 || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    printf '%s' "$pid" >"$BATCH_PID_FILE"
    printf '%s' "$pid"
    return 0
  fi
  return 1
}

ensure_monitor_alive() {
  local pid
  if [[ -f "$MONITOR_PID_FILE" ]]; then
    pid="$(tr -d '[:space:]' <"$MONITOR_PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  if pgrep -f 'monitor-enterprise-e2e-matrix.sh' >/dev/null 2>&1; then
    pgrep -f 'monitor-enterprise-e2e-matrix.sh' | head -1 >"$MONITOR_PID_FILE"
    return 0
  fi
  log "monitor dead — restarting (no duplicate matrix)"
  SB_E2E_MATRIX_LOG="$MATRIX_LOG" \
  SB_E2E_LEDGER_FILE="$LEDGER" \
  SB_E2E_MONITOR_AUTO_RESTART="$MONITOR_AUTO_RESTART" \
  bash "$MONITOR_SCRIPT" &
  echo $! >"$MONITOR_PID_FILE"
  log "monitor restarted pid=$(cat "$MONITOR_PID_FILE")"
}

append_finding() {
  local line="$1"
  printf '%s\n' "$line" >>"$FINDINGS_FILE"
}

append_ledger_ux() {
  local row="$1" severity="$2" component="$3" quote="$4"
  local marker="tui-watch|row${row}|${component}|${quote:0:40}"
  if grep -qF "$marker" "$LEDGER" 2>/dev/null; then
    return 0
  fi
  {
    printf '| %s | %s | %s | %s | tui-watch %s |\n' \
      "$row" "$severity" "$component" "${quote:0:80}" "$(utc_now)"
  } >>"$LEDGER"
  log "ledger UX: row=$row $severity $component"
}

analyze_chunk() {
  local row="$1" chunk_file="$2"
  python3 - "$row" "$chunk_file" <<'PY'
import json, re, sys
from datetime import datetime, timezone

row, chunk_path = sys.argv[1], sys.argv[2]
with open(chunk_path, 'rb') as f:
    raw = f.read()
try:
    chunk = raw.decode('utf-8', errors='replace')
except Exception:
    chunk = str(raw)
ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# Strip ANSI / terminal control sequences
text = re.sub(r'\x1b\[[0-9;?]*[ -/]*[@-~]', '', chunk)
text = re.sub(r'\x1b\][^\x07]*\x07', '', text)
text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', ' ', text)

findings = []

def emit(severity, category, message, excerpt=""):
    findings.append({
        "ts": ts, "row": int(row), "severity": severity,
        "category": category, "message": message,
        "excerpt": (excerpt or message)[:200]
    })

# --- SB routing ---
for m in re.finditer(r'SILVER BULLET\s*[►>]\s*ROUTING[^\n]*', text, re.I):
    line = m.group(0).strip()
    emit("info", "routing", line, line)
    if re.search(r'routing.*silver:(?!feature|bugfix|fast|orchestrator)', line, re.I):
        emit("annoyance", "routing", f"unexpected route: {line}", line)

# Wrong skill / not registered
for pat in [
    r'orchestrator skill is not registered',
    r'skill is not registered',
    r'Unknown skill',
    r'No such skill',
]:
    for m in re.finditer(pat, text, re.I):
        emit("blocker", "skill", m.group(0), text[max(0,m.start()-40):m.end()+40])

# --- Hook errors ---
for pat in [
    (r'hookEventName', 'hook', 'annoyance'),
    (r'Stop hook error', 'hook', 'annoyance'),
    (r'stage enforcer', 'hook', 'blocker'),
    (r'planning-file-guard', 'hook', 'blocker'),
    (r'PostToolUse:.*hook error', 'hook', 'annoyance'),
    (r'PreToolUse:.*hook error', 'hook', 'annoyance'),
]:
    rx, cat, sev = pat
    for m in re.finditer(rx, text, re.I):
        ctx = text[max(0,m.start()-20):m.end()+80].replace('\n', ' ')
        emit(sev, cat, m.group(0), ctx)

# --- UX friction ---
for pat, cat, sev in [
    (r'ORCHESTRATOR PARENT.*forbidden', 'orchestrator', 'annoyance'),
    (r'parent must not implement inline', 'orchestrator', 'info'),
    (r'clarify', 'clarify', 'info'),
    (r'Not logged in', 'auth', 'info'),
    (r'0\s*tokens', 'stall', 'annoyance'),
    (r'timed out waiting for Claude', 'harness', 'blocker'),
    (r'API Error:.*429', 'quota', 'info'),
    (r'Token Plan usage limit', 'quota', 'info'),
    (r'ConnectionRefused', 'network', 'info'),
    (r'ENOTFOUND', 'network', 'info'),
    (r'Unable to connect to API', 'network', 'info'),
]:
    for m in re.finditer(pat, text, re.I):
        ctx = text[max(0,m.start()-30):m.end()+60].replace('\n', ' ')
        emit(sev, cat, m.group(0), ctx)

# Dual-orchestrator confusion heuristic
if re.search(r'orchestrator', text, re.I) and re.search(r'/silver:', text):
    if re.search(r'(parent|inline|spawn|Task)', text, re.I):
        emit("annoyance", "orchestrator", "dual-orchestrator / slash-skill deliberation", text[-300:].replace('\n', ' ')[:200])

# --- Nonsensical behavior ---
if re.search(r'silver-orchestrator', text, re.I) and re.search(r'(Write|Edit|StrReplace|```)', text):
    emit("annoyance", "orchestrator", "orchestrator parent may be implementing inline", text[-250:].replace('\n', ' ')[:200])

for line in findings:
    print(json.dumps(line, ensure_ascii=False))
PY
}

find_active_row() {
  python3 - "$SB_ROOT" <<'PY'
import glob, os, sys
root = sys.argv[1]
logs = sorted(glob.glob(os.path.join(root, ".e2e-row*-attempt.log")))
if not logs:
    print("0")
    sys.exit(0)
# Prefer largest mtime; tie-break by size
best = max(logs, key=lambda p: (os.path.getmtime(p), os.path.getsize(p)))
m = __import__('re').search(r'row(\d+)-attempt', os.path.basename(best))
print(m.group(1) if m else "0")
PY
}

read_new_tail() {
  local logfile="$1"
  local key="$2"
  python3 - "$logfile" "$OFFSETS_FILE" "$key" <<'PY'
import json, os, sys
path, offsets_path, key = sys.argv[1:4]
offsets = {}
if os.path.isfile(offsets_path):
    with open(offsets_path) as f:
        offsets = json.load(f)
start = int(offsets.get(key, 0))
size = os.path.getsize(path) if os.path.isfile(path) else 0
if size < start:
    start = 0
with open(path, 'rb') as f:
    f.seek(start)
    data = f.read()
offsets[key] = start + len(data)
with open(offsets_path, 'w') as f:
    json.dump(offsets, f, indent=2)
sys.stdout.buffer.write(data)
PY
}

count_matrix_passes() {
  local n
  n="$(grep -cE '^\s*PASS:' "$MATRIX_LOG" 2>/dev/null || true)"
  echo "${n:-0}"
}

matrix_complete() {
  if grep -qE 'MATRIX (COMPLETE|DONE|FINISHED)|All rows (passed|complete)' "$MATRIX_LOG" 2>/dev/null; then
    return 0
  fi
  local passes expected
  passes="$(count_matrix_passes)"
  expected="${SB_E2E_MATRIX_EXPECTED_ROWS:-12}"
  if [[ "$passes" -ge "$expected" ]]; then
  # Also verify batch not running
    local pid
    if ! discover_batch_pid >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

last_growth_epoch=""
last_growth_size=0
last_growth_file=""
issue_count=0
start_epoch="$(date +%s)"
last_status_epoch="$start_epoch"

trap 'log "tui-watch signal — exiting"; exit 0' INT TERM

while true; do
  now="$(date +%s)"
  if (( now - start_epoch > MAX_RUNTIME )); then
    log "max runtime ${MAX_RUNTIME}s — exiting"
    append_finding "$(jq -nc --arg ts "$(utc_now)" \
      --argjson issues "$issue_count" \
      '{type:"final",ts:$ts,reason:"max_runtime",issues:$issues}')"
    break
  fi

  ensure_monitor_alive

  batch_pid=""
  if discover_batch_pid >/dev/null 2>&1; then
    batch_pid="$(discover_batch_pid)"
  fi

  if matrix_complete; then
    log "matrix complete — exiting"
    append_finding "$(jq -nc --arg ts "$(utc_now)" --argjson issues "$issue_count" \
      '{type:"final",ts:$ts,reason:"matrix_complete",issues:$issues,passes:'"$(count_matrix_passes)"'}')"
    break
  fi

  active_row="$(find_active_row)"
  active_log="${SB_ROOT}/.e2e-row${active_row}-attempt.log"

  # Scan all row logs that grew since last pass
  grew=0
  chunk_tmp="$(mktemp "${TMPDIR:-/tmp}/e2e-tui-chunk.XXXXXX")"
  trap 'rm -f "$chunk_tmp"' RETURN
  for logfile in "${SB_ROOT}"/.e2e-row*-attempt.log; do
    [[ -f "$logfile" ]] || continue
    key="$(basename "$logfile")"
    read_new_tail "$logfile" "$key" >"$chunk_tmp"
    clen="$(wc -c <"$chunk_tmp" | tr -d ' ')"
    if (( clen > 0 )); then
      grew=1
      row="$(echo "$key" | sed -n 's/\.e2e-row\([0-9]*\)-attempt\.log/\1/p')"
      while IFS= read -r finding; do
        [[ -n "$finding" ]] || continue
        append_finding "$finding"
        issue_count=$((issue_count + 1))
        sev="$(printf '%s' "$finding" | jq -r '.severity // "info"')"
        cat="$(printf '%s' "$finding" | jq -r '.category // "unknown"')"
        msg="$(printf '%s' "$finding" | jq -r '.message // ""')"
        if [[ "$sev" == "blocker" ]]; then
          append_ledger_ux "$row" "$sev" "$cat" "$msg"
        fi
      done < <(analyze_chunk "$row" "$chunk_tmp")
    fi
  done
  rm -f "$chunk_tmp"
  trap - RETURN

  # Hung detection: no growth on active log for HUNG_SEC
  if [[ -f "$active_log" ]]; then
    cur_size="$(wc -c <"$active_log" | tr -d ' ')"
    if [[ "$active_log" != "$last_growth_file" ]] || [[ "$cur_size" != "$last_growth_size" ]]; then
      last_growth_file="$active_log"
      last_growth_size="$cur_size"
      last_growth_epoch="$now"
    elif [[ -n "$last_growth_epoch" ]] && (( now - last_growth_epoch > HUNG_SEC )); then
      append_finding "$(jq -nc --arg ts "$(utc_now)" --arg row "$active_row" \
        --argjson sec "$HUNG_SEC" \
        '{type:"finding",ts:$ts,row:($row|tonumber),severity:"blocker",category:"stall",message:("no log growth for "+($sec|tostring)+"s"),excerpt:("active row "+$row)}')"
      log "WARN hung: row $active_row no growth ${HUNG_SEC}s (not killing claude)"
      last_growth_epoch="$now"
    fi
  fi

  if (( now - last_status_epoch >= STATUS_INTERVAL )); then
  last_interaction=""
  if [[ -f "$active_log" ]]; then
    last_interaction="$(tail -c 4000 "$active_log" 2>/dev/null | strings | grep -vE '^[[:space:]]*$' | tail -3 | tr '\n' ' ' | cut -c1-120)"
  fi
  passes="$(count_matrix_passes)"
  status_line="$(jq -nc \
    --arg ts "$(utc_now)" \
    --arg row "$active_row" \
    --arg summary "$last_interaction" \
    --argjson issues "$issue_count" \
    --argjson passes "$passes" \
    --arg batch "${batch_pid:-none}" \
    '{type:"status",ts:$ts,active_row:($row|tonumber),batch_pid:$batch,passes:$passes,issues:$issues,last_interaction:$summary}')"
    append_finding "$status_line"
    log "status row=$active_row passes=$passes issues=$issue_count batch=${batch_pid:-dead}"
    last_status_epoch="$now"
  fi

  # Adaptive sleep: shorter if logs grew
  if (( grew )); then
    sleep_sec="$POLL_MIN"
  else
    sleep_sec=$((POLL_MIN + RANDOM % (POLL_MAX - POLL_MIN + 1)))
  fi
  sleep "$sleep_sec"
done

log "tui-watch finished issues=$issue_count"
exit 0

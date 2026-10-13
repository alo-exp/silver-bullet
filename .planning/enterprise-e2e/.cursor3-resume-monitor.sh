#!/usr/bin/env bash
# Resume monitor: wait for rows 15-22, process each, update ledger summary.
set -euo pipefail
SB=/Users/shafqat/projects/silver-bullet/repo
FIX=/Users/shafqat/projects/enterprise-grade-test-app-cursor
STATE=$SB/.planning/enterprise-e2e/cursor3-real-pipeline.state
LEDGER=$SB/.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md
PROC=$SB/.planning/enterprise-e2e/.cursor3-process-row.sh
LOG=$SB/.e2e-cursor3-resume-monitor.log

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"; }

slug_for() {
  case "$1" in
    15) echo review-triad ;; 16) echo ship-readiness ;; 17) echo silver-incident ;;
    18) echo silver-retro ;; 19) echo silver-forensics ;; 20) echo process-maintenance ;;
    21) echo post-exec-gates ;; 22) echo validate-substep ;; *) echo row-$1 ;;
  esac
}

update_ledger_row() {
  local row=$1 slug=$2 bytes=$3 sha=$4
  python3 - "$row" "$slug" "$bytes" "$sha" "$LEDGER" <<'PY'
import re, sys
row, slug, nbytes, sha, path = sys.argv[1:6]
text = open(path).read()
line = f"| {row} | `{slug}` | **PASS** | {nbytes} | `{sha}` | batch3 resume live |"
if re.search(rf'^\| {row} \| `{re.escape(slug)}` \|', text, re.M):
    text = re.sub(rf'^\| {row} \| `{re.escape(slug)}` \|[^\n]*\n', line + '\n', text, count=1)
else:
    m = re.search(r'(\| 14 \| `silver-release`[^\n]+\n)', text)
    if m:
        text = text[:m.end()] + line + '\n' + text[m.end():]
    else:
        text += '\n' + line + '\n'
n = len(re.findall(r'^\| \d+ \| `[^`]+` \| \*\*PASS\*\*', text, re.M))
text = re.sub(r'\*In progress — \d+/22 rows PASS[^\n]*\*', f'*In progress — {n}/22 rows PASS; see matrix table.*', text)
text = re.sub(r'\| Full matrix 22/22 \| pending \(\d+/22 PASS\) \|', f'| Full matrix 22/22 | pending ({n}/22 PASS) |', text)
open(path, 'w').write(text)
print(f'ledger row {row} updated ({n}/22)')
PY
}

log "resume-monitor start rows 15-22"
for row in $(seq 15 22); do
  log "waiting row $row"
  for poll in $(seq 1 120); do
    grep -q "^ROW_${row}:DONE" "$STATE" 2>/dev/null && break
    sleep 60
    bytes=$(wc -c < "$SB/.e2e-row${row}-cursor-attempt.log" 2>/dev/null | tr -d ' ')
    log "poll row${row} bytes=${bytes:-0}"
  done
  if ! grep -q "^ROW_${row}:DONE" "$STATE"; then
    log "STALL row $row"; exit 1
  fi
  slug=$(slug_for "$row")
  if result=$(bash "$PROC" "$row" 2>&1); then
    sha=$(git -C "$FIX" rev-parse --short HEAD)
    bytes=$(wc -c < "$SB/.e2e-row${row}-cursor-attempt.log" | tr -d ' ')
    update_ledger_row "$row" "$slug" "$bytes" "$sha"
    log "PASS row $row $result"
  else
    log "FAIL row $row: $result"
    exit 1
  fi
done
log "ALL_ROWS_15_22_DONE — trigger Phase C via monitor"

#!/usr/bin/env bash
# Double-fork poll watcher for codex-r8-tierbc driver (PID = live-test batch root).
# Usage: .codex-r8-tierbc-poll-watch.sh <batch_pid> [poll_interval_sec]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BATCH_PID="${1:?batch pid required}"
INTERVAL="${2:-90}"
LOG="${ROOT}/.planning/enterprise-e2e/.codex-r8-tierbc-poll.log"
MATRIX_LOG="${ROOT}/.e2e-matrix-codex-live.log"
LEDGER="${ROOT}/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md"

log_line() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"
}

score_n22() {
  python3 - <<'PY' "$LEDGER" 2>/dev/null || echo "?"
import re, sys
led = open(sys.argv[1], errors='replace').read()
# workflow matrix rows 1-22 only (slug column present)
passes = len(re.findall(r'^\|\s*(\d{1,2})\s*\|\s*`[^`]+`\s*\|[^|]*\|\s*\*\*Pass\*\*', led, re.M | re.I))
fails = len(re.findall(r'^\|\s*(\d{1,2})\s*\|\s*`[^`]+`\s*\|[^|]*\|\s*\*\*Fail\*\*', led, re.M | re.I))
print(f"{passes}/22 ({fails} fail)")
PY
}

log_line "POLL start batch=${BATCH_PID} interval=${INTERVAL}s branch=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown) ledger=$(score_n22)"

while kill -0 "$BATCH_PID" 2>/dev/null; do
  row="$(strings "$MATRIX_LOG" 2>/dev/null | grep '^=== Row ' | tail -1 || true)"
  child="$(pgrep -P "$BATCH_PID" 2>/dev/null | head -1 || true)"
  log_line "BATCH=${BATCH_PID} RUNNING ${row} child=${child} ledger=$(score_n22)"
  sleep "$INTERVAL"
done

log_line "BATCH=${BATCH_PID} EXIT ledger=$(score_n22)"
summary="$(strings "$MATRIX_LOG" 2>/dev/null | grep -E '^(=== Matrix summary|Pass:|Fail:|Total:)' | tail -6 || true)"
while IFS= read -r line; do
  [[ -n "$line" ]] && log_line "SUMMARY: $line"
done <<<"$summary"

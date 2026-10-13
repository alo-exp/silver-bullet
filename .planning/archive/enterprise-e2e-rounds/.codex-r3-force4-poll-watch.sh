#!/usr/bin/env bash
# Double-fork poll watcher for codex-r3-force4 batch.
# Usage: .codex-r3-force4-poll-watch.sh <batch_pid> [poll_interval_sec]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BATCH_PID="${1:?batch pid required}"
INTERVAL="${2:-75}"
LOG="${ROOT}/.planning/enterprise-e2e/.codex-r3-force4-poll.log"
MATRIX_LOG="${ROOT}/.e2e-matrix-codex-live.log"

log_line() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"
}

log_line "POLL start batch=${BATCH_PID} interval=${INTERVAL}s branch=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"

while kill -0 "$BATCH_PID" 2>/dev/null; do
  row="$(strings "$MATRIX_LOG" 2>/dev/null | grep '^=== Row ' | tail -1 || true)"
  child="$(pgrep -P "$BATCH_PID" 2>/dev/null | head -1 || true)"
  log_line "BATCH=${BATCH_PID} RUNNING ${row} child=${child}"
  sleep "$INTERVAL"
done

log_line "BATCH=${BATCH_PID} EXIT"
summary="$(strings "$MATRIX_LOG" 2>/dev/null | grep -E '^(=== Matrix summary|Pass:|Fail:|Total:)' | tail -6 || true)"
while IFS= read -r line; do
  [[ -n "$line" ]] && log_line "SUMMARY: $line"
done <<<"$summary"

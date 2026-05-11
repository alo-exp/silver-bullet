#!/usr/bin/env bash
set -euo pipefail
# Fail-open: never block; this is a debug-only hook.
trap 'exit 0' ERR

# Debug hook to dump Codex/Claude hook payloads for local troubleshooting.
# Enabled only when the flag file exists:
#   ~/.claude/.silver-bullet/debug-dump
#
# Writes JSON payload lines to:
#   ~/.claude/.silver-bullet/hook-dump.jsonl

umask 0077

DBG_DIR="${HOME}/.claude/.silver-bullet"
DBG_FLAG="${DBG_DIR}/debug-dump"
DBG_OUT="${DBG_DIR}/hook-dump.jsonl"

if [[ ! -f "$DBG_FLAG" || -L "$DBG_FLAG" ]]; then
  # Consume stdin if present to satisfy hook protocol, but don't block.
  if [[ ! -t 0 ]]; then
    cat >/dev/null 2>&1 || true
  fi
  exit 0
fi

payload=""
if [[ ! -t 0 ]]; then
  payload="$(cat 2>/dev/null || true)"
fi
[[ -n "$payload" ]] || exit 0

mkdir -p "$DBG_DIR" 2>/dev/null || true
printf '%s\n' "$payload" >>"$DBG_OUT" 2>/dev/null || true

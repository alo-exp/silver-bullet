#!/usr/bin/env bash
set -euo pipefail
# Fail-open: never block; this is a debug-only hook.
trap 'exit 0' ERR

# Debug hook to dump Codex/Claude hook payloads for local troubleshooting.
# Enabled only when the flag file exists:
#   <host runtime>/.silver-bullet/debug-dump
#
# Writes JSON payload lines to:
#   <host runtime>/.silver-bullet/hook-dump.jsonl

umask 0077

# Source runtime path selector so the debug dump follows the host runtime.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi

DBG_DIR="${SB_RUNTIME_STATE_DIR}"
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

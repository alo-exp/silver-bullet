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
#
# Payloads contain commands and file contents, so the dump is bounded (R3-33): the flag expires
# after SB_DEBUG_DUMP_TTL_SECONDS (default 4 h), the file rotates past 5 MB, token-like values
# are redacted, and session-start warns while the flag is present.

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

# Expire the flag: a forgotten debug switch must not record every payload forever.
flag_mtime="$(stat -f %m "$DBG_FLAG" 2>/dev/null)" || flag_mtime=""
[[ "$flag_mtime" =~ ^[0-9]+$ ]] || flag_mtime="$(stat -c %Y "$DBG_FLAG" 2>/dev/null)"
ttl="${SB_DEBUG_DUMP_TTL_SECONDS:-14400}"
[[ "$ttl" =~ ^[0-9]+$ ]] || ttl=14400
if [[ "$flag_mtime" =~ ^[0-9]+$ ]] && (( $(date +%s) - flag_mtime > ttl )); then
  rm -f -- "$DBG_FLAG"
  exit 0
fi
[[ -n "$payload" ]] || exit 0

mkdir -p "$DBG_DIR" 2>/dev/null || true
if [[ -L "$DBG_OUT" ]]; then exit 0; fi
# Rotate past 5 MB (one generation kept).
out_size="$(wc -c <"$DBG_OUT" 2>/dev/null | tr -d ' ' || true)"
if [[ "$out_size" =~ ^[0-9]+$ ]] && (( out_size > 5242880 )); then
  mv -f -- "$DBG_OUT" "${DBG_OUT}.1"
fi
# Redact token-like values before they reach the file.
printf '%s\n' "$payload" \
  | sed -E \
    -e 's/gh[pousr]_[A-Za-z0-9]{20,}/[REDACTED]/g' \
    -e 's/github_pat_[A-Za-z0-9_]{20,}/[REDACTED]/g' \
    -e 's/sk-[A-Za-z0-9_-]{16,}/[REDACTED]/g' \
    -e 's/AKIA[0-9A-Z]{16}/[REDACTED]/g' \
    -e 's/xox[abprs]-[A-Za-z0-9-]{10,}/[REDACTED]/g' \
    -e 's/(([Pp][Aa][Ss][Ss]([Ww][Oo][Rr])?[Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy])[^A-Za-z0-9]{1,6})[^ ",}\\]+/\1[REDACTED]/g' \
    >>"$DBG_OUT"

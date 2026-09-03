#!/usr/bin/env bash
# PreToolUse — shell compression: RTK primary, lean-ctx fallback only if RTK missing.
set -euo pipefail
_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
source "$_LIB/common.sh"
primary="$(ts_shell_compression_primary 2>/dev/null || echo rtk)"
fallback="$(ts_shell_compression_fallback 2>/dev/null || echo leanctx)"
case "$primary" in
  rtk) command -v rtk >/dev/null 2>&1 && exec rtk hook cursor ;;
  leanctx) command -v lean-ctx >/dev/null 2>&1 && exec lean-ctx hook rewrite ;;
esac
case "$fallback" in
  rtk) command -v rtk >/dev/null 2>&1 && exec rtk hook cursor ;;
  leanctx) command -v lean-ctx >/dev/null 2>&1 && exec lean-ctx hook rewrite ;;
esac
exit 0

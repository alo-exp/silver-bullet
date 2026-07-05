#!/usr/bin/env bash
# PostToolUse hook — semantic context compression gate.
# Exits immediately for non-phase skills (< 10ms overhead).
set -euo pipefail
trap 'exit 0' ERR

# Security: restrict file creation permissions (user-only)
umask 0077

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
[[ -z "$input" ]] && exit 0

skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""' 2>/dev/null || true)

case "${skill:-}" in
  silver:execute|silver:plan|silver:context|silver:deep-research|\
  silver-execute|silver-plan|silver-context|silver-deep-research) ;;
  *) exit 0 ;;
esac

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_active_or_exit
fi

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HOOK_DIR/../scripts/semantic-compress.sh"

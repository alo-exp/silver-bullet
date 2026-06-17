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
  silver:execute|silver:plan|silver:context|silver:research|\
  silver-execute|silver-plan|silver-context|silver-research) ;;
  *) exit 0 ;;
esac

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HOOK_DIR/../scripts/semantic-compress.sh"

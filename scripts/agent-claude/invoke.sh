#!/usr/bin/env bash
# Invoke wrapper: preflight → env → agent-claude-delegate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent-claude/lib.sh
source "${SCRIPT_DIR}/lib.sh"
REPO_ROOT="$(agent_claude_repo_root)"
DELEGATE="${REPO_ROOT}/scripts/agent-claude-delegate.sh"
SKIP_PREFLIGHT=0
DELEGATE_ARGS=()

usage() {
  cat <<'EOF'
Usage: invoke.sh [--skip-preflight] <agent-claude-delegate.sh args>

Runs preflight + env defaults, then delegates to scripts/agent-claude-delegate.sh.
All delegate flags (--work-dir, --use-print, --brief-file, etc.) pass through.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-preflight) SKIP_PREFLIGHT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; DELEGATE_ARGS+=("$@"); break ;;
    *) DELEGATE_ARGS+=("$1"); shift ;;
  esac
done

export SB_ROOT="${SB_ROOT:-$REPO_ROOT}"

agent_claude_apply_delegate_env

if [[ "$SKIP_PREFLIGHT" -eq 0 ]]; then
  bash "${SCRIPT_DIR}/preflight.sh" --sb-root "$SB_ROOT"
fi

[[ -x "$DELEGATE" ]] || { printf 'ERROR: missing delegate: %s\n' "$DELEGATE" >&2; exit 1; }
exec bash "$DELEGATE" "${DELEGATE_ARGS[@]}"

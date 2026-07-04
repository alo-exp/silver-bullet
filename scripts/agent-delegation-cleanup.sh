#!/usr/bin/env bash
# Clear stale active delegation state after crash or cancel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=hooks/lib/runtime-paths.sh
source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
# shellcheck source=hooks/lib/agent-delegation-state.sh
source "${REPO_ROOT}/hooks/lib/agent-delegation-state.sh"

usage() {
  cat <<'EOF'
Usage: agent-delegation-cleanup.sh [--force]

Clears session-scoped agent-delegation-active.json when delegation ended abnormally.
Preserves completed artifacts under .planning/agent-<host>/<task-id>/.
EOF
}

force=0
[[ "${1:-}" == "--force" ]] && force=1
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

if [[ "$force" == "1" ]]; then
  sb_agent_delegation_deactivate
  printf 'agent-delegation state cleared\n'
  exit 0
fi

if sb_agent_delegation_is_active; then
  printf 'delegation still active — use --force to clear\n' >&2
  exit 1
fi

sb_agent_delegation_deactivate
printf 'no active delegation (state file removed if present)\n'

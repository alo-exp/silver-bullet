#!/usr/bin/env bash
# Install host-global Cursor toolstack hooks, rules, MCP merge, hooks.json patch.
# Delegates five-tool reconciliation to scripts/reconcile-recommended-tools.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOYED="${HOME}/.cursor/hooks/toolstack/install.sh"
SRC="${REPO_ROOT}/scripts/lib/global-toolstack"
GENERIC_SRC="${REPO_ROOT}/scripts/lib/five_tool_runtime"
GENERIC_DST="${HOME}/.cursor/hooks/toolstack/lib/five_tool_runtime"
PROJECT_ROOT="${SB_RECONCILE_PROJECT_ROOT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: bash scripts/install-global-toolstack.sh [--project-root PATH]"
      exit 0
      ;;
    *) shift ;;
  esac
done

mkdir -p "${HOME}/.cursor/hooks/toolstack/lib" "${HOME}/.cursor/state/toolstack"

# Stage all global-toolstack artifacts
for f in "${SRC}"/*; do
  base="$(basename "$f")"
  case "$base" in
    common.sh) cp -f "$f" "${HOME}/.cursor/hooks/toolstack/lib/common.sh" ;;
    install-body.sh) cp -f "$f" "$DEPLOYED" ;;
    *.sh)
      cp -f "$f" "${HOME}/.cursor/hooks/toolstack/${base}" 2>/dev/null || true
      chmod +x "${HOME}/.cursor/hooks/toolstack/${base}" 2>/dev/null || true
      ;;
    *.py) cp -f "$f" "${HOME}/.cursor/hooks/toolstack/${base}" 2>/dev/null || true ;;
    *.mdc) ;;
  esac
done

# Stage the SB-independent runtime beside the deployed adapter.  The adapter
# first looks here, then falls back to the source-tree sibling for in-repo use.
mkdir -p "$GENERIC_DST"
cp -f "$GENERIC_SRC"/*.py "$GENERIC_DST/"

chmod +x "$DEPLOYED" 2>/dev/null || true

export TOOLSTACK_REPO_ROOT="$REPO_ROOT"
export SB_RECONCILE_PROJECT_ROOT="$PROJECT_ROOT"
exec bash "$DEPLOYED"

#!/usr/bin/env bash
# Install host-global Cursor toolstack hooks, rules, MCP merge, hooks.json patch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOYED="${HOME}/.cursor/hooks/toolstack/install.sh"
SRC="${REPO_ROOT}/scripts/lib/global-toolstack"

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

chmod +x "$DEPLOYED" 2>/dev/null || true

export TOOLSTACK_REPO_ROOT="$REPO_ROOT"
exec bash "$DEPLOYED"

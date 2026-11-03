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
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/install-global-toolstack.sh [--project-root PATH] [--force]

Installs the machine-wide Cursor toolstack (hooks, rules, MCP merge) for the tools the user
granted "wire" consent for (bash scripts/sb-consent.sh status; docs/CONSENT.md). Does nothing
when no tool is consented or Cursor is not installed (--force skips the Cursor check).
EOF
      exit 0
      ;;
    *) shift ;;
  esac
done

# shellcheck source=../hooks/lib/user-consent.sh
source "${REPO_ROOT}/hooks/lib/user-consent.sh"
wired=0
for tool in graphify agentmemory rtk context_mode leanctx; do
  sb_consent_granted "$tool" wire && wired=1
done
if [[ "$wired" -eq 0 ]]; then
  echo "SKIP: global toolstack - no tool has your 'wire' consent."
  echo "  To allow it: bash ${SCRIPT_DIR}/sb-consent.sh grant <tool> --all-projects --capabilities wire"
  exit 0
fi
if [[ "$FORCE" -eq 0 && ! -d "${HOME}/.cursor" ]] && ! command -v cursor >/dev/null 2>&1 && ! command -v cursor-agent >/dev/null 2>&1; then
  echo "SKIP: global toolstack - Cursor is not installed on this machine (--force to install anyway)."
  exit 0
fi

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
    # The deployed install-body.sh only finds this rule next to itself.
    global-recommended-tools.mdc) cp -f "$f" "${HOME}/.cursor/hooks/toolstack/${base}" 2>/dev/null || true ;;
    *.mdc) ;;
  esac
done

# Stage the SB-independent runtime beside the deployed adapter.  The adapter
# first looks here, then falls back to the source-tree sibling for in-repo use.
mkdir -p "$GENERIC_DST"
cp -f "$GENERIC_SRC"/*.py "$GENERIC_DST/"
# The config writers import this beside themselves when deployed.
cp -f "${REPO_ROOT}/scripts/lib/sb_host_config.py" "${HOME}/.cursor/hooks/toolstack/sb_host_config.py"

chmod +x "$DEPLOYED" 2>/dev/null || true

export TOOLSTACK_REPO_ROOT="$REPO_ROOT"
export SB_RECONCILE_PROJECT_ROOT="$PROJECT_ROOT"
exec bash "$DEPLOYED"

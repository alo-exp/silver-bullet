#!/usr/bin/env bash
# Install Cursor always-on rules for all SB recommended tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_GLOBAL=0
RULES_DIR="${REPO_ROOT}/.cursor/rules"

usage() {
  cat <<'EOF'
Usage: bash scripts/install-recommended-tools-cursor.sh [--global]

Installs always-on Cursor rules for SB recommended tools under the project
.cursor/rules/ directory. With --global, also syncs context-mode and
token-compression rules to ~/.cursor/rules/ (authoritative for all workspaces).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) INSTALL_GLOBAL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

install_rule() {
  local name="$1"
  local dest_dir="$2"
  local src="${RULES_DIR}/${name}"
  if [[ ! -f "$src" ]]; then
    printf 'WARN: missing rule file %s\n' "$src" >&2
    return 1
  fi
  if [[ "$dest_dir" != "$RULES_DIR" ]]; then
    mkdir -p "$dest_dir"
    cp "$src" "${dest_dir}/${name}"
  fi
  printf 'OK: %s\n' "${dest_dir}/${name}"
}

if command -v graphify >/dev/null 2>&1; then
  graphify cursor install 2>/dev/null || true
fi

install_rule graphify.mdc "$RULES_DIR"
install_rule agentmemory.mdc "$RULES_DIR"
install_rule recommended-tools.mdc "$RULES_DIR"
install_rule leanctx.mdc "$RULES_DIR"

if [[ -f "${RULES_DIR}/context-mode.mdc" ]]; then
  :
elif command -v context-mode >/dev/null 2>&1; then
  cm_pkg="$(npm root -g 2>/dev/null)/context-mode"
  if [[ -f "${cm_pkg}/configs/cursor/context-mode.mdc" ]]; then
    cp "${cm_pkg}/configs/cursor/context-mode.mdc" "${RULES_DIR}/context-mode.mdc"
  fi
fi

TOKEN_ENFORCE_TPL="${REPO_ROOT}/scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc"
if [[ ! -f "${RULES_DIR}/token-compression-enforcement.mdc" ]] && [[ -f "$TOKEN_ENFORCE_TPL" ]]; then
  cp "$TOKEN_ENFORCE_TPL" "${RULES_DIR}/token-compression-enforcement.mdc"
fi

GLOBAL_RULES_DIR="${HOME}/.cursor/rules"
if [[ "$INSTALL_GLOBAL" -eq 1 ]]; then
  mkdir -p "$GLOBAL_RULES_DIR"
  for rule in context-mode.mdc token-compression-enforcement.mdc graphify.mdc agentmemory.mdc leanctx.mdc; do
    [[ -f "${RULES_DIR}/${rule}" ]] && install_rule "$rule" "$GLOBAL_RULES_DIR"
  done
  if [[ -f "${REPO_ROOT}/scripts/lib/global-toolstack/global-recommended-tools.mdc" ]]; then
    cp "${REPO_ROOT}/scripts/lib/global-toolstack/global-recommended-tools.mdc" \
      "${GLOBAL_RULES_DIR}/recommended-tools.mdc"
    printf 'OK: %s/recommended-tools.mdc (global variant)\n' "$GLOBAL_RULES_DIR"
  elif [[ -f "${RULES_DIR}/recommended-tools.mdc" ]]; then
    install_rule recommended-tools.mdc "$GLOBAL_RULES_DIR"
  fi
  if [[ -x "${REPO_ROOT}/scripts/install-global-toolstack.sh" ]]; then
    bash "${REPO_ROOT}/scripts/install-global-toolstack.sh"
  fi
  if [[ -x "${HOME}/.cursor/hooks/toolstack/parity-verify.sh" ]]; then
    bash "${HOME}/.cursor/hooks/toolstack/parity-verify.sh" || true
  fi
  printf '\nGlobal toolstack rules + hooks synced to %s\n' "$GLOBAL_RULES_DIR"
fi

if [[ -f "${RULES_DIR}/context-mode.mdc" ]]; then
  install_rule context-mode.mdc "$RULES_DIR"
fi
if [[ -f "${RULES_DIR}/token-compression-enforcement.mdc" ]]; then
  install_rule token-compression-enforcement.mdc "$RULES_DIR"
fi

printf '\nCursor recommended-tool rules installed under %s\n' "$RULES_DIR"
printf 'Verify agentmemory MCP in ~/.cursor/mcp.json (see docs/AGENTMEMORY.md)\n'
if [[ "$INSTALL_GLOBAL" -eq 0 ]]; then
  printf 'Tip: run with --global to sync context-mode rules to ~/.cursor/rules/\n'
fi


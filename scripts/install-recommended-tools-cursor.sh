#!/usr/bin/env bash
# Install Cursor always-on rules for all SB recommended tools.
# Delegates host/project reconciliation to scripts/reconcile-recommended-tools.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_GLOBAL=0
PROJECT_ROOT=""
RULES_DIR="${REPO_ROOT}/.cursor/rules"

usage() {
  cat <<'EOF'
Usage: bash scripts/install-recommended-tools-cursor.sh [--global] [--project-root PATH]

Installs always-on Cursor rules for SB recommended tools under the project
.cursor/rules/ directory. Host MCP/hook merges and five-tool reconciliation
are delegated to scripts/reconcile-recommended-tools.sh.

With --global, also syncs rules to ~/.cursor/rules/ and runs host-scope
reconciler apply (installer entry point).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) INSTALL_GLOBAL=1; shift ;;
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(pwd)"
  if git -C "$PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)"
  fi
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"

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

# Project rules (idempotent copy when missing)
for rule in graphify.mdc agentmemory.mdc recommended-tools.mdc leanctx.mdc; do
  install_rule "$rule" "$RULES_DIR" 2>/dev/null || true
done

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
fi

# shellcheck source=lib/recommended-tools/installer.sh
source "${REPO_ROOT}/scripts/lib/recommended-tools/installer.sh"
if [[ -f "${PROJECT_ROOT}/.silver-bullet.json" ]]; then
  rt_installer_post_install "$REPO_ROOT" "$PROJECT_ROOT" || \
    printf 'WARN: reconciler post-install exited nonzero (host infra may still be usable)\n' >&2
elif [[ "$INSTALL_GLOBAL" -eq 1 ]]; then
  rt_installer_post_install "$REPO_ROOT" "" || \
    printf 'WARN: reconciler post-install exited nonzero (host infra may still be usable)\n' >&2
fi

if [[ -x "${HOME}/.cursor/hooks/toolstack/parity-verify.sh" ]]; then
  bash "${HOME}/.cursor/hooks/toolstack/parity-verify.sh" || true
fi

printf '\nCursor recommended-tool rules installed under %s\n' "$RULES_DIR"
if [[ "$INSTALL_GLOBAL" -eq 0 ]]; then
  printf 'Tip: run with --global to sync global rules and host-scope reconciliation\n'
fi

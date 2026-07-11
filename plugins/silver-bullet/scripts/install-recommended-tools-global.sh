#!/usr/bin/env bash
# install-recommended-tools-global.sh — global RTK + Context Mode instruction artifacts per host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/rtk-cm-global.sh"

HOST=""
INSTALL_GLOBAL=0

usage() {
  cat <<'EOF'
Usage: bash scripts/install-recommended-tools-global.sh --host HOST [--global]

Syncs global instruction artifacts (rules, AGENTS.md routing) for RTK + Context Mode.
Does NOT require Silver Bullet. RTK/Codex hooks are applied by optimize-rtk-context-mode.sh.

Hosts: claude | codex | cursor | opencode | hermes | goose | all

Options:
  --host HOST   Target agent (required)
  --global      Alias for global-only install (default behavior)
  -h, --help    Show help
EOF
}

# shellcheck source=../hooks/lib/rtk-cm-global.sh
source "$LIB"

install_cursor_global() {
  bash "${SCRIPT_DIR}/install-recommended-tools-cursor.sh" --global
}

install_opencode_agents() {
  local dest="${HOME}/.config/opencode/AGENTS.md"
  local cm_pkg=""
  if command -v npm >/dev/null 2>&1; then
    cm_pkg="$(npm root -g 2>/dev/null)/context-mode/configs/opencode/AGENTS.md"
  fi
  if [[ -f "$cm_pkg" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$cm_pkg" "$dest"
    printf 'OK: %s\n' "$dest"
  else
    printf 'WARN: context-mode opencode AGENTS.md not found — run npm install -g context-mode\n' >&2
  fi
}

install_codex_agents() {
  local dest="${HOME}/.codex/AGENTS.md"
  local cm_pkg=""
  if command -v npm >/dev/null 2>&1; then
    cm_pkg="$(npm root -g 2>/dev/null)/context-mode/configs/codex/AGENTS.md"
  fi
  if [[ -f "$cm_pkg" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$cm_pkg" "$dest"
    printf 'OK: %s\n' "$dest"
  else
    printf 'WARN: context-mode codex AGENTS.md not found\n' >&2
  fi
}

install_claude_hint() {
  if [[ -f "${HOME}/.codex/RTK.md" ]]; then
    printf 'OK: ~/.codex/RTK.md present (from rtk init -g)\n'
  else
    printf 'WARN: run rtk init -g for Claude RTK wiring\n' >&2
  fi
}

install_hermes_note() {
  printf 'Hermes: enable rtk-rewrite in ~/.hermes/config.yaml plugins.enabled\n'
  printf 'See docs/rtk-cm/verification/hermes-verify-rtk-cm.md\n'
}

install_goose_skip() {
  rtcm_log_unsupported "goose"
}

install_host() {
  local h="${1:-}"
  case "$h" in
    cursor) install_cursor_global ;;
    opencode) install_opencode_agents ;;
    codex) install_codex_agents ;;
    claude) install_claude_hint ;;
    hermes) install_hermes_note ;;
    goose) install_goose_skip ;;
    *) printf 'Unsupported host: %s\n' "$h" >&2; return 2 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --global) INSTALL_GLOBAL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$HOST" ]] || { usage >&2; exit 2; }
: "${INSTALL_GLOBAL:?}" # reserved for future --global wiring

if [[ "$HOST" == "all" ]]; then
  for h in $RTCM_SUPPORTED_HOSTS; do
    install_host "$h"
  done
  exit 0
fi

rtcm_validate_host "$HOST" || {
  echo "Invalid --host: $HOST" >&2
  exit 2
}
install_host "$HOST"

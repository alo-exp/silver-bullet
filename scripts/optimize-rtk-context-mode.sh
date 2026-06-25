#!/usr/bin/env bash
# optimize-rtk-context-mode.sh — research-backed RTK + Context Mode host optimization.
# Idempotently wires hooks, MCP, cli-config allow-list, and global rules per host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MERGE_PY="${SCRIPT_DIR}/lib/merge-token-compression-config.py"

HOST="auto"
DRY_RUN=0
SKIP_CLI_CONFIG=0
SKIP_RTK_INIT=0
SKIP_CM_DOCTOR=0

usage() {
  cat <<'EOF'
Usage: bash scripts/optimize-rtk-context-mode.sh [options]

Ensures optimized RTK + Context Mode wiring for the active AI coding host.

Options:
  --host <cursor|claude|codex|all|auto>  Target host (default: auto-detect)
  --dry-run                             Print actions without writing files
  --skip-cli-config                     Skip ~/.cursor/cli-config.json merge
  --skip-rtk-init                       Skip rtk init -g wiring
  --skip-cm-doctor                      Skip context-mode doctor
  -h, --help                            Show this help

Called by /silver:init and /silver:update after RTK/CM install when opted in.
EOF
}

detect_host() {
  if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]] || [[ -d "${HOME}/.cursor" ]]; then
    printf '%s' "cursor"
    return 0
  fi
  if [[ -n "${CODEX_HOME:-}" ]] || [[ -d "${HOME}/.codex" ]]; then
    printf '%s' "codex"
    return 0
  fi
  if [[ -d "${HOME}/.claude" ]]; then
    printf '%s' "claude"
    return 0
  fi
  printf '%s' "cursor"
}

log() { printf '%s\n' "$*"; }
run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

rtk_binary_ok() {
  command -v rtk >/dev/null 2>&1 || return 1
  rtk gain --help >/dev/null 2>&1 || return 1
  ! rtk --help 2>&1 | head -5 | grep -qiE 'rust type kit|rtk-check'
}

optimize_rtk_cursor() {
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (cursor)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH or wrong binary — skip rtk init"
    return 0
  fi
  run_cmd rtk init -g --agent cursor
  if [[ "$DRY_RUN" -eq 0 ]]; then
    if grep -q 'rtk hook cursor\|"rtk"' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
      log "OK: RTK Cursor hook present"
    else
      log "WARN: RTK hook not found after rtk init — check ~/.cursor/hooks.json"
    fi
  fi
}

optimize_rtk_claude() {
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (claude)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd rtk init -g
}

optimize_rtk_codex() {
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (codex)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd rtk init -g --codex
}

optimize_context_mode_claude() {
  if command -v claude >/dev/null 2>&1; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "DRY-RUN: claude plugin marketplace add mksglu/context-mode"
      log "DRY-RUN: claude plugin install context-mode@context-mode"
    else
      claude plugin marketplace add mksglu/context-mode 2>/dev/null || true
      claude plugin install context-mode@context-mode 2>/dev/null || true
    fi
    log "NOTE: Restart Claude Code after plugin install"
  else
    log "WARN: claude CLI not found — use npm install -g context-mode for MCP path"
    run_cmd npm install -g context-mode 2>/dev/null || true
  fi
}

optimize_context_mode_cursor() {
  if ! command -v context-mode >/dev/null 2>&1 && ! command -v npm >/dev/null 2>&1; then
    log "WARN: context-mode and npm missing — skip CM merge"
    return 0
  fi
  if ! command -v context-mode >/dev/null 2>&1; then
    run_cmd npm install -g context-mode
  fi
  local merge_args=(python3 "$MERGE_PY" --host cursor --repo-root "$REPO_ROOT")
  [[ "$DRY_RUN" -eq 1 ]] && merge_args+=(--dry-run)
  [[ "$SKIP_CLI_CONFIG" -eq 1 ]] && merge_args+=(--skip-cli-config)
  run_cmd "${merge_args[@]}"
  bash "${SCRIPT_DIR}/install-recommended-tools-cursor.sh" --global 2>/dev/null || true
}

optimize_context_mode_codex() {
  if ! command -v context-mode >/dev/null 2>&1; then
    run_cmd npm install -g context-mode 2>/dev/null || true
  fi
  local merge_args=(python3 "$MERGE_PY" --host codex --repo-root "$REPO_ROOT")
  [[ "$DRY_RUN" -eq 1 ]] && merge_args+=(--dry-run)
  run_cmd "${merge_args[@]}"
}

run_cm_doctor() {
  if [[ "$SKIP_CM_DOCTOR" -eq 1 ]]; then
    log "SKIP: context-mode doctor"
    return 0
  fi
  if ! command -v context-mode >/dev/null 2>&1; then
    log "WARN: context-mode not on PATH — skip doctor"
    return 0
  fi
  local platform="cursor"
  case "$HOST" in
    claude) platform="claude" ;;
    codex) platform="codex" ;;
    cursor|all|auto) platform="cursor" ;;
  esac
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: CONTEXT_MODE_PLATFORM=${platform} context-mode doctor"
    return 0
  fi
  CONTEXT_MODE_PLATFORM="$platform" context-mode doctor 2>&1 | head -40 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-auto}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-cli-config) SKIP_CLI_CONFIG=1; shift ;;
    --skip-rtk-init) SKIP_RTK_INIT=1; shift ;;
    --skip-cm-doctor) SKIP_CM_DOCTOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$HOST" == "auto" ]] && HOST="$(detect_host)"

log "=== RTK + Context Mode optimization (host=${HOST}) ==="

case "$HOST" in
  cursor)
    optimize_rtk_cursor
    optimize_context_mode_cursor
  ;;
  claude)
    optimize_rtk_claude
    optimize_context_mode_claude
  ;;
  codex)
    optimize_rtk_codex
    optimize_context_mode_codex
  ;;
  all)
    optimize_rtk_cursor
    optimize_context_mode_cursor
    optimize_rtk_claude
    optimize_context_mode_claude
    optimize_rtk_codex
    optimize_context_mode_codex
  ;;
  *)
    echo "Invalid --host: $HOST" >&2
    exit 2
  ;;
esac

run_cm_doctor
run_cmd bash "${SCRIPT_DIR}/enable-rtk-context-mode.sh" --tool all 2>/dev/null || true

log "=== Optimization complete ==="

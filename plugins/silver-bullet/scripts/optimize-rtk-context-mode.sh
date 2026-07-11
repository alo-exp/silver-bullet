#!/usr/bin/env bash
# optimize-rtk-context-mode.sh — research-backed RTK + Context Mode global host optimization.
# Idempotently wires hooks, MCP, cli-config allow-list, and global rules per host.
# SB-independent: works without .silver-bullet.json or /silver:init.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MERGE_PY="${SCRIPT_DIR}/lib/merge-token-compression-config.py"
LIB="${REPO_ROOT}/hooks/lib/rtk-cm-global.sh"

HOST="auto"
DRY_RUN=0
SKIP_CLI_CONFIG=0
SKIP_RTK_INIT=0
SKIP_CM_DOCTOR=0

usage() {
  cat <<'EOF'
Usage: bash scripts/optimize-rtk-context-mode.sh [options]

Ensures optimized RTK + Context Mode wiring for AI coding hosts (global config only).

Options:
  --host <claude|codex|cursor|opencode|hermes|goose|all|auto>
                                        Target host (default: auto-detect)
  --dry-run                             Print actions without writing files
  --skip-cli-config                     Skip $HOME/.codex/cli-config.json merge
  --skip-rtk-init                       Skip rtk init wiring
  --skip-cm-doctor                      Skip context-mode doctor
  -h, --help                            Show this help

Hosts:
  claude, codex, cursor, opencode  — full or primary upstream integration
  hermes                           — partial (RTK plugin + CM MCP; no CM doctor platform)
  goose                            — unsupported (documented skip; no fake wiring)

No Silver Bullet opt-in required. See docs/rtk-cm/README.md.
EOF
}

# shellcheck source=../hooks/lib/rtk-cm-global.sh
source "$LIB"

detect_host() {
  if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]] || [[ -d "${HOME}/.codex" ]]; then
    printf '%s' "cursor"
    return 0
  fi
  if [[ -n "${CODEX_HOME:-}" ]] || [[ -d "${HOME}/.codex" ]]; then
    printf '%s' "codex"
    return 0
  fi
  if [[ -d "${HOME}/.config/opencode" ]]; then
    printf '%s' "opencode"
    return 0
  fi
  if [[ -d "${HOME}/.hermes" ]]; then
    printf '%s' "hermes"
    return 0
  fi
  if [[ -d "${HOME}/.codex" ]]; then
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

ensure_context_mode_cli() {
  if command -v context-mode >/dev/null 2>&1; then
    return 0
  fi
  if command -v npm >/dev/null 2>&1; then
    run_cmd npm install -g context-mode 2>/dev/null || true
  fi
}

run_merge_py() {
  local merge_host="${1:-}"
  local merge_args=(python3 "$MERGE_PY" --host "$merge_host" --repo-root "$REPO_ROOT")
  [[ "$DRY_RUN" -eq 1 ]] && merge_args+=(--dry-run)
  [[ "$SKIP_CLI_CONFIG" -eq 1 ]] && merge_args+=(--skip-cli-config)
  run_cmd "${merge_args[@]}"
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
    if grep -q 'rtk hook cursor\|"rtk"' "${HOME}/.codex/hooks.json" 2>/dev/null; then
      log "OK: RTK Cursor hook present"
    else
      log "WARN: RTK hook not found after rtk init — check $HOME/.codex/hooks.json"
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

optimize_rtk_opencode() {
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (opencode)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd rtk init -g --opencode
}

optimize_rtk_hermes() {
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (hermes)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd rtk init --agent hermes
}

optimize_rtk_goose() {
  rtcm_log_unsupported "goose"
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
    log "WARN: claude CLI not found — merge npm MCP path via merge helper"
    ensure_context_mode_cli
    run_merge_py claude
  fi
}

optimize_context_mode_cursor() {
  ensure_context_mode_cli
  run_merge_py cursor
  run_cmd bash "${SCRIPT_DIR}/install-recommended-tools-global.sh" --host cursor --global 2>/dev/null || \
    bash "${SCRIPT_DIR}/install-recommended-tools-cursor.sh" --global 2>/dev/null || true
}

optimize_context_mode_codex() {
  ensure_context_mode_cli
  run_merge_py codex
}

optimize_context_mode_opencode() {
  ensure_context_mode_cli
  run_merge_py opencode
}

optimize_context_mode_hermes() {
  ensure_context_mode_cli
  run_merge_py hermes
  log "NOTE: Hermes has no context-mode doctor platform — verify MCP in ~/.hermes/config.yaml"
}

optimize_context_mode_goose() {
  rtcm_log_unsupported "goose"
}

optimize_host() {
  local h="${1:-}"
  log ""
  log "--- host: ${h} (status: $(rtcm_host_status "$h")) ---"
  case "$h" in
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
    opencode)
      optimize_rtk_opencode
      optimize_context_mode_opencode
      ;;
    hermes)
      optimize_rtk_hermes
      optimize_context_mode_hermes
      ;;
    goose)
      optimize_rtk_goose
      optimize_context_mode_goose
      ;;
    *)
      log "Invalid host: $h" >&2
      return 2
      ;;
  esac
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
  local platform
  platform="$(rtcm_doctor_platform "$HOST")"
  if [[ -z "$platform" ]]; then
    log "SKIP: context-mode doctor (no platform adapter for host=${HOST})"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: CONTEXT_MODE_PLATFORM=${platform} context-mode doctor"
    return 0
  fi
  CONTEXT_MODE_PLATFORM="$platform" context-mode doctor 2>&1 | head -40 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-auto}"; shift 2 ;;
    --dry-run) DRY_RUN=1; export RTCM_DRY_RUN=1; shift ;;
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
  all)
    for h in $RTCM_ALL_HOSTS; do
      optimize_host "$h"
    done
    ;;
  *)
    rtcm_validate_host "$HOST" || {
      echo "Invalid --host: $HOST (use: auto ${RTCM_ALL_HOSTS} all)" >&2
      exit 2
    }
    optimize_host "$HOST"
    ;;
esac

run_cm_doctor
if [[ "$DRY_RUN" -eq 0 ]]; then
  run_cmd bash "${SCRIPT_DIR}/enable-rtk-context-mode.sh" --tool all 2>/dev/null || true
fi

log "=== Optimization complete ==="

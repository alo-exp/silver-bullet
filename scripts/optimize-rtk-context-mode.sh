#!/usr/bin/env bash
# optimize-rtk-context-mode.sh — research-backed RTK + Context Mode global host optimization.
# Idempotently wires hooks, MCP, cli-config allow-list, and global rules per host.
# Works without .silver-bullet.json or /sb:init, but never without the user's consent: it wires
# only the tools the user granted "wire" for (docs/CONSENT.md), installs Context Mode only with
# "install", and never touches a tool that was not granted.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MERGE_PY="${SCRIPT_DIR}/lib/merge-token-compression-config.py"
LIB="${REPO_ROOT}/hooks/lib/rtk-cm-global.sh"
RECOMMENDED_TOOLS_LIB="${REPO_ROOT}/hooks/lib/recommended-tools.sh"
CONTEXT_MODE_LIB="${REPO_ROOT}/hooks/lib/context-mode-gate.sh"
RTK_GATE_LIB="${REPO_ROOT}/hooks/lib/rtk-gate.sh"

HOST=""
DRY_RUN=0
SKIP_CLI_CONFIG=0
SKIP_RTK_INIT=0
SKIP_CM_DOCTOR=0
CLI_ALLOWLIST="read-only"
PROJECT_ROOT=""
# Per-tool consent (filled in after the arguments are parsed).
WIRE_RTK=0
WIRE_CM=0
WIRE_LEANCTX=0

usage() {
  cat <<'EOF'
Usage: bash scripts/optimize-rtk-context-mode.sh [options]

Ensures optimized RTK + Context Mode wiring for AI coding hosts (global config only).

Options:
  --host <claude|codex|cursor|opencode|pi|hermes|goose|all>
                                        Target host (required)
  --project-root <path>                 Canonical SB project root (required)
  --dry-run                             Print actions without writing files
  --skip-cli-config                     Skip ~/.cursor/cli-config.json merge
  --cli-allowlist <none|read-only|full> Cursor CLI shell allow-list to merge (default: read-only;
                                        full pre-approves interpreters, rm, curl, docker, ...)
  --skip-rtk-init                       Skip rtk init wiring
  --skip-cm-doctor                      Skip context-mode doctor
  -h, --help                            Show this help

Hosts:
  claude, codex, cursor, opencode, pi — shared/global integration
  hermes                           — partial (RTK plugin + CM MCP; no CM doctor platform)
  goose                            — unsupported (documented skip; no fake wiring)

Needs the user's consent per tool (bash scripts/sb-consent.sh grant TOOL --all-projects
--capabilities wire[,install]); tools without it are left alone. See docs/CONSENT.md and
docs/rtk-cm/README.md.
EOF
}

# shellcheck source=../hooks/lib/rtk-cm-global.sh
source "$LIB"
# shellcheck source=../hooks/lib/recommended-tools.sh
[[ -f "$RECOMMENDED_TOOLS_LIB" ]] && source "$RECOMMENDED_TOOLS_LIB"
# shellcheck source=../hooks/lib/context-mode-gate.sh
[[ -f "$CONTEXT_MODE_LIB" ]] && source "$CONTEXT_MODE_LIB"
# shellcheck source=../hooks/lib/rtk-gate.sh
[[ -f "$RTK_GATE_LIB" ]] && source "$RTK_GATE_LIB"

detect_host() {
  if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]] || [[ -d "${HOME}/.cursor" ]]; then
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
  if [[ -n "${PI_CODING_AGENT_DIR:-}" ]] || [[ -d "${HOME}/.pi/agent" ]]; then
    printf '%s' "pi"
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
  local bin
  bin="$(sb_rtk_cli_path 2>/dev/null || true)"
  [[ -n "$bin" ]] || return 1
  "$bin" gain --help >/dev/null 2>&1 || return 1
  ! grep -qiE 'rust type kit|rtk-check' < <("$bin" --help 2>&1 | head -5)
}

# tool_consented TOOL CAPABILITY: the user granted CAPABILITY for TOOL. A project file never does.
tool_consented() {
  declare -f sb_consent_granted >/dev/null 2>&1 && sb_consent_granted "$1" "$2"
}

consent_hint() {
  log "SKIP: ${1} — no consent. To allow it: bash ${SCRIPT_DIR}/sb-consent.sh grant ${2} --all-projects --capabilities ${3}"
}

ensure_context_mode_cli() {
  if declare -f sb_context_mode_cli_path >/dev/null 2>&1 && sb_context_mode_cli_path >/dev/null 2>&1; then
    return 0
  fi
  if command -v context-mode >/dev/null 2>&1; then
    return 0
  fi
  if ! tool_consented context_mode install; then
    consent_hint "npm install -g context-mode" context_mode install
    return 0
  fi
  if command -v npm >/dev/null 2>&1; then
    run_cmd npm install -g context-mode || log "WARN: npm install -g context-mode failed"
  fi
}

claude_native_context_mode_enabled() {
  local settings="${HOME}/.claude/settings.json"
  if [[ -f "$settings" ]] && jq -e \
    '.enabledPlugins["context-mode@context-mode"] == true' \
    "$settings" >/dev/null 2>&1; then
    return 0
  fi
  if command -v claude >/dev/null 2>&1; then
    grep -q 'enabled' < <(claude plugin list 2>/dev/null |
      grep -A3 -F 'context-mode@context-mode') && return 0
  fi
  return 1
}

disable_claude_native_context_mode() {
  claude_native_context_mode_enabled || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: claude plugin disable context-mode@context-mode --scope user"
    return 0
  fi
  command -v claude >/dev/null 2>&1 || {
    log "ERROR: Claude Context Mode plugin is enabled but the claude CLI is unavailable; disable context-mode@context-mode or install the global context-mode MCP manually" >&2
    return 1
  }
  run_cmd claude plugin disable context-mode@context-mode --scope user
}

run_merge_py() {
  local merge_host="${1:-}"
  local merge_args=(python3 "$MERGE_PY" --host "$merge_host" --repo-root "$REPO_ROOT")
  [[ "$DRY_RUN" -eq 1 ]] && merge_args+=(--dry-run)
  [[ "$SKIP_CLI_CONFIG" -eq 1 ]] && merge_args+=(--skip-cli-config)
  merge_args+=(--cli-allowlist "$CLI_ALLOWLIST")
  [[ "$WIRE_RTK" -eq 1 && "$WIRE_CM" -eq 0 ]] && merge_args+=(--rtk-only)
  [[ "$WIRE_RTK" -eq 0 && "$WIRE_CM" -eq 1 ]] && merge_args+=(--context-mode-only)
  run_cmd "${merge_args[@]}"
}

canonicalize_cursor_toolstack_hooks() {
  local patch_py="${REPO_ROOT}/scripts/lib/global-toolstack/patch-hooks.py"
  [[ -f "$patch_py" ]] || return 0
  # `rtk init --agent cursor` can preserve an older LeanCTX rewrite hook.  Run
  # the shared hook reconciler after vendor initialization so the manifest-
  # backed RTK hook is the only shell rewrite owner.
  run_cmd env \
    RT_PATCH_RTK="$WIRE_RTK" \
    RT_PATCH_CONTEXT_MODE="$WIRE_CM" \
    RT_PATCH_LEANCTX="$WIRE_LEANCTX" \
    python3 "$patch_py"
}

optimize_rtk_cursor() {
  [[ "$WIRE_RTK" -eq 1 ]] || { consent_hint "rtk init (cursor)" rtk wire; return 0; }
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (cursor)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH or wrong binary — skip rtk init"
    return 0
  fi
  run_cmd "$(sb_rtk_cli_path)" init -g --agent cursor
  if [[ "$DRY_RUN" -eq 0 ]]; then
    if grep -q 'rtk hook cursor\|"rtk"' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
      log "OK: RTK Cursor hook present"
    else
      log "WARN: RTK hook not found after rtk init — check ~/.cursor/hooks.json"
    fi
  fi
}

optimize_rtk_claude() {
  [[ "$WIRE_RTK" -eq 1 ]] || { consent_hint "rtk init (claude)" rtk wire; return 0; }
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (claude)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd "$(sb_rtk_cli_path)" init -g
}

optimize_rtk_codex() {
  [[ "$WIRE_RTK" -eq 1 ]] || { consent_hint "rtk init (codex)" rtk wire; return 0; }
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (codex)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd "$(sb_rtk_cli_path)" init -g --codex
}

optimize_rtk_opencode() {
  [[ "$WIRE_RTK" -eq 1 ]] || { consent_hint "RTK wiring (opencode)" rtk wire; return 0; }
  log "OK: OpenCode RTK is wired by the shared manifest-backed plugin"
  # With Context Mode also consented the one merge in optimize_context_mode_opencode writes both.
  [[ "$WIRE_CM" -eq 1 ]] || run_merge_py opencode
}

optimize_rtk_pi() {
  [[ "$WIRE_RTK" -eq 1 ]] || { consent_hint "RTK wiring (pi)" rtk wire; return 0; }
  log "OK: Pi RTK is wired by the shared native tool_call adapter"
}

optimize_rtk_hermes() {
  [[ "$WIRE_RTK" -eq 1 ]] || { consent_hint "rtk init (hermes)" rtk wire; return 0; }
  if [[ "$SKIP_RTK_INIT" -eq 1 ]]; then
    log "SKIP: rtk init (hermes)"
    return 0
  fi
  if ! rtk_binary_ok; then
    log "WARN: rtk-ai/rtk not on PATH — skip rtk init"
    return 0
  fi
  run_cmd "$(sb_rtk_cli_path)" init --agent hermes
}

optimize_rtk_goose() {
  rtcm_log_unsupported "goose"
}

optimize_context_mode_claude() {
  [[ "$WIRE_CM" -eq 1 ]] || { consent_hint "Context Mode wiring (claude)" context_mode wire; return 0; }
  disable_claude_native_context_mode
  ensure_context_mode_cli
  run_merge_py claude
}

optimize_context_mode_cursor() {
  [[ "$WIRE_CM" -eq 1 ]] || { consent_hint "Context Mode wiring (cursor)" context_mode wire; return 0; }
  ensure_context_mode_cli
  run_merge_py cursor
  canonicalize_cursor_toolstack_hooks
  if [[ -z "${TOOLSTACK_INSTALL_IN_PROGRESS:-}" && -z "${SB_RT_APPLY_ACTIVE:-}" ]]; then
    run_cmd bash "${SCRIPT_DIR}/install-recommended-tools-global.sh" --host cursor --global 2>/dev/null || \
      bash "${SCRIPT_DIR}/install-recommended-tools-cursor.sh" --global 2>/dev/null || true
  fi
}

optimize_context_mode_codex() {
  [[ "$WIRE_CM" -eq 1 ]] || { consent_hint "Context Mode wiring (codex)" context_mode wire; return 0; }
  ensure_context_mode_cli
  run_merge_py codex
}

optimize_context_mode_opencode() {
  [[ "$WIRE_CM" -eq 1 ]] || { consent_hint "Context Mode wiring (opencode)" context_mode wire; return 0; }
  ensure_context_mode_cli
  run_merge_py opencode
}

optimize_context_mode_pi() {
  [[ "$WIRE_CM" -eq 1 ]] || { consent_hint "Context Mode wiring (pi)" context_mode wire; return 0; }
  local installer="${REPO_ROOT}/scripts/lib/global-toolstack/install-pi.py"
  [[ -f "$installer" ]] || {
    log "ERROR: Pi adapter installer missing: $installer" >&2
    return 1
  }
  run_cmd python3 "$installer" --repo-root "$REPO_ROOT"
}

optimize_context_mode_hermes() {
  [[ "$WIRE_CM" -eq 1 ]] || { consent_hint "Context Mode wiring (hermes)" context_mode wire; return 0; }
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
    pi)
      optimize_rtk_pi
      optimize_context_mode_pi
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
  local context_mode_bin
  context_mode_bin="$(sb_context_mode_cli_path 2>/dev/null || true)"
  if [[ -z "$context_mode_bin" ]]; then
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
  CONTEXT_MODE_PLATFORM="$platform" "$context_mode_bin" doctor 2>&1 | head -40 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host|--project-root)
      # A trailing option has no value; `shift 2` would abort silently under set -e.
      if [[ $# -lt 2 ]]; then echo "ERROR: $1 requires a value" >&2; usage >&2; exit 2; fi
      if [[ "$1" == "--host" ]]; then HOST="$2"; else PROJECT_ROOT="$2"; fi
      shift 2
      ;;
    --dry-run) DRY_RUN=1; export RTCM_DRY_RUN=1; shift ;;
    --skip-cli-config) SKIP_CLI_CONFIG=1; shift ;;
    --skip-rtk-init) SKIP_RTK_INIT=1; shift ;;
    --skip-cm-doctor) SKIP_CM_DOCTOR=1; shift ;;
    --cli-allowlist)
      if [[ $# -lt 2 ]]; then echo "ERROR: --cli-allowlist requires a value" >&2; usage >&2; exit 2; fi
      case "$2" in none|read-only|full) CLI_ALLOWLIST="$2" ;; *) echo "ERROR: --cli-allowlist takes none, read-only or full" >&2; exit 2 ;; esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$HOST" ]]; then
  echo "ERROR: --host is required" >&2
  usage >&2
  exit 2
fi
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: --project-root is required" >&2
  usage >&2
  exit 2
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"
export RT_PROJECT_ROOT="$PROJECT_ROOT"

[[ "$HOST" == "auto" ]] && HOST="$(detect_host)"

tool_consented rtk wire && WIRE_RTK=1
tool_consented context_mode wire && WIRE_CM=1
tool_consented leanctx wire && WIRE_LEANCTX=1
if [[ "$WIRE_RTK" -eq 0 && "$WIRE_CM" -eq 0 ]]; then
  consent_hint "RTK and Context Mode optimization" "rtk|context_mode" wire
  exit 0
fi

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

if [[ "$WIRE_CM" -eq 1 ]]; then
  run_cm_doctor
fi
if [[ "$DRY_RUN" -eq 0 ]]; then
  run_cmd bash "${SCRIPT_DIR}/enable-rtk-context-mode.sh" --tool all 2>/dev/null || true
fi

log "=== Optimization complete ==="

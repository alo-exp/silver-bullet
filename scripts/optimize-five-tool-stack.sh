#!/usr/bin/env bash
# optimize-five-tool-stack.sh — orchestrate SB five-tool routed profile.
#
# Replaces ad-hoc optimize-rtk-context-mode.sh when LeanCTX is opted in (conflict #9).
# Gates RTK+CM optimize behind this script so shell/sandbox/FTS surfaces stay exclusive.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_LEANCTX="${SCRIPT_DIR}/install-leanctx-sb.sh"
OPTIMIZE_RTCM="${SCRIPT_DIR}/optimize-rtk-context-mode.sh"
OPTIMIZE_SYNERGY="${SCRIPT_DIR}/sb-optimize-stack.sh"
INSTALL_CURSOR_RULES="${SCRIPT_DIR}/install-recommended-tools-cursor.sh"
LIB="${REPO_ROOT}/hooks/lib/rtk-cm-global.sh"

HOST=""
DRY_RUN=0
SKIP_RTCM=0
SKIP_SYNERGY=0
FORCE=0
PROJECT_ROOT=""

usage() {
  cat <<'EOF'
Usage: bash scripts/optimize-five-tool-stack.sh [options]

Orchestrates the SB five-tool routed stack when leanctx is opted in:
  LeanCTX  — wire proxy, AST read, PathJail, ledger, injection detection
  RTK      — sb_shell
  CM       — sb_grep, sb_slice, sb_webfetch
  Graphify — sb_graph
  agentmemory — sb_remember

When leanctx.enabled_by_user is true, callers MUST use this script instead of
optimize-rtk-context-mode.sh alone (conflict #9).

Options:
  --host <cursor|claude|codex|opencode|all>   Target host (required)
  --project-root <path>                       Canonical SB project root (required)
  --dry-run                                        Print actions without writes
  --skip-rtcm                                      Skip RTK+CM optimize helper
  --skip-synergy                                   Skip Graphify+agentmemory optimize
  --force                                          Run even if leanctx not opted in
  -h, --help                                       Show help
EOF
}

# shellcheck source=../hooks/lib/rtk-cm-global.sh
source "$LIB"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

detect_host() {
  if [[ -n "${RT_HOST:-}" ]]; then
    printf '%s' "$RT_HOST"
    return 0
  fi
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
  if [[ -d "${HOME}/.codex" ]]; then
    printf '%s' "claude"
    return 0
  fi
  printf '%s' "cursor"
}

config_file() {
  if [[ -n "$PROJECT_ROOT" && -f "${PROJECT_ROOT}/.silver-bullet.json" ]]; then
    printf '%s' "${PROJECT_ROOT}/.silver-bullet.json"
  elif [[ -f "${REPO_ROOT}/.silver-bullet.json" ]]; then
    printf '%s' "${REPO_ROOT}/.silver-bullet.json"
  else
    printf '%s' "${REPO_ROOT}/templates/silver-bullet.config.json.default"
  fi
}

leanctx_opted_in() {
  local cfg
  cfg="$(config_file)"
  [[ -f "$cfg" ]] || return 1
  local val
  val="$(jq -r '.recommended_tools.leanctx.enabled_by_user // "null"' "$cfg" 2>/dev/null || echo null)"
  [[ "$val" == "true" ]]
}

five_tool_profile_active() {
  local cfg
  cfg="$(config_file)"
  [[ -f "$cfg" ]] || return 1
  local profile
  profile="$(jq -r '.recommended_tools.leanctx.optimization_profile // "five_tool_routed"' "$cfg" 2>/dev/null || echo five_tool_routed)"
  [[ "$profile" == "five_tool_routed" ]]
}

apply_profile_metadata() {
  local cfg
  cfg="$(config_file)"
  [[ -f "$cfg" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: stamp optimization_profiles.five_tool_routed metadata"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  jq '
    .optimization_profiles.five_tool_routed = (
      .optimization_profiles.five_tool_routed // {
        "extends": "synergy_max",
        "stack_mode": "parallel_routed",
        "primary_fts": "context_mode",
        "routes": {
          "sb_wire": "leanctx",
          "sb_read": "leanctx",
          "sb_grep": "context_mode",
          "sb_shell": "rtk",
          "sb_slice": "context_mode",
          "sb_webfetch": "context_mode",
          "sb_graph": "graphify",
          "sb_remember": "agentmemory",
          "sb_pathjail": "leanctx",
          "sb_injection": "leanctx"
        }
      }
    )
    | .recommended_tools.leanctx.optimization_profile = "five_tool_routed"
    | .recommended_tools.leanctx.stack_mode = "parallel_routed"
    | .recommended_tools.leanctx.primary_fts = "context_mode"
  ' "$cfg" >"$tmp"
  mv "$tmp" "$cfg"
  log "OK: five_tool_routed profile metadata applied to .silver-bullet.json"
}

optimize_host() {
  local h="${1:-}"
  log ""
  log "--- five-tool optimize: host=${h} ---"

  local leanctx_args=(bash "$INSTALL_LEANCTX" --host "$h" --project-root "${PROJECT_ROOT:-$REPO_ROOT}")
  [[ "$DRY_RUN" -eq 1 ]] && leanctx_args+=(--dry-run)
  run_cmd "${leanctx_args[@]}"

  if [[ "$SKIP_RTCM" -eq 0 ]]; then
    local rtcm_args=(bash "$OPTIMIZE_RTCM" --host "$h" --project-root "${PROJECT_ROOT:-$REPO_ROOT}" --skip-cm-doctor)
    [[ "$DRY_RUN" -eq 1 ]] && rtcm_args+=(--dry-run)
    run_cmd "${rtcm_args[@]}"
  else
    log "SKIP: optimize-rtk-context-mode.sh"
  fi

  if [[ "$h" == "cursor" ]]; then
    run_cmd bash "$INSTALL_CURSOR_RULES" $([[ "$DRY_RUN" -eq 1 ]] && printf '%s' '--global' || true)
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; export RTCM_DRY_RUN=1; shift ;;
    --skip-rtcm) SKIP_RTCM=1; shift ;;
    --skip-synergy) SKIP_SYNERGY=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$HOST" ]]; then
  echo "ERROR: --host is required (reconciler must pass explicit host)" >&2
  usage >&2
  exit 2
fi
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: --project-root is required" >&2
  usage >&2
  exit 2
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"

[[ "$HOST" == "auto" ]] && HOST="$(detect_host)"

if [[ "$FORCE" -eq 0 ]] && ! leanctx_opted_in; then
  log "leanctx not opted in (recommended_tools.leanctx.enabled_by_user != true)"
  log "Use optimize-rtk-context-mode.sh for RTK+CM only, or pass --force"
  exit 0
fi

log "=== SB five-tool stack optimization (host=${HOST}) ==="
log "NOTE: optimize-rtk-context-mode.sh gated — use this script when LeanCTX active (conflict #9)"

apply_profile_metadata

case "$HOST" in
  all)
    for h in cursor claude codex opencode; do
      optimize_host "$h"
    done
    ;;
  cursor|claude|codex|opencode)
    optimize_host "$HOST"
    ;;
  *)
    echo "Invalid --host: $HOST" >&2
    exit 2
    ;;
esac

if [[ "$SKIP_SYNERGY" -eq 0 ]]; then
  synergy_args=(bash "$OPTIMIZE_SYNERGY" --apply)
  [[ "$DRY_RUN" -eq 1 ]] && synergy_args+=(--dry-run)
  [[ "$HOST" != "auto" && "$HOST" != "all" ]] && synergy_args+=(--host "$HOST")
  run_cmd "${synergy_args[@]}"
else
  log "SKIP: sb-optimize-stack.sh (Graphify + agentmemory)"
fi

if five_tool_profile_active; then
  log "Profile: five_tool_routed (primary_fts=context_mode, parallel_routed)"
else
  warn "five_tool_routed profile not active in config"
fi

log "=== Five-tool optimization complete ==="


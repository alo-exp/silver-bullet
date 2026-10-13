#!/usr/bin/env bash
# install-leanctx-sb.sh — Silver Bullet host-aware LeanCTX install (library mode).
#
# SB owns all host config writes. This script NEVER runs `lean-ctx init --agent *`
# (which clobbers AGENTS.md, .cursorrules, and agent skill dirs — conflict #8).
#
# Upstream CLI flag verification (2026-07-07):
#   --library-mode  : NOT present in lean-ctx README/compatibility docs — use fallback chain.
#   lean-ctx mcp    : documented MCP entrypoint.
#   curl installer  : https://leanctx.com/install.sh
#
# Fallback install path (safest when --library-mode absent):
#   1. Ensure lean-ctx binary on PATH (curl installer or cargo install lean-ctx).
#   2. Skip lean-ctx init entirely; wire MCP via scripts/lib/global-toolstack/patch-mcp.py.
#   3. Apply SB five-tool profile env via merge script (lctx_ prefix, CM overlap off).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_MCP_PY="${SCRIPT_DIR}/lib/global-toolstack/patch-mcp.py"
VERIFY_PY="${SCRIPT_DIR}/lib/verify-leanctx-wire-proxy-ordering.py"
# Shared manifest helpers keep every host on the same user-global LeanCTX
# executable when its command is not already present on PATH.
if [[ -f "${REPO_ROOT}/hooks/lib/recommended-tools.sh" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/hooks/lib/recommended-tools.sh"
fi

leanctx_cli_path() {
  if declare -f sb_global_tool_path >/dev/null 2>&1; then
    sb_global_tool_path leanctx 2>/dev/null && return 0
  fi
  command -v lean-ctx 2>/dev/null
}

HOST=""
DRY_RUN=0
SKIP_INSTALL=0
SKIP_VERIFY=0
SKIP_MERGE=0
PROJECT_ROOT=""

# Host paths lean-ctx init would clobber — we guard these (conflict #8).
declare -a GUARD_PATHS=()

usage() {
  cat <<'EOF'
Usage: bash scripts/install-leanctx-sb.sh [options]

Host-aware LeanCTX install for Silver Bullet five-tool routed stack.
Uses library-mode when upstream supports it; otherwise SB merge-only wiring.

Options:
  --host <cursor|claude|codex|opencode|pi> Target host (required)
  --project-root <path>                   Canonical SB project root (required)
  --dry-run                                     Print actions without writes
  --skip-install                                Skip binary install step
  --skip-merge                                  Skip MCP merge helper
  --skip-verify                                 Skip wire-proxy ordering validator
  -h, --help                                    Show help

Never writes AGENTS.md, .cursorrules, or host skill directories.
EOF
}

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
  if [[ -n "${PI_CODING_AGENT_DIR:-}" ]] || [[ -d "${HOME}/.pi/agent" ]]; then
    printf '%s' "pi"
    return 0
  fi
  if [[ -d "${HOME}/.codex" ]]; then
    printf '%s' "claude"
    return 0
  fi
  printf '%s' "cursor"
}

init_guard_paths() {
  GUARD_PATHS=()
  case "$HOST" in
    cursor)
      GUARD_PATHS+=(
        "${HOME}/.cursor/AGENTS.md"
        "${REPO_ROOT}/.cursorrules"
        "${REPO_ROOT}/AGENTS.md"
      )
      ;;
    codex)
      GUARD_PATHS+=("${HOME}/.codex/AGENTS.md")
      ;;
    opencode)
      GUARD_PATHS+=("${HOME}/.config/opencode/AGENTS.md")
      ;;
    pi)
      GUARD_PATHS+=("${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/AGENTS.md")
      ;;
    claude)
      GUARD_PATHS+=("${HOME}/.claude/CLAUDE.md")
      ;;
  esac
}

snapshot_guard_mtimes() {
  local -a snaps=()
  local p hash
  for p in "${GUARD_PATHS[@]}"; do
    if [[ -f "$p" ]]; then
      hash="$(shasum -a 256 "$p" 2>/dev/null | awk '{print $1}')"
      snaps+=("${p}=hash:${hash}")
    else
      snaps+=("${p}=missing")
    fi
  done
  printf '%s\n' "${snaps[@]}"
}

assert_guard_unchanged() {
  local -a before=("$@")
  local entry path state hash actual
  for entry in "${before[@]}"; do
    path="${entry%%=*}"
    state="${entry#*=}"
    if [[ "$state" == "missing" ]]; then
      [[ ! -f "$path" ]] || {
        warn "install touched guarded path (created): $path"
        return 1
      }
      continue
    fi
    if [[ "$state" == hash:* ]]; then
      hash="${state#hash:}"
      if [[ ! -f "$path" ]]; then
        warn "install removed guarded path: $path"
        return 1
      fi
      actual="$(shasum -a 256 "$path" 2>/dev/null | awk '{print $1}')"
      [[ -n "$actual" && "$actual" == "$hash" ]] || {
        warn "install modified guarded path: $path"
        return 1
      }
      continue
    fi
    # Legacy mtime snapshots (older callers) — tolerate missing hash prefix.
    if [[ -f "$path" ]]; then
      local mtime
      mtime="$(stat -f '%m' "$path" 2>/dev/null || stat -c '%Y' "$path" 2>/dev/null || echo 0)"
      [[ "$mtime" == "$state" ]] || {
        warn "install modified guarded path: $path"
        return 1
      }
    fi
  done
  return 0
}

leanctx_binary_ok() {
  local bin="$(leanctx_cli_path || true)"
  [[ -n "$bin" ]] || return 1
  "$bin" --version >/dev/null 2>&1 || "$bin" --help >/dev/null 2>&1
}

leanctx_supports_library_mode() {
  local bin="$(leanctx_cli_path || true)"
  [[ -n "$bin" ]] && "$bin" init --help 2>&1 | grep -q -- '--library-mode'
}

context_mode_configured() {
  case "$HOST" in
    cursor)
      local mcp="${HOME}/.cursor/mcp.json"
      [[ -f "$mcp" ]] && grep -q '"context-mode"' "$mcp" 2>/dev/null
      ;;
    claude)
      local claude_plugin_root="${HOME}/.claude/plugins"
      [[ -d "${claude_plugin_root}/context-mode" ]] \
        || compgen -G "${claude_plugin_root}/cache/*/context-mode" >/dev/null 2>&1 \
        || [[ -d "${HOME}/.codex/plugins/context-mode" ]] \
        || {
          local mcp="${HOME}/.claude.json"
          [[ -f "$mcp" ]] && grep -q '"context-mode"' "$mcp" 2>/dev/null
        }
      ;;
    codex)
      local mcp="${CODEX_HOME:-${HOME}/.codex}/config.toml"
      [[ -f "$mcp" ]] && grep -q '^\[mcp_servers\.context-mode\]$' "$mcp" 2>/dev/null
      ;;
    opencode)
      local mcp="${HOME}/.config/opencode/opencode.json"
      [[ -f "$mcp" ]] && jq -e '(.plugin // [] | any(. == "context-mode")) or (.mcp["context-mode"] // .mcp["user-context-mode"] // empty)' "$mcp" >/dev/null 2>&1
      ;;
    pi)
      local mcp="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/extensions/silver-bullet-five-tool-stack/config.json"
      [[ -f "$mcp" ]] && jq -e '.servers.context_mode.enabled == true' "$mcp" >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

install_leanctx_binary() {
  if [[ "$SKIP_INSTALL" -eq 1 ]]; then
    log "SKIP: lean-ctx binary install"
    return 0
  fi
  if leanctx_binary_ok; then
    log "OK: lean-ctx already on PATH"
    return 0
  fi
  log "Installing lean-ctx via upstream installer..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: curl -fsSL https://leanctx.com/install.sh | sh"
    return 0
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://leanctx.com/install.sh | sh || true
  fi
  if ! leanctx_binary_ok; then
    warn "lean-ctx not on PATH after installer — try: cargo install lean-ctx"
    return 1
  fi
  log "OK: lean-ctx installed"
}

run_library_mode_init() {
  # Conflict #8: never `lean-ctx init --agent *`. Library mode only when verified.
  local bin="$(leanctx_cli_path || true)"
  if ! leanctx_binary_ok; then
    warn "lean-ctx missing — skip library init"
    return 0
  fi
  if leanctx_supports_library_mode; then
    log "Running lean-ctx init --library-mode (verified upstream flag)"
    run_cmd "$bin" init --library-mode
    return 0
  fi
  # Fallback flags documented but unverified — safest path is merge-only wiring.
  log "NOTE: --library-mode not in lean-ctx init --help; using SB merge-only wiring"
  log "NOTE: unverified fallbacks if upstream adds them later:"
  log "  lean-ctx init --library-mode --no-rules --no-agents"
  log "  lean-ctx mcp install --prefix lctx_"
  return 0
}

merge_mcp_config() {
  if [[ "$SKIP_MERGE" -eq 1 ]]; then
    log "SKIP: MCP merge"
    return 0
  fi
  local merge_py="${SCRIPT_DIR}/lib/merge-leanctx-mcp-config.py"
  case "$HOST" in
    cursor)
      if [[ ! -f "$PATCH_MCP_PY" ]]; then
        warn "patch-mcp helper missing: $PATCH_MCP_PY"
        return 1
      fi
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY-RUN: RT_PATCH_LEANCTX=1 RT_PATCH_GRAPHIFY=0 python3 $PATCH_MCP_PY"
        return 0
      fi
      RT_PATCH_LEANCTX=1 RT_PATCH_GRAPHIFY=0 run_cmd python3 "$PATCH_MCP_PY"
      ;;
    claude|codex|opencode)
      if [[ ! -f "$merge_py" ]]; then
        warn "merge-leanctx-mcp-config helper missing: $merge_py"
        return 1
      fi
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY-RUN: python3 $merge_py --host $HOST"
        return 0
      fi
      log "Merging LeanCTX MCP for host=${HOST} via merge-leanctx-mcp-config.py"
      run_cmd python3 "$merge_py" --host "$HOST"
      ;;
    pi)
      local pi_installer="${SCRIPT_DIR}/lib/global-toolstack/install-pi.py"
      [[ -f "$pi_installer" ]] || {
        warn "Pi adapter installer missing: $pi_installer"
        return 1
      }
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY-RUN: python3 $pi_installer --repo-root $REPO_ROOT"
      else
        run_cmd python3 "$pi_installer" --repo-root "$REPO_ROOT"
      fi
      ;;
    *)
      log "SKIP: MCP merge (host=${HOST}; no merge target implemented — supported: cursor, claude, codex, opencode, pi)"
      return 0
      ;;
  esac
}

write_sb_profile_env() {
  local profile_dir="${SB_RUNTIME_HOME_ROOT:-${HOME}/.silver-bullet}/leanctx-profile"
  local profile_file="${profile_dir}/five-tool-routed.env"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: write ${profile_file}"
    return 0
  fi
  mkdir -p "$profile_dir"
  cat >"$profile_file" <<'ENVEOF'
# SB five_tool_routed profile — applied by install-leanctx-sb.sh / optimize-five-tool-stack.sh
LEANCTX_MCP_TOOL_PREFIX=lctx_
LEANCTX_DISABLE_SHELL_MCP=1
LEANCTX_DISABLE_SANDBOX_MCP=1
LEANCTX_DISABLE_FETCH_MCP=1
LEANCTX_DISABLE_FTS=1
LEANCTX_PRIMARY_FTS=context_mode
ENVEOF
  log "OK: ${profile_file}"
}

verify_wire_proxy_ordering() {
  if [[ "$SKIP_VERIFY" -eq 1 ]]; then
    log "SKIP: wire-proxy ordering verify"
    return 0
  fi
  if [[ ! -f "$VERIFY_PY" ]]; then
    warn "verify helper missing: $VERIFY_PY"
    return 0
  fi
  log "Verifying wire-proxy ordering schema (Codex conflict #13)..."
  local fixture
  fixture="$(python3 "$VERIFY_PY" --generate-fixture)"
  if ! printf '%s' "$fixture" | python3 "$VERIFY_PY" -; then
    warn "wire-proxy ordering self-test failed"
    return 1
  fi
  log "OK: wire-proxy ordering validator self-test passed"
  if [[ "$HOST" == "codex" ]] && leanctx_binary_ok; then
    local bin="$(leanctx_cli_path || true)"
    if [[ -n "$bin" ]] && "$bin" proxy --help >/dev/null 2>&1; then
      log "OK: lean-ctx proxy subcommand available for Codex wire path"
    else
      warn "lean-ctx proxy subcommand not found — Codex wire path may be limited"
    fi
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --skip-merge) SKIP_MERGE=1; shift ;;
    --skip-verify) SKIP_VERIFY=1; shift ;;
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

log "=== LeanCTX SB install (host=${HOST}) ==="

if context_mode_configured; then
  log "Context Mode detected — LeanCTX MCP overlap surfaces will be disabled (lctx_ prefix)"
fi

init_guard_paths
GUARD_SNAPSHOT=()
while IFS= read -r _line; do
  GUARD_SNAPSHOT+=("$_line")
done < <(snapshot_guard_mtimes)

install_leanctx_binary
run_library_mode_init
merge_mcp_config
write_sb_profile_env
verify_wire_proxy_ordering

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "SKIP: guard unchanged check (dry-run — no writes)"
elif ! assert_guard_unchanged "${GUARD_SNAPSHOT[@]}"; then
  warn "Guard check failed — SB install must not clobber host agent config"
  exit 1
fi

log "=== LeanCTX SB install complete ==="
log "Routing: sb_wire/sb_read/sb_pathjail/sb_injection → LeanCTX; sb_shell→RTK; sb_slice/sb_grep/sb_webfetch→CM; sb_graph→Graphify; sb_remember→agentmemory"
log "See .cursor/rules/leanctx.mdc and docs/LEANCTX.md (when present)"

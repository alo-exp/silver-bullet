#!/usr/bin/env bash
# install-leanctx-sb.sh — Silver Bullet host-aware LeanCTX install (library mode).
#
# SB owns all host config writes. This script NEVER runs `lean-ctx init --agent *`
# (which clobbers AGENTS.md, .cursorrules, and agent skill dirs — conflict #8).
#
# Upstream CLI flag verification (2026-07-07):
#   --library-mode  : NOT present in lean-ctx README/compatibility docs — use fallback chain.
#   lean-ctx mcp    : documented MCP entrypoint.
#   installer       : https://leanctx.com/install.sh (never piped to a shell: see install_leanctx_binary)
#
# Fallback install path (safest when --library-mode absent):
#   1. Ensure lean-ctx binary on PATH (checksum-verified installer or the pinned cargo install).
#   2. Skip lean-ctx init entirely; wire MCP via scripts/lib/global-toolstack/patch-mcp.py.
#   3. Apply SB five-tool profile env via merge script (lctx_ prefix, CM overlap off).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# One backup per run: sb_host_config keeps the user's file as it was before the run's first change.
export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"
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
INSTALLER_SHA256=""
WIRE_EVIDENCE=""

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
  --installer-sha256 <hex>                      Download https://leanctx.com/install.sh and run it
                                                only if its SHA-256 equals <hex> (needs "install" consent)
  --wire-proxy-evidence <file>                  Validate this captured Codex wire-proxy evidence
  -h, --help                                    Show help

Needs your consent for LeanCTX (bash scripts/sb-consent.sh grant leanctx --all-projects
--capabilities wire,install). Never writes AGENTS.md, .cursorrules, or host skill directories.
EOF
}

log() { printf '%s\n' "$*"; }
leanctx_consented() {
  declare -f sb_consent_granted >/dev/null 2>&1 && sb_consent_granted leanctx "$1"
}
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}
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
  if [[ -d "${HOME}/.claude" ]]; then
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
        "${PROJECT_ROOT}/.cursorrules"
        "${PROJECT_ROOT}/AGENTS.md"
      )
      ;;
    codex)
      GUARD_PATHS+=("${HOME}/.codex/AGENTS.md" "${PROJECT_ROOT}/AGENTS.md")
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
      mtime="$(stat -c '%Y' "$path" 2>/dev/null || stat -f '%m' "$path" 2>/dev/null || echo 0)"
      [[ "$mtime" == "$state" ]] || {
        warn "install modified guarded path: $path"
        return 1
      }
    fi
  done
  return 0
}

leanctx_binary_ok() {
  local bin
  bin="$(leanctx_cli_path || true)"
  [[ -n "$bin" ]] || return 1
  "$bin" --version >/dev/null 2>&1 && return 0
  "$bin" --help >/dev/null 2>&1
}

leanctx_supports_library_mode() {
  local bin
  bin="$(leanctx_cli_path || true)"
  [[ -n "$bin" ]] && grep -q -- '--library-mode' < <("$bin" init --help 2>&1)
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

# The cargo command that installs the LeanCTX release Silver Bullet's template pins (min_version):
# an unpinned `cargo install lean-ctx` would take whatever is newest.
leanctx_cargo_install_command() {
  local pin=""
  pin="$(jq -r '.recommended_tools.leanctx.min_version // empty' "${REPO_ROOT}/templates/silver-bullet.config.json.default" 2>/dev/null || true)"
  [[ "$pin" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || pin="3.9.9"
  printf 'cargo install lean-ctx --version %s --locked' "$pin"
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
  # An installer fetched from the network runs only with the user's "install" consent AND a SHA-256
  # the user pinned for exactly that file; it is never piped from curl into a shell.
  if ! leanctx_consented install; then
    warn "lean-ctx is not installed and you have not allowed installing it."
    warn "  allow: bash ${SCRIPT_DIR}/sb-consent.sh grant leanctx --all-projects --capabilities install"
    warn "  or install it yourself: $(leanctx_cargo_install_command)"
    return 1
  fi
  if [[ -z "$INSTALLER_SHA256" ]]; then
    warn "lean-ctx is not installed. Silver Bullet will not run an unverified installer."
    warn "  Download https://leanctx.com/install.sh, read it, then re-run with --installer-sha256 <sha256 of that file>"
    warn "  or: $(leanctx_cargo_install_command)"
    return 1
  fi
  if [[ ! "$INSTALLER_SHA256" =~ ^[0-9a-fA-F]{64}$ ]]; then
    warn "--installer-sha256 must be 64 hexadecimal characters"
    return 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: download https://leanctx.com/install.sh, verify sha256 ${INSTALLER_SHA256}, run it"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || { warn "curl is required to download the lean-ctx installer"; return 1; }
  local installer actual
  installer="$(mktemp "${TMPDIR:-/tmp}/leanctx-install.XXXXXX")"
  if ! curl -fsSL --proto '=https' --max-time 60 -o "$installer" -- https://leanctx.com/install.sh; then
    rm -f -- "$installer"
    warn "could not download the lean-ctx installer"
    return 1
  fi
  actual="$(sha256_of "$installer")"
  if [[ "$(printf '%s' "$actual" | tr 'A-F' 'a-f')" != "$(printf '%s' "$INSTALLER_SHA256" | tr 'A-F' 'a-f')" ]]; then
    rm -f -- "$installer"
    warn "lean-ctx installer checksum mismatch (got ${actual}); not running it"
    return 1
  fi
  sh "$installer" || warn "lean-ctx installer exited non-zero"
  rm -f -- "$installer"
  if ! leanctx_binary_ok; then
    warn "lean-ctx not on PATH after installer — try: $(leanctx_cargo_install_command)"
    return 1
  fi
  log "OK: lean-ctx installed"
}

run_library_mode_init() {
  # Conflict #8: never `lean-ctx init --agent *`. Library mode only when verified.
  local bin
  bin="$(leanctx_cli_path || true)"
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
        log "DRY-RUN: python3 $pi_installer --repo-root $REPO_ROOT --enable-tool leanctx"
      else
        run_cmd python3 "$pi_installer" --repo-root "$REPO_ROOT" --enable-tool leanctx
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
# lean-ctx >= 3.11 honors LEAN_CTX_DISABLED_TOOLS; the LEANCTX_* lines serve older releases.
LEAN_CTX_DISABLED_TOOLS=ctx_shell,shell,ctx_execute,ctx_search,ctx_index,ctx_url_read,ctx_knowledge,ctx_memory
LEANCTX_MCP_TOOL_PREFIX=lctx_
LEANCTX_DISABLE_SHELL_MCP=1
LEANCTX_DISABLE_SANDBOX_MCP=1
LEANCTX_DISABLE_FETCH_MCP=1
LEANCTX_DISABLE_FTS=1
LEANCTX_PRIMARY_FTS=context_mode
ENVEOF
  log "OK: ${profile_file}"
}

# lean-ctx wraps agent shells (shell_activation=agents-only). RTK output is already
# compressed, so exclude rtk from lean-ctx's shell compression to avoid a second pass.
configure_rtk_passthrough() {
  if ! leanctx_binary_ok; then
    log "SKIP: lean-ctx not installed; RTK passthrough not configured"
    return 0
  fi
  local current
  current="$(lean-ctx config 2>/dev/null | sed -n 's/^excluded_commands = //p' | head -1)"
  if [[ "$current" == *'"rtk"'* ]]; then
    log "OK: lean-ctx excluded_commands already includes rtk"
    return 0
  fi
  if [[ -n "$current" && "$current" != "[]" ]]; then
    warn "lean-ctx excluded_commands=${current}; add rtk to it so RTK output is not compressed twice"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: lean-ctx config set excluded_commands rtk"
    return 0
  fi
  run_cmd lean-ctx config set excluded_commands rtk
}

# lean-ctx re-renders its hooks on every MCP server start and after updates. That
# restores `hook rewrite` (double-wraps RTK) and `hook observe` (re-injects the
# ctx_shell policy) after the routed profile removed them. With manage_hooks off,
# only an explicit `lean-ctx setup`, `init`, or `doctor --fix` writes hook config.
configure_leanctx_hook_management() {
  if ! leanctx_binary_ok; then
    return 0
  fi
  if lean-ctx config 2>/dev/null | awk '/^\[setup\]/{s=1;next} /^\[/{s=0} s && /^manage_hooks = false/{f=1} END{exit !f}'; then
    log "OK: lean-ctx setup.manage_hooks already false"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: lean-ctx config set setup.manage_hooks false"
    return 0
  fi
  run_cmd lean-ctx config set setup.manage_hooks false
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
  if [[ -n "$WIRE_EVIDENCE" ]]; then
    log "Validating the captured wire-proxy evidence ${WIRE_EVIDENCE} (Codex conflict #13)..."
    if ! python3 "$VERIFY_PY" "$WIRE_EVIDENCE"; then
      warn "wire-proxy evidence is not valid message ordering"
      return 1
    fi
    log "OK: wire-proxy evidence preserves message ordering"
  else
    log "Checking the wire-proxy ordering validator itself (Codex conflict #13)..."
    local fixture
    fixture="$(python3 "$VERIFY_PY" --generate-fixture)"
    if ! printf '%s' "$fixture" | python3 "$VERIFY_PY" -; then
      warn "wire-proxy ordering validator self-test failed"
      return 1
    fi
    log "OK: validator self-test passed (this proves the validator, not the proxy: pass --wire-proxy-evidence <file> to check real captured traffic)"
  fi
  if [[ "$HOST" == "codex" ]] && leanctx_binary_ok; then
    local bin
    bin="$(leanctx_cli_path || true)"
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
    --installer-sha256) INSTALLER_SHA256="${2:-}"; shift $(( $# > 1 ? 2 : 1 )) ;;
    --wire-proxy-evidence) WIRE_EVIDENCE="${2:-}"; shift $(( $# > 1 ? 2 : 1 )) ;;
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

# LeanCTX changes host configuration for every project: only with the user's own consent.
if ! leanctx_consented wire; then
  log "SKIP: LeanCTX install - no consent. To allow it:"
  log "  bash ${SCRIPT_DIR}/sb-consent.sh grant leanctx --all-projects --capabilities wire,install"
  exit 0
fi

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
configure_rtk_passthrough
configure_leanctx_hook_management
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

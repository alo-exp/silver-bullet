# shellcheck shell=bash
# Context Mode install/wiring gate — CLI, Node, MCP/plugin wiring, instruction fragment.
# Enforcement is active only with the user's consent (see user-consent.sh) in a project
# whose .silver-bullet.json does not turn Context Mode off.
# Sourced by: context-mode-gate.sh, context-mode-read-deny.sh, enable-rtk-context-mode.sh,
# sb-diagnostics.sh

_sb_context_mode_default_min_node="22.5"
_sb_context_mode_fragment_begin='<!-- BEGIN context-mode hint (do not edit) -->'
_sb_context_mode_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_context_mode_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_context_mode_lib_dir}/opt-in-gate.sh"

sb_context_mode_required() {
  sb_recommended_tool_enforced "${1:-}" "context_mode"
}

# Minimum Node version; a config value that is not a plain dotted version is ignored.
sb_context_mode_min_node_version() {
  local config_file="${1:-}" min=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    min="$(jq -r '.recommended_tools.context_mode.min_node_version // "" | tostring' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_version_valid "$min" || min="$_sb_context_mode_default_min_node"
  printf '%s' "$min"
}

sb_context_mode_cli_path() {
  sb_global_tool_path context_mode 2>/dev/null && return 0
  if command -v context-mode >/dev/null 2>&1; then
    command -v context-mode
    return 0
  fi
  return 1
}

# A Claude Code plugin install: the marketplace registry or the legacy plugin directories.
sb_context_mode_claude_plugin_present() {
  local registry="${HOME}/.claude/plugins/installed_plugins.json"
  [[ -d "${HOME}/.claude/plugins/context-mode" || -d "${HOME}/.claude/plugins/mksglu-context-mode" ]] && return 0
  [[ -f "$registry" ]] || return 1
  jq -e '(.plugins // {}) | type == "object" and (keys | any(startswith("context-mode@")))' "$registry" >/dev/null 2>&1
}

sb_context_mode_cli_available() {
  sb_context_mode_cli_path >/dev/null 2>&1 || sb_context_mode_claude_plugin_present
}

# The installed Node version, cached per binary in the runtime state dir (starting node
# costs tens of milliseconds); the cache is refreshed when the binary changes.
sb_context_mode_node_version() {
  local node_bin cache cached_bin="" cached_ver="" ver
  node_bin="$(command -v node 2>/dev/null)" || return 1
  cache="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/context-mode-node"
  if [[ -f "$cache" && ! -L "$cache" && "$cache" -nt "$node_bin" ]]; then
    IFS=' ' read -r cached_bin cached_ver <"$cache" || true
    if [[ "$cached_bin" == "$node_bin" ]] && sb_rt_version_valid "$cached_ver"; then
      printf '%s' "$cached_ver"
      return 0
    fi
  fi
  ver="$(sb_rt_version_extract "$(node --version 2>/dev/null || true)" || true)"
  [[ -n "$ver" ]] || return 1
  if mkdir -p "$(dirname "$cache")" 2>/dev/null && printf '%s %s\n' "$node_bin" "$ver" >"${cache}.$$" 2>/dev/null; then
    mv -f -- "${cache}.$$" "$cache" 2>/dev/null || rm -f -- "${cache}.$$"
  fi
  printf '%s' "$ver"
}

sb_context_mode_node_ok() {
  local config_file="${1:-}" have
  have="$(sb_context_mode_node_version)" || return 1
  sb_rt_version_ge "$have" "$(sb_context_mode_min_node_version "$config_file")"
}

sb_context_mode_platform_artifact_path() {
  local _project_root="${1:-$PWD}" host="${2:-}"
  if [[ -n "${SB_CONTEXT_MODE_MCP_ARTIFACT:-}" ]]; then
    printf '%s' "${SB_CONTEXT_MODE_MCP_ARTIFACT}"
    return 0
  fi
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/mcp.json' "${HOME}" ;;
    codex) printf '%s/config.toml' "${CODEX_HOME:-${HOME}/.codex}" ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    pi) printf '%s/extensions/silver-bullet-five-tool-stack/config.json' \
      "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}" ;;
    *) printf '%s/.claude.json' "${HOME}" ;;
  esac
}

# Claude Code wiring as docs/CONTEXT-MODE.md sets it up: a context-mode MCP server in
# ~/.claude.json (user scope or this project's entry) or in the project's .mcp.json, or the
# Claude plugin (marketplace registry or a legacy plugin directory).
_sb_context_mode_claude_wired() {
  local project_root="${1:-$PWD}" physical
  local has_cm='def cm: type == "object" and (keys | any(test("context[-_]mode")));'
  physical="$(cd -P -- "$project_root" 2>/dev/null && pwd -P)" || physical="$project_root"
  if [[ -f "${HOME}/.claude.json" ]] && jq -e --arg a "$project_root" --arg b "$physical" "${has_cm}"'
      ((.mcpServers // {}) | cm)
      or ((.projects[$a].mcpServers // {}) | cm)
      or ((.projects[$b].mcpServers // {}) | cm)' "${HOME}/.claude.json" >/dev/null 2>&1; then
    return 0
  fi
  if [[ -f "${project_root%/}/.mcp.json" ]] \
    && jq -e "${has_cm}"' (.mcpServers // {}) | cm' "${project_root%/}/.mcp.json" >/dev/null 2>&1; then
    return 0
  fi
  sb_context_mode_claude_plugin_present
}

sb_context_mode_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}" artifact
  host="${host:-$(sb_runtime_host)}"
  if [[ "$host" == "claude" && -z "${SB_CONTEXT_MODE_MCP_ARTIFACT:-}" ]]; then
    _sb_context_mode_claude_wired "$project_root" && return 0
    return 1
  fi
  artifact="$(sb_context_mode_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  case "$host" in
    opencode)
      jq -e '(.plugin // [] | any(.[]?; (type == "string") and (. == "context-mode" or startswith("context-mode@") or endswith("/build/adapters/opencode/plugin.js")))) or (.mcp["context-mode"] // .mcp["user-context-mode"])' \
        "$artifact" >/dev/null 2>&1
      ;;
    pi)
      jq -e '.servers.context_mode.enabled == true' "$artifact" >/dev/null 2>&1
      ;;
    *)
      grep -q 'context-mode' "$artifact" 2>/dev/null
      ;;
  esac
}

sb_context_mode_instruction_fragment_present() {
  local project_root="${1:-$PWD}" doc
  for doc in "${project_root%/}/silver-bullet.md" "${project_root%/}/CLAUDE.md" "${project_root%/}/AGENTS.md"; do
    [[ -f "$doc" ]] || continue
    if grep -qE 'ctx_execute|ctx_index|ctx_search|ctx_batch_execute' "$doc" 2>/dev/null \
      && { grep -qF "$_sb_context_mode_fragment_begin" "$doc" 2>/dev/null || grep -q 'context-mode hint' "$doc" 2>/dev/null; }; then
      return 0
    fi
  done
  return 1
}

# Status 0 when an edit target is SB configuration or Context Mode's own wiring (normalized).
sb_context_mode_edit_path_is_exempt() {
  local normalized
  [[ -n "${1:-}" ]] || return 1
  normalized="$(sb_opt_in_normalize_path "$1" "$(dirname "${2:-$PWD/x}")")"
  case "$normalized" in
    */.silver-bullet.json | */SETUP_REPORT.md | */.silver-bullet/* | */.cursor/mcp.json \
      | */.cursor/hooks.json | */templates/context-mode-hint.md.base)
      return 0
      ;;
  esac
  return 1
}

sb_context_mode_command_is_exempt() {
  ! sb_opt_in_shell_needs_gate context_mode "${1:-}"
}

sb_context_mode_block_message_no_cli() {
  local config_file="${1:-}" host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" context_mode "$host")"
  cat <<EOF
🚫 CONTEXT MODE REQUIRED — package not installed (you opted in to Context Mode enforcement).

Silver Bullet mandates Context Mode for MCP/large-file compaction (host: ${host}):

${install_lines}

License: Elastic License 2.0 (ELv2) — not OSI-open; commercial bundling requires the upstream license.

Restart the agent after plugin/MCP wiring. See docs/CONTEXT-MODE.md.
EOF
}

sb_context_mode_block_message_node() {
  local config_file="${1:-}"
  cat <<EOF
🚫 CONTEXT MODE — Node too old (need >= $(sb_context_mode_min_node_version "$config_file")).

Upgrade Node, then reinstall: npm install -g context-mode

See docs/CONTEXT-MODE.md.
EOF
}

sb_context_mode_block_message_no_platform() {
  local config_file="${1:-}" host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_context_mode_platform_artifact_path "$(dirname "${config_file:-$PWD/x}")" "$host")"
  cat <<EOF
🚫 CONTEXT MODE NOT WIRED — MCP/plugin integration missing.

Expected a context-mode MCP server (or plugin) for host ${host} in:
  ${artifact}

Run platform install (host: ${host}):
$(sb_recommended_tool_platform_install_commands "" context_mode "$host")
EOF
}

sb_context_mode_block_message_no_fragment() {
  cat <<EOF
🚫 CONTEXT MODE INSTRUCTION FRAGMENT MISSING — scaffold routing hints in project docs.

Run /sb:init or /sb:update to inject the context-mode hint block into silver-bullet.md and CLAUDE.md (sentinel-wrapped).

Without the fragment, the model may bypass ctx_* tools and savings drop to zero.
See docs/CONTEXT-MODE.md and templates/context-mode-hint.md.base.
EOF
}

# Status 0 when Context Mode is installed and wired for the host, so its ctx_* tools exist.
sb_context_mode_ready() {
  local project_root="${1:-$PWD}"
  sb_context_mode_cli_available && sb_context_mode_platform_artifact_present "$project_root"
}

sb_context_mode_prompt_reminder_line() {
  local config_file="${1:-}" project_root host
  project_root="$(dirname "$config_file")"
  host="$(sb_runtime_host)"

  case "$(sb_recommended_tool_consent "$config_file" "context_mode")" in
    pending)
      printf '%s' "Context Mode: consent pending — ask user to opt in or out (ELv2 license disclosure required)."
      ;;
    disabled)
      printf '%s' "Context Mode: opted out — enforcements disabled."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "context_mode"; then
        printf '%s' "Context Mode: opted in but install failed — enforcement suspended; retry on /sb:update."
      elif ! sb_context_mode_node_ok "$config_file"; then
        printf '%s' "Context Mode: Node too old — upgrade to >= $(sb_context_mode_min_node_version "$config_file") before install."
      elif ! sb_context_mode_cli_available; then
        printf '%s' "Context Mode: CLI/plugin missing — install per docs/CONTEXT-MODE.md."
      elif ! sb_context_mode_platform_artifact_present "$project_root" "$host"; then
        printf '%s' "Context Mode: MCP/plugin not wired for ${host}."
      elif ! sb_context_mode_instruction_fragment_present "$project_root"; then
        printf '%s' "Context Mode: instruction fragment missing — run init/update scaffold."
      else
        printf '%s' "Context Mode: wired — follow §2g-ii for files >5 KB and MCP-heavy results; restart agent after plugin changes."
      fi
      ;;
  esac
}

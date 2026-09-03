# shellcheck shell=bash
# Context Mode install/wiring gate — CLI, Node, MCP/hooks, instruction fragment helpers.
# Enforcement active only when recommended_tools.context_mode.enabled_by_user is true.
# Sourced by: context-mode-gate.sh, enable-rtk-context-mode.sh, sb-diagnostics.sh

_sb_context_mode_default_min_node="22.5"
_sb_context_mode_fragment_begin='<!-- BEGIN context-mode hint (do not edit) -->'
_sb_context_mode_fragment_end='<!-- END context-mode hint (do not edit) -->'

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi

sb_context_mode_required() {
  sb_recommended_tool_enforced "${1:-}" "context_mode"
}

sb_context_mode_min_node_version() {
  local config_file="${1:-}"
  local min="${_sb_context_mode_default_min_node}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    min="$(jq -r --arg def "$_sb_context_mode_default_min_node" \
      '.recommended_tools.context_mode.min_node_version // $def' "$config_file" 2>/dev/null || echo "$_sb_context_mode_default_min_node")"
  fi
  printf '%s' "$min"
}

sb_context_mode_cli_path() {
  if command -v context-mode >/dev/null 2>&1; then
    command -v context-mode
    return 0
  fi
  return 1
}

sb_context_mode_claude_plugin_present() {
  [[ -d "${HOME}/.codex/plugins/context-mode" ]] \
    || [[ -d "${HOME}/.codex/plugins/mksglu-context-mode" ]]
}

sb_context_mode_cli_available() {
  sb_context_mode_cli_path >/dev/null 2>&1 || sb_context_mode_claude_plugin_present
}

sb_context_mode_node_ok() {
  local config_file="${1:-}"
  local node_ver major minor min_ver min_major min_minor
  command -v node >/dev/null 2>&1 || return 1
  node_ver="$(node --version 2>/dev/null | sed 's/^v//')"
  [[ -n "$node_ver" ]] || return 1
  major="$(printf '%s' "$node_ver" | cut -d. -f1)"
  minor="$(printf '%s' "$node_ver" | cut -d. -f2)"
  min_ver="$(sb_context_mode_min_node_version "$config_file")"
  min_major="$(printf '%s' "$min_ver" | cut -d. -f1)"
  min_minor="$(printf '%s' "$min_ver" | cut -d. -f2)"
  if [[ "$major" -gt "$min_major" ]]; then return 0; fi
  if [[ "$major" -lt "$min_major" ]]; then return 1; fi
  [[ "$minor" -ge "$min_minor" ]]
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
    codex) printf '%s/.codex/config.toml' "${CODEX_HOME:-${HOME}/.codex}" ;;
    *) printf '%s/.codex/plugins/context-mode' "${HOME}" ;;
  esac
}

sb_context_mode_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    claude)
      sb_context_mode_claude_plugin_present && return 0
      artifact="$(sb_context_mode_platform_artifact_path "$project_root" "$host")"
      [[ -d "$artifact" ]]
      ;;
    cursor)
      artifact="$(sb_context_mode_platform_artifact_path "$project_root" "$host")"
      [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
      grep -q 'context-mode' "$artifact" 2>/dev/null
      ;;
    codex)
      artifact="$(sb_context_mode_platform_artifact_path "$project_root" "$host")"
      [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
      grep -q 'context-mode' "$artifact" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

sb_context_mode_hooks_present() {
  local host="${1:-}"
  local hooks_file
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    claude)
      sb_context_mode_claude_plugin_present
      ;;
    cursor)
      hooks_file="${HOME}/.cursor/hooks.json"
      [[ -f "$hooks_file" ]] && grep -q 'context-mode' "$hooks_file" 2>/dev/null
      ;;
    codex)
      hooks_file="${CODEX_HOME:-${HOME}/.codex}/hooks.json"
      [[ -f "$hooks_file" ]] && grep -q 'context-mode' "$hooks_file" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

sb_context_mode_instruction_fragment_present() {
  local project_root="${1:-$PWD}"
  local doc
  for doc in "${project_root%/}/silver-bullet.md" "${project_root%/}/CLAUDE.md" "${project_root%/}/AGENTS.md"; do
    [[ -f "$doc" ]] || continue
    if grep -qF "$_sb_context_mode_fragment_begin" "$doc" 2>/dev/null \
      && grep -qE 'ctx_execute|ctx_index|ctx_search|ctx_batch_execute' "$doc" 2>/dev/null; then
      return 0
    fi
    if grep -q 'context-mode hint' "$doc" 2>/dev/null \
      && grep -qE 'ctx_execute|ctx_index|ctx_search|ctx_batch_execute' "$doc" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

sb_context_mode_cursor_rule_present() {
  local project_root="${1:-$PWD}"
  [[ -f "${project_root%/}/.cursor/rules/context-mode.mdc" ]] \
    || grep -rl 'context-mode' "${project_root%/}/.cursor/rules/" 2>/dev/null | grep -q .
}

sb_context_mode_is_windows_native() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) return 0 ;;
  esac
  if [[ -n "${OS:-}" ]] && printf '%s' "$OS" | grep -qi windows; then
    return 0
  fi
  return 1
}

sb_context_mode_edit_path_is_exempt() {
  local file_path="${1:-}"
  [[ -n "$file_path" ]] || return 1
  case "$file_path" in
    */.silver-bullet.json|*/SETUP_REPORT.md)
      return 0
      ;;
  esac
  if [[ "$file_path" == *"/.silver-bullet/"* ]]; then
    return 0
  fi
  if [[ "$file_path" == *"/.cursor/mcp.json" ]] || [[ "$file_path" == *"/.cursor/hooks.json" ]]; then
    return 0
  fi
  if [[ "$file_path" == *"/templates/context-mode-hint.md.base" ]]; then
    return 0
  fi
  return 1
}

sb_context_mode_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])context-mode([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE 'enable-rtk-context-mode|npm install.*context-mode'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(npm|node|curl|grep|cat|jq|mkdir|cp|chmod|echo|printf|true|false)(\s|$)'; then
    return 0
  fi
  return 1
}

sb_context_mode_block_message_no_cli() {
  local config_file="${1:-}"
  local host install_lines license_note
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" context_mode "$host" 2>/dev/null || true)"
  license_note="$(sb_recommended_tool_config_string "$config_file" context_mode "license_note" "")"
  cat <<EOF
🚫 CONTEXT MODE REQUIRED — package not installed (user opted in).

Silver Bullet mandates Context Mode for MCP/large-file compaction (host: ${host}):

${install_lines}

${license_note:+License: ${license_note}}

Restart the agent after plugin/MCP wiring. See docs/CONTEXT-MODE.md.
EOF
}

sb_context_mode_block_message_node() {
  local config_file="${1:-}"
  local min_ver
  min_ver="$(sb_context_mode_min_node_version "$config_file")"
  cat <<EOF
🚫 CONTEXT MODE — Node too old (need >= ${min_ver}).

Upgrade Node, then reinstall: npm install -g context-mode

See docs/CONTEXT-MODE.md.
EOF
}

sb_context_mode_block_message_no_platform() {
  local config_file="${1:-}"
  local host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_context_mode_platform_artifact_path "$(dirname "$config_file")" "$host")"
  cat <<EOF
🚫 CONTEXT MODE NOT WIRED — MCP/plugin integration missing.

Expected artifact for host ${host}:
  ${artifact}

Also verify hooks reference context-mode (see docs/CONTEXT-MODE.md).

Run platform install (host: ${host}):
$(sb_recommended_tool_platform_install_commands "$config_file" context_mode "$host" 2>/dev/null || true)
EOF
}

sb_context_mode_block_message_no_fragment() {
  cat <<EOF
🚫 CONTEXT MODE INSTRUCTION FRAGMENT MISSING — scaffold routing hints in project docs.

Run /silver:init or /silver:update to inject the context-mode hint block into silver-bullet.md and CLAUDE.md (sentinel-wrapped).

Without the fragment, the model may bypass ctx_* tools and savings drop to zero.
See docs/CONTEXT-MODE.md and templates/context-mode-hint.md.base.
EOF
}

sb_context_mode_prompt_reminder_line() {
  local config_file="${1:-}"
  local project_root host
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
        printf '%s' "Context Mode: opted in but install failed — enforcement suspended; retry on /silver:update."
      elif ! sb_context_mode_node_ok "$config_file"; then
        printf '%s' "Context Mode: Node too old — upgrade to >= 22.5 before install."
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

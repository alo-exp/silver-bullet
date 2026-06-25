# shellcheck shell=bash
# Alumnium MCP install/wiring gate — browser/visual testing companion.
# Enforcement active only when recommended_tools.alumnium.enabled_by_user is true.
# Sourced by: alumnium-gate.sh, prompt-reminder.sh, sb-diagnostics.sh

_sb_alumnium_default_mcp_name="alumnium"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi

sb_alumnium_required() {
  sb_recommended_tool_enforced "${1:-}" "alumnium"
}

sb_alumnium_mcp_server_name() {
  local config_file="${1:-}"
  local name="${_sb_alumnium_default_mcp_name}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    name="$(jq -r --arg def "$_sb_alumnium_default_mcp_name" \
      '.recommended_tools.alumnium.mcp_server_name // $def' "$config_file" 2>/dev/null || echo "$_sb_alumnium_default_mcp_name")"
  fi
  printf '%s' "$name"
}

sb_alumnium_npx_available() {
  command -v npx >/dev/null 2>&1 || return 1
  npm view alumnium version >/dev/null 2>&1
}

sb_alumnium_platform_artifact_path() {
  local _project_root="${1:-$PWD}" host="${2:-}"
  if [[ -n "${SB_ALUMNIUM_MCP_ARTIFACT:-}" ]]; then
    printf '%s' "${SB_ALUMNIUM_MCP_ARTIFACT}"
    return 0
  fi
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/mcp.json' "${HOME}" ;;
    codex) printf '%s/.codex/config.toml' "${CODEX_HOME:-${HOME}/.codex}" ;;
    *) printf '%s/.claude.json' "${HOME}" ;;
  esac
}

sb_alumnium_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}" artifact mcp_name
  host="${host:-$(sb_runtime_host)}"
  mcp_name="$(sb_alumnium_mcp_server_name "${project_root}/.silver-bullet.json")"
  artifact="$(sb_alumnium_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -qiE "alumnium|${mcp_name}" "$artifact" 2>/dev/null
}

sb_alumnium_edit_path_is_exempt() {
  local file_path="${1:-}"
  [[ -n "$file_path" ]] || return 1
  case "$file_path" in
    */.silver-bullet.json|*/SETUP_REPORT.md|*/silver-bullet.md|*/CLAUDE.md|*/AGENTS.md)
      return 0
      ;;
  esac
  if [[ "$file_path" == *"/.silver-bullet/"* ]]; then
    return 0
  fi
  if [[ "$file_path" == *"/.cursor/mcp.json" ]] || [[ "$file_path" == *"/.claude.json" ]]; then
    return 0
  fi
  return 1
}

sb_alumnium_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if printf '%s' "$cmd" | grep -qiE '(^|[[:space:]/])alumnium([[:space:]]|$)|npx[[:space:]]+-y[[:space:]]+alumnium'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(npm|npx|which|command -v|grep|cat|jq|echo|printf|true|false)(\s|$)'; then
    return 0
  fi
  return 1
}

sb_alumnium_block_message_no_mcp() {
  local config_file="${1:-}"
  local host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" alumnium "$host" 2>/dev/null || true)"
  cat <<EOF
🚫 ALUMNIUM REQUIRED — MCP server not wired (user opted in).

Silver Bullet mandates [Alumnium](https://alumnium.ai/) for browser/visual testing when opted in (host: ${host}):

${install_lines}

Provider API key required (e.g. OPENAI_API_KEY or ANTHROPIC_API_KEY in MCP env).

To disable enforcement, set recommended_tools.alumnium.enabled_by_user to false in .silver-bullet.json.
See docs/ALUMNIUM.md and silver-bullet.md §8.1.
EOF
}

sb_alumnium_prompt_reminder_line() {
  local config_file="${1:-}"
  case "$(sb_recommended_tool_consent "$config_file" "alumnium")" in
    pending)
      printf '%s' "Alumnium: consent pending — ask user to opt in or out (browser/visual MCP; see docs/ALUMNIUM.md)."
      ;;
    disabled)
      printf '%s' "Alumnium: opted out — use host browser MCP fallback for UI evidence (§8.1)."
      ;;
    *)
      if sb_alumnium_platform_artifact_present "$(dirname "$config_file")"; then
        printf '%s' "Alumnium: MCP wired — prefer do/check/get/wait for UI clarify, ui-review, and verify."
      else
        printf '%s' "Alumnium: opted in but MCP not wired — run platform install per docs/ALUMNIUM.md."
      fi
      ;;
  esac
}

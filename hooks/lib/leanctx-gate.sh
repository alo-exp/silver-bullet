# shellcheck shell=bash
# LeanCTX install/wiring/usage gate — CLI, MCP, and freshness helpers.
# Enforcement active only when recommended_tools.leanctx.enabled_by_user is true.
# Sourced by: leanctx-gate.sh, record-leanctx-usage.sh, sb-diagnostics.sh

_sb_leanctx_default_ttl_seconds=1800
_sb_leanctx_default_cli="lean-ctx"
_sb_leanctx_mcp_server_names='leanctx|lean-ctx|user-leanctx'

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi

sb_leanctx_required() {
  sb_recommended_tool_enforced "${1:-}" "leanctx"
}

sb_leanctx_cli_command() {
  local config_file="${1:-}"
  local cli="${_sb_leanctx_default_cli}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    cli="$(sb_recommended_tool_config_string "$config_file" "leanctx" "cli_command" "$_sb_leanctx_default_cli")"
  fi
  printf '%s' "$cli"
}

sb_leanctx_cli_path() {
  local config_file="${1:-}"
  local cli
  cli="$(sb_leanctx_cli_command "$config_file")"
  if command -v "$cli" >/dev/null 2>&1; then
    command -v "$cli"
    return 0
  fi
  if [[ -x "${HOME}/.local/bin/${cli}" ]]; then
    printf '%s' "${HOME}/.local/bin/${cli}"
    return 0
  fi
  return 1
}

sb_leanctx_cli_available() {
  sb_leanctx_cli_path "${1:-}" >/dev/null 2>&1
}

sb_leanctx_platform_artifact_path() {
  local _project_root="${1:-$PWD}" host="${2:-}"
  if [[ -n "${SB_LEANCTX_MCP_ARTIFACT:-}" ]]; then
    printf '%s' "${SB_LEANCTX_MCP_ARTIFACT}"
    return 0
  fi
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/mcp.json' "${HOME}" ;;
    codex) printf '%s/.codex/config.toml' "${CODEX_HOME:-${HOME}/.codex}" ;;
    opencode) printf '%s/.config/opencode/mcp.json' "${HOME}" ;;
    claude) printf '%s/.claude/settings.json' "${HOME}" ;;
    *) printf '%s/.codex/settings.json' "${HOME}" ;;
  esac
}

sb_leanctx_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_leanctx_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -qE 'leanctx|lean-ctx' "$artifact" 2>/dev/null
}

sb_leanctx_hooks_present() {
  local host="${1:-}"
  local hooks_file
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor)
      hooks_file="${HOME}/.cursor/hooks.json"
      [[ -f "$hooks_file" ]] && grep -qE 'leanctx|lean-ctx' "$hooks_file" 2>/dev/null
      ;;
    codex)
      hooks_file="${CODEX_HOME:-${HOME}/.codex}/hooks.json"
      [[ -f "$hooks_file" ]] && grep -qE 'leanctx|lean-ctx' "$hooks_file" 2>/dev/null
      ;;
    claude)
      # Claude wires lean-ctx through settings.json (hooks + MCP server entry)
      # rather than a standalone hooks.json.
      hooks_file="${HOME}/.claude/settings.json"
      [[ -f "$hooks_file" ]] && grep -qE 'leanctx|lean-ctx' "$hooks_file" 2>/dev/null
      ;;
    *)
      # Intentionally permissive: for hosts SB has no wiring contract for we
      # cannot distinguish "not wired" from "wired somewhere we don't know
      # about", so we must not block on an unverifiable claim.
      return 0
      ;;
  esac
}

sb_leanctx_usage_ttl_seconds() {
  local config_file="${1:-}"
  local ttl="${_sb_leanctx_default_ttl_seconds}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r --argjson def "$_sb_leanctx_default_ttl_seconds" \
      '.recommended_tools.leanctx.usage_ttl_seconds // $def' "$config_file" 2>/dev/null || echo "$_sb_leanctx_default_ttl_seconds")"
  fi
  if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 60 ]]; then
    ttl="${_sb_leanctx_default_ttl_seconds}"
  fi
  printf '%s' "$ttl"
}

sb_leanctx_usage_state_path() {
  local config_file="${1:-}"
  local state_path=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    state_path="$(jq -r '.recommended_tools.leanctx.usage_state_file // ""' "$config_file" 2>/dev/null || true)"
    state_path="${state_path/#\~/$HOME}"
    state_path="${state_path//\$\{SB_RUNTIME_HOME_ROOT\}/${SB_RUNTIME_HOME_ROOT:-${HOME}/.cursor}}"
    state_path="${state_path//\$\{SB_RUNTIME_STATE_DIR\}/${SB_RUNTIME_STATE_DIR:-${HOME}/.cursor/.silver-bullet}}"
  fi
  if [[ -z "$state_path" ]]; then
    state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/leanctx-usage"
  fi
  if declare -f sb_runtime_path_is_state_scoped >/dev/null 2>&1; then
    if ! sb_runtime_path_is_state_scoped "$state_path"; then
      state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/leanctx-usage"
    fi
  fi
  printf '%s' "$state_path"
}

sb_leanctx_usage_epoch() {
  local state_path="${1:-}"
  [[ -f "$state_path" && ! -L "$state_path" ]] || return 1
  local epoch
  epoch="$(sed -n '1p' "$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$epoch"
}

sb_leanctx_usage_is_fresh() {
  local config_file="${1:-}"
  local state_path epoch now ttl age
  state_path="$(sb_leanctx_usage_state_path "$config_file")"
  epoch="$(sb_leanctx_usage_epoch "$state_path" 2>/dev/null || true)"
  [[ -n "$epoch" ]] || return 1
  now="$(date +%s)"
  ttl="$(sb_leanctx_usage_ttl_seconds "$config_file")"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

sb_leanctx_record_usage() {
  local config_file="${1:-}"
  local state_path
  state_path="$(sb_leanctx_usage_state_path "$config_file")"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "$state_path"
  fi
  date +%s >"$state_path" 2>/dev/null || return 1
}

sb_leanctx_clear_usage_state() {
  local config_file="${1:-}"
  local state_path
  state_path="$(sb_leanctx_usage_state_path "$config_file")"
  rm -f -- "$state_path" 2>/dev/null || true
}

sb_leanctx_edit_path_is_exempt() {
  local file_path="${1:-}"
  local config_file="${2:-}"
  [[ -n "$file_path" ]] || return 1
  case "$file_path" in
    */.silver-bullet.json|*/SETUP_REPORT.md|*/silver-bullet.md|*/CLAUDE.md|*/AGENTS.md)
      return 0
      ;;
  esac
  if [[ "$file_path" == *"/.silver-bullet/"* ]]; then
    return 0
  fi
  if [[ "$file_path" == *"/.cursor/mcp.json" ]] || [[ "$file_path" == *"/.cursor/hooks.json" ]]; then
    return 0
  fi
  if [[ "$file_path" == *"/docs/LEANCTX.md" ]]; then
    return 0
  fi
  return 1
}

sb_leanctx_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(lean-ctx|leanctx)([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE 'install-leanctx-sb|optimize-five-tool-stack'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(brew|curl|npm install|which|command -v|grep|cat|jq|echo|printf|true|false)(\s|$)'; then
    return 0
  fi
  return 1
}

sb_leanctx_command_is_usage() {
  local cmd="${1:-}" config_file="${2:-}"
  local cli
  [[ -n "$cmd" ]] || return 1
  cli="$(sb_leanctx_cli_command "$config_file")"
  if printf '%s' "$cmd" | grep -qE "(^|[[:space:]/])${cli}([[:space:]]|$)"; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(lean-ctx|leanctx)([[:space:]]|$)'; then
    return 0
  fi
  return 1
}

sb_leanctx_mcp_tool_is_usage() {
  local mcp_tool="${1:-}"
  [[ -n "$mcp_tool" ]] || return 1
  case "$mcp_tool" in
    lctx_read_ast|lctx_wire|lctx_compact|lctx_*)
      return 0
      ;;
  esac
  return 1
}

sb_leanctx_mcp_server_matches() {
  local server="${1:-}"
  [[ -n "$server" ]] || return 1
  printf '%s' "$server" | grep -qiE "$_sb_leanctx_mcp_server_names"
}

sb_leanctx_block_message_no_cli() {
  local config_file="${1:-}"
  local host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" leanctx "$host" 2>/dev/null || true)"
  if [[ -z "$install_lines" ]]; then
    install_lines='curl -fsSL https://leanctx.com/install.sh | sh'
  fi
  cat <<EOF
🚫 LEANCTX REQUIRED — CLI not installed (user opted in).

Silver Bullet mandates LeanCTX for wire proxy, AST read, PathJail, and savings ledger when opted in (host: ${host}):

${install_lines}

Verify: lean-ctx --version

To disable enforcement, set recommended_tools.leanctx.enabled_by_user to false in .silver-bullet.json.
See docs/LEANCTX.md.
EOF
}

sb_leanctx_block_message_no_mcp() {
  local config_file="${1:-}"
  local host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_leanctx_platform_artifact_path "$(dirname "$config_file")" "$host")"
  cat <<EOF
🚫 LEANCTX NOT WIRED — MCP integration missing.

Expected LeanCTX MCP entry for host ${host} in:
  ${artifact}

Run platform install (host: ${host}):
$(sb_recommended_tool_platform_install_commands "$config_file" leanctx "$host" 2>/dev/null || true)

See docs/LEANCTX.md.
EOF
}

sb_leanctx_block_message_stale_usage() {
  local config_file="${1:-}"
  local ttl cli
  ttl="$(sb_leanctx_usage_ttl_seconds "$config_file")"
  cli="$(sb_leanctx_cli_command "$config_file")"
  cat <<EOF
🚫 LEANCTX USAGE REQUIRED — invoke LeanCTX before substantive work.

When LeanCTX is opted in, use owned surfaces (wire proxy, lctx_read_ast, PathJail) at least once every ${ttl}s before substantive edits/commits.

Examples:
  • CallMcpTool lctx_read_ast for large-file analysis (sb_read owner)
  • ${cli} status (CLI health check)

A fresh usage stamp is required every ${ttl}s. See docs/LEANCTX.md and silver-bullet.md §2g.
EOF
}

sb_leanctx_prompt_reminder_line() {
  local config_file="${1:-}"
  local project_root host
  project_root="$(dirname "$config_file")"
  host="$(sb_runtime_host)"

  case "$(sb_recommended_tool_consent "$config_file" "leanctx")" in
    pending)
      printf '%s' "LeanCTX: consent pending — ask user to opt in or out (see session-start context)."
      ;;
    disabled)
      printf '%s' "LeanCTX: opted out — enforcements disabled."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "leanctx"; then
        printf '%s' "LeanCTX: opted in but install failed — enforcement suspended until upgrade; retry on /sb:update."
      elif ! sb_leanctx_cli_available "$config_file"; then
        printf '%s' "LeanCTX: CLI missing — install lean-ctx; hooks block substantive work until wired."
      elif ! sb_leanctx_platform_artifact_present "$project_root" "$host"; then
        printf '%s' "LeanCTX: MCP not wired for ${host}."
      elif sb_leanctx_usage_is_fresh "$config_file"; then
        printf '%s' "LeanCTX: fresh usage recorded — substantive work allowed until TTL expires."
      else
        printf '%s' "LeanCTX: USAGE REQUIRED — invoke lctx_read_ast or lean-ctx before edits (TTL $(sb_leanctx_usage_ttl_seconds "$config_file")s)."
      fi
      ;;
  esac
}

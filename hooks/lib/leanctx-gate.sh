# shellcheck shell=bash
# LeanCTX install/wiring/usage gate — CLI, MCP, and freshness helpers.
# Enforcement is active only with the user's consent (see user-consent.sh) in a project
# whose .silver-bullet.json does not turn LeanCTX off.
# Sourced by: leanctx-gate.sh, record-leanctx-usage.sh, context-mode-read-deny.sh,
# session-start, sb-diagnostics.sh

_sb_leanctx_default_ttl_seconds=1800
_sb_leanctx_default_cli="lean-ctx"
_sb_leanctx_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_leanctx_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_leanctx_lib_dir}/opt-in-gate.sh"

sb_leanctx_required() {
  sb_recommended_tool_enforced "${1:-}" "leanctx"
}

# The CLI name. It used to come from the project config and was spliced into a regex, so a
# repository could make any command count as LeanCTX usage; the user-level five-tool
# manifest (sb_global_tool_path) is the place to point at a differently installed binary.
sb_leanctx_cli_command() {
  printf '%s' "$_sb_leanctx_default_cli"
}

sb_leanctx_cli_path() {
  sb_global_tool_path leanctx 2>/dev/null && return 0
  if command -v "$_sb_leanctx_default_cli" >/dev/null 2>&1; then
    command -v "$_sb_leanctx_default_cli"
    return 0
  fi
  if [[ -x "${HOME}/.local/bin/${_sb_leanctx_default_cli}" ]]; then
    printf '%s' "${HOME}/.local/bin/${_sb_leanctx_default_cli}"
    return 0
  fi
  return 1
}

sb_leanctx_cli_available() {
  sb_leanctx_cli_path >/dev/null 2>&1
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
    codex) printf '%s/config.toml' "${CODEX_HOME:-${HOME}/.codex}" ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    pi) printf '%s/extensions/silver-bullet-five-tool-stack/config.json' \
      "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}" ;;
    *) printf '%s/.claude/settings.json' "${HOME}" ;;
  esac
}

sb_leanctx_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}" artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_leanctx_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -qE 'leanctx|lean-ctx' "$artifact" 2>/dev/null
}

sb_leanctx_usage_ttl_seconds() {
  local config_file="${1:-}" ttl=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r '.recommended_tools.leanctx.usage_ttl_seconds // "" | tostring' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_ttl_seconds "$ttl" "$_sb_leanctx_default_ttl_seconds"
}

# The usage stamp; a configured usage_state_file is honoured only inside the state dir.
sb_leanctx_usage_state_path() {
  local config_file="${1:-}" configured=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    configured="$(jq -r '.recommended_tools.leanctx.usage_state_file // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_state_file "$configured" leanctx-usage
}

sb_leanctx_usage_is_fresh() {
  local config_file="${1:-}"
  sb_rt_stamp_is_fresh "$(sb_leanctx_usage_state_path "$config_file")" \
    "$(sb_leanctx_usage_ttl_seconds "$config_file")"
}

sb_leanctx_record_usage() {
  sb_rt_stamp_write "$(sb_leanctx_usage_state_path "${1:-}")"
}

# Cleared with the other usage stamps when the branch or worktree changes (session-start).
sb_leanctx_clear_usage_state() {
  rm -f -- "$(sb_leanctx_usage_state_path "${1:-}")" 2>/dev/null || true
}

# Status 0 when an edit target is SB configuration or LeanCTX's own wiring (normalized).
sb_leanctx_edit_path_is_exempt() {
  local normalized
  [[ -n "${1:-}" ]] || return 1
  normalized="$(sb_opt_in_normalize_path "$1" "$(dirname "${2:-$PWD/x}")")"
  case "$normalized" in
    */.silver-bullet.json | */SETUP_REPORT.md | */silver-bullet.md | */CLAUDE.md | */AGENTS.md \
      | */.silver-bullet/* | */.cursor/mcp.json | */.cursor/hooks.json | */docs/LEANCTX.md)
      return 0
      ;;
  esac
  return 1
}

sb_leanctx_command_is_exempt() {
  ! sb_opt_in_shell_needs_gate leanctx "${1:-}"
}

# Status 0 when CMD is one LeanCTX CLI invocation (single simple command; a word in another
# program's arguments, or a call inside a pipe or list that could hide a failure, is not).
sb_leanctx_command_is_usage() {
  local cmd program
  cmd="$(sb_opt_in_rtk_unwrap "${1:-}")"
  cmd="$(_sb_opt_in_squash "$cmd")"
  [[ -n "$cmd" ]] && _sb_opt_in_simple_command "$cmd" || return 1
  program="$(_sb_opt_in_program "$cmd" || true)"
  [[ "$program" == "lean-ctx" || "$program" == "leanctx" ]]
}

sb_leanctx_mcp_tool_is_usage() {
  [[ "${1:-}" =~ ^lctx_[A-Za-z0-9_]+$ ]]
}

# The LeanCTX MCP server: leanctx, lean-ctx, or a namespaced name ending in one of them.
sb_leanctx_mcp_server_matches() {
  [[ "${1:-}" =~ ^([A-Za-z0-9_-]+[_-])?lean-?ctx$ ]]
}

sb_leanctx_block_message_no_cli() {
  local config_file="${1:-}" host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" leanctx "$host")"
  cat <<EOF
🚫 LEANCTX REQUIRED — CLI not installed (you opted in to LeanCTX enforcement).

Silver Bullet mandates LeanCTX for wire proxy, AST read, PathJail, and savings ledger when opted in (host: ${host}):

${install_lines}

Verify: lean-ctx --version

To turn LeanCTX enforcement off: bash $(sb_rt_plugin_script scripts/sb-consent.sh) decline leanctx --project $(printf '%q' "$(dirname "${config_file:-$PWD/x}")")
See docs/LEANCTX.md.
EOF
}

sb_leanctx_block_message_no_mcp() {
  local config_file="${1:-}" host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_leanctx_platform_artifact_path "$(dirname "${config_file:-$PWD/x}")" "$host")"
  cat <<EOF
🚫 LEANCTX NOT WIRED — MCP integration missing.

Expected LeanCTX MCP entry for host ${host} in:
  ${artifact}

Run platform install (host: ${host}):
$(sb_recommended_tool_platform_install_commands "" leanctx "$host")

See docs/LEANCTX.md.
EOF
}

sb_leanctx_block_message_stale_usage() {
  local config_file="${1:-}" ttl
  ttl="$(sb_leanctx_usage_ttl_seconds "$config_file")"
  cat <<EOF
🚫 LEANCTX USAGE REQUIRED — invoke LeanCTX before substantive work.

When LeanCTX is opted in, use owned surfaces (wire proxy, lctx_read_ast, PathJail) at least once every ${ttl}s before substantive edits/commits.

Examples:
  • lctx_read_ast from the LeanCTX MCP server for large-file analysis (sb_read owner)
  • lean-ctx status (CLI health check), run on its own

A fresh usage stamp is required every ${ttl}s. See docs/LEANCTX.md and silver-bullet.md §2g.
EOF
}

sb_leanctx_prompt_reminder_line() {
  local config_file="${1:-}" project_root host
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

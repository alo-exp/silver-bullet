# shellcheck shell=bash
# Shared usage gate for RTK CLI freshness before delivery commands (git commit, gh pr create,
# gh release create). Active with the user's consent to RTK and install_status=installed.
# Sourced by: token-compression-tools-gate.sh, record-token-compression-usage.sh,
# prompt-reminder.sh

_sb_token_tool_default_ttl=1800
_sb_token_tool_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_token_tool_lib_dir}/recommended-tools.sh"
# The mutual-exclusion state belongs to the coordinator; without it that check is skipped.
if [[ -f "${_sb_token_tool_lib_dir}/stack-compression-coordinator.sh" ]]; then
  # shellcheck source=stack-compression-coordinator.sh
  source "${_sb_token_tool_lib_dir}/stack-compression-coordinator.sh"
fi

# The tool's CLI name: built in. A config cli_command (repository data) used to be spliced
# into a regex, so a repository could make every command (e.g. git) count as RTK usage.
sb_token_tool_cli_command() {
  case "${2:-}" in
    context_mode) printf 'context-mode' ;;
    *) printf '%s' "${2:-}" ;;
  esac
}

sb_token_tool_usage_ttl_seconds() {
  sb_rt_ttl_seconds "$(sb_recommended_tool_config_string "${1:-}" "${2:-}" "usage_ttl_seconds" "")" \
    "$_sb_token_tool_default_ttl"
}

# The usage stamp; a configured usage_state_file is honoured only inside the state dir.
sb_token_tool_usage_state_path() {
  local config_file="${1:-}" tool_id="${2:-}"
  sb_rt_state_file "$(sb_recommended_tool_config_string "$config_file" "$tool_id" "usage_state_file" "")" \
    "${tool_id}-usage"
}

sb_token_tool_install_ready() {
  [[ "$(sb_recommended_tool_install_status "${1:-}" "${2:-}")" == "installed" ]]
}

sb_token_tool_cli_available() {
  command -v "$(sb_token_tool_cli_command "${1:-}" "${2:-}")" >/dev/null 2>&1
}

sb_token_tool_usage_is_fresh() {
  local config_file="${1:-}" tool_id="${2:-}"
  sb_rt_stamp_is_fresh "$(sb_token_tool_usage_state_path "$config_file" "$tool_id")" \
    "$(sb_token_tool_usage_ttl_seconds "$config_file" "$tool_id")"
}

sb_token_tool_record_usage() {
  sb_rt_stamp_write "$(sb_token_tool_usage_state_path "${1:-}" "${2:-}")"
}

# Status 0 when CMD runs the CLI: its first program (after optional env and NAME=value
# words) is CLI. A mention in another program's arguments (echo rtk) does not count.
sb_token_tool_command_matches() {
  local cmd="${1:-}" cli="${3:-}" program
  [[ -n "$cmd" && -n "$cli" ]] || return 1
  cmd="${cmd#"${cmd%%[![:space:]]*}"}"
  [[ "$cmd" == "env "* ]] && cmd="${cmd#env }"
  program="$(_sb_opt_in_program "${cmd%%[;&|<>]*}" || true)"
  [[ "$program" == "$cli" ]]
}

sb_token_tool_enforced() {
  local config_file="${1:-}" tool_id="${2:-}"
  sb_recommended_tool_enforced "$config_file" "$tool_id" || return 1
  sb_token_tool_install_ready "$config_file" "$tool_id" || return 1
}

# Status 0 when a shell command is a delivery step this gate guards. A command the shared
# analyzer proves read-only (echo "git commit", git log --grep 'gh pr create') never is.
sb_token_tool_command_is_delivery() {
  local cmd
  cmd="$(sb_opt_in_rtk_unwrap "${1:-}")"
  [[ -n "$cmd" ]] || return 1
  sb_shell_command_looks_read_only "$cmd" >/dev/null 2>&1 && return 1
  sb_opt_in_shell_is_delivery "$cmd"
}

sb_token_tool_block_message() {
  local config_file="${1:-}" tool_id="${2:-}" display cli ttl
  display="$(sb_recommended_tool_display_name "$tool_id")"
  cli="$(sb_token_tool_cli_command "$config_file" "$tool_id")"
  ttl="$(sb_token_tool_usage_ttl_seconds "$config_file" "$tool_id")"
  cat <<EOF
🚫 ${display} USAGE REQUIRED — run ${cli} before substantive compression-sensitive work.

When ${display} is opted in, invoke the CLI at least once every ${ttl}s before commits, PRs and releases. See silver-bullet.md §2g-i and docs/code-intelligence-contract.md.
EOF
}

sb_token_compression_mutual_exclusion_block_message() {
  sb_stack_mutual_exclusion_block_message
}

# Status 0 when the coordinator reports a double-compression violation for this project/session.
sb_token_tool_mutex_dirty() {
  local config_file="${1:-}"
  declare -f sb_stack_mutual_exclusion_required >/dev/null 2>&1 || return 1
  sb_stack_mutual_exclusion_required "$config_file" && ! sb_stack_mutual_exclusion_is_clean "$config_file"
}

sb_token_tool_prompt_reminder_line() {
  local config_file="${1:-}" tool_id="${2:-}" display cli ttl
  display="$(sb_recommended_tool_display_name "$tool_id")"
  cli="$(sb_token_tool_cli_command "$config_file" "$tool_id")"

  case "$(sb_recommended_tool_consent "$config_file" "$tool_id")" in
    pending)
      printf '%s' "${display}: consent pending — ask user to opt in or out."
      ;;
    disabled)
      printf '%s' "${display}: opted out — enforcement inactive."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "$tool_id"; then
        printf '%s' "${display}: opted in but install failed — enforcement suspended."
      elif ! sb_token_tool_install_ready "$config_file" "$tool_id"; then
        printf '%s' "${display}: integration pending — install_status not installed yet."
      elif ! sb_token_tool_cli_available "$config_file" "$tool_id"; then
        printf '%s' "${display}: CLI \`${cli}\` missing — install before substantive work."
      elif sb_token_tool_usage_is_fresh "$config_file" "$tool_id"; then
        printf '%s' "${display}: fresh usage recorded — substantive work allowed until TTL expires."
      else
        ttl="$(sb_token_tool_usage_ttl_seconds "$config_file" "$tool_id")"
        printf '%s' "${display}: USAGE REQUIRED — run \`${cli}\` before substantive work (TTL ${ttl}s)."
      fi
      ;;
  esac
}

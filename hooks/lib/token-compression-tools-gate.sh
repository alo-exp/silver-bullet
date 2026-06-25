# shellcheck shell=bash
# Shared usage gate for RTK CLI freshness before substantive commits.
# Active when enabled_by_user=true and install_status=installed.

_sb_token_tool_default_ttl=1800

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools-registry.sh" ]]; then
  # shellcheck source=recommended-tools-registry.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools-registry.sh"
fi

sb_token_tool_cli_command() {
  local config_file="${1:-}" tool_id="${2:-}"
  local cli
  cli="$(sb_recommended_tool_config_string "$config_file" "$tool_id" "cli_command" "$tool_id")"
  printf '%s' "$cli"
}

sb_token_tool_usage_ttl_seconds() {
  local config_file="${1:-}" tool_id="${2:-}"
  local ttl
  ttl="$(sb_recommended_tool_config_string "$config_file" "$tool_id" "usage_ttl_seconds" "$_sb_token_tool_default_ttl")"
  if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 60 ]]; then
    ttl="$_sb_token_tool_default_ttl"
  fi
  printf '%s' "$ttl"
}

sb_token_tool_usage_state_path() {
  local config_file="${1:-}" tool_id="${2:-}"
  local state_path
  state_path="$(sb_recommended_tool_config_string "$config_file" "$tool_id" "usage_state_file" "")"
  state_path="${state_path/#\~/$HOME}"
  if [[ -z "$state_path" ]]; then
    state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.cursor/.silver-bullet}/${tool_id}-usage"
  fi
  printf '%s' "$state_path"
}

sb_token_tool_install_ready() {
  local config_file="${1:-}" tool_id="${2:-}"
  [[ "$(sb_recommended_tool_install_status "$config_file" "$tool_id")" == "installed" ]]
}

sb_token_tool_cli_available() {
  local config_file="${1:-}" tool_id="${2:-}"
  local cli
  cli="$(sb_token_tool_cli_command "$config_file" "$tool_id")"
  command -v "$cli" >/dev/null 2>&1
}

sb_token_tool_usage_is_fresh() {
  local config_file="${1:-}" tool_id="${2:-}"
  local state_path epoch now ttl age
  state_path="$(sb_token_tool_usage_state_path "$config_file" "$tool_id")"
  [[ -f "$state_path" ]] || return 1
  epoch="$(tr -d '[:space:]' <"$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s)"
  ttl="$(sb_token_tool_usage_ttl_seconds "$config_file" "$tool_id")"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

sb_token_tool_record_usage() {
  local config_file="${1:-}" tool_id="${2:-}"
  local state_path
  state_path="$(sb_token_tool_usage_state_path "$config_file" "$tool_id")"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  date +%s >"$state_path" 2>/dev/null || return 1
}

sb_token_tool_command_matches() {
  local cmd="${1:-}" tool_id="${2:-}" cli="${3:-}"
  [[ -n "$cmd" && -n "$cli" ]] || return 1
  printf '%s' "$cmd" | grep -qE "(^|[[:space:]/])${cli}([[:space:]]|$)"
}

sb_token_tool_enforced() {
  local config_file="${1:-}" tool_id="${2:-}"
  sb_recommended_tool_enforced "$config_file" "$tool_id" || return 1
  sb_token_tool_install_ready "$config_file" "$tool_id" || return 1
}

sb_token_tool_block_message() {
  local config_file="${1:-}" tool_id="${2:-}"
  local display cli ttl
  display="$(sb_recommended_tool_display_name "$tool_id")"
  cli="$(sb_token_tool_cli_command "$config_file" "$tool_id")"
  ttl="$(sb_token_tool_usage_ttl_seconds "$config_file" "$tool_id")"
  cat <<EOF
🚫 ${display} USAGE REQUIRED — run ${cli} before substantive compression-sensitive work.

When ${display} is opted in, invoke the CLI at least once every ${ttl}s before edits/commits that expand context. See silver-bullet.md §2g-i and docs/code-intelligence-contract.md.
EOF
}

sb_token_tool_prompt_reminder_line() {
  local config_file="${1:-}" tool_id="${2:-}"
  local display cli ttl
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

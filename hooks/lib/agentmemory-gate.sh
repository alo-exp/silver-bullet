# shellcheck shell=bash
# agentmemory capture gate — CLI/server/MCP/export helpers.
# Enforcement active only when recommended_tools.agentmemory.enabled_by_user is true.
# Sourced by: agentmemory-gate.sh, record-agentmemory-usage.sh, prompt-reminder.sh, sb-diagnostics.sh

_sb_agentmemory_default_ttl_seconds=1800
_sb_agentmemory_default_health_url="http://localhost:3111/agentmemory/health"
_sb_agentmemory_default_export_root=".agentmemory"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]]; then
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"
fi

sb_agentmemory_required() {
  sb_recommended_tool_enforced "${1:-}" "agentmemory"
}

sb_agentmemory_health_url() {
  local config_file="${1:-}"
  local url="${_sb_agentmemory_default_health_url}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    url="$(jq -r --arg def "$_sb_agentmemory_default_health_url" \
      '.recommended_tools.agentmemory.health_url // $def' "$config_file" 2>/dev/null || echo "$_sb_agentmemory_default_health_url")"
  fi
  printf '%s' "$url"
}

sb_agentmemory_export_rel_path() {
  local config_file="${1:-}"
  local rel="${_sb_agentmemory_default_export_root}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    rel="$(jq -r --arg def "$_sb_agentmemory_default_export_root" \
      '.recommended_tools.agentmemory.export_root // $def' "$config_file" 2>/dev/null || echo "$_sb_agentmemory_default_export_root")"
  fi
  printf '%s' "$rel"
}

sb_agentmemory_abs_export_path() {
  local project_root="${1:-$PWD}"
  local config_file="${2:-}"
  local rel
  rel="$(sb_agentmemory_export_rel_path "$config_file")"
  if [[ "$rel" == /* ]]; then
    printf '%s' "$rel"
  else
    printf '%s/%s' "${project_root%/}" "$rel"
  fi
}

sb_agentmemory_export_exists() {
  local project_root="${1:-$PWD}"
  local config_file="${2:-}"
  local export_path
  export_path="$(sb_agentmemory_abs_export_path "$project_root" "$config_file")"
  [[ -d "$export_path" && ! -L "$export_path" ]]
}

sb_agentmemory_cli_path() {
  if command -v agentmemory >/dev/null 2>&1; then
    command -v agentmemory
    return 0
  fi
  return 1
}

sb_agentmemory_cli_available() {
  sb_agentmemory_cli_path >/dev/null 2>&1
}

sb_agentmemory_server_healthy() {
  local config_file="${1:-}"
  local url
  url="$(sb_agentmemory_health_url "$config_file")"
  command -v curl >/dev/null 2>&1 || return 1
  curl -sf --max-time 3 "$url" >/dev/null 2>&1
}

sb_agentmemory_platform_artifact_path() {
  local _project_root="${1:-$PWD}" host="${2:-}"
  if [[ -n "${SB_AGENTMEMORY_MCP_ARTIFACT:-}" ]]; then
    printf '%s' "${SB_AGENTMEMORY_MCP_ARTIFACT}"
    return 0
  fi
  host="${host:-$(sb_runtime_host)}"
  case "$host" in
    cursor) printf '%s/.cursor/mcp.json' "${HOME}" ;;
    codex) printf '%s/.codex/config.toml' "${HOME}" ;;
    opencode) printf '%s/.config/opencode/opencode.json' "${HOME}" ;;
    goose) printf '%s/.config/goose/config.yaml' "${HOME}" ;;
    hermes) printf '%s/.hermes/config.yaml' "${HOME}" ;;
    *) printf '%s/.claude.json' "${HOME}" ;;
  esac
}

sb_agentmemory_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}"
  local artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_agentmemory_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -q 'agentmemory' "$artifact" 2>/dev/null
}

sb_agentmemory_usage_ttl_seconds() {
  local config_file="${1:-}"
  local ttl="${_sb_agentmemory_default_ttl_seconds}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r --argjson def "$_sb_agentmemory_default_ttl_seconds" \
      '.recommended_tools.agentmemory.usage_ttl_seconds // $def' "$config_file" 2>/dev/null || echo "$_sb_agentmemory_default_ttl_seconds")"
  fi
  if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 60 ]]; then
    ttl="${_sb_agentmemory_default_ttl_seconds}"
  fi
  printf '%s' "$ttl"
}

sb_agentmemory_usage_state_path() {
  local config_file="${1:-}"
  local state_path=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    state_path="$(jq -r '.recommended_tools.agentmemory.usage_state_file // ""' "$config_file" 2>/dev/null || true)"
    state_path="${state_path/#\~/$HOME}"
  fi
  if [[ -z "$state_path" ]]; then
    state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/agentmemory-usage"
  fi
  if declare -f sb_runtime_path_is_state_scoped >/dev/null 2>&1; then
    if ! sb_runtime_path_is_state_scoped "$state_path"; then
      state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/agentmemory-usage"
    fi
  fi
  printf '%s' "$state_path"
}

sb_agentmemory_usage_epoch() {
  local state_path="${1:-}"
  [[ -f "$state_path" && ! -L "$state_path" ]] || return 1
  local epoch
  epoch="$(sed -n '1p' "$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$epoch"
}

sb_agentmemory_usage_is_fresh() {
  local config_file="${1:-}"
  local state_path epoch now ttl age
  state_path="$(sb_agentmemory_usage_state_path "$config_file")"
  epoch="$(sb_agentmemory_usage_epoch "$state_path" 2>/dev/null || true)"
  [[ -n "$epoch" ]] || return 1
  now="$(date +%s)"
  ttl="$(sb_agentmemory_usage_ttl_seconds "$config_file")"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

sb_agentmemory_record_usage() {
  local config_file="${1:-}"
  local state_path
  state_path="$(sb_agentmemory_usage_state_path "$config_file")"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "$state_path"
  fi
  date +%s >"$state_path" 2>/dev/null || return 1
}

sb_agentmemory_clear_usage_state() {
  local config_file="${1:-}"
  local state_path
  state_path="$(sb_agentmemory_usage_state_path "$config_file")"
  rm -f -- "$state_path" 2>/dev/null || true
}

# When Graphify handles retrieval, agentmemory gate checks infrastructure only.
sb_agentmemory_graphify_synergy_active() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  if ! declare -f sb_graphify_query_is_fresh >/dev/null 2>&1; then
    local _gf_lib
    _gf_lib="$(dirname "${BASH_SOURCE[0]}")/graphify-gate.sh"
    # shellcheck disable=SC1090
    [[ -f "$_gf_lib" ]] && source "$_gf_lib"
  fi
  if ! declare -f sb_graphify_required >/dev/null 2>&1; then
    return 1
  fi
  sb_graphify_required "$config_file" || return 1
  sb_graphify_query_is_fresh "$config_file"
}

sb_agentmemory_command_is_retrieval() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  if printf '%s' "$cmd" | grep -qE 'localhost:3111/agentmemory/(smart-search|search|recall|file-history)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])agentmemory([[:space:]]|$)'; then
    printf '%s' "$cmd" | grep -qE '\b(search|recall|smart-search|file-history|query)\b' && return 0
  fi
  if printf '%s' "$cmd" | grep -qE '@agentmemory/mcp'; then
    return 0
  fi
  return 1
}

sb_agentmemory_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if sb_agentmemory_command_is_retrieval "$cmd"; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])agentmemory([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE 'localhost:3111/agentmemory'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(curl|mkdir|chmod|cat|head|tail|grep|jq|npm install|nohup|kill|lsof|curl|which|command -v|echo|printf|true|false|systemctl|launchctl)(\s|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)'; then
    return 0
  fi
  return 1
}

sb_agentmemory_edit_path_is_exempt() {
  local file_path="${1:-}"
  local config_file="${2:-}"
  [[ -n "$file_path" ]] || return 1
  local export_rel
  export_rel="$(sb_agentmemory_export_rel_path "$config_file")"
  case "$file_path" in
    */"${export_rel}"/*|"${export_rel}"/*)
      return 0
      ;;
  esac
  if [[ "$file_path" == *"/.silver-bullet/"* ]]; then
    return 0
  fi
  return 1
}

sb_agentmemory_block_message_no_cli() {
  local config_file="${1:-}"
  local host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" agentmemory "$host" 2>/dev/null || true)"
  if [[ -z "$install_lines" ]]; then
    install_lines=$'npm install -g @agentmemory/agentmemory'
  fi
  cat <<EOF
🚫 AGENTMEMORY REQUIRED — CLI not installed (user opted in).

Silver Bullet mandates agentmemory for session capture and git-backed memory export. Install before substantive work (host: ${host}):

${install_lines}

Start the server: nohup agentmemory > ~/.agentmemory/server.log 2>&1 &

To disable enforcement, set recommended_tools.agentmemory.enabled_by_user to false in .silver-bullet.json.
EOF
}

sb_agentmemory_block_message_no_server() {
  local config_file="${1:-}"
  local url
  url="$(sb_agentmemory_health_url "$config_file")"
  cat <<EOF
🚫 AGENTMEMORY SERVER DOWN — start the memory engine before substantive work.

Health check failed: ${url}

From a shell:
  mkdir -p ~/.agentmemory
  nohup agentmemory > ~/.agentmemory/server.log 2>&1 &

Verify: curl -sf ${url}

Hooks block substantive edits until the server responds.
EOF
}

sb_agentmemory_block_message_no_mcp() {
  local config_file="${1:-}"
  local host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_agentmemory_platform_artifact_path "$(dirname "$config_file")" "$host")"
  cat <<EOF
🚫 AGENTMEMORY MCP NOT WIRED — connect the agent before substantive work.

Expected MCP registration for host ${host} in:
  ${artifact}

Run platform connect from the project root (host: ${host}):
$(sb_recommended_tool_platform_install_commands "$config_file" agentmemory "$host" 2>/dev/null || true)

See docs/AGENTMEMORY.md for Cursor MCP merge steps.
EOF
}

sb_agentmemory_block_message_no_export() {
  local export_path="${1:-.agentmemory}"
  cat <<EOF
🚫 AGENTMEMORY EXPORT ROOT MISSING — scaffold project memory directory.

Create and configure the export root:
  mkdir -p ${export_path}/memory ${export_path}/snapshots

Ensure ~/.agentmemory/.env sets AGENTMEMORY_EXPORT_ROOT=./${export_path##*/} and restart the server.
See docs/AGENTMEMORY.md for git-backed auto-save setup.
EOF
}

sb_agentmemory_block_message_stale_usage() {
  local ttl="${1:-1800}"
  cat <<EOF
🚫 AGENTMEMORY USAGE REQUIRED — recall memory before substantive work.

When Graphify is not handling retrieval, query agentmemory first:
  curl -s -X POST http://localhost:3111/agentmemory/smart-search -H "Content-Type: application/json" -d '{"query":"<task context>"}'

Or invoke agentmemory MCP tools (memory_smart_search, memory_recall). A fresh usage is required every ${ttl}s.

When both agentmemory and Graphify are enabled: save via agentmemory, retrieve via Graphify query.
EOF
}

sb_agentmemory_prompt_reminder_line() {
  local config_file="${1:-}"
  local project_root export_rel ttl
  project_root="$(dirname "$config_file")"
  export_rel="$(sb_agentmemory_export_rel_path "$config_file")"

  case "$(sb_recommended_tool_consent "$config_file" "agentmemory")" in
    pending)
      printf '%s' "agentmemory: consent pending — ask user to opt in or out (see session-start context)."
      ;;
    disabled)
      printf '%s' "agentmemory: opted out — enforcements disabled."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "agentmemory"; then
        printf '%s' "agentmemory: opted in but install failed — enforcement suspended until upgrade; retry on /silver:update."
      elif ! sb_agentmemory_cli_available; then
        printf '%s' "agentmemory: CLI missing — install @agentmemory/agentmemory; hooks block substantive work until installed."
      elif ! sb_agentmemory_server_healthy "$config_file"; then
        printf '%s' "agentmemory: server down — run \`nohup agentmemory > ~/.agentmemory/server.log 2>&1 &\`; hooks block until healthy."
      elif ! sb_agentmemory_platform_artifact_present "$project_root" "$config_file"; then
        printf '%s' "agentmemory: MCP not wired — run platform connect (see docs/AGENTMEMORY.md)."
      elif ! sb_agentmemory_export_exists "$project_root" "$config_file"; then
        printf '%s' "agentmemory: export root missing — mkdir -p ${export_rel}/memory; hooks block until present."
      elif sb_agentmemory_graphify_synergy_active "$config_file"; then
        printf '%s' "agentmemory+Graphify: capture via agentmemory; retrieve via Graphify query (synergy active)."
      elif sb_agentmemory_usage_is_fresh "$config_file"; then
        printf '%s' "agentmemory: fresh usage recorded — substantive work allowed until TTL expires."
      else
        ttl="$(sb_agentmemory_usage_ttl_seconds "$config_file")"
        printf '%s' "agentmemory: USAGE REQUIRED — recall via MCP or smart-search before edits (TTL ${ttl}s), or enable Graphify for retrieval."
      fi
      ;;
  esac
}

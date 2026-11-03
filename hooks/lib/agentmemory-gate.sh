# shellcheck shell=bash
# agentmemory capture gate — CLI/server/MCP/export helpers.
# Enforcement is active only with the user's consent (see user-consent.sh) in a project
# whose .silver-bullet.json does not turn agentmemory off.
# Sourced by: agentmemory-gate.sh, record-agentmemory-usage.sh, record-recommended-mcp.sh,
# prompt-reminder.sh, session-start, sb-diagnostics.sh

_sb_agentmemory_default_ttl_seconds=1800
_sb_agentmemory_default_health_url="http://localhost:3111/agentmemory/health"
_sb_agentmemory_default_export_root=".agentmemory"
_sb_agentmemory_health_cache_seconds=30
_sb_agentmemory_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_agentmemory_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_agentmemory_lib_dir}/opt-in-gate.sh"

sb_agentmemory_required() {
  sb_recommended_tool_enforced "${1:-}" "agentmemory"
}

# The health URL. The config value is repository data: only http(s) to localhost, 127.0.0.1
# or [::1] (optional port, plain path) is accepted, so it can never be a curl option, a
# file:// URL or a beacon to another host.
sb_agentmemory_health_url() {
  local config_file="${1:-}" url=""
  local re='^https?://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]{1,5})?(/[A-Za-z0-9._~/%-]*)?$'
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    url="$(jq -r '.recommended_tools.agentmemory.health_url // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  [[ "$url" =~ $re ]] || url="$_sb_agentmemory_default_health_url"
  printf '%s' "$url"
}

sb_agentmemory_export_rel_path() {
  local config_file="${1:-}" rel=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    rel="$(jq -r '.recommended_tools.agentmemory.export_root // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_safe_rel_path "$rel" "$_sb_agentmemory_default_export_root"
}

sb_agentmemory_export_rel_is_safe() {
  local rel="${1:-}"
  [[ -n "$rel" && "$(sb_rt_safe_rel_path "$rel" "")" == "$rel" ]]
}

# Status 0 when EXPORT_PATH resolves (physically) inside PROJECT_ROOT.
sb_agentmemory_export_path_is_project_scoped() {
  local project_root="${1:-}" export_path="${2:-}"
  [[ -n "$project_root" && -n "$export_path" ]] || return 1
  sb_opt_in_path_under "$export_path" "$project_root"
}

sb_agentmemory_abs_export_path() {
  local project_root="${1:-$PWD}" config_file="${2:-}" abs
  abs="${project_root%/}/$(sb_agentmemory_export_rel_path "$config_file")"
  sb_agentmemory_export_path_is_project_scoped "$project_root" "$abs" || return 1
  printf '%s' "$abs"
}

sb_agentmemory_export_exists() {
  local project_root="${1:-$PWD}" config_file="${2:-}" export_path
  export_path="$(sb_agentmemory_abs_export_path "$project_root" "$config_file" 2>/dev/null || true)"
  [[ -n "$export_path" && -d "$export_path" && ! -L "$export_path" ]]
}

sb_agentmemory_scaffold_export_root() {
  local project_root="${1:-$PWD}" config_file="${2:-}" export_path
  export_path="$(sb_agentmemory_abs_export_path "$project_root" "$config_file" 2>/dev/null || true)"
  [[ -n "$export_path" ]] || return 1
  mkdir -p "${export_path}/memory" "${export_path}/snapshots" 2>/dev/null || return 1
}

sb_agentmemory_cli_path() {
  sb_global_tool_path agentmemory 2>/dev/null && return 0
  if command -v agentmemory >/dev/null 2>&1; then
    command -v agentmemory
    return 0
  fi
  return 1
}

sb_agentmemory_cli_available() {
  sb_agentmemory_cli_path >/dev/null 2>&1
}

# Probe the server without trusting the URL: it is validated above and passed after "--",
# only http(s) is allowed, redirects are not followed and proxies are bypassed (loopback).
_sb_agentmemory_probe() {
  local url="$1" am_bin status_out
  if command -v curl >/dev/null 2>&1 \
    && curl -sf --max-time 2 --proto '=http,https' --max-redirs 0 --noproxy '*' -o /dev/null -- "$url" >/dev/null 2>&1; then
    return 0
  fi
  am_bin="$(sb_agentmemory_cli_path 2>/dev/null || true)"
  if [[ -n "$am_bin" ]]; then
    status_out="$("$am_bin" status 2>/dev/null || true)"
    grep -qE 'Connected|Health:[[:space:]]+healthy' <<<"$status_out" && return 0
  fi
  return 1
}

# Server health, cached for a few seconds in the runtime state dir so prompts, session
# start and gated calls do not each wait on the network. The cache only shapes messages
# and the optimization score; no gate decision is relaxed by it.
sb_agentmemory_server_healthy() {
  local config_file="${1:-}" url cache epoch="" status="" cached_url="" now
  url="$(sb_agentmemory_health_url "$config_file")"
  cache="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/agentmemory-health"
  now="$(date +%s)"
  if [[ -f "$cache" && ! -L "$cache" ]]; then
    IFS=' ' read -r epoch status cached_url <"$cache" || true
    if [[ "$epoch" =~ ^[0-9]{1,12}$ && "$cached_url" == "$url" ]] \
      && ((now - 10#$epoch >= 0 && now - 10#$epoch < _sb_agentmemory_health_cache_seconds)); then
      [[ "$status" == "up" ]] && return 0
      return 1
    fi
  fi
  status="down"
  _sb_agentmemory_probe "$url" && status="up"
  mkdir -p "$(dirname "$cache")" 2>/dev/null || true
  local tmp
  if tmp="$(mktemp "${cache}.XXXXXX" 2>/dev/null)"; then
    if printf '%s %s %s\n' "$now" "$status" "$url" 2>/dev/null >"$tmp"; then
      mv -f -- "$tmp" "$cache" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null
    else
      rm -f -- "$tmp" 2>/dev/null
    fi
  fi
  [[ "$status" == "up" ]] && return 0
  return 1
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
    pi) printf '%s/extensions/silver-bullet-five-tool-stack/config.json' \
      "${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}" ;;
    *) printf '%s/.claude.json' "${HOME}" ;;
  esac
}

sb_agentmemory_platform_artifact_present() {
  local project_root="${1:-$PWD}" host="${2:-}" artifact
  host="${host:-$(sb_runtime_host)}"
  artifact="$(sb_agentmemory_platform_artifact_path "$project_root" "$host")"
  [[ -f "$artifact" && ! -L "$artifact" ]] || return 1
  grep -q 'agentmemory' "$artifact" 2>/dev/null
}

sb_agentmemory_usage_ttl_seconds() {
  local config_file="${1:-}" ttl=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r '.recommended_tools.agentmemory.usage_ttl_seconds // "" | tostring' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_ttl_seconds "$ttl" "$_sb_agentmemory_default_ttl_seconds"
}

# The usage stamp; a configured usage_state_file is honoured only inside the state dir.
sb_agentmemory_usage_state_path() {
  local config_file="${1:-}" configured=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    configured="$(jq -r '.recommended_tools.agentmemory.usage_state_file // "" | strings' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_state_file "$configured" agentmemory-usage
}

sb_agentmemory_usage_is_fresh() {
  local config_file="${1:-}"
  sb_rt_stamp_is_fresh "$(sb_agentmemory_usage_state_path "$config_file")" \
    "$(sb_agentmemory_usage_ttl_seconds "$config_file")"
}

sb_agentmemory_record_usage() {
  sb_rt_stamp_write "$(sb_agentmemory_usage_state_path "${1:-}")"
}

sb_agentmemory_clear_usage_state() {
  rm -f -- "$(sb_agentmemory_usage_state_path "${1:-}")" 2>/dev/null || true
}

# When Graphify handles retrieval, agentmemory gate checks infrastructure only.
sb_agentmemory_graphify_synergy_active() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  if ! declare -f sb_graphify_query_is_fresh >/dev/null 2>&1; then
    # shellcheck source=graphify-gate.sh
    source "${_sb_agentmemory_lib_dir}/graphify-gate.sh"
  fi
  sb_graphify_required "$config_file" || return 1
  sb_graphify_query_is_fresh "$config_file"
}

# Status 0 when CMD is one agentmemory retrieval: the CLI's search/recall subcommands or a
# read-only curl of the loopback REST API's retrieval endpoints, as a single simple command
# (a pipe or list could hide a failure; echo agentmemory search is not a retrieval).
sb_agentmemory_command_is_retrieval() {
  local cmd program word seen=0
  local -a words
  cmd="$(sb_opt_in_rtk_unwrap "${1:-}")"
  cmd="$(_sb_opt_in_squash "$cmd")"
  [[ -n "$cmd" ]] && _sb_opt_in_simple_command "$cmd" || return 1
  program="$(_sb_opt_in_program "$cmd" || true)"
  if [[ "$program" == "curl" ]]; then
    _sb_opt_in_agentmemory_curl "$cmd" || return 1
    [[ "$cmd" =~ :3111/agentmemory/(smart-search|search|recall|file-history)([/?\"\'[:space:]]|$) ]] && return 0
    return 1
  fi
  [[ "$program" == "agentmemory" ]] || return 1
  read -r -a words <<<"$cmd"
  for word in "${words[@]}"; do
    if [[ "$seen" == 0 ]]; then
      [[ "${word##*/}" == "agentmemory" ]] && seen=1
      continue
    fi
    case "$word" in
      search | recall | smart-search | file-history | query) return 0 ;;
      -*) continue ;;
      *) return 1 ;;
    esac
  done
  return 1
}

# MCP retrieval: an agentmemory server (exact name, or a namespaced name ending in
# _agentmemory / -agentmemory) and one of its read tools. memory_save is capture, not
# retrieval, and a search tool on any other server is not agentmemory.
sb_agentmemory_mcp_server_matches() {
  [[ "${1:-}" =~ ^([A-Za-z0-9_-]+[_-])?agentmemory$ ]]
}

sb_agentmemory_mcp_tool_is_retrieval() {
  case "${1:-}" in
    memory_smart_search | memory_recall | memory_search | memory_file_history | smart_search | recall | search)
      return 0
      ;;
  esac
  return 1
}

sb_agentmemory_command_is_exempt() {
  ! sb_opt_in_shell_needs_gate agentmemory "${1:-}"
}

# Status 0 when an edit target is the project's memory export or Silver Bullet state
# (normalized first: .agentmemory/../src/app.py is src/app.py).
sb_agentmemory_edit_path_is_exempt() {
  local file_path="${1:-}" config_file="${2:-}" project_root normalized
  [[ -n "$file_path" ]] || return 1
  project_root="$(dirname "${config_file:-$PWD/.silver-bullet.json}")"
  normalized="$(sb_opt_in_normalize_path "$file_path" "$project_root")"
  [[ "$normalized" == */.silver-bullet/* ]] && return 0
  sb_opt_in_path_under "$normalized" "${project_root%/}/$(sb_agentmemory_export_rel_path "$config_file")"
}

sb_agentmemory_block_message_no_cli() {
  local config_file="${1:-}" host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" agentmemory "$host")"
  cat <<EOF
🚫 AGENTMEMORY REQUIRED — CLI not installed (you opted in to agentmemory enforcement).

Silver Bullet mandates agentmemory for session capture and git-backed memory export. Install before substantive work (host: ${host}):

${install_lines}

Start the server: nohup agentmemory > ~/.agentmemory/server.log 2>&1 &

To turn agentmemory enforcement off: bash $(sb_rt_plugin_script scripts/sb-consent.sh) decline agentmemory --project $(printf '%q' "$(dirname "${config_file:-$PWD/x}")")
EOF
}

sb_agentmemory_block_message_no_server() {
  local config_file="${1:-}" url
  url="$(sb_agentmemory_health_url "$config_file")"
  cat <<EOF
⚠️ AGENTMEMORY SERVER DOWN — recall needs the server.

Health check failed: ${url}

Start the memory engine, then recall:
  mkdir -p ~/.agentmemory && nohup agentmemory > ~/.agentmemory/server.log 2>&1 &
EOF
}

sb_agentmemory_block_message_no_mcp() {
  local config_file="${1:-}" host artifact
  host="$(sb_runtime_host)"
  artifact="$(sb_agentmemory_platform_artifact_path "$(dirname "${config_file:-$PWD/x}")" "$host")"
  cat <<EOF
⚠️ AGENTMEMORY MCP NOT WIRED — expected an agentmemory MCP registration for host ${host} in:
  ${artifact}

Run platform connect from the project root (host: ${host}):
$(sb_recommended_tool_platform_install_commands "" agentmemory "$host")
Until then, recall through the REST API (curl smart-search below).
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

When Graphify is not handling retrieval, query agentmemory first, on its own (a call inside a pipe or list is not recorded):
  curl -s -X POST http://localhost:3111/agentmemory/smart-search -H "Content-Type: application/json" -d '{"query":"<task context>"}'

Or invoke agentmemory MCP tools (memory_smart_search, memory_recall). A fresh usage is required every ${ttl}s.

When both agentmemory and Graphify are enabled: save via agentmemory, retrieve via Graphify query.
EOF
}

sb_agentmemory_prompt_reminder_line() {
  local config_file="${1:-}" project_root export_rel ttl
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
        printf '%s' "agentmemory: opted in but install failed — enforcement suspended until upgrade; retry on /sb:update."
      elif ! sb_agentmemory_cli_available; then
        printf '%s' "agentmemory: CLI missing — install @agentmemory/agentmemory; hooks block substantive work until installed."
      elif ! sb_agentmemory_export_exists "$project_root" "$config_file"; then
        printf '%s' "agentmemory: export root missing — mkdir -p ${export_rel}/memory; hooks block until present."
      elif sb_agentmemory_graphify_synergy_active "$config_file"; then
        printf '%s' "agentmemory+Graphify: capture via agentmemory; retrieve via Graphify query (synergy active)."
      elif sb_agentmemory_usage_is_fresh "$config_file"; then
        printf '%s' "agentmemory: fresh usage recorded — substantive work allowed until TTL expires."
      elif ! sb_agentmemory_server_healthy "$config_file"; then
        printf '%s' "agentmemory: USAGE REQUIRED and the server is down — start it (\`nohup agentmemory > ~/.agentmemory/server.log 2>&1 &\`), then recall before edits."
      else
        ttl="$(sb_agentmemory_usage_ttl_seconds "$config_file")"
        printf '%s' "agentmemory: USAGE REQUIRED — recall via MCP or smart-search before edits (TTL ${ttl}s), or enable Graphify for retrieval."
      fi
      ;;
  esac
}

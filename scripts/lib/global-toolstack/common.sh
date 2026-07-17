# shellcheck shell=bash
# Global toolstack helpers — reads ~/.cursor/toolstack.json; defers to SB when bridge active.

_TS_DEFAULT_CONFIG="${HOME}/.cursor/toolstack.json"
_TS_DEFAULT_STATE="${HOME}/.cursor/state/toolstack"
_TS_DEFAULT_GRAPH_PATH="graphify-out/graph.json"
_TS_DEFAULT_QUERY_TTL=1800
_TS_DEFAULT_QUERY_BUDGET=2000
_TS_DEFAULT_USAGE_TTL=1800
_TS_DEFAULT_HEALTH_URL="http://localhost:3111/agentmemory/health"
_TS_DEFAULT_EXPORT_ROOT=".agentmemory"
_TS_SB_GRAPHIFY_STATE="${HOME}/.silver-bullet/graphify-query"
_TS_SB_AGENTMEMORY_STATE="${HOME}/.silver-bullet/agentmemory-usage"

ts_expand_path() {
  local p="${1:-}"
  p="${p/#\~/$HOME}"
  printf '%s' "$p"
}

ts_config_path() {
  printf '%s' "${TS_CONFIG:-$_TS_DEFAULT_CONFIG}"
}

ts_config() {
  local cfg
  cfg="$(ts_config_path)"
  [[ -f "$cfg" ]] || return 1
  printf '%s' "$cfg"
}

ts_jq() {
  local filter="${1:-}"
  local cfg
  cfg="$(ts_config)" || return 1
  shift
  if [[ $# -gt 0 ]]; then
    jq -r --argjson def "$1" "$filter" "$cfg" 2>/dev/null
  else
    jq -r "$filter" "$cfg" 2>/dev/null
  fi
}

ts_sb_jq() {
  local config_file="${1:-}" filter="${2:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  shift 2
  if [[ $# -gt 0 ]]; then
    jq -r --argjson def "$1" "$filter" "$config_file" 2>/dev/null
  else
    jq -r "$filter" "$config_file" 2>/dev/null
  fi
}

ts_find_sb_config() {
  local start="${1:-$PWD}" dir
  dir="$(cd "$start" 2>/dev/null && pwd -P)" || dir="$start"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.silver-bullet.json" && -f "$dir/silver-bullet.md" ]]; then
      printf '%s' "$dir/.silver-bullet.json"
      return 0
    fi
    if [[ -d "$dir/.git" ]]; then
      break
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

ts_sb_defer_to_bridge() {
  local cfg project_root project_id worktree_id session_id hb_path
  cfg="$(ts_find_sb_config 2>/dev/null || true)"
  [[ -n "$cfg" ]] || return 1
  project_root="$(dirname "$cfg")"
  # Heartbeat schema-v1: defer only on valid, unexpired SB bridge heartbeat.
  if [[ -f "${project_root}/scripts/lib/recommended-tools/heartbeat.sh" ]]; then
    # shellcheck source=/dev/null
    source "${project_root}/scripts/lib/recommended-tools/heartbeat.sh" 2>/dev/null || true
    if declare -f rt_heartbeat_path >/dev/null 2>&1; then
      project_id="$(rt_project_id 2>/dev/null || true)"
      worktree_id="$(rt_worktree_id "$project_root" 2>/dev/null || true)"
      session_id="$(rt_current_session_id 2>/dev/null || true)"
      hb_path="$(rt_heartbeat_path "$project_id" "$worktree_id" "$session_id" 2>/dev/null || true)"
      if [[ -n "$hb_path" ]] && rt_heartbeat_is_valid "$hb_path" "cursor" "$project_root" "$project_root"; then
        return 0
      fi
    fi
  fi
  return 1
}

ts_enforcement_active() {
  local mode
  mode="$(ts_jq '.enforcement // "off"')" || return 1
  [[ "$mode" == "always" ]]
}

ts_tool_required() {
  local tool="${1:-}"
  [[ -n "$tool" ]] || return 1
  ts_enforcement_active || return 1
  [[ "$(ts_jq ".tools.${tool}.required // false")" == "true" ]]
}

ts_profile_name() {
  ts_jq '.profile // .tools.leanctx.profile // "five_tool_routed"' || printf '%s' "five_tool_routed"
}

ts_route_owner() {
  local route="${1:-}"
  local owner
  owner="$(ts_jq ".routes.${route} // .optimization_profiles.five_tool_routed.routes.${route} // \"\"")" || true
  [[ -n "$owner" ]] || return 1
  printf '%s' "$owner"
}

ts_state_root() {
  local root
  root="$(ts_jq '.state_dir // ""')"
  [[ -n "$root" ]] || root="$_TS_DEFAULT_STATE"
  ts_expand_path "$root"
}

ts_git_root() {
  local start="${1:-$PWD}" dir
  dir="$(cd "$start" 2>/dev/null && pwd -P)" || dir="$start"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

ts_project_hash() {
  local root="${1:-}"
  [[ -n "$root" ]] || return 1
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$root" | shasum -a 256 | awk '{print substr($1,1,16)}'
  else
    printf '%s' "$root" | sha256sum | awk '{print substr($1,1,16)}'
  fi
}

ts_project_state_dir() {
  local root hash base
  root="$(ts_git_root 2>/dev/null || true)"
  [[ -n "$root" ]] || { ts_state_root; return; }
  hash="$(ts_project_hash "$root")"
  base="$(ts_state_root)"
  printf '%s/%s' "$base" "$hash"
}

ts_emit_deny() {
  local reason="${1:-blocked}" event="${2:-PreToolUse}"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if [[ "$event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

ts_tool_name() {
  local input="${1:-}"
  printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null
}

ts_tool_file_path() {
  local input="${1:-}"
  printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null
}

ts_tool_command_string() {
  local input="${1:-}"
  printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null
}

ts_mcp_tool_name() {
  local input="${1:-}"
  printf '%s' "$input" | jq -r '.tool_input.toolName // .tool_input.name // ""' 2>/dev/null
}

ts_mcp_server_name() {
  local input="${1:-}"
  printf '%s' "$input" | jq -r '.tool_input.server // .tool_input.serverName // ""' 2>/dev/null
}

ts_is_substantive_shell() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  if printf '%s' "$cmd" | grep -qE '\bgit commit\b|\bgh pr create\b|\bgh release create\b'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\bsed\b[^$]*-i|\bperl\b[^$]*-i)'; then
    return 0
  fi
  return 1
}

# --- effective readers (SB config preferred when present) ---

ts_effective_graph_path() {
  local sb_cfg rel
  sb_cfg="$(ts_find_sb_config 2>/dev/null || true)"
  if [[ -n "$sb_cfg" ]]; then
    rel="$(ts_sb_jq "$sb_cfg" '.recommended_tools.graphify.graph_path // .graphify.graph_path // ""')" || true
    [[ -n "$rel" ]] && { printf '%s' "$rel"; return 0; }
  fi
  ts_graphify_graph_rel_path
}

ts_effective_query_ttl() {
  local sb_cfg ttl
  sb_cfg="$(ts_find_sb_config 2>/dev/null || true)"
  if [[ -n "$sb_cfg" ]]; then
    ttl="$(ts_sb_jq "$sb_cfg" '.recommended_tools.graphify.query_ttl_seconds // 0')" || ttl="0"
    if [[ "$ttl" =~ ^[0-9]+$ ]] && [[ "$ttl" -ge 60 ]]; then
      printf '%s' "$ttl"
      return 0
    fi
  fi
  ts_graphify_query_ttl_seconds
}

ts_effective_query_budget() {
  local sb_cfg budget
  sb_cfg="$(ts_find_sb_config 2>/dev/null || true)"
  if [[ -n "$sb_cfg" ]]; then
    budget="$(ts_sb_jq "$sb_cfg" '.recommended_tools.graphify.query_budget // 0')" || budget="0"
    if [[ "$budget" =~ ^[0-9]+$ ]] && [[ "$budget" -gt 0 ]]; then
      printf '%s' "$budget"
      return 0
    fi
  fi
  ts_graphify_query_budget
}

ts_effective_export_root() {
  local sb_cfg rel
  sb_cfg="$(ts_find_sb_config 2>/dev/null || true)"
  if [[ -n "$sb_cfg" ]]; then
    rel="$(ts_sb_jq "$sb_cfg" '.recommended_tools.agentmemory.export_root // ""')" || true
    [[ -n "$rel" ]] && { printf '%s' "$rel"; return 0; }
  fi
  ts_agentmemory_export_rel_path
}

ts_effective_usage_ttl() {
  local sb_cfg ttl
  sb_cfg="$(ts_find_sb_config 2>/dev/null || true)"
  if [[ -n "$sb_cfg" ]]; then
    ttl="$(ts_sb_jq "$sb_cfg" '.recommended_tools.agentmemory.usage_ttl_seconds // 0')" || ttl="0"
    if [[ "$ttl" =~ ^[0-9]+$ ]] && [[ "$ttl" -ge 60 ]]; then
      printf '%s' "$ttl"
      return 0
    fi
  fi
  ts_agentmemory_usage_ttl_seconds
}

ts_effective_health_url() {
  local sb_cfg url
  sb_cfg="$(ts_find_sb_config 2>/dev/null || true)"
  if [[ -n "$sb_cfg" ]]; then
    url="$(ts_sb_jq "$sb_cfg" '.recommended_tools.agentmemory.health_url // ""')" || true
    [[ -n "$url" ]] && { printf '%s' "$url"; return 0; }
  fi
  ts_agentmemory_health_url
}

# --- graphify ---

ts_graphify_graph_rel_path() {
  local rel
  rel="$(ts_jq '.tools.graphify.graph_path // ""')" || true
  [[ -n "$rel" ]] || rel="$_TS_DEFAULT_GRAPH_PATH"
  printf '%s' "$rel"
}

ts_graphify_query_budget() {
  local budget
  budget="$(ts_jq '.tools.graphify.query_budget // 0')" || budget="0"
  if ! [[ "$budget" =~ ^[0-9]+$ ]] || [[ "$budget" -lt 1 ]]; then
    budget="$_TS_DEFAULT_QUERY_BUDGET"
  fi
  printf '%s' "$budget"
}

ts_graphify_query_ttl_seconds() {
  local ttl
  ttl="$(ts_jq '.tools.graphify.query_ttl_seconds // 0')" || ttl="0"
  if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 60 ]]; then
    ttl="$_TS_DEFAULT_QUERY_TTL"
  fi
  printf '%s' "$ttl"
}

ts_graphify_cli_available() {
  command -v graphify >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/graphify" ]]
}

ts_graphify_abs_graph_path() {
  local root="${1:-$PWD}" rel
  rel="$(ts_effective_graph_path)"
  if [[ "$rel" == /* ]]; then
    printf '%s' "$rel"
  else
    printf '%s/%s' "${root%/}" "$rel"
  fi
}

ts_graphify_index_exists() {
  local root="${1:-$PWD}" graph_path
  graph_path="$(ts_graphify_abs_graph_path "$root")"
  [[ -f "$graph_path" && ! -L "$graph_path" ]]
}

ts_graphify_query_state_path() {
  if ts_find_sb_config >/dev/null 2>&1; then
    printf '%s' "$_TS_SB_GRAPHIFY_STATE"
    return 0
  fi
  printf '%s/graphify-query' "$(ts_project_state_dir)"
}

ts_graphify_query_epoch() {
  local state_path="${1:-}"
  [[ -f "$state_path" && ! -L "$state_path" ]] || return 1
  local epoch
  epoch="$(sed -n '1p' "$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$epoch"
}

ts_graphify_query_is_fresh() {
  local state_path epoch now ttl age
  state_path="$(ts_graphify_query_state_path)"
  epoch="$(ts_graphify_query_epoch "$state_path" 2>/dev/null || true)"
  [[ -n "$epoch" ]] || return 1
  now="$(date +%s)"
  ttl="$(ts_effective_query_ttl)"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

ts_graphify_record_query() {
  local state_path
  state_path="$(ts_graphify_query_state_path)"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  date +%s >"$state_path" 2>/dev/null || return 1
}

ts_graphify_command_is_retrieval() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)' || return 1
  printf '%s' "$cmd" | grep -qE '\b(query|explain|affected|path|diagnose|dfs)\b'
}

ts_graphify_command_is_index_build() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)' || return 1
  printf '%s' "$cmd" | grep -qE '\b(update|extract|watch)\b'
}

ts_graphify_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if ts_graphify_command_is_retrieval "$cmd" || ts_graphify_command_is_index_build "$cmd"; then return 0; fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)'; then return 0; fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(cat|head|tail|less|more|wc|ls|pwd|which|type|file|stat|jq|git (status|diff|log|show|branch|rev-parse)|command -v|echo|printf|true|false)(\s|$)'; then return 0; fi
  return 1
}

ts_graphify_edit_path_is_exempt() {
  local file_path="${1:-}"
  [[ -n "$file_path" ]] || return 1
  local graph_rel graph_dir
  graph_rel="$(ts_effective_graph_path)"
  graph_dir="$(dirname "$graph_rel")"
  case "$file_path" in
    */graphify-out/*|graphify-out/*|*/"$graph_dir"/*|"$graph_dir"/*|*/.silver-bullet/*|.silver-bullet/*) return 0 ;;
  esac
  return 1
}

ts_graphify_bootstrap_enabled() {
  [[ "$(ts_jq '.worktree.bootstrap_graphify // false')" == "true" ]]
}

ts_graphify_block_message_stale_query() {
  local graph_rel ttl budget
  graph_rel="$(ts_effective_graph_path)"
  ttl="$(ts_effective_query_ttl)"
  budget="$(ts_effective_query_budget)"
  cat <<EOF
🚫 GRAPHIFY QUERY REQUIRED — run retrieval before substantive work.

  graphify query "<task, file paths, hook names, or feature context>" --graph ${graph_rel} --budget ${budget}

A fresh query is required every ${ttl}s. Native search is not an acceptable substitute.
EOF
}

# --- agentmemory ---

ts_agentmemory_health_url() {
  local url
  url="$(ts_jq '.tools.agentmemory.health_url // ""')" || true
  [[ -n "$url" ]] || url="$_TS_DEFAULT_HEALTH_URL"
  printf '%s' "$url"
}

ts_agentmemory_export_rel_path() {
  local rel
  rel="$(ts_jq '.tools.agentmemory.export_root // .tools.agentmemory.export_dir // ""')" || true
  [[ -n "$rel" ]] || rel="$_TS_DEFAULT_EXPORT_ROOT"
  printf '%s' "$rel"
}

ts_agentmemory_abs_export_path() {
  local root="${1:-$PWD}" rel
  rel="$(ts_effective_export_root)"
  case "$rel" in *..*) return 1 ;; esac
  if [[ "$rel" == /* ]]; then printf '%s' "$rel"; else printf '%s/%s' "${root%/}" "$rel"; fi
}

ts_agentmemory_export_exists() {
  local root="${1:-$PWD}" export_path
  export_path="$(ts_agentmemory_abs_export_path "$root" 2>/dev/null || true)"
  [[ -n "$export_path" && -d "$export_path" && ! -L "$export_path" ]]
}

ts_agentmemory_scaffold_export() {
  local root="${1:-$PWD}" export_path
  export_path="$(ts_agentmemory_abs_export_path "$root" 2>/dev/null || true)"
  [[ -n "$export_path" ]] || return 1
  mkdir -p "${export_path}/memory" "${export_path}/snapshots" 2>/dev/null || return 1
}

ts_agentmemory_cli_available() { command -v agentmemory >/dev/null 2>&1; }

ts_agentmemory_server_healthy() {
  local url
  url="$(ts_effective_health_url)"
  if command -v curl >/dev/null 2>&1 && curl -sf --max-time 3 "$url" >/dev/null 2>&1; then return 0; fi
  if command -v agentmemory >/dev/null 2>&1; then
    agentmemory status 2>/dev/null | grep -qE 'Connected|Health:[[:space:]]+healthy' && return 0
  fi
  return 1
}

ts_agentmemory_mcp_wired() {
  local mcp="${HOME}/.cursor/mcp.json"
  [[ -f "$mcp" && ! -L "$mcp" ]] && grep -q 'agentmemory' "$mcp" 2>/dev/null
}

ts_agentmemory_usage_ttl_seconds() {
  local ttl
  ttl="$(ts_jq '.tools.agentmemory.usage_ttl_seconds // 0')" || ttl="0"
  if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 60 ]]; then ttl="$_TS_DEFAULT_USAGE_TTL"; fi
  printf '%s' "$ttl"
}

ts_agentmemory_usage_state_path() {
  if ts_find_sb_config >/dev/null 2>&1; then
    printf '%s' "$_TS_SB_AGENTMEMORY_STATE"
    return 0
  fi
  printf '%s/agentmemory-usage' "$(ts_project_state_dir)"
}

ts_agentmemory_usage_epoch() {
  local state_path="${1:-}"
  [[ -f "$state_path" && ! -L "$state_path" ]] || return 1
  local epoch
  epoch="$(sed -n '1p' "$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$epoch"
}

ts_agentmemory_usage_is_fresh() {
  local state_path epoch now ttl age
  state_path="$(ts_agentmemory_usage_state_path)"
  epoch="$(ts_agentmemory_usage_epoch "$state_path" 2>/dev/null || true)"
  [[ -n "$epoch" ]] || return 1
  now="$(date +%s)"
  ttl="$(ts_effective_usage_ttl)"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

ts_agentmemory_record_usage() {
  local state_path
  state_path="$(ts_agentmemory_usage_state_path)"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  date +%s >"$state_path" 2>/dev/null || return 1
}

ts_agentmemory_graphify_synergy_active() {
  ts_tool_required graphify || return 1
  ts_graphify_query_is_fresh
}

ts_agentmemory_command_is_retrieval() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  if printf '%s' "$cmd" | grep -qE 'localhost:3111/agentmemory/(smart-search|search|recall|file-history)'; then return 0; fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])agentmemory([[:space:]]|$)'; then
    printf '%s' "$cmd" | grep -qE '\b(search|recall|smart-search|file-history|query)\b' && return 0
  fi
  printf '%s' "$cmd" | grep -qE '@agentmemory/mcp' && return 0
  return 1
}

ts_agentmemory_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if ts_agentmemory_command_is_retrieval "$cmd"; then return 0; fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])agentmemory([[:space:]]|$)'; then return 0; fi
  if printf '%s' "$cmd" | grep -qE 'localhost:3111/agentmemory'; then return 0; fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(curl|mkdir|chmod|cat|head|tail|grep|jq|npm install|nohup|kill|lsof|which|command -v|echo|printf|true|false|launchctl)(\s|$)'; then return 0; fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)'; then return 0; fi
  return 1
}

ts_agentmemory_edit_path_is_exempt() {
  local file_path="${1:-}" export_rel
  [[ -n "$file_path" ]] || return 1
  export_rel="$(ts_effective_export_root)"
  case "$file_path" in
    */.agentmemory/*|.agentmemory/*|*/"${export_rel}"/*|"${export_rel}"/*) return 0 ;;
  esac
  return 1
}

ts_agentmemory_mcp_is_save() {
  local input="${1:-}" server tool
  server="$(ts_mcp_server_name "$input")"
  tool="$(ts_mcp_tool_name "$input")"
  case "$server" in *agentmemory*|user-agentmemory) ;; *) return 1 ;; esac
  case "$tool" in memory_save|save_memory|agentmemory_save) return 0 ;; esac
  return 1
}

# --- shell compression ---

ts_shell_compression_primary() {
  local primary
  primary="$(ts_jq '.shell_compression.primary // .tools.shell_compression.primary // "rtk"')" || primary="rtk"
  printf '%s' "$primary"
}

ts_shell_compression_fallback() {
  local fb
  fb="$(ts_jq '.shell_compression.fallback // .tools.shell_compression.fallback // "leanctx"')" || fb="leanctx"
  printf '%s' "$fb"
}

# --- token compression state ---

ts_token_usage_state_path() {
  local tool="${1:-rtk}"
  printf '%s/%s-usage' "$(ts_project_state_dir)" "$tool"
}

ts_token_usage_is_fresh() {
  local tool="${1:-rtk}" state_path epoch now ttl age
  ttl="$(ts_jq '.tools.'"${tool}"'.usage_ttl_seconds // 1800')" || ttl="1800"
  state_path="$(ts_token_usage_state_path "$tool")"
  [[ -f "$state_path" && ! -L "$state_path" ]] || return 1
  epoch="$(sed -n '1p' "$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s)"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

ts_rtk_cli_available() {
  command -v rtk >/dev/null 2>&1
}

ts_rtk_hook_present() {
  local hooks="${HOME}/.cursor/hooks.json"
  [[ -f "$hooks" ]] && grep -q 'rtk hook cursor' "$hooks" 2>/dev/null
}

ts_context_mode_cli_available() {
  command -v context-mode >/dev/null 2>&1
}

ts_context_mode_mcp_wired() {
  local mcp="${HOME}/.cursor/mcp.json"
  [[ -f "$mcp" && ! -L "$mcp" ]] && grep -q '"context-mode"' "$mcp" 2>/dev/null
}

ts_leanctx_mcp_wired() {
  local mcp="${HOME}/.cursor/mcp.json"
  [[ -f "$mcp" && ! -L "$mcp" ]] && grep -q '"leanctx"' "$mcp" 2>/dev/null
}

ts_sb_plugin_cache() {
  local cache="${HOME}/.cursor/plugins/cache/alo-labs/silver-bullet/current"
  [[ -d "$cache/hooks/lib" ]] && printf '%s' "$cache"
}


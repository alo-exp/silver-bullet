# shellcheck shell=bash
# Graphify retrieval gate — CLI/index/query state helpers.
# Enforcement is active only when recommended_tools.graphify.enabled_by_user is true.
# Sourced by: graphify-gate.sh, record-graphify-query.sh, prompt-reminder.sh, sb-diagnostics.sh

_sb_graphify_default_ttl_seconds=1800
_sb_graphify_default_graph_path="graphify-out/graph.json"

[[ -f "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh" ]] && \
  # shellcheck source=recommended-tools.sh
  source "$(dirname "${BASH_SOURCE[0]}")/recommended-tools.sh"

sb_graphify_graph_rel_path() {
  local config_file="${1:-}"
  local rel="${_sb_graphify_default_graph_path}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    rel="$(jq -r --arg def "$_sb_graphify_default_graph_path" \
      '.recommended_tools.graphify.graph_path // .graphify.graph_path // $def' "$config_file" 2>/dev/null || echo "$_sb_graphify_default_graph_path")"
  fi
  printf '%s' "$rel"
}

sb_graphify_query_ttl_seconds() {
  local config_file="${1:-}"
  local ttl="${_sb_graphify_default_ttl_seconds}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r --argjson def "$_sb_graphify_default_ttl_seconds" \
      '.recommended_tools.graphify.query_ttl_seconds // .graphify.query_ttl_seconds // $def' "$config_file" 2>/dev/null || echo "$_sb_graphify_default_ttl_seconds")"
  fi
  if ! [[ "$ttl" =~ ^[0-9]+$ ]] || [[ "$ttl" -lt 60 ]]; then
    ttl="${_sb_graphify_default_ttl_seconds}"
  fi
  printf '%s' "$ttl"
}

sb_graphify_cli_path() {
  if command -v graphify >/dev/null 2>&1; then
    command -v graphify
    return 0
  fi
  if [[ -x "${HOME}/.local/bin/graphify" ]]; then
    printf '%s' "${HOME}/.local/bin/graphify"
    return 0
  fi
  return 1
}

sb_graphify_cli_available() {
  sb_graphify_cli_path >/dev/null 2>&1
}

sb_graphify_abs_graph_path() {
  local project_root="${1:-$PWD}"
  local config_file="${2:-}"
  local rel
  rel="$(sb_graphify_graph_rel_path "$config_file")"
  if [[ "$rel" == /* ]]; then
    printf '%s' "$rel"
  else
    printf '%s/%s' "${project_root%/}" "$rel"
  fi
}

sb_graphify_index_exists() {
  local project_root="${1:-$PWD}"
  local config_file="${2:-}"
  local graph_path
  graph_path="$(sb_graphify_abs_graph_path "$project_root" "$config_file")"
  [[ -f "$graph_path" && ! -L "$graph_path" ]]
}

sb_graphify_query_state_path() {
  local config_file="${1:-}"
  local state_path=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    state_path="$(jq -r '.recommended_tools.graphify.query_state_file // .graphify.query_state_file // ""' "$config_file" 2>/dev/null || true)"
    state_path="${state_path/#\~/$HOME}"
  fi
  if [[ -z "$state_path" ]]; then
    state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/graphify-query"
  fi
  if declare -f sb_runtime_path_is_state_scoped >/dev/null 2>&1; then
    if ! sb_runtime_path_is_state_scoped "$state_path"; then
      state_path="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}/graphify-query"
    fi
  fi
  printf '%s' "$state_path"
}

sb_graphify_query_epoch() {
  local state_path="${1:-}"
  [[ -f "$state_path" && ! -L "$state_path" ]] || return 1
  local epoch
  epoch="$(sed -n '1p' "$state_path" 2>/dev/null || true)"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$epoch"
}

sb_graphify_query_is_fresh() {
  local config_file="${1:-}"
  local state_path epoch now ttl age
  state_path="$(sb_graphify_query_state_path "$config_file")"
  epoch="$(sb_graphify_query_epoch "$state_path" 2>/dev/null || true)"
  [[ -n "$epoch" ]] || return 1
  now="$(date +%s)"
  ttl="$(sb_graphify_query_ttl_seconds "$config_file")"
  age=$((now - epoch))
  [[ "$age" -ge 0 && "$age" -le "$ttl" ]]
}

sb_graphify_record_query() {
  local config_file="${1:-}"
  local state_path
  state_path="$(sb_graphify_query_state_path "$config_file")"
  mkdir -p "$(dirname "$state_path")" 2>/dev/null || true
  if declare -f sb_guard_nofollow >/dev/null 2>&1; then
    sb_guard_nofollow "$state_path"
  fi
  date +%s >"$state_path" 2>/dev/null || return 1
}

sb_graphify_clear_query_state() {
  local config_file="${1:-}"
  local state_path
  state_path="$(sb_graphify_query_state_path "$config_file")"
  rm -f -- "$state_path" 2>/dev/null || true
}

sb_graphify_command_is_retrieval() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)' || return 1
  printf '%s' "$cmd" | grep -qE '\b(query|explain|affected|path|diagnose|dfs)\b'
}

sb_graphify_command_is_index_build() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 1
  printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)' || return 1
  printf '%s' "$cmd" | grep -qE '\b(update|extract|watch)\b'
}

sb_graphify_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if sb_graphify_command_is_retrieval "$cmd" || sb_graphify_command_is_index_build "$cmd"; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(cat|head|tail|less|more|wc|ls|pwd|which|type|file|stat|jq|git (status|diff|log|show|branch|rev-parse)|command -v|echo|printf|true|false)(\s|$)'; then
    return 0
  fi
  return 1
}

sb_graphify_edit_path_is_exempt() {
  local file_path="${1:-}"
  local config_file="${2:-}"
  [[ -n "$file_path" ]] || return 1
  local graph_rel graph_dir
  graph_rel="$(sb_graphify_graph_rel_path "$config_file")"
  graph_dir="$(dirname "$graph_rel")"
  case "$file_path" in
    */graphify-out/*|graphify-out/*|*/"$graph_dir"/*|"$graph_dir"/*)
      return 0
      ;;
  esac
  if [[ "$file_path" == *"/.silver-bullet/"* ]]; then
    return 0
  fi
  return 1
}

sb_graphify_block_message_no_cli() {
  local config_file="${1:-}"
  local host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "$config_file" graphify "$host" 2>/dev/null || true)"
  if [[ -z "$install_lines" ]]; then
    install_lines=$'uv tool install graphifyy\npipx install graphifyy'
    local pre post
    pre="$(sb_recommended_tool_platform_pre_index_commands "$config_file" graphify "$host" 2>/dev/null || true)"
    post="$(sb_recommended_tool_platform_post_index_commands "$config_file" graphify "$host" 2>/dev/null || true)"
    [[ -n "$pre" ]] && install_lines="${install_lines}"$'\n'"${pre}"
    install_lines="${install_lines}"$'\n'"graphify update . --no-cluster"
    [[ -n "$post" ]] && install_lines="${install_lines}"$'\n'"${post}"
  fi
  cat <<EOF
🚫 GRAPHIFY REQUIRED — CLI not installed (user opted in).

Silver Bullet mandates Graphify for tier-1 project-memory retrieval in this project. Install before substantive work (host: ${host}):

${install_lines}

Then run: graphify update . --no-cluster

To disable enforcement, set recommended_tools.graphify.enabled_by_user to false in .silver-bullet.json.
EOF
}

sb_graphify_block_message_no_index() {
  local graph_path="${1:-graphify-out/graph.json}"
  cat <<EOF
🚫 GRAPHIFY INDEX MISSING — build the graph before substantive work.

Run from the project root:

  graphify update . --no-cluster

Expected index: ${graph_path}

Hooks block edits and delivery commands until the index exists and a fresh Graphify query is recorded.
EOF
}

sb_graphify_block_message_stale_query() {
  local graph_path="${1:-graphify-out/graph.json}"
  local ttl="${2:-1800}"
  cat <<EOF
🚫 GRAPHIFY QUERY REQUIRED — run retrieval before substantive work.

From the project root, query with concrete file/feature context:

  graphify query "<task, file paths, hook names, or feature context>" --graph ${graph_path} --budget 2000

Inspect returned nodes before editing. A fresh query is required every ${ttl}s (or after branch change). Native search is not an acceptable substitute when Graphify is enabled.
EOF
}

sb_graphify_prompt_reminder_line() {
  local config_file="${1:-}"
  local project_root graph_rel ttl
  project_root="$(dirname "$config_file")"
  graph_rel="$(sb_graphify_graph_rel_path "$config_file")"

  case "$(sb_recommended_tool_consent "$config_file" "graphify")" in
    pending)
      printf '%s' "Graphify: consent pending — ask user to opt in or out (see session-start context)."
      ;;
    disabled)
      printf '%s' "Graphify: opted out — enforcements disabled; use direct docs reads."
      ;;
    enabled)
      if sb_recommended_tool_enforcement_suspended "$config_file" "graphify"; then
        printf '%s' "Graphify: opted in but install failed — enforcement suspended until upgrade; retry on /silver:update."
      elif ! sb_graphify_cli_available; then
        printf '%s' "Graphify: CLI missing — install graphifyy; hooks block substantive work until installed."
      elif ! sb_graphify_index_exists "$project_root" "$config_file"; then
        printf '%s' "Graphify: index missing — run \`graphify update . --no-cluster\` (expected ${graph_rel}). Hooks block substantive edits until built."
      elif sb_graphify_query_is_fresh "$config_file"; then
        printf '%s' "Graphify: fresh query recorded — substantive work allowed until TTL expires."
      else
        ttl="$(sb_graphify_query_ttl_seconds "$config_file")"
        printf '%s' "Graphify: QUERY REQUIRED — run \`graphify query \"<concrete task context>\" --graph ${graph_rel} --budget 2000\` before edits (TTL ${ttl}s). Native search is not a substitute."
      fi
      ;;
  esac
}

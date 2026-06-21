# shellcheck shell=bash
# Graphify mandatory retrieval gate — single source of truth for CLI/index/query state.
# Sourced by: graphify-gate.sh, record-graphify-query.sh, prompt-reminder.sh, sb-diagnostics.sh

_sb_graphify_default_ttl_seconds=1800
_sb_graphify_default_graph_path="graphify-out/graph.json"

# Resolve graphify.required from project config (default: true when key absent).
sb_graphify_required() {
  local config_file="${1:-}"
  [[ -n "$config_file" && -f "$config_file" ]] || return 1
  if jq -e '.graphify.required == false' "$config_file" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

sb_graphify_graph_rel_path() {
  local config_file="${1:-}"
  local rel="${_sb_graphify_default_graph_path}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    rel="$(jq -r --arg def "$_sb_graphify_default_graph_path" '.graphify.graph_path // $def' "$config_file" 2>/dev/null || echo "$_sb_graphify_default_graph_path")"
  fi
  printf '%s' "$rel"
}

sb_graphify_query_ttl_seconds() {
  local config_file="${1:-}"
  local ttl="${_sb_graphify_default_ttl_seconds}"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r --argjson def "$_sb_graphify_default_ttl_seconds" '.graphify.query_ttl_seconds // $def' "$config_file" 2>/dev/null || echo "$_sb_graphify_default_ttl_seconds")"
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
    state_path="$(jq -r '.graphify.query_state_file // ""' "$config_file" 2>/dev/null || true)"
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

# Detect graphify retrieval commands in a shell string.
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

# Read-only or graphify maintenance commands that do not require a prior query.
sb_graphify_command_is_exempt() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || return 0
  if sb_graphify_command_is_retrieval "$cmd" || sb_graphify_command_is_index_build "$cmd"; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[[:space:]/])(graphify|graphifyy)([[:space:]]|$)'; then
    return 0
  fi
  # Common read-only discovery — do not require graphify query first.
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
  cat <<'EOF'
⚠️ GRAPHIFY REQUIRED — CLI not installed.

Silver Bullet mandates Graphify for tier-1 project-memory retrieval. Install before substantive work:

  uv tool install graphifyy
  # or: python3 -m pip install graphifyy

Then run: graphify update . --no-cluster

Docs-read fallback is allowed only when Graphify is literally unavailable — do not substitute native search when Graphify can be installed.
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

Inspect returned nodes before editing. A fresh query is required every ${ttl}s (or after branch change). Native search is not an acceptable substitute when Graphify is available.
EOF
}

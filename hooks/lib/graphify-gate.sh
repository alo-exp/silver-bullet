# shellcheck shell=bash
# Graphify retrieval gate — CLI/index/query state helpers.
# Enforcement is active only with the user's consent (see user-consent.sh) in a project
# whose .silver-bullet.json does not turn Graphify off.
# Sourced by: graphify-gate.sh, record-graphify-query.sh, record-recommended-mcp.sh,
# prompt-reminder.sh, session-start, sb-diagnostics.sh

_sb_graphify_default_ttl_seconds=1800
_sb_graphify_default_graph_path="graphify-out/graph.json"
_sb_graphify_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=recommended-tools.sh
source "${_sb_graphify_lib_dir}/recommended-tools.sh"
# shellcheck source=opt-in-gate.sh
source "${_sb_graphify_lib_dir}/opt-in-gate.sh"

# Project-relative path to graph.json. The config value is repository data: it must be a
# relative path of plain characters with no '.' or '..' component, else the default is used.
sb_graphify_graph_rel_path() {
  local config_file="${1:-}" rel=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    rel="$(jq -r '.recommended_tools.graphify.graph_path // .graphify.graph_path // "" | strings' \
      "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_safe_rel_path "$rel" "$_sb_graphify_default_graph_path"
}

sb_graphify_query_ttl_seconds() {
  local config_file="${1:-}" ttl=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    ttl="$(jq -r '.recommended_tools.graphify.query_ttl_seconds // .graphify.query_ttl_seconds // ""
      | tostring' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_ttl_seconds "$ttl" "$_sb_graphify_default_ttl_seconds"
}

sb_graphify_cli_path() {
  local global_graphify_command=""
  global_graphify_command="$(sb_global_tool_command graphify 2>/dev/null || true)"
  if [[ -n "$global_graphify_command" && "$(basename "$global_graphify_command")" == "graphify" ]]; then
    if [[ "$global_graphify_command" == */* ]]; then
      [[ -x "$global_graphify_command" ]] || return 1
      printf '%s' "$global_graphify_command"
      return 0
    fi
    command -v "$global_graphify_command"
    return $?
  fi
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
  local project_root="${1:-$PWD}" config_file="${2:-}"
  printf '%s/%s' "${project_root%/}" "$(sb_graphify_graph_rel_path "$config_file")"
}

sb_graphify_index_exists() {
  local project_root="${1:-$PWD}" config_file="${2:-}" graph_path
  graph_path="$(sb_graphify_abs_graph_path "$project_root" "$config_file")"
  [[ -f "$graph_path" && ! -L "$graph_path" ]]
}

# The query stamp. A configured query_state_file is repository data: it is honoured only
# inside the runtime state dir (sb_rt_state_file), so it can never name a user file.
sb_graphify_query_state_path() {
  local config_file="${1:-}" configured=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    configured="$(jq -r '.recommended_tools.graphify.query_state_file // .graphify.query_state_file // ""
      | strings' "$config_file" 2>/dev/null || true)"
  fi
  sb_rt_state_file "$configured" graphify-query
}

sb_graphify_query_is_fresh() {
  local config_file="${1:-}"
  sb_rt_stamp_is_fresh "$(sb_graphify_query_state_path "$config_file")" \
    "$(sb_graphify_query_ttl_seconds "$config_file")"
}

sb_graphify_record_query() {
  sb_rt_stamp_write "$(sb_graphify_query_state_path "${1:-}")"
}

sb_graphify_clear_query_state() {
  rm -f -- "$(sb_graphify_query_state_path "${1:-}")" 2>/dev/null || true
}

# Status 0 when CMD is one Graphify retrieval: a single simple command whose program is
# graphify (after an optional RTK prefix and NAME=value assignments) and whose subcommand
# is query, explain, path or affected. An optional trailing 2>/dev/null is allowed. Words
# that merely appear in another program's arguments (echo graphify query) never count, and
# a pipe or list (| head, || true, ;) could hide a failure, so it does not count either.
sb_graphify_command_is_retrieval() {
  local cmd program
  local -a words
  cmd="$(sb_opt_in_rtk_unwrap "${1:-}")"
  cmd="$(_sb_opt_in_squash "$cmd")"
  cmd="${cmd% 2>/dev/null}"
  [[ -n "$cmd" ]] && _sb_opt_in_simple_command "$cmd" || return 1
  program="$(_sb_opt_in_program "$cmd" || true)"
  [[ "$program" == "graphify" || "$program" == "graphifyy" ]] || return 1
  read -r -a words <<<"$cmd"
  local word seen=0
  for word in "${words[@]}"; do
    if [[ "$seen" == 0 ]]; then
      [[ "${word##*/}" == "$program" ]] && seen=1
      continue
    fi
    case "$word" in
      query | explain | path | affected) return 0 ;;
      -*) continue ;;
      *) return 1 ;;
    esac
  done
  return 1
}

# Status 0 when a shell command does not need the Graphify gate (see opt-in-gate.sh).
sb_graphify_command_is_exempt() {
  ! sb_opt_in_shell_needs_gate graphify "${1:-}"
}

# Status 0 when an edit target is Graphify's own output or Silver Bullet state. Paths are
# normalized first, so graphify-out/../src/app.py is src/app.py.
sb_graphify_edit_path_is_exempt() {
  local file_path="${1:-}" config_file="${2:-}" project_root graph_dir normalized
  [[ -n "$file_path" ]] || return 1
  project_root="$(dirname "${config_file:-$PWD/.silver-bullet.json}")"
  normalized="$(sb_opt_in_normalize_path "$file_path" "$project_root")"
  case "$normalized" in
    */graphify-out/* | */.silver-bullet/*) return 0 ;;
  esac
  graph_dir="$(dirname "$(sb_graphify_graph_rel_path "$config_file")")"
  [[ "$graph_dir" != "." ]] && sb_opt_in_path_under "$normalized" "${project_root%/}/${graph_dir}" && return 0
  return 1
}

sb_graphify_block_message_no_cli() {
  local config_file="${1:-}" host install_lines
  host="$(sb_runtime_host)"
  install_lines="$(sb_recommended_tool_full_install_lines "" graphify "$host")"
  cat <<EOF
🚫 GRAPHIFY REQUIRED — CLI not installed (you opted in to Graphify enforcement).

Silver Bullet mandates Graphify for tier-1 project-memory retrieval in this project. Install before substantive work (host: ${host}):

${install_lines}

Then run: graphify update . --no-cluster

If the user asks to turn Graphify enforcement off: bash $(sb_rt_plugin_script scripts/sb-consent.sh) decline graphify --project $(printf '%q' "$(dirname "${config_file:-$PWD/x}")")
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
  local graph_path="${1:-graphify-out/graph.json}" ttl="${2:-1800}"
  cat <<EOF
🚫 GRAPHIFY QUERY REQUIRED — run retrieval before substantive work.

From the project root, query with concrete file/feature context:

  graphify query "<task, file paths, hook names, or feature context>" --graph ${graph_path} --budget 2000

Run it on its own: a query inside a pipe or list (| head, || true, ;) is not recorded, because its failure would be hidden.
Inspect returned nodes before editing. A fresh query is required every ${ttl}s (or after branch change). Native search is not an acceptable substitute when Graphify is enabled.
EOF
}

sb_graphify_prompt_reminder_line() {
  local config_file="${1:-}" project_root graph_rel ttl
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
        printf '%s' "Graphify: opted in but install failed — enforcement suspended until upgrade; retry on /sb:update."
      elif ! sb_graphify_cli_available; then
        printf '%s' "Graphify: CLI missing — install graphifyy; hooks block substantive work until installed."
      elif ! sb_graphify_index_exists "$project_root" "$config_file"; then
        printf '%s' "Graphify: index missing — run \`graphify update . --no-cluster\` (expected ${graph_rel}). Hooks block substantive edits until built."
      elif sb_graphify_query_is_fresh "$config_file"; then
        printf '%s' "Graphify: fresh query recorded — substantive work allowed until TTL expires."
      else
        ttl="$(sb_graphify_query_ttl_seconds "$config_file")"
        printf '%s' "Graphify: QUERY REQUIRED — run \`graphify query \"<concrete task context>\" --graph ${graph_rel} --budget 2000\` on its own (no pipe) before edits (TTL ${ttl}s). Native search is not a substitute."
      fi
      ;;
  esac
}

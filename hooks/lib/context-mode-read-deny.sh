# shellcheck shell=bash
# Context Mode Read/Grep size nudge — when the user has opted in to Context Mode and it is
# installed and wired (so its ctx_* tools exist), the first full Read of a large file is
# denied once with directions to the sandboxed tools. Repeating the same Read within
# _sb_context_mode_read_ack_seconds is allowed (Edit needs the exact bytes), so no file is
# ever blocked outright. Exempt: partial reads that stay under the threshold, images, PDFs
# and notebooks (Read is the only way to view them), Silver Bullet's own instruction files
# and plugin files, Grep that only lists files or counts, and SB state files.
# Sourced by: context-mode-read-deny.sh

_sb_context_mode_default_read_deny_bytes=5120
_sb_context_mode_read_ack_seconds=1800
_sb_context_mode_read_lib_dir="${BASH_SOURCE[0]%/*}"

# shellcheck source=context-mode-gate.sh
source "${_sb_context_mode_read_lib_dir}/context-mode-gate.sh"
# shellcheck source=stack-compression-coordinator.sh
source "${_sb_context_mode_read_lib_dir}/stack-compression-coordinator.sh"
# shellcheck source=leanctx-gate.sh
source "${_sb_context_mode_read_lib_dir}/leanctx-gate.sh"

sb_context_mode_read_deny_bypassed() {
  case "${CONTEXT_MODE_READ_DENY_BYPASS:-${SB_CONTEXT_MODE_READ_DENY_BYPASS:-}}" in
    1|true|yes|YES|on|ON) return 0 ;;
  esac
  return 1
}

# Threshold in bytes. The project may raise it or set 0 to switch the nudge off; a lower
# value than the default would add blocking, so it is not honoured.
sb_context_mode_read_deny_bytes() {
  local config_file="${1:-}" bytes=""
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    bytes="$(jq -r '.recommended_tools.context_mode.read_deny_bytes // "" | tostring' "$config_file" 2>/dev/null || true)"
  fi
  if [[ "$bytes" =~ ^[0-9]{1,12}$ ]] && { ((10#$bytes == 0)) || ((10#$bytes >= _sb_context_mode_default_read_deny_bytes)); }; then
    printf '%s' "$((10#$bytes))"
    return 0
  fi
  printf '%s' "$_sb_context_mode_default_read_deny_bytes"
}

sb_context_mode_file_size_bytes() {
  local file_path="${1:-}" size
  [[ -n "$file_path" && -f "$file_path" ]] || return 1
  size="$(wc -c <"$file_path" 2>/dev/null | tr -d '[:space:]')"
  [[ "$size" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$size"
}

sb_context_mode_tool_read_path() {
  local input="${1:-}"
  case "$(sb_tool_name "$input" 2>/dev/null || true)" in
    Read) printf '%s' "$input" | jq -r '.tool_input.file_path // "" | strings' 2>/dev/null || true ;;
    Grep) printf '%s' "$input" | jq -r '.tool_input.path // "" | strings' 2>/dev/null || true ;;
  esac
}

# Status 0 for a file only Read can show (images, PDFs, notebooks), by extension.
sb_context_mode_read_path_is_media() {
  case "${1:-}" in
    *.[pP][nN][gG] | *.[jJ][pP][gG] | *.[jJ][pP][eE][gG] | *.[gG][iI][fF] | *.[wW][eE][bB][pP] \
      | *.[bB][mM][pP] | *.[iI][cC][oO] | *.[tT][iI][fF] | *.[tT][iI][fF][fF] | *.[hH][eE][iI][cC] \
      | *.[aA][vV][iI][fF] | *.[pP][dD][fF] | *.[iI][pP][yY][nN][bB])
      return 0
      ;;
  esac
  return 1
}

sb_context_mode_read_path_is_exempt() {
  local file_path="${1:-}" config_file="${2:-}" state_file trivial_file
  [[ -n "$file_path" ]] || return 1
  sb_context_mode_edit_path_is_exempt "$file_path" "$config_file" && return 0
  sb_context_mode_read_path_is_media "$file_path" && return 0
  case "$file_path" in
    */graphify-out/graph.json | */graphify-out/wiki/index.md | */silver-bullet.md | */CLAUDE.md \
      | */AGENTS.md | */GEMINI.md | */SKILL.md | "${_SB_RT_PLUGIN_ROOT}"/*)
      return 0
      ;;
  esac
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    state_file="$(jq -r '.state.state_file // "" | strings' "$config_file" 2>/dev/null || true)"
    trivial_file="$(jq -r '.state.trivial_file // "" | strings' "$config_file" 2>/dev/null || true)"
    [[ -n "$state_file" && "$file_path" == "${state_file/#\~/$HOME}" ]] && return 0
    [[ -n "$trivial_file" && "$file_path" == "${trivial_file/#\~/$HOME}" ]] && return 0
  fi
  return 1
}

# Status 0 when the routed read tools exist: LeanCTX when it owns sb_read, else Context Mode.
sb_context_mode_read_tools_ready() {
  local config_file="${1:-}" project_root="${2:-$PWD}"
  if sb_stack_read_deny_defer_to_leanctx "$config_file"; then
    sb_leanctx_cli_available "$config_file" && sb_leanctx_platform_artifact_present "$project_root" && return 0
    return 1
  fi
  sb_context_mode_ready "$project_root"
}

# Bytes this call would bring into context: the whole file, or for a Read with a line
# limit the limit times the file's average line length.
_sb_context_mode_read_bytes() {
  local input="$1" path="$2" size limit lines
  size="$(sb_context_mode_file_size_bytes "$path")" || return 1
  limit="$(printf '%s' "$input" | jq -r '.tool_input.limit // "" | tostring' 2>/dev/null || true)"
  if [[ "$limit" =~ ^[0-9]{1,9}$ ]] && ((10#$limit > 0)); then
    lines="$(wc -l <"$path" 2>/dev/null | tr -d '[:space:]')"
    [[ "$lines" =~ ^[0-9]+$ ]] && ((lines > 0)) || lines=1
    if ((10#$limit < lines)); then
      size=$((size * 10#$limit / lines))
    fi
  fi
  printf '%s' "$size"
}

_sb_context_mode_read_ack_path() {
  local sum
  sum="$(printf '%s' "${1:-}" | cksum | awk '{print $1}')"
  printf '%s/context-mode-read-acks/%s' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}" "$sum"
}

# Prints the resolved path and returns 0 when this Read/Grep should be denied.
sb_context_mode_should_deny_read() {
  local input="${1:-}" config_file="${2:-}" project_root="${3:-$PWD}"
  local tool_name file_path threshold resolved size ack

  sb_context_mode_read_deny_bypassed && return 1
  threshold="$(sb_context_mode_read_deny_bytes "$config_file")"
  ((threshold > 0)) || return 1

  tool_name="$(sb_tool_name "$input" 2>/dev/null || true)"
  case "$tool_name" in
    Read) ;;
    Grep)
      # Conflict #2: Grep stays on the CM cooperative path when LeanCTX owns sb_read.
      sb_stack_leanctx_active "$config_file" && return 1
      # Only content output can bring the file in; file lists and counts cannot.
      [[ "$(printf '%s' "$input" | jq -r '.tool_input.output_mode // "files_with_matches"' 2>/dev/null)" == "content" ]] || return 1
      [[ "$(printf '%s' "$input" | jq -r '.tool_input.head_limit // "" | tostring' 2>/dev/null)" =~ ^[1-9][0-9]*$ ]] && return 1
      ;;
    *) return 1 ;;
  esac

  file_path="$(sb_context_mode_tool_read_path "$input")"
  [[ -n "$file_path" ]] || return 1
  resolved="$(sb_opt_in_normalize_path "$file_path" "$project_root")"
  [[ -f "$resolved" ]] || return 1
  sb_context_mode_read_path_is_exempt "$resolved" "$config_file" && return 1
  size="$(_sb_context_mode_read_bytes "$input" "$resolved")" || return 1
  ((size > threshold)) || return 1
  sb_context_mode_read_tools_ready "$config_file" "$project_root" || return 1

  # A repeated Read of a file denied (or allowed after a denial) within the window is a
  # deliberate request for the exact bytes: allow it.
  ack="$(_sb_context_mode_read_ack_path "$resolved")"
  if sb_rt_stamp_is_fresh "$ack" "$_sb_context_mode_read_ack_seconds"; then
    return 1
  fi
  sb_rt_stamp_write "$ack" || true
  printf '%s' "$resolved"
  return 0
}

sb_context_mode_read_deny_message() {
  local file_path="${1:-}" size="${2:-}" threshold="${3:-}" config_file="${4:-}"
  if [[ -n "$config_file" ]] && sb_stack_read_deny_defer_to_leanctx "$config_file"; then
    sb_stack_read_deny_message_leanctx "$file_path" "$size" "$threshold"
    return 0
  fi
  cat <<EOF
🚫 CONTEXT MODE — large Read redirected once (${size} bytes > ${threshold} byte threshold).

For analysis, keep the file out of context:
  • ctx_execute_file — sandboxed analysis (stdout only enters context)
  • ctx_index + ctx_search — index then query relevant sections
  • ctx_batch_execute — batch reads with auto-index

Need the exact bytes (for example to Edit this file)? Repeat the same Read: it is allowed for the next 30 minutes. A Read with a small limit, images, PDFs and SB instruction files are never redirected.

Path: ${file_path}
See docs/CONTEXT-MODE.md and silver-bullet.md §2g-ii.
EOF
}

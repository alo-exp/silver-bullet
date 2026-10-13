#!/usr/bin/env bash

if [[ -n "${_lib_dir:-}" && -d "${_lib_dir}/tool-input" ]]; then
  _sb_tool_input_py_dir="${_lib_dir}/tool-input"
else
  _sb_tool_input_py_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tool-input"
fi

_sb_tool_input_py() {
  local script="$1"
  shift
  python3 "${_sb_tool_input_py_dir}/${script}" "$@" 2>/dev/null || true
}

_sb_tool_input_py_status() {
  local script="$1"
  shift
  python3 "${_sb_tool_input_py_dir}/${script}" "$@" 2>/dev/null
}

sb_tool_name() {
  local payload="${1:-}"
  printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || true
}

sb_tool_is_shell_like() {
  local tool_name="${1:-}"
  case "$tool_name" in
    Bash|Shell|shell|exec_command) return 0 ;;
    *) return 1 ;;
  esac
}

sb_tool_command_string() {
  local payload="${1:-}"
  _sb_tool_input_py tool_command_string.py "$payload"
}

# Normalize agent shell commands for gate regexes — strip RTK_DISABLED bypass and rtk wrapper.
sb_shell_command_unwrap_rtk() {
  local payload="${1:-}"
  [[ -n "$payload" ]] || return 0
  local unwrapped
  unwrapped="$(_sb_tool_input_py shell_unwrap_rtk.py "$payload")"
  if [[ -n "$unwrapped" ]]; then
    printf '%s' "$unwrapped"
  else
    printf '%s' "$payload"
  fi
}

sb_tool_patch_paths() {
  local payload="${1:-}"
  _sb_tool_input_py patch_paths.py "$payload"
}

sb_tool_file_path() {
  local payload="${1:-}"
  local direct_path
  direct_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null || true)"
  if [[ -n "$direct_path" ]]; then
    printf '%s\n' "$direct_path"
    return 0
  fi
  sb_tool_patch_paths "$payload" | sed -n '1p'
}

sb_shell_invoked_script_path() {
  local command_str="${1:-}"
  local base_dir="${2:-$PWD}"
  _sb_tool_input_py invoked_script_path.py "$base_dir" "$command_str"
}

sb_shell_candidate_write_paths() {
  local command_str="${1:-}"
  local base_dir="${2:-$PWD}"
  _sb_tool_input_py candidate_write_paths.py "$base_dir" "$command_str"
}

sb_shell_command_looks_read_only() {
  local command_str="${1:-}"
  _sb_tool_input_py_status command_looks_read_only.py "$command_str"
}

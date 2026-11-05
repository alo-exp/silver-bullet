#!/usr/bin/env bash
# Hook payload accessors shared by the gates.
#
# Every helper sends its input to python3 on stdin, so payload size is never limited by
# argv (Linux refuses a single argument over 128 KiB). When a hook has already called
# sb_tool_input_load (shell-analysis.sh, sourced below) for the same payload or command,
# the accessors reuse that one analysis instead of starting python3 again.

if [[ -n "${_lib_dir:-}" && -d "${_lib_dir}/tool-input" ]]; then
  _sb_tool_input_py_dir="${_lib_dir}/tool-input"
else
  _sb_tool_input_py_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tool-input"
fi
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/shell-analysis.sh" ]]; then
  # shellcheck source=shell-analysis.sh
  source "$(dirname "${BASH_SOURCE[0]}")/shell-analysis.sh"
fi

# _sb_tool_input_py_status SCRIPT INPUT [ARG...]: run a helper with INPUT on stdin
# (the helper reads it because its input argument is "-"); keeps the helper's status.
_sb_tool_input_py_status() {
  local script="$1" input="$2"
  shift 2
  printf '%s' "$input" | python3 "${_sb_tool_input_py_dir}/${script}" "$@" - 2>/dev/null
}

# _sb_tool_input_py SCRIPT INPUT [ARG...]: same, but never fails (prints nothing instead).
_sb_tool_input_py() {
  _sb_tool_input_py_status "$@" || true
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
  local payload="${1:-}" command_str
  if declare -f _sb_sa_loaded_payload >/dev/null 2>&1 && _sb_sa_loaded_payload "$payload"; then
    printf '%s' "$SB_TI_COMMAND"
    return 0
  fi
  if command_str="$(_sb_tool_input_py_status tool_command_string.py "$payload")"; then
    printf '%s' "$command_str"
    return 0
  fi
  # python3 is missing or failing: read the same fields with jq so the gates still see the
  # command (sb_tool_input_load reports SB_TI_STATUS=helper_unavailable for them to deny).
  printf '%s' "$payload" | jq -r '
    (.tool_input // {}) | if type == "object" then (.command // .cmd) else null end
    | if type == "string" then .
      elif type == "array" then map(tostring | if test("^[A-Za-z0-9_@%+=:,./-]+$") then . else @sh end) | join(" ")
      else empty end' 2>/dev/null || true
}

# Normalize agent shell commands for gate regexes — strip RTK_DISABLED bypass and rtk wrapper.
sb_shell_command_unwrap_rtk() {
  local payload="${1:-}"
  [[ -n "$payload" ]] || return 0
  local unwrapped
  if declare -f _sb_sa_loaded_command >/dev/null 2>&1 && _sb_sa_loaded_command "$payload"; then
    unwrapped="$SB_SA_RTK_UNWRAPPED"
  else
    unwrapped="$(_sb_tool_input_py shell_unwrap_rtk.py "$payload")"
  fi
  if [[ -n "$unwrapped" ]]; then
    printf '%s' "$unwrapped"
  else
    printf '%s' "$payload"
  fi
}

sb_tool_patch_paths() {
  local payload="${1:-}"
  if declare -f _sb_sa_loaded_payload >/dev/null 2>&1 && _sb_sa_loaded_payload "$payload"; then
    [[ -z "$SB_TI_PATCH_PATHS" ]] || printf '%s\n' "$SB_TI_PATCH_PATHS"
    return 0
  fi
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
  if declare -f _sb_sa_loaded_command >/dev/null 2>&1 && _sb_sa_loaded_command "$command_str" "$base_dir"; then
    [[ -z "$SB_SA_INVOKED_SCRIPT" ]] || printf '%s\n' "$SB_SA_INVOKED_SCRIPT"
    return 0
  fi
  _sb_tool_input_py invoked_script_path.py "$command_str" "$base_dir"
}

sb_shell_candidate_write_paths() {
  local command_str="${1:-}"
  local base_dir="${2:-$PWD}"
  if declare -f _sb_sa_loaded_command >/dev/null 2>&1 && _sb_sa_loaded_command "$command_str" "$base_dir"; then
    [[ -z "$SB_SA_WRITE_PATHS" ]] || printf '%s\n' "$SB_SA_WRITE_PATHS"
    return 0
  fi
  _sb_tool_input_py candidate_write_paths.py "$command_str" "$base_dir"
}

sb_shell_command_looks_read_only() {
  local command_str="${1:-}"
  if declare -f _sb_sa_loaded_command >/dev/null 2>&1 && _sb_sa_loaded_command "$command_str"; then
    [[ "$SB_SA_READ_ONLY_LEGACY" == "true" ]] || return 1
    printf 'read-only\n'
    return 0
  fi
  _sb_tool_input_py_status command_looks_read_only.py "$command_str"
}

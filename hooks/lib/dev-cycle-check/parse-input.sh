#!/usr/bin/env bash
# dev-cycle-check module — auto-split
# Read JSON from stdin
input=$(cat)

# Detect hook event type (PreToolUse vs PostToolUse)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')

dcc_resolve_repo_root() {
  local d="$PWD"
  while [[ "$d" != "/" && -n "$d" ]]; do
    if [[ -d "$d/.planning" || -d "$d/.git" ]]; then
      printf '%s' "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  return 1
}

# --- Determine file path or command based on tool type ---
if declare -f sb_tool_file_path >/dev/null 2>&1; then
  file_path="$(sb_tool_file_path "$input")"
else
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // ""')
fi
command_str=""

if [[ -z "$file_path" ]]; then
  # Shell-like tool — extract command
  if declare -f sb_tool_command_string >/dev/null 2>&1; then
    command_str="$(sb_tool_command_string "$input")"
  else
    command_str=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
  fi
  [[ -z "$command_str" ]] && exit 0
fi
if declare -f sb_tool_name >/dev/null 2>&1; then
  tool_name="$(sb_tool_name "$input")"
else
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
fi
patch_file_paths=()
if [[ "$tool_name" == "apply_patch" ]] && declare -f sb_tool_patch_paths >/dev/null 2>&1; then
  while IFS= read -r patch_path; do
    [[ -n "$patch_path" ]] && patch_file_paths+=("$patch_path")
  done < <(sb_tool_patch_paths "$input" 2>/dev/null || true)
  if [[ -z "$file_path" && ${#patch_file_paths[@]} -gt 0 ]]; then
    file_path="${patch_file_paths[0]}"
  fi
fi
if [[ -z "$file_path" ]] && declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
  sb_tool_is_shell_like "$tool_name" || exit 0
fi

shell_script_path=""
shell_script_dir="$PWD"
shell_script_body=""
shell_write_targets=()
shell_in_scope_targets=()
shell_target_scope_fallback=false

dcc_collect_shell_write_targets() {
  local payload="$1"
  local base_dir="$2"
  local target_path
  [[ -n "$payload" ]] || return 0
  if ! declare -f sb_shell_candidate_write_paths >/dev/null 2>&1; then
    return 0
  fi
  while IFS= read -r target_path; do
    [[ -n "$target_path" ]] || continue
    shell_write_targets+=("$target_path")
  done < <(sb_shell_candidate_write_paths "$payload" "$base_dir" 2>/dev/null || true)
}

dcc_shell_writes_to_exact_path() {
  local expected="$1"
  local target_path expected_canon target_canon
  expected_canon="$(sb_canonical_path "$expected")"
  for target_path in "${shell_write_targets[@]:-}"; do
    target_canon="$(sb_canonical_path "$target_path")"
    [[ "$target_canon" == "$expected_canon" ]] && return 0
  done
  return 1
}

dcc_shell_writes_under_prefix() {
  local prefix="${1%/}"
  local target_path prefix_canon target_canon
  prefix_canon="$(sb_canonical_path "$prefix")"
  for target_path in "${shell_write_targets[@]:-}"; do
    target_canon="$(sb_canonical_path "$target_path")"
    [[ "$target_canon" == "$prefix_canon" || "$target_canon" == "$prefix_canon"/* ]] && return 0
  done
  return 1
}

if [[ -z "$file_path" && -n "$command_str" ]]; then
  if declare -f sb_shell_invoked_script_path >/dev/null 2>&1; then
    shell_script_path="$(sb_shell_invoked_script_path "$command_str" "$PWD" 2>/dev/null || true)"
  fi
  if [[ -n "$shell_script_path" && -f "$shell_script_path" ]]; then
    shell_script_dir="$(dirname "$shell_script_path")"
    shell_script_body="$(cat "$shell_script_path" 2>/dev/null || true)"
  fi
  dcc_collect_shell_write_targets "$command_str" "$PWD"
  if [[ -n "$shell_script_body" ]]; then
    dcc_collect_shell_write_targets "$shell_script_body" "$PWD"
    dcc_collect_shell_write_targets "$shell_script_body" "$shell_script_dir"
  fi
fi

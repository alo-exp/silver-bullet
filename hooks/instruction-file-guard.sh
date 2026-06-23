#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse guard for root project instruction files.
#
# Silver Bullet may reconcile an existing project instruction file in place,
# but it must not synthesize a brand-new root CLAUDE.md or AGENTS.md during
# Codex initialization. Silver Bullet's primary contract lives in
# silver-bullet.md.

umask 0077

command -v jq >/dev/null 2>&1 || exit 0

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi

input=$(cat)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch) ;;
  *) exit 0 ;;
esac

normalize_path() {
  python3 -c 'import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))' "$1" 2>/dev/null || printf '%s' "$1"
}

resolve_repo_root() {
  local dir="$PWD"
  while true; do
    if [[ -f "$dir/.silver-bullet.json" ]] || [[ -f "$dir/silver-bullet.md" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    if [[ -d "$dir/.git" ]] || [[ "$dir" == "/" ]]; then
      return 1
    fi
    dir=$(dirname "$dir")
  done
}

repo_root="$(resolve_repo_root 2>/dev/null || true)"
[[ -n "$repo_root" ]] || exit 0
repo_root="$(normalize_path "$repo_root")"

# Only enforce inside an SB-initiated project.
[[ -f "$repo_root/.silver-bullet.json" ]] || exit 0
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi
if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$repo_root/.silver-bullet.json" || exit 0
elif declare -f sb_project_is_initiated >/dev/null 2>&1; then
  sb_project_is_initiated "$repo_root/.silver-bullet.json" || exit 0
fi

deny_root_instruction_creation() {
  local target_path="$1"
  local basename_target
  basename_target="$(basename "$target_path")"
  case "$basename_target" in
    CLAUDE.md|AGENTS.md) ;;
    *) return 0 ;;
  esac

  if [[ "$target_path" != "$repo_root/CLAUDE.md" && "$target_path" != "$repo_root/AGENTS.md" ]]; then
    return 0
  fi

  [[ -e "$target_path" ]] && return 0

  local reason
  reason="PROJECT INSTRUCTION FILE CREATION BLOCKED — Silver Bullet does not synthesize a new root CLAUDE.md or AGENTS.md during Codex initialization. If an instruction file already exists, update it in place; otherwise keep the project instruction surface optional and rely on silver-bullet.md as the primary contract."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$(printf '%s' "$reason" | jq -Rs '.')"
  exit 0
}

tool_paths() {
  if [[ "$tool_name" == "apply_patch" ]] && declare -f sb_tool_patch_paths >/dev/null 2>&1; then
    sb_tool_patch_paths "$input" 2>/dev/null || true
  else
    printf '%s' "$input" | jq -r '
      .tool_input.file_path? // empty,
      (.tool_input.file_paths? // [])[]?
    ' 2>/dev/null || true
  fi
}

while IFS= read -r raw_path; do
  [[ -n "$raw_path" ]] || continue
  deny_root_instruction_creation "$(normalize_path "$raw_path")"
done < <(tool_paths)

exit 0

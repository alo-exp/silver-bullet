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

input=$(cat)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
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

# Only enforce inside an active SB project. If Silver Bullet has not been
# initialized yet, or the project is not SB-managed, this hook stays inert.
[[ -f "$repo_root/silver-bullet.md" || -f "$repo_root/.silver-bullet.json" ]] || exit 0

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

while IFS= read -r raw_path; do
  [[ -n "$raw_path" ]] || continue
  deny_root_instruction_creation "$(normalize_path "$raw_path")"
done < <(
  printf '%s' "$input" | jq -r '
    .tool_input.file_path? // empty,
    (.tool_input.file_paths? // [])[]?
  ' 2>/dev/null || true
)

exit 0

#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse guard for root project instruction files.
#
# Silver Bullet may reconcile an existing project instruction file in place,
# but it must not synthesize a brand-new root CLAUDE.md or AGENTS.md during
# Codex initialization. Silver Bullet's primary contract lives in
# silver-bullet.md.
#
# Covers the file tools (Edit, Write, MultiEdit, NotebookEdit, every apply_patch path) and
# shell writes (redirects, cp, mv, tee, ...: the write targets of the shell analysis). Names
# compare case-insensitively: on APFS and NTFS claude.md is the file the host loads as CLAUDE.md.

umask 0077

command -v jq >/dev/null 2>&1 || exit 0

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/planning-floor.sh
source "$_lib_dir/planning-floor.sh"
if [[ -f "$_lib_dir/cert-bypass.sh" ]]; then
  # shellcheck source=lib/cert-bypass.sh
  source "$_lib_dir/cert-bypass.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi

input=$(cat)
if declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
  exit 0
fi
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tool_name" in
  Edit | Write | MultiEdit | NotebookEdit | apply_patch) ;;
  *) sb_tool_is_shell_like "$tool_name" || exit 0 ;;
esac

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
repo_root="$(sb_pf_canon "$repo_root")"

# Only enforce inside an SB-initiated project.
[[ -f "$repo_root/.silver-bullet.json" ]] || exit 0
if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$repo_root/.silver-bullet.json" || exit 0
fi

REASON="PROJECT INSTRUCTION FILE CREATION BLOCKED — Silver Bullet does not synthesize a new root CLAUDE.md or AGENTS.md during Codex initialization. If an instruction file already exists, update it in place; otherwise keep the project instruction surface optional and rely on silver-bullet.md as the primary contract."

deny() {
  sb_emit_hook_decision PreToolUse deny "$1"
  exit 0
}

sb_tool_input_load "$input" "$PWD"
if ! sb_tool_input_ok; then
  [[ "${SB_TI_STATUS:-}" == "empty" ]] && exit 0
  # The shell command cannot be analysed: refuse only what names an instruction file.
  lower="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == *claude.md* || "$lower" == *agents.md* ]] || exit 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.cmd // ""' 2>/dev/null)"
  sb_pf_plain_read_only "$cmd" && exit 0
  deny "$(sb_pf_unanalysable_message)"
fi

if [[ "${SB_TI_TOOL_KIND:-}" == "shell" ]] && sb_pf_opaque_mentions claude.md agents.md; then
  deny "$REASON"
fi

# An instruction file already there (any case) may be updated in place.
instruction_file_exists() {
  local name="$1"
  [[ -e "$repo_root/$name" ]] && return 0
  [[ -n "$(find "$repo_root" -maxdepth 1 -iname "$name" 2>/dev/null | head -n 1)" ]]
}

while IFS= read -r target; do
  [[ "$(dirname "$target")" == "$repo_root" ]] || continue
  name="$(basename "$target" | tr '[:upper:]' '[:lower:]')"
  case "$name" in
    claude.md | agents.md) ;;
    *) continue ;;
  esac
  instruction_file_exists "$(basename "$target")" && continue
  deny "$REASON"
done < <(sb_pf_write_targets "$input")

exit 0

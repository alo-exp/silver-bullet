#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Edit|Write|MultiEdit)
# Blocks direct edits to GSD-managed planning artifacts (.planning/ROADMAP.md etc.)
# that must only be modified through the appropriate GSD skill.
#
# Protected files:
#   .planning/ROADMAP.md, STATE.md, REQUIREMENTS.md, PROJECT.md,
#   RELEASE.md, UAT.md, v*-MILESTONE-*.md
#
# Bypass: create ~/.claude/.silver-bullet/planning-edit-override (file, not symlink)
# or set env var SB_ALLOW_PLANNING_EDITS=1 before starting Claude Code.

# Security: restrict file creation permissions (user-only)
umask 0077

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

# Extract file path from tool input (Edit and Write both use file_path)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[[ -z "$file_path" ]] && exit 0

# Only care about files immediately inside a .planning/ directory
# Canonicalize path to prevent traversal bypass (e.g. .planning/sub/../ROADMAP.md)
_norm_path=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$file_path" 2>/dev/null || printf '%s' "$file_path")
dir_basename=$(basename "$(dirname "$_norm_path")")
[[ "$dir_basename" != ".planning" ]] && exit 0

basename_path=$(basename "$_norm_path")

# Check if the file is in the protected set
protected=false
case "$basename_path" in
  ROADMAP.md|STATE.md|REQUIREMENTS.md|PROJECT.md|RELEASE.md|UAT.md)
    protected=true
    ;;
  v*-MILESTONE-*.md)
    protected=true
    ;;
esac

[[ "$protected" == false ]] && exit 0

# ── Exit early if project is not using Silver Bullet ─────────────────────────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[[ -z "$config_file" ]] && exit 0

# ── Bypass: env var override ──────────────────────────────────────────────────
if [[ "${SB_ALLOW_PLANNING_EDITS:-}" == "1" ]]; then
  _msg="⚠️  planning-file-guard: SB_ALLOW_PLANNING_EDITS=1 — allowing direct edit to ${basename_path}. Prefer the owning GSD skill."
  printf '{"hookSpecificOutput":{"message":%s}}\n' "$(printf '%s' "$_msg" | jq -Rs '.')"
  exit 0
fi

# ── Bypass: file-based override (consistent with ci-red-override pattern) ─────
_override="${HOME}/.claude/.silver-bullet/planning-edit-override"
if [[ -f "$_override" && ! -L "$_override" ]]; then
  _msg="⚠️  planning-file-guard: override active — allowing direct edit to ${basename_path}. Remove ${_override} when done."
  printf '{"hookSpecificOutput":{"message":%s}}\n' "$(printf '%s' "$_msg" | jq -Rs '.')"
  exit 0
fi

# ── Trivial bypass (sourced from shared helper — REF-01) ─────────────────────
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
_trivial_file="${HOME}/.claude/.silver-bullet/trivial"
_cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file" 2>/dev/null || true)
[[ -n "$_cfg_trivial" ]] && _trivial_file="${_cfg_trivial/#\~/$HOME}"
# Security: validate trivial path stays within ~/.claude/ (mirrors stop-check.sh SB-002)
case "$_trivial_file" in
  "$HOME"/.claude/*) ;;
  *) _trivial_file="${HOME}/.claude/.silver-bullet/trivial" ;;
esac
if [[ -f "$_lib_dir/trivial-bypass.sh" ]]; then
  # shellcheck disable=SC1090
  source "$_lib_dir/trivial-bypass.sh"
  sb_trivial_bypass "$_trivial_file"
fi

# ── Block direct edit ─────────────────────────────────────────────────────────
skill_hint=""
case "$basename_path" in
  ROADMAP.md)
    skill_hint="Use /gsd-add-phase, /gsd-roadmapper, or /gsd-complete-milestone instead."
    ;;
  STATE.md)
    skill_hint="Use /gsd-execute-phase, /gsd-complete-milestone, /gsd-pause-work, or /gsd-resume-work instead."
    ;;
  REQUIREMENTS.md)
    skill_hint="Use /gsd-roadmapper instead."
    ;;
  PROJECT.md)
    skill_hint="Use /gsd-new-project instead."
    ;;
  RELEASE.md)
    skill_hint="Use /silver-release or /create-release instead."
    ;;
  UAT.md)
    skill_hint="Use /gsd-audit-uat instead."
    ;;
  v*-MILESTONE-*.md)
    skill_hint="Use /gsd-audit-milestone instead."
    ;;
esac

msg="🚫 PLANNING FILE GUARD — Direct edits to .planning/${basename_path} are not permitted.

GSD-managed planning artifacts must be modified only through their owning skills.
${skill_hint}

To bypass for a one-off doc fix:
  touch ~/.claude/.silver-bullet/planning-edit-override
Remove the file when done."

json_msg=$(printf '%s' "$msg" | jq -Rs '.')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_msg"

#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Edit|Write|MultiEdit)
# Blocks direct edits to GSD-managed planning artifacts (.planning/ROADMAP.md etc.)
# that must only be modified through the appropriate GSD skill.
#
# Protected files (GSD-managed — updated by GSD CLI tools, not by direct
# Write/Edit): top-level project state plus nested phase lifecycle artifacts
# such as .planning/phases/**/PLAN.md, SUMMARY.md, REVIEW.md, SECURITY.md,
# and VERIFICATION.md. SB may own separate spec/quality artifacts, but it does
# not directly mutate GSD lifecycle artifacts.
#
# Bypass: create <host runtime>/.silver-bullet/planning-edit-override (file, not symlink)
# or set env var SB_ALLOW_PLANNING_EDITS=1 before starting Claude Code.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so the override/trivial files follow the host.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "$_lib_dir/hook-audit.sh"
fi

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

# Extract file path from tool input (Edit, Write, and MultiEdit all use file_path)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[[ -z "$file_path" ]] && exit 0

# Canonicalize path to prevent traversal bypass (e.g. .planning/sub/../ROADMAP.md)
_norm_path=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$file_path" 2>/dev/null || printf '%s' "$file_path")
case "$_norm_path" in
  /*) ;;
  *) _norm_path="$PWD/$_norm_path" ;;
esac
basename_path=$(basename "$_norm_path")

# Check if the file is in the protected set (GSD-managed lifecycle artifacts).
# SB-owned spec and quality files remain outside this protected set unless they
# are core GSD planning state files.
protected=false
planning_rel=""
case "$_norm_path" in
  */.planning/*)
    planning_rel="${_norm_path#*/.planning/}"
    ;;
  *) exit 0 ;;
esac

case "$planning_rel" in
  ROADMAP.md|STATE.md|PROJECT.md|RELEASE.md|REQUIREMENTS.md|UAT.md)
    protected=true
    ;;
  v*-MILESTONE-*.md|milestones/*.md)
    protected=true
    ;;
  phases/*/*-PLAN.md|phases/*/*-SUMMARY.md|phases/*/*-REVIEW.md|phases/*/*-SECURITY.md|phases/*/*-VERIFICATION.md|phases/*/VERIFICATION.md|phases/*/REVIEW.md|phases/*/SECURITY.md)
    protected=true
    ;;
esac

[[ "$protected" == false ]] && exit 0

# ── Exit early if project is not using Silver Bullet ─────────────────────────
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[[ -z "$config_file" ]] && exit 0

# ── Verify the file being edited is under THIS project's root (WR-05) ─────────
# Prevents enforcement firing on a different project's .planning/ when Claude is
# running in a multi-repo or worktree setup where absolute paths are passed.
_project_root=$(dirname "$config_file")
case "$_norm_path" in
  "$_project_root"/*) ;;   # file is inside this project — enforce
  *) exit 0 ;;             # file is outside this project — skip
esac

# ── Bypass: env var override ──────────────────────────────────────────────────
if [[ "${SB_ALLOW_PLANNING_EDITS:-}" == "1" ]]; then
  _msg="⚠️  planning-file-guard: SB_ALLOW_PLANNING_EDITS=1 — allowing direct edit to ${basename_path}. Prefer the owning GSD skill."
  printf '{"hookSpecificOutput":{"message":%s}}\n' "$(printf '%s' "$_msg" | jq -Rs '.')"
  exit 0
fi

# ── Bypass: file-based override (consistent with ci-red-override pattern) ─────
_override="${SB_RUNTIME_STATE_DIR}/planning-edit-override"
if [[ -f "$_override" && ! -L "$_override" ]]; then
  _msg="⚠️  planning-file-guard: override active — allowing direct edit to ${basename_path}. Remove ${_override} when done."
  printf '{"hookSpecificOutput":{"message":%s}}\n' "$(printf '%s' "$_msg" | jq -Rs '.')"
  exit 0
fi

# ── Trivial bypass (sourced from shared helper — REF-01) ─────────────────────
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
_trivial_file="${SB_RUNTIME_STATE_DIR}/trivial"
_cfg_trivial=$(jq -r '.state.trivial_file // ""' "$config_file" 2>/dev/null || true)
[[ -n "$_cfg_trivial" ]] && _trivial_file="${_cfg_trivial/#\~/$HOME}"
# Security: validate trivial path stays within the host runtime state root (mirrors stop-check.sh SB-002)
if ! sb_runtime_path_is_state_scoped "$_trivial_file"; then
  _trivial_file="${SB_RUNTIME_STATE_DIR}/trivial"
fi
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
  PROJECT.md)
    skill_hint="Use /gsd-new-project instead."
    ;;
  RELEASE.md)
    skill_hint="Use /silver-release or /silver-create-release instead."
    ;;
  REQUIREMENTS.md)
    skill_hint="Use /gsd-new-project, /gsd-new-milestone, /gsd-spec-phase, or /gsd-ingest-docs instead. SB specs should live in SB-owned spec artifacts, not overwrite GSD requirements directly."
    ;;
  UAT.md)
    skill_hint="Use /gsd-verify-work or /gsd-validate-phase instead."
    ;;
  v*-MILESTONE-*.md)
    skill_hint="Use /gsd-audit-milestone instead."
    ;;
  *-PLAN.md|PLAN.md)
    skill_hint="Use /gsd-plan-phase instead."
    ;;
  *-SUMMARY.md|SUMMARY.md)
    skill_hint="Use /gsd-execute-phase, /gsd-milestone-summary, or the relevant GSD phase completion skill instead."
    ;;
  *-REVIEW.md|REVIEW.md)
    skill_hint="Use /gsd-code-review instead."
    ;;
  *-SECURITY.md|SECURITY.md)
    skill_hint="Use /gsd-secure-phase instead."
    ;;
  *-VERIFICATION.md|VERIFICATION.md)
    skill_hint="Use /gsd-verify-work or /gsd-validate-phase instead."
    ;;
esac

msg="🚫 PLANNING FILE GUARD — Direct edits to .planning/${basename_path} are not permitted.

GSD-managed planning artifacts must be modified only through their owning skills.
${skill_hint}

To bypass for a one-off doc fix:
  touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/planning-edit-override
Remove the file when done."

json_msg=$(printf '%s' "$msg" | jq -Rs '.')
sb_hook_audit_record "planning-file-guard" "PreToolUse" "deny" "$msg" "$_norm_path"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_msg"

#!/usr/bin/env bash
# Harden the shell only when executed directly. When sourced, these options, the ERR
# trap and the umask would leak into the caller's shell (a later failing command would
# end the caller with status 0), so a sourced run leaves the caller's settings alone.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  trap 'exit 0' ERR
  # Security: restrict file creation permissions (user-only)
  umask 0077
fi

# Source runtime path selector so the deploy gate follows the host runtime.
_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null)" || _repo_root=""
if [[ -f "$_repo_root/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$_repo_root/hooks/lib/runtime-paths.sh"
fi
if [[ -f "$_repo_root/hooks/lib/required-skills.sh" ]]; then
  # shellcheck source=hooks/lib/required-skills.sh
  # shellcheck disable=SC1091
  source "$_repo_root/hooks/lib/required-skills.sh"
fi

###############################################################################
# Deploy Gate Snippet — Silver Bullet
#
# Copy-paste this snippet into your deploy / CI script to block deployment
# unless all required workflow skills were invoked during the current session.
#
# Usage:
#   bash /path/to/deploy-gate-snippet.sh             # standalone (recommended)
#   source /path/to/deploy-gate-snippet.sh || exit 1   # sourced in deploy script
#   bash /path/to/deploy-gate-snippet.sh --skip-workflow-check  # bypass
#
# The script reads .silver-bullet.json (walking up from $PWD) for config.
# If no config is found it falls back to sensible defaults.
#
# Note: Uses return (not exit) so sourcing doesn't kill the caller's shell. A blocked
# gate returns 1 to the caller, so always guard the source with `|| exit 1` (or
# `|| handle`): a bare `source` under the caller's own `set -e` would abort it, and
# without `set -e` the caller would carry on and deploy. Sourcing leaves the caller's
# shell options, ERR trap and umask untouched.
# When run standalone, bash treats return outside a function as exit.
###############################################################################

# --- Resolve .silver-bullet.json by walking up from $PWD ---
_dw_config_file=""
_dw_search_dir="$PWD"
while true; do
  if [[ -f "$_dw_search_dir/.silver-bullet.json" ]]; then
    _dw_config_file="$_dw_search_dir/.silver-bullet.json"
    break
  fi
  # Stop at .git boundary or filesystem root
  if [[ -d "$_dw_search_dir/.git" ]] || [[ "$_dw_search_dir" == "/" ]]; then
    break
  fi
  _dw_search_dir=$(dirname "$_dw_search_dir")
done

if [[ -f "$_repo_root/hooks/lib/trivial-bypass.sh" ]]; then
  # shellcheck source=hooks/lib/trivial-bypass.sh
  source "$_repo_root/hooks/lib/trivial-bypass.sh"
fi

# --- Read config (gracefully degrade if jq is absent) ---
_SB_STATE_DIR="${SB_RUNTIME_STATE_DIR:-}"
STATE_FILE="${_SB_STATE_DIR}/state"
TRIVIAL_FILE="${_SB_STATE_DIR}/trivial"
_DEFAULT_STATE_FILE="$STATE_FILE"
_DEFAULT_TRIVIAL_FILE="$TRIVIAL_FILE"
REQUIRED_DEPLOY="silver-quality-gates silver-context silver-plan silver-execute silver-verify silver-ship silver-review security silver-secure silver-validate silver-review-request silver-review-triage silver-triage silver-branch-finish silver-completion-audit tdd verify-tests"
[[ -n "${DEFAULT_REQUIRED:-}" ]] && REQUIRED_DEPLOY="$DEFAULT_REQUIRED"

if [[ -n "$_dw_config_file" ]] && command -v jq >/dev/null 2>&1; then
  # Config paths are repository content: they get the same expansion and state-directory check the hooks
  # apply (R1-24, R1-25), so the shipped template's ${SB_RUNTIME_HOME_ROOT}/... spelling resolves to the
  # real files and a path outside the state directory falls back to the defaults.
  _val=$(jq -r '.state.state_file // ""' "$_dw_config_file")
  if [[ -n "$_val" ]]; then
    _val="$(sb_expand_state_config_path "$_val")"
    ! sb_runtime_path_is_state_scoped "$_val" || STATE_FILE="$_val"
  fi

  _val=$(jq -r '.state.trivial_file // ""' "$_dw_config_file")
  if [[ -n "$_val" ]]; then
    _val="$(sb_expand_state_config_path "$_val")"
    ! sb_trivial_path_trusted "$_val" "$_DEFAULT_TRIVIAL_FILE" || TRIVIAL_FILE="$_val"
  fi

  _val=$(jq -r '(.skills.required_deploy // []) | join(" ")' "$_dw_config_file")
  if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
    REQUIRED_DEPLOY="$(sb_required_skills_normalize_configured_list "$_dw_config_file" "$_val" "$REQUIRED_DEPLOY")"
  elif [[ -n "$_val" ]]; then
    REQUIRED_DEPLOY="$_val"
  fi
fi

# --- Gate logic ---

# 1. Trivial-change fast path
if [[ -f "$TRIVIAL_FILE" && ! -L "$TRIVIAL_FILE" ]]; then
  echo "[deploy-gate] ℹ️  Trivial change detected — workflow check skipped."
  # Safety: only the default state and trivial files are ever deleted, and only regular files
  [[ "$STATE_FILE" == "$_DEFAULT_STATE_FILE" && -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] && rm -f -- "$STATE_FILE"
  [[ "$TRIVIAL_FILE" == "$_DEFAULT_TRIVIAL_FILE" ]] && rm -f -- "$TRIVIAL_FILE"
  return 0 2>/dev/null || exit 0
fi

# 2. Explicit bypass flag
if [[ "${1:-}" == "--skip-workflow-check" ]]; then
  echo "[deploy-gate] ⚠️  Workflow check bypassed via --skip-workflow-check."
  return 0 2>/dev/null || exit 0
fi

# 3. State file must exist
if [[ ! -f "$STATE_FILE" ]]; then
  echo "[deploy-gate] ❌ No workflow state file found at $STATE_FILE."
  echo "    Did you run through the Silver Bullet workflow skills before deploying?"
  return 1 2>/dev/null || exit 1
fi

# 4. Check required skills (same rules as the hook: branch finishing does not apply on main/master,
#    and recorded skills may match through aliases)
_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
_missing=()
for _skill in $REQUIRED_DEPLOY; do
  if [[ "$_branch" == "main" || "$_branch" == "master" ]]; then
    case "$_skill" in finishing-a-development-branch | silver-branch-finish) continue ;; esac
  fi
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$(<"$STATE_FILE")" "$_skill" && continue
  elif grep -Fqx -- "$_skill" "$STATE_FILE" 2>/dev/null; then
    continue
  fi
  _missing+=("$_skill")
done

if [[ ${#_missing[@]} -gt 0 ]]; then
  echo "[deploy-gate] ❌ Missing required workflow skills:"
  for _m in "${_missing[@]}"; do
    echo "    - $_m"
  done
  echo "    Complete these skills before deploying."
  return 1 2>/dev/null || exit 1
fi

# 5. All clear
echo "[deploy-gate] ✅ All required workflow skills completed. Proceeding with deploy."
[[ "$STATE_FILE" == "$_DEFAULT_STATE_FILE" ]] && rm -f -- "$STATE_FILE"
[[ "$TRIVIAL_FILE" == "$_DEFAULT_TRIVIAL_FILE" ]] && rm -f -- "$TRIVIAL_FILE"
return 0 2>/dev/null || exit 0

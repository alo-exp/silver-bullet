#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# Security: restrict file creation permissions (user-only)
umask 0077

###############################################################################
# Deploy Gate Snippet — Silver Bullet
#
# Copy-paste this snippet into your deploy / CI script to block deployment
# unless all required workflow skills were invoked during the current session.
#
# Usage:
#   bash /path/to/deploy-gate-snippet.sh             # standalone (recommended)
#   source /path/to/deploy-gate-snippet.sh           # sourced in deploy script
#   bash /path/to/deploy-gate-snippet.sh --skip-workflow-check  # bypass
#
# The script reads .silver-bullet.json (walking up from $PWD) for config.
# If no config is found it falls back to sensible defaults.
#
# Note: Uses return (not exit) so sourcing doesn't kill the caller's shell.
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

# --- Read config (gracefully degrade if jq is absent) ---
_SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
STATE_FILE="${_SB_STATE_DIR}/state"
TRIVIAL_FILE="${_SB_STATE_DIR}/trivial"
REQUIRED_DEPLOY="silver-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt"

if [[ -n "$_dw_config_file" ]] && command -v jq >/dev/null 2>&1; then
  _val=$(jq -r '.state.state_file // ""' "$_dw_config_file")
  [[ -n "$_val" ]] && STATE_FILE="${_val/#\~/$HOME}"

  _val=$(jq -r '.state.trivial_file // ""' "$_dw_config_file")
  [[ -n "$_val" ]] && TRIVIAL_FILE="${_val/#\~/$HOME}"

  _val=$(jq -r '(.skills.required_deploy // []) | join(" ")' "$_dw_config_file")
  [[ -n "$_val" ]] && REQUIRED_DEPLOY="$_val"
fi

# --- Gate logic ---

# 1. Trivial-change fast path
if [[ -f "$TRIVIAL_FILE" && ! -L "$TRIVIAL_FILE" ]]; then
  echo "[deploy-gate] ℹ️  Trivial change detected — workflow check skipped."
  # Safety: only delete regular files (not symlinks)
  [[ -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] && rm -f -- "$STATE_FILE"
  rm -f -- "$TRIVIAL_FILE"
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

# 4. Check required skills
_missing=()
for _skill in $REQUIRED_DEPLOY; do
  if ! grep -qx "$_skill" "$STATE_FILE" 2>/dev/null; then
    _missing+=("$_skill")
  fi
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
rm -f -- "$STATE_FILE" "$TRIVIAL_FILE"
return 0 2>/dev/null || exit 0

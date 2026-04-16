#!/usr/bin/env bash
set -euo pipefail

# Stop hook (event: Stop)
# Fires when Claude outputs a final response (declaring task complete).
# Blocks if required_deploy skills are missing from the state file.
#
# Exit format: {"decision":"block","reason":"..."} to block completion.
# Silent exit 0 to allow completion.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  exit 0
fi

# Read JSON from stdin (consumed per hook protocol; content not used by stop-check)
cat >/dev/null

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  stop-check.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Resolve config file by walking up from $PWD ──────────────────────────────
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

# No config → project not set up with Silver Bullet — silent exit
[[ -z "$config_file" ]] && exit 0

# ── Read config values ────────────────────────────────────────────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_deploy // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle")
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '3p')
active_workflow=$(printf '%s' "$config_vals" | sed -n '4p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate paths stay within ~/.claude/ (SB-002/SB-003)
case "$state_file" in
  "$HOME"/.claude/*) ;;
  *) state_file="${SB_STATE_DIR}/state" ;;
esac
case "$trivial_file" in
  "$HOME"/.claude/*) ;;
  *) trivial_file="${SB_STATE_DIR}/trivial" ;;
esac

# ── Resolve lib dir (needed for trivial-bypass and required-skills helpers) ───
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

# ── Trivial bypass (sourced from shared helper — REF-01) ────────────────────
# shellcheck source=lib/trivial-bypass.sh
if [[ -f "$_lib_dir/trivial-bypass.sh" ]]; then
  # shellcheck disable=SC1090
  source "$_lib_dir/trivial-bypass.sh"
  sb_trivial_bypass "$trivial_file"
fi

# ── Detect current git branch ─────────────────────────────────────────────────
current_branch=""
current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
# Validate branch name: only allow safe characters
if [[ -n "$current_branch" ]] && ! printf '%s' "$current_branch" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
  current_branch=""
fi
on_main=false
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  on_main=true
fi

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

# HOOK-04: empty state file means no skills were tracked — non-dev session — skip enforcement
[[ -z "$state_contents" ]] && exit 0

# ── Build required skills list (Tier 2: full required_deploy list) ────────────
# Source canonical required-skills list (single source of truth — TD-01 fix)
# shellcheck source=lib/required-skills.sh
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck disable=SC1090
  source "$_lib_dir/required-skills.sh"
else
  # Fallback if lib not found (should not happen in correct installs)
  DEFAULT_REQUIRED="silver-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt review-loop-pass-1 review-loop-pass-2"
  DEVOPS_DEFAULT_REQUIRED="silver-blast-radius devops-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt review-loop-pass-1 review-loop-pass-2"
fi

# DevOps workflow substitutes silver-quality-gates with silver-blast-radius + devops-quality-gates
if [[ "$active_workflow" == "devops-cycle" ]]; then
  DEFAULT_REQUIRED="$DEVOPS_DEFAULT_REQUIRED"
fi

# When on main/master branch, finishing-a-development-branch is not applicable
if [[ "$on_main" == true ]]; then
  DEFAULT_REQUIRED=$(printf '%s' "$DEFAULT_REQUIRED" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
  required_deploy_cfg=$(printf '%s' "$required_deploy_cfg" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
fi

# When config supplies required_deploy, it is the sole source of truth.
# When config is absent, fall back to DEFAULT_REQUIRED from required-skills.sh.
if [[ -n "$required_deploy_cfg" ]]; then
  all_skills="$required_deploy_cfg"
else
  all_skills="$DEFAULT_REQUIRED"
fi

# Deduplicate
required_skills=""
for skill in $all_skills; do
  already=false
  for existing in $required_skills; do
    if [[ "$existing" == "$skill" ]]; then
      already=true
      break
    fi
  done
  if [[ "$already" == false ]]; then
    required_skills="${required_skills:+$required_skills }$skill"
  fi
done

# ── Check required skills ─────────────────────────────────────────────────────
missing=""
for skill in $required_skills; do
  if ! printf '%s\n' "$state_contents" | grep -qx "$skill" 2>/dev/null; then
    missing="${missing:+$missing }$skill"
  fi
done

# ── Output result ─────────────────────────────────────────────────────────────
if [[ -n "$missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  - ${skill}\n"
  done
  reason=$(printf 'Cannot complete -- missing required skills:\n%s\nRun these skills before declaring task complete.' "$missing_lines")
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
fi

exit 0

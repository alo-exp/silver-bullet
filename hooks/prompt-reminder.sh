#!/usr/bin/env bash
set -euo pipefail

# UserPromptSubmit hook
# Fires before every user prompt is processed.
# Injects a compact Silver Bullet compliance reminder into additionalContext.
#
# Must be FAST (< 200ms) — no git operations, no stdin blocking, single jq call.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — exit silently if missing (don't slow down prompts with warnings)
command -v jq >/dev/null 2>&1 || exit 0

# DO NOT read stdin — UserPromptSubmit hooks must not block on stdin for speed.

# ── Error trap: on any failure, exit 0 silently ───────────────────────────────
trap 'exit 0' ERR

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

# ── Read config values (single jq call for speed) ────────────────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_deploy // []) | join(" "))
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '3p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate paths stay within ~/.claude/
case "$state_file" in
  "$HOME"/.claude/*) ;;
  *) state_file="${SB_STATE_DIR}/state" ;;
esac
case "$trivial_file" in
  "$HOME"/.claude/*) ;;
  *) trivial_file="${SB_STATE_DIR}/trivial" ;;
esac

# ── Trivial bypass (reject symlinks) ─────────────────────────────────────────
if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
  exit 0
fi

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

# ── Build required skills list ────────────────────────────────────────────────
if [[ -n "$required_deploy_cfg" ]]; then
  required_skills="$required_deploy_cfg"
else
  required_skills="quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist create-release verification-before-completion test-driven-development tech-debt"
fi

# ── Compute missing skills ────────────────────────────────────────────────────
missing_list=""
total=0
completed=0
for skill in $required_skills; do
  total=$((total + 1))
  if printf '%s\n' "$state_contents" | grep -qx "$skill" 2>/dev/null; then
    completed=$((completed + 1))
  else
    missing_list="${missing_list:+$missing_list, }${skill}"
  fi
done

# ── Emit additionalContext ────────────────────────────────────────────────────
if [[ -z "$missing_list" ]]; then
  msg="Silver Bullet: all required skills complete."
else
  msg="Silver Bullet -- Missing: ${missing_list} (${completed} of ${total} complete)"
fi

printf '{"hookSpecificOutput":{"additionalContext":%s}}' "$(printf '%s' "$msg" | jq -Rs '.')"

exit 0

#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Skill)
# Tracks skill invocations to a state file for workflow enforcement.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# Extract skill name
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
[[ -z "$skill" ]] && exit 0

# Strip namespace prefixes (superpowers:, engineering:, design:, context7-plugin:, etc.)
skill=$(printf '%s' "$skill" | sed 's/^[a-zA-Z0-9_-]*://')

# --- Resolve config file by walking up from $PWD ---
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  # Stop at .git boundary or filesystem root
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

# --- State file (env var override first, then config, then default) ---
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR" 2>/dev/null || true
STATE_FILE="${SILVER_BULLET_STATE_FILE:-}"
if [[ -z "$STATE_FILE" && -n "$config_file" ]]; then
  STATE_FILE=$(jq -r '.state.state_file // ""' "$config_file")
  # Expand ~ to $HOME (config stores literal tilde)
  STATE_FILE="${STATE_FILE/#\~/$HOME}"
fi
STATE_FILE="${STATE_FILE:-${SB_STATE_DIR}/state}"

# Security: validate state file path stays within ~/.claude/ (SB-002/SB-003)
case "$STATE_FILE" in
  "$HOME"/.claude/*) ;;
  *) STATE_FILE="${SB_STATE_DIR}/state" ;;
esac

# --- Tracked skills list ---
DEFAULT_TRACKED="quality-gates blast-radius devops-quality-gates devops-skill-router design-system ux-copy architecture system-design code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist create-release"

tracked_list="$DEFAULT_TRACKED"
if [[ -n "$config_file" ]]; then
  custom_tracked=$(jq -r '(.skills.all_tracked // []) | join(" ")' "$config_file")
  if [[ -n "$custom_tracked" ]]; then
    tracked_list="$custom_tracked"
  fi
fi

# --- Check if skill is tracked ---
is_tracked=false
for t in $tracked_list; do
  if [[ "$t" == "$skill" ]]; then
    is_tracked=true
    break
  fi
done

if [[ "$is_tracked" == false ]]; then
  printf '{"hookSpecificOutput":{"message":"ℹ️ Skill not tracked by Silver Bullet: %s"}}' "$skill"
  exit 0
fi

# --- Record skill (no duplicates) ---
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
touch "$STATE_FILE"
if ! grep -qx "$skill" "$STATE_FILE" 2>/dev/null; then
  printf '%s\n' "$skill" >> "$STATE_FILE"
fi

printf '{"hookSpecificOutput":{"message":"✅ Skill recorded: %s"}}' "$skill"

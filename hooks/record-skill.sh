#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Skill)
# Tracks skill invocations to a state file for workflow enforcement.

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ jq not found — record-skill.sh skipped"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# Extract skill name
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
[[ -z "$skill" ]] && exit 0

# Strip namespace prefixes (superpowers:, engineering:, design:, etc.)
skill=$(printf '%s' "$skill" | sed 's/^[a-zA-Z_-]*://')

# --- Resolve config file by walking up from $PWD ---
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.dev-workflows.json" ]]; then
    config_file="$search_dir/.dev-workflows.json"
    break
  fi
  # Stop at .git boundary or filesystem root
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

# --- State file (env var override first, then config, then default) ---
STATE_FILE="${DEV_WORKFLOWS_STATE_FILE:-}"
if [[ -z "$STATE_FILE" && -n "$config_file" ]]; then
  STATE_FILE=$(jq -r '.state.state_file // ""' "$config_file")
fi
STATE_FILE="${STATE_FILE:-/tmp/.dev-workflows-state}"

# --- Tracked skills list ---
DEFAULT_TRACKED="using-superpowers brainstorming write-spec design-system ux-copy architecture system-design writing-plans executing-plans code-review requesting-code-review receiving-code-review testing-strategy systematic-debugging debug tech-debt documentation verification-before-completion finishing-a-development-branch deploy-checklist"

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
  printf '{"hookSpecificOutput":{"message":"ℹ️ Skill not tracked by Dev Workflows: %s"}}' "$skill"
  exit 0
fi

# --- Record skill (no duplicates) ---
touch "$STATE_FILE"
if ! grep -qx "$skill" "$STATE_FILE" 2>/dev/null; then
  printf '%s\n' "$skill" >> "$STATE_FILE"
fi

printf '{"hookSpecificOutput":{"message":"✅ Skill recorded: %s"}}' "$skill"

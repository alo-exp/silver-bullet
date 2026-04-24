#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse hook (matcher: Skill)
# Tracks skill invocations to a state file for workflow enforcement.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source symlink-write guard (SEC-02)
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/nofollow-guard.sh" ]]; then
  # shellcheck source=lib/nofollow-guard.sh
  source "$_lib_dir/nofollow-guard.sh"
else
  sb_guard_nofollow() { [[ -L "$1" ]] && { printf 'ERROR: refusing to write through symlink: %s\n' "$1" >&2; exit 1; }; return 0; }
  sb_safe_write()    { [[ -L "$1" ]] && rm -f -- "$1"; return 0; }
fi

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

# GSD commands (gsd:discuss-phase, gsd:plan-phase, etc.) are tracked with gsd- prefix
# Other namespace prefixes (superpowers:, engineering:, design:, etc.) are stripped.
# Greedy loop strips ALL namespace prefixes (handles double-namespace: outer:inner:skill-name).
if printf '%s' "$skill" | grep -qE '^gsd:'; then
  skill=$(printf '%s' "$skill" | sed 's/^gsd:/gsd-/')
else
  while printf '%s' "$skill" | grep -qE '^[a-zA-Z0-9_-]+:'; do
    skill=$(printf '%s' "$skill" | sed 's/^[a-zA-Z0-9_-]*://')
  done
fi

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
# GSD command phases (tracked as gsd-* markers for compliance visibility)
# These are recorded when /gsd:* commands fire via the Skill tool
DEFAULT_TRACKED="silver-quality-gates silver-blast-radius devops-quality-gates devops-skill-router design-system ux-copy architecture system-design code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt gsd-new-project gsd-new-milestone gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-verify-work gsd-ship gsd-debug gsd-ui-phase gsd-ui-review gsd-secure-phase"

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
  printf '{"hookSpecificOutput":{"message":%s}}' "$(printf 'ℹ️ Skill not tracked by Silver Bullet: %s' "$skill" | jq -Rs '.')"
  exit 0
fi

# --- Record skill (no duplicates) ---
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
# SEC-02: refuse to write through a symlink at STATE_FILE
sb_guard_nofollow "$STATE_FILE"
touch -- "$STATE_FILE"
if ! grep -qx "$skill" "$STATE_FILE" 2>/dev/null; then
  printf '%s\n' "$skill" >> "$STATE_FILE"
fi

printf '{"hookSpecificOutput":{"message":"✅ Skill recorded: %s"}}' "$skill"

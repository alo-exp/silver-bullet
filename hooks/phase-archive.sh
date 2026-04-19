#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"phase-archive: archive failed — blocking clear to prevent data loss\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Bash)
# Intercepts gsd-tools.cjs phases clear before it runs.
# Archives all current phase directories to .planning/archive/{milestone}/ so
# they are preserved after the clear completes.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# Extract command from Bash tool input
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Only trigger on gsd-tools phases clear commands
if ! printf '%s' "$cmd" | grep -qE 'gsd-tools[^"]*phases\s+clear'; then
  exit 0
fi

# Locate PROJECT.md to read the current milestone slug
PROJECT_MD=".planning/PROJECT.md"
if [[ ! -f "$PROJECT_MD" ]]; then
  # No PROJECT.md — exit silently and allow the clear to proceed
  exit 0
fi

# Read milestone name from "Current Milestone:" line, convert to slug
milestone_line=$(grep "Current Milestone:" "$PROJECT_MD" || true)
if [[ -z "$milestone_line" ]]; then
  exit 0
fi

# Extract the value after the colon, trim whitespace, lowercase, replace spaces with hyphens
milestone_raw=$(printf '%s' "$milestone_line" | sed 's/.*Current Milestone:[[:space:]]*//' | sed 's/[[:space:]]*$//')
milestone_slug=$(printf '%s' "$milestone_raw" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9._-')

if [[ -z "$milestone_slug" ]]; then
  exit 0
fi

PHASES_DIR=".planning/phases"
ARCHIVE_DIR=".planning/archive/${milestone_slug}"

# No phases to archive — exit silently
if [[ ! -d "$PHASES_DIR" ]] || [[ -z "$(ls -A "$PHASES_DIR" 2>/dev/null)" ]]; then
  exit 0
fi

# Create archive destination
mkdir -p "$ARCHIVE_DIR"

# Copy all phase directories (cp -r preserves structure; clear runs after we exit 0)
# Skip if archive already exists (avoid overwriting prior archive on repeated runs)
if [[ -n "$(ls -A "$ARCHIVE_DIR" 2>/dev/null)" ]]; then
  msg=$(printf 'Phase archive: .planning/archive/%s/ already exists — skipping to avoid overwrite.' "$milestone_slug" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"message":%s}}' "$msg"
  exit 0
fi

for phase_dir in "$PHASES_DIR"/*/; do
  [[ -d "$phase_dir" ]] || continue
  phase_name=$(basename "$phase_dir")
  cp -r "$phase_dir" "$ARCHIVE_DIR/${phase_name}"
done

msg=$(printf 'Phase archive: copied phases to .planning/archive/%s/ before clear.' "$milestone_slug" | jq -Rs '.')
printf '{"hookSpecificOutput":{"message":%s}}' "$msg"

# Exit 0 — let the original clear command proceed
exit 0

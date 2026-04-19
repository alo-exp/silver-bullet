#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Skill)
# Blocks invocation of forbidden skills that bypass Silver Bullet enforcement.
#
# Forbidden skills (hardcoded):
#   - executing-plans
#   - subagent-driven-development
# Also blocks skills listed in .silver-bullet.json skills.forbidden array.
#
# Output format: {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
# Silent exit 0 to allow the skill.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  forbidden-skill-check.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Extract skill name from tool input ───────────────────────────────────────
raw_skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
[[ -z "$raw_skill" ]] && exit 0

# Strip all namespace prefixes (e.g. "outer:inner:executing-plans" → "executing-plans")
# Threat T-07-01: greedy strip prevents double-namespace bypass (SENTINEL finding)
skill_name="$raw_skill"
while [[ "$skill_name" == *:* ]]; do
  skill_name="${skill_name#*:}"
done

# Invariant: if raw_skill was non-empty but contained only colons, skill_name
# is now empty. Empty skill_name safely matches no forbidden entry.
[[ -z "$skill_name" ]] && exit 0

# ── Hardcoded forbidden list ──────────────────────────────────────────────────
FORBIDDEN_HARDCODED="executing-plans subagent-driven-development"

# ── Read configurable forbidden list from .silver-bullet.json ────────────────
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

forbidden_cfg=""
if [[ -n "$config_file" ]]; then
  forbidden_cfg=$(jq -r '(.skills.forbidden // []) | .[]' "$config_file" 2>/dev/null || true)
fi

# ── Check against hardcoded forbidden list ────────────────────────────────────
for entry in $FORBIDDEN_HARDCODED; do
  if [[ "$skill_name" == "$entry" ]]; then
    reason="FORBIDDEN SKILL — ${skill_name} is blocked by Silver Bullet. Use /gsd:execute-phase for execution and /gsd:plan-phase for planning. See silver-bullet.md section 6."
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    exit 0
  fi
done

# ── Check against configurable forbidden list ─────────────────────────────────
if [[ -n "$forbidden_cfg" ]]; then
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$skill_name" == "$entry" ]]; then
      reason="FORBIDDEN SKILL -- ${skill_name} is blocked by project configuration. See .silver-bullet.json skills.forbidden."
      json_reason=$(printf '%s' "$reason" | jq -Rs '.')
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
      exit 0
    fi
  done <<< "$forbidden_cfg"
fi

# Skill is not forbidden — allow
exit 0

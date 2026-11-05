#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Skill|Bash|exec_command — the Skill tool and the Codex invoke-skill adapter)
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

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in jq-gate.sh sb-project-gate.sh; do
  if [[ -f "$_lib_dir/$_lib" ]]; then
    # shellcheck source=/dev/null
    source "$_lib_dir/$_lib"
  fi
done

emit_block_jq_missing() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.' 2>/dev/null || printf '"jq required for Silver Bullet enforcement"')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

if declare -f sb_jq_enforcement_block_sb_initiated >/dev/null 2>&1; then
  sb_jq_enforcement_block_sb_initiated "forbidden-skill-check" "emit_block_jq_missing"
elif ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  exit 0
fi

if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit
fi

# Read JSON from stdin
input=$(cat)

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  forbidden-skill-check.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

deny() {
  local json_reason
  json_reason=$(printf '%s' "$1" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  exit 0
}

# ── Which skills does this call invoke? (Skill tool, or the Codex invoke-skill adapter) ──────
# Unparsable input is an unexpected error (the trap warns), as it always was.
printf '%s' "$input" | jq -e . >/dev/null
if [[ -f "$_lib_dir/skill-channel.sh" ]]; then
  # shellcheck source=lib/skill-channel.sh
  source "$_lib_dir/skill-channel.sh"
  sb_skill_channel_load "$input"
else
  # Without the channel lib the Skill tool's own field is still enforced.
  SB_SKILL_CHANNEL_NAMES="$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')"
  SB_SKILL_CHANNEL_STATUS="ok"
fi
if [[ "$SB_SKILL_CHANNEL_STATUS" == "helper_unavailable" ]]; then
  deny "$(sb_shell_analysis_helper_message)"
fi
[[ -n "$SB_SKILL_CHANNEL_NAMES" ]] || exit 0

# ── Config: configurable forbidden list ───────────────────────────────────────
FORBIDDEN_HARDCODED="executing-plans subagent-driven-development"
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
forbidden_cfg=""
if [[ -n "$config_file" ]]; then
  forbidden_cfg=$(jq -r '(.skills.forbidden // []) | .[]' "$config_file" 2>/dev/null || true)
fi

_SB_RETIRED_NS=$(printf '%s%s' gs d)

while IFS= read -r raw_skill; do
  [[ -n "$raw_skill" ]] || continue
  # Normalise before every comparison (R2-17): trim, lower-case, then look at EVERY namespace
  # segment, so `Executing-Plans`, ` executing-plans ` and `marketplace:gsd-execute-phase` match.
  norm="$(printf '%s' "$raw_skill" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$norm" ]] || continue
  skill_name="${norm##*:}"
  rest="$norm"
  while [[ -n "$rest" ]]; do
    segment="${rest%%:*}"
    if [[ "$rest" == *:* ]]; then rest="${rest#*:}"; else rest=""; fi
    # Block retired GSD namespace (removed from SB runtime).
    if [[ "$segment" == "$_SB_RETIRED_NS" || "$segment" == "${_SB_RETIRED_NS}-"* ]]; then
      deny "FORBIDDEN SKILL — ${raw_skill} is blocked. GSD lifecycle skills were removed from Silver Bullet. Use /sb routing and SB-owned skills (sb:context, sb:plan, sb:execute, sb:verify, sb:ship). See silver-bullet.md."
    fi
  done
  # Invariant: a skill that is only colons leaves skill_name empty, which matches no entry.
  [[ -n "$skill_name" ]] || continue

  for entry in $FORBIDDEN_HARDCODED; do
    if [[ "$skill_name" == "$entry" ]]; then
      deny "FORBIDDEN SKILL — ${skill_name} is blocked by Silver Bullet. Use /sb:execute for execution and /sb:plan for planning. See silver-bullet.md section 6."
    fi
  done

  if [[ -n "$forbidden_cfg" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      if [[ "$skill_name" == "$(printf '%s' "$entry" | tr '[:upper:]' '[:lower:]')" ]]; then
        deny "FORBIDDEN SKILL -- ${skill_name} is blocked by project configuration. See .silver-bullet.json skills.forbidden."
      fi
    done <<< "$forbidden_cfg"
  fi
done <<< "$SB_SKILL_CHANNEL_NAMES"

# Skill is not forbidden — allow
exit 0

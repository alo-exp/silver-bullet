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

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in jq-gate.sh sb-project-gate.sh planning-floor.sh; do
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
  printf '{"systemMessage":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}'
  exit 0
fi

if declare -f sb_project_gate_or_exit >/dev/null 2>&1; then
  sb_project_gate_or_exit
fi

if ! declare -f sb_pf_skill_calls >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Silver Bullet hook libraries are missing (hooks/lib/planning-floor.sh). Reinstall the plugin."}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'sb_emit_hook_message PreToolUse "⚠️  forbidden-skill-check.sh: unexpected error — skipping check"; exit 0' ERR

hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PreToolUse"')

emit_block() {
  sb_emit_hook_decision "$hook_event" deny "$1"
}

# ── Extract the invoked skill(s): the Skill tool, or the Codex invoke-skill adapter ──────────
rc=0
sb_pf_skill_calls "$input" raw || rc=$?
[[ "$rc" -eq 1 ]] && exit 0
if [[ "$rc" -eq 2 ]]; then
  emit_block "$(sb_pf_unanalysable_message)"
  exit 0
fi

_SB_RETIRED_NS_COLON=$(printf '%s%s:' gs d)
_SB_RETIRED_NS_HYPHEN=$(printf '%s%s-' gs d)

# ── Hardcoded forbidden list ──────────────────────────────────────────────────
FORBIDDEN_HARDCODED="executing-plans subagent-driven-development"

# ── Read configurable forbidden list from .silver-bullet.json ────────────────
config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
forbidden_cfg=""
if [[ -n "$config_file" ]]; then
  forbidden_cfg=$(jq -r '(.skills.forbidden // []) | .[]' "$config_file" 2>/dev/null || true)
fi

check_skill() {
  local raw_skill="$1" skill_name entry reason segment norm
  [[ -z "$raw_skill" ]] && return 0

  # R2-17: compare trimmed and lower-cased, and look at EVERY namespace segment, so
  # `Executing-Plans`, ` executing-plans ` and `marketplace:gsd-execute-phase` are caught.
  norm="$(printf '%s' "$raw_skill" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$norm" ]] || return 0
  local segments
  IFS=':' read -r -a segments <<<"$norm"
  for segment in "${segments[@]}"; do
    # Block retired GSD namespace (removed from SB runtime).
    if [[ "$segment" == "${_SB_RETIRED_NS_COLON%:}" || "$segment" == ${_SB_RETIRED_NS_HYPHEN}* ]]; then
      emit_block "FORBIDDEN SKILL — ${raw_skill} is blocked. GSD lifecycle skills were removed from Silver Bullet. Use /sb routing and SB-owned skills (sb:context, sb:plan, sb:execute, sb:verify, sb:ship). See silver-bullet.md."
      exit 0
    fi
  done
  raw_skill="$norm"

  # Strip all namespace prefixes (e.g. "outer:inner:executing-plans" → "executing-plans")
  # Threat T-07-01: greedy strip prevents double-namespace bypass (SENTINEL finding)
  skill_name="$raw_skill"
  while [[ "$skill_name" == *:* ]]; do
    skill_name="${skill_name#*:}"
  done

  # Invariant: if raw_skill was non-empty but contained only colons, skill_name
  # is now empty. Empty skill_name safely matches no forbidden entry.
  [[ -z "$skill_name" ]] && return 0

  # ── Check against hardcoded forbidden list ──────────────────────────────────
  for entry in $FORBIDDEN_HARDCODED; do
    if [[ "$skill_name" == "$entry" ]]; then
      reason="FORBIDDEN SKILL — ${skill_name} is blocked by Silver Bullet. Use /sb:execute for execution and /sb:plan for planning. See silver-bullet.md section 6."
      emit_block "$reason"
      exit 0
    fi
  done

  # ── Check against configurable forbidden list ───────────────────────────────
  if [[ -n "$forbidden_cfg" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      entry="$(printf '%s' "$entry" | tr '[:upper:]' '[:lower:]')"
      if [[ "$skill_name" == "$entry" ]]; then
        emit_block "FORBIDDEN SKILL -- ${skill_name} is blocked by project configuration. See .silver-bullet.json skills.forbidden."
        exit 0
      fi
    done <<< "$forbidden_cfg"
  fi
}

while IFS= read -r skill; do
  check_skill "$skill"
done <<<"$SB_PF_SKILLS"

# Skill is not forbidden — allow
exit 0

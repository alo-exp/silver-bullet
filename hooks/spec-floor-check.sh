#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Bash|Skill)
# Enforces spec floor — hard-blocks silver:plan without a minimum viable SPEC.md,
# and emits an advisory warning for silver:fast when no spec exists. silver:*
# routes normalize via hooks/lib/skill-discovery.sh.

# Security: restrict file creation permissions (user-only)
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/skill-discovery.sh" ]]; then
  # shellcheck source=lib/skill-discovery.sh
  source "$_lib_dir/skill-discovery.sh"
fi
# jq is required for JSON parsing
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "spec-floor-check"
fi

# Read JSON from stdin
input=$(cat)
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi

# Detect hook event type (PreToolUse vs PostToolUse)
hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"')

# Emit a block in the correct format for the hook event type
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

# Extract command/skill intent from tool input. For Bash, only inspect the
# first shell command token from the first line; never match heredoc bodies,
# comments, prose, or read-only paths that merely contain a skill name.
if declare -f sb_tool_name >/dev/null 2>&1; then
  tool_name="$(sb_tool_name "$input")"
else
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
fi
cmd=""
skill=""
if [[ "$tool_name" == "Skill" ]]; then
  skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
  if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
    skill="$(sb_skill_canonical_name "$skill")"
  fi
else
  if declare -f sb_tool_is_shell_like >/dev/null 2>&1; then
    sb_tool_is_shell_like "$tool_name" || exit 0
  fi
  if declare -f sb_tool_command_string >/dev/null 2>&1; then
    raw_cmd="$(sb_tool_command_string "$input")"
  else
    raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
  fi
  [[ -z "$raw_cmd" ]] && exit 0
  cmd_first_line=$(printf '%s' "$raw_cmd" | sed -n '1p')
  # Strip leading env assignments and common shell wrappers.
  cmd=$(printf '%s' "$cmd_first_line" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*//; s/^(command|exec)[[:space:]]+//; s/[[:space:]].*$//')
  # Read-only inspection commands may search for skill names as text. Do not
  # treat those string arguments as invocations.
  case "$cmd" in
    rg|grep|egrep|fgrep|sed|awk|cat|nl|head|tail|find|ls|jq|git)
      exit 0
      ;;
  esac
fi

# Detect command type — is this silver:plan or silver:fast?
is_plan_phase=false
is_fast=false

case "$skill" in
  silver-plan)
    is_plan_phase=true
    ;;
  silver-fast)
    is_fast=true
    ;;
esac

if [[ "$is_plan_phase" == false && "$is_fast" == false ]]; then
  case "$cmd" in
    silver-plan)
      is_plan_phase=true
      ;;
    silver-fast)
      is_fast=true
      ;;
  esac
fi

if [[ "$is_plan_phase" == false && "$is_fast" == false ]]; then
  # Allow direct slash-style strings as a defensive fallback, but only when the
  # first shell token itself is the route. This avoids blocking file paths
  # that contain skill names as text substrings.
  case "$cmd" in
    /silver:plan|/silver-plan)
      is_plan_phase=true
      ;;
    /silver:fast|/silver-fast)
      is_fast=true
      ;;
  esac
  # silver:* slash routes (normalized at cmd token)
  if [[ "$is_plan_phase" == false && "$is_fast" == false ]] && declare -F sb_skill_canonical_name >/dev/null 2>&1; then
    _norm_cmd="$(sb_skill_canonical_name "${cmd#/}")"
    case "$_norm_cmd" in
      silver-plan) is_plan_phase=true ;;
      silver-fast) is_fast=true ;;
    esac
  fi
fi

if [[ "$is_plan_phase" == true ]]; then
  is_plan_phase=true
elif [[ "$is_fast" == true ]]; then
  is_fast=true
fi

# Exit early if neither pattern matched
[[ "$is_plan_phase" == false && "$is_fast" == false ]] && exit 0

# ── Composition opt-out check (Pass 1: deferred) ─────────────────────────────
# The legacy single-file WORKFLOW.md was retired (see completion-audit.sh
# for full rationale). v0.29.x replaces it with per-instance
# `.planning/workflows/<id>.md` files. Until Pass 2 lands, the spec floor
# always applies as the safe default — the previous downgrade-when-PATH-4-
# excluded behavior is unavailable until per-workflow composition tracking
# is rebuilt. Composers that legitimately exclude PATH 4 can still
# bypass via `--skip-spec` flags on their direct invocations.

SPEC=".planning/SPEC.md"
FAST_SPEC=".planning/SPEC.fast.md"

if [[ "$is_plan_phase" == true ]]; then
  # HARD BLOCK: SPEC.md must exist with required sections
  if [[ ! -f "$SPEC" ]]; then
    emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing. Run /silver:spec before planning. silver:plan requires a minimum viable spec."
    exit 0
  fi
  for section in "## Overview" "## Acceptance Criteria"; do
    if ! grep -qE "^${section}[[:space:]]*$" "$SPEC"; then
      emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing required section: ${section}. Run /silver:spec to complete the spec before planning."
      exit 0
    fi
  done
fi

if [[ "$is_fast" == true ]]; then
  # WARNING ONLY: emit advisory, do not block
  if [[ ! -f "$SPEC" && ! -f "$FAST_SPEC" ]]; then
    printf '{"hookSpecificOutput":{"message":"⚠️  SPEC FLOOR ADVISORY: No .planning/SPEC.md found. Fast path proceeding without spec floor. For tracked work, run /silver:spec first."}}'
  fi
fi

exit 0

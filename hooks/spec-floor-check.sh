#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Bash|exec_command|Skill)
# Enforces spec floor — hard-blocks sb:plan without a minimum viable SPEC.md,
# and emits an advisory warning for sb:fast when no spec exists.
#
# The skill is read from the real invocation channels: the Skill tool (Claude) and the
# `scripts/silver-bullet invoke-skill <skill>` adapter (Codex), through the shell analysis,
# so quoting, wrappers and chains cannot hide it and prose that merely names a skill never
# matches. A shell command literally named silver-plan or /sb:plan is still honoured.

# Security: restrict file creation permissions (user-only)
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# jq is required for JSON parsing
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_active_or_exit
fi
if [[ -f "$_lib_dir/planning-floor.sh" ]]; then
  # shellcheck source=lib/planning-floor.sh
  source "$_lib_dir/planning-floor.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "spec-floor-check"
fi

# Read JSON from stdin
input=$(cat)

hook_event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null || echo PostToolUse)

emit_block() {
  sb_emit_hook_decision "$hook_event" deny "$1"
}

is_plan_phase=false
is_fast=false
note_skill() {
  case "$1" in
    silver-plan) is_plan_phase=true ;;
    silver-fast) is_fast=true ;;
  esac
}

rc=0
sb_pf_skill_calls "$input" || rc=$?
[[ "$rc" -eq 1 ]] && exit 0
if [[ "$rc" -eq 2 ]]; then
  emit_block "$(sb_pf_unanalysable_message)"
  exit 0
fi
while IFS= read -r skill; do
  [[ -n "$skill" ]] && note_skill "$skill"
done <<<"$SB_PF_SKILLS"

if [[ "${SB_TI_TOOL_KIND:-}" == "shell" && "$is_plan_phase" == false && "$is_fast" == false ]]; then
  # Legacy spelling: the first command word is itself the route (silver-plan, /sb:plan).
  legacy_word="$(printf '%s' "${SB_SA_JSON:-}" | jq -r '.commands[0]?.argv[0]? // empty' 2>/dev/null)"
  legacy_word="${legacy_word#/}"
  if [[ -n "$legacy_word" ]]; then
    note_skill "$legacy_word"
    if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
      note_skill "$(sb_skill_canonical_name "$legacy_word")"
    fi
  fi
fi

# Exit early if neither pattern matched
[[ "$is_plan_phase" == false && "$is_fast" == false ]] && exit 0

project_root="$(sb_find_project_root_walk_only 2>/dev/null || true)"
[[ -n "$project_root" ]] || project_root="$PWD"
SPEC="$project_root/.planning/SPEC.md"
FAST_SPEC="$project_root/.planning/SPEC.fast.md"

if [[ "$is_plan_phase" == true ]]; then
  # HARD BLOCK: SPEC.md must exist with required sections
  if [[ ! -f "$SPEC" ]]; then
    emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing. Run /sb:spec before planning. sb:plan requires a minimum viable spec."
    exit 0
  fi
  for section in "## Overview" "## Acceptance Criteria"; do
    if ! grep -qE "^${section}[[:space:]]*$" "$SPEC"; then
      emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing required section: ${section}. Run /sb:spec to complete the spec before planning."
      exit 0
    fi
  done
fi

if [[ "$is_fast" == true ]]; then
  # WARNING ONLY: emit advisory, do not block
  if [[ ! -f "$SPEC" && ! -f "$FAST_SPEC" ]]; then
    sb_emit_hook_message "$hook_event" "⚠️  SPEC FLOOR ADVISORY: No .planning/SPEC.md found. Fast path proceeding without spec floor. For tracked work, run /sb:spec first."
  fi
fi

exit 0

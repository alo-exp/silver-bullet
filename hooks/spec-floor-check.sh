#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Bash)
# Enforces spec floor — hard-blocks gsd-plan-phase without a minimum viable SPEC.md,
# and emits an advisory warning for gsd-fast/gsd-quick when no spec exists.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

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

# Extract command from Bash tool input
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Detect command type — is this gsd-plan-phase or gsd-fast/gsd-quick?
# Note (ME-03): This hook is registered as a Bash matcher only (see hooks/hooks.json).
# GSD commands invoked via the Skill tool will NOT trigger this hook — only direct
# Bash invocations of gsd-plan-phase match here. This is intentional: the spec floor
# check fires when the user runs gsd-plan-phase as a shell command. Skill-tool
# invocations are handled separately by the workflow gate in dev-cycle-check.sh.
is_plan_phase=false
is_fast=false

if printf '%s' "$cmd" | grep -qwE 'gsd-plan-phase|gsd[- ]plan[- ]phase'; then
  is_plan_phase=true
elif printf '%s' "$cmd" | grep -qwE 'gsd-fast|gsd[- ]fast|gsd[- ]quick'; then
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
    emit_block "SPEC FLOOR VIOLATION: .planning/SPEC.md is missing. Run /silver:spec before planning. gsd-plan-phase requires a minimum viable spec."
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

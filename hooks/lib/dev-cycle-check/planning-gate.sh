#!/usr/bin/env bash
# dev-cycle-check module — auto-split
# --- Read state file and determine stage ---
completed_skills=""
if [[ -f "$state_file" ]]; then
  completed_skills=$(cat "$state_file")
fi

# Helper: check if a skill is in the completed list
dcc_has_skill() {
  if declare -F sb_required_skill_is_recorded >/dev/null 2>&1; then
    sb_required_skill_is_recorded "$completed_skills" "$1"
    return $?
  fi
  printf '%s\n' "$completed_skills" | grep -Fqx -- "$1" 2>/dev/null
}

# --- Check required planning skills ---
missing_skills=""
unavailable_skills=""
for skill in $required_planning; do
  if ! dcc_has_skill "$skill"; then
    if sb_skill_is_installed "$skill"; then
      if [[ -n "$missing_skills" ]]; then
        missing_skills="$missing_skills $skill"
      else
        missing_skills="$skill"
      fi
    else
      if [[ -n "$unavailable_skills" ]]; then
        unavailable_skills="$unavailable_skills $skill"
      else
        unavailable_skills="$skill"
      fi
    fi
  fi
done

# --- Four-stage gate ---
if [[ -n "$missing_skills" ]]; then
  # Stage A: missing planning skills — HARD STOP
  missing_display=""
  for ms in $missing_skills; do
    missing_display="${missing_display}❌ ${ms}"$'\n'
  done
  stage_a_msg=$(printf '🚫 HARD STOP — Planning incomplete. Missing skills:\n%s\nRun the missing planning skills before editing source code.' "$missing_display")
  if [[ -n "$unavailable_skills" ]]; then
    unavailable_display=""
    for us in $unavailable_skills; do
      unavailable_display="${unavailable_display}⚠️ ${us} (not installed anywhere invocable)\n"
    done
    stage_a_msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$stage_a_msg" "$unavailable_display")
  fi
  emit_block "$stage_a_msg"
  exit 0
fi

if [[ -n "$unavailable_skills" ]]; then
  unavailable_display=""
  for us in $unavailable_skills; do
    unavailable_display="${unavailable_display}⚠️ ${us} (not installed anywhere invocable)\n"
  done
  stage_a_msg=$(printf '⚠️ Planning skills not installed anywhere invocable, so they were not enforced:\n%s\nProceeding with source edits.' "$unavailable_display")
  sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "$stage_a_msg" "${file_path:-${command_str:-}}"
  jq -n --arg m "$stage_a_msg" '{"hookSpecificOutput":{"message":$m}}'
  exit 0
fi

# --- Phase skip detection (after HARD STOP so Stage A always fires first) ---
# Derive post-review/finalization skills from config required_deploy; fall back to
# hardcoded defaults. Context/plan/execute/verify/review are normal lifecycle
# lifecycle markers and must not be treated as phase-skip evidence.
finalization_skills="silver-branch-finish silver-create-release silver-completion-audit tdd"
if [[ -n "$config_file" ]]; then
  cfg_finalization=$(jq -r '(.skills.required_deploy // []) | map(select(
    . != "silver-quality-gates"
    and . != "silver-blast-radius"
    and . != "devops-quality-gates"
    and . != "silver-context"
    and . != "silver-plan"
    and . != "silver-execute"
    and . != "silver-verify"
    and . != "silver-review"
    and . != "silver-review-request"
    and . != "silver-review-triage"
    and . != "requesting-code-review"
    and . != "receiving-code-review"
  )) | join(" ")' "$config_file" 2>/dev/null || true)
  [[ -n "$cfg_finalization" ]] && finalization_skills="$cfg_finalization"
fi
has_finalization=false
for fs in $finalization_skills; do
  if dcc_has_skill "$fs"; then
    has_finalization=true
    break
  fi
done

if ! dcc_has_skill "silver-review"; then
  # Stage B: planning done, implementation window open. Code review is a
  # post-implementation/final-delivery gate and must not block execution.
  if [[ "$has_finalization" == true ]]; then
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "Planning verified, but finalization markers exist before silver-review." "${file_path:-${command_str:-}}"
    printf '{"hookSpecificOutput":{"message":"⚠️ Planning verified, but finalization markers exist before silver-review. Source edits are allowed so fixes can proceed; final delivery remains blocked until review/verification gates pass in order."}}'
  else
    sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "Planning verified. Implementation edits allowed." "${file_path:-${command_str:-}}"
    printf '{"hookSpecificOutput":{"message":"✅ Planning verified. Implementation edits allowed. Code review, verification, and finalization remain required before delivery."}}'
  fi
  exit 0
fi

if ! dcc_has_skill "silver-branch-finish"; then
  # Stage C: has silver-review, finalization remaining
  sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "SB code review recorded. Source edits remain allowed." "${file_path:-${command_str:-}}"
  printf '{"hookSpecificOutput":{"message":"✅ SB code review recorded. Source edits remain allowed; finalization, verification, and delivery gates still apply."}}'
  exit 0
fi

# Stage D: all phases complete
sb_hook_audit_record "dev-cycle-check" "$hook_event" "allow" "All workflow phases complete. Proceed freely." "${file_path:-${command_str:-}}"
printf '{"hookSpecificOutput":{"message":"✅ All workflow phases complete. Proceed freely."}}'
exit 0

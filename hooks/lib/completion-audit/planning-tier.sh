#!/usr/bin/env bash
# completion-audit: TIER 1 intermediate commit gate
ca_run_planning_tier_gate() {
  # Determine planning skills required for intermediate commits
  # DevOps workflow requires silver-blast-radius + devops-quality-gates instead of silver-quality-gates
  # DEFAULT_PLANNING populated by required-skills.sh (sourced at top).
  default_planning="${DEFAULT_PLANNING:-${__SB_RS_PLANNING_FALLBACK:-silver-quality-gates silver-context silver-plan}}"
  if [[ "$active_workflow" == "devops-cycle" ]]; then
    default_planning="${DEVOPS_DEFAULT_PLANNING:-${__SB_RS_DEVOPS_PLANNING_FALLBACK:-silver-blast-radius devops-quality-gates silver-context silver-plan}}"
  fi
  if [[ "$active_workflow" == "devops-cycle" && -n "$required_planning_devops_cfg" ]]; then
    configured_planning="$required_planning_devops_cfg"
  else
    configured_planning="$required_planning_cfg"
  fi
  if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
    planning_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$configured_planning" "$default_planning")"
  else
    planning_skills="${configured_planning:-$default_planning}"
  fi

  missing_planning=""
  ignored_planning=""
  for skill in $planning_skills; do
    if ! has_skill "$skill"; then
      if sb_skill_is_installed "$skill"; then
        missing_planning="${missing_planning:+$missing_planning }$skill"
      else
        ignored_planning="${ignored_planning:+$ignored_planning }$skill"
      fi
    fi
  done

  if [[ -n "$missing_planning" ]]; then
    missing_lines=""
    for skill in $missing_planning; do
      missing_lines="${missing_lines}  ❌ /${skill}\n"
    done
    msg=$(printf '🚫 COMMIT BLOCKED — Planning incomplete.\n\nYou must complete these planning steps before any commits:\n%s\nRun the missing planning skills first, then commit.' "$missing_lines")
    if [[ -n "$ignored_planning" ]]; then
      ignored_lines=""
      for skill in $ignored_planning; do
        ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
      done
      msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$msg" "$ignored_lines")
    fi
    emit_block "$msg"
    exit 0
  fi

  # VFY-01 plan-boundary: block plan-seal commits without completion-audit since last plan work
  if printf '%s' "$cmd" | grep -qE 'docs\([0-9]+-[0-9]+\): complete'; then
    if ! has_skill "silver-completion-audit"; then
      emit_block "$(printf '🛑 PLAN SEAL BLOCKED — Plan completion commit detected but /silver:completion-audit has not been recorded this session.\n\nRun /silver:completion-audit to verify completion claims, then retry the plan-seal commit.')"
      exit 0
    fi
    # VFY-01 extension (P3): require silver-verify + non-stale VERIFICATION.md
    if ! has_skill "silver-verify"; then
      emit_block "$(printf '🛑 PLAN SEAL BLOCKED — Phase completion requires /silver:verify recorded this session.\n\nRun /silver:verify and refresh VERIFICATION.md before plan-seal commit.')"
      exit 0
    fi
    _pr="$(dirname "$config_file")"
    [[ -z "$_pr" ]] && _pr="$PWD"
    vfile=""
    for candidate in "$_pr/.planning/VERIFICATION.md" "$_pr/.planning/phases"/*/*-VERIFICATION.md; do
      [[ -f "$candidate" && ! -L "$candidate" ]] || continue
      vfile="$candidate"
      break
    done
    if [[ -z "$vfile" ]]; then
      emit_block "$(printf '🛑 PLAN SEAL BLOCKED — No VERIFICATION.md found under .planning/. Run /silver:verify before plan-seal commit.')"
      exit 0
    fi
  fi

  # Planning is done — intermediate commits are allowed
  if [[ -n "$ignored_planning" ]]; then
    ignored_lines=""
    for skill in $ignored_planning; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '✅ Planning verified. Intermediate commit allowed.\n\nIgnored required skills:\n%s' "$ignored_lines")
    jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
  else
    printf '{"hookSpecificOutput":{"message":"✅ Planning verified. Intermediate commit allowed."}}'
  fi
  exit 0
}

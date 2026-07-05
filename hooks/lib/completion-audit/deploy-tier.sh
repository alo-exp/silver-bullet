#!/usr/bin/env bash
# completion-audit: TIER 2 final delivery gate
ca_run_deploy_tier_gate() {
project_root="$(dirname "$config_file")"
[[ -z "$project_root" ]] && project_root="$PWD"
if [[ -f "${_lib_dir}/enterprise-policy.sh" && -n "${config_file:-}" && -f "$config_file" ]]; then
  # shellcheck source=lib/enterprise-policy.sh
  source "${_lib_dir}/enterprise-policy.sh"
  if sb_enterprise_policy_delivery_blocked "$config_file" "${cmd_first_line:-$cmd}"; then
    emit_block "$(sb_enterprise_policy_delivery_block_message "$config_file")"
    exit 0
  fi
fi
run_enforcement_tier_delivery_gate
run_workflow_strict_gate "$project_root"
run_doc_scheme_delivery_gate "$project_root"
run_evidence_schema_delivery_gate "$project_root"
run_artifact_substance_delivery_gate "$project_root"

release_live_matrix_file="${SB_RUNTIME_STATE_DIR}/release-live-matrix"
e2e_live_matrix_file="${SB_RUNTIME_STATE_DIR}/e2e-live-matrix"
inline_e2e_matrix_file="${SB_RUNTIME_STATE_DIR}/inline-e2e-matrix"
if printf '%s' "$cmd_first_line" | grep -qE '\bgh release create\b'; then
  if [[ "$release_require_plugin_runtime_matrix" == "true" || "${SB_REQUIRE_PLUGIN_RELEASE_MATRIX:-0}" == "1" ]]; then
    release_matrix_value=""
    e2e_matrix_value=""
    inline_matrix_value=""
    if [[ -f "$release_live_matrix_file" && ! -L "$release_live_matrix_file" ]]; then
      release_matrix_value=$(grep -E '^matrix=' "$release_live_matrix_file" 2>/dev/null || true)
    fi
    if [[ -f "$e2e_live_matrix_file" && ! -L "$e2e_live_matrix_file" ]]; then
      e2e_matrix_value=$(grep -E '^matrix=' "$e2e_live_matrix_file" 2>/dev/null || true)
    fi
    if [[ -f "$inline_e2e_matrix_file" && ! -L "$inline_e2e_matrix_file" ]]; then
      inline_matrix_value=$(grep -E '^matrix=' "$inline_e2e_matrix_file" 2>/dev/null || true)
    fi

    if [[ "$release_matrix_value" == 'matrix=full-claude-codex' && "$e2e_matrix_value" == 'matrix=full-claude-codex' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    elif [[ "$release_matrix_value" == 'matrix=claude-only' && "$e2e_matrix_value" == 'matrix=claude-only' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    elif [[ "$release_matrix_value" == 'matrix=codex-only' && "$e2e_matrix_value" == 'matrix=codex-only' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    elif [[ "$release_matrix_value" == 'matrix=cursor-smoke' && "$e2e_matrix_value" == 'matrix=codex-only' && "$inline_matrix_value" == 'matrix=inline-full-surface' ]]; then
      :
    else
      emit_block "$(printf '🛑 RELEASE BLOCKED — The plugin-runtime release matrix has not completed for this release session.\n\nThis gate is enabled for SB plugin releases. Run bash scripts/run-release-live-matrix.sh and tests/e2e-live/run-e2e-live-tests.sh in the standard Claude direct-OAuth configuration (or Kay/OpenCode Go/DeepSeek V4 Flash low when isolated Codex-compatible runs are required), ensure the enterprise-grade-test-app journey records matrix=inline-full-surface in the host runtime inline-e2e-matrix (or complete the Claude supervised enterprise-e2e-matrix per .planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md), then retry. A full Claude/Codex matrix is still accepted when explicitly run, but it is no longer required for the release gate.' )"
      exit 0
    fi
  fi

  if [[ "$release_require_pre_release_quality_gate" == "true" || "${SB_REQUIRE_PRE_RELEASE_QUALITY_GATE:-0}" == "1" ]]; then
    quality_gate_ready=false
    if [[ -f "$quality_gate_state_file" && ! -L "$quality_gate_state_file" ]]; then
      quality_gate_ready=true
      for marker in \
        adversarial-review-clean \
        sentinel-skills-clean \
        quality-gate-stage-3 \
        full-test-suite-rerun; do
        if ! grep -Fqx -- "$marker" "$quality_gate_state_file" 2>/dev/null; then
          quality_gate_ready=false
          break
        fi
      done
    fi

    if [[ "$quality_gate_ready" != true ]]; then
      emit_block "$(printf '🛑 RELEASE BLOCKED — The configured pre-release quality sequence has not been completed in this session.\n\nComplete docs/internal/pre-release-quality-gate.md (adversarial + SENTINEL per-skill + public content + test rerun), record adversarial-review-clean, sentinel-skills-clean, quality-gate-stage-3, and full-test-suite-rerun in %s, then retry.' "$quality_gate_state_file" )"
      exit 0
    fi

    # Optional automated validation when scripts exist (non-fatal when absent in test fixtures).
    _qg_validate_launch="${project_root}/scripts/validate-launch-review.sh"
    if [[ -x "$_qg_validate_launch" ]]; then
      if ! "$_qg_validate_launch" >/dev/null 2>&1; then
        emit_block "$(printf '🛑 RELEASE BLOCKED — LAUNCH-REVIEW.md does not satisfy adversarial exit criteria (status: clean, discovery_clean_streak >= 2).\n\nRun bash scripts/validate-launch-review.sh for details, complete ENHANCED adversarial review, then retry.' )"
        exit 0
      fi
    fi
    _qg_validate_sentinel="${project_root}/scripts/validate-sentinel-skills-manifest.sh"
    if [[ -x "$_qg_validate_sentinel" ]]; then
      if ! "$_qg_validate_sentinel" >/dev/null 2>&1; then
        emit_block "$(printf '🛑 RELEASE BLOCKED — SENTINEL per-skill manifest is incomplete (docs/audits/sentinel-skills/manifest.json must show 85/85 clean rows).\n\nRun bash scripts/validate-sentinel-skills-manifest.sh for details, complete per-skill SENTINEL audits, record sentinel-skills-clean, then retry.' )"
        exit 0
      fi
    fi
  fi

  release_commit_sha=$(git -C "$project_root" rev-parse HEAD 2>/dev/null || true)
  if [[ -z "$release_commit_sha" ]]; then
    emit_block "$(printf '🛑 RELEASE BLOCKED — Unable to determine the current HEAD commit for this release session.\n\nRe-run the release flow from a valid git checkout after CI finishes.' )"
    exit 0
  fi

  release_runs_json=""
  if ! release_runs_json=$(sb_github_run_list_json "$release_commit_sha"); then
    emit_block "$(printf '🛑 RELEASE BLOCKED — Unable to verify GitHub Actions status for commit %s.\n\nInstall the gh CLI or rerun the release after CI has finished and GitHub Actions status can be verified.' "$release_commit_sha")"
    exit 0
  fi

  if ! printf '%s' "$release_runs_json" | jq empty >/dev/null 2>&1; then
    emit_block "$(printf '🛑 RELEASE BLOCKED — GitHub Actions status payload for commit %s is invalid.\n\nWait for CI to finish and retry the release.' "$release_commit_sha")"
    exit 0
  fi

  release_total_runs=$(printf '%s' "$release_runs_json" | jq -r --arg commit_sha "$release_commit_sha" '[.[] | select((.headSha // "") == $commit_sha)] | length')
  if [[ "${release_total_runs:-0}" -eq 0 ]]; then
    emit_block "$(printf '🛑 RELEASE BLOCKED — No GitHub Actions runs were found for commit %s yet.\n\nWait for CI to start and finish successfully before creating the release.' "$release_commit_sha")"
    exit 0
  fi

  blocked_runs=$(printf '%s' "$release_runs_json" | jq -r --arg commit_sha "$release_commit_sha" '
    [ .[]
      | select((.headSha // "") == $commit_sha)
    ]
    | sort_by(.workflowName // .name // "unknown")
    | group_by(.workflowName // .name // "unknown")
    | map(max_by(.createdAt // ""))
    | map(select(
        ((.status // "") != "completed")
        or (((.conclusion // "") as $conclusion | (["success", "skipped", "neutral"] | index($conclusion)) == null))
      ))
    | .[]
    | [(.workflowName // .name // "unknown"), (.status // ""), (.conclusion // ""), (.createdAt // "")]
    | @tsv
  ')

  if [[ -n "$blocked_runs" ]]; then
    blocked_lines=""
    while IFS=$'\t' read -r wf status conclusion created_at; do
      [[ -z "$wf" ]] && continue
      line=$(printf '  • %s — status=%s conclusion=%s created=%s' "$wf" "$status" "$conclusion" "$created_at")
      if [[ -n "$blocked_lines" ]]; then
        blocked_lines+=$'\n'"$line"
      else
        blocked_lines="$line"
      fi
    done <<< "$blocked_runs"
    emit_block "$(printf '🛑 RELEASE BLOCKED — GitHub Actions for commit %s are still running or not green yet.\n\nWait until the latest run for each workflow on this commit is completed successfully before releasing.\n\nCurrent non-green run(s):\n%s\n\nThis release gate is intentionally conservative so we never cut a release in the middle of CI.' "$release_commit_sha" "$blocked_lines")"
    exit 0
  fi
fi

# Build required skills list (DEFAULT_* already populated by required-skills.sh at top).
DEFAULT_REQUIRED="${DEFAULT_REQUIRED:-${__SB_RS_FALLBACK:-silver-quality-gates silver-completion-audit verify-tests}}"
DEVOPS_DEFAULT_REQUIRED="${DEVOPS_DEFAULT_REQUIRED:-${__SB_RS_FALLBACK:-silver-quality-gates silver-completion-audit verify-tests}}"

# DevOps workflow substitutes silver-quality-gates with silver-blast-radius + devops-quality-gates
delivery_uses_devops_deploy=false
if [[ "$active_workflow" == "devops-cycle" ]]; then
  delivery_uses_devops_deploy=true
  DEFAULT_REQUIRED="$DEVOPS_DEFAULT_REQUIRED"
else
  project_root_for_composer="$(dirname "$config_file")"
  [[ -z "$project_root_for_composer" ]] && project_root_for_composer="$PWD"
  wf_dir_for_composer="$project_root_for_composer/.planning/workflows"
  composer_wf_id="${SB_WORKFLOW_ID:-}"
  if [[ -z "$composer_wf_id" ]]; then
    composer_wf_id="$(workflow_id_from_shell_assignment "$cmd" 2>/dev/null || true)"
  fi
  if [[ -n "$composer_wf_id" && -f "$wf_dir_for_composer/$composer_wf_id.md" ]]; then
    composer_slug_raw="$(awk -F': ' '/^composer: / { print $2; exit }' "$wf_dir_for_composer/$composer_wf_id.md" 2>/dev/null || true)"
    composer_slug_norm="$(printf '%s' "$composer_slug_raw" | tr '[:upper:]' '[:lower:]' | sed 's|[:/]| |g' | awk '{print $NF}')"
    if [[ "$composer_slug_norm" == "silver-devops" || "$composer_slug_norm" == "devops" ]]; then
      delivery_uses_devops_deploy=true
      DEFAULT_REQUIRED="$DEVOPS_DEFAULT_REQUIRED"
    fi
  fi
fi

if [[ "$delivery_uses_devops_deploy" == true ]]; then
  if [[ -n "$required_deploy_devops_cfg" ]]; then
    required_deploy_cfg="$required_deploy_devops_cfg"
  fi
fi

# When on main/master branch, branch finishing is not applicable
if [[ "$on_main" == true ]]; then
  # Remove from DEFAULT_REQUIRED and from any config-supplied required_deploy
  DEFAULT_REQUIRED=$(printf '%s' "$DEFAULT_REQUIRED" | tr ' ' '\n' | grep -vE '^(finishing-a-development-branch|silver-branch-finish)$' | tr '\n' ' ' | sed 's/ $//')
  required_deploy_cfg=$(printf '%s' "$required_deploy_cfg" | tr ' ' '\n' | grep -vE '^(finishing-a-development-branch|silver-branch-finish)$' | tr '\n' ' ' | sed 's/ $//')
fi

# Current-version config-supplied required_deploy remains the sole source of
# truth. Legacy configs are normalized so old projects inherit current gates
# and retired dependencies do not deadlock delivery.
if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
  all_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$required_deploy_cfg" "$DEFAULT_REQUIRED")"
elif [[ -n "$required_deploy_cfg" ]]; then
  all_skills="$required_deploy_cfg"
else
  all_skills="$DEFAULT_REQUIRED"
fi

# Release commands also require release-only skills (e.g. silver-create-release).
if printf '%s' "$cmd_first_line" | grep -qE '\bgh release create\b'; then
  release_defaults="${DEFAULT_RELEASE_REQUIRED:-silver-create-release}"
  if [[ "$delivery_uses_devops_deploy" == true ]]; then
    release_defaults="${DEVOPS_DEFAULT_RELEASE_REQUIRED:-silver-create-release}"
  fi
  release_cfg=""
  if command -v jq >/dev/null 2>&1 && [[ -f "$config_file" ]]; then
    if [[ "$delivery_uses_devops_deploy" == true ]]; then
      release_cfg=$(jq -r '(.skills.required_release_devops // .skills.required_release // []) | join(" ")' "$config_file" 2>/dev/null || true)
    else
      release_cfg=$(jq -r '(.skills.required_release // []) | join(" ")' "$config_file" 2>/dev/null || true)
    fi
  fi
  if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
    release_skills="$(sb_required_skills_normalize_configured_list "$config_file" "$release_cfg" "$release_defaults")"
  elif [[ -n "$release_cfg" ]]; then
    release_skills="$release_cfg"
  else
    release_skills="$release_defaults"
  fi
  all_skills="$all_skills $release_skills"
fi

# Deduplicate
required_skills=""
for skill in $all_skills; do
  already=false
  for existing in $required_skills; do
    if [[ "$existing" == "$skill" ]]; then
      already=true
      break
    fi
  done
  if [[ "$already" == false ]]; then
    required_skills="${required_skills:+$required_skills }$skill"
  fi
done

# ── Check required skills ─────────────────────────────────────────────────────
missing=""
ignored=""
for skill in $required_skills; do
  if ! has_skill "$skill"; then
    if sb_skill_is_installed "$skill"; then
      missing="${missing:+$missing }$skill"
    else
      ignored="${ignored:+$ignored }$skill"
    fi
  fi
done

# Pre-ship quality-gates must record adversarial mode when VERIFICATION.md passed.
if declare -f sb_qg_repo_requires_pre_ship_marker >/dev/null 2>&1 \
   && declare -f sb_qg_pre_ship_marker_recorded >/dev/null 2>&1; then
  project_root_qg="$(dirname "$config_file")"
  [[ -z "$project_root_qg" || "$project_root_qg" == "." ]] && project_root_qg="$PWD"
  if sb_qg_repo_requires_pre_ship_marker "$project_root_qg"; then
    if [[ "$delivery_uses_devops_deploy" == true ]] \
       && declare -f sb_dqg_pre_ship_marker_recorded >/dev/null 2>&1; then
      if ! sb_dqg_pre_ship_marker_recorded "$state_contents"; then
        if has_skill "devops-quality-gates"; then
          missing="${missing:+$missing }devops-quality-gates-adversarial"
        else
          missing="${missing:+$missing }devops-quality-gates"
        fi
      fi
    elif ! sb_qg_pre_ship_marker_recorded "$state_contents"; then
      if has_skill "silver-quality-gates"; then
        missing="${missing:+$missing }silver-quality-gates-adversarial"
      else
        missing="${missing:+$missing }silver-quality-gates"
      fi
    fi
  fi
fi

# ── Check code review ordering ───────────────────────────────────────────────
# Enforce: review-request frames the review, silver-review produces REVIEW.md,
# and review-triage handles findings after review output exists.
ordering_issues=""
if has_skill "silver-review-request" && has_skill "silver-review"; then
  req_line=$(skill_line "silver-review-request")
  cr_line=$(skill_line "silver-review")
  if [[ "$req_line" -gt 0 && "$cr_line" -gt 0 && "$cr_line" -lt "$req_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /silver-review was run BEFORE /silver-review-request (wrong order)\n"
  fi
fi
if has_skill "silver-review" && has_skill "silver-review-triage"; then
  cr_line=$(skill_line "silver-review")
  recv_line=$(skill_line "silver-review-triage")
  if [[ "$cr_line" -gt 0 && "$recv_line" -gt 0 && "$recv_line" -lt "$cr_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /silver-review-triage was run BEFORE /silver-review (wrong order)\n"
  fi
fi
if has_skill "silver-review-request" && has_skill "silver-review-triage"; then
  req_line=$(skill_line "silver-review-request")
  recv_line=$(skill_line "silver-review-triage")
  if [[ "$req_line" -gt 0 && "$recv_line" -gt 0 && "$recv_line" -lt "$req_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /silver-review-triage was run BEFORE /silver-review-request (wrong order)\n"
  fi
fi

# ── Artifact existence check (blocking for recorded lifecycle work) ───────────
# Verifies that key SB lifecycle phases produced expected output files.
# These checks prove the work was done, not just that the skill was invoked.
artifact_blocks=""
project_root=$(dirname "$config_file")

find_planning_artifact() {
  local pattern="$1"
  [[ -d "$project_root/.planning" ]] || return 1
  find "$project_root/.planning" -type f -name "$pattern" -print -quit 2>/dev/null | grep -q .
}

# silver-execute should produce .planning/STATE.md
if has_skill "silver-execute" && [[ ! -f "$project_root/.planning/STATE.md" ]]; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-execute was recorded but .planning/STATE.md is absent — was execution actually completed?\n"
fi

# silver-verify should produce UAT/verification artifacts.
if has_skill "silver-verify" && \
   [[ ! -f "$project_root/.planning/UAT.md" ]] && \
   ! find_planning_artifact '*-UAT.md' && \
   ! find_planning_artifact '*VERIFICATION.md' && \
   ! find_planning_artifact 'VERIFICATION.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-verify was recorded but no UAT/VERIFICATION artifact was found under .planning/ — was verification actually completed?\n"
fi

if has_skill "silver-review" && \
   [[ ! -f "$project_root/.planning/REVIEW.md" ]] && \
   ! find_planning_artifact '*-REVIEW.md' && \
   ! find_planning_artifact 'REVIEW.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-review was recorded but no REVIEW artifact was found under .planning/ — was code review actually completed?\n"
fi

if has_skill "silver-secure" && \
   ! find_planning_artifact '*-SECURITY.md' && \
   ! find_planning_artifact 'SECURITY.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-secure was recorded but no SECURITY artifact was found under .planning/ — was security verification actually completed?\n"
fi

if has_skill "silver-validate" && \
   ! find_planning_artifact '*-VALIDATION.md' && \
   ! find_planning_artifact 'VALIDATION.md'; then
  artifact_blocks="${artifact_blocks}  ❌ /silver-validate was recorded but no VALIDATION artifact was found under .planning/ — was validation actually completed?\n"
fi

# Fresh test execution marker: if verify-tests is required and has been recorded,
# the marker must still exist or the run is stale.
verify_tests_required=false
for skill in $required_skills; do
  if [[ "$skill" == "verify-tests" ]]; then
    verify_tests_required=true
    break
  fi
done
test_freshness_warning=""
if [[ "$verify_tests_required" == true ]] && has_skill "verify-tests" && [[ ! -f "$verify_tests_state_file" ]]; then
  test_freshness_warning=$(printf '🛑 TEST GATE STALE — /verify-tests was recorded earlier, but the freshness marker is missing at %s.\n\nSource changes invalidate the marker. Re-run /verify-tests before creating the PR, deploy, or release.' "$verify_tests_state_file")
fi

# ── Output result ─────────────────────────────────────────────────────────────
if [[ -n "$missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  ❌ /${skill}\n"
  done
  ordering_note=""
  [[ -n "$ordering_issues" ]] && ordering_note=$(printf '\n⚠️  Ordering issues detected:\n%s' "$ordering_issues")
  msg=$(printf '🛑 COMPLETION BLOCKED — Workflow incomplete.\n\nYou are attempting to create a PR/deploy but these required steps are missing:\n%s%sComplete ALL required workflow steps before finalizing.\nDo NOT proceed with this action.' "$missing_lines" "$ordering_note")
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s\nInstall them if you want them enforced.' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
elif [[ -n "$test_freshness_warning" ]]; then
  msg="$test_freshness_warning"
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
elif [[ -n "$ordering_issues" ]]; then
  msg=$(printf '🛑 ORDERING BLOCKED — Code Review Triad ran out of order:\n%s\nRe-run /silver:review-request → /silver:review → /silver:review-triage before delivery.' "$ordering_issues")
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
elif [[ -n "$artifact_blocks" ]]; then
  msg=$(printf '🛑 ARTIFACT BLOCKED — SB lifecycle markers were recorded but expected output files are missing. This may indicate vacuous skill invocation or an incomplete workflow:\n\n%s\nComplete the owning SB workflow step and produce the artifact before final delivery.' "$artifact_blocks")
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '%s\n\nIgnored required skills:\n%s' "$msg" "$ignored_lines")
  fi
  emit_block "$msg"
  exit 0
else
  if [[ -n "$ignored" ]]; then
    ignored_lines=""
    for skill in $ignored; do
      ignored_lines="${ignored_lines}  ⚠️ /${skill} (not installed anywhere invocable)\n"
    done
    msg=$(printf '✅ Workflow compliance verified. Proceed.\n\nIgnored required skills:\n%s' "$ignored_lines")
    if [[ -n "${EVIDENCE_SCHEMA_WARN:-}" ]]; then
      msg=$(printf '%s\n\n%s' "$msg" "$EVIDENCE_SCHEMA_WARN")
    fi
    jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
  elif [[ -n "${EVIDENCE_SCHEMA_WARN:-}" ]]; then
    msg=$(printf '✅ Workflow compliance verified. Proceed.\n\n%s' "$EVIDENCE_SCHEMA_WARN")
    jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
  else
    printf '{"hookSpecificOutput":{"message":"✅ Workflow compliance verified. Proceed."}}'
  fi
fi
}

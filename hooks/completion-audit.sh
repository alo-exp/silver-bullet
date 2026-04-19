#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# shellcheck source=lib/workflow-utils.sh
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck disable=SC1091
[[ -f "$_lib_dir/workflow-utils.sh" ]] && source "$_lib_dir/workflow-utils.sh"
# Fallback definitions if sourcing failed (e.g. in test environments or path resolution issues)
if ! declare -f count_flow_log_rows >/dev/null 2>&1; then
  count_flow_log_rows() { grep -cE '^\| [0-9]+ \|' "$1" 2>/dev/null || echo 0; }
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| complete' "$1" 2>/dev/null || echo 0; }
fi

# Pre+PostToolUse hook (matcher: Bash)
# Detects git commit/push/deploy commands and blocks if workflow is incomplete.
#
# TWO-TIER ENFORCEMENT:
#   Intermediate commits (git commit, git push to feature branches):
#     → Only require required_planning skills (default: silver-quality-gates)
#     → Allows GSD execute-phase to make atomic commits during development
#   Final delivery (gh pr create, deploy, gh release create):
#     → Require full required_deploy skill list
#
# This prevents the deadlock where GSD's execution subagents cannot commit
# because finalization skills (code-review, testing-strategy, etc.) aren't done yet.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
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

# Extract the command being run
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# ── Classify the command ──────────────────────────────────────────────────────
# is_intermediate: git commit / git push (atomic commits during development)
# is_completion:   gh pr create / deploy / gh release create (final delivery gates)
is_intermediate=false
is_completion=false

if printf '%s' "$cmd" | grep -qE '\bgit commit\b'; then
  is_intermediate=true
elif printf '%s' "$cmd" | grep -qE '\bgit push\b'; then
  is_intermediate=true
elif printf '%s' "$cmd" | grep -qE '\bgh pr create\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -qE '\bgh pr merge\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -iqE '\bdeploy\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -qE '\bgh release create\b'; then
  is_completion=true
fi

# Skip commands that don't match any gate
[[ "$is_intermediate" == false && "$is_completion" == false ]] && exit 0

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  completion-audit.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# ── Resolve config file by walking up from $PWD ──────────────────────────────
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

# No config → project not set up with Silver Bullet — silent exit
[[ -z "$config_file" ]] && exit 0

# ── Read config values ────────────────────────────────────────────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR"
state_file="${SB_STATE_DIR}/state"
trivial_file="${SB_STATE_DIR}/trivial"
required_planning_cfg=""
required_deploy_cfg=""
active_workflow="full-dev-cycle"

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_planning // []) | join(" ")),
  ((.skills.required_deploy // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle")
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
required_planning_cfg=$(printf '%s' "$config_vals" | sed -n '3p')
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '4p')
active_workflow=$(printf '%s' "$config_vals" | sed -n '5p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate paths stay within ~/.claude/ (SB-002/SB-003)
case "$state_file" in
  "$HOME"/.claude/*) ;;
  *) state_file="${SB_STATE_DIR}/state" ;;
esac
case "$trivial_file" in
  "$HOME"/.claude/*) ;;
  *) trivial_file="${SB_STATE_DIR}/trivial" ;;
esac

# ── Trivial bypass (reject symlinks) ─────────────────────────────────────────
if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
  exit 0
fi

# ── WORKFLOW.md path completion check (primary gate with legacy fallback) ─────
workflow_file="$PWD/.planning/WORKFLOW.md"
if [[ -f "$workflow_file" && ! -L "$workflow_file" ]]; then
  # Parse Flow Log: count completed and total paths
  wf_complete=0
  wf_total=0
  wf_parse_ok=false
  if wf_complete=$(count_complete_flow_rows "$workflow_file") && \
     wf_total=$(count_flow_log_rows "$workflow_file"); then
    wf_parse_ok=true
  fi

  if [[ "$wf_parse_ok" == true && "$wf_total" -gt 0 ]]; then
    if [[ "$is_intermediate" == true ]]; then
      # For intermediate commits: any path completed means planning is underway — allow
      if [[ "$wf_complete" -gt 0 ]]; then
        printf '{"hookSpecificOutput":{"message":"✅ WORKFLOW.md: %s/%s flows complete. Intermediate commit allowed."}}\n' \
          "$wf_complete" "$wf_total"
        exit 0
      fi
      # No flows complete yet — fall through to legacy check
    elif [[ "$is_completion" == true ]]; then
      if [[ "$wf_complete" -eq "$wf_total" ]]; then
        # All flows complete — final delivery allowed
        printf '{"hookSpecificOutput":{"message":"✅ WORKFLOW.md: all %s flows complete. Delivery allowed."}}\n' "$wf_total"
        exit 0
      else
        # Not all flows done — block final delivery
        emit_block "WORKFLOW INCOMPLETE — ${wf_complete}/${wf_total} flows done. Complete all flows before final delivery."
        exit 0
      fi
    fi
  fi
  # If parsing failed (malformed WORKFLOW.md), fall through to legacy logic silently
fi
# If WORKFLOW.md absent: fall through to existing legacy logic unchanged

# ── Detect current git branch ─────────────────────────────────────────────────
current_branch=""
current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
# Validate branch name: only allow safe characters
if [[ -n "$current_branch" ]] && ! printf '%s' "$current_branch" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
  current_branch=""
fi
on_main=false
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  on_main=true
fi

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

has_skill() {
  printf '%s\n' "$state_contents" | grep -qx "$1" 2>/dev/null
}

# Line number of a skill in the state file (for ordering checks); 0 if absent
skill_line() {
  local line
  line=$(printf '%s\n' "$state_contents" | grep -nx "^${1}$" | head -1 | cut -d: -f1)
  printf '%s' "${line:-0}"
}

# ── TIER 1: Intermediate commit check (git commit / git push) ─────────────────
if [[ "$is_intermediate" == true ]]; then
  # Determine planning skills required for intermediate commits
  # DevOps workflow requires silver-blast-radius + devops-quality-gates instead of silver-quality-gates
  if [[ "$active_workflow" == "devops-cycle" ]]; then
    DEFAULT_PLANNING="silver-blast-radius devops-quality-gates"
  else
    DEFAULT_PLANNING="silver-quality-gates"
  fi
  planning_skills="${required_planning_cfg:-$DEFAULT_PLANNING}"

  missing_planning=""
  for skill in $planning_skills; do
    if ! has_skill "$skill"; then
      missing_planning="${missing_planning:+$missing_planning }$skill"
    fi
  done

  if [[ -n "$missing_planning" ]]; then
    missing_lines=""
    for skill in $missing_planning; do
      missing_lines="${missing_lines}  ❌ /${skill}\n"
    done
    msg=$(printf '🚫 COMMIT BLOCKED — Planning incomplete.\n\nYou must complete these planning steps before any commits:\n%s\nRun the missing planning skills first, then commit.' "$missing_lines")
    emit_block "$msg"
    exit 0
  fi

  # Planning is done — intermediate commits are allowed
  printf '{"hookSpecificOutput":{"message":"✅ Planning verified. Intermediate commit allowed."}}'
  exit 0
fi

# ── TIER 2: Final delivery check (gh pr create / deploy / release) ────────────

# Build required skills list
# Source canonical required-skills list (single source of truth — TD-01 fix)
# shellcheck source=lib/required-skills.sh
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck disable=SC1090
  source "$_lib_dir/required-skills.sh"
else
  # Fallback if lib not found (should not happen in correct installs)
  DEFAULT_REQUIRED="silver-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt"
  DEVOPS_DEFAULT_REQUIRED="silver-blast-radius devops-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist silver-create-release verification-before-completion test-driven-development tech-debt"
fi

# DevOps workflow substitutes silver-quality-gates with silver-blast-radius + devops-quality-gates
if [[ "$active_workflow" == "devops-cycle" ]]; then
  DEFAULT_REQUIRED="$DEVOPS_DEFAULT_REQUIRED"
fi

# When on main/master branch, finishing-a-development-branch is not applicable
if [[ "$on_main" == true ]]; then
  # Remove from DEFAULT_REQUIRED and from any config-supplied required_deploy
  DEFAULT_REQUIRED=$(printf '%s' "$DEFAULT_REQUIRED" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
  required_deploy_cfg=$(printf '%s' "$required_deploy_cfg" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
fi

# When config supplies required_deploy, it is the sole source of truth.
# When config is absent, fall back to DEFAULT_REQUIRED from required-skills.sh.
if [[ -n "$required_deploy_cfg" ]]; then
  all_skills="$required_deploy_cfg"
else
  all_skills="$DEFAULT_REQUIRED"
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
for skill in $required_skills; do
  if ! has_skill "$skill"; then
    missing="${missing:+$missing }$skill"
  fi
done

# ── Check code review triad ordering ─────────────────────────────────────────
# Enforce: code-review must precede requesting-code-review,
#          requesting-code-review must precede receiving-code-review
ordering_issues=""
if has_skill "code-review" && has_skill "requesting-code-review"; then
  cr_line=$(skill_line "code-review")
  req_line=$(skill_line "requesting-code-review")
  if [[ "$cr_line" -gt 0 && "$req_line" -gt 0 && "$req_line" -lt "$cr_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /requesting-code-review was run BEFORE /code-review (wrong order)\n"
  fi
fi
if has_skill "requesting-code-review" && has_skill "receiving-code-review"; then
  req_line=$(skill_line "requesting-code-review")
  recv_line=$(skill_line "receiving-code-review")
  if [[ "$req_line" -gt 0 && "$recv_line" -gt 0 && "$recv_line" -lt "$req_line" ]]; then
    ordering_issues="${ordering_issues}  ⚠️  /receiving-code-review was run BEFORE /requesting-code-review (wrong order)\n"
  fi
fi

# ── Artifact existence check (non-blocking, informational) ───────────────────
# Verifies that key GSD phases produced expected output files.
# These checks prove the work was done, not just that the skill was invoked.
artifact_warnings=""
project_root=$(dirname "$config_file")

# gsd-execute-phase should produce .planning/STATE.md
if has_skill "gsd-execute-phase" && [[ ! -f "$project_root/.planning/STATE.md" ]]; then
  artifact_warnings="${artifact_warnings}  ⚠️  /gsd:execute-phase was recorded but .planning/STATE.md is absent — was execution actually completed?\n"
fi

# gsd-verify-work should produce VERIFICATION.md
if has_skill "gsd-verify-work" && [[ ! -f "$project_root/VERIFICATION.md" ]] && \
   [[ ! -f "$project_root/.planning/VERIFICATION.md" ]]; then
  artifact_warnings="${artifact_warnings}  ⚠️  /gsd:verify-work was recorded but VERIFICATION.md is absent — was verification actually completed?\n"
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
  emit_block "$msg"
  exit 0
elif [[ -n "$ordering_issues" ]]; then
  msg=$(printf '⚠️  ORDERING WARNING — All skills recorded but Code Review Triad ran out of order:\n%s\nConsider re-running the triad in the correct sequence before merging.' "$ordering_issues")
  jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
elif [[ -n "$artifact_warnings" ]]; then
  msg=$(printf '⚠️  ARTIFACT WARNING — Skills recorded but expected output files are missing. This may indicate vacuous skill invocation (calling a skill without doing the work):\n\n%s\nProceed only if these artifacts exist under a different path. Enforcement is invocation-based, not outcome-based.' "$artifact_warnings")
  jq -n --arg m "$msg" '{"hookSpecificOutput":{"message":$m}}'
else
  printf '{"hookSpecificOutput":{"message":"✅ Workflow compliance verified. Proceed."}}'
fi

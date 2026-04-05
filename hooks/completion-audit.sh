#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: Bash)
# Detects git commit/push/deploy commands and blocks if workflow is incomplete.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ completion-audit SKIPPED — jq not installed. Enforcement inactive."}}'
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

# Check if command matches completion patterns (word boundaries, case-insensitive for deploy)
is_completion=false
is_release=false
if printf '%s' "$cmd" | grep -qE '\bgit commit\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -qE '\bgit push\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -qE '\bgh pr create\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -iqE '\bdeploy\b'; then
  is_completion=true
elif printf '%s' "$cmd" | grep -qE '\bgh release create\b'; then
  is_completion=true
  is_release=true
fi

[[ "$is_completion" == false ]] && exit 0

# --- Error handler: on any failure past this point, warn and exit 0 ---
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️ completion-audit.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

# --- Resolve config file by walking up from $PWD ---
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

# --- Read config values ---
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"
mkdir -p "$SB_STATE_DIR"
state_file="${SB_STATE_DIR}/state"
trivial_file="${SB_STATE_DIR}/trivial"
required_deploy=""

if [[ -n "$config_file" ]]; then
  sb_default_state="${SB_STATE_DIR}/state"
  sb_default_trivial="${SB_STATE_DIR}/trivial"
  config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
    (.state.state_file // $ds),
    (.state.trivial_file // $dt),
    ((.skills.required_deploy // []) | join(" "))
  ] | join("\n")' "$config_file")

  state_file=$(printf '%s' "$config_vals" | sed -n '1p')
  state_file="${state_file/#\~/$HOME}"
  trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
  trivial_file="${trivial_file/#\~/$HOME}"
  required_deploy=$(printf '%s' "$config_vals" | sed -n '3p')
fi

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

# --- Check trivial file override (reject symlinks for safety) ---
if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
  exit 0
fi

# --- Build required skills list ---
DEFAULT_REQUIRED="quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist create-release verification-before-completion test-driven-development tech-debt"

if [[ -z "$required_deploy" && -z "$config_file" ]]; then
  # No config at all — use defaults
  required_skills="$DEFAULT_REQUIRED"
else
  # Config exists: merge required_deploy + mandatory finalization skills (deduplicated)
  mandatory="testing-strategy documentation finishing-a-development-branch deploy-checklist"
  all_skills="$required_deploy $mandatory"

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
fi

# --- Check state file for required skills ---
missing=""
if [[ -f "$state_file" ]]; then
  state_contents=$(cat "$state_file")
  for skill in $required_skills; do
    if ! printf '%s\n' "$state_contents" | grep -qx "$skill" 2>/dev/null; then
      missing="${missing:+$missing }$skill"
    fi
  done
else
  # No state file — all skills are missing
  missing="$required_skills"
fi

# --- §9 Pre-Release Quality Gate check (only for gh release create) ---
release_missing=""
if [[ "${is_release:-false}" == true ]]; then
  if [[ -f "$state_file" ]]; then
    state_contents=$(cat "$state_file")
    # All 4 stages use explicit markers (symmetric recording)
    for stage in quality-gate-stage-1 quality-gate-stage-2 quality-gate-stage-3 quality-gate-stage-4; do
      if ! printf '%s\n' "$state_contents" | grep -qx "$stage" 2>/dev/null; then
        release_missing="${release_missing:+$release_missing }$stage"
      fi
    done
  else
    # No state file at all — all stages missing
    release_missing="quality-gate-stage-1 quality-gate-stage-2 quality-gate-stage-3 quality-gate-stage-4"
  fi
fi

# --- Output result ---
# Combine both missing-skills and release-gate messages if both apply
if [[ -n "$missing" && -n "$release_missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  ❌ /${skill}\n"
  done
  msg=$(printf '🛑 RELEASE BLOCKED — Workflow incomplete AND §9 Quality Gate incomplete.\n\nMissing workflow steps:\n%s\nMissing quality gate stages: %s\n\nComplete ALL workflow steps first, then run the 4-stage quality gate.\nDo NOT proceed with this release.' "$missing_lines" "$release_missing")
  emit_block "$msg"
  exit 0
elif [[ -n "$release_missing" ]]; then
  msg=$(printf '🛑 RELEASE BLOCKED — §9 Pre-Release Quality Gate incomplete.\n\nMissing evidence for: %s\n\nThe 4-stage quality gate (Code Review Triad, Big-Picture Audit, Content Refresh, SENTINEL) must complete before /create-release.\nDo NOT proceed with this release.' "$release_missing")
  emit_block "$msg"
  exit 0
fi

if [[ -n "$missing" ]]; then
  # Build missing list
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  ❌ /${skill}\n"
  done

  msg=$(printf '🛑 COMPLETION BLOCKED — Workflow incomplete.\n\nYou are attempting to commit/push/deploy but these required steps are missing:\n%sComplete ALL required workflow steps before finalizing.\nDo NOT proceed with this action.' "$missing_lines")

  emit_block "$msg"
else
  printf '{"hookSpecificOutput":{"message":"✅ Workflow compliance verified. Proceed."}}'
fi

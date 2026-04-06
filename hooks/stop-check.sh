#!/usr/bin/env bash
set -euo pipefail

# Stop hook (event: Stop)
# Fires when Claude outputs a final response (declaring task complete).
# Blocks if required_deploy skills are missing from the state file.
#
# Exit format: {"decision":"block","reason":"..."} to block completion.
# Silent exit 0 to allow completion.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed. Install it: brew install jq (macOS) / apt install jq (Linux). All Silver Bullet enforcement hooks are disabled until jq is available."}}'
  exit 0
fi

# Read JSON from stdin (consumed per hook protocol; content not used by stop-check)
cat >/dev/null

# ── Error handler: warn and exit 0 on unexpected failure ─────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"⚠️  stop-check.sh: unexpected error — skipping check\"}}" ; exit 0' ERR

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

sb_default_state="${SB_STATE_DIR}/state"
sb_default_trivial="${SB_STATE_DIR}/trivial"
config_vals=$(jq -r --arg ds "$sb_default_state" --arg dt "$sb_default_trivial" '[
  (.state.state_file // $ds),
  (.state.trivial_file // $dt),
  ((.skills.required_deploy // []) | join(" ")),
  (.project.active_workflow // "full-dev-cycle")
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
state_file="${state_file/#\~/$HOME}"
trivial_file=$(printf '%s' "$config_vals" | sed -n '2p')
trivial_file="${trivial_file/#\~/$HOME}"
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '3p')
active_workflow=$(printf '%s' "$config_vals" | sed -n '4p')

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

# ── Build required skills list (Tier 2: full required_deploy list) ────────────
DEFAULT_REQUIRED="quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist create-release verification-before-completion test-driven-development tech-debt review-loop-pass-1 review-loop-pass-2"

# DevOps workflow substitutes quality-gates with blast-radius + devops-quality-gates
if [[ "$active_workflow" == "devops-cycle" ]]; then
  DEFAULT_REQUIRED="blast-radius devops-quality-gates code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist create-release verification-before-completion test-driven-development tech-debt review-loop-pass-1 review-loop-pass-2"
fi

# Mandatory finalization skills
mandatory="testing-strategy documentation finishing-a-development-branch deploy-checklist"

# When on main/master branch, finishing-a-development-branch is not applicable
if [[ "$on_main" == true ]]; then
  mandatory="testing-strategy documentation deploy-checklist"
  DEFAULT_REQUIRED=$(printf '%s' "$DEFAULT_REQUIRED" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
  required_deploy_cfg=$(printf '%s' "$required_deploy_cfg" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
fi

if [[ -n "$required_deploy_cfg" ]]; then
  all_skills="$required_deploy_cfg $mandatory"
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
  if ! printf '%s\n' "$state_contents" | grep -qx "$skill" 2>/dev/null; then
    missing="${missing:+$missing }$skill"
  fi
done

# ── Check quality-gate-stage markers (F-16) ───────────────────────────────────
# Apply when: create-release is in required_skills OR any stage marker is already present
release_context=false
for skill in $required_skills; do
  if [[ "$skill" == "create-release" ]]; then
    release_context=true
    break
  fi
done
if [[ "$release_context" == false ]]; then
  for stage in quality-gate-stage-1 quality-gate-stage-2 quality-gate-stage-3 quality-gate-stage-4; do
    if printf '%s\n' "$state_contents" | grep -qx "$stage" 2>/dev/null; then
      release_context=true
      break
    fi
  done
fi

release_missing=""
if [[ "$release_context" == true ]]; then
  for stage in quality-gate-stage-1 quality-gate-stage-2 quality-gate-stage-3 quality-gate-stage-4; do
    if ! printf '%s\n' "$state_contents" | grep -qx "$stage" 2>/dev/null; then
      release_missing="${release_missing:+$release_missing }$stage"
    fi
  done
fi

# ── Output result ─────────────────────────────────────────────────────────────
if [[ -n "$missing" && -n "$release_missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  - ${skill}\n"
  done
  reason=$(printf 'Cannot complete -- missing required skills:\n%s\nAlso missing quality gate stages: %s\n\nComplete all required skills and all 4 quality gate stages before declaring task complete.' "$missing_lines" "$release_missing")
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
elif [[ -n "$release_missing" ]]; then
  reason=$(printf 'Cannot complete -- quality gate stages incomplete: %s\n\nComplete all 4 stages before declaring task complete.' "$release_missing")
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
elif [[ -n "$missing" ]]; then
  missing_lines=""
  for skill in $missing; do
    missing_lines="${missing_lines}  - ${skill}\n"
  done
  reason=$(printf 'Cannot complete -- missing required skills:\n%s\nRun these skills before declaring task complete.' "$missing_lines")
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"decision":"block","reason":%s}' "$json_reason"
fi

exit 0

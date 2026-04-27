#!/usr/bin/env bash
set -euo pipefail
# Fail-open: on any unexpected error, exit 0 silently — never block user prompts.
trap 'exit 0' ERR

# UserPromptSubmit hook
# Fires before every user prompt is processed.
# Injects a compact Silver Bullet compliance reminder into additionalContext.
#
# Must be FAST (< 200ms) — no git operations, no stdin blocking, single jq call.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — exit silently if missing (don't slow down prompts with warnings)
command -v jq >/dev/null 2>&1 || exit 0

# DO NOT read stdin — UserPromptSubmit hooks must not block on stdin for speed.

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

# ── Read config values (single jq call for speed) ────────────────────────────
SB_STATE_DIR="${HOME}/.claude/.silver-bullet"

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
required_deploy_cfg=$(printf '%s' "$config_vals" | sed -n '3p')

# Env var override for state file
state_file="${SILVER_BULLET_STATE_FILE:-$state_file}"

# Security: validate paths stay within ~/.claude/
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

# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")

# ── Detect current git branch (for main-branch exemptions) ───────────────────
current_branch=""
current_branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [[ -n "$current_branch" ]] && ! printf '%s' "$current_branch" | grep -qE '^[a-zA-Z0-9/_.-]+$'; then
  current_branch=""
fi
on_main=false
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  on_main=true
fi

# ── Build required skills list ────────────────────────────────────────────────
# Source canonical required-skills list (single source of truth — TD-01 fix)
# shellcheck source=lib/required-skills.sh
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck disable=SC1090
  source "$_lib_dir/required-skills.sh"
else
  # Fallback if lib not found (should not happen in correct installs)
  DEFAULT_REQUIRED="silver-quality-gates code-review requesting-code-review receiving-code-review finishing-a-development-branch silver-create-release verification-before-completion test-driven-development"
fi

if [[ -n "$required_deploy_cfg" ]]; then
  required_skills="$required_deploy_cfg"
else
  required_skills="$DEFAULT_REQUIRED"
fi

# On main/master, finishing-a-development-branch is not applicable
if [[ "$on_main" == true ]]; then
  required_skills=$(printf '%s' "$required_skills" | tr ' ' '\n' | grep -v '^finishing-a-development-branch$' | tr '\n' ' ' | sed 's/ $//')
fi

# ── Compute missing skills ────────────────────────────────────────────────────
# O(N) grep calls per prompt -- acceptable for N<=20 skills; if prompt
# latency exceeds 200ms, optimize with associative array or single awk pass.
missing_list=""
total=0
completed=0
for skill in $required_skills; do
  total=$((total + 1))
  if printf '%s\n' "$state_contents" | grep -qx "$skill" 2>/dev/null; then
    completed=$((completed + 1))
  else
    missing_list="${missing_list:+$missing_list, }${skill}"
  fi
done

# ── Load core enforcement rules (Tier 2 rule injection — survives compaction) ──
# Read core-rules.md from the same directory as this script so rules are
# re-injected before every user prompt, not just at session start.
# Security: core-rules.md is co-located with hook scripts in the plugin directory.
# An attacker who can write to the plugin directory can already modify the hooks
# themselves, so external-file read does not add meaningful attack surface on
# single-user developer systems. File must reside under the same plugin root.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_rules_file="${script_dir}/core-rules.md"
if [[ ! -f "$core_rules_file" ]] && [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  core_rules_file="${CLAUDE_PLUGIN_ROOT}/hooks/core-rules.md"
fi
# Security: verify core-rules.md is actually within the plugin directory (path traversal defense)
resolved_rules=""
if [[ -f "$core_rules_file" ]]; then
  resolved_rules="$(cd "$(dirname "$core_rules_file")" && pwd)/$(basename "$core_rules_file")"
fi
if [[ -n "$resolved_rules" && "$resolved_rules" != "${script_dir}/"* && "$resolved_rules" != "${script_dir}" ]]; then
  # Path resolved outside plugin directory — reject silently
  core_rules_file=""
fi

# ── Composed-workflow position injection (Pass 1: list active workflows) ─────
# v0.29.x replaces the legacy single-file WORKFLOW.md with per-instance files
# in `.planning/workflows/`. List the active workflow IDs (the file basenames).
# Pass 2 will parse each per-workflow file for richer position info.
workflows_dir="$PWD/.planning/workflows"
workflow_position=""
if [[ -d "$workflows_dir" && ! -L "$workflows_dir" ]]; then
  active_ids=""
  shopt -s nullglob
  for _wf in "$workflows_dir"/*.md; do
    [[ -f "$_wf" ]] || continue
    _id=$(basename "$_wf" .md)
    active_ids="${active_ids:+$active_ids,}${_id}"
  done
  shopt -u nullglob
  if [[ -n "$active_ids" ]]; then
    workflow_position="Active composed workflows: ${active_ids}"
  fi
fi

# ── Emit additionalContext ────────────────────────────────────────────────────
if [[ -z "$missing_list" ]]; then
  skill_status="Silver Bullet: all required skills complete."
else
  skill_status="Silver Bullet -- Missing: ${missing_list} (${completed} of ${total} complete)"
fi

# Append WORKFLOW.md position if present
if [[ -n "$workflow_position" ]]; then
  skill_status="${skill_status}
${workflow_position}"
fi

# Prepend core rules if available, then append skill status
if [[ -f "$core_rules_file" ]]; then
  core_content=$(cat "$core_rules_file")
  msg="${core_content}

---

${skill_status}"
else
  msg="$skill_status"
fi

printf '{"hookSpecificOutput":{"additionalContext":%s}}' "$(printf '%s' "$msg" | jq -Rs '.')"

exit 0

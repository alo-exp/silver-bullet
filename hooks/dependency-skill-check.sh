#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"Silver Bullet dependency gate encountered an internal error. Stop and tell the user to reinstall the missing dependency plugin before retrying.\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# Blocks required dependency skill invocations when the underlying plugin is
# unavailable so SB fails closed instead of silently substituting a fallback.
#
# Required dependency surfaces:
#   - GSD calls used by SB workflows (gsd-*)
#   - Superpowers, Design, Engineering, Product Management, MultAI namespaces
#   - Bare dependency skills used directly by SB: code-review, clarify,
#     test-driven-development, systematic-debugging,
#     requesting-code-review, receiving-code-review, finishing-a-development-branch,
#     design-critique, user-research, write-spec
#
# If the dependency cannot be invoked, the model must stop, notify the user,
# and offer install-first remediation before any degraded alternative.

umask 0077

if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"⚠️ Silver Bullet dependency gate requires jq. Install jq and retry."}}'
  exit 0
fi

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -n "$_lib_dir" && -f "$_lib_dir/skill-discovery.sh" ]]; then
  # shellcheck source=lib/skill-discovery.sh
  source "$_lib_dir/skill-discovery.sh"
fi

input=$(cat)
raw_skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')
[[ -n "$raw_skill" ]] || exit 0

# Projects not using SB should not be affected.
config_file=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]] && [[ -f "$search_dir/silver-bullet.md" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done
[[ -n "$config_file" ]] || exit 0

dependency_required=false
case "$raw_skill" in
  gsd:*|gsd-*|superpowers:*|design:*|engineering:*|product-management:*|multai:*)
    dependency_required=true
    ;;
  code-review|clarify|test-driven-development|systematic-debugging|requesting-code-review|receiving-code-review|finishing-a-development-branch|design-critique|user-research|write-spec)
    dependency_required=true
    ;;
esac

[[ "$dependency_required" == true ]] || exit 0

skill_name="$raw_skill"
if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
  skill_name="$(sb_skill_canonical_name "$raw_skill")"
else
  if [[ "$skill_name" == gsd:* ]]; then
    skill_name="gsd-${skill_name#gsd:}"
  else
    while [[ "$skill_name" == *:* ]]; do
      skill_name="${skill_name#*:}"
    done
  fi
fi

if sb_skill_is_installed "$skill_name"; then
  exit 0
fi

namespace="${raw_skill%%:*}"
if [[ "$raw_skill" == "$namespace" ]]; then
  namespace="(bare skill)"
fi

reason="DEPENDENCY PLUGIN UNAVAILABLE — ${raw_skill} cannot run because the ${namespace} dependency is not installed or is unavailable in this session. Stop and notify the user. Offer options in this order: A. Install the plugin and retry. B. Continue only if there is an explicitly approved degraded path. C. Switch to a different workflow or stop."
json_reason=$(printf '%s' "$reason" | jq -Rs '.')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"

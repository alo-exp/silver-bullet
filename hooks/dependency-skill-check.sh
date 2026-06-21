#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"Silver Bullet dependency compatibility gate encountered an internal error; continuing without blocking.\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# Legacy compatibility gate for dependency skill invocations.
#
# SB owns lifecycle markers and workflows. Missing optional third-party plugins
# are not a hard Silver Bullet runtime prerequisite. This hook keeps the matcher
# surface in place for compatibility but does not block absorbed namespaces.
#
# Forbidden Superpowers execution modes are still blocked by
# forbidden-skill-check.sh.

umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "dependency-skill-check"
fi

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

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_gate_or_exit
fi

# M-07: intentional no-op — absorbed dependency namespaces exit 0 below.
# silver:* routes normalize to silver-* via skill-discovery.sh.
# Hook retained for matcher compatibility; does not block SB-owned workflows.
if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
  raw_skill="$(sb_skill_canonical_name "$raw_skill")"
fi

case "$raw_skill" in
  superpowers:*|design:*|engineering:*|product-management:*|multai:*)
    exit 0
    ;;
  code-review|clarify|test-driven-development|systematic-debugging|requesting-code-review|receiving-code-review|finishing-a-development-branch|design-critique|user-research|write-spec)
    exit 0
    ;;
esac

exit 0

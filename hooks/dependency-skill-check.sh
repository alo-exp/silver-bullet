#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"Silver Bullet dependency compatibility gate encountered an internal error; continuing without blocking.\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# Legacy compatibility gate for dependency skill invocations.
#
# SB now absorbs its explicit GSD, Superpowers, and Anthropic dependencies into
# SB-owned lifecycle markers and workflows. Missing core dependency plugins are
# therefore no longer a hard Silver Bullet runtime prerequisite. This hook keeps
# the old matcher surface in place for compatibility but does not block absorbed
# dependency namespaces.
#
# Forbidden Superpowers execution modes are still blocked by
# forbidden-skill-check.sh.

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

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_gate_or_exit
fi

# M-07: intentional no-op — absorbed dependency namespaces exit 0 below.
# Legacy gsd-* aliases normalize to silver-* via legacy-gsd-alias.sh (sunset 2026-09-01).
# Hook retained for matcher compatibility; does not block SB-owned workflows.
if [[ -f "$_lib_dir/legacy-gsd-alias.sh" ]]; then
  # shellcheck source=lib/legacy-gsd-alias.sh
  source "$_lib_dir/legacy-gsd-alias.sh"
  raw_skill="$(sb_legacy_gsd_alias_normalize "$raw_skill")"
fi

case "$raw_skill" in
  gsd:*|gsd-*|superpowers:*|design:*|engineering:*|product-management:*|multai:*)
    exit 0
    ;;
  code-review|clarify|test-driven-development|systematic-debugging|requesting-code-review|receiving-code-review|finishing-a-development-branch|design-critique|user-research|write-spec)
    exit 0
    ;;
esac

exit 0

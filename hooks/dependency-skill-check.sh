#!/usr/bin/env bash
set -euo pipefail
trap 'printf "{\"hookSpecificOutput\":{\"message\":\"Silver Bullet dependency compatibility gate encountered an internal error; continuing without blocking.\"}}" ; exit 0' ERR

# PreToolUse hook (matcher: Skill)
# Legacy compatibility STUB for dependency skill invocations: INERT, every path allows (R2-32).
# It is not an enforcement gate; docs/HOOKS.md says so.
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
# The project: the nearest root with a record, else the nearest directory with both contract files.
config_file="$( (source "$(dirname "${BASH_SOURCE[0]}")/lib/integrity-anchor.sh" && sb_integrity_activation_config "$PWD") 2>/dev/null; true)"
search_dir="${config_file:+${config_file%/*}}"
search_dir="${search_dir:-$PWD}"
[[ -n "$config_file" ]] || exit 0

if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_gate_or_exit
fi

# M-07: intentional no-op — absorbed dependency namespaces exit 0 below.
# sb:* routes normalize to silver-* via skill-discovery.sh.
# Hook retained for matcher compatibility; does not block SB-owned workflows.
if declare -F sb_skill_canonical_name >/dev/null 2>&1; then
  raw_skill="$(sb_skill_canonical_name "$raw_skill")"
fi

# Every absorbed dependency namespace and every SB-owned skill passes: this hook never blocks.

exit 0

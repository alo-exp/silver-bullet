#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse/Bash — optional industry tooling reminders (P9 stretch).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
[[ -f "$_lib_dir/runtime-paths.sh" ]] && source "$_lib_dir/runtime-paths.sh"
[[ -f "$_lib_dir/sb-project-gate.sh" ]] && source "$_lib_dir/sb-project-gate.sh"

command -v jq >/dev/null 2>&1 || exit 0
sb_project_gate_or_exit

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)"
case "$tool_name" in
  Bash|exec_command) ;;
  *) exit 0 ;;
esac

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

enabled="$(jq -r '.hooks.industry_tooling.enabled // false' "$config_file" 2>/dev/null || echo false)"
[[ "$enabled" == "true" ]] || exit 0

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[[ -n "$cmd" ]] || exit 0

hints=()
if [[ -f "$PWD/package.json" ]] && printf '%s' "$cmd" | grep -qE 'npm (install|ci|run build)'; then
  if ! printf '%s' "$cmd" | grep -q 'npm audit'; then
    hints+=("Consider: npm audit (industry_tooling hint — config-driven)")
  fi
fi

if find "$PWD" -maxdepth 3 -name '*.tf' -print -quit 2>/dev/null | grep -q .; then
  if printf '%s' "$cmd" | grep -qE 'terraform (apply|plan)'; then
    if ! printf '%s' "$cmd" | grep -q 'terraform validate'; then
      hints+=("Consider: terraform validate before apply/plan (industry_tooling)")
    fi
  fi
fi

[[ ${#hints[@]} -gt 0 ]] || exit 0
msg="$(printf '%s\n' "${hints[@]}")"
printf '{"hookSpecificOutput":{"message":%s}}' "$(printf '%s' "$msg" | jq -Rs '.')"

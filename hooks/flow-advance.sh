#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse/Skill — autonomous flow chaining (Wave 0.3, 0.6, 0.8).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh orchestrator-state.sh orchestrator-parent.sh skill-discovery.sh; do
  if [[ -f "$_lib_dir/$_lib" ]]; then
    # shellcheck source=/dev/null
    source "$_lib_dir/$_lib"
  fi
done

command -v jq >/dev/null 2>&1 || exit 0
sb_project_gate_or_exit

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

raw_skill="$(printf '%s' "$input" | jq -r '.tool_input.skill // ""' 2>/dev/null || true)"
[[ -n "$raw_skill" ]] || exit 0

skill="$raw_skill"
if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
  skill="$(sb_skill_canonical_name "$raw_skill")"
else
  skill="${raw_skill#silver:}"
  skill="${skill//:/-}"
fi

repo_root=""
if declare -f sb_find_project_root >/dev/null 2>&1; then
  repo_root="$(sb_find_project_root 2>/dev/null || true)"
fi
[[ -n "$repo_root" ]] || repo_root="$PWD"

intent=""
if [[ -f "${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt" ]]; then
  intent="$(head -1 "${SB_RUNTIME_STATE_DIR}/orchestrator-intent.txt" 2>/dev/null || true)"
fi

msg=""

if sb_orchestrator_is_composer_skill "$skill"; then
  wid="$(sb_orchestrator_on_composer_start "$skill" "$intent" "$repo_root" 2>/dev/null || true)"
  if [[ -n "$wid" ]]; then
    msg="SB orchestrator ► Workflow ${wid} started (autonomous; no composition approval required)"
  fi
elif sb_orchestrator_is_flow_atom "$skill"; then
  advance_msg="$(sb_orchestrator_advance_on_atom "$skill" "$repo_root" 2>/dev/null || true)"
  [[ -n "$advance_msg" ]] && msg="$advance_msg"
fi

[[ -n "$msg" ]] || exit 0
json_msg="$(printf '%s' "$msg" | jq -Rs '.')"
printf '{"hookSpecificOutput":{"message":%s}}' "$json_msg"

#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PostToolUse/Skill — autonomous flow chaining (Wave 0.3, 0.6, 0.8).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh orchestrator-state.sh orchestrator-parent.sh skill-discovery.sh jq-gate.sh hook-output.sh; do
  if [[ -f "$_lib_dir/$_lib" ]]; then
    # shellcheck source=/dev/null
    source "$_lib_dir/$_lib"
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
    config_file="$(sb_find_project_config 2>/dev/null || true)"
    if [[ -n "$config_file" ]] && sb_project_is_initiated "$config_file"; then
      sb_jq_enforcement_warn "flow-advance"
    fi
  fi
  exit 0
fi
sb_project_gate_or_exit

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

raw_skill="$(printf '%s' "$input" | jq -r '.tool_input.skill // ""' 2>/dev/null || true)"
[[ -n "$raw_skill" ]] || exit 0

skill="$raw_skill"
if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
  skill="$(sb_skill_canonical_name "$raw_skill")"
else
  skill="${raw_skill#sb:}"
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
  # Workers may re-read composer skills for instructions — never re-seed the queue.
  if declare -f sb_orchestrator_is_worker_session >/dev/null 2>&1 && sb_orchestrator_is_worker_session; then
    exit 0
  fi
  wid="$(sb_orchestrator_on_composer_start "$skill" "$intent" "$repo_root" 2>/dev/null || true)"
  if [[ -n "$wid" ]]; then
    msg="SB orchestrator ► Workflow ${wid} started (autonomous; no composition approval required)"
  fi
elif sb_orchestrator_is_flow_atom "$skill"; then
  advance_msg="$(sb_orchestrator_advance_on_atom "$skill" "$repo_root" 2>/dev/null || true)"
  [[ -n "$advance_msg" ]] && msg="$advance_msg"
fi

# Reset devops-cycle → full-dev-cycle after devops ship (F-04)
if [[ "$skill" == "silver-ship" && -f "$repo_root/.silver-bullet.json" ]]; then
  aw="$(jq -r '.project.active_workflow // "full-dev-cycle"' "$repo_root/.silver-bullet.json" 2>/dev/null || true)"
  if [[ "$aw" == "devops-cycle" ]]; then
    tmp="$(mktemp)"
    if jq '.project.active_workflow = "full-dev-cycle"' "$repo_root/.silver-bullet.json" >"$tmp" 2>/dev/null; then
      mv "$tmp" "$repo_root/.silver-bullet.json"
      reset_note="SB ► active_workflow reset to full-dev-cycle after devops ship"
      msg="${msg:+$msg — }${reset_note}"
    else
      rm -f -- "$tmp" 2>/dev/null || true
    fi
  fi
fi

[[ -n "$msg" ]] || exit 0
sb_emit_hook_message "PostToolUse" "$msg"

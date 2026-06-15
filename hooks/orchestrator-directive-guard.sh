#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse — block Edit/Write/Bash until orchestrator directive skill invoked (P0/P6).
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
for _lib in runtime-paths.sh sb-project-gate.sh orchestrator-directive.sh orchestrator-state.sh orchestrator-parent.sh required-skills.sh hook-audit.sh; do
  # shellcheck disable=SC1090
  [[ -f "$_lib_dir/$_lib" ]] && source "$_lib_dir/$_lib"
done

_sb_odg_have_jq=false
if command -v jq >/dev/null 2>&1 && printf '{}' | jq . >/dev/null 2>&1; then
  _sb_odg_have_jq=true
fi

sb_odg_hook_field() {
  local json="$1" field="$2" default="${3:-}"
  if [[ "$_sb_odg_have_jq" == true ]]; then
    printf '%s' "$json" | jq -r ".$field // \"$default\"" 2>/dev/null || printf '%s' "$default"
    return 0
  fi
  case "$field" in
    hook_event_name)
      if grep -qE '"hook_event_name"[[:space:]]*:[[:space:]]*"PreToolUse"' <<<"$json" 2>/dev/null; then
        printf 'PreToolUse'
      else
        printf '%s' "$default"
      fi
      ;;
    tool_name)
      printf '%s' "$json" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' 2>/dev/null \
        | head -1 | sed -E 's/.*"([^"]+)"$/\1/' || printf '%s' "$default"
      ;;
    prompt)
      printf '%s' "$json" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
        | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || printf '%s' "$default"
      ;;
    tool_input.skill)
      printf '%s' "$json" | grep -oE '"skill"[[:space:]]*:[[:space:]]*"[^"]+"' 2>/dev/null \
        | head -1 | sed -E 's/.*"([^"]+)"$/\1/' || printf '%s' "$default"
      ;;
    *)
      printf '%s' "$default"
      ;;
  esac
}

sb_project_gate_or_exit

input="$(cat 2>/dev/null || true)"
[[ -n "$input" ]] || exit 0

hook_event="$(sb_odg_hook_field "$input" 'hook_event_name' 'PreToolUse')"
[[ "$hook_event" == "PreToolUse" ]] || exit 0

tool_name="$(sb_odg_hook_field "$input" 'tool_name' '')"
prompt="$(sb_odg_hook_field "$input" 'prompt' '')"

emit_block() {
  local reason="$1"
  local json_reason
  if command -v jq >/dev/null 2>&1; then
    json_reason=$(printf '%s' "$reason" | jq -Rs '.')
    if declare -f sb_hook_audit_record >/dev/null 2>&1; then
      sb_hook_audit_record "orchestrator-directive-guard" "PreToolUse" "deny" "$reason" ""
    fi
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
  else
    if declare -f sb_hook_audit_record >/dev/null 2>&1; then
      sb_hook_audit_record "orchestrator-directive-guard" "PreToolUse" "deny" "$reason" ""
    fi
    printf '%s\n' "$reason" >&2
  fi
  if [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" || "$_sb_odg_have_jq" != true ]]; then
    exit 2
  fi
}

# Skill invocations: allow when matching expected skill; clear directive on match.
case "$tool_name" in
  Skill)
    raw_skill="$(sb_odg_hook_field "$input" 'tool_input.skill' '')"
    if declare -f sb_orchestrator_is_parent_session >/dev/null 2>&1 && sb_orchestrator_is_parent_session; then
      if ! sb_orchestrator_parent_skill_allowed "$raw_skill"; then
        expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
        tmpl=""
        if [[ -f "$(sb_orchestrator_directive_file)" ]]; then
          tmpl="$(jq -r '.next_worker_template // ""' "$(sb_orchestrator_directive_file)" 2>/dev/null || true)"
        fi
        emit_block "$(printf '🛑 ORCHESTRATOR PARENT — Do not invoke /%s directly. Spawn a Task worker with template %s.md to run flow atom %s.' "$raw_skill" "${tmpl:-WORKER}" "$expected")"
        exit 0
      fi
      exit 0
    fi
    expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
    [[ -n "$expected" ]] || exit 0
    skill="$raw_skill"
    if declare -f sb_skill_canonical_name >/dev/null 2>&1; then
      skill="$(sb_skill_canonical_name "$raw_skill")"
    else
      skill="${raw_skill#silver:}"
      skill="${skill//:/-}"
    fi
    if [[ "$skill" == "$expected" ]]; then
      sb_orchestrator_directive_clear
    fi
    exit 0
    ;;
esac

# Parent orchestrator: allow delegation tools; block implementation tools on project source.
if declare -f sb_orchestrator_is_parent_session >/dev/null 2>&1 && sb_orchestrator_is_parent_session; then
  case "$tool_name" in
    Task|Subagent)
      expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
      tmpl=""
      args=""
      if [[ -f "$(sb_orchestrator_directive_file)" ]]; then
        tmpl="$(jq -r '.next_worker_template // ""' "$(sb_orchestrator_directive_file)" 2>/dev/null || true)"
        args="$(jq -r '.args // ""' "$(sb_orchestrator_directive_file)" 2>/dev/null || true)"
      fi
      if [[ -n "$expected" ]]; then
        sb_orchestrator_mark_worker_spawn "$expected" "$tmpl" "$args" 2>/dev/null || true
      fi
      exit 0
      ;;
  esac
  if sb_orchestrator_parent_tool_allowed "$tool_name"; then
    exit 0
  fi
  expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
  tmpl=""
  [[ -f "$(sb_orchestrator_directive_file)" ]] && \
    tmpl="$(jq -r '.next_worker_template // ""' "$(sb_orchestrator_directive_file)" 2>/dev/null || true)"
  emit_block "$(printf '🛑 ORCHESTRATOR PARENT — %s is forbidden in parent mode. Spawn Task worker (%s.md) for /%s, or use read-only tools for state.' "$tool_name" "${tmpl:-WORKER}" "${expected:-next flow}")"
  exit 0
fi

case "$tool_name" in
  Edit|Write|MultiEdit|apply_patch|Bash|exec_command) ;;
  *) exit 0 ;;
esac

# User override in prompt (audited on UserPromptSubmit; here we only honor if already logged this session)
if [[ -n "$prompt" ]] && sb_orchestrator_prompt_has_override "$prompt"; then
  repo_root=""
  if declare -f sb_find_project_root >/dev/null 2>&1; then
    repo_root="$(sb_find_project_root 2>/dev/null || true)"
  fi
  reason="$(sb_orchestrator_extract_override_reason "$prompt")"
  expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
  sb_orchestrator_log_override "${repo_root:-$PWD}" "$reason" "$expected"
  sb_orchestrator_directive_clear
  exit 0
fi

# Directive block takes precedence over edit-without-workflow warnings (P0 before P6)
if [[ -f "$(sb_orchestrator_directive_file)" ]] && sb_orchestrator_directive_is_blocking; then
  expected="$(sb_orchestrator_directive_next_skill 2>/dev/null || true)"
  if [[ -n "$expected" ]]; then
    config_file=""
    if declare -f sb_find_project_config >/dev/null 2>&1; then
      config_file="$(sb_find_project_config 2>/dev/null || true)"
    fi
    SB_STATE_DIR="${SB_RUNTIME_STATE_DIR}"
    state_file="${SILVER_BULLET_STATE_FILE:-${SB_STATE_DIR}/state}"
    if [[ -n "$config_file" ]]; then
      cfg_state="$(jq -r '.state.state_file // empty' "$config_file" 2>/dev/null || true)"
      if [[ -n "$cfg_state" ]]; then
        state_file="$cfg_state"
        state_file="${state_file/#\~/$HOME}"
      fi
    fi
    state_contents=""
    [[ -f "$state_file" && ! -L "$state_file" ]] && state_contents="$(cat "$state_file" 2>/dev/null || true)"
    if ! sb_orchestrator_directive_skill_recorded "$expected" "$state_contents"; then
      directive_json="$(sb_orchestrator_directive_read 2>/dev/null || true)"
      reason="$(printf '%s' "$directive_json" | jq -r '.reason // "Orchestrator directive pending"' 2>/dev/null || true)"
      emit_block "$(printf '🛑 ORCHESTRATOR DIRECTIVE — Invoke /%s before %s.\n\n%s\n\nTo bypass with audit log, include in your next user message: SB OVERRIDE: <reason>' "$expected" "$tool_name" "$reason")"
      exit 0
    fi
    sb_orchestrator_directive_clear
    exit 0
  fi
fi

# P6: edits without active composed workflow — warn then block after N (default 5)
if [[ "$tool_name" == "Edit" || "$tool_name" == "Write" || "$tool_name" == "MultiEdit" || "$tool_name" == "apply_patch" ]]; then
  repo_root=""
  if declare -f sb_find_project_root >/dev/null 2>&1; then
    repo_root="$(sb_find_project_root 2>/dev/null || true)"
  fi
  [[ -n "$repo_root" ]] || repo_root="$PWD"
  wf_dir="$repo_root/.planning/workflows"
  active_wf=0
  if [[ -d "$wf_dir" && ! -L "$wf_dir" ]]; then
    shopt -s nullglob
    for _wf in "$wf_dir"/*.md; do
      [[ -f "$_wf" ]] && active_wf=$((active_wf + 1))
    done
    shopt -u nullglob
  fi
  if [[ "$active_wf" -eq 0 ]]; then
    counter_file="${SB_RUNTIME_STATE_DIR}/edit-without-workflow.count"
    count=0
    [[ -f "$counter_file" ]] && count="$(cat "$counter_file" 2>/dev/null || echo 0)"
    count=$((count + 1))
    printf '%s' "$count" >"$counter_file" 2>/dev/null || true
    threshold="${SB_ORCHESTRATOR_EDIT_WITHOUT_WORKFLOW_BLOCK:-5}"
    if [[ "$count" -ge "$threshold" ]]; then
      emit_block "$(printf '🛑 WORKFLOW REQUIRED — %s edits without an active composed workflow (.planning/workflows/*.md).\n\nRun /silver to route work and start workflows.sh, or invoke a composer skill (silver:feature).' "$count")"
      exit 0
    elif [[ "$count" -eq 1 || "$count" -eq 3 ]]; then
      printf '{"hookSpecificOutput":{"message":"⚠️ SB: edit without active workflow (%s/%s before block). Route via /silver and start composed workflow."}}' "$count" "$threshold"
      exit 0
    fi
  else
    rm -f -- "${SB_RUNTIME_STATE_DIR}/edit-without-workflow.count" 2>/dev/null || true
  fi
fi

exit 0

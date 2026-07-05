#!/usr/bin/env bash
# Bounded redacted delegation progress for hook additional_context (max 8 lines / 2 KB).
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
# shellcheck source=hooks/lib/agent-delegation-state.sh
[[ -f "$_lib_dir/agent-delegation-state.sh" ]] && source "$_lib_dir/agent-delegation-state.sh"
# shellcheck source=scripts/lib/agent-delegate-common.sh
_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$_repo_root/scripts/lib/agent-delegate-common.sh" ]] && source "$_repo_root/scripts/lib/agent-delegate-common.sh"

sb_agent_delegation_progress_surface() {
  sb_agent_delegation_is_active || return 0
  local log_path host task_id lines summary
  log_path="$(sb_agent_delegation_read_field log_path "")"
  host="$(sb_agent_delegation_read_field host "")"
  task_id="$(sb_agent_delegation_read_field task_id "")"
  summary="[SB delegation active] host=${host} task_id=${task_id}"
  if [[ -n "$log_path" && -f "$log_path" ]]; then
    lines="$(tail -n 8 "$log_path" 2>/dev/null || true)"
    lines="$(agent_delegate_redact_output "$lines" 2>/dev/null || printf '%s' "$lines")"
    summary="${summary}
${lines}"
  fi
  if [[ "${#summary}" -gt 2048 ]]; then
    summary="${summary:0:2048}"
  fi
  printf '%s' "$summary"
}

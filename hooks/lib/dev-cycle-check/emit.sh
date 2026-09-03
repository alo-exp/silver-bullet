#!/usr/bin/env bash
# dev-cycle-check emit helper (sourced inside main)
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  sb_hook_audit_record "dev-cycle-check" "$hook_event" "deny" "$reason" "${file_path:-${command_str:-}}"
  if [[ "$hook_event" == "PreToolUse" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
    if [[ "${SB_KAY_HOOK_BRIDGE_INVOKED:-}" == "1" ]]; then
      printf '%s\n' "$reason" >&2
      exit 2
    fi
  else
    printf '{"decision":"block","reason":%s,"hookSpecificOutput":{"message":%s}}' "$json_reason" "$json_reason"
  fi
}

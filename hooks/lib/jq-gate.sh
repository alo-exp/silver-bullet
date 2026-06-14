# shellcheck shell=bash
# Silver Bullet — jq presence gate for enforcement hooks.
#
# Usage:
#   source hooks/lib/jq-gate.sh
#   sb_jq_enforcement_block "completion-audit" "emit_block"   # blocks delivery
#   sb_jq_enforcement_warn "stop-check"                       # visible warn, exit 0

sb_jq_missing_message() {
  printf '%s' '🛑 ENFORCEMENT BLOCKED — jq is required for Silver Bullet hooks.

Install jq, then re-run /silver:init:
  macOS: brew install jq
  Linux: sudo apt install jq

Until jq is installed, delivery gates and session completion checks cannot run.'
}

sb_jq_enforcement_warn() {
  local hook_name="${1:-hook}"
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  printf '{"hookSpecificOutput":{"message":"⚠️  ENFORCEMENT INACTIVE — jq not installed (%s). Install: brew install jq (macOS) / apt install jq (Linux). Silver Bullet enforcement is disabled until jq is available."}}' "$hook_name"
  exit 0
}

# Args: hook_name emit_block_fn_name
# Calls emit_block_fn with jq missing message when jq absent.
# When emit_fn is unavailable, falls back to python3 JSON encoding.
sb_jq_enforcement_block() {
  local hook_name="${1:-hook}"
  local emit_fn="${2:-}"
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  local msg
  msg="$(sb_jq_missing_message)"
  if [[ -n "$emit_fn" ]] && declare -f "$emit_fn" >/dev/null 2>&1; then
    "$emit_fn" "$msg"
    exit 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$msg" <<'PY'
import json, sys
msg = sys.argv[1]
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": msg,
  }
}))
PY
    exit 0
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq required for Silver Bullet enforcement"}}'
  exit 0
}

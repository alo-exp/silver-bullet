#!/usr/bin/env bash
# Optional debug-grade audit log for live hook verification.
#
# Disabled by default. Enable either by exporting SILVER_BULLET_HOOK_AUDIT_LOG
# to a state-scoped jsonl path, or by creating
#   <state dir>/hook-audit-enabled
# and using the default <state dir>/hook-audit.jsonl sink.

sb_hook_audit_log_path() {
  local explicit="${SILVER_BULLET_HOOK_AUDIT_LOG:-}"
  local default_log="${SB_RUNTIME_STATE_DIR:-}/hook-audit.jsonl"
  local default_flag="${SB_RUNTIME_STATE_DIR:-}/hook-audit-enabled"

  if [[ -n "$explicit" ]]; then
    explicit="${explicit/#\~/$HOME}"
    if declare -f sb_runtime_path_is_state_scoped >/dev/null 2>&1; then
      if ! sb_runtime_path_is_state_scoped "$explicit"; then
        return 1
      fi
    fi
    printf '%s\n' "$explicit"
    return 0
  fi

  [[ -n "${SB_RUNTIME_STATE_DIR:-}" ]] || return 1
  [[ -f "$default_flag" && ! -L "$default_flag" ]] || return 1
  printf '%s\n' "$default_log"
}

sb_hook_audit_record() {
  local hook_name="$1"
  local hook_event="$2"
  local decision="$3"
  local detail="${4:-}"
  local target="${5:-}"
  local log_path

  log_path="$(sb_hook_audit_log_path 2>/dev/null || true)"
  [[ -n "$log_path" ]] || return 0
  [[ ! -L "$log_path" ]] || return 0

  mkdir -p "$(dirname "$log_path")" 2>/dev/null || return 0

  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg runtime "${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-unknown}}" \
      --arg hook_name "$hook_name" \
      --arg hook_event "$hook_event" \
      --arg decision "$decision" \
      --arg detail "$detail" \
      --arg target "$target" \
      --arg cwd "$PWD" \
      '{
        timestamp:$ts,
        runtime:$runtime,
        hook_name:$hook_name,
        hook_event:$hook_event,
        decision:$decision,
        detail:$detail,
        target:$target,
        cwd:$cwd
      }' >>"$log_path" 2>/dev/null || true
    return 0
  fi

  printf '{"timestamp":"%s","runtime":"%s","hook_name":"%s","hook_event":"%s","decision":"%s","detail":"%s","target":"%s","cwd":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "${SB_RUNTIME_NAME:-${SILVER_BULLET_RUNTIME:-unknown}}" \
    "$hook_name" \
    "$hook_event" \
    "$decision" \
    "$detail" \
    "$target" \
    "$PWD" >>"$log_path" 2>/dev/null || true
}

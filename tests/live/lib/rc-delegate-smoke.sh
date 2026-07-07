#!/usr/bin/env bash
# Bounded RC delegate smoke helpers.
rc_delegate_smoke_prompt() { printf '%s\n' 'Reply with exactly: RC_SMOKE_OK. No tools.'; }
rc_delegate_smoke_run() {
  local host="$1" wd="$2" log="$3" repo="${4:-}"
  repo="${repo:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
  local script prompt extra_args=()
  prompt="$(rc_delegate_smoke_prompt)"
  # Bounded one-line reply — default 512 B delegate log floor is too high for RC smoke.
  export SB_AGENT_DELEGATE_LOG_FLOOR="${SB_AGENT_DELEGATE_LOG_FLOOR:-64}"
  export SB_AGENT_CLAUDE_LOG_FLOOR="${SB_AGENT_CLAUDE_LOG_FLOOR:-64}"
  case "$host" in
    cursor)
      script="${repo}/scripts/agent-cursor-delegate.sh"
      export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5
      export SB_AGENT_CURSOR_LOG_FLOOR="${SB_AGENT_CURSOR_LOG_FLOOR:-64}"
      ;;
    codex) script="${repo}/scripts/agent-codex-delegate.sh" ;;
    claude)
      script="${repo}/scripts/agent-claude-delegate.sh"
      # Print mode avoids interactive Bypass Permissions disclaimer in RC harness.
      extra_args+=(--use-print)
      ;;
    *) return 2 ;;
  esac
  if ((${#extra_args[@]})); then
    bash "$script" --work-dir "$wd" --prompt "$prompt" --log "$log" --mode permissive --sb-root "$repo" "${extra_args[@]}" && grep -q RC_SMOKE_OK "$log"
  else
    bash "$script" --work-dir "$wd" --prompt "$prompt" --log "$log" --mode permissive --sb-root "$repo" && grep -q RC_SMOKE_OK "$log"
  fi
}
rc_delegate_five_tool_scenarios() {
  local repo="$1"
  export SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=prerelease
  export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5
  bash "${repo}/tests/live/test-live-five-tool-stack-cursor.sh"
}

#!/usr/bin/env bash
# Bounded RC delegate smoke helpers.
rc_delegate_smoke_prompt() { printf '%s\n' 'Reply with exactly: RC_SMOKE_OK. No tools.'; }
rc_delegate_smoke_run() {
  local host="$1" wd="$2" log="$3" repo="${4:-}"
  repo="${repo:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
  local script prompt; prompt="$(rc_delegate_smoke_prompt)"
  case "$host" in
    cursor) script="${repo}/scripts/agent-cursor-delegate.sh"; export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5 ;;
    codex) script="${repo}/scripts/agent-codex-delegate.sh" ;;
    claude) script="${repo}/scripts/agent-claude-delegate.sh" ;;
    *) return 2 ;;
  esac
  bash "$script" --work-dir "$wd" --prompt "$prompt" --log "$log" --mode permissive --sb-root "$repo" && grep -q RC_SMOKE_OK "$log"
}
rc_delegate_five_tool_scenarios() {
  local repo="$1"
  export SB_FIVE_TOOL_LIVE=1 SB_FIVE_TOOL_LIVE_EXECUTE=1 SB_FIVE_TOOL_MODE=prerelease
  export CURSOR_AGENT_MODEL=composer-2.5 CURSOR_MODEL=composer-2.5
  bash "${repo}/tests/live/test-live-five-tool-stack-cursor.sh"
}

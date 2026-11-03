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
    codex) script="${repo}/scripts/agent-codex-delegate.sh" ;;
    claude)
      script="${repo}/scripts/agent-claude-delegate.sh"
      # Print mode avoids interactive Bypass Permissions disclaimer in RC harness.
      extra_args+=(--use-print)
      ;;
    *) return 2 ;;
  esac
  # Capture stdout/stderr into the requested evidence log as well as relying
  # on the delegate's own log writer.  Pinned non-interactive Claude/Codex
  # paths exec the native CLI before the wrapper can append its normal log;
  # without this capture a successful one-line reply leaves no rc.log for the
  # matrix assertion to inspect.
  local delegate_rc=0
  if ((${#extra_args[@]})); then
    bash "$script" --work-dir "$wd" --prompt "$prompt" --log "$log" --mode permissive --sb-root "$repo" "${extra_args[@]}" >"$log" 2>&1 || delegate_rc=$?
  else
    bash "$script" --work-dir "$wd" --prompt "$prompt" --log "$log" --mode permissive --sb-root "$repo" >"$log" 2>&1 || delegate_rc=$?
  fi
  [[ "$delegate_rc" -eq 0 ]] || return "$delegate_rc"
  grep -q RC_SMOKE_OK "$log"
}

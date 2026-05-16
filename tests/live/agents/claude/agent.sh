#!/usr/bin/env bash
# Claude agent adapter for live Silver Bullet tests.

agent_name() {
  printf 'claude'
}

agent_cli_path() {
  printf '%s\n' "${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/Users/shafqat/.local/bin/claude")}"
}

agent_preflight() {
  local cli
  cli="$(agent_cli_path)"
  if ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: claude CLI not found or not working at %s\n' "$cli" >&2
    return 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    printf 'ERROR: node is required on PATH for Claude hooks\n' >&2
    return 1
  fi
}

agent_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local permission_mode
  local continue_flag

  cli="$(agent_cli_path)"
  permission_mode="${CLAUDE_PERMISSION_MODE:-default}"
  : "${CLAUDE_PROMPT_COUNT:=0}"
  if [[ "$mode" == "permissive" ]]; then
    permission_mode="bypassPermissions"
  fi

  continue_flag=0
  if [[ "${CLAUDE_PROMPT_COUNT:-0}" -gt 0 ]]; then
    continue_flag=1
  fi

  output=$(cd "$WORK_DIR" && \
    {
      local args=(
        --print
        --model "${CLAUDE_MODEL:-sonnet}"
        --effort "${CLAUDE_EFFORT:-low}"
        --permission-mode "$permission_mode"
        --verbose
      )
      if [[ "$continue_flag" == "1" ]]; then
        args+=(--continue)
      fi
      "$cli" "${args[@]}" "$prompt"
    } 2>&1) || true

  printf '%s' "$output"

  CLAUDE_PROMPT_COUNT=$((CLAUDE_PROMPT_COUNT + 1))
}

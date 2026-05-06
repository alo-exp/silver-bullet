#!/usr/bin/env bash
# Claude runtime adapter for live Silver Bullet tests.

runtime_name() {
  printf 'claude'
}

runtime_cli_path() {
  printf '%s\n' "${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo "/Users/shafqat/.local/bin/claude")}"
}

runtime_preflight() {
  local cli
  cli="$(runtime_cli_path)"
  if ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: claude CLI not found or not working at %s\n' "$cli" >&2
    return 1
  fi
  if ! command -v expect >/dev/null 2>&1; then
    printf 'ERROR: expect is required for the interactive Claude driver\n' >&2
    return 1
  fi
  if ! command -v node >/dev/null 2>&1; then
    printf 'ERROR: node is required on PATH for Claude hooks\n' >&2
    return 1
  fi
}

runtime_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local prompt_file
  local expect_script
  local effective_path
  local permission_mode
  local continue_flag

  cli="$(runtime_cli_path)"
  expect_script="${SB_ROOT}/scripts/claude-interactive-invoke.expect"
  prompt_file="$(mktemp "${TMPDIR:-/tmp}/claude-live-prompt-XXXXXX")"
  printf '%s' "$prompt" > "$prompt_file"

  effective_path="/Users/shafqat/.local/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
  permission_mode="${CLAUDE_PERMISSION_MODE:-default}"
  if [[ "$mode" == "permissive" ]]; then
    permission_mode="bypassPermissions"
  fi

  continue_flag=0
  if [[ "${CLAUDE_PROMPT_COUNT:-0}" -gt 0 ]]; then
    continue_flag=1
  fi

  output=$(cd "$WORK_DIR" && \
    PATH="$effective_path" \
    CLAUDE_BIN="$cli" \
    CLAUDE_WORK_DIR="$WORK_DIR" \
    CLAUDE_PROMPT_FILE="$prompt_file" \
    CLAUDE_CONTINUE="$continue_flag" \
    CLAUDE_MODEL="${CLAUDE_MODEL:-claude-haiku-4-5-20251001}" \
    CLAUDE_EFFORT="${CLAUDE_EFFORT:-low}" \
    CLAUDE_PERMISSION_MODE="$permission_mode" \
    CLAUDE_INTERACTIVE_TIMEOUT="${CLAUDE_INTERACTIVE_TIMEOUT:-900}" \
    "$expect_script" 2>&1) || true

  rm -f "$prompt_file"
  printf '%s' "$output"

  CLAUDE_PROMPT_COUNT=$((CLAUDE_PROMPT_COUNT + 1))
}

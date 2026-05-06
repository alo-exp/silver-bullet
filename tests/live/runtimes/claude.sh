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
}

runtime_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output

  cli="$(runtime_cli_path)"

  local args=(
    -p "$prompt"
    --plugin-dir "$SB_ROOT"
    --output-format text
    --model "${CLAUDE_MODEL:-claude-haiku-4-5-20251001}"
    --max-budget-usd "$MAX_BUDGET"
    --verbose
  )

  if [[ "$mode" == "permissive" ]]; then
    args+=(--dangerously-skip-permissions)
  fi

  output=$(cd "$WORK_DIR" && "$cli" "${args[@]}" 2>&1) || true
  printf '%s' "$output"
}

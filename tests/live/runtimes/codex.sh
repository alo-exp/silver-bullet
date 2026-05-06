#!/usr/bin/env bash
# Codex runtime adapter for live Silver Bullet tests.

runtime_name() {
  printf 'codex'
}

runtime_cli_path() {
  printf '%s\n' "${CODEX_BIN:-$(command -v codex 2>/dev/null)}"
}

runtime_preflight() {
  local cli
  cli="$(runtime_cli_path)"
  if [[ -z "$cli" ]] || ! "$cli" --version >/dev/null 2>&1; then
    printf 'ERROR: codex CLI not found or not working in PATH\n' >&2
    return 1
  fi
}

runtime_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local last_message_file
  local tmpdir

  cli="$(runtime_cli_path)"
  tmpdir="${TMPDIR:-/tmp}"
  last_message_file="$(mktemp "${tmpdir}/codex-live-last-message-XXXXXX")"

  local args=(
    exec
    --cd "$WORK_DIR"
    --ephemeral
    --skip-git-repo-check
    --output-last-message "$last_message_file"
    --color never
    --sandbox danger-full-access
  )

  if [[ "$mode" == "permissive" ]]; then
    args+=(--dangerously-bypass-approvals-and-sandbox)
  fi

  output=$(cd "$SB_ROOT" && "$cli" "${args[@]}" "$prompt" 2>&1) || true
  if [[ -f "$last_message_file" ]]; then
    output="${output}"$'\n'"$(cat "$last_message_file")"
    rm -f -- "$last_message_file"
  fi
  printf '%s' "$output"
}

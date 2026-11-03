#!/usr/bin/env bash
# Shared helpers for five-tool pre-release validation.
# shellcheck shell=bash

five_tool_prerelease_repo_root() {
  if [[ -n "${SB_ROOT:-}" ]]; then
    printf '%s' "$SB_ROOT"
    return 0
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${here}/../../.." && pwd
}

five_tool_claude_cli_path() {
  local cli=""
  cli="$(command -v claude 2>/dev/null || true)"
  [[ -n "$cli" ]] && printf '%s' "$cli"
}

five_tool_claude_cli_authenticated() {
  local cli auth_out=""
  cli="$(five_tool_claude_cli_path)" || return 1
  if ! "$cli" --version >/dev/null 2>&1; then
    return 1
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" || -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
    return 0
  fi
  auth_out="$("$cli" auth status 2>&1 || true)"
  if grep -qiE 'not logged in|not authenticated|authentication required' <<<"$auth_out"; then
    return 1
  fi
  grep -qiE 'logged in|authenticated|claude\.ai|api_key|oauth' <<<"$auth_out"
}

#!/usr/bin/env bash
# Shared helpers for five-tool pre-release and live Cursor validation.
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

# True when leanctx is explicitly opted in (enabled_by_user: true).
five_tool_leanctx_opted_in() {
  local cfg="${1:-$(five_tool_prerelease_repo_root)/.silver-bullet.json}"
  [[ -f "$cfg" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e '.recommended_tools.leanctx.enabled_by_user == true' "$cfg" >/dev/null 2>&1
}

five_tool_cursor_cli_path() {
  local cli=""
  cli="$(command -v cursor-agent 2>/dev/null || true)"
  if [[ -z "$cli" ]]; then
    cli="$(command -v agent 2>/dev/null || true)"
  fi
  [[ -n "$cli" ]] && printf '%s' "$cli"
}

# Auth: CURSOR_API_KEY or logged-in cursor-agent status.
five_tool_cursor_agent_authenticated() {
  local cli
  cli="$(five_tool_cursor_cli_path)" || return 1
  if ! "$cli" --version >/dev/null 2>&1; then
    return 1
  fi
  # The current Cursor CLI also supports a logged-in session token through
  # CURSOR_AUTH_TOKEN. This is especially useful for isolated live fixtures
  # whose CURSOR_CONFIG_DIR does not share the user's Keychain-backed status.
  if [[ -n "${CURSOR_API_KEY:-}" || -n "${CURSOR_AUTH_TOKEN:-}" ]]; then
    return 0
  fi
  local status_out=""
  status_out="$("$cli" status 2>&1 || true)"
  if printf '%s' "$status_out" | grep -qiE 'not logged in|authentication required'; then
    return 1
  fi
  printf '%s' "$status_out" | grep -qiE 'logged in as|email:|account:'
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
  if printf '%s' "$auth_out" | grep -qiE 'not logged in|not authenticated|authentication required'; then
    return 1
  fi
  printf '%s' "$auth_out" | grep -qiE 'logged in|authenticated|claude\.ai|api_key|oauth'
}

five_tool_prerelease_marker_path() {
  local root="${SB_RUNTIME_STATE_DIR:-${SB_RUNTIME_HOME_ROOT:-$HOME}/.silver-bullet}"
  printf '%s/pre-release-five-tool-stack' "$root"
}

five_tool_prerelease_write_marker() {
  local marker mode="${1:-offline}"
  marker="$(five_tool_prerelease_marker_path)"
  mkdir -p "$(dirname "$marker")"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$mode" >"$marker"
}

five_tool_prerelease_offline_tests() {
  local root="$1"
  cat <<EOF
${root}/tests/hooks/test-leanctx-gate-lib.sh
${root}/tests/hooks/test-leanctx-gate.sh
${root}/tests/hooks/test-stack-compression-coordinator.sh
${root}/tests/hooks/test-five-tool-mcp-namespace.sh
${root}/tests/hooks/test-five-tool-mutual-exclusion.sh
${root}/tests/hooks/test-agentmemory-graphify-synergy.sh
${root}/tests/scripts/test-install-leanctx-sb.sh
${root}/tests/scripts/test-optimize-five-tool-stack.sh
${root}/tests/scripts/test-reconcile-recommended-tools.sh
${root}/tests/scripts/test-reload-receipts.sh
${root}/tests/scripts/test-runtime-mirror-freshness.sh
${root}/tests/scripts/test-agent-cursor-skill.sh
EOF
}

five_tool_prerelease_run_offline_bundle() {
  local root="$1"
  local test_file failures=0
  while IFS= read -r test_file; do
    [[ -n "$test_file" && -f "$test_file" ]] || continue
    echo "--- offline: $(basename "$test_file") ---"
    if bash "$test_file"; then
      printf 'PASS: offline %s\n' "$(basename "$test_file")"
    else
      printf 'FAIL: offline %s\n' "$(basename "$test_file")"
      failures=$((failures + 1))
    fi
  done < <(five_tool_prerelease_offline_tests "$root")
  return "$failures"
}

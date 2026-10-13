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

claude_should_use_interactive() {
  local prompt="$1"
  if [[ "${CLAUDE_USE_INTERACTIVE:-}" == "0" ]]; then
    return 1
  fi
  if [[ "${CLAUDE_USE_INTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  if [[ "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
    return 0
  fi
  if [[ "$prompt" =~ ^/(silver|review-triad|ship-readiness) ]]; then
    return 0
  fi
  if [[ "$prompt" =~ \[\$silver\]|\[silver\] ]]; then
    return 0
  fi
  return 1
}

agent_invoke() {
  local mode="$1"
  local prompt="$2"
  local cli
  local output
  local permission_mode
  local continue_flag
  local timeout_seconds
  local prompt_file
  local expect_script
  local sb_root

  cli="$(agent_cli_path)"
  permission_mode="${CLAUDE_PERMISSION_MODE:-acceptEdits}"
  timeout_seconds="${CLAUDE_INTERACTIVE_TIMEOUT:-${CODEX_INTERACTIVE_TIMEOUT:-300}}"
  : "${CLAUDE_PROMPT_COUNT:=0}"
  if [[ "$mode" == "permissive" ]]; then
    permission_mode="bypassPermissions"
  fi

  continue_flag=0
  if [[ "${CLAUDE_PROMPT_COUNT:-0}" -gt 0 ]]; then
    continue_flag=1
  fi

  sb_root="${SB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
  expect_script="${sb_root}/scripts/claude-interactive-invoke.expect"
  if [[ -f "${sb_root}/tests/live/lib/detach-background.sh" ]]; then
    # shellcheck source=tests/live/lib/detach-background.sh
    source "${sb_root}/tests/live/lib/detach-background.sh"
    sb_prepend_harness_path
  fi
  # shellcheck source=scripts/lib/claude-matrix-auth.sh
  source "${sb_root}/scripts/lib/claude-matrix-auth.sh"

  if claude_should_use_interactive "$prompt" && [[ -x "$expect_script" ]] && command -v expect >/dev/null 2>&1; then
    prompt_file="$(mktemp "${TMPDIR:-/tmp}/claude-live-prompt.XXXXXX")"
    printf '%s' "$prompt" >"$prompt_file"
    run_expect() {
      if [[ "${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-0}" == "1" ]]; then
        claude_matrix_auth_prepare
        trap 'claude_matrix_auth_restore' RETURN
      fi
      local -a spawn_env=(
        "HOME=${HOME}"
        "TERM=${TERM:-xterm-256color}"
        "CLAUDE_BIN=${cli}"
        "CLAUDE_WORK_DIR=${WORK_DIR}"
        "CLAUDE_PROMPT_FILE=${prompt_file}"
        "CLAUDE_MODEL=${CLAUDE_MODEL:-sonnet}"
        "CLAUDE_EFFORT=${CLAUDE_EFFORT:-low}"
        "CLAUDE_PERMISSION_MODE=${permission_mode}"
        "CLAUDE_CONTINUE=${continue_flag}"
        "CLAUDE_INTERACTIVE_TIMEOUT=${timeout_seconds}"
        "CLAUDE_INTERACTIVE_QUIET_TIMEOUT=${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-120}"
        "CLAUDE_INTERACTIVE_READY_DELAY_MS=${CLAUDE_INTERACTIVE_READY_DELAY_MS:-1000}"
        "SB_E2E_MATRIX_CLEAN_ENV=${SB_E2E_MATRIX_CLEAN_ENV:-0}"
        "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-0}"
        "CLAUDE_PRINT_SKIP_SETTINGS_EXPORT=${CLAUDE_PRINT_SKIP_SETTINGS_EXPORT:-0}"
        "CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-keys}"
        "CLAUDE_INTERACTIVE_READY_TIMEOUT=${CLAUDE_INTERACTIVE_READY_TIMEOUT:-300}"
        "CLAUDE_INTERACTIVE_BYPASS_STRATEGY=${CLAUDE_INTERACTIVE_BYPASS_STRATEGY:-arrow}"
      )
      if [[ -n "${CLAUDE_INTERACTIVE_LOG_FILE:-}" ]]; then
        spawn_env+=("CLAUDE_INTERACTIVE_LOG_FILE=${CLAUDE_INTERACTIVE_LOG_FILE}")
      fi
      if [[ -n "${SB_E2E_MATRIX_EVIDENCE_PATH:-}" ]]; then
        spawn_env+=("SB_E2E_MATRIX_EVIDENCE_PATH=${SB_E2E_MATRIX_EVIDENCE_PATH}")
      fi
      if [[ -n "${SB_E2E_ENTERPRISE_MATRIX:-}" ]]; then
        spawn_env+=("SB_E2E_ENTERPRISE_MATRIX=${SB_E2E_ENTERPRISE_MATRIX}")
      fi
      if [[ -n "${SB_E2E_MATRIX_ROUTING_ROW:-}" ]]; then
        spawn_env+=("SB_E2E_MATRIX_ROUTING_ROW=${SB_E2E_MATRIX_ROUTING_ROW}")
      fi
      local kv
      while IFS= read -r kv; do
        [[ -n "$kv" ]] && spawn_env+=("$kv")
      done < <(claude_matrix_auth_env_lines)
      claude_matrix_export_settings_env
      cd "$WORK_DIR" && env "${spawn_env[@]}" expect "$expect_script" 2>&1
    }
    if [[ "${SB_E2E_MATRIX_CLEAN_ENV:-0}" == "1" ]]; then
      # Opt-in env -i + bash -c (not -lc) for OAuth/key-conflict isolation only.
      # Default (SB_E2E_MATRIX_CLEAN_ENV=0) inherits caller auth — env -i strips
      # keychain/HOME credentials and often yields "Not logged in" in interactive TUI.
      # Also strip ~/.codex/settings.json env keys — Claude reads API keys there
      # even when the shell env is empty, which conflicts with claude.ai OAuth.
      claude_matrix_auth_prepare
      trap 'claude_matrix_auth_restore' RETURN
      output=$(
        env -i \
          HOME="${HOME}" \
          USER="${USER:-}" \
          LOGNAME="${LOGNAME:-${USER:-}}" \
          SHELL="${SHELL:-/bin/bash}" \
          PATH="${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}" \
          TERM="${TERM:-xterm-256color}" \
          TMPDIR="${TMPDIR:-/tmp}" \
          CLAUDE_BIN="$cli" \
          CLAUDE_WORK_DIR="$WORK_DIR" \
          CLAUDE_PROMPT_FILE="$prompt_file" \
          CLAUDE_MODEL="${CLAUDE_MODEL:-haiku}" \
          CLAUDE_EFFORT="${CLAUDE_EFFORT:-low}" \
          CLAUDE_PERMISSION_MODE="$permission_mode" \
          CLAUDE_CONTINUE="$continue_flag" \
          CLAUDE_INTERACTIVE_TIMEOUT="$timeout_seconds" \
          CLAUDE_INTERACTIVE_QUIET_TIMEOUT="${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-120}" \
          CLAUDE_INTERACTIVE_READY_DELAY_MS="${CLAUDE_INTERACTIVE_READY_DELAY_MS:-1000}" \
          CLAUDE_INTERACTIVE_READY_TIMEOUT="${CLAUDE_INTERACTIVE_READY_TIMEOUT:-60}" \
          bash -c 'unset ANTHROPIC_API_KEY OPENAI_API_KEY; export ANTHROPIC_API_KEY=; cd "$CLAUDE_WORK_DIR" && expect "$1" 2>&1' _ "$expect_script"
      ) || true
      claude_matrix_auth_restore
      trap - RETURN
    else
      output="$(run_expect)" || true
    fi
    rm -f -- "$prompt_file"
    printf '%s' "$output"
    CLAUDE_PROMPT_COUNT=$((CLAUDE_PROMPT_COUNT + 1))
    return 0
  fi

  if [[ "${CLAUDE_PRINT_SKIP_SETTINGS_EXPORT:-0}" != "1" ]]; then
    claude_matrix_export_settings_env
  fi
  output=$(
    cd "$WORK_DIR" && \
      HOME="${HOME}" \
      SB_AGENT_CERT_RUN="${SB_AGENT_CERT_RUN:-}" \
      CLAUDE_LIVE_CLI="$cli" \
      CLAUDE_LIVE_PROMPT="$prompt" \
      CLAUDE_LIVE_PERMISSION_MODE="$permission_mode" \
      CLAUDE_LIVE_CONTINUE="$continue_flag" \
      CLAUDE_LIVE_TIMEOUT="$timeout_seconds" \
      python3 - <<'PY'
import os
import subprocess
import sys

cli = os.environ["CLAUDE_LIVE_CLI"]
prompt = os.environ["CLAUDE_LIVE_PROMPT"]
timeout = int(os.environ.get("CLAUDE_LIVE_TIMEOUT") or "300")
args = [
    cli,
    "--print",
    "--model",
    os.environ.get("CLAUDE_MODEL", "haiku"),
    "--effort",
    os.environ.get("CLAUDE_EFFORT", "low"),
    "--permission-mode",
    os.environ["CLAUDE_LIVE_PERMISSION_MODE"],
]
if os.environ.get("CLAUDE_PRINT_VERBOSE", "1") != "0":
    args.append("--verbose")
if os.environ.get("CLAUDE_LIVE_CONTINUE") == "1":
    args.append("--continue")
args.append(prompt)

try:
    env = os.environ.copy()
    cert = os.environ.get("SB_AGENT_CERT_RUN", "")
    marker = os.path.join(os.getcwd(), ".silver-bullet", "agent-cert-run")
    if os.path.isfile(marker) and not os.path.islink(marker):
        env["SB_AGENT_CERT_RUN"] = "1"
    elif cert:
        env["SB_AGENT_CERT_RUN"] = cert
    result = subprocess.run(
        args,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
        env=env,
    )
    if result.stdout:
        sys.stdout.write(result.stdout)
    sys.exit(result.returncode)
except subprocess.TimeoutExpired as exc:
    if exc.stdout:
        sys.stdout.write(exc.stdout if isinstance(exc.stdout, str) else exc.stdout.decode(errors="replace"))
    sys.stdout.write(f"\nERROR: timed out waiting for Claude prompt to complete after {timeout}s\n")
    sys.exit(124)
PY
  ) || true

  printf '%s' "$output"

  CLAUDE_PROMPT_COUNT=$((CLAUDE_PROMPT_COUNT + 1))
}

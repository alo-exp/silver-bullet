#!/usr/bin/env bash
# Cursor CLI routing smoke for pre-release gate (isolated env, no Keychain).
#
# Credential store: CURSOR_API_KEY env var only, passed via --api-key to cursor-agent.
# Optional file fallback: ${SB_PRE_RELEASE_SMOKE_ROOT}/.cursor-api-key (gitignored temp).
# Sets AGENT_CLI_CREDENTIAL_STORE=memory so cursor-agent never touches macOS Keychain
# (cursor-user / security find-generic-password).
#
# Never calls: cursor-agent login, cursor-agent status, security(1).
#
# Usage (from run-pre-release-host-smoke.sh or standalone):
#   CURSOR_API_KEY=... AGENT_CLI_CREDENTIAL_STORE=memory \
#     bash scripts/pre-release-cursor-cli-smoke.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export SB_PRE_RELEASE_REPO_ROOT="$REPO_ROOT"

# shellcheck source=scripts/lib/pre-release-host-isolation.sh
source "${SCRIPT_DIR}/lib/pre-release-host-isolation.sh"

cli="$(command -v cursor-agent 2>/dev/null || true)"
if [[ -z "$cli" ]]; then
  cli="$(command -v agent 2>/dev/null || true)"
fi
if [[ -z "$cli" ]]; then
  printf 'ERROR: cursor-agent CLI not found on PATH\n' >&2
  exit 1
fi
if ! "$cli" --version >/dev/null 2>&1; then
  printf 'ERROR: cursor-agent CLI not working\n' >&2
  exit 1
fi

if ! sb_smoke_cursor_cli_auth_env; then
  printf 'ERROR: CURSOR_API_KEY required (env or %s/.cursor-api-key in smoke root)\n' "$(sb_smoke_root)" >&2
  printf 'Do not use cursor-agent login — Keychain storage is disabled for pre-release smoke.\n' >&2
  exit 1
fi

sb_smoke_begin_cursor
root="$(sb_smoke_host_root cursor)"
workspace="${root}/cli-workspace"
mkdir -p "$workspace"

if ! bash "${REPO_ROOT}/scripts/install-cursor.sh" >/dev/null 2>&1; then
  printf 'ERROR: install-cursor.sh failed in isolated CURSOR_HOME\n' >&2
  exit 1
fi

timeout_seconds="${CURSOR_AGENT_TIMEOUT:-120}"
model="${CURSOR_AGENT_MODEL:-${CURSOR_MODEL:-}}"

out="$(
  cd "$workspace" && \
    AGENT_CLI_CREDENTIAL_STORE=memory \
    CURSOR_AGENT_CLI="$cli" \
    CURSOR_API_KEY="$CURSOR_API_KEY" \
    CURSOR_AGENT_PROMPT="Reply with exactly one line: SB_ROUTING_OK. Do not use tools." \
    CURSOR_AGENT_TIMEOUT="$timeout_seconds" \
    CURSOR_AGENT_MODEL="$model" \
    python3 - <<'PY'
import os
import subprocess
import sys

cli = os.environ["CURSOR_AGENT_CLI"]
api_key = os.environ["CURSOR_API_KEY"]
prompt = os.environ["CURSOR_AGENT_PROMPT"]
timeout = int(os.environ.get("CURSOR_AGENT_TIMEOUT") or "120")
model = os.environ.get("CURSOR_AGENT_MODEL") or ""

args = [
    cli,
    "--print",
    "--trust",
    "--force",
    "--api-key", api_key,
    "--workspace", os.getcwd(),
    "--output-format", "text",
]
if model:
    args.extend(["--model", model])
args.append(prompt)

env = os.environ.copy()
env["AGENT_CLI_CREDENTIAL_STORE"] = "memory"
env["CURSOR_API_KEY"] = api_key

try:
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
    sys.stdout.write(f"\nERROR: timed out after {timeout}s\n")
    sys.exit(124)
PY
)" || true

if printf '%s' "$out" | grep -qi 'SB_ROUTING_OK'; then
  printf 'pre-release-cursor-cli-smoke: PASS\n'
  exit 0
fi

printf 'pre-release-cursor-cli-smoke: FAIL\n' >&2
printf '  snippet: %s\n' "$(printf '%s' "$out" | head -c 400)" >&2
exit 1

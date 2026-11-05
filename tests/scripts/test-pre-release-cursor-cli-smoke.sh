#!/usr/bin/env bash
# pre-release-cursor-cli-smoke.sh against a stub cursor-agent: CLI discovery,
# credential gate, plugin-dir gate, argument/environment hand-off, PASS/FAIL
# verdict and the timeout path. No real Cursor CLI, network or Keychain.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# The script derives its repo root from its own path: use a minimal tree whose
# plugins/silver-bullet we control.
T="$TL_TMP/tree"
mkdir -p "$T/scripts/lib"
cp "$TL_REPO_ROOT/scripts/pre-release-cursor-cli-smoke.sh" "$T/scripts/"
cp "$TL_REPO_ROOT/scripts/lib/pre-release-host-isolation.sh" "$T/scripts/lib/"
SCRIPT="$T/scripts/pre-release-cursor-cli-smoke.sh"
SMOKE_ROOT="$TL_TMP/smoke-root"
mkdir -p "$SMOKE_ROOT"
CALLS="$TL_TMP/cli-calls.log"

# Stub CLI: --version succeeds; otherwise logs args + relevant env, then prints
# whatever CLI_OUTPUT says (default: the expected routing token).
cli_stub_body='
if [[ "${1:-}" == "--version" ]]; then echo "stub 1.0"; exit "${STUB_VERSION_RC:-0}"; fi
{
  printf "ARG=%s\n" "$@"
  echo "ENV_STORE=${AGENT_CLI_CREDENTIAL_STORE-}"
  echo "ENV_KEY=${CURSOR_API_KEY-}"
  echo "ENV_CONFIG=${CURSOR_CONFIG_DIR-}"
  echo "CWD=$PWD"
} >>"'"$CALLS"'"
if [[ -n "${STUB_HANG:-}" ]]; then echo partial-output; exec sleep 30; fi
printf "%s\n" "${CLI_OUTPUT:-reply: SB_ROUTING_OK}"
exit "${CLI_RC:-0}"'

run_smoke() {
  tl_run env -u CURSOR_API_KEY -u HOST_API_KEY -u CURSOR_AGENT_MODEL -u CURSOR_MODEL \
    SB_PRE_RELEASE_SMOKE_ROOT="$SMOKE_ROOT" "$@" timeout 60 bash "$SCRIPT"
}

# --- no CLI -------------------------------------------------------------
NOCLI="$(tl_path_without cursor-agent agent)"
run_smoke PATH="$NOCLI" CURSOR_API_KEY=k
assert_eq "no CLI exits 1" 1 "$TL_STATUS"
assert_contains "no CLI reported" "$TL_ERR" "cursor-agent CLI not found on PATH"
assert_contains "no CLI: override named" "$TL_ERR" "CURSOR_AGENT_BIN"
# R8-10: a bare `agent` binary is not trusted with the API key.
mkdir -p "$TL_TMP/agentbin"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/agent-calls.log"\necho SB_ROUTING_OK\n' "$TL_TMP" >"$TL_TMP/agentbin/agent"
chmod +x "$TL_TMP/agentbin/agent"
mkdir -p "$T/plugins/silver-bullet"
run_smoke PATH="$TL_TMP/agentbin:$NOCLI" CURSOR_API_KEY=k
assert_eq "bare agent binary is not used" 1 "$TL_STATUS"
assert_file_absent "bare agent binary never ran" "$TL_TMP/agent-calls.log"
rmdir "$T/plugins/silver-bullet"

# --- broken CLI ---------------------------------------------------------
tl_stub cursor-agent "$cli_stub_body"
run_smoke CURSOR_API_KEY=k STUB_VERSION_RC=1
assert_eq "broken CLI exits 1" 1 "$TL_STATUS"
assert_contains "broken CLI reported" "$TL_ERR" "cursor-agent CLI not working"

# --- no credential ------------------------------------------------------
run_smoke
assert_eq "missing key exits 1" 1 "$TL_STATUS"
assert_contains "missing key explained" "$TL_ERR" "CURSOR_API_KEY required"
assert_contains "key file locations named" "$TL_ERR" "$SMOKE_ROOT/.cursor-api-key"
assert_contains "keychain login discouraged" "$TL_ERR" "Do not use cursor-agent login"

# --- plugin dir missing -------------------------------------------------
run_smoke CURSOR_API_KEY=k
assert_eq "missing plugin dir exits 1" 1 "$TL_STATUS"
assert_contains "missing plugin dir named" "$TL_ERR" "plugin dir missing at"
assert_file_absent "CLI not invoked without a plugin dir" "$CALLS"

# --- success ------------------------------------------------------------
mkdir -p "$T/plugins/silver-bullet"
run_smoke CURSOR_API_KEY=secret-key CURSOR_AGENT_MODEL=m-1 CURSOR_AGENT_TIMEOUT=20
assert_eq "routing OK exits 0" 0 "$TL_STATUS"
assert_contains "PASS verdict" "$TL_OUT" "pre-release-cursor-cli-smoke: PASS"
calls="$(<"$CALLS")"
assert_contains "print mode" "$calls" "ARG=--print"
assert_contains "trust flag" "$calls" "ARG=--trust"
# R8-10: the key reaches the CLI through its environment only, never argv
# (argv is world-readable through ps and /proc/<pid>/cmdline).
assert_not_contains "api key never on the command line" "$calls" "ARG=secret-key"
assert_not_contains "no --api-key flag" "$calls" "ARG=--api-key"
assert_contains "plugin dir passed" "$calls" "ARG=$T/plugins/silver-bullet"
assert_contains "workspace under the smoke root" "$calls" "ARG=$SMOKE_ROOT/cursor/workspace"
assert_contains "model passed" "$calls" "ARG=m-1"
assert_contains "prompt passed last" "$calls" "ARG=Reply with exactly one line: SB_ROUTING_OK. Do not use tools."
assert_contains "credential store forced to memory" "$calls" "ENV_STORE=memory"
assert_contains "api key in env" "$calls" "ENV_KEY=secret-key"
assert_contains "isolated config dir" "$calls" "ENV_CONFIG=$SMOKE_ROOT/cursor/fake-home/.cursor"
assert_contains "runs inside the workspace" "$calls" "CWD=$SMOKE_ROOT/cursor/workspace"
assert_file_exists "isolated cli config written" "$SMOKE_ROOT/cursor/fake-home/.cursor/cli-config.json"

# Without a model the flag is omitted; the case-insensitive token still passes.
: >"$CALLS"
run_smoke CURSOR_API_KEY=k CLI_OUTPUT="sb_routing_ok (lower case)"
assert_eq "case-insensitive token passes" 0 "$TL_STATUS"
assert_not_contains "no --model without a model" "$(<"$CALLS")" "ARG=--model"

# CURSOR_MODEL is the fallback model variable; key file is the fallback credential.
: >"$CALLS"
printf 'file-key' >"$SMOKE_ROOT/.cursor-api-key"
run_smoke CURSOR_MODEL=fallback-model
assert_eq "key file credential passes" 0 "$TL_STATUS"
assert_contains "CURSOR_MODEL used" "$(<"$CALLS")" "ARG=fallback-model"
assert_contains "key read from file" "$(<"$CALLS")" "ENV_KEY=file-key"
assert_not_contains "file key not on the command line" "$(<"$CALLS")" "ARG=file-key"
rm -f "$SMOKE_ROOT/.cursor-api-key"

# An explicit CURSOR_AGENT_BIN is used (for a CLI installed under another name).
: >"$CALLS"
cp "$TL_BIN/cursor-agent" "$TL_TMP/my-cursor-cli"
run_smoke PATH="$NOCLI" CURSOR_AGENT_BIN="$TL_TMP/my-cursor-cli" CURSOR_API_KEY=k
assert_eq "CURSOR_AGENT_BIN override runs" 0 "$TL_STATUS"
assert_contains "override CLI received the call" "$(<"$CALLS")" "ARG=--print"

# R8-11: standalone (no smoke root given) the run pins one root and removes it.
STANDALONE_TMP="$TL_TMP/standalone-tmp"
mkdir -p "$STANDALONE_TMP"
tl_run env -u CURSOR_API_KEY -u HOST_API_KEY -u SB_PRE_RELEASE_SMOKE_ROOT TMPDIR="$STANDALONE_TMP" \
  CURSOR_API_KEY=k timeout 60 bash "$SCRIPT"
assert_eq "standalone run passes" 0 "$TL_STATUS"
assert_eq "standalone run leaves no smoke roots behind" "" "$(ls -A "$STANDALONE_TMP")"
# A caller's root (operator directory) is reused and kept, contents intact.
mkdir -p "$TL_TMP/operator-root/keep"; echo mine >"$TL_TMP/operator-root/keep/notes"
tl_run env -u CURSOR_API_KEY -u HOST_API_KEY SB_PRE_RELEASE_SMOKE_ROOT="$TL_TMP/operator-root" \
  CURSOR_API_KEY=k timeout 60 bash "$SCRIPT"
assert_eq "operator root run passes" 0 "$TL_STATUS"
assert_eq "operator root kept with its files" mine "$(cat "$TL_TMP/operator-root/keep/notes")"

# --- failure verdicts ---------------------------------------------------
long="$(printf 'x%.0s' $(seq 1 600))"
run_smoke CURSOR_API_KEY=k CLI_OUTPUT="wrong answer $long"
assert_eq "wrong answer exits 1" 1 "$TL_STATUS"
assert_contains "FAIL verdict" "$TL_ERR" "pre-release-cursor-cli-smoke: FAIL"
assert_contains "snippet shows the answer" "$TL_ERR" "snippet: wrong answer"
assert_not_contains "snippet is capped at 400 bytes" "$TL_ERR" "$(printf 'x%.0s' $(seq 1 420))"

# A CLI that exits non-zero without the token fails; with the token it still
# counts (the verdict is the routing token, not the exit code).
run_smoke CURSOR_API_KEY=k CLI_OUTPUT="boom" CLI_RC=9
assert_eq "failing CLI without token exits 1" 1 "$TL_STATUS"

# --- timeout ------------------------------------------------------------
run_smoke CURSOR_API_KEY=k STUB_HANG=1 CURSOR_AGENT_TIMEOUT=1
assert_eq "hanging CLI exits 1" 1 "$TL_STATUS"
assert_contains "timeout reported" "$TL_ERR" "ERROR: timed out after 1s"
assert_contains "partial output kept" "$TL_ERR" "partial-output"

tl_results

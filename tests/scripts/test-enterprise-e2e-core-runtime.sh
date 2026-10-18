#!/usr/bin/env bash
# Behaviour tests for the install, TUI-offset, runtime-path, auth-preflight and Session 0
# helpers in scripts/enterprise-e2e/lib/core.sh. Agent CLIs and installers are stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/enterprise-e2e-helpers.sh"
tl_init

CORE="$TL_REPO_ROOT/scripts/enterprise-e2e/lib/core.sh"
CFG="$TL_TMP/hosts.json"
echo '{"default_host": "claude", "hosts": {}}' >"$CFG"
BASE_ENV=("SILVER_BULLET_RUNTIME=claude" "SB_E2E_HOSTS_CONFIG=$CFG")
# run BODY ENV...: source core.sh then evaluate BODY.
run() {
  local body="$1"
  shift
  e2e_script "source '$CORE'; $body" "${BASE_ENV[@]}" "$@"
}

# --- install-claude --------------------------------------------------------
mkdir -p "$TL_TMP/sb/scripts" "$TL_TMP/sb/tests/live/lib"
cat >"$TL_TMP/sb/tests/live/lib/detach-background.sh" <<'S'
sb_prepend_harness_path() { echo "harness-path-prepended" >>"$HARNESS_MARK"; }
S
cat >"$TL_TMP/sb/scripts/install-claude.sh" <<'S'
echo "interactive-install-ran"
S
export HARNESS_MARK="$TL_TMP/harness.mark"
SB="$TL_TMP/sb"

run "enterprise_e2e_run_install_claude" "SB_ROOT="
assert_eq "install: no root fails" 1 "$TL_STATUS"
run "enterprise_e2e_run_install_claude '$TL_TMP/nope'" "SB_ROOT="
assert_eq "install: missing root dir fails" 1 "$TL_STATUS"

LOGF="$TL_TMP/install.log"
printf 'x\nClaude marketplaces registered\ndone\n' >"$LOGF"
run "enterprise_e2e_run_install_claude '$SB'" "SB_E2E_INSTALL_CLAUDE_LOG=$LOGF" "HARNESS_MARK=$HARNESS_MARK" "SB_ROOT=$SB"
assert_eq "install: cached marker short-circuits" 0 "$TL_STATUS"
assert_contains "install: cached message" "$TL_OUT" "Plugin install (cached — see $LOGF):"
assert_contains "install: cached tail shows the marker" "$TL_OUT" "Claude marketplaces registered"
assert_not_contains "install: cached run does not install" "$TL_OUT" "interactive-install-ran"
assert_contains "install: harness path prepended first" "$(cat "$HARNESS_MARK")" "harness-path-prepended"

# Detached branch (no tty): stubbed sb_run_detached_pty.
run_detached() {  # run_detached STUB-BODY LOGCONTENT SETUP [env...]
  local stub="$1" content="$2" setup="$3"
  shift 3
  printf '%s' "$content" >"$LOGF"
  run "$setup
sb_run_detached_pty() { $stub; }
enterprise_e2e_run_install_claude '$SB'" "SB_E2E_INSTALL_CLAUDE_LOG=$LOGF" "HARNESS_MARK=$HARNESS_MARK" "SB_ROOT=$SB" "$@"
}
run_detached 'echo "args:$*" >>"'"$TL_TMP"'/pty.args"; echo "Claude marketplace refreshed" >>"$2"; echo $$' "" ":"
assert_eq "install: detached install completes on the marker" 0 "$TL_STATUS"
assert_contains "install: announces latest checkout install" "$TL_OUT" "Plugin install (latest SB checkout):"
assert_contains "install: tails the finished log" "$TL_OUT" "Claude marketplace refreshed"
assert_contains "install: installer launched through bash -c in the SB root" "$(cat "$TL_TMP/pty.args")" "--log $LOGF -- bash -c cd $SB && exec bash scripts/install-claude.sh </dev/null"
# Child died before the marker.
DEAD_PID="$(bash -c 'echo $$')"
run_detached "echo 'partial output' >>\"\$2\"; echo $DEAD_PID" "" ":"
assert_eq "install: dead installer without marker fails" 1 "$TL_STATUS"
assert_contains "install: early-exit error" "$TL_ERR" "ERROR: install-claude exited before completion — see $LOGF"
assert_contains "install: early-exit shows the log" "$TL_ERR" "partial output"
# Marker lands in the window between the loop check and the liveness check:
# grep reports no marker for the first two probes, then the real result.
tl_stub grep 'if [[ "$*" == *"Claude marketplaces registered"* ]]; then n=0; [ -f "$GREP_COUNT" ] && n=$(cat "$GREP_COUNT"); n=$((n+1)); echo $n >"$GREP_COUNT"; [ "$n" -le 2 ] && exit 1; fi; exec /usr/bin/env -S PATH=/usr/bin:/bin grep "$@"'
rm -f "$TL_TMP/grep.count"
run_detached "echo 'Claude marketplaces registered' >>\"\$2\"; echo $DEAD_PID" "" ":" "GREP_COUNT=$TL_TMP/grep.count"
assert_eq "install: marker seen once the child exited counts as success" 0 "$TL_STATUS"
rm -f "$TL_BIN/grep"
# Timeout: sleep advances SECONDS; the installer pid stays alive.
# The "installer" is a tail started in the stub's subshell; its pid is recorded so the test
# can stop exactly that process afterwards (pkill -P on the test shell never matched it).
run_detached 'tail -f /dev/null >/dev/null 2>&1 & echo $! >"'"$TL_TMP"'/installer.pid"; echo $!' "" 'sleep() { SECONDS=$((SECONDS + 200)); }'
assert_eq "install: timeout fails" 1 "$TL_STATUS"
assert_contains "install: timeout message" "$TL_ERR" "ERROR: install-claude timed out after 300s — see $LOGF"
installer_pid="$(cat "$TL_TMP/installer.pid")"
kill "$installer_pid" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$installer_pid" 2>/dev/null || break; command -p sleep 0.2; done
assert_eq "install: timed-out installer stopped by the test" 1 "$(kill -0 "$installer_pid" 2>/dev/null && echo 0 || echo 1)"

# Interactive branch needs a real tty on stdin and stdout: drive it through a pty.
printf '' >"$LOGF"
rm -f "$LOGF"
if python3 -c 'import pty' 2>/dev/null; then
  tl_run python3 -c 'import os, pty, sys
status = pty.spawn(sys.argv[1:])
sys.exit(os.waitstatus_to_exitcode(status))' \
    env "SILVER_BULLET_RUNTIME=claude" "SB_E2E_HOSTS_CONFIG=$CFG" "SB_E2E_INSTALL_CLAUDE_LOG=$LOGF" "HARNESS_MARK=$HARNESS_MARK" \
    bash -c "set -euo pipefail; source '$CORE'; enterprise_e2e_run_install_claude '$SB'"
  assert_eq "install: interactive tty runs the installer directly" 0 "$TL_STATUS"
  assert_contains "install: interactive installer output" "$TL_OUT" "interactive-install-ran"
else
  echo "SKIP: python3 pty module unavailable"
fi

# --- quiesce wrapper ---------------------------------------------------------
mkdir -p "$SB/scripts/lib"
echo 'enterprise_e2e_matrix_quiesce_orchestrator_queue() { echo "quiesced:$1"; }' >"$SB/scripts/lib/enterprise-e2e-matrix-quiesce.sh"
run "enterprise_e2e_quiesce_orchestrator_queue '$TL_TMP/nope'" "SB_ROOT="
assert_eq "quiesce: missing root fails" 1 "$TL_STATUS"
run "enterprise_e2e_quiesce_orchestrator_queue '$SB'" "SB_ROOT="
assert_eq "quiesce: delegates to the shared helper" "quiesced:$SB" "$TL_OUT"
run "enterprise_e2e_quiesce_orchestrator_queue" "SB_ROOT=$SB"
assert_eq "quiesce: root defaults to SB_ROOT" "quiesced:$SB" "$TL_OUT"

# --- TUI monitor offsets -----------------------------------------------------
TUI="$TL_TMP/tui"
mkdir -p "$TUI"
printf 'abc' >"$TUI/.e2e-row1-attempt.log"
printf 'abcdef' >"$TUI/.e2e-row2-attempt.log"
printf 'zz' >"$TUI/.e2e-row1-codex-attempt.log"
run "enterprise_e2e_reset_tui_monitor_offsets '$TL_TMP/nope'" "SB_ROOT="
assert_eq "tui offsets: missing root fails" 1 "$TL_STATUS"
run "enterprise_e2e_reset_tui_monitor_offsets '$TUI'" "SB_E2E_LIVE_RUNTIME=claude" "SB_ROOT="
assert_eq "tui offsets: claude reset ok" 0 "$TL_STATUS"
assert_contains "tui offsets: reports claude row logs" "$TL_OUT" "tui-watch offsets reset (3 row logs) -> $TUI/.e2e-tui-watch-offsets.json"
assert_eq "tui offsets: claude offsets are the file sizes" '{".e2e-row1-attempt.log":3,".e2e-row1-codex-attempt.log":2,".e2e-row2-attempt.log":6}' "$(jq -cS . "$TUI/.e2e-tui-watch-offsets.json")"
assert_contains "tui offsets: agent offset written with 0 findings" "$(cat "$TUI/.planning/enterprise-e2e/.tui-monitor-agent-offset.json")" '"findings_line": 0'
assert_eq "tui offsets: reset reason recorded" "round_start" "$(jq -r .reset_reason "$TUI/.planning/enterprise-e2e/.tui-monitor-agent-offset.json")"
printf 'f1\nf2\nf3\n' >"$TUI/.e2e-tui-watch-codex-findings.jsonl"
run "enterprise_e2e_reset_tui_monitor_offsets '$TUI'" "SB_E2E_LIVE_RUNTIME=codex" "SB_ROOT="
assert_contains "tui offsets: codex host uses its own row logs" "$TL_OUT" "tui-watch offsets reset (1 row logs) -> $TUI/.e2e-tui-watch-codex-offsets.json"
assert_eq "tui offsets: codex findings line count" "3" "$(jq -r .findings_line "$TUI/.planning/enterprise-e2e/.tui-monitor-agent-offset.json")"
assert_contains "tui offsets: summary line" "$TL_OUT" "tui-monitor-agent-offset reset findings_line=3"
run "enterprise_e2e_reset_tui_monitor_offsets" "SB_E2E_LIVE_RUNTIME=claude" "SB_ROOT=$TUI" "SB_E2E_TUI_OFFSETS=$TL_TMP/custom-offsets.json" "SB_E2E_TUI_FINDINGS=$TL_TMP/none.jsonl"
assert_file_exists "tui offsets: custom offsets path honoured" "$TL_TMP/custom-offsets.json"
assert_contains "tui offsets: missing findings file counts 0" "$TL_OUT" "findings_line=0"

# --- prepend harness path ----------------------------------------------------
rm -f "$HARNESS_MARK"
run "enterprise_e2e_prepend_harness_path" "SB_ROOT=$SB" "HARNESS_MARK=$HARNESS_MARK"
assert_eq "prepend: sources the detach helper and calls it" "harness-path-prepended" "$(cat "$HARNESS_MARK")"
rm -f "$HARNESS_MARK"
run "enterprise_e2e_prepend_harness_path" "SB_ROOT=$TL_TMP/no-detach" "HARNESS_MARK=$HARNESS_MARK"
assert_file_absent "prepend: nothing without the helper" "$HARNESS_MARK"
run "enterprise_e2e_prepend_harness_path; echo ok" "-u" "SB_ROOT"
assert_eq "prepend: SB_ROOT derived from the harness when unset" "ok" "$TL_OUT"

# --- matrix MCP environment --------------------------------------------------
FIXT="$TL_TMP/fixture"
mkdir -p "$FIXT"
cat >"$TL_TMP/fake-claude" <<'S'
#!/usr/bin/env bash
cat <<'OUT'
Checking MCP server health...

plugin:design:figma: https://x - ! Needs authentication
plugin:engineering:github: https://y - ✗ Failed to connect
plugin:agentmemory:mem: cmd - ✗ Failed to connect
local-srv: cmd - ✗ Failed to connect
healthy: cmd - ✓ Connected
junk line without a colon
OUT
S
chmod +x "$TL_TMP/fake-claude"
mkdir -p "$HOME/.claude"
echo '{"stale": true}' >"$HOME/.claude/mcp-needs-auth-cache.json"
run "enterprise_e2e_prepare_matrix_mcp_env '$FIXT'" "CLAUDE_BIN=$TL_TMP/fake-claude"
assert_eq "mcp env: ok" 0 "$TL_STATUS"
assert_contains "mcp env: reports disabled servers" "$TL_OUT" "matrix MCP env: disabled 3 server(s) for TUI"
assert_eq "mcp env: disabled list excludes agentmemory and connected servers" \
  '["local-srv","plugin:design:figma","plugin:engineering:github"]' "$(jq -c .disabledMcpjsonServers "$FIXT/.claude/settings.local.json")"
assert_eq "mcp env: auto permission mode" "auto" "$(jq -r .permissions.defaultMode "$FIXT/.claude/settings.local.json")"
assert_eq "mcp env: needs-auth cache cleared" "{}" "$(jq -c . "$HOME/.claude/mcp-needs-auth-cache.json")"
run "enterprise_e2e_prepare_matrix_mcp_env '$FIXT'" "CLAUDE_BIN=$TL_TMP/absent-claude"
assert_contains "mcp env: no claude binary disables nothing" "$TL_OUT" "disabled 0 server(s)"
run "enterprise_e2e_prepare_matrix_mcp_env" "CLAUDE_BIN=$TL_TMP/absent-claude" "SB_TEST_ENTERPRISE_APP_ROOT=$TL_TMP/fixture-default"
assert_file_exists "mcp env: fixture dir defaults from the harness" "$TL_TMP/fixture-default/.claude/settings.local.json"

# --- isolated Claude runtime paths ------------------------------------------
ISO="$TL_TMP/iso"
mkdir -p "$ISO/plain" "$ISO/nested/.claude"
iso() {  # iso CONFIG_DIR ENV...
  local dir="$1"
  shift
  run 'enterprise_e2e_apply_isolated_claude_runtime_paths; echo "HOME_ROOT=${SB_RUNTIME_HOME_ROOT:-} STATE=${SB_RUNTIME_STATE_DIR:-} PRESERVE=${SB_RUNTIME_PRESERVE_STATE_DIR:-} EXTRA=${SB_RUNTIME_EXTRA_STATE_ROOTS:-}"' \
    -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_PRESERVE_STATE_DIR -u SB_RUNTIME_EXTRA_STATE_ROOTS "CLAUDE_CONFIG_DIR=$dir" "$@"
}
iso "$ISO/plain"
assert_contains "isolated: flag off is a no-op" "$TL_OUT" "HOME_ROOT= STATE= PRESERVE= EXTRA="
iso "" "SB_E2E_ISOLATED_CLAUDE_CONFIG=1"
assert_contains "isolated: no config dir is a no-op" "$TL_OUT" "HOME_ROOT= STATE= PRESERVE= EXTRA="
iso "$ISO/plain" "SB_E2E_ISOLATED_CLAUDE_CONFIG=1"
assert_contains "isolated: plain config dir is the runtime home" "$TL_OUT" "HOME_ROOT=$ISO/plain STATE=$ISO/plain/.silver-bullet PRESERVE=1 EXTRA=$ISO/plain/.silver-bullet"
assert_eq "isolated: state dir created" "yes" "$([[ -d "$ISO/plain/.silver-bullet" ]] && echo yes || echo no)"
iso "$ISO/nested" "SB_E2E_ISOLATED_CLAUDE_CONFIG=1"
assert_contains "isolated: nested .claude is preferred" "$TL_OUT" "HOME_ROOT=$ISO/nested/.claude STATE=$ISO/nested/.claude/.silver-bullet"
iso "$ISO/plain" "SB_E2E_ISOLATED_CLAUDE_CONFIG=1" "SB_RUNTIME_EXTRA_STATE_ROOTS=/other"
assert_contains "isolated: state dir appended to existing extra roots" "$TL_OUT" "EXTRA=/other:$ISO/plain/.silver-bullet"
iso "$ISO/plain" "SB_E2E_ISOLATED_CLAUDE_CONFIG=1" "SB_RUNTIME_EXTRA_STATE_ROOTS=/other:$ISO/plain/.silver-bullet:/z"
assert_contains "isolated: state dir not duplicated" "$TL_OUT" "EXTRA=/other:$ISO/plain/.silver-bullet:/z"

# --- export_live_defaults ----------------------------------------------------
mkdir -p "$TL_TMP/no-detach"
run 'enterprise_e2e_export_live_defaults; echo "CLEAN=$SB_E2E_MATRIX_CLEAN_ENV SKIP=$SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT ARROW=$CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY QUOTA=$SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL QUIET=$SB_E2E_WORKFLOW_QUIET_TIMEOUT MODEL=$CLAUDE_MODEL DRY=${SB_E2E_MATRIX_DRY_RUN-unset} RT=$SILVER_BULLET_RUNTIME"' \
  "SB_ROOT=$TL_TMP/no-detach" -u SB_E2E_MATRIX_CLEAN_ENV -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT -u CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY \
  -u SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL -u SB_E2E_WORKFLOW_QUIET_TIMEOUT -u CLAUDE_MODEL "SB_E2E_MATRIX_DRY_RUN=1" -u SB_TEST_ENTERPRISE_APP_ROOT
assert_eq "export defaults: matrix defaults applied, dry-run cleared" \
  "CLEAN=0 SKIP=0 ARROW=arrow QUOTA=60 QUIET=600 MODEL=haiku DRY=unset RT=claude" "$TL_OUT"
run 'enterprise_e2e_export_live_defaults; echo "CLEAN=$SB_E2E_MATRIX_CLEAN_ENV SKIP=$SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT ARROW=$CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY MODEL=$CLAUDE_MODEL"' \
  "SB_ROOT=$TL_TMP/no-detach" "SB_E2E_MATRIX_CLEAN_ENV=1" "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1" "CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY=enter" "CLAUDE_MODEL=opus" -u SB_TEST_ENTERPRISE_APP_ROOT
assert_eq "export defaults: caller values are preserved" "CLEAN=1 SKIP=1 ARROW=enter MODEL=opus" "$TL_OUT"

# --- Claude token gateway preflight -----------------------------------------
GW=(-u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u CLAUDE_CONFIG_DIR)
SET_OK="$TL_TMP/settings-ok.json"
SET_EMPTY="$TL_TMP/settings-empty.json"
echo '{"env": {"ANTHROPIC_BASE_URL": "https://gw.example"}}' >"$SET_OK"
echo '{"env": {}}' >"$SET_EMPTY"
run "enterprise_e2e_preflight_claude_token_gateway ''" "${GW[@]}" "SB_ROOT="
assert_eq "gateway: missing SB_ROOT fails" 1 "$TL_STATUS"
assert_contains "gateway: missing root message" "$TL_ERR" "SB_ROOT missing for token gateway preflight"
run "enterprise_e2e_preflight_claude_token_gateway '$TL_REPO_ROOT'" "${GW[@]}" "SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1"
assert_eq "gateway: OAuth-only skip" 0 "$TL_STATUS"
assert_contains "gateway: skip message" "$TL_OUT" "Token gateway preflight: skipped"
run "enterprise_e2e_preflight_claude_token_gateway '$TL_REPO_ROOT'" "${GW[@]}" "CLAUDE_SETTINGS_FILE=$SET_OK" -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT
assert_eq "gateway: settings env accepted" 0 "$TL_STATUS"
assert_contains "gateway: settings message" "$TL_OUT" "OK (~/.claude/settings.json has ANTHROPIC_* env)"
for var in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL; do
  e2e_script "source '$CORE'; enterprise_e2e_preflight_claude_token_gateway '$TL_REPO_ROOT'" \
    -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u CLAUDE_CONFIG_DIR -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT \
    "CLAUDE_SETTINGS_FILE=$SET_EMPTY" "$var=v" "SILVER_BULLET_RUNTIME=claude"
  assert_contains "gateway: $var in the shell env is accepted" "$TL_OUT" "OK (ANTHROPIC_* present in shell env)"
done
run "enterprise_e2e_preflight_claude_token_gateway '$TL_REPO_ROOT'" "${GW[@]}" "CLAUDE_SETTINGS_FILE=$SET_EMPTY" -u SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT
assert_eq "gateway: nothing configured fails" 1 "$TL_STATUS"
assert_contains "gateway: failure message" "$TL_ERR" "Claude token gateway not configured"

# --- Session 0 gate -----------------------------------------------------------
S0="$TL_TMP/s0"
mkdir -p "$S0/app"
cat >"$S0/pass-graph.md" <<'L'
## Session 0
| Graphify + agentmemory opted in | **Pass** |
## Next
L
cat >"$S0/pass-preflight.md" <<'L'
## Session 0
| Enterprise preflight | Pass |
L
cat >"$S0/fail.md" <<'L'
## Session 0
| Graphify + agentmemory opted in | Fail |
## Other
| Enterprise preflight | **Pass** |
L
run "enterprise_e2e_ledger_session0_pass '$S0/pass-graph.md'"; assert_eq "session0: graphify row Pass" 0 "$TL_STATUS"
run "enterprise_e2e_ledger_session0_pass '$S0/pass-preflight.md'"; assert_eq "session0: preflight row Pass" 0 "$TL_STATUS"
run "enterprise_e2e_ledger_session0_pass '$S0/fail.md'"; assert_eq "session0: Pass outside the section ignored" 1 "$TL_STATUS"
run "enterprise_e2e_ledger_session0_pass ''"; assert_eq "session0: empty ledger" 1 "$TL_STATUS"
run "enterprise_e2e_ledger_session0_pass '$S0/none.md'"; assert_eq "session0: missing ledger" 1 "$TL_STATUS"
echo '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}' >"$S0/app/.silver-bullet.json"
mkdir -p "$S0/app2"
echo '{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":false}}}' >"$S0/app2/.silver-bullet.json"
run "enterprise_e2e_fixture_code_intel_opted_in '$S0/app'"; assert_eq "opted in: both enabled" 0 "$TL_STATUS"
run "enterprise_e2e_fixture_code_intel_opted_in '$S0/app2'"; assert_eq "opted in: one disabled" 1 "$TL_STATUS"
run "enterprise_e2e_fixture_code_intel_opted_in '$S0/none'"; assert_eq "opted in: no config" 1 "$TL_STATUS"
run "enterprise_e2e_fixture_code_intel_opted_in"; assert_eq "opted in: no dir" 1 "$TL_STATUS"
run "enterprise_e2e_session0_satisfied '$S0/app2' '$S0/pass-graph.md'"; assert_eq "satisfied: by ledger" 0 "$TL_STATUS"
run "enterprise_e2e_session0_satisfied '$S0/app' '$S0/fail.md'"; assert_eq "satisfied: by fixture opt-in" 0 "$TL_STATUS"
run "enterprise_e2e_session0_satisfied '$S0/app2' '$S0/fail.md'"; assert_eq "satisfied: neither" 1 "$TL_STATUS"
run "enterprise_e2e_assert_session0_or_skip '$S0/app2' '$S0/fail.md'" "SB_E2E_SESSION0_SKIP=1" "SB_E2E_SESSION0_SKIP_REASON=dry rehearsal"
assert_eq "assert: explicit skip passes" 0 "$TL_STATUS"
assert_contains "assert: skip reason printed" "$TL_OUT" "WARN: Session 0 gate skipped (SB_E2E_SESSION0_SKIP=1): dry rehearsal"
run "enterprise_e2e_assert_session0_or_skip '$S0/app2' '$S0/fail.md'" "SB_E2E_SESSION0_SKIP=1"
assert_contains "assert: skip reason defaults to unspecified" "$TL_OUT" ": unspecified"
run "enterprise_e2e_assert_session0_or_skip '$S0/app' ''" -u SB_E2E_SESSION0_SKIP
assert_contains "assert: satisfied message" "$TL_OUT" "Session 0 gate: OK"
run "enterprise_e2e_assert_session0_or_skip '$S0/app2' '$S0/fail.md'" -u SB_E2E_SESSION0_SKIP
assert_eq "assert: unsatisfied fails" 1 "$TL_STATUS"
assert_contains "assert: unsatisfied message" "$TL_ERR" "ERROR: Session 0 not satisfied"

# --- host install / preflight dispatch ----------------------------------------
run "enterprise_e2e_run_install_host" "SB_ROOT="
assert_eq "install host: no root fails" 1 "$TL_STATUS"
mkdir -p "$TL_TMP/cursor-sb/scripts"
echo 'echo "cursor-install-ran"' >"$TL_TMP/cursor-sb/scripts/install-cursor.sh"
run "enterprise_e2e_run_install_host '$TL_TMP/cursor-sb'" "SB_E2E_LIVE_RUNTIME=cursor"
assert_eq "install host: cursor adapter used" 0 "$TL_STATUS"
assert_contains "install host: cursor installer ran" "$TL_OUT" "cursor-install-ran"
run "enterprise_e2e_run_install_host" "SB_E2E_LIVE_RUNTIME=cursor" "SB_ROOT=$TL_TMP/cursor-sb"
assert_contains "install host: root defaults to SB_ROOT" "$TL_OUT" "cursor-install-ran"
run "enterprise_e2e_preflight_host" "SB_E2E_LIVE_RUNTIME=cursor" "SB_ROOT=$TL_TMP/cursor-sb"
assert_contains "preflight host: cursor adapter used" "$TL_OUT" "Cursor preflight: cursor-agent CLI or CURSOR_API_KEY required"
run "enterprise_e2e_preflight_host '$TL_TMP/cursor-sb'" "SB_E2E_LIVE_RUNTIME=cursor" -u SB_ROOT
assert_contains "preflight host: explicit root" "$TL_OUT" "Cursor preflight"

# Without adapters the Claude helpers are the fallback.
STG="$TL_TMP/stage"
mkdir -p "$STG/scripts/enterprise-e2e/lib" "$STG/scripts/lib"
for f in core.sh host.sh test-app-branch.sh; do ln -s "$TL_REPO_ROOT/scripts/enterprise-e2e/lib/$f" "$STG/scripts/enterprise-e2e/lib/$f"; done
fallback() {
  e2e_script "source '$STG/scripts/enterprise-e2e/lib/core.sh'
enterprise_e2e_run_install_claude() { echo \"claude-install:\$1\"; }
enterprise_e2e_preflight_claude_token_gateway() { echo \"claude-preflight:\$1\"; }
$1" "${BASE_ENV[@]}" "SB_E2E_LIVE_RUNTIME=codex" "SB_ROOT=$TL_TMP/cursor-sb"
}
fallback "enterprise_e2e_run_install_host 2>/dev/null"
assert_contains "install host: missing adapter falls back to Claude install" "$TL_OUT" "claude-install:$TL_TMP/cursor-sb"
fallback "enterprise_e2e_preflight_host 2>/dev/null"
assert_contains "preflight host: missing adapter falls back to the gateway check" "$TL_OUT" "claude-preflight:$TL_TMP/cursor-sb"
# An adapter that defines nothing also falls back.
mkdir -p "$STG/scripts/enterprise-e2e/lib/adapters"
echo ': # no adapter functions' >"$STG/scripts/enterprise-e2e/lib/adapters/codex.sh"
fallback "enterprise_e2e_run_install_host"
assert_contains "install host: empty adapter falls back to Claude install" "$TL_OUT" "claude-install:$TL_TMP/cursor-sb"
fallback "enterprise_e2e_preflight_host"
assert_contains "preflight host: empty adapter falls back to the gateway check" "$TL_OUT" "claude-preflight:$TL_TMP/cursor-sb"
# An adapter install failure is the install result.
cat >"$STG/scripts/enterprise-e2e/lib/adapters/codex.sh" <<'A'
enterprise_e2e_adapter_install() { return 7; }
enterprise_e2e_adapter_preflight() { return 9; }
A
fallback "enterprise_e2e_run_install_host"
assert_eq "install host: adapter status propagated" 7 "$TL_STATUS"
fallback "enterprise_e2e_preflight_host"
assert_eq "preflight host: adapter status propagated" 9 "$TL_STATUS"

tl_results

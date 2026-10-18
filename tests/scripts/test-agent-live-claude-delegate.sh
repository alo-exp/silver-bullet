#!/usr/bin/env bash
# scripts/agent-claude-delegate.sh with a scripted adapter (staged SB root) and recording CLI
# stubs. No Claude, expect or network is ever used; `sleep` is a recording stub.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/agent-live-helpers.sh"
tl_init

DELEGATE="$TL_REPO_ROOT/scripts/agent-claude-delegate.sh"
SB="$TL_TMP/sb"
W="$TL_TMP/work"
mkdir -p "$W" "$TL_TMP/tmp"
alh_stage_sb "$SB" claude

export ALH_RECORD="$TL_TMP/record"
export ALH_COUNT="$TL_TMP/count"
export ALH_SCRIPT="$TL_TMP/script"
export ALH_ENV_KEYS="CLAUDE_USE_INTERACTIVE SB_AGENT_CLAUDE_DELEGATE SB_ORCHESTRATOR_WORKER SB_ORCHESTRATOR_PARENT CLAUDE_PERMISSION_MODE CLAUDE_WORK_DIR WORK_DIR SB_ROOT CLAUDE_INTERACTIVE_LOG_FILE CLAUDE_CONFIG_DIR SB_AGENT_IDLE_SEC RTK_DISABLED"

# Host CLIs the code must never reach: they log and fail loudly. Pinned-NI tests use CLAUDE_BIN.
for cli in claude expect codex opencode pi; do
  tl_stub "$cli" "printf '%s %s\n' $cli \"\$*\" >>'$TL_TMP/unexpected-cli.log'; exit 99"
done
tl_stub sleep "printf '%s\n' \"\$*\" >>'$TL_TMP/sleep.log'; exit 0"

export TL_TMP
export TMPDIR="$TL_TMP/tmp"
export SB_AGENT_MODE_TUI_AVAILABLE=0
unset SB_AGENT_CERT_RUN CLAUDE_PERMISSION_MODE SB_AGENT_SKIP_PREFLIGHT

# run_cd ARGS...: the delegate with the staged SB root and preflight skipped.
run_cd() {
  tl_run bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" "$@"
}

alh_script "0|ok-output"

# ---------------------------------------------------------------- argument handling
tl_run bash "$DELEGATE" --help
assert_eq "claude delegate --help exits 0" "0" "$TL_STATUS"
assert_contains "claude delegate --help usage" "$TL_OUT" "Usage: agent-claude-delegate.sh --work-dir PATH"

tl_run bash "$DELEGATE" --bogus
assert_eq "claude delegate unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "claude delegate unknown arg named" "$TL_ERR" "unknown argument: --bogus"

for flag in --work-dir --prompt --prompt-file --brief-file --log --mode --sb-root --control-dir --max-turns --max-wall-sec --idle-sec --task-id; do
  tl_run bash "$DELEGATE" "$flag"
  assert_eq "claude delegate $flag without value exits 2" "2" "$TL_STATUS"
  assert_contains "claude delegate $flag without value message" "$TL_ERR" "$flag requires a value"
done

tl_run bash "$DELEGATE" --prompt hi
assert_eq "claude delegate without --work-dir exits 2" "2" "$TL_STATUS"
assert_contains "claude delegate without --work-dir message" "$TL_ERR" "--work-dir must point to an existing directory"
tl_run bash "$DELEGATE" --prompt hi --work-dir "$TL_TMP/nonexistent"
assert_eq "claude delegate nonexistent work dir exits 2" "2" "$TL_STATUS"

run_cd --mode bogus --prompt hi
assert_eq "claude delegate invalid --mode exits 2" "2" "$TL_STATUS"
assert_contains "claude delegate invalid --mode message" "$TL_ERR" "invalid-permission-mode"
run_cd --mode auto --prompt hi
assert_eq "claude delegate --mode auto is a mode conflict" "2" "$TL_STATUS"
assert_contains "claude delegate --mode auto message" "$TL_ERR" "permission-mode-smashed"

run_cd
assert_eq "claude delegate without a prompt exits 2" "2" "$TL_STATUS"
assert_contains "claude delegate without a prompt message" "$TL_ERR" "provide --prompt, --prompt-file, or --brief-file"
run_cd --prompt 'use token=abc123 please'
assert_eq "claude delegate refuses a prompt with secrets" "2" "$TL_STATUS"
assert_contains "claude delegate secret prompt message" "$TL_ERR" "prompt contains secret patterns"
run_cd --prompt-file "$TL_TMP/no-such-prompt"
assert_eq "claude delegate missing prompt file exits 2" "2" "$TL_STATUS"
run_cd --brief-file "$TL_TMP/no-such-brief"
assert_eq "claude delegate missing brief file exits 2" "2" "$TL_STATUS"

run_cd --auto-policy bogus --prompt hi
assert_eq "claude delegate invalid --auto-policy exits 2" "2" "$TL_STATUS"
assert_contains "claude delegate invalid --auto-policy message" "$TL_ERR" "invalid-auto-policy"
run_cd --prompt hi --interaction-mode
assert_eq "claude delegate --interaction-mode without value exits 2" "2" "$TL_STATUS"
assert_contains "claude delegate --interaction-mode without value message" "$TL_ERR" "missing-interaction-mode-value"
run_cd --interactive --non-interactive --prompt hi
assert_eq "claude delegate opposite aliases exit 2" "2" "$TL_STATUS"
assert_contains "claude delegate opposite aliases message" "$TL_ERR" "opposite-aliases"
assert_eq "no adapter ran for rejected invocations" "0" "$(alh_attempts)"

# ---------------------------------------------------------------- relative paths are canonicalised
mkdir -p "$TL_TMP/rel/out"
printf 'brief from file\n' >"$TL_TMP/rel/brief.txt"
printf 'prompt from file\n' >"$TL_TMP/rel/prompt.txt"
alh_script "0|rel-ok"
pushd "$TL_TMP/rel" >/dev/null
tl_run env SB_AGENT_CLAUDE_LOG_FLOOR=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --brief-file brief.txt --log out/run.log
popd >/dev/null
assert_eq "relative brief/log run exits 0" "0" "$TL_STATUS"
assert_contains "brief file content became the prompt" "$(alh_rec)" "prompt=brief from file"
assert_file_exists "relative --log landed next to the cwd" "$TL_TMP/rel/out/run.log"
alh_script "0|rel-ok"
pushd "$TL_TMP/rel" >/dev/null
run_cd --prompt-file prompt.txt
popd >/dev/null
assert_contains "prompt file content became the prompt" "$(alh_rec)" "prompt=prompt from file"
printf 'secret=hunter2\n' >"$TL_TMP/rel/bad-brief.txt"
run_cd --brief-file "$TL_TMP/rel/bad-brief.txt"
assert_eq "claude delegate refuses a brief with secrets" "2" "$TL_STATUS"
assert_contains "claude delegate secret brief message" "$TL_ERR" "brief contains secret patterns"
printf 'api_key: zzz\n' >"$TL_TMP/rel/bad-prompt.txt"
run_cd --prompt-file "$TL_TMP/rel/bad-prompt.txt"
assert_eq "claude delegate refuses a prompt file with secrets" "2" "$TL_STATUS"
assert_contains "claude delegate secret prompt file message" "$TL_ERR" "prompt file contains secret patterns"

# ---------------------------------------------------------------- pinned non-interactive exec
alh_script "0|unused"
printf '#!/usr/bin/env bash\nprintf "cwd=%%s\\n" "$PWD"; printf "argv:%%s\\n" "$@"; exit 7\n' >"$TL_TMP/claude-pin"
chmod +x "$TL_TMP/claude-pin"
tl_run env CLAUDE_BIN="$TL_TMP/claude-pin" bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --use-print --prompt "pinned prompt" --mode strict
assert_eq "pinned NI propagates the exec'd CLI's exit status" "7" "$TL_STATUS"
assert_contains "pinned NI runs in the work dir" "$TL_OUT" "cwd=$W"
assert_contains "pinned NI uses claude --print" "$TL_OUT" "argv:--print"
assert_contains "pinned NI strict mode uses acceptEdits" "$TL_OUT" "argv:acceptEdits"
assert_contains "pinned NI passes the prompt last" "$TL_OUT" "argv:pinned prompt"
assert_eq "pinned NI never reached the adapter" "0" "$(alh_attempts)"
tl_run env CLAUDE_BIN="$TL_TMP/no-such-claude" bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --non-interactive --prompt p
assert_eq "pinned NI without a CLI exits 3 (mode-unavailable)" "3" "$TL_STATUS"
assert_contains "pinned NI without a CLI message" "$TL_ERR" "mode-unavailable"

# ---------------------------------------------------------------- normal NI delegation (auto -> non-interactive)
alh_script "0|ok-output"
run_cd --prompt "do the thing"
assert_eq "auto NI delegation exits 0" "0" "$TL_STATUS"
assert_eq "delegate prints the adapter output" "ok-output" "$TL_OUT"
assert_eq "adapter ran once" "1" "$(alh_attempts)"
assert_contains "adapter preflight ran" "$(alh_rec)" "preflight"
assert_contains "adapter got the mode and prompt" "$(alh_rec)" "invoke n=1 mode=permissive prompt=do the thing"
assert_eq "NI delegation disables the interactive TUI" "0" "$(alh_env CLAUDE_USE_INTERACTIVE)"
assert_eq "lightweight delegate flag exported" "1" "$(alh_env SB_AGENT_CLAUDE_DELEGATE)"
assert_eq "orchestrator worker flag exported" "1" "$(alh_env SB_ORCHESTRATOR_WORKER)"
assert_eq "orchestrator parent flag exported" "0" "$(alh_env SB_ORCHESTRATOR_PARENT)"
assert_eq "SB_ROOT exported to the adapter" "$SB" "$(alh_env SB_ROOT)"
assert_eq "WORK_DIR exported to the adapter" "$W" "$(alh_env WORK_DIR)"
assert_eq "CLAUDE_WORK_DIR exported to the adapter" "$W" "$(alh_env CLAUDE_WORK_DIR)"
assert_eq "RTK disabled for delegation" "1" "$(alh_env RTK_DISABLED)"
assert_eq "no cert permission mode outside cert runs" "<unset>" "$(alh_env CLAUDE_PERMISSION_MODE)"
cfg_seen="$(alh_env CLAUDE_CONFIG_DIR)"
assert_match "adapter ran with an ephemeral CLAUDE_CONFIG_DIR" "^$TL_TMP/tmp/agent-claude-config-" "$cfg_seen"
assert_contains "the config dir existed while the adapter ran" "$(alh_rec)" "config-dir-present yes"
assert_contains "the folder trust file existed while the adapter ran" "$(alh_rec)" "config-trust-present yes"
assert_file_absent "ephemeral CLAUDE_CONFIG_DIR is removed afterwards" "$cfg_seen"
assert_contains "task artifacts are written under the work dir" "$(ls "$W/.planning/agent-claude")" "task-"

# explicit task id, idle seconds and mode flags reach the adapter / artifacts
alh_script "0|ok"
run_cd --prompt "p" --task-id fixed-task --idle-sec 17 --mode strict
assert_eq "explicit flags run exits 0" "0" "$TL_STATUS"
assert_file_exists "explicit task id names the task dir" "$W/.planning/agent-claude/fixed-task/mode.json"
assert_eq "idle seconds reach the adapter" "17" "$(alh_env SB_AGENT_IDLE_SEC)"
assert_contains "strict mode reaches the adapter" "$(alh_rec)" "mode=strict"

# lightweight mode can be switched off: no ephemeral config dir
alh_script "0|ok"
tl_run env SB_AGENT_CLAUDE_LIGHTWEIGHT=0 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "lightweight off still runs" "0" "$TL_STATUS"
assert_eq "lightweight off leaves CLAUDE_CONFIG_DIR alone" "<unset>" "$(alh_env CLAUDE_CONFIG_DIR)"
assert_eq "lightweight off leaves the delegate flag alone" "<unset>" "$(alh_env SB_AGENT_CLAUDE_DELEGATE)"

# ---------------------------------------------------------------- interactive pin
alh_script "0|interactive-ok"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --interactive
assert_eq "interactive pin with a TUI exits 0" "0" "$TL_STATUS"
assert_eq "interactive pin enables the TUI" "1" "$(alh_env CLAUDE_USE_INTERACTIVE)"
tl_run bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --interactive
assert_eq "interactive pin without a TUI exits 3" "3" "$TL_STATUS"
assert_contains "interactive pin without a TUI says mode-unavailable" "$TL_ERR" "mode-unavailable"
# the fallback resolves to a pinned NI launch: native argv exec, never the adapter
alh_script "0|fallback-ok"
tl_run env CLAUDE_BIN="$TL_TMP/claude-pin" bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --interactive --allow-mode-fallback
assert_eq "interactive pin with fallback execs the native NI argv" "7" "$TL_STATUS"
assert_contains "fallback exec uses claude --print" "$TL_OUT" "argv:--print"
assert_eq "fallback never reached the adapter" "0" "$(alh_attempts)"

# ---------------------------------------------------------------- cert run
alh_script "0|cert-ok"
tl_run env SB_AGENT_CERT_RUN=true bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "cert run exits 0" "0" "$TL_STATUS"
assert_eq "cert run bypasses permissions by default" "bypassPermissions" "$(alh_env CLAUDE_PERMISSION_MODE)"
assert_file_exists "cert run leaves the agent-cert-run marker" "$W/.silver-bullet/agent-cert-run"
assert_contains "cert run warns when the plugin cache helper is missing" "$TL_ERR" "plugin-cache-version helper missing"
# an unwritable marker location never fails the run (the dir is a file here)
rm -rf "$W/.silver-bullet"
: >"$W/.silver-bullet"
alh_script "0|cert-ok"
tl_run env SB_AGENT_CERT_RUN=1 bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "an unwritable cert marker location does not fail the delegation" "0" "$TL_STATUS"
assert_eq "the unwritable marker location is left untouched" "file" "$([[ -f "$W/.silver-bullet" ]] && echo file || echo other)"
rm -f "$W/.silver-bullet"
alh_script "0|cert-ok"
tl_run env SB_AGENT_CERT_RUN=1 CLAUDE_PERMISSION_MODE=acceptEdits bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "an explicit permission mode survives a cert run" "acceptEdits" "$(alh_env CLAUDE_PERMISSION_MODE)"
# a cert run with the plugin cache helper present reports readiness
mkdir -p "$SB/scripts/lib"
printf 'sb_claude_ensure_plugin_cache_ready() { printf "%%s\\n" "$1" >>"%s/cache-calls"; return 0; }\n' "$TL_TMP" >"$SB/scripts/lib/plugin-cache-version.sh"
alh_script "0|cert-ok"
tl_tmp_cache="$TL_TMP/cache-calls"
tl_run env SB_AGENT_CERT_RUN=1 bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "cert run asks the plugin cache check about the staged root" "$SB" "$(cat "$tl_tmp_cache")"
assert_contains "cert run reports the plugin cache ready" "$TL_ERR" "Claude plugin cache ready"
rm -rf "$W/.silver-bullet" "$SB/scripts"
# an exported sb_cert_run_touch_marker takes over marker creation
alh_script "0|cert-ok"
sb_cert_run_touch_marker() { printf '%s\n' "$1" >"$TL_TMP/touch-marker-arg"; }
export -f sb_cert_run_touch_marker
tl_run env SB_AGENT_CERT_RUN=1 bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
export -fn sb_cert_run_touch_marker
unset -f sb_cert_run_touch_marker
assert_eq "an available sb_cert_run_touch_marker is used with the work dir" "$W" "$(cat "$TL_TMP/touch-marker-arg")"
assert_file_absent "the fallback marker is not written when the helper exists" "$W/.silver-bullet/agent-cert-run"

# ---------------------------------------------------------------- recommended-tools preflight
alh_script "0|ok"
tl_run bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "preflight without the enterprise lib warns and continues" "0" "$TL_STATUS"
assert_contains "preflight warns about the missing enterprise lib" "$TL_ERR" "missing enterprise preflight lib"
mkdir -p "$SB/scripts/enterprise-e2e/lib"
printf 'enterprise_e2e_code_intel_preflight() { printf "%%s|%%s|%%s\\n" "$1" "$2" "$3" >>"%s/preflight-calls"; return "${PREFLIGHT_RC:-0}"; }\n' "$TL_TMP" >"$SB/scripts/enterprise-e2e/lib/core.sh"
alh_script "0|ok"
tl_run env PREFLIGHT_RC=0 bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "preflight success continues" "0" "$TL_STATUS"
assert_eq "preflight got the SB root, work dir and non-strict flag" "$SB|$W|0" "$(tail -1 "$TL_TMP/preflight-calls")"
alh_script "0|ok"
tl_run env PREFLIGHT_RC=1 bash "$DELEGATE" --sb-root "$SB" --work-dir "$W" --prompt p
assert_eq "preflight failure exits 2" "2" "$TL_STATUS"
assert_contains "preflight failure message" "$TL_ERR" "recommended-tools preflight failed"
assert_eq "preflight failure never reaches the adapter" "0" "$(alh_attempts)"
rm -rf "$SB/scripts"

# ---------------------------------------------------------------- missing adapter
MISSING_SB="$TL_TMP/sb-missing"
mkdir -p "$MISSING_SB"
tl_run bash "$DELEGATE" --sb-root "$MISSING_SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "missing adapter exits 1" "1" "$TL_STATUS"
assert_contains "missing adapter message" "$TL_ERR" "missing Claude live adapter at $MISSING_SB/tests/live/agents/claude/agent.sh"

# ---------------------------------------------------------------- quota retry loop (bounded by env, sleep is a stub)
rm -f "$TL_TMP/sleep.log"
alh_script "1|HTTP 429 rate limit hit"
tl_run env AGENT_CLAUDE_QUOTA_RETRY_MAX=2 AGENT_CLAUDE_QUOTA_RETRY_INTERVAL=3 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "exhausted quota retries exit 1" "1" "$TL_STATUS"
assert_eq "a retriable quota error is attempted max+1 times" "3" "$(alh_attempts)"
assert_contains "retry progress is reported" "$TL_ERR" "quota retry 2/3 after 3s"
assert_contains "exhaustion is reported" "$TL_ERR" "quota retries exhausted"
assert_eq "the retry interval was slept between attempts" "3 3" "$(tr '\n' ' ' <"$TL_TMP/sleep.log" | sed 's/ $//')"

alh_script "1|HTTP 429 rate limit hit" "0|recovered"
tl_run env AGENT_CLAUDE_QUOTA_RETRY_MAX=2 AGENT_CLAUDE_QUOTA_RETRY_INTERVAL=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p
assert_eq "recovery after a quota error exits 0" "0" "$TL_STATUS"
assert_eq "recovery output" "recovered" "$TL_OUT"
assert_eq "recovery took two attempts" "2" "$(alh_attempts)"

rm -f "$TL_TMP/sleep.log"
alh_script "1|Claude 5-hour quota has been exhausted. Resets in 2hr 32min"
run_cd --prompt p
assert_eq "a 5-hour quota window exits 1" "1" "$TL_STATUS"
assert_eq "a 5-hour quota window is not retried" "1" "$(alh_attempts)"
assert_contains "5-hour quota window is left to the RFL schedule" "$TL_ERR" "skip short retry (RFL schedule)"
assert_file_absent "no sleep happened for the 5-hour window" "$TL_TMP/sleep.log"

alh_script "1|plain failure"
run_cd --prompt p
assert_eq "a non-quota failure exits with the adapter status" "1" "$TL_STATUS"
assert_eq "a non-quota failure is not retried" "1" "$(alh_attempts)"
assert_eq "failure output is passed through" "plain failure" "$TL_OUT"
alh_script "5|exit five"
run_cd --prompt p
assert_eq "the adapter's exit status is propagated" "5" "$TL_STATUS"

# ---------------------------------------------------------------- logging
LOG="$TL_TMP/logs/run.log"
mkdir -p "$TL_TMP/logs"
big="$(head -c 700 /dev/zero | tr '\0' 'y')"
rm -f "$LOG"
alh_script "0|${big} token=abc123 done"
run_cd --prompt p --log "$LOG"
assert_eq "NI run with a log exits 0" "0" "$TL_STATUS"
log_text="$(cat "$LOG")"
assert_contains "log has the delegate header" "$log_text" "=== agent-claude-delegate"
assert_contains "log header records the interaction" "$log_text" "interactive=0"
assert_contains "log header records the work dir" "$log_text" "work_dir=$W"
assert_contains "log has the adapter output" "$log_text" "$big"
assert_contains "secrets are redacted in the log" "$log_text" "token=[REDACTED]"
assert_not_contains "the raw secret is gone from the log" "$log_text" "abc123"
assert_contains "log has the footer" "$log_text" "=== agent-claude-delegate complete exit=0 attempt=1 ==="
assert_contains "log size is reported" "$TL_ERR" "[agent-claude] log: $LOG"

# a short log fails the floor check, with the floor taken from the environment
rm -f "$LOG"
alh_script "0|tiny"
tl_run env SB_AGENT_CLAUDE_LOG_FLOOR=100000 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --no-escalate
assert_eq "a log below the floor forces exit 1" "1" "$TL_STATUS"
assert_contains "log floor failure is explained" "$TL_ERR" "log below floor"
assert_contains "log floor failure is recorded in the footer" "$(cat "$LOG")" "complete exit=1 attempt=1"
rm -f "$LOG"
alh_script "0|tiny"
tl_run env SB_AGENT_CLAUDE_LOG_FLOOR=10 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG"
assert_eq "SB_AGENT_CLAUDE_LOG_FLOOR lowers the floor" "0" "$TL_STATUS"

# workflow markers
rm -f "$LOG"
alh_script "0|${big}"
tl_run env SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=1 SB_AGENT_CLAUDE_LOG_FLOOR=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --no-escalate
assert_eq "a log without activity markers fails when markers are required" "1" "$TL_STATUS"
assert_contains "missing markers are explained" "$TL_ERR" "no-workflow-markers"
rm -f "$LOG"
alh_script "0|${big} ⏺ Bash(ls)"
tl_run env SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=1 SB_AGENT_CLAUDE_LOG_FLOOR=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG"
assert_eq "a log with tool activity passes the marker check" "0" "$TL_STATUS"

# interactive runs truncate the log; an adapter that removes it gets a fallback log
printf 'stale content\n' >"$LOG"
alh_script "0|interactive output"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 SB_AGENT_CLAUDE_LOG_FLOOR=1 ALH_WRITE_LOG="tui transcript" bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --interactive
assert_eq "interactive run with a log exits 0" "0" "$TL_STATUS"
assert_not_contains "interactive runs truncate a stale log" "$(cat "$LOG")" "stale content"
assert_contains "the adapter's TUI log is kept" "$(cat "$LOG")" "tui transcript"
alh_script "0|interactive output"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 ALH_RM_LOG=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --interactive
assert_eq "fallback log run exits 0" "0" "$TL_STATUS"
assert_contains "fallback log is announced" "$TL_ERR" "[agent-claude] log written: $LOG"
assert_contains "fallback log carries the output" "$(cat "$LOG")" "interactive output"
assert_contains "fallback log records the exit" "$(cat "$LOG")" "exit=0"

# ---------------------------------------------------------------- failure -> result normalisation -> D4 escalation
alh_script "1|first wave failed" "0|escalated wave ok"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-1
assert_eq "an escalated retry that succeeds exits 0" "0" "$TL_STATUS"
assert_eq "the escalated retry output is final" "escalated wave ok" "$TL_OUT"
assert_eq "the escalated retry ran the adapter twice" "2" "$(alh_attempts)"
assert_eq "the escalated retry is interactive" "1" "$(alh_env CLAUDE_USE_INTERACTIVE)"
TD="$W/.planning/agent-claude/esc-1"
assert_file_exists "failure left an escalation note" "$TD/escalation.md"
assert_contains "a missing result.md is normalised to a failing skeleton" "$(cat "$TD/result.md")" "incomplete / result-missing"
assert_contains "mode.json records the incomplete result" "$(cat "$TD/mode.json")" "result-missing"
assert_contains "mode.json records the escalation" "$(cat "$TD/mode.json")" "escalated"

# --no-escalate: a failure stays a failure
alh_script "1|first wave failed" "0|should not run"
tl_run env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-2 --no-escalate
assert_eq "--no-escalate keeps the failure" "1" "$TL_STATUS"
assert_eq "--no-escalate runs the adapter once" "1" "$(alh_attempts)"

# no TUI: the escalation is unavailable and the failure stands
alh_script "1|first wave failed" "0|should not run"
run_cd --prompt p --task-id esc-3
assert_eq "an unavailable escalation keeps the failure" "1" "$TL_STATUS"
assert_eq "an unavailable escalation runs the adapter once" "1" "$(alh_attempts)"
assert_contains "the unavailable escalation is recorded" "$(cat "$W/.planning/agent-claude/esc-3/mode.json")" "escalate-unavailable"

# an existing result.md that already carries a status is kept as-is
mkdir -p "$W/.planning/agent-claude/esc-4"
printf '## STATUS\npass\n\n## TASK\nx\n' >"$W/.planning/agent-claude/esc-4/result.md"
alh_script "1|failed again"
run_cd --prompt p --task-id esc-4
assert_eq "an existing result.md is not treated as missing" "1" "$TL_STATUS"
assert_not_contains "an existing result.md is not marked result-missing" "$(cat "$W/.planning/agent-claude/esc-4/mode.json")" "result-missing"
assert_contains "an existing result.md keeps its body" "$(cat "$W/.planning/agent-claude/esc-4/result.md")" "## TASK"

assert_file_absent "no real host CLI was reached" "$TL_TMP/unexpected-cli.log"
assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results

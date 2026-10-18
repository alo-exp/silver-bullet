#!/usr/bin/env bash
# scripts/agent-claude-delegate.sh logging, log floor / workflow markers, failure normalisation and
# D4 escalation with a scripted adapter. Split from test-agent-live-claude-delegate.sh to keep each
# file well under 30 s. No Claude, expect or network is ever used; `sleep` is a recording stub.
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
  tl_run timeout 60 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" "$@"
}

alh_script "0|ok-output"

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
tl_run timeout 60 env SB_AGENT_CLAUDE_LOG_FLOOR=100000 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --no-escalate
assert_eq "a log below the floor forces exit 1" "1" "$TL_STATUS"
assert_contains "log floor failure is explained" "$TL_ERR" "log below floor"
assert_contains "log floor failure is recorded in the footer" "$(cat "$LOG")" "complete exit=1 attempt=1"
rm -f "$LOG"
alh_script "0|tiny"
tl_run timeout 60 env SB_AGENT_CLAUDE_LOG_FLOOR=10 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG"
assert_eq "SB_AGENT_CLAUDE_LOG_FLOOR lowers the floor" "0" "$TL_STATUS"

# workflow markers
rm -f "$LOG"
alh_script "0|${big}"
tl_run timeout 60 env SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=1 SB_AGENT_CLAUDE_LOG_FLOOR=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --no-escalate
assert_eq "a log without activity markers fails when markers are required" "1" "$TL_STATUS"
assert_contains "missing markers are explained" "$TL_ERR" "no-workflow-markers"
rm -f "$LOG"
alh_script "0|${big} ⏺ Bash(ls)"
tl_run timeout 60 env SB_AGENT_CLAUDE_REQUIRE_WORKFLOW_MARKERS=1 SB_AGENT_CLAUDE_LOG_FLOOR=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG"
assert_eq "a log with tool activity passes the marker check" "0" "$TL_STATUS"

# interactive runs truncate the log; an adapter that removes it gets a fallback log
printf 'stale content\n' >"$LOG"
alh_script "0|interactive output"
tl_run timeout 60 env SB_AGENT_MODE_TUI_AVAILABLE=1 SB_AGENT_CLAUDE_LOG_FLOOR=1 ALH_WRITE_LOG="tui transcript" bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --interactive
assert_eq "interactive run with a log exits 0" "0" "$TL_STATUS"
assert_not_contains "interactive runs truncate a stale log" "$(cat "$LOG")" "stale content"
assert_contains "the adapter's TUI log is kept" "$(cat "$LOG")" "tui transcript"
alh_script "0|interactive output"
tl_run timeout 60 env SB_AGENT_MODE_TUI_AVAILABLE=1 ALH_RM_LOG=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --log "$LOG" --interactive
assert_eq "fallback log run exits 0" "0" "$TL_STATUS"
assert_contains "fallback log is announced" "$TL_ERR" "[agent-claude] log written: $LOG"
assert_contains "fallback log carries the output" "$(cat "$LOG")" "interactive output"
assert_contains "fallback log records the exit" "$(cat "$LOG")" "exit=0"

# ---------------------------------------------------------------- failure -> result normalisation -> D4 escalation
alh_script "1|first wave failed" "0|escalated wave ok"
tl_run timeout 60 env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-1
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
tl_run timeout 60 env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-2 --no-escalate
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

# an escalated retry that fails too keeps the failure (second status is final)
alh_script "1|first wave failed" "3|escalated wave failed"
tl_run timeout 60 env SB_AGENT_MODE_TUI_AVAILABLE=1 bash "$DELEGATE" --sb-root "$SB" --skip-preflight --work-dir "$W" --prompt p --task-id esc-5
assert_eq "a failing escalated retry exits with its status" "3" "$TL_STATUS"
assert_eq "a failing escalated retry output is final" "escalated wave failed" "$TL_OUT"
assert_eq "a failing escalated retry ran the adapter twice" "2" "$(alh_attempts)"

assert_file_absent "no real host CLI was reached" "$TL_TMP/unexpected-cli.log"
assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results

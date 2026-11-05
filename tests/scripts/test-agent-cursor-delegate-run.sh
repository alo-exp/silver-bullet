#!/usr/bin/env bash
# Behavioural coverage for scripts/agent-cursor-delegate.sh with the real
# delegate and agent-mode libraries, a scripted fake live adapter and a stub
# cursor-agent. Nothing reaches a real Cursor.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

DELEGATE="$TL_REPO_ROOT/scripts/agent-cursor-delegate.sh"
SB="$TL_TMP/sb"
CFG="$TL_TMP/cfg"
WORK="$TL_TMP/work"
mkdir -p "$SB/tests/live/agents/cursor" "$CFG" "$WORK"
printf '#!/usr/bin/env bash\necho "cursor-agent $*" >>"%s/native-argv.log"\necho NATIVE-OUT\n' "$CFG" >"$TL_BIN/cursor-agent"
chmod +x "$TL_BIN/cursor-agent"

cat >"$SB/tests/live/agents/cursor/agent.sh" <<ADAPTER
agent_preflight() { echo "adapter-preflight" >&2; }
agent_invoke() {
  local n=1
  [[ -f "$CFG/count" ]] && n=\$(( \$(<"$CFG/count") + 1 ))
  echo "\$n" >"$CFG/count"
  echo "invoke#\$n mode=\$1 prompt=\$2 model=\${CURSOR_AGENT_MODEL:-} headless=\${SB_LIVE_CURSOR_FORCE_HEADLESS:-} stream=\${SB_AGENT_CURSOR_STREAM_JSON:-} worker=\${SB_ORCHESTRATOR_WORKER:-} plugin_root=[\${CLAUDE_PLUGIN_ROOT:-}] project=[\${CLAUDE_PROJECT_DIR:-}] apikey=[\${CURSOR_API_KEY:-}] timeout=\${CURSOR_AGENT_TIMEOUT:-}"
  if [[ -f "$CFG/fail-until" && \$n -le \$(<"$CFG/fail-until") ]]; then
    cat "$CFG/fail-msg" 2>/dev/null
    return 1
  fi
  return 0
}
ADAPTER

reset() { rm -rf "$CFG/count" "$CFG/fail-until" "$CFG/fail-msg" "$CFG/native-argv.log" "$WORK/.planning" "$WORK/log"; }
ENVX=()
delegate() {
  tl_run env SB_AGENT_SKIP_PREFLIGHT=1 SB_AGENT_CURSOR_LOG_FLOOR=0 AGENT_CURSOR_QUOTA_RETRY_INTERVAL=0 \
    "${ENVX[@]}" bash "$DELEGATE" "$@"
}

# ---- argument errors
tl_run bash "$DELEGATE" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "Usage: agent-cursor-delegate.sh"
tl_run bash "$DELEGATE" --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "unknown argument: --bogus"
tl_run bash "$DELEGATE" --prompt hi
assert_eq "missing --work-dir exits 2" 2 "$TL_STATUS"
tl_run bash "$DELEGATE" --work-dir "$WORK" --mode auto
assert_eq "mode that is an interaction mode exits 2" 2 "$TL_STATUS"
tl_run bash "$DELEGATE" --work-dir "$WORK"
assert_eq "no prompt exits 2" 2 "$TL_STATUS"
for flag in --work-dir --prompt --prompt-file --brief-file --log --mode --sb-root --control-dir --max-turns --task-id; do
  tl_run bash "$DELEGATE" "$flag"
  assert_eq "$flag without a value exits 2" 2 "$TL_STATUS"
  assert_contains "$flag without a value explains" "$TL_ERR" "$flag requires a value"
done
tl_run env SB_AGENT_SKIP_PREFLIGHT=1 bash "$DELEGATE" --work-dir "$WORK" --prompt p --interactive --non-interactive
assert_eq "conflicting aliases exit 2" 2 "$TL_STATUS"
tl_run bash "$DELEGATE" --work-dir "$WORK" --prompt p --interaction-mode bogus
assert_eq "invalid interaction mode exits 2" 2 "$TL_STATUS"

# ---- successful delegation and policy env
reset
printf 'brief text\n' >"$WORK/brief.md"
ENVX=(CLAUDE_PLUGIN_ROOT=/leak CLAUDE_PROJECT_DIR=/leak2)
delegate --work-dir "$WORK" --brief-file "$WORK/brief.md" --sb-root "$SB" --log "$WORK/log"
assert_eq "delegation succeeds" 0 "$TL_STATUS"
assert_contains "brief became the prompt" "$TL_OUT" "prompt=brief text"
assert_contains "default model" "$TL_OUT" "model=composer-2.5"
assert_contains "Claude plugin identity not leaked" "$TL_OUT" "plugin_root=[] project=[]"
assert_contains "headless stream defaults" "$TL_OUT" "headless=1 stream=1 worker=1"
assert_contains "default timeout" "$TL_OUT" "timeout=1800"
assert_contains "log header names the model" "$(<"$WORK/log")" "model=composer-2.5"
assert_contains "log footer" "$(<"$WORK/log")" "complete exit=0 attempt=1"
reset
printf 'prompt file text\n' >"$WORK/prompt.md"
ENVX=(CURSOR_API_KEY=sekret)
delegate --work-dir "$WORK" --prompt-file "$WORK/prompt.md" --sb-root "$SB" --mode strict
assert_eq "API key run succeeds" 0 "$TL_STATUS"
assert_contains "strict mode and prompt file" "$TL_OUT" "invoke#1 mode=strict prompt=prompt file text"
assert_contains "API key unset for the adapter" "$TL_OUT" "apikey=[]"
assert_contains "API key unset is warned about" "$TL_ERR" "unsetting CURSOR_API_KEY"
assert_not_contains "secret never printed" "$TL_OUT$TL_ERR" "sekret"

# session mode and lightweight off
reset
ENVX=(SB_AGENT_MODE_TUI_AVAILABLE=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --interactive
assert_eq "interactive pin succeeds" 0 "$TL_STATUS"
assert_contains "interactive session disables forced headless" "$TL_OUT" "headless=0 stream=1 worker=1"
reset
ENVX=(SB_AGENT_CURSOR_LIGHTWEIGHT=0)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_contains "lightweight off leaves the worker flag unset" "$TL_OUT" "worker="
assert_contains "lightweight off leaves stream json unset" "$TL_OUT" "stream= worker="

# a read-only CLAUDE_PLUGIN_ROOT cannot be unset; the delegation proceeds anyway
reset
tl_run bash -c 'readonly CLAUDE_PLUGIN_ROOT=/pinned; export CLAUDE_PLUGIN_ROOT; export SB_AGENT_SKIP_PREFLIGHT=1 SB_AGENT_CURSOR_LOG_FLOOR=0; source "$@"' _ "$DELEGATE" --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "delegation survives an unsettable plugin root" 0 "$TL_STATUS"
assert_contains "pinned value reaches the adapter" "$TL_OUT" "plugin_root=[/pinned]"

# forbidden fast model
reset
ENVX=(CURSOR_AGENT_MODEL=composer-2.5-fast)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_eq "fast model refused with status 2" 2 "$TL_STATUS"
assert_contains "fast model refusal explained" "$TL_ERR" "composer-2.5-fast forbidden"
assert_file_absent "adapter never invoked" "$CFG/count"
ENVX=()

# ---- environment problems
reset
delegate --work-dir "$WORK" --prompt p --sb-root "$TL_TMP/no-such-root"
assert_eq "missing adapter exits 1" 1 "$TL_STATUS"
assert_contains "missing adapter explained" "$TL_ERR" "missing Cursor live adapter"

# ---- pinned non-interactive: execs cursor-agent natively
reset
delegate --work-dir "$WORK" --prompt "native run" --non-interactive
assert_eq "pinned NI exits 0" 0 "$TL_STATUS"
assert_contains "pinned NI output is the native CLI's" "$TL_OUT" "NATIVE-OUT"
assert_contains "native argv" "$(<"$CFG/native-argv.log")" "cursor-agent --trust --force --workspace $WORK --print"

# ---- log floor
reset
echo 1 >"$CFG/fail-until"; echo "boom" >"$CFG/fail-msg"
ENVX=(SB_AGENT_CURSOR_LOG_FLOOR=100000)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --log "$WORK/log" --no-escalate
assert_eq "failure exits non-zero" 1 "$TL_STATUS"
assert_contains "below-floor log reported" "$TL_ERR" "log below floor"
assert_contains "failure footer" "$(<"$WORK/log")" "complete exit=1"
ENVX=()

# ---- quota retries
reset
echo 1 >"$CFG/fail-until"; echo "HTTP 429 rate limit" >"$CFG/fail-msg"
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --quota-retry
assert_eq "quota error retried and succeeds" 0 "$TL_STATUS"
assert_contains "retry announced" "$TL_ERR" "quota retry 2/"
assert_eq "adapter invoked twice" 2 "$(<"$CFG/count")"
reset
echo 99 >"$CFG/fail-until"; echo "HTTP 429 rate limit" >"$CFG/fail-msg"
ENVX=(AGENT_CURSOR_QUOTA_RETRY_MAX=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_eq "persistent quota failure exits 1" 1 "$TL_STATUS"
assert_contains "retries exhausted" "$TL_ERR" "quota retries exhausted"
reset
echo 99 >"$CFG/fail-until"; echo "quota exceeded: You have hit your 5-hour limit, resets in 3 hours" >"$CFG/fail-msg"
ENVX=(AGENT_CURSOR_QUOTA_RETRY_MAX=3)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_contains "long quota window skips the short retry" "$TL_ERR" "quota window exhausted"
assert_eq "single attempt for an exhausted window" 1 "$(<"$CFG/count")"
reset
echo 99 >"$CFG/fail-until"; echo "plain failure" >"$CFG/fail-msg"
ENVX=()
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_eq "non-quota failure not retried" 1 "$(<"$CFG/count")"
assert_file_exists "incomplete result normalised" "$(find "$WORK/.planning" -name result.md | head -1)"

# ---- escalation
reset
echo 1 >"$CFG/fail-until"; echo "miss" >"$CFG/fail-msg"
ENVX=(SB_AGENT_MODE_TUI_AVAILABLE=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "escalated retry succeeds" 0 "$TL_STATUS"
assert_eq "adapter invoked for the retry" 2 "$(<"$CFG/count")"
reset
echo 99 >"$CFG/fail-until"; echo "miss" >"$CFG/fail-msg"
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "failing escalated retry exits 1" 1 "$TL_STATUS"
assert_eq "exactly one retry" 2 "$(<"$CFG/count")"
ENVX=()

tl_results

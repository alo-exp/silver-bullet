#!/usr/bin/env bash
# Behavioural coverage for scripts/agent-codex-delegate.sh: real delegate and
# agent-mode libraries, a fake SB root whose live adapter is scripted, a stub
# codex binary and a sandboxed HOME. Nothing reaches a real Codex.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

DELEGATE="$TL_REPO_ROOT/scripts/agent-codex-delegate.sh"
SB="$TL_TMP/sb"
CFG="$TL_TMP/cfg"
WORK="$TL_TMP/work"
mkdir -p "$SB/tests/live/agents/codex" "$CFG" "$WORK" "$HOME/.codex"
mkdir -p "$TL_TMP/codexbin"
printf '#!/usr/bin/env bash\necho "codex $*" >>"%s/codex-argv.log"\necho NATIVE-OUT\n' "$CFG" >"$TL_TMP/codexbin/codex"
chmod +x "$TL_TMP/codexbin/codex"
printf 'model = "m"\n[mcp_servers.x]\ncommand = "y"\n[other]\nk = 1\n' >"$HOME/.codex/config.toml"
printf 'tok' >"$HOME/.codex/auth.json"

# Scripted adapter: counts calls; fails (message from $CFG/fail-msg) until the
# call number exceeds $CFG/fail-until; prints what the delegate exported.
cat >"$SB/tests/live/agents/codex/agent.sh" <<ADAPTER
agent_preflight() { echo "adapter-preflight" >&2; }
agent_invoke() {
  local n=1
  [[ -f "$CFG/count" ]] && n=\$(( \$(<"$CFG/count") + 1 ))
  echo "\$n" >"$CFG/count"
  echo "invoke#\$n mode=\$1 prompt=\$2 exec=\${SB_LIVE_CODEX_USE_EXEC:-} lightweight=\${SB_AGENT_CODEX_DELEGATE:-} worker=\${SB_ORCHESTRATOR_WORKER:-}"
  if [[ -n "\${CODEX_HOME:-}" ]]; then
    echo "home-config: \$(tr '\\n' ' ' <"\$CODEX_HOME/config.toml") auth=\$(cat "\$CODEX_HOME/auth.json" 2>/dev/null)"
    echo "\$CODEX_HOME" >"$CFG/codex-home"
  fi
  [[ -f "$CFG/rm-log" ]] && rm -f "\${CLAUDE_INTERACTIVE_LOG_FILE:-}"
  if [[ -f "$CFG/fail-until" && \$n -le \$(<"$CFG/fail-until") ]]; then
    cat "$CFG/fail-msg" 2>/dev/null
    return 1
  fi
  return 0
}
ADAPTER

reset() { rm -rf "$CFG/count" "$CFG/fail-until" "$CFG/fail-msg" "$CFG/rm-log" "$CFG/codex-home" "$CFG/codex-argv.log" "$WORK/.planning" "$WORK/log"; }
# delegate <args...> : fast defaults, cwd outside the repo
delegate() {
  tl_run env CODEX_BIN="$TL_TMP/codexbin/codex" SB_AGENT_SKIP_PREFLIGHT=1 SB_AGENT_CODEX_LOG_FLOOR=0 \
    AGENT_CODEX_QUOTA_RETRY_INTERVAL=0 "${ENVX[@]}" bash "$DELEGATE" "$@"
}
ENVX=()

# ---- argument errors
tl_run bash "$DELEGATE" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "Usage: agent-codex-delegate.sh"
tl_run bash "$DELEGATE" --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "unknown argument: --bogus"
tl_run bash "$DELEGATE" --prompt hi
assert_eq "missing --work-dir exits 2" 2 "$TL_STATUS"
assert_contains "missing work dir explained" "$TL_ERR" "--work-dir must point to an existing directory"
tl_run bash "$DELEGATE" --work-dir "$WORK" --mode auto
assert_eq "mode that is an interaction mode exits 2" 2 "$TL_STATUS"
tl_run bash "$DELEGATE" --work-dir "$WORK" --mode nonsense
assert_eq "invalid mode exits 2" 2 "$TL_STATUS"
tl_run bash "$DELEGATE" --work-dir "$WORK" --interaction-mode bogus --prompt x
assert_eq "invalid interaction mode exits 2" 2 "$TL_STATUS"
tl_run bash "$DELEGATE" --work-dir "$WORK"
assert_eq "no prompt exits 2" 2 "$TL_STATUS"
for flag in --work-dir --prompt --prompt-file --brief-file --log --mode --sb-root --control-dir --max-turns --task-id; do
  tl_run bash "$DELEGATE" "$flag"
  assert_eq "$flag without a value exits 2" 2 "$TL_STATUS"
  assert_contains "$flag without a value explains" "$TL_ERR" "$flag requires a value"
done

# ---- mode resolution failures propagate the resolver's exit code
tl_run env SB_AGENT_SKIP_PREFLIGHT=1 bash "$DELEGATE" --work-dir "$WORK" --prompt p --interactive --non-interactive
assert_eq "conflicting aliases exit 2" 2 "$TL_STATUS"
assert_contains "conflict reported" "$TL_ERR" "mode-conflict"
tl_run env SB_AGENT_SKIP_PREFLIGHT=1 SB_AGENT_MODE_TUI_AVAILABLE=0 bash "$DELEGATE" --work-dir "$WORK" --prompt p --interactive
assert_eq "pinned interactive without a TUI exits 3" 3 "$TL_STATUS"
assert_contains "unavailability reported" "$TL_ERR" "mode-unavailable"

# ---- successful delegation (auto resolves to non-interactive: no TUI in the sandbox)
reset
delegate --work-dir "$WORK" --prompt "do the thing" --sb-root "$SB" --log "$WORK/log"
assert_eq "delegation succeeds" 0 "$TL_STATUS"
assert_contains "adapter output returned" "$TL_OUT" "invoke#1 mode=permissive prompt=do the thing exec=1"
assert_contains "lightweight delegate env exported" "$TL_OUT" "lightweight=1 worker=1"
assert_contains "MCP servers stripped from the delegate CODEX_HOME" "$TL_OUT" "home-config: model = \"m\" [other] k = 1  auth=tok"
assert_file_absent "temporary CODEX_HOME removed afterwards" "$(<"$CFG/codex-home")"
LOGTXT="$(<"$WORK/log")"
assert_contains "log header" "$LOGTXT" "=== agent-codex-delegate"
assert_contains "log carries exec output" "$LOGTXT" "invoke#1"
assert_contains "log footer records success" "$LOGTXT" "complete exit=0 attempt=1"
assert_contains "adapter preflight ran" "$TL_ERR" "adapter-preflight"

# prompt from a brief file and a prompt file (relative paths are canonicalized)
reset
printf 'brief text\n' >"$WORK/brief.md"
tl_run bash -c "cd '$WORK' && env CODEX_BIN='$TL_TMP/codexbin/codex' SB_AGENT_SKIP_PREFLIGHT=1 SB_AGENT_CODEX_LOG_FLOOR=0 bash '$DELEGATE' --work-dir . --brief-file brief.md --sb-root '$SB' --log rel.log"
assert_eq "brief file delegation succeeds" 0 "$TL_STATUS"
assert_contains "brief content became the prompt" "$TL_OUT" "prompt=brief text"
assert_file_exists "relative log path resolved against cwd" "$WORK/rel.log"
reset
printf 'prompt file text\n' >"$WORK/prompt.md"
delegate --work-dir "$WORK" --prompt-file "$WORK/prompt.md" --sb-root "$SB" --mode strict
assert_contains "prompt file content used with strict mode" "$TL_OUT" "invoke#1 mode=strict prompt=prompt file text"

# ---- lightweight switches
reset
ENVX=(SB_AGENT_CODEX_LIGHTWEIGHT=0)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "lightweight off still succeeds" 0 "$TL_STATUS"
assert_not_contains "no CODEX_HOME override when lightweight is off" "$TL_OUT" "home-config"
reset
ENVX=(SB_AGENT_CODEX_SKIP_MCP=0)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_not_contains "no CODEX_HOME override when MCP skipping is off" "$TL_OUT" "home-config"
ENVX=(CODEX_HOME="$HOME/.codex-given")
mkdir -p "$HOME/.codex-given"
printf 'k = 2\n' >"$HOME/.codex-given/config.toml"
reset
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_contains "explicit CODEX_HOME is the strip source" "$TL_OUT" "home-config: k = 2"
ENVX=()

# ---- environment / adapter problems
reset
delegate --work-dir "$WORK" --prompt p --sb-root "$TL_TMP/no-such-root"
assert_eq "missing adapter exits 1" 1 "$TL_STATUS"
assert_contains "missing adapter explained" "$TL_ERR" "missing Codex live adapter at $TL_TMP/no-such-root/tests/live/agents/codex/agent.sh"
tl_run env -u CODEX_BIN PATH="$(tl_path_without codex)" SB_CODEX_APP_CANDIDATES=/nonexistent/codex SB_AGENT_SKIP_PREFLIGHT=1 bash "$DELEGATE" --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "missing codex CLI exits 1" 1 "$TL_STATUS"
assert_contains "missing codex CLI explained" "$TL_ERR" "native Codex CLI not found"
# recommended-tools preflight: failing preflight library blocks the delegation
mkdir -p "$SB/scripts/enterprise-e2e/lib"
printf 'enterprise_e2e_code_intel_preflight() { return 1; }\n' >"$SB/scripts/enterprise-e2e/lib/core.sh"
tl_run env CODEX_BIN="$TL_TMP/codexbin/codex" SB_AGENT_CODEX_LOG_FLOOR=0 bash "$DELEGATE" --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "failing recommended-tools preflight exits 2" 2 "$TL_STATUS"
assert_contains "preflight failure explained" "$TL_ERR" "recommended-tools preflight failed"
rm -rf "$SB/scripts"

# ---- pinned non-interactive: execs the native codex
reset
delegate --work-dir "$WORK" --prompt "native run" --non-interactive --mode strict
assert_eq "pinned NI exits 0" 0 "$TL_STATUS"
assert_contains "pinned NI output is codex's" "$TL_OUT" "NATIVE-OUT"
assert_contains "native argv carries exec + prompt" "$(<"$CFG/codex-argv.log")" "codex exec --cd $WORK --sandbox danger-full-access --color never"
assert_contains "native argv ends with prompt" "$(<"$CFG/codex-argv.log")" "native run"

# ---- log handling
reset
echo 1 >"$CFG/fail-until"; echo "boom" >"$CFG/fail-msg"
ENVX=(SB_AGENT_CODEX_LOG_FLOOR=100000)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --log "$WORK/log" --no-escalate
assert_eq "failure exits non-zero" 1 "$TL_STATUS"
assert_contains "below-floor log is reported" "$TL_ERR" "log below floor"
assert_contains "failure footer recorded" "$(<"$WORK/log")" "complete exit=1"
reset
touch "$CFG/rm-log"
ENVX=(SB_AGENT_MODE_TUI_AVAILABLE=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --log "$WORK/log" --interactive
ENVX=()
assert_eq "adapter that removes the log still succeeds" 0 "$TL_STATUS"
assert_contains "fallback log announced" "$TL_ERR" "log written: $WORK/log"
assert_file_exists "fallback log written" "$WORK/log"

# ---- quota retries
reset
echo 1 >"$CFG/fail-until"; echo "HTTP 429 rate limit" >"$CFG/fail-msg"
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --quota-retry
assert_eq "quota error retried and succeeds" 0 "$TL_STATUS"
assert_contains "retry announced" "$TL_ERR" "quota retry 2/"
assert_eq "adapter invoked twice" 2 "$(<"$CFG/count")"
reset
echo 99 >"$CFG/fail-until"; echo "HTTP 429 rate limit" >"$CFG/fail-msg"
ENVX=(AGENT_CODEX_QUOTA_RETRY_MAX=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_eq "persistent quota failure exits 1" 1 "$TL_STATUS"
assert_contains "retries exhausted" "$TL_ERR" "quota retries exhausted"
assert_eq "two attempts made" 2 "$(<"$CFG/count")"
reset
echo 99 >"$CFG/fail-until"; echo "quota exceeded: You have hit your 5-hour limit, resets in 3 hours" >"$CFG/fail-msg"
ENVX=(AGENT_CODEX_QUOTA_RETRY_MAX=3)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_eq "exhausted window exits 1" 1 "$TL_STATUS"
assert_contains "long quota window skips the short retry" "$TL_ERR" "quota window exhausted"
assert_eq "single attempt for an exhausted window" 1 "$(<"$CFG/count")"
reset
echo 99 >"$CFG/fail-until"; echo "plain failure" >"$CFG/fail-msg"
ENVX=()
delegate --work-dir "$WORK" --prompt p --sb-root "$SB" --no-escalate
assert_eq "non-quota failure is not retried" 1 "$(<"$CFG/count")"
assert_eq "non-quota failure exits 1" 1 "$TL_STATUS"
assert_file_exists "incomplete result normalised" "$(find "$WORK/.planning" -name result.md | head -1)"

# ---- escalation: auto non-interactive miss retried once interactively
reset
echo 1 >"$CFG/fail-until"; echo "miss" >"$CFG/fail-msg"
ENVX=(SB_AGENT_MODE_TUI_AVAILABLE=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "escalated retry succeeds" 0 "$TL_STATUS"
assert_eq "adapter invoked for the retry" 2 "$(<"$CFG/count")"
assert_contains "retry runs without exec" "$TL_OUT" "invoke#2 mode=permissive prompt=p exec=0"
# the retry also fails -> its status is final
reset
echo 99 >"$CFG/fail-until"; echo "miss" >"$CFG/fail-msg"
ENVX=(SB_AGENT_MODE_TUI_AVAILABLE=1)
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "failing escalated retry exits 1" 1 "$TL_STATUS"
assert_eq "exactly one retry" 2 "$(<"$CFG/count")"
ENVX=()

# ---- the temporary CODEX_HOME cannot be removed: tolerated
reset
REAL_RM="$(command -v rm)"
tl_stub rm 'for a in "$@"; do [[ "$a" == */agent-codex-codex-home-* ]] && exit 1; done; exec '"$REAL_RM"' "$@"'
delegate --work-dir "$WORK" --prompt p --sb-root "$SB"
assert_eq "undeletable lightweight home tolerated" 0 "$TL_STATUS"
"$REAL_RM" -rf "$TL_BIN/rm" "$(<"$CFG/codex-home")"

tl_results

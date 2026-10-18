#!/usr/bin/env bash
# scripts/lib/agent-host-exec.sh: CLI resolution, native argv for every host, Pi expect-file
# machinery (guard, --continue hops, fresh rewrite), exec_native and the PTY runner.
# The library is staged next to a stub pi-zero-byte-guard.py and every host CLI is a stub in
# $TL_BIN; nothing signals or leaves a process behind.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/k-agents-live-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/k-agents-live-2-helpers.sh"

S="$TL_TMP/stage/scripts/lib"
mkdir -p "$S"
for f in agent-host-exec.sh codex-cli.sh opencode-cli.sh multi-ai-opencode-worker.sh pi-cli.sh; do
  cp "$TL_REPO_ROOT/scripts/lib/$f" "$S/"
done
export FAKE_LOG="$TL_TMP/fake.log"
cat >"$S/pi-zero-byte-guard.py" <<'PY'
import os, sys
a = sys.argv[1:]
plan = os.environ.get("GUARD_PLAN", "0").split(",")
cnt = os.environ.get("GUARD_COUNTER", "/dev/null")
try:
    n = int(open(cnt).read() or 0)
except Exception:
    n = 0
if cnt != "/dev/null":
    open(cnt, "w").write(str(n + 1))
ent = plan[min(n, len(plan) - 1)].split(":")
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write("GUARD idle=%s hard=%s expect=%s min=%s cwd=%s argv=%s\n" % (a[0], a[1], a[2], a[3], os.getcwd(), " ".join(a[4:])))
if os.environ.get("GUARD_OUT"):
    print(os.environ["GUARD_OUT"])
if len(ent) > 1 and ent[1]:
    open(a[2], "w").write("x" * int(ent[1]))
sys.exit(int(ent[0]))
PY
# shellcheck source=/dev/null
source "$S/agent-host-exec.sh"

# pi stub: logs argv; plan "rc[:bytes]" per invocation, writing PI_EXPECT_OUT
tl_stub pi 'echo "PI $*" >>"$FAKE_LOG"
plan="${PI_PLAN:-0}"; cnt="${PI_COUNTER:-/dev/null}"
n=0; [[ "$cnt" != /dev/null && -f "$cnt" ]] && n="$(cat "$cnt")"
[[ "$cnt" != /dev/null ]] && echo $((n+1)) >"$cnt"
IFS=, read -ra arr <<<"$plan"; i=$n; (( i >= ${#arr[@]} )) && i=$(( ${#arr[@]} - 1 ))
IFS=: read -r rc size <<<"${arr[$i]}"
[[ -n "${size:-}" ]] && head -c "$size" /dev/zero | tr "\0" x >"$PI_EXPECT_OUT"
echo "pi-out:${PI_STUB_OUT:-}"
exit "$rc"'
big() { head -c "$2" /dev/zero | tr '\0' x >"$1"; }
reset_log() { : >"$FAKE_LOG"; }
logged() { cat "$FAKE_LOG"; }
argv_str() { printf '%s|' "${AGENT_HOST_ARGV[@]}"; }

# =================== resolve_cli ===================
STUB_BIN="$TL_TMP/stubs"; mkdir -p "$STUB_BIN"
for n in claude codex opencode cursor-agent agent; do printf '#!/bin/sh\nexit 0\n' >"$STUB_BIN/$n"; chmod +x "$STUB_BIN/$n"; done
NOHOSTS="$(tl_path_without claude codex opencode pi cursor-agent agent)"

assert_eq "claude: CLAUDE_BIN" "$STUB_BIN/claude" "$(CLAUDE_BIN="$STUB_BIN/claude" agent_host_resolve_cli claude)"
assert_eq "claude: PATH" "$STUB_BIN/claude" "$(PATH="$STUB_BIN:$NOHOSTS" CLAUDE_BIN="" agent_host_resolve_cli claude)"
mkdir -p "$HOME/.local/bin"; cp "$STUB_BIN/claude" "$HOME/.local/bin/claude"
assert_eq "claude: ~/.local/bin fallback" "$HOME/.local/bin/claude" "$(PATH="$NOHOSTS" CLAUDE_BIN="" agent_host_resolve_cli claude)"
rm -f "$HOME/.local/bin/claude"
rc=0; PATH="$NOHOSTS" CLAUDE_BIN="" agent_host_resolve_cli claude >/dev/null || rc=$?
assert_eq "claude: missing returns 1" 1 "$rc"
rc=0; CLAUDE_BIN="$TL_TMP/not-executable" agent_host_resolve_cli claude >/dev/null || rc=$?
assert_eq "claude: non-executable CLAUDE_BIN returns 1" 1 "$rc"

assert_eq "codex: CODEX_BIN" "$STUB_BIN/codex" "$(CODEX_BIN="$STUB_BIN/codex" agent_host_resolve_cli codex)"
assert_eq "opencode: OPENCODE_BIN" "$STUB_BIN/opencode" "$(OPENCODE_BIN="$STUB_BIN/opencode" agent_host_resolve_cli opencode)"
assert_eq "pi: PI_BIN" "$TL_BIN/pi" "$(PI_BIN="$TL_BIN/pi" agent_host_resolve_cli pi)"
assert_eq "cursor: cursor-agent preferred" "$STUB_BIN/cursor-agent" "$(PATH="$STUB_BIN:$NOHOSTS" agent_host_resolve_cli cursor)"
rm -f "$STUB_BIN/cursor-agent"
assert_eq "cursor: falls back to agent" "$STUB_BIN/agent" "$(PATH="$STUB_BIN:$NOHOSTS" agent_host_resolve_cli cursor)"
rm -f "$STUB_BIN/agent"
rc=0; PATH="$NOHOSTS" agent_host_resolve_cli cursor >/dev/null || rc=$?
assert_eq "cursor: missing returns 1" 1 "$rc"
rc=0; agent_host_resolve_cli bogus >/dev/null || rc=$?
assert_eq "unknown host returns 1" 1 "$rc"
rc=0; PATH="$NOHOSTS" PI_BIN="" HOME="$TL_TMP/nohome" agent_host_resolve_cli pi >/dev/null || rc=$?
assert_eq "pi: missing returns 1" 1 "$rc"

# =================== ni_write_rails_needed ===================
for m in grok-4 qwen3 claude/opus; do
  agent_host_pi_ni_write_rails_needed "$m" && tl_pass "rails needed for $m" || tl_fail "rails needed for $m"
done
agent_host_pi_ni_write_rails_needed mimo-v2.5 && tl_fail "no rails for mimo" || tl_pass "no rails for mimo"

# =================== build_argv ===================
export CLAUDE_BIN="$STUB_BIN/claude" CODEX_BIN="$STUB_BIN/codex" OPENCODE_BIN="$STUB_BIN/opencode"
cp "$STUB_BIN/claude" "$STUB_BIN/cursor-agent"; PATH="$STUB_BIN:$PATH"; hash -r
unset CLAUDE_MODEL CLAUDE_EFFORT CLAUDE_PRINT_VERBOSE CODEX_MODEL SB_LIVE_CODEX_MODEL CODEX_BYPASS_HOOK_TRUST CODEX_AUTO_TRUST_HOOKS \
  OPENCODE_RUN_MODEL PI_PROVIDER PI_MODEL CURSOR_AGENT_OUTPUT_FORMAT SB_AGENT_CURSOR_STREAM_JSON SB_E2E_ENTERPRISE_MATRIX \
  CURSOR_AGENT_RESUME CURSOR_AGENT_MODEL CURSOR_MODEL

rc=0; agent_host_build_argv bogus non-interactive /w p || rc=$?
assert_eq "build: unknown host" 1 "$rc"
rc=0; CLAUDE_BIN="" PATH="$NOHOSTS" HOME="$TL_TMP/nohome" agent_host_build_argv claude non-interactive /w p || rc=$?
assert_eq "build: unresolvable cli" 1 "$rc"
rc=0; agent_host_build_argv claude interactive /w p || rc=$?
assert_eq "build: claude has no interactive mode (2)" 2 "$rc"
agent_host_build_argv claude non-interactive /w "the prompt"
assert_eq "build claude permissive" "$STUB_BIN/claude|--print|--model|sonnet|--effort|low|--permission-mode|bypassPermissions|--verbose|the prompt|" "$(argv_str)"
CLAUDE_PRINT_VERBOSE=0 CLAUDE_MODEL=opus CLAUDE_EFFORT=high; export CLAUDE_PRINT_VERBOSE CLAUDE_MODEL CLAUDE_EFFORT
agent_host_build_argv claude non-interactive /w p strict
assert_eq "build claude strict, quiet, custom model/effort" "$STUB_BIN/claude|--print|--model|opus|--effort|high|--permission-mode|acceptEdits|p|" "$(argv_str)"
unset CLAUDE_PRINT_VERBOSE CLAUDE_MODEL CLAUDE_EFFORT

rc=0; agent_host_build_argv codex interactive /w p || rc=$?
assert_eq "build: codex has no interactive mode (2)" 2 "$rc"
agent_host_build_argv codex non-interactive /w p
assert_eq "build codex permissive" "$STUB_BIN/codex|exec|--cd|/w|--sandbox|danger-full-access|--color|never|--dangerously-bypass-approvals-and-sandbox|p|" "$(argv_str)"
CODEX_BYPASS_HOOK_TRUST=1 SB_LIVE_CODEX_MODEL=gpt-live agent_host_build_argv codex non-interactive /w p strict
assert_eq "build codex strict + hook trust + live model" "$STUB_BIN/codex|exec|--cd|/w|--sandbox|danger-full-access|--color|never|--dangerously-bypass-hook-trust|--model|gpt-live|p|" "$(argv_str)"
CODEX_AUTO_TRUST_HOOKS=1 CODEX_MODEL=gpt-x agent_host_build_argv codex non-interactive /w p strict
assert_contains "build codex auto-trust alias + CODEX_MODEL wins" "$(argv_str)" "--dangerously-bypass-hook-trust|--model|gpt-x|"

agent_host_build_argv opencode non-interactive /w p
assert_eq "build opencode NI" "$STUB_BIN/opencode|run|--dir|/w|-m|opencode-go/mimo-v2.5|--auto|p|" "$(argv_str)"
OPENCODE_RUN_MODEL=opencode-go/other agent_host_build_argv opencode interactive /w p
assert_eq "build opencode interactive" "$STUB_BIN/opencode|/w|-m|opencode-go/other|--auto|--prompt|p|" "$(argv_str)"

agent_host_build_argv pi non-interactive /w p
assert_eq "build pi NI (no rails for mimo)" "$TL_BIN/pi|-p|--provider|opencode-go|--model|mimo-v2.5|p|" "$(argv_str)"
agent_host_build_argv pi interactive /w p
assert_eq "build pi interactive never passes -p" "$TL_BIN/pi|--provider|opencode-go|--model|mimo-v2.5|" "$(argv_str)"
PI_MODEL=qwen3-max PI_PROVIDER=omni agent_host_build_argv pi non-interactive /w p
assert_contains "build pi NI qwen rails" "$(argv_str)" "--provider|omni|--model|qwen3-max|--thinking|off|--no-context-files|--no-skills|--no-extensions|--tools|read,bash,edit,write|--append-system-prompt|NON-INTERACTIVE:"
assert_eq "build pi NI prompt last" "p" "${AGENT_HOST_ARGV[$((${#AGENT_HOST_ARGV[@]} - 1))]}"

agent_host_build_argv cursor non-interactive /w p
assert_eq "build cursor NI permissive" "$STUB_BIN/cursor-agent|--trust|--force|--workspace|/w|--print|--output-format|text|--yolo|p|" "$(argv_str)"
SB_AGENT_CURSOR_STREAM_JSON=1 CURSOR_MODEL=composer agent_host_build_argv cursor non-interactive /w p strict
assert_eq "build cursor NI stream-json + model + strict" "$STUB_BIN/cursor-agent|--trust|--force|--workspace|/w|--print|--output-format|text|--output-format|stream-json|--stream-partial-output|--model|composer|p|" "$(argv_str)"
SB_E2E_ENTERPRISE_MATRIX=1 CURSOR_AGENT_MODEL=m2 agent_host_build_argv cursor non-interactive /w p strict
assert_contains "build cursor enterprise matrix streams, CURSOR_AGENT_MODEL wins" "$(argv_str)" "--stream-partial-output|--model|m2|"
agent_host_build_argv cursor interactive /w p
assert_eq "build cursor interactive" "$STUB_BIN/cursor-agent|--trust|--force|--workspace|/w|--yolo|p|" "$(argv_str)"
CURSOR_AGENT_RESUME=chat-1 agent_host_build_argv cursor interactive /w p strict
assert_eq "build cursor interactive resume" "$STUB_BIN/cursor-agent|--trust|--force|--workspace|/w|--resume|chat-1|p|" "$(argv_str)"

# build_argv default case (impossible host past resolve): resolve succeeds via function override
agent_host_resolve_cli() { printf '%s' "$STUB_BIN/claude"; }
rc=0; agent_host_build_argv bogus non-interactive /w p || rc=$?
assert_eq "build: unexpected host with resolvable cli still fails" 1 "$rc"
# re-source to restore the real resolver
# shellcheck source=/dev/null
source "$S/agent-host-exec.sh"

# =================== dump_argv ===================
AGENT_HOST_ARGV=(a "b c" d)
rc=0; SB_AGENT_HOST_ARGV_FILE="" agent_host_dump_argv || rc=$?
assert_eq "dump: no path is a no-op" 0 "$rc"
agent_host_dump_argv "$TL_TMP/argv/out.txt"
assert_eq "dump: one arg per line, dir created" "a
b c
d" "$(cat "$TL_TMP/argv/out.txt")"
SB_AGENT_HOST_ARGV_FILE="$TL_TMP/argv/env.txt" agent_host_dump_argv
assert_file_exists "dump: env path used" "$TL_TMP/argv/env.txt"

# =================== file_is_stub / file_ok ===================
F="$TL_TMP/f.md"
rc=0; agent_host_pi_file_is_stub "$TL_TMP/missing" || rc=$?
assert_eq "stub: missing file is not a stub" 1 "$rc"
printf 'IN_PROGRESS: working\n' >"$F"; agent_host_pi_file_is_stub "$F" && tl_pass "stub: IN_PROGRESS marker" || tl_fail "stub: IN_PROGRESS marker"
printf 'real content\n' >"$F"; agent_host_pi_file_is_stub "$F" && tl_fail "stub: real content" || tl_pass "stub: real content is not a stub"
rc=0; agent_host_pi_file_ok "$TL_TMP/missing" || rc=$?
assert_eq "ok: missing file" 1 "$rc"
big "$F" 100; rc=0; PI_EXPECT_FILE_MIN_BYTES="" agent_host_pi_file_ok "$F" || rc=$?
assert_eq "ok: below default 2500 bytes" 1 "$rc"
big "$F" 3000; agent_host_pi_file_ok "$F" && tl_pass "ok: large enough" || tl_fail "ok: large enough"
big "$F" 100; PI_EXPECT_FILE_MIN_BYTES=50 agent_host_pi_file_ok "$F" && tl_pass "ok: custom min bytes" || tl_fail "ok: custom min bytes"
PI_EXPECT_FILE_MIN_BYTES=junk agent_host_pi_file_ok "$F" && tl_fail "ok: junk min falls back to 2500" || tl_pass "ok: junk min falls back to 2500"
{ printf 'IN_PROGRESS: x\n'; head -c 3000 /dev/zero | tr '\0' y; } >"$F"
agent_host_pi_file_ok "$F" && tl_fail "ok: large stub rejected" || tl_pass "ok: large stub rejected"

# =================== auth failure / should_continue / hint ===================
for t in "invalid_api_key" "Invalid API key" "missing api key" "HTTP 401 unauthorized" "insufficient balance" "insufficient_quota"; do
  agent_host_pi_is_auth_failure "$t" && tl_pass "auth failure: $t" || tl_fail "auth failure: $t"
done
agent_host_pi_is_auth_failure "port 14012 ok" && tl_fail "auth: 4012 is not 401" || tl_pass "auth: embedded digits are not 401"
agent_host_pi_should_continue 1 "fine" && tl_fail "continue: nonzero rc" || tl_pass "continue: nonzero rc stops"
agent_host_pi_should_continue 0 "401" && tl_fail "continue: auth failure" || tl_pass "continue: auth failure stops"
agent_host_pi_should_continue 0 "plan only" && tl_pass "continue: clean exit 0 continues" || tl_fail "continue: clean exit 0 continues"

tl_run agent_host_pi_surface_auth_hint $'line\ninsufficient credits left\nresets in 2h\nresets in 3h'
assert_contains "hint: billing line" "$TL_ERR" "[agent-pi] first-hop billing: insufficient credits left"
assert_contains "hint: first quota-window line only" "$TL_ERR" "[agent-pi] quota-window: resets in 2h"
assert_not_contains "hint: later window lines dropped" "$TL_ERR" "3h"
tl_run agent_host_pi_surface_auth_hint "all quiet"
assert_eq "hint: nothing to surface" "" "$TL_ERR"

# =================== continue / fresh prompts ===================
unset PI_CONTINUE PI_CONTINUE_RETRY
assert_contains "continue prompt hop 1 default" "$(agent_host_pi_continue_prompt /a/out.md 1)" "STOP. ./out.md is still missing"
assert_contains "continue prompt hop 2 default" "$(agent_host_pi_continue_prompt /a/out.md 2)" "You already failed by emitting a plan sentence"
assert_eq "continue prompt hop 1 override" "go1" "$(PI_CONTINUE=go1 agent_host_pi_continue_prompt /a/out.md)"
assert_eq "continue prompt hop 2 override" "go2" "$(PI_CONTINUE=go1 PI_CONTINUE_RETRY=go2 agent_host_pi_continue_prompt /a/out.md 2)"
assert_contains "continue prompt hop 2 ignores PI_CONTINUE" "$(PI_CONTINUE=go1 agent_host_pi_continue_prompt /a/out.md 2)" "You already failed"
assert_contains "fresh prompt with original" "$(agent_host_pi_fresh_rewrite_prompt /a/out.md 'ORIGINAL')" "FRESH SESSION (not --continue). ./out.md"
assert_contains "fresh prompt appends original" "$(agent_host_pi_fresh_rewrite_prompt /a/out.md 'ORIGINAL')" "

ORIGINAL"
assert_not_contains "fresh prompt without original" "$(agent_host_pi_fresh_rewrite_prompt /a/out.md)" "ORIGINAL"

# =================== zero-byte idle ===================
unset PI_NI_ZERO_BYTE_IDLE_SEC PI_NI_ZERO_BYTE_IDLE_QWEN_SEC PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC PI_MODEL
assert_eq "idle: env override wins" "7" "$(PI_NI_ZERO_BYTE_IDLE_SEC=7 agent_host_pi_zero_byte_idle_sec qwen)"
assert_eq "idle: qwen default" "120" "$(agent_host_pi_zero_byte_idle_sec qwen3)"
assert_eq "idle: qwen custom" "30" "$(PI_NI_ZERO_BYTE_IDLE_QWEN_SEC=30 agent_host_pi_zero_byte_idle_sec qwen3)"
assert_eq "idle: non-qwen default" "600" "$(agent_host_pi_zero_byte_idle_sec mimo)"
assert_eq "idle: non-qwen custom" "45" "$(PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC=45 agent_host_pi_zero_byte_idle_sec mimo)"
assert_eq "idle: model defaults to PI_MODEL" "120" "$(PI_MODEL=qwen-x agent_host_pi_zero_byte_idle_sec)"
assert_eq "idle: empty model is non-qwen" "600" "$(agent_host_pi_zero_byte_idle_sec)"

# =================== zero-byte guard invocation ===================
reset_log
AGENT_HOST_ARGV=(pi -p hello)
(cd "$TL_TMP" && PI_MODEL=qwen3 PI_RUN_TIMEOUT=33 PI_EXPECT_FILE_MIN_BYTES=7 agent_host_pi_run_argv_zero_byte_guard /e/out.md) >/dev/null
assert_contains "guard receives idle, hard, expect, min, argv" "$(logged)" "GUARD idle=120 hard=33 expect=/e/out.md min=7 cwd=$TL_TMP argv=pi -p hello"
reset_log
(PI_MODEL=mimo PI_EXPECT_FILE_MIN_BYTES=junk agent_host_pi_run_argv_zero_byte_guard) >/dev/null
assert_contains "guard defaults: 600 idle, 900 hard, 2500 min, empty expect" "$(logged)" "GUARD idle=600 hard=900 expect= min=2500"
rc=0; GUARD_PLAN=5 agent_host_pi_run_argv_zero_byte_guard /e >/dev/null || rc=$?
assert_eq "guard propagates exit status" 5 "$rc"
reset_log
(agent_host_pi_run_guard_with_argv /e/x.md pi --foo bar; echo "after: $(argv_str)") >"$TL_TMP/o" 2>&1
assert_contains "run_guard_with_argv passes replacement argv" "$(logged)" "argv=pi --foo bar"

# =================== fresh_rewrite_for_file ===================
W="$TL_TMP/work"; mkdir -p "$W"
EXP="$W/out.md"
export PI_EXPECT_OUT="$EXP"
unset PI_PLAN
rm -f "$EXP"; big "$EXP" 3000
rc=0; agent_host_pi_fresh_rewrite_for_file "$EXP" orig "$W" || rc=$?
assert_eq "fresh: already ok returns 0 without work" 0 "$rc"
rm -f "$EXP"
rc=0; PATH="$NOHOSTS" PI_BIN="" HOME="$TL_TMP/nohome" agent_host_pi_fresh_rewrite_for_file "$EXP" orig "$W" || rc=$?
assert_eq "fresh: no pi cli returns 127" 127 "$rc"
rc=0; agent_host_pi_fresh_rewrite_for_file "$EXP" orig "$TL_TMP/no-such-dir" 2>/dev/null || rc=$?
assert_eq "fresh: mktemp failure returns 1" 1 "$rc"
reset_log
rc=0; GUARD_PLAN="0:3000" GUARD_OUT=guard-said agent_host_pi_fresh_rewrite_for_file "$EXP" "the original" "$W" >"$TL_TMP/o" 2>"$TL_TMP/e" || rc=$?
assert_eq "fresh: success returns 0" 0 "$rc"
assert_contains "fresh: guard output replayed" "$(cat "$TL_TMP/o")" "guard-said"
assert_contains "fresh: announces new session dir" "$(cat "$TL_TMP/e")" "[agent-pi] fresh pi -p rewrite (new session dir, not --continue) in $W/.pi-fresh-rewrite."
assert_contains "fresh: argv has session dir, tools and prompt" "$(logged)" "--provider opencode-go --model mimo-v2.5 --session-dir $W/.pi-fresh-rewrite."
assert_contains "fresh: write tools only" "$(logged)" '--tools write,edit,read,bash FRESH SESSION'
assert_not_contains "fresh: no rails for mimo" "$(logged)" "--thinking off"
rm -f "$EXP"; reset_log
PI_MODEL=qwen3 GUARD_PLAN="0:3000" agent_host_pi_fresh_rewrite_for_file "$EXP" "x" "$W" >/dev/null 2>&1
assert_contains "fresh: rails for qwen" "$(logged)" "--thinking off --no-context-files --no-skills --no-extensions --append-system-prompt NON-INTERACTIVE:"
# file still missing: error with guard rc, plain rc 0 -> 1, auth failure variants
rm -f "$EXP"
rc=0; GUARD_PLAN="4" agent_host_pi_fresh_rewrite_for_file "$EXP" x "$W" >/dev/null 2>"$TL_TMP/e" || rc=$?
assert_eq "fresh: missing file propagates guard rc" 4 "$rc"
assert_contains "fresh: missing file error" "$(cat "$TL_TMP/e")" "ERROR: expected file missing, too small, or IN_PROGRESS stub after pi -p: $EXP"
rc=0; GUARD_PLAN="0" agent_host_pi_fresh_rewrite_for_file "$EXP" x "$W" >/dev/null 2>&1 || rc=$?
assert_eq "fresh: missing file with rc 0 returns 1" 1 "$rc"
rc=0; GUARD_PLAN="9" GUARD_OUT="HTTP 401 insufficient credits" agent_host_pi_fresh_rewrite_for_file "$EXP" x "$W" >/dev/null 2>"$TL_TMP/e" || rc=$?
assert_eq "fresh: auth failure propagates guard rc" 9 "$rc"
assert_contains "fresh: auth failure fail-fast message" "$(cat "$TL_TMP/e")" "fail-fast: skipping --continue after fresh rewrite EXIT 9"
assert_contains "fresh: auth hint surfaced" "$(cat "$TL_TMP/e")" "first-hop billing: HTTP 401 insufficient credits"
rc=0; GUARD_PLAN="0" GUARD_OUT="invalid_api_key" agent_host_pi_fresh_rewrite_for_file "$EXP" x "$W" >/dev/null 2>&1 || rc=$?
assert_eq "fresh: auth failure with rc 0 returns 1" 1 "$rc"
# default original prompt/work dir
rm -f "$EXP"; reset_log
(cd "$W" && PI_ORIGINAL_PROMPT=from-env GUARD_PLAN="0:3000" agent_host_pi_fresh_rewrite_for_file "$EXP") >/dev/null 2>&1
assert_contains "fresh: PI_ORIGINAL_PROMPT default" "$(logged)" "from-env"

# =================== continue_for_file ===================
rm -f "$EXP"
rc=0; PATH="$NOHOSTS" PI_BIN="" HOME="$TL_TMP/nohome" agent_host_pi_continue_for_file "$EXP" "" x "$W" || rc=$?
assert_eq "continue: no pi cli returns 127" 127 "$rc"
rm -f "$EXP"; big "$EXP" 3000; reset_log
rc=0; agent_host_pi_continue_for_file "$EXP" "" x "$W" >/dev/null 2>&1 || rc=$?
assert_eq "continue: file already ok" 0 "$rc"
assert_eq "continue: nothing launched" "" "$(logged)"
# first hop writes the file
rm -f "$EXP"; reset_log; : >"$TL_TMP/pic"; rm -f "$TL_TMP/pic"
rc=0; PI_PLAN="0:3000" PI_COUNTER="$TL_TMP/pic" agent_host_pi_continue_for_file "$EXP" "my continue" x "$W" >/dev/null 2>"$TL_TMP/e" || rc=$?
assert_eq "continue: success on hop 1" 0 "$rc"
assert_contains "continue: hop banner" "$(cat "$TL_TMP/e")" "[agent-pi] --continue hop 1/2 for $EXP"
assert_contains "continue: argv and custom prompt" "$(logged)" "PI -p --continue --provider opencode-go --model mimo-v2.5 --tools write,edit my continue"
# hop 2 uses the generated prompt even with a custom first prompt; both hops fail -> fresh rewrite
rm -f "$EXP" "$TL_TMP/pic"; reset_log
rc=0; PI_MODEL=grok-4 PI_PLAN="0,0" PI_COUNTER="$TL_TMP/pic" GUARD_PLAN="0:3000" agent_host_pi_continue_for_file "$EXP" "first" orig "$W" >/dev/null 2>&1 || rc=$?
assert_eq "continue: falls through to fresh rewrite" 0 "$rc"
assert_eq "continue: two hops ran" 2 "$(grep -c '^PI -p --continue' "$FAKE_LOG")"
assert_contains "continue: rails on grok" "$(logged)" "--thinking off --no-context-files --no-skills --no-extensions --append-system-prompt Write the COMPLETE deliverable now."
assert_contains "continue: hop 2 uses default retry prompt" "$(logged)" "You already failed by emitting a plan sentence"
assert_contains "continue: fresh rewrite runs through guard" "$(logged)" "GUARD idle="
assert_contains "continue: fresh rewrite carries original prompt" "$(logged)" "orig"
# PI_CONTINUE_MAX bounds hops; junk resets to 2; original prompt falls back to last argv word
rm -f "$EXP" "$TL_TMP/pic"; reset_log; AGENT_HOST_ARGV=(pi -p "argv-prompt")
PI_CONTINUE_MAX=3 PI_PLAN="0,0,0:3000" PI_COUNTER="$TL_TMP/pic" agent_host_pi_continue_for_file "$EXP" "" "" "$W" >/dev/null 2>&1
assert_eq "continue: PI_CONTINUE_MAX=3 allows three hops" 3 "$(grep -c '^PI -p --continue' "$FAKE_LOG")"
rm -f "$EXP" "$TL_TMP/pic"; reset_log
PI_CONTINUE_MAX=junk PI_PLAN="0" PI_COUNTER="$TL_TMP/pic" GUARD_PLAN="0:3000" agent_host_pi_continue_for_file "$EXP" "" "" "$W" >/dev/null 2>&1
assert_eq "continue: junk PI_CONTINUE_MAX falls back to two hops" 2 "$(grep -c '^PI -p --continue' "$FAKE_LOG")"
assert_contains "continue: original prompt taken from AGENT_HOST_ARGV" "$(logged)" "argv-prompt"
AGENT_HOST_ARGV=()

# =================== run_pi_until_file ===================
rm -f "$EXP"; big "$EXP" 3000
reset_log
rc=0; GUARD_PLAN="7" agent_host_run_pi_until_file "$EXP" >/dev/null 2>&1 || rc=$?
assert_eq "until: ok file returns guard rc" 7 "$rc"
rm -f "$EXP"
rc=0; GUARD_PLAN="3" GUARD_OUT="HTTP 401" agent_host_run_pi_until_file "$EXP" >"$TL_TMP/o" 2>"$TL_TMP/e" || rc=$?
assert_eq "until: auth failure keeps guard rc" 3 "$rc"
assert_contains "until: fail-fast message" "$(cat "$TL_TMP/e")" "fail-fast: skipping --continue after first-run EXIT 3"
assert_contains "until: guard output teed to stdout" "$(cat "$TL_TMP/o")" "HTTP 401"
rc=0; GUARD_PLAN="0" GUARD_OUT="HTTP 401 unauthorized" agent_host_run_pi_until_file "$EXP" >/dev/null 2>&1 || rc=$?
assert_eq "until: auth failure on rc 0 returns 1" 1 "$rc"
rc=0; GUARD_PLAN="2" GUARD_OUT="boom" agent_host_run_pi_until_file "$EXP" >/dev/null 2>&1 || rc=$?
assert_eq "until: failed run (rc 2) never continues" 2 "$rc"
# plan-only exit 0 -> continue hop writes the file
rm -f "$EXP" "$TL_TMP/pic"; reset_log
rc=0; GUARD_PLAN="0" PI_PLAN="0:3000" PI_COUNTER="$TL_TMP/pic" agent_host_run_pi_until_file "$EXP" "go on" >/dev/null 2>&1 || rc=$?
assert_eq "until: plan-only run continues and succeeds" 0 "$rc"
assert_contains "until: continuation launched with prompt" "$(logged)" "PI -p --continue"

# =================== exec_native ===================
exec_native() { # <expected-env...> -- host work prompt [perm]
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  tl_run env "${envs[@]}" bash -c 'source "$1"; shift; agent_host_exec_native "$@"' _ "$S/agent-host-exec.sh" "$@"
}
exec_native X=1 -- bogus "$W" prompt
assert_eq "exec_native: unknown host returns 127" 127 "$TL_STATUS"
exec_native X=1 -- claude "$TL_TMP/no-such-dir" prompt
assert_eq "exec_native: missing work dir returns 1" 1 "$TL_STATUS"
printf '#!/usr/bin/env bash\necho "claude-ran cwd=$PWD args=$*"\nexit 6\n' >"$STUB_BIN/claude"
exec_native CLAUDE_BIN="$STUB_BIN/claude" SB_AGENT_HOST_ARGV_FILE="$TL_TMP/native-argv" -- claude "$W" "do it"
assert_eq "exec_native: exec replaces shell, status from CLI" 6 "$TL_STATUS"
assert_contains "exec_native: ran in work dir with argv" "$TL_OUT" "claude-ran cwd=$W args=--print --model sonnet --effort low --permission-mode bypassPermissions --verbose do it"
assert_contains "exec_native: argv dumped" "$(cat "$TL_TMP/native-argv")" "do it"
# pi + expect file runs (does not exec) and exits with the until-file status
rm -f "$EXP"; reset_log
exec_native PI_EXPECT_FILE="$EXP" GUARD_PLAN="0:3000" FAKE_LOG="$FAKE_LOG" -- pi "$W" "pi prompt"
assert_eq "exec_native: pi with expect file exits with run status" 0 "$TL_STATUS"
assert_contains "exec_native: pi went through the guard" "$(logged)" "GUARD idle="
rm -f "$EXP"
exec_native SB_AGENT_EXPECT_FILE="$EXP" GUARD_PLAN="5" FAKE_LOG="$FAKE_LOG" -- pi "$W" "pi prompt"
assert_eq "exec_native: pi failure status propagates via SB_AGENT_EXPECT_FILE" 5 "$TL_STATUS"
# pi without an expect file is exec'd directly
reset_log
exec_native FAKE_LOG="$FAKE_LOG" PI_PLAN=0 -- pi "$W" "plain"
assert_eq "exec_native: pi without expect file execs the CLI" 0 "$TL_STATUS"
assert_contains "exec_native: direct pi argv" "$(logged)" "PI -p --provider opencode-go --model mimo-v2.5 plain"

# =================== run_pty ===================
# Interactive hosts only; the child is a stub that exits at once. No timeout kill is exercised.
printf '#!/usr/bin/env bash\necho "pty-child cwd=$PWD args=$*"\nexit "${PTY_RC:-0}"\n' >"$STUB_BIN/opencode"
pty() { tl_run env OPENCODE_BIN="$STUB_BIN/opencode" "$@" bash -c 'source "$1"; shift; agent_host_run_pty "$@"' _ "$S/agent-host-exec.sh" opencode "$W" "hi"; }
pty PTY_RC=0
assert_eq "pty: child exit 0" 0 "$TL_STATUS"
assert_contains "pty: output relayed with interactive argv" "$TL_OUT" "pty-child cwd=$W args=$W -m opencode-go/mimo-v2.5 --auto --prompt hi"
pty PTY_RC=4
assert_eq "pty: child exit code propagated" 4 "$TL_STATUS"
pty PTY_RC=127
assert_eq "pty: exit 127 maps to mode-unavailable 3" 3 "$TL_STATUS"
tl_run env CLAUDE_BIN="$STUB_BIN/claude" bash -c 'source "$1"; shift; agent_host_run_pty "$@"' _ "$S/agent-host-exec.sh" claude "$W" hi
assert_eq "pty: host without interactive mode returns 2" 2 "$TL_STATUS"
tl_run env PATH="$NOHOSTS" OPENCODE_BIN="" HOME="$TL_TMP/nohome" bash -c 'source "$1"; shift; agent_host_run_pty "$@"' _ "$S/agent-host-exec.sh" opencode "$W" hi
assert_eq "pty: missing cli returns 1" 1 "$TL_STATUS"
tl_run env OPENCODE_BIN="$STUB_BIN/opencode" bash -c 'source "$1"; shift; agent_host_run_pty "$@"' _ "$S/agent-host-exec.sh" opencode "$TL_TMP/no-such-dir" hi
assert_eq "pty: chdir failure in child maps to 3" 3 "$TL_STATUS"

tl_results

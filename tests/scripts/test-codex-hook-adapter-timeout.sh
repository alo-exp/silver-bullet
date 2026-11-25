#!/usr/bin/env bash
# Regression: codex-hook-adapter must kill slow hook subprocesses (orphan prevention).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="${REPO_ROOT}/hooks/codex-hook-adapter.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }


# A hook that records that it really started (SB_TEST_STUB_MARK) and then hangs.
# The timeout verdict is only judged once the hang was actually reached: a hook
# that never started (spawn failure under heavy load or tracing) proves nothing
# about the timeout path and is retried, while every other outcome is reported
# with the adapter's exit status and stderr so a failure explains itself.
mk_slow_stub() { # path [body] (default: hang)
  printf '#!/usr/bin/env bash\n[[ -z "${SB_TEST_STUB_MARK:-}" ]] || : >"$SB_TEST_STUB_MARK"\n%s\n' "${2:-sleep 30}" >"$1"
  chmod +x "$1"
}
slow_stub="$(mktemp)"
mk_slow_stub "$slow_stub"

# run_slow STUB EVENT [VAR=VAL ...] -> OUT (stdout), RC (adapter exit status), ERR (stderr head), STARTED (yes/no)
run_slow() {
  local stub="$1" ev="$2" mark errf attempt
  shift 2
  mark="$(mktemp -u)"
  errf="$(mktemp)"
  STARTED=no
  for attempt in 1 2 3; do
    rm -f "$mark"
    RC=0
    OUT=$(printf '{}' | env SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 SB_TEST_STUB_MARK="$mark" "$@" "$ADAPTER" "$ev" "$stub" 2>"$errf") || RC=$?
    if [[ -e "$mark" ]]; then
      STARTED=yes
      break
    fi
    echo "NOTE: $ev hook never started on attempt $attempt (adapter rc=$RC, stderr: $(head -c 300 "$errf")); the timeout path was not reached, retrying"
  done
  ERR="$(head -c 500 "$errf")"
  rm -f "$mark" "$errf"
}
# diag: what the adapter did, appended to every FAIL line of a run_slow check.
diag() { printf 'got: [%s] (adapter rc=%s, hook started=%s, stderr=[%s])' "$OUT" "$RC" "$STARTED" "$ERR"; }

start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
run_slow "$slow_stub" PreToolUse
out="$OUT"
end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
elapsed=$((end_ms - start_ms))

if [[ "$elapsed" -lt 8000 ]]; then
  pass "adapter returned within 8s for 30s stub (elapsed ${elapsed}ms)"
else
  fail "adapter hung too long for slow stub (elapsed ${elapsed}ms)"
fi

if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | test("timed out"))' >/dev/null 2>&1; then
  pass "PreToolUse timeout fails closed (deny, not allow)"
else
  fail "PreToolUse timeout must emit a deny, $(diag)"
fi

run_slow "$slow_stub" Stop
out="$OUT"
if printf '%s' "$out" | jq -e '.decision == "block" and (.reason | test("timed out"))' >/dev/null 2>&1; then
  pass "Stop timeout fails closed (block)"
else
  fail "Stop timeout must emit a block, $(diag)"
fi
run_slow "$slow_stub" SubagentStop
out="$OUT"
if printf '%s' "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "SubagentStop timeout fails closed (block)"
else
  fail "SubagentStop timeout must emit a block, $(diag)"
fi

run_slow "$slow_stub" PostToolUse
out="$OUT"
if printf '%s' "$out" | jq -e '.systemMessage | test("timed out")' >/dev/null 2>&1; then
  pass "PostToolUse timeout only emits the timeout systemMessage"
else
  fail "PostToolUse timeout should emit a systemMessage, $(diag)"
fi

run_slow "$slow_stub" PreToolUse SB_CODEX_HOOK_ON_TIMEOUT=allow
out="$OUT"
if printf '%s' "$out" | jq -e '.systemMessage | test("timed out")' >/dev/null 2>&1; then
  pass "SB_CODEX_HOOK_ON_TIMEOUT=allow is the explicit opt-out"
else
  fail "opt-out should emit only the notice, $(diag)"
fi

# R7-01: the hook's own hooks.json budget (--timeout) is honoured: a hook that
# takes 2 s and then denies must deliver its deny under a 5 s budget, and only
# time out under a 1 s budget. The 12 s default no longer applies.
deny_stub="$(mktemp)"
printf '#!/usr/bin/env bash\nsleep 2\necho '"'"'{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"slow gate says no"}}'"'"'\n' >"$deny_stub"
chmod +x "$deny_stub"
out=$(printf '{}' | "$ADAPTER" PreToolUse --timeout 5 "$deny_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecisionReason == "slow gate says no"' >/dev/null 2>&1; then
  pass "--timeout 5 lets a 2 s gate deliver its own deny"
else
  fail "--timeout budget not honoured: $out"
fi
out=$(printf '{}' | "$ADAPTER" PreToolUse --timeout 1 "$deny_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecisionReason | test("timed out")' >/dev/null 2>&1; then
  pass "--timeout 1 stops the same gate and denies"
else
  fail "--timeout 1 should time out into a deny: $out"
fi
# A malformed budget falls back to the safe default (120), not to a short cap.
out=$(printf '{}' | "$ADAPTER" PreToolUse --timeout abc "$deny_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecisionReason == "slow gate says no"' >/dev/null 2>&1; then
  pass "malformed --timeout falls back to the default budget"
else
  fail "malformed --timeout should fall back: $out"
fi

# R7-02: without python3 the hook's deny and block still reach the host.
nopy="$(mktemp -d)"
for tool in bash cat mktemp rm timeout sleep env dirname jq; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$src" ]] && ln -s "$src" "$nopy/$tool"
done
out=$(printf '{}' | PATH="$nopy" "$BASH" "$ADAPTER" PreToolUse "$deny_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and .hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1; then
  pass "no python3: PreToolUse deny is kept"
else
  fail "no python3: deny dropped: $out"
fi
block_stub="$(mktemp)"
printf '#!/usr/bin/env bash\necho '"'"'{"decision":"block","reason":"stop floor"}'"'"'\n' >"$block_stub"
chmod +x "$block_stub"
out=$(printf '{}' | PATH="$nopy" "$BASH" "$ADAPTER" Stop "$block_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "no python3: Stop block is kept"
else
  fail "no python3: block dropped: $out"
fi
# Without jq as well the raw hook output is passed through byte for byte.
rm -f "$nopy/jq"
out=$(printf '{}' | PATH="$nopy" "$BASH" "$ADAPTER" Stop "$block_stub" 2>/dev/null || true)
if [[ "$out" == '{"decision":"block","reason":"stop floor"}' ]]; then
  pass "no python3 and no jq: raw output passed through"
else
  fail "raw pass-through expected, got: $out"
fi
# Non-JSON output is also passed through unchanged.
text_stub="$(mktemp)"
printf '#!/usr/bin/env bash\necho plain text\n' >"$text_stub"
chmod +x "$text_stub"
out=$(printf '{}' | "$ADAPTER" PreToolUse "$text_stub" 2>/dev/null || true)
if [[ "$out" == "plain text" ]]; then
  pass "non-JSON output passed through"
else
  fail "non-JSON output should pass through, got: $out"
fi
# Env overrides are validated: a non-numeric or zero cap falls back to the
# manifest budget instead of crashing `timeout` (rc 125, deny lost) or disabling it.
for bad_cap in abc 0 00 0.000 0e0 -1 -5 NaN nan inf 1e3 . 5. .5 "1;2" " "; do
  out=$(printf '{}' | SB_CODEX_HOOK_SUBPROC_TIMEOUT="$bad_cap" "$ADAPTER" PreToolUse --timeout 5 "$deny_stub" 2>/dev/null || true)
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecisionReason == "slow gate says no"' >/dev/null 2>&1; then
    pass "invalid SB_CODEX_HOOK_SUBPROC_TIMEOUT [$bad_cap] ignored, deny kept"
  else
    fail "invalid SB_CODEX_HOOK_SUBPROC_TIMEOUT [$bad_cap] lost the deny: $out"
  fi
done
# Only exactly "allow" opts out of fail-closed.
slow2="$(mktemp)"; mk_slow_stub "$slow2"
for odd in block deny DENY Allow yes ""; do
  run_slow "$slow2" PreToolUse SB_CODEX_HOOK_ON_TIMEOUT="$odd"
  out="$OUT"
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    pass "SB_CODEX_HOOK_ON_TIMEOUT=[$odd] still fails closed"
  else
    fail "SB_CODEX_HOOK_ON_TIMEOUT=[$odd] must fail closed, $(diag)"
  fi
done
rm -f "$slow2"

# --timeout without a value or a command is a usage error (exit 2).
rc=0
printf '{}' | "$ADAPTER" PreToolUse --timeout >/dev/null 2>&1 || rc=$?
if [[ "$rc" -eq 2 ]]; then
  pass "--timeout without value/command: usage error (exit 2)"
else
  fail "--timeout without value/command should exit 2, got $rc"
fi
rm -rf "$nopy" "$deny_stub" "$block_stub" "$text_stub"


# A hook ended by a signal produced no verdict: GNU timeout (and the python3 fallback)
# report it as 128 + signal, not 124, and a Codex host treats an empty exit-143 as a
# non-blocking error, i.e. an allow. The adapter treats it like a timeout: deny/block on
# the events that can deny, a notice elsewhere, the same opt-out.
sig_dir="$(mktemp -d)"
for sig in TERM KILL HUP; do
  mk_slow_stub "$sig_dir/die-$sig" "kill -$sig \$\$"
done
for sig in TERM:15:SIGTERM KILL:9:SIGKILL HUP:1:SIGHUP; do
  IFS=: read -r sname snum slabel <<<"$sig"
  want="terminated by signal $snum ($slabel) and produced no verdict"
  run_slow "$sig_dir/die-$sname" PreToolUse
  if printf '%s' "$OUT" | jq -e --arg w "$want" '.hookSpecificOutput.permissionDecision == "deny" and .hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput.permissionDecisionReason | contains($w))' >/dev/null 2>&1 && [[ "$RC" -eq 0 ]]; then
    pass "PreToolUse hook killed by $sname fails closed (deny, adapter exit 0)"
  else
    fail "PreToolUse hook killed by $sname must deny, $(diag)"
  fi
  for ev in Stop SubagentStop; do
    run_slow "$sig_dir/die-$sname" "$ev"
    if printf '%s' "$OUT" | jq -e --arg w "$want" '.decision == "block" and (.reason | contains($w))' >/dev/null 2>&1; then
      pass "$ev hook killed by $sname fails closed (block)"
    else
      fail "$ev hook killed by $sname must block, $(diag)"
    fi
  done
  run_slow "$sig_dir/die-$sname" PostToolUse
  if printf '%s' "$OUT" | jq -e --arg w "$want" '.systemMessage | contains($w)' >/dev/null 2>&1 && ! printf '%s' "$OUT" | jq -e 'has("decision") or has("hookSpecificOutput")' >/dev/null 2>&1; then
    pass "PostToolUse hook killed by $sname only emits the notice"
  else
    fail "PostToolUse hook killed by $sname must emit only a notice, $(diag)"
  fi
done
run_slow "$sig_dir/die-TERM" PreToolUse SB_CODEX_HOOK_ON_TIMEOUT=allow
if printf '%s' "$OUT" | jq -e '.systemMessage | test("terminated by signal 15")' >/dev/null 2>&1 && ! printf '%s' "$OUT" | jq -e 'has("hookSpecificOutput")' >/dev/null 2>&1; then
  pass "SB_CODEX_HOOK_ON_TIMEOUT=allow also opts out for a killed hook"
else
  fail "opt-out for a killed hook should emit only the notice, $(diag)"
fi
# Ordinary exit codes are the hook's own and are not rewritten.
for code in 1 2 127; do
  mk_slow_stub "$sig_dir/exit-$code" "echo 'plain output'; exit $code"
  run_slow "$sig_dir/exit-$code" PreToolUse
  if [[ "$OUT" == "plain output" && "$RC" -eq "$code" ]]; then
    pass "hook exit $code passes through unchanged (output kept, exit $code)"
  else
    fail "hook exit $code must pass through, $(diag)"
  fi
done
# The python3 fallback (no GNU timeout on PATH) reports the same three outcomes.
pyonly="$(mktemp -d)"
for tool in bash cat mktemp rm sleep env dirname jq python3; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [[ -z "$src" ]] || ln -s "$src" "$pyonly/$tool"
done
[[ ! -e "$pyonly/timeout" ]] || fail "python-only PATH must not hold GNU timeout"
out=$(printf '{}' | PATH="$pyonly" "$BASH" "$ADAPTER" PreToolUse "$sig_dir/die-TERM" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("signal 15"))' >/dev/null 2>&1; then
  pass "python3 fallback: a killed hook is denied"
else
  fail "python3 fallback: killed hook must deny, got: $out"
fi
out=$(printf '{}' | SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 PATH="$pyonly" "$BASH" "$ADAPTER" Stop "$slow_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.decision == "block" and (.reason | contains("timed out"))' >/dev/null 2>&1; then
  pass "python3 fallback: a timeout still blocks"
else
  fail "python3 fallback: timeout must block, got: $out"
fi
rc=0
out=$(printf '{}' | PATH="$pyonly" "$BASH" "$ADAPTER" PreToolUse "$sig_dir/exit-2" 2>/dev/null) || rc=$?
if [[ "$out" == "plain output" && "$rc" -eq 2 ]]; then
  pass "python3 fallback: exit 2 passes through"
else
  fail "python3 fallback: exit 2 must pass through, got rc=$rc out=$out"
fi
rm -rf "$sig_dir" "$pyonly"
rm -f "$slow_stub"

# Direct lib check (macOS python3 fallback when GNU timeout absent)
# shellcheck source=../../hooks/lib/hook-subproc-timeout.sh
source "$REPO_ROOT/hooks/lib/hook-subproc-timeout.sh"
lib_stub="$(mktemp)"
mk_slow_stub "$lib_stub"
lib_in="$(mktemp)"; lib_out="$(mktemp)"; lib_err="$(mktemp)"
printf '{}' >"$lib_in"
lib_start=$(python3 -c 'import time; print(int(time.time()*1000))')
set +e
sb_run_hooked_command 1 "$lib_in" "$lib_out" "$lib_err" "$lib_stub"
lib_rc=$?
set -e
lib_end=$(python3 -c 'import time; print(int(time.time()*1000))')
lib_elapsed=$((lib_end - lib_start))
rm -f "$lib_stub" "$lib_in" "$lib_out" "$lib_err"
if [[ "$lib_elapsed" -lt 8000 && "$lib_rc" -eq 124 ]]; then
  pass "lib sb_run_hooked_command timeout=1 kills 30s stub (elapsed ${lib_elapsed}ms)"
else
  fail "lib sb_run_hooked_command expected <8s and rc 124 (elapsed ${lib_elapsed}ms, rc=$lib_rc)
"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]


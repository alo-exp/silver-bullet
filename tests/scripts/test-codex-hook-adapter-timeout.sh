#!/usr/bin/env bash
# Regression: codex-hook-adapter must kill slow hook subprocesses (orphan prevention).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="${REPO_ROOT}/hooks/codex-hook-adapter.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; ((PASS++)) || true; }
fail() { echo "FAIL: $1"; ((FAIL++)) || true; }


slow_stub="$(mktemp)"
printf '#!/usr/bin/env bash\nsleep 30\n' >"$slow_stub"
chmod +x "$slow_stub"

start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
out=$(printf '{}' | env SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 "$ADAPTER" PreToolUse "$slow_stub" 2>/dev/null || true)
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
  fail "PreToolUse timeout must emit a deny, got: $out"
fi

out=$(printf '{}' | env SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 "$ADAPTER" Stop "$slow_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.decision == "block" and (.reason | test("timed out"))' >/dev/null 2>&1; then
  pass "Stop timeout fails closed (block)"
else
  fail "Stop timeout must emit a block, got: $out"
fi
out=$(printf '{}' | env SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 "$ADAPTER" SubagentStop "$slow_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  pass "SubagentStop timeout fails closed (block)"
else
  fail "SubagentStop timeout must emit a block, got: $out"
fi

out=$(printf '{}' | env SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 "$ADAPTER" PostToolUse "$slow_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.systemMessage | test("timed out")' >/dev/null 2>&1; then
  pass "PostToolUse timeout only emits the timeout systemMessage"
else
  fail "PostToolUse timeout should emit a systemMessage, got: $out"
fi

out=$(printf '{}' | env SB_CODEX_HOOK_SUBPROC_TIMEOUT=1 SB_CODEX_HOOK_ON_TIMEOUT=allow "$ADAPTER" PreToolUse "$slow_stub" 2>/dev/null || true)
if printf '%s' "$out" | jq -e '.systemMessage | test("timed out")' >/dev/null 2>&1; then
  pass "SB_CODEX_HOOK_ON_TIMEOUT=allow is the explicit opt-out"
else
  fail "opt-out should emit only the notice, got: $out"
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
rm -rf "$nopy" "$deny_stub" "$block_stub" "$text_stub"

rm -f "$slow_stub"

# Direct lib check (macOS python3 fallback when GNU timeout absent)
# shellcheck source=../../hooks/lib/hook-subproc-timeout.sh
source "$REPO_ROOT/hooks/lib/hook-subproc-timeout.sh"
lib_stub="$(mktemp)"
printf '#!/usr/bin/env bash\nsleep 30\n' >"$lib_stub"
chmod +x "$lib_stub"
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


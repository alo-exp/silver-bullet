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

if printf '%s' "$out" | jq -e '.systemMessage | test("timed out")' >/dev/null 2>&1; then
  pass "adapter emits timeout systemMessage"
else
  fail "adapter should emit timeout systemMessage on subprocess timeout"
fi

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


---
phase: 060-test-coverage
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - tests/hooks/test-session-log-init.sh
  - tests/hooks/test-dev-cycle-check.sh
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 060: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Two test files were reviewed as part of the Phase 060 test-coverage expansion. The changes are:

- `test-session-log-init.sh` Test 8: expanded to assert that the `sentinel-lock-<uuid>` file is created alongside the `sentinel-pid` file in autonomous mode (TST-01).
- `test-dev-cycle-check.sh` Tests 17g and 17h: added coverage for the quote-literal exemption in the state-tamper guard — 17g asserts that a state path inside a quoted `echo` argument is not blocked, and 17h asserts that the exemption does not fire when the quoted path is a `tee` redirect target.

Both new additions test real behavior correctly. There are two warnings regarding resource-leak risk and a potentially misleading assertion message, and one info item about a style inconsistency.

---

## Warnings

### WR-01: Sentinel process leaked when TST-01 sub-assertion fails

**File:** `tests/hooks/test-session-log-init.sh:252`

**Issue:** The `kill "$_sentinel_pid"` call at line 252 is inside the outer `if [[ -f "${SB_TEST_DIR}/sentinel-pid" ]]` block but is executed unconditionally only after the TST-01 inner `if/else` block ends (lines 245–251). However, the `kill` is not reached at all if the outer `if` branch is skipped (sentinel-pid file absent). More importantly: the sentinel was launched with `SENTINEL_SLEEP_OVERRIDE=3600` (line 235), meaning it will sleep for one hour. If the inner TST-01 assertion at line 245 fails (e.g., because `uuidgen` is unavailable and the fallback UUID happens to equal `_sentinel_pid`, or because the lock file is missing), the `else` branch increments `FAIL` and the code continues to line 252 where the kill does execute. So the kill path itself is safe for the failure case.

The real leak scenario is subtler: the `rm -f ... "sentinel-lock-"*` glob on line 255 uses a bare glob that expands in the caller's shell context. If `nullglob` is not set and no `sentinel-lock-*` files exist (e.g., because the lock file was already cleaned up by the hook's own unconditional cleanup at line 88 of `session-log-init.sh`), the rm receives a literal `"${SB_TEST_DIR}/sentinel-lock-"*` token and attempts to remove a file with that exact name — it will fail silently (because `rm -f` ignores missing files), which is safe. This is not a leak, but the following IS:

If `touch "$SB_DIR/sentinel-lock-$_uuid"` fails inside the hook (line 143 of `session-log-init.sh`), the hook kills the sentinel and does NOT write `sentinel-pid`. In that case the outer `if [[ -f "${SB_TEST_DIR}/sentinel-pid" ]]` is false, the test falls into the `else` branch (line 256), increments `FAIL`, and **never kills the background sentinel process**. The sentinel was disowned by the hook only on the success path (line 145); on the failure path the hook kills it (line 147). So this scenario is actually safe — the hook handles its own cleanup. No actual leak is possible from the test code itself.

However, the ordering of the `kill` relative to the lock-file assertion is semantically backwards and will cause a spurious test failure on any system where killing the sentinel also causes cleanup of the lock file (unlikely but theoretically possible if the sentinel script removes its own lock on exit). The kill should be moved to after the lock-file assertion completes.

**Fix:** Move the `kill` and `rm -f` block to after the inner if/else, so the lock file is asserted before the process is terminated:

```bash
_sentinel_contents=$(cat "${SB_TEST_DIR}/sentinel-pid" 2>/dev/null || true)
_sentinel_pid="${_sentinel_contents%%:*}"
_sentinel_uuid="${_sentinel_contents#*:}"
# TST-01: assert sentinel-lock-<uuid> file is also created
if [[ -n "$_sentinel_uuid" && "$_sentinel_uuid" != "$_sentinel_pid" && -f "${SB_TEST_DIR}/sentinel-lock-${_sentinel_uuid}" ]]; then
  echo "  ✅ autonomous mode creates sentinel-lock-<uuid> file"
  PASS=$((PASS + 1))
else
  echo "  ❌ expected sentinel-lock-<uuid> file not found (uuid=${_sentinel_uuid})"
  FAIL=$((FAIL + 1))
fi
# Kill and clean up AFTER assertions are complete
[[ -n "$_sentinel_pid" ]] && kill "$_sentinel_pid" 2>/dev/null || true
rm -f "${SB_TEST_DIR}/sentinel-pid" "${SB_TEST_DIR}/timeout" \
      "${SB_TEST_DIR}/session-start-time" "${SB_TEST_DIR}/timeout-warn-count" \
      "${SB_TEST_DIR}/sentinel-lock-"*
```

The current code happens to be correct in practice (the sentinel sleep process does not delete its own lock file), but this ordering is fragile and should be fixed.

---

### WR-02: Test 17h uses tilde `~` which is not expanded in the hook's regex context

**File:** `tests/hooks/test-dev-cycle-check.sh:338`

**Issue:** Test 17h passes the command string `echo 'x' | tee "~/.claude/.silver-bullet/state"` to `run_hook_bash`. The tilde `~` is inside double quotes in the outer shell invocation at line 337:

```bash
out=$(run_hook_bash "PreToolUse" "echo 'x' | tee \"~/.claude/.silver-bullet/state\"")
```

Inside double quotes, `~` is NOT expanded by bash. The literal string `~/.claude/.silver-bullet/state` is passed to the hook. The hook's `_state_redirect_dquote` pattern is:

```
(>>|[[:space:]]>[^>&=]|\btee\b)[^"]*"[^"]*\.claude/[^/]+/state
```

This pattern matches `~/.claude/.silver-bullet/state` because it doesn't require `$HOME` — it only checks for `\.claude/`. So the veto fires and the test passes correctly.

However, in a real Claude session, the command would contain the expanded `$HOME` path (e.g., `/Users/alice/.claude/.silver-bullet/state`) because the shell expands `~` before passing it to the hook. Tests 17e and 17f use the unexpanded `~` form and pass for the same reason. This inconsistency means the tests exercise the hook's regex against `~`-prefixed paths but not against fully-expanded `$HOME` paths. If someone refactored the hook's patterns to only match absolute paths (e.g., adding a `^/` anchor), tests 17g and 17h would still pass (against `~`) while the real use-case (absolute path) would silently regress.

**Fix:** Add a parallel assertion using the expanded path to verify coverage of real-session behavior:

```bash
# Test 17g-expanded: same assertion with $HOME-expanded path
setup
out=$(run_hook_bash "PreToolUse" "echo \"path is ${HOME}/.claude/.silver-bullet/state\"")
assert_passes "tamper: state path (expanded) in quoted echo argument is NOT blocked (quote-literal exemption)" "$out"
teardown

# Test 17h-expanded: tee with expanded quoted state path IS still blocked
setup
out=$(run_hook_bash "PreToolUse" "echo 'x' | tee \"${HOME}/.claude/.silver-bullet/state\"")
assert_blocks "tamper: tee with expanded quoted state path is still blocked" "$out"
teardown
```

---

## Info

### IN-01: TST-01 error message reveals internal UUID variable name

**File:** `tests/hooks/test-session-log-init.sh:249`

**Issue:** The failure message `"❌ expected sentinel-lock-<uuid> file not found (uuid=${_sentinel_uuid})"` exposes the raw value of `_sentinel_uuid`. If the sentinel-pid file has the legacy format (no colon), `_sentinel_uuid` equals `_sentinel_pid` (the PID), and the failure message reads `uuid=12345` — which could be confused with a PID. The condition guard `"$_sentinel_uuid" != "$_sentinel_pid"` correctly fails the assertion in this case, but the diagnostic output will print a misleading `uuid=<pid>`.

**Fix:** Add a clearer diagnostic that distinguishes the "no UUID in pid file" case from the "lock file missing" case:

```bash
if [[ -z "$_sentinel_uuid" || "$_sentinel_uuid" == "$_sentinel_pid" ]]; then
  echo "  ❌ sentinel-pid file has no UUID token (legacy format or write failed)"
  FAIL=$((FAIL + 1))
elif [[ ! -f "${SB_TEST_DIR}/sentinel-lock-${_sentinel_uuid}" ]]; then
  echo "  ❌ expected sentinel-lock-<uuid> file not found (uuid=${_sentinel_uuid})"
  FAIL=$((FAIL + 1))
else
  echo "  ✅ autonomous mode creates sentinel-lock-<uuid> file"
  PASS=$((PASS + 1))
fi
```

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

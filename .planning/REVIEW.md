---
phase: code-review
reviewed: 2026-05-01T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - hooks/stop-check.sh
  - hooks/planning-file-guard.sh
  - hooks/ci-status-check.sh
  - hooks/hooks.json
  - tests/hooks/test-planning-file-guard.sh
  - tests/hooks/test-ci-status-check.sh
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Code Review Report

**Reviewed:** 2026-05-01T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed three hook scripts (`stop-check.sh`, `planning-file-guard.sh`, `ci-status-check.sh`), the hooks manifest (`hooks.json`), and two new test files. The hooks follow established SB patterns (ERR trap, umask, jq guard, fail-open). One critical enforcement-bypass defect was found in `stop-check.sh` where invalid user-supplied regex patterns in `transient_path_ignore_patterns` are silently accepted by the validator, then cause awk to fail, which makes the dirty-tree check incorrectly report a clean tree and exit the Stop hook without enforcing required skills. Additionally: a test correctness defect where the ci-status-check trivial-bypass test silently exercises the deprecated backward-compat path rather than the real bypass path; a silent failure mode in the CI-fix Option A bypass for branches without an upstream; and a path-traversal gap in planning-file-guard when python3 is absent.

---

## Critical Issues

### CR-01: Invalid `transient_path_ignore_patterns` regex silently bypasses Stop-hook enforcement

**File:** `hooks/stop-check.sh:177`

**Issue:** The validator at line 177 is intended to reject patterns that match the empty string (e.g. `.*`). It tests `printf '\n' | grep -qE "$sb_extra"`: a pattern that matches an empty line is rejected, anything else is accepted. However, `grep` also exits non-zero (exit code 2) when the regex itself is syntactically invalid — and `if` treats all non-zero exits as false. This means a syntactically invalid pattern like `tmp/|` (trailing pipe = empty alternation) is silently accepted by the validator.

When the invalid pattern is appended to `sb_transient_re`, the awk invocation at line 188 receives a malformed combined regex. On macOS/BSD awk this causes awk to exit with code 2 (printing nothing to stdout). Because the pipeline uses `|| true` is absent here, but `set -euo pipefail` + ERR trap or the subshell means `filtered` is set to empty string. `[[ -z "$filtered" ]]` then sets `tree_clean=true` unconditionally — the hook exits 0 as if the working tree were clean, bypassing required-skills enforcement entirely.

A `.silver-bullet.json` with any syntactically invalid ERE in `transient_path_ignore_patterns` triggers this bypass. The defect is in the validator's failure to distinguish between "pattern does not match empty string" (exit 1, accept) and "pattern is invalid regex" (exit 2, must reject).

**Verified by:**
```bash
printf '\n' | grep -qE 'tmp/|' 2>/dev/null; echo $?   # 2 (error, not rejection)
# Combined regex passed to awk: (\.claude/...|REVIEW\.md|tmp/|)
echo 'test' | awk -v re='(\.claude/|REVIEW\.md|tmp/|)' '{if($0 !~ re) print}'
# awk: illegal primary in regular expression — exits 2, prints nothing
# filtered='' -> tree_clean=true -> exit 0 (enforcement bypassed)
```

**Fix:** Check the grep exit code explicitly to distinguish no-match (1) from invalid-regex (2):

```bash
if printf '\n' | grep -qE "$sb_extra" 2>/dev/null; then
  # pattern matches empty string — too broad, reject
  printf '{"hookSpecificOutput":{"message":"⚠️ stop-check: transient_path_ignore_patterns is too broad (matches empty path) — ignoring. Fix your .silver-bullet.json."}}'
else
  _grep_rc=$?
  if (( _grep_rc >= 2 )); then
    # grep error = invalid regex — reject rather than silently accept
    printf '{"hookSpecificOutput":{"message":"⚠️ stop-check: transient_path_ignore_patterns contains invalid regex — ignoring. Fix your .silver-bullet.json."}}'
  else
    sb_transient_re="(${sb_transient_re#(}"
    sb_transient_re="${sb_transient_re%)}|${sb_extra})"
  fi
fi
```

Note: the `if/else` structure must be restructured because `$?` is consumed by the `if` itself. Use a separate variable:

```bash
_grep_rc=0
printf '\n' | grep -qE "$sb_extra" 2>/dev/null || _grep_rc=$?
if (( _grep_rc == 0 )); then
  printf '{"hookSpecificOutput":{"message":"⚠️ stop-check: transient_path_ignore_patterns is too broad (matches empty path) — ignoring. Fix your .silver-bullet.json."}}'
elif (( _grep_rc >= 2 )); then
  printf '{"hookSpecificOutput":{"message":"⚠️ stop-check: transient_path_ignore_patterns contains invalid regex — ignoring. Fix your .silver-bullet.json."}}'
else
  sb_transient_re="(${sb_transient_re#(}"
  sb_transient_re="${sb_transient_re%)}|${sb_extra})"
fi
```

---

## Warnings

### WR-01: Test 5 (trivial bypass) silently exercises deprecated backward-compat path, not the real bypass

**File:** `tests/hooks/test-ci-status-check.sh:116`

**Issue:** `setup()` (line 17) writes a `.silver-bullet.json` with `state.trivial_file` pointing to `${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}` (the test-scoped path). The hook resolves this into `_bypass_trivial` (lines 76-78 of `ci-status-check.sh`) and calls `sb_trivial_bypass "$_bypass_trivial"`. Test 5 touches `$TRIVIAL_FILE` which is `${SB_TEST_DIR}/trivial` (the hardcoded default, defined at line 12 of the test file) — not the test-scoped path from config.

The hook never reaches `sb_trivial_bypass` via the config-driven path. Instead it hits the backward-compat block at lines 86-89 of `ci-status-check.sh` (which hard-checks the default `trivial` path), emits the deprecation warning, and exits 0. The test passes for the wrong reason: the actual `sb_trivial_bypass "$_bypass_trivial"` call is never exercised by Test 5, so a regression in that path would go undetected.

Test 8 independently and intentionally validates this same deprecated path, making Test 5 a duplicate of Test 8 in practice.

**Fix:** Touch the test-scoped trivial path that matches what the config points to:

```bash
# Test 5 — trivial bypass suppresses CI check
setup
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"   # matches config-driven _bypass_trivial
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_passes "trivial bypass suppresses CI check" "$out"
teardown
```

### WR-02: CI-fix Option A bypass silently fails for branches without a configured upstream

**File:** `hooks/ci-status-check.sh:137`

**Issue:** Option A checks:

```bash
if git rev-parse "@{u}" >/dev/null 2>&1; then
  _changed=$(git diff "@{u}..HEAD" --name-only 2>/dev/null || true)
  ...
fi
```

On a freshly-created local branch with no upstream configured, `git rev-parse "@{u}"` fails — the inner `if` body is skipped entirely. `_changed` remains empty. No message is emitted. The developer sees only the standard CI-red block with the instruction "Ensure your diff touches .github/workflows/, tests/, or package.json" — which they may already have done. They have no indication that Option A silently did not run. Only Option B (commit message prefix) works in this scenario, and the block message does not prioritize it.

This is reproducible in Group 8 tests: `setup_git` initialises a repo with `git init` but no remote, so `@{u}` is always undefined in all Group 8 test cases. Option A is never exercised by the test suite.

**Fix (option 1):** Fall back to `origin/HEAD` when `@{u}` is unavailable:

```bash
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  _diff_base="@{u}"
elif git rev-parse --verify origin/HEAD >/dev/null 2>&1; then
  _diff_base="origin/HEAD"
fi
if [[ -n "${_diff_base:-}" ]]; then
  _changed=$(git diff "${_diff_base}..HEAD" --name-only 2>/dev/null || true)
  ...
fi
```

**Fix (option 2):** Emit an informational note when `@{u}` is unavailable so the developer knows to use the commit-message convention:

```bash
if git rev-parse "@{u}" >/dev/null 2>&1; then
  _changed=$(git diff "@{u}..HEAD" --name-only 2>/dev/null || true)
  ...
else
  printf '{"hookSpecificOutput":{"message":"ℹ️ No upstream configured — Option A (diff-based) ci-fix bypass unavailable. Use commit prefix fix(ci): or ci: instead."}}'
fi
```

### WR-03: `planning-file-guard.sh` path traversal bypass when python3 is absent

**File:** `hooks/planning-file-guard.sh:29-31`

**Issue:** The hook canonicalizes `file_path` via python3's `os.path.normpath` to prevent traversal bypasses such as `.planning/sub/../ROADMAP.md`. The fallback when python3 is unavailable (line 29, `|| printf '%s' "$file_path"`) returns the raw, un-normalized path. `dirname` on `.planning/sub/../ROADMAP.md` yields `.planning/sub/..`, and `basename` of that is `..`, not `.planning`. The guard at line 31 (`[[ "$dir_basename" != ".planning" ]] && exit 0`) then passes without blocking — a protected planning file is silently left unguarded.

python3 is the only non-Bash dependency introduced by this hook and is not listed in the project's documented prerequisites (`jq` only). macOS ships python3 via Xcode Command Line Tools, so the fallback is low-probability but not impossible in minimal CI environments or stripped containers.

**Fix:** Replace the python3 call with a pure-Bash normpath using `realpath -m` (available on macOS via GNU coreutils) or a manual `..`-collapse loop that avoids the undeclared dependency:

```bash
# Pure-bash option: use realpath -m (resolves .. without requiring the path to exist)
_norm_path=$(realpath -m "$file_path" 2>/dev/null || printf '%s' "$file_path")
```

If `realpath` is also unavailable, the current fallback is correct to use the raw path but should emit a warning rather than silently degrading, so an operator knows the guard is weakened:

```bash
_norm_path=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$file_path" 2>/dev/null \
  || realpath -m "$file_path" 2>/dev/null \
  || { printf '{"hookSpecificOutput":{"message":"⚠️ planning-file-guard: cannot canonicalize path (python3/realpath unavailable) — traversal protection degraded"}}\n'; printf '%s' "$file_path"; })
```

---

## Info

### IN-01: `hooks.json` — `planning-file-guard.sh` matcher omits `MultiEdit`

**File:** `hooks/hooks.json:51-59`

**Issue:** The new entry uses matcher `"Edit|Write|MultiEdit"` — wait, actually it uses `"Edit|Write"` (line 52). The existing `dev-cycle-check.sh` (line 107) and `phase-lock-claim.sh` (line 139) entries both use `"Edit|Write|MultiEdit"`. If Claude Code invokes `MultiEdit` on a protected planning file (e.g., `ROADMAP.md`), `planning-file-guard.sh` is not triggered and the edit proceeds unguarded.

Note: verify that `MultiEdit` uses `file_path` in its `tool_input` (same as `Edit` and `Write`) before adding the matcher — `planning-file-guard.sh` line 24 reads `.tool_input.file_path` and would need updating if `MultiEdit` uses a different field (e.g. `.tool_input.edits[].file_path`).

**Fix:**

```json
{
  "matcher": "Edit|Write|MultiEdit",
  "hooks": [
    {
      "type": "command",
      "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/planning-file-guard.sh\"",
      "async": false,
      "timeout": 10
    }
  ]
}
```

---

_Reviewed: 2026-05-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

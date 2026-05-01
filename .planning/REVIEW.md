---
phase: code-review
reviewed: 2026-05-01T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - hooks/ci-status-check.sh
  - hooks/hooks.json
  - hooks/planning-file-guard.sh
  - hooks/stop-check.sh
  - tests/hooks/test-ci-status-check.sh
  - tests/hooks/test-planning-file-guard.sh
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Code Review Report

**Reviewed:** 2026-05-01
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed three hook scripts (`ci-status-check.sh`, `planning-file-guard.sh`, `stop-check.sh`), the hooks manifest (`hooks.json`), and two new test files. The hooks follow established SB patterns (ERR trap, umask, jq guard, fail-open). One critical security logic defect was found in `stop-check.sh` where the validation meant to reject overly-broad `transient_path_ignore_patterns` is structurally broken. Additionally: a test correctness issue where the trivial-bypass test for `ci-status-check` exercises the deprecated backward-compat path rather than the real bypass, a silent failure mode in the CI-fix Option A bypass for branches without an upstream, and a missing `MultiEdit` matcher in `hooks.json` for `planning-file-guard.sh`.

---

## Critical Issues

### CR-01: `transient_path_ignore_patterns` empty-string validation always passes — `.*` is not rejected

**File:** `hooks/stop-check.sh:177`

**Issue:** The guard intended to reject overly-broad patterns uses `printf ''` which emits **zero bytes** — no newline, no content. `grep` receives an empty stream with no lines, so it finds no match regardless of the regex. Concretely: `printf '' | grep -qE '.*'` returns exit code 1. This means every user-supplied pattern passes validation, including `.*`, `.*\.md`, and any other pattern that matches empty string.

When such a pattern is appended to `sb_transient_re`, the awk filter at line 188 drops every porcelain line, forcing `tree_clean=true` unconditionally. The entire HOOK-14 tree-dirty check is silently neutralized and the Stop hook exits 0 instead of enforcing required skills. A malicious or misconfigured `.silver-bullet.json` with `"transient_path_ignore_patterns": [".*"]` completely disables stop-check enforcement.

**Fix:** Feed `grep` an actual empty line so it has a line to test against:

```bash
# Before (broken — zero input lines, grep always returns exit 1):
if printf '' | grep -qE "$sb_extra" 2>/dev/null; then

# After (correct — one empty line gives grep a line to match against):
if printf '\n' | grep -qE "$sb_extra" 2>/dev/null; then
```

---

## Warnings

### WR-01: Test 5 (trivial bypass) silently exercises deprecated backward-compat path, not the real bypass

**File:** `tests/hooks/test-ci-status-check.sh:116`

**Issue:** `setup()` (line 17) writes a `.silver-bullet.json` with `state.trivial_file` pointing to `${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}` (the test-scoped path). The hook resolves this into `_bypass_trivial` (lines 76-78 of `ci-status-check.sh`) and passes it to `sb_trivial_bypass "$_bypass_trivial"`. Test 5 touches `$TRIVIAL_FILE` which is `${SB_TEST_DIR}/trivial` (the hardcoded default, defined at line 12 of the test file) — not the test-scoped path from config.

The hook never reaches `sb_trivial_bypass` via the config-driven path. Instead it hits the backward-compat block at lines 86-89 (which hard-checks the default `trivial` path), emits the deprecation warning, and exits 0. The test passes for the wrong reason. The actual `sb_trivial_bypass "$_bypass_trivial"` call is never exercised by Test 5, meaning a regression in that code path would go undetected.

Test 8 independently and intentionally tests this same deprecated path, making Test 5 a duplicate of Test 8 in practice.

**Fix:** Touch the test-scoped path that matches the config:

```bash
# Test 5 — trivial bypass suppresses CI check
setup
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"   # matches config-driven _bypass_trivial
out=$(run_hook "git commit -m test" '{"status":"completed","conclusion":"failure"}')
assert_passes "trivial bypass suppresses CI check" "$out"
teardown
```

### WR-02: CI-fix Option A bypass silently fails for branches with no upstream configured

**File:** `hooks/ci-status-check.sh:137`

**Issue:** Option A runs:

```bash
_changed=$(git diff "@{u}..HEAD" --name-only 2>/dev/null || true)
```

`@{u}` resolves the upstream tracking ref. On a freshly-created local branch with no upstream configured, `@{u}` is undefined — `git diff` fails, `|| true` absorbs the error, and `_changed` is empty. The `[[ -n "$_changed" ]]` guard then skips Option A entirely with no message. The developer sees the standard CI-red block with no indication that the bypass was attempted and silently failed. This is especially surprising because the escape-hatch instructions in the block message say "Ensure your diff touches .github/workflows/, tests/, or package.json" — which the developer may already have done.

**Fix:** Emit an informational message when `@{u}` is unavailable, or fall back to `origin/HEAD`:

```bash
_upstream_ref="@{u}"
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  _upstream_ref="origin/HEAD"
fi
_changed=$(git diff "${_upstream_ref}..HEAD" --name-only 2>/dev/null || true)
```

### WR-03: `planning-file-guard.sh` does not canonicalize paths — trailing `..` segment bypasses the guard

**File:** `hooks/planning-file-guard.sh:28-29`

**Issue:** The guard checks whether the immediate parent directory of the target file is named `.planning`:

```bash
dir_basename=$(basename "$(dirname "$file_path")")
[[ "$dir_basename" != ".planning" ]] && exit 0
```

`dirname` and `basename` operate on the string lexically without resolving `..`. A path like `/project/.planning/subdir/../ROADMAP.md` has `dirname` returning `/project/.planning/subdir/..` and `basename` of that returning `..`. The `[[ "$dir_basename" != ".planning" ]]` check exits 0 (unguarded), even though the path resolves to the protected `.planning/ROADMAP.md`. Since this is a security-enforcement hook, the absence of canonicalization is a correctness gap.

**Fix:** Canonicalize the path before extraction. `realpath -m` resolves `..` components without requiring the file to exist:

```bash
canonical_path=$(realpath -m "$file_path" 2>/dev/null || printf '%s' "$file_path")
dir_basename=$(basename "$(dirname "$canonical_path")")
basename_path=$(basename "$canonical_path")
```

---

## Info

### IN-01: `hooks.json` — `planning-file-guard.sh` matcher omits `MultiEdit`

**File:** `hooks/hooks.json:51-59`

**Issue:** The new entry uses matcher `"Edit|Write"`. The existing `dev-cycle-check.sh` and `phase-lock-claim.sh` entries both use `"Edit|Write|MultiEdit"`. If Claude Code invokes `MultiEdit` on a protected planning file (e.g. `ROADMAP.md`), `planning-file-guard.sh` is not triggered and the edit proceeds unguarded. `MultiEdit` applies multiple edits to a file in one tool call and is a plausible path for bulk-editing planning artifacts.

Note: verify that `MultiEdit` uses `file_path` in its `tool_input` (same as `Edit` and `Write`) before adding the matcher — the guard at line 24 of `planning-file-guard.sh` reads `.tool_input.file_path`.

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

_Reviewed: 2026-05-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

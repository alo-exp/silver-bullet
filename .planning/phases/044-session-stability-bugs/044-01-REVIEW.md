---
phase: 044-session-stability-bugs
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
  critical: 2
  warning: 3
  info: 4
  total: 9
status: issues_found
---

# Phase 044: Code Review Report

**Reviewed:** 2026-05-01T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase delivers three enforcement-gap fixes: `stop-check.sh` tightens the transient-path ignore-pattern validation (issue #90), `planning-file-guard.sh` is a new hook blocking direct edits to GSD-managed planning artifacts (issue #93), and `ci-status-check.sh` adds a `git rev-parse "@{u}"` guard before the Option A path-diff CI-fix bypass (issue #95). `hooks.json` extends the planning-file-guard matcher to include `MultiEdit`.

Two blockers were found. The CR-01 fix for issue #90 is incomplete: `printf '\n' | grep -qE ".*"` returns exit 1, so `.*` (and any pattern using `*`-quantifiers) passes validation and can silently nullify all stop-check enforcement. Separately, the override-file test in `test-planning-file-guard.sh` creates the live `~/.claude/.silver-bullet/planning-edit-override` file without crash-safe cleanup, which can disable the planning-file-guard in real sessions if the test is interrupted.

---

## Critical Issues

### CR-01: `stop-check.sh` transient-pattern validation does not catch `.*` — enforcement fully bypassable

**File:** `hooks/stop-check.sh:177`

**Issue:** The issue #90 fix validates user-supplied `transient_path_ignore_patterns` with:
```bash
if printf '\n' | grep -qE "$sb_extra" 2>/dev/null; then
  # warn and discard the pattern
```
The intent is to reject patterns that match an empty path. However `grep -qE ".*"` returns exit 1 against an empty line (verified on both macOS and Linux grep). A value of `[".*"]` in `.silver-bullet.json` passes the validator, is combined into the awk regex, and causes awk to match — and therefore suppress — every porcelain line. `filtered` becomes empty, `tree_clean` is set to `true`, and stop-check skips enforcement silently.

End-to-end verification:
```bash
# Validation check (what stop-check.sh does):
printf '\n' | grep -qE ".*"; echo $?    # → 1 (not caught)

# Effect in awk filter with .* as sb_extra:
printf ' M .planning/STATE.md\n?? src/main.py\n' \
  | awk -v re='(REVIEW\.md|.*)' '{ path=substr($0,4); if (path !~ re) print }'
# → empty output → tree_clean=true → stop-check exits 0, enforcement bypassed
```

This requires deliberate misconfiguration of `.silver-bullet.json` (or a supply-chain attack on that file), but the impact is total silent enforcement bypass.

**Fix:** Test the pattern against a representative non-empty single-character input instead of an empty line:
```bash
# Replace line 177:
if printf 'x' | grep -qE "$sb_extra" 2>/dev/null; then
```
`printf 'x'` means: any pattern that matches `x` (including `.*`, `.+`, `x`, `.`, `x*`, `[a-z]`) is caught as too-broad. Legitimate path-fragment patterns (e.g. `\.superpowers/`, `REVIEW\.md`) do not match the single char `x` and pass through correctly.

---

### CR-02: `test-planning-file-guard.sh` override test creates live file without crash-safe cleanup

**File:** `tests/hooks/test-planning-file-guard.sh:12-16, 123-126`

**Issue:** `OVERRIDE_FILE` is defined at line 12 as a test-scoped path with a PID suffix (`planning-edit-override-test-${TEST_RUN_ID}`). The `cleanup_all` EXIT trap removes `$OVERRIDE_FILE`. However the actual test at line 123 creates a *different*, non-suffixed file — the real live path the hook checks:
```bash
touch "${SB_TEST_DIR}/planning-edit-override"   # real hook path, no PID suffix
out=$(run_hook_edit ...)
assert_passes ...
rm -f "${SB_TEST_DIR}/planning-edit-override"   # line 126 — only runs if no crash
```
The EXIT trap never removes this file. If the test is killed between lines 123 and 126, `~/.claude/.silver-bullet/planning-edit-override` is left behind. Any subsequent Silver Bullet session will silently allow direct edits to all protected planning files (ROADMAP.md, STATE.md, etc.) until the file is manually removed.

`$OVERRIDE_FILE` with the PID-suffix is also never actually written to or used in a test — it is dead code.

**Fix:** Change `OVERRIDE_FILE` to use the real hook path so the EXIT trap covers it, and update the test to use the variable:
```bash
# Line 12: use the actual path the hook checks
OVERRIDE_FILE="${SB_TEST_DIR}/planning-edit-override"

# cleanup_all already removes $OVERRIDE_FILE — no change needed there.

# Line 123: use the variable
touch "$OVERRIDE_FILE"
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_passes "planning-edit-override file allows protected file edit" "$out"
rm -f "$OVERRIDE_FILE"   # line 126: optional now since EXIT trap covers it
```

---

## Warnings

### WR-01: `planning-file-guard.sh` bypass messages build JSON with unescaped `printf`

**File:** `hooks/planning-file-guard.sh:65, 72`

**Issue:** The two early-exit bypass paths inject `$basename_path` directly into a JSON string literal via `printf` without JSON-escaping:
```bash
printf '{"hookSpecificOutput":{"message":"⚠️  planning-file-guard: ... %s ..."}}\n' "$basename_path"
```
The protected-file `case` includes `v*-MILESTONE-*.md`, a glob that matches filenames containing JSON-special characters. A filename like `v1-MILESTONE-"injected"}.md` produces malformed JSON, breaking Claude Code's hook output parsing.

The blocking path (line 122) correctly uses `jq -Rs '.'` for escaping — the bypass paths should too.

**Fix:**
```bash
# Replace lines 65 and 72 pattern with jq-escaped output:
_msg="⚠️  planning-file-guard: SB_ALLOW_PLANNING_EDITS=1 — allowing direct edit to ${basename_path}. Prefer the owning GSD skill."
printf '{"hookSpecificOutput":{"message":%s}}\n' "$(printf '%s' "$_msg" | jq -Rs '.')"
```

---

### WR-02: `planning-file-guard.sh` `trivial_file` path lacks `~/.claude/` prefix validation

**File:** `hooks/planning-file-guard.sh:79-85`

**Issue:** After reading `state.trivial_file` from the project config and expanding `~`, the hook passes the value directly to `sb_trivial_bypass` with no path safety check. `stop-check.sh` applies an explicit guard (lines 88-93):
```bash
case "$trivial_file" in
  "$HOME"/.claude/*) ;;
  *) trivial_file="${SB_STATE_DIR}/trivial" ;;
esac
```
Without this guard, a `.silver-bullet.json` with `"state": {"trivial_file": "/tmp/always-present"}` causes `planning-file-guard.sh` to permanently allow all protected file edits for any session where `/tmp/always-present` exists.

**Fix:** Add path validation after line 80:
```bash
# Security: validate trivial path stays within ~/.claude/ (mirrors stop-check.sh SB-002)
case "$_trivial_file" in
  "$HOME"/.claude/*) ;;
  *) _trivial_file="${HOME}/.claude/.silver-bullet/trivial" ;;
esac
```

---

### WR-03: Option A of CI-fix bypass in `ci-status-check.sh` has zero test coverage

**File:** `tests/hooks/test-ci-status-check.sh` (entire Group 8)

**Issue:** The issue #95 fix adds two bypass paths. Option B (commit message convention: `fix(ci):`, `ci:`, `[ci-fix]`) has 5 tests. Option A (diff touches `.github/workflows/`, `tests/`, or `package.json`) has no test at all.

The `setup_git` function at line 197 creates a local git repo but never sets an upstream via `git push -u origin`. Because `git rev-parse "@{u}"` fails in this repo, the `if git rev-parse "@{u}" >/dev/null 2>&1` guard at `ci-status-check.sh:137` is never true, and Option A code is never executed during tests. The `@{u}` guard itself (the core of the issue #95 fix) is therefore unexercised by the test suite.

**Fix:** Add a Group 8b test using a bare-repo upstream:
```bash
setup_git_with_upstream() {
  TMPDIR_TEST=$(mktemp -d)
  cat > "${TMPDIR_TEST}/.silver-bullet.json" << 'EOF'
{ "project": {}, "state": {} }
EOF
  local bare; bare=$(mktemp -d)
  ( cd "$TMPDIR_TEST" \
    && git init -q && git config user.email "t@t" && git config user.name "T" \
    && touch dummy && git add dummy && git commit -q -m "init" \
    && git remote add origin "$bare" \
    && git push -q -u origin HEAD:main 2>/dev/null || true )
}
# Then commit a change to .github/workflows/ci.yml and assert push allowed despite red CI
```

---

## Info

### IN-01: Stale comment in `planning-file-guard.sh` — says `Edit|Write`, hook is registered as `Edit|Write|MultiEdit`

**File:** `hooks/planning-file-guard.sh:5, 23`

Line 5: `# PreToolUse hook (matcher: Edit|Write)` should read `Edit|Write|MultiEdit`.
Line 23: `# Extract file path from tool input (Edit and Write both use file_path)` should include MultiEdit.

**Fix:**
```bash
# PreToolUse hook (matcher: Edit|Write|MultiEdit)
# Extract file path from tool input (Edit, Write, and MultiEdit all use file_path)
```

---

### IN-02: `test-planning-file-guard.sh` has no `MultiEdit` tool type test

**File:** `tests/hooks/test-planning-file-guard.sh`

After extending the matcher to include `MultiEdit`, no test exercises the hook with `{"tool_name":"MultiEdit","tool_input":{"file_path":"..."}}`. If a future Claude Code release changes how MultiEdit passes the file path (e.g. moving to `tool_input.edits[0].file_path`), the hook silently stops blocking MultiEdit on protected files with no test failure.

**Fix:** Add a `run_hook_multiedit` helper and a corresponding test group:
```bash
run_hook_multiedit() {
  local file_path="$1"
  local input
  input=$(printf '{"tool_name":"MultiEdit","tool_input":{"file_path":"%s","edits":[]}}' "$file_path")
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}
# Group 5:
setup
out=$(run_hook_multiedit "${TMPDIR_TEST}/.planning/ROADMAP.md")
assert_blocks "blocks MultiEdit on .planning/ROADMAP.md" "$out"
teardown
```

---

### IN-03: `test-planning-file-guard.sh` has no test for path traversal bypass prevention

**File:** `tests/hooks/test-planning-file-guard.sh`

The `python3 normpath` canonicalization at `planning-file-guard.sh:29` defends against traversal bypass (e.g. `.planning/sub/../ROADMAP.md → .planning/ROADMAP.md`). This defense exists and works correctly. However there is no test covering it — a future refactor that replaces `normpath` with a naive `basename` on the raw path would silently remove the protection.

**Fix:**
```bash
setup
out=$(run_hook_edit "${TMPDIR_TEST}/.planning/phases/01/../ROADMAP.md")
assert_blocks "path traversal .planning/phases/01/../ROADMAP.md is blocked" "$out"
teardown
```

---

### IN-04: `stop-check.sh` line 180 is dead code (no-op re-assignment)

**File:** `hooks/stop-check.sh:180`

```bash
sb_transient_re="(${sb_transient_re#(}"   # line 180 — strips leading ( then re-adds it; no-op
sb_transient_re="${sb_transient_re%)}|${sb_extra})"  # line 181 — does the actual work
```

Line 180 strips the leading `(` via `${sb_transient_re#(}` and immediately prepends `"("` again, leaving the value unchanged. Only line 181 performs useful work. The dead assignment adds confusion but produces a correct final result.

**Fix:** Remove line 180:
```bash
# Delete this line:
# sb_transient_re="(${sb_transient_re#(}"
# Keep only:
sb_transient_re="${sb_transient_re%)}|${sb_extra})"
```

---

_Reviewed: 2026-05-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

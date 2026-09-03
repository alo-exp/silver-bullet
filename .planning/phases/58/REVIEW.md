---
phase: 58-layer-a-review
reviewed: 2026-04-25T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - .github/workflows/ci.yml
  - docs/internal/pre-release-quality-gate.md
  - hooks/dev-cycle-check.sh
  - hooks/session-log-init.sh
  - hooks/timeout-check.sh
  - silver-bullet.md
  - skills/silver-add/SKILL.md
  - skills/silver-create-release/SKILL.md
  - skills/silver-release/SKILL.md
  - skills/silver-rem/SKILL.md
  - skills/silver-remove/SKILL.md
  - skills/silver-scan/SKILL.md
  - templates/silver-bullet.md.base
  - tests/hooks/test-timeout-check.sh
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 58: Code Review Report (Layer A — v0.26.0 RC)

**Reviewed:** 2026-04-25
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

This is the Layer A code review for the Silver Bullet v0.26.0 release candidate, covering changes from four phases: Phase 55 (BUG-01/02/05), Phase 56 (BUG-03/04 + QUAL-01/02), Phase 57 (CI-01/02), and Phase 58 (QUAL-03/04).

The overall quality is high. The hook fixes (timeout-check.sh state file isolation, dev-cycle-check.sh tamper regex, session-log-init.sh UUID token approach) are well-implemented with appropriate tests. The CI hardening additions are correct. The skill fixes are generally solid.

Four warnings and five info items were found. No critical issues. The most significant finding (WR-01) is a stale Allowed Commands declaration in `skills/silver-remove/SKILL.md` that still lists `sed -i ''` as a permitted command, contradicting the actual portability fix applied in the implementation body. This creates a documentation-vs-implementation inconsistency that could cause a future reviewer to implement a fallback using the non-portable form.

---

## Warnings

### WR-01: silver-remove Allowed Commands lists `sed -i ''` but implementation uses tmpfile+mv

**File:** `skills/silver-remove/SKILL.md:34`
**Issue:** The "Allowed Commands" section still lists `sed -i ''` (BSD sed, macOS) as a permitted command. The QUAL-01 fix correctly replaced the `sed -i ''` implementation in Step 5d with the portable `sed ... > "$TMP" && mv "$TMP" "$TARGET_FILE"` tmpfile+mv pattern. However, the Allowed Commands whitelist was not updated to remove `sed -i ''` and add `mktemp`, `mv`. The comment in Step 5d even explicitly notes "The tmpfile+mv pattern is used instead of `sed -i ''`", making the Allowed Commands list contradictory. A future agent following the Allowed Commands whitelist could revert to `sed -i ''` as an apparently sanctioned approach.
**Fix:** Remove `sed -i ''` from the Allowed Commands list and add `mktemp`, `mv` (with note: already listed but confirm inclusion). Update the entry to:
```
- `sed` — heading pattern matching (output redirected to tmpfile, never in-place)
- `mktemp`, `mv` — atomic tmpfile+mv for portable in-place replacement
```

---

### WR-02: session-log-init.sh re-launch path writes sentinel-pid before verifying lock file write succeeded

**File:** `hooks/session-log-init.sh:141`
**Issue:** In the re-launch sentinel path (existing log, autonomous mode), the sequence is:
```bash
touch "$SB_DIR/sentinel-lock-$_uuid"
printf '%s:%s\n' "$sentinel_pid" "$_uuid" > "$SB_DIR"/sentinel-pid
```
If `touch` fails (e.g., disk full), the `trap 'exit 0' ERR` catches the error and exits — but `sentinel_pid` was already disowned on line 137. The sentinel process is now orphaned (running, uncancellable from cleanup logic) while no pid file records it. On the same path in the new-log creation block (lines 249-252) the same pattern applies. This is a pre-existing structural limitation, but it is worth noting because the TOCTOU fix introduced the lock file as the ONLY identity anchor — if the lock file can silently fail to be created, the TOCTOU protection is incomplete.
**Fix:** Add an explicit existence check after the `touch` and before writing the pid file:
```bash
touch "$SB_DIR/sentinel-lock-$_uuid" || { kill "$sentinel_pid" 2>/dev/null || true; exit 0; }
printf '%s:%s\n' "$sentinel_pid" "$_uuid" > "$SB_DIR"/sentinel-pid
```
This kills the orphaned sentinel before exiting if lock file creation fails.

---

### WR-03: silver-scan Step 2 uses `ls` + `grep -c` which silently miscounts when no `.md` files match

**File:** `skills/silver-scan/SKILL.md:52-53`
**Issue:** The session log enumeration uses:
```bash
SESSION_LOGS=$(ls docs/sessions/*.md 2>/dev/null | sort)
TOTAL_SESSIONS=$(echo "$SESSION_LOGS" | grep -c '\.md$' || echo 0)
```
When `docs/sessions/*.md` expands to no files, `ls` exits non-zero and stderr is suppressed — `SESSION_LOGS` becomes empty. Then `echo "$SESSION_LOGS" | grep -c '\.md$'` counts lines in the empty string — on most shells this produces `0`, but `echo ""` may produce a single newline, causing `grep -c` to return `0` (no `.md` match in a blank line). The `|| echo 0` fallback never fires because `echo "$SESSION_LOGS"` always succeeds. This is fragile. The Phase 56 fix correctly used `find ... -print | sort | tail -1` in silver-add/silver-rem, but silver-scan was not updated with the same pattern.
**Fix:** Replace with the `find` pattern used elsewhere in the codebase:
```bash
SESSION_LOGS=$(find docs/sessions -maxdepth 1 -name '*.md' -print 2>/dev/null | sort)
TOTAL_SESSIONS=$(printf '%s\n' "$SESSION_LOGS" | grep -c '\.md' || echo 0)
[[ -z "$SESSION_LOGS" ]] && TOTAL_SESSIONS=0
```

---

### WR-04: templates/silver-bullet.md.base §9 is missing the Pre-Release Quality Gate — structural section heading drift

**File:** `templates/silver-bullet.md.base:771`
**Issue:** In `silver-bullet.md`, §9 is "Pre-Release Quality Gate" (four-stage gate with enforcement rules). In `templates/silver-bullet.md.base`, §9 is "User Workflow Preferences" (the dogfood copy's §10). The base template has no Pre-Release Quality Gate section at all — consistent with the `MEMORY.md` note that "Gate stays in silver-bullet.md §9 but NOT in silver-bullet.md.base; end-user projects don't get it." However, the section number drift means the template's §10 subsections (`### 10a`, `### 10b`) appear under `## 9.` in the base. This is cosmetic but confusing: the sub-headings say `10a`, `10b`, etc. while the parent heading is `## 9.`. A user reading the stamped `silver-bullet.md` in their project sees `## 9. User Workflow Preferences` with `### 10a` subsections — the numbers do not match.
**Fix:** Renumber the subsections in `templates/silver-bullet.md.base` to `### 9a`, `### 9b`, `### 9c`, `### 9d`, `### 9e` to align with the parent heading number.

---

## Info

### IN-01: CI workflow `docs/workflows/ parity check` will fail on any added file difference but silently ignores content differences in identical-named files

**File:** `.github/workflows/ci.yml:191-198`
**Issue:** The parity check uses `diff -r --brief`, which reports files that exist in one directory but not the other, and files whose content differs. This is correct for the intended purpose. However, the step name says "parity" but the check output only lists `--brief` differences — if a file is renamed between the two dirs it shows as "only in X" and "only in Y" rather than as a rename. This is a limitation of `diff`, not a bug, but worth documenting for future maintainers.
**Fix:** No code change required. Consider adding an inline comment:
```yaml
# Note: diff --brief reports missing files and content differences.
# Renames appear as "only in X" + "only in Y" pairs — treat as parity failures.
```

---

### IN-02: silver-add Step 4a uses `grep -qE` with a pattern that has a false-negative risk on some gh auth output formats

**File:** `skills/silver-add/SKILL.md:107`
**Issue:** The auth scope check is:
```bash
gh auth status 2>&1 | grep -qE '(Token scopes|Scopes):.*\bproject\b'
```
The Phase 56 fix correctly added the `(Token scopes|Scopes):` prefix to avoid false positives from the word "project" appearing elsewhere in `gh auth status` output. However, if the GitHub CLI changes its output format (e.g., outputting `token scopes:` in lowercase), the pattern would not match and the skill would incorrectly stop with the "project scope absent" error even when the scope exists. This is a fragility, not a current bug.
**Fix:** Add `-i` case-insensitive flag:
```bash
gh auth status 2>&1 | grep -qiE '(token scopes|scopes):.*\bproject\b'
```

---

### IN-03: silver-rem Step 6 uses `${INSIGHT:0:60}` bash substring syntax which is documented as a shell command but this is a skill (markdown instruction to Claude)

**File:** `skills/silver-rem/SKILL.md:348`
**Issue:** The session log append step shows:
```bash
printf -- '- [%s]: %s — %s\n' "$INSIGHT_TYPE" "$CATEGORY" "${INSIGHT:0:60}" >> "$SESSION_LOG"
```
The `${INSIGHT:0:60}` bash parameter expansion is listed in a code block, implying Claude should literally run this shell command. But silver-rem is a SKILL.md — its code blocks are instructions to Claude, not shell scripts. When Claude follows these instructions as a skill (not a hook script), it calls the shell with this exact syntax. In bash `${var:0:60}` is valid, but if Claude uses `printf` in a subshell or different context, the expansion behavior may vary. The comment acknowledges `INSIGHT` is untrusted data and uses printf/redirection correctly — the specific issue is whether Claude will faithfully truncate to 60 chars using this bash syntax when running an ad-hoc shell command vs. inline expansion.
**Fix:** Make the truncation explicit and safe:
```bash
INSIGHT_SHORT=$(printf '%s' "$INSIGHT" | head -c 60)
printf -- '- [%s]: %s — %s\n' "$INSIGHT_TYPE" "$CATEGORY" "$INSIGHT_SHORT" >> "$SESSION_LOG"
```

---

### IN-04: test-timeout-check.sh uses `sleep 1` for mtime ordering which can be flaky on fast CI runners

**File:** `tests/hooks/test-timeout-check.sh:31`
**Issue:** Tests 1, 5, and 6 rely on `sleep 1` to ensure file modification times differ by at least 1 second (so a file created after `sleep 1` has a strictly greater mtime than one created before). On some CI environments (especially containerized runners where filesystem timestamps may have low resolution or be virtualized), 1-second sleep may be insufficient to guarantee a different mtime. Tests 5 and 6 are already gated as `macOS-only` which partially mitigates this, but Test 1 (line 31) runs on all platforms.
**Fix:** No immediate code change needed since the tests pass in CI currently. Consider documenting the timing dependency with a comment:
```bash
sleep 1  # ensure flag mtime >= session-start-time (1s needed for mtime ordering)
```

---

### IN-05: silver-scan Step 9 summary counter note refers to "Pass 1" and "Pass 2" but uses inconsistent variable names in the summary block

**File:** `skills/silver-scan/SKILL.md:230-246`
**Issue:** The summary block template (lines 230-242) shows the `CANDIDATE_COUNT` label as "Presented to you" and the description note at lines 245-246 clarifies the two counters. However, the summary block uses `ITEMS_FOUND` (total found before stale filter) but `CANDIDATE_COUNT` (presented after stale filter) in the same "Pass 1" section without a row for stale-already-tracked items (introduced with Phase 58's Step 4-iv local tracker cross-reference). With the new `ALREADY_TRACKED` classification joining `STALE`, the `ITEMS_FOUND - ITEMS_STALE - CANDIDATE_COUNT` arithmetic may not add up if ALREADY_TRACKED items are counted separately from STALE in the implementation but not shown in the summary.
**Fix:** Add an `Already tracked (local):` row to the summary block template to make the accounting complete:
```
  Marked stale:        ITEMS_STALE
  Already tracked:     ITEMS_ALREADY_TRACKED
  Presented to you:    CANDIDATE_COUNT
```
And initialize `ITEMS_ALREADY_TRACKED=0` in the counters block at Step 2.

---

_Reviewed: 2026-04-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 064-verification-init-improvements
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - hooks/session-log-init.sh
  - hooks/session-start
  - hooks/stop-check.sh
  - skills/silver-add/SKILL.md
  - skills/silver-create-release/SKILL.md
  - skills/silver-init/SKILL.md
  - skills/silver-rem/SKILL.md
  - tests/hooks/test-dev-cycle-check.sh
  - tests/hooks/test-session-log-init.sh
  - tests/hooks/test-stop-check.sh
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 064: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Three hook scripts (session-log-init.sh, session-start, stop-check.sh), four skill files (silver-add, silver-create-release, silver-init, silver-rem), and three test files were reviewed at standard depth. No critical security vulnerabilities or data-loss risks were found. The three warnings cover: a test that passes for the wrong reason (masking unverified on-main behavior), an instruction gap where `$release_url` is used but never bound, and a duplicated dependency check in silver-init. Four info items cover minor inconsistencies and missing test coverage.

---

## Warnings

### WR-01: Test 5 in test-stop-check.sh passes for the wrong reason — on-main filtering is never exercised

**File:** `tests/hooks/test-stop-check.sh:205`
**Issue:** `setup()` writes `"feature/test"` to `$TMPBRANCH_FILE` and exports `SILVER_BULLET_BRANCH_FILE`. Test 5 then calls `git checkout -b main` (changing the actual git branch to `main`) but never updates `$TMPBRANCH_FILE`. When `stop-check.sh` runs it sees:
- `current_branch = "main"` (from `git rev-parse --abbrev-ref HEAD`)
- `stored_state_branch = "feature/test"` (from `$TMPBRANCH_FILE`)

These differ, so the branch-scope validation at line 221 fires and exits 0 — the test passes because of the branch mismatch bypass, not because the on-main skill-filter logic (lines 243–245) ran. The actual on-main filtering of `finishing-a-development-branch` is never reached or verified.

**Fix:** Update `$TMPBRANCH_FILE` to `"main"` after the git checkout in Test 5:
```bash
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
printf 'main\n' > "$TMPBRANCH_FILE"   # <-- add this line
```

---

### WR-02: `$release_url` used in Google Chat notification but never assigned in silver-create-release

**File:** `skills/silver-create-release/SKILL.md:257`
**Issue:** Step 6.3 shows `gh release create` with no output capture — the URL is not assigned to a shell variable. Step 6.5 then uses `$release_url` in the `jq -n` payload for the Google Chat notification and in the `$summary` description. Without the assignment, `$release_url` is empty and the notification omits the release link entirely. The `gh release create` command can return the URL via `--json url -q .url`.

**Fix:** Capture the release URL in Step 6.3:
```bash
release_url=$(gh release create "$VERSION" \
  --title "$VERSION" \
  --notes "$RELEASE_NOTES_MARKDOWN" \
  --json url -q '.url')
```

---

### WR-03: silver-init checks for the Engineering plugin twice (Phase 1.4 and Phase 1.8)

**File:** `skills/silver-init/SKILL.md:140` and `skills/silver-init/SKILL.md:213`
**Issue:** Phase 1.4 ("Engineering plugin") and Phase 1.8 ("Anthropic Engineering plugin") check for the same plugin with the same glob paths (the second check adds `~/.claude/plugins/cache/engineering/skills/` which is subsumed by Phase 1.4's `*/engineering/*/skills/documentation/SKILL.md` glob when the cache layout matches). Both failures trigger the same AskUserQuestion with the same install command. A user who installs the plugin after Phase 1.4's prompt will hit a duplicate install prompt at Phase 1.8, causing confusion.

**Fix:** Remove Phase 1.8 entirely. If the intent is to detect a flat `engineering/` layout in the cache (without a version subdirectory), expand Phase 1.4's glob to also match `~/.claude/plugins/cache/engineering/skills/documentation/SKILL.md`. The Engineering plugin presence check should be consolidated into a single phase.

---

## Info

### IN-01: _insert_before silently no-ops when anchor section is absent from existing log

**File:** `hooks/session-log-init.sh:102`
**Issue:** The `_insert_before` helper inserts a section immediately before a named anchor line. If the anchor (e.g., `"## Task"`, `"## Agent Teams dispatched"`, `"## Knowledge & Lessons additions"`) is absent from an existing session log, the awk never fires, the file is unchanged, and the missing section is silently skipped. For pre-v2 logs that use different section headings this means `## Pre-answers`, `## Skills flagged at discovery`, and `## Items Filed` are never backfilled, with no warning emitted.

**Fix:** After each `_insert_before` call, verify the expected heading was actually inserted with `grep -q`. If not, fall back to appending the section at the end of the file:
```bash
if ! grep -q "^## Pre-answers$" "$existing"; then
  printf '\n## Pre-answers\n\n(filled at Step 0 by Claude if autonomous mode)\n' >> "$existing"
fi
```

No test currently covers this edge case. A test with a legacy-format log missing `## Task` would catch it.

---

### IN-02: Trailing-newline inconsistency between existing-log and new-log JSON output paths

**File:** `hooks/session-log-init.sh:160` vs `hooks/session-log-init.sh:266`
**Issue:** The existing-log path (line 160) pipes through `tr -d '\n'` to strip the trailing newline from the JSON output. The new-log path (line 266) does not — `jq` emits a trailing newline by default. The hook protocol is likely tolerant of both, but the inconsistency means consumers that read the output precisely will see different line-ending behavior depending on which branch ran.

**Fix:** Apply `tr -d '\n'` consistently on both output lines, or remove it from line 160 so both paths let jq emit its standard trailing newline.

---

### IN-03: silver-rem size-cap redirect Step 5 lacks explicit code for creating the overflow header

**File:** `skills/silver-rem/SKILL.md:158`
**Issue:** When the existing target file has ≥300 lines, Step 5 says "redirect TARGET to the next-suffix file (e.g., `YYYY-MM-b.md`). If that suffix file is new (does not exist), create it with the appropriate header template for the type." Only the `wc -l` command is shown in a code block; the conditional header-creation for the overflow file is described in prose only. An implementer following this skill must infer the pattern from the non-overflow `IS_NEW_FILE=true` blocks above. For `YYYY-MM-c.md` and beyond, the step says "Continue to next suffix" (Edge Cases section) but provides no loop or iteration code.

**Fix:** Add an explicit code block for overflow file creation:
```bash
if (( LINE_COUNT >= 300 )); then
  TARGET="${TARGET%.md}-b.md"
  if [[ ! -f "$TARGET" ]]; then
    # Re-run Step 5 header creation for the overflow file using same INSIGHT_TYPE branch
    IS_NEW_FILE=true
  fi
fi
```
Also document that the `-b` → `-c` → `-d` progression requires iterating the suffix check in a loop rather than a one-time redirect.

---

### IN-04: silver-add Step 4b label-create uses sed for repo name extraction — fragile for non-standard SSH URLs

**File:** `skills/silver-add/SKILL.md:111`
**Issue:** The `sed` chain `s|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|` is applied to derive `OWNER_REPO`. This pattern handles HTTPS and standard `git@github.com:` SSH URLs but fails for enterprise GitHub URLs (`https://github.mycompany.com/`), non-standard SSH config aliases, or GitHub CLI SSH format (`ssh://git@github.com/`). A label-create failure does not abort the flow (the command uses `|| true`), but the issue will be created with an incorrect or empty `--repo` and silently succeed against the wrong repo.

**Fix:** Use `gh repo set-default --view` or `gh repo view --json nameWithOwner -q .nameWithOwner` as the authoritative source for `OWNER_REPO`. These commands use the gh CLI's built-in remote resolution which handles all URL formats and SSH config aliases. Fall back to the sed chain only when `gh` is unavailable.

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

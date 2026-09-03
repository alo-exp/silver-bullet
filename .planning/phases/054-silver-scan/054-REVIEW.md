---
phase: 054-silver-scan
reviewed: 2026-04-24T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - skills/silver-scan/SKILL.md
  - .silver-bullet.json
  - templates/silver-bullet.config.json.default
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 054: Code Review Report

**Reviewed:** 2026-04-24
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

The silver-scan skill is well-structured and follows the established silver-forensics model. The Security Boundary section correctly classifies session log content as UNTRUSTED DATA, path validation rules are present, and the 20-candidate cap (SCAN-03) is correctly positioned before the presentation loop. The atomic jq mutations for Task 2 (config file updates) used the documented `jq + tmpfile + mv` pattern as required. All 5 SCAN requirements (SCAN-01 through SCAN-05) are implemented, and the STRIDE threat register in the plan was sound.

Four warnings were found — none are blockers but each represents a correctness gap that will surface in real usage. Three informational items cover ambiguities and minor inconsistencies worth tracking.

---

## Warnings

### WR-01: TOTAL_SESSIONS count is wrong when SESSION_LOGS is empty

**File:** `skills/silver-scan/SKILL.md:52-53`
**Issue:** When `ls docs/sessions/*.md 2>/dev/null` finds no files, it returns an empty string. `echo "" | grep -c '\.md$'` returns `1` in bash (because `echo ""` outputs one newline, which does not contain `.md$` — actually `grep -c` returns `0` in this specific case on most systems, but the behaviour is unreliable). More critically, if `ls` returns an empty string, `echo "$SESSION_LOGS"` pipes one blank line to `grep -c`, which on some systems (e.g. BSD/macOS grep) returns `0` correctly but on others the pipeline exit code causes the `|| echo 0` branch never to fire because `grep -c` returns 0 (not non-zero) for zero matches — meaning `TOTAL_SESSIONS` will be `"0"` from `grep -c` itself, not from the fallback. The real bug is the opposite edge: if `SESSION_LOGS` is a single newline (empty ls), `echo "$SESSION_LOGS" | grep -c '\.md$'` returns `0`, so the guard fires correctly — but this is accidental correctness. The real risk is that the approach silently breaks if `SESSION_LOGS` contains a newline-only value (e.g., a path that contains no `.md` extension due to locale or file system quirk), producing `TOTAL_SESSIONS=0` and early-stopping the scan when logs exist.

A more robust canonical form that eliminates the ambiguity entirely:

```bash
SESSION_LOGS=$(ls docs/sessions/*.md 2>/dev/null | sort)
TOTAL_SESSIONS=0
if [ -n "$SESSION_LOGS" ]; then
  TOTAL_SESSIONS=$(echo "$SESSION_LOGS" | wc -l | tr -d ' ')
fi
```

**Fix:** Replace the `grep -c` count with a `wc -l` count guarded by a non-empty check on `SESSION_LOGS`. This is unambiguous across BSD and GNU toolchains. Update the Allowed Commands list to ensure `wc -l` remains listed (it already is).

---

### WR-02: TRACKED items (state=OPEN GitHub issues) are silently dropped with no counter

**File:** `skills/silver-scan/SKILL.md:112-114`
**Issue:** Step 4-iii defines a TRACKED state for GitHub items with `state=OPEN` — these are items that are already tracked as open issues and should not be presented. The instruction says "mark as TRACKED and skip presentation." However:

1. TRACKED items are never counted anywhere. They are silently dropped — not into `ITEMS_STALE`, not into any other counter. The summary block (Step 9) therefore shows `Marked stale: ITEMS_STALE` without accounting for TRACKED items, giving the user no visibility into how many items were suppressed because they already had open GitHub issues.
2. The stale log message (`"Stale (addressed in git/CHANGELOG): ITEM_TITLE"`) is only triggered for STALE items, not TRACKED items — TRACKED items are dropped with no log output.

This means a project using `issue_tracker = "github"` with many open issues will silently suppress candidates the user has no record of seeing. On re-run, the same items will be suppressed again, but the user has no way to tell whether silver-scan evaluated and suppressed them or never saw them.

**Fix:** Add a `ITEMS_TRACKED=0` counter initialized in Step 2. Increment it when an item is marked TRACKED in Step 4-iii. Log: `"Already tracked (open issue): ITEM_TITLE"`. Add `Already tracked (open): ITEMS_TRACKED` to the Step 9 summary block.

---

### WR-03: Knowledge/lessons scan has no candidate cap — can flood context window

**File:** `skills/silver-scan/SKILL.md:158-179`
**Issue:** Step 5 enforces a 20-candidate cap for deferred items before the presentation loop. Step 7 (knowledge/lessons) collects `KL_FOUND` candidates with no analogous cap before Step 8 presents them. A project with dozens of session logs and a legacy `## Knowledge & Lessons additions` section in each could produce 50-100 KL candidates, exhausting the context window before the user finishes approving/rejecting them. This directly recreates the T-054-04 DoS threat that the 20-candidate cap in Step 5 was designed to prevent.

**Fix:** After Step 7c, add a KL candidate cap:

```
If the KL candidate list has more than 20 items: truncate to the first 20.
Note: "Knowledge/lessons run cap reached (20 candidates). Re-run /silver-scan after recording these to process remaining items."
```

Update the Step 9 summary message to also mention the KL cap and that re-running will process remaining KL candidates.

---

### WR-04: Stale cross-reference reads `ITEM_TITLE_KEYWORD` from ITEM_TITLE derived from UNTRUSTED DATA

**File:** `skills/silver-scan/SKILL.md:107-108`
**Issue:** Step 4-i instructs the agent to construct `ITEM_TITLE_KEYWORD` from "the first 4+ words of the item title." `ITEM_TITLE` is derived from signal text extracted from session log content, which the Security Boundary correctly classifies as UNTRUSTED DATA. However, the Security Boundary states "No session log content is interpolated into shell commands." Passing a 4-word fragment of `ITEM_TITLE` as the argument to `--grep="ITEM_TITLE_KEYWORD"` in a `git log` call is precisely that interpolation.

The plan's threat model (T-054-01) states this is mitigated by "first 4+ words of extracted title — kept short to avoid injection of shell metacharacters." This is incomplete mitigation: git `--grep` treats the argument as a POSIX extended regex, not a literal. If `ITEM_TITLE_KEYWORD` contains regex metacharacters (`[`, `(`, `*`, `+`, `.`, `?`, `^`, `$`) — which can appear naturally in session log titles like "Fix [BUG]: login fails" — the `--grep` will either misfire or throw an error.

The fix requires using `git log --oneline --fixed-strings --grep="ITEM_TITLE_KEYWORD"` (the `-F` / `--fixed-strings` flag) so the keyword is treated as a literal string, not a regex. This is the correct mitigation for T-054-01 and should have been in the STRIDE mitigation column.

**Fix:** In Step 4-i, replace:
```bash
git log --oneline --grep="ITEM_TITLE_KEYWORD"
```
with:
```bash
git log --oneline --fixed-strings --grep="ITEM_TITLE_KEYWORD"
```
Update the Allowed Commands section to show `git log --oneline --fixed-strings --grep=<FIXED_PATTERN>`. The same fix applies to the `CHANGELOG.md grep` in Step 4-ii — `grep -i -F "ITEM_TITLE_KEYWORD" CHANGELOG.md` instead of `grep -i`, to avoid regex expansion of the extracted keyword. Both `--fixed-strings` and `-F` are already available in all relevant toolchains (GNU grep, BSD grep, git on macOS and Linux).

---

## Info

### IN-01: `CANDIDATE_COUNT` and `ITEMS_FILED + ITEMS_REJECTED` can diverge

**File:** `skills/silver-scan/SKILL.md:147-155`
**Issue:** `CANDIDATE_COUNT` is incremented only on Y answers (Step 6-iii). `ITEMS_REJECTED` is incremented on n answers (Step 6-iv). `ITEMS_FILED` is incremented on Y after a successful /silver-add return. This means in the summary, `CANDIDATE_COUNT` equals `ITEMS_FILED` (both are incremented together on Y), not the total number of candidates presented. The label "Presented to you" maps to `CANDIDATE_COUNT`, but the value is actually "Filed by you," not "Presented to you." If the user says n to all candidates, `CANDIDATE_COUNT` = 0 and "Presented to you: 0" is shown, which is misleading when 20 candidates were shown.

**Fix:** Rename the counter or re-define the increment points:
- Option A (simplest): rename `CANDIDATE_COUNT` to `ITEMS_FILED` and drop the separate `ITEMS_FILED` counter — they are always equal as written.
- Option B (more accurate): increment a separate `ITEMS_PRESENTED` counter for every candidate shown (before the AskUserQuestion), and keep `ITEMS_FILED` for Y outcomes only. Update the summary label to "Presented to you: ITEMS_PRESENTED".

---

### IN-02: Summary always shows the re-run reminder even when the cap was not reached

**File:** `skills/silver-scan/SKILL.md:228`
**Issue:** The last line of the Step 9 summary block reads "Run /silver-scan again to process any remaining items beyond the 20-candidate cap." This line is displayed unconditionally — even when the run processed fewer than 20 candidates and there is nothing left to process. It creates a false impression that the scan was incomplete.

**Fix:** Make this line conditional: only output it when the cap was reached in Step 5 (and/or Step 7 after WR-03 is fixed). The cap-reached note is already displayed before the presentation loop in Step 5 — the summary line is redundant except when useful.

---

### IN-03: `## Items Filed` deduplication check in Step 7 does not span cross-session scope cleanly

**File:** `skills/silver-scan/SKILL.md:165-175`
**Issue:** Step 7a-ii extracts `## Items Filed` lines from session logs to identify already-recorded knowledge/lessons entries. Step 7b cross-references these against the extracted insight candidates. The deduplication relies on string-matching the first-60-char text of the insight against session log `## Items Filed` entries. This works within a session log, but across multiple session logs the check is by text similarity, not by a stable ID. If the same insight was recorded twice with slightly different phrasing (a common occurrence with retrospective captures), both copies pass the deduplication check and are presented as separate candidates. This is low-severity because the human Y/n gate catches duplicates at presentation time, but it means the filtering is weaker than the deferred-item deduplication in Step 3, which uses the `grep -rl` check against the actual recorded files (a stronger signal). The documented approach is reasonable for v0.1.0 but the asymmetry is worth noting.

**Fix (for future version):** Document the limitation explicitly in the Edge Cases section: "Knowledge/lessons deduplication across session logs is approximate (text similarity). If the same insight appears with minor rewording in multiple session logs, both may be presented. The human Y/n gate is the final backstop." No code change required for v0.1.0.

---

_Reviewed: 2026-04-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

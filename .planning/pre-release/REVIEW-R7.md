# Pre-Release Quality Gate — Round 7 Review

**Date:** 2026-04-24
**Round:** 7
**Layers:** A (automated), B (peer), C (engineering)

## Fix Verified — B-01

All 9 orchestrator skills (`silver-ui`, `silver-feature`, `silver-devops`, `silver-ingest`, `silver-validate`, `silver-research`, `silver-release`, `silver-spec`, `silver-bugfix`) now use `"^## [0-9]\+\. User Workflow Preferences"` in their pre-flight grep. Confirmed via grep across all 9 files. CHANGELOG entry at line 39 of `[0.25.0]` accurately describes the fix. B-01 is resolved.

---

## Layer A — Automated Pattern Review

**Shell injection vectors:** No unquoted variable expansions into shell commands in any reviewed skill. All user-supplied content passed to `gh issue create` or `jq` via `--arg` (not string interpolation). `silver-remove` validates the ID with a strict `^SB-[IB]-[0-9]+$` regex before using it in `sed`. `silver-ingest` Step 5 validates `{owner}/{repo}` against `^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$` before any `gh api` call.

**`grep -rl` without `-F`:** All cross-reference greps in `silver-scan` Step 7b use `grep -rlF` (fixed string). The CHANGELOG fix for this (`silver-scan` Step 7b missing `-F`) is confirmed applied at line 175 of `silver-scan/SKILL.md`.

**`rm -rf` without guards:** The single `rm -rf` in `silver-update` Step 6b has all three required guards: HOME unset check (line 155), symlink check `! -L "$STALE_CACHE"` (line 159), and path prefix check `"$STALE_CACHE" == "${HOME}/"*` (line 159). No findings.

**Hardcoded secrets:** No hardcoded passwords, API keys, or tokens found in any reviewed file. The `_notifications_comment` in `.silver-bullet.json` explicitly documents that webhook URLs are NOT committed.

**Missing `|| fallback` on critical jq reads:** `silver-add` Step 4d reads from the `_github_project` cache only after confirming `CACHE_OWNER` is non-empty (lines 161-170). However, when cache IS present, `PROJ_NUM`, `NODE_ID`, `STATUS_FIELD_ID`, `BACKLOG_OPT_ID` are all read without `// empty` fallbacks (lines 166-170). If the cache were partially written (e.g., missing `number`), `jq -r` would return the string `"null"`, which would be passed silently to `gh project item-add`. Severity: INFO — the cache is always written atomically in one jq operation (line 203-204), making partial writes impossible in normal operation.

**Version consistency:** `.silver-bullet.json` = `0.25.0`, `templates/silver-bullet.config.json.default` version/config_version = `0.25.0`, CHANGELOG top entry = `[0.25.0]`. All consistent.

**No findings.**

---

## Layer B — Peer Review

### B-R7-01: Stale step reference "proceed to Step 3" in `silver-release` gap-closure loop

**File:** `skills/silver-release/SKILL.md`, lines 159 and 163

**Issue:** The gap-closure loop (Step 2b) presents three options to the user when 2 iterations are exhausted. Option A says "proceed to Step 3" and the prose at line 163 says "If A: proceed to Step 3 with gaps documented." However, there is no `## Step 3` heading in this skill. The step immediately following Step 2b is `## Step 3a: Verify Existing Documentation`. The original "Step 3" was split into `Step 3a` and `Step 3b`, but the gap-closure loop text was not updated to reflect this split. An AI agent reading these instructions has no `## Step 3` anchor to jump to.

**Impact:** Moderate — an agent following this instruction after 2 gap-closure iterations would either halt in confusion or make a judgment call (most likely proceeding to Step 3a, which is correct behavior). The instruction is misleading but does not cause a hard failure in practice.

**Fix:** Update both occurrences to reference `Step 3a`:

Line 159:
```
> A. Release anyway — document gaps as known issues, proceed to Step 3a
```

Line 163:
```
Wait for user selection. If A: proceed to Step 3a with gaps documented. If B or C: exit workflow.
```

---

## Layer C — Engineering Review

No findings. The following items were checked and are clean:

- **`silver-bullet.md` vs `templates/silver-bullet.md.base` consistency:** Both have identical `§3b-i` and `§3b-ii` sections. Both have identical `required_deploy` and `all_tracked` arrays. The `[0.25.0]` CHANGELOG note about clearing live preferences from the template's Mode Preferences table is reflected — the template's `§9 Mode Preferences` table is empty.

- **Template §9 / §10 numbering:** The pre-existing issue #59 (parent `## 9. User Workflow Preferences` with subsections labeled `### 10a.`–`### 10e.`) is unchanged and correctly not re-flagged. All skill instructions referencing `§10b` in `templates/silver-bullet.md.base` match the subsection headings (`### 10b.`) within the template's `## 9.` section — the heading text is self-consistent even if the parent/child numbering is inconsistent.

- **B-01 fix scope completeness:** The fix covers all 9 orchestrator skills that have a pre-flight `grep` for User Workflow Preferences. `silver-add`, `silver-rem`, `silver-scan`, `silver-remove`, and `silver-update` do not have this pre-flight pattern and are unaffected. The CHANGELOG correctly states "all 9 orchestrator skills."

- **`silver-scan` CANDIDATE_COUNT counter logic:** Fixed correctly — counter increments before the Y/n prompt (line 143), ensuring both accepted and rejected candidates are counted. Summary display at line 223 ("Presented to you: CANDIDATE_COUNT") is consistent with the counter semantics.

- **`silver-release` Step 9b `(none)` grep:** Uses `grep -qF '(none)'` (line 258) — `-F` flag correctly applied for fixed-string match. Consistent with CHANGELOG fix note.

- **`silver-rem` size cap overflow logic:** IS_NEW_FILE reset and header creation for `-b` files is handled in Step 5. Step 7 correctly excludes overflow files from INDEX.md updates via `"$TARGET" != *-b.md && "$TARGET" != *-c.md`. Pre-existing gap for `-d.md` and beyond is documented in Edge Cases and is a theoretical concern only.

- **Cross-skill step references in orchestrator skills:** All forward and backward step references within silver-feature, silver-ui, silver-devops, silver-research, silver-spec, silver-bugfix, silver-validate, silver-ingest, and silver-add are consistent with the steps defined in each respective skill.

---

## Summary

| Layer | Findings |
|-------|----------|
| A | 0 |
| B | 1 |
| C | 0 |
| **Total** | **1** |

**Clean round:** NO

### Finding Detail

**B-R7-01 (Warning)** — `skills/silver-release/SKILL.md` lines 159 and 163 reference "Step 3" in the gap-closure user prompt and prose, but no `## Step 3` heading exists (the step was renamed to `Step 3a` / `Step 3b`). Fix: replace both references with "Step 3a". Two-line change, no logic change required.

This is the only finding. It is in a non-critical path (reached only after 2 gap-closure iterations fail, which is an exceptional case), and the correct behavior (proceed to documentation steps) is unambiguous to any agent reading the full skill in context.

# Pre-Release Code Review — Round 3 (All Layers)

## Fix verification (Round 2 fixes)

### Fix 1 — Template subsections restored to 10a–10e
**CORRECT.** `templates/silver-bullet.md.base` lines 778–796 carry headings `### 10a.` through `### 10e.`. The parent section heading at line 771 is `## 9. User Workflow Preferences`. This is internally consistent: the subsections are labelled `10a`–`10e` (as expected by skills that reference them via `§10a`/`§10e`) while the parent section is `## 9.`. All orchestrator skills (`silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-release`, `silver-research`, `silver-spec`, `silver-validate`, `silver-ingest`) consistently reference `§10`, `§10b`, `§10e` when addressing the subsections — this matches the template labels. No regression.

### Fix 2 — Template lines 312/325 §10 → §9 cross-references
**CORRECT.** Both references have been updated:
- Line 312: `silver:security` is always mandatory — cannot be skipped via **§9**
- Line 325: Records the decision in **§9** if user chooses A permanently

These correctly point to the parent section `## 9. User Workflow Preferences` (i.e., the section as a whole), not to a specific subsection label. No other lines in the template incorrectly refer to the preferences section as `§10` at the parent level — the only `§10` occurrences remaining in the template body are at lines 407–408 (`§9` used correctly there too, confirmed by grep showing zero `§10` hits in the template).

**Note:** Lines 407–408 in `## 3. NON-NEGOTIABLE RULES` also correctly say `§9`:
- `Override a non-skippable gate … via §9 preferences`
- `Write runtime preference updates to §9 without updating both …`

All four `§9` references in the template body are accurate.

### Fix 3 — silver-update Step 6a jq path syntax
**CORRECT.** The skill at line 144 now reads:
```bash
if jq -e '.plugins["silver-bullet@silver-bullet"]' "$REG" > /dev/null 2>&1; then
```
And line 146:
```bash
jq 'del(.plugins["silver-bullet@silver-bullet"])' "$REG" > "$TMP" && mv "$TMP" "$REG"
```
The bracket-notation `.plugins["silver-bullet@silver-bullet"]` is valid jq syntax for a key containing hyphens and `@` characters. This correctly accesses the nested `.plugins` object rather than the flat root level that the old `."silver-bullet@silver-bullet"` path incorrectly targeted.

### Fix 4 — silver-update Step 6b $HOME guard
**CORRECT.** Lines 155–163 implement:
```bash
if [[ -z "$HOME" ]]; then
  echo "WARNING: HOME is unset — skipping stale cache cleanup."
else
  STALE_CACHE="${HOME}/.claude/plugins/cache/silver-bullet/silver-bullet"
  if [[ -d "$STALE_CACHE" && ! -L "$STALE_CACHE" && "$STALE_CACHE" == "${HOME}/"* ]]; then
    rm -rf "$STALE_CACHE"
  fi
fi
```
Three guards are present: (1) unset `$HOME` → skip with warning, (2) symlink guard `! -L`, (3) path-prefix containment check `== "${HOME}/"*`. This correctly prevents `rm -rf` on symlinks, unset `$HOME` expansion, and paths that escape the expected prefix.

### Fix 5 — CHANGELOG.md v0.25.0 entry added
**CORRECT.** Entry present at line 3 with format `## [0.25.0] — 2026-04-24` matching the established format used by all prior entries (e.g., `## [0.24.0] — 2026-04-24`, `## [0.23.10] — 2026-04-24`). The entry contains a milestone summary paragraph, subsections with FEAT/CAPT/UPD/FORN/BUG-FIX labels matching the project's pattern, and commit SHA references consistent with prior entries. No format deviation.

### Fix 6 — Template §9 Mode Preferences table cleared
**CORRECT.** `### 10e. Mode Preferences` at lines 794–796 contains only the header row `| Setting | Value | Since |` with no data rows — the live Silver Bullet project's autonomous mode preference that was leaked into the base template has been removed.

### Fix 7 — Template §5.1 alo-labs key check
**CORRECT.** Line 22 of the template reads:
```bash
cat "$HOME/.claude/plugins/installed_plugins.json" | jq -r '.plugins["silver-bullet@alo-labs"][0].version // .plugins["silver-bullet@silver-bullet"][0].version // "unknown"'
```
Checks `alo-labs` first (post-marketplace install), falls back to legacy `silver-bullet@silver-bullet` key. Consistent with silver-update Step 1 which uses the same fallback pattern.

---

## New issues found

### CRITICAL

None.

### HIGH

None.

### MEDIUM

**M-01 — silver-remove Step 2: case glob accepts trailing garbage before strict guard**

File: `skills/silver-remove/SKILL.md` lines 55–70

The `case` statement matches `SB-I-[0-9]*` and `SB-B-[0-9]*` which allows trailing non-digit characters (the `*` glob). The strict regex guard `^SB-[IB]-[0-9]+$` that follows does catch these — but only for `local-issue` and `local-backlog` ID types. The guard is correctly applied. However the code flow assigns `ID_TYPE` before the guard runs, and line 73 references `ID_TYPE` for the GitHub path check immediately after the case/guard block without re-reading `ID_TYPE`. If `ID_TYPE` is `"local-issue"` and the guard fires `exit 1`, control never reaches line 73, so this is not a real execution bug.

**Reassessed:** The guard is in the right place and exits cleanly. No actual defect — downgrading to LOW/INFO.

*(Removing from MEDIUM — see LOW/INFO M-01 below)*

**M-02 — silver-remove Step 5d: sed -i '' is BSD-only (portability)**

File: `skills/silver-remove/SKILL.md` line 181

```bash
sed -i '' "s|^### ${ITEM_ID} —|### [REMOVED ${DATE}] ${ITEM_ID} —|" "$TARGET_FILE"
```

The `sed -i ''` form is BSD macOS syntax. GNU sed (Linux) requires `sed -i` without the empty string argument. Since Silver Bullet targets macOS (Claude Desktop), this is acceptable in context, but if a user runs on Linux this will fail. This was noted as issue #57 (awk `-v` backslash interpretation) in Round 2 — the `sed -i` portability issue is a distinct but closely related concern.

**Check against deferred list:** Issue #56 in the Round 1 backlog covers `sed -i` portability. **This is already a deferred/known item — do not re-report.**

*(Removing from MEDIUM — already deferred as #56)*

### LOW/INFO

**L-01 — silver-remove Step 2 case glob vs. strict guard — no actual defect, INFO only**

The `case` statement for `SB-I-[0-9]*` / `SB-B-[0-9]*` allows trailing non-digit chars at the glob level, and the strict `^SB-[IB]-[0-9]+$` regex guard beneath it correctly rejects them with `exit 1`. The two-level validation is slightly redundant (the case glob could be tightened to `SB-I-[0-9][0-9]*` to avoid accepting e.g. `SB-I-5abc` at the case level), but the strict guard makes it functionally correct. No user-visible defect.

**L-02 — CHANGELOG.md: v0.25.0 "Bug Fixes" subsection does not use a label code (e.g., BUG-NN)**

All other subsections in the 0.25.0 entry use label codes (`FEAT-SCAN`, `CAPT-01`, `UPD-01`, `FORN-01`). The `### Bug Fixes (pre-release review)` subsection uses plain prose bullets without `BUG-NN` codes. This is inconsistent with the established format (compare v0.24.0 which uses `BUG-01` through `BUG-06`). Not a functional issue — documentation consistency only.

**L-03 — silver-scan Step 8 knowledge/lessons candidates increment CANDIDATE_COUNT is not explicitly stated**

Step 6 increments `CANDIDATE_COUNT` before each deferred-item presentation (line 142 of SKILL.md). Step 8 (knowledge/lessons candidates) has no equivalent `CANDIDATE_COUNT` increment instruction. The summary in Step 9 shows `Presented to you: CANDIDATE_COUNT` which appears to be scoped to deferred items only (Steps 3–6), not knowledge/lessons (Steps 7–8). This is a minor documentation gap — knowledge/lessons candidates are not counted in `CANDIDATE_COUNT`. Whether this is intentional (separate counters for deferred vs. K/L) or an oversight is ambiguous. `KL_FOUND` and `KL_RECORDED` are separate counters, so the summary is still complete — this is INFO only.

---

## Summary

Total new: 0 critical, 0 high, 0 medium, 3 low/info

All Round 2 fixes verified correct:
- Template §9/§10 section numbering is internally consistent and matches skill references
- Lines 312 and 325 correctly say §9 (no other stale §10 parent-section refs remain in template)
- silver-update Step 6a jq bracket-notation syntax is correct for hyphenated/@ keys
- silver-update Step 6b $HOME guard covers all three unsafe-rm scenarios
- CHANGELOG.md v0.25.0 entry format matches prior entries
- Template §10e Mode Preferences table is cleared
- Template §5.1 alo-labs key checked first with legacy fallback

L-01 and L-03 are informational observations with no functional impact. L-02 is a documentation consistency note.

Clean round: **YES**
(Zero new accepted findings — all three LOW/INFO items are either informational observations or already-deferred items)

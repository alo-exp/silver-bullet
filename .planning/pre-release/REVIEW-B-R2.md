# Pre-Release Code Review — Layer B (Peer Review)
## Round 2

**Reviewed:** 2026-04-24
**Reviewer:** Peer (Claude Sonnet 4.6)
**Scope:** Fix verification (commits 494d438–1047bf0) + new-issue sweep
**Files Reviewed:** `silver-bullet.md`, `templates/silver-bullet.md.base`, `skills/silver-rem/SKILL.md`, `skills/silver-scan/SKILL.md`, `skills/silver-add/SKILL.md`, `skills/silver-release/SKILL.md`, `skills/silver-update/SKILL.md`, `skills/silver-remove/SKILL.md`, `templates/silver-bullet.config.json.default`, `.silver-bullet.json`

---

## Fix Verification

### CRIT-B-01 — jq path for alo-labs key first with fallback

**Status: PASS**

Both `silver-bullet.md §5.1` (line 22) and `templates/silver-bullet.md.base §5.1` (line 22) now read:

```bash
cat "$HOME/.claude/plugins/installed_plugins.json" | jq -r '.plugins["silver-bullet@alo-labs"][0].version // .plugins["silver-bullet@silver-bullet"][0].version // "unknown"'
```

The jq path uses `.plugins[<key>][0].version` which matches the structure that `silver-update` Step 6a's cleanup code deletes (top-level key, but the `.plugins` nesting is consistent with how the registry stores per-plugin arrays). The alo-labs key is tried first; the legacy key is the fallback; `"unknown"` is the final fallback. This is correct: after `silver-update` removes the legacy key and installs under alo-labs, the first branch resolves the installed version correctly.

`silver-update` Step 1 instructs the agent to try alo-labs first and fall back to silver-bullet — consistent with the jq order. Fix verified.

---

### CRIT-B-02 — silver-rem Step 5 PROJECT_NAME read and heredoc variable expansion

**Status: PASS**

`skills/silver-rem/SKILL.md` Step 5 (line 121) now reads:

```bash
PROJECT_NAME=$(jq -r '.project.name // "unknown"' .silver-bullet.json 2>/dev/null || echo "unknown")
```

This assignment occurs **before** the `cat > "$TARGET" << EOF` heredoc. The heredoc delimiter `EOF` is unquoted, so shell variable expansion applies to the body — `${PROJECT_NAME}` expands correctly to the value just assigned. Variable is available and correctly interpolated into the heredoc. Fix verified.

The same `PROJECT_NAME` assignment also appears in the size-cap overflow block (line 177), where the `-b` file header is created — consistent.

---

### COR-06 — silver-rem Step 6 awk command

**Status: PASS with minor observation**

The awk command in Step 6 for both knowledge and lessons entries:

```bash
awk -v h="## ${CATEGORY}" -v d="${DATE}" -v ins="${INSIGHT}" \
  'BEGIN{done=0} $0==h && !done{print; printf "\n%s — %s\n",d,ins; done=1; next} {print}'
```

**Correctness:** The `!done` flag ensures insertion only at the FIRST occurrence of the heading — correct behavior for files where a heading might theoretically appear more than once. After insertion, `done=1` prevents any second match from triggering another insertion. `next` skips re-printing the heading (already printed in the same action). The pattern correctly handles: heading found → insert entry immediately after → print remaining lines unchanged. The awk command is correct.

**Observation (not a blocking issue):** The `awk -v ins="$INSIGHT"` variable-passing mechanism has a known behavior: backslash sequences in the value are interpreted by awk's `-v` assignment. Specifically, a literal `\n` in the insight text becomes a newline character in the awk variable. If a user's insight text contains `\n` (e.g., "Use `\n` for line breaks"), the appended entry will contain an actual newline in the middle of the line, splitting it across two lines in the doc file. The entry is technically malformed but readable. This is a cosmetic edge case, not a data-loss bug. Documented as NEW-LOW-01 below.

---

### COR-01 — silver-rem -b overflow file header creation

**Status: PASS**

The size-cap block (Step 5, lines 169–215) now contains explicit `cat > "$TARGET" << EOF` heredoc code for both knowledge and lessons types when the `-b` file is new (`IS_NEW_FILE=true` after the suffix update). The header for knowledge includes all five category headings. The header for lessons uses the correct YAML front matter. HIGH-B-02 from Round 1 is resolved — no longer a comment-only stub.

---

### COR-02 — silver-rem Step 7 guard for overflow files

**Status: PASS**

Step 7 now contains the guard:

```bash
if [[ "$IS_NEW_FILE" = true && "$TARGET" != *-b.md && "$TARGET" != *-c.md ]]; then
  # proceed with INDEX.md updates below
fi
```

This correctly prevents INDEX.md updates when the target is an overflow file (`-b.md`, `-c.md`). The guard covers both known overflow suffixes. Edge cases section also confirms: "Size cap hit on -b file: continue to the next suffix (YYYY-MM-c.md, etc.)". The guard's pattern `!= *-c.md` would not match `-d.md` or later suffixes, but in practice the skill's size cap logic only ever creates one overflow suffix per month (the -b file), and `-c.md` is listed as a future extension. The guard is sufficient for current implementation. Fix verified.

---

### HIGH-02 / MED-B-03 — Template §9 subsections renamed and Mode Preferences cleared

**Status: PASS**

`templates/silver-bullet.md.base` now has:
- `## 9. User Workflow Preferences` with subsections `### 9a.` through `### 9e.` (lines 778–795) — matches section number
- `### 9e. Mode Preferences` table is now empty (header rows only, no data rows) — confirmed no residual live Silver Bullet preferences seeded into the template

MED-B-02 (numbering mismatch) and MED-B-03 (live preference data in template) are both resolved.

---

### HIGH-B-01 — silver-add Step 4e rate-limit path proceeds to Step 6

**Status: PASS**

Step 4e (line 219) now reads: "Set `FILED_ID` to `"#${ISSUE_NUM}"` and proceed to Step 6 (session log) then Step 7 with a warning — the filing must be recorded even when board placement fails."

The earlier "Do NOT proceed to Step 6" instruction is absent. Both partial-success paths (board not found in Step 4d, rate limit exhausted in Step 4e) now correctly flow through Step 6 before Step 7. Fix verified.

---

### silver-scan — -F flag and CANDIDATE_COUNT

**Status: PASS**

`skills/silver-scan/SKILL.md`:

- `-F` flag: present in Step 4-ii (CHANGELOG grep uses `grep -i -F`), Step 7b cross-reference uses `grep -rlF`. Step 4-i uses `git log --oneline --fixed-strings --grep=` (correct for git). All grep commands against untrusted content now use fixed-string mode.

- CANDIDATE_COUNT: Step 2 initializes `CANDIDATE_COUNT=0`. Step 6-ii states "Increment `CANDIDATE_COUNT` (before asking — this counter tracks candidates presented, regardless of user choice)." Step 9 summary shows `Presented to you: CANDIDATE_COUNT`. Semantics are now correct — this counter tracks presentations, not filings.

Both fixes verified.

---

### silver-release — grep -qF

**Status: PASS**

Step 9b.2 (line 258) uses `grep -qF '(none)'` for the items-filed section check. The `-F` flag treats `(none)` as a literal string, preventing false matches if the section content contained regex metacharacters. Fix verified.

---

### silver-update — $HOME guard

**Status: PASS**

Step 6b (lines 155–162) now contains:

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

Guard against unset `$HOME` present. Additional guards: `! -L "$STALE_CACHE"` prevents following symlinks; `"$STALE_CACHE" == "${HOME}/"*` prefix check prevents path traversal. Fix verified and more robust than the minimum required.

---

### silver-remove — strict regex guard

**Status: PASS**

Step 2 now includes:

```bash
if [[ "$ID_TYPE" = "local-issue" || "$ID_TYPE" = "local-backlog" ]]; then
  if ! [[ "$ITEM_ID" =~ ^SB-[IB]-[0-9]+$ ]]; then
    echo "ERROR: ID '${ITEM_ID}' contains invalid characters after the numeric suffix. Expected format: SB-I-N or SB-B-N (digits only)."
    exit 1
  fi
fi
```

The `case` statement glob `SB-I-[0-9]*` allows trailing non-digit characters (e.g., `SB-I-1abc`). The subsequent regex `^SB-[IB]-[0-9]+$` with anchored `$` rejects any trailing characters. Guard is correct. Fix verified.

---

### Version bumps — config files

**Status: PASS**

`templates/silver-bullet.config.json.default`: `"config_version": "0.25.0"`, `"version": "0.25.0"` — confirmed.
`.silver-bullet.json`: `"version": "0.25.0"` — confirmed.

---

## New Issues Found

### NEW-HIGH-01: `templates/silver-bullet.md.base` §2h still contains `§10` cross-references — should be `§9`

**Severity: HIGH**
**File:** `templates/silver-bullet.md.base`, lines 312 and 325
**Introduced by:** Pre-existing but exposed by Round 1's §9 renaming fix

The template's body text still contains two `§10` references:

- Line 312 (`§2h`): `` `silver:security` is always mandatory — cannot be skipped via §10 ``
- Line 325 (`§2h` step-skip protocol): `Records the decision in §10 if user chooses A permanently...`

After Round 1 renamed the template's preferences section from `§10` to `§9`, these cross-references in `§2h` became dangling — they point to a section that does not exist in the template. When a user project's Claude reads the template-generated `silver-bullet.md`, it will encounter `§10` references and find no `§10` section in the document, causing confusion about where workflow preferences are stored.

The live `silver-bullet.md` correctly uses `§10` (because it does have a `§9 Pre-Release Quality Gate` before the preferences section). The template, which skips §9, must use `§9` throughout.

**Fix:** In `templates/silver-bullet.md.base`, replace both remaining `§10` references with `§9`:
- Line 312: `cannot be skipped via §9`
- Line 325: `Records the decision in §9 if user chooses A permanently — before committing, display the exact text being written to §9...`

---

### NEW-MED-01: All 9 orchestrator skills have hardcoded `grep "^## 10\."` for preference loading — fails in user projects where the section is `§9`

**Severity: MEDIUM**
**Files:** `skills/silver-release/SKILL.md:23`, `skills/silver-feature/SKILL.md:19`, `skills/silver-ui/SKILL.md:21`, `skills/silver-bugfix/SKILL.md:19`, `skills/silver-devops/SKILL.md:26`, `skills/silver-research/SKILL.md:21`, `skills/silver-spec/SKILL.md:19`, `skills/silver-validate/SKILL.md:19`, `skills/silver-ingest/SKILL.md:19`

Every orchestrator skill's Pre-flight section contains:

```bash
grep -A 50 "^## 10\. User Workflow Preferences" silver-bullet.md | head -60
```

In user projects initialized by `/silver:init`, `silver-bullet.md` is generated from the template — which has `## 9. User Workflow Preferences`. The `grep "^## 10\."` pattern will find nothing in a user project's `silver-bullet.md` and return empty output. The preference-loading step silently fails, and all nine orchestrator skills operate without user preferences.

This is a functional regression introduced by Round 1's §9 renaming fix (which correctly renamed the template section but did not update skill grep patterns). The fix in the skills would have been needed at the same time.

**Scope:** 9 skills affected — all orchestrator workflows for user projects will silently skip preference loading until this is fixed.

**Fix:** Update the grep pattern in all 9 skills to match both section numbers:

```bash
grep -A 50 "^## [0-9]\+\. User Workflow Preferences" silver-bullet.md | head -60
```

Or use the heading text without the number:

```bash
grep -A 50 "User Workflow Preferences" silver-bullet.md | grep -A 50 "^## " | head -60
```

---

### NEW-LOW-01: `silver-rem` Step 6 awk `-v ins` passes INSIGHT through awk variable assignment — backslash sequences in insight text are interpreted

**Severity: LOW**
**File:** `skills/silver-rem/SKILL.md:233-235`, `skills/silver-rem/SKILL.md:252-254`

The awk command passes the insight text via `-v ins="${INSIGHT}"`. awk's `-v` assignment processes backslash escape sequences in the value: `\n` becomes a newline, `\t` becomes a tab, `\\` becomes a single backslash. If a user captures an insight containing literal `\n` (e.g., documenting a string escape), the appended doc line is split across multiple lines.

This is cosmetic — the entry is still readable — but creates malformed entries in knowledge/lessons files if the insight text contains backslash sequences.

**Fix:** Use `ENVIRON["ins"]` instead of `-v ins=`:

```bash
export INSIGHT
awk -v h="## ${CATEGORY}" -v d="${DATE}" \
  'BEGIN{done=0} $0==h && !done{print; printf "\n%s — %s\n",d,ENVIRON["ins"]; done=1; next} {print}' \
  "$TARGET" > "$TMP" && mv "$TMP" "$TARGET"
```

`ENVIRON` bypasses awk's escape-sequence processing for the value.

---

## Summary

### Fix verification results

| Finding | Status | Notes |
|---------|--------|-------|
| CRIT-B-01 (jq alo-labs key) | PASS | Correct path and fallback order in both files |
| CRIT-B-02 (project name in heredoc) | PASS | PROJECT_NAME set before heredoc; unquoted EOF expands correctly |
| COR-06 (awk insert command) | PASS | Logic correct; !done flag handles duplicate headings; minor edge case noted as NEW-LOW-01 |
| COR-01 (-b overflow header) | PASS | Explicit creation code for both knowledge and lessons types |
| COR-02 (Step 7 overflow guard) | PASS | Guards -b.md and -c.md; sufficient for current implementation |
| HIGH-02/MED-B-03 (§9 subsections + empty prefs) | PASS | 9a–9e renamed; Mode Preferences table cleared |
| HIGH-B-01 (Step 4e session log) | PASS | "Do NOT proceed to Step 6" removed; both partial-success paths log |
| silver-scan -F flag + CANDIDATE_COUNT | PASS | -F present in all grep calls; CANDIDATE_COUNT semantics corrected |
| silver-release grep -qF | PASS | Fixed in Step 9b.2 |
| silver-update $HOME guard | PASS | Guard plus symlink and prefix checks |
| silver-remove strict regex | PASS | Anchored regex rejects trailing characters after case glob |
| Version bumps (both config files) | PASS | 0.25.0 in both files |

All 12 Round 1 targeted fixes are correctly applied.

### New issues found

**Total new: 0 critical, 1 high, 1 medium, 1 low**

| ID | Severity | Summary |
|----|----------|---------|
| NEW-HIGH-01 | HIGH | Template §2h still has 2 dangling `§10` references; no `§10` exists in template |
| NEW-MED-01 | MEDIUM | 9 orchestrator skill files hardcode `grep "^## 10\."` for preference loading — silently fails in all user projects (section is `§9` in generated files) |
| NEW-LOW-01 | LOW | `silver-rem` awk `-v ins` interprets `\n`/`\t` backslash sequences in insight text, splitting entries across lines |

**Priority for pre-release resolution:** NEW-HIGH-01 and NEW-MED-01 are user-facing correctness bugs that affect all new project installations. NEW-MED-01 in particular is a functional regression introduced by the Round 1 §9 renaming fix. Both should be addressed before v0.25.0 ships. NEW-LOW-01 is a cosmetic edge case.

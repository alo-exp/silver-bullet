# Pre-Release Code Review — Layer A (GSD Automated)
## Round 2

**Reviewed:** 2026-04-24
**Files Reviewed:** 10
**Depth:** Standard (full file read + cross-file analysis)

---

## Fix Verification

Each of the 15 accepted Round 1 fixes was verified against the committed files.

| # | Fix description | File(s) | Verdict |
|---|----------------|---------|---------|
| 1 | §5.1 alo-labs key read first, silver-bullet fallback | `silver-bullet.md`, `templates/silver-bullet.md.base` | CORRECT |
| 2 | §9 subsection renaming 9a–9e in base template | `templates/silver-bullet.md.base` | PARTIAL — see NI-01 |
| 3 | silver-rem project name from `.project.name` | `skills/silver-rem/SKILL.md:121` | CORRECT |
| 4 | silver-rem -b file header created with correct type header | `skills/silver-rem/SKILL.md:175-213` | CORRECT |
| 5 | silver-rem awk inserts entry AFTER heading, not before | `skills/silver-rem/SKILL.md:233-235` | CORRECT |
| 6 | silver-rem INDEX.md guard skips overflow files | `skills/silver-rem/SKILL.md:268` | CORRECT |
| 7 | silver-scan Step 7b uses `grep -rlF` (fixed-string flag) | `skills/silver-scan/SKILL.md:175` | CORRECT |
| 8 | silver-scan CANDIDATE_COUNT incremented before user prompt | `skills/silver-scan/SKILL.md:143` | CORRECT |
| 9 | silver-add Step 6 session log runs for GitHub path too | `skills/silver-add/SKILL.md:319-337` | CORRECT |
| 10 | silver-release Step 9b uses `grep -qF '(none)'` | `skills/silver-release/SKILL.md:258` | CORRECT |
| 11 | silver-update Step 6b $HOME guard before rm -rf | `skills/silver-update/SKILL.md:155-162` | CORRECT |
| 12 | silver-remove strict post-case `=~ ^SB-[IB]-[0-9]+$` guard | `skills/silver-remove/SKILL.md:65-70` | CORRECT |
| 13 | templates/silver-bullet.config.json.default version fields | `templates/silver-bullet.config.json.default:2-3` | CORRECT |
| 14 | .silver-bullet.json version field updated to 0.25.0 | `.silver-bullet.json:2` | CORRECT |

**Fix verification result:** 13 of 14 fixes are fully correct. Fix #2 (§9 subsection renaming) is only partial — it renamed the subsection headings but left two cross-reference pointers and a missing section that break newly initialized projects. See NI-01 below.

---

## New Issues Found

### NI-01 (HIGH): Base template `## 9. Pre-Release Quality Gate` section missing — all skills silently fail to load preferences on new project instances

**Files:** `templates/silver-bullet.md.base:771`, all skills with pre-flight preference load

**Issue:** The Round 1 fix correctly renamed the base template's User Workflow Preferences subsections from `10a–10e` to `9a–9e` (since in the template that section is `##9`). However, the fix did not address the root cause: the base template is missing the `## 9. Pre-Release Quality Gate` section entirely. In `silver-bullet.md` (deployed), the section numbering is:

- `## 8. Third-Party Plugin Boundary`
- `## 9. Pre-Release Quality Gate`
- `## 10. User Workflow Preferences`

But in `templates/silver-bullet.md.base`, the section numbering is:

- `## 8. Third-Party Plugin Boundary`
- `## 9. User Workflow Preferences`

Every workflow skill (`silver-release`, `silver-feature`, `silver-ui`, `silver-devops`, `silver-research`, `silver-ingest`, `silver-validate`) greps for `"^## 10\. User Workflow Preferences"`. On any project initialized from the base template, this grep returns nothing — the preferences section is at `##9`. All stored preferences are silently ignored for the lifetime of those projects until the user manually re-runs `/silver:init`.

Additionally, new projects lack the 4-stage quality gate section entirely, meaning `silver-bullet.md §9` in those projects describes preferences, not quality gates — making the `completion-audit.sh` quality-gate-stage markers inconsistent with the document the user reads.

**Fix:** Add the `## 9. Pre-Release Quality Gate` section to `templates/silver-bullet.md.base` between sections 8 and 9, and renumber User Workflow Preferences to `## 10`. Update all template internal cross-references accordingly (currently lines 312 and 325 in the base template reference `§10` inconsistently — see NI-02).

---

### NI-02 (MEDIUM): Base template internal cross-references still point to `§10` while User Workflow Preferences is `§9` in that document

**File:** `templates/silver-bullet.md.base:312`, `templates/silver-bullet.md.base:325`

**Issue:** Two inline cross-references in `silver-bullet.md.base` reference `§10`:

- Line 312: `` `silver:security` is always mandatory — cannot be skipped via §10 ``
- Line 325: `Records the decision in §10 if user chooses A permanently...`

But in the base template, User Workflow Preferences IS section 9 (`## 9. User Workflow Preferences`). There is no `§10` in the base template. Users of new projects who read these instructions will look for a §10 that does not exist, creating confusion. Lines 407–408 in the same template correctly use `§9`, making this inconsistency within a single file.

**Fix:** If NI-01 is not fixed (base template remains without Quality Gate section), change lines 312 and 325 from `§10` to `§9`. If NI-01 is fixed by adding the Quality Gate section, these lines are already correct and no change is needed.

---

### NI-03 (MEDIUM): CHANGELOG.md has no entry for v0.25.0 — version mismatch between config and changelog

**File:** `CHANGELOG.md`, `.silver-bullet.json:2`, `templates/silver-bullet.config.json.default:2-3`

**Issue:** Both `.silver-bullet.json` and `templates/silver-bullet.config.json.default` declare `"version": "0.25.0"`, but the CHANGELOG.md latest entry is `## [0.24.0] — 2026-04-24`. There is no `0.25.0` entry. The silver-update skill fetches the CHANGELOG to display "What's New" between versions — users upgrading from any prior version to 0.25.0 will see an empty or incorrect diff because the version entry is absent.

Additionally, `silver-bullet.md §3 RULES` states: "`README.md` MUST be updated to reflect current version, features, and changes before release. `/silver-create-release` will block if README is stale." The same principle applies to CHANGELOG — it is a user-visible surface that must be updated before release.

**Fix:** Add a `## [0.25.0]` section to `CHANGELOG.md` documenting the Round 1 bug fixes shipped in this release.

---

### NI-04 (MEDIUM): `silver-rem` awk `-v ins="${INSIGHT}"` binding interprets backslash escape sequences in user input, corrupting output entries

**File:** `skills/silver-rem/SKILL.md:233-234`, `skills/silver-rem/SKILL.md:252-253`

**Issue:** Both the knowledge and lessons entry-insert paths use awk with:

```bash
awk -v h="..." -v d="${DATE}" -v ins="${INSIGHT}" \
  'BEGIN{done=0} $0==h && !done{print; printf "\n%s — %s\n",d,ins; done=1; next} {print}'
```

In GNU awk and POSIX awk, the `-v var=value` assignment interprets escape sequences in `value`. A user insight containing a literal `\n` (as text, e.g., "Use `\n` for newlines in bash") will be converted to an actual newline by awk, splitting the entry across two lines and breaking the `DATE — INSIGHT` single-line format. Insights containing `\t`, `\r`, or `\\` are similarly corrupted.

This is not a security vulnerability (the content is user-supplied and written to a local file), but it is a data correctness bug that corrupts knowledge entries silently.

**Fix:** Replace `-v ins="${INSIGHT}"` with a pipe or heredoc approach, or use awk's `ENVIRON` to bypass escape interpretation:

```bash
INSIGHT="$INSIGHT" awk -v h="## ${CATEGORY}" -v d="${DATE}" \
  'BEGIN{done=0; ins=ENVIRON["INSIGHT"]} $0==h && !done{print; printf "\n%s \342\200\224 %s\n",d,ins; done=1; next} {print}' \
  "$TARGET" > "$TMP" && mv "$TMP" "$TARGET"
```

`ENVIRON["INSIGHT"]` reads from the environment variable and does not interpret escape sequences. Alternatively, pass the insight via a temp file and use `getline`.

---

### NI-05 (LOW): `.silver-bullet.json` missing `config_version` field present in the template

**File:** `.silver-bullet.json`

**Issue:** `templates/silver-bullet.config.json.default` has both `"config_version": "0.25.0"` and `"version": "0.25.0"`. The project's own `.silver-bullet.json` has only `"version": "0.25.0"` — `config_version` is absent. If any hook or skill checks `config_version` for compatibility gating, the project file will fail that check silently. Currently no hook checks this field, but the discrepancy creates drift between the template and the live config.

**Fix:** Add `"config_version": "0.25.0"` to `.silver-bullet.json`, or remove `config_version` from the template if it serves no purpose.

---

### NI-06 (LOW): `silver-update` Step 6a jq path is wrong — legacy key cleanup silently does nothing

**File:** `skills/silver-update/SKILL.md:144-146`

**Issue:** Step 6a checks for and removes the legacy `silver-bullet@silver-bullet` registry entry:

```bash
if jq -e '."silver-bullet@silver-bullet"' "$REG" > /dev/null 2>&1; then
  jq 'del(."silver-bullet@silver-bullet")' "$REG" > "$TMP" && mv "$TMP" "$REG"
fi
```

The `installed_plugins.json` structure (as shown by all other accesses in the codebase) is `{"plugins": {"silver-bullet@alo-labs": [...], ...}}`. The jq expressions `'."silver-bullet@silver-bullet"'` and `'del(."silver-bullet@silver-bullet")'` access a top-level key named `silver-bullet@silver-bullet`, which does not exist — the entries are under `.plugins`. The result: the existence check always returns null/false, and the cleanup never executes. Legacy installations will retain the stale `silver-bullet@silver-bullet` entry indefinitely across updates.

**Fix:**

```bash
if jq -e '.plugins["silver-bullet@silver-bullet"]' "$REG" > /dev/null 2>&1; then
  TMP="$(mktemp "${REG}.XXXXXX")"
  jq 'del(.plugins["silver-bullet@silver-bullet"])' "$REG" > "$TMP" && mv "$TMP" "$REG"
fi
```

---

## Summary

**Fix verification:** 13/14 correct. Fix #2 (§9 subsection renaming) is partial — subsections were renamed but the root cause (missing Pre-Release Quality Gate section in base template) was not addressed.

**New findings:**

| ID | Severity | Description |
|----|----------|-------------|
| NI-01 | HIGH | Base template missing `## 9. Pre-Release Quality Gate` — skills silently load no preferences on new project instances |
| NI-02 | MEDIUM | Base template internal cross-references at lines 312 and 325 still say `§10` while preferences is `§9` |
| NI-03 | MEDIUM | CHANGELOG.md has no `0.25.0` entry — version mismatch with config files |
| NI-04 | MEDIUM | awk `-v ins` binding interprets backslash sequences in insight text, corrupting entries |
| NI-05 | LOW | `.silver-bullet.json` missing `config_version` field present in template |
| NI-06 | LOW | silver-update Step 6a wrong jq path — legacy key cleanup silently does nothing |

**Total new: 0 critical, 1 high, 3 medium, 2 low**

This is not a clean round. NI-01 and NI-03 are blocking release concerns: NI-01 causes preferences to be silently dropped for all new project users, and NI-03 means the shipped changelog will show a blank "What's New" for this release. NI-04 is a data correctness bug in silver-rem that silently corrupts knowledge entries containing backslash sequences.

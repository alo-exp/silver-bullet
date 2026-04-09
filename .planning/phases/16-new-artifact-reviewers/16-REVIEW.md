---
phase: 16-new-artifact-reviewers
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - skills/review-spec/SKILL.md
  - skills/review-design/SKILL.md
  - skills/review-requirements/SKILL.md
  - skills/review-roadmap/SKILL.md
  - skills/review-context/SKILL.md
  - skills/review-research/SKILL.md
  - skills/review-ingestion-manifest/SKILL.md
  - skills/review-uat/SKILL.md
  - skills/artifact-reviewer/SKILL.md
findings:
  critical: 0
  warning: 5
  info: 3
  total: 8
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

All 9 reviewer SKILL.md files were examined against the artifact-reviewer interface contract defined in `skills/artifact-reviewer/rules/reviewer-interface.md`. The reviewers are structurally consistent: every file declares `PASS`/`ISSUES_FOUND` output with the correct Finding schema, explicitly prohibits artifact modification, and documents distinct finding ID prefixes. The artifact-to-reviewer mapping table in `artifact-reviewer/SKILL.md` correctly lists all 8 new reviewers.

Issues found fall into three categories:
1. **Finding ID collision hazard** — several reviewers define multiple findings with the same base number (e.g., `ROAD-F30` and `ROAD-F31`), which is fine, but two reviewers define sibling IDs that share the same suffix and could generate duplicate IDs at runtime when "increment suffix" logic is applied.
2. **QC guard gaps** — two quality criteria that perform cross-file reads (`source_inputs`) omit an explicit guard for when the file at the provided path does not exist or cannot be read, leaving no fallback finding and potentially causing the reviewer to silently skip the criterion.
3. **Inconsistent `source_inputs` type declaration** — `review-context` and `review-research` declare `source_inputs` as `string[]` in the Input table while all other reviewers declare it as `string` (the interface contract uses `string[]`). This is an inconsistency in documentation, not a functional bug, but creates confusion.

---

## Warnings

### WR-01: ROAD-F30 / ROAD-F31 and INGM-F20 sibling IDs risk runtime collision

**File:** `skills/review-roadmap/SKILL.md:78-79`, `skills/review-ingestion-manifest/SKILL.md:59`

**Issue:** `review-roadmap` emits both `ROAD-F30` (circular dependency) and `ROAD-F31` (backward reference) as fixed IDs for two different sub-cases of QC-4. Similarly, `review-ingestion-manifest` emits `INGM-F20` with "increment suffix per missing block" but the base ID `INGM-F20` is also used for the parent finding description. If both a circular dependency AND a backward reference exist in the same roadmap, the reviewer will produce two findings with `ROAD-F30` and `ROAD-F31` — which are unique. However, in `review-ingestion-manifest`, the same `INGM-F20` base is used to cover both QC-3 and QC-4 failures independently, creating a genuine ID collision when both criteria fire: both QC-3's `INGM-F20` and QC-4's `INGM-F30` (false-success check) share the `INGM-F` + 2-digit namespace without a clear reservation of which ranges belong to which QC. Currently QC-4 reuses `INGM-F30` — the same number used as the suffix range for QC-3 multi-instance findings — making it ambiguous whether `INGM-F30` came from QC-3 (third missing block) or QC-4.

**Fix:** Reserve distinct numeric ranges per QC in `review-ingestion-manifest`:
- QC-1: `INGM-F01` – `INGM-F09`
- QC-2: `INGM-F10` – `INGM-F19`
- QC-3: `INGM-F20` – `INGM-F29`
- QC-4: `INGM-F35` (not `INGM-F30`) or introduce a letter suffix: `INGM-F30-FS` for false-success findings. Update `review-ingestion-manifest/SKILL.md` QC-4 to use `INGM-F35`.

---

### WR-02: Missing unreadable-path guard in cross-file QC steps

**File:** `skills/review-design/SKILL.md:82-93` (QC-6), `skills/review-requirements/SKILL.md:91-101` (QC-7), `skills/review-roadmap/SKILL.md:51-61` (QC-2), `skills/review-uat/SKILL.md:41-47` (QC-1)

**Issue:** Every cross-file criterion that reads `source_inputs[0]` begins with "Only evaluate this criterion when `source_inputs` contains a path." None specify what the reviewer should do if the path is provided but the file cannot be read (e.g., wrong path, file deleted). If the read fails silently, the criterion is skipped entirely — masking a configuration error as a clean result. This violates the spirit of "Do NOT skip sections because they look complete."

**Fix:** Add an explicit guard to each cross-file QC step:

```markdown
If `source_inputs[0]` is provided but the file at that path cannot be read,
emit ISSUE finding `[PREFIX]-F99` with location = source_inputs[0],
description = "Linked source file cannot be read — cross-reference check skipped",
suggestion = "Verify the path provided in source_inputs[0] is correct and the file exists."
```

Add this block to QC-6 in `review-design`, QC-7 in `review-requirements`, QC-2/QC-3 in `review-roadmap`, and QC-1/QC-2 in `review-uat`.

---

### WR-03: review-uat QC-2 "No Orphaned UAT Rows" has an unconditional reference to spec-path that contradicts its own guard

**File:** `skills/review-uat/SKILL.md:49-53`

**Issue:** QC-2 is titled "No Orphaned UAT Rows" and states it applies "when source_inputs provides a spec-path" (in the parenthetical), but the section header and opening sentence do NOT include the conditional guard clause that appears in QC-1. The guard is buried in the parenthetical on line 51: "(when source_inputs provides a spec-path)". Without the explicit `**Only evaluate this criterion when...**` marker, an implementing agent may apply QC-2 unconditionally, causing it to fail every UAT review that does not provide a spec path.

**Fix:** Add the standard conditional guard line as the first line of QC-2 in `review-uat/SKILL.md`:

```markdown
**Only evaluate this criterion when `source_inputs` includes a spec-path.**
```

This brings QC-2 into consistent form with QC-1, QC-4 (UAT-F31), and cross-file QC sections in all other reviewers.

---

### WR-04: review-requirements QC-2 pattern accepts zero-digit suffix

**File:** `skills/review-requirements/SKILL.md:53-57`

**Issue:** QC-2 defines the REQ-ID format as `REQ-nn` where "nn is one or more digits". The description says "one or more digits" but the examples show two-digit zero-padded IDs (`REQ-01`, `REQ-12`). The pattern `REQ-nn` as written accepts `REQ-1` (single digit) as valid, yet the suggestion for fixing invalid IDs says "zero-padded digits" — implying two digits minimum. If the actual template enforces two-digit zero-padding, a single-digit ID like `REQ-5` should fail QC-2 but under the current rule it passes.

**Fix:** Clarify whether single-digit IDs are valid. If two-digit zero-padding is required, update the QC-2 pattern to:
```
REQ-nn where nn is exactly two zero-padded digits (e.g., REQ-01 through REQ-99)
```
If single-digit IDs are acceptable, remove "zero-padded" from the fix suggestion.

---

### WR-05: review-ingestion-manifest QC-6 emits INFO for missing run timestamp but this is a resumability ISSUE

**File:** `skills/review-ingestion-manifest/SKILL.md:82-83`

**Issue:** QC-6 ("Resumability") splits into two findings: missing artifact IDs emits ISSUE (`INGM-F50`), but missing run timestamp/session ID emits INFO (`INGM-F51`). The skill's own description states the manifest "supports resumability" as a primary quality criterion, and the intro text says the timestamp is needed to "enable auditing". A manifest without a session ID or timestamp cannot reliably identify which run produced it, which directly undermines the stated resumability goal — this deserves ISSUE severity, not INFO.

**Fix:** Promote `INGM-F51` from INFO to ISSUE severity to match the criticality stated in the QC-6 description:

```markdown
**If run timestamp or session ID is missing:** Emit ISSUE finding `INGM-F51` with suggestion = "Add a run timestamp or session ID..."
```

---

## Info

### IN-01: Inconsistent `source_inputs` type in Input table across reviewers

**File:** `skills/review-context/SKILL.md:32`, `skills/review-research/SKILL.md:32`

**Issue:** `review-context` and `review-research` declare the `source_inputs` input field as type `string[]` in their Input tables. All other reviewers (`review-spec`, `review-design`, `review-requirements`, `review-roadmap`, `review-ingestion-manifest`, `review-uat`) declare it as `string` in their respective Input tables (showing `source_inputs[0]` as a named positional field). The canonical interface in `reviewer-interface.md` correctly types it as `string[]`. The positional field style in the majority of reviewers creates the impression that only one source input is accepted — yet the interface allows multiple. This is an inconsistency in documentation style that could mislead implementers.

**Fix:** Standardize all reviewer Input tables to use type `string[]` for `source_inputs` and adopt indexed notation (`source_inputs[0]`, `source_inputs[1]`) only in the Quality Criteria where specific positions are referenced.

---

### IN-02: review-research QC-1 has a conditional that depends on two different inputs (review_context OR source_inputs)

**File:** `skills/review-research/SKILL.md:41-45`

**Issue:** QC-1 fires "If `review_context` or `source_inputs` includes a phase CONTEXT.md with a list of key research questions." This is a compound OR condition — the trigger depends on inspecting the content of either field. No other reviewer combines `review_context` and `source_inputs` as alternative keys for the same criterion trigger. This makes QC-1 harder to implement deterministically: an agent must inspect whether either field contains a CONTEXT.md reference, rather than simply checking `source_inputs` presence.

**Fix:** Clarify the trigger condition to be unambiguous:

```markdown
**Only evaluate this criterion when `source_inputs` includes a CONTEXT.md path.**
If key questions are passed as plain text in `review_context` instead, treat the review_context string as the key question list.
```

---

### IN-03: artifact-reviewer mapping table has no catch-all / fallback entry

**File:** `skills/artifact-reviewer/SKILL.md:21-34`

**Issue:** The artifact-to-reviewer mapping table lists 11 specific patterns. There is no catch-all row (e.g., `*` or `Unknown`) that specifies what the orchestrator should do when the artifact filename matches none of the known patterns. If `--reviewer` is omitted and the file is e.g., `GLOSSARY.md`, the orchestrator has no documented fallback behavior.

**Fix:** Add a fallback row to the mapping table:

```markdown
| (no match) | (none) | Emit an error: "No reviewer found for artifact. Use --reviewer to specify one explicitly." |
```

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 12-spec-foundation
plan: "02"
subsystem: skills
tags: [silver-spec, elicitation, spec, requirements, orchestration]
dependency_graph:
  requires: []
  provides: [skills/silver-spec/SKILL.md]
  affects: [silver-spec elicitation workflow, SPEC.md artifact generation]
tech_stack:
  added: []
  patterns: [orchestration-only SKILL.md, Socratic elicitation, assumption block pattern, skill delegation via Skill tool]
key_files:
  created:
    - skills/silver-spec/SKILL.md
  modified: []
decisions:
  - "silver-spec delegates to product-management:write-spec, design:user-research, design:design-critique rather than reimplementing (ELIC-06)"
  - "SPEC.md spec-version incremented in augment mode by reading existing frontmatter value"
  - "Non-skippable gates are Step 3 (Socratic Elicitation), Step 5 (Assumption Consolidation), Step 7 (Write SPEC.md)"
  - "Artifact injection (Step 4) is conditional on URL presence from Step 1"
  - "DESIGN.md write (Step 9) is conditional on design artifact presence"
metrics:
  duration: ~5min
  completed: 2026-04-09
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 12 Plan 02: silver-spec Elicitation Skill Summary

**One-liner:** 11-step Socratic elicitation orchestration skill guiding PM/BA through 9 requirements domains to produce SPEC.md + REQUIREMENTS.md, with assumption consolidation, skill delegation, and greenfield/augment mode detection.

## What Was Built

`skills/silver-spec/SKILL.md` — an orchestration-only skill (no code, markdown only) following the exact silver-feature SKILL.md pattern with:

- **Step 0:** Mode detection — checks if `.planning/SPEC.md` exists to select greenfield or augment mode
- **Step 1:** Context gathering — feature name/description + optional JIRA/Figma/Google Doc URLs
- **Step 2:** Delegates to `product-management:write-spec` via Skill tool for PM spec scaffold
- **Step 3:** 9-turn Socratic elicitation with domain table (Problem → User goal → Scope → User stories → AC → Edge cases → Error states → Data model → Open questions), assumption trigger phrasing after every answer, `[ASSUMPTION: ...]` block emission for unresolvable ambiguities
- **Step 4:** Conditional artifact injection — WebFetch for Google Docs, `design:user-research` delegation for Figma URLs
- **Step 5:** Assumption consolidation — numbered list, per-assumption resolve/accept/tag decision
- **Step 6:** Conditional `design:design-critique` delegation if design artifact exists
- **Step 7:** Writes `.planning/SPEC.md` from template, sets all frontmatter fields, increments spec-version in augment mode
- **Step 8:** Writes `.planning/REQUIREMENTS.md` from template with REQ-XX and NFR-XX IDs derived from elicitation
- **Step 9:** Conditional `.planning/DESIGN.md` write if design artifact present
- **Step 10:** git commit of spec artifacts
- **Step 11:** Summary banner with spec-version, section count, assumption count, open question count, follow-up warning if needed

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create silver-spec SKILL.md | 18f2f21 | skills/silver-spec/SKILL.md |

## Verification Results

All automated checks passed:
- `test -f skills/silver-spec/SKILL.md` — PASS
- `grep "product-management:write-spec"` — 2 matches
- `grep "design:user-research"` — 1 match
- `grep "design:design-critique"` — 2 matches
- `grep "ASSUMPTION:"` — 4 matches
- `grep "SPEC.md.template"` — 2 matches
- `grep "greenfield"` — 4 matches
- `grep "augment"` — 5 matches
- `grep "spec-version"` — multiple matches
- `wc -l` — 237 lines (requirement: >= 100)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. This is a pure orchestration skill; it references templates that will be created in Plan 12-01. The templates must exist before silver-spec can be run in production, but silver-spec SKILL.md itself is complete and self-consistent.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. The skill is a markdown orchestration document.

## Self-Check: PASSED

- `skills/silver-spec/SKILL.md` exists: CONFIRMED
- Commit `18f2f21` exists: CONFIRMED (created in this session)

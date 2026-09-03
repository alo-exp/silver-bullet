---
phase: 23-specialized-paths
plan: "01"
subsystem: silver-feature skill workflow
tags: [composable-paths, skill-files, path-sections, explore, ideate, specify, design-contract, ui-quality]
dependency_graph:
  requires: [21-foundation, 22-core-paths]
  provides: [PATH2-EXPLORE, PATH3-IDEATE, PATH4-SPECIFY, PATH6-DESIGN-CONTRACT, PATH8-UI-QUALITY]
  affects: [silver-feature/SKILL.md]
tech_stack:
  added: []
  patterns: [composable-path-sections, prerequisite-checks, review-cycles, exit-conditions]
key_files:
  modified:
    - skills/silver-feature/SKILL.md
decisions:
  - "Testing strategy and writing-plans remain in PATH 5 (PLAN) per D-10 — not PATH 4"
  - "PATH 4 skip condition: only allowed when REQUIREMENTS.md already exists from PATH 0"
  - "PATH 6 triggers on UI keywords, UI file types (.tsx/.jsx/.css etc), or DESIGN.md existence"
  - "PATH 8 triggers when PATH 6 was in composition OR SUMMARY.md contains UI file types"
metrics:
  duration_minutes: 20
  completed_date: "2026-04-15"
  tasks_completed: 2
  files_modified: 1
---

# Phase 23 Plan 01: Specialized Paths (silver-feature) Summary

**One-liner:** Replaced 5 [future] placeholder sections in silver-feature/SKILL.md with full composable path sections for PATH 2 (EXPLORE), PATH 3 (IDEATE), PATH 4 (SPECIFY), PATH 6 (DESIGN CONTRACT), and PATH 8 (UI QUALITY) — each with prerequisite checks, trigger conditions, numbered steps, review cycles, and exit conditions.

## What Was Built

### Task 1: PATH 2, 3, 4 (commits: 487395e)

Removed the `## Non-core path steps: Exploration & Ideation` placeholder wrapper and replaced it with three structured path sections:

- **PATH 2: EXPLORE** — Prerequisite: PATH 1 completed (intel files). Trigger: fuzzy/complex classification. 5 steps: gsd-explore, product-management:product-brainstorming, design:user-research, product-management:synthesize-research, product-management:competitive-brief. No review cycle.
- **PATH 3: IDEATE** — Prerequisite: PATH 2 completed. Skip for simple work. 4 steps: superpowers:brainstorming, engineering:architecture, engineering:system-design, design:design-system. Includes MultAI conditional sub-step (preserved from existing Step 1d trigger logic).
- **PATH 4: SPECIFY** — Prerequisite: PATH 3 or external spec. Skip condition: ONLY when REQUIREMENTS.md exists (from PATH 0). 4 steps: silver-ingest, product-management:write-spec, silver-spec, silver-validate. Full review cycle: SPEC.md, REQUIREMENTS.md, DESIGN.md (if exists), INGESTION_MANIFEST.md (if ingest). silver-validate BLOCK findings halt progression.

Testing strategy (`engineering:testing-strategy`) and writing-plans (`superpowers:writing-plans`) were confirmed to stay in PATH 5 per D-10.

### Task 2: PATH 6, PATH 8, [future] cleanup (commit: a2de4c1)

Added two new path sections and cleaned up remaining `[future]` markers:

- **PATH 6: DESIGN CONTRACT** — Inserted between PATH 5 and PATH 7. Trigger: UI keywords in phase name/goal, UI file types in codebase, or DESIGN.md existence. 4 steps: design:design-system, design:ux-copy, gsd-ui-phase, design:accessibility-review. Iterative (Claude suggests exit; user decides). Produces UI-SPEC.md.
- **PATH 8: UI QUALITY** — Inserted between PATH 7 and review steps. Trigger: PATH 6 was in composition OR SUMMARY.md contains UI file types. 3 steps: design:design-critique, gsd-ui-review (6-pillar audit), design:accessibility-review. Produces UI-REVIEW.md. Fixes via `gsd-execute-phase --gaps-only`.
- Removed all 7 `[future]` markers from the review/security/quality section. Updated wrapper comment to note Phase 24 promotion.

## Final State

silver-feature/SKILL.md now has 11 complete path sections:
- PATH 0 (BOOTSTRAP), PATH 1 (ORIENT): from Phase 21
- PATH 2 (EXPLORE), PATH 3 (IDEATE), PATH 4 (SPECIFY): from this plan
- PATH 5 (PLAN), PATH 7 (EXECUTE): from Phase 22
- PATH 6 (DESIGN CONTRACT), PATH 8 (UI QUALITY): from this plan
- PATH 11 (VERIFY), PATH 13 (SHIP): from Phase 22

Zero `[future]` placeholders remain in silver-feature/SKILL.md.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | 487395e | feat(23-01): replace PATH 2, 3, 4 placeholder steps with full path sections |
| 2 | a2de4c1 | feat(23-01): add PATH 6 and PATH 8 sections, remove remaining [future] markers |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all path sections are fully specified with concrete skill invocations.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary changes introduced. SKILL.md files are version-controlled instructions only.

## Self-Check: PASSED

- `grep "## PATH 2: EXPLORE" skills/silver-feature/SKILL.md` → 1 match
- `grep "## PATH 3: IDEATE" skills/silver-feature/SKILL.md` → 1 match
- `grep "## PATH 4: SPECIFY" skills/silver-feature/SKILL.md` → 1 match
- `grep "## PATH 6: DESIGN CONTRACT" skills/silver-feature/SKILL.md` → 1 match
- `grep "## PATH 8: UI QUALITY" skills/silver-feature/SKILL.md` → 1 match
- `grep -c "\[future\]" skills/silver-feature/SKILL.md` → 0
- Total PATH sections: 11
- Commits 487395e and a2de4c1 verified in git log

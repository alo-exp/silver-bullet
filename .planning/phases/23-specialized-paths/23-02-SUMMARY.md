---
phase: 23-specialized-paths
plan: "02"
subsystem: skill-orchestration
tags: [composable-paths, silver-ui, silver-release, design-paths, PATH-6, PATH-8, PATH-15]
dependency_graph:
  requires: [23-01]
  provides: [PATH-6-silver-ui, PATH-8-silver-ui, PATH-15-silver-release]
  affects: [skills/silver-ui/SKILL.md, skills/silver-release/SKILL.md]
tech_stack:
  added: []
  patterns: [composable-path-sections, prerequisite-check, exit-condition]
key_files:
  created: []
  modified:
    - skills/silver-ui/SKILL.md
    - skills/silver-release/SKILL.md
decisions:
  - PATH 6 and PATH 8 are always-active in silver-ui (no trigger detection needed — UI workflow is inherently UI work)
  - PATH 15 in silver-release uses file-existence check (UI-SPEC.md or UI-REVIEW.md) to detect UI milestones
  - PATH 15 is constrained to PATH 17 (RELEASE) only, documented explicitly to prevent per-phase invocation
metrics:
  duration: ~10 minutes
  completed: 2026-04-15
  tasks_completed: 2
  files_modified: 2
---

# Phase 23 Plan 02: Specialized Paths — silver-ui and silver-release Summary

**One-liner:** PATH 6 (DESIGN CONTRACT) and PATH 8 (UI QUALITY) added as always-active sections to silver-ui/SKILL.md; PATH 15 (DESIGN HANDOFF) inserted between security gate and gap closure in silver-release/SKILL.md with UI-phase trigger detection.

## What Was Built

### Task 1: PATH 6 and PATH 8 in silver-ui/SKILL.md

Replaced the flat Step 5 (UI Phase — Design Contract) with a full PATH 6 section and the flat Step 9 (UI Visual Audit) with a full PATH 8 section, both following the standard composable path pattern.

**PATH 6: DESIGN CONTRACT** — always-active, iterative:
- Prerequisite: PLAN.md exists
- Steps: design:design-system → design:ux-copy (as-needed) → gsd-ui-phase → design:accessibility-review (as-needed)
- Produces: UI-SPEC.md
- Exit: UI-SPEC.md exists, user accepts design contract

**PATH 8: UI QUALITY** — always-active, post-execution:
- Prerequisite: SUMMARY.md exists with UI deliverables
- Steps: design:design-critique → gsd-ui-review → design:accessibility-review (all always)
- Produces: UI-REVIEW.md; fixes via gsd-execute-phase --gaps-only
- Exit: UI-REVIEW.md with no critical findings, or user accepts

### Task 2: PATH 15 in silver-release/SKILL.md

Inserted PATH 15 (DESIGN HANDOFF) between Step 2a (Security Hard Gate) and Step 2b (Gap-Closure Loop).

**PATH 15: DESIGN HANDOFF**:
- Trigger detection: `ls .planning/phases/*/UI-SPEC.md .planning/phases/*/UI-REVIEW.md`
- Steps: design:design-handoff (always) → design:design-system (as-needed)
- Produces: Handoff package
- Constraint: PATH 17 (RELEASE) only — never in per-phase sequence

## Decisions Made

- PATH 6 and PATH 8 are always-active in silver-ui — no conditional trigger needed since the silver-ui workflow is inherently UI work
- PATH 15 uses file-existence shell check as the trigger (T-23-04 threat mitigation: prevents PATH 15 from firing on non-UI milestones)
- "per-phase sequence" constraint is explicitly documented in silver-release to prevent misuse

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. SKILL.md files are instruction-only — no runtime user input crosses trust boundaries.

## Self-Check: PASSED

- skills/silver-ui/SKILL.md: modified and committed (34b01b2)
- skills/silver-release/SKILL.md: modified and committed (d0f8631)
- `grep "## PATH 6: DESIGN CONTRACT" skills/silver-ui/SKILL.md` — match found
- `grep "## PATH 8: UI QUALITY" skills/silver-ui/SKILL.md` — match found
- `grep "## PATH 15: DESIGN HANDOFF" skills/silver-release/SKILL.md` — match found
- PATH 15 positioned at line 62, between Step 2a (line 58) and Step 2b (line 80) — confirmed

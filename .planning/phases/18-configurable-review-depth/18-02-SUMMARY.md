---
phase: 18-configurable-review-depth
plan: "02"
subsystem: artifact-reviewer
tags: [reviewer-interface, check-mode, review-depth, skill-docs]
dependency_graph:
  requires: [18-01]
  provides: [check_mode-contract, depth-config-docs]
  affects: [skills/artifact-reviewer/rules/reviewer-interface.md, skills/artifact-reviewer/SKILL.md]
tech_stack:
  added: []
  patterns: [structural-vs-full-review, qc-check-tagging]
key_files:
  modified:
    - skills/artifact-reviewer/rules/reviewer-interface.md
    - skills/artifact-reviewer/SKILL.md
decisions:
  - "check_mode defaults to 'full' if not provided — reviewers cannot accidentally skip checks (T-18-03 mitigation)"
  - "QC checks tagged as structural or content — structural mode skips content-tagged checks only"
  - "standard depth requires 1 clean pass; deep requires 2 consecutive; quick uses structural-only + 1 pass"
metrics:
  duration_minutes: 10
  completed: "2026-04-10"
  tasks_completed: 2
  files_modified: 2
---

# Phase 18 Plan 02: Reviewer Interface check_mode and Depth Configuration Summary

**One-liner:** Reviewer interface extended with check_mode parameter (full/structural) and SKILL.md updated with review_depth config schema, depth levels table, and defaults.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add check_mode to reviewer interface contract | ef0874f | skills/artifact-reviewer/rules/reviewer-interface.md |
| 2 | Update SKILL.md with depth configuration documentation | 3304312 | skills/artifact-reviewer/SKILL.md |

## What Was Built

**Task 1 — reviewer-interface.md:**
- Added `check_mode: "full" | "structural"` to Input Contract (after `review_context`, defaults to "full")
- Added `## Check Mode Behavior` section defining full vs structural modes
- Structural mode validates: required sections present, format valid, required fields non-empty
- Structural mode explicitly skips: content quality, cross-reference consistency, semantic correctness, depth of coverage
- Added QC check tagging rule: each reviewer MUST tag checks as `structural` or `content`
- Added reviewer responsibility: respect check_mode, skip content checks when structural

**Task 2 — SKILL.md:**
- Added `## Review Depth Configuration` section with config.json schema example
- Added Depth Levels table: deep (full QC, 2 passes), standard (full QC, 1 pass), quick (structural only, 1 pass)
- Documented defaults: absent config = all standard; missing entry = standard; empty object = all standard
- Updated orchestration step 4 to reference depth resolution from config.json
- Updated step 6 to say "required consecutive clean passes (depth-dependent)" instead of hardcoded 2

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. check_mode defaults to "full" (T-18-03 mitigation applied in interface contract). Audit trail records depth and check_mode per round via REVIEW-ROUNDS.md (T-18-04 mitigation — existing from review-loop.md).

## Self-Check: PASSED

- skills/artifact-reviewer/rules/reviewer-interface.md — FOUND, contains check_mode
- skills/artifact-reviewer/SKILL.md — FOUND, contains review_depth and Depth Levels
- Commit ef0874f — FOUND
- Commit 3304312 — FOUND

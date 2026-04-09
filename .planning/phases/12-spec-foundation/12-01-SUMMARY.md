---
phase: 12-spec-foundation
plan: "01"
subsystem: spec-templates-and-floor-hook
tags: [spec, templates, hooks, enforcement]
dependency_graph:
  requires: []
  provides: [templates/specs/SPEC.md.template, templates/specs/DESIGN.md.template, templates/specs/REQUIREMENTS.md.template, hooks/spec-floor-check.sh]
  affects: [hooks/hooks.json, silver-bullet.md, skills/silver/SKILL.md]
tech_stack:
  added: []
  patterns: [bash-hook-boilerplate, PreToolUse-deny, YAML-frontmatter-template]
key_files:
  created:
    - templates/specs/SPEC.md.template
    - templates/specs/DESIGN.md.template
    - templates/specs/REQUIREMENTS.md.template
    - hooks/spec-floor-check.sh
  modified: []
decisions:
  - SPEC.md template uses 8 canonical sections matching section names expected by downstream Phase 13/14 hooks
  - spec-floor-check.sh follows exact dev-cycle-check.sh boilerplate — same stdin parsing, emit_block, trap/umask pattern
  - Fast-path (gsd-fast/gsd-quick) issues advisory warning only — never hard-blocks — to preserve fast-path purpose
metrics:
  duration: ~5min
  completed: "2026-04-09"
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
---

# Phase 12 Plan 01: Spec Templates and Floor Hook — Summary

**One-liner:** Canonical SPEC.md/DESIGN.md/REQUIREMENTS.md templates plus spec-floor-check.sh hook that hard-blocks gsd-plan-phase without a minimum viable spec.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create spec template files in templates/specs/ | a39b5d0 | templates/specs/SPEC.md.template, DESIGN.md.template, REQUIREMENTS.md.template |
| 2 | Create spec-floor-check.sh hook | d63d7cc | hooks/spec-floor-check.sh |

## What Was Built

**Task 1 — Template files:**
- `templates/specs/SPEC.md.template`: YAML frontmatter (spec-version, status, jira-id, figma-url, source-artifacts, created, last-updated) + 8 sections: Overview, User Stories, UX Flows, Acceptance Criteria, Assumptions (with [ASSUMPTION:] block pattern), Open Questions, Out of Scope, Implementations
- `templates/specs/DESIGN.md.template`: YAML frontmatter + Screens, Components, Behavior Specifications (table), State Definitions (table), Design Tokens sections
- `templates/specs/REQUIREMENTS.md.template`: Functional Requirements table, Non-Functional Requirements table, Out of Scope, Open Items

**Task 2 — Enforcement hook:**
- `hooks/spec-floor-check.sh`: PreToolUse Bash hook using exact dev-cycle-check.sh boilerplate. Hard-blocks gsd-plan-phase when .planning/SPEC.md is missing or lacks `## Overview` / `## Acceptance Criteria`. Issues advisory warning (no block) for gsd-fast/gsd-quick. Checks both .planning/SPEC.md and .planning/SPEC.fast.md for fast-path. Completes in <100ms (file existence + grep only).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Template files contain placeholder text by design (they are templates, not populated documents).

## Threat Flags

None. All threat mitigations from the plan's threat model were implemented:
- T-12-03: `trap 'exit 0' ERR` present — no unexpected failure can block tool calls
- T-12-04: `umask 0077` present — file permissions restricted

Note: hooks.json registration (Pattern 3 from research) is NOT part of this plan. The research document explicitly noted hooks.json is self-protected and registration requires a manual step or silver:init. This plan (12-01) correctly scopes to templates and hook file creation only — registration is a separate concern for Plan 12-03 or silver:init.

## Self-Check

- [x] templates/specs/SPEC.md.template exists with spec-version:, ## Overview, ## Acceptance Criteria, [ASSUMPTION:]
- [x] templates/specs/DESIGN.md.template exists with ## Screens, ## Components, ## Behavior Specifications, ## State Definitions
- [x] templates/specs/REQUIREMENTS.md.template exists with ## Functional Requirements, ## Non-Functional Requirements
- [x] hooks/spec-floor-check.sh exists and is executable (-x)
- [x] Commits a39b5d0 and d63d7cc exist in git log

## Self-Check: PASSED

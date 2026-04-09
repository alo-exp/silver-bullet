---
phase: 16-new-artifact-reviewers
plan: "01"
subsystem: artifact-reviewers
tags: [reviewer, spec, design, requirements, roadmap, artifact-review]
dependency_graph:
  requires: [15-02]
  provides: [review-spec, review-design, review-requirements, review-roadmap]
  affects: [skills/artifact-reviewer/SKILL.md]
tech_stack:
  added: []
  patterns: [reviewer-interface, 2-pass-review-loop, structured-findings]
key_files:
  created:
    - skills/review-spec/SKILL.md
    - skills/review-design/SKILL.md
    - skills/review-requirements/SKILL.md
    - skills/review-roadmap/SKILL.md
  modified:
    - skills/artifact-reviewer/SKILL.md
decisions:
  - "SPEC reviewer uses 7 QC checks covering sections, overview quality, user story format, AC testability, assumption status, frontmatter, and source input cross-reference"
  - "DESIGN reviewer checks orphaned components against linked SPEC.md as a cross-artifact consistency gate"
  - "REQUIREMENTS reviewer checks REQ-ID uniqueness and format in addition to testability, making duplicate IDs machine-detectable"
  - "ROADMAP reviewer builds full dependency graph to detect circular and backward phase dependencies"
metrics:
  duration: 166s
  completed: "2026-04-09"
  tasks: 2
  files: 5
---

# Phase 16 Plan 01: New Artifact Reviewers (SPEC, DESIGN, REQUIREMENTS, ROADMAP) Summary

4 new SB artifact reviewer skills created — SPEC.md, DESIGN.md, REQUIREMENTS.md, and ROADMAP.md reviewers — each conforming to the artifact-reviewer framework interface with structured PASS/ISSUES_FOUND output and ISSUE-severity findings for every quality criterion violation.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create SPEC.md and DESIGN.md reviewer skills | da2a795 | skills/review-spec/SKILL.md, skills/review-design/SKILL.md |
| 2 | Create REQUIREMENTS.md and ROADMAP.md reviewer skills, update mapping table | d33e08d | skills/review-requirements/SKILL.md, skills/review-roadmap/SKILL.md, skills/artifact-reviewer/SKILL.md |

## What Was Built

### review-spec (ARVW-01)
7 quality criteria covering: required sections (Overview, User Stories, UX Flows, Acceptance Criteria, Assumptions, Open Questions, Out of Scope, Implementations), non-empty overview with problem statement, user story "As a/I want/so that" format, testable acceptance criteria, assumption Status fields, frontmatter completeness (spec-version, status, created, last-updated), and JIRA/Figma source input cross-reference. Finding prefix: `SPEC-F`.

### review-design (ARVW-02)
7 quality criteria covering: required sections (Screens, Components, Behavior Specifications, State Definitions), non-empty Screen fields (Purpose, Entry point, Exit points), non-empty Component fields (Type, State variants, Behavior), Behavior Specifications table with at least 1 real row, State Definitions table with at least 1 real row, orphaned component detection against linked SPEC.md, and frontmatter linked-spec field. Finding prefix: `DESIGN-F`.

### review-requirements (ARVW-03)
7 quality criteria covering: required sections (Functional Requirements, Non-Functional Requirements, Out of Scope, Open Items), REQ-ID format correctness (REQ-nn/NFR-nn pattern), REQ-ID uniqueness across the entire document, testable acceptance criteria and metrics (no vague language), Priority field presence and validity (P1/P2/P3), traceability via "Derived from" field, and SPEC acceptance criterion coverage cross-check. Finding prefix: `REQ-F`.

### review-roadmap (ARVW-04)
6 quality criteria covering: required phase fields (Goal, Depends on, Requirements, Success Criteria), 100% requirement coverage (every REQ-ID in requirements file appears in at least one phase), no phantom requirements (phase-referenced IDs must exist in requirements file), phase dependency correctness (no circular or backward dependencies), success criteria derivation traceability, and Plans field completeness (completed phases list plans; upcoming phases have at least TBD). Finding prefix: `ROAD-F`.

### Mapping Table Updated
`skills/artifact-reviewer/SKILL.md` rows for SPEC.md, DESIGN.md, REQUIREMENTS.md, ROADMAP.md updated from `(Phase 16)` placeholders to actual reviewer skill names: `review-spec`, `review-design`, `review-requirements`, `review-roadmap`.

## Decisions Made

- SPEC reviewer uses 7 QC checks covering sections, overview quality, user story format, AC testability, assumption status, frontmatter, and source input cross-reference
- DESIGN reviewer checks orphaned components against linked SPEC.md as a cross-artifact consistency gate
- REQUIREMENTS reviewer checks REQ-ID uniqueness and format in addition to testability, making duplicate IDs machine-detectable
- ROADMAP reviewer builds full dependency graph to detect circular and backward phase dependencies

## Deviations from Plan

None — plan executed exactly as written. All 4 reviewers created with criteria matching ARVW-01 through ARVW-04. Mapping table updated.

## Known Stubs

None — all reviewer skills are fully specified with complete quality criteria and finding structures. No placeholder content.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. All 4 files are read-only markdown skill definitions.

## Self-Check: PASSED

Files exist:
- skills/review-spec/SKILL.md: FOUND
- skills/review-design/SKILL.md: FOUND
- skills/review-requirements/SKILL.md: FOUND
- skills/review-roadmap/SKILL.md: FOUND

Commits exist:
- da2a795: FOUND
- d33e08d: FOUND

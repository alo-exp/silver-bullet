---
phase: 29-help-center-homepage
plan: 01
subsystem: site
tags: [homepage, help-center, composable-paths, documentation]
dependency_graph:
  requires: []
  provides: [updated-homepage, composable-paths-concept-page, artifact-review-assessor-concept-page]
  affects: [site/index.html, site/help/concepts/]
tech_stack:
  added: []
  patterns: [static-html, composable-paths-architecture]
key_files:
  created:
    - site/help/concepts/composable-paths.html
    - site/help/concepts/artifact-review-assessor.html
  modified:
    - site/index.html
    - site/help/concepts/routing-logic.html
    - site/help/concepts/verification.html
    - site/help/concepts/documentation.html
    - site/help/concepts/index.html
decisions:
  - "Hero pills updated to show '18 Composable Paths' replacing '20 + 24 Steps'"
  - "Solution section feature cards replaced with composable architecture messaging (4 new cards)"
  - "composable-paths.html includes full 18-path table from composable-paths-contracts.md"
  - "artifact-review-assessor.html uses custom verdict badge CSS matching page style"
  - "concepts/index.html gets a new 'Composable Paths' section before 'Routing & Behavior'"
metrics:
  duration_minutes: 25
  completed_date: "2026-04-14T16:02:55Z"
  tasks_completed: 2
  files_modified: 7
---

# Phase 29 Plan 01: Help Center + Homepage — Summary

Homepage and help center updated to reflect composable paths architecture: 18-path catalog in meta tags, hero, and feature cards; two new concept pages educating users on composable paths and the artifact review assessor.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Update homepage for composable paths architecture | 1c2d062 | site/index.html |
| 2 | Create/update concept pages | 35e2f6e | 6 files |

## What Was Built

### Task 1 — Homepage Updates (D-01 through D-04)

**Meta tags (D-01):** Title updated to "Composable Paths Architecture for AI-native Software Engineering & DevOps". Description and all OG/Twitter meta tags reference 18 composable paths, dynamic composition, dual-mode quality gates, WORKFLOW.md tracking, and 3-tier silver-fast triage.

**Hero section (D-02):** Version badge updated to "Composable Paths Architecture". Subtitle rewritten to describe 18 composable paths and dynamic composition. Hero pills updated: "20 + 24 Steps" replaced with "18 Composable Paths".

**Workflow section (D-03):** Section heading updated to "18 Composable Paths. Every Step Enforced." Section description updated to describe path composition replacing fixed pipelines, enforced via WORKFLOW.md supervision loop.

**Feature cards (D-04):** Solution section's 4 feature cards completely rewritten:
1. "18 Composable Paths" — explains dynamic composition from 18-path catalog
2. "WORKFLOW.md Real-Time Tracking" — explains per-composition state tracking
3. "Dual-Mode Quality Gates" — explains PATH 12 running twice (pre-plan + pre-ship)
4. "3-Tier silver-fast Triage" — explains trivial bypass with scope expansion re-routing

Additional references in comparison table and install callout also updated.

### Task 2 — Concept Pages (D-05 through D-09 + D-33)

**composable-paths.html (D-05):** New concept page with full 18-path table (PATH 0 BOOTSTRAP through PATH 17 RELEASE), composition steps (context classification → path selection → chain ordering → proposal), WORKFLOW.md tracking section, and supervision loop section.

**artifact-review-assessor.html (D-06):** New concept page explaining assessor triage: MUST-FIX / NICE-TO-HAVE / DISMISS verdicts, the 5-step review cycle, and all 8 reviewer contexts where the assessor runs (ROADMAP, REQUIREMENTS, SPEC, CONTEXT, RESEARCH, PLAN, UAT, code review).

**routing-logic.html (D-07):** Overview section updated to describe path composition after complexity triage. "fixed workflow dispatch" replaced with "path composition" framing. See Also section adds link to composable-paths.html.

**verification.html (D-08):** New section "PATH 11 VERIFY and Dual-Mode Quality Gates" added before See Also. Explains PATH 11 VERIFY (non-skippable, produces UAT.md + VERIFICATION.md) and PATH 12 QUALITY GATE dual-mode (design-time checklist + adversarial audit). See Also updated with composable-paths.html link.

**documentation.html (D-09):** New section "PATH 16 DOCUMENT and WORKFLOW.md" added before See Also. Explains PATH 16 steps and distinguishes project-level docs (three-layer scheme) from WORKFLOW.md (composition-level, ephemeral). See Also updated with composable-paths.html link.

**concepts/index.html (D-33):** New "Composable Paths" section added before "Routing & Behavior" with two concept cards (composable-paths.html and artifact-review-assessor.html). Sidebar navigation updated with new section and links.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All pages contain fully wired content sourced from docs/composable-paths-contracts.md.

## Threat Flags

None. Static HTML documentation site, no new network endpoints, no auth paths, no sensitive data.

## Self-Check: PASSED

- site/index.html: exists, modified — FOUND
- site/help/concepts/composable-paths.html: FOUND (created)
- site/help/concepts/artifact-review-assessor.html: FOUND (created)
- site/help/concepts/routing-logic.html: FOUND, contains "composable"
- site/help/concepts/verification.html: FOUND, contains "PATH 11" and "dual-mode"
- site/help/concepts/documentation.html: FOUND, contains "PATH 16" and "WORKFLOW.md"
- site/help/concepts/index.html: FOUND, contains hrefs to both new pages
- Commit 1c2d062: FOUND (Task 1)
- Commit 35e2f6e: FOUND (Task 2)

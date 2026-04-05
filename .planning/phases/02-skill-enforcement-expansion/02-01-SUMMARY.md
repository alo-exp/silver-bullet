---
phase: 02-skill-enforcement-expansion
plan: 01
subsystem: workflows
tags: [skill-enforcement, full-dev-cycle, tdd, tech-debt, accessibility, silver-bullet]

# Dependency graph
requires: []
provides:
  - /accessibility-review skill gate in DISCUSS UI conditional (REQUIRED when UI work)
  - /test-driven-development skill gate in EXECUTE step 6 (REQUIRED, replaces prose)
  - /tech-debt skill gate in FINALIZATION step 14 (REQUIRED, replaces inline prose)
  - 4 new skills in all_tracked (test-driven-development, tech-debt, accessibility-review, incident-response)
  - 2 new skills in required_deploy (test-driven-development, tech-debt)
affects: [completion-audit, skill-discovery, full-dev-cycle-execution]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Skill invocations with REQUIRED markers replace inline prose descriptions in workflow steps"
    - "Conditional skills (accessibility-review, incident-response) tracked in all_tracked but NOT required_deploy"

key-files:
  created: []
  modified:
    - docs/workflows/full-dev-cycle.md
    - templates/workflows/full-dev-cycle.md
    - .silver-bullet.json

key-decisions:
  - "test-driven-development and tech-debt added to required_deploy (hard enforcement gates for all dev work)"
  - "accessibility-review and incident-response in all_tracked only (conditional skills — not universally required)"
  - "TDD prose line removed from EXECUTE step 6 — replaced by /test-driven-development skill invocation"
  - "Tech-debt notes inline prose removed from FINALIZATION step 14 — replaced by /tech-debt skill invocation"

patterns-established:
  - "Skill invocation pattern: /skill-name — description   **REQUIRED** <- DO NOT SKIP (right-aligned ~col 80)"

requirements-completed: [SB-R2]

# Metrics
duration: 2min
completed: 2026-04-05
---

# Phase 02 Plan 01: Skill Enforcement Expansion (Full Dev Cycle) Summary

**Three enforcement gaps closed in full-dev-cycle: /accessibility-review for UI work, /test-driven-development replacing TDD prose, /tech-debt replacing inline notes — plus 4 new skills wired into .silver-bullet.json tracking**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-05T00:40:36Z
- **Completed:** 2026-04-05T00:42:06Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added `/accessibility-review` to the DISCUSS UI conditional with `REQUIRED when UI work` marker
- Replaced "TDD principles apply" prose in EXECUTE step 6 with `/test-driven-development` skill invocation and `REQUIRED` marker
- Replaced "Tech-debt notes (inline)" in FINALIZATION step 14 with `/tech-debt` skill invocation and `REQUIRED` marker
- Updated `.silver-bullet.json`: 4 skills added to `all_tracked`, 2 added to `required_deploy`
- Mirrored all changes to `templates/workflows/full-dev-cycle.md` (byte-for-byte identical to docs/)

## Task Commits

Each task was committed atomically:

1. **Task 1: Update full-dev-cycle.md — three skill insertions** - `e9647be` (feat)
2. **Task 2: Update .silver-bullet.json — 4 skills to all_tracked, 2 to required_deploy** - `fc327ca` (feat)
3. **Task 3: Mirror full-dev-cycle changes to templates/** - `26a893f` (feat)

**Plan metadata:** (docs commit — pending)

## Files Created/Modified
- `docs/workflows/full-dev-cycle.md` - 3 skill gates added (accessibility-review, test-driven-development, tech-debt)
- `templates/workflows/full-dev-cycle.md` - Mirror of docs/ — identical changes applied
- `.silver-bullet.json` - required_deploy +2, all_tracked +4

## Decisions Made
- `test-driven-development` and `tech-debt` added to `required_deploy` — these apply to all development work universally, so hard blocking is appropriate
- `accessibility-review` and `incident-response` added to `all_tracked` only — conditional skills that apply when UI work is present or an incident occurs, not every dev cycle
- Old TDD prose and Tech-debt inline notes removed entirely — the skill invocations replace them, no duplication

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- Plan 02-02 (devops-cycle enforcement) can proceed — these changes are independent
- completion-audit.sh will now block commits when test-driven-development or tech-debt are skipped
- Skill discovery will surface accessibility-review and incident-response for relevant tasks

---
*Phase: 02-skill-enforcement-expansion*
*Completed: 2026-04-05*

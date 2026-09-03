---
phase: 049-silver-add
plan: 01
subsystem: skills
tags: [silver-add, issue-tracking, github-issues, project-board, classification, skill-authoring]

# Dependency graph
requires: []
provides:
  - skills/silver-add/SKILL.md — complete silver-add skill with 7-step filing workflow
  - docs/issues/ file location and SB-I-N / SB-B-N ID schema established
  - _github_project cache schema under .silver-bullet.json
  - silver-add listed in skills.all_tracked in both config files
affects: [050-silver-remove, 051-auto-capture, 054-silver-scan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "jq + tmpfile + mv atomic write for .silver-bullet.json cache updates"
    - "gh CLI two-step board placement: gh project item-add + gh project item-edit"
    - "Sequential ID derivation: grep -oE 'SB-I-[0-9]+' | sort -n | tail -1"
    - "Exponential backoff retry: 60s/120s/240s, max 3 retries on 403/429"
    - "Session log ## Items Filed section: graceful handling of old and new template"

key-files:
  created:
    - skills/silver-add/SKILL.md
  modified:
    - .silver-bullet.json
    - templates/silver-bullet.config.json.default

key-decisions:
  - "Local issue files use docs/issues/ISSUES.md and docs/issues/BACKLOG.md (not docs/ root) — matches REQUIREMENTS.md ADD-03 and ARCHITECTURE.md"
  - "_github_project uses underscore prefix (not github_project) to signal derived/cached field, not user-configurable"
  - "silver-add placed after silver-forensics in all_tracked array to keep silver-* skills grouped"
  - "Classification default is backlog when ambiguous — prevents over-alarming with issues"
  - "Minimum bar criterion prevents noise items during auto-capture (no transient TODOs)"

patterns-established:
  - "Pattern: docs/issues/ subdirectory for all local tracking files (ISSUES.md, BACKLOG.md)"
  - "Pattern: SB-I-N for issues, SB-B-N for backlog — sequential, never renumbered"
  - "Pattern: _github_project cache in .silver-bullet.json — write once on discovery, read-only thereafter"

requirements-completed: [ADD-01, ADD-02, ADD-03, ADD-04, ADD-05]

# Metrics
duration: 3min
completed: 2026-04-24
---

# Phase 049 Plan 01: silver-add Summary

**silver-add SKILL.md written: 7-step skill that classifies items as issue/backlog and files to GitHub Issues+board or local docs/issues/ with SB-I-N/SB-B-N IDs and exponential backoff retry**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-24T09:34:23Z
- **Completed:** 2026-04-24T09:37:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `skills/silver-add/SKILL.md` (370 lines, 7 steps) — complete classification-and-filing workflow with security boundary, classification rubric with minimum bar, GitHub and local routing paths, _github_project cache with atomic jq write, exponential backoff retry (60s/120s/240s), session log ## Items Filed append, and full edge case coverage
- Added `"silver-add"` to `skills.all_tracked` in `.silver-bullet.json` (position 25, after silver-forensics)
- Added `"silver-add"` to `skills.all_tracked` in `templates/silver-bullet.config.json.default` (same position, mirroring primary config)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write skills/silver-add/SKILL.md** - `12afec6` (feat)
2. **Task 2: Add silver-add to skills.all_tracked in both config files** - `fc40431` (feat)

**Plan metadata:** see final docs commit below

## Files Created/Modified
- `skills/silver-add/SKILL.md` - Complete silver-add skill instruction file (370 lines, 7 steps)
- `.silver-bullet.json` - Added "silver-add" to skills.all_tracked after silver-forensics
- `templates/silver-bullet.config.json.default` - Same addition, mirroring primary config

## Decisions Made
- Local issue files use `docs/issues/ISSUES.md` and `docs/issues/BACKLOG.md` subdirectory (not `docs/` root) — confirmed by REQUIREMENTS.md ADD-03 and ARCHITECTURE.md as authoritative over earlier STACK.md draft
- `_github_project` uses underscore prefix to signal derived/cached field vs user-configurable settings
- Classification default is backlog when ambiguous — prevents over-alarming with unnecessary issues
- Minimum bar criterion added to prevent noise from auto-capture (transient exploration notes, one-line TODOs without context, items already addressed in session)
- Concurrency warning added: "Do not call silver-add concurrently from parallel agent contexts"

## Deviations from Plan

None — plan executed exactly as written. All SKILL.md structure, security boundary, steps, classification rubric, GitHub path (Steps 4a-4e), local path (Steps 5a-5e), session log step, and edge cases implemented as specified.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `skills/silver-add/SKILL.md` is complete and ready for Phase 50 (silver-remove) to reference the docs/issues/ path and ID schema
- Phase 51 (auto-capture enforcement) can reference this skill by name in silver-bullet.md enforcement §3b
- Phase 54 (silver-scan) depends on the SB-I-N / SB-B-N ID schema established here
- The `_github_project` cache schema is defined and will be populated on first /silver-add invocation with issue_tracker=github

## Self-Check: PASSED

- FOUND: skills/silver-add/SKILL.md
- FOUND: .silver-bullet.json
- FOUND: templates/silver-bullet.config.json.default
- FOUND: 049-01-SUMMARY.md
- FOUND: commit 12afec6 (Task 1)
- FOUND: commit fc40431 (Task 2)

---
*Phase: 049-silver-add*
*Completed: 2026-04-24*

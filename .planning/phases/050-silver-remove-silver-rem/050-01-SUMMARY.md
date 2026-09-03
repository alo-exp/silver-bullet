---
phase: 050-silver-remove-silver-rem
plan: "01"
subsystem: skills
tags: [silver-remove, skill-authoring, gh-cli, sed, markdown-mutation, github-issues]

# Dependency graph
requires:
  - phase: 049-silver-add
    provides: "ID schema (SB-I-N/SB-B-N), heading format, config read pattern, allowed-commands structure locked by silver-add SKILL.md"
provides:
  - "skills/silver-remove/SKILL.md — GitHub issue close (not planned) + removed-by-silver-bullet label + local SB-I-N/SB-B-N inline [REMOVED YYYY-MM-DD] marker"
  - "silver-remove registered in skills.all_tracked in .silver-bullet.json and templates/silver-bullet.config.json.default"
affects:
  - 050-02-PLAN (silver-rem skill — adds silver-rem to all_tracked)
  - 054-silver-scan (deduplication depends on removed-by-silver-bullet label to recognize SB-removed issues)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SKILL.md structure: frontmatter + Security Boundary + Allowed Commands + numbered steps + Edge Cases (established by Phase 49, reinforced here)"
    - "Idempotent label creation: gh label create ... 2>/dev/null || true before label-dependent steps"
    - "Anchored sed pattern: ^### ${ITEM_ID} — prevents body-text false matches"
    - "Post-sed verification grep confirms replacement before reporting success"

key-files:
  created:
    - "skills/silver-remove/SKILL.md"
  modified:
    - ".silver-bullet.json (skills.all_tracked)"
    - "templates/silver-bullet.config.json.default (skills.all_tracked)"

key-decisions:
  - "silver-remove closes GitHub issues (gh issue close --reason 'not planned') rather than deleting — GitHub REST/GraphQL API requires delete_repo scope for deletion; close is the correct primitive"
  - "ID routing is prefix-based (SB-I vs SB-B) — file path derived only from prefix, never from user input directly (prevents path traversal, T-050-02)"
  - "Integer ID with issue_tracker=gsd returns error, does not silently fall through — clarity over permissiveness"
  - "ITEM_ID validated via case statement before use in sed or gh commands (mitigates T-050-01)"

patterns-established:
  - "silver-remove GitHub path: label idempotent create → gh issue close --reason 'not planned' → gh issue edit --add-label (three-step sequence, all three required)"
  - "silver-remove local path: prefix routing → file existence check → grep pre-check → anchored sed → grep verification (five sub-steps, fail fast on any)"

requirements-completed:
  - REM-01
  - REM-02

# Metrics
duration: 2min
completed: 2026-04-24
---

# Phase 50 Plan 01: silver-remove SKILL.md Summary

**silver-remove SKILL.md: GitHub issue close as "not planned" with removed-by-silver-bullet label + local SB-I-N/SB-B-N inline [REMOVED YYYY-MM-DD] heading mutation via anchored BSD sed**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-24T10:03:02Z
- **Completed:** 2026-04-24T10:05:22Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Wrote 202-line `skills/silver-remove/SKILL.md` covering both GitHub and local removal paths with Security Boundary, Allowed Commands, 6 numbered steps, and Edge Cases
- GitHub path: idempotent label creation + `gh issue close --reason "not planned"` + `gh issue edit --add-label "removed-by-silver-bullet"` (three-step atomic sequence)
- Local path: SB-I/SB-B prefix routing to correct file, pre-check grep, anchored `sed -i ''` replacement, post-sed verification grep — body text fully preserved
- Added `"silver-remove"` to `skills.all_tracked` in both `.silver-bullet.json` and `templates/silver-bullet.config.json.default` via atomic jq + tmpfile + mv

## Task Commits

Each task was committed atomically:

1. **Task 1: Write skills/silver-remove/SKILL.md** - `8b10820` (feat)
2. **Task 2: Add silver-remove to skills.all_tracked in both config files** - `7f41320` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `skills/silver-remove/SKILL.md` - New skill: remove tracked items by ID (GitHub close or local inline marker)
- `.silver-bullet.json` - Added "silver-remove" to skills.all_tracked (exactly once)
- `templates/silver-bullet.config.json.default` - Added "silver-remove" to skills.all_tracked (exactly once)

## Decisions Made

- **Close, not delete**: GitHub REST/GraphQL API requires `delete_repo` scope for deletion which most users don't have. `gh issue close --reason "not planned"` is the correct primitive — documented explicitly so users understand the behavior.
- **Integer ID with gsd tracker → error**: When `issue_tracker=gsd` and user passes a plain integer, returning an error with guidance ("use SB-I-N or SB-B-N format") is clearer than silently failing or trying GitHub anyway.
- **Separate `gh issue edit` call for label**: `gh issue close` does not accept `--add-label` — label must be applied in a separate `gh issue edit` call. Idempotent label creation precedes both steps.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The SKILL.md is prose instructions; it does not execute at write time. All threat mitigations from the plan's threat model are present in the SKILL.md Security Boundary section (T-050-01: anchored sed; T-050-02: prefix-based file routing).

## Known Stubs

None — the SKILL.md is a complete, fully wired instruction set. No placeholder text, no hardcoded empty values, no "coming soon" markers.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `skills/silver-remove/SKILL.md` complete and committed — users can invoke `/silver-remove` immediately
- `skills.all_tracked` updated in both config files — enforcement hooks will recognize silver-remove
- Plan 050-02 can proceed: add `silver-rem` skill and register `silver-rem` (and `silver-rem` alias) in `all_tracked`

---

*Phase: 050-silver-remove-silver-rem*
*Completed: 2026-04-24*

## Self-Check: PASSED

- `skills/silver-remove/SKILL.md` exists: FOUND
- Commit `8b10820` exists: FOUND (Task 1)
- Commit `7f41320` exists: FOUND (Task 2)
- Both config files contain "silver-remove" in all_tracked: VERIFIED
- Both config files are valid JSON: VERIFIED

---
phase: 13-ingestion-multi-repo
plan: "02"
subsystem: silver-router, silver-bullet-template
tags: [routing, multi-repo, mcp, ingestion, version-validation]
dependency_graph:
  requires: [13-01]
  provides: [silver-ingest routing, REPO-02 validation, REPO-03/04 conventions, MCP prereq docs]
  affects: [skills/silver/SKILL.md, templates/silver-bullet.md.base]
tech_stack:
  added: []
  patterns: [session-start version gating, read-only cache pattern, MCP connector table]
key_files:
  modified:
    - skills/silver/SKILL.md
    - templates/silver-bullet.md.base
decisions:
  - "Multi-repo version check placed at §0 step 5.5 (after tool version checks) so it runs on every session start"
  - "Version check is best-effort: gh CLI failure emits warning rather than blocking (T-13-06 mitigation)"
  - "Cross-repo conventions placed in §2k alongside spec lifecycle content (§2i/2j) for discoverability"
metrics:
  duration: "8 minutes"
  completed: "2026-04-09T10:33:39Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 13 Plan 02: Wire silver-ingest into SB Ecosystem Summary

silver-ingest is now routable via /silver and enforces cross-repo spec version consistency at every session start, with MCP connector documentation and cross-repo workflow conventions added to silver-bullet.md.base.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Add silver-ingest routing entry to /silver router | bc032ca |
| 2 | Add session-start version validation, MCP prereqs, cross-repo conventions to silver-bullet.md.base | 112284e |

## What Was Built

**Task 1 — /silver router (skills/silver/SKILL.md):**
- Added `silver:ingest` to the routing table with intent patterns: "ingest", "import", "jira", "figma", "pull ticket", "cross-repo", "fetch spec from"
- Added `silver:ingest` as option H in the ambiguous-input clarification menu (Step 3)

**Task 2 — silver-bullet.md.base:**
- Added §0 step 5.5: Multi-Repo Spec Validation — reads SPEC.main.md spec-version, fetches remote version via gh CLI, blocks session on mismatch with explicit `/silver:ingest --source-url` refresh instruction (REPO-02)
- gh CLI failure produces a warning ("proceed with caution") rather than a hard block (T-13-06 threat mitigation)
- Added §2j: MCP Connector Prerequisites table documenting Atlassian MCP (streamable HTTP, SSE deprecated 2026-06-30), Figma MCP, Google Drive MCP — all non-blocking
- Added §2k: Cross-Repo Spec Workflow conventions (REPO-03: main repo specs first; REPO-04: mobile-exclusive follows standard SB; SPEC.main.md is read-only cache)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints or trust boundaries introduced beyond what the plan's threat model already covers.

## Self-Check: PASSED

- skills/silver/SKILL.md: FOUND
- templates/silver-bullet.md.base: FOUND
- Commit bc032ca: FOUND
- Commit 112284e: FOUND

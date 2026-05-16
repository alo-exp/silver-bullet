---
gsd_state_version: 1.0
milestone: v0.35.4
milestone_name: Agents Directory Reorg
status: planning
last_updated: "2026-05-16T07:37:49.017Z"
last_activity: 2026-05-16
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

**Project:** Silver Bullet
**Current version:** v0.35.3 (release line shipped)
**Active milestone:** v0.35.4 Agents Directory Reorg
**Current plan:** none

Last activity: 2026-05-16

## Project Reference

Silver Bullet keeps the canonical `skills/` source tree and generates runtime-specific bundles under `agents/<agent>/...` for Claude and Codex.

See:
- `.planning/PROJECT.md`
- `.planning/MILESTONES.md`
- `.planning/ROADMAP.md`

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-16 — Milestone v0.35.4 started

## Pending Todos

- Render and commit `agents/claude` and `agents/codex` from the canonical `skills/` tree.
- Rewire Codex and Claude install/sync paths to consume the generated agent bundles.
- Update docs, tests, and compatibility aliases for the new layout.
- Verify with focused tests, the full suite, and live e2e before release.

## Session Continuity

Last session: 2026-05-16
Stopped at: restarting from handoff, clearing stale GSD state, and beginning the agents-directory reorg

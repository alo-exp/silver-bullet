---
phase: 18-configurable-review-depth
plan: "01"
subsystem: artifact-reviewer
tags: [review-loop, config, depth, quality-control]
dependency_graph:
  requires: []
  provides: [review_depth-config-schema, depth-aware-review-loop]
  affects: [skills/artifact-reviewer/rules/review-loop.md, .planning/config.json]
tech_stack:
  added: []
  patterns: [depth-resolution, configurable-pass-counts, structural-vs-full-checks]
key_files:
  created: []
  modified:
    - .planning/config.json
    - skills/artifact-reviewer/rules/review-loop.md
decisions:
  - "Empty review_depth object in config.json means all artifact types default to standard (1 pass, full QC)"
  - "resolve_depth() always falls back to standard when config is absent or has no entry for the reviewer"
  - "check_mode=structural passed to reviewer invocation so reviewers can skip content quality checks for quick depth"
metrics:
  duration: "10m"
  completed: "2026-04-10"
  tasks_completed: 2
  files_modified: 2
---

# Phase 18 Plan 01: Configurable Review Depth Summary

Depth-aware review loop with config.json schema: deep=2 passes full QC, standard=1 pass full QC (default), quick=1 pass structural only.

## What Was Built

**config.json schema:** Added `review_depth` empty object and `_review_depth_help` documentation key to `.planning/config.json`. The empty object means all artifact types default to `standard` depth per ARVW-11e.

**Depth-aware review loop:** Rewrote Section 1 of `review-loop.md` to:
1. Add "Depth Resolution" subsection explaining how depth is read from `config.json[review_depth][reviewer_skill_name]` with fallback to `"standard"` at every failure point (no config, no key, no entry)
2. Add `resolve_depth()` pseudocode function
3. Replace hardcoded `while consecutive_passes < 2` with `required_passes = 2 if depth == "deep" else 1`
4. Add `check_mode = "structural" if depth == "quick" else "full"` passed to `invoke_reviewer()`
5. Update display messages to include depth name and required_passes count
6. Update audit trail format (Section 3) to include Depth and Check mode fields, and `{count}/{required_passes}` instead of hardcoded `/2`
7. Update Key Rules to document all three depth levels and structural check restriction

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | e06e773 | feat(18-01): add review_depth config schema to config.json |
| 2 | c7d0a2f | feat(18-01): update review-loop.md with depth-aware algorithm |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

1. config.json contains valid `review_depth` empty object — PASS (python3 assertion)
2. review-loop.md references resolve_depth, required_passes, check_mode, structural — PASS (grep count >= 4)
3. Default depth is "standard" when no config entry — confirmed via resolve_depth() fallback logic
4. "deep" requires 2 consecutive clean passes — confirmed via `required_passes = 2 if depth == "deep" else 1`
5. "quick" passes check_mode="structural" — confirmed via `check_mode = "structural" if depth == "quick" else "full"`

## Self-Check: PASSED

- `.planning/config.json` — exists, contains review_depth
- `skills/artifact-reviewer/rules/review-loop.md` — exists, depth-aware algorithm present
- Commit e06e773 — verified
- Commit c7d0a2f — verified

---
seed_id: SEED-006
title: Cross-surface docs audit (README, website, help center, GitHub topics)
github_issue: 70
priority: low
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - Before any major version bump (v0.40.0+) where the public surface needs to look fresh
  - A user reports specific stale content (install command, version reference, CHANGELOG gap)
  - A documentation contributor wants to volunteer
---

# SEED-006: Cross-surface docs audit

## Idea

Audit every public-facing surface against current SB state and refresh inconsistencies. Surfaces in scope: README.md, GitHub repo description + topics, the homepage, the help center articles, and the public CHANGELOG.

## Why This Matters

Public docs out of sync with code creates a credibility tax — users encountering one wrong reference distrust the rest. The audit is mechanical but tedious. Editorial choices (tone, structure, what to keep vs cut) need a human in the loop.

## When to Surface

- Before a major version bump where the marketing impression matters.
- When a user reports specific stale content; do the surrounding cleanup at the same time.
- When SB adds a new flagship feature and the README needs a feature spotlight refresh anyway.

## Implementation Sketch (when triggered)

1. Build a checklist: every install command, every version reference, every skill name, every hook name, every config field. Search each across all surfaces.
2. Catalog mismatches in a single doc (`docs/internal/docs-audit-<date>.md`).
3. Surface-by-surface: open a focused PR for each (README → one PR, website → another, help center → another). Avoid the giant-PR temptation.
4. After landing: add a CI check that asserts the README's "Latest version" reference matches `git describe --tags --abbrev=0`. Only that one check — broader staleness detection is too brittle.

## What Was Already Done in v0.30.0

The v0.30.0 sweep ([README.md](../../README.md)) added the SB-only install path (Path A vs Path B), addressing one specific complaint from the original issue. The full audit remains.

## Why Deferred

This is documentation work that needs editorial judgment, not just mechanical updates. It's worth doing well rather than as a side task in an unrelated milestone. Cap the scope and own it as a dedicated docs milestone when the time is right.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/70
- Companion: #74 (SB-only install path) — partial fix landed v0.30.0; this issue tracks the broader cross-surface pass.

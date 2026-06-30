---
name: "silver:release"
title: "Release"
description: >
  This skill should be used for SB-owned milestone release: silver:quality-gates -> audit -> gap closure (max 2x) -> docs -> silver:ship -> milestone archive -> silver:create-release
argument-hint: "<version or release description, e.g. v1.2.0>"
version: 0.3.0
---

# /silver:release — Milestone Release Composition Spec

SB-owned milestone publishing. Coordinates FLOW 18 (RELEASE) and nested FLOW 16–17.
Use `silver:ship` for phase-level PR/CI; use `silver:release` for versioned milestone
publish, changelog, tag, and GitHub Release.

**Canonical contracts:** `docs/composable-flows-contracts.md` (FLOW 16–18 + sub-steps).
Never publishes directly — writes release evidence before `silver:create-release`.

## Standard composition chain (FLOW vocabulary)

```
FLOW 13 (QUALITY GATE, release) → FLOW 12 (UAT audit evidence)
→ FLOW 18 (milestone audit + gap closure) → FLOW 11 (SECURE)
→ [FLOW 8 + FLOW 15 gap closure, max 2×] → FLOW 16 (DESIGN HANDOFF) [if UI]
→ FLOW 17 (DOCUMENT) → FLOW 10 (REVIEW) → FLOW 12 (VERIFY + verify-tests)
→ FLOW 14 (SHIP) → deploy/canary [if live rollout]
→ FLOW 18 (milestone archive) → silver:create-release (last)
```

See contracts § FLOW 18 sub-steps for artifact names (`RELEASE-UAT-AUDIT.md`,
`RELEASE-MILESTONE-AUDIT.md`, `MILESTONE-SUMMARY.md`, archive layout).

## Conditional insertions

| Signal | Insert |
|--------|--------|
| UI phases in milestone | FLOW 16 — `.planning/UI-HANDOFF.md` |
| Blocking audit gaps | Gap-closure loop (max 2) — nested composers as **sub-flows**; preserve release `SB_WORKFLOW_ID` |
| Deployment in release | `silver:deploy`, `silver:canary`, `silver:devops` as needed |
| Pre-release quality gate doc | `docs/internal/pre-release-quality-gate.md` 4-stage markers before tag |

## Orchestrator parent mode

When `orchestrator_mode` is `parent`, the autonomous queue runs the **delivery tail**
only (FLOW 13 → review → verify → secure → ship prep → `silver:create-release`).
Audit, UAT, milestone, and gap-closure steps remain **parent-driven** — complete them
before the delivery tail advances.

Delivery tail queue: `hooks/lib/orchestrator-state.sh` (`silver-release` composer).

## Context scan

Read when present: `STATE.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `SPEC.md`, `DESIGN.md`,
phase artifacts, `docs/task-doc-checklist.json`, `CHANGELOG.md`.

Detect UI scope via `UI-SPEC.md` / `UI-REVIEW.md` under `.planning/phases/`.

## Non-skippable gates

`silver:quality-gates`, `security`, FLOW 12 UAT audit, FLOW 18 milestone audit,
cross-artifact review when release artifacts exist, fresh `verify-tests`, `silver:verify`,
`silver:ship`, milestone archive before `silver:create-release`.

## Step-skip protocol

On skip request: explain → offer A/B/C → record permanent skips in `silver-bullet.md` +
`templates/silver-bullet.md.base`.

## Release execution summary

| Phase | FLOW | Key outputs |
|-------|------|-------------|
| Pre-release QG + domain audit | 13 | Quality + domain evidence |
| UAT audit | 12 | `RELEASE-UAT-AUDIT.md` |
| Milestone audit + security | 18 / 11 | `RELEASE-MILESTONE-AUDIT.md` |
| Gap closure | 8 / 15 | `RELEASE-GAP-CLOSURE.md` (≤2 loops) |
| Design handoff | 16 | `UI-HANDOFF.md` (conditional) |
| Document | 17 | `silver:ensure-docs`, `MILESTONE-SUMMARY.md` |
| Review + verify | 10 / 12 | Fresh tests + `silver:verify` |
| Ship | 14 | PR/CI via `silver:ship` |
| Archive + publish | 18 | Archive dir, tag, `silver:create-release` |

Before tag: run `scripts/sync-release-marketplace-versions.sh` per `silver:create-release`.

## Workflow tracking (fallback)

Resolve `scripts/workflows.sh`, start `/silver:release` with FLOW names from the chain,
export `SB_WORKFLOW_ID`, `complete-flow` per step, `complete` after `silver:create-release`.

## Post-release

Summarize issues/backlog/knowledge filed during milestone; optional `silver:retro` for
major releases.

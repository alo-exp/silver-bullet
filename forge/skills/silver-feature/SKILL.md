---
id: silver-feature
title: Silver — Feature Development Workflow
description: Full workflow: brainstorm → specify → quality-gate → plan → execute → verify → secure → ship
trigger:
  - "silver feature"
  - "feature workflow"
  - "full feature workflow"
  - "new feature"
---

# Silver Feature — Full Workflow

## Non-Skippable Gates
These cannot be omitted: pre-plan quality gates, verification, pre-ship quality gates, security.

## Path Chain (execute in order)

**PATH 1: ORIENT**
Read `.planning/STATE.md`, `.planning/ROADMAP.md`, and any existing specs for this feature area.

**PATH 2: BRAINSTORM**
Run brainstorming procedure (trigger: "brainstorm"). Document 2-3 approaches, recommend one, get approval.

**PATH 3: SPECIFY**
Write design doc to `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`. Ask user to review before continuing.

**PATH 4: QUALITY GATES (pre-plan) [NON-SKIPPABLE]**
Run all 9 quality dimensions (trigger: "quality gates") on the spec. Fix any ❌ before proceeding.

**PATH 5: PLAN**
Run gsd-plan procedure (trigger: "plan phase"). Write PLAN.md. Get user to review.

**PATH 6: EXECUTE**
Run gsd-execute procedure (trigger: "execute phase"). Atomic commits. TDD discipline.

**PATH 7: REVIEW**
Run gsd-review procedure (trigger: "code review"). Fix CRITICAL findings before continuing.

**PATH 8: VERIFY [NON-SKIPPABLE]**
Run gsd-verify procedure (trigger: "verify work"). VERIFICATION.md must show Status: PASSED.

**PATH 9: SECURITY [NON-SKIPPABLE]**
Run security quality dimension (trigger: "security"). Write SECURITY.md.

**PATH 10: QUALITY GATES (pre-ship) [NON-SKIPPABLE]**
Run all 9 quality dimensions in pre-ship mode. Fix any ❌.

**PATH 10b: DOC-SCHEME COMPLIANCE (conditional)**
Only if `docs/doc-scheme.md` exists: before raising the PR, verify:
1. `docs/CHANGELOG.md` — has an entry for this phase (newest-first). Write it if missing.
2. `docs/ARCHITECTURE.md` — does not say "in progress" for completed phases. Update if stale.
3. `docs/knowledge/YYYY-MM.md` — append architectural patterns, API gotchas, or key decisions if any.
4. `docs/lessons/YYYY-MM.md` — append portable lessons learned if any.
Do NOT proceed to PATH 11 until all four checks pass. If `docs/doc-scheme.md` does not exist, skip this path.

**PATH 11: SHIP**
Run gsd-ship procedure (trigger: "ship"). Create PR.

## Supervision Between Paths
After each path: verify its exit condition was met. If not: retry or document skip reason.
Report progress: "PATH X/11: <name> ✓ | Remaining: [list]"

## Session Logging
Track each path completion in `docs/sessions/YYYY-MM-DD.md`.

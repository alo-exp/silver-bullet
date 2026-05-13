# Roadmap: Silver Bullet v0.33.1 Open Issue Burn-down

**Goal:** Close the 22 open GitHub issues in the Silver Bullet repo by fixing the remaining init/docs/hooks gaps, reconciling already-shipped backlog items, clearing the todo-app duplicate cluster, and then shipping `v0.33.1`.

**Phase numbering:** Continues from Phase 86.

---

## Phases

### Phase 86: Runtime-Aware Bootstrap

**Requirements:** INIT-01..06

**Goal:** Make `silver:init` runtime-aware and brownfield-friendly so Codex, Claude, and GitHub-backed repos are detected correctly without manual correction.

**Issues targeted:** #144, #145, #146, #147, #148, #150

### Phase 87: Docs & Semantic Audit

**Requirements:** DOC-01

**Goal:** Upgrade `silver:ensure-docs` from structural reconciliation to a semantic audit that compares live docs against current code, hooks, workflows, and runtime behavior.

**Issues targeted:** #151

### Phase 88: Hook Inspection Ergonomics

**Requirements:** HOOK-01

**Goal:** Allow read-only inspection of Silver Bullet enforcement hooks during maintenance and audits without weakening write protection.

**Issues targeted:** #149

### Phase 89: Backlog Reconciliation

**Requirements:** TRACK-01

**Goal:** Close or reconcile already-shipped backlog items, starting with the `silver-handoff` issue and any other stale items that are already implemented in the current repo.

**Issues targeted:** #98

### Phase 90: Todo-App Clear-Completed Burn-down

**Requirements:** TRACK-02

**Goal:** Implement or retarget the todo-app clear-completed work in the sibling fixture repo, then collapse the duplicate GitHub issue cluster so the backlog only retains the canonical work item.

**Issues targeted:** #106, #107, #111, #112, #122, #127, #135, #137, #138, #140, #141, #142, #143

### Phase 91: Release v0.33.1

**Requirements:** REL-01..03

**Goal:** Bump release-facing version surfaces, run CI and the pre-release quality gate until two consecutive passes are clean, and create/publish the `v0.33.1` GitHub Release with structured notes.

**Issues targeted:** release packaging for the completed burn-down

---

## Progress

| Phase | Requirements | Status | Notes |
|-------|--------------|--------|-------|
| 86. Runtime-Aware Bootstrap | INIT-01..06 | Pending | Core init/runtime issue cluster |
| 87. Docs & Semantic Audit | DOC-01 | Pending | `silver:ensure-docs` scope gap |
| 88. Hook Inspection Ergonomics | HOOK-01 | Pending | Read-only hook inspection |
| 89. Backlog Reconciliation | TRACK-01 | Pending | Already-shipped issue closure |
| 90. Todo-App Clear-Completed Burn-down | TRACK-02 | Pending | Sibling fixture + duplicate collapse |
| 91. Release v0.33.1 | REL-01..03 | Pending | CI + pre-release gate + GitHub Release |

## Coverage Validation

- v1 requirements: 13/13 mapped
- Milestone phases: 6
- Open issues in scope: 22
- Unmapped requirements: 0 ✓

---
*Roadmap defined: 2026-05-13*
*Last updated: 2026-05-13 after v0.33.1 milestone start*

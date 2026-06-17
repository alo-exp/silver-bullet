---
name: "silver:plan"
title: "Plan"
description: This skill writes SB phase plans with dependencies, assumptions, waves, TDD policy, acceptance criteria, and verification steps.
argument-hint: "<phase or change description>"
version: 0.1.0
---

# /silver:plan - Phase Plan

SB-owned planning creates clear tasks, small waves, assumptions, dependencies,
verification criteria, and explicit handoff to execution.

Do not delegate core planning to an external lifecycle plugin. The PLAN.md
artifact is SB-owned.

## Output

Write or update `.planning/phases/<phase>/PLAN.md`. If no phase folder exists,
create the smallest sensible phase folder under `.planning/phases/`.

## Planning Modes

| Mode | When to use | How waves are organized |
|------|-------------|------------------------|
| Standard (default) | Most phases | Horizontal layers: shared infrastructure, then service/API, then UI/presentation |
| MVP vertical-slice (`--mvp`) | Phase 1 of a new project OR when the user asks for "walking skeleton" / "vertical slice" / "end-to-end from UI to DB" | Feature slices: each wave delivers a thin vertical cut (UI + API + DB) for one user-facing scenario. Prefer 2–3 slices per wave. Produces an optional `SKELETON.md` for phase 1 of a new project with no prior phases. |

Use `--mvp` when the user says "MVP", "vertical slice", "feature slice", "end-to-end first", or "walking skeleton". Default to standard otherwise.

## Process

1. Display `SILVER BULLET > PLAN`.
2. Read available project context: PROJECT, REQUIREMENTS, ROADMAP, STATE, SPEC,
   CONTEXT, VALIDATION, REVIEW, and prior phase summaries.
3. Determine planning mode from arguments or ROADMAP.md (`**Mode:** mvp` annotation).
4. Identify dependencies:
   - prerequisite files, migrations, APIs, data changes, and external services;
   - ordering constraints;
   - rollback or compatibility constraints;
   - unknowns that must be resolved before execution.
5. Produce implementation waves. Each wave must have:
   - goal;
   - concrete tasks;
   - expected files or areas;
   - acceptance criteria links;
   - test or verification evidence;
   - risks and rollback notes where relevant.
6. State TDD policy:
   - implementation logic requires `tdd` before code edits;
   - docs/config/infra-only work may skip application TDD but still needs
     verification evidence.
7. Add a verification plan that `silver:verify` can execute without inventing
   criteria later.
8. Surface every assumption and unresolved question from context.
9. In MVP mode, write `SKELETON.md` when this is phase 1 of a new project with
   no prior SUMMARY.md files. SKELETON.md describes the walking skeleton:
   the minimal end-to-end path from UI to data store that proves the system
   hangs together.

## Exit Gate

The plan is complete only when:

- every acceptance criterion has at least one planned task or an explicit
  out-of-scope decision;
- task order is executable;
- verification evidence is defined before execution starts;
- blockers are visible and not silently downgraded.

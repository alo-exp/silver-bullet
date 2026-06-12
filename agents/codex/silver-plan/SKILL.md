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

## Process

1. Display `SILVER BULLET > PLAN`.
2. Read available project context: PROJECT, REQUIREMENTS, ROADMAP, STATE, SPEC,
   CONTEXT, VALIDATION, REVIEW, and prior phase summaries.
3. Identify dependencies:
   - prerequisite files, migrations, APIs, data changes, and external services;
   - ordering constraints;
   - rollback or compatibility constraints;
   - unknowns that must be resolved before execution.
4. Produce implementation waves. Each wave must have:
   - goal;
   - concrete tasks;
   - expected files or areas;
   - acceptance criteria links;
   - test or verification evidence;
   - risks and rollback notes where relevant.
5. State TDD policy:
   - implementation logic requires `tdd` before code edits;
   - docs/config/infra-only work may skip application TDD but still needs
     verification evidence.
6. Add a verification plan that `silver:verify` can execute without inventing
   criteria later.
7. Surface every assumption and unresolved question from context.

## Exit Gate

The plan is complete only when:

- every acceptance criterion has at least one planned task or an explicit
  out-of-scope decision;
- task order is executable;
- verification evidence is defined before execution starts;
- blockers are visible and not silently downgraded.

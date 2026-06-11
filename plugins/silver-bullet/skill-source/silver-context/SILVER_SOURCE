---
name: "silver:context"
title: "Context"
description: This skill captures phase context, decisions, assumptions, constraints, and open questions before planning.
argument-hint: "<phase or change description>"
version: 0.1.0
---

# /silver:context - Phase Context

SB-owned context capture. This absorbs the useful behavior SB previously took
from GSD discuss-phase: adaptive questioning, locked decisions, assumptions,
constraints, and planner handoff.

Do not delegate to GSD or Superpowers. Produce enough context for an SB plan to
be written without re-asking solved questions.

## Output

Write or update the narrowest applicable context artifact:

- `.planning/CONTEXT.md` for project-level context.
- `.planning/phases/<phase>/CONTEXT.md` for phase-level context.
- `.planning/SPEC.md` references when context changes acceptance criteria.

## Process

1. Display `SILVER BULLET > CONTEXT`.
2. Read existing `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`,
   `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/SPEC.md`, and any
   current phase context or plan files that exist.
3. Ask only material unanswered questions. Prefer 3 or fewer questions per
   round. Do not ask questions already answered by artifacts.
4. Record decisions, constraints, risks, assumptions, non-goals, dependencies,
   and unresolved questions.
5. Mark each assumption with owner and status: Accepted, Follow-up-required, or
   Blocking.
6. End with a planning handoff section containing scope, out-of-scope items,
   acceptance criteria references, and unresolved blockers.

## Exit Gate

Context is complete only when:

- blockers are either resolved or explicitly labeled Blocking;
- assumptions are visible to the planner;
- the handoff is specific enough for `silver:plan` to create tasks and
  verification criteria.

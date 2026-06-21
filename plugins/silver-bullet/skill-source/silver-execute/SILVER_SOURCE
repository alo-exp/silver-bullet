---
name: "silver:execute"
title: "Execute"
description: This skill executes an SB PLAN.md in controlled waves with TDD, evidence capture, and summary artifacts.
argument-hint: "<plan path or execution scope>"
version: 0.1.0
---

# /silver:execute - Plan Execution

SB-owned execution loop keeps implementation inside the current coding agent and
SB artifacts while enforcing wave discipline, evidence capture, and deferred-item
tracking.

Do not delegate core project execution to an external lifecycle plugin.

## Output

Update the current phase with:

- changed source/test/doc files;
- `.planning/phases/<phase>/SUMMARY.md`;
- task status updates in PLAN.md when the local format supports it;
- deferred items filed through `silver:add`.

## Process

1. Display `SILVER BULLET > EXECUTE`.
2. Run Graphify retrieval for the plan scope before the first wave:
   `graphify query "<phase/plan files and task context>" --graph graphify-out/graph.json --budget 2000`
3. Read the active PLAN.md and confirm prerequisites, blockers, and TDD policy.
4. For implementation logic, invoke `tdd` before code edits and establish the
   failing test or explicit testability rationale.
4. Execute one wave at a time. Keep edits scoped to the wave.
5. After each wave:
   - run the smallest relevant verification;
   - record evidence and changed files;
   - file skipped or deferred work immediately through `silver:add`.
6. If execution fails, stop the phase and route to `silver:debug` or
   `silver:bugfix`; do not mark the phase complete.
7. Write SUMMARY.md with tasks completed, files changed, tests run, known gaps,
   and follow-up items.

## Exit Gate

Execution is complete only when:

- all planned tasks are done or explicitly deferred;
- required tests/checks for the executed scope have run;
- SUMMARY.md exists;
- no blocker is hidden as a note.

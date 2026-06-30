---
name: "silver:debug"
title: "Debug"
description: This skill performs systematic debugging with reproduction, hypotheses, evidence, root cause, fix plan, and regression guard.
argument-hint: "<bug or failure description>"
version: 0.1.0
---

# /silver:debug - Systematic Debugging

SB-owned debugging structures reproduction, hypotheses, evidence, root cause,
fix planning, and regression guards.

## Output

Write or update `.planning/DEBUG.md` or the current phase debug section.

## Process

1. Display `SILVER BULLET > DEBUG`.
2. Reproduce or characterize the failure before changing code.
3. Capture observed behavior, expected behavior, environment, logs, commands,
   and the smallest reproduction found.
4. Build a ranked hypothesis list with evidence for and against each item.
5. Test hypotheses one at a time. Do not shotgun fixes.
6. Identify root cause and blast radius.
7. Define the fix plan and the regression guard. Invoke `tdd` before code edits
   when the failure is implementation behavior.
8. Route implementation through `silver:execute` or the active workflow.

## Exit Gate

Debugging is complete only when root cause is evidenced, the next fix action is
clear, and a regression guard exists or a testability rationale is documented.

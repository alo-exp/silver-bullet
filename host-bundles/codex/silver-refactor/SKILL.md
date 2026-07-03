---
name: "silver:refactor"
title: "Refactor"
description: >
  This skill should be used for SB-owned refactoring: evaluate scope, preserve
  behavior with baseline tests, make structural changes, and prove nothing
  regressed.
argument-hint: "<refactor scope> [--plan-only|--continue|--batch <file>]"
version: 0.1.0
---

# /silver:refactor - Behavior-Preserving Change Workflow

SB-owned refactoring workflow for moving, splitting, renaming, simplifying, or
untangling code while preserving external behavior.

## Output

Write or update `.planning/REFACTOR.md`.

The artifact must include:

- refactor goal and non-goals;
- baseline behavior and tests;
- dependency/blast-radius map;
- ordered change slices;
- verification commands before and after;
- rollback notes.

## Process

1. Display `SILVER BULLET > REFACTOR`.
2. Evaluate scope with `silver:scan`, code reads, and dependency/call-chain
   evidence where available.
3. Establish the behavior contract: public APIs, user-visible behavior, data
   shape, CLI output, screenshots, or integration points that must not change.
4. Run or define baseline tests before editing. If no baseline exists, route to
   `silver:test --mode write` first for the affected behavior.
5. Plan small slices through `silver:plan`; avoid broad cosmetic rewrites.
6. Execute each slice through `silver:execute`, preserving behavior.
7. Invoke or apply `silver:domain-audit` with `code-health`,
   `structure-maintainability`, `test-health`, and affected API/data/UI packs.
8. Re-run the baseline after every meaningful slice and record evidence.
9. Use `--continue` only when the existing `.planning/REFACTOR.md` contract
   matches the current branch and scope.

## Exit Gate

The refactor passes only when behavior-preservation evidence is fresh, no
unresolved `BLOCK` findings remain, and the final diff matches the stated
refactor goal without unrelated churn.

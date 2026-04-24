---
id: tdd
title: TDD — Test-Driven Development
description: Enforces Red-Green-Refactor cycle; the iron law for all implementation work
trigger:
  - "TDD"
  - "test-driven"
  - "red green refactor"
  - "write tests first"
  - "failing test"
---

# TDD — Test-Driven Development

## The Iron Law
```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```
Violating this rule in letter violates it in spirit. No exceptions.

## Red-Green-Refactor

### RED — Write Failing Test
Write one minimal test for the behavior you're about to implement.
Run it. Confirm it FAILS.
Confirm it fails for the RIGHT reason — "feature missing" not "syntax error".
Commit: `[RED] test(<scope>): <behavior description> — N stubs`
DCO: `Signed-off-by: <name> <email>`

If the test passes immediately: you're testing existing behavior. The test is wrong. Fix it.

### GREEN — Write Minimal Code
Write the simplest code that makes the test pass. Nothing more.
No extra features. No refactoring. Minimum to go green.
Run ALL tests. Confirm they all pass.
Commit: `[GREEN] feat(<scope>): <description> — N tests pass`
DCO sign-off.

### REFACTOR — Clean Up
After green: improve names, extract helpers, remove duplication.
Tests must stay green throughout. If any go red: revert refactor, retry.

## Commit Pattern
1. `[RED] test(scope): describe-behavior — N stubs (todo!/unimplemented!)`
2. `[GREEN] feat(scope): describe-behavior — N tests pass`
3. `refactor(scope): clean up` (optional, only after all green)

## Red Flags — Stop and Start Over
Any of these means delete the code and start with a failing test:
- Code committed before test
- Test passed on first run without any implementation
- "I'll add tests after" / "This is too simple to test"
- "Manual testing is enough"
- "Tests slow me down on this part"

## Verification
Before marking any implementation complete:
- Every new function/method has at least one test
- You watched each test fail before implementing
- Each test failed for the expected reason (feature missing)
- Minimal code was written to pass (no gold-plating)
- All tests pass, no warnings

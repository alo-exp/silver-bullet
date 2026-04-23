---
id: silver-bugfix
title: Silver — Bug Fix Workflow
description: Systematic bug diagnosis and fix workflow
trigger:
  - "silver bugfix"
  - "bug fix workflow"
  - "fix bug"
  - "debug"
---

# Silver Bugfix — Systematic Bug Fix

## When to Use
When something is broken, crashing, erroring, or not working as expected.

## Steps

### Step 1: Triage
Identify the bug:
- What is broken?
- When does it happen?
- What did it do before?

### Step 2: Reproduce
Create a minimal reproduction case. Confirm the bug exists.

### Step 3: Diagnose
Find the root cause:
- Read error messages carefully
- Check recent changes (git log)
- Add logging to trace execution
- Narrow down to the failing component

### Step 4: Fix
Apply the minimal fix:
- Fix the root cause
- Do not add unrelated changes
- Follow TDD: write test first, then fix

### Step 5: Verify
Confirm the fix works:
- Run existing tests
- Run reproduction case
- Verify edge cases

### Step 6: Review
Run code review on the fix (trigger: "code review").

### Step 7: Quality Gates (pre-ship)
Run quality gates (trigger: "quality gates") before shipping.

### Step 8: Ship
Create PR with fix (trigger: "ship").

## Session Logging
Document the bug, diagnosis, and fix in `docs/sessions/YYYY-MM-DD.md`.

## Exit Condition
Bug fixed, verified, and PR created.

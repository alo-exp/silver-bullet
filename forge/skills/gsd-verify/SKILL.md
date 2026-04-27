---
name: gsd-verify
id: gsd-verify
title: GSD — Verify Work
description: Execute verification steps from PLAN.md and produce VERIFICATION.md
trigger:
  - "verify work"
  - "verify phase"
  - "verification"
  - "check done"
  - "is it done"
---

# GSD — Verify Work

## Steps

### Step 1: Read Verification Steps
Read the "Verification steps" section of `.planning/phases/<N>/PLAN.md`. These are the acceptance criteria.

### Step 2: Execute Each Verification Step
For each step, run it and record the result.

### Step 3: Write VERIFICATION.md
Write `.planning/VERIFICATION.md`:
```
# Phase <N> Verification

| Step | Result | Evidence |
|------|--------|----------|
| <step 1> | ✅/❌ | <how you verified> |
...

## Status: PASSED / FAILED
```

### Step 4: Gate
If any step is ❌: do NOT mark phase complete. Fix the issue and re-run verification.

## Exit Condition
VERIFICATION.md exists with `## Status: PASSED` and no ❌ rows.

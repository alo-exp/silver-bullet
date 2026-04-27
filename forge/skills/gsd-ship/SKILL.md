---
name: gsd-ship
id: gsd-ship
title: GSD — Ship Phase (Create PR)
description: Push branch and create PR; refuses to ship without passing verification
trigger:
  - "ship"
  - "create PR"
  - "pull request"
  - "ship phase"
---

# GSD — Ship Phase

## Hard Prerequisites
VERIFICATION.md must exist with `Status: PASSED`. If it doesn't: "Cannot ship without passing verification. Run 'verify work' first." Do not create a PR without it.

## Steps

### Step 1: Final Quality Gates (pre-ship)
Run all 9 quality dimensions in pre-ship (adversarial) mode. Fix any ❌ before proceeding.

### Step 2: Push Branch
Push the current branch to origin.

### Step 3: Create PR
Create a PR with:
- **Title**: `feat(<phase>): <description>` (≤70 chars, imperative)
- **Body**:
  ```
  ## Summary
  <1-3 bullet points of what was built>

  ## Requirements Covered
  <list of REQ-IDs from PLAN.md>

  ## Verification Evidence
  <paste VERIFICATION.md Status section>

  ## Test Plan
  <checklist of what was tested>
  ```

## Exit Condition
PR URL returned. Link recorded in session log.

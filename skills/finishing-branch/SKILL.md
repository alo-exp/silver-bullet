---
id: finishing-branch
title: Finishing a Development Branch
description: Merge, PR, or cleanup decisions for completing a branch
trigger:
  - "finishing branch"
  - "cleanup branch"
  - "merge decision"
  - "branch done"
---

# Finishing a Development Branch

## Purpose
Make informed decisions about branch finalization: merge strategy, cleanup, and next steps.

## Steps

### Step 1: Verify Completeness
Before finishing:
- All tests pass
- All review findings addressed
- VERIFICATION.md shows PASSED
- Security review complete
- Documentation updated

### Step 2: Choose Merge Strategy
```
Merge strategies:
A. Squash merge: Clean history, single commit per feature (recommended)
B. Merge commit: Preserve history, multi-commit branches
C. Rebase + merge: Linear history, preserves commits
```

Ask user or use project default.

### Step 3: Update Branch
- Rebase on latest main if needed
- Resolve conflicts
- Ensure tests pass post-merge

### Step 4: Create PR
If not already created:
- Title: `feat(<scope>): <description>` (≤70 chars)
- Body: Summary, requirements covered, verification
- Reviewers: Assign appropriate people

### Step 5: Document Decisions
```
# Branch Completion: <branch-name>

## Status
- Tests: ✅/❌
- Review: ✅/❌ (N findings, all addressed)
- Verification: ✅/❌
- Security: ✅/❌

## Merge Strategy
<squash/merge/rebase>

## PR
<URL>

## Next Steps
- Merge after approval
- Monitor CI/CD
- Close issue after deploy
```

## When to Clean Up Locally
After PR is merged:
- Delete local branch: `git branch -d <branch>`
- Delete remote branch: `git push origin --delete <branch>`

## Exit Condition
PR created or branch merged. Completion documented.

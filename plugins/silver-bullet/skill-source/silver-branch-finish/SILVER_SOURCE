---
name: "silver:branch-finish"
title: "Branch Finish"
description: "This skill performs branch finishing decisions before PR or merge: status, tests, docs, cleanup, and user choice."
argument-hint: "<branch or ship scope>"
version: 0.1.0
---

# /silver:branch-finish - Branch Finishing

SB-owned branch finishing handles status, tests, docs, cleanup, and the user's
PR/merge decision.

## Output

Update the ship or review artifact with branch readiness and chosen next step.

## Process

1. Display `SILVER BULLET > BRANCH FINISH`.
2. Inspect branch status, changed files, staged files, pending tests, docs, and
   review/verification artifacts.
3. Confirm whether the current branch is a feature branch or mainline.
4. Present the practical finish options:
   - create or update PR;
   - merge locally after approval;
   - keep branch open with explicit remaining work;
   - stop because gates are missing.
5. Ensure generated artifacts, temporary files, and unrelated changes are not
   accidentally shipped.

## Exit Gate

Branch finishing passes only when the next branch action is explicit and no
required gate is silently bypassed.

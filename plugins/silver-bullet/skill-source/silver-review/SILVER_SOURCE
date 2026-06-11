---
name: "silver:review"
title: "Review"
description: This skill performs SB-owned code review, records findings, and drives the fix loop.
argument-hint: "<review scope>"
version: 0.1.0
---

# /silver:review - Code Review

SB-owned code review. This absorbs the useful behavior SB previously took from
GSD code-review/code-review-fix and Engineering code-review while preserving
SB's stricter artifact and fix-loop requirements.

## Output

Write or update `.planning/REVIEW.md`.

## Process

1. Display `SILVER BULLET > REVIEW`.
2. Read the review request, SPEC, PLAN, SUMMARY, VERIFICATION, and changed files.
3. Review for bugs, regressions, security issues, missing tests, broken docs,
   maintainability risks, and release blockers.
4. Report findings first, ordered by severity, with file and line references.
5. For each finding, classify severity as BLOCK, WARN, or INFO.
6. Fix BLOCK findings before ship unless the user explicitly accepts the risk.
7. Re-run targeted verification after fixes and update REVIEW.md.

## Optional Review Enrichment

External second-opinion reviewers may be used when the user requests them or the
change is architecturally significant, but they feed into REVIEW.md and do not
replace this SB review artifact.

## Exit Gate

Review passes only when all BLOCK findings are fixed or explicitly accepted and
REVIEW.md reflects the final state.

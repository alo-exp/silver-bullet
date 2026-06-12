---
name: "silver:review-triage"
title: "Review Triage"
description: This skill triages review findings, rejects weak findings, fixes valid blockers, and captures deferred work.
argument-hint: "<review findings>"
version: 0.1.0
---

# /silver:review-triage - Review Response

SB-owned review response rejects weak findings, fixes valid blockers, and
captures deferred work without blindly accepting or ignoring findings.

## Output

Update `.planning/REVIEW.md` with triage decisions and follow-up status.

## Process

1. Display `SILVER BULLET > REVIEW TRIAGE`.
2. For each finding, decide: valid blocker, valid non-blocker, duplicate,
   already fixed, false positive, or needs user decision.
3. Explain the evidence for rejected or downgraded findings.
4. Fix valid blockers or route them into the active plan.
5. File valid non-blocking deferred items through `silver:add`.
6. Re-run targeted checks after fixes.

## Exit Gate

Triage is complete only when every finding has an outcome, every blocker is
handled, and deferred work is recorded outside the review thread.

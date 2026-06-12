---
name: "silver:review-request"
title: "Review Request"
description: This skill frames a code review request with scope, risks, artifacts, and reviewer instructions.
argument-hint: "<review scope>"
version: 0.1.0
---

# /silver:review-request - Review Framing

SB-owned review framing defines scope, risk, evidence, and blocker criteria
before review begins.

## Output

Write or update the review request section in `.planning/REVIEW.md`.

## Process

1. Display `SILVER BULLET > REVIEW REQUEST`.
2. Identify changed files, intended behavior, non-goals, high-risk areas,
   tests run, and artifacts to inspect.
3. State reviewer focus areas:
   - correctness and regressions;
   - security and privacy;
   - test gaps;
   - maintainability and architecture;
   - docs and operational impact.
4. Include known tradeoffs and constraints so reviewers do not rediscover them.
5. Explicitly list what would block ship.

## Exit Gate

The request is complete when a reviewer can start without asking what changed,
why it changed, what to test, or what risk matters most.

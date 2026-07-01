---
name: "silver:completion-audit"
title: "Completion Audit"
description: This skill independently verifies completion claims before SB accepts a phase, task, review, or release as done.
argument-hint: "<completion claim>"
version: 0.1.0
---

# /silver:completion-audit - Completion Claim Audit

SB-owned completion audit verifies completion claims against direct evidence
before SB accepts them.

## Process

1. Display `SILVER BULLET > COMPLETION AUDIT`.
2. Restate the exact completion claim being audited.
3. Identify the artifacts that would prove the claim: files, tests, summaries,
   review records, verification records, CI, screenshots, or release evidence.
4. Check the artifacts directly. Do not accept a self-report as proof.
5. Run targeted commands when needed and safe.
6. Classify the claim:
   - PASS: evidence supports the claim;
   - PARTIAL: some work is done but gaps remain;
   - FAIL: evidence contradicts the claim;
   - UNKNOWN: evidence is missing.
7. For PARTIAL/FAIL/UNKNOWN, list the minimum next action.

## Exit Gate

SB may advance only after this audit returns PASS or the user explicitly accepts
the remaining risk.

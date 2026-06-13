---
name: "silver:review"
title: "Review"
description: This skill performs SB-owned code review, records findings, and drives the fix loop.
argument-hint: "<review scope>"
version: 0.1.0
---

# /silver:review - Code Review

SB-owned code review records findings and drives the fix loop while preserving
SB's strict artifact and evidence requirements.

## Output

Write or update `.planning/REVIEW.md`.

## Process

1. Display `SILVER BULLET > REVIEW`.
2. Read the review request, SPEC, PLAN, SUMMARY, VERIFICATION, and changed files.
3. Review for bugs, regressions, security issues, missing tests, broken docs,
   maintainability risks, and release blockers.
4. When the review scope touches API, data, dependency, performance, structure,
   CI, environment, accessibility, content/search, UI, architecture, runtime,
   incident, retro, or benchmark surfaces, invoke or apply `silver:domain-audit`
   for the affected packs and merge the normalized findings into REVIEW.md.
5. Report findings first, ordered by severity, with file and line references.
6. For each finding, classify severity as BLOCK, WARN, or INFO.
7. Fix BLOCK findings before ship unless the user explicitly accepts the risk.
8. Re-run targeted verification after fixes and update REVIEW.md.

## Optional Review Enrichment

Follow `docs/external-review-policy.md`. External second-opinion reviewers may
be used when the user requests them or the change is architecturally significant,
but they feed into REVIEW.md and do not replace this SB review artifact.

Normalize imported findings with `docs/evidence-schema.md`.

Before completing review, run when available:

```bash
bash scripts/validate-evidence-findings.sh
```

Malformed finding tables surface as delivery warnings (or blocks when strict mode
is enabled). See `hooks/lib/evidence-schema-gate.sh`.

## Exit Gate

Review passes only when all BLOCK findings are fixed or explicitly accepted and
REVIEW.md reflects the final state.

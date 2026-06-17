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
9. **Score deployment risk** (see Deployment Risk Scoring below) and include
   the score in REVIEW.md.

## Deployment Risk Scoring

After listing findings, assign a deployment risk tier to the overall change set.
This score reflects how risky it is to deploy the change to production — independent
of whether all review findings are resolved.

| Tier | Label | Criteria |
|------|-------|----------|
| 1 | `LOW` | Docs, config, copy, dependency bumps (non-breaking), test additions. No production data path changes. |
| 2 | `MEDIUM` | New features behind flags, additive API changes, non-critical bug fixes, schema changes with safe migrations. |
| 3 | `HIGH` | Auth/authz changes, breaking API changes, migrations that modify existing rows, performance-critical paths, payment/billing logic. |
| 4 | `CRITICAL` | Multi-tenant data isolation changes, security patches for active exploits, production data backfills, irreversible schema drops, changes to authentication secrets or encryption. |

Write in REVIEW.md:

```markdown
## Deployment Risk

Tier: HIGH (example)
Rationale: <one sentence explaining the highest-risk change>
Recommended deploy steps:
- <e.g., "Deploy behind feature flag">
- <e.g., "Run migration in read-only first">
- <e.g., "Verify rollback plan before deploying">
```

The deployment risk tier is informational — it does not block ship on its own.
However, CRITICAL tier requires the user to explicitly acknowledge the risk
before `silver:ship` proceeds.

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

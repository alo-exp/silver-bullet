---
name: "silver:review-triage"
title: "Review Triage"
description: "Specialized review-response wrapper — delegates to generic /silver:triage for finding classification, PM filing, and fix routing after code or artifact review."
argument-hint: "<review findings>"
version: 0.2.0
---

# /silver:review-triage — Review Response (wrapper)

Legacy entry point for the review triad (`silver:review-request` → `silver:review` → `silver:review-triage`). **Delegates to generic `/silver:triage`** for all classification, PM filing, and fix routing.

## Delegation

Invoke **`/silver:triage`** with:

- Raw findings from `/silver:review` or external review
- Scope = files or artifacts under review
- Charter = active plan goals, `REVIEW.md`, or review request scope

Do not reimplement triage logic here — this skill exists for catalog compatibility (`AF-REVIEW-TRIAGE`) and triad sequencing.

## Output

Same as `/silver:triage`: triage table in `.planning/REVIEW.md` plus `silver-triage-v1` JSON summary.

## Exit Gate

Same as `/silver:triage` — every finding classified, valid items filed or linked, blockers routed to fix workflows.

---
name: sb:review-triage
description: Specialized review-response wrapper — delegates to generic /sb:triage for finding classification, PM filing, and fix routing after code or artifact review.
argument-hint: "<review findings>"
version: 0.2.0
---

# /sb:review-triage — Review Response (wrapper)

Legacy entry point for the review triad (`sb:review-request` → `sb:review` → `sb:review-triage`). **Delegates to generic `/sb:triage`** for all classification, PM filing, and fix routing.

## Delegation

Invoke **`/sb:triage`** with:

- Raw findings from `/sb:review` or external review
- Scope = files or artifacts under review
- Charter = active plan goals, `REVIEW.md`, or review request scope

Do not reimplement triage logic here — this skill exists for catalog compatibility (`AF-REVIEW-TRIAGE`) and triad sequencing.

## Output

Same as `/sb:triage`: triage table in `.planning/REVIEW.md` plus `silver-triage-v1` JSON summary.

## Exit Gate

Same as `/sb:triage` — every finding classified, valid items filed or linked, blockers routed to fix workflows.

# `/silver:new-workflow` Meta Workflow — Plan

**Branch:** `feature/silver-agent-claude-skill`  
**Date:** 2026-07-05  
**Status:** implemented

## Goal

Deliver `/silver:new-workflow` — a catalog-backed meta workflow that creates or promotes SB workflows/atomic flows from user intent, with safe target-repo selection, reuse analysis, plan RFL, implementation, validation, and local catalog registration.

## Modes

| Mode | Trigger | Outcome |
|------|---------|---------|
| **Create** | User describes a new workflow intent | New composer skill + catalog workflow + hooks/tests/docs |
| **Convert** | User supplies existing skill/workflow path | Gap review → compliant SB workflow/AF + catalog entries |

## Composition (catalog)

`WF-SILVER-NEW-WORKFLOW` (precomposed):

```
AF-CLARIFY → AF-ORIENT → AF-DECIDE → AF-PLAN → AF-REVIEW-TRIAGE → AF-EXECUTE → AF-VERIFY → AF-VALIDATE → AF-DOCUMENT
```

**Enforcement queue:** `silver-clarify`, `silver-scan`, `silver-research`, `silver-plan`, `silver-review-fix-ladder`, `silver-execute`, `silver-verify`, `silver-validate`, `silver-ensure-docs`

## RFL rung outcomes (plan phase)

| Rung | Phase | Result |
|------|-------|--------|
| composer-2.5 / low | audit_fix + verify_1 + verify_2 | Clean |
| composer-2.5 / medium | audit_fix + verify_1 + verify_2 | Clean — plan approved |

**Plan RFL status:** PASS

## Post-implementation RFL

See `.planning/reviews/NEW-WORKFLOW-RFL-CLOSEOUT.md` after validation gates.

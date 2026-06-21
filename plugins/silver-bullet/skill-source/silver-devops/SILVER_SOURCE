---
name: "silver:devops"
title: "DevOps"
description: >
  This skill should be used for SB-owned infrastructure/CI-CD workflow: intel → silver:blast-radius → devops-skill-router → devops-quality-gates (7 IaC dims) → SB plan/execute/verify → review → secure → ship
argument-hint: "<infrastructure or CI/CD change description>"
version: 0.2.0
---

# /silver:devops — DevOps Composition Spec

SB **queue builder** for infra/CI/CD/IaC. Parent orchestrator spawns workers — does not
implement changes inline.

**Canonical contracts:** `docs/composable-flows-contracts.md` + runtime tokens
(BLAST-RADIUS, DEVOPS-SKILL-ROUTER). **Workers:** `templates/orchestrator-workers/*.md`.

**Design notes:**
- Blast-radius replaces product brainstorm for infra scope.
- `devops-quality-gates` (7 IaC dimensions) replaces product `silver:quality-gates` at
  both pre-plan and pre-ship positions.
- Pure infra plans skip application `tdd`; use plan/dry-run/policy/drift validation.
- `required_deploy_devops` omits `tdd` by design.

## Standard composition chain

```
FLOW 1 (BOOTSTRAP) [skip if .planning/] → FLOW 2 (ORIENT)
→ FLOW 3 (CLARIFY) [if scope unclear] → FLOW 4 (DECIDE) [if tooling choice]
→ BLAST-RADIUS + DEVOPS-SKILL-ROUTER (FLOW 6 DevOps extensions)
→ FLOW 13 (QUALITY GATE, DevOps pre-plan) → FLOW 11 (SECURE, pre-plan)
→ FLOW 6 (PLAN) → FLOW 8 (EXECUTE) → FLOW 10 (REVIEW) → FLOW 12 (VERIFY)
→ FLOW 11 (SECURE) → FLOW 13 (QUALITY GATE, DevOps pre-ship) → FLOW 14 (SHIP)
```

Never includes FLOW 7 or FLOW 9. Post-execution order matches `silver:feature` after FLOW 8.

## Conditional insertions

| Signal | Insert |
|--------|--------|
| Live rollout in scope | `silver:deploy`, `silver:canary` inside FLOW 14 |
| `docs/doc-scheme.md` | FLOW 17 checks before ship |
| CI/deploy failure | FLOW 15 (DEBUG) |
| Domain packs touched | `silver:domain-audit` DevOps packs with quality gates |

## Enforcement queue

**Pre-execution:** `silver:blast-radius` → `devops-skill-router` → `devops-quality-gates`
→ `security` → `silver:context` → `silver:plan` → `silver:validate`

**Post-execution:** `silver:execute` → review triad → `silver:verify` → `security`
→ `silver:secure` → `silver:validate` → `devops-quality-gates` (pre-ship)
→ `silver:branch-finish` → `silver:completion-audit` → `silver:ship`

## DevOps-cycle profile

At workflow start set `.silver-bullet.json` → `project.active_workflow = "devops-cycle"`.
Restore to `full-dev-cycle` after ship.

## Routing and pre-flight

1. Load preferences from `silver-bullet.md` §10.
2. Banner with change description and mode.
3. Autonomous default — log `SB ► devops composed {N} paths — orchestrator active`.

## Step-skip protocol

**Non-skippable:** `security` (pre-plan), `devops-quality-gates` pre-ship, `silver:verify`.

## Workflow tracking (fallback)

Same `scripts/workflows.sh` pattern with `/silver:devops` and FLOW/extension names.

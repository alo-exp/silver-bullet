---
name: "silver:ui"
title: "UI"
description: >
  This skill should be used for full SB-owned UI/frontend workflow: orient → clarify/decide → test strategy → silver:ui-contract → execute+TDD → silver:ui-review → review → verify → secure → ship
argument-hint: "<UI feature or component description>"
version: 0.2.0
---

# /silver:ui — UI Composition Spec

SB **queue builder** for UI/frontend work. Parent orchestrator seeds the queue and spawns
Task workers per flow — does not implement UI inline.

**Canonical contracts:** `docs/composable-flows-contracts.md`. **Workers:**
`templates/orchestrator-workers/*.md`.

## Standard composition chain

```
FLOW 1 (BOOTSTRAP) [skip if .planning/] → FLOW 2 (ORIENT) → FLOW 3 (CLARIFY)
→ FLOW 4 (DECIDE) [if design tradeoff] → FLOW 5 (SPECIFY) [if no SPEC.md]
→ FLOW 13 (QUALITY GATE, pre-plan) → FLOW 6 (PLAN) → FLOW 7 (DESIGN CONTRACT)
→ FLOW 8 (EXECUTE) → FLOW 9 (UI QUALITY) → FLOW 10 (REVIEW) → FLOW 12 (VERIFY)
→ FLOW 11 (SECURE) → FLOW 13 (QUALITY GATE, pre-ship) → FLOW 14 (SHIP)
```

FLOW 7 and FLOW 9 are **always** included in this workflow.

Post-execution after FLOW 8: **UI QUALITY → REVIEW → VERIFY → SECURE → VALIDATE →
QUALITY GATE (pre-ship) → SHIP**.

## Conditional insertions

| Signal | Insert / skip |
|--------|----------------|
| `.planning/` exists | Skip FLOW 1 |
| No `.planning/SPEC.md` | FLOW 5 — enforced by `workflow-chain-guard` |
| Fuzzy UI intent | FLOW 3 (CLARIFY) |
| Major UI system / user requests MultAI | Optional multi-AI UX perspectives — not bundled |
| Execution failure | FLOW 15 (DEBUG) |
| Last milestone phase | FLOW 18 via `silver:release` when user confirms |
| `docs/doc-scheme.md` | FLOW 17 checks before FLOW 14 |

## Enforcement queue

**Pre-execution:** `silver:quality-gates` → `silver:context` → `silver:plan`
→ `silver:ui-contract` → `silver:validate` (conditional `silver:spec` when SPEC absent)

**Post-execution:** `silver:execute` → `silver:ui-review` → review triad → `silver:verify`
→ `security` → `silver:secure` → `silver:validate` → `silver:quality-gates` (pre-ship)
→ `silver:branch-finish` → `silver:completion-audit` → `silver:ship`

`workflow-chain-guard.sh` enforces pre-execution only at edit time.

## Routing and pre-flight

1. Load preferences from `silver-bullet.md` §10.
2. Banner: `SILVER BULLET ► UI WORKFLOW` + intent + mode.
3. Autonomous default — log `SB ► ui composed {N} paths — orchestrator active`.

## Step-skip protocol

**Non-skippable:** `security`, `silver:quality-gates` pre-ship, `silver:verify`.

## Workflow tracking (fallback)

See `silver:feature` composition spec — same `scripts/workflows.sh` pattern with
`/silver:ui` composer and FLOW names from the chain above.

## Deferred work

File deferred items via `/silver:add` during and after execution.

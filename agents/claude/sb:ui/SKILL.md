---
name: sb:ui
description: >
  This skill should be used for full SB-owned UI/frontend workflow: orient → clarify/decide → test strategy → sb:ui-contract → execute+TDD → sb:ui-review → review → verify → secure → ship
argument-hint: "<UI feature or component description>"
version: 0.2.0
---

# /sb:ui — UI Composition Spec

SB **queue builder** for UI/frontend work. Parent orchestrator seeds the queue and spawns
Task workers per flow — does not implement UI inline.

**Canonical contracts:** `docs/composable-flows-contracts.md`. **Workers:**
`templates/orchestrator-workers/*.md`.

## Standard composition chain

```
FLOW 1 (BOOTSTRAP) [skip if .planning/] → FLOW 2 (ORIENT) → FLOW 3 (CLARIFY) [--spec if no SPEC.md]
→ FLOW 4 (DECIDE) [if design tradeoff] → FLOW 5 (SPECIFY) [compiler if no SPEC.md]
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
| No `.planning/SPEC.md` | **FLOW 3 = `sb:clarify --spec` is mandatory**, then FLOW 5 compiler. Not fuzzy-only. Enforced by `workflow-chain-guard` + `orchestrator-state.sh`. |
| Existing SPEC.md | Skip FLOW 3 `--spec` and FLOW 5 |
| Fuzzy UI intent | FLOW 3 light (not `--spec`) |
| Major UI system / user requests MultAI | Optional multi-AI UX perspectives — not bundled |
| Execution failure | FLOW 15 (DEBUG) |
| Last milestone phase | FLOW 18 via `sb:release` when user confirms |
| `docs/doc-scheme.md` | FLOW 17 checks before FLOW 14 |

## Enforcement queue

**Pre-execution:** `sb:quality-gates` → `sb:context` → `sb:plan`
→ `sb:ui-contract` → `sb:validate` (plus mandatory `sb:clarify --spec` then `sb:spec` when SPEC.md absent)

**Post-execution:** `sb:execute` → `sb:ui-review` → review triad → `sb:verify`
→ `security` → `sb:secure` → `sb:validate` → `sb:quality-gates` (pre-ship)
→ `sb:branch-finish` → `sb:completion-audit` → `sb:ship`

`workflow-chain-guard.sh` enforces pre-execution only at edit time.

## Routing and pre-flight

1. Load preferences from `silver-bullet.md` §10.
2. Banner: `SILVER BULLET ► UI WORKFLOW` + intent + mode.
3. Autonomous default — log `SB ► ui composed {N} paths — orchestrator active`.

## Step-skip protocol

**Non-skippable:** `security`, `sb:quality-gates` pre-ship, `sb:verify`.

## Workflow tracking (fallback)

See `sb:feature` composition spec — same `scripts/workflows.sh` pattern with
`/sb:ui` composer and FLOW names from the chain above.

## Deferred work

File deferred items via `/sb:add` during and after execution.

---
name: "silver:bugfix"
title: "Bugfix"
description: >
  This skill should be used for SB-orchestrated bug investigation and fix: triage → path A/B/C → plan → TDD regression test → execute → review → verify → ship
argument-hint: "<description of the bug or failure>"
version: 0.2.0
---

# /silver:bugfix — Bugfix Composition Spec

SB **queue builder** for bugs and regressions. Parent orchestrator spawns workers — does
not fix inline.

**Canonical contracts:** `docs/composable-flows-contracts.md` (FLOW 15 DEBUG, FLOW 6 PLAN,
FLOW 8 EXECUTE, post-execution chain).

## Standard composition chain

```
FLOW 2 (ORIENT) [optional] → FLOW 15 (DEBUG) → FLOW 6 (PLAN) → FLOW 8 (EXECUTE)
→ FLOW 10 (REVIEW) → FLOW 12 (VERIFY) → FLOW 11 (SECURE)
→ FLOW 13 (QUALITY GATE, pre-ship) → FLOW 14 (SHIP)
```

Post-execution order after FLOW 8: **REVIEW → VERIFY → SECURE → VALIDATE → QUALITY GATE
(pre-ship) → SHIP** (see contracts § Post-execution sequencing).

Single-phase by design — no per-phase loop. FLOW 15 always included.

Before triage, run Graphify for the failure surface:

```bash
graphify query "<bug symptom, files, tests, stack traces>" --graph graphify-out/graph.json --budget 2000
```

## Triage paths (FLOW 15)

| User selection | Route |
|----------------|-------|
| A — known symptom, unknown fix | `silver:debug` → plan → TDD → execute |
| B — unknown cause | `silver:forensics` → hand off to path A |
| C — failed SB lifecycle | `silver:forensics` (post-mortem) → path A |

Internal `tdd` gate: failing regression test before fix code (RED → GREEN).

## Conditional insertions

| Signal | Insert |
|--------|--------|
| `docs/doc-scheme.md` | FLOW 17 checks before FLOW 14 |
| `tech-debt` plugin available | Optional debt capture after fix |

## Enforcement queue

**Pre-execution:** `silver:debug` → `silver:plan` (no quality-gates/context)

**Post-execution:** same canonical chain as `silver:feature` after `silver:execute`.

## Routing and pre-flight

1. Load preferences from `silver-bullet.md` §10.
2. Banner with symptom from `$ARGUMENTS`.
3. Present triage A/B/C when cause is unclear.
4. Autonomous default — log `SB ► bugfix composed {N} paths — orchestrator active`.

## Step-skip protocol

**Non-skippable:** `security`, `silver:quality-gates` pre-ship, `silver:verify`.

## Workflow tracking (fallback)

Same `scripts/workflows.sh` pattern with `/silver:bugfix`.

## Deferred work

File deferred items via `/silver:add` during and after execution.

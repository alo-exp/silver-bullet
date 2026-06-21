---
name: "silver:feature"
title: "Feature"
description: >
  This skill should be used for full SB-owned feature development workflow: orient → clarify/decide → silver:quality-gates → SB context/plan/execute → review → verify → secure → ship
argument-hint: "<feature description>"
version: 0.2.0
---

# /silver:feature — Feature Composition Spec

SB **queue builder** for feature development. The parent orchestrator seeds
`orchestrator.json` and spawns Task workers per atomic flow — it does not execute
flows inline. Never implements features directly.

**Canonical contracts:** `docs/composable-flows-contracts.md` (FLOW 1–18 steps, produces,
exit conditions). **Worker templates:** `templates/orchestrator-workers/*.md`.
**Supervision loop:** `references/supervision-loop.md`.

## Standard composition chain

```
FLOW 1 (BOOTSTRAP) → FLOW 2 (ORIENT) → FLOW 3 (CLARIFY) → FLOW 4 (DECIDE)
→ FLOW 5 (SPECIFY) → FLOW 13 (QUALITY GATE, pre-plan) → FLOW 6 (PLAN)
→ FLOW 7 (DESIGN CONTRACT) [if UI] → FLOW 8 (EXECUTE)
→ FLOW 9 (UI QUALITY) [if UI] → FLOW 10 (REVIEW) → FLOW 12 (VERIFY)
→ FLOW 11 (SECURE) → FLOW 13 (QUALITY GATE, pre-ship) → FLOW 14 (SHIP)
```

Post-execution order after FLOW 8: **REVIEW → VERIFY → SECURE → VALIDATE → QUALITY GATE
(pre-ship) → SHIP** (see contracts § Post-execution sequencing).

## Conditional insertions

| Signal | Insert / skip |
|--------|----------------|
| `.planning/` missing | Include FLOW 1 (BOOTSTRAP) |
| Brownfield / unfamiliar codebase | FLOW 2 deeper `silver:scan` |
| Fuzzy intent or empty `$ARGUMENTS` | FLOW 3 (CLARIFY) |
| Architecture/stack/API choice | FLOW 4 (DECIDE) via `silver:research` |
| No `.planning/SPEC.md` | FLOW 5 (SPECIFY) — enforced by `workflow-chain-guard` |
| Existing SPEC.md | Skip FLOW 5 |
| Existing phase PLAN.md | Skip FLOW 6 for that phase |
| UI files in scope | FLOW 7 + FLOW 9 |
| Execution/CI/test failure | FLOW 15 (DEBUG) |
| Last phase of milestone | FLOW 18 (RELEASE) after user confirms |
| User requests MultAI / second opinion | Optional external research/review — feeds SB artifacts only |
| `docs/doc-scheme.md` present | FLOW 17 doc-scheme checks before FLOW 14 |
| Trivial (≤3 files, typo, config) | **STOP** — route to `silver:fast` |

## Enforcement queue (hooks / orchestrator)

**Pre-execution** (blocks implementation edits until recorded):

`silver:quality-gates` → `silver:context` → `silver:plan` → `silver:validate`
(plus conditional `silver:spec` when SPEC.md absent)

**Post-execution** (completion / deploy gates):

`silver:execute` → review triad → `silver:verify` → `security` → `silver:secure`
→ `silver:validate` → `silver:quality-gates` (pre-ship) → `silver:branch-finish`
→ `silver:completion-audit` → `silver:ship`

Queue source: `hooks/lib/orchestrator-state.sh` (`silver-feature` composer).

If any required SB skill cannot be invoked, stop and notify the user. Do not replace
missing lifecycle skills with shell-only work.

## Routing and pre-flight

1. Read **User Workflow Preferences** from `silver-bullet.md` §10 before composing.
2. Display: `SB ► feature: {$ARGUMENTS} [autonomous]`
3. Do not ask for composition approval — `flow-advance.sh` starts the workflow tracker.
4. Log: `SB ► composed {N} flows ({skipped} skipped) — orchestrator active`

### Context scan (skip/include flags)

Before composing flows, run Graphify retrieval for the feature scope:

```bash
graphify query "<feature intent plus likely files/modules>" --graph graphify-out/graph.json --budget 2000
```

Inspect nodes before choosing skip/include flags. Hooks block implementation edits without a fresh query.

| Artifact | Action |
|----------|--------|
| `.planning/SPEC.md` | Skip FLOW 5 when present |
| Phase `PLAN.md` files | Skip FLOW 6 when planning done |
| UI files in scope | Include FLOW 7 + FLOW 9 |
| `STATE.md` / `ROADMAP.md` | Set per-phase loop bounds |

### Per-phase loop

For each remaining milestone phase: FLOW 6 → FLOW 8 → post-execution chain (above).
Tick `ROADMAP.md` via FLOW 14 (`silver:ship`) — use planning-edit override only when
ship did not tick the checkbox (see `references/supervision-loop.md`).

## Step-skip protocol

On skip request: explain (one sentence) → offer A/B/C → record permanent skips in
`silver-bullet.md` §10b + `templates/silver-bullet.md.base` §9b.

**Non-skippable:** `security`, `silver:quality-gates` pre-ship, `silver:verify`.

## Workflow tracking (fallback)

When hooks did not start tracking, resolve `scripts/workflows.sh`, export `SB_WORKFLOW_ID`,
and use FLOW names from the composition chain for `complete-flow` rows. Archive with
`complete` when the final FLOW 14 / FLOW 18 step succeeds.

## Deferred work

File skipped/descoped items via `/silver:add` during execution and in a final post-work
sweep — do not accumulate silently.

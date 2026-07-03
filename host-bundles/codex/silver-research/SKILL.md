---
name: "silver:research"
title: "Research"
description: >
  This skill should be used for SB-orchestrated research workflow: clarify → direct research by default, optional MultAI augmentation only when user-requested → clarify → hand off to silver:feature or silver:devops
argument-hint: "<research question or technology decision>"
version: 0.2.0
---

# /silver:research — Research Composition Spec

SB **queue builder** for tech decisions and spikes. Workers produce artifacts; parent
does not write research inline.

**Canonical contracts:** `docs/composable-flows-contracts.md` (FLOW 3–5). No FLOW 8/12/14.

## Standard composition chain

```
FLOW 3 (CLARIFY) → FLOW 4 (DECIDE) → FLOW 5 (SPECIFY) [when ingesting to SPEC]
→ handoff to silver:feature | silver:devops | done
```

Mandatory trace: `silver:clarify` → research path → `silver:clarify` (apply findings)
before implementation handoff.

## Research mode policy

Default mode is direct research in the current host session (primary sources, repo context).

Only opt into MultAI when the user explicitly requests multi-AI in the **current task**.
- If MultAI requested but unavailable: stop — offer install-and-retry or degraded path approval.

## Research paths (FLOW 4)

| Type | Signals | Artifact |
|------|---------|----------|
| A — landscape | market/ecosystem questions | `.planning/research/<date>-<slug>/landscape-report.md` |
| B — tech selection | X vs Y, stack choice | `.../comparison-report.md` |
| C — competitive | product/competitor intel | `.../competitive-intelligence-report.md` |

Optional MultAI skills augment paths A–C only when user-requested in the current task.

## Conditional insertions

| Signal | Action |
|--------|--------|
| External spec to ingest | FLOW 5 via `silver:ingest` / `silver:spec` |
| Prior `.planning/research/` | Note continuity — still re-scope |

## Enforcement queue

`silver:clarify` → `silver:research` (or clarify-only chain per orchestrator).
`workflow-chain-guard` blocks implementation edits until clarify + research markers exist.

## Routing and pre-flight

1. Load preferences from `silver-bullet.md` §10.
2. Banner with research question.
3. Autonomous default — log `SB ► research composed {N} paths — orchestrator active`.

## Handoff (after FLOW 3 apply pass)

Ask: **A** `silver:feature` · **B** `silver:devops` · **C** research-only (summarize paths).

Pass artifact directory to the receiving composer as context.

## Step-skip protocol

No skip for `silver:clarify` when scope is ambiguous.

## Workflow tracking (fallback)

Same `scripts/workflows.sh` pattern with `/silver:research` and FLOW 3/4/5 names.

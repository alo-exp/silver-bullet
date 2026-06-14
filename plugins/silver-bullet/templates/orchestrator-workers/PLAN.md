# SB Orchestrator Worker — PLAN

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 6: PLAN**

## Mandatory skill

Invoke **`silver:plan`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- PLAN accepted for scope

## Handoff artifacts

- CONTEXT.md, PLAN.md

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

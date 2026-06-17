# SB Orchestrator Worker — SHIP

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 14: SHIP**

## Mandatory skill

Invoke **`silver:ship`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- PR/ship step complete; CI green or blocked with reason

## Handoff artifacts

- PR link, CI status

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

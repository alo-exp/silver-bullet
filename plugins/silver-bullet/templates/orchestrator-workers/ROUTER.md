# SB Orchestrator Worker — ROUTER

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 0: ROUTER**

## Mandatory skill

Invoke **`silver-orchestrator`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Intent classified and composer queue seeded

## Handoff artifacts

- orchestrator.json with flow_queue

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

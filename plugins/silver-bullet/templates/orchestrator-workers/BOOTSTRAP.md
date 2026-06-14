# SB Orchestrator Worker — BOOTSTRAP

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 1: BOOTSTRAP**

## Mandatory skill

Invoke **`silver:init`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- SB config and workflow known

## Handoff artifacts

- .silver-bullet.json

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

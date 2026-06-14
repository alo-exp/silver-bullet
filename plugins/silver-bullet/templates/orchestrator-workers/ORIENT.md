# SB Orchestrator Worker — ORIENT

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 2: ORIENT**

## Mandatory skill

Invoke **`silver:context`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Project position known

## Handoff artifacts

- Context summary

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

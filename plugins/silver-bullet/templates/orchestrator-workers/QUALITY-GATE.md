# SB Orchestrator Worker — QUALITY GATE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 13: QUALITY GATE**

## Mandatory skill

Invoke **`silver:quality-gates`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Blocking dimensions resolved or accepted

## Handoff artifacts

- Quality gate evidence

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

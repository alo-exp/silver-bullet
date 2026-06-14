# SB Orchestrator Worker — BLAST RADIUS

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW —: BLAST RADIUS**

## Mandatory skill

Invoke **`silver:blast-radius`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Blast radius assessed

## Handoff artifacts

- Blast radius notes

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

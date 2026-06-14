# SB Orchestrator Worker — VALIDATE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW —: VALIDATE**

## Mandatory skill

Invoke **`silver:validate`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- No BLOCK findings

## Handoff artifacts

- Validation report

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

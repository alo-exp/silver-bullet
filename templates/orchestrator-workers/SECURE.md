# SB Orchestrator Worker — SECURE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 11: SECURE**

## Mandatory skill

Invoke **`silver:secure`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- No blocking security findings

## Handoff artifacts

- SECURITY.md

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

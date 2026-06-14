# SB Orchestrator Worker — FAST

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW —: FAST**

## Mandatory skill

Invoke **`silver:fast`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Trivial change complete

## Handoff artifacts

- Minimal diff

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

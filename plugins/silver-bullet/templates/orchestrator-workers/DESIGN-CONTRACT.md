# SB Orchestrator Worker — DESIGN CONTRACT

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 7: DESIGN CONTRACT**

## Mandatory skill

Invoke **`silver:ui-contract`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- UI contract exists or waived

## Handoff artifacts

- UI-SPEC / contract

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

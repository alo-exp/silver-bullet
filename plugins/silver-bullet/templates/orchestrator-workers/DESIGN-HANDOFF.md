# SB Orchestrator Worker — DESIGN HANDOFF

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 16: DESIGN HANDOFF**

## Mandatory skill

Invoke **`silver:handoff`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Design-to-dev handoff prompt or notes produced when UI milestone scope applies

## Handoff artifacts

- Handoff prompt, design release notes (when applicable)

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

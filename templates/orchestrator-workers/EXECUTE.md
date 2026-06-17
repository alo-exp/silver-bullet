# SB Orchestrator Worker — EXECUTE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 8: EXECUTE**

## Mandatory skill

Invoke **`silver:execute`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Planned tasks complete with summary

## Handoff artifacts

- Code, tests, SUMMARY

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

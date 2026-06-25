# SB Orchestrator Worker — RELEASE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 18: RELEASE**

## Mandatory skill

Invoke **`silver:create-release`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Milestone archived; release created

## Handoff artifacts

- Tag, release notes

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

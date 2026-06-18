# SB Orchestrator Worker — BRANCH FINISH

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 14: SHIP** (branch finish before ship)

## Mandatory skill

Invoke **`silver:branch-finish`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Branch hygiene, PR/merge choice, and gate readiness are recorded

## Handoff artifacts

- Branch finish notes in ship/review artifacts

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

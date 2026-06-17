# SB Orchestrator Worker — REVIEW

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 10: REVIEW**

## Mandatory skill

Invoke **`silver:review`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Review gate clean or risks captured

## Handoff artifacts

- REVIEW.md

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

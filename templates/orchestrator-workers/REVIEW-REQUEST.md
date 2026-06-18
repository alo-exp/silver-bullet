# SB Orchestrator Worker — REVIEW REQUEST

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 10: REVIEW** (review triad — request)

## Mandatory skill

Invoke **`silver:review-request`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Review scope, risks, and artifacts are framed for review

## Handoff artifacts

- Review request notes linked to REVIEW.md scope

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

# SB Orchestrator Worker — REVIEW TRIAGE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 10: REVIEW** (review triad — triage)

## Mandatory skill

Invoke **`silver:review-triage`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- REVIEW.md findings are triaged — fixed, accepted, or deferred with evidence

## Handoff artifacts

- Updated REVIEW.md and deferred items filed via `silver:add` when required

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

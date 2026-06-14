# SB Orchestrator Worker — UI QUALITY

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 9: UI QUALITY**

## Mandatory skill

Invoke **`silver:ui-review`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- No blocking UI findings

## Handoff artifacts

- UI-REVIEW.md

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

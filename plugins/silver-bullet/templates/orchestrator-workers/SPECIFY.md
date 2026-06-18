# SB Orchestrator Worker — SPECIFY

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Contract

`docs/composable-flows-contracts.md` — **FLOW 5: SPECIFY**

## Mandatory skill

Invoke **`silver:spec`** through the active runtime's SB-recognized skill invocation channel before implementation edits.

When external artifacts exist, run **`silver:ingest`** first per the skill contract, then **`silver:spec`**.

## Acceptance criteria

- `.planning/SPEC.md` exists with acceptance criteria
- `.planning/REQUIREMENTS.md` exists when required by the spec skill
- Pre-build validation can run against the new spec

## Handoff artifacts

- `.planning/SPEC.md`
- `.planning/REQUIREMENTS.md` (when applicable)

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

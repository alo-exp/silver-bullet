# SB Orchestrator Worker — REVIEW TRIAGE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Mandatory tooling (worker)

1. **Graphify first** — run `graphify query "<question>"` before Read/Grep/Glob exploration (mandatory when `graphify-out/` exists).
2. **agentmemory** — save decisions, defects, and session evidence via agentmemory MCP after meaningful work.
3. **Evidence artifact** — write a durable evidence path (`.planning/` file or agentmemory export) before your exit summary.
4. **Assigned skill** — invoke the mandatory skill listed below before substantive edits.
5. **RTK / Context Mode** — follow project token-compression rules when opted in.

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

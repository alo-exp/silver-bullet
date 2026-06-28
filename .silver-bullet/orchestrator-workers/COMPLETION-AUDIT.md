# SB Orchestrator Worker — COMPLETION AUDIT

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Mandatory tooling (worker)

1. **Graphify first** — run `graphify query "<question>"` before Read/Grep/Glob exploration (mandatory when `graphify-out/` exists).
2. **agentmemory** — save decisions, defects, and session evidence via agentmemory MCP after meaningful work.
3. **Evidence artifact** — write a durable evidence path (`.planning/` file or agentmemory export) before your exit summary.
4. **Assigned skill** — invoke the mandatory skill listed below before substantive edits.
5. **RTK / Context Mode** — follow project token-compression rules when opted in.

## Contract

`docs/composable-flows-contracts.md` — **FLOW 12: VERIFY** (completion audit before delivery)

## Mandatory skill

Invoke **`silver:completion-audit`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- Completion claims are verified against evidence (PASS or explicit user acceptance)

## Handoff artifacts

- Completion audit notes / evidence summary

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.

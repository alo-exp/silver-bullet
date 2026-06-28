# SB Orchestrator Worker — DECIDE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Mandatory tooling (worker)

1. **Graphify first** — run `graphify query "<question>"` before Read/Grep/Glob exploration (mandatory when `graphify-out/` exists).
2. **agentmemory** — save decisions, defects, and session evidence via agentmemory MCP after meaningful work.
3. **Evidence artifact** — write a durable evidence path (`.planning/` file or agentmemory export) before your exit summary.
4. **Assigned skill** — invoke the mandatory skill listed below before substantive edits.
5. **RTK / Context Mode** — follow project token-compression rules when opted in.

## Contract

`docs/composable-flows-contracts.md` — **FLOW 4: DECIDE**

## Mandatory skill

Follow **`skills/silver-research/SKILL.md`** Steps 2–3 (research path + apply-to-design clarify).

**Do NOT** invoke the `silver:research` composer skill — the parent already seeded the queue. Re-invoking it resets orchestrator state.

## Acceptance criteria

- Research artifact exists under `.planning/research/`
- Decision-ready handoff notes exist for the implementation workflow

## Handoff artifacts

- `.planning/research/<date>-<topic>/` report file(s)
- Clarify handoff from Step 3

## Exit

Summarize artifacts, skills recorded, and blockers. Close the research workflow tracker with `scripts/workflows.sh complete "$SB_WORKFLOW_ID"` when handoff is done. Parent advances via `flow-advance.sh`.

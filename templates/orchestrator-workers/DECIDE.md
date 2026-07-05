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

Follow **`skills/silver-deep-research/SKILL.md`** for the selected FLOW 4
research depth. The flow step is `FS-SILVER_DEEP_RESEARCH`.

The deep-research engine is a nested workflow inside this flow step. Execute the
mode-appropriate internal steps (`DR-SCOPE`, `DR-PLAN`, `DR-RETRIEVE`,
`DR-TRIANGULATE`, `DR-OUTLINE`, `DR-SYNTHESIZE`, `DR-CRITIQUE`,
`DR-REFINE`, `DR-PACKAGE`) and record their local V-loop results in
`vloop-rollup.json`.

**Do NOT** invoke the `silver:deep-research` composer skill — the parent already
seeded the queue. Re-invoking it resets orchestrator state.

There is no MultAI branch in AF-DECIDE.

## Acceptance criteria

- Research artifact exists under `.planning/research/`
- `vloop-rollup.json` shows every required internal phase V-loop passed or was
  explicitly skipped by the selected mode
- Decision-ready handoff notes exist for the implementation workflow

## Handoff artifacts

- `.planning/research/<date>-<topic>/` report file(s)
- `.planning/research/<date>-<topic>/decision-record.md`
- Clarify handoff from Step 3

## Exit

Summarize artifacts, skills recorded, and blockers. Close the research workflow tracker with `scripts/workflows.sh complete "$SB_WORKFLOW_ID"` when handoff is done. Parent advances via `flow-advance.sh`.

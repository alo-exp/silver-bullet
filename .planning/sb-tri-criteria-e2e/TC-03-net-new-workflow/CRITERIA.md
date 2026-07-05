# TC-03 — Net-New Workflow Creation

**Criterion:** SB creates a **new** workflow (not tailoring existing WF-*) via `silver-new-workflow` / `NEW-WORKFLOW` worker.  
**Primary outcome:** `OUT-NEWWF-01`

## Success criteria

| # | Requirement |
|---|-------------|
| 1 | `OUT-NEWWF-01: pass` — NEW-WORKFLOW dispatched + net-new spec artifact |
| 2 | `OUT-ORCH-01: pass` (parent mode) |
| 3 | `OUT-AUTO-01`, `OUT-NOOP-01`, `OUT-WORLD-01` pass |
| 4 | Compliance script + JSON + markdown report committed |
| 5 | New workflow spec in `.planning/workflows/` with novel workflow_id |

## Forbidden shortcuts

- Reuse `silver-benchmark` / `silver-deep-research` as substitute
- Operator-authored workflow markdown without NEW-WORKFLOW worker
- Fake workflow_id that maps 1:1 to existing catalog entry

## Evidence

- `orchestrator-events.jsonl`: `dispatch` with `NEW-WORKFLOW` or `silver-new-workflow`
- `.planning/workflows/<new-compliance-workflow>.md`
- Optional: `docs/apo-catalog.d/*.json` fragment
- `scripts/*compliance*` + `.planning/compliance/*.md`

## Advisory

`OUT-KM-01`, `OUT-FLOW-01`, `OUT-TRACE-01`

## Alternate host

Agent-claude delegation acceptable when `SB_TRI_CRITERIA_HOST=agent-claude` — score still uses `OUT-NEWWF-01`.

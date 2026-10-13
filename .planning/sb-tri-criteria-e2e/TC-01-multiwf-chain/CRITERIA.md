# TC-01 — Autonomous Multi-Workflow Chain

**Criterion:** ≥3 distinct catalog `workflow_id`s chained without operator workflow selection.  
**Primary outcome:** `OUT-MULTIWF-01`

## Success criteria

| # | Requirement |
|---|-------------|
| 1 | `OUT-MULTIWF-01: pass` — ≥3 unique `workflow_id` in composition log and/or events |
| 2 | `OUT-ORCH-01: pass` — parent Task workers only |
| 3 | `OUT-AUTO-01: pass` — no babysitting |
| 4 | `OUT-NOOP-01: pass` — no automatable decision pauses |
| 5 | `OUT-WORLD-01: pass` — composite |
| 6 | Waitlist API + landing + Docker + ship artifact committed |

## Forbidden shortcuts

- Single `silver-feature` queue only
- Operator picks `/silver:devops` manually mid-session
- `npm test` without multi-workflow chain
- Counting AF-* atoms as workflow_ids

## Evidence

- `runs/<id>/parent-session.log`
- `<work_dir>/.planning/orchestrator-composition-log.jsonl`
- `$SB_RUNTIME_STATE_DIR/orchestrator-events.jsonl`
- `runs/<id>/ledger.json` with `verdict: PASS`

## Advisory

`OUT-KM-01`, `OUT-VLOOP-01`, `OUT-TRACE-01`, `OUT-FLOW-01`

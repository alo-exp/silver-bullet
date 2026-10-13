# TC-02 — Dynamic Workflow Composition

**Criterion:** Tailor pre-existing workflows via catalog `dynamic_rules` (prune/insert/substitute/parallelize/loop).  
**Primary outcome:** `OUT-DYNAMIC-01`

## Success criteria

| # | Requirement |
|---|-------------|
| 1 | `OUT-DYNAMIC-01: pass` — ≥2 dynamic ops with valid `catalog_rule_ref` |
| 2 | `OUT-TAILOR-01: pass` — route tailored from default |
| 3 | `OUT-ORCH-01`, `OUT-AUTO-01`, `OUT-NOOP-01`, `OUT-WORLD-01` pass |
| 4 | README badge committed; no spurious feature pipeline artifacts |

## Forbidden shortcuts

- Unmodified default `silver-feature` full queue
- Operator `/silver:fast` manual override
- Empty or invalid `catalog_rule_ref` in composition log
- Single op only (below minimum diversity)

## Evidence

- `.planning/orchestrator-composition-log.jsonl` with `operations[]` + `scheduler_decisions`
- Cross-check refs against `docs/apo-catalog.json` `dynamic_rules`
- `parent-session.log`

## Advisory

`OUT-KM-01`, `OUT-TRACE-01`, `OUT-FLOW-01`

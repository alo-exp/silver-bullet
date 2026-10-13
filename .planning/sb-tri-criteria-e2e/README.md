# SB Tri-Criteria E2E Framework

**Status:** **tri-host live complete** — 9/9 PASS ([TRI-HOST-RESULT-20260706.md](TRI-HOST-RESULT-20260706.md))  
**Vision anchor:** [`docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md`](../../docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md)  
**Canonical multi-workflow bar:** [CURSOR-MULTIWF-CRITERIA.md](CURSOR-MULTIWF-CRITERIA.md) (mirrors auto-e2e)

## Three falsifiable criteria

| Track | Criterion | Host path | Primary outcome |
|-------|-----------|-----------|-----------------|
| [TC-01-multiwf-chain](TC-01-multiwf-chain/) | Autonomous multi-workflow chaining | Cursor parent orchestrator | `OUT-MULTIWF-01` |
| [TC-02-dynamic-compose](TC-02-dynamic-compose/) | Dynamic workflow composition | Cursor parent orchestrator | `OUT-DYNAMIC-01` |
| [TC-03-net-new-workflow](TC-03-net-new-workflow/) | Net-new workflow creation | Cursor parent or agent-claude | `OUT-NEWWF-01` |

## Distinct from sibling tracks

| Track | What it proves |
|-------|----------------|
| Enterprise 22-row matrix | Host certification breadth (historically babysat) |
| Minimal-intent (MI-01) | Full lifecycle from one vision paragraph |
| Agent-claude 3-row | Claude TUI autonomous delegation |
| **Tri-criteria (this)** | Three orthogonal SB capabilities with falsifiable evidence |

## Harness

```bash
bash scripts/sb-tri-criteria-e2e.sh preflight
bash scripts/sb-tri-criteria-e2e.sh cold --track TC-01   # recommended cold proof
bash scripts/sb-tri-criteria-e2e.sh start --track TC-01  # live parent session
bash scripts/sb-tri-criteria-e2e.sh score --run <run-id> --track TC-01
```

## Artifacts

| File | Purpose |
|------|---------|
| [DESIGN.md](DESIGN.md) | Full design: success definitions, forbidden shortcuts, goal prompts |
| [MATRIX.json](MATRIX.json) | Umbrella matrix (all three tracks) |
| `TC-*/RUNBOOK.md` | Per-track operator steps |
| `TC-*/CRITERIA.md` | Per-track blocking/advisory outcomes |
| `TC-*/MATRIX.json` | Per-track row definitions |
| `TC-*/fixtures/` | Vision paragraphs and prefs |

**Do not claim PASS** until live session completes and score exits 0.

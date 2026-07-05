# Minimal-Intent Full Development E2E (Design Track)

**Status:** scaffold only — **not yet run**  
**Vision anchor:** [`docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md`](../../docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md)  
**Distinct from:**

| Track | Entry | Executor |
|-------|-------|----------|
| Enterprise 22-row matrix | Per-row harness prompts | Host TUI (historically babysat) |
| Agent-claude 3-row | Harness brief → Claude delegate | Claude TUI via `/silver:agent-claude` |
| **Minimal-intent (this)** | User vision paragraph + optional prefs | **Cursor parent orchestrator** + Task workers |

## North star

Prove SB can drive a **development lifecycle end-to-end** from **minimal user intent** — one paragraph vision plus optional preferences file — with the parent orchestrator composing and advancing clarify/spec → plan → implement → verify → review → ship (subset justified per session).

## Artifacts

| File | Purpose |
|------|---------|
| [RUNBOOK.md](RUNBOOK.md) | Operator preflight, start, score |
| [CRITERIA.md](CRITERIA.md) | Success criteria aligned with inverted role model |
| [MATRIX.json](MATRIX.json) | Single-row scaffold (MI-01); expandable |
| `fixtures/MI-01-vision.md` | Example minimal intent |
| `fixtures/MI-01-prefs.json` | Optional minimal preferences |

## Harness

```bash
bash scripts/minimal-intent-autonomous-e2e.sh preflight
bash scripts/minimal-intent-autonomous-e2e.sh start --row MI-01
bash scripts/minimal-intent-autonomous-e2e.sh score --run <run-id>
```

**Do not claim PASS** until a live parent-orchestrator session completes and score exits 0.

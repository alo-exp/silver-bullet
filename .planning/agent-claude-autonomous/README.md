# Agent-Claude Autonomous Vision Test (Fresh Track)

**Status:** complete (3/3 PASS — see MATRIX-LEDGER.json)  
**Started:** 2026-07-06  
**Mechanism:** [`/silver:agent-claude`](../../skills/silver-agent-claude/SKILL.md) — **not** legacy Round 9 Gate 3 matrix  
**Vision anchor:** [`docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md`](../../docs/PRODUCT-VISION-AUTONOMOUS-ENTERPRISE.md)

## Complexity policy (mandatory)

Autonomous certification requires **complex multi-workflow goals** — never smoke-only (`npm test`), single-step tasks, or health-check verification. See [`.planning/sb-tri-criteria-e2e/CURSOR-MULTIWF-CRITERIA.md`](../sb-tri-criteria-e2e/CURSOR-MULTIWF-CRITERIA.md). Codex smoke runs flagged for re-run under this bar.

**Related:** [SB tri-criteria E2E](../sb-tri-criteria-e2e/) — TC-03 can use agent-claude as alternate host for net-new workflow proof.

## Why a fresh track

Prior Claude enterprise E2E (6/22 registry, possible 22/22 narrative) exercised the **matrix harness** with operator babysitting. That is **not** the autonomous vision proof target per PRODUCT-VISION §6.2.

This track proves whether **Claude TUI invoked via agent-claude** can drive SB autonomously on the **current working-copy `install_fp`** with inverted human/agent roles:

| Role | Actor |
|------|-------|
| Supervisor (minimal) | Cursor parent / harness operator |
| Executor | Claude TUI in `enterprise-grade-test-app` via `agent-claude-delegate.sh` |

## Artifacts

| File | Purpose |
|------|---------|
| [RUNBOOK.md](RUNBOOK.md) | Operator steps, preflight, launch, score |
| [CRITERIA.md](CRITERIA.md) | Success criteria, blocking vs advisory outcomes |
| [EVIDENCE-TEMPLATE.md](EVIDENCE-TEMPLATE.md) | Per-run evidence checklist |
| [MATRIX.json](MATRIX.json) | Minimal 3-row fresh matrix (not 22 legacy rows) |
| `runs/<run-id>/` | Per-run ledger, brief, log, outcomes (gitignored logs) |

## Harness

```bash
bash scripts/agent-claude-autonomous-test.sh preflight
bash scripts/agent-claude-autonomous-test.sh start --row AUTO-C01
bash scripts/agent-claude-autonomous-test.sh score --run <run-id>
```

## Certification policy

- Does **not** upgrade Claude to 22/22 without fresh agent-claude evidence.
- Adds evidence pointer only: `docs/testing/host-certification-sources.json` → `agent_claude_autonomous`.
- Canonical matrix ledger remains `.planning/enterprise-e2e/ROUND-9-LEDGER.md` until this track completes and is reconciled separately.

# Cursor Multi-Workflow Criteria (SB mirror)

**Canonical upstream:** [auto-e2e `.planning/auto-e2e-note-app/CURSOR-MULTIWF-CRITERIA.md`](https://github.com/alo-exp/auto-e2e/blob/main/.planning/auto-e2e-note-app/CURSOR-MULTIWF-CRITERIA.md)

This file mirrors the bar for **Silver Bullet repo** tri-criteria E2E tracks. When upstream changes, reconcile this mirror.

## Mandatory bar

Autonomous proof requires **complex multi-workflow goals**:

1. **Multi-workflow DAG** — clarify/spec → plan → execute → verify+ (or justified subset spanning ≥3 catalog `workflow_id`s for TC-01)
2. **One vision paragraph** — no harness step list in user input
3. **Multiple `.planning/` artifacts** — specs, plans, workflow logs, composition log
4. **Substantive commits** — not `npm test` only, not health-check smoke, not single-file typo fixes

## Invalid proof targets

| Invalid | Valid alternative |
|---------|-------------------|
| `npm test` only | Feature + verify + ship chain |
| Single AF-* atom | Multiple workflows or dynamic composition |
| Install/bootstrap only | Product delta on fixture app |
| Operator micro-prompting each worker | Parent orchestrator autonomous advance |

## SB tri-criteria mapping

| Criterion | Multi-workflow aspect |
|-----------|----------------------|
| TC-01 | Explicit ≥3 `workflow_id` gate (`OUT-MULTIWF-01`) |
| TC-02 | Dynamic tailoring ≠ default queue (`OUT-DYNAMIC-01`) |
| TC-03 | Net-new workflow creation (`OUT-NEWWF-01`) |

## References in SB repo

- [`.planning/sb-tri-criteria-e2e/DESIGN.md`](DESIGN.md)
- [`.planning/minimal-intent-e2e/CRITERIA.md`](../minimal-intent-e2e/CRITERIA.md)
- [`.planning/agent-claude-autonomous/CRITERIA.md`](../agent-claude-autonomous/CRITERIA.md)

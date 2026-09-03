# Review charter

## Scope (locked)

1. [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../PRD-silver-doctor-opt-in-coverage.md) — review target (do not edit during REVIEW-ONLY)
2. [`.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/`](./) — ladder artifacts only (`review.md`, Policy C, ledger)

**FORBIDDEN** outside those paths. Do not open the freeze [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) unless citing a PRD cross-link that already exists in the PRD. Do not implement doctor code.

## Goals

1. The PRD is internally consistent and implementable as Session A (D10 completeness on live `sb-doctor.sh` + reconciler).
2. Bird's-eye: missing product slices, wrong scope fork, contradictions with stated current system, untestable "done when".
3. Ant's-eye: wrong paths, stale D10 lists, `--fix` swallow, host matrix, N/A vs FAIL, search_cli canary, Omni WS7 vs D10 stuffing, docs-pin, secrets, five-tool mutex.
4. Findings have `file:line` (or heading + quote) and severity HIGH / MED / LOW / NIT.

## Non-goals

- Implementing `/silver:doctor` or probes
- Editing the router-subagent freeze
- Session B unbounded generic installer (PRD correctly rejects it; do not reopen as a goal)
- Repo-wide audit

## Verification signals (orchestrator)

After each verify pass, from repo root:

```bash
test -f .planning/PRD-silver-doctor-opt-in-coverage.md
rg -n "Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A" .planning/PRD-silver-doctor-opt-in-coverage.md
rg -n "four surfaces|Setup|Health|Diagnosis|--fix" .planning/PRD-silver-doctor-opt-in-coverage.md
```

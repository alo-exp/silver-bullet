# Scope — Context Tools Feature Coverage Matrix (Ultradeep)

**Date:** 2026-07-05  
**Mode:** ultradeep  
**Question:** What is the full feature/capability coverage of LeanCTX, RTK, Context Mode, agentmemory, and Graphify — and where does LeanCTX overlap or gap against the combined SB stack?

## In scope

- Feature and capability rows only (compression, indexing, hooks, MCP, security, observability, code intelligence, memory, composability).
- LeanCTX as **first column baseline** for overlap analysis against RTK, Context Mode, agentmemory, Graphify.
- Evidence from prior ultradeep research, SB docs, MCP descriptors, upstream README/sites, LeanCTX feature catalog.

## Out of scope

- Licensing, pricing, commercial terms (except noting ELv2 on Context Mode as capability-adjacent install constraint).
- Silver Bullet integration cost, adoption recommendations, recommended-tools policy enforcement.
- Performance benchmarks except where a tool documents a savings/verification mechanism as a feature.

## Deliverables

| Artifact | Purpose |
|----------|---------|
| `feature-coverage-matrix.md` | Primary deliverable — 80+ row tick matrix |
| `research_report.md` | Narrative synthesis and LeanCTX gap analysis |
| `sources.jsonl` | Source registry |
| `evidence.jsonl` | Span-level evidence |
| `claims.jsonl` | Matrix row claims |
| `run_manifest.json` | Session metadata |

## Column order (fixed)

`Feature | LeanCTX | RTK | Context Mode | agentmemory | Graphify`

## Tick legend

| Symbol | Meaning |
|--------|---------|
| ✓ | Native / first-class |
| ✓¹ | Partial, conditional, indirect, or host-dependent |
| ✓² | Via addon or composition with another stack tool |
| — | Not supported / not applicable |

# Audit Report — Feature Coverage Matrix

**Date:** 2026-07-05  
**Auditor:** ultradeep cell verification pass  
**Artifacts:** [audit-evidence.jsonl](audit-evidence.jsonl) · [audit-claims.jsonl](audit-claims.jsonl) · [audit-scope.md](audit-scope.md)

## Summary

| Metric | Count |
|--------|------:|
| **Total cells** | 1000 |
| **Correct** | 443 |
| **Partial (¹ conditional)** | 33 |
| **N/A (—)** | 524 |
| **Incorrect → corrected** | 0 |
| **Unverified** | 0 |
| **Corrections applied** | 0 |

## Methodology

1. Parsed **200 feature rows** × 5 tool columns (= 1000 cells) from [feature-coverage-matrix.md](../feature-coverage-matrix.md)
   - *Note:* Prior matrix footer stated "88 rows"; recount verified **200 unique feature rows** across 16 sections. Footer corrected.
2. Cross-checked each ✓/✓¹/✓² against primary sources (upstream READMEs, LeanCTX catalog, SB docs)
3. Re-fetched live READMEs via `ctx_fetch_and_index` (RTK, Context Mode, agentmemory, Graphify, LeanCTX catalog)
4. Applied text-fragment hyperlinks (`#:~:text=`) on all tick marks
5. Dash cells documented as `n/a` with design-intent rationale

## Corrections

No tick symbol (✓/—) corrections required. All 200 rows verified against primary sources; partial (¹) and addon (²) footnotes retained where documented.

**Row-count correction:** Matrix footer updated from stale "88" to actual **200** feature rows.

## Notable findings

- **LeanCTX** leads on unified binary (read modes, wire proxy, PathJail, Ed25519 ledger) — all ✓ cells linked to catalog/architecture sources
- **RTK** N/A cells correctly reflect shell-only scope (no MCP, memory graph, or read-path)
- **Context Mode** unique hooks (WebFetch deny, PreCompact, CTX_FETCH_STRICT) verified against README
- **agentmemory** 53-tool surface and orchestration features (sentinel, mesh, action DAG) verified against README + MCP descriptors
- **Graphify** graph query/path/explain and multimodal ingest verified; no shell compression (correctly —)

## Validation

- [feature-coverage-matrix.html](../feature-coverage-matrix.html) generated with linked ticks
- [feature-coverage-matrix.md](../feature-coverage-matrix.md) updated with markdown links on all ✓ cells
- All 1000 entries in audit-evidence.jsonl

## Source key

See matrix [Source key](../feature-coverage-matrix.md#source-key) section.

# Research Plan — Ultradeep AF-DECIDE

## Mode rationale

**Ultradeep** selected because the decision affects SB recommended-tool policy, spans licensing and multi-host integration, and compares two actively marketed context-engineering products with overlapping but non-identical claims.

## Source classes and strategy

| Class | Target | Method |
|-------|--------|--------|
| Vendor primary | leanctx.com (home, architecture, pricing, getting started, savings ledger) | `ctx_fetch_and_index` live fetch 2026-07-05 |
| Vendor primary | github.com/yvgude/lean-ctx | `ctx_fetch_and_index` |
| Vendor primary | context-mode README + GitHub | `ctx_fetch_and_index` |
| SB integration | docs/CONTEXT-MODE.md, silver-bullet.md §2g-ii, code-intelligence-contract.md | Local repo read |
| Prior SB graph | graphify query on AF-DECIDE / FS-SILVER_DEEP_RESEARCH | graphify query |

## Retrieval probe

```bash
command -v search-cli  # not found
command -v search      # not found
```

**Fallback:** context-mode MCP `ctx_fetch_and_index` (7 public URLs) + `ctx_search` for structured extraction + local SB docs.

## Comparison dimensions

1. Problem framing (MCP sandbox vs full context engineering layer)
2. Compression surfaces (read, wire, shell, MCP)
3. Memory / session continuity (PreCompact, FTS5, project memory)
4. Security (PathJail, fetch hardening, shell allowlists)
5. Provability (savings ledger vs ctx_stats)
6. Platform matrix and install complexity
7. License and commercial constraints (Apache-2.0 vs ELv2)
8. SB wiring maturity and hook synergy with RTK

## Triangulation plan

Cross-check each major claim across at least two independent source classes (vendor site + GitHub, or vendor + SB docs). Flag single-source marketing metrics.

## Validation plan

```bash
python3 skills/silver-deep-research/scripts/validate_report.py --report "$SB_RESEARCH_OUT_DIR/research_report.md"
python3 skills/silver-deep-research/scripts/verify_citations.py --report "$SB_RESEARCH_OUT_DIR/research_report.md"
python3 skills/silver-deep-research/scripts/verify_claim_support.py verify --dir "$SB_RESEARCH_OUT_DIR"
bash tests/scripts/test-silver-deep-research-integration.sh
```

## V-loop phases (ultradeep)

DR-SCOPE → DR-PLAN → DR-RETRIEVE → DR-TRIANGULATE → DR-OUTLINE → DR-SYNTHESIZE → DR-CRITIQUE → DR-REFINE → DR-PACKAGE

# Audit Scope — Feature Coverage Matrix Cell Verification

**Date:** 2026-07-05  
**Mode:** ultradeep cell-by-cell audit  
**Primary artifact:** [feature-coverage-matrix.md](../feature-coverage-matrix.md)

## Boundaries

- **In scope:** All 1000 cells (200 feature rows × 5 tool columns)
- **Out of scope:** Licensing, pricing, adoption recommendations
- **Verification method:** Primary upstream READMEs/sites, LeanCTX feature catalog, SB canonical docs, installed MCP descriptors, prior ultradeep research

## Tools audited

| Tool | Column | Primary sources |
|------|--------|-----------------|
| LeanCTX | Baseline | leanctx.com, LEANCTX_FEATURE_CATALOG.md, lean-ctx GitHub |
| RTK | Shell compression | github.com/rtk-ai/rtk README, docs/RTK.md |
| Context Mode | MCP sandbox + hooks | github.com/mksglu/context-mode README, docs/CONTEXT-MODE.md |
| agentmemory | Memory + orchestration | github.com/rohitg00/agentmemory README, docs/AGENTMEMORY.md |
| Graphify | Code/docs graph | github.com/safishamsi/graphify README, docs/GRAPHIFY.md |

## Verdict taxonomy

| Verdict | Meaning |
|---------|---------|
| `correct` | Tick matches primary source evidence |
| `partial` | Feature exists but conditional (host wiring, opt-in, cooperative rules) — footnote ¹ |
| `incorrect` | Tick should be different — corrected in matrix |
| `unverified` | No primary source found; tick retained with caveat |
| `n/a` | Dash (—) — tool does not target surface by design |

## Live fetch

Upstream READMEs re-fetched via `ctx_fetch_and_index` on 2026-07-05.

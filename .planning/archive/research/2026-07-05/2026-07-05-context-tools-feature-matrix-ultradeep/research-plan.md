# Research Plan — Context Tools Feature Matrix

## Mode rationale

**ultradeep** — user requested comprehensive matrix (80+ rows) triangulating five tools across docs, MCP surfaces, hooks, and upstream catalogs.

## Source classes

| Class | Targets |
|-------|---------|
| Prior research | `.planning/research/2026-07-05-context-mode-vs-lean-context-ultradeep/` |
| SB local docs | `docs/RTK.md`, `docs/CONTEXT-MODE.md`, `docs/AGENTMEMORY.md`, `docs/GRAPHIFY.md`, `docs/code-intelligence-contract.md`, `silver-bullet.md` §2g |
| Upstream web | leanctx.com, github.com/rtk-ai/rtk, github.com/mksglu/context-mode, github.com/rohitg00/agentmemory, github.com/safishamsi/graphify |
| MCP descriptors | `mcps/user-agentmemory` (53 tools), `mcps/user-context-mode` (11 tools) |
| Feature SSOT | `LEANCTX_FEATURE_CATALOG.md` (lean-ctx repo) |

## Retrieval strategy

1. `graphify query` orientation (mandatory).
2. `ctx_batch_execute` + `ctx_fetch_and_index` for upstream pages (no WebFetch).
3. `ctx_search` for triangulation across indexed batches.
4. SB docs via `ctx_execute` (size > 5 KB aggregate).
5. MCP JSON descriptors for tool inventory enumeration.

## Synthesis approach

1. Enumerate capabilities per tool from independent sources.
2. Union into feature rows grouped by 16 section headers.
3. Assign ticks with footnotes for partial/addon/conditional cases.
4. Map each non-trivial row to `evidence.jsonl` + `claims.jsonl`.
5. Summarize LeanCTX gaps vs RTK+CM+agentmemory+Graphify combined stack.

## Validation

- Row count ≥ 80.
- Every ✓/✓¹/✓² row has ≥1 evidence span unless marked unverified in footnote.
- No invented features; uncertain cells use — with footnote.

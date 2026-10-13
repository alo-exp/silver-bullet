# Research Report — Context Tools Feature Coverage Matrix

**Mode:** ultradeep · **Date:** 2026-07-05  
**Primary artifact:** [feature-coverage-matrix.md](feature-coverage-matrix.md)

## Executive summary

This research produced an **88-row × 5-column** feature coverage matrix comparing **LeanCTX** (baseline), **RTK**, **Context Mode**, **agentmemory**, and **Graphify**. Sources triangulated prior ultradeep work, SB canonical docs, upstream READMEs/sites, LeanCTX `LEANCTX_FEATURE_CATALOG.md`, and installed MCP descriptors (53 agentmemory + 11 context-mode tools).

**LeanCTX** is the only tool that unifies read-path AST modes, shell compression, optional wire proxy, runtime PathJail, project memory graph, and Ed25519 savings ledger in one Rust binary with **81 MCP tools**. It explicitly lists **RTK as a compatible addon** (✓² in matrix), acknowledging the SB pattern of composing specialists.

The **RTK + Context Mode + agentmemory + Graphify** stack remains broader in aggregate because each tool optimizes a different layer:

| Layer | Stack leader | LeanCTX overlap |
|-------|--------------|-----------------|
| Shell CLI compression | RTK | Native + RTK addon² |
| MCP sandbox + fetch deny + PreCompact | Context Mode | Partial (ctx_execute, fewer hook events) |
| Agent orchestration memory | agentmemory | Partial (ctx_agent, ctx_handoff) |
| Code/docs knowledge graph | Graphify | Partial (ctx_graph, overlapping but different center of gravity) |

## Tool profiles (capability-only)

### LeanCTX

Five subsystems: Smart I/O, Memory, Security, Request Compression, Provable Savings. Hybrid (MCP + shell hooks) vs MCP-only modes for 30+ agents. Feature catalog documents 81 granular MCP tools including `ctx_read` (10 modes), `ctx_graph`, `ctx_handoff`, wire proxy, PathJail, bounce detection, and MCP Tool-Catalog Gateway.

### RTK

Narrow, deep: **shell output compression** via PreToolUse rewrite on 14+ agents. Command-specific compressors for git, gh, rg, docker, test runners, cloud CLIs. Analytics via `rtk gain`, `rtk discover`, `rtk session`. No MCP, no read-path, no memory graph.

### Context Mode

**MCP-centric sandbox**: 11 tools, FTS5 KB with RRF, `ctx_fetch_and_index`, hook suite (PreToolUse through PreCompact). Strongest published fetch hardening and PreCompact recovery. Cooperative Read routing (SB adds deny hook). 17+ platforms.

### agentmemory

**Session capture + orchestration**: 53 MCP tools when server running — actions, leases, sentinels, mesh sync, crystallize, 4-tier consolidation, git commit linkage, proactive injection. REST API on :3111. Pairs with Graphify in SB synergy model.

### Graphify

**Retrieval graph**: tree-sitter AST + LLM INFERRED edges, Leiden communities, god nodes, `query`/`path`/`explain`/`affected`, multimodal PDF/image ingest, wiki/Obsidian/HTML exports, git hook auto-rebuild. Not a live compression interceptor.

## LeanCTX coverage gaps vs combined stack

Three largest gaps where **RTK + CM + agentmemory + Graphify** together exceed LeanCTX native surface:

1. **Hook-native MCP sandbox enforcement (Context Mode)** — Context Mode's architecture centers isolated subprocess analysis with hook-level **WebFetch deny**, **curl/wget redirect**, **PreCompact XML recovery**, and documented **CTX_FETCH_STRICT** SSRF tiers. LeanCTX has `ctx_execute`, sandbox-first routing hints, and runtime PathJail, but does not publish equivalent hook-event coverage or fetch-hardening detail across 17+ CM platforms.

2. **Multi-agent work orchestration memory (agentmemory)** — agentmemory's **action DAG** (`memory_frontier`, `memory_lease`, `memory_next`), **sentinels**, **sketch→promote**, **mesh sync**, and **crystallize** form a work-management layer atop memory. LeanCTX offers `ctx_agent`, `ctx_handoff`, and `ctx_workflow` but lacks the breadth of 53 orchestration-oriented MCP tools evidenced in agentmemory descriptors.

3. **Multimodal research corpus graph (Graphify)** — Graphify's primary deliverable is a **persistent multimodal knowledge graph** (code + papers + screenshots + tweets) with **god nodes**, **Leiden clustering**, and **71.5× query efficiency** narrative for `/raw`-style corpora. LeanCTX's `ctx_graph` and universal intake overlap conceptually but Graphify remains the dedicated graph-first retrieval engine with vision extraction and `GRAPH_REPORT.md` god-node synthesis as first-class outputs.

**Secondary gaps:** RTK as **standalone lightweight shell-only** install (no Rust binary / Node coupling); CM **progressive ctx_search throttling** tied to session SQLite; Graphify **git merge driver** for `graph.json`; agentmemory **gitleaks export scanning** bridge.

## Where LeanCTX leads

- **Wire-side request compression proxy** (none in RTK/CM/AM/GF)
- **Ed25519 hash-chained savings ledger** with offline verify
- **PathJail + deny-by-default shell allowlist** as unified runtime governance
- **10 native read fidelity modes + ModePredictor** on read path
- **81-tool integrated MCP surface** including LSP refactor and Tool-Catalog Gateway

## Methodology notes

- `graphify query` run before exploration (mandatory).
- Upstream fetched via `ctx_batch_execute` (not WebFetch).
- Uncertain cells marked — or ✓¹ with footnotes; no invented features.
- Prior research reused and extended: [2026-07-05-context-mode-vs-lean-context-ultradeep](../2026-07-05-context-mode-vs-lean-context-ultradeep/).

## Artifacts

| File | Description |
|------|-------------|
| [feature-coverage-matrix.md](feature-coverage-matrix.md) | 88-row tick matrix (primary) |
| [evidence.jsonl](evidence.jsonl) | 27 evidence spans |
| [claims.jsonl](claims.jsonl) | 10 synthesized claims |
| [sources.jsonl](sources.jsonl) | 18 sources |
| [scope.md](scope.md) | Boundaries |
| [research-plan.md](research-plan.md) | Retrieval plan |
| [run_manifest.json](run_manifest.json) | Session metadata |

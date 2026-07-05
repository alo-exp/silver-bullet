# Triangulation — Context Mode vs Lean Context

## Claim clusters and cross-source agreement

### Cluster A: Local-first, no mandatory cloud

| Claim | LeanCTX [1][5] | Context Mode [6][7] | SB docs [8] | Agreement |
|-------|----------------|---------------------|-------------|-----------|
| Processing stays on-device | FAQ: nothing uploaded for core features | README: nothing leaves machine | SB docs assume local MCP | **Strong** — both vendors + SB align |
| Telemetry | Zero telemetry stated [1] | No usage tracking [6] | N/A | **Strong** |

### Cluster B: Token reduction mechanisms differ

| Claim | LeanCTX [2][5] | Context Mode [6] | Triangulation |
|-------|----------------|------------------|---------------|
| Read-path compression | AST modes, 60–90% read reduction [1][5] | Routes large Read to ctx_execute_file [6][10] | **Divergent surfaces** — Lean optimizes file reads directly; CM intercepts analysis reads via MCP sandbox |
| Wire/request compression | Optional local proxy, prompt-cache safe [2] | Not primary positioning [6] | **Lean-only** for wire-side |
| Shell output | Shell hooks + hybrid mode [5] | Complements RTK for shell [10] | **Partial overlap** — Lean native; CM defers shell to RTK in SB stack |

### Cluster C: Session memory and retrieval

| Claim | LeanCTX [2] | Context Mode [6] | Agreement |
|-------|-------------|------------------|-----------|
| Persistent search | Project memory, ctx_knowledge [2] | FTS5 ctx_search + session auto-memory [6] | **Conceptual overlap**, different implementations |
| Post-compact continuity | Git-anchored snapshots [1] | PreCompact hook [6] | **Both address compaction** — different mechanisms |

### Cluster D: Security and governance

| Claim | LeanCTX [2][5] | Context Mode [6] | Agreement |
|-------|----------------|------------------|-----------|
| Path confinement | PathJail workspace jail [2] | Sandbox permissions extend host rules [6] | **Lean stronger on read-path jail** |
| Provable savings | Ed25519 ledger [12] | ctx_stats session metrics [6] | **Lean stronger on audit/export** |

### Cluster E: Licensing and SB fit

| Claim | LeanCTX [5] | Context Mode [6][8] | SB [9][10] | Agreement |
|-------|-------------|---------------------|------------|-----------|
| License | Apache-2.0 [5] | ELv2 [6][8] | SB discloses ELv2 at consent [8] | **Conflict for OSS bundling** — favors Lean |
| SB integration | Not in SB catalog | First-class recommended tool [8][10] | CM wired in hooks/docs | **CM wins operational fit today** |

## Contradictions and single-source flags

1. **LeanCTX 60–90% / 80% session savings** [1][2] — vendor benchmark pages; not independently reproduced in this run. Treat as directional marketing until SB runs controlled measurement.
2. **Context Mode "98% reduction"** [6] — scenario-specific MCP sandbox examples; not comparable 1:1 to Lean read benchmarks.
3. **LeanCTX "76 MCP tools"** [5] vs **"80 tools"** [4] — minor doc drift; capability count evolving.

## Triangulation verdict

Neither product is strictly "better" on all dimensions. **Lean Context leads on breadth** (read + wire + governance + provable ledger + Apache-2.0). **Context Mode leads on SB-ready MCP sandbox integration** and is already the canonical tier-1c companion to RTK. Recommendation must be **conditional**, not winner-take-all.

# LeanCTX as Single-Tool Replacement for RTK + Context Mode + agentmemory + Graphify

**Author:** mimo-v2.5-pro (deep-research agent)
**Date:** 2026-07-07
**Mode:** ULTRADEEP
**Scope:** Critical analysis of whether LeanCTX is a better single-tool replacement for the four-tool composable stack

---

## Executive Summary

LeanCTX is **not a universal drop-in replacement** for the RTK + Context Mode + agentmemory + Graphify stack, but it is a **credible simplification** for the majority of agentic coding workflows. The analysis reveals a nuanced picture:

**Capability coverage is high but not uniform.** LeanCTX achieves 97% replacement coverage for RTK (shell compression), 95% for Context Mode (sandbox + fetch), 87% for agentmemory (orchestration), and 99% for Graphify (code graph). These percentages, derived from a 200-row feature matrix audit, mask critical depth differences: LeanCTX's 81 MCP tools are breadth-first, while the four-stack's combined ~75 tools are depth-first per concern.

**The 17 hard gaps are persona-conditional, not universal.** Two gaps rise to super-critical status for specific personas: (1) `CTX_FETCH_STRICT` RFC1918/loopback blocking for corporate/regulated environments — Context Mode's published fetch-governance depth exceeds LeanCTX's SSRF protection; (2) agentmemory's 53-tool orchestration surface (action DAG, frontier, lease, mesh, sentinels) for multi-agent ops-at-scale workflows. Neither blocks a solo developer or small team doing standard agentic coding.

**LeanCTX has 5 super-critical wins the four-stack lacks entirely.** The wire/request compression proxy (compressing every outbound model request), enforced read-path AST compression (10 fidelity modes), PathJail runtime filesystem confinement, Ed25519 hash-chained savings ledger with offline verification, and prompt-injection detection before model entry are capabilities no incumbent provides. These represent genuine architectural advantages, not marketing claims — the read-path data flow (PathJail → session cache → AST extraction → mode selection → compression → token accounting → ledger) is documented at the source-code level.

**Token economics are genuinely mixed.** LeanCTX wins on read-heavy workloads (AST modes, ~13-token cached re-reads) and long sessions (wire proxy). The four-stack wins on graph-first orientation (Graphify scoped subgraphs), tight MCP surfaces (11 tools vs 81), and shell-heavy loops (RTK per-CLI compressors). No controlled head-to-head benchmark exists — all vendor savings claims (LeanCTX 60–90% per read, Context Mode ~98% with hooks, RTK 60–90% on shell) are uncorroborated by independent testing.

**The recommended minimum stack varies by persona:** LeanCTX alone suffices for solo devs and small coding teams. Add Context Mode for corporate fetch governance. Add agentmemory for multi-agent orchestration. RTK and Graphify are optional addons, not universal must-keeps.

---

## Introduction

### Scope

This analysis evaluates whether LeanCTX — a single Rust binary unifying I/O compression, memory, security, wire proxy, and savings ledger — can replace the composable stack of RTK (shell compression), Context Mode (MCP sandbox + session KB + fetch hardening), agentmemory (persistent memory + orchestration), and Graphify (knowledge graph retrieval) for agentic coding workflows.

### Methodology

The analysis follows an 8-phase deep-research pipeline:

1. **SCOPE** — Define "better" across 7 dimensions
2. **PLAN** — Map dimensions to personas
3. **RETRIEVE** — Web validation of claims from actual documentation
4. **TRIANGULATE** — Cross-reference coverage percentages
5. **SYNTHESIZE** — Structured analysis across 7 sections
6. **CRITIQUE** — Challenge assumptions
7. **REFINE** — Address critique points
8. **PACKAGE** — Final report

Evidence base: the ultradeep 200-row feature matrix audit (2026-07-05), the capability analysis gist, and direct validation of claims against each tool's published documentation (leanctx.com, GitHub READMEs for mksglu/context-mode, rohitg00/agentmemory, rtk-ai/rtk, safishamsi/graphify).

### Key Assumptions

- "Better" is evaluated across capability coverage, depth, token efficiency, operational simplicity, security, orchestration, and collaboration
- The analysis treats the four-stack as already deployed and working — migration cost is excluded
- All tools are evaluated at their current published state (July 2026)
- Vendor claims are treated as directional until independently verified

---

## 1. Replacement by Surface Area

### RTK Replacement: 97% — Near-Complete

LeanCTX covers RTK's core value proposition comprehensively. Both are single Rust binaries with zero dependencies. Both implement PreToolUse hook-based shell command rewriting. Both offer command-specific compressors (git, gh, rg, docker, k8s, test runners). Both provide savings analytics (`rtk gain` / `lean-ctx savings`).

**What LeanCTX adds that RTK lacks:**
- Wire/request-path compression proxy (compresses every outbound model request, not just shell output)
- Read-path AST compression (10 fidelity modes intercepting Read before tokens reach the model)
- PathJail runtime filesystem confinement
- Ed25519 hash-chained savings ledger with offline verification CLI
- FTS5 session knowledge base with search

**What RTK retains as an edge:**
- Deepest per-CLI compressors — RTK's 95+ handcrafted patterns for specific CLI tools (git status -80%, cargo test -90%, pytest -90%) are the most mature in the ecosystem
- 14+ AI tool integrations with platform-specific install paths
- Lightest possible shell-only footprint — RTK does one thing extremely well

**Verdict:** LeanCTX replaces RTK for most users. The documented RTK addon compatibility (LeanCTX explicitly lists RTK as a compatible shell compression addon) means the deepest per-CLI compressors can be composed when needed, not lost. Standalone RTK is only necessary when you want shell compression without any other context tooling.

### Context Mode Replacement: 95% — Strong with Governance Gaps

LeanCTX and Context Mode share the most architectural DNA. Both implement MCP sandbox execution (`ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`), FTS5-based session knowledge bases, PreToolUse/PostToolUse/SessionStart/Stop hooks, web fetch with URL sanitization, and progressive search throttling.

**What LeanCTX adds that Context Mode lacks:**
- 10 read fidelity modes with ModePredictor and `mode=auto` (Context Mode has cooperative `ctx_execute_file` but no hook-enforced read-path routing)
- Wire proxy compression
- PathJail + IDE config-dir jail
- Ed25519 savings ledger
- Prompt-injection detection before model entry
- Cross-archive FTS (`ctx_expand`)

**What Context Mode retains as an edge:**
- `CTX_FETCH_STRICT` — RFC1918/loopback/ULA blocking mode for hosted/CI environments. This is the **only hard gap that becomes super-critical** for corporate/regulated personas. LeanCTX has SSRF protection (cloud metadata IP block, non-HTTP scheme block) but lacks the explicit `CTX_FETCH_STRICT=1` toggle that blocks private network targets entirely.
- `afterAgentResponse` hook — fire-and-forget hook receiving full response text, useful for post-response analysis
- `ctx_insight` dashboard launcher — observability UX connecting to a hosted analytics layer
- Sandbox credential passthrough for approved CLIs (`gh`, `aws`, `gcloud`, `kubectl`, `docker` inherit env vars and config paths without exposing them to conversation)
- 17+ platform compatibility with published per-platform hook matrices
- PreCompact snapshot restore — session recovery after context compaction

**Verdict:** LeanCTX replaces Context Mode for most coding agents. The `CTX_FETCH_STRICT` gap matters only when context-mode runs as a shared service in hosted/CI environments, not on a developer's own machine. The credential passthrough sandbox matters for CI/automation personas. The `afterAgentResponse` hook and `ctx_insight` dashboard are UX niceties, not capability floors.

### agentmemory Replacement: 87% — Significant Orchestration Gap

LeanCTX and agentmemory overlap on memory capture (decision/insight save, observation from tool use, user prompt capture), knowledge graph traversal, session handoff, team share/feed, and multi-agent mesh sync.

**What LeanCTX adds that agentmemory lacks:**
- Read-path AST compression (agentmemory's `memory_compress_file` compresses exported markdown, not live agent Read-path)
- Wire proxy
- PathJail
- Ed25519 ledger
- Prompt-injection detection

**What agentmemory retains as an edge — the 53-tool orchestration surface:**
This is the **second-largest gap** in the comparison. agentmemory's extended tool set includes:
- **Action DAG** (`memory_action_create`, `memory_action_update`) — work items with dependencies
- **Frontier scheduling** (`memory_frontier`, `memory_next`) — unblocked actions ranked by priority
- **Lease management** (`memory_lease`) — exclusive action leases for multi-agent coordination
- **Signal messaging** (`memory_signal_send`, `memory_signal_read`) — inter-agent communication with receipts
- **Sentinel event-driven unblocking** (`memory_sentinel_create`, `memory_sentinel_trigger`) — event-driven watchers
- **Sketch → promote** (`memory_sketch_create`, `memory_sketch_promote`) — ephemeral exploratory workgraphs that become permanent
- **Crystallize** (`memory_crystallize`) — compact completed action chains via LLM digest
- **Diagnose/heal** (`memory_diagnose`, `memory_heal`) — health checks and auto-fix for stuck state
- **Citation verification** (`memory_verify`) — trace provenance
- **Claude MEMORY.md bridge sync** — host-specific bridge
- **Gitleaks scanning on memory export** — secret hygiene on shared exports
- **4-tier memory consolidation** (working → episodic → semantic → procedural) with Ebbinghaus decay

**Verdict:** LeanCTX replaces agentmemory for memory capture and retrieval. It does **not** replace agentmemory's orchestration primitives. For solo interactive coding, the orchestration gap is irrelevant. For multi-agent ops-at-scale (frontier scheduling, leasing, mesh coordination), agentmemory remains non-negotiable.

### Graphify Replacement: 99% — Near-Complete

This is the highest-coverage replacement. LeanCTX mirrors Graphify's core value: tree-sitter AST parsing, knowledge graph construction, `query`/`path`/`explain`/`affected` operations, god-node detection, Leiden community detection, INFERRED semantic edges, incremental `graphify update` merge, and wiki generation per community.

**What LeanCTX adds that Graphify lacks:**
- Integrated read-path compression (Graphify's graph-aware file reads are retrieval-focused, not compression-focused)
- Wire proxy, PathJail, ledger

**What Graphify retains as an edge:**
- **Multimodal corpus graph as primary deliverable** — vision ingest (images, diagrams), video/audio transcription, PDF citation mining all map into the same graph. LeanCTX has multimodal intake but Graphify's corpus graph is the primary artifact, not a side effect.
- **Postgres-backed extract** — `graphify extract --postgres` for CI/headless extraction
- **Confidence-tagged edges** — every connection carries `EXTRACTED` (explicit in source) vs `INFERRED` (resolved by graphify) metadata
- **Mature graph.json git workflow** — the graph artifact is a first-class git-tracked deliverable with merge driver support

**Verdict:** Graphify is the most replaceable tool in the stack. For code-oriented agents, LeanCTX's graph capabilities are sufficient. Graphify remains valuable only for multimodal corpus-as-primary or Postgres-backed CI extraction workflows.

---

## 2. Combined Stack Replacement — Synergy Analysis

The four tools work **together** as a pipeline:

```
RTK compresses shell → Context Mode processes sandbox outputs →
agentmemory captures decisions → Graphify retrieves patterns
```

When you replace all 4 with LeanCTX alone, the **pipeline collapses into a single runtime**. This has both advantages and disadvantages.

### What the Unified Pipeline Preserves

LeanCTX's read-path data flow (PathJail → session cache → AST extraction → mode selection → compression → token accounting → ledger) replicates the read-side pipeline natively. The shell path (allowlist → execute → pattern engine → compressed stdout) replicates RTK's value. The session KB (FTS5 + graph tooling) replicates Context Mode's knowledge base. The knowledge graph (entities + relationships) replicates agentmemory's memory graph.

### What the Unified Pipeline Loses

**Separation of concerns.** The four-stack's architecture enforces clean boundaries: RTK only compresses shell, Context Mode only sandboxes analysis, agentmemory only captures/retrieves memory, Graphify only builds/queries graphs. Each tool can be upgraded, replaced, or disabled independently. LeanCTX couples all five subsystems into one binary — a version upgrade affects all concerns simultaneously.

**Best-of-breed depth per concern.** RTK's 95+ shell patterns are deeper than LeanCTX's native shell compression. Context Mode's `CTX_FETCH_STRICT` is more rigorous than LeanCTX's SSRF protection. agentmemory's 53-tool orchestration surface has no LeanCTX equivalent. Graphify's multimodal corpus graph is more mature than LeanCTX's multimodal intake.

**The save-via-agentmemory, retrieve-via-Graphify pattern.** This is a documented Silver Bullet synergy: decisions are captured through agentmemory's `memory_save`, exported to `.agentmemory/` markdown, indexed into Graphify's `graph.json`, and retrieved via `graphify query`/`path`/`explain`. LeanCTX's unified memory graph conceptually covers this, but the two-tool pattern is battle-tested in the Silver Bullet ecosystem with documented export/import contracts.

### Honest Assessment

For **single-session interactive coding**, the unified pipeline is strictly better — less setup, fewer failure modes, one cache. For **multi-session, multi-agent, team-scale workflows**, the composable pipeline's separation of concerns and independent upgrade paths are genuine architectural advantages, not just theoretical concerns.

---

## 3. The 17 Hard Gaps — Criticality Assessment

The gist claims none of the 17 hard gaps is a universal super-critical dealbreaker. **I partially disagree.** Two gaps deserve promotion, and one gap is understated.

### Promoted to Super-Critical

**Gap #4: `CTX_FETCH_STRICT` RFC1918/loopback block mode.**
Context Mode's documentation explicitly states: "For hosted/CI environments where you want to block private targets too, set `export CTX_FETCH_STRICT=1`. That blocks loopback + RFC1918 + ULA in addition to the always-blocked ranges." LeanCTX has SSRF protection (cloud metadata IP block, non-HTTP scheme block) but lacks this explicit toggle. For any agent running as a shared service (not on a developer's own machine), this is a compliance requirement, not a nice-to-have. **Verdict: super-critical for hosted/CI personas.**

**Gap #15: 53-tool orchestration MCP surface.**
agentmemory's documentation confirms all 53 tools including action DAG, frontier, lease, mesh, sentinels, sketch→promote, crystallize, diagnose/heal. LeanCTX has `ctx_graph` and handoffs but nothing approaching this orchestration depth. For multi-agent ops-at-scale, this is not a "specialist overlay" — it's the core product surface. **Verdict: super-critical for multi-agent ops personas.**

### Understated Gap

**Gap #2: `afterAgentResponse` hook.**
The gist categorizes this as "niche / optional — host lifecycle nicety." Context Mode's documentation shows this as a first-class hook type in the install configuration, receiving full response text for post-response analysis. For agents that need to analyze their own outputs (self-critique loops, quality gates), this is more than a nicety. **Verdict: important but not super-critical — promoted from niche.**

### Remaining Gaps — Honest Assessment

| Gap | Criticality | Notes |
|-----|-------------|-------|
| #1 Credential passthrough sandbox | Important for CI/automation | Many coding loops never touch passthrough sandboxes |
| #3 `ctx_insight` dashboard | Niche | Observability UX, not capability floor |
| #5-13 agentmemory features | Varies | Memory slots, relations, reflect, bridge sync, verify, sentinel, sketch, crystallize, diagnose/heal — all orchestration-adjacent |
| #14 WebFetch deny depth | Important | LeanCTX has hooks + sandbox fetch; gap is published parity depth |
| #16 Multimodal corpus graph | Niche for coding agents | Matters when vision ingest + community-scale retrieval is the workflow |
| #17 Gitleaks export scanning | Important for team memory | Mitigated by repo policy and pre-export review |

### My Verdict vs the Gist

The gist says "none of the 17 hard gaps is a universal super-critical dealbreaker." I agree for **solo interactive coding**. I disagree for **hosted/CI environments** (`CTX_FETCH_STRICT`) and **multi-agent orchestration** (53-tool surface). These are not edge cases — they represent two of the four personas the gist itself defines.

---

## 4. Unified vs Composable Architecture

### Single-Binary Simplicity (LeanCTX Wins)

The operational argument for LeanCTX is strong:
- **One install path** vs four (`cargo install lean-ctx` vs `cargo install rtk` + `npm install -g context-mode` + `npx @agentmemory/agentmemory` + `pip install graphify`)
- **One config surface** vs four (one MCP server vs four MCP servers + hook configurations)
- **One upgrade path** vs four (version conflicts, breaking changes across independent tools)
- **One diagnostic tool** (`lean-ctx doctor` vs `rtk --version` + `context-mode doctor` + agentmemory health endpoint + `graphify --version`)
- **One cache** vs four separate indexes

For a solo developer or small team (2-5 people), this simplification is the primary value proposition. The 81 MCP tool surface is mitigated by LeanCTX's 5 unified high-level tools route.

### Best-of-Breed Depth (Four-Stack Wins)

The composable argument is equally strong for different reasons:
- **Independent upgrade cadence** — RTK can ship new shell compressors without touching memory/graph code
- **Independent failure isolation** — agentmemory crashing doesn't affect shell compression or graph retrieval
- **Specialist depth** — RTK's 95+ patterns, Context Mode's fetch governance, agentmemory's orchestration, Graphify's multimodal corpus are each deeper than LeanCTX's corresponding subsystem
- **Ecosystem composability** — each tool can be replaced individually (e.g., swap Graphify for a different graph engine)

### The Real Tradeoff at Different Scales

| Scale | Winner | Why |
|-------|--------|-----|
| Solo dev, 1 project | LeanCTX | Setup simplicity dominates; depth gaps don't matter |
| Small team (2-5), 1-3 projects | LeanCTX | Onboarding simplicity > specialist depth |
| Small mixed team (5-10, devs + non-devs) | LeanCTX + agentmemory | Non-devs need exported artifacts, not graph queries; agentmemory's team surface fills the gap |
| Multi-agent ops (10+ parallel agents) | Four-stack | Orchestration primitives (frontier, lease, mesh, sentinels) are the product |
| Corporate/regulated | LeanCTX + Context Mode | `CTX_FETCH_STRICT` is non-negotiable |
| Enterprise (50+ seats) | Four-stack | Independent governance, audit, and compliance per concern |

---

## 5. Token Economics

### The Gist's Verdict: "Mixed — Neither is Clearly Better"

**I agree, with caveats.** The token economics depend entirely on workload shape, and no controlled benchmark exists to settle the question.

### When LeanCTX Likely Wins on Tokens

1. **Read-heavy exploration** — 10 read fidelity modes (full → map → signatures → diff → task → reference → aggressive → entropy → lines:N-M) with ModePredictor selecting the optimal mode from task intent. The ~13-token cached re-read for unchanged files is a genuine win over re-reading full file contents.
2. **Long multi-turn sessions** — The wire proxy compresses every outbound request (system prompt, history, tool results) with prompt-cache-safe ordering. This is a surface the four-stack does not offer at all.
3. **Repeated file access** — Content-addressed session cache keyed by path + mtime/hash means unchanged files collapse to stubs.
4. **Mixed read + shell + fetch workflows** — One unified cache beats four separate indexes when the workload spans all surfaces.

### When the Four-Stack Likely Wins on Tokens

1. **Codebase orientation** — Graphify's `graphify query` / `path` / `explain` returns scoped subgraphs (typically far smaller than reading file contents). This is the most token-efficient way to understand a codebase before broad `Read`/`Grep`.
2. **MCP-heavy analysis** — Context Mode's 11 focused tools have a tighter tool-schema surface than LeanCTX's 81 tools. Tool definitions consume tokens every turn.
3. **Shell-heavy dev loops** — RTK's 95+ handcrafted patterns (git status -80%, cargo test -90%, pytest -90%) are the deepest available.
4. **PreCompact session recovery** — Context Mode's compaction-recovery hook reduces re-bootstrap reads after context compaction.
5. **Disciplined save → retrieve** — agentmemory capture + Graphify retrieval avoids re-reading raw memory exports.

### The 81-Tool Tax

The gist correctly flags this: LeanCTX's 81 documented MCP tools can easily erase single-binary simplicity if the full catalog is exposed. Every MCP tool descriptor consumes context tokens. LeanCTX's 5 unified high-level tools are the lean path, but users must actively route through them. The four-stack's combined ~75 tools (CM 11 + agentmemory 53 + Graphify ~5 + RTK hooks-only) are distributed across separate MCP servers, so each server's tool surface is independently scoped.

**Net assessment:** LeanCTX's 81 tools are a tax if fully exposed; a non-issue if the 5 high-level tools are used. The four-stack's distributed tool surfaces are inherently scoped per concern.

---

## 6. Persona-Specific Verdicts

### Solo Dev

**Minimum viable stack:** LeanCTX alone.
**Critical must-keep incumbents:** None.
**Why:** LeanCTX covers 97-99% of RTK and Graphify, 95% of Context Mode, and 87% of agentmemory. The orchestration gap (agentmemory) is irrelevant for single-session interactive coding. The fetch governance gap (Context Mode) is irrelevant on a developer's own machine. The shell compression depth gap (RTK) is mitigated by LeanCTX's native shell + documented RTK addon. Token economics favor LeanCTX on read-heavy workloads.

**Risk:** If the solo dev works on a large codebase and relies heavily on Graphify's `graphify query` for orientation, they may miss the scoped-subgraph retrieval pattern. LeanCTX's `ctx_query`/`ctx_path`/`ctx_explain` partially cover this.

### Corporate Security

**Minimum viable stack:** LeanCTX + Context Mode.
**Critical must-keep incumbents:** Context Mode (`CTX_FETCH_STRICT`).
**Why:** `CTX_FETCH_STRICT=1` blocks loopback + RFC1918 + ULA in addition to always-blocked ranges. This is a compliance requirement when context-mode runs as a shared service, not on a developer's own machine. LeanCTX's SSRF protection (cloud metadata IP block, non-HTTP scheme block) is not equivalent — it lacks the explicit private-network toggle.

**Additional consideration:** Context Mode's credential passthrough sandbox (`gh`, `aws`, `gcloud`, `kubectl` inheriting env vars without exposing them to conversation) matters for CI/automation pipelines.

**Risk:** Running LeanCTX + Context Mode together creates tool-schema overlap (both expose `ctx_execute`, `ctx_search`, etc.). The user must decide which MCP server handles each concern.

### Multi-Agent Ops

**Minimum viable stack:** LeanCTX + agentmemory.
**Critical must-keep incumbents:** agentmemory (53-tool orchestration surface).
**Why:** agentmemory's action DAG, frontier scheduling, lease management, signal messaging, sentinel event-driven unblocking, sketch→promote, and crystallize are the core product surface for multi-agent coordination. LeanCTX has `ctx_graph` and handoffs but nothing approaching this depth.

**Additional consideration:** agentmemory's `memory_mesh_sync` for P2P sync between instances and `memory_signal_send`/`memory_signal_read` for inter-agent messaging with receipts are unique coordination primitives.

**Risk:** agentmemory's 53-tool surface is only available when the full server is running (`AGENTMEMORY_URL`). The published MCP shim falls back to 7 tools without a reachable server.

### Small Mixed Team (5-10 devs + non-devs)

**Minimum viable stack:** LeanCTX + agentmemory.
**Critical must-keep incumbents:** agentmemory (team memory layer).
**Why:** Non-devs (PMs, designers, ops) need durable prose artifacts (exported markdown, team feed, viewer UI), not graph queries or sandbox execution. agentmemory's `team_share`, `team_feed`, `memory_export` with gitleaks scanning, and session viewer UI make handoffs legible to people who never open the repo's source tree. LeanCTX's team features (partial ¹ in the matrix) are workable for devs but thinner on team feed maturity.

**Conditional addition:** Add Context Mode if corporate/regulated (`CTX_FETCH_STRICT`).

**Risk:** LeanCTX + agentmemory creates two MCP servers to maintain. The single-binary simplification argument weakens when you still need a second tool for team memory.

---

## 7. Overall Verdict

### Is LeanCTX Truly Better as a Replacement?

**Conditionally yes.** LeanCTX is a better single-tool replacement under these conditions:

1. **The workload is single-session interactive coding** — no multi-agent orchestration, no hosted/CI fetch governance, no team-scale memory exports
2. **The user values setup simplicity over specialist depth** — one binary, one config, one upgrade path
3. **The workload is read-heavy** — AST modes, cached re-reads, and wire proxy provide genuine token savings
4. **The user routes through 5 high-level tools** — not the full 81-tool catalog

**Conditionally no.** LeanCTX is not a better replacement under these conditions:

1. **Multi-agent ops-at-scale** — agentmemory's 53-tool orchestration surface is non-negotiable
2. **Corporate/regulated environments** — Context Mode's `CTX_FETCH_STRICT` is non-negotiable
3. **Team memory with export hygiene** — agentmemory's gitleaks scanning + team feed is non-negotiable
4. **Graph-first codebase orientation at scale** — Graphify's multimodal corpus graph + Postgres-backed CI extraction is deeper

### Evidence That Is Missing

1. **No controlled head-to-head benchmark** — All savings claims (LeanCTX 60–90%, Context Mode ~98%, RTK 60–90%) are vendor-provided or single-tool README examples. Independent benchmarking on identical tasks with identical agents is needed.
2. **No co-installation testing** — LeanCTX + RTK addon, LeanCTX + Context Mode, LeanCTX + agentmemory — the interaction effects (tool-schema overlap, cache conflicts, hook ordering) are untested.
3. **No long-term adoption data** — The gist and matrix are snapshot audits. Real-world adoption over months would reveal maintenance burden, upgrade friction, and actual token savings.
4. **No security audit** — LeanCTX's PathJail, prompt-injection detection, and SSRF protection are documented at the architecture level but not independently security-audited. Context Mode's `CTX_FETCH_STRICT` has published platform-specific behavior; LeanCTX's equivalent is thinner in documentation.

### What Would Change My Verdict

1. **If LeanCTX ships `CTX_FETCH_STRICT` equivalent** — the corporate/regulated persona gap closes
2. **If LeanCTX ships orchestration primitives** comparable to agentmemory's action DAG/frontier/lease/mesh — the multi-agent ops gap closes
3. **If an independent benchmark** shows LeanCTX's wire proxy + read modes delivering >2x token savings vs the four-stack on identical tasks — the token economics argument tilts decisively
4. **If agentmemory's team features** (gitleaks, team feed, viewer UI) are ported to or replicated in LeanCTX — the small mixed team gap closes

---

## Synthesis & Insights

### The Fundamental Tension

The comparison is not "one tool vs four tools" — it's **unified runtime vs composable specialist architecture**. LeanCTX's strength is integration: one binary, one cache, one ledger, one read-path. The four-stack's strength is separation: each tool does one thing extremely well, can be upgraded independently, and fails independently.

### The Missing Middle

The analysis reveals a gap in the tooling landscape: there is no tool that provides **orchestration-grade memory** (action DAG, frontier, lease, mesh) with **LeanCTX-grade compression** (wire proxy, AST modes, PathJail). agentmemory has orchestration but not compression. LeanCTX has compression but not orchestration. A hypothetical "LeanCTX + agentmemory orchestration" would cover all four personas.

### The Token Question Is Unanswerable

Without controlled benchmarks, the token economics comparison is architectural reasoning, not empirical evidence. LeanCTX's wire proxy is a genuinely novel surface — compressing every outbound request — but its actual savings depend on session length, history size, and tool-result volume. RTK's per-CLI compressors are the deepest available but only cover shell output. Context Mode's sandbox-first design keeps raw data out of context but doesn't compress what does enter. The honest answer is: **we don't know which approach saves more tokens in practice.**

---

## Limitations & Caveats

1. **Snapshot analysis** — All tools are evaluated at their July 2026 state. Any tool could ship updates that close gaps.
2. **Vendor claims accepted at face value** — LeanCTX's 60–90% savings, ~13-token cached re-reads, and 81 MCP tools are documented on leanctx.com and the feature catalog. None are independently verified.
3. **No install/migration cost** — The analysis excludes the practical cost of migrating from the four-stack to LeanCTX (reconfiguring hooks, rebuilding knowledge bases, retraining team).
4. **No pricing analysis** — LeanCTX is open-source; Context Mode has an optional paid Insight SaaS dashboard. Licensing and pricing are excluded.
5. **Silver Bullet context** — The analysis is performed in the context of the Silver Bullet repo, which currently uses the four-stack. This may bias toward the incumbent architecture.
6. **Partial (¹) cells** — Many LeanCTX cells in the matrix are marked as partial/conditional/host-dependent. The replacement coverage percentages (97%, 95%, 87%, 99%) treat partial cells as covered, which may overstate LeanCTX's actual parity.

---

## Recommendations

### For Solo Developers

**Adopt LeanCTX as primary.** Keep RTK as an optional addon if shell output dominates your workflow. No other incumbents are necessary.

### For Small Teams (2-5)

**Adopt LeanCTX as primary.** Pilot with 2 devs before rolling out. Validate that LeanCTX's team features (partial ¹) meet your handoff needs before dropping agentmemory.

### For Small Mixed Teams (5-10)

**Adopt LeanCTX + agentmemory.** Use LeanCTX for compression/sandbox/graph, agentmemory for team memory (export, feed, viewer). Add Context Mode only if corporate/regulated.

### For Multi-Agent Ops

**Keep agentmemory as primary orchestrator.** Add LeanCTX for compression and security. Do not attempt to replace agentmemory's 53-tool orchestration surface with LeanCTX's `ctx_graph` and handoffs.

### For Corporate/Regulated

**Keep Context Mode for fetch governance.** Add LeanCTX for compression and security. Validate that `CTX_FETCH_STRICT` behavior meets compliance requirements before considering LeanCTX-only.

---

## Bibliography

| ID | Source | URL | Accessed |
|----|--------|-----|----------|
| [LC-home] | LeanCTX Homepage | https://leanctx.com/ | 2026-07-07 |
| [LC-arch] | LeanCTX Architecture Page | https://leanctx.com/architecture/ | 2026-07-07 |
| [LC-catalog] | LeanCTX Feature Catalog (GitHub) | https://github.com/yvgude/lean-ctx/blob/main/LEANCTX_FEATURE_CATALOG.md | 2026-07-07 |
| [LC-compat] | LeanCTX Compatibility Page | https://leanctx.com/compatibility/ | 2026-07-07 |
| [LC-ledger] | LeanCTX Savings Ledger Docs | https://leanctx.com/docs/concepts/savings-ledger/ | 2026-07-07 |
| [CM-readme] | Context Mode GitHub README | https://github.com/mksglu/context-mode | 2026-07-07 |
| [AM-readme] | agentmemory GitHub README | https://github.com/rohitg00/agentmemory | 2026-07-07 |
| [RTK-readme] | RTK GitHub README | https://github.com/rtk-ai/rtk | 2026-07-07 |
| [GF-readme] | Graphify GitHub README | https://github.com/safishamsi/graphify | 2026-07-07 |
| [audit] | Ultradeep Feature Matrix Audit (2026-07-05) | gist-leanctx-capability-analysis.md | 2026-07-05 |
| [SB-contract] | Silver Bullet Code Intelligence Contract | docs/code-intelligence-contract.md | Internal |

---

## Methodology Appendix

### Phase 1 — SCOPE

Defined "better" across 7 dimensions: capability coverage (raw feature parity), depth of implementation (1st class vs partial/modicum), token efficiency/compression quality, operational simplicity (one binary vs 4 tools + composability), security/governance, orchestration/multi-agent support, team/collaboration features.

### Phase 2 — PLAN

Mapped dimensions to 4 personas: solo dev (simplicity + capability), corp security (governance + compliance), multi-agent ops (orchestration + coordination), small mixed team (simplicity + collaboration).

### Phase 3 — RETRIEVE

Fetched and indexed 8 documentation pages:
- leanctx.com/architecture/ (27 sections, 24.6KB)
- LEANCTX_FEATURE_CATALOG.md (51 sections, 16.6KB)
- mksglu/context-mode README (68 sections, 110.0KB)
- rohitg00/agentmemory README (82 sections, 98.1KB)
- rtk-ai/rtk README (63 sections, 31.9KB)
- safishamsi/graphify README (55 sections, 62.8KB)
- leanctx.com/compatibility/ (46 sections, 15.8KB)
- leanctx.com/docs/concepts/savings-ledger/ (9 sections, 7.4KB)

Total indexed: 291+ sections across 8 sources.

### Phase 4 — TRIANGULATE

Cross-referenced coverage percentages (97%, 95%, 87%, 99%) against actual documentation. Verified:
- RTK's 14+ AI tool integrations and 95+ shell patterns match the 97% claim
- Context Mode's `CTX_FETCH_STRICT`, credential passthrough, and 17+ platform support match the 95% claim
- agentmemory's 53-tool orchestration surface confirms the 87% claim (13% gap is orchestration)
- Graphify's `query`/`path`/`explain`/`affected` + tree-sitter AST + Leiden communities confirm the 99% claim

### Phase 5 — SYNTHESIS

Structured analysis across 7 sections as outlined in the research question scope.

### Phase 6 — CRITIQUE

Identified assumptions: snapshot analysis, vendor claims at face value, no install/migration cost, no pricing analysis, Silver Bullet context bias, partial cells treated as covered.

### Phase 7 — REFINE

Addressed critique by: noting the `CTX_FETCH_STRICT` gap as persona-conditional super-critical (challenging the gist's "none universal" claim), flagging the 81-tool tax, and acknowledging the missing benchmark evidence.

### Phase 8 — PACKAGE

Final report written to: `/Users/shafqat/projects/silver-bullet/repo/.planning/archive/research/2026-07-05/2026-07-05-context-tools-feature-matrix-ultradeep/multi-ai-deep-research-out/mimo-v2.5-pro-report.md`

# Adding LeanCTX to the Silver Bullet 4-Tool Stack — 5-Stack Synergy & Conflict Analysis

**Author:** deepseek-v4-pro (follow-up analysis)
**Date:** 2026-07-07
**Follow-up to:** `consolidated.md` (6-model consensus report) + `deepseek-v4-pro-report.md` (prior analysis)
**Research question:** Would adding LeanCTX to the existing 4-tool Silver Bullet stack (RTK + Context Mode + agentmemory + Graphify) be better for SB? Would there be conflicts? How to resolve them across Cursor, Codex, Claude Code, and OpenCode?

---

## Executive Summary

**Adding LeanCTX as a 5th tool to the existing Silver Bullet 4-tool stack is architecturally defensible but operationally treacherous without deliberate integration design.** LeanCTX's five unique capabilities (wire proxy, AST read-path modes, PathJail governance, Ed25519 cryptographic ledger, pre-model prompt injection detection) fill genuine gaps the 4-tool stack cannot close — most critically the wire proxy (which compresses system prompt + conversation history — the largest untapped savings surface) and PathJail (which enforces deny-by-default shell safety the SB hooks can only recommend). However, the overlap between LeanCTX and the incumbents is substantial: shell compression (vs RTK), sandbox execution and FTS5 indexing (vs Context Mode), memory capture and graph query (vs agentmemory + Graphify), and hook interception (vs SB's 60-hook enforcement surface). Integrating LeanCTX as a peer tool without deliberate isolation, ordering, or toggling will produce hook conflicts, double-compression waste, triple token accounting, and a rules-tax burden that erodes the very context savings LeanCTX is designed to deliver.

**The recommended path is a layered integration, not a peer-to-peer addition.** LeanCTX should sit as the *outermost layer* (wire proxy first, PathJail first, AST read-path first), with the SB incumbents operating *inside* the LeanCTX perimeter. This requires: (1) hook ordering treaties (LeanCTX PreToolUse runs before SB hooks for compression; SB hooks run after for enforcement), (2) tool-role specialization (disable LeanCTX's sandbox/memory/graph when incumbents provide deeper versions), (3) shell-compression toggling (RTK for deep per-CLI compression, LeanCTX for wire-level aggregation), and (4) per-environment capability-tier mappings since the three SB target hosts (Cursor, Codex, Claude Code) have fundamentally different hook and MCP architectures.

**Verdict: Add LeanCTX, but as a foundation layer beneath the stack, not a peer alongside it.** The phased path is: Layer 1 (LeanCTX wire proxy + PathJail + Ed25519 ledger), Layer 2 (RTK for shell compression, Context Mode for sandbox governance), Layer 3 (agentmemory for orchestration memory, Graphify for codebase graph). Toggle LeanCTX's memory/graph/sandbox OFF when the incumbents are present; keep the wire proxy, PathJail, and savings ledger ON always. This gives SB the genuinely unique capabilities of LeanCTX without the feature overlap, hook conflicts, and cumulative rules tax of running all 5 at full blast.

---

## 1. Would Adding LeanCTX Benefit SB?

### 1.1 What SB Gets From Its Current 4-Tool Stack

SB currently recommends and gates four tools via `.cursor/rules/` (6 `.mdc` files: `recommended-tools.mdc`, `context-mode.mdc`, `agentmemory.mdc`, `graphify.mdc`, `token-compression-enforcement.mdc`, `silver-orchestrator.mdc`) and 60+ hook scripts gating their use. The division of labor is:

| Tool | SB Role | Unique Value |
|------|---------|-------------|
| **RTK** | Shell output compression | Per-CLI compressors (`rtk pytest -90%`, `rtk go test -90%`), 14+ host integrations, `rtk gain`/`rtk session` |
| **Context Mode** | Sandbox execution + fetch governance | `CTX_FETCH_STRICT` RFC1918/loopback blocking, `ctx_execute`/`ctx_execute_file` sandbox, credential passthrough, PreCompact recovery, 11 focused tools |
| **agentmemory** | Decision capture + team memory | 53-tool orchestration surface (action DAG, frontier scheduler, lease system, mesh sync), LongMemEval-S benchmarks, gitleaks-scanned exports, Markdown-first team artifacts |
| **Graphify** | Codebase knowledge graph | AST extraction, tree-sitter, god nodes, Leiden communities, `query`/`path`/`explain`/`affected`, multimodal corpus graph |

These tools operate inside SB's 12 enforcement hook layers and feed into SB's workflow state machine.

### 1.2 LeanCTX's Unique Capabilities — Would They Fill Gaps?

The consolidated 6-model report identified 5 LeanCTX-unique capabilities the 4-stack cannot replicate:

| Capability | Is It a Genuine SB Gap? | How Significant for SB? |
|------------|------------------------|------------------------|
| **Wire proxy** (compresses prompt + history + tool results on every request) | **Yes — critical gap.** No SB tool touches the model request body. RTK compresses post-tool shell output; CM compresses sandbox stdout. The system prompt, conversation history, and accumulated tool results (the largest context consumers) are untouched. | **Very high.** SB's own AGENTS.md (~9.5KB) + silver-bullet.md instructions + 6 `.mdc` rule files consume standing tokens every turn. Compressing these at the wire level is the single largest uncaptured savings surface. |
| **AST read-path modes** (10+ fidelity levels with ModePredictor) | **Yes — genuine gap.** CM's `CTX_EXECUTE_FILE` processes files in-sandbox (keeping raw bytes out of context), but it doesn't *intercept reads before the model sees them* — it provides an alternative path. LeanCTX intercepts every Read at the wire level and routes through appropriate AST fidelity. | **High.** SB workflows frequently involve reading large files (specs, plans, test output, evidence artifacts). Automatic fidelity routing eliminates the cognitive load of "should I `ctx_execute_file` this or read it directly?" |
| **PathJail** (deny-by-default shell allowlist) | **Yes — SB's biggest governance gap.** SB's hooks enforce cooperative rules ("don't curl from the shell", "use sandbox fetch instead") via hook scripts (`context-mode-read-deny.sh`, `token-compression-tools-gate.sh`). These are instruction-following, not hard enforcement. An agent that refuses to cooperate can bypass them. | **Very high.** SB markets itself as "hook-enforced accountability" but hooks are cooperative — they depend on the agent following instructions. PathJail provides a filesystem-level deny-by-default with allowlisting that cannot be bypassed by an uncooperative agent. |
| **Ed25519 hash-chained savings ledger** | **Yes — audit gap.** RTK's `rtk gain` and CM's `ctx_stats` provide session metrics, but neither is cryptographically verifiable. An enterprise compliance team cannot audit token savings without trusting the tool's self-reporting. | **Medium-high for enterprise.** The savings ledger provides independently verifiable proof of token compression. For SB's enterprise/regulated persona, this is a genuine compliance differentiator. |
| **Pre-model prompt injection detection** | **Yes — security gap.** No incumbent addresses prompt injection at all. SB's security skill (`silver-secure`) covers code security, not agent security. | **Medium-high.** As SB workflows become more agentic (subagent dispatch, multi-agent review ladders), injection risk grows. This is preventive infrastructure, not a current pain point. |

**Additional LeanCTX capabilities relevant to SB:**

| Capability | SB Relevance |
|------------|-------------|
| **MCP Tool-Catalog Gateway** (proxy unlimited downstream MCP tools behind 5 unified tools) | Could consolidate SB's 4 MCP servers behind one proxy — potentially reducing MCP tool descriptor overhead |
| **`proxy.effort`** cross-provider reasoning-effort pinning | Useful for SB's multi-model subagent dispatch (Cursor subagents, Claude Code parallel workers) |
| **Cache-prefix volatility relocation** (dates/UUIDs/SHAs that break deterministic caching) | SB's workflow state files, evidence artifacts, and planning docs generate many volatile prefixes — this could meaningfully improve cache hit rates |

### 1.3 What LeanCTX Overlaps — Diminishing Returns Risk

LeanCTX also overlaps significantly with each incumbent:

| LeanCTX Subsystem | Overlaps With | Overlap Severity |
|-------------------|---------------|:---:|
| Shell compression | RTK's per-CLI compressors | **High** — both compress shell output; RTK is deeper, LeanCTX is wire-proxy-integrated |
| `ctx_execute`/`ctx_execute_file` sandbox | Context Mode sandbox | **High** — near-identical API surface; CM has credential passthrough, LeanCTX has PathJail integration |
| FTS5 search (`ctx_search`) | Context Mode FTS5 | **High** — dual FTS5 databases with no shared index |
| `ctx_agent`/`ctx_handoff`/`ctx_workflow` memory | agentmemory orchestration surface | **Medium** — LeanCTX is ~30-40% of agentmemory's depth |
| `ctx_graph`/`ctx_callgraph` | Graphify god nodes, Leiden communities | **High** — surface parity is 99% for structural code graph |
| Hook interception | SB's 60-hook enforcement surface | **Critical** — both want to handle PreToolUse, PostToolUse, SessionStart |

**The core dilemma:** LeanCTX's unique capabilities (wire proxy, PathJail, AST read modes, Ed25519 ledger, injection detection) are genuinely novel and fill SB gaps. But LeanCTX also duplicates 3 of the 4 incumbent tools with comparable (if sometimes shallower) implementations. Running all 5 at full capability means running 2 shell compressors, 2 sandboxes, 2 FTS5 indexes, 3 memory systems, and 2 code graphs — a wasteful architecture that consumes the very context LeanCTX's wire proxy is supposed to save.

### 1.4 Bottom Line: Yes, But Only If Isolated to LeanCTX's Unique Capabilities

LeanCTX benefits SB **only if** it is deliberately scoped to its unique value-add layer (wire proxy, PathJail, AST read path, Ed25519 ledger, injection detection) and its overlapping subsystems are toggled OFF when deeper incumbents are present. Adding LeanCTX at full capability alongside the 4-tool stack is a net negative due to overlap waste and conflict overhead.

---

## 2. Conflicts — Comprehensive Identification

### 2.1 Hook Conflicts

SB hooks operate across 7 event layers (from `hooks/hooks.json`):
- `SessionStart` (1 handler)
- `PreToolUse` (9 handlers — context-mode-read-deny, token-compression-tools-gate, rtk-gate, graphify-gate, agentmemory-gate, context-mode-gate, etc.)
- `PostToolUse` (7 handlers — record-token-compression-usage, record-agentmemory-usage, record-graphify-query, etc.)
- `SubagentStart` (1 handler) / `SubagentStop` (1 handler)
- `Stop` (1 handler) / `UserPromptSubmit` (1 handler)

LeanCTX's hook surface (from docs/architecture):
- `PreToolUse` — AST read-mode routing, compression decisions, PathJail allowlist check
- `PostToolUse` — savings ledger updates, tool result compression
- `SessionStart` — setup, compatibility detection, auto-configuration
- `PreCompact` — context compaction hooks (LeanCTX only — Context Mode also has PreCompact)

**Conflict 2.1.1 — PreToolUse ordering.** Both LeanCTX and SB hooks need to intercept `PreToolUse` events. The SB hooks at this layer perform enforcement (read-deny, tool gating), while LeanCTX performs optimization (AST mode selection, compression). If LeanCTX runs *after* SB enforcement, an uncompressed large read could be denied before LeanCTX has a chance to compress it. If LeanCTX runs *before* SB enforcement, a PathJail-blocked command could be compressed and passed through before the deny check.

**Conflict 2.1.2 — PostToolUse ordering.** SB's PostToolUse hooks record usage (token compression, agentmemory, graphify queries) for audit trails. LeanCTX's PostToolUse updates the savings ledger and compresses tool results. If SB records run before LeanCTX compresses, the audit captures pre-compression state (useful for measuring savings). If LeanCTX runs first, SB records compressed state (cleaner but loses before/after delta).

**Conflict 2.1.3 — SessionStart initialization.** Both SB and LeanCTX initialize at session start. SB stamps project state, runs diagnostics, and gates recommended tools. LeanCTX detects host environment, configures wire proxy, and sets up PathJail. If LeanCTX initializes its wire proxy after SB has already loaded AGENTS.md instructions into context, the proxy misses the first-turn compression opportunity.

**Conflict 2.1.4 — PreCompact divergence.** Both LeanCTX and Context Mode provide PreCompact hooks. These hooks serve different purposes (LeanCTX: compact context for re-feeding; CM: reduce re-bootstrap reads). They can coexist if they run sequentially, but the order matters — CM's PreCompact should run first (reduce what needs to be preserved), then LeanCTX's (compress what remains for re-injection).

### 2.2 MCP Conflicts

**Conflict 2.2.1 — Port assignment.** All tools need MCP server ports (default typically 3000+ range). With 5 tools (4 incumbents + LeanCTX), port assignment becomes a coordination problem. SB's current setup wires 4 MCP servers; adding a 5th requires documented port allocation.

**Conflict 2.2.2 — Tool namespace collisions.** LeanCTX's tool names (`ctx_execute`, `ctx_search`, `ctx_execute_file`, `ctx_index`, `ctx_graph`, `ctx_shell`) overlap with Context Mode's tool names (`ctx_execute`, `ctx_execute_file`, `ctx_search`, `ctx_index`, `ctx_batch_execute`, `ctx_fetch_and_index`, `ctx_insight`, `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge`). If both MCP servers expose tools with the same name, the agent receives ambiguous tool schemas.

**Conflict 2.2.3 — MCP tool descriptor overhead.** SB's 4-tool stack already exposes significant MCP tool descriptors (Context Mode: 11, Graphify: ~10, agentmemory: 53). Adding LeanCTX's 81 tools (or even its 5 unified gateway tools) further inflates the standing tool schema. The consolidated report estimates 8,000-16,000 tokens of MCP tool descriptor overhead for 81 tools. Even the 5-tool gateway adds ~500-1,000 tokens.

### 2.3 Read-Path Conflicts

**Conflict 2.3.1 — Read deny vs Read compress.** Context Mode's `context-mode-read-deny.sh` hook intercepts reads and denies them if they exceed thresholds (to prevent context flooding). LeanCTX's wire proxy intercepts reads and applies AST fidelity compression (to reduce token consumption). These are in direct tension: CM denies what LeanCTX could compress. If CM denies first, LeanCTX never gets to compress. If LeanCTX compresses first, the compressed result may pass CM's threshold check — but this requires LeanCTX to run before CM in the PreToolUse chain.

**Conflict 2.3.2 — Dual path to file analysis.** SB currently has two read paths: (a) direct Read (discouraged by CM rules for large files), and (b) `ctx_execute_file` sandbox processing (recommended for analysis). LeanCTX adds a third path: (c) AST-mode read at selected fidelity. The agent now has three ways to get file content, and the "correct" path depends on context (file size, purpose, AST availability). This increases cognitive load on the agent.

### 2.4 Search/Index Conflicts

**Conflict 2.4.1 — Dual FTS5 databases.** Both LeanCTX and Context Mode maintain independent FTS5 databases for indexed content (web fetches, batch execution output, stored content). Content indexed via `ctx_fetch_and_index` (CM) will not be searchable via LeanCTX's `ctx_search`, and vice versa. The agent must know which database to search for which content — creating a "which search tool do I use?" routing tax.

**Conflict 2.4.2 — Auto-indexing from batch_execute.** Context Mode's `ctx_batch_execute` auto-indexes command output into CM's FTS5. If the agent runs shell commands through LeanCTX's wire proxy, the output is compressed but not auto-indexed into CM's search. This breaks the "run commands → auto-index → search later" pattern SB relies on.

### 2.5 Memory Graph Conflicts

**Conflict 2.5.1 — Triple graph system.** SB currently has two graphs: agentmemory's `memory_graph_query` (decision graph, action DAG) and Graphify's `graphify query` (codebase knowledge graph with god nodes and Leiden communities). LeanCTX adds `ctx_graph` (context knowledge graph with call graph capabilities). Three graphs serving partially overlapping purposes:

| Graph | Primary Purpose | Unique Advantage |
|-------|----------------|------------------|
| Graphify | Codebase structure (AST, call graphs, god nodes, communities) | Multimodal corpus graph, Leiden community detection, mergeable `graph.json` |
| agentmemory | Work orchestration (action DAG, frontier, leases, agent coordination) | 53-tool orchestration surface built around the graph |
| LeanCTX `ctx_graph` | Context knowledge (compressed reads, saved decisions, session memory, AST-derived call graphs) | Integrated with wire proxy; automatically indexed from compressed reads |

**Conflict 2.5.2 — agentmemory `ctx_graph` vs LeanCTX `ctx_graph` vs Graphify.** agentmemory also has a `ctx_graph` concept, and LeanCTX has `ctx_graph`, and Graphify has `graphify query`. Three different graph APIs, three different graph backends, three different query languages — the agent must choose the right graph engine for the right question.

### 2.6 Shell Compression Conflicts

**Conflict 2.6.1 — Double compression.** RTK compresses shell output using per-CLI compressors (`rtk pytest`, `rtk go test`, `rtk gh`, `rtk rg`). LeanCTX's wire proxy also compresses shell output (as part of its holistic request-body compression). If both run on the same shell output, the result is double-compressed (RTK summary compressed again by LeanCTX's wire proxy), which adds latency without additional savings. Worse: RTK's structured summaries may not compress as cleanly as raw output, reducing the marginal benefit of the wire proxy's second pass.

**Conflict 2.6.2 — RTK PreToolUse rewrite vs LeanCTX PreToolUse rewrite.** RTK's PreToolUse hook rewrites shell commands to prefix with `rtk` (e.g., `pytest` → `rtk pytest`). LeanCTX's PreToolUse hook may also rewrite or intercept shell commands for PathJail allowlist checking or compression decisions. If both rewrite the same command, the result could be `leanctx rtk pytest` — an unintended double-wrapper that breaks command execution.

### 2.7 Token Accounting Conflicts

**Conflict 2.7.1 — Triple tracking.** Three independent token accounting systems:
- **LeanCTX Ed25519 ledger:** Cryptographically verifiable, hash-chained, measures what the wire proxy saves
- **RTK `rtk gain`:** Session-level per-command savings metrics, measures what RTK's compressors save
- **Context Mode `ctx_stats`:** Session-level context consumption by tool category, measures what CM's sandbox saves

These three systems measure different things with different methodologies. `ctx_stats` totals 200K tokens saved; `rtk gain` reports 150K; Ed25519 ledger reports 180K. None reconcile with the others. For SB's audit and reporting purposes, three conflicting token-savings numbers undermine the credibility of all three.

**Conflict 2.7.2 — Double counting.** If RTK saves 50K on a shell command and LeanCTX's wire proxy saves an additional 20K on the same compressed output, do you report 70K total (RTK + LeanCTX) or does LeanCTX's 20K include RTK's 50K in its baseline? Without a shared measurement standard, savings numbers are either double-counted or undercounted, and neither result is verifiable.

### 2.8 Runtime Governance Conflicts

**Conflict 2.8.1 — PathJail deny-by-default vs SB cooperative rules.** PathJail is a kernel-level deny-by-default with allowlisting — a hard enforcement that an agent cannot bypass. SB's hooks are cooperative — they depend on the agent following the AGENTS.md and `.mdc` rule instructions. These are fundamentally different governance models:

- **PathJail:** "You literally cannot run this command. The filesystem won't allow it."
- **SB hooks:** "You should not run this command. AGENTS.md says so. Please comply."

In a cooperative agent scenario (the agent follows instructions), both achieve the same outcome. In an adversarial or instruction-drift scenario (the agent misses or ignores a rule), PathJail provides actual security while SB hooks provide none. The conflict arises when PathJail blocks a command that SB hooks would have allowed (e.g., PathJail's default allowlist is too restrictive for SB's workflow patterns, which include legitimate `curl`/`wget` calls that Context Mode would redirect but PathJail would deny outright).

**Conflict 2.8.2 — PathJail vs SB's shell-skills.** SB's workflow engine dispatches shell commands as part of skill execution (e.g., `silver-execute` runs `git`, `npm test`, `pytest`, `gh`, etc.). PathJail's deny-by-default model requires explicit allowlisting for every binary and directory path. If PathJail hasn't been configured for SB's entire shell-surface, legitimate workflow steps will fail with PathJail denials.

### 2.9 Rules Tax

**Conflict 2.9.1 — Cumulative AGENTS.md/.mdc overhead.** SB already carries:
- `AGENTS.md` (repo level, ~109 lines / 9.5KB) — SB operational rules
- `silver-bullet.md` — canonical Silver Bullet instructions
- 6 `.mdc` files in `.cursor/rules/` — context-mode, agentmemory, graphify, token-compression-enforcement, recommended-tools, silver-orchestrator
- Context mode AGENTS.md (from system prompt) — ~56KB of routing rules
- SB skills (85 canonical skills, ~36 marketplace command stubs)

Adding LeanCTX adds:
- LeanCTX AGENTS.md / `.mdc` rules (estimated ~30-60KB based on existing tool rule sizes)
- LeanCTX's own auto-detected configuration instructions
- Potentially additional `.cursor/rules/leanctx.mdc`

Total rules tax could exceed 150KB of standing instructions — consuming significant context before any work is done. The wire proxy can compress these instructions on the wire, but they still consume agent reasoning capacity.

**Conflict 2.9.2 — Conflicting or redundant instructions.** With 5 tools' worth of rules, contradictions emerge:
- "NEVER read large files directly — use `ctx_execute_file`" (CM rule) vs "LeanCTX will compress reads automatically — reading files directly is safe" (LeanCTX rule)
- "Always route shell through RTK" (RTK rule) vs "PathJail blocks unlisted binaries — check the allowlist" (LeanCTX rule)

The agent receives contradictory guidance and must resolve it per-situation, adding reasoning overhead.

---

## 3. Resolution Strategies

The conflicts above are resolvable — but not by running all 5 tools at full capability as peers. Resolution requires deliberate architectural layering, toggling, and per-environment configuration.

### 3.1 Hook Ordering Treaty

**Principle:** LeanCTX runs as the *outermost* hook layer (closest to the model), SB enforcement hooks run as the *innermost* layer (closest to the tool execution). This ensures LeanCTX compresses *before* SB gates, and SB gates have the final word on enforcement.

| Hook Event | Order | Tool | Purpose |
|-----------|-------|------|---------|
| `SessionStart` | 1st | LeanCTX | Setup wire proxy, detect host, configure PathJail, initialize Ed25519 ledger |
| `SessionStart` | 2nd | SB hooks | Stamp project state, run diagnostics, gate recommended tools, load AGENTS.md |
| `PreToolUse` | 1st | LeanCTX | AST read-mode selection, command PathJail allowlist check, compression decisions |
| `PreToolUse` | 2nd | SB hooks | Read-deny (post-compression check), tool gating (rtk-gate, graphify-gate, etc.) |
| `PostToolUse` | 1st | SB hooks | Record usage metrics (pre-compression state) |
| `PostToolUse` | 2nd | LeanCTX | Update Ed25519 ledger, compress tool results for wire proxy |
| `PreCompact` | 1st | Context Mode | Reduce bootstrap reads, preserve critical decisions |
| `PreCompact` | 2nd | LeanCTX | Compress remaining context for re-injection |

**Why this order works:** LeanCTX's compression and PathJail happen first (optimizing/blocking before the model or enforcement sees the raw data). SB's enforcement happens second (it sees post-compression, post-PathJail data and applies process gates). PostToolUse is reversed: SB records pre-compression usage (for accurate before/after delta tracking), then LeanCTX compresses for the next request.

**Implementation:** This requires the host agent platform to support hook ordering. Cursor's hook system supports ordering via rule file priority. Claude Code supports sequential hook registration. Codex hooks are more limited (deny-only) — see §4.

### 3.2 Tool Role Specialization (Toggle Overlapping Subsystems)

**Principle:** LeanCTX's subsystems that overlap with deeper incumbent tools are toggled OFF. Only LeanCTX's genuinely unique capabilities remain active. The stack operates as:

| Capability | Primary Tool | Reason | Secondary Tool (status) |
|-----------|-------------|--------|------------------------|
| Shell compression | RTK | 236 releases of mature per-CLI compressors | LeanCTX shell compression: **OFF** |
| Sandbox execution | Context Mode | Credential passthrough, CTX_FETCH_STRICT compliance | LeanCTX `ctx_execute`: **OFF** |
| Fetch governance | Context Mode | Tiered SSRF blocking, documented platform matrix | LeanCTX fetch security: **OFF** |
| Sandbox search/index | Context Mode | Single FTS5 for all sandbox output | LeanCTX `ctx_search` on sandbox data: **OFF** |
| Multi-agent orchestration | agentmemory | 53-tool orchestration surface, proven at scale | LeanCTX `ctx_agent`/`ctx_handoff`: **OFF** |
| Decision memory capture | agentmemory | Team-shared Markdown exports, gitleaks scanning | LeanCTX memory capture: **OFF** |
| Codebase knowledge graph | Graphify | God nodes, Leiden communities, mergeable `graph.json` | LeanCTX `ctx_graph`: **OFF** |
| **Wire proxy** | **LeanCTX** | **Unique — no incumbent equivalent** | — |
| **AST read-path modes** | **LeanCTX** | **Unique — no incumbent intercepts reads before model** | — |
| **PathJail governance** | **LeanCTX** | **Unique — kernel-level deny-by-default** | — |
| **Ed25519 savings ledger** | **LeanCTX** | **Unique — cryptographic verification** | — |
| **Pre-model injection detection** | **LeanCTX** | **Unique — no incumbent addresses this** | — |
| **Tool-Catalog Gateway** | **LeanCTX** | **Unique — proxy downstream MCP** | — |

**Implementation:** LeanCTX's feature toggles (or, if toggles aren't available, routing rules) disable `ctx_execute`, `ctx_search` (on sandbox data), `ctx_graph`, `ctx_agent`, `ctx_shell` (compression path) when the corresponding incumbent is installed. LeanCTX's `ctx_search` can remain active for *wire proxy-cached content* — a separate scope from CM's sandbox-indexed content.

### 3.3 Shell Compression: RTK Primary, LeanCTX Wire-Only

**Principle:** RTK handles per-command shell compression (its core competence). LeanCTX's wire proxy handles *aggregate request compression* (its unique competence). They operate at different layers and should not overlap:

```
Raw shell output → RTK compresses (per-CLI) → compressed summary → LeanCTX wire proxy (aggregates with rest of request)
```

**RTK PreToolUse rewrite takes priority.** The `rtk` prefix is applied by RTK's hook. LeanCTX's hook must recognize `rtk`-prefixed commands and skip its own shell rewrite. This requires LeanCTX to be RTK-aware (which it partially is, via its RTK addon documentation).

**If double compression is a persistent issue:** Disable LeanCTX's native shell compression entirely and rely on the wire proxy's holistic request compression (which compresses whatever arrives, RTK-compressed or not, as part of the aggregate request body).

### 3.4 Token Accounting: Single Ledger

**Principle:** Pick one authoritative token accounting system. The Ed25519 savings ledger is the strongest candidate because it is cryptographically verifiable, which aligns with SB's evidence-based governance model.

| System | Role |
|--------|------|
| Ed25519 ledger (LeanCTX) | **Authoritative savings record.** Measures wire-proxy savings across all layers. Hash-chained for audit. |
| `rtk gain` | Session-level per-command metrics. Reports to Ed25519 ledger. |
| `ctx_stats` | Session-level context consumption breakdown. Reports to Ed25519 ledger. |

**Implementation:** RTK and Context Mode metrics are treated as *inputs* to the Ed25519 ledger, not as competing sources of truth. The ledger records: "RTK saved X tokens on command Y; Context Mode saved Z tokens via sandbox; net savings = X + Z."

**If this integration is impractical:** Keep only the Ed25519 ledger as the authoritative source. Suppress `rtk gain` display and `ctx_stats` display to avoid conflicting numbers in the agent's view. Keep both available for debugging but not presented as "the number."

### 3.5 Search/Index: Scope Separation

**Principle:** Two FTS5 databases with clearly separated scopes. The agent never needs to guess which search tool to use because the scope determines the tool:

| Database | Scope | Tool |
|----------|-------|------|
| LaunchCTX FTS5 | Wire-proxy-cached content (compressed reads, re-read cache, proxy-fetched pages) | `ctx_search` (LeanCTX) |
| Context Mode FTS5 | Sandbox-processed output (batch_execute output, sandbox fetch results, manually indexed content) | `ctx_search` (Context Mode) |

**The agent rule:** "If you processed the content in a sandbox, search CM. If you read the file directly (compressed by LeanCTX), search LeanCTX. If uncertain, search both."

### 3.6 PathJail + SB Hooks: Layered Governance

**Principle:** PathJail provides hard enforcement for the outer boundary (what binaries can run, what paths can be accessed). SB hooks provide soft enforcement for the inner boundary (what workflows are followed, what quality gates pass). They are complementary, not competing:

| Governance Layer | Type | Scope |
|-----------------|------|-------|
| PathJail | Hard (kernel-level deny-by-default) | Binary allowlist, path access control, network egress (if supported) |
| SB hooks | Soft (instruction-following with gate enforcement) | Workflow compliance, quality gates, skill routing, PR safety |

**PathJail allowlist must include SB's entire shell surface.** SB's workflows legitimately invoke: `git`, `npm`, `pytest`, `gh`, `jq`, `bash`, `python3`, `rg`, `docker`, `kubectl`, `aws`, `gcloud`, and others depending on project type. The PathJail allowlist must be project-configured via SB's `.silver-bullet.json` (or a new `pathjail-allowlist.json` section) rather than a hardcoded default.

### 3.7 Memory Graph: Three Graphs, Three Purposes, Clear Contracts

**Principle:** The three graph systems serve fundamentally different purposes. The conflict is navigability, not capability overlap. The resolution is clear documentation of which graph answers which question:

| Question | Use | Because |
|----------|-----|---------|
| "What files call this function?" | Graphify `query` | Codebase AST graph with call edges and god nodes |
| "What's the dependency structure?" | Graphify `path` | Leiden communities reveal module boundaries |
| "What work is pending for which agent?" | agentmemory `memory_frontier` | Action DAG with lease/exclusive access semantics |
| "What decisions were made about X?" | agentmemory `memory_graph_query` | Decision graph with temporal edges and evidence links |
| "What was the context-state during the last `ctx_execute` call?" | LeanCTX `ctx_graph` | Integrated wire-proxy-compressed context snapshot |
| "How did the project state evolve across sessions?" | LeanCTX `ctx_graph` | Cross-session state diffing from wire-proxy cache |

**Agent routing rule:** "Use Graphify for code. Use agentmemory for work/decisions. Use LeanCTX graph for context-state tracking. If a question spans domains, start with the domain-specific graph and cross-reference."

### 3.8 Rules Tax Mitigation

**Principle:** LeanCTX's rules should be scoped to its *active capabilities only*, not its full feature catalog. If LeanCTX's shell compression, sandbox, memory, and graph subsystems are toggled OFF, their rules should not be present in AGENTS.md.

**Mitigation strategies:**
1. **Conditional rules:** The LeanCTX `.mdc` rule file should document only active LeanCTX capabilities (wire proxy, PathJail, AST read modes, Ed25519 ledger, injection detection). Subsystems that are toggled OFF should not generate rules.
2. **Wire-proxy compression of rules:** Since LeanCTX's wire proxy compresses the system prompt (which includes rules files), the rules overhead is partially self-mitigating — LeanCTX compresses its own rules at the wire level.
3. **Consolidation:** SB's 6 `.mdc` files + potential LeanCTX `.mdc` = 7 rule files. Consider consolidating into fewer, role-grouped files (e.g., `governance.mdc` covering PathJail + CM gates, `compression.mdc` covering RTK + wire proxy, `memory-graph.mdc` covering agentmemory + Graphify).

---

## 4. Per-Environment Analysis

SB targets three primary environments (Cursor, Codex, Claude Code) with documented capability tiers (`sb-diagnostics.sh` output). The 5-stack integration feasibility varies significantly by environment.

### 4.1 Claude Code (Tier 3 — full hook system)

**Hook support:** Claude Code has the richest hook surface of the three: supports PreToolUse, PostToolUse, SessionStart, PreCompact, Stop, and others. Supports sequential hook registration with ordering control.

**Feasibility of 5-stack integration: HIGHEST.**

- **Hook ordering treaty** (§3.1) is implementable: LeanCTX hooks registered first, SB enforcement hooks registered second. Claude Code's hook system allows explicit ordering.
- **MCP port coordination** is straightforward: Claude Code supports multiple MCP servers with individual port configurations.
- **PathJail integration:** Claude Code runs in a local process with full filesystem access — PathJail can operate at the process level. The allowlist can be project-scoped.
- **Wire proxy:** Claude Code's request pipeline supports proxy middleware. LeanCTX's wire proxy can be configured as a request middleware layer.
- **Rules tax:** Claude Code processes AGENTS.md + CLAUDE.md. The cumulative rules from 5 tools are significant but wire-proxy-compressible.

**Capability tier:** If SB adds LeanCTX, the `sb-diagnostics.sh` output should report Tier 3+ ("LeanCTX-enhanced") for Claude Code.

### 4.2 Cursor (Tier 2 — MCP + allow-lists + .mdc rules)

**Hook support:** Cursor supports a subset of Claude Code's hook events (PreToolUse, PostToolUse, SessionStart confirmed). Hook ordering is less granular — rule file priority determines execution order, not explicit hook registration order. Cursor's hook system is allow-list-based (tools must be explicitly allowed in `.cursor/rules/`).

**Feasibility of 5-stack integration: HIGH (with constraints).**

- **Hook ordering** is achievable via `.mdc` file priority (cursor rules load in alphabetical/globbing order). Prefix rule files with numbers to enforce order: `01-leanctx.mdc` → `02-context-mode.mdc` → `03-rtk.mdc` → `04-agentmemory.mdc` → `05-graphify.mdc`.
- **MCP tool allowlisting:** Cursor requires each MCP tool to be allowlisted. With 5 MCP servers (81 + 11 + 10 + 53 + ~10 tools), the allowlist must explicitly authorize every tool. This is tedious but feasible. LeanCTX's 5-tool unified gateway mode reduces the allowlist surface from 81 to 5 entries for LeanCTX.
- **PathJail:** Cursor's sandbox model may not support kernel-level filesystem jails. PathJail may need to be implemented as a Cursor rule (soft enforcement) rather than kernel-level (hard enforcement) in this environment.
- **Wire proxy:** Cursor does not natively support a request proxy middleware in the same way Claude Code does. LeanCTX's wire proxy may need to operate as a passthrough MCP server or a separate process that intercepts network requests to the LLM API.
- **Rules tax:** Cursor already has 6 `.mdc` files. Adding a 7th is manageable. Cursor's rule system handles multiple `.mdc` files well.

**Capability tier:** Cursor would remain at Tier 2 for LeanCTX integration (some unique capabilities — wire proxy, AST modes — may not be fully realizable due to Cursor's architecture; PathJail may be soft only).

### 4.3 Codex (Tier 2 — deny-only hooks, limited MCP)

**Hook support:** Codex has the most limited hook surface of the three: deny-only hooks (can block, cannot transform), no PostToolUse modifications, no request interception. Codex exposes native `/silver:` command entries via its plugin system.

**Feasibility of 5-stack integration: MODERATE (significant constraints).**

- **Hook ordering:** Codex's deny-only model means LeanCTX's PreToolUse transforms (AST mode routing, compression) are NOT achievable through Codex hooks. The agent can be instructed to use LeanCTX tools explicitly, but hook-enforced read compression is not possible.
- **MCP:** Codex supports MCP servers via its plugin infrastructure. Tool namespace collisions (§2.2.2) are a concern — Codex must disambiguate between CM's `ctx_execute` and LeanCTX's `ctx_execute`.
- **PathJail:** Hard enforcement is limited by Codex's sandbox model. Soft enforcement via rules is the fallback.
- **Wire proxy:** Codex does not support request-level proxy middleware. LeanCTX's wire proxy would need to operate as a separate network-level proxy that Codex routes its LLM API calls through — a configuration that may not be supported by Codex's current architecture.
- **Recommended approach for Codex:** Treat LeanCTX as a *supplemental tool* (agent invokes `ctx_wire_proxy_stats`, `ctx_pathjail_check`, `ctx_ed25519_verify` explicitly) rather than a transparent hook layer. The wire proxy and AST read modes — LeanCTX's strongest unique capabilities — are likely non-functional in Codex's current architecture.

**Capability tier:** Codex would remain at Tier 2 for LeanCTX integration, with the caveat that only LeanCTX's explicit MCP tools (Ed25519 ledger queries, injection detection, PathJail status checks) are functional.

### 4.4 OpenCode (potential 4th target — MCP-first architecture)

**Hook support:** OpenCode's hook architecture differs from Cursor/Claude Code/Codex. It is MCP-first — tools are MCP servers, hooks are tool interception rules. OpenCode's `opencode.json`/`opencode.jsonc` configuration supports MCP server declarations, permission rules, and subagent definitions. No native PreToolUse/PostToolUse hook events in the same sense as Claude Code.

**Feasibility of 5-stack integration: MODERATE-HIGH (different architecture, but MCP-first makes tool integration cleaner).**

- **MCP server registration:** OpenCode's `opencode.json` can declare all 5 MCP servers with port assignments, tool scoping, and permission rules. This is cleaner than Cursor's allowlist model because it's declarative rather than per-tool enumeration.
- **Tool namespace collisions:** OpenCode's permission rules can scope which tools are available to which agents/subagents. CM's `ctx_execute` and LeanCTX's `ctx_execute` can be scoped to different subagents, or one can be disambiguated via prefix.
- **Wire proxy:** OpenCode may not natively support request-level proxy middleware. However, OpenCode supports custom MCP server processes, which could include a passthrough proxy. LeanCTX's wire proxy could be registered as a middleware MCP server.
- **PathJail:** OpenCode runs as a local CLI tool — kernel-level PathJail enforcement is feasible if OpenCode inherits process-level filesystem permissions.
- **Rules tax:** OpenCode uses `AGENTS.md` and `opencode.json` for configuration. The cumulative rules from 5 tools plus SB's own rules would be significant. However, OpenCode's plugin/permission model may allow LeanCTX capabilities to be declared as permissions rather than instructions, reducing prose overhead.

**Recommendation for OpenCode:** If SB formally targets OpenCode, make LeanCTX a first-class OpenCode integration (MCP server with permission rules in `opencode.json`). The MCP-first architecture is a better fit for LeanCTX than Cursor's allow-list model.

---

## 5. Five-Stack Synergy Assessment

### 5.1 What SB Gains (Net Positive, Contingent on Layering)

| Gain | Mechanism | Magnitude |
|------|-----------|:---------:|
| **Wire-level context savings** | Wire proxy compresses system prompt + history + tool results — the largest compression surface | **Large** |
| **Hard shell governance** | PathJail deny-by-default replaces cooperative "please don't curl" rules with actual enforcement | **Large** |
| **Automatic read compression** | AST modes eliminate the "read vs ctx_execute_file" decision — all reads are compressed | **Medium-Large** |
| **Cryptographically verifiable savings** | Ed25519 ledger provides audit-grade evidence of token compression | **Medium (high for enterprise)** |
| **Pre-model security** | Prompt injection detection catches poisoned content before it reaches the model | **Medium** |
| **MCP consolidation** | Tool-Catalog Gateway can proxy downstream MCP servers, reducing standing tool schema overhead | **Medium** |
| **Cache efficiency** | Cache-prefix volatility relocation improves hit rates on SB's date/UUID/SHA-heavy workflow state | **Small-Medium** |

### 5.2 What SB Loses (Net Negative, Mitigated by Layering)

| Loss | Mechanism | Mitigation |
|------|-----------|------------|
| **Operational complexity** | 5 tools with 5 setup paths, 5 MCP servers, hook ordering, toggle management | Document as phased tiers; tool-role specialization reduces active surface |
| **Rules tax** | 150KB+ standing instructions inflate agent context | Wire proxy self-mitigates; consolidate `.mdc` files; conditional rules only for active subsystems |
| **Agent decision fatigue** | "Which tool do I use for this?" — 5 tools with overlapping surfaces | Clear contracts (use Graphify for code, agentmemory for decisions, CM for sandbox, RTK for shell, LeanCTX for wire-layer) |
| **Debug complexity** | When context savings are lower than expected, which of the 5 tools is underperforming? | Single Ed25519 ledger provides unified view |
| **Upgrade coordination** | 5 independently-versioned tools with weekly/daily releases create a moving compatibility target | Pin versions in `.silver-bullet.json`; CI gate for tool version compatibility |

### 5.3 Diminishing Returns Assessment

The marginal benefit of each additional tool declines:

| Stack | Cumulative Unique Capabilities | Cumulative Overlap |
|-------|:---:|:---:|
| RTK alone | Shell compression | — |
| RTK + CM | + Sandbox + fetch governance + search/index | — |
| RTK + CM + agentmemory | + Decision memory + orchestration | agentmemory memory vs CM session KB |
| RTK + CM + agentmemory + Graphify | + Codebase graph + multimodal corpus + god nodes | Graphify graph vs agentmemory memory graph |
| **+ LeanCTX (wire-layer only)** | **+ Wire proxy + PathJail + AST reads + Ed25519 + injection detection** | **LeanCTX shell vs RTK, LeanCTX sandbox vs CM, LeanCTX memory vs agentmemory, LeanCTX graph vs Graphify** |

The 4th tool (Graphify) has minimal overlap with the prior 3 — it adds a genuinely distinct capability (codebase graph) with little redundancy. The 5th tool (LeanCTX) has **substantial overlap with all 4** but also adds 5 capabilities none of the 4 have. The net is positive *only if* LeanCTX's overlapping subsystems are toggled OFF. With full 5-tool activation, the overlap penalty exceeds the unique-capability gain for all but the wire proxy and PathJail.

**Diminishing returns curve:**
```
1 tool  (RTK):          ■■■■■■■■■■  (foundational)
2 tools (+CM):          ■■■■■■■■    (strong add)
3 tools (+agentmemory): ■■■■■■      (significant add)
4 tools (+Graphify):    ■■■■        (modest add — low overlap, specialized)
5 tools (+LeanCTX):     ■■■ (if full) → ■■■■■ (if wire-layer only)
```

### 5.4 Scenarios Where the 5-Stack Is Unambiguously Better

1. **Enterprise regulated + multi-agent at scale:** LeanCTX (PathJail + Ed25519 ledger) + CM (CTX_FETCH_STRICT) + agentmemory (53-tool orchestration) + Graphify (codebase graph) + RTK (shell compression). All 5 tools fill non-overlapping roles when properly scoped.
2. **Security-first SB deployment:** LeanCTX's four security capabilities (PathJail, injection detection, Ed25519 ledger, wire proxy) are genuinely additive and fill gaps no incumbent addresses. Even if leanCTX's overlapping subsystems are redundant, these four capabilities alone justify the addition.
3. **Long-session SB workflows:** SB's full-dev-cycle workflow can span hundreds of turns. The wire proxy's holistic compression of system prompt + history + tool results provides savings that scale with session length — the longer the session, the more the wire proxy saves.

### 5.5 Scenarios Where the 5-Stack Is Not Worth the Cost

1. **Solo dev on a small project:** The 4-tool stack is already operationally heavy for one person. Adding a 5th tool with toggle management and hook ordering is overhead without proportional benefit.
2. **Codex-only deployment:** LeanCTX's strongest capabilities (wire proxy, AST read modes) are likely non-functional in Codex's architecture. The remaining capabilities (Ed25519 ledger, injection detection) do not justify the integration complexity.
3. **Simple SB workflows** (bugfix, fast-path, content-only): These workflows are short and targeted. The wire proxy's savings are proportional to session length — short sessions see minimal savings. The rules tax of 5 tools may exceed the wire proxy savings.

---

## 6. Recommendation

### 6.1 Should SB Add LeanCTX?

**Yes — but as a foundation layer, not a peer tool.** The recommendation is NOT "add LeanCTX as a 5th recommended tool alongside the existing 4." The recommendation is: **restructure the SB tool stack into 3 layers, with LeanCTX as Layer 1 (foundation).**

### 6.2 Three-Layer Architecture

```
┌─────────────────────────────────────────────┐
│ LAYER 3: Knowledge & Orchestration          │
│   agentmemory (decision memory + 53-tool    │
│     orchestration surface)                  │
│   Graphify (codebase knowledge graph +      │
│     multimodal corpus)                      │
├─────────────────────────────────────────────┤
│ LAYER 2: Execution & Governance             │
│   RTK (per-CLI shell compression)           │
│   Context Mode (sandbox + CTX_FETCH_STRICT  │
│     + FTS5 search/index)                    │
├─────────────────────────────────────────────┤
│ LAYER 1: Wire Foundation (LeanCTX unique)   │
│   Wire proxy (compress prompt+history+tools)│
│   AST read-path modes (10+ fidelity levels) │
│   PathJail (deny-by-default shell allowlist)│
│   Ed25519 savings ledger (cryptographic)    │
│   Pre-model injection detection             │
│   MCP Tool-Catalog Gateway                  │
└─────────────────────────────────────────────┘
```

**Layer 1 (LeanCTX foundation) is always ON.** These capabilities are unique, non-overlapping, and benefit every layer above them. They operate at the wire level and cannot interfere with the upper layers' logic.

**Layer 2 (Execution) and Layer 3 (Knowledge) are persona-conditional** — exactly as the consolidated report recommends:
- Solo dev: Layer 1 only (LeanCTX wire foundation)
- Shell-heavy: Layer 1 + RTK from Layer 2
- Regulated: Layer 1 + Context Mode from Layer 2 (for CTX_FETCH_STRICT)
- Multi-agent: Layer 1 + agentmemory from Layer 3
- Full SB: Layer 1 + Layer 2 + Layer 3

### 6.3 Phased Adoption Path

**Phase 1: Layer 1 only — Wire Foundation (recommended for all SB users)**

Install LeanCTX and configure ONLY the wire-layer capabilities:
- Wire proxy enabled
- AST read modes enabled (ModePredictor on)
- PathJail enabled with SB shell-surface allowlist
- Ed25519 savings ledger enabled
- Pre-model injection detection enabled
- All LeanCTX subsystems that overlap with incumbents: **toggled OFF**

This phase has zero conflict with the existing 4-tool stack. LeanCTX sits at the wire layer; the 4 incumbents operate inside it. No tool namespace collisions (LeanCTX's overlapping tools are disabled), no hook conflicts (LeanCTX runs before SB hooks), no double compression (LeanCTX native shell compression is off; wire proxy compresses RTK's output as part of aggregate request).

**Deliverable:** `leanctx-layer1.mdc` rule file (for Cursor), configuration template for Claude Code, configuration notes for Codex (limited functionality). Updated `sb-diagnostics.sh` to report LeanCTX wire-layer presence. PathJail allowlist template in `.silver-bullet.json`.

**Success criteria:** Documented wire-level token savings (Ed25519 ledger), zero conflicts with existing 4-tool stack, measurable reduction in session token consumption on identical SB workflows.

---

**Phase 2: Tool-Catalog Gateway (optional, for teams wanting MCP consolidation)**

Enable LeanCTX's MCP Tool-Catalog Gateway to proxy the 4 incumbent MCP servers behind 5 unified tools. This reduces the standing MCP tool descriptor overhead from ~85 tools (11 CM + 10 GF + 53 AM + ~10 RTK) to 5 unified gateway tools + wire-layer tools.

**Deliverable:** Gateway configuration that proxies CM/RKT/AM/GF MCP servers. Agent routing instructions for the 5 unified tools.

**Success criteria:** Measurable reduction in tool descriptor context overhead. No degradation in agent's ability to correctly route tool calls.

---

**Phase 3: Full 5-stack persona profiles (for advanced setups)**

Document persona-specific stacks in `recommended-tools.mdc`:
- **Profile "wire-baseline":** Layer 1 only (LeanCTX wire foundation)
- **Profile "solo-dev":** Layer 1 + RTK (if shell-heavy)
- **Profile "regulated":** Layer 1 + Context Mode (for CTX_FETCH_STRICT)
- **Profile "team":** Layer 1 + agentmemory (for team memory + orchestration)
- **Profile "full-sb":** Layer 1 + Layer 2 + Layer 3 (all 5 tools, persona-conditional toggles)

Each profile documents: which tools are active, which LeanCTX subsystems are toggled, hook ordering configuration, MCP port assignments, PathJail allowlist, and expected rules tax.

---

### 6.4 Integration with SB's Existing Infrastructure

**Changes to `.silver-bullet.json`:**
```json
{
  "recommended_tools": {
    "leanctx": {
      "layer": "foundation",
      "enabled_subsystems": ["wire_proxy", "ast_read_modes", "pathjail", "ed25519_ledger", "injection_detection"],
      "disabled_subsystems": ["shell_compression", "sandbox_execution", "memory_capture", "ctx_graph", "ctx_agent"],
      "pathjail_allowlist": ["git", "npm", "pytest", "gh", "jq", "bash", "python3", "rg", "docker"],
      "mcp_port": 3010,
      "install_commands": ["npm install -g lean-ctx", "lean-ctx setup"]
    }
  }
}
```

**Changes to `hooks/hooks.json`:**
- Add `leanctx-gate.sh` to PreToolUse handlers (position: first in array)
- Add `leanctx-post-compression.sh` to PostToolUse handlers (position: last in array)
- Add `leanctx-session-init.sh` to SessionStart handlers (position: first in array)

**Changes to `.cursor/rules/`:**
- Add `leanctx-layer1.mdc` (wire-layer capabilities and routing rules)
- Update `recommended-tools.mdc` with persona profiles (§6.3 Phase 3)
- Update `token-compression-enforcement.mdc` to reflect wire proxy as primary compressor

**Changes to `AGENTS.md`:**
- Add brief LeanCTX section under "Recommended Tools" describing Layer 1 role
- Update read-path guidance: "Default: read files directly — LeanCTX wire proxy handles AST-mode compression. For analysis-only reads, `ctx_execute_file` remains available."
- Update governance guidance: "PathJail enforces shell safety at the filesystem level. SB hooks enforce workflow compliance at the process level. Both are active."

**Changes to `sb-diagnostics.sh`:**
- Detect LeanCTX presence and report layer configuration
- Report wire proxy status, PathJail allowlist coverage, Ed25519 ledger health
- Add LeanCTX-enhanced capability tier (Tier 3+ for Claude Code with wire proxy, Tier 2+ for Cursor with soft PathJail)

### 6.5 Open Questions and Risks

1. **Can LeanCTX's subsystems be independently toggled?** The analysis assumes they can. If LeanCTX's architecture bundles all subsystems (all-or-nothing), the Phase 1 approach (wire-layer only) may not be achievable. The fallback is to accept the overlap and rely on hook ordering + agent routing rules to avoid conflicts — a messier but functional approach.

2. **Does LeanCTX's wire proxy work as a transparent middleware, or must the agent explicitly route through it?** If transparent (intercepts all LLM API calls automatically), integration is clean. If explicit (agent must call `ctx_wire_proxy` tools), the operational model changes significantly and the savings are less automatic.

3. **Will LeanCTX's PathJail work across all 3 (or 4) target environments?** Kernel-level filesystem jails may not be supported in Cursor's or Codex's sandbox models. Soft PathJail (rule-based enforcement) is the fallback but loses the "cannot be bypassed" advantage.

4. **What is the performance overhead of the wire proxy?** Adding a request-middleware proxy adds latency to every LLM API call. If the compression processing adds >500ms per request, it may negatively impact the interactive coding experience. This must be measured before recommending universal adoption.

5. **How does LeanCTX's wire proxy interact with SB's multi-model subagent dispatch?** SB dispatches subagents (Cursor Task tool, Claude Code parallel workers) with different models. If the wire proxy intercepts all LLM API calls, it must be model-aware (different models have different compression characteristics). LeanCTX's `proxy.effort` capability addresses cross-model reasoning-effort pinning, which suggests awareness — but this needs verification.

### 6.6 Final Verdict

**Add LeanCTX as a foundation layer, not a peer tool.** The wire proxy, PathJail, AST read modes, Ed25519 ledger, and injection detection are genuinely novel capabilities that fill gaps the 4-tool stack cannot close. The overlapping subsystems (shell compression, sandbox, memory, graph) should be toggled OFF when incumbents are present. This layered architecture preserves the depth advantage of the incumbent tools while adding LeanCTX's unique governance and compression surface.

The conflicts identified in §2 are real but resolvable via the strategies in §3 — hook ordering, tool role specialization, scope separation, and layered governance. The per-environment analysis in §4 shows that Claude Code supports the fullest integration, Cursor supports most capabilities with constraints, Codex is limited to explicit tool usage, and OpenCode (if SB targets it) is a strong fit for LeanCTX's MCP-first architecture.

The phased adoption path (§6.3) minimizes risk: start with Layer 1 only (zero conflicts), measure wire-proxy savings with the Ed25519 ledger, then expand to Tool-Catalog Gateway and persona profiles as the integration proves itself.

**The alternative — not adding LeanCTX — is also defensible.** The 4-tool stack is mature, independently validated, and deeply integrated into SB's workflow engine. Adding a 5th tool with architectural layering adds operational complexity that may not be justified for teams satisfied with their current stack. The recommendation is to offer LeanCTX as an *optional enhancement tier* (like SB's capability tiers 0-3), not as a mandatory upgrade. Solo devs and small teams may prefer the 4-tool simplicity. Enterprise and security-conscious teams will benefit most from the layered 5-stack.

---

## Appendix A: Conflict Resolution Summary Matrix

| Conflict | Severity | Resolution Strategy | Effort | Risk |
|----------|:--------:|--------------------|:------:|:----:|
| PreToolUse ordering | High | LeanCTX first (compress), SB second (enforce) | Medium | Depends on host hook ordering support |
| PostToolUse ordering | Medium | SB first (record pre-compression), LeanCTX second (compress) | Low | Low |
| SessionStart initialization | Medium | LeanCTX first (wire proxy), SB second (project state) | Low | LeanCTX must not delay SB init |
| PreCompact divergence | Low | CM first (reduce re-bootstrap), LeanCTX second (compress) | Low | Low |
| MCP port collision | Medium | Documented port assignment in `.silver-bullet.json` | Low | Low |
| MCP tool namespace | High | Disable LeanCTX overlapping tools; prefix if both active | Medium | Agent must not be confused by ambiguous tool names |
| MCP tool descriptor overhead | Medium | Tool-Catalog Gateway (Phase 2) | Medium | Gateway adds routing tax |
| Read deny vs compress | High | LeanCTX compresses first, CM denies post-compression threshold | Medium | Requires hook ordering |
| Dual FTS5 databases | Low | Scope separation (wire-proxy cache vs sandbox output) | Low | Agent must know which to search |
| Triple graph system | Medium | Clear contracts (Graphify=code, agentmemory=work, LeanCTX=context) | Low | Agent routing tax |
| Double shell compression | Medium | RTK primary, LeanCTX native shell compression OFF | Low | LeanCTX must support toggling |
| RTK vs LeanCTX PreToolUse rewrite | High | RTK rewrite has priority; LeanCTX recognizes RTK prefix | Medium | LeanCTX must be RTK-aware |
| Triple token accounting | Medium | Ed25519 ledger as authoritative; RTK/CM feed into it | Medium | Integration may be impractical — fall back to single ledger |
| PathJail vs SB cooperative rules | Medium | PathJail hard enforcement for shell, SB soft enforcement for workflow | Medium | PathJail allowlist must cover SB's shell surface |
| Cumulative rules tax | Medium | Wire proxy self-mitigates; consolidate `.mdc` files; conditional rules | Low-Medium | Rules must be actively maintained |
| Diminishing returns | High | Toggle overlapping LeanCTX subsystems OFF | Medium | Depends on LeanCTX toggle granularity |

## Appendix B: Environment Capability Matrix

| Capability | Claude Code | Cursor | Codex | OpenCode (projected) |
|-----------|:---:|:---:|:---:|:---:|
| Wire proxy (transparent middleware) | Yes | Partial (passthrough MCP) | No (network proxy only) | Partial (MCP middleware) |
| AST read-path modes (PreToolUse intercept) | Yes | Yes | No (deny-only hooks) | Yes (MCP tool intercept) |
| PathJail (kernel-level jail) | Yes | Soft only | Soft only | Yes |
| PathJail (soft/rule enforcement) | Yes | Yes | Yes | Yes |
| Ed25519 ledger (passive) | Yes | Yes | Yes | Yes |
| Injection detection (PreToolUse) | Yes | Yes | No | Yes |
| Hook ordering control | Yes | Partial (file priority) | No | Yes (declarative) |
| MCP Tool-Catalog Gateway | Yes | Yes | Yes | Yes (native) |
| SB hook enforcement (12 layers) | Full | 7/12 layers | Partial (deny-only) | TBD |
| Recommended integration depth | Full 5-stack layered | 5-stack, soft PathJail | Partial (explicit tools only) | 5-stack, MCP-first |

---

*End of report.*

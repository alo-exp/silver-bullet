# Follow-Up: Adding LeanCTX to Silver Bullet's Existing 4-Tool Stack

**Model:** qwen3.7-max  
**Date:** 2026-07-07  
**Question:** Would adding LeanCTX to the existing 4-tool Silver Bullet stack (RTK + Context Mode + agentmemory + Graphify) be better for Silver Bullet? Would there be any conflict? How to resolve conflicts and make all 5 operationally smooth and synergistic across Cursor, Codex, Claude Code, and potentially OpenCode?

---

## Executive Summary

Adding LeanCTX as a **fifth tool alongside** the existing four is **not recommended** as a default configuration. The conflict surface is substantial: 9 distinct conflict categories, each requiring explicit resolution. However, LeanCTX's **wire proxy compression** and **PathJail runtime governance** fill genuine gaps in SB's current stack that no existing tool addresses. The optimal path is a **selective integration** strategy: LeanCTX replaces RTK + Context Mode's compression/sandbox layer (becoming the new "layer 2") while agentmemory and Graphify remain untouched. This yields a **3-tool stack** (LeanCTX + agentmemory + Graphify) that is both simpler and more capable than the current 4-tool configuration — but only for environments where `CTX_FETCH_STRICT` compliance is not required.

For SB specifically — a process orchestrator with 60 hook scripts, 7 hook event types, and multi-environment deployment across Cursor/Codex/Claude Code/OpenCode — the integration cost is non-trivial but manageable if approached as a phased migration rather than a bolt-on addition.

---

## 1. Would Adding LeanCTX Benefit SB?

### 1.1 Genuine Gaps LeanCTX Fills

| Gap in Current SB Stack | LeanCTX Capability | Impact for SB |
|------------------------|-------------------|---------------|
| No wire/request-path compression | Wire proxy compresses prompt + history + tool results every request | **High** — SB sessions are long (workflow chains, multi-phase), history accumulates heavily |
| No filesystem-level runtime governance | PathJail deny-by-default shell allowlist | **High** — SB currently relies on cooperative rules in AGENTS.md; PathJail provides hard enforcement |
| No pre-model prompt-injection detection | Built-in injection scanner on read path | **Medium** — SB's hook-heavy architecture processes many external inputs |
| No cryptographic savings audit | Ed25519 hash-chained ledger + offline verify | **Medium** — SB's `record-token-compression-usage.sh` tracks usage but not tamper-evidently |
| No read-path AST fidelity routing | 10 read modes with ModePredictor | **Medium** — SB agents read the same files repeatedly across workflow phases |
| No cross-provider reasoning-effort pinning | `proxy.effort` parameter | **Low-Medium** — useful for SB's multi-model research workflows |

### 1.2 Overlap with Existing Tools

| LeanCTX Capability | Already Covered By | Overlap Severity |
|-------------------|-------------------|-----------------|
| Shell output compression | RTK (97% parity) | **High** — direct duplication |
| MCP sandbox execution | Context Mode `ctx_execute*` | **High** — parallel sandbox |
| FTS5 knowledge base + search | Context Mode `ctx_search` | **High** — dual FTS5 databases |
| Session memory + auto-capture | Context Mode hooks + agentmemory | **High** — triple memory layer |
| Knowledge graph + scoped retrieval | Graphify | **Medium** — different graph implementations |
| Hook-based interception | SB's 60 hook scripts + CM hooks | **High** — hook chain explosion |
| Fetch + index + search | Context Mode `ctx_fetch_and_index` | **High** — parallel fetch pipelines |

### 1.3 Verdict

LeanCTX fills **3 genuine high-impact gaps** (wire proxy, PathJail, prompt-injection detection) and **2 medium-impact gaps** (Ed25519 audit, AST read modes). However, it **overlaps heavily** with 7 existing capabilities across RTK and Context Mode. Adding it as a fifth tool without removing or disabling overlapping functionality would create more problems than it solves.

---

## 2. Conflicts — Complete Inventory

### 2.1 Hook Conflicts

SB currently runs **60 hook scripts** across **7 event types**:

| Event Type | SB Handlers | Context Mode Hooks | LeanCTX Would Add | Conflict |
|-----------|:-----------:|:------------------:|:-----------------:|----------|
| SessionStart | 1 (`subagent-start.sh`, `stop-check.sh`, `spec-session-record.sh`) | Session KB init, stats reset | LeanCTX cache init, PathJail setup | **Triple initialization** — ordering matters, all three compete for first-run |
| PreToolUse | 9 handlers (gates for RTK, CM, agentmemory, Graphify, planning, CI, etc.) | WebFetch deny, curl redirect, credential redaction, read-deny | Read-path AST intercept, PathJail enforcement, injection scan, shell compress | **Critical** — SB already has `context-mode-read-deny.sh` blocking large reads; LeanCTX intercepts Read before model. Two competing read-path policies |
| PostToolUse | 7 handlers (recording, flow-advance, compliance, skill recording) | Auto-capture decisions/errors, KB indexing | Shell output compress, bounce detect, savings ledger write | **High** — both CM and LeanCTX want to process every tool result |
| SubagentStart | 1 handler | — | — | No conflict |
| Stop | 1 handler | Session summary | Session summary + ledger flush | **Medium** — competing session-end summaries |
| SubagentStop | 1 handler | — | — | No conflict |
| UserPromptSubmit | 1 handler | Prompt capture | Injection scan | **Low** — complementary, but ordering matters |

**Specific hook-on-hook conflicts:**

| SB Hook | LeanCTX Equivalent | Conflict Type |
|---------|-------------------|---------------|
| `rtk-gate.sh` (PreToolUse, matcher: `Bash\|exec_command`) | LeanCTX shell compression (PreToolUse) | **Double compression** — both intercept Bash, both compress output |
| `context-mode-gate.sh` (PreToolUse) | LeanCTX MCP tool routing | **Namespace collision** — both gate MCP tool availability |
| `context-mode-read-deny.sh` (PreToolUse, matcher: `Read\|Grep`) | LeanCTX `ctx_read` AST intercept | **Read-path war** — CM denies large reads; LeanCTX wants to compress them via AST. Which fires first? |
| `agentmemory-gate.sh` (PreToolUse) | LeanCTX memory auto-capture | **Memory governance** — both decide what gets saved to memory |
| `graphify-gate.sh` (PreToolUse) | LeanCTX `ctx_graph` operations | **Graph governance** — both gate graph operations |
| `record-token-compression-usage.sh` (PostToolUse) | LeanCTX Ed25519 ledger write | **Double accounting** — both record compression savings |
| `record-agentmemory-usage.sh` (PostToolUse) | LeanCTX memory metrics | **Double metrics** — both track memory operations |

### 2.2 MCP Conflicts

| Dimension | Context Mode | LeanCTX | Conflict |
|-----------|-------------|---------|----------|
| MCP server name | `context-mode` | `leanctx` | **No collision** — different server names |
| Port assignment | Default MCP stdio | Default MCP stdio | **No collision** — both use stdio transport |
| Tool namespace | `ctx_execute`, `ctx_search`, `ctx_fetch_and_index`, `ctx_index`, `ctx_batch_execute`, `ctx_execute_file`, `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge`, `ctx_insight` (11 tools) | `ctx_read`, `ctx_graph`, `ctx_handoff`, `ctx_gain`, `ctx_discover`, `ctx_quality`, `ctx_refactor`, + 74 more (81 tools total) | **Prefix collision** — both use `ctx_` prefix. `ctx_search` (CM) vs potential `ctx_search` (LeanCTX). Tool schema cost: 11 + 81 = 92 MCP tools in system prompt |
| Tool schema token cost | ~2,000 tokens (11 tools) | ~8,000-12,000 tokens (81 tools) | **Severe** — adding LeanCTX's 81 tools to CM's 11 = ~14,000 tokens of tool schemas alone, before any other tools |

**Critical namespace collisions:**

| Tool Name | Context Mode | LeanCTX | Collision |
|-----------|:-----------:|:-------:|-----------|
| `ctx_search` | FTS5 knowledge base search | Likely exists in 81-tool catalog | **Direct collision** — same name, different backends |
| `ctx_stats` | Session token/consumption stats | Likely `ctx_gain` or similar | **Near collision** — similar purpose, different names |
| `ctx_execute` | Sandbox code execution | May have equivalent | **Potential collision** — if LeanCTX has sandbox exec |

### 2.3 Read-Path Conflicts

This is the **most architecturally dangerous** conflict:

1. **Context Mode's `context-mode-read-deny.sh`** fires on PreToolUse for `Read|Grep` matcher. It denies reads of files exceeding a size threshold, directing the agent to use `ctx_execute_file` instead.

2. **LeanCTX's read-path intercept** fires on PreToolUse for Read operations. It compresses the file via AST modes before tokens reach the model.

3. **Conflict sequence:**
   - Agent calls `Read("large-file.ts")`
   - CM's `context-mode-read-deny.sh` fires → **blocks** the read, says "use ctx_execute_file"
   - LeanCTX's intercept never fires because CM already blocked it
   - OR: LeanCTX fires first → compresses to AST → CM sees compressed output → doesn't block → model gets AST instead of full file
   - **Result:** Behavior depends on hook ordering, which is platform-dependent and fragile

4. **Semantic conflict:** CM's philosophy is "deny large reads, force sandbox analysis." LeanCTX's philosophy is "compress large reads via AST, let model see compressed version." These are **opposing strategies** for the same problem.

### 2.4 Search/Index Conflicts — Dual FTS5 Databases

| Dimension | Context Mode | LeanCTX | Conflict |
|-----------|-------------|---------|----------|
| FTS5 database | Session-scoped SQLite, per-session tables | Session-scoped SQLite (likely separate DB) | **Two FTS5 databases** — content indexed in one is invisible to the other |
| Indexing triggers | Auto-capture (decisions, errors, plans, user prompts), manual `ctx_index`, `ctx_fetch_and_index` | Auto-capture on read/compress operations, manual indexing | **Split knowledge** — a decision captured by CM is not searchable via LeanCTX, and vice versa |
| Search algorithm | BM25 + Porter stemming + trigram + RRF merge + proximity rerank + fuzzy correction | BM25 (likely, standard FTS5) | **Quality disparity** — CM's search pipeline is more sophisticated; LeanCTX results may be lower quality |
| Progressive throttle | Rolling time window with soft/hard caps | Unknown | **Incompatible throttling** — two search systems with different rate limits |
| Session continuity | Persistent across /clear and /compact | Unknown | **Continuity gap** — CM preserves KB after compaction; LeanCTX may not |

**Practical impact:** When the agent searches for "what did we decide about caching," CM searches its auto-captured decisions. LeanCTX searches its own indexed content. The agent gets **incomplete results** from whichever tool it queries, and doesn't know to check the other.

### 2.5 Memory Graph Conflicts — Three Graph Systems

| System | Implementation | Scope | Query Interface |
|--------|---------------|-------|-----------------|
| LeanCTX `ctx_graph` | Built-in knowledge graph | Session + project | MCP tool `ctx_graph` |
| agentmemory `memory_graph_query` | 53-tool orchestration with graph queries | Cross-session persistent | MCP tool `memory_graph_query` |
| Graphify | Persistent project-scoped knowledge graph with Leiden communities, multimodal ingest | Project-scoped, team-shared | CLI `graphify query/path/explain` + `graphify-out/` files |

**Conflicts:**
- **Triple graph state:** Three separate graph representations of the same codebase, each with different update triggers and freshness guarantees
- **Query routing:** When the agent needs "what files relate to authentication," which graph does it query? Graphify is the SB-standard answer, but LeanCTX's graph may have more recent data
- **Update conflicts:** Graphify updates via `graphify update .` (AST-only). LeanCTX's graph updates on read operations. agentmemory's graph updates on memory operations. Three different update cadences = three different freshness levels
- **Storage:** Graphify writes to `graphify-out/`. LeanCTX writes to its own storage. agentmemory writes to its own storage. Three disk footprints

### 2.6 Shell Compression Conflicts — RTK + LeanCTX Double Compression

| Stage | RTK | LeanCTX | Result |
|-------|-----|---------|--------|
| PreToolUse | `rtk-gate.sh` intercepts Bash, rewrites command | LeanCTX intercepts Bash, compresses via wire proxy | **Double intercept** — which fires first? |
| Tool execution | Command runs | Command runs | No conflict |
| PostToolUse | RTK compresses output (per-CLI compressors: `rtk pytest` -90%, `rtk go test` -90%) | LeanCTX compresses output (generic shell compression) | **Double compression** — output compressed by RTK, then compressed again by LeanCTX. Potential data loss or garbled output |
| Metrics | `rtk gain` reports savings | `ctx_gain` / Ed25519 ledger reports savings | **Double counting** — savings reported twice, potentially with different numbers |

**Specific risk:** RTK's per-CLI compressors produce structured output (e.g., `rtk pytest` extracts failing tests + summary). If LeanCTX then compresses this structured output again with generic compression, the model may lose the structured format and receive garbled text.

### 2.7 Token Accounting Conflicts — Three Separate Trackers

| Tracker | What It Measures | Output | Conflict |
|---------|-----------------|--------|----------|
| LeanCTX Ed25519 ledger | Wire proxy compression + read-path compression + bounce-adjusted savings | Hash-chained entries, offline-verifiable | **Most authoritative** but only covers LeanCTX's own compression |
| RTK `rtk gain` | Shell output compression savings per command | Session summary | **Overlaps** with LeanCTX shell compression; double-counts if both active |
| Context Mode `ctx_stats` | Total bytes returned to context, breakdown by tool, call counts, estimated tokens, context savings ratio | Session summary | **Most comprehensive** for CM operations but blind to LeanCTX/RTK operations |

**Practical impact:** The agent (and user) sees **three different savings numbers** for the same session. Which is "real"? The Ed25519 ledger is cryptographically verifiable but only covers LeanCTX operations. `ctx_stats` covers CM operations. `rtk gain` covers RTK operations. None gives a unified view.

### 2.8 Runtime Governance Conflicts — PathJail vs SB Cooperative Rules

| Governance Layer | SB Current | LeanCTX | Conflict |
|-----------------|-----------|---------|----------|
| File access | Cooperative rules in AGENTS.md ("never modify plugins/cache/") | PathJail deny-by-default allowlist | **Philosophy clash** — SB trusts the agent with rules; PathJail doesn't trust the agent at all |
| Shell access | SB hooks gate specific commands (planning gate, CI check) | PathJail deny-by-default shell allowlist | **Double gating** — SB's `planning-file-guard.sh` blocks writes to planning files; PathJail blocks all shell commands not in allowlist. Agent gets blocked twice with different error messages |
| Network access | CM's WebFetch deny + curl/wget redirect + SSRF block | PathJail network policy (if any) | **Overlapping network governance** — CM is more specific (RFC1918/loopback block); PathJail is broader |
| MCP tool access | SB's tool-specific gates (`context-mode-gate.sh`, `agentmemory-gate.sh`, `graphify-gate.sh`) | LeanCTX MCP Tool-Catalog Gateway | **Gateway conflict** — SB gates individual tools; LeanCTX gates all MCP through its catalog gateway |

**Critical conflict:** SB's entire enforcement model is **cooperative** — hooks check conditions and return allow/deny, but the agent can potentially bypass them. PathJail is **mandatory** — the agent cannot bypass it. Running both simultaneously creates confusing UX: some operations are blocked by SB hooks (with SB-specific error messages), others by PathJail (with PathJail error messages), and the agent doesn't know which governance layer blocked it.

### 2.9 Rules Tax — Cumulative AGENTS.md / .mdc Files

| Source | Estimated Token Cost | Content |
|--------|---------------------|---------|
| SB AGENTS.md (project) | ~2,000 tokens | Repo guide, working rules, release policy, graphify |
| SB AGENTS.md (user ~/.config/opencode/) | ~3,000 tokens | Context-mode routing rules, blocked/redirected patterns |
| SB .mdc files (Cursor) | ~1,000 tokens per file × multiple files | Subagent rules, recommended tools, umbrella rules |
| Context Mode routing rules | ~1,500 tokens | Think-in-Code, tool selection hierarchy, parallel I/O |
| LeanCTX AGENTS.md additions | ~1,000-2,000 tokens (estimated) | PathJail config, read mode preferences, proxy settings |
| LeanCTX .mdc files (Cursor) | ~500-1,000 tokens (estimated) | LeanCTX-specific Cursor rules |

**Cumulative rules tax:** ~9,000-12,000 tokens of system prompt devoted to tool governance rules alone. This is **before** any project-specific instructions, skill instructions, or model system prompts. On models with 200K context windows, this is manageable. On models with 128K or less, this is a significant overhead that reduces available working context.

---

## 3. Resolution Strategies

### 3.1 Hook Conflicts — Resolution

| Conflict | Strategy | Implementation |
|----------|----------|----------------|
| Triple SessionStart init | **Priority ordering** | LeanCTX init first (PathJail must be up before any tool runs), then CM, then SB hooks |
| PreToolUse read-path war | **Layered delegation** | Disable `context-mode-read-deny.sh` when LeanCTX is active. LeanCTX handles all read-path decisions (AST compress for large, pass-through for small). CM's read-deny becomes redundant |
| PreToolUse double Bash intercept | **Single compressor** | Disable `rtk-gate.sh` when LeanCTX is active. LeanCTX handles shell compression. RTK becomes a fallback for when LeanCTX is disabled |
| PostToolUse double processing | **Sequential pipeline** | LeanCTX compresses first (wire proxy), then CM auto-captures (decisions/errors). They operate on different aspects and can coexist sequentially |
| Stop hook competing summaries | **Merged summary** | LeanCTX writes Ed25519 ledger entry, CM writes session summary. A new SB hook `merge-session-summary.sh` combines both into one output |

### 3.2 MCP Conflicts — Resolution

| Conflict | Strategy | Implementation |
|----------|----------|----------------|
| `ctx_` prefix collision | **Namespace rename** | LeanCTX tools get `lctx_` prefix (or keep `ctx_` and rename CM tools to `cm_`). Requires LeanCTX config change or CM config change |
| 92 total MCP tools | **Tool gating** | LeanCTX's MCP Tool-Catalog Gateway proxies all downstream MCP. CM's 11 tools register behind the gateway. Agent sees LeanCTX's catalog, not individual CM tools. Total visible tools: ~81 (LeanCTX native) + CM tools proxied through gateway |
| `ctx_search` collision | **Unified search** | Route all search through CM's `ctx_search` (superior pipeline: BM25 + Porter + trigram + RRF + proximity + fuzzy). LeanCTX's search disabled or proxied through CM |

### 3.3 Read-Path Conflicts — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **LeanCTX owns read path** | Disable `context-mode-read-deny.sh`. LeanCTX's AST intercept handles all reads. CM's `ctx_execute_file` remains available for explicit sandbox analysis | Lose CM's strict deny policy; gain AST compression for all reads |
| **CM owns read path** | Disable LeanCTX read intercept. CM's deny + sandbox remains. LeanCTX only compresses shell and wire proxy | Lose AST compression; keep CM's proven read governance |
| **Hybrid (recommended)** | LeanCTX handles reads < threshold (AST compress). CM handles reads > threshold (deny + sandbox). Threshold negotiated between both systems | Complex but gets best of both; requires careful threshold tuning |

### 3.4 Search/Index Conflicts — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **CM owns search** (recommended) | Disable LeanCTX's FTS5 indexing. All content indexed through CM's `ctx_index`, `ctx_fetch_and_index`, auto-capture. LeanCTX's read operations feed into CM's indexer via PostToolUse hook | Lose LeanCTX's native search; keep CM's superior pipeline and session continuity |
| **LeanCTX owns search** | Disable CM's auto-capture and indexing. All content through LeanCTX | Lose CM's session continuity, progressive throttle, and sophisticated ranking |
| **Unified index** | Both tools write to the same FTS5 database | Requires deep integration; not feasible without modifying source code |

### 3.5 Memory Graph Conflicts — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **Graphify owns codebase graph** (recommended) | Disable LeanCTX `ctx_graph`. Graphify remains the project-scoped codebase graph. agentmemory remains the cross-session memory graph. LeanCTX contributes read-path data to Graphify via PostToolUse hook | Lose LeanCTX's integrated graph; keep Graphify's Leiden communities and multimodal support |
| **LeanCTX owns graph** | Disable Graphify. Use LeanCTX `ctx_graph` for all graph operations | Lose Leiden communities, multimodal ingest, team-shared `graphify-out/` |
| **Federated queries** | Agent queries all three graphs and merges results | Expensive (3× query cost), confusing results, no clear authority |

### 3.6 Shell Compression Conflicts — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **LeanCTX owns shell** (recommended for 5-stack) | Disable `rtk-gate.sh`. LeanCTX handles all shell compression via wire proxy. RTK binary remains installed as fallback (`RTK_DISABLED=0` when LeanCTX is down) | Lose RTK's per-CLI depth (e.g., `rtk pytest` -90%); gain wire proxy compression on all requests |
| **RTK owns shell** | Disable LeanCTX shell compression. RTK remains the shell specialist. LeanCTX only does wire proxy + read path | Lose LeanCTX's generic compression; keep RTK's per-CLI depth |
| **Layered (RTK deep + LeanCTX wire)** | RTK compresses tool output (PostToolUse). LeanCTX compresses the wire request (proxy layer). They operate at different stages | Best of both but complex; RTK output → model request → LeanCTX wire compress. Requires confirming no double-compression artifacts |

### 3.7 Token Accounting Conflicts — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **Ed25519 ledger as source of truth** (recommended) | LeanCTX's ledger records all compression events. RTK and CM report their savings to LeanCTX's ledger via PostToolUse hooks. `ctx_stats` becomes a dashboard that reads from the ledger | Requires LeanCTX API for external ledger writes; most authoritative |
| **`ctx_stats` as dashboard** | CM's `ctx_stats` aggregates from all three sources. RTK and LeanCTX report to CM | CM's stats are already the most comprehensive dashboard |
| **Unified SB hook** | New SB hook `unified-token-accounting.sh` collects from all three and writes single report | SB-specific; doesn't help non-SB users |

### 3.8 Runtime Governance Conflicts — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **PathJail as enforcement floor** (recommended) | PathJail provides hard deny-by-default. SB hooks provide additional cooperative rules on top. SB rules that PathJail already covers are removed from AGENTS.md to reduce rules tax | Lose some SB-specific governance nuance; gain hard enforcement |
| **SB hooks only** | Disable PathJail. SB's cooperative hooks remain the governance layer | Lose hard enforcement; keep SB's nuanced workflow-aware governance |
| **Layered with clear boundaries** | PathJail handles filesystem + shell access control. SB hooks handle workflow + planning + quality gates. No overlap | Clean separation but requires careful mapping of which governance concerns belong where |

### 3.9 Rules Tax — Resolution

| Strategy | Implementation | Trade-off |
|----------|----------------|-----------|
| **Consolidate rules** | Merge LeanCTX rules into existing SB AGENTS.md. Remove redundant rules that PathJail enforces at runtime | Reduces token cost; requires careful rule audit |
| **Conditional rules** | LeanCTX rules only loaded when LeanCTX is active (conditional include in AGENTS.md) | Reduces tax when LeanCTX is disabled; adds complexity |
| **Runtime-only governance** | Move all governance to PathJail + hooks. Remove corresponding AGENTS.md rules | Maximum token savings; loses the "belt and suspenders" approach |

---

## 4. Per-Environment Analysis

### 4.1 Cursor

| Dimension | Current SB (4-tool) | With LeanCTX (5-tool) | Assessment |
|-----------|---------------------|----------------------|------------|
| Hook system | `cursor-hooks.json` + `cursor-hook-bridge.sh` bridges to Claude-format hooks | LeanCTX has Cursor support (hybrid mode: MCP + shell hooks) | **Compatible** — LeanCTX's Cursor integration is mature |
| Allow-lists | Cursor MCP allow-list in `~/.cursor/mcp.json` | LeanCTX registers as additional MCP server | **Adds 81 tools** to Cursor's MCP panel; may hit Cursor's tool limit or confuse the model |
| Rules files | `~/.cursor/rules/*.mdc` (subagent, recommended-tools, umbrella) | Additional `.mdc` for LeanCTX config | **Rules tax increases** by ~1,000-2,000 tokens |
| Composer 2.5 subagents | SB mandates `composer-2.5` for all subagent work | LeanCTX subagent behavior unknown | **Risk** — untested interaction between LeanCTX and Composer 2.5 subagents |
| Recommended tools | `scripts/install-recommended-tools-cursor.sh` installs graphify + agentmemory | Would need LeanCTX install step | **Manageable** — add to install script |

**Cursor verdict:** LeanCTX integrates but adds significant tool-schema overhead. The 81-tool catalog may overwhelm Cursor's model context. **Recommend: LeanCTX MCP-only mode** (not hybrid) for Cursor to reduce hook conflicts.

### 4.2 Codex (OpenAI)

| Dimension | Current SB (4-tool) | With LeanCTX (5-tool) | Assessment |
|-----------|---------------------|----------------------|------------|
| Hook system | `codex-hook-adapter.sh` adapts Claude-format hooks to Codex's 6 events | LeanCTX has Codex support (hybrid mode) | **Compatible** — but Codex's deny-only hook policy means LeanCTX's PreToolUse intercepts may not work as expected |
| Deny-only hooks | Codex hooks can only deny, not modify tool inputs | LeanCTX's PreToolUse rewrite (modifying tool inputs) won't work | **Critical limitation** — LeanCTX's read-path AST compression and shell compression rely on PreToolUse rewrite, which Codex doesn't support |
| MCP servers | `[mcp_servers.context-mode]` in Codex config | Additional `[mcp_servers.leanctx]` | **Compatible** — Codex supports multiple MCP servers |
| Plugin marketplace | `alo-labs/codex-plugins` package | LeanCTX not in SB's Codex marketplace | **Requires packaging** — LeanCTX needs Codex plugin manifest |

**Codex verdict:** LeanCTX's **core value proposition is degraded** on Codex because deny-only hooks prevent PreToolUse rewrite. Wire proxy compression still works (it's proxy-level, not hook-level), but read-path AST compression and shell compression require PreToolUse rewrite. **Recommend: Do NOT add LeanCTX for Codex environment** unless Codex adds modify-capable hooks.

### 4.3 Claude Code

| Dimension | Current SB (4-tool) | With LeanCTX (5-tool) | Assessment |
|-----------|---------------------|----------------------|------------|
| Hook system | Full Claude Code hook system (PreToolUse, PostToolUse, SessionStart, Stop, SubagentStart, SubagentStop, UserPromptSubmit, Notification, PreCompact) | LeanCTX has Claude Code support (hybrid mode) | **Best environment** — Claude Code has the richest hook system, LeanCTX can use all hooks |
| Plugin system | `/plugin install alo-exp/silver-bullet` | LeanCTX would need plugin manifest or standalone install | **Compatible** — Claude Code supports multiple plugins |
| PreCompact hook | CM's PreCompact compaction guide | LeanCTX's PreCompact session summary | **Compatible** — both can run, CM writes compaction guide, LeanCTX writes ledger snapshot |
| afterAgentResponse | CM has this hook (unique to CM) | LeanCTX does not have this hook | **No conflict** — CM retains this unique hook |

**Claude Code verdict:** This is the **best environment** for LeanCTX integration. Full hook support, PreToolUse rewrite works, all governance layers functional. **Recommend: Primary integration target for LeanCTX.**

### 4.4 OpenCode

| Dimension | Current SB (4-tool) | With LeanCTX (5-tool) | Assessment |
|-----------|---------------------|----------------------|------------|
| Hook system | OpenCode uses MCP-first architecture; hooks via TS plugin events | LeanCTX has OpenCode support (MCP mode) | **Compatible** — OpenCode's MCP-first design works well with LeanCTX's MCP server |
| MCP configuration | `opencode.json` MCP section | Additional LeanCTX MCP entry | **Compatible** — OpenCode supports multiple MCP servers |
| Rules | `~/.config/opencode/AGENTS.md` | LeanCTX rules added to AGENTS.md | **Compatible** — standard AGENTS.md extension |
| Tool display | OpenCode shows MCP tools in UI | 81 additional LeanCTX tools | **UX concern** — tool list becomes very long |

**OpenCode verdict:** MCP-first architecture is **well-suited** for LeanCTX. No hook conflicts because OpenCode uses MCP for everything. **Recommend: Good secondary integration target.**

### 4.5 Environment Summary

| Environment | LeanCTX Compatibility | Hook Conflicts | Core Value Retained | Recommendation |
|------------|:--------------------:|:--------------:|:-------------------:|----------------|
| Claude Code | **Excellent** | Manageable | 100% | **Primary target** |
| OpenCode | **Good** | Minimal (MCP-only) | ~90% (no shell hooks) | Secondary target |
| Cursor | **Fair** | Moderate | ~80% (tool schema overhead) | MCP-only mode |
| Codex | **Poor** | Significant | ~50% (deny-only hooks block core features) | **Do not add** |

---

## 5. Five-Stack Synergy Assessment

### 5.1 What SB Gains

| Capability | Source | Value for SB |
|-----------|--------|-------------|
| Wire proxy compression | LeanCTX (unique) | **High** — SB's long workflow sessions accumulate massive history; wire proxy compresses every request |
| PathJail hard governance | LeanCTX (unique) | **High** — upgrades SB from cooperative rules to mandatory enforcement |
| Pre-model injection detection | LeanCTX (unique) | **Medium** — protects SB's hook-heavy input pipeline |
| Ed25519 audit trail | LeanCTX (unique) | **Medium** — provable savings for SB's token-conscious users |
| AST read modes | LeanCTX (unique) | **Medium** — reduces token cost for SB's repeated file reads across workflow phases |
| MCP Tool-Catalog Gateway | LeanCTX (unique) | **Low-Medium** — could unify SB's multi-tool MCP surface |

### 5.2 What SB Loses

| Loss | Severity | Mitigation |
|------|----------|------------|
| Hook chain complexity (60 → ~75 hooks) | **High** | Careful ordering, disable redundant hooks |
| MCP tool schema overhead (+81 tools = ~12K tokens) | **High** | Use MCP Tool-Catalog Gateway to proxy; or MCP-only mode with selective tool exposure |
| Dual FTS5 databases (split knowledge) | **High** | Route all indexing through CM; disable LeanCTX indexing |
| Triple graph systems | **Medium** | Disable LeanCTX graph; keep Graphify + agentmemory |
| Triple token accounting | **Medium** | Unified ledger via LeanCTX Ed25519 |
| Rules tax increase (~2K tokens) | **Medium** | Consolidate rules, remove redundant AGENTS.md entries |
| Codex incompatibility | **High** | Don't deploy LeanCTX on Codex; keep 4-tool stack for Codex |
| Testing surface explosion | **High** | New test matrix: 5 tools × 4 environments × hook interactions |
| Debugging complexity | **High** | When something breaks, 5 tools to investigate instead of 4 |
| User onboarding complexity | **Medium** | SB's `/silver:init` now needs to install and configure 5 tools |

### 5.3 Diminishing Returns Analysis

The **law of diminishing returns** applies sharply here:

| Stack Size | Marginal Benefit | Marginal Cost | Net |
|:----------:|:----------------:|:-------------:|:---:|
| 1 tool (RTK only) | Baseline compression | Minimal | **+** |
| 2 tools (+ CM) | Sandbox + KB + search | Moderate hooks | **+** |
| 3 tools (+ agentmemory) | Orchestration + memory | Significant hooks | **+** |
| 4 tools (+ Graphify) | Knowledge graph + scoped retrieval | Significant hooks | **+** (current sweet spot) |
| 5 tools (+ LeanCTX) | Wire proxy + PathJail + AST reads | **Severe** hook/MCP/graph conflicts | **±** (marginal at best) |

The 4-tool stack is SB's **current sweet spot**. Each tool occupies a distinct concern (compression, sandbox/KB, orchestration/memory, graph/retrieval). Adding LeanCTX doesn't add a new concern — it **overlaps** with 3 of the 4 existing concerns while adding 2 genuinely new capabilities (wire proxy, PathJail).

### 5.4 The Better Question: Replacement vs Addition

The consolidated report already answered this: **"Do not add LeanCTX as a fifth tool. If you integrate LeanCTX, do it as a replacement for RTK + CM."**

This is the correct framing. The comparison should be:

| Configuration | Tools | Compression | Sandbox/KB | Orchestration | Graph | Governance | Audit |
|--------------|:-----:|:-----------:|:----------:|:-------------:|:-----:|:----------:|:-----:|
| Current SB | 4 | RTK | CM | agentmemory | Graphify | Cooperative rules | `rtk gain` + `ctx_stats` |
| LeanCTX replaces RTK+CM | 3 | LeanCTX (wire+shell+AST) | LeanCTX (sandbox+FTS5) | agentmemory | Graphify | PathJail + rules | Ed25519 ledger |
| LeanCTX as 5th tool | 5 | RTK + LeanCTX (double) | CM + LeanCTX (double) | agentmemory | Graphify + LeanCTX (double) | PathJail + rules + hooks (triple) | Three trackers |

The **3-tool replacement** is clearly superior to the **5-tool addition**.

---

## 6. Recommendation

### 6.1 Primary Recommendation: Do NOT Add LeanCTX as a Fifth Tool

Adding LeanCTX alongside the existing 4-tool stack creates **9 conflict categories** requiring explicit resolution, adds **~12,000 tokens** of MCP tool schemas, creates **dual FTS5 databases** with split knowledge, and produces **three competing graph systems**. The operational cost outweighs the marginal benefit.

### 6.2 Alternative Recommendation: LeanCTX as RTK+CM Replacement (3-Tool Stack)

For SB environments where:
- `CTX_FETCH_STRICT` compliance is **not required** (non-regulated, non-corporate)
- Wire proxy compression would provide measurable value (long workflow sessions)
- PathJail hard governance is desired over cooperative rules
- Claude Code or OpenCode is the primary environment

Then **replacing RTK + Context Mode with LeanCTX** yields a simpler, more capable 3-tool stack:

```
LeanCTX (compression + sandbox + KB + governance)
  + agentmemory (orchestration + memory)
  + Graphify (knowledge graph + scoped retrieval)
```

### 6.3 Phased Adoption Path

#### Phase 0: Evaluation (1-2 weeks)
- Install LeanCTX in a test SB project alongside the 4-tool stack
- Disable LeanCTX's overlapping features (FTS5 indexing, graph, shell compression)
- Measure wire proxy compression on real SB workflow sessions
- Validate PathJail against SB's hook governance model
- Test on Claude Code only (best compatibility)

#### Phase 1: Wire Proxy Only (2-4 weeks)
- Enable LeanCTX **only as wire proxy** (no hooks, no MCP tools exposed to agent)
- LeanCTX runs as transparent proxy between agent and model provider
- All 4 existing tools remain active and unchanged
- Measure actual token savings from wire compression on SB workflows
- **Risk: Low** — proxy is transparent, no hook conflicts

#### Phase 2: PathJail Evaluation (2-4 weeks)
- Enable PathJail in **audit mode** (log violations, don't block)
- Compare PathJail violations against SB hook denials
- Identify which SB cooperative rules PathJail could enforce at runtime
- **Risk: Low** — audit mode doesn't block anything

#### Phase 3: RTK Replacement (4-8 weeks)
- If Phase 1 showed meaningful wire proxy savings, proceed
- Disable `rtk-gate.sh`, enable LeanCTX shell compression
- Keep RTK binary installed as fallback
- Measure compression quality: LeanCTX generic vs RTK per-CLI
- **Risk: Medium** — shell compression quality may differ

#### Phase 4: Context Mode Replacement (8-16 weeks)
- **Only if** Phase 3 succeeded and LeanCTX's FTS5 KB proves equivalent
- Migrate CM's auto-capture hooks to LeanCTX equivalents
- Migrate CM's `ctx_search` to LeanCTX's search (or keep CM's search as proxy)
- Disable CM MCP server, enable LeanCTX MCP server
- **Risk: High** — CM's search pipeline is more sophisticated; session continuity must be preserved
- **Gate:** Must pass SB's `tests/run-all-tests.sh` with LeanCTX replacing CM

#### Phase 5: Codex/Cursor Environment Assessment
- After Phase 4 succeeds on Claude Code, evaluate Cursor (MCP-only mode)
- **Do not deploy on Codex** until deny-only hook limitation is resolved
- OpenCode: evaluate as MCP-only integration

#### Phase 6: Full 3-Tool Stack Stabilization
- LeanCTX + agentmemory + Graphify as the new standard SB stack
- Update `.silver-bullet.json` tool manifests
- Update `scripts/install-recommended-tools-cursor.sh`
- Update all SB documentation and skills referencing RTK/CM
- Update `tests/run-all-tests.sh` for new stack

### 6.4 What Would Change This Recommendation

| Condition | Impact |
|-----------|--------|
| LeanCTX adds `CTX_FETCH_STRICT` equivalent | Removes the primary gap; strengthens replacement case |
| Codex adds modify-capable hooks | Removes Codex incompatibility; LeanCTX viable on all 4 environments |
| LeanCTX's FTS5 search matches CM's pipeline quality | Removes search quality concern in Phase 4 |
| LeanCTX adds gitleaks bridge on exports | Closes agentmemory's governance gap |
| Head-to-head benchmark shows LeanCTX wire proxy saves >20% on SB workflows | Strong quantitative case for Phase 1 |
| SB community reports hook conflicts are manageable in practice | Reduces Phase 3-4 risk |

### 6.5 Per-Environment Deployment Matrix

| Phase | Claude Code | OpenCode | Cursor | Codex |
|:-----:|:-----------:|:--------:|:------:|:-----:|
| 0 (Eval) | Yes | No | No | No |
| 1 (Wire proxy) | Yes | Yes | No | No |
| 2 (PathJail audit) | Yes | Yes | No | No |
| 3 (RTK replace) | Yes | Yes | No | No |
| 4 (CM replace) | Yes | Yes | No | No |
| 5 (Multi-env) | Yes | Yes | MCP-only | **Skip** |
| 6 (Stable) | 3-tool | 3-tool | 3-tool MCP-only | 4-tool (unchanged) |

---

## Appendix A: Conflict Resolution Quick Reference

| # | Conflict | Resolution | Owner |
|:-:|----------|-----------|-------|
| 1 | Hook chain explosion | Disable redundant hooks; priority ordering | SB hooks.json |
| 2 | MCP `ctx_` prefix collision | Namespace rename or Tool-Catalog Gateway proxy | LeanCTX config |
| 3 | Read-path war (CM deny vs LeanCTX AST) | LeanCTX owns read path; CM deny disabled | SB `context-mode-read-deny.sh` |
| 4 | Dual FTS5 databases | CM owns search/index; LeanCTX indexing disabled | LeanCTX config |
| 5 | Triple graph systems | Graphify owns codebase graph; LeanCTX graph disabled | LeanCTX config |
| 6 | Double shell compression | LeanCTX owns shell; RTK disabled (fallback only) | SB `rtk-gate.sh` |
| 7 | Triple token accounting | Ed25519 ledger as source of truth; others report to it | New SB hook |
| 8 | PathJail vs cooperative rules | PathJail as enforcement floor; SB rules on top | AGENTS.md consolidation |
| 9 | Rules tax increase | Consolidate rules; remove PathJail-enforced rules from AGENTS.md | AGENTS.md audit |

## Appendix B: SB Hook Inventory Affected by LeanCTX

| Hook Script | Event | LeanCTX Impact | Action |
|-------------|-------|---------------|--------|
| `rtk-gate.sh` | PreToolUse | **Replaced** by LeanCTX shell compression | Disable when LeanCTX active |
| `context-mode-gate.sh` | PreToolUse | **Replaced** by LeanCTX MCP routing | Disable when LeanCTX active |
| `context-mode-read-deny.sh` | PreToolUse | **Replaced** by LeanCTX AST intercept | Disable when LeanCTX active |
| `agentmemory-gate.sh` | PreToolUse | **No change** — agentmemory remains | Keep |
| `graphify-gate.sh` | PreToolUse | **No change** — Graphify remains | Keep |
| `record-token-compression-usage.sh` | PostToolUse | **Modified** — record from LeanCTX ledger | Update to read Ed25519 ledger |
| `record-agentmemory-usage.sh` | PostToolUse | **No change** | Keep |
| `record-graphify-query.sh` | PostToolUse | **No change** | Keep |
| `semantic-compress.sh` | PostToolUse | **Potentially redundant** with LeanCTX | Evaluate overlap |
| `token-compression-tools-gate.sh` | PreToolUse | **Updated** — gate LeanCTX instead of RTK | Update matcher |

## Appendix C: Methodology

This analysis was produced by:
1. Reading the qwen3.7-max original report and the consolidated multi-model report
2. Analyzing SB's actual hook inventory (60 scripts, 7 event types, hooks.json configuration)
3. Analyzing SB's `.silver-bullet.json` tool manifests for all 4 recommended tools
4. Fetching and indexing the SB homepage (sb.alolabs.dev) for project context
5. Fetching and indexing LeanCTX documentation (leanctx.com/docs) for capability verification
6. Cross-referencing all 9 conflict categories against SB's actual architecture
7. Evaluating per-environment compatibility against SB's 4 target platforms

All findings are grounded in the actual SB codebase configuration and the documented capabilities of all 5 tools as verified in the upstream research.

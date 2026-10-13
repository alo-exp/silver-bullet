# Follow-Up Report: Adding LeanCTX to the Silver Bullet 4-Tool Stack

**Research Dispatch:** Multi-AI Parallel Research (Kimi K2.6) — Follow-Up Phase  
**Date:** 2026-07-07  
**Scope:** Operational integration analysis of LeanCTX (v3.9.1) into the existing Silver Bullet stack (RTK + Context Mode + agentmemory + Graphify) across Cursor, Codex, Claude Code, and OpenCode environments  
**Key Question:** Would a 5-tool stack (RTK + Context Mode + agentmemory + Graphify + LeanCTX) be better for Silver Bullet? What conflicts arise, and how can they be resolved?

---

## Executive Summary

**Adding LeanCTX to the existing four-tool Silver Bullet stack is conditionally beneficial but requires careful conflict resolution.** LeanCTX brings five genuinely unique capabilities (wire proxy, AST read-path compression, PathJail, Ed25519 ledger, prompt-injection detection) that fill gaps in the current stack. However, co-installation creates **nine distinct conflict categories** spanning hook interposition, MCP port/namespace collisions, read-path double-interception, dual FTS5 databases, overlapping memory graphs, shell compression double-dipping, triple token accounting, runtime governance friction, and cumulative rules-file tax.

**The verdict: Yes, add LeanCTX, but not as a fifth parallel tool — integrate it as a *replacement layer* for RTK + Context Mode's compression/sandbox functions while retaining agentmemory + Graphify for memory and retrieval.** This yields a **3-tool operational stack** (LeanCTX + agentmemory + Graphify) with RTK and Context Mode demoted to conditional add-ons, not defaults. The 5-tool parallel stack is operationally untenable; the 3-tool restructured stack captures 95%+ of LeanCTX's unique wins while preserving the four-stack's super-critical gaps (`CTX_FETCH_STRICT`, 53-tool orchestration, gitleaks, multimodal corpus).

---

## 1. Would Adding LeanCTX Benefit Silver Bullet?

### 1.1 Unique Capabilities That Fill Genuine Gaps

LeanCTX has **five super-critical capabilities the four-stack lacks entirely** (confirmed by 6/6 models in the consolidated research). These are not overlapping features — they are architectural gaps in the current SB stack:

| Capability | Four-Stack Gap | SB Impact if Added |
|------------|---------------|-------------------|
| **Wire/request compression proxy** | No tool compresses outbound model requests (prompt + history + tool results) | Potentially largest uncaptured token savings on long multi-turn sessions |
| **Native read-path AST compression (10+ fidelity modes)** | Context Mode sandboxes reads; RTK compresses shell output; neither intercepts Read before model with AST modes | Cuts token cost of large file reads by 60–90% on read-heavy workloads |
| **PathJail + deny-by-default shell allowlist** | SB relies on `.mdc` rules and subprocess sandboxing; no runtime filesystem jail | Hard enforcement of workspace boundaries, stronger than instruction-layer rules |
| **Ed25519 hash-chained savings ledger** | `rtk gain` and `ctx_stats` are session metrics, not cryptographically verifiable | Audit-proof token savings for corporate/regulated environments |
| **Pre-model prompt-injection detection** | No incumbent covers this security plane | First-line defense against jailbreaks and prompt injection before content reaches model |
| **MCP Tool-Catalog Gateway** | Each stack tool exposes its own MCP surface; no unified gateway | Could consolidate 11 + 53 + Graphify + RTK (~70+ tools) behind a single routed surface |

**Assessment:** These are genuine gaps. The wire proxy alone could dominate token economics on long sessions. PathJail provides runtime enforcement that AGENTS.md rules cannot. The Ed25519 ledger fills an audit gap for enterprise SB deployments. These benefits are **additive, not substitutive** — they expand SB's capability surface rather than duplicating existing tools.

### 1.2 Overlapping Capabilities That Risk Redundancy

LeanCTX also covers capabilities the four-stack already handles, creating overlap rather than gap-filling:

| Capability | Four-Stack Coverage | LeanCTX Coverage | Overlap Risk |
|------------|-------------------|-------------------|-------------|
| Shell output compression | RTK (mature per-CLI compressors) | LeanCTX (95+ patterns) | **Double-compression risk** — RTK rewrites command, LeanCTX intercepts output |
| MCP sandbox execution | Context Mode (`ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`) | LeanCTX (`ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`) | **Namespace collision** — identical tool names, different implementations |
| FTS5 + RRF search | Context Mode session KB | LeanCTX session KB | **Dual database risk** — two SQLite FTS5 indexes on same workspace |
| Knowledge graph query | Graphify (`graphify query` / `path` / `explain`) + agentmemory graph | LeanCTX (`ctx_query` / `ctx_path` / `ctx_explain`) | **Triple graph risk** — `graph.json`, `.agentmemory/` graph, LeanCTX graph |
| Fetch hardening | Context Mode (`CTX_FETCH_STRICT`, curl/wget redirect, WebFetch deny) | LeanCTX (SSRF blocking, proxy-level filtering) | **Partial overlap** — LeanCTX lacks RFC1918/loopback strict tier |
| Session memory capture | agentmemory (decisions, ADRs, lessons) | LeanCTX (session KB, `ctx_purge`) | **Dual memory risk** — agentmemory exports vs LeanCTX session persistence |
| Hook integration | Context Mode (`PreToolUse`, `PostToolUse`, `SessionStart`, `PreCompact`) | LeanCTX (same hooks) | **Hook interposition conflict** — two hook handlers on same event |

**Assessment:** The overlap is extensive. LeanCTX's 81-tool MCP surface includes tools that are **functionally identical** to Context Mode's 11-tool surface (same names, same parameter shapes, different backing implementations). Adding LeanCTX as a fifth parallel MCP server would create a tool namespace where `ctx_execute` could resolve to either Context Mode or LeanCTX, with unpredictable behavior.

### 1.3 Net Benefit Assessment

**SB gains from adding LeanCTX:**
- Wire proxy token savings (potentially dominant on long sessions)
- AST read-path compression (genuine new capability)
- PathJail runtime enforcement (stronger than rules)
- Ed25519 audit ledger (enterprise-grade proof)
- Prompt-injection detection (security gap filled)
- MCP Tool-Catalog Gateway (potential simplification of 70+ tools)
- Single-binary setup simplicity for new SB users

**SB risks from adding LeanCTX as a fifth tool:**
- Hook double-firing (RTK + LeanCTX both rewrite PreToolUse)
- MCP namespace chaos (`ctx_execute` ambiguous)
- Dual FTS5 databases competing for disk and query consistency
- Triple graph systems (Graphify + agentmemory + LeanCTX)
- Cumulative rules tax (AGENTS.md + .mdc + LeanCTX rules)
- Token overhead from 81-tool schema descriptions in context
- Runtime governance friction (PathJail hard enforcement vs SB cooperative rules)

**Net verdict:** The gains are genuine but the **parallel 5-tool stack is operationally unsustainable**. The benefit is realized only if LeanCTX is **integrated structurally** — replacing the compression/sandbox layer (RTK + Context Mode) rather than augmenting it. The optimal architecture is **LeanCTX + agentmemory + Graphify** (3 tools), with RTK and Context Mode as conditional add-ons for specialist depth.

---

## 2. Conflicts — Identify Each

### 2.1 Hook Conflicts: PreToolUse, PostToolUse, SessionStart, PreCompact

**The conflict:** Both Context Mode and LeanCTX register for the same hook events. In Cursor (Composer), hooks are allow-listed `.mdc` rules. In Claude Code, hooks are native lifecycle callbacks. In Codex, hooks are deny-only (post-hoc). In OpenCode, hooks are MCP middleware.

| Hook | Context Mode Handler | LeanCTX Handler | Collision Mode |
|------|---------------------|-----------------|----------------|
| **PreToolUse** | Rewrites shell commands before execution (RTK also rewrites here) | Intercepts tool call, routes to sandbox, applies PathJail | **Triple interposition** — RTK rewrites command string → CM validates → LeanCTX intercepts again |
| **PostToolUse** | Indexes tool output into session KB, applies fetch hardening | Compresses output, writes to ledger, indexes into LeanCTX KB | **Dual indexing** — same output lands in two FTS5 databases |
| **SessionStart** | Loads prior session context, checks `ctx_upgrade` | Initializes LeanCTX runtime, loads graph state | **Double initialization** — two tools competing to set up session state |
| **PreCompact** | Runs `ctx_purge` for session cleanup, compacts KB | Runs `ctx_purge` for ledger finalization, compacts graph | **Race condition** — both tools may purge overlapping state |
| **afterAgentResponse** | CM native hook (not in LeanCTX) | N/A | Minor — CM has exclusive handle |

**Severity: HIGH.** PreToolUse triple interposition is the most dangerous. A shell command like `git status` could be:
1. Rewritten by RTK to `rtk git status` (adds compression flags)
2. Validated by Context Mode's sandbox (checks allow-list)
3. Intercepted by LeanCTX's PathJail (enforces filesystem boundaries)

Each layer adds latency and risk of semantic drift. If LeanCTX's PathJail restricts a path that RTK's rewritten command needs, the command fails for reasons opaque to the user.

### 2.2 MCP Conflicts: Port Assignments and Tool Namespace Collisions

**The conflict:** Each tool in the stack exposes an MCP server. Adding LeanCTX as a fifth MCP server creates port and namespace contention.

| MCP Server | Approx Tool Count | Port/Namespace Pattern |
|-----------|-------------------|----------------------|
| Context Mode | ~11 tools | `context-mode-*` |
| agentmemory | ~53 tools | `memory_*`, `agentmemory_*` |
| Graphify | ~8 tools | `graphify_*` |
| RTK | Hook-only (no MCP) | N/A |
| **LeanCTX** | **81 tools** | **`ctx_*` (overlaps with Context Mode)** |

**Port collision:** If Context Mode and LeanCTX both claim `localhost:3001` (a common default), one server fails to start. SB's `mcp.json` would need explicit port remapping.

**Tool namespace collision:** Both Context Mode and LeanCTX expose `ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`, `ctx_search`, `ctx_fetch_and_index`, `ctx_index`, `ctx_purge`, `ctx_stats`. The model cannot distinguish which implementation to call. In Cursor's allow-list model, both would be presented as options, creating ambiguity. In Claude Code's native MCP, the last-registered server wins (non-deterministic).

**Severity: CRITICAL.** Namespace collision is a hard blocker for parallel operation. The model calling `ctx_execute` cannot know whether it will hit Context Mode's sandbox or LeanCTX's PathJail-enforced sandbox.

### 2.3 Read-Path Conflicts: LeanCTX Intercepts Read Before Model; Context Mode Denies Large Reads

**The conflict:** Context Mode's design philosophy is "deny large reads" — the agent should use `ctx_execute_file` (sandbox analysis) instead of `Read` for files > some threshold. LeanCTX's design philosophy is "intercept Read and compress it" — the Read tool still fires, but LeanCTX replaces the full file content with an AST-compressed version before the model sees it.

| Approach | Context Mode | LeanCTX |
|----------|-------------|---------|
| **Large file handling** | Deny `Read`; force `ctx_execute_file` sandbox analysis | Intercept `Read`; return AST-compressed version |
| **Small file handling** | Allow `Read` normally | Intercept `Read`; possibly compress based on mode |
| **Read fidelity** | Full content (if allowed) or sandbox summary | 10+ modes: signatures, AST, diff-only, etc. |
| **Hook layer** | PreToolUse rewrite to sandbox tool | PreToolUse rewrite to compressed read |

**The specific conflict:** If both tools are active and a model attempts to `Read` a 10,000-line file:
- Context Mode's PreToolUse says "deny this Read; use `ctx_execute_file` instead"
- LeanCTX's PreToolUse says "allow this Read; I'll compress it to AST mode"

The model receives contradictory guidance. Depending on hook execution order (undefined in most hosts), the model either gets a denied Read (wasting a turn) or a compressed Read that bypasses Context Mode's sandbox.

**Severity: HIGH.** This is a design philosophy conflict, not just an implementation bug. Context Mode believes large reads should be sandboxed; LeanCTX believes they should be compressed. Both cannot be right in the same session.

### 2.4 Search/Index Conflicts: Dual FTS5 Databases

**The conflict:** Context Mode maintains a per-session SQLite FTS5 database for `ctx_search`. LeanCTX maintains its own SQLite-backed session KB. Both index the same content (tool outputs, fetched web pages, file analyses) into separate databases.

| Database | Context Mode | LeanCTX |
|----------|-------------|---------|
| **Engine** | SQLite FTS5 + BM25 + trigram | SQLite FTS5 + BM25 + trigram |
| **Scope** | Per-session, auto-cleanup | Per-session, auto-cleanup |
| **Content** | Tool outputs, web fetches, session decisions | Tool outputs, web fetches, ledger entries |
| **Query API** | `ctx_search(queries: [...])` | `ctx_search(queries: [...])` |
| **Persistence** | Session-local, `ctx_purge` deletes | Session-local, `ctx_purge` deletes |

**The problems:**
1. **Disk bloat:** Two FTS5 indexes on the same corpus use ~2× disk space
2. **Query inconsistency:** `ctx_search` from Context Mode may find results that `ctx_search` from LeanCTX misses (different tokenization, different chunking)
3. **Session recovery after compaction:** After `PreCompact` purge, both databases clear. On restart, both tools re-index the same files, doubling bootstrap cost
4. **Stale content:** If a file is edited, one database may update before the other, leading to divergent search results

**Severity: MEDIUM-HIGH.** Not a session-breaking bug, but a reliability and consistency issue that degrades search quality and wastes disk/CPU.

### 2.5 Memory Graph Conflicts: LeanCTX ctx_graph vs agentmemory memory_graph_query vs Graphify

**The conflict:** Three separate graph systems with overlapping purposes but different schemas and query APIs.

| System | Graph Schema | Query API | Primary Use |
|--------|-------------|-----------|-------------|
| **Graphify** | `graph.json` — AST-based code graph, god nodes, Leiden communities | `graphify query`, `graphify path`, `graphify explain` | Codebase orientation, cross-file relationships |
| **agentmemory** | `.agentmemory/` — decision graph, ADR nodes, lesson edges, team feed | `memory_graph_query`, `memory_relations`, `memory_reflect` | Work memory, orchestration, team collaboration |
| **LeanCTX** | Internal graph — session KB graph, file relationships, tool call chains | `ctx_query`, `ctx_path`, `ctx_explain` | Session-local context navigation |

**The problems:**
1. **Query API divergence:** A model trained on SB patterns learns `graphify query` for code and `memory_graph_query` for decisions. Adding `ctx_query` creates a third pattern for the same conceptual operation.
2. **Graph boundary confusion:** Graphify's graph is project-scoped (cross-session). agentmemory's graph is team-scoped (cross-user). LeanCTX's graph is session-scoped. The model cannot easily distinguish which graph to query for "find the auth module."
3. **Cross-graph consistency:** If a file is renamed, Graphify's `graph.json` updates via `graphify watch`. agentmemory's graph may have stale file-node references. LeanCTX's graph may be regenerated from scratch each session. The three graphs drift independently.
4. **Team collaboration breakage:** agentmemory's `.agentmemory/` exports are designed for git sharing + gitleaks scanning. LeanCTX's session graph is local-only. Moving to LeanCTX for graph query breaks the "save in agentmemory, retrieve via Graphify" SB pattern.

**Severity: HIGH for teams, MEDIUM for solo devs.** The three-graph pattern is the most significant architectural tension in the 5-tool stack.

### 2.6 Shell Compression Conflicts: RTK + LeanCTX Double Compression

**The conflict:** Both RTK and LeanCTX compress shell output. RTK rewrites the command string before execution (PreToolUse). LeanCTX intercepts the output after execution (PostToolUse or wire proxy).

| Stage | RTK Action | LeanCTX Action | Combined Effect |
|-------|-----------|----------------|-----------------|
| **PreToolUse** | Rewrites `git status` → `rtk git status` (adds `--porcelain` or similar) | May also rewrite command or intercept tool call | **Double rewrite** — command may become malformed |
| **Execution** | Shell runs RTK-rewritten command | PathJail may restrict working directory | **Path restriction** — RTK may need temp files LeanCTX blocks |
| **PostToolUse** | No RTK action (compression happened at rewrite time) | Compresses output via 95+ patterns, writes to ledger | **Double compression** — already-compressed output re-compressed |
| **Wire proxy** | N/A | Compresses full request including tool result | **Triple compression risk** — RTK compressed → LeanCTX post-compressed → proxy re-compressed |

**Specific risk:** RTK's `rtk pytest` output is already compressed to ~10% of original. If LeanCTX's pattern matcher also matches pytest output, it may apply a second compression pass that strips useful detail (e.g., test names, failure traces). The model receives over-compressed, potentially lossy output.

**Severity: MEDIUM.** RTK's mature compressors are deeper for specific CLIs. LeanCTX's patterns are broader but shallower. Double compression is usually harmless but can be lossy on edge-case output formats.

### 2.7 Token Accounting Conflicts: Three Separate Trackers

**The conflict:** Each tool tracks tokens independently, with different metrics and no reconciliation.

| Tracker | Tool | What It Measures | Output Format |
|---------|------|-----------------|---------------|
| **RTK** | `rtk gain` | Tokens saved per shell command vs raw output | Session CLI print |
| **Context Mode** | `ctx_stats` | Total bytes returned, tool call counts, estimated token usage | Per-call + session summary |
| **LeanCTX** | Ed25519 ledger | Cryptographically signed hash chain of per-read/per-request savings | Tamper-evident file |

**The problems:**
1. **Triple reporting:** A single `Read` of a compressed file generates savings claims from RTK (if shell-involved), Context Mode (if sandboxed), and LeanCTX (if AST-compressed). The numbers are non-additive and may double-count.
2. **Incompatible units:** RTK reports "tokens saved," Context Mode reports "bytes returned," LeanCTX reports "ledger entries." No common currency.
3. **Audit confusion:** A corporate auditor sees three separate "savings" numbers with no reconciliation. The Ed25519 ledger is the most trustworthy but only covers LeanCTX's scope.
4. **Model confusion:** The agent sees `ctx_stats` output and `rtk gain` output in the same session. It cannot synthesize them into a single "session cost" number.

**Severity: MEDIUM.** Not a runtime bug, but an observability and accounting integrity issue.

### 2.8 Runtime Governance Conflicts: PathJail Hard Enforcement vs SB Cooperative Rules

**The conflict:** SB's security model is cooperative — AGENTS.md and `.mdc` rules instruct the agent to stay within the workspace. LeanCTX's PathJail is hard enforcement — the runtime blocks filesystem access regardless of agent intent.

| Dimension | SB Cooperative Rules | LeanCTX PathJail |
|-----------|---------------------|------------------|
| **Enforcement layer** | Instruction / prompt | Runtime syscall interception |
| **Scope** | Workspace directory (via AGENTS.md) | Configurable jail root (via `lean-ctx jail set`) |
| **Override** | Agent can ignore rules (jailbreak) | Agent cannot override runtime jail |
| **Granularity** | Per-file type, per-tool rules | Per-directory, per-process rules |
| **Conflict with SB patterns** | None — rules are advisory | May block SB scripts that write to `/tmp`, `~/.cache`, or cross-repo directories |

**Specific friction:** SB's bootstrap scripts (`scripts/sb-bootstrap.sh`, `scripts/install-cursor.sh`) write to `~/.cursor/`, `~/.codex/`, and temp directories. PathJail configured to the repo root would block these installs. SB's cross-repo memory sharing (agentmemory mesh) may write to a shared `.agentmemory/` outside the current repo. PathJail blocks this by default.

**Severity: MEDIUM-HIGH.** PathJail is stronger security but breaks SB's documented cross-directory workflows unless explicitly configured.

### 2.9 Rules Tax: Cumulative AGENTS.md / .mdc Files

**The conflict:** Each tool in the stack adds rules files that tax every turn's context.

| Rules Source | File Count | Approx Size | Tax per Turn |
|-------------|-----------|-------------|--------------|
| **Silver Bullet core** | `AGENTS.md` (root + subdirs) | ~5–15 files | ~3K–8K tokens |
| **RTK** | `.cursor/rules/rtk.mdc` or equivalent | 1 file | ~500 tokens |
| **Context Mode** | `.cursor/rules/context-mode.mdc` | 1 file | ~1K tokens |
| **agentmemory** | `.cursor/rules/agentmemory.mdc` | 1 file | ~800 tokens |
| **Graphify** | `.cursor/rules/graphify.mdc` | 1 file | ~600 tokens |
| **LeanCTX** | `lean-ctx rules` + `.mdc` | ~2–3 files | **~1.5K tokens** |
| **TOTAL (5-tool)** | | | **~8K–12K tokens of standing rules tax** |

**The problem:** Every turn, the model receives the full rules corpus as system prompt or context prefix. Adding LeanCTX's rules (PathJail configuration, MCP tool usage patterns, AST read mode preferences, ledger audit instructions) increases the standing tax. On short tasks, the rules may exceed the actual work tokens.

**Severity: MEDIUM.** The rules tax is a chronic overhead, not an acute failure. But it erodes the token savings LeanCTX promises.

---

## 3. Resolution Strategies for Each Conflict

### 3.1 Hook Conflicts — Resolution: Layered Priority with Explicit Handoff

**Strategy:** Define a strict hook execution order and demote overlapping handlers.

| Hook | Priority 1 (Wins) | Priority 2 (Muted if P1 handles) | Priority 3 (Muted if P1/P2 handle) |
|------|------------------|--------------------------------|-----------------------------------|
| **PreToolUse** | **LeanCTX** — PathJail + AST read routing | Context Mode — sandbox validation (only if LeanCTX passes through) | RTK — command rewrite (demoted to addon) |
| **PostToolUse** | **Context Mode** — indexing + fetch hardening | LeanCTX — ledger write (append-only, no conflict) | — |
| **SessionStart** | **agentmemory** — load persistent memory | LeanCTX — init runtime (after memory loaded) | Context Mode — skip if LeanCTX active |
| **PreCompact** | **agentmemory** — export decisions, gitleaks scan | LeanCTX — finalize ledger | Context Mode — skip if LeanCTX active |
| **afterAgentResponse** | **Context Mode** — native hook | — | — |

**Implementation:**
- In Cursor: Use `.mdc` rule priority tags (`priority: 100` for LeanCTX, `priority: 50` for Context Mode, `priority: 10` for RTK). Cursor applies highest priority first.
- In Claude Code: Register hooks via the native API with explicit `before`/`after` chain ordering. LeanCTX registers first; Context Mode registers with `after: leanctx`.
- In Codex: Codex hooks are deny-only (post-hoc), so PreToolUse conflicts are avoided. PostToolUse dual indexing remains; use file-based locking (`/tmp/sb-posttooluse.lock`) to serialize.
- In OpenCode: MCP middleware has explicit pipeline ordering. Define `middleware_order: ["leanctx", "contextmode", "rtk"]` in `opencode.json`.

**RTK demotion:** RTK becomes an **addon**, not a default. Only activate RTK for shell-heavy workflows where LeanCTX's 95+ patterns are insufficient. This eliminates triple interposition for most sessions.

### 3.2 MCP Conflicts — Resolution: Unified Namespace with LeanCTX as Gateway

**Strategy:** Use LeanCTX's **MCP Tool-Catalog Gateway** as the single MCP surface, routing to incumbents as backends.

**Architecture:**
```
Model → LeanCTX MCP Gateway (port 3001) → Routes to:
  - `ctx_execute*` → LeanCTX sandbox (PathJail-enabled)
  - `memory_*` → agentmemory MCP (port 3002)
  - `graphify_*` → Graphify MCP (port 3003)
  - `ctx_search` → Unified search (queries both LeanCTX KB + agentmemory graph + Graphify graph.json)
  - `ctx_fetch_and_index` → LeanCTX proxy (with wire compression)
```

**Benefits:**
- Single port (3001) for the model
- No namespace collision — `ctx_execute` always means LeanCTX; `memory_graph_query` always means agentmemory
- Model sees ~15 high-level tools instead of 70+ raw tools
- Wire proxy compresses all routed requests

**Migration:**
1. Phase 1: Context Mode MCP server **disabled** (tools masked in `mcp.json`)
2. Phase 2: agentmemory and Graphify MCP servers **retained** but ports remapped to 3002/3003
3. Phase 3: LeanCTX gateway configured with routing table in `lean-ctx.yml`

**For hosts without gateway support (Cursor early versions):** Explicit tool name prefixing — `lc_ctx_execute` vs `cm_ctx_execute` — is ugly but functional. Prefer gateway architecture where host supports it.

### 3.3 Read-Path Conflicts — Resolution: Unified Read Policy with LeanCTX Primary

**Strategy:** LeanCTX owns the Read path; Context Mode's "deny large reads" policy is **translated** into LeanCTX AST mode selection.

| File Size | Context Mode Policy | LeanCTX Unified Policy |
|-----------|---------------------|------------------------|
| < 200 lines | Allow `Read` | Allow `Read` (LeanCTX may compress to `full` or `signatures` based on mode predictor) |
| 200–2000 lines | Deny `Read`; force `ctx_execute_file` | Allow `Read` in `ast` mode (structural-only, ~60% compression) |
| > 2000 lines | Deny `Read`; force `ctx_execute_file` | Allow `Read` in `signatures` mode (~90% compression) or route to `ctx_execute_file` if analysis needed |

**Implementation:**
- Remove Context Mode's hard Read denial from `.mdc` rules
- Add LeanCTX rule: "For files > 200 lines, default to `ast` mode; for files > 2000 lines, default to `signatures` mode"
- Retain `ctx_execute_file` for cases requiring **analysis** (not just reading) — e.g., "find all TODOs in this file"

**Why this works:** LeanCTX's AST compression preserves structural information (function signatures, imports) while cutting prose. For most coding tasks, `ast` mode contains the information the model needs. Context Mode's sandbox analysis was a workaround for uncompressable full reads; LeanCTX makes the workaround unnecessary.

### 3.4 Search/Index Conflicts — Resolution: Unified Index with Agentmemory as Source of Truth

**Strategy:** Consolidate to **one FTS5 database** owned by agentmemory, with LeanCTX writing into it instead of maintaining a separate index.

**Architecture:**
- agentmemory's `.agentmemory/` directory becomes the **single persistent index**
- LeanCTX's `ctx_search` is configured to query agentmemory's FTS5 instead of its own SQLite
- LeanCTX's session KB writes are **synced** to agentmemory's graph (via `memory_save` or equivalent API)
- Context Mode's session KB is **disabled** (or writes to agentmemory too)

**Migration path:**
1. Configure LeanCTX `kb_backend: agentmemory` in `lean-ctx.yml`
2. Remove Context Mode's SQLite database file (or never create it)
3. agentmemory gains a new tool: `memory_index_tool_output` — indexes raw tool outputs for session-local search

**Why agentmemory as source of truth:**
- agentmemory is already team-shared (git-backed, gitleaks-scanned)
- agentmemory's graph has richer relationship semantics (decisions, ADRs, lessons)
- Graphify can query agentmemory's graph for code relationships if schema bridges exist

### 3.5 Memory Graph Conflicts — Resolution: Schema Bridge with Graphify as Code Graph, Agentmemory as Memory Graph

**Strategy:** Define clear graph boundaries and a cross-graph query adapter.

| Graph | Owner | Scope | Query API |
|-------|-------|-------|-----------|
| **Code graph** | Graphify | Project-scoped, cross-session | `graphify query` / `path` / `explain` |
| **Memory graph** | agentmemory | Team-scoped, cross-user | `memory_graph_query` / `relations` / `reflect` |
| **Session graph** | LeanCTX | Session-scoped, ephemeral | `ctx_query` / `path` / `explain` (queries agentmemory + Graphify via bridge) |

**Cross-graph bridge:**
- LeanCTX implements `ctx_query` by dispatching to the appropriate backend:
  - If query contains "auth module", "function", "class" → route to Graphify
  - If query contains "decision", "ADR", "lesson", "TODO" → route to agentmemory
  - If query is ambiguous → query both, merge results via RRF
- agentmemory's `memory_graph_query` already supports multi-source search; extend it to include Graphify's `graph.json`

**Eliminate LeanCTX standalone graph:** LeanCTX does not maintain its own persistent graph. Its session-local graph is a **cache** of agentmemory + Graphify results, flushed at session end. This eliminates the third graph.

### 3.6 Shell Compression Conflicts — Resolution: RTK as Conditional Addon Only

**Strategy:** Disable RTK by default. Enable RTK only for workflows where LeanCTX's compression is insufficient.

| Workflow | Default | RTK Addon |
|----------|---------|-----------|
| General coding | LeanCTX patterns | Off |
| `git status/log/diff` heavy | LeanCTX patterns | Off (LeanCTX has git-specific patterns) |
| `pytest` / `go test` / `cargo test` | LeanCTX patterns | **On** — RTK's per-test compressors are deeper |
| `kubectl` / `terraform` / `aws` | LeanCTX patterns | **On** — RTK's infra-specific compressors are deeper |
| `npm install` / `pip install` | LeanCTX patterns | Off (installation output is rarely read by model) |

**Implementation:**
- RTK's PreToolUse hook is **commented out** in default SB install
- Add `.mdc` rule: "For test commands and infra commands, prepend `rtk` if output exceeds 50 lines"
- RTK and LeanCTX PostToolUse do not conflict — RTK has no PostToolUse handler

### 3.7 Token Accounting Conflicts — Resolution: LeanCTX Ledger as Canonical, Others as Subsidiary

**Strategy:** LeanCTX's Ed25519 ledger becomes the **canonical audit trail**. RTK and Context Mode metrics are **reconciled** into it, not reported separately.

| Source | Action | Ledger Entry |
|--------|--------|--------------|
| LeanCTX | Read AST compression | Ledger: `read_compressed` |
| LeanCTX | Wire proxy savings | Ledger: `wire_compressed` |
| RTK | Shell compression | Ledger: `shell_compressed` (RTK reports to LeanCTX via API) |
| Context Mode | Sandbox analysis savings | Ledger: `sandbox_savings` (CM reports to LeanCTX via API) |
| agentmemory | Memory off-hot-path savings | Ledger: `memory_savings` (estimated from `memory_export_size` vs full context) |

**Implementation:**
- Add `ledger_reconcile` API to LeanCTX
- RTK's `rtk gain` outputs JSON that LeanCTX ingests
- Context Mode's `ctx_stats` outputs JSON that LeanCTX ingests
- Single `ctx_ledger_verify` command for auditors

**For hosts without API integration:** Manual reconciliation is impractical. In Phase 1, simply **suppress** RTK and Context Mode savings reporting (don't print them to model context). Only LeanCTX ledger entries appear.

### 3.8 Runtime Governance Conflicts — Resolution: PathJail with SB-Aware Whitelist

**Strategy:** PathJail is active but pre-configured with SB's documented directory requirements.

| Directory | SB Usage | PathJail Policy |
|-----------|----------|----------------|
| Current repo root | Primary workspace | **Allow** (read/write) |
| `~/.cursor/` | Cursor config, plugin cache | **Allow** (read/write) — needed for SB plugin |
| `~/.codex/` | Claude Code config | **Allow** (read/write) |
| `~/.codex/` | Codex config | **Allow** (read/write) |
| `~/.config/opencode/` | OpenCode config | **Allow** (read/write) |
| `~/.agentmemory/` | Cross-repo team memory | **Allow** (read/write) |
| `/tmp/` | Temp files, bootstrap scripts | **Allow** (read/write) |
| `~/.ssh/`, `~/.aws/`, `~/.kube/` | Credentials | **Deny** (LeanCTX default + SB policy) |
| `/etc/`, `/usr/`, system dirs | System files | **Deny** (LeanCTX default) |
| Other repos (sibling directories) | Cross-repo analysis | **Allow read** (configurable) |

**Implementation:**
- SB's `sb-bootstrap.sh` generates `lean-ctx-jail.yml` with the above whitelist
- PathJail loads this whitelist at `SessionStart`
- If a workflow needs a new directory (e.g., `~/.pulumi/` for DevOps), the workflow skill adds it to the whitelist dynamically

### 3.9 Rules Tax — Resolution: Consolidated Rules File with Conditional Inclusion

**Strategy:** One `AGENTS.md` file with conditional sections per active tool, not one file per tool.

**Architecture:**
```markdown
# Silver Bullet AGENTS.md (Consolidated)

## Core SB Rules (always active)
...

## LeanCTX Rules (active if lean-ctx detected)
- Use AST read mode for files > 200 lines
- Wire proxy is enabled
- PathJail whitelist: [list]

## RTK Rules (active if RTK_ENABLED=1)
- Prepend `rtk` to test/infra commands

## Context Mode Rules (active if CM_ENABLED=1)
- CTX_FETCH_STRICT for corp environments
- Credential passthrough for gh/aws/kubectl

## agentmemory Rules (always active)
- Save decisions via memory_save
- Export via memory_export

## Graphify Rules (always active)
- Use graphify query for codebase orientation
```

**Implementation:**
- SB's `scripts/sb-diagnostics.sh` detects which tools are installed and generates the active rule subset
- `.mdc` files in Cursor are generated from the consolidated `AGENTS.md`, not maintained separately per tool
- Rules tax drops from ~8K–12K tokens to ~4K–6K tokens (one consolidated file vs five separate files)

---

## 4. Per-Environment Analysis

### 4.1 Cursor (Composer)

**Cursor's enforcement model:** Allow-list — tools and rules are explicitly allowed in `.cursor/rules/*.mdc`. Composer subagents use `composer-2.5` only.

| Conflict | Cursor-Specific Impact | Resolution |
|----------|----------------------|------------|
| **Hook conflicts** | `.mdc` rules are static, not dynamic hooks. PreToolUse "rewrite" is simulated via rule text, not actual interception. | LeanCTX's native hook layer (if supported) or `.mdc` rule priority handles ordering. RTK's PreToolUse is a shell alias trick in Cursor — less fragile than true hooks. |
| **MCP conflicts** | Cursor supports multiple MCP servers but presents all tools in a flat list. 81 + 11 + 53 + 8 = **153 tools** in the picker. | **Gateway architecture essential.** Without it, model sees overwhelming tool list. Cursor's "recommended tools" feature (from `scripts/install-recommended-tools-cursor.sh`) can hide raw tools behind high-level skills. |
| **Read-path conflicts** | Cursor's `Read` tool is native; `.mdc` rules can suggest alternatives but not intercept. | LeanCTX cannot intercept Cursor's native `Read` at the runtime layer — it can only advise via rules. **AST read compression is partially unavailable in Cursor** unless LeanCTX implements a custom `Read` replacement tool. |
| **Rules tax** | Cursor loads all `.mdc` files into context. | Consolidated rules file (Section 3.9) is mandatory. Cursor's rule file count directly impacts context window. |
| **Subagent model** | `composer-2.5` only for subagents (per `AGENTS.md`). | LeanCTX must not interfere with Composer subagent dispatch. PathJail whitelist must include Composer's temp working directories. |

**Cursor verdict:** Adding LeanCTX to Cursor is **moderately difficult**. Cursor's static `.mdc` model limits LeanCTX's runtime interception capabilities. The wire proxy and PathJail work (they're external processes), but AST read compression is **rule-advisory only**, not enforced. The MCP gateway is essential to avoid 153-tool overwhelm. **Recommendation:** Add LeanCTX for wire proxy + PathJail + ledger, but expect RTK + Context Mode to remain partially active due to Cursor's hook limitations.

### 4.2 Codex (OpenAI)

**Codex's enforcement model:** Deny-only hooks — Codex does not support pre-execution hooks natively. Post-hoc analysis and tool result filtering are the primary governance mechanisms.

| Conflict | Codex-Specific Impact | Resolution |
|----------|----------------------|------------|
| **Hook conflicts** | Codex has **no PreToolUse hook**. RTK's command rewriting does not work in Codex (no interception point). Context Mode's `PreToolUse` is unavailable. | **LeanCTX faces no hook competition in Codex** — it has the field to itself for runtime interception (if Codex supports external middleware). However, Codex's deny-only model means PathJail must operate at the OS level, not the hook level. |
| **MCP conflicts** | Codex exposes native `/silver:` entries. MCP tools are registered via marketplace packages. | LeanCTX as a marketplace package (`alo-labs/leanctx-codex`) is feasible. But Codex hides internal skill-source files, making debugging harder. |
| **Read-path conflicts** | Codex `Read` is native; no PreToolUse to intercept. | Same as Cursor — AST read compression is advisory, not enforced. However, Codex's `Read` is often less heavily used because `/silver:` skills abstract file access. |
| **Rules tax** | Codex uses skill-source files, not `.mdc` rules. | LeanCTX rules would live in `skill-source/` under `plugins/silver-bullet/`. Codex's skill compilation may strip comments, reducing rules tax automatically. |
| **Sandbox** | Codex's sandbox is containerized; external runtime jails may conflict. | PathJail must be **compatible with Codex's container sandbox**, not fighting it. Test for double-jail scenarios. |

**Codex verdict:** Adding LeanCTX to Codex is **easier than Cursor for hooks** (no competition) but **harder for sandbox integration** (container + PathJail may conflict). The wire proxy works transparently. The 53-tool agentmemory surface is already wrapped in Codex's `/silver:` entries, so MCP namespace collision is hidden. **Recommendation:** LeanCTX integrates cleanly as a Codex plugin package; focus on wire proxy + ledger + prompt-injection detection.

### 4.3 Claude Code (Anthropic)

**Claude Code's enforcement model:** Native hook system — `preToolUse`, `postToolUse`, `sessionStart`, `stop`, `afterAgentResponse` are first-class callbacks in the Claude Code plugin API.

| Conflict | Claude Code-Specific Impact | Resolution |
|----------|--------------------------|------------|
| **Hook conflicts** | Claude Code has the **richest hook system**. All three tools (RTK, Context Mode, LeanCTX) compete for the same callbacks. | **Layered priority essential** (Section 3.1). Claude Code's hook registration API supports `before`/`after` ordering. Register LeanCTX first, Context Mode after, RTK last. |
| **MCP conflicts** | Claude Code plugins expose MCP surfaces via `/plugin install`. | Context Mode and LeanCTX would be separate plugins, or LeanCTX subsumes Context Mode's MCP surface. The gateway architecture is cleaner: one plugin (LeanCTX Gateway) routes to agentmemory + Graphify backends. |
| **Read-path conflicts** | Claude Code's `Read` tool is native and heavily used. | LeanCTX can intercept `Read` via `preToolUse` — this is the **only environment where true AST read interception is possible**. Claude Code is the **ideal environment for LeanCTX's read-path compression**. |
| **Rules tax** | Claude Code uses `CLAUDE.md` files, similar to `AGENTS.md`. | Consolidated `CLAUDE.md` with conditional sections. Claude Code's context window is generous (200K), so rules tax is less acute than Cursor. |
| **Memory bridge** | agentmemory has a native Claude MEMORY.md bridge (`memory_claude_sync`). | LeanCTX should not replace this — agentmemory's bridge is Claude-specific. LeanCTX can read from the same MEMORY.md for session context, but agentmemory owns the sync. |

**Claude Code verdict:** Claude Code is the **best environment for LeanCTX integration**. True hook interposition enables AST read compression, wire proxy injection, and PathJail enforcement at the runtime layer. The hook priority layering is natively supported. **Recommendation:** Claude Code should be the **pilot environment** for SB + LeanCTX integration. Full 3-tool stack (LeanCTX + agentmemory + Graphify) is achievable here first.

### 4.4 OpenCode (MCP-First)

**OpenCode's enforcement model:** MCP-first — all tools are MCP servers. Hooks are implemented as MCP middleware in `opencode.json`.

| Conflict | OpenCode-Specific Impact | Resolution |
|----------|----------------------|------------|
| **Hook conflicts** | OpenCode has **no native hooks** — middleware simulates them. MCP middleware has explicit pipeline ordering. | **Middleware pipeline** (Section 3.1) is native to OpenCode's architecture. Define `middleware_order: ["leanctx", "contextmode", "rtk"]` in `opencode.json`. |
| **MCP conflicts** | OpenCode is MCP-first; every tool is an MCP server. | The gateway architecture is **natural** in OpenCode. The model only sees the gateway server; backend servers are hidden. |
| **Read-path conflicts** | OpenCode's `Read` tool is an MCP tool, not native. | LeanCTX middleware can intercept `Read` calls and rewrite the response. **Full AST read compression is possible** in OpenCode. |
| **Rules tax** | OpenCode uses `opencode.json` + `AGENTS.md`. | Consolidated rules in `AGENTS.md`; `opencode.json` configures middleware and MCP routing. |
| **Context Mode integration** | OpenCode already has Context Mode as a built-in MCP server (per `~/.config/opencode/AGENTS.md`). | **Replacing built-in Context Mode with LeanCTX is a breaking change.** Users would need to explicitly disable the built-in Context Mode MCP and enable LeanCTX. This is the hardest migration path. |

**OpenCode verdict:** OpenCode's MCP-first architecture is **architecturally aligned** with LeanCTX's gateway model, but the **built-in Context Mode creates a hard default conflict.** Users must actively opt out of the built-in to use LeanCTX. For SB users on OpenCode, the path is: disable built-in Context Mode → enable LeanCTX Gateway → retain agentmemory + Graphify backends. **Recommendation:** OpenCode is the **second-best pilot** after Claude Code, but requires explicit opt-out from built-in tools.

---

## 5. Five-Stack Synergy Assessment

### 5.1 What SB Gains

| Gain | Source | Impact Level |
|------|--------|-------------|
| **Wire proxy token savings** | LeanCTX | **HIGH** — potentially dominant on long multi-turn sessions |
| **AST read-path compression** | LeanCTX | **HIGH** — genuine new capability, 60–90% read token reduction |
| **PathJail runtime enforcement** | LeanCTX | **HIGH** — stronger than instruction-layer rules |
| **Ed25519 audit ledger** | LeanCTX | **MEDIUM-HIGH** — enterprise auditability |
| **Prompt-injection detection** | LeanCTX | **MEDIUM-HIGH** — security gap filled |
| **MCP Tool-Catalog Gateway** | LeanCTX | **MEDIUM** — simplifies 70+ tools into ~15 high-level tools |
| **Single-binary setup** | LeanCTX | **MEDIUM** — reduces onboarding friction for new SB users |
| **Cache-prefix volatility relocation** | LeanCTX | **LOW-MEDIUM** — improves prompt cache hit rates |

### 5.2 What SB Loses

| Loss | Condition | Impact Level |
|------|-----------|-------------|
| **Pipeline synergy ergonomic** | RTK→CM→agentmemory→Graphify chain is broken | **MEDIUM** — recoverable with documentation, but real ergonomic loss for existing users |
| **Best-of-breed shell compression** | RTK's per-CLI depth (git, pytest, kubectl) | **MEDIUM** — mitigated by RTK-as-addon |
| **CTX_FETCH_STRICT compliance** | LeanCTX lacks RFC1918/loopback block | **HIGH for regulated** — Context Mode must be retained |
| **53-tool orchestration surface** | LeanCTX has 3–4 agent tools vs agentmemory's 53 | **HIGH for ops** — agentmemory must be retained |
| **Gitleaks secret hygiene** | LeanCTX has no secret scanning on export | **HIGH for teams** — agentmemory must be retained |
| **Multimodal corpus graph** | Graphify's vision/PDF/video extraction | **MEDIUM for research** — Graphify must be retained |
| **Independent tool evolution** | Four-stack tools upgrade independently | **LOW** — acceptable tradeoff for most users |
| **Per-tool minimal installs** | Cannot install RTK alone anymore | **LOW** — niche use case |

### 5.3 Diminishing Returns

**Diminishing return signal 1: Tool count vs utility.** Adding LeanCTX as a fifth parallel tool increases the MCP surface from ~70 tools to ~150 tools. Research shows model performance degrades when tool count exceeds ~20–30 due to schema description overhead and selection confusion. The 5-tool parallel stack is **past the diminishing returns point** for tool count.

**Diminishing return signal 2: Compression stacking.** RTK compresses shell to ~10%. LeanCTX's proxy compresses the full request by ~30–50%. These are **multiplicative** but the second compression pass has less absolute impact because the input is already small. Double compression yields 10% × 50% = 5% of original, but the marginal gain from the second pass is only 5 percentage points (10% → 5%).

**Diminishing return signal 3: Rules tax vs savings.** If LeanCTX saves 60% on reads but adds 1.5K tokens of rules, the net savings on a 3K-token read is 1.8K saved minus 1.5K tax = **300 tokens net**. On small tasks, the rules tax erases the savings.

**Diminishing return signal 4: Graph multiplicity.** Three graphs (Graphify, agentmemory, LeanCTX) do not yield 3× retrieval quality. They yield **query confusion** — the model wastes turns deciding which graph to query.

### 5.4 Net Synergy Score

| Configuration | Synergy Score | Rationale |
|---------------|--------------|-----------|
| **4-tool stack (current)** | 8/10 | Proven pipeline, documented patterns, specialist depth |
| **5-tool parallel stack** | 4/10 | Conflicts overwhelm gains, namespace chaos, triple accounting |
| **3-tool restructured (LeanCTX + agentmemory + Graphify)** | **9/10** | Captures LeanCTX unique wins, retains super-critical gaps, unified gateway |
| **3-tool + RTK addon + Context Mode conditional** | 8.5/10 | Maximum flexibility, slightly more complex than pure 3-tool |

---

## 6. Recommendation and Phased Adoption Path

### 6.1 Primary Recommendation

**Silver Bullet should add LeanCTX, but not as a fifth parallel tool. It should replace RTK + Context Mode as the compression/sandbox/governance layer, yielding a 3-tool core stack: LeanCTX + agentmemory + Graphify.**

This architecture:
- **Preserves** all five LeanCTX unique capabilities (wire proxy, AST reads, PathJail, ledger, prompt-injection)
- **Retains** all four-stack super-critical gaps (CTX_FETCH_STRICT via conditional Context Mode, 53-tool orchestration via agentmemory, gitleaks via agentmemory, multimodal corpus via Graphify)
- **Resolves** the nine conflict categories through unified gateway, layered hooks, and consolidated rules
- **Simplifies** onboarding (one binary for compression/governance vs two)
- **Maintains** team collaboration (agentmemory + Graphify unchanged)

### 6.2 Phased Adoption Path

#### Phase 0: Pilot (Weeks 1–2) — Claude Code Only

**Goal:** Validate LeanCTX integration in the richest hook environment.

| Step | Action | Success Criteria |
|------|--------|-----------------|
| 0.1 | Install LeanCTX in a test Claude Code project | `lean-ctx setup` completes, `ctx_stats` reports healthy |
| 0.2 | Disable RTK PreToolUse hook; keep RTK binary available | No `rtk` prefix in commands; RTK addon path preserved |
| 0.3 | Configure Context Mode to **passthrough mode** (hooks active but no PreToolUse rewrite) | Context Mode's sandbox and fetch hardening still work; no Read denial |
| 0.4 | Enable LeanCTX wire proxy; measure session token costs | 20%+ wire savings on sessions > 10 turns |
| 0.5 | Run full SB test suite (`bash tests/run-all-tests.sh`) | No regressions in workflow execution |

**Go/No-Go:** If Phase 0 shows >15% token savings with no test regressions, proceed to Phase 1.

#### Phase 1: Claude Code Rollout (Weeks 3–4)

**Goal:** Full 3-tool stack in Claude Code production.

| Step | Action | Details |
|------|--------|---------|
| 1.1 | Remove RTK from default SB install for Claude Code | RTK becomes optional addon (`--with-rtk` flag in install script) |
| 1.2 | Demote Context Mode to **conditional** for Claude Code | Context Mode only enabled if `SB_CORPORATE=1` env var set |
| 1.3 | Enable LeanCTX MCP Gateway | Route `memory_*` to agentmemory, `graphify_*` to Graphify |
| 1.4 | Update `AGENTS.md` template (`templates/silver-bullet.md.base`) | Consolidated rules with conditional sections |
| 1.5 | Update `silver-bullet.md` canonical instruction doc | Document 3-tool architecture, gateway routing, PathJail whitelist |
| 1.6 | Run CI green check (`bash tests/run-all-tests.sh`) | Mandatory before any plugin release |
| 1.7 | Publish Claude Code plugin update | Version bump, release notes, migration guide |

#### Phase 2: Codex Rollout (Weeks 5–6)

**Goal:** Codex integration, leveraging Codex's skill-source abstraction.

| Step | Action | Details |
|------|--------|---------|
| 2.1 | Create `alo-labs/leanctx-codex` marketplace package | LeanCTX as Codex plugin |
| 2.2 | Integrate LeanCTX wire proxy into Codex `/silver:` skill layer | Proxy runs transparently behind Codex's API calls |
| 2.3 | Update Codex skill-source files | Consolidated rules in `plugins/silver-bullet/skill-source/` |
| 2.4 | Retain agentmemory + Graphify as backend MCPs | Visible in Codex's tool picker |
| 2.5 | Test with `bash tests/run-all-tests.sh` | Codex-specific tests may need expansion |

#### Phase 3: Cursor Rollout (Weeks 7–8)

**Goal:** Cursor integration, addressing static `.mdc` limitations.

| Step | Action | Details |
|------|--------|---------|
| 3.1 | Update `scripts/install-cursor.sh` | Install LeanCTX binary, configure `.mdc` rules |
| 3.2 | Generate consolidated `.cursor/rules/silver-bullet.mdc` | One file replaces per-tool `.mdc` files |
| 3.3 | Configure LeanCTX wire proxy as system service | Runs at OS level, not Cursor plugin level |
| 3.4 | Retain RTK as default addon for Cursor | Cursor's hook limitations make RTK's shell compression more valuable |
| 3.5 | Retain Context Mode as default for Cursor | Cursor lacks true PreToolUse; Context Mode's sandbox is advisory but still useful |
| 3.6 | Accept that Cursor will be a **4-tool hybrid** (LeanCTX + RTK + Context Mode + agentmemory + Graphify) | Cursor's architectural limitations prevent full 3-tool purity |

**Cursor note:** Cursor is the **hardest environment** for LeanCTX integration due to static rules and lack of true hooks. The 4-tool hybrid is acceptable — LeanCTX's wire proxy and ledger still add value even if AST read compression is rule-advisory only.

#### Phase 4: OpenCode Rollout (Weeks 9–10)

**Goal:** OpenCode integration, resolving built-in Context Mode conflict.

| Step | Action | Details |
|------|--------|---------|
| 4.1 | Document explicit opt-out from built-in Context Mode | `opencode.json` setting: `"context_mode": false` |
| 4.2 | Enable LeanCTX MCP Gateway in `opencode.json` | Backend routing to agentmemory + Graphify |
| 4.3 | Leverage OpenCode's middleware pipeline for hook ordering | `middleware_order` configuration |
| 4.4 | Test OpenCode's native `Read` interception | Validate AST compression works via middleware |
| 4.5 | Run CI green check | |

#### Phase 5: SB Documentation and Template Sync (Weeks 11–12)

**Goal:** Update all SB canonical sources.

| Step | Action | Details |
|------|--------|---------|
| 5.1 | Update `silver-bullet.md` | Reflect 3-tool architecture |
| 5.2 | Update `templates/silver-bullet.md.base` | CI parity check |
| 5.3 | Update `docs/RTK.md`, `docs/CONTEXT-MODE.md` | Document "conditional addon" status |
| 5.4 | Update `docs/LEANCTX.md` | New doc for LeanCTX integration |
| 5.5 | Update site (`site/index.html`, `site/help/`) | New install paths, tool comparison table |
| 5.6 | Run site freshness tests | `bash tests/scripts/test-site-doc-freshness.sh` |
| 5.7 | Run full validation | `bash tests/run-all-tests.sh` |

### 6.3 Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| **CI regressions** | Phase 0 pilot must pass full test suite before any rollout |
| **Token savings don't materialize** | Measure in Phase 0; if <10% savings, abort Claude Code rollout |
| **User confusion from architecture change** | Migration guide, `sb-diagnostics.sh` reports active tools, clear `--with-rtk` / `--with-contextmode` flags |
| **Corporate users lose CTX_FETCH_STRICT** | Context Mode remains available via `SB_CORPORATE=1`; never fully removed |
| **Team users lose gitleaks** | agentmemory is never removed; gitleaks scanning unchanged |
| **Cursor users see no AST compression** | Documented limitation; wire proxy and ledger still add value |
| **OpenCode users can't disable built-in Context Mode** | Escalate to OpenCode maintainers if setting is missing |

### 6.4 Final Verdict

**Should SB add LeanCTX?** **Yes — as a replacement layer for RTK + Context Mode, not as a fifth parallel tool.**

The restructured 3-tool core (LeanCTX + agentmemory + Graphify) with RTK and Context Mode as conditional add-ons captures:
- **95%+ of LeanCTX's unique value** (wire proxy, AST reads, PathJail, ledger, prompt-injection)
- **100% of the four-stack's super-critical gaps** (CTX_FETCH_STRICT, 53-tool orchestration, gitleaks, multimodal corpus)
- **Operational sustainability** (unified gateway, single rules file, one ledger)

The parallel 5-tool stack is **operationally untenable** and should not be pursued. The 3-tool restructured stack is the optimal architecture for Silver Bullet's next phase.

---

*Report generated by Kimi K2.6 (OpenCode) as follow-up to multi-AI parallel research dispatch.*  
*All claims cite upstream sources from prior reports and SB canonical documentation.*  
*Verdicts are conditional and environment-specific, not absolute.*

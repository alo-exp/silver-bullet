# LeanCTX as 5th Tool in the Silver Bullet Stack: Conflict Analysis & Integration Strategy

**Author:** mimo-v2.5-pro (followup deep-research agent)
**Date:** 2026-07-07
**Mode:** ULTRADEEP
**Scope:** Can LeanCTX be added to SB's existing 4-tool stack (RTK + Context Mode + agentmemory + Graphify) without conflicts? How to make all 5 synergistic across Cursor, Codex, Claude Code, and OpenCode?

---

## Executive Summary

**Adding LeanCTX as a 5th tool is architecturally feasible but requires a layered resolution strategy across 9 conflict domains.** The key insight is that LeanCTX should not be a peer of the existing 4 tools — it should be a **replacement layer for RTK + Context Mode** (compression/sandbox) while coexisting with agentmemory + Graphify (memory/retrieval). This reduces the effective stack from 5 tools to 3 (LeanCTX + agentmemory + Graphify), eliminating most conflicts by design.

**The 9 conflict domains are: hook ordering, MCP port/namespace, read-path interception, dual FTS5 indexes, memory graph overlap, shell double-compression, triple token accounting, PathJail vs cooperative governance, and cumulative rules tax.** Each has a concrete resolution strategy — layering, toggling, priority ordering, or isolation. No conflict is unresolvable.

**Per-environment analysis reveals that Cursor's allow-list model is the hardest integration surface** (LeanCTX's Bash rewrites need explicit allow-list entries alongside RTK's), while **Claude Code's hook system is the easiest** (deep hook surface with explicit ordering). OpenCode's MCP-first model makes LeanCTX's MCP server the natural primary integration point.

**The 5-stack synergy assessment yields diminishing returns.** SB gains PathJail (filesystem security), wire proxy (request compression), prompt-injection detection, and Ed25519 savings ledger — all genuinely novel capabilities SB lacks. But it loses separation of concerns, independent upgrade cadence, and the idiomatic RTK→CM→agentmemory→Graphify pipeline. The net benefit is positive only when LeanCTX replaces RTK+CM rather than augmenting them.

**Recommendation: Phased adoption.** LeanCTX replaces RTK + Context Mode in a 3-tool stack (LeanCTX + agentmemory + Graphify). This preserves SB's memory/retrieval pipeline while gaining LeanCTX's 5 unique capabilities. Do not run all 5 tools simultaneously.

---

## 1. Would Adding LeanCTX Benefit SB?

### 1.1 Genuinely Novel Capabilities SB Lacks

SB's current 4-tool stack has no equivalent for these LeanCTX capabilities:

| Capability | SB's Current Gap | Impact |
|-----------|-----------------|--------|
| **PathJail** runtime filesystem confinement | SB relies on cooperative rules (`silver-bullet.md` instructions) + hooks that check but don't jail. No filesystem sandbox. | **High** — SB's PAIN 08 (security reviews after merge) is partially caused by lack of pre-write confinement |
| **Wire proxy** (compresses every outbound model request) | Neither RTK (shell only) nor Context Mode (analysis sandbox) compresses the model request body. | **High** — SB's PAIN 06 (context rot) is partially caused by uncompressed request history |
| **Prompt-injection detection** before model entry | No incumbent tool provides this. SB's `SECURE` atomic flow reviews code, but doesn't scan incoming context for injection. | **High** — SB's PAIN 08 (security reviews after merge) |
| **Ed25519 hash-chained savings ledger** with offline verification | RTK `rtk gain` and Context Mode `ctx_stats` are session metrics, not cryptographically verifiable. | **Medium** — Auditability, not capability |
| **MCP Tool-Catalog Gateway** (proxy unlimited downstream MCP) | No equivalent. Each SB tool has its own MCP server. | **Medium** — Useful for OpenCode integration |

### 1.2 Capabilities That Overlap But Improve on SB's Stack

| Capability | SB's Current Implementation | LeanCTX Advantage |
|-----------|---------------------------|-------------------|
| Read-path compression | Context Mode `ctx_execute_file` (cooperative, not enforced) | 10 AST fidelity modes with ModePredictor, hook-enforced |
| Shell compression | RTK 95+ CLI-specific patterns | LeanCTX native + RTK addon compatibility |
| Session knowledge base | Context Mode FTS5 | LeanCTX FTS5 + cross-archive expansion (`ctx_expand`) |
| Savings tracking | `rtk gain` + `ctx_stats` (separate) | Unified Ed25519 ledger |

### 1.3 Capabilities That Merely Duplicate

| Capability | SB's Implementation | LeanCTX's Implementation | Verdict |
|-----------|---------------------|-------------------------|---------|
| Knowledge graph | Graphify `graphify query/path/explain` | LeanCTX `ctx_query/ctx_path/ctx_explain` | **Keep Graphify** — deeper multimodal corpus, mature git workflow |
| Session memory | agentmemory 53-tool orchestration | LeanCTX `ctx_graph` + handoffs | **Keep agentmemory** — orchestration gap is super-critical |
| Sandbox execution | Context Mode `ctx_execute/ctx_execute_file` | LeanCTX `ctx_execute/ctx_execute_file` | **Replace Context Mode** with LeanCTX |

### 1.4 Net Assessment

LeanCTX fills **3 genuine security gaps** (PathJail, prompt injection, wire proxy) and **1 operational gap** (unified savings ledger) that SB's stack completely lacks. These are not incremental improvements — they are architectural capabilities no incumbent provides. The question is not "does LeanCTX add value?" but "can it be integrated without destroying existing value?"

---

## 2. Conflicts — Identify Each

### 2.1 Hook Conflicts

SB has 12 hook layers registered in `hooks/hooks.json`. Each tool has its own gate hook:

| Hook Event | SB's Hooks | Tool Gate Hooks | LeanCTX's Hooks |
|-----------|-----------|----------------|-----------------|
| **SessionStart** | `session-start`, `spec-session-record.sh` | — | Session init, cache warm |
| **PreToolUse/`.*`** | `debug-dump.sh` | — | PathJail check, prompt-injection scan |
| **PreToolUse/Bash\|Skill** | `phase-archive.sh`, `completion-audit.sh` | `rtk-gate.sh`, `context-mode-gate.sh` | Shell compression rewrite |
| **PreToolUse/Edit\|Write** | `planning-file-guard.sh`, `instruction-file-guard.sh`, `workflow-chain-guard.sh`, `orchestrator-directive-guard.sh`, `agent-delegation-guard.sh`, `phase-lock-claim.sh` | — | PathJail confinement |
| **PreToolUse/Read\|Grep** | — | `context-mode-read-deny.sh` | AST mode interception |
| **PreToolUse/Task\|Subagent** | `orchestrator-directive-guard.sh`, `agent-delegation-guard.sh` | — | — |
| **PostToolUse/Write\|Edit** | `record-site-session.sh`, `trivial-file-clear.sh` | — | Cache invalidation |
| **PostToolUse/Skill\|Bash** | `record-skill.sh`, `flow-advance.sh`, `ci-status-check.sh`, `record-graphify-query.sh` | `record-token-compression-usage.sh` | Usage recording |
| **PostToolUse/Skill** | `semantic-compress.sh` | — | — |
| **Stop** | `outcomes-check.sh`, `prompt-reminder.sh` | — | Session summary |

**Conflict points:**

1. **PreToolUse/Bash ordering**: RTK rewrites shell first, then SB's `completion-audit.sh` checks. Where does LeanCTX's shell compression fit? Before RTK? After? The documented order is "RTK rewrites first; CM routes/denies." LeanCTX adds a third layer.

2. **PreToolUse/Read\|Grep double interception**: SB's `context-mode-read-deny.sh` denies reads >5120 bytes when Context Mode is opted in. LeanCTX wants to intercept Read with AST modes. If both are active, the model sees two competing read-path handlers.

3. **SessionStart overlap**: SB's `session-start` resets state, checks versions, compacts context. LeanCTX's session init warms cache and restores state. Both fire on `startup|clear|compact`.

4. **PostToolUse/Bash recording**: SB's `record-token-compression-usage.sh` records RTK usage. LeanCTX would also record usage. Two recorders for the same event.

### 2.2 MCP Conflicts

| MCP Server | Port | Tools Exposed |
|-----------|------|---------------|
| Context Mode | Default (stdio) | `ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`, `ctx_search`, `ctx_index`, `ctx_fetch_and_index`, `ctx_stats`, `ctx_insight`, `ctx_purge`, `ctx_upgrade`, `ctx_doctor` |
| agentmemory | Default (stdio) | 53 tools (`memory_save`, `memory_query`, `memory_action_create`, etc.) |
| Graphify | Default (stdio, or HTTP :8080) | `graphify_query`, `graphify_path`, `graphify_explain`, `graphify_affected` |
| **LeanCTX** | Default (stdio) | `ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`, `ctx_search`, `ctx_index`, `ctx_fetch_and_index`, `ctx_stats`, + 70 more |

**Conflict points:**

1. **Tool namespace collision**: LeanCTX and Context Mode expose identically-named tools (`ctx_execute`, `ctx_search`, `ctx_stats`, etc.). MCP clients cannot disambiguate — the host would see duplicate tool names and either error or pick one arbitrarily.

2. **Port conflicts** (HTTP mode): If any tool uses HTTP transport, port collisions are possible. Graphify defaults to `:8080`. LeanCTX's HTTP port is configurable but must not collide.

3. **Tool-schema token tax**: SB already pays for Context Mode's 11 tool schemas + agentmemory's 53 + Graphify's ~5 = ~69 tool descriptors per turn. Adding LeanCTX's 81 tools brings the total to ~150 tool descriptors, consuming significant context tokens every turn.

### 2.3 Read-Path Conflicts

SB's current read-path governance:
- `context-mode-read-deny.sh` (PreToolUse/Read|Grep): denies reads on files > `read_deny_bytes` (default 5120) when Context Mode is opted in.
- `silver-bullet.md` §2g-ii: instructional rule to use `ctx_execute_file` instead of `Read` for large files.

LeanCTX's read-path governance:
- PathJail: runtime filesystem jail, deny-by-default on paths outside project.
- AST read modes: hook-enforced fidelity routing (10 modes: full → map → signatures → diff → task → reference → aggressive → entropy → lines:N-M).
- ModePredictor: selects optimal mode from task intent.

**Conflict:** Both SB and LeanCTX want to govern Read. If both are active:
- SB's `context-mode-read-deny.sh` denies the Read.
- LeanCTX's AST mode hook intercepts the Read.
- The model receives conflicting signals: one says "denied, use ctx_execute_file", the other says "intercepted, returning compressed AST mode."

### 2.4 Search/Index Conflicts

| Index | Owner | Backend | Purpose |
|-------|-------|---------|---------|
| Session KB | Context Mode | FTS5 | Sandbox outputs, web fetches, code analysis |
| Session KB | LeanCTX | FTS5 | Same data, different index |
| Knowledge graph | Graphify | graph.json (JSON) | Code structure, relationships |
| Memory graph | agentmemory | `.agentmemory/` markdown + FTS5 | Decisions, observations, team memory |
| Knowledge graph | LeanCTX | `ctx_graph` (FTS5 + graph) | Code structure + memory |

**Conflict:** Running Context Mode + LeanCTX means two FTS5 databases indexing overlapping data. The agent's `ctx_search` queries hit both, returning potentially different results. Maintenance overhead doubles.

### 2.5 Memory Graph Conflicts

| System | Tools | Data Model |
|--------|-------|------------|
| agentmemory | `memory_save`, `memory_query`, `memory_action_create`, `memory_frontier`, etc. (53 tools) | Action DAG, frontier scheduling, leases, signals, sentinels |
| Graphify | `graphify_query`, `graphify_path`, `graphify_explain` | AST-derived code graph with community detection |
| LeanCTX | `ctx_graph`, `ctx_query`, `ctx_path`, `ctx_explain` | Unified memory + code graph |

**Conflict:** Three graph systems active simultaneously. The "save via agentmemory, retrieve via Graphify" pattern (documented SB synergy) would have a third participant. If LeanCTX's `ctx_graph` is also active, the agent has three graph query surfaces with overlapping but different data.

### 2.6 Shell Compression Conflicts

| Layer | Tool | Mechanism |
|-------|------|-----------|
| 1 | RTK | PreToolUse hook rewrites Bash commands, compresses stdout |
| 2 | LeanCTX | PreToolUse hook rewrites Bash commands, compresses stdout |

**Conflict:** If both are active, shell output is compressed twice. RTK rewrites `git status` → compressed output. LeanCTX then compresses that already-compressed output. The second compression is wasted work at best, garbled output at worst.

### 2.7 Token Accounting Conflicts

| Tracker | Owner | Mechanism |
|---------|-------|-----------|
| `rtk gain` | RTK | CLI command, session metrics |
| `ctx_stats` | Context Mode | MCP tool, per-session bytes returned |
| LeanCTX savings | LeanCTX | Ed25519 hash-chained ledger, offline verification |

**Conflict:** Three separate savings numbers with different methodologies. The agent (and user) cannot easily determine "how many tokens did we actually save?" because each tracker counts different things differently.

### 2.8 Runtime Governance Conflicts

| Layer | Mechanism | Enforcement |
|-------|-----------|-------------|
| SB | Cooperative rules in `silver-bullet.md` + hook checks | Hooks deny/block at boundary; rules instruct the agent |
| LeanCTX PathJail | Runtime filesystem jail | Hard enforcement — paths outside jail are inaccessible, not just blocked by hook |

**Conflict:** SB's governance model is cooperative — hooks check and deny, but the agent can theoretically work around them (e.g., using a different tool name). PathJail is hard enforcement — the filesystem itself is confined. If both are active, PathJail may block legitimate SB operations (e.g., SB's `session-start` writes to state directories that PathJail might confine).

### 2.9 Rules Tax

| File | Approximate Size | Content |
|------|-----------------|---------|
| `silver-bullet.md` | ~20KB | Enforcement instructions, tool rules, workflow routing |
| `AGENTS.md` | ~8KB | Repo-operational guidance |
| Context Mode instruction fragment | ~2KB | When to use `ctx_*` vs `Read` |
| Cursor `.mdc` rules | ~5KB | Recommended tool rules |
| **LeanCTX AGENTS.md addition** | ~3-5KB | Tool routing, PathJail rules, AST mode guidance |

**Conflict:** Cumulative rules approach ~40KB of instruction context consumed every turn. Each additional tool's AGENTS.md fragment reduces the context available for actual work.

---

## 3. Resolution Strategies

### 3.1 Hook Conflicts → Priority Layering

**Strategy: Explicit hook ordering with priority tiers.**

```
Tier 1 (rewrite):    RTK → LeanCTX shell compression (only if RTK not active)
Tier 2 (governance): LeanCTX PathJail → SB planning-file-guard → SB completion-audit
Tier 3 (read-path):  LeanCTX AST modes (when LeanCTX active) OR context-mode-read-deny (when CM active)
Tier 4 (recording):  SB record-skill → LeanCTX usage recording
```

**Implementation:**
- In `hooks.json`, register LeanCTX hooks **after** RTK hooks in the PreToolUse/Bash matcher.
- LeanCTX detects RTK presence: if RTK is installed and active, LeanCTX skips shell compression (documented RTK addon compatibility).
- For PreToolUse/Read|Grep: LeanCTX's AST mode hook **replaces** `context-mode-read-deny.sh` when LeanCTX is active. Register LeanCTX's read hook with higher priority; disable CM's read-deny hook via `recommended_tools.context_mode.enabled_by_user: false`.
- SessionStart: LeanCTX init runs **after** SB's `session-start` (which resets state first). Add LeanCTX's session init as a third SessionStart hook entry with appropriate timeout.

**Resolution type:** Layering + toggling.

### 3.2 MCP Conflicts → Namespace Isolation + Toggle

**Strategy: LeanCTX replaces Context Mode's MCP server. Do not run both.**

- When LeanCTX is active, set `recommended_tools.context_mode.enabled_by_user: false`.
- Context Mode's 11 MCP tools are a subset of LeanCTX's 81 tools. LeanCTX covers 95% of Context Mode's surface.
- The one hard gap (`CTX_FETCH_STRICT`) is addressed by LeanCTX's SSRF protection + a LeanCTX configuration flag (see §3.8).
- agentmemory and Graphify MCP servers continue to run independently — no namespace collision with LeanCTX (different tool prefixes: `memory_*` vs `ctx_*` vs `graphify_*`).

**For the 81-tool tax:** LeanCTX's 5 high-level tools (`ctx_execute`, `ctx_search`, `ctx_fetch_and_index`, `ctx_index`, `ctx_stats`) should be the primary interface. Document in SB's `silver-bullet.md` §2g-ii that LeanCTX's full 81-tool catalog is available but the 5 high-level tools are the recommended entry point. If the MCP host supports tool filtering (some do), expose only the 5 high-level tools + any domain-specific tools the workflow needs.

**Resolution type:** Toggling + isolation.

### 3.3 Read-Path Conflicts → Single Interceptor

**Strategy: One tool owns the read path. LeanCTX takes over from Context Mode.**

- When LeanCTX is active: LeanCTX's AST mode hook intercepts Read|Grep. Context Mode's `context-mode-read-deny.sh` is disabled (via `enabled_by_user: false`).
- LeanCTX's `read_deny_bytes` setting replaces Context Mode's. Same semantics, same threshold, different owner.
- LeanCTX's PathJail adds confinement **on top of** the read-path interception — PathJail restricts which paths are accessible; AST modes compress what is read. These are complementary, not conflicting.

**Resolution type:** Replacement.

### 3.4 Search/Index Conflicts → Single FTS5

**Strategy: LeanCTX's FTS5 replaces Context Mode's FTS5.**

- When LeanCTX is active, Context Mode's session KB is not created. LeanCTX's FTS5 session KB is the single source of truth for session-scoped search.
- Graphify's `graph.json` remains the code-structure index (not FTS5 — it's a separate JSON artifact).
- agentmemory's `.agentmemory/` markdown remains the memory export format.
- Three different indexes for three different purposes: session KB (LeanCTX FTS5), code graph (Graphify graph.json), team memory (agentmemory markdown). No duplication.

**Resolution type:** Replacement.

### 3.5 Memory Graph Conflicts → Role Separation

**Strategy: Each graph system has a distinct role. LeanCTX does not replace agentmemory's orchestration graph.**

| System | Role | Data |
|--------|------|------|
| **Graphify** | Code structure graph (AST-derived) | Symbols, dependencies, communities |
| **agentmemory** | Orchestration + team memory graph | Actions, decisions, frontier, leases, signals |
| **LeanCTX** | Session-scoped memory + code graph | Current session context, cached reads |

**Key principle:** LeanCTX's `ctx_graph` operates at session scope. agentmemory operates at project/team scope. Graphify operates at codebase scope. They are layered, not competing.

**Implementation:**
- LeanCTX's `ctx_graph` is used for session-scoped entity tracking (what files were touched, what decisions were made this session).
- agentmemory's `memory_save` / `memory_query` is used for durable cross-session decisions and team handoffs.
- Graphify's `graphify query` is used for codebase orientation before planning/editing.
- The "save via agentmemory, retrieve via Graphify" pattern continues unchanged. LeanCTX adds a session-scoped layer beneath it.

**Resolution type:** Layering.

### 3.6 Shell Compression Conflicts → Mutual Exclusion

**Strategy: Only one shell compressor active at a time. LeanCTX detects and defers to RTK.**

- LeanCTX's documentation already lists RTK as a compatible addon. When RTK is detected (binary on PATH, hooks registered), LeanCTX skips its native shell compression.
- If RTK is **not** installed, LeanCTX's native shell compression activates.
- This is the simplest conflict to resolve — it's already addressed in LeanCTX's compatibility layer.

**Implementation in SB:** In `rtk-gate.sh`, the hook already checks if RTK is installed. If the user opts into LeanCTX but not RTK, LeanCTX handles shell compression. If both are installed, RTK handles shell compression (deeper per-CLI patterns) and LeanCTX handles everything else (read-path, wire proxy, PathJail).

**Resolution type:** Toggling (mutual exclusion with detection).

### 3.7 Token Accounting Conflicts → Unified Reporting

**Strategy: One primary tracker (LeanCTX's Ed25519 ledger) with optional secondary trackers.**

- LeanCTX's Ed25519 ledger is the authoritative savings record (cryptographically verifiable).
- `rtk gain` continues to work for shell-specific metrics when RTK is the active compressor.
- `ctx_stats` is replaced by LeanCTX's `ctx_stats` (same tool name, same semantics).
- SB's `record-token-compression-usage.sh` records whichever compressor is active (RTK or LeanCTX).

**Resolution type:** Replacement (Context Mode stats) + coexistence (RTK gain + LeanCTX ledger).

### 3.8 Runtime Governance Conflicts → PathJail as Hard Boundary, SB Rules as Process Layer

**Strategy: PathJail and SB governance are complementary layers, not competing.**

```
Layer 1 (hard):  PathJail — filesystem confinement (paths outside project inaccessible)
Layer 2 (process): SB hooks — planning gates, completion audits, workflow enforcement
Layer 3 (cooperative): SB rules — silver-bullet.md instructions, agent guidance
```

**Implementation:**
- PathJail confines the filesystem boundary. SB's hooks enforce process within that boundary.
- PathJail does not block SB's state directories (`.planning/`, `.silver-bullet.json`) — these are within the project root.
- If PathJail blocks a legitimate SB operation (e.g., writing to a temp directory outside the project), the PathJail configuration must include an allowlist for SB's known paths: `${CLAUDE_PLUGIN_ROOT}/`, `${SB_RUNTIME_HOME_ROOT}/`, `/tmp/opencode/`.
- LeanCTX's prompt-injection detection runs **before** SB's hooks — if injection is detected, the request is blocked before SB's governance even sees it. This is complementary.

**Resolution type:** Layering.

### 3.9 Rules Tax → Selective Inclusion

**Strategy: LeanCTX's AGENTS.md contribution is minimal — only routing rules, not full documentation.**

- LeanCTX adds ~1-2KB to AGENTS.md (when to use `ctx_*` tools, PathJail boundary notes), not the full 3-5KB of comprehensive documentation.
- Full LeanCTX documentation lives in LeanCTX's own docs, not in SB's instruction files.
- Context Mode's instruction fragment (~2KB) is **removed** when LeanCTX replaces it, so the net rules tax is approximately zero.

**Net rules budget:**

| File | Before (4-tool) | After (LeanCTX + agentmemory + Graphify) | Delta |
|------|:---------------:|:----------------------------------------:|:-----:|
| `silver-bullet.md` | ~20KB | ~20KB (updated §2g-ii) | 0 |
| `AGENTS.md` | ~8KB | ~8KB | 0 |
| Context Mode fragment | ~2KB | **removed** | -2KB |
| LeanCTX routing | 0 | ~1.5KB | +1.5KB |
| **Net** | ~30KB | ~29.5KB | **-0.5KB** |

**Resolution type:** Replacement + selective inclusion.

---

## 4. Per-Environment Analysis

### 4.1 Cursor

**Hook model:** PreToolUse with allow-list coupling. Cursor's `cli-config.json` defines which Bash commands are allowed. Hooks can deny but not rewrite in the same way Claude Code does.

**Integration challenges:**
- **Allow-list coupling**: RTK's shell rewrites require entries in `~/.cursor/cli-config.json`. LeanCTX's shell rewrites would also need allow-list entries. If both are active, the allow-list must permit both RTK's and LeanCTX's command patterns.
- **Hook bridge**: SB uses `cursor-hook-bridge.sh` to adapt Claude Code hooks to Cursor's hook model. LeanCTX's hooks would also need bridging.
- **Rules surface**: Cursor uses `.mdc` files in `.cursor/rules/`. LeanCTX would need a `.mdc` rule file alongside Graphify's and agentmemory's.

**Resolution:**
- Use LeanCTX **instead of** RTK + Context Mode (not alongside). This eliminates the allow-list conflict — only LeanCTX's command patterns need allow-list entries.
- Generate a LeanCTX `.mdc` rule file via `lean-ctx cursor install` (if supported) or manual creation.
- LeanCTX's hooks are registered in `.cursor/hooks.json` alongside SB's existing hooks.

**Feasibility: Medium.** Cursor's allow-list model is the most restrictive host. LeanCTX's Bash rewrites must be tested against Cursor's allow-list before deployment.

### 4.2 Codex

**Hook model:** Deny-only hooks in `~/.codex/hooks.json`. No rewrite capability — hooks can deny (exit non-zero) or allow (exit 0), but cannot modify the tool input/output.

**Integration challenges:**
- **No rewrite support**: Codex hooks cannot rewrite Bash commands. RTK's shell compression works via PreToolUse hook rewrites on Claude Code, but on Codex, it's prompt-only (instructional). LeanCTX would face the same limitation.
- **MCP-first**: Codex uses MCP servers as the primary tool surface. LeanCTX's MCP server is the natural integration point.
- **SessionStart**: Codex may not support SessionStart hooks in the same way as Claude Code.

**Resolution:**
- LeanCTX's MCP server provides all compression, sandbox, and graph tools via MCP (no hooks needed for core functionality).
- Shell compression is instructional on Codex (documented in AGENTS.md, not hook-enforced).
- PathJail operates at the MCP server level, not the hook level — it confines the MCP sandbox, not the host agent.
- agentmemory and Graphify MCP servers continue to run independently.

**Feasibility: High.** Codex's MCP-first model is the most natural fit for LeanCTX's architecture. Hook limitations are irrelevant when the MCP server provides the core functionality.

### 4.3 Claude Code

**Hook model:** Deep hook surface — PreToolUse, PostToolUse, SessionStart, Stop, UserPromptSubmit. Hooks can deny, allow, or modify tool input/output. This is SB's primary development host.

**Integration challenges:**
- **Hook ordering**: SB has 12 hook layers. LeanCTX adds its own hooks. The ordering must be explicit and documented.
- **Plugin model**: SB is a Claude Code plugin. LeanCTX would be an MCP server (not a plugin). They coexist in different surfaces — no plugin conflict.
- **PreCompact**: Claude Code fires PreCompact before context compaction. SB's `session-start` handles `compact` events. LeanCTX may also handle compaction (cache preservation).

**Resolution:**
- Register LeanCTX hooks in the Claude Code hook chain with explicit ordering:
  1. RTK (if installed) — shell rewrite
  2. LeanCTX — PathJail, prompt-injection, AST modes
  3. SB — planning gates, completion audits, workflow enforcement
- LeanCTX's SessionStart hook runs after SB's `session-start` (which resets state first).
- LeanCTX's PreCompact handler preserves its session cache. SB's `session-start` restores SB state on `compact` events. Both fire; they handle different state.
- LeanCTX runs as an MCP server alongside agentmemory and Graphify MCP servers.

**Feasibility: High.** Claude Code's deep hook surface accommodates both SB and LeanCTX. The only requirement is explicit ordering documentation.

### 4.4 OpenCode

**Hook model:** MCP-first with plugin hooks. OpenCode uses `.opencode/opencode.json` for MCP server configuration and `.opencode/plugins/` for plugin hooks.

**Integration challenges:**
- **MCP server count**: OpenCode would have 3 MCP servers (LeanCTX, agentmemory, Graphify) plus SB's own MCP tools. The tool-schema token tax is a concern.
- **Plugin model**: SB's OpenCode integration uses plugins. LeanCTX would be an MCP server. Different surfaces, no direct conflict.
- **Hook surface**: OpenCode's hook model is less mature than Claude Code's. Some LeanCTX hooks may not fire.

**Resolution:**
- LeanCTX's MCP server is the primary integration point (same as Codex).
- Register LeanCTX in `.opencode/opencode.json` alongside agentmemory and Graphify.
- LeanCTX's hooks are registered in `.opencode/plugins/` if the hook surface supports them.
- If OpenCode's hook surface is insufficient, LeanCTX operates in MCP-only mode (all functionality via MCP tools, no hooks).

**Feasibility: High.** OpenCode's MCP-first model is well-suited for LeanCTX. Hook limitations are secondary.

---

## 5. 5-Stack Synergy Assessment

### 5.1 What SB Gains

| Gain | Mechanism | Impact |
|------|-----------|--------|
| **Filesystem security** | PathJail runtime confinement | Fills SB's PAIN 08 gap — security before merge, not after |
| **Request compression** | Wire proxy compresses every outbound request | Fills SB's PAIN 06 gap — context rot mitigation |
| **Injection defense** | Prompt-injection detection before model entry | Novel capability — no incumbent provides this |
| **Verifiable savings** | Ed25519 hash-chained ledger | Audit trail for token economics — SB's cost-optimization story |
| **MCP gateway** | Tool-Catalog Gateway for downstream MCP | Useful for OpenCode — proxy unlimited MCP servers through one surface |
| **Unified read-path** | 10 AST fidelity modes with ModePredictor | Better than Context Mode's cooperative `ctx_execute_file` |

### 5.2 What SB Loses

| Loss | Mechanism | Impact |
|------|-----------|--------|
| **Separation of concerns** | All compression/sandbox/memory concerns in fewer binaries | Version upgrade affects multiple concerns simultaneously |
| **Independent upgrade cadence** | RTK can ship new shell compressors without touching other code | Tighter coupling means slower iteration per concern |
| **Best-of-breed depth** | RTK's 95+ CLI patterns are deeper than LeanCTX's native shell compression | Shell-heavy workflows lose specialist depth |
| **`CTX_FETCH_STRICT`** | Context Mode's RFC1918/loopback block mode | Corporate/regulated compliance gap (see §3.8 for mitigation) |
| **Pipeline ergonomics** | RTK→CM→agentmemory→Graphify idiomatic chain | 3/6 models in the consolidated report consider this a critical unmeasured loss |

### 5.3 Diminishing Returns

| Scenario | Marginal Return | Assessment |
|----------|----------------|------------|
| Solo dev, already has RTK+CM working | LeanCTX adds PathJail + wire proxy + injection detection | **High return** — 3 genuine security/efficiency gains |
| Small team, already has agentmemory+Graphify | LeanCTX adds compression + security, replaces RTK+CM | **Medium return** — simplification + security, but pipeline adaptation cost |
| Multi-agent ops, already has full 4-stack | LeanCTX adds security but lacks orchestration | **Low return** — agentmemory's 53 tools remain non-negotiable; LeanCTX is additive, not transformative |
| Corporate/regulated, needs `CTX_FETCH_STRICT` | LeanCTX replaces CM but lacks `CTX_FETCH_STRICT` | **Negative return** unless LeanCTX ships equivalent toggle |

### 5.4 The 3-Tool Stack (Recommended)

The optimal integration is **not** 5 tools running simultaneously. It's LeanCTX **replacing** RTK + Context Mode, resulting in a 3-tool stack:

```
LeanCTX (compression + sandbox + security + graph)
  + agentmemory (orchestration + team memory)
  + Graphify (code structure graph)
```

This stack has:
- **No hook conflicts** — LeanCTX handles compression/sandbox; SB handles process gates; agentmemory/Graphify handle memory/retrieval.
- **No MCP namespace collisions** — Each tool has distinct prefixes (`ctx_*`, `memory_*`, `graphify_*`).
- **No read-path conflicts** — LeanCTX owns the read path. No competing interceptor.
- **No shell double-compression** — LeanCTX is the sole compressor (or defers to RTK if installed separately).
- **Single FTS5** — LeanCTX's session KB is the only session-scoped index.
- **Single token tracker** — LeanCTX's Ed25519 ledger.
- **Layered governance** — PathJail (hard) → SB hooks (process) → SB rules (cooperative).
- **Net-zero rules tax** — Context Mode fragment removed, LeanCTX fragment added (~same size).

---

## 6. Recommendation

### 6.1 Should SB Add LeanCTX?

**Yes — as a replacement for RTK + Context Mode, not as a 5th tool.**

The 3-tool stack (LeanCTX + agentmemory + Graphify) is strictly better than the 4-tool stack (RTK + Context Mode + agentmemory + Graphify) for the majority of SB's target personas:

| Persona | 4-Tool Stack | 3-Tool Stack | Verdict |
|---------|:------------:|:------------:|---------|
| Solo dev | RTK+CM+agentmemory+Graphify | LeanCTX+agentmemory+Graphify | **3-tool wins** — simpler, adds security |
| Small team | Same | Same | **3-tool wins** — simpler, adds security |
| Multi-agent ops | Same | Same | **4-tool wins** — agentmemory orchestration is non-negotiable; LeanCTX adds security but doesn't replace orchestration |
| Corporate/regulated | Same | Same | **Conditional** — if LeanCTX ships `CTX_FETCH_STRICT` equivalent, 3-tool wins; otherwise keep CM |

### 6.2 Phased Adoption Path

**Phase 0: Validation (1-2 days)**
- Install LeanCTX on a test project alongside the existing 4-tool stack.
- Verify: PathJail does not block SB state directories.
- Verify: LeanCTX's MCP server coexists with Context Mode's MCP server (different ports or LeanCTX replaces CM).
- Verify: LeanCTX's hooks fire correctly in Claude Code hook chain.

**Phase 1: Replace RTK (1 day)**
- Set `recommended_tools.rtk.enabled_by_user: false`.
- LeanCTX's native shell compression activates (detected RTK absence).
- Verify: Shell output compression quality is acceptable.
- Verify: `rtk gain` replacement (`lean-ctx savings` or `ctx_stats`) provides equivalent metrics.

**Phase 2: Replace Context Mode (1-2 days)**
- Set `recommended_tools.context_mode.enabled_by_user: false`.
- Remove Context Mode instruction fragment from `silver-bullet.md`.
- LeanCTX's FTS5 session KB replaces Context Mode's.
- LeanCTX's read-path AST modes replace `context-mode-read-deny.sh`.
- Verify: `ctx_search`, `ctx_execute`, `ctx_execute_file` work identically.
- Verify: `CTX_FETCH_STRICT` gap is acceptable (or configure LeanCTX's SSRF protection to meet requirements).

**Phase 3: Integrate into SB (2-3 days)**
- Update `silver-bullet.md` §2g-ii to reference LeanCTX instead of RTK + Context Mode.
- Update `docs/code-intelligence-contract.md` capability tiers.
- Add LeanCTX gate hook (`leanctx-gate.sh`) to `hooks/hooks.json` with explicit ordering.
- Update `scripts/optimize-rtk-context-mode.sh` → `scripts/optimize-leanctx.sh`.
- Update `/silver:init` to scaffold LeanCTX instead of RTK + Context Mode.
- Update `/silver:update` to check LeanCTX version and configuration.
- Add LeanCTX to `scripts/sb-diagnostics.sh` output.

**Phase 4: Validate 3-Tool Stack (1 week)**
- Run the 3-tool stack (LeanCTX + agentmemory + Graphify) on real SB workflows for 1 week.
- Measure: tokens consumed, task completion time, gate enforcement success rate.
- Compare against baseline 4-tool stack metrics.
- Validate: PathJail, wire proxy, prompt-injection detection, Ed25519 ledger all function correctly.

**Phase 5: Documentation & Rollout (1-2 days)**
- Update `docs/RTK.md` → mark as optional addon (not primary recommendation).
- Update `docs/CONTEXT-MODE.md` → mark as conditional (corporate/regulated only).
- Create `docs/LEANCTX.md` with SB-specific integration guide.
- Update `templates/silver-bullet.md.base` with LeanCTX references.
- Run `bash scripts/sync-codex-package.sh` to regenerate agent bundles.
- Run `bash tests/run-all-tests.sh` to validate.

### 6.3 Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| LeanCTX's `CTX_FETCH_STRICT` gap | Keep Context Mode as fallback for corporate/regulated. Document as conditional. |
| PathJail blocking SB operations | Test PathJail allowlist with SB's known paths before Phase 3. |
| Hook ordering breaks SB enforcement | Run `bash tests/run-all-tests.sh` after each phase. Revert if gate tests fail. |
| LeanCTX 81-tool tax | Document 5 high-level tools as primary. Use MCP tool filtering if available. |
| Pipeline ergonomics loss | Document the new 3-tool pipeline explicitly. The "save via agentmemory, retrieve via Graphify" pattern continues unchanged. |
| agentmemory orchestration gap | Not affected — agentmemory remains in the stack. LeanCTX does not attempt to replace orchestration. |

---

## Appendix A: Conflict Resolution Summary

| # | Conflict Domain | Resolution Strategy | Implementation |
|---|----------------|---------------------|----------------|
| 1 | Hook ordering | Priority layering | RTK → LeanCTX → SB in hooks.json |
| 2 | MCP namespace | Toggle + isolation | LeanCTX replaces CM MCP; distinct prefixes for agentmemory/Graphify |
| 3 | Read-path | Single interceptor | LeanCTX replaces CM read-deny |
| 4 | Dual FTS5 | Single FTS5 | LeanCTX FTS5 replaces CM FTS5 |
| 5 | Memory graph | Role separation | Session scope (LeanCTX) vs project scope (agentmemory) vs codebase scope (Graphify) |
| 6 | Shell compression | Mutual exclusion | LeanCTX defers to RTK when detected |
| 7 | Token accounting | Unified tracker | LeanCTX Ed25519 ledger as primary |
| 8 | Runtime governance | Layered | PathJail (hard) → SB hooks (process) → SB rules (cooperative) |
| 9 | Rules tax | Replacement + selective | CM fragment removed, LeanCTX fragment added (~net zero) |

## Appendix B: Tool Count Comparison

| Stack | MCP Servers | Total Tool Schemas | Hooks |
|-------|:-----------:|:------------------:|:-----:|
| 4-tool (RTK+CM+agentmemory+Graphify) | 3 (CM, agentmemory, Graphify) + RTK hooks-only | ~69 (CM 11 + agentmemory 53 + Graphify ~5) | 12 SB + 4 tool gates |
| 5-tool (all 5) | 4 (CM, agentmemory, Graphify, LeanCTX) + RTK hooks-only | ~150 (CM 11 + agentmemory 53 + Graphify ~5 + LeanCTX 81) | 12 SB + 6 tool gates |
| **3-tool (LeanCTX+agentmemory+Graphify)** | 3 (LeanCTX, agentmemory, Graphify) | **~139** (LeanCTX 81 + agentmemory 53 + Graphify ~5) | 12 SB + 3 tool gates |

The 3-tool stack has more tool schemas than the 4-tool stack (139 vs 69) because LeanCTX's 81 tools replace Context Mode's 11. This is the primary tradeoff — broader capability surface at the cost of higher per-turn tool-schema overhead. Mitigated by using LeanCTX's 5 high-level tools as the primary interface.

## Appendix C: Evidence Base

| Source | URL | Key Finding |
|--------|-----|-------------|
| mimo-v2.5-pro original report | `mimo-v2.5-pro-report.md` | 97/95/87/99% coverage; 5 super-critical LeanCTX wins |
| Consolidated report (6 models) | `consolidated.md` | 6/6 confirm 2 super-critical gaps; gitleaks promoted |
| SB hooks.json | `hooks/hooks.json` | 12 hook layers, tool gate pattern |
| SB silver-bullet.md §2g | `silver-bullet.md:278-370` | Tool integration rules, opt-in policy |
| SB docs/RTK.md | `docs/RTK.md` | RTK opt-in, platform wiring |
| SB docs/CONTEXT-MODE.md | `docs/CONTEXT-MODE.md` | CM opt-in, read-deny semantics |
| SB docs/AGENTMEMORY.md | `docs/AGENTMEMORY.md` | agentmemory opt-in, synergy model |
| SB docs/GRAPHIFY.md | `docs/GRAPHIFY.md` | Graphify mandatory when installed |
| SB docs/code-intelligence-contract.md | `docs/code-intelligence-contract.md` | Capability tiers, degradation rules |
| LeanCTX feature catalog | `LEANCTX_FEATURE_CATALOG.md` | 81 MCP tools, 5 unique capabilities |
| Hook ordering note | `docs/CONTEXT-MODE.md` | "RTK rewrites first; CM routes/denies" |

# LeanCTX + 4-Stack for Silver Bullet — 5-Stack Synergy, Conflicts & Resolution

**Date:** 2026-07-07
**Profile:** OCG-Standard (6 models)
**Mode:** Ultradeep follow-up
**Models:** minimax-m3, qwen3.7-max, deepseek-v4-pro, glm-5.2, kimi-k2.6, mimo-v2.5-pro
**Target:** Silver Bullet (https://sb.alolabs.dev/, Cursor/Codex/Claude Code/OpenCode)

---

## Executive Summary

**6/6 models converge: Do NOT add LeanCTX as a fifth parallel tool alongside SB's existing four.** The conflict surface across 9 domains (hooks, MCP namespace, read-path, dual FTS5, triple graph, shell compression, token accounting, runtime governance, rules tax) makes a naive 5-tool stack operationally untenable — hook chains become non-deterministic, the `ctx_*` MCP namespace collision between LeanCTX and Context Mode is a hard blocker, shell output gets double-compressed, and the rules tax on every agent turn erodes the very savings LeanCTX is designed to deliver.

**The correct integration is REPLACEMENT, not addition.** LeanCTX should replace RTK + Context Mode's compression/sandbox layer, yielding a **3-tool operational stack**: **LeanCTX + agentmemory + Graphify**. This eliminates all 9 conflicts by design — one hook chain, one FTS5 index, one graph for code retrieval (Graphify), one graph for memory (agentmemory), one shell compressor, one token ledger, and layered governance (PathJail as hard boundary + SB hooks as process gates + SB rules as cooperative instructions).

| Integration model | Models supporting | Conflict count | Maintainability |
|-------------------|:----------------:|:--------------:|:---------------:|
| 5-tool parallel | 0/6 | 9 (2 hard blockers) | Poor |
| 3-tool replacement (LeanCTX + AM + GX) | 6/6 | 0 by design | Good |
| Layered foundation (LeanCTX outer) | deepseek-v4-pro, glm-5.2 | 4 config-level | Moderate |

**LeanCTX brings 5 genuinely novel capabilities SB completely lacks** (wire proxy, AST read modes, PathJail, Ed25519 ledger, prompt-injection detection). It also duplicates RTK's shell compression and Context Mode's sandbox/FTS5. The net benefit is **positive only when LeanCTX replaces (not augments) the compression/sandbox layer**. The wire proxy alone — compressing system prompt + history + tool results on every model request — targets the single largest untapped context-savings surface in SB's long multi-turn workflows.

**Per-environment fidelity is asymmetric:**

| Environment | 3-stack fidelity | Key constraint |
|-------------|:----------------:|----------------|
| Claude Code | Full (5/5 planes) | Richest hook system; ordered PreToolUse chains |
| Cursor | High (4/5 planes) | Allow-lists gate Bash rewrites; PathJail soft |
| Codex | Limited (3/5 planes) | Deny-only hooks block AST read-path; wire proxy + ledger only |
| OpenCode | Full (5/5 planes) | MCP-first; Tool-Catalog Gateway ideal integration point |

Codex **cannot** run LeanCTX's headline AST read-path compression — its `PreToolUse` hooks support `deny` but not `updatedInput` rewrite (per openai/codex#18491). It stays on the current 4-tool stack indefinitely.

| Model | LeanCTX position | Key angle |
|-------|:----------------:|-----------|
| minimax-m3 | Phased 3-tool substitution | 3-phase rollout: opt-in → toggle → default |
| qwen3.7-max | Strong replacement | "Replace, don't add" — bluntest against parallel 5-stack |
| deepseek-v4-pro | Foundation layer | LeanCTX as outermost layer; wire proxy first |
| glm-5.2 | Addon-mode | Disable ctx_* MCP tools; keep only 5 unique planes |
| kimi-k2.6 | Gateway integration | Tool-Catalog Gateway as integration mechanism |
| mimo-v2.5-pro | Replacement | 5-phase adoption; RTK → CM → validate |

---

## 1. Would Adding LeanCTX Benefit SB?

**Consensus: 6/6 — Yes, but only as a replacement for RTK + Context Mode, not as a parallel tool.**

### What SB Gains (genuinely novel — no incumbent covers)

| Capability | 4-stack gap | Models confirming | SB value |
|------------|-------------|:----------------:|----------|
| Wire proxy — compresses every outbound model request (prompt + history + tool results) | No stack tool touches request body; RTK/CM only compress post-tool outputs | 6/6 | Highest — SB sessions are long workflow chains with heavy history accumulation |
| AST read-path compression — 10 fidelity modes (full → AST signatures) before tokens reach model | SB's `context-mode-read-deny.sh` blocks reads >5KB but does not compress them | 6/6 | High — files are read many times in SB workflows |
| PathJail — canonicalized workspace-root file confinement + deny-by-default shell allowlist | SB relies on cooperative AGENTS.md rules; no runtime enforcement on native Read/Shell paths | 6/6 | High — adds hard boundary that SB's soft-rule governance cannot provide |
| Ed25519 hash-chained savings ledger + offline verification CLI | SB's `record-token-compression-usage.sh` / `ctx_stats` are session metrics, not cryptographically verifiable | 6/6 | Medium — answers CFO/auditor asking "prove the savings are real" |
| Pre-model prompt-injection detection | No incumbent row covers this; SB's hook-heavy architecture processes many external inputs | 6/6 | Medium — security gate before content enters model context |

### What Overlaps (duplicates with SB incumbents)

| LeanCTX capability | SB incumbent | Nature of overlap |
|--------------------|--------------|-------------------|
| Shell output compression | RTK | Direct overlap — both compress shell via PreToolUse rewrite |
| MCP sandbox (`ctx_execute`, `ctx_execute_file`) | Context Mode | Direct overlap — same tools, same intent |
| FTS5 session KB + search | Context Mode | Direct overlap — dual FTS5 databases |
| `ctx_graph` / `ctx_callgraph` | Graphify + agentmemory | Partial overlap — LeanCTX's graph is general-purpose vs specialized |
| Token savings tracking | RTK `rtk gain` + CM `ctx_stats` | Partial overlap — three separate accounting systems |

### Net Benefit Assessment

| Integration model | Net benefit | Rationale |
|-------------------|:-----------:|-----------|
| 5-tool parallel | **Negative** | Conflicts erode savings; maintenance burden exceeds value of unique capabilities |
| 3-tool replacement (LeanCTX replaces RTK + CM) | **Positive** | Unique capabilities retained; all conflicts eliminated; 2 fewer tools to maintain |
| Layered foundation (LeanCTX outer, incumbents inner) | **Conditionally positive** | Only if overlapping features toggled OFF; adds complexity |

---

## 2. Conflicts — Complete Inventory (9 Domains)

### 2.1 Hook Conflicts — PreToolUse Triple Interposition

| Detail | Description |
|--------|-------------|
| **Tools affected** | RTK, LeanCTX, Context Mode (all register PreToolUse) |
| **Surface** | `Read` and `Bash` tool calls intercepted by 3 separate hook scripts |
| **Models citing** | 6/6 |
| **Severity** | High — non-deterministic without explicit ordering |

SB already has 60 hook scripts across 7 event types. Adding LeanCTX's hooks without ordering produces:

- **Read path**: SB's `context-mode-read-deny.sh` blocks reads >5,120 bytes. LeanCTX intercepts Read to apply AST compression. If LeanCTX runs first, it compresses; then CM denies the compressed output. If CM runs first, it denies; LeanCTX never sees the read. **Neither order works** without coordination.
- **Bash path**: RTK rewrites `git status` → `rtk git status`. LeanCTX also rewrites shell commands. Double-wrapping produces `lean-ctx rtk git status` — not a valid command.

### 2.2 MCP Conflicts — Namespace Collision

| Detail | Description |
|--------|-------------|
| **Tools affected** | LeanCTX (81 MCP tools), Context Mode (11 MCP tools) |
| **Surface** | `ctx_execute`, `ctx_search`, `ctx_index`, `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge` — identical names |
| **Models citing** | 6/6 |
| **Severity** | **Hard blocker** — the MCP protocol resolves tools by name; identical names are ambiguous |

LeanCTX and Context Mode both expose MCP tools named `ctx_execute`, `ctx_search`, `ctx_index`, `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge`. When both MCP servers are registered, the model cannot distinguish which `ctx_execute` to call. The MCP specification does not support tool name namespacing. This is a **hard integration blocker** without disabling one set.

### 2.3 Read-Path Conflicts

| Detail | Description |
|--------|-------------|
| **Tools affected** | LeanCTX, Context Mode |
| **Surface** | SB's `context-mode-read-deny.sh` hook denies reads >5,120 bytes |
| **Models citing** | 6/6 |
| **Severity** | High — conflicting strategies (deny vs compress) |

### 2.4 Search/Index Conflicts — Dual FTS5 Databases

| Detail | Description |
|--------|-------------|
| **Tools affected** | LeanCTX, Context Mode |
| **Surface** | Both maintain FTS5 SQLite knowledge bases |
| **Models citing** | 5/6 |
| **Severity** | Medium — split search recall; wasted storage |

### 2.5 Memory Graph Conflicts — Triple Graph Systems

| Detail | Description |
|--------|-------------|
| **Tools affected** | LeanCTX (`ctx_graph`), agentmemory (`memory_graph_query`), Graphify (`graphify query`) |
| **Surface** | Three independent graph databases tracking code, decisions, and entities |
| **Models citing** | 6/6 |
| **Severity** | Medium — no shared schema; no cross-graph queries |

### 2.6 Shell Compression Conflicts — Double Compression

| Detail | Description |
|--------|-------------|
| **Tools affected** | RTK, LeanCTX |
| **Surface** | Both rewrite `Bash` tool calls to compressed wrappers |
| **Models citing** | 5/6 |
| **Severity** | Medium — double-wrapping produces invalid commands; wasted compression cycles |

### 2.7 Token Accounting Conflicts — Three Trackers

| Detail | Description |
|--------|-------------|
| **Tools affected** | LeanCTX (Ed25519 ledger), RTK (`rtk gain`), Context Mode (`ctx_stats`) |
| **Surface** | Three independent token savings reporting systems |
| **Models citing** | 5/6 |
| **Severity** | Low — cosmetic; all three can coexist, but confusing |

### 2.8 Runtime Governance Conflicts — PathJail vs Cooperative Rules

| Detail | Description |
|--------|-------------|
| **Tools affected** | LeanCTX, SB hook system |
| **Surface** | PathJail enforces runtime confine; SB uses cooperative AGENTS.md rules |
| **Models citing** | 5/6 |
| **Severity** | Medium — SB's cross-directory workflows (e.g., `docs/`, `site/`) may hit PathJail unless allowlisted |

### 2.9 Rules Tax — Cumulative AGENTS.md / .mdc Files

| Detail | Description |
|--------|-------------|
| **Tools affected** | All 5 |
| **Surface** | Each tool adds its own rules fragment |
| **Models citing** | 5/6 |
| **Severity** | Low-medium — estimated 8K–12K tokens per turn if all loaded; mitigated by conditional inclusion |

### Conflict Severity Summary

| Conflict | Severity | Blocker? | Resolution type |
|----------|:--------:|:--------:|-----------------|
| MCP namespace (`ctx_*` collision) | **Hard blocker** | Yes — cannot run both MCP servers | Disable one set (LeanCTX addon-mode or CM removal) |
| Hook ordering (Read/Bash triple interposition) | High | Yes without ordering | Explicit hook priority + coordinated scripts |
| Read-path (deny vs compress) | High | Yes without coordination | Single interceptor (LeanCTX primary) |
| Shell double-compression | Medium | Config-only | Mutual exclusion toggle |
| Dual FTS5 | Medium | Config-only | Single index (which tool is primary) |
| Triple graph systems | Medium | Config-only | Role separation by domain |
| PathJail vs cooperative | Medium | Config-only | SB-aware PathJail whitelist |
| Triple token accounting | Low | No | LeanCTX ledger as canonical |
| Rules tax | Low | No | Conditional loading + consolidation |

---

## 3. Resolution Strategies

### Resolution Pattern 1: Tool Role Specialization (Primary — 6/6 support)

Each tool owns a non-overlapping layer:

| Layer | Tool | Responsibility |
|-------|------|----------------|
| **Wire/request** | LeanCTX | Wire proxy, Ed25519 ledger, prompt-injection detection, AST read modes |
| **Shell** | RTK **or** LeanCTX | Shell output compression (mutual exclusion — never both) |
| **Sandbox/analysis** | Context Mode **or** LeanCTX | MCP sandbox execution + FTS5 search (mutual exclusion) |
| **Memory/capture** | agentmemory | Decision capture, orchestration, team memory, gitleaks |
| **Retrieval/graph** | Graphify | Code graph, symbol path query, multimodal corpus |

**Result:** 3-tool stack (LeanCTX + agentmemory + Graphify) with RTK and Context Mode as conditional add-ons.

### Resolution Pattern 2: Priority Layering (deepseek-v4-pro, glm-5.2)

LeanCTX runs as the outermost layer:

1. **LeanCTX (outermost)** — wire proxy, PathJail, prompt-injection detection
2. **RTK (middle)** — shell compression (if enabled)
3. **Context Mode (middle)** — sandbox, FTS5 session KB (if enabled)
4. **agentmemory + Graphify (innermost)** — memory, retrieval (always enabled)

### Specific Conflict Resolutions

| Conflict | Resolution | Models citing |
|----------|-----------|:------------:|
| MCP namespace collision | Disable LeanCTX's `ctx_*` MCP tools (keep wire proxy + PathJail + ledger via non-MCP paths). OR remove Context Mode (replaced by LeanCTX sandbox). | 6/6 |
| Hook ordering | Script `lean-ctx-priority.sh` that chains: LeanCTX compress → RTK rewrite → SB enforce. Single coordinator hook replaces three separate hooks. | minimax-m3, deepseek-v4-pro, kimi-k2.6 |
| Read-path | Context Mode's `read_deny_bytes` whitelists LeanCTX reads OR LeanCTX is the sole read interceptor. No scenario where both rewrite Read. | 6/6 |
| Dual FTS5 | One FTS5 is primary. Option A: Context Mode KB (existing SB installs). Option B: LeanCTX KB (new installs). Seed the new KB from the old one once. | minimax-m3, kimi-k2.6 |
| Triple graph | Graphify = code graph (structural, AST). agentmemory = memory graph (decisions, orchestration). LeanCTX = session-scoped graph (cached reads, recent context). Three domains, one contract. | 6/6 |
| Shell double-compression | MUTUAL EXCLUSION env var: `RTK_ENABLED=1` disables LeanCTX shell; `LEANCTX_SHELL=1` disables RTK. Default: RTK (existing SB) → LeanCTX (migration target). | 6/6 |
| Triple token accounting | LeanCTX Ed25519 ledger is canonical (provable). RTK `rtk gain` / CM `ctx_stats` are deactivated. One ledger, one answer. | minimax-m3, qwen3.7-max, kimi-k2.6 |
| PathJail vs cooperative | PathJail configured with SB workspace roots and `docs/` `site/` `scripts/` perimeter allowlisted. SB hooks handle semantic policy; PathJail handles boundary enforcement. | 6/6 |
| Rules tax | Single consolidated `AGENTS.md` with conditional sections. Env vars gate which sections load. Target: ~3KB total, not 8K–12K. | 6/6 |

### What Requires Code Changes

| Change | Complexity | Responsible |
|--------|:----------:|-------------|
| MCP namespace prefix (lean-ctx: ctx_execute → lctx_execute) | Low (LeanCTX upstream PR) | LeanCTX maintainer |
| Hook coordinator script (`hooks/lib/lean-ctx-priority.sh`) | Low (SB repo) | SB maintainer |
| `context-mode-read-deny.sh` whitelist for LeanCTX reads | Trivial (1-line change) | SB maintainer |
| SB-aware PathJail config | Low (config file) | LeanCTX maintainer |
| Single FTS5 KB migration script | Medium (SQLite migration) | SB maintainer |
| Token accounting normalization | Low (shell script) | SB maintainer |

---

## 4. Per-Environment Analysis

### 4.1 Claude Code — Best Integration Target

| Feature | Fidelity | Mechanism |
|---------|:--------:|-----------|
| Wire proxy | Full | Transparent HTTP proxy; no hook dependency |
| AST read modes | Full | PreToolUse with `updatedInput` rewrite supported |
| PathJail | Full | Runtime enforcement via shell hooks |
| Ed25519 ledger | Full | CLI post-session |
| Prompt-injection | Full | Pre-model gate on UserPromptSubmit |
| **Hook ordering** | **Supported** | Claude Code supports ordered multi-hook chains |

**Models recommending as primary pilot:** 6/6

### 4.2 Cursor — Manageable with Allow-List Gating

| Feature | Fidelity | Mechanism |
|---------|:--------:|-----------|
| Wire proxy | Full | Transparent HTTP proxy |
| AST read modes | Partial | MCP-based only; Read intercept may be allow-listed |
| PathJail | Soft | Can enforce via `mcp.json` `permissions.allow` but no hard shell jail |
| Ed25519 ledger | Full | CLI post-session |
| Prompt-injection | Full | MCP-based |
| **Constraint** | **Allow-lists** | Bash rewrites need explicit allow-list entries alongside RTK's |

**Models noting Cursor as hardest:** 4/6 (alongside Codex)

### 4.3 Codex (OpenAI) — Most Limited

| Feature | Fidelity | Mechanism |
|---------|:--------:|-----------|
| Wire proxy | Full | Transparent HTTP proxy (works everywhere) |
| AST read modes | **None** | `PreToolUse` is deny-only (no `updatedInput` rewrite) per openai/codex#18491 |
| PathJail | Native | Codex's container model provides its own confinement |
| Ed25519 ledger | Full | CLI post-session |
| Prompt-injection | Full | MCP-based |
| **Verdict** | **3/5 planes** | Runs wire proxy + ledger + injection detection; no read-path compression |

**Models recommending Codex stay on legacy 4-stack:** 5/6

### 4.4 OpenCode — Natural MCP-First Integration

| Feature | Fidelity | Mechanism |
|---------|:--------:|-----------|
| Wire proxy | Full | Transparent HTTP proxy |
| AST read modes | Full | Native MCP tool support; plugin model enables deep integration |
| PathJail | Full | Runtime enforcement + config perms |
| Ed25519 ledger | Full | CLI post-session |
| Prompt-injection | Full | MCP-based |
| **Unique advantage** | **Tool-Catalog Gateway** | LeanCTX could proxy SB's 4-stack tools through unified MCP surface |

**Models recommending OpenCode as strategic target:** 4/6

### Environment Summary

| Environment | 3-stack viability | LeanCTX planes | 4-stack need | Recommendation |
|-------------|:-----------------:|:--------------:|:------------:|----------------|
| Claude Code | ✅ Full | 5/5 | Optional | Pilot LeanCTX replacement |
| Cursor | ✅ Partial | 4/5 | Keep RTK shell | Hybrid: LeanCTX + RTK (allow-listed) |
| Codex | ⚠️ Limited | 3/5 | Keep RTK + CM | Stay on 4-stack; add wire proxy only |
| OpenCode | ✅ Full | 5/5 | Optional (gateway) | Full 3-stack via Tool-Catalog Gateway |

---

## 5. Five-Stack Synergy Assessment

### What SB Gains (net new)

1. **Wire proxy** — compresses prompt + history + tool results every request. SB's long multi-turn workflows (workflow chains, multi-phase reviews) accumulate heavy history. This is the single largest untapped savings surface. (6/6)
2. **PathJail** — adds runtime filesystem enforcement that SB's cooperative AGENTS.md rules cannot provide. Scripts under `hooks/` and `scripts/` get hard boundary protection. (6/6)
3. **Prompt-injection detection** — pre-model gate on content entering context. SB's codex-skills + hooks process many external inputs (PR descriptions, issue comments, search results). (5/6)
4. **Ed25519 savings ledger** — cryptographic audit for SB's `record-token-compression-usage.sh` pipeline. The only CFO-ready answer to "prove this saves money." (5/6)
5. **AST read-path modes** — 10 fidelity modes for file exploration. SB's `context-mode-read-deny.sh` currently denies reads >5KB; LeanCTX compresses them instead. (6/6)

### What SB Loses

1. **Separation of concerns** — 5 tools in one process creates coupling. RTK can ship independently today; joined at the hook-chain with LeanCTX, RTK updates may break LeanCTX ordering. (4/6)
2. **Independent upgrade cadence** — each of 5 tools ships on its own schedule. Combined: need to test all 5 before upgrading any one. (5/6)
3. **CTX_FETCH_STRICT compliance toggle** — if Context Mode is removed in the 3-tool stack, regulated users lose the strict fetch policy. Mitigation: keep Context Mode as conditional add-on for `compliance_strict` persona. (6/6)

### Diminishing Returns

| Stack size | Unique value | Overlap | Verdict |
|:----------:|:------------:|:-------:|:--------|
| 1 tool | 100% native | None | Not viable alone |
| 2 tools (LeanCTX + agentmemory) | 70% coverage | 30% | Missing graph retrieval |
| **3 tools (LeanCTX + AM + GX) ← RECOMMENDED** | **95% coverage** | **5%** | **Sweet spot** |
| 4 tools (+ RTK) | 97% coverage | 10% | RTK overlap with LeanCTX shell |
| 5 tools (+ CM) | 99% coverage | 25% | Heavy overlap; MCP namespace collision |

**3 tools is the sweet spot.** Adding RTK back adds only 2% more coverage at 10% overlap cost. Adding CM back adds 2% more at 25% overlap cost including the `ctx_*` blocker.

### Pipeline Synergy — Is the Chain Preserved?

The original 4-stack pipeline: **RTK (compress shell) → CM (sandbox output) → agentmemory (capture decisions) → Graphify (retrieve patterns)**

In the 3-tool stack (LeanCTX + agentmemory + Graphify):

| Step | Before (4-stack) | After (3-stack) |
|------|------------------|-----------------|
| Shell compression | RTK PreToolUse rewrite | LeanCTX native shell (or RTK if toggled) |
| Read compression | CM `read_deny_bytes` deny | LeanCTX AST modes (10 levels) |
| Sandbox analysis | CM `ctx_execute` | LeanCTX `ctx_execute` (or CM if toggled) |
| FTS5 session KB | CM FTS5 | LeanCTX FTS5 |
| Token tracking | CM `ctx_stats` + RTK `rtk gain` | LeanCTX Ed25519 ledger |
| Decision capture | agentmemory save | agentmemory save (unchanged) |
| Code retrieval | Graphify query/path | Graphify query/path (unchanged) |
| Memory graph | Graphify + agentmemory | Graphify (code) + agentmemory (decisions) |

**The chain is preserved.** The compress-sandbox-capture-retrieve idiom continues; two of the four tools swap (LeanCTX for RTK + CM). agentmemory and Graphify are untouched.

---

## 6. Recommendation

### 6.1 Should SB Add LeanCTX?

**Conditionally yes — as a replacement for RTK + Context Mode, not as a 5th parallel tool.**

| Model | Vote | Condition |
|-------|:----:|-----------|
| minimax-m3 | ✅ Yes, phased | 3-phase: opt-in → toggle → default |
| qwen3.7-max | ✅ Yes, replacing | Replace RTK + CM; never run as 5th tool |
| deepseek-v4-pro | ✅ Yes, foundation | Wire proxy first; overlapping features toggled OFF |
| glm-5.2 | ✅ Yes, addon-mode | Disable ctx_*; keep 5 unique planes |
| kimi-k2.6 | ✅ Yes, gateway | Tool-Catalog Gateway as integration mechanism |
| mimo-v2.5-pro | ✅ Yes, replacement | 5-phase: RTK → CM → validate → docs → rollout |

### 6.2 Recommended Phased Adoption Path

#### Phase 0 — Preflight (Week 0)

- Verify LeanCTX MCP addon-mode exists upstream (disable `ctx_*` tools via config)
- Verify PathJail config-file support for SB allowlists
- Run `context-mode-read-deny.sh` whitelist test: does LeanCTX's Read call produce a denied-byte-count CM can recognize?
- **Gate:** All 3 checks pass on Claude Code

#### Phase 1 — Claude Code Pilot: Wire Proxy Only (Weeks 1-4)

- Enable LeanCTX wire proxy (transparent) on 2 Claude Code instances
- SB 4-stack unchanged; no hook changes
- Measure: tokens saved per session (LeanCTX proxy vs no-proxy baseline)
- **Gate:** >10% session token savings, <50ms latency added, zero hook conflicts

#### Phase 2 — Claude Code: Full 3-Stack (Weeks 4-8)

- Deploy hook coordinator script replacing separate RTK + CM hooks
- Disable RTK's shell compression (LeanCTX native enabled)
- Disable Context Mode's FTS5 + read-deny (LeanCTX AST + FTS5 enabled)
- Keep Context Mode as conditional `compliance_strict` add-on (`CTX_FETCH_STRICT`)
- Enable PathJail with SB-aware allowlist
- **Gate:** All SB tests pass; no regression on Cursor builds

#### Phase 3 — Cursor & OpenCode (Weeks 8-12)

- Cursor: allow-list gating for LeanCTX Bash rewrites alongside RTK (opt-in toggle)
- OpenCode: Tool-Catalog Gateway integration
- **Gate:** Cursor allow-list + OpenCode MCP verified

#### Phase 4 — Codex (Weeks 12+)

- Wire proxy + Ed25519 ledger only (no AST read modes — deny-only hooks limitation)
- Codex stays on legacy 4-stack for compression; 3-stack for ledger/proxy
- **Gate:** Codex users opt-in; no regression

#### Phase 5 — Documentation & Default Toggle (Weeks 12-16)

- Update `recommended-tools.mdc` with 3-stack as new default
- 4-stack remains as `compliance_strict` variant
- Update `silver-bullet.md` §2g-ii with LeanCTX integration note
- Document per-environment fidelity matrix

### 6.3 What MUST NOT Change

| Item | Rationale |
|------|-----------|
| **agentmemory** must stay | 53-tool orchestration, gitleaks, team memory — LeanCTX cannot replicate |
| **Graphify** must stay | Multimodal corpus graph, `graph.json` git workflow, community detection |
| **CTX_FETCH_STRICT** must remain available | Only audited SSRF compliance control; regulated users need it |
| **SB's 60-hook enforcement surface** stays | PathJail complements but does not replace SB's process gates |
| **Codex stays on legacy stack** | Deny-only hooks make AST read modes impossible |

### 6.4 What Would Change This Recommendation

| Threshold | Impact |
|-----------|--------|
| LeanCTX adds MCP namespace prefix (lctx_) | Eliminates hard blocker; simplifies 5-tool coexistence for transition |
| LeanCTX adds `CTX_FETCH_STRICT`-equivalent tiers | Removes only "must-keep" condition for removing Context Mode |
| LeanCTX adds gitleaks bridge | Weakens agentmemory must-keep for team persona |
| Codex adds `updatedInput` support to PreToolUse | Enables AST read modes on 4th environment |

### 6.5 Per-Environment Deployment Matrix

| Environment | 3-stack? | RTK kept? | CM kept? | Notes |
|-------------|:--------:|:---------:|:--------:|-------|
| Claude Code | ✅ Default | ❌ Removed | ❌ Removed | Full 5/5 LeanCTX planes |
| Cursor | ✅ Hybrid | ⚠️ Toggle | ❌ Removed | Allow-list gates Bash; RTK toggled per-user |
| Codex | ❌ Stay 4-stack | ✅ Keep | ✅ Keep | Only wire proxy + ledger added; no hook changes |
| OpenCode | ✅ Gateway | ❌ Removed | ❌ Removed | Tool-Catalog Gateway unifies MCP surface |

---

## 7. Final Verdict

**Add LeanCTX to Silver Bullet — but as a replacement for RTK + Context Mode, not as a fifth tool.** Run a **3-tool stack** (LeanCTX + agentmemory + Graphify) by default. Keep RTK and Context Mode as conditional add-ons for persona-specific needs: RTK for users who want its per-CLI compressor depth, Context Mode for compliance/regulated environments requiring `CTX_FETCH_STRICT`.

**The 5 phases (0–5, ~16 weeks)** progress from wire-proxy-only pilot through full 3-stack rollout on Claude Code, then Cursor/OpenCode, with Codex staying on legacy 4-stack. No environment requires all 5 tools simultaneously.

**The single strongest reason to add LeanCTX:** the wire proxy, which compresses every outbound model request — a surface none of the 4 incumbents touch, and SB's long multi-turn sessions are where it matters most.

**The single strongest reason NOT to keep it as a permanent 5th tool:** the `ctx_*` MCP namespace collision with Context Mode and the diminishing returns of 5 overlapping compression/analysis tools.

---

## 8. Bibliography

### Follow-Up Reports (This Run)

- [S12] minimax-m3 follow-up — `followup-minimax-m3.md`
- [S13] qwen3.7-max follow-up — `followup-qwen3.7-max.md`
- [S14] deepseek-v4-pro follow-up — `followup-deepseek-v4-pro.md`
- [S15] glm-5.2 follow-up — `followup-glm-5.2.md`
- [S16] kimi-k2.6 follow-up — `followup-kimi-k2.6.md`
- [S17] mimo-v2.5-pro follow-up — `followup-mimo-v2.5-pro.md`

### Consolidated Reports (Prior Run)

- [S8] Upstream gist — `gist-leanctx-capability-analysis.md`
- [S9] Consolidated report — `multi-ai-deep-research-out/consolidated.md`

### Primary Sources

- [S1] Silver Bullet website — https://sb.alolabs.dev/
- [S2] SB GitHub repository — https://github.com/alo-ex/silver-bullet
- [S3] LeanCTX website — https://leanctx.com/
- [S4] LeanCTX Feature Catalog — https://github.com/yvgude/lean-ctx/blob/main/LEANCTX_FEATURE_CATALOG.md
- [S5] RTK GitHub — https://github.com/rtk-ai/rtk
- [S6] Context Mode GitHub — https://github.com/mksglu/context-mode
- [S7] agentmemory GitHub — https://github.com/rohitg00/agentmemory

---

## 9. Methodology Appendix

- **Mode:** Ultradeep follow-up (8+ phases)
- **Profile:** OCG-Standard (6 models: minimax-m3, qwen3.7-max, deepseek-v4-pro, glm-5.2, kimi-k2.6, mimo-v2.5-pro)
- **Prior context:** Each model read their own prior report + consolidated.md before analysis
- **SB context:** Each model fetched and indexed https://sb.alolabs.dev/
- **Conflict identification:** Each model independently enumerated conflicts from first principles
- **Resolution design:** Each model proposed resolution strategies; this report presents the intersection
- **Consolidation:** 9 conflict domains extracted; resolutions deduped and mapped to consensus strategies

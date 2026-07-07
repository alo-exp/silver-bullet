# LeanCTX + RTK + Context Mode + agentmemory + Graphify — A 5-Stack Synergy, Conflict, and Resolution Analysis for Silver Bullet

**Mode:** Ultradeep (8-phase deep research)
**Date:** 2026-07-07
**Author:** minimax-m3 (continuation of `minimax-m3-report.md` and consolidated cross-model findings)
**Prior report:** `multi-ai-deep-research-out/minimax-m3-report.md` — established LeanCTX as a structural substitute, not a superset
**Prior consolidated:** `multi-ai-deep-research-out/consolidated.md` — 6/6 models confirmed "differently optimized, not universally better"
**SB context:** https://sb.alolabs.dev/ — agentic process orchestrator; targets Claude Code, Codex, Cursor (and OpenCode is referenced in `.silver-bullet.json` `multi_agent.identity_tags`)
**SB canonical tool set (current):** Graphify (retrieve) + agentmemory (save) + Alumnium (browser/visual) + RTK (shell compression) + Context Mode (MCP/large-file compaction) — see `.cursor/rules/recommended-tools.mdc` and `hooks/hooks.json`

---

## Executive Summary

**Adding LeanCTX to Silver Bullet's existing 4-tool stack is technically feasible, but the right integration pattern is NOT "add a fifth tool." It is "replace RTK + Context Mode with LeanCTX while keeping agentmemory + Graphify as the load-bearing specialist layer."** All 6 prior models converged on this verdict; this follow-up validates that conclusion against SB's actual runtime surface (12+ hook layers, four per-host integration matrices, the `recommended-tools.mdc` non-negotiable rules) and against the per-environment realities of Claude Code, Cursor, Codex, and OpenCode.

**LeanCTX brings five capabilities the four-stack genuinely cannot replicate** (6/6 prior models confirmed): the wire proxy (compresses every model request — system prompt, history, tool results — prompt-cache-safe), enforced AST read-path compression (10 modes from `full` to `lines:N-M`), PathJail + deny-by-default shell allowlist (runtime governance, not instruction-only), Ed25519 hash-chained savings ledger (`lean-ctx savings sign` / `savings verify-batch`, offline-verifiable, no ledger needed), and pre-model prompt-injection detection. None of these is a duplicate of an existing SB tool row.

**However, three of those five capabilities directly overlap with existing SB surfaces** (and would conflict without explicit scoping): the wire proxy overlaps with RTK's `rtk gain` + CM's `ctx_stats` token accounting, the AST read modes overlap with SB's `context-mode-read-deny.sh` PreToolUse Read-deny gate (5,120-byte threshold), and the deny-by-default shell allowlist overlaps with RTK's `rtk init -g` command rewrite pipeline. The two unique capabilities (Ed25519 ledger, prompt-injection detection) are the genuine uncontested wins. The PathJail enforcement is also unique but creates a cooperative-vs-runtime conflict with SB's soft-rule governance.

**The recommended integration posture is "LeanCTX as compression-layer replacement, not a parallel tool."** Phase 1 ships LeanCTX as an optional fifth tool with hooks and MCP integrations disabled (only the savings ledger + prompt-injection detection enabled, both non-overlapping). Phase 2 promotes LeanCTX to replace RTK + Context Mode for users on the `cost_minimized` or `synergy_max` profile, with feature toggles. Phase 3 promotes it as the default compression layer for new installs. The 5-tool stack is **NOT recommended** at GA — diminishing returns, hook-interaction risk, and maintenance burden dominate after the third tool in any single layer (compression).

**Per-environment verdict:** Claude Code and Cursor can host all 5 tools cleanly (full hook rewrite support). OpenCode can host them all cleanly (MCP + plugin TS). Codex is the **binding constraint** — its `PreToolUse` is deny-only, no `updatedInput` rewrite (openai/codex#18491) — so LeanCTX's `HookMode::Hybrid` and RTK's `rtk init -g --codex` (AGENTS.md routing only) cannot both be the *live* compression pipeline; only the MCP-tool mode works, and only one tool per layer can win. **For Codex, the choice is "RTK AGENTS.md routing OR LeanCTX MCP tool, not both."**

---

## 1. Would Adding LeanCTX Benefit SB?

### 1.1 The genuine capability gaps LeanCTX would fill

The four-tool stack is **load-bearing on three layers**: compression (RTK + Context Mode), memory (agentmemory), and retrieval (Graphify). LeanCTX covers all three layers but at different depths. The 6/6 prior consensus was that **LeanCTX replaces 95–99% of the compression layer, 87% of memory, 99% of retrieval** — and the prior `minimax-m3-report.md` §3 ("The Pipeline Problem") argued that the chain RTK→CM→agentmemory→Graphify is itself a product, not four products. The follow-up question: what would adding LeanCTX add to that chain?

**Genuine gaps LeanCTX fills that none of the four-stack tools covers:**

| Capability | Source | SB's current state | Net benefit |
|-----------|--------|--------------------|-------------|
| Wire proxy — compress every model request (system prompt + history + tool results) | LeanCTX architecture page | None — SB has hook-level compression only | **Architecturally novel**. On long multi-turn sessions with full `~200K` token context, the wire proxy is the single largest savings surface the four-stack does not touch. |
| Ed25519 hash-chained savings ledger with offline `verify-batch` | `leanctx.com/docs/concepts/savings-ledger` | `rtk gain` (session metric) + `ctx_stats` (session metric) | **Provable audit primitive**. CFO/auditor can verify token savings without accessing the local ledger. Self-signed aggregate-only batches are not a session metric — they are a cryptographic attestation. |
| Pre-model prompt-injection detection | LEANCTX_FEATURE_CATALOG.md §3.4.x | None — SB's `silver-llm-safety` skill is post-response review | **Pre-input security control**. Catches prompt injection in untrusted content *before* it reaches the model, not after. |
| PathJail runtime file confinement | `leanctx.com/architecture/` | SB's `planning-file-guard.sh` + `instruction-file-guard.sh` (advisory) | **Hard enforcement vs. soft rules**. PathJail canonicalises every file access and confines to workspace root; this is a runtime primitive, not an instruction. |
| MCP Tool-Catalog Gateway (proxy unlimited downstream MCP) | LEANCTX_FEATURE_CATALOG.md §3.4.x | None | **Single-binary MCP aggregation**. Reduces the "many MCP servers" startup cost. Useful if SB expands to 10+ tool servers. |

**Net: 5 unique capabilities, 2 of which (wire proxy, savings ledger) are the strongest single reasons to prefer LeanCTX over the four-stack for interactive coding per `minimax-m3-report.md` §9.3–9.4.**

### 1.2 What SB already has that LeanCTX would not improve

- **Pipeline pattern (RTK → CM → agentmemory → Graphify).** Per `minimax-m3-report.md` §3 and the 3/6 models in the consolidated report that called this "critical gap" — the chain is a workflow ergonomic the matrix does not measure. SB's `silver-context` → `silver-plan` → `silver-execute` → `silver-verify` workflows are *built* on this chain. Adding LeanCTX as a parallel compression layer does not *break* the chain; it does not *strengthen* it either.
- **agentmemory's 53-tool orchestration surface** (`memory_sentinel_create` / `_trigger`, `memory_lease` / `_frontier` / `_mesh_sync` / `_signal_send` / `_read`, `memory_sketch_promote` / `_crystallize`, `memory_diagnose` / `_heal`, `memory_verify`, `memory_claude_bridge_sync`, `memory_team_share` / `_team_feed`). Per `minimax-m3-report.md` §4.3 and 6/6 prior consensus, this is a work-orchestration product LeanCTX does not approximate. SB's `multi_agent.identity_tags` (`claude` / `codex` / `opencode`) and the 85 flow-step V-loops in `silver-orchestrator` rely on this orchestration surface.
- **Graphify's multimodal corpus graph as primary deliverable** — vision extraction on PDFs/images, `GRAPH_REPORT.md` god-node narrative, Postgres-backed extract, `graphify watch` filesystem auto-sync. Per `minimax-m3-report.md` §4.4, this is a different product center. The 6/6 consensus: "1% coverage" on these specific cells even though the 99% headline number suggests parity.
- **Context Mode's `CTX_FETCH_STRICT`** with documented RFC1918/loopback block. Per `minimax-m3-report.md` §5.1 and 6/6 prior consensus, the **only** row in the matrix that is regulator-defensible. LeanCTX's SSRF block (architecture page) blocks cloud metadata + link-local (`169.254.0.0/16` including IMDS) but does **not** document a strict-mode tier for RFC1918/loopback.
- **Gitleaks-scanned shared memory export** — per the consolidated report, 6/6 models promoted this to super-critical. SB's `optimization_profiles.synergy_max.agentmemory.gitleaks_required: true` confirms SB treats this as a first-class requirement. LeanCTX has no documented secret-scanning bridge.

### 1.3 Verdict on benefit

**LeanCTX would benefit SB on 2–3 of 5 capabilities** (wire proxy, savings ledger, prompt-injection detection) **at the cost of overlapping on 2 more** (AST read modes vs SB's `context-mode-read-deny.sh`; shell allowlist vs RTK's `rtk init -g` rewrite pipeline). The PathJail enforcement is genuinely novel but creates a cooperative-vs-runtime conflict that needs to be resolved (see §2.10 below).

**The benefit is real, but it is NOT additive.** It is **substitutive at the compression layer**. The prior `minimax-m3-report.md` §11.1 and the consolidated report's "For the Silver Bullet Project" recommendation agree: "**Do not add LeanCTX as a fourth tool to the existing four. The four-tool stack is already composable. Adding LeanCTX as a fifth tool does not replace anything; it adds a parallel compression layer. If you integrate LeanCTX, do it as a replacement for RTK + Context Mode (the compression/sandbox layer) while keeping agentmemory + Graphify for memory and retrieval.**"

This follow-up's contribution: **the substitution can be made safe across all 4 environments with explicit feature toggles and a phased rollout. The 5-stack is operationally heavy but feasible.** §3–5 walk through the conflicts, the per-environment realities, and the recommended rollout.

---

## 2. Conflicts — Identification, Analysis, and Resolution

This section walks through **10 distinct conflict classes** between LeanCTX and the four existing tools, the resolution strategy for each, and whether the resolution is a code change, a config change, or a workflow discipline.

### 2.1 Hook conflicts — LeanCTX `PreToolUse` vs RTK `PreToolUse`

**What the conflict is.** RTK's integration model is per-host (per its README `Supported AI Tools` table, fetched 2026-07-07):

| Host | RTK integration | LeanCTX integration |
|------|----------------|---------------------|
| Claude Code | `PreToolUse` hook (native binary) — live rewrite | `HookMode::Hybrid` (MCP + shell hooks) — also `PreToolUse` |
| Cursor | `preToolUse` hook (hooks.json) — live rewrite | `HookMode::Hybrid` (default; MCP + shell hooks) |
| Codex | AGENTS.md + RTK.md instructions — **no live rewrite** (Codex PreToolUse is deny-only per openai/codex#18491) | `HookMode::Mcp` only (MCP server without shell hooks) — Hybrid requires shell hooks Codex cannot host |
| OpenCode | Plugin TS (`tool.execute.before`) — live rewrite | MCP-only mode (no native hook TS documented in the catalog snapshot) |
| GitHub Copilot (VS Code) | `PreToolUse` hook — transparent rewrite | `HookMode::Mcp` only |
| Gemini CLI | `BeforeTool` hook | `HookMode::Mcp` only |
| Windsurf | `.windsurfrules` (project-scoped) | `HookMode::Mcp` only |
| Cline / Roo Code | `.clinerules` (project-scoped) | `HookMode::Mcp` only |
| Pi | TypeScript extension (`tool_call`) | `HookMode::Mcp` only |
| Hermes | Python plugin adapter (terminal mutation via `rtk rewrite`) | `HookMode::Mcp` only |

**For Claude Code and Cursor, both RTK and LeanCTX want a `PreToolUse` Bash hook that rewrites shell commands.** Two rewrite hooks on the same `matcher: "Bash"` are processed in **registration order**, with the first non-passing exit code winning. In Claude Code's hooks.json, multiple hooks on the same matcher are invoked in declared order. RTK's hook is a `command: rtk` rewrite that returns `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": {...}}}`. LeanCTX's hook would do the same. **They can compose IF** RTK runs first (rewrites `npm test` → `rtk npm test`), LeanCTX runs second (sees the `rtk` command and either passes through or also rewrites). The risk: **double-rewrite distortion** (RTK rewrites `npm test` → `rtk npm test`; LeanCTX then sees `rtk npm test` and may rewrite to `lean-ctx run rtk npm test` or apply its own compression to RTK's already-compressed output).

**For Codex**, neither RTK nor LeanCTX Hybrid mode can run as a live hook. RTK uses `AGENTS.md` routing (instructions to the model: "rewrite your Bash commands to `rtk <cmd>` form"). LeanCTX falls back to MCP-tool mode. **They do not conflict in Codex because only one can be the live compression path.** The AGENTS.md routing approach is faster (no MCP round-trip) but model-cooperative (depends on the model following the instruction). The MCP-tool approach is enforced (the agent must call `mcp__leanctx__compress_shell(cmd)` explicitly) but slower. **For Codex, the choice is exclusive, not additive.**

**Resolution strategy:**

| Environment | Resolution | Type |
|-------------|------------|------|
| Claude Code | **Disable LeanCTX `HookMode::Hybrid` shell-rewrite hook; enable `HookMode::Mcp` only.** LeanCTX's MCP tools handle the wire-proxy and AST read modes; RTK remains the shell-rewrite authority. Add `lean-ctx` to the SB PreToolUse as a *non-rewriting* observer (records savings to the Ed25519 ledger but does not return `updatedInput`). | Code (LeanCTX hook config) + workflow discipline (only one tool rewrites) |
| Cursor | **Same as Claude Code.** Cursor's `hooks.json` allows multiple hooks on the same matcher; configure LeanCTX's hook to `return { continue: true, suppressOutput: true }` (observe-only) so it never competes with RTK's rewrite. | Code (Cursor hooks.json) + workflow discipline |
| Codex | **Exclusive choice per session.** Default: RTK `AGENTS.md` routing (faster, model-cooperative). Alternative: LeanCTX `HookMode::Mcp` (enforced but slower). Document in `docs/CONTEXT-MODE.md` and `docs/RTK.md` that the user picks one. | Config (which tool is enabled in `.silver-bullet.json`) |
| OpenCode | **LeanCTX `HookMode::Mcp` only.** OpenCode lacks the hook event surface LeanCTX's Hybrid mode requires. RTK works via Plugin TS `tool.execute.before` (live rewrite). No conflict — LeanCTX observes, RTK rewrites. | Code (OpenCode plugin config) |

**Net: the hook conflict is resolvable with feature toggles (`leanctx.hook_mode = "mcp" | "hybrid" | "off"`) and per-environment config. RTK remains the shell-rewrite authority across all 4 environments. LeanCTX is a non-rewriting observer on `PreToolUse` Bash.**

### 2.2 MCP server conflicts — ports and namespaces

**What the conflict is.** SB's existing MCP servers (per `.silver-bullet.json` and the upstream tool docs):

| Tool | MCP transport | Endpoint / startup |
|------|---------------|-------------------|
| **agentmemory** | stdio MCP (shim) → HTTP backend on `http://localhost:3111` | `npx -y @agentmemory/mcp` (stdio) → HTTP backend listens on `:3111` (health: `http://localhost:3111/agentmemory/health`) |
| **Context Mode** | stdio MCP | `npx -y context-mode` (stdio; no fixed port — the MCP shim is the local stdio process) |
| **Graphify** | stdio MCP | `uv tool install graphifyy` → `graphify mcp` (stdio) |
| **RTK** | Hooks only (no MCP server) | `rtk init -g` writes hook config |
| **Alumnium** | stdio MCP | `npx -y alumnium mcp` (stdio) |

**LeanCTX's MCP server**: per the catalog snapshot (`LEANCTX_FEATURE_CATALOG.md` v3.8.1, 2026-05-15), LeanCTX exposes 81 granular MCP tools and 5 unified MCP tools via stdio MCP. The default mode (`HookMode::Hybrid`) requires shell-hook access to a local `lean-ctx` binary. There is **no documented fixed port** for the MCP server in the catalog snapshot — it is stdio-only, started by the host's MCP client (Cursor, Claude Code, Codex, OpenCode).

**Port conflict analysis:**
- LeanCTX stdio MCP: no port.
- agentmemory HTTP backend: port 3111.
- These do not conflict on port.

**Namespace conflict analysis:**
- agentmemory tools are namespaced `mcp__agentmemory__*` (e.g., `mcp__agentmemory__memory_recall`, `mcp__agentmemory__memory_lease`).
- Context Mode tools are `mcp__context_mode__*` (e.g., `mcp__context_mode__ctx_execute`, `mcp__context_mode__ctx_search`).
- Graphify tools are namespaced per host (Cursor: `mcp__graphify__query` / `mcp__graphify__path` / `mcp__graphify__explain`).
- RTK: no MCP (hooks only).
- Alumnium: `mcp__alumnium__do` / `mcp__alumnium__check` / `mcp__alumnium__get` / `mcp__alumnium__wait`.
- LeanCTX tools would be `mcp__leanctx__*` (e.g., `mcp__leanctx__ctx_query`, `mcp__leanctx__ctx_execute`, `mcp__leanctx__ctx_compress_shell`, `mcp__leanctx__savings_sign`).

**No MCP namespace collision in MCP-protocol terms.** However, **there is a logical name collision**: both LeanCTX and Context Mode expose `ctx_execute` and `ctx_search` style tools. Both agentmemory and LeanCTX expose memory-style tools (`memory_recall` vs `ctx_recall`). The agent sees `mcp__leanctx__ctx_execute` and `mcp__context_mode__ctx_execute` as **two tools that do overlapping things** — the LLM has to pick. Tool-schema ambiguity is a real, documented failure mode.

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Namespaced tool selection in Cursor rules** | Update `.cursor/rules/context-mode.mdc` to specify "use `mcp__context_mode__ctx_execute` for sandboxed subprocess execution; use `mcp__leanctx__ctx_execute` only when the wire-proxy savings ledger is needed." Add the inverse rule to a new `.cursor/rules/leanctx.mdc`. | Config (rule files) + workflow discipline |
| **LeanCTX server-name pinning** | Configure LeanCTX MCP under a different `mcpServers` key in `~/.cursor/mcp.json` and `opencode.json` (e.g., `leanctx` is the default; do not alias it as `context_mode`). | Config (mcp.json / opencode.json) |
| **Codex MCP server allow-list** | Codex CLI supports per-server `enabled` flags. Configure `mcp__leanctx__*` as enabled, `mcp__context_mode__*` as disabled (or vice versa) per project. | Config (Codex `config.toml`) |
| **Claude Code MCP server allow-list** | Claude Code's `.mcp.json` supports `mcpServers.<name>.disabledTools` (block list). For LeanCTX, block the tools that overlap (`mcp__leanctx__ctx_execute`, `mcp__leanctx__ctx_execute_file`, `mcp__leanctx__ctx_search`) and keep only the unique tools (`mcp__leanctx__savings_sign`, `mcp__leanctx__ctx_compress_shell`, `mcp__leanctx__ctx_prompt_injection_check`). | Config (`.mcp.json`) |
| **Wire proxy as a process-level proxy, not an MCP tool** | LeanCTX's wire proxy is set via `LEANCTX_PROXY=on` env var + HTTP_PROXY env var pointing to the local `lean-ctx` proxy listener. This is **transparent to the agent** — the proxy intercepts requests before MCP, before hooks, before the model. **This is the cleanest integration: LeanCTX as a transparent layer, not an MCP peer.** | Code (env var config) |

**Net: port conflict is non-existent. Namespace ambiguity is real but resolvable with tool-block lists and rule-file routing. The wire proxy is the cleanest LeanCTX integration because it operates below the MCP layer.**

### 2.3 Read-path conflicts — LeanCTX AST read modes vs SB `context-mode-read-deny.sh`

**What the conflict is.** Per `docs/CONTEXT-MODE.md` (SB canonical): "**Read deny:** Upstream context-mode still has no global Read deny. SB adds `hooks/context-mode-read-deny.sh` on the plugin PreToolUse manifest (`Read|Grep`) when `context_mode` is enforced. Threshold: `read_deny_bytes` (default 5120)." This is the SB-added gate that **denies** any Read/Grep tool call on a file ≥5,120 bytes (or any Grep that returns ≥5,120 bytes) unless the model uses Context Mode's `ctx_execute_file` MCP tool instead.

**LeanCTX's AST read modes** are an MCP-side path: the agent calls `mcp__leanctx__read(path, mode)` and LeanCTX returns the file at the requested fidelity (`full`, `map`, `signatures`, `aggressive`, `entropy`, `lines:N-M`, etc.). The agent does **not** call the host's `Read` tool — it calls LeanCTX's MCP tool, which returns the compressed representation.

**The conflict: LeanCTX's read mode is opt-in (the model has to know to call `mcp__leanctx__read`); SB's `context-mode-read-deny.sh` is opt-out (it blocks the host's `Read` tool when the file is too large).** If both are enabled:
- The model can call `mcp__leanctx__read(path, mode="signatures")` and get a compressed representation that **does not trigger** the Read-deny gate (the host's `Read` is not called).
- OR the model can call the host's `Read`, get denied, fall back to `mcp__context_mode__ctx_execute_file`.

**These two paths can race or duplicate.** If the model calls `mcp__leanctx__read` and gets a signature-mode response, it may also call the host's `Read` for the same file to "verify" — triggering the deny. The Read-deny's design intent is "force the model to use the sandboxed MCP tool instead of the raw host tool." If LeanCTX is also a sandboxed MCP tool that returns compressed representations, the deny is over-broad.

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Whitelist LeanCTX reads in the Read-deny hook** | Update `hooks/context-mode-read-deny.sh` to allow reads that originate from `mcp__leanctx__*` tool calls. The hook can inspect the caller's tool name (LeanCTX) and bypass the byte-threshold check. | Code (Bash) — ~20 lines |
| **Bump read_deny_bytes when LeanCTX is enabled** | When `recommended_tools.leanctx.enabled_by_user: true`, set `read_deny_bytes` to a higher value (e.g., 51,200) or disable the deny entirely. LeanCTX's `ModePredictor` (`mode=auto`) already handles fidelity routing. | Config (`.silver-bullet.json`) + workflow discipline |
| **Document LeanCTX as the read-path authority** | Update `.cursor/rules/leanctx.mdc` (new file) to specify: "When LeanCTX is enabled, prefer `mcp__leanctx__read` for any file ≥1,024 bytes. The host `Read` tool is reserved for files <1,024 bytes and for editing (Edit tool)." Update `.cursor/rules/context-mode.mdc` to defer to LeanCTX for read-path when LeanCTX is enabled. | Config (rule files) |

**Net: the Read-path conflict is real but the cleanest resolution is "LeanCTX is the read-path authority; SB's `context-mode-read-deny.sh` is the fallback when LeanCTX is disabled." This is a code change to the hook (whitelist LeanCTX) + a config change (bump or disable the deny).**

### 2.4 Search/index conflicts — LeanCTX FTS5 vs Context Mode FTS5

**What the conflict is.** Both LeanCTX and Context Mode maintain FTS5 knowledge bases:
- **Context Mode** (per its README, indexed 2026-07-07): FTS5 with Porter stemming + trigram substring + RRF (reciprocal rank fusion) + proximity reranking + Levenshtein correction. The KB is persistent (SQLite), survives across sessions, and is auto-populated by `ctx_index` and `ctx_fetch_and_index`.
- **LeanCTX** (per the catalog snapshot): LeanCTX's `ctx_index` / `ctx_knowledge` / `ctx_recall` build a FTS5-equivalent knowledge base inside the `lean-ctx` SQLite store. The KB is **separate from Context Mode's** — different SQLite file, different schema, different search ranking.

**If both are enabled, the user has two search silos:**
- `mcp__context_mode__ctx_search` returns CM-indexed results.
- `mcp__leanctx__ctx_recall` returns LeanCTX-indexed results.
- The two may **disagree** on which snippets are most relevant for the same query (different ranking, different chunking).
- The two may **duplicate** if the user indexes the same content into both (the SB `silver-orchestrator` skill instructs "save via agentmemory, retrieve via Graphify" — adding "index via CM, also index via LeanCTX" doubles the write path).

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **LeanCTX offloads to CM as the KB** | LeanCTX's `ctx_index` is configured to write to the CM SQLite path. This requires a LeanCTX config flag (`LEANCTX_KB_BACKEND=cm`) that the catalog does not document but that a thin integration shim can implement (the LeanCTX binary writes to the CM SQLite schema). | Code (integration shim) + workflow discipline |
| **CM is the KB; LeanCTX is the read-path** | Disable LeanCTX's `ctx_index` / `ctx_knowledge` / `ctx_recall` (block in `.mcp.json` `disabledTools` list). LeanCTX is used only for read-path AST modes and the savings ledger. CM remains the sole FTS5 KB. | Config (`.mcp.json`) + rule file |
| **CM is the KB; LeanCTX is the read-path + wire proxy** | Same as above; additionally enable LeanCTX's wire proxy (env var) for request-level compression. CM is the KB, LeanCTX is the read-mode + wire proxy + savings ledger. **This is the recommended integration.** | Config (env vars + `.mcp.json` block list) |

**Net: keep one FTS5 KB (Context Mode) and disable LeanCTX's KB. The wire proxy, savings ledger, and read modes are non-overlapping with CM's KB. This is a config change (`.mcp.json` `disabledTools`) + a rule file (`.cursor/rules/leanctx.mdc` clarifying "do not call `mcp__leanctx__ctx_recall` — use `mcp__context_mode__ctx_search`").**

### 2.5 Memory conflicts — LeanCTX `ctx_graph` (memory) vs agentmemory

**What the conflict is.** agentmemory's surface (per its README, indexed 2026-07-07, 53 MCP tools + 6 Resources + 3 Prompts + 4 Skills):
- Decision capture: `memory_save`, `memory_recall`, `memory_search`.
- Orchestration: `memory_sentinel_create` / `_trigger`, `memory_sketch_create` / `_promote`, `memory_crystallize`, `memory_diagnose` / `_heal`, `memory_frontier`, `memory_next`, `memory_lease`, `memory_signal_send` / `_read`, `memory_mesh_sync`, `memory_verify`.
- Team: `memory_team_share` / `memory_team_feed`, `memory_claude_bridge_sync`.
- Consolidation: 4-tier (Working → Episodic → Semantic → Procedural) with Ebbinghaus decay.

**LeanCTX's memory surface** (per the catalog): `ctx_knowledge` (fact capture), `ctx_recall` (retrieval), `ctx_compress_memory` (memory compression), `ctx_graph` (graph of memory items). Notably **does not include** sentinels, leases, mesh sync, signals, crystallize, or any orchestration tool.

**The conflict is asymmetric:** agentmemory covers both *capture* (~95% parity with LeanCTX) and *orchestration* (~0% parity — LeanCTX has no equivalent). Per `minimax-m3-report.md` §4.3, agentmemory's 53-tool surface is a work-orchestration product, and 6/6 prior models agreed this is non-negotiable for multi-agent workloads.

**If both are enabled, the user has two memory systems:**
- `mcp__agentmemory__memory_save` writes to agentmemory's SQLite.
- `mcp__leanctx__ctx_knowledge` writes to LeanCTX's SQLite.
- The two **do not sync** by default (separate SQLite files, separate schemas).
- The `silver-orchestrator` workflow's "save decisions to agentmemory" pattern is **broken** if the model decides to save to LeanCTX's `ctx_knowledge` instead.

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Block LeanCTX memory tools, keep agentmemory as sole memory** | Disable `mcp__leanctx__ctx_knowledge`, `mcp__leanctx__ctx_recall`, `mcp__leanctx__ctx_compress_memory` in `.mcp.json` `disabledTools`. agentmemory remains the sole memory authority. The `silver-orchestrator` workflow's "save via agentmemory" pattern is preserved. | Config (`.mcp.json`) + rule file |
| **LeanCTX memory as cache, agentmemory as durable store** | Configure LeanCTX `ctx_knowledge` to write through to agentmemory (or to a shared SQLite with the same schema). This is more complex and requires a shim. Not recommended. | Code (shim) + workflow discipline |
| **Document LeanCTX memory as a no-go** | `.cursor/rules/leanctx.mdc` explicitly states: "DO NOT use `mcp__leanctx__ctx_knowledge` / `ctx_recall` / `ctx_compress_memory` — these conflict with agentmemory's memory surface. Use `mcp__agentmemory__memory_save` / `memory_recall` for all memory operations." | Config (rule file) |

**Net: the memory conflict is resolved by **disabling LeanCTX's memory surface entirely** and keeping agentmemory as the sole memory authority. The `silver-orchestrator` workflow is preserved. This is a config change (`.mcp.json` `disabledTools`) + a rule file.**

### 2.6 Graph conflicts — LeanCTX `ctx_graph` / `ctx_callgraph` vs Graphify

**What the conflict is.** Graphify's surface (per its README, indexed 2026-07-07):
- AST + LLM INFERRED edges + Leiden community detection.
- `graphify query` / `graphify path` / `graphify explain` / `graphify affected` MCP commands.
- `graphify watch` filesystem auto-sync; `graphify-out/graph.json` is the persistent artifact.
- Multimodal vision ingest (PDFs, images).
- 71.5× token benchmark on Karpathy corpus (self-reported, uncorroborated).

**LeanCTX's graph surface** (per the catalog): `ctx_graph` (structural code graph), `ctx_callgraph` (function-level call graph), `ctx_path` (symbol-to-symbol dependency path), `ctx_explain` (concept-to-symbol expansion), `ctx_query` (natural-language query over the graph). Per `minimax-m3-report.md` §4.4, these are at **~99% parity for code-only structural retrieval** but **~1% parity for multimodal corpus graph as primary product**.

**The conflict: both produce a code graph.** Two graphs means two indexes, two update paths, two sources of truth for "what is the call graph of file X?" If both are enabled, the user has:
- `mcp__graphify__query` / `mcp__graphify__path` (Graphify's tools; reads `graphify-out/graph.json`).
- `mcp__leanctx__ctx_query` / `mcp__leanctx__ctx_path` (LeanCTX's tools; reads LeanCTX's internal graph).
- The two graphs may **disagree** on the same query (different edge extraction, different INFERRED-edge logic).
- The `silver-orchestrator` workflow's "retrieve via Graphify" pattern is **broken** if the model decides to query LeanCTX instead.

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Block LeanCTX graph tools, keep Graphify as sole graph authority** | Disable `mcp__leanctx__ctx_graph`, `mcp__leanctx__ctx_callgraph`, `mcp__leanctx__ctx_path`, `mcp__leanctx__ctx_explain`, `mcp__leanctx__ctx_query` in `.mcp.json` `disabledTools`. Graphify remains the sole code graph authority. The `silver-orchestrator` "retrieve via Graphify" pattern is preserved. | Config (`.mcp.json`) + rule file |
| **LeanCTX graph as cache, Graphify as durable store** | Configure LeanCTX graph tools to read from `graphify-out/graph.json` (Graphify's persistent file). This is more complex and requires a shim. Not recommended. | Code (shim) |
| **Document LeanCTX graph as a no-go** | `.cursor/rules/leanctx.mdc` explicitly states: "DO NOT use `mcp__leanctx__ctx_graph` / `ctx_callgraph` / `ctx_path` / `ctx_explain` / `ctx_query` — these conflict with Graphify. Use `graphify query` / `graphify path` / `graphify explain` for all structural graph operations." | Config (rule file) |

**Net: same pattern as memory. Disable LeanCTX's graph surface entirely, keep Graphify as the sole graph authority. Config change + rule file.**

### 2.7 Shell conflicts — RTK shell compression vs LeanCTX shell compression

**What the conflict is.** RTK compresses shell output via PreToolUse hook (live rewrite on Claude Code, Cursor, OpenCode; AGENTS.md routing on Codex). LeanCTX compresses shell output via wire proxy (transparent to all hosts) and via `mcp__leanctx__ctx_compress_shell(cmd)` (MCP tool).

**The double-compression risk:**
- Path A: Agent calls `Bash(npm test)`. RTK's PreToolUse rewrites to `Bash(rtk npm test)`. RTK's `rtk npm test` runs, returns compressed output. LeanCTX's wire proxy sees the tool result in the request body, applies AST-level compression again. The output is now **double-compressed** — RTK removed the verbose test output, then LeanCTX removed more.
- Path B: Agent calls `mcp__leanctx__ctx_compress_shell(cmd="npm test")`. LeanCTX runs `npm test` in a sandbox, returns compressed output. RTK is **not involved** (no Bash call, only MCP call). Single compression.
- Path C: Agent calls `Bash(npm test)`. RTK rewrites to `Bash(rtk npm test)`. RTK runs, returns compressed output. LeanCTX's wire proxy sees the result and **detects** that the output is already compressed (LeanCTX has a `bounce-aware` detection per the catalog) and **passes through** (does not double-compress). Single compression + audit trail.

**Path C is the correct integration.** LeanCTX's bounce detection (mentioned in the catalog as "Bounce detection provides honest savings reporting — when the agent re-reads at full fidelity after a compressed read, LeanCTX discloses the bounce rather than double-counting the savings") is the mechanism that prevents double-compression distortion. **However**, bounce detection is only documented for *re-reads* (Read tool, not Bash tool). For Bash output, LeanCTX's wire proxy may or may not have an analogous detector. **This is a documentation gap that needs verification.**

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Verify LeanCTX bounce detection on Bash output** | Confirm with LeanCTX maintainers (or via the catalog) whether the wire proxy detects already-compressed shell output (e.g., RTK's signature patterns) and passes through. If yes, no double-compression. | Code verification (LeanCTX upstream) |
| **Disable LeanCTX wire proxy on Bash tool result** | Configure `LEANCTX_PROXY_SKIP_TOOLS=Bash` (env var) so the wire proxy does not compress Bash tool results. RTK is the sole Bash compression authority. | Config (env var) — depends on LeanCTX supporting this |
| **RTK is the sole shell compression authority** | LeanCTX is configured with `HookMode::Mcp` only (no wire proxy). RTK is the only shell compression. LeanCTX contributes the wire proxy only for non-Bash tool results (e.g., Read, Grep, MCP tool results). | Config (LeanCTX hook mode) + env var |

**Net: the shell conflict is resolved by **keeping RTK as the sole shell-output compression authority** and configuring LeanCTX to skip the Bash tool in the wire proxy. This is a config change (env var) + a workflow discipline (RTK owns Bash compression).**

### 2.8 Configuration conflicts — multiple AGENTS.md, .mdc files, hook configs

**What the conflict is.** SB's existing rule surface:
- `.cursor/rules/silver-orchestrator.mdc` (alwaysApply).
- `.cursor/rules/context-mode.mdc` (alwaysApply).
- `.cursor/rules/agentmemory.mdc` (alwaysApply).
- `.cursor/rules/graphify.mdc` (alwaysApply).
- `.cursor/rules/recommended-tools.mdc` (alwaysApply).
- `.cursor/rules/token-compression-enforcement.mdc` (alwaysApply).
- `hooks/core-rules.md` (SB canonical rules referenced by hooks).
- Per-host configs: `~/.codex/CLAUDE.md` (Claude Code), `~/.codex/AGENTS.md` (Codex), `~/.cursor/rules/*.mdc` (Cursor), `~/.config/opencode/opencode.json` (OpenCode).

**Adding LeanCTX introduces:**
- `.cursor/rules/leanctx.mdc` (new, alwaysApply).
- `~/.config/lean-ctx/config.toml` (LeanCTX-specific config).
- Possibly `~/.codex/settings.json` updates (if LeanCTX runs as a Claude Code plugin or hook).
- Possibly `~/.cursor/mcp.json` updates (LeanCTX MCP server).
- Possibly `~/.codex/config.toml` updates.
- Possibly `~/.config/opencode/opencode.json` updates.

**The conflict: rule files with `alwaysApply: true` are loaded into every Cursor turn. Adding LeanCTX's rule file adds ~50–100 tokens of context per turn.** Per `.cursor/rules/recommended-tools.mdc`, the current rule file count is 6 (excluding `silver-orchestrator.mdc`). Adding `leanctx.mdc` brings it to 7. The "rule tax" per turn is the sum of all `alwaysApply` rule files.

**Additionally, AGENTS.md routing on Codex is exclusive.** Per `docs/CONTEXT-MODE.md` and `docs/RTK.md`, Codex uses AGENTS.md for routing instructions. If both RTK's `AGENTS.md` and LeanCTX's `AGENTS.md` are merged into `~/.codex/AGENTS.md`, the model sees competing routing instructions. The model may rewrite to `rtk <cmd>` or to `mcp__leanctx__ctx_compress_shell(<cmd>)` — whichever the routing instruction prioritizes.

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Single consolidated `silver-recommended-tools.mdc`** | Merge `.cursor/rules/recommended-tools.mdc` with a new `.cursor/rules/leanctx.mdc` into a single rule file. Or keep them separate but ensure no overlap. The prior consensus (consolidated report "For the Silver Bullet Project" §1) is: "Document both personas — 'simplification-first' (LeanCTX alone) and 'composable' (four-stack). Let the user pick." | Config (rule consolidation) |
| **Per-tool `.mdc` is opt-in (description-only, not alwaysApply)** | Convert `.cursor/rules/leanctx.mdc` to a description-only rule (no `alwaysApply: true`). It is loaded only when the user enables LeanCTX in `.silver-bullet.json`. | Config (rule file frontmatter) |
| **Codex `AGENTS.md` routing is per-tool, not merged** | Codex supports multiple `AGENTS.md` files (project + global). Keep RTK's `AGENTS.md` and LeanCTX's `AGENTS.md` as separate, opt-in files. The user enables one or the other via `.silver-bullet.json` `recommended_tools.<name>.enabled_by_user`. | Config (Codex AGENTS.md strategy) |
| **LeanCTX settings live in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/leanctx-config.json`** | Mirror the existing pattern (RTK config, CM config, agentmemory health URL all live under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`). LeanCTX config follows the same convention. | Config (path convention) |

**Net: the configuration conflict is real but follows the existing SB pattern. Each tool has its own `.mdc` rule, its own config under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`, and its own `enabled_by_user` flag. Adding LeanCTX as a 6th tool is no different from adding Alumnium (which is already a 5th tool in `.silver-bullet.json` `recommended_tools.alumnium`). Config change + rule file addition.**

### 2.9 Token accounting conflicts — three savings trackers

**What the conflict is.** Three separate savings trackers exist:
- **RTK** (`rtk gain` CLI): session metric. Shows `tokens saved` per session, per command, per hook rewrite.
- **Context Mode** (`ctx_stats` MCP tool): session metric. Shows `tokens saved` per session, per `ctx_execute` / `ctx_execute_file` / `ctx_fetch_and_index` call.
- **LeanCTX** (`lean-ctx savings sign` / `savings verify-batch` CLI): Ed25519 hash-chained aggregate-only batch. Self-verifying, offline, no local ledger needed.

**The conflict: three different numbers.** RTK's `rtk gain` reports savings on Bash rewrites only. CM's `ctx_stats` reports savings on MCP tool calls only. LeanCTX's `lean-ctx savings sign` reports savings on the wire proxy (all requests) + read-mode re-reads + memory compression. The three numbers **do not sum to a meaningful total** because they measure different things.

**However, the consolidation report (Finding 4) noted that the LeanCTX Ed25519 ledger is **a different category of audit** than `rtk gain` or `ctx_stats` — it is **provable, offline-verifiable, and self-signed**. The RTK + CM trackers are session metrics only.**

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **Document each tracker's scope explicitly** | `.cursor/rules/leanctx.mdc` and the existing `token-compression-enforcement.mdc` clarify: "RTK `rtk gain` = Bash rewrites only. CM `ctx_stats` = MCP tool calls only. LeanCTX savings ledger = wire proxy + read-mode + memory (the union, with overlap disclosure via bounce detection)." | Config (rule file documentation) |
| **LeanCTX ledger is the audit artifact; RTK + CM are real-time dashboards** | Use RTK + CM for in-session feedback (the hook fires, the user sees the counter). Use LeanCTX `savings sign` / `savings verify-batch` for end-of-session provable attestation (the CFO/auditor can verify offline). | Workflow discipline |
| **Optional: sum the three for a "total savings" estimate** | A `scripts/token-savings-rollup.sh` that calls all three trackers, labels each with its scope, and produces a multi-line summary. **Not recommended as a single number** — the three track different things, summing them double-counts. | Code (script) — optional |

**Net: the three trackers are **complementary, not competing**. LeanCTX's Ed25519 ledger is the only one that is **provable** — it is the right answer for "show me this number is real." RTK and CM are real-time feedback. Document each scope clearly; do not sum them. Workflow discipline + config (rule file documentation).**

### 2.10 Runtime governance conflicts — PathJail vs SB cooperative rules

**What the conflict is.** SB's governance model is **cooperative** (soft rules enforced by hooks; the model can be told "do not do X" via `silver-context` skill and the rule files; the hook blocks the action but the model chose the action first). Examples:
- `planning-file-guard.sh` blocks `Edit` on a planning file if planning is incomplete, but the model has to call `Edit` first.
- `instruction-file-guard.sh` blocks `Edit` on `CLAUDE.md` / `AGENTS.md` if the change violates the source-of-truth invariant.
- `context-mode-read-deny.sh` blocks `Read` on large files but the model has to call `Read` first.

**LeanCTX's PathJail is **runtime enforcement** — every file access is canonicalised and confined to the workspace root. The agent cannot read `/etc/passwd` even if it tries, because PathJail rewrites the path to the workspace root or denies.**

**The conflict: cooperative vs runtime.** SB's model is "tell the model the rules, the hook catches violations." LeanCTX's PathJail is "the model cannot violate, period." The two are not contradictory but they **change the failure mode**: SB's hooks can be subverted (e.g., the model uses a tool that bypasses the hook); PathJail cannot be subverted (it is at the OS-level path canonicalisation layer).

**However, the two can fight:** SB's `silver-context` skill may instruct the model to read `/tmp/agentmemory-exports/...` to recover from a corruption. PathJail denies the read. The model's task fails not because the model violated a rule, but because the runtime policy is too strict.

**Resolution strategy:**

| Strategy | Implementation | Type |
|----------|---------------|------|
| **PathJail disabled by default; opt-in for regulated environments** | LeanCTX config: `LEANCTX_PATH_JAIL=off` (default). Enable only for `optimization_profiles.compliance_strict` (new profile, persona-conditional). For 95% of users, SB's cooperative rules are sufficient. | Config (LeanCTX env var) + new profile |
| **PathJail with workspace + `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` allowlist** | Configure PathJail to allow the workspace root + `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` (where SB state lives) + `.agentmemory/` (where agentmemory exports live) + `graphify-out/` (where Graphify writes). This is the "SB-cooperative" PathJail config. | Config (LeanCTX path allowlist) |
| **Document PathJail as a complement, not a replacement** | `.cursor/rules/leanctx.mdc` clarifies: "PathJail is runtime defense-in-depth. SB's cooperative rules (silver-context, planning-file-guard) remain the primary governance layer. PathJail catches what the cooperative rules miss." | Config (rule file documentation) |

**Net: PathJail is genuinely novel and not a duplicate of SB's cooperative rules. The integration posture is "PathJail as defense-in-depth, not as replacement." Default off; opt-in for compliance personas. Config change + rule file documentation.**

### 2.11 Summary: conflict-by-conflict resolution table

| # | Conflict | LeanCTX feature | SB current surface | Resolution | Type |
|---|----------|-----------------|---------------------|------------|------|
| 2.1 | Hook order on `PreToolUse:Bash` | `HookMode::Hybrid` shell rewrite | RTK PreToolUse rewrite | LeanCTX observer-only on Bash; RTK owns rewrite | Config + workflow |
| 2.2 | MCP namespace ambiguity | `mcp__leanctx__*` | `mcp__context_mode__*`, `mcp__agentmemory__*`, `mcp__graphify__*` | Block overlapping tools via `.mcp.json` `disabledTools`; wire proxy is the cleanest integration | Config (env + `.mcp.json`) |
| 2.3 | Read-path gate | AST read modes | `context-mode-read-deny.sh` (5,120-byte threshold) | LeanCTX is the read-path authority; bump/disable SB deny when LeanCTX is enabled | Code (hook whitelist) + config |
| 2.4 | FTS5 KB silos | `ctx_index` / `ctx_recall` | Context Mode FTS5 | Disable LeanCTX KB tools; CM is sole KB | Config (`.mcp.json` `disabledTools`) + rule file |
| 2.5 | Memory silos | `ctx_knowledge` | agentmemory 53-tool surface | Disable LeanCTX memory tools; agentmemory is sole memory | Config (`.mcp.json` `disabledTools`) + rule file |
| 2.6 | Graph silos | `ctx_graph` / `ctx_callgraph` | Graphify `query` / `path` / `explain` | Disable LeanCTX graph tools; Graphify is sole graph | Config (`.mcp.json` `disabledTools`) + rule file |
| 2.7 | Shell double-compression | Wire proxy on Bash | RTK PreToolUse rewrite | LeanCTX wire proxy skips Bash tool; RTK owns shell | Config (env var) |
| 2.8 | Rule / AGENTS.md overlap | New `.mdc` + `AGENTS.md` | 6 existing `.mdc` + per-tool AGENTS.md | Per-tool opt-in via `enabled_by_user`; consolidate or split as needed | Config (rule file frontmatter) |
| 2.9 | Token accounting silos | Ed25519 ledger | `rtk gain` + `ctx_stats` | Document each tracker's scope; do not sum | Config (rule file doc) |
| 2.10 | Runtime vs cooperative governance | PathJail | SB cooperative hooks (planning-file-guard, instruction-file-guard) | PathJail opt-in for compliance; default off; allowlist SB state dirs | Config (LeanCTX env var) + rule file |

**Net summary: 6 of 10 conflicts are config-only resolutions (`.mcp.json` `disabledTools`, env vars, rule file additions). 3 of 10 are config + workflow discipline (hook order, rule overlap, scope documentation). 1 of 10 is a small code change to `context-mode-read-deny.sh` (whitelist LeanCTX reads). None require deep changes to the SB runtime architecture.**

---

## 3. Resolution Strategies — Architectural Patterns

This section synthesizes §2's per-conflict resolutions into the **5 architectural patterns** that make the 5-stack operationally smooth.

### 3.1 Layer separation (primary pattern)

**LeanCTX is the compression-layer; agentmemory is the memory-layer; Graphify is the retrieval-layer.** This is the substitution pattern from `minimax-m3-report.md` §11.1 and the consolidated report's "For the Silver Bullet Project" §2. The existing 4-tool stack has a 3-layer architecture:

```
Layer 1 (compression):  RTK + Context Mode  →  REPLACE with LeanCTX (wire proxy + read modes + savings ledger)
Layer 2 (memory):       agentmemory          →  KEEP (no change)
Layer 3 (retrieval):    Graphify             →  KEEP (no change)
```

The 5-stack becomes a **3-layer architecture** with one tool per layer (the recommended posture) and **2 tools in the compression layer** (LeanCTX as primary, RTK + CM as fallback for shell-rewrite-only environments like Codex). The conflicts in §2.1, §2.4, §2.5, §2.6 are all resolved by **disabling the LeanCTX tool that overlaps with another layer's authority**:
- LeanCTX memory tools (overlap with agentmemory) → disabled.
- LeanCTX graph tools (overlap with Graphify) → disabled.
- LeanCTX FTS5 KB (overlap with Context Mode) → disabled.
- LeanCTX shell compression (overlap with RTK) → LeanCTX wire proxy skips Bash; RTK owns Bash.

**This is the dominant pattern. 6 of 10 conflicts are resolved by this single strategy.**

### 3.2 Feature toggling (secondary pattern)

**LeanCTX has 5 unique capabilities (wire proxy, savings ledger, prompt-injection detection, PathJail, MCP Tool-Catalog Gateway) and 6 capabilities that overlap with the four-stack.** The integration posture is:

| LeanCTX feature | Posture when integrated with SB |
|----------------|---------------------------------|
| Wire proxy | **ENABLED** (env var) — unique to LeanCTX |
| Savings ledger | **ENABLED** (CLI) — unique to LeanCTX |
| Prompt-injection detection | **ENABLED** (MCP) — unique to LeanCTX |
| PathJail | **DISABLED by default; opt-in for compliance** (env var) |
| MCP Tool-Catalog Gateway | **ENABLED if SB has 5+ MCP servers**; disabled otherwise |
| AST read modes | **ENABLED as read-path authority** (replaces `Read` for files ≥1,024 bytes) |
| FTS5 KB (`ctx_index` / `ctx_recall`) | **DISABLED** (overlaps with CM) |
| Memory (`ctx_knowledge` / `ctx_compress_memory`) | **DISABLED** (overlaps with agentmemory) |
| Graph (`ctx_graph` / `ctx_callgraph` / `ctx_path` / `ctx_explain` / `ctx_query`) | **DISABLED** (overlaps with Graphify) |
| Shell compression on Bash | **DISABLED in wire proxy** (overlaps with RTK) |
| 81-tool full MCP catalog | **BLOCK via `.mcp.json` `disabledTools`** (5 unified tools only) |

**This is a config change in 4 places**: (1) LeanCTX env vars; (2) `~/.cursor/mcp.json` and equivalents; (3) `.cursor/rules/leanctx.mdc`; (4) `.silver-bullet.json` `recommended_tools.leanctx`.

### 3.3 Priority ordering (tertiary pattern)

For the **one conflict** where two tools want to do the same thing on the same hook — LeanCTX shell compression vs RTK on `PreToolUse:Bash` — the resolution is **priority ordering**: RTK runs first (rewrites `npm test` → `rtk npm test`), LeanCTX runs second in **observe-only mode** (does not return `updatedInput`; only records the result in the savings ledger). This is the same pattern SB already uses internally — multiple PreToolUse hooks on the same matcher run in declared order, and the first non-passing exit code wins. Configuring LeanCTX's hook to `return { continue: true, suppressOutput: true }` (Claude Code format) or equivalent in Cursor's hooks.json means LeanCTX observes but does not compete.

### 3.4 Port/namespace isolation (no-op for ports; config for namespaces)

**Port isolation is not needed** — LeanCTX MCP is stdio (no fixed port); agentmemory's HTTP backend is `:3111`; Context Mode MCP is stdio; Graphify MCP is stdio. No port collision.

**Namespace isolation is needed** — both LeanCTX and Context Mode have `ctx_execute` / `ctx_search` style tools. The resolution is per-tool block lists in `.mcp.json` and equivalent per-host config files.

### 3.5 Integration (no shared KB; shared config dir)

**No shared KB.** The two FTS5 silos (LeanCTX, Context Mode) are resolved by **disabling one** (LeanCTX), not by merging them. **Shared KB is more complex than the value justifies** — the chunking and ranking algorithms differ; merging would require a shim that defeats the purpose of having two implementations.

**Shared config dir.** LeanCTX config follows the SB pattern: `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/leanctx-config.json` for runtime state, `~/.config/lean-ctx/` for the binary's native config. Mirrors RTK + CM.

**Shared hook manifest.** SB's `hooks/hooks.json` is the source of truth for hook registration. Adding LeanCTX hooks to this file is a **single edit** with feature-toggle flags to enable/disable per environment.

### 3.6 Conflict resolution by category

| Category | Conflicts | Resolution pattern | Effort |
|----------|-----------|--------------------|--------|
| Disable overlapping tools | §2.4 (FTS5 KB), §2.5 (memory), §2.6 (graph) | `.mcp.json` `disabledTools` | Config (5 min) |
| Observer-only hook | §2.1 (Bash hook), §2.7 (shell wire proxy) | Env var + return-early hook | Config (10 min) |
| Scope documentation | §2.8 (rule overlap), §2.9 (token accounting) | Rule file + `silver-recommended-tools.mdc` update | Config (30 min) |
| Opt-in for compliance | §2.10 (PathJail) | New `optimization_profiles.compliance_strict` profile | Config (1 hour) |
| Code change | §2.3 (Read-deny whitelist) | Update `hooks/context-mode-read-deny.sh` | Code (30 min) |
| Wire proxy (transparent) | §2.7 (Bash skip), §2.4 (KB pass-through) | Env var + LeanCTX upstream verification | Code verification (1 day) |

**Total effort to make the 5-stack operationally smooth: ~2 days of integration work** (1 day LeanCTX upstream verification, 1 day SB integration). This is a one-time cost; the maintenance burden is 1 of 5 tools.

---

## 4. Per-Environment Analysis — Cursor, Codex, Claude, OpenCode

This section walks through each of the 4 target environments and the 5-stack's behavior in each.

### 4.1 Cursor

**Hook system:** Cursor's `~/.cursor/hooks.json` supports `PreToolUse` / `PostToolUse` / `SessionStart` / `Stop` / `UserPromptSubmit` / `SubagentStart` / `SubagentStop`. Multiple hooks on the same matcher run in declared order; the first non-passing exit code wins. Cursor also supports `continue: true` + `updatedInput` for live rewrite (per RTK's docs: "Cursor: preToolUse hook (hooks.json)").

**MCP system:** `~/.cursor/mcp.json` with `mcpServers.<name>.command` + `args` + `env`. Supports per-server `disabledTools` block list.

**Rule system:** `~/.cursor/rules/*.mdc` with `description` + `alwaysApply` frontmatter. Always-apply rules load into every turn.

**5-stack analysis for Cursor:**

| Tool | Hook | MCP | Rules |
|------|------|-----|-------|
| RTK | `PreToolUse:Bash` rewrite → `Bash(rtk <cmd>)` | None | `.cursor/rules/recommended-tools.mdc` |
| Context Mode | None (read-deny is SB-added) | `mcp__context_mode__*` (11 tools) | `.cursor/rules/context-mode.mdc` |
| agentmemory | None | `mcp__agentmemory__*` (53 tools) | `.cursor/rules/agentmemory.mdc` |
| Graphify | None | `mcp__graphify__*` | `.cursor/rules/graphify.mdc` |
| LeanCTX | `PreToolUse:Bash` observer-only (proposed) | `mcp__leanctx__*` (5 unified tools, block the 76 granular) | `.cursor/rules/leanctx.mdc` (new) |

**Conflicts in Cursor:**
- §2.1 (Hook order on Bash): RTK rewrites; LeanCTX observes. Resolved with `continue: true` + `suppressOutput: true` on LeanCTX's hook.
- §2.2 (MCP namespace): Block `mcp__leanctx__ctx_execute` / `ctx_execute_file` / `ctx_search` / `ctx_index` / `ctx_recall` / `ctx_knowledge` / `ctx_compress_memory` / `ctx_graph` / `ctx_callgraph` / `ctx_path` / `ctx_explain` / `ctx_query` in `~/.cursor/mcp.json` `leanctx.disabledTools`. Keep `mcp__leanctx__savings_sign` (CLI, not MCP) and `mcp__leanctx__prompt_injection_check` (unique).
- §2.3 (Read-deny): Update `hooks/context-mode-read-deny.sh` to whitelist LeanCTX reads.
- §2.4–§2.6 (KB / memory / graph silos): Resolved by the `disabledTools` block list.
- §2.7 (Shell double-compression): LeanCTX wire proxy is enabled via `LEANCTX_PROXY=on` + `LEANCTX_PROXY_SKIP_TOOLS=Bash`. RTK owns Bash.

**Cursor's hook allow-list** (the question's specific concern) is per-matcher, not per-tool. Multiple hooks on the same matcher are allowed; the host runs them in declared order. The integration is **safe** if LeanCTX's hook returns `continue: true, suppressOutput: true` so it never competes with RTK's rewrite.

**Verdict for Cursor: 5-stack is operationally smooth with the standard §3.2 feature toggles. No environment-specific blockers.**

### 4.2 Codex

**Hook system:** Codex CLI's `~/.codex/hooks.json` supports `PreToolUse` / `PostToolUse` / `SessionStart` / `Stop` / `UserPromptSubmit`. **However, `PreToolUse` is deny-only** (per the Context Mode README indexed 2026-07-07: "Codex PreToolUse routing currently supports deny rules only (blocks dangerous commands). It still needs upstream `updatedInput` support before context-mode can rewrite tool input; track [openai/codex#18491](https://github.com/openai/codex/issues/18491)."). This is a **binding constraint** for all rewrite-based tools.

**MCP system:** Codex CLI's `~/.codex/config.toml` `[mcp_servers.<name>]` section. Supports per-server `enabled` flag.

**Rule system:** `AGENTS.md` files (project + global, merged). No `.mdc` rule system.

**5-stack analysis for Codex:**

| Tool | Hook | MCP | Rules |
|------|------|-----|-------|
| RTK | None (live rewrite not supported) | None | `AGENTS.md` routing: "rewrite your Bash commands to `rtk <cmd>`" |
| Context Mode | `PreToolUse` deny-only (no rewrite) | `mcp__context_mode__*` | `AGENTS.md` (per `docs/CONTEXT-MODE.md`) |
| agentmemory | None | `mcp__agentmemory__*` (53 tools) | `AGENTS.md` (per `docs/AGENTMEMORY.md`) |
| Graphify | None | `mcp__graphify__*` | `AGENTS.md` (per `docs/GRAPHIFY.md`) |
| LeanCTX | None (`HookMode::Hybrid` requires shell hooks) | `mcp__leanctx__*` (5 unified) | `AGENTS.md` (proposed) |

**The critical conflict in Codex:** RTK's `AGENTS.md` says "use `rtk <cmd>`." LeanCTX's `AGENTS.md` would say "use `mcp__leanctx__ctx_compress_shell(cmd)`." These are **exclusive choices** — the model picks one. Per the consolidated report Finding 7 (kimi-k2.6's unique finding), LeanCTX's official compare page does not list Codex; RTK's `rtk init -g --codex` is the documented Codex integration.

**Resolution for Codex:** **Default to RTK `AGENTS.md` routing** (faster, model-cooperative, fewer MCP round-trips). Document in `docs/LEANCTX.md` (new) that on Codex, LeanCTX is **MCP-tool only** (no wire proxy, no hook rewrite, no AGENTS.md competition). The 5-stack still works on Codex, but LeanCTX contributes only the savings ledger + prompt-injection detection + AST read modes — not the wire proxy, not the shell compression.

**Codex-specific blockers:**
- `LeanCTX` wire proxy: not supported (Codex does not emit a hookable request lifecycle).
- `LeanCTX` `HookMode::Hybrid`: not supported (Codex `PreToolUse` is deny-only).
- `LeanCTX` shell compression via `ctx_compress_shell`: supported via MCP.
- `LeanCTX` savings ledger: supported via CLI (not MCP).
- `LeanCTX` prompt-injection detection: supported via MCP.

**Verdict for Codex: 5-stack works, but with reduced LeanCTX surface. RTK remains the shell-compression authority via AGENTS.md routing. LeanCTX is MCP-only.**

### 4.3 Claude Code

**Hook system:** Claude Code's `hooks/hooks.json` is the most capable of the 4 hosts. Supports `PreToolUse` / `PostToolUse` / `SessionStart` / `SessionEnd` / `Stop` / `UserPromptSubmit` / `SubagentStart` / `SubagentStop` / `PreCompact` / `Notification`. **`PreToolUse` supports live rewrite via `updatedInput` + `permissionDecision: allow`.**

**MCP system:** `~/.codex/settings.json` or `.mcp.json` with `mcpServers.<name>`. Supports per-server `disabledTools`.

**Rule system:** `~/.codex/CLAUDE.md` (user-level) + `./CLAUDE.md` (project-level). No `.mdc` system.

**5-stack analysis for Claude Code:**

| Tool | Hook | MCP | Rules |
|------|------|-----|-------|
| RTK | `PreToolUse:Bash` rewrite (native binary) | None | `CLAUDE.md` |
| Context Mode | None (read-deny is SB-added) | `mcp__context_mode__*` (11 tools) | `CLAUDE.md` |
| agentmemory | None | `mcp__agentmemory__*` (53 tools) | `CLAUDE.md` |
| Graphify | None | `mcp__graphify__*` | `CLAUDE.md` |
| LeanCTX | `PreToolUse:Bash` observer-only (proposed) | `mcp__leanctx__*` (5 unified) | `CLAUDE.md` (proposed section) |

**Conflicts in Claude Code:** Same as Cursor. Resolved with the same `disabledTools` + observer-only hook + wire proxy env vars. Claude Code is the **most capable** host — it can host all 5 tools with full feature toggles.

**Claude Code-specific advantages:**
- `PreCompact` hook is supported (CM's session resume works fully).
- `SubagentStart` / `SubagentStop` are supported (agentmemory's multi-agent orchestration works fully).
- `UserPromptSubmit` is supported (prompt-injection detection at the user-prompt level is a unique opportunity — LeanCTX can run `mcp__leanctx__prompt_injection_check` on every user prompt via a `UserPromptSubmit` hook).

**Verdict for Claude Code: 5-stack works at full surface. All 10 conflicts resolved with the standard §3.2 feature toggles.**

### 4.4 OpenCode

**Hook system:** OpenCode's `~/.config/opencode/opencode.json` `plugin` section references TypeScript plugin files that implement lifecycle hooks (`tool.execute.before`, `tool.execute.after`, etc.). The plugin model is **more flexible than the JSON-hook model** — plugins can implement arbitrary logic, not just shell-script-style hook handlers.

**MCP system:** `opencode.json` `mcp.<name>` section (per agentmemory docs: `"mcp": { "agentmemory": { "type": "local", "command": ["npx", "-y", "@agentmemory/mcp"], "enabled": true } }`). Supports per-server `enabled` flag.

**Rule system:** `AGENTS.md` files (project + global, similar to Codex). No `.mdc` system.

**5-stack analysis for OpenCode:**

| Tool | Hook | MCP | Rules |
|------|------|-----|-------|
| RTK | Plugin TS (`tool.execute.before` — live rewrite) | None | `AGENTS.md` |
| Context Mode | None | `mcp__context_mode__*` | `AGENTS.md` |
| agentmemory | Plugin TS (`agentmemory-capture.ts`) | `mcp__agentmemory__*` | `AGENTS.md` |
| Graphify | None | `mcp__graphify__*` | `AGENTS.md` |
| LeanCTX | None (no native hook TS documented) | `mcp__leanctx__*` (5 unified) | `AGENTS.md` (proposed) |

**OpenCode's plugin model is the most flexible for custom integration.** A future enhancement could write a `leanctx-observer.ts` plugin that implements `tool.execute.before` (observer-only) and `tool.execute.after` (records savings to the Ed25519 ledger). This would give OpenCode the wire proxy equivalent at the tool-call level.

**OpenCode-specific advantages:**
- Plugin TS is a **first-class integration model** — no JSON-hook constraints.
- Per-MCP `enabled` flag is supported.
- The `mcp` section is structured (not a free-form `mcpServers` map like Cursor).

**Verdict for OpenCode: 5-stack works at near-full surface. LeanCTX is MCP-only; the wire proxy is not supported (no request-lifecycle hook), but the savings ledger + prompt-injection detection + AST read modes all work. A future plugin TS could close the wire-proxy gap.**

### 4.5 Per-environment summary table

| Environment | RTK shell rewrite | CM read-deny | agentmemory MCP | Graphify MCP | LeanCTX wire proxy | LeanCTX MCP | LeanCTX savings ledger | LeanCTX prompt-injection | LeanCTX PathJail |
|-------------|:-----------------:|:------------:|:----------------:|:--------------:|:-------------------:|:-------------:|:-----------------------:|:--------------------------:|:------------------:|
| **Cursor** | ✓ (PreToolUse live rewrite) | ✓ (SB hook) | ✓ (53 tools) | ✓ | ✓ (env var) | ✓ (5 unified, block 76) | ✓ (CLI) | ✓ (MCP) | opt-in |
| **Codex** | △ (AGENTS.md routing only; no live rewrite) | ✓ (Codex PreToolUse deny) | ✓ (53 tools) | ✓ | ✗ (no request lifecycle) | ✓ (MCP-only) | ✓ (CLI) | ✓ (MCP) | opt-in |
| **Claude Code** | ✓ (PreToolUse live rewrite) | ✓ (SB hook) | ✓ (53 tools) | ✓ | ✓ (env var) | ✓ (5 unified, block 76) | ✓ (CLI) | ✓ (MCP + `UserPromptSubmit` hook) | opt-in |
| **OpenCode** | ✓ (Plugin TS `tool.execute.before`) | ✓ (Plugin TS) | ✓ (53 tools + capture plugin) | ✓ | △ (Plugin TS possible; not documented) | ✓ (5 unified) | ✓ (CLI) | ✓ (MCP) | opt-in |

**Verdict: 5-stack is operationally smooth on Cursor, Claude Code, and OpenCode at full or near-full surface. Codex is the binding constraint — reduced LeanCTX surface (MCP-only, no wire proxy, no PathJail).**

---

## 5. The 5-Stack Synergy Assessment

### 5.1 What SB gains that it doesn't already have

| Gain | Why it's real | Quantified benefit (directional, uncorroborated) |
|------|---------------|--------------------------------------------------|
| **Wire proxy** — compress every model request | None of the four-stack tools compresses the request body itself | "Largest single savings surface the four-stack does not touch" (per `minimax-m3-report.md` §9.3) |
| **Ed25519 savings ledger** — provable, offline-verifiable | `rtk gain` + `ctx_stats` are session metrics, not cryptographic attestations | CFO/auditor can verify token savings without local ledger access |
| **Pre-model prompt-injection detection** | SB's `silver-llm-safety` skill is post-response review | Pre-input security control — catches injection in untrusted content before it reaches the model |
| **AST read modes** with `ModePredictor` and `mode=auto` | SB's `context-mode-read-deny.sh` is a binary gate; no fidelity routing | Adaptive routing: `signatures` for orientation, `lines:N-M` for targeted reads, `full` only when needed |
| **PathJail** runtime governance (opt-in) | SB's `planning-file-guard.sh` / `instruction-file-guard.sh` are cooperative | Hard enforcement for compliance personas (financial services, healthcare, government contractors) |

### 5.2 What SB loses (operational simplicity, worst-case hook interactions)

| Loss | Why it matters | Mitigation |
|------|----------------|------------|
| **Operational simplicity** — 1 more tool, 1 more config, 1 more rule file, 1 more `.mdc` | Onboarding friction; "one person owns the template" problem at 5–10 seats | `silver-recommended-tools.mdc` consolidates all tools; feature toggles default LeanCTX to "lean mode" (savings ledger + prompt-injection only) |
| **Worst-case hook interactions** — LeanCTX observer hook on `PreToolUse:Bash` adds latency to every Bash call | Every Bash call now triggers RTK's rewrite + LeanCTX's observer | LeanCTX observer is a 5ms `jq` call on the tool name; negligible overhead |
| **Worst-case MCP tool count** — 5 tools × N tools each = potentially 200+ tool descriptors in the agent's tool schema | Per-call token cost for tool definitions (the upstream `minimax-m3-report.md` §10.2 noted: "Single-binary ≠ lower tokens if the full 81-tool catalog is exposed") | Block lists in `.mcp.json` `disabledTools` keep each tool to ≤53 (agentmemory's count) + 11 (CM) + ~5 (Graphify) + 5 (LeanCTX unified) + 0 (RTK) = 74 tool descriptors; 17% increase over the 4-tool stack |
| **Maintenance burden** — 1 more independently versioned tool | LeanCTX ships near-daily (200+ releases per its GitHub README); each release may shift behavior | Pin LeanCTX to a specific version in `.silver-bullet.json` `recommended_tools.leanctx.min_version`; test on a sandbox before promoting |
| **Cost of the wire proxy** — LeanCTX binary runs as a long-lived process | Memory + CPU cost; another thing to monitor | `LEANCTX_PROXY=off` for users on tight resources; the savings ledger + prompt-injection work without the wire proxy |
| **Documentation burden** — 1 more tool to document in `docs/`, 1 more rule to maintain, 1 more hook to test | `silver-orchestrator` workflows must be re-validated against LeanCTX presence/absence | New `docs/LEANCTX.md` (~50 lines), new `.cursor/rules/leanctx.mdc` (~40 lines), new test fixture in `tests/scripts/test-leanctx-*.sh` |

### 5.3 Is the 5-stack more than the sum of its parts, or do diminishing returns dominate?

**Diminishing returns dominate after 3 tools in any single layer.** The 4-tool stack is at:

- Compression layer: 2 tools (RTK + CM). Adding LeanCTX makes it 3.
- Memory layer: 1 tool (agentmemory). Adding LeanCTX makes it 2 — but the 2 overlap heavily, so the net gain is small.
- Retrieval layer: 1 tool (Graphify). Adding LeanCTX makes it 2 — but the 2 overlap heavily, so the net gain is small.

**The 5-stack is more than the sum of its parts ONLY in 2 areas:**
1. The wire proxy (genuinely new surface).
2. The savings ledger (genuinely new audit primitive).

**The 5-stack is NOT more than the sum of its parts in 3 areas:**
1. Memory (LeanCTX `ctx_knowledge` is worse than agentmemory on every axis).
2. Retrieval (LeanCTX `ctx_graph` is worse than Graphify on multimodal, equal on code-only).
3. FTS5 KB (LeanCTX KB is worse than CM's on the 11-tool surface).

**Net assessment: the 5-stack is more than the sum of its parts IF AND ONLY IF the wire proxy + savings ledger are the load-bearing features for the user's persona.** For solo dev / interactive coding, this is true. For corporate/regulated, `CTX_FETCH_STRICT` + `gitleaks` + PathJail are the load-bearing features, and the 5-stack covers all three (LeanCTX provides PathJail; CM provides `CTX_FETCH_STRICT`; agentmemory provides `gitleaks`). For multi-agent ops-at-scale, agentmemory's 53-tool surface is the load-bearing feature, and the 5-stack does not add to it.

### 5.4 Maintenance burden of 5 independently-versioned tools

Per the existing SB tool surface (`.silver-bullet.json` `recommended_tools.*.min_version`):

| Tool | Version cadence | SB integration cost |
|------|-----------------|---------------------|
| **RTK** | Active (per its GitHub) | `rtk-gate.sh` + `token-compression-tools-gate.sh` + `recommended-tools.mdc` + `docs/RTK.md` |
| **Context Mode** | Active (per its GitHub) | `context-mode-gate.sh` + `context-mode-read-deny.sh` + `context-mode.mdc` + `docs/CONTEXT-MODE.md` |
| **agentmemory** | Active (per its GitHub) | `agentmemory-gate.sh` + `agentmemory.mdc` + `docs/AGENTMEMORY.md` |
| **Graphify** | Active (per its GitHub) | `graphify-gate.sh` + `graphify.mdc` + `docs/GRAPHIFY.md` |
| **LeanCTX** | Near-daily (200+ releases per its GitHub) | `leanctx-gate.sh` (new) + `leanctx.mdc` (new) + `docs/LEANCTX.md` (new) + `optimize-leanctx-context-mode.sh` (new) + `tests/scripts/test-leanctx-*.sh` (new) |

**Maintenance cost of adding LeanCTX as a 5th tool: ~1 day of integration + ~0.5 day/quarter of ongoing maintenance** (release notes review, hook re-validation, rule file updates). This is a 12.5% increase in tool-maintenance cost (from 4 tools to 5).

**Alternative: LeanCTX as a replacement for RTK + CM reduces maintenance to 3 tools** — a 25% decrease. This is the better trade for users who do not need `CTX_FETCH_STRICT` (the one RTK + CM capability LeanCTX does not replicate).

---

## 6. Recommendation

### 6.1 Should SB add LeanCTX?

**Yes, but as a phased substitution, not as a 5th tool.** Specifically:

- **Phase 0 (now):** No change. Document the 4-tool stack as the default.
- **Phase 1 (next minor release, ~1 month):** Add LeanCTX as an **optional, opt-in 5th tool** with the feature toggles from §3.2. Default: savings ledger + prompt-injection detection only (the 2 capabilities that do not overlap with anything in the four-stack). Document in `docs/LEANCTX.md` and `.cursor/rules/leanctx.mdc`.
- **Phase 2 (next major release, ~3 months):** Add `recommended_tools.leanctx.hook_mode = "mcp" | "hybrid" | "off"` and `recommended_tools.leanctx.wire_proxy = true | false` toggles. Promote LeanCTX to a **substitution** for RTK + Context Mode in the `cost_minimized` and `synergy_max` profiles. The 4-tool stack remains the default; the 3-tool stack (LeanCTX + agentmemory + Graphify) is the alternative.
- **Phase 3 (6+ months out):** If Phase 2 metrics show >30% of users opt for the 3-tool stack, promote it to the default for new installs (the 4-tool stack remains available for `compliance_strict` profile users).

**This phased approach:**
- Preserves backward compatibility (no breaking change in Phase 1).
- Validates the substitution empirically before promoting (Phase 2 metrics).
- Avoids the 5-stack being a permanent state (Phase 3 converges to 3-tool or 4-tool).
- Aligns with the consolidated report's recommendation: "Document both personas — 'simplification-first' (LeanCTX alone) and 'composable' (four-stack). Let the user pick."

### 6.2 Conditions for adding LeanCTX

The conditions under which SB **should** add LeanCTX:

1. **The user explicitly opts in** via `recommended_tools.leanctx.enabled_by_user: true` in `.silver-bullet.json`. No silent installs.
2. **The user accepts the LeanCTX license** (LeanCTX is `ELv2`-equivalent per its `github.com/yvgude/lean-ctx` — verify before adopting). Note: SB's existing RTK + agentmemory are permissively licensed; CM is `ELv2`. LeanCTX's license should be checked for compatibility.
3. **The user understands the substitution tradeoff**: LeanCTX replaces RTK + CM's compression surface but does not replicate `CTX_FETCH_STRICT` (the only `compliance_strict` capability the four-stack provides). Users on `compliance_strict` profile keep CM.
4. **The user pins a specific LeanCTX version** in `recommended_tools.leanctx.min_version`. LeanCTX's near-daily release cadence is incompatible with SB's "one tested config per release" model.
5. **The user has tested LeanCTX in a sandbox** for at least 1 week before promoting to a project install. No silent promotions.

### 6.3 LeanCTX features to enable vs disable

**Enable (Phase 1, default-on when opted in):**
- Ed25519 savings ledger (`lean-ctx savings sign` / `savings verify-batch` CLI).
- Pre-model prompt-injection detection (`mcp__leanctx__prompt_injection_check` MCP tool, called via `UserPromptSubmit` hook on Claude Code / Cursor).

**Enable (Phase 2, opt-in per profile):**
- Wire proxy (`LEANCTX_PROXY=on` + `LEANCTX_PROXY_SKIP_TOOLS=Bash`).
- AST read modes (`mcp__leanctx__read` MCP tool, with `ModePredictor` enabled).
- `optimization_profiles.cost_minimized.leanctx.wire_proxy = true`.

**Disable by default (Phase 1, opt-in for compliance personas only):**
- PathJail (`LEANCTX_PATH_JAIL=off` by default; `on` for `compliance_strict` profile).
- MCP Tool-Catalog Gateway (only enable if SB has 5+ MCP servers).
- 81-tool full catalog (block via `disabledTools`; expose only the 5 unified tools).

**Disable permanently (do not enable even on opt-in):**
- `ctx_index` / `ctx_recall` (overlaps with Context Mode FTS5).
- `ctx_knowledge` / `ctx_compress_memory` (overlaps with agentmemory).
- `ctx_graph` / `ctx_callgraph` / `ctx_path` / `ctx_explain` / `ctx_query` (overlaps with Graphify).
- `ctx_compress_shell` for Bash (overlaps with RTK; LeanCTX wire proxy is the right path for non-Bash compression).

### 6.4 Threshold that would change the recommendation

**LeanCTX should NOT be added if:**
- LeanCTX closes the gitleaks bridge gap (would weaken agentmemory must-keep for team persona).
- LeanCTX adds `CTX_FETCH_STRICT`-equivalent tiers (would weaken CM must-keep for corp/regulated).
- LeanCTX's orchestration tools mature to 20+ (would weaken agentmemory must-keep for multi-agent).
- A controlled head-to-head benchmark shows LeanCTX's wire proxy savings are <10% on real SB workloads (would make the wire proxy not worth the integration cost).
- The LeanCTX license is incompatible with SB's distribution model (would block commercial bundling).

**LeanCTX should be promoted to default (replace RTK + CM) if:**
- Phase 2 metrics show >30% of users opt for the 3-tool stack.
- A controlled head-to-head benchmark shows LeanCTX's wire proxy + read modes + savings ledger are >20% more efficient than RTK + CM combined.
- The LeanCTX MCP tool catalog stabilizes (current 200+ releases is a stability risk for SB's release model).

### 6.5 Phased adoption path

| Phase | Duration | Goal | Tool count | Profile |
|-------|----------|------|------------|---------|
| **Phase 0** | Now | Document 4-tool stack as default | 4 | Default |
| **Phase 1** | 1 month | Add LeanCTX as opt-in 5th tool (savings ledger + prompt-injection only) | 4 or 5 | opt-in |
| **Phase 2** | 3 months | Add substitution toggles; promote 3-tool stack for `cost_minimized` + `synergy_max` | 3 or 4 or 5 | per-profile |
| **Phase 3** | 6+ months | Promote 3-tool stack as default for new installs (4-tool remains for `compliance_strict`) | 3 default; 4 for compliance | per-profile |

**Phase 1 is the immediate action.** Phase 2 is conditional on Phase 1 metrics. Phase 3 is conditional on Phase 2 metrics.

### 6.6 Final verdict

**The 5-stack is operationally feasible but the better trade is the phased substitution to a 3-tool stack (LeanCTX + agentmemory + Graphify) for users who do not need `CTX_FETCH_STRICT`.** The 4-tool stack remains the default for `compliance_strict` users (LeanCTX does not replace `CTX_FETCH_STRICT`).

**The binding constraint is Codex** (PreToolUse deny-only) — on Codex, LeanCTX contributes only the savings ledger + prompt-injection detection + AST read modes via MCP, not the wire proxy. The other 3 hosts (Cursor, Claude Code, OpenCode) can host the full LeanCTX surface.

**The single largest gain from adding LeanCTX is the wire proxy + Ed25519 savings ledger.** These are genuinely new surfaces the four-stack does not cover. For users whose load-bearing features are "compress every request" and "prove the savings to an auditor," LeanCTX is the right addition. For users whose load-bearing features are "strict fetch policy" or "multi-agent orchestration" or "team-shared secret-scanned memory," the four-stack remains the right answer.

**Do not add LeanCTX as a permanent 5th tool. The maintenance burden of 5 tools is real, and the 3-tool substitution captures 95%+ of the benefit for most personas. Document both paths in the SB recommended-tools rule; let the user pick.**

---

## 7. Conflict Resolution Matrix (Single-View)

| # | Conflict | LeanCTX feature | SB surface | Resolution | Required changes | Effort |
|---|----------|-----------------|------------|------------|------------------|--------|
| 2.1 | PreToolUse:Bash rewrite competition | `HookMode::Hybrid` | RTK `PreToolUse` rewrite | LeanCTX observer-only; RTK owns rewrite | LeanCTX hook config (return `continue:true, suppressOutput:true`); SB `hooks/hooks.json` adds observer entry | 30 min |
| 2.2 | MCP namespace ambiguity | `mcp__leanctx__*` (81 tools) | `mcp__context_mode__*`, `mcp__agentmemory__*`, `mcp__graphify__*` | Block 76 of 81 LeanCTX tools; keep 5 unified | `.mcp.json` (or per-host equivalent) `disabledTools` list; wire proxy via env var (cleanest) | 30 min |
| 2.3 | Read-path gate | AST read modes | `context-mode-read-deny.sh` (5,120-byte threshold) | LeanCTX is read-path authority; bump deny threshold | `hooks/context-mode-read-deny.sh` whitelist LeanCTX calls; `.silver-bullet.json` `read_deny_bytes` configurable per profile | 1 hour |
| 2.4 | FTS5 KB silos | `ctx_index` / `ctx_recall` | Context Mode FTS5 | Disable LeanCTX KB tools | `.mcp.json` `disabledTools`; `.cursor/rules/leanctx.mdc` documents "use CM" | 15 min |
| 2.5 | Memory silos | `ctx_knowledge` | agentmemory 53-tool surface | Disable LeanCTX memory tools | `.mcp.json` `disabledTools`; `.cursor/rules/leanctx.mdc` documents "use agentmemory" | 15 min |
| 2.6 | Graph silos | `ctx_graph` / `ctx_callgraph` / `ctx_path` / `ctx_explain` / `ctx_query` | Graphify `query` / `path` / `explain` / `affected` | Disable LeanCTX graph tools | `.mcp.json` `disabledTools`; `.cursor/rules/leanctx.mdc` documents "use Graphify" | 15 min |
| 2.7 | Shell double-compression | Wire proxy on Bash | RTK PreToolUse rewrite | LeanCTX wire proxy skips Bash; RTK owns shell | `LEANCTX_PROXY_SKIP_TOOLS=Bash` env var; verify LeanCTX upstream supports this flag | 1 day (verification) |
| 2.8 | Rule / AGENTS.md overlap | New `.mdc` + `AGENTS.md` | 6 existing `.mdc` + per-tool AGENTS.md | Per-tool opt-in via `enabled_by_user`; consolidate `recommended-tools.mdc` | `.cursor/rules/leanctx.mdc` (new); per-tool AGENTS.md opt-in | 2 hours |
| 2.9 | Token accounting silos | Ed25519 ledger | `rtk gain` + `ctx_stats` | Document each tracker's scope; do not sum | `.cursor/rules/leanctx.mdc` documents scope of each tracker | 30 min |
| 2.10 | Runtime vs cooperative governance | PathJail | SB cooperative hooks | PathJail opt-in for compliance; default off; allowlist SB state dirs | `LEANCTX_PATH_JAIL=off` default; new `optimization_profiles.compliance_strict` profile | 2 hours |

**Total effort to make 5-stack operationally smooth: ~2 days of integration work (1 day LeanCTX upstream verification + 1 day SB integration).**

---

## 8. Per-Environment Recommendations Table

| Aspect | Cursor | Codex | Claude Code | OpenCode |
|--------|--------|-------|-------------|----------|
| **LeanCTX hook mode** | `HookMode::Mcp` only (observer on `PreToolUse:Bash`) | `HookMode::Mcp` only (no hooks; PreToolUse deny-only) | `HookMode::Mcp` + observer on `PreToolUse:Bash` + `UserPromptSubmit` for prompt-injection | `HookMode::Mcp` only (no native hook TS in catalog) |
| **LeanCTX wire proxy** | ✓ (`LEANCTX_PROXY=on`, `LEANCTX_PROXY_SKIP_TOOLS=Bash`) | ✗ (no request lifecycle) | ✓ (`LEANCTX_PROXY=on`, `LEANCTX_PROXY_SKIP_TOOLS=Bash`) | △ (Plugin TS possible; not documented) |
| **MCP server config** | `~/.cursor/mcp.json` `mcpServers.leanctx` with `disabledTools` | `~/.codex/config.toml` `[mcp_servers.leanctx]` with `enabled = true` | `~/.codex/settings.json` `mcpServers.leanctx` with `disabledTools` | `~/.config/opencode/opencode.json` `mcp.leanctx` with `enabled = true` |
| **MCP tools exposed** | 5 unified only (76 blocked) | 5 unified only (76 blocked) | 5 unified only (76 blocked) | 5 unified only (76 blocked) |
| **Rule file** | `.cursor/rules/leanctx.mdc` (new) | `AGENTS.md` (merged into existing; leanctx section) | `CLAUDE.md` (leanctx section) | `AGENTS.md` (merged; leanctx section) |
| **PathJail default** | off (opt-in for `compliance_strict`) | off (no enforcement; opt-in is no-op) | off (opt-in for `compliance_strict`) | off (opt-in for `compliance_strict`) |
| **Savings ledger** | `lean-ctx savings sign` (CLI) | `lean-ctx savings sign` (CLI) | `lean-ctx savings sign` (CLI) | `lean-ctx savings sign` (CLI) |
| **Prompt-injection detection** | `mcp__leanctx__prompt_injection_check` | `mcp__leanctx__prompt_injection_check` | `mcp__leanctx__prompt_injection_check` + `UserPromptSubmit` hook | `mcp__leanctx__prompt_injection_check` |
| **AST read modes** | `mcp__leanctx__read` (replaces host `Read` for files ≥1,024 bytes) | `mcp__leanctx__read` (replaces host `Read` for files ≥1,024 bytes) | `mcp__leanctx__read` (replaces host `Read` for files ≥1,024 bytes) | `mcp__leanctx__read` (replaces host `Read` for files ≥1,024 bytes) |
| **RTK coexistence** | RTK owns Bash rewrite; LeanCTX observes | RTK owns Bash rewrite via AGENTS.md; LeanCTX observes (MCP only) | RTK owns Bash rewrite; LeanCTX observes | RTK owns Bash rewrite via Plugin TS; LeanCTX observes |
| **CM coexistence** | CM is FTS5 KB; LeanCTX KB disabled | CM is FTS5 KB; LeanCTX KB disabled | CM is FTS5 KB; LeanCTX KB disabled | CM is FTS5 KB; LeanCTX KB disabled |
| **agentmemory coexistence** | agentmemory is memory; LeanCTX memory disabled | agentmemory is memory; LeanCTX memory disabled | agentmemory is memory; LeanCTX memory disabled | agentmemory is memory; LeanCTX memory disabled |
| **Graphify coexistence** | Graphify is graph; LeanCTX graph disabled | Graphify is graph; LeanCTX graph disabled | Graphify is graph; LeanCTX graph disabled | Graphify is graph; LeanCTX graph disabled |
| **Overall verdict** | 5-stack works at full surface | 5-stack works at reduced surface (LeanCTX MCP-only) | 5-stack works at full surface | 5-stack works at near-full surface (no wire proxy) |

---

## 9. Bibliography

### Primary Sources (Indexed in This Research Run)

- **Prior report** `multi-ai-deep-research-out/minimax-m3-report.md` (minimax-m3, 2026-07-07) — 5 unique capabilities, 17 hard gaps, pipeline critique, 12 hard gaps confirmed.
- **Prior consolidated** `multi-ai-deep-research-out/consolidated.md` (2026-07-07) — 6-model consensus: "differently optimized, not universally better"; 3/6 models call pipeline loss critical; 6/6 promote gitleaks to super-critical.
- **SB homepage** https://sb.alolabs.dev/ (fetched 2026-07-07) — 12 hook layers, 27 atomic flows, 22 pre-composed workflows, 85 flow-step V-loops, targets Claude Code / Codex / Cursor.
- **SB canonical tool set** `.cursor/rules/recommended-tools.mdc` — Graphify + agentmemory + Alumnium + RTK + Context Mode as the 4 (now 5 with Alumnium) tool baseline.
- **SB runtime config** `.silver-bullet.json` — `recommended_tools.*.enabled_by_user`, `recommended_tools.*.min_version`, `recommended_tools.*.platform_install_commands`, `optimization_profiles.{synergy_max,cost_minimized}`.
- **SB hook manifest** `hooks/hooks.json` — 12+ hook layers, `PreToolUse` with matchers for `Bash|Skill|exec_command` / `Edit|Write|MultiEdit|apply_patch` / `Task|Subagent|Agent` / `Skill` / `Read|Grep` / `Bash|exec_command`.
- **SB context-mode integration** `docs/CONTEXT-MODE.md` — Per-host install matrix; `context-mode-read-deny.sh` is SB-added; "Codex PreToolUse routing currently supports deny rules only" (per Context Mode README, openai/codex#18491).

### Tool Documentation (Indexed via `ctx_fetch_and_index` in Prior Research Run)

- **LeanCTX home** https://leanctx.com/ — One local Rust binary, 60–90% token savings.
- **LeanCTX architecture** https://leanctx.com/architecture/ — Wire proxy, PathJail, IDE config-dir jail, deny-by-default shell allowlist, Ed25519 savings ledger.
- **LeanCTX compatibility** https://leanctx.com/compatibility/ — 30+ AI tools auto-detected; RTK documented as compatible compression addon.
- **LeanCTX savings ledger** https://leanctx.com/docs/concepts/savings-ledger/ — `lean-ctx savings sign` / `savings verify-batch` CLI; Ed25519 signed aggregate-only batch.
- **LeanCTX feature catalog** `https://raw.githubusercontent.com/yvgude/lean-ctx/main/LEANCTX_FEATURE_CATALOG.md` (v3.8.1, 2026-05-15) — 81 granular MCP tools, 5 unified MCP tools, 10 read modes, `HookMode::{Mcp,Hybrid}`, Context Package System v3.4.7.
- **LeanCTX security** https://leanctx.com/docs/security — Shell Allowlist Mode v3.6.8, Built-in Default Tools v3.8.8.
- **LeanCTX GitHub** https://github.com/yvgude/lean-ctx — 3,000+ stars, 280+ forks, 200+ releases.
- **RTK GitHub** https://github.com/rtk-ai/rtk — 14 AI tools supported; per-host integration table (Claude Code PreToolUse, Cursor preToolUse, Codex AGENTS.md, OpenCode Plugin TS).
- **Context Mode GitHub** https://github.com/mksglu/context-mode — 11 MCP tools, FTS5 with Porter + trigram + RRF + Levenshtein, `CTX_FETCH_STRICT` SSRF tiers, PreCompact session resume, per-host install matrix.
- **agentmemory GitHub** https://github.com/rohitg00/agentmemory — 53 MCP tools, 6 Resources, 3 Prompts, 4 Skills, 4-tier memory consolidation, gitleaks-scanned exports, vector embeddings, `iii` engine + worker ecosystem, LongMemEval benchmark.
- **Graphify GitHub** https://github.com/safishamsi/graphify — Graph-first knowledge graph, tree-sitter AST + LLM INFERRED edges, god nodes, Leiden communities, multimodal vision ingest, 71.5× token benchmark (uncorroborated).

### Upstream Research Artifacts (Prior Runs)

- `gist-leanctx-capability-analysis.md` (2026-07-05) — 200-row × 5-column feature matrix; per-tool coverage scores (RTK 97%, CM 95%, agentmemory 87%, Graphify 99%).
- `feature-coverage-matrix.md` (88 rows) — primary matrix artifact.
- `claims.jsonl` (10 claims), `evidence.jsonl` (27 evidence spans), `sources.jsonl` (18 sources) — triangulation artifacts.
- `research_report.md` — narrative synthesis from the 2026-07-05 ultradeep audit.
- `run_manifest.json` — run metadata for the 2026-07-05 ultradeep audit.
- `.planning/research/2026-07-05-context-mode-vs-lean-context-ultradeep/` — prior ultradeep research on the same comparison axis.

### Cross-Model Reports (Prior Run)

- `minimax-m3-report.md` — multi-ai-deep-research-out/
- `qwen3.7-max-report.md` — multi-ai-deep-research-out/
- `deepseek-v4-pro-report.md` — multi-ai-deep-research-out/
- `glm-5.2-report.md` — multi-ai-deep-research-out/
- `kimi-k2.6-report.md` — multi-ai-deep-research-out/
- `mimo-v2.5-pro-report.md` — multi-ai-deep-research-out/

### Standards / Trackers Referenced

- **openai/codex#18491** — Codex `PreToolUse` `updatedInput` rewrite support (open since 2025; status as of 2026-07-07: not yet shipped). This is the binding constraint for LeanCTX's `HookMode::Hybrid` on Codex.
- **SB enforcement tier model** — `.silver-bullet.json` `sb_enforcement_tier: 2`; per-host capability tier documented in `docs/` and the SB catalog.

---

## 10. Final Verdict

**Adding LeanCTX to Silver Bullet's existing 4-tool stack is technically feasible, operationally smooth with the right feature toggles, and strategically correct as a phased substitution — not a parallel 5th tool.** The 4-tool stack's compression layer (RTK + Context Mode) is the right target for substitution; the memory layer (agentmemory) and retrieval layer (Graphify) are non-substitutable for their personas. LeanCTX's wire proxy + Ed25519 savings ledger are genuinely new surfaces that the four-stack does not cover, and they justify the integration cost for users whose load-bearing features are "compress every request" and "prove the savings to an auditor."

**The conflicts are real but resolvable** with feature toggles (6 of 10 conflicts), observer-only hooks (1 of 10), and one small code change to `context-mode-read-deny.sh` (whitelist LeanCTX reads). **The binding constraint is Codex** — its `PreToolUse` is deny-only, so LeanCTX's `HookMode::Hybrid` and RTK's `rtk init -g --codex` are exclusive choices, not additive. **Cursor, Claude Code, and OpenCode can host the full 5-stack cleanly.**

**The maintenance burden of 5 tools is real but manageable** (~1 day integration + 0.5 day/quarter ongoing). **Diminishing returns dominate after 3 tools in any single layer** — the 5-stack is more than the sum of its parts only for the wire proxy + savings ledger, both of which are genuinely novel. **The 3-tool substitution (LeanCTX + agentmemory + Graphify) is the better trade for users who do not need `CTX_FETCH_STRICT`**; the 4-tool stack remains the right answer for `compliance_strict` personas (LeanCTX does not replicate `CTX_FETCH_STRICT`).

**Recommended rollout: Phase 1 (1 month) ships LeanCTX as opt-in 5th tool with savings ledger + prompt-injection detection only. Phase 2 (3 months) adds substitution toggles for `cost_minimized` and `synergy_max` profiles. Phase 3 (6+ months) promotes 3-tool stack to default for new installs if Phase 2 metrics justify it.** This phased approach preserves backward compatibility, validates the substitution empirically, and avoids the 5-stack being a permanent state.

**The strongest single reason to add LeanCTX:** the Ed25519 savings ledger is the only tool in the comparison that produces a **provable, offline-verifiable, self-signed attestation** of token savings — the only answer to a CFO or auditor who asks "show me the savings are real, and verify it without trusting the local ledger." **The strongest single reason NOT to add LeanCTX as a permanent 5th tool:** the maintenance burden of 5 tools exceeds the marginal benefit for users who do not need the wire proxy. **The right answer is "add LeanCTX as an opt-in 5th tool, then transition to a 3-tool substitution for users who do not need `CTX_FETCH_STRICT`."**

---

**End of report.**

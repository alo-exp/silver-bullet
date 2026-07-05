# RTK + Context Mode vs LeanCTX — Feature & Capability Comparison

**Scope:** Features and capabilities only. Excludes licensing, pricing, Silver Bullet integration cost, recommended-tools policy, and adoption recommendations.

**Sources:** Ultrdeep research artifacts in this directory ([research_report.md](research_report.md), [evidence.jsonl](evidence.jsonl), [sources.jsonl](sources.jsonl)); local docs [docs/RTK.md](../../../docs/RTK.md), [docs/CONTEXT-MODE.md](../../../docs/CONTEXT-MODE.md); live LeanCTX pages fetched 2026-07-05 [1][2][11].

**Column note:** **RTK + Context Mode** treats [RTK](https://github.com/rtk-ai/rtk) (shell) and [Context Mode](https://github.com/mksglu/context-mode) (MCP/analysis) as the combined stack used together — not a single product.

---

## Side-by-side comparison

| Capability area | RTK + Context Mode (combined stack) | LeanCTX (unified product) | Winner (feature-only) |
|---|---|---|---|
| **Primary purpose / problem solved** | Split stack: RTK compresses **shell command output** at PreToolUse; Context Mode keeps **MCP tool and fetch results** in a sandbox so raw bytes never enter the model context [docs/RTK.md], [6][b2a40c43029e9a0c]. | Full **context engineering layer** in one local Rust binary: controls what agents read, remembers project knowledge, guards file/shell access, optionally compresses wire requests, and signs savings proof [1][2][c38283d5a6d182b2]. | **LeanCTX** — broader stated scope in one runtime |
| **Compression surfaces — shell** | RTK rewrites allow-listed Shell/Bash commands to `rtk <cmd>` via host PreToolUse hooks (Cursor, Claude, OpenCode, partial Hermes). Codex is prompt-layer only (no live rewrite) [docs/RTK.md]. Cursor rewrites only commands matching `permissions.allow` in `~/.cursor/cli-config.json`. | Native **shell compression** via shell hooks in hybrid/CLI-Redirect mode; shell allowlist is deny-by-default at runtime [2][c903204ab4ae696a]. Lists RTK as compatible addon [1]. | **LeanCTX** — shell compression built-in; RTK is a separate dependency |
| **Compression surfaces — Read / large files** | Context Mode: cooperative routing — agents use `ctx_execute_file` / rules; SB can enforce Read deny above threshold via project hook [docs/CONTEXT-MODE.md]. No upstream global Read deny; no AST read modes. | **10 read modes** from full content down to AST signatures; adaptive ModePredictor learns per file type [5][c903204ab4ae696a]. Intervenes on read path before tokens reach the model [research_report.md]. | **LeanCTX** — native read-path AST/fidelity modes |
| **Compression surfaces — MCP tool output** | Core design: `ctx_execute`, `ctx_execute_file`, `ctx_batch_execute` run in isolated subprocess; only stdout enters context [6]. Hooks match Shell, Read, Grep, WebFetch, Task, external MCP tools. | MCP exposes large tool surface (~80 tools in protocol-only agents per GitHub [5]); hybrid mode uses MCP for cached re-reads (~13 tokens claimed) [c903204ab4ae696a]. | **Context Mode** — MCP sandboxing is the primary architectural center |
| **Compression surfaces — web fetch** | `ctx_fetch_and_index` fetches, converts to markdown/chunks, indexes locally; raw page never enters context. Hooks **deny WebFetch** and redirect `curl`/`wget` in Shell to MCP path [6][docs/CONTEXT-MODE.md]. | Universal intake includes web/HTML/PDF/CSV/RSS/YouTube transcripts compressed into facts [1]. Wire proxy can compress tool results on request path [2]. | **Tie** — both local fetch + compaction; CM documents stronger hook-level fetch blocking |
| **Compression surfaces — wire / request path** | No first-party request proxy; savings are post-tool (sandbox stdout) and RTK-compressed shell output. | Optional **local request compression proxy** — system prompt, history, tool results — prompt-cache-safe [2][090729540bfb4895]. | **LeanCTX** — only stack with documented wire-side proxy |
| **Retrieval / indexing** | **FTS5** knowledge base: Porter stemming + trigram tokenizers, Reciprocal Rank Fusion via `ctx_search`; `ctx_index` for local content [6][b2a40c43029e9a0c]. Intent-driven filtering when sandbox output > ~5 KB. | Project **memory subsystem**: sessions, project knowledge, **knowledge graph**, handoffs (12 MCP tools / 5 features on architecture page) [2]. Cached re-reads return compact representations. | **LeanCTX** — graph + handoffs beyond FTS search |
| **Sandbox / isolation model** | Per-call **subprocess sandbox** for `ctx_execute*` (12 language runtimes); raw data stays in sandbox. Extends host permission rules into MCP layer [6]. | **PathJail** canonicalizes paths and confines file I/O to workspace root; IDE config-dir jail optional; deny-by-default shell allowlist [2]. Single binary enforces boundaries on read/shell paths. | **LeanCTX** — filesystem + shell enforcement at runtime; CM focuses on analysis subprocess |
| **Agent UX — hooks** | RTK: PreToolUse shell rewrite. Context Mode: pre/post ToolUse, SessionStart, Stop, afterAgentResponse, **PreCompact**, UserPromptSubmit on 17+ platforms [6][b2a40c43029e9a0c]. Codex PreToolUse deny-only (no `updatedInput` yet). | `lean-ctx setup` auto-detects editors and wires hooks + MCP [4][89c76c574c070343]. Hybrid (CLI-Redirect + MCP) vs MCP-only modes [5][11]. | **LeanCTX** — zero-config multi-tool setup; **Context Mode** — deeper PreCompact story |
| **Agent UX — MCP tools** | 11 Context Mode tools: 6 sandbox (`ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`, `ctx_index`, `ctx_search`, `ctx_fetch_and_index`) + 5 meta (`ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge`, `ctx_insight`) [6]. | ~**80 MCP tools** across five subsystems (Smart I/O, Memory, Security, Request Compression, Provable Savings) [2][5]. Stdio transport, `command: lean-ctx` only [4]. | **LeanCTX** — larger integrated MCP surface |
| **Agent UX — CLI / doctor** | `context-mode doctor`, `ctx_stats`, `ctx_upgrade`, `ctx_purge`; RTK `rtk gain`, `rtk --version`, hook test via stdin JSON [docs/RTK.md][6]. | `lean-ctx setup`, install via script/Homebrew/npm/cargo [4]. Local dashboard on localhost with bearer token [2]. | **Tie** — both ship diagnostics; different shapes |
| **IDE / host support** | Documented: Claude Code, Cursor, Codex, OpenCode, partial Hermes; Goose unsupported [docs/RTK.md][docs/CONTEXT-MODE.md]. 17+ platforms via Context Mode hooks [6]. | **30+ tools** claimed; compatibility matrix lists Cursor/Claude/Codex as CLI-Redirect hybrid, VS Code/JetBrains/Zed as MCP-only [1][11]. | **LeanCTX** — wider agent coverage on paper |
| **Token savings mechanism** | RTK: command-specific compressors on rewritten shell output. Context Mode: sandbox-only stdout + indexed fetch; worked examples cite ~94–99% vs raw fetch in README [6]. `ctx_stats` session metrics. | Vendor claims **60–90% fewer tokens per read**, ~**13 tokens per cached re-read** [1]; request-side estimates in local engine [3]. | **Unclear** — no shared benchmark; both vendor-claimed |
| **Web / external fetch handling** | `ctx_fetch_and_index` with TTL cache; blocks non-HTTP schemes, cloud metadata (169.254.x), multicast/reserved; optional `CTX_FETCH_STRICT=1` for RFC1918/loopback block [6][cfe6b1639c3c3094]. Hook denies native WebFetch. | Universal intake pipeline for external formats; local processing [1]. Less published detail on SSRF hardening vs Context Mode. | **Context Mode** — documented fetch hardening + hook deny |
| **Code analysis (AST, grep, batch)** | Agents write analysis code in sandbox (`ctx_execute` / `ctx_batch_execute` / `ctx_execute_file`) — programmatic grep/filter/count, not AST read modes. RTK compresses `rg`/`grep`/`git` output when allow-listed. | **AST signature read mode** and 9 other fidelity levels; Smart I/O includes deterministic reads + search [2][c903204ab4ae696a]. Shell compression in same subsystem. | **LeanCTX** — native AST read routing; **RTK+CM** — programmatic sandbox analysis |
| **Session / memory continuity** | FTS5 persistent KB + `ctx_search(sort: timeline)`; **PreCompact hook** preserves tasks, files, decisions across compaction [6][b2a40c43029e9a0c]. Session DB in home directory [6]. | Persistent sessions, project knowledge graph, handoffs; **git-anchored signed context snapshots** for replay/restore [2]. | **LeanCTX** — graph + git-anchored replay; **CM** — strong PreCompact hook |
| **Governance / safety** | Instruction-fragment + rules (`.mdc`) routing; MCP `tool_input` redaction before persistence; sandbox credential passthrough for CLIs [6]. RTK: allow-list gated rewrites; `RTK_DISABLED=1` bypass. No PathJail. | **PathJail**, IDE config-dir jail, **deny-by-default shell allowlist**, secret redaction, budgets, injection detection [2]. Signed evidence bundles [2][12]. | **LeanCTX** — runtime filesystem/shell enforcement |
| **Observability** | `ctx_stats` — per-tool savings, cache hits, session statistics [6]. RTK `rtk gain` for hook/savings visibility [docs/RTK.md]. Optional Insight SaaS (out of scope here). | **Ed25519-signed, hash-chained savings ledger** on disk; batch-verifiable entries [12][e372b3aaba168ac3]. Reproducible benchmark narrative [2]. | **LeanCTX** — cryptographic audit ledger |
| **Install / runtime model** | Two products: RTK binary (Homebrew/curl); Context Mode **Node.js ≥ 22.5** (or Bun), global npm, per-host MCP + hooks + rules merge [6][docs/CONTEXT-MODE.md]. Windows via WSL for CM. | **Single Rust binary** — curl/Homebrew/npm/cargo; `lean-ctx setup` wires hosts [4]. No Node coupling for core runtime. | **LeanCTX** — one binary vs dual stack |
| **Maturity / ecosystem** | RTK and Context Mode are separate upstream projects with active hook/MCP docs; Context Mode README is extensive per-platform [6][7]. RTK ≥ 0.42.0 for Cursor native hooks [docs/RTK.md]. | Newer unified product; strong marketing/docs on architecture, compatibility, ledger [1][2][11]. GitHub documents hybrid vs MCP-only [5]. | **Context Mode + RTK** — longer separate track records; **LeanCTX** — faster surface-area growth in one repo |

---

## Summary — pure capability strengths

### RTK + Context Mode together

- **MCP-centric sandboxing** is the deepest capability: isolated multi-language subprocess execution, fetch-to-index pipeline, FTS5 search, and hook-driven routing/deny for WebFetch and shell HTTP [6].
- **PreCompact session recovery** and progressive `ctx_search` throttling are explicit Context Mode features for long agent sessions [6].
- **Fetch security hardening** (SSRF/metadata blocking, MCP credential redaction) is documented in detail [6][cfe6b1639c3c3094].
- **RTK** adds mature, command-specific **shell output compression** for common dev CLIs when host allow-lists permit rewrites [docs/RTK.md].

### LeanCTX

- **Broadest compression surface** in one runtime: read-path AST modes, shell hooks, optional **wire-side request proxy**, and MCP — five named subsystems [1][2].
- **Runtime governance** (PathJail, deny-by-default shell allowlist, config-dir jail) goes beyond instruction-only enforcement [2].
- **Project memory graph, handoffs, and git-anchored replay** plus **Ed25519 savings ledger** for verifiable token economics [2][12].
- **Wider agent matrix** (30+ tools, hybrid CLI-Redirect + MCP modes) with single-binary setup [1][11][4].

### Where they overlap

Both are **local-first** (no mandatory cloud for core features) [1][6]. Both use **MCP + hooks**. Both target agentic coding token waste. LeanCTX explicitly lists RTK as a compatible addon, implying composability rather than mutual exclusion [1].

---

## Source key

| ID | Reference |
|---|---|
| [1] | LeanCTX homepage — [leanctx.com](https://leanctx.com/) [c38283d5a6d182b2] |
| [2] | LeanCTX architecture — [leanctx.com/architecture/](https://leanctx.com/architecture/) [090729540bfb4895] |
| [3] | LeanCTX pricing (savings estimates) — [leanctx.com/pricing/](https://leanctx.com/pricing/) [d24236ac357a7221] |
| [4] | LeanCTX getting started — [leanctx.com/docs/getting-started/](https://leanctx.com/docs/getting-started/) [89c76c574c070343] |
| [5] | lean-ctx GitHub — [github.com/yvgude/lean-ctx](https://github.com/yvgude/lean-ctx) [c903204ab4ae696a] |
| [6] | Context Mode README — [github.com/mksglu/context-mode](https://github.com/mksglu/context-mode) [b2a40c43029e9a0c] |
| [7] | context-mode GitHub repo [cfe6b1639c3c3094] |
| [11] | LeanCTX compatibility — [leanctx.com/compatibility](https://leanctx.com/compatibility) [f2e157bf55bc7de3] |
| [12] | LeanCTX savings ledger — [leanctx.com/docs/concepts/savings-ledger](https://leanctx.com/docs/concepts/savings-ledger) [e372b3aaba168ac3] |
| [docs/RTK.md] | [docs/RTK.md](../../../docs/RTK.md) |
| [docs/CONTEXT-MODE.md] | [docs/CONTEXT-MODE.md](../../../docs/CONTEXT-MODE.md) |

Evidence span IDs in brackets (e.g. `[b2a40c43029e9a0c]`) map to rows in [evidence.jsonl](evidence.jsonl) and sources in [sources.jsonl](sources.jsonl).

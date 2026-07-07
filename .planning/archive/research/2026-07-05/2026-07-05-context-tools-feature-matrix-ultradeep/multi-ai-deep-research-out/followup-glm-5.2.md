# Adding LeanCTX to the Silver Bullet 4-Tool Stack — Conflict & Synergy Analysis

**Follow-up deep-research analysis**
**Author:** glm-5.2 (continuation of the 2026-07-07 ultradeep dispatch)
**Date:** 2026-07-07
**Scope:** Whether LeanCTX should be **added as a 5th tool** to the existing Silver Bullet stack (RTK + Context Mode + agentmemory + Graphify) — not whether it should *replace* any of them (that was the prior report's question). Identifies every operational conflict, proposes resolutions, and assesses synergy across SB's 3 current target environments (Cursor, Codex, Claude Code) plus a potential 4th (OpenCode).
**Prior work:** `glm-5.2-report.md` (replacement analysis), `consolidated.md` (6-model convergence), `gist-leanctx-capability-analysis.md` (200-row matrix), primary SB sources (`hooks/hooks.json`, `docs/code-intelligence-contract.md`, `https://sb.alolabs.dev/`, repo `AGENTS.md`).

---

## Executive Summary

**Adding LeanCTX as a 5th tool to the SB stack is net-positive *if and only if* it is integrated in "addon mode" — wire proxy + AST read modes + PathJail + Ed25519 ledger + prompt-injection gating enabled, and the `ctx_*` MCP tool surface either disabled or namespaced.** A naive "install LeanCTX alongside the four-stack" deployment is operationally broken: the `ctx_*` tool-name collision between LeanCTX and Context Mode is a hard blocker, the double FTS5 index wastes disk and splits search recall, and the hook-chain ordering on PreToolUse (Read + Bash) produces non-deterministic interception. The consolidated report's recommendation ("do not add as a 5th tool; use as replacement for RTK + CM") is directionally correct but over-conservative — it under-weights the 5 LeanCTX-only planes (wire, AST reads, PathJail, ledger, injection gating) that the 4-stack genuinely cannot occupy.

The conflict surface is **9 distinct categories**, of which **2 are hard blockers** (MCP `ctx_*` namespace collision, Read-path double interception), **4 are manageable with config** (hook ordering, FTS5 duplication, triple token accounting, PathJail vs SB cooperative rules), and **3 are additive taxes** (rules-file bloat, install surface growth, maintainence burden). All 9 are resolvable with the layering strategy documented in §3 — no conflict requires removing any of the 4 incumbents.

The per-environment picture is asymmetric: **Claude Code** is the only environment where the full 5-stack can run with complete hook fidelity (it has the richest hook surface and supports ordered multi-hook chains); **Cursor** can run the 5-stack with allow-list gating but loses some LeanCTX read-path interception; **Codex** cannot run LeanCTX's headline read-path AST modes at all (deny-only hooks cannot transform tool output, only block); **OpenCode** is MCP-first and would benefit most from LeanCTX's Tool-Catalog Gateway *but* is also where the `ctx_*` naming collision hurts most (no hook layer to disambiguate — the model sees both tool sets raw).

**Recommendation: phased adoption.** Phase 0 (do nothing reckless), Phase 1 (addon-mode pilot on Claude Code only, `ctx_*` disabled), Phase 2 (namespace resolution + Cursor rollout), Phase 3 (Codex + OpenCode with documented degraded modes), Phase 4 (evaluate RTK retirement — the only incumbent LeanCTX credibly replaces at >95% parity). Never retire Context Mode (`CTX_FETCH_STRICT`), agentmemory (53-tool orchestration), or Graphify (multimodal corpus) — their depth planes are not duplicated by LeanCTX.

---

## 1. Would adding LeanCTX benefit SB?

### The 4-stack's occupied planes (re-validated)

SB's `docs/code-intelligence-contract.md` defines capability tiers 0–3 with the 4 tools occupying distinct planes:

| Tool | Plane | SB tier | Role in SB pipeline |
|---|---|---|---|
| RTK | Shell compression | 1c | PreToolUse rewrite for Bash; `rtk pytest`, `rtk go test` per-CLI compressors |
| Context Mode | MCP sandbox + fetch hardening | 1c | `ctx_execute*` sandbox, FTS5 index, `CTX_FETCH_STRICT`, WebFetch deny + curl/wget redirect |
| agentmemory | Session memory + orchestration | 1b | `memory_save`/`recall`, 53-tool action DAG, frontier, lease, mesh, team feed, gitleaks |
| Graphify | Code/repo knowledge graph | 1, 2 | Tree-sitter AST + LLM INFERRED edges, `query`/`path`/`explain`, `GRAPH_REPORT.md`, wiki/, obsidian/ |

The SB website (`sb.alolabs.dev`) frames this as: *"RTK + Context Mode compress tokens and index large files. Graphify + agentmemory wire a knowledge graph of accepted decisions, ADRs, and durable learnings. The next session starts where the last one left off — not from zero."* The pipeline is **RTK compresses shell → Context Mode sandboxes output → agentmemory captures decisions → Graphify retrieves patterns**.

### LeanCTX's 5 unique planes the 4-stack does NOT occupy

Per my prior report (§4, Finding 4) and the consolidated report (Finding 4, 6/6 model consensus), LeanCTX ships 5 capabilities with no incumbent row:

| LeanCTX capability | Plane | SB 4-stack gap |
|---|---|---|
| **Wire/request compression proxy** (`lean-ctx proxy enable`) | Model API boundary | No incumbent compresses the request body (system prompt + history + tool results) — the largest uncaptured savings surface on long multi-turn sessions |
| **AST read-path compression** (10 modes: full → AST → signatures; `ModePredictor`, `IntentEngine`, `~13-token` cached re-read) | Read tool boundary | Context Mode redirects reads to sandbox (cooperative rules); no incumbent compresses reads *in-place* before the model sees them |
| **PathJail + deny-by-default shell allowlist** | Filesystem runtime | SB relies on cooperative AGENTS.md rules + hook guards (`planning-file-guard`, `instruction-file-guard`); no filesystem jail on native Read/Shell paths |
| **Ed25519 hash-chained savings ledger** + offline batch-verify CLI | Token audit | RTK `rtk gain` and CM `ctx_stats` are session metrics, not tamper-evident cryptographically verifiable audit |
| **Pre-model prompt-injection detection** | Security gate | No incumbent row; SB's `ai-llm-safety` skill is instructional, not runtime |

Plus 5 secondary LeanCTX-only surfaces found during prior retrieval: `proxy.effort` (cross-provider reasoning-effort pinning), output-token verbosity steer, cache-prefix volatility relocation, `ctx_quality` (cognitive-complexity hotspot + token-quality-tax), `ctx_refactor` (LSP-backed rename/references/definition/implementations — Graphify is read-only).

### Benefit assessment — genuine gaps filled

**Yes, LeanCTX fills genuine gaps.** The 5 unique planes are not marginal — they are surfaces the 4-stack architecturally cannot occupy. SB's current enforcement model is *cooperative* (rules + hook guards that rely on the model reading AGENTS.md and complying). LeanCTX's PathJail and prompt-injection gating are *runtime* enforcement that does not depend on model compliance. For SB's stated thesis — *"enforced process plus retrieval so you are not paying frontier API prices for every planning pass, re-read, and gate check"* — the wire proxy alone is a direct cost-reduction lever the 4-stack lacks.

The LSP-backed `ctx_refactor` is also a genuine upgrade over Graphify (which is read-only). SB's code-intelligence contract tops out at tier 2 (structural graph) and tier 3 (live runtime); LeanCTX's `ctx_refactor` adds a *write-path* structural operation (rename across the graph) that neither Graphify nor tier-2 shell discovery provides.

### Overlap assessment — where LeanCTX is redundant

| Plane | LeanCTX overlaps with | Overlap severity |
|---|---|---|
| Shell compression | RTK (97% coverage per matrix) | **High** — LeanCTX native 95+ patterns + 270 rules ≈ RTK's surface; running both is double compression |
| MCP sandbox + FTS5 | Context Mode (95% coverage) | **High + naming collision** — both ship `ctx_execute`, `ctx_search`, `ctx_index`, `ctx_batch_execute`, `ctx_fetch_and_index`, `ctx_stats`, `ctx_purge` |
| Session memory + handoff | agentmemory (87% coverage, arguably 80–85%) | **Medium** — LeanCTX has 7 multi-agent tools vs agentmemory's 53; depth gap not overlap |
| Code-structural graph | Graphify (99% coverage for code) | **Medium** — LeanCTX `ctx_graph` + `ctx_callgraph` overlap Graphify's `query`/`path`/`explain`; but Graphify's `wiki/` + `GRAPH_REPORT.md` + `obsidian/` artifact ecosystem is distinctive |

### Verdict on benefit

LeanCTX benefits SB **on 5 net-new planes** (wire, AST reads, PathJail, ledger, injection gating) + 1 net-new write-path capability (LSP refactor). It overlaps the 4-stack on 4 planes (shell, sandbox, memory, code-graph) with varying severity. **The benefit is real and material if and only if the overlap conflicts are resolved** — a naive parallel install produces naming collisions and double compression that erase the benefit. The conflict analysis below determines whether the benefit is realizable.

---

## 2. Conflicts — identified by category

### 2.1 Hook conflicts (PreToolUse, PostToolUse, SessionStart, PreCompact)

**SB's current hook surface** (from `hooks/hooks.json`):

| Event | Matchers | SB hooks chained |
|---|---|---|
| SessionStart | `startup\|clear\|compact` | `session-start`, `spec-session-record.sh` |
| PreToolUse | `.*` | `debug-dump.sh` |
| PreToolUse | `Bash\|Skill\|exec_command` | `phase-archive.sh`, `completion-audit.sh` |
| PreToolUse | `Edit\|Write\|MultiEdit\|apply_patch` | `planning-file-guard.sh`, `instruction-file-guard.sh`, `workflow-chain-guard.sh`, `orchestrator-directive-guard.sh`, `agent-delegation-guard.sh`, `phase-lock-claim.sh` (6 hooks) |
| PreToolUse | `Task\|Subagent\|Agent` | `orchestrator-directive-guard.sh`, `subagent-stop-enforcement.sh`, `review-fix-ladder-guard.sh` |
| PreToolUse (gates) | tool-specific | `graphify-gate`, `agentmemory-gate`, `context-mode-gate`, `token-compression-tools-gate`, `alumnium-gate` |
| PostToolUse | (per-tool) | `site-preview-preflight`, `site-chrome-guard`, `trivial-file-guard`, `dev-cycle-check`, gate validations |
| Stop | `.*` | `completion-audit.sh` (final) |
| UserPromptSubmit | `.*` | router classification |

SB's website claims "12 Hook Layers" — the actual `hooks.json` ships ~20 distinct hook scripts across those layers. The matcher `startup|clear|compact` on SessionStart means SB re-injects workflow state on session start, clear, AND compact — so SB does not use a separate PreCompact hook; it folds compact handling into SessionStart.

**LeanCTX's hook surface** (per prior report §2, re-validated):

| Event | LeanCTX behavior |
|---|---|
| PreToolUse (Read) | Intercepts Read before model sees output; applies AST modes, ModePredictor, density compression; returns compressed content |
| PreToolUse (Bash/Shell) | Enforces deny-by-default shell allowlist; PathJail on command arguments |
| PostToolUse | Ed25519 ledger signing for savings attestation |
| SessionStart | Auto-detects agent, configures read modes, cache prefix |
| PreCompact | Memory snapshot, CCR marker injection for reversibility |

**Conflicts:**

1. **PreToolUse(Read) double interception.** SB does not currently intercept Read in PreToolUse (its Read-path discipline is cooperative via AGENTS.md rules — "Reading to analyze → `ctx_execute_file`"). LeanCTX *does* intercept Read in PreToolUse. If both are installed, LeanCTX's hook fires on Read, returns compressed content; SB's cooperative rule never triggers because the model already received (compressed) content. **This is not a hard conflict** — it is a philosophical substitution. But it means Context Mode's read-routing value is silently bypassed.

2. **PreToolUse(Bash) double interception.** Both RTK (PreToolUse shell rewrite) and LeanCTX (shell allowlist + PathJail) want to intercept Bash. SB also has `phase-archive.sh` + `completion-audit.sh` on `Bash|Skill|exec_command`. Three interceptors on the same matcher. Order matters: if RTK rewrites the command first, LeanCTX's allowlist sees the rewritten command (may not match patterns); if LeanCTX runs first, RTK's compressor sees the already-filtered command. **Hard conflict if both RTK and LeanCTX native shell are enabled.**

3. **PreToolUse(Edit|Write|MultiEdit) chain length.** SB already chains 6 hooks on this matcher. Adding LeanCTX's PathJail write-check = 7th. Claude Code supports ordered multi-hook chains, but the 7th hook adds latency (PathJail is synchronous deny-by-default) and a new failure mode (PathJail denies a write that SB's `planning-file-guard` would allow — e.g., writing to `${CLAUDE_PLUGIN_ROOT}/state/` outside the project cwd). **Medium conflict — PathJail config must include plugin state dirs.**

4. **SessionStart(compact) vs PreCompact.** SB uses SessionStart with `compact` matcher to re-inject workflow state. LeanCTX uses PreCompact for memory snapshot + CCR marker. These are *different events* in Claude Code's hook lifecycle (PreCompact fires *before* compaction; SessionStart with `compact` matcher fires *after* compaction on the new session). **No conflict — complementary.** SB captures state pre-compaction via its own SessionStart; LeanCTX captures memory snapshot pre-compaction via PreCompact. They run on different triggers.

5. **PostToolUse ledger vs gate validation.** SB's PostToolUse runs gate validations (`graphify-gate`, `agentmemory-gate`, etc.) — these check whether the tool call was *allowed* per SB policy. LeanCTX's PostToolUse signs the savings ledger. **No conflict — different concerns.** Gate validation is policy; ledger signing is attestation. Both can run; order: SB gate first (policy), LeanCTX ledger second (attest only if allowed).

### 2.2 MCP conflicts (port assignments, tool namespace collisions)

**Tool namespace collision — the hardest conflict.** Context Mode ships 11 MCP tools: `ctx_batch_execute`, `ctx_execute`, `ctx_execute_file`, `ctx_index`, `ctx_search`, `ctx_fetch_and_index`, `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge`, `ctx_insight`. LeanCTX ships **the same names** (per the feature catalog, LeanCTX's 81 tools include `ctx_execute`, `ctx_search`, `ctx_index`, `ctx_batch_execute`, `ctx_fetch_and_index`, `ctx_stats`, `ctx_purge` — direct mirror of Context Mode's sandbox surface). When both MCP servers are registered, the host (Claude Code, Cursor, Codex) sees **two tools named `ctx_search`**, two named `ctx_execute`, etc. Behavior:

- **Claude Code:** MCP tool names are server-scoped in the manifest but exposed flat to the model. The model sees duplicate names; behavior is host-dependent (last-registered wins, or both appear with ambiguous disambiguation). **Broken.**
- **Cursor:** MCP tools are exposed via the MCP registry; duplicate names cause registration conflicts. **Broken.**
- **Codex:** MCP tools exposed via `/silver:` commands and MCP; duplicate names collide. **Broken.**
- **OpenCode:** MCP-first — all tools exposed raw via MCP; duplicate names are the most visible failure. **Broken.**

This is a **universal hard blocker** for naive parallel installation. It is the single conflict that makes "just install LeanCTX alongside the 4-stack" operationally non-functional.

**Port assignments.** agentmemory runs a server on `:3111` (REST API + MCP). Context Mode runs as a Node MCP server (stdio or SSE — typically stdio for Claude Code). Graphify runs as a Python MCP (stdio). RTK is hook-only (no MCP server). LeanCTX runs a Rust binary with an optional wire proxy (port configurable, default per LeanCTX config) + MCP server (stdio or SSE). **No documented port collision** between LeanCTX and the 4-stack's default configs — but if LeanCTX's wire proxy and agentmemory's `:3111` both bind localhost, operators must verify no overlap. **Low conflict — config-resolvable.**

### 2.3 Read-path conflicts (LeanCTX intercepts Read before model; Context Mode denies large reads)

This is the **philosophical conflict** between two different read-path strategies:

- **Context Mode strategy (cooperative redirect):** AGENTS.md rules instruct the model: "Reading to analyze/explore/summarize → `ctx_execute_file`." The Read tool itself is not blocked; the model is *trained* by the rules to choose `ctx_execute_file` instead. Large reads that bypass the rule are not denied at the tool level (Context Mode's hooks deny WebFetch and curl/wget, not Read).
- **LeanCTX strategy (runtime interception):** PreToolUse(Read) hook intercepts the Read call, applies AST modes, returns compressed content. The model never sees the raw file; it receives compressed content directly. No cooperative rule needed.

**Conflict when both installed:** LeanCTX's PreToolUse(Read) fires first (it is a synchronous hook). The model receives compressed content. Context Mode's cooperative routing rule ("use `ctx_execute_file` instead of Read") never triggers because the model already got content from Read. **Context Mode's read-routing value is silently bypassed** — not a crash, but a loss of Context Mode's sandbox-indexing pipeline (the FTS5 index does not get populated because reads go through LeanCTX, not `ctx_execute_file`).

**Secondary conflict:** Context Mode's `ctx_execute_file` reads a file in the sandbox and returns only stdout (the derived answer). LeanCTX's Read interception returns compressed content (still the file content, just compressed). These are different value propositions — `ctx_execute_file` is for "analyze without reading raw"; LeanCTX Read is for "read compressed." If the model uses LeanCTX-compressed Read, it gets compressed *raw* content (still in context, just smaller); if it uses `ctx_execute_file`, it gets only the *answer* (raw bytes never enter context). The latter is strictly better for context budget on analysis tasks. **So LeanCTX Read interception and Context Mode `ctx_execute_file` are not equivalent — they serve different use cases, and the model should use both.** The conflict is that LeanCTX's interception makes the cooperative routing rule less likely to fire.

### 2.4 Search/index conflicts (dual FTS5 databases)

Context Mode persists an FTS5 SQLite knowledge base (chunks indexed from `ctx_execute_file`, `ctx_batch_execute`, `ctx_fetch_and_index`, `ctx_index`). LeanCTX ships its own `ctx_index` + `ctx_search` with FTS5 + RRF + progressive throttling (per the feature catalog mirror). **If both run, two FTS5 databases accumulate:**

- **Disk duplication:** content indexed via Context Mode's `ctx_fetch_and_index` is in CM's FTS5; content indexed via LeanCTX's `ctx_index` is in LeanCTX's FTS5. Same source content, two indexes, double disk.
- **Search recall split:** `ctx_search` returns CM results; LeanCTX's `ctx_search` returns LeanCTX results. The model sees two `ctx_search` tools (naming collision from §2.2) and cannot tell which to call. Even if namespaced, the model must decide which index to query — and the indexes may have different chunking, different BM25 rankings, different RRF fusion.
- **Index population split:** if LeanCTX intercepts reads (§2.3), CM's index stops growing because `ctx_execute_file` is bypassed. LeanCTX's index grows from its own interception. Net: CM's index atrophies; LeanCTX's index becomes authoritative. **This is a soft migration from CM to LeanCTX for the index plane** — not a crash, but a silent functional shift.

**Hard conflict if both `ctx_index` calls are exposed (naming collision). Medium conflict if namespaced (double index, operator chooses which to populate).**

### 2.5 Memory graph conflicts (LeanCTX ctx_graph vs agentmemory memory_graph_query vs Graphify)

Three graph systems with different schemas and centers of gravity:

| System | Graph type | Schema | Primary use |
|---|---|---|---|
| **Graphify** | Code-structural + multimodal | Tree-sitter AST nodes + LLM INFERRED edges; Leiden communities; god nodes; `wiki/`, `GRAPH_REPORT.md`, `obsidian/`, `graph.html` artifacts | Codebase orientation; cross-session replay via persistent artifacts; multimodal corpus (PDF/image/diagram) |
| **agentmemory `memory_graph_query`** | Memory-relational | `memory_relations` typed edges between memory nodes; relation traversal | Session memory graph; decision→ADR→learning edges; team memory |
| **LeanCTX `ctx_graph`** | Code-structural (property graph) | Weighted BFS over `imports`, `calls`, `exports`, `type_ref`, `tested_by` edges; `ctx_callgraph` for callers/callees | Code-structural queries; `ctx_refactor` LSP-backed rename/references |

**Conflicts:**

1. **LeanCTX `ctx_graph` vs Graphify** — both are code-structural graphs. LeanCTX's edge types (`imports`, `calls`, `exports`, `type_ref`, `tested_by`) overlap Graphify's AST + INFERRED edges. Graphify's distinctive value (Leiden communities, god nodes, `wiki/` markdown artifacts, multimodal ingest, `GRAPH_REPORT.md`) is not duplicated by LeanCTX. **Overlap on code-structural queries; Graphify wins on artifact ecosystem and multimodal.** If both are queried, the model gets two code-graph results for the same question — confusing but not broken.

2. **LeanCTX `ctx_graph` vs agentmemory `memory_graph_query`** — different domains (code vs memory). **No conflict.** These graphs serve different purposes and do not overlap.

3. **Triple-graph cognitive load.** The model must decide: for "how does X relate to Y in the codebase?" → Graphify `query`/`path` or LeanCTX `ctx_graph`? For "what did we decide about X?" → agentmemory `memory_graph_query`. SB's current rules (`graphify.mdc`) route codebase questions to Graphify. Adding LeanCTX adds a second code-graph option. **Rules-tax conflict** — the routing rule must be extended to disambiguate.

### 2.6 Shell compression conflicts (RTK + LeanCTX double compression)

RTK: PreToolUse shell rewrite, 95+ patterns, 270 passthrough rules, per-CLI compressors (`rtk pytest -90%`, `rtk go test -90%`).
LeanCTX: native 95+ shell patterns + 270 passthrough rules (per the feature catalog, near-identical coverage).

**Conflict if both active on PreToolUse(Bash):**

- **Order problem:** If RTK runs first, RTK rewrites the command output (e.g., compresses `pytest` output to a summary). LeanCTX's shell compressor then sees RTK's already-compressed output and applies its own patterns — which may not match (RTK's compressed format is RTK-specific). Result: either no further compression (LeanCTX patterns don't match RTK output) or double compression that corrupts (rare but possible if both apply regex rewrites to the same text).
- **Double taxation:** two synchronous PreToolUse hooks on Bash add latency to every shell call. RTK is fast (Rust); LeanCTX is fast (Rust); but two hooks × every Bash call = measurable overhead on tight dev loops.
- **Accounting confusion:** RTK's `rtk gain` claims the savings; LeanCTX's Ed25519 ledger claims the savings. **Double-counting** — both tools claim credit for the same compressed output. The "savings" number is inflated.

**LeanCTX documents RTK as a compatible addon** (per `leanctx.com/compatibility`, confirmed in prior report). The addon mode likely means "RTK for shell, LeanCTX for read/wire" — i.e., disable LeanCTX's native shell compression when RTK is present. **Resolution: operator config, not architectural.** But the default install (both active) is a conflict.

### 2.7 Token accounting conflicts (three separate trackers)

| Tracker | Tool | Type | Scope |
|---|---|---|---|
| `rtk gain` / `rtk session` | RTK | Session metrics | RTK shell compression only |
| `ctx_stats` | Context Mode | Session metrics, per-tool breakdown | CM sandbox + fetch + index |
| Ed25519 savings ledger | LeanCTX | Cryptographic, hash-chained, batch-verifiable | LeanCTX all planes (wire + read + shell + sandbox) |

**Conflicts:**

1. **No unified number.** Each tracker reports its own savings. SB's `validate-claude-agent-token-budget.sh` (per repo scripts list) checks token budget — which number does it use? If it uses `ctx_stats`, it misses RTK and LeanCTX savings. If it sums all three, it double-counts overlap (e.g., a compressed read counts for both LeanCTX ledger and CM `ctx_stats` if both intercepted).
2. **Ed25519 ledger covers LeanCTX only.** The ledger is tamper-evident but only attests LeanCTX's savings. It does not attest RTK or CM savings. For SB's audit purposes, the ledger is a *partial* audit trail, not a unified one.
3. **Different units.** RTK reports "tokens saved" per command; CM reports "bytes returned to context" per tool; LeanCTX reports "savings %" per read + absolute tokens. Summing these requires a normalization layer SB does not have.

**Medium conflict — resolvable with a normalization/aggregation script, but no such script exists today.**

### 2.8 Runtime governance conflicts (PathJail hard enforcement vs SB cooperative rules)

**SB's governance model:** cooperative. AGENTS.md + `silver-bullet.md` + per-tool `.mdc` rules instruct the model. Hook guards (`planning-file-guard.sh`, `instruction-file-guard.sh`, `workflow-chain-guard.sh`, `orchestrator-directive-guard.sh`, `agent-delegation-guard.sh`) enforce *specific* policies (don't edit `.planning/` state directly, don't edit instruction files outside workflow, etc.). The model is expected to comply; hooks catch violations.

**LeanCTX's governance model:** runtime. PathJail enforces deny-by-default filesystem access. Shell allowlist enforces deny-by-default command execution. The model *cannot* violate — the tool call is blocked at the runtime layer.

**Conflicts:**

1. **PathJail scope vs SB plugin state writes.** SB's hooks write to `${CLAUDE_PLUGIN_ROOT}/state/`, `${CLAUDE_PLUGIN_ROOT}/hooks/`, and workflow state files under `.planning/`. If PathJail jails to the project cwd, plugin state writes (outside cwd) are blocked. **Hard conflict on default PathJail config.** Resolution: PathJail config-dir jail must include `${CLAUDE_PLUGIN_ROOT}` and `.planning/`.
2. **PathJail vs SB's `planning-file-guard`.** SB's guard *allows* specific planning-file edits (e.g., workflow state advancement) and *denies* others (e.g., direct state file edits outside workflow). PathJail's binary deny-by-default does not understand SB's workflow semantics — it would deny *all* planning edits or allow *all* planning edits (depending on jail config). **Semantic conflict** — PathJail is too coarse for SB's nuanced planning-file policy.
3. **Shell allowlist vs SB's Bash hook chain.** SB's `phase-archive.sh` + `completion-audit.sh` run on Bash but do not deny commands — they archive and audit. LeanCTX's shell allowlist *denies* commands not in the allowlist. If LeanCTX denies a command that SB's workflow needs (e.g., a custom `sb-*` script not in LeanCTX's default allowlist), SB workflows break. **Config conflict** — LeanCTX's allowlist must be extended with SB's command vocabulary.
4. **Governance philosophy mismatch.** SB's cooperative model assumes the model is a *participant* in governance (it reads rules, complies, hooks catch edge cases). LeanCTX's runtime model assumes the model is an *adversary* (it cannot be trusted, runtime blocks it). These are not incompatible — SB can use cooperative rules for workflow semantics and LeanCTX for filesystem/command safety — but they require clear layering. **Not a conflict if layered; conflict if both try to own the same policy.**

### 2.9 Rules tax (cumulative AGENTS.md / .mdc files)

**SB's current rules surface (Cursor):**
- `AGENTS.md` (root, ~150 lines)
- `silver-bullet.md` (canonical instruction, large)
- `recommended-tools.mdc` (umbrella)
- `graphify.mdc`
- `agentmemory.mdc`
- `context-mode.mdc` (the context-mode AGENTS.md I'm operating under is itself ~150 lines of mandatory routing rules)
- RTK routing rules (in `silver-bullet.md` §2g)

**Adding LeanCTX rules:**
- `leanctx.mdc` (new — routing rules for LeanCTX's 5 high-level tools + 81 granular tools)
- AGENTS.md additions for LeanCTX routing (when to use LeanCTX vs Context Mode vs RTK)
- PathJail config documentation
- Wire proxy enablement instructions

**Conflict:** the per-turn rules tax grows. Every turn, the model reads all rules files. Adding LeanCTX's rules adds ~100–200 lines of routing instructions. The context-mode AGENTS.md I'm operating under already warns "One unrouted command dumps 56 KB into context" — adding LeanCTX routing rules *increases* the baseline context cost. **This is the hidden tax of the 5-stack:** the tools compress tool *output*, but the rules compress *nothing* — they are pure per-turn overhead.

**Quantification:** 4-stack rules ≈ 4 `.mdc` files × ~100 lines = ~400 lines of routing rules per turn. 5-stack ≈ 500 lines. At ~3 tokens/line, that's ~300 additional tokens per turn from LeanCTX rules alone. Over a 100-turn session, 30K tokens of additional rules tax. LeanCTX's wire proxy may save more than 30K tokens on long sessions — but the rules tax is *certain* overhead while the wire proxy savings are *conditional* on proxy being enabled.

---

## 3. Resolution strategies for each conflict

### 3.1 Hook conflicts → **Ordered layering + event partitioning**

| Hook event | Resolution | Order |
|---|---|---|
| PreToolUse(Read) | **LeanCTX only.** Disable SB's cooperative Read redirect rule when LeanCTX is active. LeanCTX's AST interception subsumes CM's cooperative redirect for the Read tool. CM's `ctx_execute_file` remains available as a *separate* tool for analysis tasks (not Read replacement). | LeanCTX PreToolUse(Read) → model receives compressed content |
| PreToolUse(Bash) | **RTK only for compression; LeanCTX for allowlist only.** Per LeanCTX's documented RTK-addon compat: RTK does shell compression (PreToolUse rewrite); LeanCTX does shell *governance* (allowlist check, no rewrite). Order: LeanCTX allowlist first (deny if not allowed) → RTK compression (rewrite if allowed). | LeanCTX allowlist → RTK rewrite → SB `phase-archive` + `completion-audit` |
| PreToolUse(Edit\|Write\|MultiEdit) | **SB guards first, LeanCTX PathJail last.** SB's semantic guards (planning-file-guard, instruction-file-guard, etc.) run first — they understand workflow semantics. LeanCTX PathJail runs last as a filesystem safety net. Order: 6 SB guards → LeanCTX PathJail. PathJail config must allow `${CLAUDE_PLUGIN_ROOT}` and `.planning/`. | SB guards (6) → LeanCTX PathJail (1) |
| SessionStart | **Both, different concerns.** SB re-injects workflow state; LeanCTX configures read modes + cache prefix. No order dependency. | Parallel |
| PreCompact | **LeanCTX only.** SB does not use PreCompact (it folds compact into SessionStart). LeanCTX's PreCompact captures memory snapshot + CCR markers. | LeanCTX PreCompact |
| PostToolUse | **SB gates first, LeanCTX ledger last.** SB gate validation (policy: was this call allowed?) → LeanCTX ledger signing (attest savings if allowed). | SB gates → LeanCTX ledger |

**Config mechanism:** Claude Code's `hooks.json` supports ordered hook arrays per matcher. SB's existing 6-hook chain on `Edit|Write|MultiEdit` proves the pattern works. Adding LeanCTX hooks at specific positions in the array is a config change, not an architecture change. **Resolution: ordered layering via hooks.json array position.**

### 3.2 MCP conflicts → **Namespace prefixing + LeanCTX addon-mode**

**The `ctx_*` naming collision is the hardest conflict and requires one of three resolutions:**

1. **LeanCTX addon-mode (disable `ctx_*` MCP tools):** Run LeanCTX with only the 5 high-level tools (`lean_*` namespaced) + wire proxy + PathJail + ledger. Disable the 81 granular tools including the `ctx_*` mirror. Context Mode retains the `ctx_*` namespace exclusively. **Pros:** zero naming collision; CM's sandbox/index remains authoritative. **Cons:** LeanCTX's `ctx_graph`/`ctx_callgraph`/`ctx_refactor` (which are *better* than Graphify for code-structural queries) are lost. **Best for:** SB configs where Context Mode + Graphify remain the primary sandbox/graph tools and LeanCTX is purely additive (wire + reads + PathJail + ledger + injection gating).

2. **Namespace prefixing (rename LeanCTX tools to `leanctx_*`):** LeanCTX's `ctx_search` → `leanctx_search`, `ctx_index` → `leanctx_index`, etc. Requires either upstream LeanCTX support for a namespace prefix env var, or an SB-side MCP wrapper that renames tools at registration. **Pros:** both tool sets coexist; model can call either. **Cons:** upstream LeanCTX may not support renaming; SB wrapper adds maintenance burden; the model must learn two tool sets. **Best for:** SB configs where LeanCTX's sandbox/graph tools are wanted alongside Context Mode's.

3. **LeanCTX Tool-Catalog Gateway as proxy:** LeanCTX's gateway proxies downstream MCP at constant context cost. Expose Context Mode's `ctx_*` tools *through* LeanCTX's gateway. LeanCTX's own tools are the 5 high-level tools; CM's tools are proxied. **Pros:** single MCP surface (LeanCTX gateway); constant context cost; no naming collision (gateway disambiguates). **Cons:** LeanCTX becomes a dependency for CM access — if LeanCTX's gateway fails, CM is unreachable. **Best for:** OpenCode (MCP-first) where a single gateway surface is idiomatic.

**Recommended:** Resolution #1 (addon-mode) for Phase 1–2; Resolution #2 (namespacing) for Phase 3 if LeanCTX's code-graph tools are wanted; Resolution #3 (gateway) for OpenCode specifically.

### 3.3 Read-path conflicts → **Complementary use, not substitution**

LeanCTX Read interception (compressed raw content) and Context Mode `ctx_execute_file` (sandbox analysis, stdout-only) serve different use cases:

- **Use LeanCTX Read for:** orientation reads where the model needs to *see* the file content (just compressed) — e.g., reading a source file to edit it.
- **Use Context Mode `ctx_execute_file` for:** analysis reads where the model needs to *derive* something — e.g., count lines, find patterns, extract structure. Raw bytes never enter context; only the answer.

**Resolution:** update AGENTS.md routing rules to distinguish:
- "Reading to **edit** → LeanCTX-compressed Read is fine"
- "Reading to **analyze/count/filter/summarize** → `ctx_execute_file` (Context Mode)"

This preserves Context Mode's sandbox value while accepting LeanCTX's read compression for edit-bound reads. The FTS5 index population concern (§2.4) is addressed by ensuring `ctx_fetch_and_index` and `ctx_batch_execute` (which populate the index) are still called for web fetches and batch analysis — those tools are not bypassed by LeanCTX's Read interception.

### 3.4 Search/index conflicts → **Operator chooses primary index; secondary disabled or namespaced**

**Resolution options:**

1. **Context Mode as primary index, LeanCTX index disabled.** LeanCTX addon-mode (§3.2 resolution #1) disables `ctx_index`/`ctx_search`. CM's FTS5 is the sole search index. **Simplest.** Loses LeanCTX's RRF + progressive throttling (which may be better than CM's ranking — unbenchmarkd).
2. **LeanCTX as primary index, CM index frozen.** Migrate indexing to LeanCTX; CM's `ctx_index` calls deprecated. CM retains `ctx_execute_file`/`ctx_fetch_and_index`/`ctx_batch_execute` (sandbox tools) but `ctx_index`/`ctx_search` are disabled. **Loses CM's published 98% platform hook matrix enforcement.**
3. **Dual index with namespacing** (§3.2 resolution #2). Both indexes active; model chooses `ctx_search` (CM) vs `leanctx_search` (LeanCTX). **Highest flexibility, highest complexity.**

**Recommended:** Resolution #1 for Phase 1 (CM primary, LeanCTX index disabled). Revisit if LeanCTX's search ranking is benchmarked superior.

### 3.5 Memory graph conflicts → **Domain partitioning**

| Graph need | Tool | Rule |
|---|---|---|
| Codebase structural question (how does X call Y?) | Graphify `query`/`path` OR LeanCTX `ctx_graph` | Default: Graphify (existing SB routing); LeanCTX `ctx_graph` only if LSP-backed refactor is needed |
| Codebase refactor (rename X across graph) | LeanCTX `ctx_refactor` | LeanCTX only (Graphify is read-only) |
| Memory/decision graph (what did we decide about X?) | agentmemory `memory_graph_query` | agentmemory only |
| Multimodal corpus (PDF/image/diagram in graph) | Graphify | Graphify only |

**Resolution:** extend `graphify.mdc` routing rule to add: "for LSP-backed refactor operations, use LeanCTX `ctx_refactor`." No other graph routing changes. The three graphs serve disjoint domains; the routing rule just needs to name the disambiguation.

### 3.6 Shell compression conflicts → **RTK for compression, LeanCTX for governance only**

Per LeanCTX's documented RTK-addon compatibility:
- **RTK:** PreToolUse(Bash) shell compression (rewrite). Active.
- **LeanCTX:** PreToolUse(Bash) shell allowlist check (deny/allow, no rewrite). Active.
- **LeanCTX native shell compression:** **disabled** (avoid double compression).

**Order:** LeanCTX allowlist (governance, deny if not allowed) → RTK compression (rewrite if allowed) → SB `phase-archive` + `completion-audit`.

**Accounting:** RTK `rtk gain` reports shell savings; LeanCTX ledger reports wire + read + (disabled shell) savings. No double-counting because LeanCTX shell compression is off. **Resolution: LeanCTX addon config `shell.compression=false`, `shell.allowlist=true`.**

### 3.7 Token accounting conflicts → **Normalization script + Ed25519 as audit overlay**

**Resolution:**

1. **SB `validate-claude-agent-token-budget.sh` uses `ctx_stats` (Context Mode) as the primary budget metric** — it has the most detailed per-tool breakdown and is the existing SB integration point.
2. **RTK `rtk gain` reported as a secondary metric** (shell-specific savings).
3. **LeanCTX Ed25519 ledger used as an audit overlay**, not a budget metric. The ledger attests that the savings reported by `ctx_stats` + `rtk gain` are consistent with LeanCTX's own measurements. If the ledger's hash chain does not validate, flag a discrepancy. **The ledger is tamper-evidence for the aggregate, not a replacement for per-tool metrics.**
4. **Write a normalization script** (`scripts/aggregate-token-savings.sh`) that sums `ctx_stats` + `rtk gain` + LeanCTX ledger and reports a unified number with per-plane breakdown. This does not exist today; it is a small SB script (~50 lines of bash + jq).

### 3.8 Runtime governance conflicts → **PathJail as safety net, SB guards as semantic policy**

**Resolution: layered governance.**

| Layer | Tool | Role |
|---|---|---|
| Semantic policy (workflow-aware) | SB hook guards (`planning-file-guard`, `instruction-file-guard`, `workflow-chain-guard`, etc.) | Understand SB workflow semantics; allow/deny based on workflow state |
| Filesystem safety net (workflow-agnostic) | LeanCTX PathJail | Deny writes outside configured dirs; catch anything SB guards miss |
| Command safety net | LeanCTX shell allowlist | Deny commands not in allowlist; catch anything SB's Bash hooks miss |

**PathJail config must include:**
- Project cwd (always)
- `${CLAUDE_PLUGIN_ROOT}` (SB plugin state + hooks)
- `.planning/` (SB workflow state — may be outside cwd if absolute path configured)
- `${SB_RUNTIME_HOME_ROOT}` (SB runtime home, per repo AGENTS.md: "Never modify the installed plugin cache under `${SB_RUNTIME_HOME_ROOT}/plugins/cache/`")
- Any LeanCTX-specific dirs (its config, ledger, cache)

**Shell allowlist must include:**
- All SB scripts (`scripts/*.sh`, `hooks/*.sh`)
- `graphify`, `agentmemory` CLIs
- `rtk` CLI
- Standard dev tools (`git`, `gh`, `npm`, `python`, `pytest`, `bash`, `jq`, etc.)
- LeanCTX's own CLI (`lean-ctx`)

**Resolution: PathJail config file (`leanctx.pathjail.conf`) with SB-aware paths. Shell allowlist file (`leanctx.shell-allowlist.conf`) with SB command vocabulary. Both shipped as SB install scripts (`scripts/install-leanctx.sh` generates them).**

### 3.9 Rules tax → **Conditional rules loading + rules consolidation**

**Resolution:**

1. **Conditional `.mdc` loading.** Cursor supports conditional rules (context-based activation). LeanCTX's `leanctx.mdc` should activate only when LeanCTX is installed (detected via `recommended_tools.leanctx.enabled_by_user: true` in SB config, same pattern as Graphify/agentmemory). If LeanCTX is not installed, the rules file is inert. **No tax on non-LeanCTX sessions.**
2. **Consolidate routing rules.** Instead of 5 separate `.mdc` files (graphify, agentmemory, context-mode, rtk, leanctx), consolidate into a single `recommended-tools.mdc` with conditional sections. SB already has `recommended-tools.mdc` as the umbrella — extend it rather than adding a 5th file. **Reduces per-turn rules tax by ~100 lines.**
3. **LeanCTX addon-mode reduces rules.** If LeanCTX runs in addon-mode (§3.2 resolution #1), the routing rule is simpler: "LeanCTX handles wire + reads + PathJail; use `ctx_execute_file` for analysis; use Graphify for codebase questions; use agentmemory for memory." No need to document LeanCTX's 81 tools because they are disabled. **Rules tax for addon-mode LeanCTX: ~30 lines, not ~200.**

---

## 4. Per-environment analysis

### 4.1 Cursor (allow-list hooks)

**Cursor's hook model:** allow-list based. Hooks must be explicitly allowed per matcher. SB's `scripts/install-recommended-tools-cursor.sh` installs Graphify + agentmemory + umbrella rules. SB's `install-cursor.sh` installs the SB plugin.

**LeanCTX on Cursor:**
- LeanCTX auto-detects 30+ agents including Cursor (per prior report). LeanCTX's PreToolUse(Read) interception requires Cursor to expose Read as an allow-listable hook. Cursor's hook maturity is lower than Claude Code's — Read interception may not be supported.
- **Wire proxy:** works on Cursor (operates at the API layer, independent of host hooks). ✓
- **AST read modes:** may not work on Cursor if Cursor doesn't expose PreToolUse(Read). ⚠ Degraded.
- **PathJail:** may not work on Cursor if Cursor doesn't expose PreToolUse(Edit|Write) for filesystem interception. ⚠ Degraded.
- **Ed25519 ledger:** works (PostToolUse or out-of-band). ✓
- **Prompt-injection gating:** works (operates on the request body, not host hooks). ✓
- **MCP tools:** Cursor supports MCP; the `ctx_*` naming collision applies. Must use addon-mode (§3.2). ✓ with config.

**5-stack on Cursor — conflicts specific to Cursor:**
- RTK is "Cursor allow-list gated" per prior report — RTK's PreToolUse(Bash) works on Cursor. Adding LeanCTX's PreToolUse(Bash) allowlist requires a second allow-list entry on the same matcher. **Resolvable** (Cursor supports multiple hooks per matcher via allow-list).
- Cursor `.mdc` rules: adding `leanctx.mdc` or extending `recommended-tools.mdc` is the standard SB pattern. ✓
- **Cursor verdict:** 5-stack works with degraded AST read modes. Wire proxy + ledger + injection gating + PathJail (if Edit hook exposed) are the gains. **Manageable.**

### 4.2 Codex (deny-only hooks)

**Codex's hook model:** deny-only. Hooks can *block* tool calls but cannot *transform* tool output. SB's Codex install exposes native `/silver:` entries; SB's hooks on Codex are deny-only policy gates.

**LeanCTX on Codex:**
- **Wire proxy:** works (API layer, no host hook dependency). ✓
- **AST read modes:** **do not work on Codex.** PreToolUse(Read) transformation requires the host to allow hook output to replace tool output. Codex's deny-only model can block the Read but cannot return compressed content. **LeanCTX's headline read-path feature is disabled on Codex.** ✗
- **PathJail (filesystem):** partial. Codex can deny writes (deny-only) but cannot transform paths. PathJail's deny-by-default works; its path-rewriting (if any) does not. ⚠ Partial.
- **PathJail (shell):** works (deny commands not in allowlist). ✓
- **Ed25519 ledger:** works (PostToolUse or out-of-band). ✓
- **Prompt-injection gating:** works (API layer). ✓
- **MCP tools:** Codex supports MCP; `ctx_*` naming collision applies. Addon-mode required. ✓ with config.

**5-stack on Codex — conflicts specific to Codex:**
- **The biggest loss: LeanCTX's AST read-path compression is disabled.** This is the feature that makes LeanCTX unique on the read plane. On Codex, LeanCTX degrades to "wire proxy + PathJail + ledger + injection gating" — still valuable (4 of 5 unique planes) but not the full read-path value.
- SB's Codex hooks are deny-only; adding LeanCTX's deny-by-default allowlist is semantically aligned (both deny). **No philosophical conflict on Codex.**
- **Codex verdict:** 5-stack works with degraded read-path. Wire proxy + PathJail + ledger + injection gating are the gains. **The read-path loss is material — Codex users get 4 of 5 LeanCTX planes.**

### 4.3 Claude Code (full hook system)

**Claude Code's hook model:** the richest. SessionStart, PreToolUse, PostToolUse, Stop, UserPromptSubmit, PreCompact, SubagentStop. Supports ordered multi-hook chains per matcher (SB already chains 6 hooks on `Edit|Write|MultiEdit`). Hooks can transform tool output (PreToolUse can return modified content).

**LeanCTX on Claude Code:**
- **Wire proxy:** works. ✓
- **AST read modes:** works (PreToolUse(Read) can transform output). ✓
- **PathJail (filesystem + shell):** works (PreToolUse can deny). ✓
- **Ed25519 ledger:** works. ✓
- **Prompt-injection gating:** works. ✓
- **MCP tools:** Claude Code supports MCP; `ctx_*` naming collision applies. Addon-mode or namespacing required. ✓ with config.

**5-stack on Claude Code — conflicts specific to Claude Code:**
- Claude Code is where the **full 5-stack can run with complete fidelity.** All 5 LeanCTX planes are operational. All 4 incumbent tools are operational. The only conflict is the `ctx_*` naming collision (resolved via addon-mode or namespacing) and hook chain ordering (resolved via §3.1 ordered layering).
- Hook chain length: SB's `Edit|Write|MultiEdit` already has 6 hooks; adding LeanCTX PathJail = 7. Claude Code supports this (no documented hard limit), but latency compounds. **Measurable but acceptable.**
- **Claude Code verdict:** 5-stack works at full fidelity. This is the reference environment for Phase 1 pilot. **Best case.**

### 4.4 OpenCode (MCP-first, potential 4th target)

**OpenCode's model:** MCP-first. Tools are exposed via MCP; hooks are less mature than Claude Code's. SB has partial OpenCode support (`.opencode/opencode.json` + `.opencode/skills/graphify/SKILL.md`).

**LeanCTX on OpenCode:**
- **Wire proxy:** works (API layer). ✓
- **AST read modes:** depends on OpenCode's PreToolUse support. If OpenCode exposes PreToolUse(Read) with transformation, works. If not, degraded. ⚠ Needs verification.
- **PathJail:** depends on OpenCode's PreToolUse(Edit|Write|Bash) support. ⚠ Needs verification.
- **Ed25519 ledger:** works (PostToolUse or out-of-band). ✓
- **Prompt-injection gating:** works (API layer). ✓
- **MCP tools:** OpenCode is MCP-first — the `ctx_*` naming collision is **most severe here** because all tools are exposed raw via MCP with no hook layer to disambiguate. **Must use LeanCTX Tool-Catalog Gateway (§3.2 resolution #3)** to proxy CM's tools through LeanCTX, presenting a single MCP surface.

**5-stack on OpenCode — conflicts specific to OpenCode:**
- **The `ctx_*` naming collision is the dominant conflict.** OpenCode has no hook layer to route around it. The Tool-Catalog Gateway is the resolution — but it makes LeanCTX a dependency for CM access (if LeanCTX gateway fails, CM is unreachable).
- **LeanCTX as OpenCode enabler:** LeanCTX's auto-detect + Tool-Catalog Gateway could actually *help* SB's OpenCode support. Instead of SB writing separate OpenCode integrations for each of the 4 tools, LeanCTX's gateway provides a uniform MCP surface. **LeanCTX could be the OpenCode integration path for the 4-stack.**
- **OpenCode verdict:** 5-stack works *if* the Tool-Catalog Gateway is used as the MCP surface. LeanCTX may be *more valuable* on OpenCode than on Claude Code because it solves the MCP integration problem the 4-stack alone cannot. **Highest architectural fit, highest config complexity.**

### 4.5 Per-environment summary

| Environment | Wire | AST reads | PathJail | Ledger | Injection | MCP collision | 5-stack verdict |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| Claude Code | ✓ | ✓ | ✓ | ✓ | ✓ | Addon-mode | **Full fidelity — reference env** |
| Cursor | ✓ | ⚠ | ⚠ | ✓ | ✓ | Addon-mode | **Degraded reads/PathJail — manageable** |
| Codex | ✓ | ✗ | ⚠ | ✓ | ✓ | Addon-mode | **No AST reads — 4 of 5 planes** |
| OpenCode | ✓ | ⚠ | ⚠ | ✓ | ✓ | Gateway mode | **Gateway required — highest complexity, potential enabler** |

---

## 5. 5-stack synergy assessment

### 5.1 What SB gains

| Gain | Plane | Value to SB | Confidence |
|---|---|---|:---:|
| Wire request compression | Model API boundary | Direct cost reduction on every multi-turn session; the largest uncaptured savings surface | High |
| AST read-path compression | Read tool boundary | Compressed reads for edit-bound file access; ~13-token cached re-reads | High |
| PathJail runtime | Filesystem/command safety | Runtime enforcement that does not depend on model compliance with AGENTS.md rules | High |
| Ed25519 savings ledger | Token audit | Tamper-evident attestation of savings; SB can use for delivery evidence | High |
| Prompt-injection pre-model gating | Security | Runtime defense that SB's `ai-llm-safety` skill covers only instructionally | High |
| `ctx_refactor` LSP-backed | Code intelligence write-path | Rename/references across graph — Graphify is read-only; SB's tier 2 becomes write-capable | Medium |
| `proxy.effort` reasoning-effort pinning | Cost control | Pin reasoning effort per task type; SB's workflow steps could pin low-effort for routine gates, high-effort for planning | Medium |
| Cache-prefix volatility relocation | Cache economics | Relocates dates/UUIDs/SHAs out of cacheable prefix → better prompt cache hit rate | Medium |
| `ctx_quality` cognitive-complexity hotspots | Code quality | Token-quality-tax + navigability scoring for SB's review workflows | Medium |

**Total: 5 high-confidence + 4 medium-confidence gains. The 5 high-confidence gains are planes the 4-stack cannot occupy at all.**

### 5.2 What SB loses

| Loss | Cause | Severity |
|---|---|:---:|
| `ctx_*` naming collision | LeanCTX mirrors CM's tool names | **Hard blocker** if unresolved; resolved by addon-mode |
| Double FTS5 index | Both LeanCTX and CM index content | Medium — resolvable by disabling LeanCTX index |
| Rules tax growth | +30–200 lines of routing rules per turn | Low–Medium — resolvable by conditional loading + consolidation |
| Hook chain latency | +1–2 hooks per matcher | Low — measurable but acceptable on Claude Code |
| Install surface growth | 5 tools not 4; 5 install scripts not 4 | Low — one additional `install-leanctx.sh` |
| Maintenance burden | 5th tool-gate hook (`leanctx-gate`); 5th tool docs (`docs/LEANCTX.md`); 5th platform install test | Medium — ongoing SB maintainer cost |
| Operational complexity for users | 5 tools to configure, debug, update | Medium — mitigated by LeanCTX's single-binary + auto-detect |
| Double-counted savings | RTK + CM + LeanCTX each claim savings | Low — resolvable by normalization script (§3.7) |

### 5.3 Diminishing returns analysis

**The 4-stack already covers 4 planes:** shell (RTK), sandbox (CM), memory (AM), code-graph (Graphify). LeanCTX overlaps on all 4 + adds 5 new planes.

**On the 4 overlapping planes:** diminishing returns are real. LeanCTX's shell compression ≈ RTK's (97% coverage); running both is double compression (resolved by addon-mode, but the net gain on the shell plane is ~0). LeanCTX's sandbox ≈ CM's (95% coverage); running both is double index (resolved by disabling LeanCTX index; net gain ~0 on sandbox plane). LeanCTX's memory is thinner than agentmemory's (87% / arguably 80–85%); running both is not overlapping but complementary (LeanCTX for solo memory, agentmemory for orchestration — no conflict). LeanCTX's code-graph ≈ Graphify's (99% for code); running both is dual graph (resolved by domain partitioning; net gain = LSP refactor only).

**On the 5 new planes:** no diminishing returns. These are planes the 4-stack does not occupy. The gain is 1:1 — LeanCTX's wire proxy is the only wire proxy; LeanCTX's AST reads are the only AST reads; etc.

**Net assessment:** the 5-stack's value is concentrated in the 5 new planes, not the 4 overlapping planes. **If SB values the 5 new planes (wire, AST reads, PathJail, ledger, injection gating), the 5-stack is net-positive. If SB does not value those 5 planes (e.g., SB is happy with cooperative rules and does not want runtime enforcement), the 5-stack is net-negative (added complexity, no new capability).**

**The decisive question for SB:** does SB want *runtime* enforcement (PathJail, injection gating) in addition to *cooperative* enforcement (AGENTS.md rules)? SB's thesis is "enforced process" — the word "enforced" suggests yes. SB's website: "blocks unsafe commits, PRs, and releases until the evidence is real." LeanCTX's PathJail + injection gating are *runtime* enforcement that strengthens SB's "enforced" claim. **On SB's own thesis, the 5-stack is net-positive.**

### 5.4 The pipeline synergy question

The consolidated report (Finding 5) noted 3/6 models flagged pipeline synergy loss as critical. For the *additive* (5-stack) question, pipeline synergy is *preserved* — the 4-stack pipeline (RTK → CM → AM → Graphify) still runs. LeanCTX is *additive*, not substitutive. The pipeline is:

> **LeanCTX compresses wire** → **RTK compresses shell** → **LeanCTX compresses reads** → **Context Mode sandboxes analysis** → **agentmemory captures decisions** → **Graphify retrieves patterns** → **LeanCTX ledger attests savings**

The 5-stack pipeline is the 4-stack pipeline with LeanCTX wrapping the *boundaries* (wire before, reads during, audit after). **No pipeline synergy is lost in the additive configuration.** This is a stronger position than the replacement configuration (where pipeline synergy was the main loss).

---

## 6. Recommendation

### 6.1 Should SB add LeanCTX?

**Yes — in addon-mode, phased, Claude Code first.** The 5 net-new planes (wire, AST reads, PathJail, ledger, injection gating) are genuine gaps in SB's 4-stack that align with SB's "enforced process" thesis. The 9 conflicts are all resolvable with the layering strategy in §3. The `ctx_*` naming collision is the only hard blocker, and addon-mode (disable LeanCTX's `ctx_*` MCP tools, keep wire + reads + PathJail + ledger + injection gating + the 5 high-level tools) eliminates it.

**Do NOT add LeanCTX as a naive 5th tool with all 81 MCP tools enabled.** That configuration is operationally broken by the `ctx_*` naming collision.

### 6.2 Phased adoption path

#### Phase 0 — Pre-flight (do not skip)

1. **Verify LeanCTX addon-mode config exists.** Confirm LeanCTX supports disabling the `ctx_*` MCP tool surface while keeping wire proxy + AST reads + PathJail + ledger + injection gating. If addon-mode is not supported, **block Phase 1** until upstream LeanCTX adds it or SB writes a wrapper.
2. **Verify PathJail config-file format.** Confirm PathJail accepts a config file listing allowed dirs (must include `${CLAUDE_PLUGIN_ROOT}`, `.planning/`, `${SB_RUNTIME_HOME_ROOT}`). If PathJail is hardcoded to cwd only, **block Phase 1**.
3. **Verify shell allowlist config-file format.** Confirm the allowlist accepts a config file listing allowed commands (must include SB scripts, `graphify`, `agentmemory`, `rtk`, `lean-ctx`, standard dev tools). If hardcoded, **block Phase 1**.
4. **Write `docs/LEANCTX.md`** (parallel to `docs/RTK.md`, `docs/CONTEXT-MODE.md`, `docs/AGENTMEMORY.md`, `docs/GRAPHIFY.md`). Document addon-mode, PathJail config, shell allowlist config, hook ordering, and the `ctx_*` collision resolution.
5. **Add `recommended_tools.leanctx` config schema** to `.silver-bullet.json` (parallel to `recommended_tools.graphify`, `.agentmemory`, `.rtk`, `.context_mode`). Fields: `enabled_by_user`, `addon_mode`, `wire_proxy_enabled`, `pathjail_config`, `shell_allowlist_config`.

#### Phase 1 — Claude Code pilot (addon-mode only)

1. **Target: Claude Code only.** It is the only environment with full hook fidelity (§4.3).
2. **Config: addon-mode.** Disable LeanCTX's `ctx_*` MCP tools. Enable: wire proxy, AST read modes, PathJail, Ed25519 ledger, prompt-injection gating, `ctx_refactor` (LSP), `ctx_quality`, `ctx_callgraph` (these don't collide with CM/Graphify names). Disable: `ctx_search`, `ctx_index`, `ctx_batch_execute`, `ctx_execute`, `ctx_execute_file`, `ctx_fetch_and_index`, `ctx_stats`, `ctx_purge` (Context Mode retains these).
3. **Hook ordering:** per §3.1. Insert LeanCTX hooks at documented positions in `hooks.json`.
4. **PathJail config:** per §3.8. Include `${CLAUDE_PLUGIN_ROOT}`, `.planning/`, `${SB_RUNTIME_HOME_ROOT}`.
5. **Shell allowlist:** per §3.8. Include SB scripts + standard dev tools.
6. **RTK coexistence:** LeanCTX shell compression OFF (§3.6); RTK remains shell compressor; LeanCTX shell allowlist ON.
7. **Rules:** add `leanctx.mdc` with conditional loading (§3.9); extend `recommended-tools.mdc`.
8. **Add `leanctx-gate` hook** (parallel to `graphify-gate`, `agentmemory-gate`, `context-mode-gate`, `token-compression-tools-gate`).
9. **Add `scripts/install-leanctx.sh`** (parallel to `enable-rtk-context-mode.sh`, `graphify-am-global-setup.sh`). Generates PathJail config + shell allowlist from SB's known paths.
10. **Pilot duration: 4 weeks.** Measure: tokens consumed (via `ctx_stats` + LeanCTX ledger), hook chain latency, PathJail false-positive rate, wire proxy savings, prompt-injection gating triggers.
11. **Success criteria:** no `ctx_*` naming collisions; PathJail false-positive rate < 2%; wire proxy savings > 10% on multi-turn sessions; hook chain latency increase < 50ms per tool call; zero SB workflow regressions.

#### Phase 2 — Cursor rollout + namespace evaluation

1. **Target: Claude Code (production) + Cursor (pilot).**
2. **Cursor config:** same addon-mode. Accept degraded AST read modes if Cursor doesn't expose PreToolUse(Read). Wire proxy + ledger + injection gating are the primary Cursor gains.
3. **Evaluate namespacing (§3.2 resolution #2):** if Phase 1 shows that LeanCTX's `ctx_search`/`ctx_index` (disabled in addon-mode) would add value over Context Mode's, work with LeanCTX upstream (or write an SB MCP wrapper) to namespace LeanCTX tools as `leanctx_*`. Re-enable the namespaced tools.
4. **Write `scripts/install-leanctx-cursor.sh`** (parallel to `install-recommended-tools-cursor.sh`).
5. **Extend `sb-diagnostics.sh`** to report LeanCTX tier (parallel to Graphify/agentmemory/RTK/CM tier reporting).

#### Phase 3 — Codex + OpenCode

1. **Codex:** addon-mode with documented degraded AST reads (§4.2). Wire proxy + PathJail (shell) + ledger + injection gating are the 4 operational planes. Update `docs/LEANCTX.md` with Codex degradation notes.
2. **OpenCode:** use LeanCTX Tool-Catalog Gateway (§3.2 resolution #3) as the MCP surface. Proxy CM's `ctx_*` tools through LeanCTX's gateway. This may actually *enable* SB's OpenCode support — LeanCTX becomes the OpenCode integration layer for the 4-stack.
3. **Write `scripts/install-leanctx-opencode.sh`** (parallel to OpenCode's partial `.opencode/opencode.json` support).
4. **Update `docs/code-intelligence-contract.md`** to add LeanCTX tier (1e: runtime governance + wire compression; 2b: LSP refactor via `ctx_refactor`).

#### Phase 4 — Evaluate RTK retirement

1. **Only after Phase 1–3 are stable.** Evaluate whether LeanCTX's native shell compression (97% RTK coverage) can replace standalone RTK.
2. **Condition:** LeanCTX shell compression enabled (not addon-mode's `shell.compression=false`); RTK standalone disabled; LeanCTX ledger reports shell savings.
3. **Risk:** loses RTK's `rtk gain`/`rtk session` analytics; loses RTK's per-CLI compressor depth for niche commands. Per prior report, RTK is the most replaceable incumbent (97% coverage + documented addon compat).
4. **Do NOT retire Context Mode** (`CTX_FETCH_STRICT` is non-negotiable for regulated personas).
5. **Do NOT retire agentmemory** (53-tool orchestration is non-replicable for ops-at-scale).
6. **Do NOT retire Graphify** (multimodal corpus + `wiki/`/`GRAPH_REPORT.md` artifact ecosystem is non-replicable).

### 6.3 What NOT to do

1. **Do not install LeanCTX with all 81 MCP tools enabled alongside the 4-stack.** The `ctx_*` naming collision is a hard blocker.
2. **Do not enable both RTK shell compression and LeanCTX native shell compression simultaneously.** Double compression; double-counted savings.
3. **Do not enable both LeanCTX FTS5 index and Context Mode FTS5 index simultaneously.** Double disk; split recall; naming collision.
4. **Do not enable LeanCTX PathJail without configuring SB-aware paths.** Default PathJail (cwd-only) blocks SB plugin state writes.
5. **Do not enable LeanCTX shell allowlist without configuring SB-aware commands.** Default allowlist blocks SB scripts.
6. **Do not replace Context Mode, agentmemory, or Graphify with LeanCTX.** Their depth planes (`CTX_FETCH_STRICT`, 53-tool orchestration, multimodal corpus) are not duplicated by LeanCTX. (This was the prior report's verdict; it holds for the additive question too.)
7. **Do not skip the 4-week Phase 1 pilot.** The conflicts are resolved *in theory* by §3; the pilot validates them *in practice*.

### 6.4 The bottom line

**Adding LeanCTX to the SB 4-stack is net-positive in addon-mode, phased, Claude Code first.** The 5 net-new planes (wire, AST reads, PathJail, ledger, injection gating) align with SB's "enforced process" thesis and are not duplicated by any of the 4 incumbents. The 9 conflicts are resolvable with ordered hook layering, addon-mode config, PathJail/allowlist SB-aware config, conditional rules loading, and a token-savings normalization script. The `ctx_*` naming collision is the only hard blocker and is eliminated by addon-mode (disable LeanCTX's `ctx_*` MCP tools; Context Mode retains that namespace).

**The 5-stack is not "4 tools + 1 more doing the same thing."** It is "4 tools on their home planes + 1 tool wrapping the boundaries (wire before, reads during, audit after, runtime enforcement throughout)." The pipeline is preserved; the synergy is additive; the diminishing returns are confined to the 4 overlapping planes (resolved by addon-mode disabling the overlapping surfaces).

**SB's thesis is "enforced process plus retrieval at 10x lower cost."** LeanCTX's wire proxy serves the "10x lower cost" claim directly; PathJail + injection gating serve the "enforced" claim directly. **On SB's own stated thesis, the 5-stack is the more complete realization of SB's goals than the 4-stack alone.**

---

## 7. Limitations & Caveats

- **No installed pilot.** This analysis is paper-architectural. The Phase 1 pilot (§6.2) is the validation step. All conflict resolutions are theoretically sound but unverified in production.
- **LeanCTX addon-mode config unverified.** Phase 0 step 1 verifies that LeanCTX supports disabling the `ctx_*` MCP surface while keeping wire + reads + PathJail + ledger + injection gating. If LeanCTX does not support this config, Phase 1 is blocked and the recommendation changes to "wait for upstream LeanCTX addon-mode support."
- **PathJail config-file format unverified.** Phase 0 step 2 verifies PathJail accepts a config file. If PathJail is hardcoded to cwd only, the SB plugin state write conflict is a hard blocker.
- **Hook chain latency unmeasured.** Adding 1–2 hooks per matcher has theoretical overhead; the Phase 1 pilot measures actual latency.
- **OpenCode support is partial.** SB has `.opencode/opencode.json` + a Graphify skill but not full OpenCode target-environment support. Phase 3 OpenCode rollout depends on SB first completing OpenCode as a target environment.
- **LeanCTX snapshot drift.** LeanCTX ships near-daily (200+ releases per prior report). Config options (addon-mode, PathJail config, shell allowlist config) may change between this analysis and Phase 0.
- **No head-to-head benchmark.** Per prior report and consolidated report (6/6 model consensus): no controlled cross-tool benchmark exists. The "net-positive" verdict is an architectural inference from the 5 net-new planes + 9 resolvable conflicts, not a measured outcome.
- **SB repo bias.** This analysis is conducted from within the SB repo (the research artifacts live in `.planning/archive/research/`). The recommendation is made in SB's interest but inherits SB's framing of the 4-stack as the baseline.

---

## 8. Bibliography

### Primary inputs (this follow-up)

- [F1] `glm-5.2-report.md` — prior replacement analysis (this session's prior output)
- [F2] `consolidated.md` — 6-model consolidated report (this session's prior output)
- [F3] `gist-leanctx-capability-analysis.md` — 200-row feature matrix (upstream gist)
- [F4] `https://sb.alolabs.dev/` — SB website, fetched and indexed 2026-07-07 (58 sections, 36.4 KB)

### SB repo sources (fetched and indexed 2026-07-07)

- [F5] `hooks/hooks.json` — SB hook configuration (SessionStart, PreToolUse, PostToolUse, Stop, UserPromptSubmit; 12 hook layers, ~20 hook scripts)
- [F6] `docs/code-intelligence-contract.md` — capability tiers 0/1/1b/1c/1d/2/3; Graphify/agentmemory/RTK-CM/Alumnium tier mapping
- [F7] `AGENTS.md` (repo root) — SB repo guide, working rules, release policy, graphify rules
- [F8] `.silver-bullet.json` — SB plugin manifest
- [F9] `scripts/` — install scripts (install-claude.sh, install-codex.sh, install-cursor.sh, install-recommended-tools-cursor.sh, enable-rtk-context-mode.sh, optimize-rtk-context-mode.sh, graphify-am-global-setup.sh; no install-leanctx.sh yet)
- [F10] `.opencode/opencode.json` + `.opencode/skills/graphify/SKILL.md` — partial OpenCode support
- [F11] `docs/RTK.md`, `docs/CONTEXT-MODE.md`, `docs/AGENTMEMORY.md`, `docs/GRAPHIFY.md` — per-tool docs (referenced, not re-fetched)

### Re-validated from prior report

- [F12] LeanCTX homepage + architecture + compatibility + compare + GitHub README + LEANCTX_FEATURE_CATALOG.md + savings-ledger docs (per `glm-5.2-report.md` bibliography [1]–[7])
- [F13] RTK GitHub README (per `glm-5.2-report.md` bibliography [8])
- [F14] Context Mode GitHub README (per `glm-5.2-report.md` bibliography [9])
- [F15] agentmemory GitHub README (per `glm-5.2-report.md` bibliography [10])
- [F16] Graphify GitHub README (per `glm-5.2-report.md` bibliography [11])

---

## 9. Methodology Appendix

### Phase 1 — Inputs
- Read `glm-5.2-report.md` (full 557 lines, prior output).
- Read `consolidated.md` (full 482 lines, 6-model consolidated report).
- Fetched + indexed `https://sb.alolabs.dev/` (58 sections, 36.4 KB).

### Phase 2 — SB repo verification
- Ran 9-command batch (`ctx_batch_execute`, concurrency 4) covering: hooks.json structure, root AGENTS.md, recommended-tools docs, LeanCTX references in repo, hook scripts list, OpenCode references, plugin manifest, install scripts, code-intelligence-contract.
- Indexed 25 sections, searched 7 queries for: hook events, tool integration, OpenCode support, LeanCTX references, hook enforcement tiers, install scripts, code intelligence contract.

### Phase 3 — Conflict identification
- Mapped SB's 12 hook layers × LeanCTX's hook surface → identified 5 hook conflicts (§2.1).
- Mapped SB's MCP tool surface × LeanCTX's 81 MCP tools → identified `ctx_*` naming collision as hard blocker (§2.2).
- Mapped SB's read-path (cooperative CM redirect) × LeanCTX's read-path (runtime interception) → identified philosophical substitution conflict (§2.3).
- Mapped CM FTS5 × LeanCTX FTS5 → identified dual-index conflict (§2.4).
- Mapped Graphify × agentmemory `memory_graph_query` × LeanCTX `ctx_graph` → identified triple-graph conflict (§2.5).
- Mapped RTK shell × LeanCTX shell → identified double-compression conflict (§2.6).
- Mapped RTK `rtk gain` × CM `ctx_stats` × LeanCTX Ed25519 ledger → identified triple-tracker conflict (§2.7).
- Mapped SB cooperative rules × LeanCTX PathJail runtime → identified governance philosophy mismatch (§2.8).
- Mapped SB rules surface × LeanCTX rules addition → identified rules tax growth (§2.9).

### Phase 4 — Resolution design
- For each conflict, designed a resolution via: ordered layering (hooks), addon-mode (MCP namespace), complementary use (read-path), operator config (FTS5, PathJail, shell allowlist), domain partitioning (graphs), normalization (token accounting), conditional loading (rules).

### Phase 5 — Per-environment analysis
- Mapped each LeanCTX plane to each environment's hook/MCP capabilities: Claude Code (full fidelity), Cursor (allow-list, degraded reads), Codex (deny-only, no AST reads), OpenCode (MCP-first, gateway required).

### Phase 6 — Synergy assessment
- Net gains: 5 high-confidence + 4 medium-confidence planes.
- Net losses: 1 hard blocker (resolvable) + 7 medium/low conflicts (resolvable).
- Diminishing returns: confined to 4 overlapping planes (resolved by addon-mode).
- Pipeline synergy: preserved (additive, not substitutive).

### Phase 7 — Recommendation
- Phased adoption: Phase 0 (pre-flight verification), Phase 1 (Claude Code pilot, addon-mode), Phase 2 (Cursor + namespace evaluation), Phase 3 (Codex + OpenCode via gateway), Phase 4 (evaluate RTK retirement).
- "What NOT to do" list to prevent naive deployment failures.

### Phase 8 — Package
- Output written to `/Users/shafqat/projects/silver-bullet/repo/.planning/archive/research/2026-07-05/2026-07-05-context-tools-feature-matrix-ultradeep/multi-ai-deep-research-out/followup-glm-5.2.md`.
- Format: Executive Summary → Benefit Assessment → Conflict Identification (9 categories) → Resolution Strategies (9 categories) → Per-Environment Analysis (4 environments) → 5-Stack Synergy Assessment → Recommendation (phased) → Limitations → Bibliography → Methodology.
- Primary inputs: prior glm-5.2 report + consolidated report + SB website + SB repo (hooks.json, code-intelligence-contract.md, AGENTS.md, .silver-bullet.json, scripts/, .opencode/).
- No curl/wget/WebFetch used per AGENTS.md routing rules; all web content via `ctx_fetch_and_index` + `ctx_search`; all repo content via `ctx_batch_execute` + `ctx_search`.

# Research Report: Context Mode vs Lean Context for Agentic Coding

## Executive Summary

This ultradeep AF-DECIDE study compared **Context Mode** and **Lean Context (LeanCTX)** as context-management solutions for agentic coding and AI-assisted software engineering, with emphasis on Silver Bullet (SB) recommended-tool policy. Live retrieval on 2026-07-05 fetched current public documentation from leanctx.com and upstream Context Mode sources, triangulated against SB integration docs (`docs/CONTEXT-MODE.md`, `silver-bullet.md`, `docs/code-intelligence-contract.md`). `search-cli` was unavailable; fallback used `ctx_fetch_and_index` and local repo docs.

**Primary finding:** the products solve overlapping but non-identical problems. LeanCTX positions as a full **context engineering layer**—one Rust binary with five subsystems covering read routing (AST modes), optional wire-side request compression, project memory, PathJail governance, and an Ed25519-signed savings ledger [1][2][5][12]. Context Mode focuses on **MCP-protocol sandboxing**: raw tool and fetch output stays in an isolated subprocess, with FTS5-backed `ctx_search`, PreCompact session recovery, and hook-driven routing across 17+ platforms [6][7]. Both are local-first with no mandatory cloud [1][6].

**Recommendation for Silver Bullet:** retain **Context Mode as the default recommended token-compression tool** (tier 1c) because SB already ships install gates, hook verification, ELv2 consent disclosure, and instruction-fragment enforcement paired with RTK shell compression [8][9][10]. Recommend **Lean Context when** teams need Apache-2.0 licensing, read-path AST compression as the primary savings surface, wire-side prompt-cache-preserving proxying, PathJail or shell allowlist governance, or cryptographically verifiable savings exports for finance/compliance [3][5][12]—especially outside SB's current hook catalog.

**Confidence:** medium-high for SB adoption guidance; medium for absolute superiority claims because vendor token-reduction percentages were not independently benchmarked in this run. Residual risks include integration cost of adding a second context layer, doc drift between Lean MCP tool counts, and Context Mode's ELv2 constraint for commercial bundling [8].

---

## Introduction

### Research Question

For agentic coding and AI-assisted software engineering workflows, which context management solution is better: Context Mode or Lean Context, and under what conditions should Silver Bullet recommend one over the other?

### Scope and Methodology

Research followed the SB `FS-SILVER_DEEP_RESEARCH` ultradeep pipeline: scope, plan, live retrieve, triangulate, outline, synthesize, critique, package. Twelve sources were registered in `sources.jsonl` with twenty-eight evidence spans in `evidence.jsonl`. Graphify oriented the run before exploration. Provider probe showed `search-cli` and `search` absent from PATH; primary retrieval used Context Mode's own `ctx_fetch_and_index` against seven public URLs plus three local SB documents—a deliberate irony noted in `run_manifest.json`.

### Key Assumptions

We assume Cursor with MCP and PreToolUse hooks as the reference SB host, that comparison scope excludes general enterprise RAG platforms, and that vendor marketing metrics (e.g., LeanCTX "60–90% fewer tokens") are recorded as stated claims pending independent measurement.

---

## Main Analysis

### Finding 1: Architectural Framing — Sandbox vs Context Engineering Layer

LeanCTX describes itself as "the context engineering layer for AI agents" implemented as one local Rust binary that "decides what they read, remembers what they learn, guards what they touch, and signs the proof" [1]. Its architecture page states that compression on read and wire paths is **one of five subsystems**, with every original remaining locally retrievable [2]. Capabilities are grouped into routing (ten read modes including AST signatures), memory (sessions, project knowledge, handoffs), security (PathJail, shell allowlist), request compression (optional local proxy), and provable savings [2][5].

Context Mode's README frames a narrower but deep specialty: it "operates at the MCP protocol layer" so "raw data stays in a sandboxed subprocess and never enters your context window" [6]. The tool surface centers on `ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`, `ctx_fetch_and_index`, and `ctx_search`, plus meta tools (`ctx_stats`, `ctx_doctor`) [6][7]. Session continuity relies on hooks including **PreCompact** to preserve tasks and decisions across compaction events [6].

For agentic coding, the architectural distinction matters: LeanCTX intervenes earlier in the **read and shell path** (before tokens reach the model), while Context Mode intervenes at the **MCP tool boundary** (after the agent chooses a tool, before results flood context). SB's current enforcement rules target the latter pattern—mandating `ctx_*` for large file analysis and MCP-heavy output [10].

### Finding 2: Retrieval, Indexing, and Token Savings Models

LeanCTX advertises "60–90% fewer tokens per read" and "~13 tokens per cached re-read" on its homepage [1]. Its GitHub repository documents **hybrid integration**: MCP for cached reads plus shell hooks for command compression, and an adaptive `ModePredictor` that learns optimal read modes per file type across ten fidelity levels down to AST signatures [5]. An optional **request compression proxy** compresses system prompt, history, and tool output in a prompt-cache-safe manner on the wire [2]. The pricing page emphasizes that savings are "request-side estimates produced by the free, local engine" and can be verified via an Ed25519-signed, hash-chained ledger [3][12].

Context Mode documents sandbox savings through worked examples—e.g., deep repo research at "94% saved" relative to raw fetch size when using batched `ctx_*` calls [6]. Search uses **FTS5** with Porter stemming and trigram tokenizers merged via Reciprocal Rank Fusion [6]. Fetch hardening blocks non-HTTP schemes and cloud metadata endpoints by default [6]. SB positions Context Mode alongside **RTK** for shell output compression rather than duplicating shell hooks inside Context Mode itself [9][10]; LeanCTX explicitly lists RTK as a compatible compression addon, suggesting a composable stack rather than mutual exclusion [1].

**Implication:** LeanCTX offers broader compression surfaces (read + wire + shell native); Context Mode offers disciplined MCP sandboxing with proven hook integration in SB. Token savings claims are not directly comparable without a shared benchmark harness.

### Finding 3: Agent UX, Installation, and Runtime Complexity

LeanCTX installation is advertised as one command (`curl -fsSL https://leanctx.com/install.sh | sh`) followed by `lean-ctx setup`, which auto-detects editors and wires hooks and MCP servers [1][4]. The binary can also be built from Rust source [4]. MCP configuration requires only `"command": "lean-ctx"` with stdio transport [4]. This single-binary model reduces Node version coupling.

Context Mode requires **Node.js >= 22.5** (or Bun), global `npm install -g context-mode`, and per-host merging of MCP config, hooks, and routing rules [6][8]. SB's `docs/CONTEXT-MODE.md` documents Cursor wiring via plugin or manual MCP/hooks merge, notes Windows requires WSL, and warns about duplicate hook entries and the Cursor `additional_context` surfacing bug [8]. Without the instruction fragment in project docs, "Context Mode savings drop to zero" per SB documentation [8].

**UX tradeoff:** LeanCTX optimizes for zero-config breadth across 30+ tools [1][11]; Context Mode optimizes for deep integration on fewer hosts with explicit agent rules—a fit for SB's consent-and-fragment model but higher onboarding friction.

### Finding 4: IDE and CLI Integration — Cursor, Claude, Codex

LeanCTX's compatibility matrix places **Cursor** in "CLI-Redirect" hybrid mode alongside Claude Code and Codex CLI-Redirect, while JetBrains, VS Code, and Zed use MCP-only mode [1][11]. GitHub docs enumerate hybrid vs MCP-only integration modes with ~80 MCP tools in protocol-only agents [5].

Context Mode supports Cursor via marketplace plugin (Windows robocopy/symlink path) or manual `~/.cursor/mcp.json` plus `hooks.json` and `.cursor/rules/context-mode.mdc` [6][8]. Codex, Claude Code plugin marketplace, OpenCode, and others have documented hook manifests [6]. SB lists Goose as **unsupported** and Hermes as partial for Context Mode [8].

For SB's tri-host story (Cursor, Claude, Codex), both products cover the core surfaces; LeanCTX claims wider agent coverage (30+), while Context Mode has **first-party SB install scripts and gates** today [8][10].

### Finding 5: Privacy, Security, Local and Offline Behavior

Both vendors commit to local processing. LeanCTX FAQ states compression, caching, ledger, and project memory run locally with nothing uploaded except opt-in anonymous leaderboard aggregates [1]. Context Mode states "Nothing leaves your machine" with SQLite databases in the home directory [6].

Security depth differs in emphasis. LeanCTX **PathJail** canonicalizes paths and confines file access to the workspace root, with deny-by-default shell allowlists and signed evidence bundles [2]. Context Mode extends host permission rules into the MCP sandbox, redacts sensitive MCP tool_input fields before persistence, and hardens `ctx_fetch_and_index` against SSRF-style targets [6]. Neither requires network connectivity for core local features.

Offline/air-gapped enterprise deployment is explicit on LeanCTX's enterprise plane [3]; Context Mode's optional Insight SaaS dashboard is out of SB scope [8].

### Finding 6: Maturity, Documentation, Licensing, and Pricing

LeanCTX is Apache-2.0 licensed on GitHub [5]. Local use is "free forever" with CI enforcement stated on the pricing page [3]. Commercial paths include Team shared context, Enterprise (SSO, fleet policies), supporter subscriptions from $5/month, and outcome-based pilots tied to verified savings [3].

Context Mode uses **Elastic License 2.0**, which permits use and modification but restricts offering as a hosted service and requires retaining license notices [6]. SB surfaces ELv2 at consent via `recommended_tools.context_mode.license_note` [8]—a material constraint for teams shipping SB-derived products that bundle context tooling.

Documentation quality for both is strong on install paths; Context Mode's README is exceptionally long with per-platform collapsible sections [6]. LeanCTX's site emphasizes benchmarks and governance narratives [1][2].

### Finding 7: Fit for Silver Bullet Recommended-Tool Policy

SB's code intelligence contract places token compression at **tier 1c**: "RTK shell wiring; Context Mode MCP/fragment" complementing Graphify retrieval and agentmemory capture without evidence-tier conflict [9]. `silver-bullet.md` mandates Context Mode usage for files > 5 KB and MCP-heavy results when opted in [10]. Hooks verify Node version, CLI install, MCP wiring, and instruction fragment presence [8].

LeanCTX is **not** in SB's recommended-tools catalog today. Adding it would require new consent flows, hook gates, docs parity, and clarity on stacking with existing RTK + Context Mode guidance. However, LeanCTX's Apache-2.0 license and read-path compression could address gaps Context Mode does not claim—especially wire-side proxying and PathJail—while listing RTK as an addon suggests intentional composability [1].

---

## Synthesis and Insights

### Patterns Identified

Three patterns emerge from triangulation. First, **compression surface area** correlates with product scope: LeanCTX is multi-layer; Context Mode is MCP-centric. Second, **SB operational maturity** currently favors Context Mode because enforcement, docs, and synergies are implemented. Third, **licensing** creates a fork: Apache-2.0 (Lean) vs ELv2 (Context Mode) is decisive for commercial redistribution scenarios [5][8].

### Novel Insights

The comparison is not a pure substitute decision. SB's stack already splits shell (RTK) from MCP analysis (Context Mode) [9][10]. LeanCTX could theoretically unify read and shell compression in one binary but would overlap RTK and Context Mode unless scoped narrowly (e.g., read-path only). LeanCTX's savings ledger addresses an SB gap: **provable token economics** for enterprise adopters—Context Mode offers `ctx_stats` session metrics but not Ed25519 audit exports [6][12].

### Implications for SB

Default guidance should remain Context Mode for opted-in tier 1c. SB should publish a **decision matrix** routing LeanCTX evaluation for Apache-2.0, governance-heavy, or read-proxy use cases, and run a future spike to measure hook coexistence with RTK+CM.

---

## Limitations and Caveats

### Known Gaps

This run did not install or benchmark either product end-to-end. Vendor token-reduction percentages [1][6] are uncorroborated by controlled measurement. `search-cli` was unavailable, limiting scholarly or broad web triangulation beyond fetched URLs. LeanCTX compatibility and Team pricing pages were registered but not all subpages were deeply indexed.

### Assumptions

Findings assume public docs reflect shipping behavior as of 2026-07-05. SB host defaults to Cursor; Codex/Claude parity may shift per-platform hook limitations noted in SB docs [8].

### Areas of Uncertainty

Co-installation behavior (LeanCTX + Context Mode + RTK simultaneously) is untested. Enterprise LeanCTX air-gapped claims were not validated. Context Mode Insight paid analytics were excluded from comparison [8].

---

## Recommendations

### Immediate Actions for Silver Bullet

1. **Keep Context Mode** as the default recommended context-management tool when users opt into tier 1c token compression [8][10].
2. **Document Lean Context** in SB research or adjacent-tools docs as a conditional alternative—not a catalog replacement—linked to this decision record.
3. **Add a routing table** to help users choose: ELv2 acceptable + MCP-heavy workflows → Context Mode; Apache-2.0 + read/wire governance → evaluate LeanCTX.

### Next Steps

Run an integration spike: install LeanCTX alongside SB's RTK+CM stack on a sample repo, measure hook conflicts, and capture `ctx_stats` vs Lean ledger exports.

### Further Research

Independent token benchmark on identical agent tasks; legal review of ELv2 vs Apache-2.0 for SB plugin redistribution; user interviews on PathJail vs instruction-only enforcement.

---

## Bibliography

[1] LeanCTX (2026). "LeanCTX — Control What Your AI Can See". https://leanctx.com/ (Retrieved: 2026-07-05)
[2] LeanCTX (2026). "The Cognitive Context Layer — Architecture". https://leanctx.com/architecture/ (Retrieved: 2026-07-05)
[3] LeanCTX (2026). "Pricing — LeanCTX". https://leanctx.com/pricing/ (Retrieved: 2026-07-05)
[4] LeanCTX (2026). "Getting Started — LeanCTX Docs". https://leanctx.com/docs/getting-started/ (Retrieved: 2026-07-05)
[5] yvgude (2026). "lean-ctx GitHub Repository". https://github.com/yvgude/lean-ctx (Retrieved: 2026-07-05)
[6] mksglu (2026). "Context Mode README". https://raw.githubusercontent.com/mksglu/context-mode/main/README.md (Retrieved: 2026-07-05)
[7] mksglu (2026). "context-mode GitHub Repository". https://github.com/mksglu/context-mode (Retrieved: 2026-07-05)
[8] Silver Bullet (2026). "Context Mode — SB Recommended Tool". https://github.com/alo-exp/silver-bullet/blob/main/docs/CONTEXT-MODE.md (Retrieved: 2026-07-05)
[9] Silver Bullet (2026). "SB Code Intelligence Contract". https://github.com/alo-exp/silver-bullet/blob/main/docs/code-intelligence-contract.md (Retrieved: 2026-07-05)
[10] Silver Bullet (2026). "silver-bullet.md §2g-ii Recommended Tools". https://github.com/alo-exp/silver-bullet/blob/main/silver-bullet.md (Retrieved: 2026-07-05)
[11] LeanCTX (2026). "Compatibility Matrix". https://leanctx.com/compatibility (Retrieved: 2026-07-05)
[12] LeanCTX (2026). "Savings Ledger Concepts". https://leanctx.com/docs/concepts/savings-ledger (Retrieved: 2026-07-05)

---

## Appendix: Methodology

### Research Process

Ultradeep AF-DECIDE nested V-loop: DR-SCOPE through DR-PACKAGE with critique-driven gap recording. Artifacts stored under `.planning/research/2026-07-05-context-mode-vs-lean-context-ultradeep/`.

### Sources Consulted

Twelve registered sources spanning vendor web, GitHub, and SB integration docs; twenty-eight evidence spans with direct quotes and paraphrases.

### Verification Approach

Automated `validate_report.py`, `verify_citations.py`, and `verify_claim_support.py` plus `test-silver-deep-research-integration.sh`.

### Quality Control

Triangulation matrix in `triangulation.md`; unsupported vendor metrics flagged as single-source; validation failures logged under `validation/` without suppression.

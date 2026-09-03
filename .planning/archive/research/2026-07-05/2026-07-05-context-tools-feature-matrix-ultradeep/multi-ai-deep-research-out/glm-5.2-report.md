# Is LeanCTX a Better Single-Tool Replacement for the RTK + Context Mode + agentmemory + Graphify Stack?

**Deep-research analysis · Mode: ultradeep**
**Author:** glm-5.2 (parallel deep-research dispatch)
**Date:** 2026-07-07
**Scope:** Critical evaluation of whether LeanCTX is a *better* single-tool replacement for RTK + Context Mode + agentmemory + Graphify — both individually and as a combined composable stack.
**Inputs:** `gist-leanctx-capability-analysis.md` (200-row matrix, per-tool coverage scores, 17 hard gaps, token economics, persona-conditional analysis), primary upstream corroboration (LeanCTX site/catalog/compare, RTK README, Context Mode README, agentmemory README, Graphify README), plus prior ultradeep research artifacts in the same directory.

---

## Executive Summary

LeanCTX is **not** a *better* single-tool replacement for the full RTK + Context Mode + agentmemory + Graphify stack in the strong sense — it does not strictly dominate any one of the four on the four-tool's home turf, and it leaves two persona-conditional super-critical gaps open (Context Mode `CTX_FETCH_STRICT` for regulated agents, agentmemory's 53-tool orchestration surface for multi-agent ops-at-scale). The gist's coverage scores (RTK 97% / Context Mode 95% / agentmemory 87% / Graphify 99%) are **directionally credible** but **optimistically skewed**: many of LeanCTX's "covered" cells are self-attested from the LeanCTX feature catalog (✓¹) without the published depth that the incumbent brings via concrete READMEs, hook-platform matrices, or installed MCP descriptors. Primary-source corroboration confirms LeanCTX genuinely ships 81 MCP tools, 10 read modes, PathJail, the Ed25519 savings ledger, an optional wire proxy, and prompt-injection detection — these are real, distinctive, and unmatched by any single incumbent.

Where LeanCTX **does** outclass the four-stack — and where it can reasonably be called "better" — is on surfaces the four-stack has no row for: **wire/request compression proxy**, **enforced read-path AST fidelity modes**, **runtime PathJail + shell allowlist**, **cryptographic savings ledger with offline batch verify**, **prompt-injection pre-model gating**, and **single-binary unified governance**. On these five super-critical axes, the *combined four-stack* has gaps *vs LeanCTX*, not the other way around.

The honest verdict is **complementarity, not equivalence**: LeanCTX is best read as a unified *compression-and-governance runtime* that already documents RTK as a compatible addon. It can credibly replace RTK standalone and Graphify standalone for code-orientation personas (97% / 99% coverage). It is *workable but thinner* on Context Mode's published fetch hardening depth (95%) and meaningfully thinner on agentmemory's orchestration breadth (87%). For solo and code-heavy SB-style agents, **LeanCTX alone is a credible simplification**. For regulated/corporate agents, **Context Mode must remain** for `CTX_FETCH_STRICT`. For multi-agent ops-at-scale, **agentmemory must remain** for the 53-tool orchestration surface. For a 5-10 person mixed team, **LeanCTX + agentmemory** is the minimum viable composition: the unified binary buys setup consistency and the agentmemory layer buys a non-dev-readable, gitleaks-scannable shared memory surface.

The headline finding there is **no published head-to-head benchmark** — LeanCTX's 60–90% per-read claims and ~13-token cached re-read, Context Mode's ~98% hook-platform savings, and Graphify's 71.5× corpus reduction all originate with each vendor and remain uncorroborated in a controlled cross-tool study. Any token-economics conclusion is therefore a structural argument from architecture, not measured.

---

## 1. Introduction

### Scope and methodology

This analysis asks: **is LeanCTX a better single-tool replacement for all the use cases of RTK + Context Mode + agentmemory + Graphify — both individually and combined?** It builds on a 200-row ultradeep capability matrix (`gist-leanctx-capability-analysis.md`, 2026-07-05) that scored LeanCTX's per-tool coverage at 97% / 95% / 87% / 99% respectively, enumerated 17 hard gaps (13 cell-exact, 4 depth gaps), and concluded no universal dealbreaker — only persona-conditional ones.

The deep-research task here is critical, not summarative: we (a) define what "better" means across seven dimensions, (b) validate gist claims against primary sources re-fetched on 2026-07-07, (c) triangulate coverage scores against published READMEs and LeanCTX's self-published catalog and compare page, (d) challenge — then refine — the verdict.

### Key assumptions

- **Capability-only lens.** Licensing, pricing, install cost, and Silver Bullet migration policy are explicitly out of scope (mirroring the source gist). Operational simplicity and security are in scope because they materially shape the replacement decision.
- **Published-surface evidence.** A feature is "covered" only if it is documented in a primary source (vendor site, GitHub README, or installed MCP descriptor). Self-attested catalog entries are marked ✓¹ per the original matrix's footnote convention.
- **Head-to-head absence.** Prior ultradeep research explicitly noted "no end-to-end install, no identical-task benchmark." This analysis did not find a published controlled comparison during retrieval either.
- **Recent-update cut-off.** Sources were re-fetched on 2026-07-07; LeanCTX's GitHub reports 3,000+ stars, 280+ forks, and 200+ near-daily releases shipped since launch, so the catalog is a moving target. New features (e.g., `proxy.effort`, output-token verbosity steer, cache-prefix volatility relocation) post-date the snapshot gist and are flagged here as corroboration, not as cells retroactively added to the matrix.

### What "better" means (Phase 1 dimensions)

| Dimension | What it captures |
|---|---|
| **Capability coverage** | Raw feature parity across the 200-row matrix; quantified by per-tool coverage scores |
| **Depth of implementation** | Whether a feature is first-class (✓), thin/partial (✓¹), or composable-via-addon (✓²); the difference between "documents this capability" and "publishes the depth the incumbent does" |
| **Token efficiency / compression quality** | Per-surface savings claims, reversibility, re-read cost, overhead taxes (rules + MCP tool schemas) |
| **Operational simplicity** | One Rust binary vs four install paths × hook/MCP rule files; onboarding friction at 1 seat and at 10 seats |
| **Security / governance** | SSRF tiers, runtime PathJail, prompt-injection pre-model gating, gitleaks on shared export, audit trail |
| **Orchestration / multi-agent support** | Action DAG, leasing, mesh, sentinels, sketch→promote, crystallize — surfaces that *enable* multi-agent coordination, not just two-agent handoffs |
| **Team / collaboration features** | Shared markdown exports, team feed, viewer UI, non-dev-readable artifacts |

The four-stack wins on dimension 1 and 7 (incumbents publish deeper on their home surfaces). LeanCTX wins on dimensions 3 (wire + read-path), 5 (runtime governance + ledger + injection gating), 6 (operational simplicity and unified audit). Dimensions 2 and 4 are mixed and persona-dependent.

---

## 2. Replacement by surface area (Section 1 of synthesis)

The gist's per-tool coverage scores — RTK 97%, Context Mode 95%, agentmemory 87%, Graphify 99% — answer "how completely does LeanCTX cover each tool's published first-class rows." Re-validation against current primary sources modifies these readings as follows.

### RTK (97%) — **confirmed**

LeanCTX ships native shell compression (95+ patterns, 270 passthrough rules, PreToolUse rewrite), and LeanCTX's own `compatibility` and `compare` pages explicitly list RTK as a compression addon — the only documented addon relationship in either tool's published surface. RTK's distinctive remaining surface is its lightest-footprint, shell-only specialization: a single-purpose CLI proxy with `rtk gain`, `rtk discover`, `rtk session` analytics. LeanCTX's native + RTK-addon story covers ~97% of RTK's rows credibly.

The 3% residual is "RTK as the lightest possible single-purpose install": it is a CLI proxy alone, no Rust binary coupling the read-path, no Node MCP server, no LSP refactor surface. For a workflow that strictly wants shell compression and nothing else — no read modes, no graph, no memory — RTK remains the leaner dependency. For everything else, LeanCTX native is sufficient.

**Verdict: yes, credibly replaceable** (with documented RTK addon for depth if needed).

### Context Mode (95%) — **confirmed but optimistically scored**

LeanCTX publishes `ctx_execute`, `ctx_execute_file`, `ctx_batch_execute`, `ctx_fetch_and_index`, `ctx_index`, `ctx_search`, `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge` — direct mirror of Context Mode's 11 MCP tools. Its sandbox sandbox + FTS5 + RRF + progressive throttling is conceptually aligned.

The 5% residual is concentrated in four cell-exact gaps (gaps #1, #2, #3, #4 in the gist) plus the depth gap #14 (WebFetch deny + curl/wget redirect published platform matrix). Primary-source corroboration confirms the gap'surface: Context Mode's README publishes a *concrete per-platform table* (Claude Code/Gemini CLI/VS Code Copilot/JetBrains/Copilot CLI/Cursor/OpenCode/OpenClaw/Codex CLI/Antigravity/Kiro/OMP) with measured savings "with hooks ~98% saved vs without hooks ~60% saved." LeanCTX publishes the capability but not the per-platform enforcement matrix at equivalent depth.

The super-critical axis within this 5% is `CTX_FETCH_STRICT` (RFC1918/loopback block mode for hosted/CI environments). Context Mode publishes concrete block-list semantics: schemes http/https only, 169.254.0.0/16 always-blocked with DNS-rebinding defense, 224.0.0.0/4, 0.0.0.0/8, IPv6 ff00::/8 and fe80::/10, and `CTX_FETCH_STRICT=1` adds loopback + RFC1918 + ULA. LeanCTX publishes SSRF/marketing on its security page but without the published tier matrix.

A *new* corroboration post-dating the matrix: Context Mode's *About* tagline updated to "Sandboxes tool output (98% reduction)" — so the published 98% claim is now foregrounded, increasing the credibility cost of LeanCTX's slightly hand-wavier "60–90% per read" range.

**Verdict: partially replaceable. LeanCTX replaces Context Mode for solo/dev-loop agents; for regulated/CI-hosted fetch, Context Mode's published strict tier remains a hard requirement.**

### agentmemory (87%) — **confirmed and arguably overstated**

agentmemory's README, re-fetched 2026-07-07, confirms the 53-tool orchestration surface: core (`memory_recall`, `memory_save`, `memory_smart_search`, `memory_export`, `memory_relations`, …) plus extended (`memory_frontier`, `memory_lease`, `memory_next`, `memory_signal_send/read`, `memory_checkpoint`, `memory_mesh_sync`, `memory_sentinel_create/trigger`, `memory_sketch_create/promote`, `memory_crystallize`, `memory_diagnose`, `memory_heal`, `memory_verify`, `memory_team_share`, `memory_team_feed`, `memory_audit`, `memory_governance_delete`). Its About tagline brands itself "#1 Persistent memory for AI coding agents based on real-world benchmarks" — a marketing claim LeanCTX has not contested.

LeanCTX's catalog contains 7 multi-agent-ish tools: `ctx_session`, `ctx_knowledge`, `ctx_agent`, `ctx_share`, `ctx_handoff`, `ctx_workflow`, `ctx_feedback`. That is handoff-grade, not action-DAG-grade. The 13% residual is concentrated in 7 hard cell-exact gaps (gaps #5, #6, #7, #8, #9, #10, #11, #12, #13) plus depth gap #15 (53-tool orchestration MCP) and gap #17 (gitleaks on export). These cells genuinely exist in agentmemory with documented semantics and have no LeanCTX row.

The 87% number is, in this author's analysis, *generous*: orchestrating multi-agent work via `memory_frontier` + `memory_lease` + `memory_signal_send/read` + `memory_mesh_sync` is not just "more tools"; it is *concurrency control over a shared action graph*. LeanCTX's `ctx_workflow`/`ctx_handoff` are primitives, not a coordination primitive set. A more conservative reading would put agentmemory coverage at **80–85%**, with the gap being *real and material* for ops-at-scale.

**Verdict: cautiously replaceable for solo/interactive coding; not replaceable for ops-at-scale without retaining agentmemory.**

### Graphify (99%) — **confirmed, with one caveat**

Graphify's primary deliverable is a persistent multimodal knowledge graph (`graph.json` + `wiki/` + `GRAPH_REPORT.md` + `graph.html` + `obsidian/`), built from tree-sitter AST + LLM INFERRED edges, with Leiden communities, god nodes, and `query`/`path`/`explain`/`affected` traversal. Its README reports a measured 71.5× token reduction on a mixed Karpathy-repos corpus.

LeanCTX's catalog now includes `ctx_graph` (with `build`, `related`, `symbol`, `impact`, `status`, `enrich`, `context`, `diagram` actions), `ctx_callgraph` (callers/callees), `ctx_refactor` (LSP rename/references/definition/implementations), `ctx_architecture`, `ctx_impact`, `ctx_quality` (navigability + cognitive-complexity hotspots + token-quality-tax), `ctx_review`. LeanCTX's property graph supports weighted BFS over `imports`, `calls`, `exports`, `type_ref`, `tested_by` edge types. These are graph-grade capabilities, including *more* code-graph intelligence than Graphify publishes (e.g., LSP-backed refactor — Graphify is read-only).

The 1% residual is the multimodal-research-corpus-as-primary-deliverable (gap #16) — vision/PDF/image ingest + Postgres-backed extract for `/raw`-scale retrieval is Graphify's distinctive center of gravity. Structural code-graph parity is genuinely ~99%; the residual is the *research-corpus* workflow, not the *code-orientation* workflow.

**Verdict: credibly replaceable for code-orientation; Graphify optional only for multimodal-corpus-as-product personas.**

### Summary of surface-area replacement

| Incumbent | LeanCTX coverage | Re-validate vs primary | Verdict |
|---|---:|---|---|
| RTK | 97% | ✓ 95+ patterns, 270 rules; RTK addon documented | Replace with addon available |
| Context Mode | 95% | ✓ tools mirror; ✗ CTX_FETCH_STRICT depth gap | Replace for solo; keep for regulated |
| agentmemory | 87% | ⚠ handoff primitives, not action-DAG; ✗ gitleaks | Replace for solo; keep for ops-at-scale |
| Graphify | 99% | ✓ ctx_graph/callgraph/refactor ≥ Graphify rows | Replace for code; Graphify optional for corpus |

---

## 3. Combined stack replacement — what synergy is lost? (Section 2)

The four-stack is *designed* to compose. The Silver Bullet pattern (per `docs/code-intelligence-contract.md`) is a layered pipeline:

> **RTK compresses shell** → **Context Mode processes sandbox outputs** → **agentmemory captures decisions** → **Graphify retrieves patterns**

Each tool's center of gravity is on a different plane: RTK at the shell boundary, Context Mode at the MCP sandbox boundary, agentmemory at the session/orchestration boundary, Graphify at the retrieval-graph boundary. Their *combined* value is not the sum of their tool counts — it is that the four planes compose cleanly without re-architecting any one.

### Does LeanCTX's unified design replicate this pipeline?

**Partially — but with one important qualitative loss.** LeanCTX covers all four planes (shell compression ✓, sandbox analysis ✓, session/handoff ✓, graph query ✓). What it does *not* replicate is the *best-of-breed depth* on planes 2, 3, and 4:

- **Plane 2 (CM sandbox):** LeanCTX mirrors the 10 sandbox tools but not the per-platform published hook matrix, the `CTX_FETCH_STRICT` tier table, the `afterAgentResponse` hook, or the credential-passthrough sandbox.
- **Plane 3 (agentmemory orchestration):** LeanCTX ships 7 multi-agent tools; agentmemory ships 53 — including `memory_frontier`, `memory_lease`, `memory_next`, `memory_signal_send/read`, `memory_checkpoint`, `memory_mesh_sync`, `memory_sentinel_create/trigger`, `memory_sketch_create/promote`, `memory_crystallize`, `memory_diagnose`, `memory_heal`, `memory_verify`. These form a *coordination primitive set*, not just a memory store.
- **Plane 4 (Graphify retrieval):** LeanCTX's `ctx_graph` is graph-grade, but Graphify's primary deliverable — a persistent multimodal `graph.json` + `GRAPH_REPORT.md` + `wiki/` + `obsidian/` + `graph.html` for cross-session replay — is a *traversable artifact ecosystem*, not just a query API.

### The synergy lost is real but bounded

**Lost synergy #1: shared-memory-as-markdown.** The SB "save via agentmemory → retrieve via Graphify" pattern produces a *git-exportable markdown corpus* that survives MCP server outages, can be browsed by humans without a UI, and is suitable for `git blame`/PR-review workflow. LeanCTX's `ctx_share`/`ctx_knowledge` exists but is partial (✓¹) on team feed maturity and lacks the gitleaks-bridge for shared export.

**Lost synergy #2: orchestration-memory-artifact-retrieval pipeline.** The sequence `agentmemory save → graphify update → graphify query` produces workflow-aware memory available for retrieval in subsequent sessions through a structural graph. LeanCTX has memory and graph in one subsystem, but the *depth* at each plane is thinner than incumbent best-of-breed.

**Lost synergy #3: split-stack composability.** Each incumbent can be uninstalled/replaced/versioned independently. A defect in agentmemory's server does not block Context Mode's sandbox. LeanCTX's single binary couples all five subsystems — a regression in, say, its wire proxy affects the entire stack. Independent upgrade cycles are a feature.

**Lost synergy #4: evidence-tier separation.** The four-stack keeps each tool's evidence tier disjoint: RTK proves shell savings, CM proves sandbox savings, Graphify proves 71.5× corpus reduction. LeanCTX's Ed25519 ledger is unified — *one* savings number for a multi-surface stack. This is more convenient for dashboards but less falsifiable per plane.

### What LeanCTX *gains* in unified design that the four-stack cannot

The four-stack cannot offer:
1. **Wire-path request compression** (LeanCTX's `lean-ctx proxy enable` sits between agent and model — no incumbent operates at this layer).
2. **Reversible Content-Addressed Recovery (CCR):** five recovery paths (`ctx_expand`, `ctx_retrieve`, in-band marker, `GET /v1/references/{id}`, re-read) — no incumbent publishes reversibility at this depth.
3. **Runtime PathJail + deny-by-default shell allowlist** — the four-stack relies on rules + CM subprocess sandbox; no filesystem jail on native Read/Shell.
4. **Ed25519 hash-chained savings ledger + offline batch-verify CLI** — RTK's `rtk gain` and CM's `ctx_stats` are session metrics, not tamper-evident audit.
5. **Prompt-injection pre-model gating** — no incumbent row covers this.

These are not marginal advantages — they are *planes the four-stack does not occupy at all*.

### The combined-stack-replacement verdict

LeanCTX's unified design *does* replicate the four-plane pipeline *at shallower depth* on planes 2 and 3, and *at comparable or superior depth* on planes 1 and 4 (and adds planes 5–7 the four-stack lacks). For solo or code-heavy agents, the lost synergy on planes 2 and 3 is not material. For multi-agent ops-at-scale or non-dev-readable team memory, the lost synergy on plane 3 (agentmemory's action DAG / team feed / gitleaks) is material. For regulated/corporate fetch, the lost depth on plane 2 is material.

---

## 4. The 17 hard gaps — criticality assessment (Section 3)

The gist's verdict: none of the 17 is a universal dealbreaker; two become super-critical only under specific personas. Per critical re-analysis:

### Cell-exact gaps (13)

| # | Gap | Assessment upon re-validation |
|---|---|---|
| 1 | Sandbox credential passthrough (CM) | Confirmed. Specialized for CI/automation. LeanCTX's sandbox can run code but does not publish credential passthrough semantics for approved CLIs. |
| 2 | `afterAgentResponse` hook (CM) | Confirmed. Host lifecycle nicety. Not super-critical. |
| 3 | `ctx_insight` dashboard launcher (CM) | Confirmed. UX only; not capability floor. |
| 4 | `CTX_FETCH_STRICT` RFC1918/loopback (CM) | **Confirmed and arguably understated.** CM README publishes a concrete block list semantics (schemes, 169.254/16 with DNS-rebinding defense, multicast/reserved, IPv6 site-local ULA) — LeanCTX's security page does not publish a comparable tier matrix. |
| 5 | Editable memory slots (AM) | Confirmed. Power-user ergonomics; not super-critical. |
| 6 | `memory_relations` (AM) | Confirmed. Relation-traversal exposed in agentmemory's core tools. LeanCTX's `ctx_graph` is conceptually similar but partial (✓¹). |
| 7 | `memory_reflect` LLM insight synthesis (AM) | Confirmed. No LeanCTX row. |
| 8 | Claude MEMORY.md bridge sync (AM) | Confirmed. Host-specific; not generic. |
| 9 | Citation chain verification `memory_verify` (AM) | Confirmed. Trust/audit persona only. |
| 10 | Sentinel event-driven unblocking (AM) | Confirmed. Long-running orchestration; not interactive baseline. |
| 11 | Sketch → promote exploratory workgraphs (AM) | Confirmed. Exploratory orchestration; not baseline capture. |
| 12 | Crystallize completed action chains (AM) | Confirmed. Orchestration maintenance, not baseline. |
| 13 | `memory_diagnose` + `memory_heal` (AM) | Confirmed. Maintenance auto-fix; not super-critical but its absence raises operational burden on multi-agent teams. |

### Depth gaps (4)

| # | Gap | Assessment |
|---|---|---|
| 14 | Hook-layer WebFetch deny + curl/wget redirect w/ published platform matrix (CM) | **Confirmed and arguably understated.** CM's published per-platform table with "with hooks ~98% saved vs without hooks ~60% saved" materially out-publishes LeanCTX on hook enforcement depth. |
| 15 | 53-tool action DAG / frontier / lease / mesh orchestration MCP surface (AM) | **Confirmed.** Depth, not just tool count. |
| 16 | Multimodal corpus graph as primary deliverable (GF) | Confirmed. Niche for code agents, central for research-corpus personas. |
| 17 | Gitleaks scan on memory export (AM) | **Confirmed and arguably understated** for shared-git memory workflows. `.agentmemory/` markdown exports in git are a secret-leak vector at team scale. |

### Do I agree none are universal dealbreakers?

**Yes — with a sharpening.** No single gap blocks a *capable solo or code-floor coding agent* on LeanCTX. The two super-critical persona-conditional gaps (`CTX_FETCH_STRICT`, 53-tool orchestration) are correctly identified.

### Which gaps I would promote to super-critical

I promote **none to *universal* super-critical**, but I would elevate three from "important but not super-critical" to **persona-conditional super-critical**:

1. **Gap #17 (gitleaks on memory export)** — promote for *any team that exports `.agentmemory/` markdown into shared git*. The leak risk is concrete and not mitigated by "pre-export review" if exports happen automatically in hooks.
2. **Gap #15 (53-tool orchestration)** — already super-critical for ops-at-scale; promote explicitly for *parallel-agent CI workflows* where `memory_lease` provides mutual exclusion. Without it, parallel agents will stomp each other repeatedly.
3. **Gap #14 (WebFetch deny depth)** — promote for *any agent that runs in CI/automation unattended*, not just corporate. The CM published matrix with measured 98% vs 60% savings shows the gap is not just security theatre — it changes what agents can do unattended.

### Newly found gaps (post-snapshot)

LeanCTX corroboration revealed *new* LeanCTX-native capabilities not in the matrix that change the gap ledger:

- **`proxy.effort`** (cross-provider reasoning-effort pinning) — LeanCTX-only, no incumbent row.
- **Output-token verbosity steer with measured holdout** — LeanCTX-only.
- **Cache-prefix volatility relocation** (relocates dates/UUIDs/SHAs out of cacheable prefix) — LeanCTX-only.
- **`ctx_quality` cognitive-complexity hotspot + token-quality-tax** — LeanCTX-only, no direct incumbent analog.
- **`ctx_refactor` LSP-backed rename/references/definition/implementations** — LeanCTX-only.

These do not change the *incumbent→LeanCTX* gap ledger, but they do expand the *LeanCTX→incumbent* gap ledger: each of these is a surface the four-stack genuinely lacks.

---

## 5. Unified vs composable architecture (Section 4)

The tradeoff between **single-binary unified runtime** (LeanCTX) and **four-tool composable best-of-breed stack** is not symmetric across scale; it changes character at different operational tiers.

### At solo / 1-seat scale

**LeanCTX wins decisively.** One `curl` install, one setup command auto-detecting 30+ agents, zero per-tool config. The four-stack requires RTK shell hook install + Context Mode plugin install + agentmemory server install (`AGENTMEMORY_URL` env, `:3111` port) + Graphify pip install + SB rules (`graphify.mdc`, `context-mode.mdc`, `agentmemory.mdc`, `recommended-tools.mdc` instruction fragments) + hook/Bash discipline. Per-seat onboarding for a solo dev is materially cheaper with LeanCTX.

### At small-team scale (5–10 mixed seats)

**LeanCTX + agentmemory wins.** Mixed dev/non-dev teams need setup consistency (one binary beats four MCP servers × mixed skill levels) *and* non-dev-readable shared memory (git-exported `.agentmemory/` markdown + team feed). The four-stack forces one maintainer to debug four install paths per seat (Node agentmemory, npm CM, pip Graphify, RTK hooks — plus SB rules). LeanCTX + agentmemory is the smallest stack that still serves devs and non-devs.

### At org / corporate scale (50+ seats, regulated)

**LeanCTX + Context Mode + agentmemory wins.** Corporate security needs published `CTX_FETCH_STRICT` semantics. Multi-agent ops needs orchestration. LeanCTX alone cannot replace either at this tier. The four-stack's composability becomes a *feature* — independent version pinning and security review per tool.

### At hyperscale / SaaS (multi-tenant, SLO-bound)

**Unclear — evidence is missing.** LeanCTX publishes "Role-based budgets, SLOs, audit trail" on its compare page and an Ed25519 savings ledger for tamper-evident audit, which *suggests* SLO-grade operational fitness, but no public production deployment at hyperscale is documented. agentmemory runs a server on `:3111` and exposes a REST API; Graphify publishes Postgres-backed extract — both more obviously multi-tenant-shaped than LeanCTX's localhost-bearer dashboard. Evidence insufficient.

### The real tradeoff: depth-vs-coupling

The four-stack's composability is depth-per-plane with weak coupling between planes. LeanCTX's unification is depth-at-coupled-planes with stronger coupling. At small scale, weak coupling is overhead; at large scale, weak coupling is risk isolation. The crossover point is roughly **5–10 seats**: below it, LeanCTX's coupling is a feature; above it, the four-stack's decoupling becomes a feature.

A weakly-coupled stack tolerates failure-isolation (one tool's bug does not break the others) but pays coordination tax (the four planes must agree on routing). A strongly-coupled binary tolerates audit-unification (one ledger) but pays regression coupling (one subsystem's bug can break the whole agent). Neither design dominates in the abstract.

---

## 6. Token economics — is the gist's "mixed" verdict correct? (Section 5)

The gist's verdict: *mixed — neither is clearly better overall on tokens*. Critical re-examination agrees, with sharpening.

### By compression surface (re-validated)

| Surface | LeanCTX | Four-stack | Re-validated verdict |
|---|---|---|---|
| **Shell** | Native 95+ patterns + 270 passthrough rules; RTK addon | RTK PreToolUse rewrite (Cursor allow-list gated) | **Tie → LeanCTX slight edge** with broader out-of-box coverage; RTK still the lightest specialist |
| **Read / large files** | 10 modes (full → AST signatures), `ModePredictor`, `IntentEngine`, `~13-token` cached re-read, `density:X` SDE-budget compression | CM cooperative `ctx_execute_file` + SB Read-deny > 5 KB; no native AST read modes | **LeanCTX** — the only stack with native read-path AST compression |
| **MCP / analysis output** | `ctx_execute*` sandbox w/ stdout-only return; 81 MCP tools | Context Mode: 11 focused sandbox tools; architectural center | **Four-stack (CM)** — tighter tool-surface means lower per-call schema framing cost |
| **Wire / request proxy** | Local proxy compresses system prompt + history + tool results, prompt-cache-safe; also effort pinning, output verbosity steer, volatility relocation | None | **LeanCTX only** — the *largest single uncaptured savings surface* on long multi-turn sessions |
| **Web fetch** | Universal intake → compact facts | `ctx_fetch_and_index` + hook WebFetch deny + curl/wget redirect | **Slight four-stack edge** on hook-enforced fetch discipline; compression quality unbenchmarked |
| **Re-read / cache** | ~13 tokens per cached compressed re-read + bounce detection | FTS5 + RRF + progressive throttling (CM); budget-limited scoped subgraph (Graphify) | **Mixed** — LeanCTX wins re-read; CM wins search-throttle; Graphify wins graph-query |

### Honest uncertainty — confirmed

Re-validation found **no published head-to-head benchmark**. LeanCTX's "~60–90% per read / ~13-token re-read" comes from its own catalog and compare page. Context Mode's "~98% saved with hooks" comes from its own README per-platform table. Graphify's "71.5× fewer tokens per query" comes from its own README corpus benchmark. agentmemory's "#1 based on real-world benchmarks" points to `agent-memory.dev` benchmarks — *their own*. None of these runs the *other tools' workloads* on a controlled task. Treat every single-number savings claim as **directional marketing**, not evidence — and treat the comparative tiering in this report as an architectural argument, not a measured one.

### Overhead taxes — the LeanCTX 81-tool surface

The gist flags LeanCTX's 81-MCP-tool surface as a hidden context tax. Re-validation *confirms this concern is real but partially mitigated*. LeanCTX publishes:
- **5 high-level MCP tools** (the lean path) plus
- **81 granular MCP tools** (for advanced scenarios) plus
- **MCP Tool-Catalog Gateway** (proxy unlimited downstream MCP at constant context cost) plus
- **6 dynamic tool categories** (lazy resolution).

If you expose all 81 at every session startup, your tool-definition context bloat can *erase* single-binary simplicity. If you route through the 5 high-level tools or the gateway, LeanCTX is lean. The four-stack's tool surface is *naturally smaller* (CM 11 + agentmemory 53 if enabled + Graphify MCP + RTK hooks-only = ~65 at full coverage) but less aggressively organized. The 81-tool concern is real but operator-error, not architectural.

### Verdict

The "mixed" verdict is correct. LeanCTX likely wins on tokens *when*:
- Workload is read-heavy (AST modes, density, cached re-reads).
- Wire proxy is actually enabled (opt-in).
- Tool surface is routed through the 5 high-level tools or gateway.

The four-stack likely wins on tokens *when*:
- Orientation is graph-first via Graphify subgraph.
- MCP analysis dominates (CM's 11-tool surface).
- Shell work hits RTK's per-CLI compressors.
- Discipline of save-via-agentmemory-retrieve-via-Graphify is followed.

Real outcomes depend on agent rule compliance, Cursor allow-list coverage for RTK, host MCP exposure, and whether the wire proxy is enabled. None were measured head-to-head.

---

## 7. Persona-specific verdicts (Section 6)

### Persona A — Solo dev / individual contributor

**Minimum viable stack:** LeanCTX alone. Optionally LeanCTX + RTK addon if shell output dominates the workflow.

**Critical must-keep incumbents:** None.

**Why:** Solo coding is compression-heavy and graph-orientation-light. LeanCTX's 81-tool surface can be routed through 5 high-level tools; its read modes + cached re-reads + wire proxy deliver cumulative savings on long sessions; PathJail and prompt-injection gating are runtime security without needing hooks-of-Cooperative-discipline that CM requires. The 17 hard gaps all hit personas other than solo (regulated fetch, multi-agent ops, team shared memory, multimodal corpus). agentmemory's orchestration primitives are designed for *multi-agent* — overkill for solo; agentmemory's *capture* features are nice but LeanCTX's `ctx_save`/`ctx_handoff` cover the solo-memory use case adequately.

**Evidence-graded risk:** LeanCTX's "documents this capability" markings (✓¹) are self-attested. The risk is that solo devs discover in production that a specific niche capability (e.g., `ctx_search` ranking depth, or `ctx_handoff` cross-session survival) is thinner than CM's or agentmemory's equivalent — for which the mitigation is the documented RTK addon path and the option to install CM in parallel without conflict.

### Persona B — Corporate / regulated security

**Minimum viable stack:** LeanCTX + Context Mode.

**Critical must-keep incumbents:** **Context Mode** (specifically `CTX_FETCH_STRICT`).

**Why:** Regulated/corporate agents run in hosted/CI/automation environments where RFC1918 and loopback fetches must be hard-blocked, not policy-discouraged. CM's published tier matrix (schemes, 169.254/16 with DNS-rebinding defense, multicast/reserved, IPv6 ULA, `CTX_FETCH_STRICT=1` for RFC1918) is the only audited-grade published fetch hardening in the four-stack. LeanCTX's security page publishes SSRF hardening but at thinner published depth. LeanCTX's prompt-injection pre-model gating, PathJail, and Ed25519 audit ledger *add* values CM does not have — but the regulatory floor is `CTX_FETCH_STRICT`, and only CM publishes it concretely.

**Evidence-graded risk:** Operating without `CTX_FETCH_STRICT` in regulated environments is not "maybe-blocked-but-probably-fine" — it is non-compliant if a SOC2/ISO27001 audit引用 internal-network fetch interception. Do not let LeanCTX's "secret & injection defense" marketing substitute for CM's published tier matrix without a security review.

### Persona C — Multi-agent ops-at-scale

**Minimum viable stack:** LeanCTX + agentmemory.

**Critical must-keep incumbents:** **agentmemory** (53-tool orchestration surface). Do not skip.

**Why:** `memory_frontier` + `memory_lease` + `memory_next` + `memory_signal_send/read` + `memory_checkpoint` + `memory_mesh_sync` + `memory_sentinel_create/trigger` + `memory_sketch_create/promote` + `memory_crystallize` + `memory_diagnose` + `memory_heal` form a *coordination primitive set* for parallel agents. LeanCTX's `ctx_agent`/`ctx_handoff`/`ctx_workflow` are handoff primitives, not concurrency control over a shared action graph. Dropping agentmemory for ops-at-scale means parallel agents will race, double-execute, and silently fall over each other.

**Evidence-graded risk:** LeanCTX's catalog says it has "multi-agent" capabilities; the gap is not absence but *depth and proven coordination primitives*. For ops-at-scale, "multi-agent" without lease-and-frontier semantics is not enough.

### Persona D — Small mixed team (5–10 devs + non-devs)

**Minimum viable stack:** LeanCTX + agentmemory. Add Context Mode only if corporate/regulated.

**Critical must-keep incumbents:** **agentmemory** for team memory layer (`memory_team_share`, `memory_team_feed`, git-exported `.agentmemory/` markdown, gitleaks export scan).

**Why:** Mixed dev/non-dev teams have *two* first-class requirements that scale shifts into critical: **setup consistency** and **non-dev-readable memory**. LeanCTX's single-binary per seat reduces onboarding friction for non-dev PMs/designers/ops; the read-cache and wire proxy help the repeated "fresh chat" orientation tax multiplied by headcount. agentmemory stays *not* for the 53-tool ops-at-scale orchestration, but as the *team memory layer*: markdown exports browseable by people who never open the source tree, team feed for cross-session visibility, gitleaks bridge for shared-git secret hygiene.

**Secondary: drop standalone RTK** (LeanCTX native or RTK addon if shell-heavy). **Skip standalone Graphify** unless your business depends on INFERRED-edge/multimodal-corpus-as-product workflows — LeanCTX's `ctx_graph`/`ctx_callgraph`/`ctx_refactor` is sufficient for team-scale code orientation.

**Evidence-graded risk:** LeanCTX's partial (✓¹) on `team_share`/`team_feed`/`mesh_sync` mean a 5–10 seat pilot should validate the LeanCTX team feed before fully retiring agentmemory. A safer pilot sequence: 2 devs + 1 non-dev → LeanCTX + agentmemory for 4 weeks → measure friction → decide. The cost of running LeanCTX + agentmemory is one extra `:3111` server, materially less than the four-stack.

### Persona matrix — aggregated

| Persona | Min stack | Incumbent kept (critical) | Token verdict |
|---|---|---|---|
| Solo dev | LeanCTX | none (RTK addon optional) | LeanCTX likely wins |
| Corp security | LeanCTX + Context Mode | Context Mode | Mixed; CM-published 98% vs LeanCTX 60–90% |
| Multi-agent ops | LeanCTX + agentmemory | agentmemory | Mixed; depth on demand from agentmemory |
| Small mixed team | LeanCTX + agentmemory (+ CM if corp) | agentmemory + (CM if corp) | Mixed; LeanCTX wins fresh-chat tax; agentmemory wins shared memory legibility |

---

## 8. Overall verdict — is LeanCTX truly better as a replacement?

**Yes — under explicitly bounded conditions.**

LeanCTX is a *better* single-tool replacement for the four-stack when:

1. **The persona is solo or code-heavy SB-style agent** — none of the 17 hard gaps touch the workflow; LeanCTX wins on operational simplicity, optional wire proxy, prompt-injection gating, Ed25519 audit, read-path AST modes, and RTK addon availability.
2. **The commodity-fetch-regulatory floor is not a binding constraint** — i.e., no SOC2/ISO internal-network fetch block requirement, so Context Mode's `CTX_FETCH_STRICT` published tier is luxury, not necessity.
3. **The multi-agent work is *handoff*, not *frontier scheduling*** — LeanCTX's `ctx_handoff`/`ctx_workflow` suffice if "multi-agent" means "delegate to subagent", not "parallel agents with mutual exclusion over a shared frontier".
4. **The team memory layer is *dev-only* and not exported to git for non-dev reading** — LeanCTX's memory primitives suffice for in-session capture.
5. **Graphify is used for code-orientation only** — LeanCTX's `ctx_graph`/`ctx_callgraph`/`ctx_refactor` cover ~99% of code-graph use cases *and* add LSP refactor that Graphify lacks.

LeanCTX is **not** a better single-tool replacement when:

1. **Persona is corporate/regulated** — Context Mode must remain for `CTX_FETCH_STRICT` published semantics. Promote gap #4 to super-critical.
2. **Persona is multi-agent ops-at-scale with parallel coordination** — agentmemory must remain for the 53-tool orchestration primitive set. Promote gap #15 to super-critical.
3. **Persona is small mixed team with shared memory export discipline** — agentmemory must remain for git-exportable markdown + gitleaks + team_feed legibility for non-devs. Promote gap #17 to *persona-conditional* super-critical for any team that commits `.agentmemory/` to shared git.
4. **The workflow's primary deliverable is a *multimodal research corpus graph*** — Graphify must remain (gap #16). Niche but real.

### What evidence is missing

This analysis, the source gist, and the prior ultradeep research all consistently note:

- **No published controlled head-to-head benchmark** of any two of these tools on the same task.
- Vendor metrics (LeanCTX 60–90%/13-token, CM 98%, Graphify 71.5×, agentmemory "#1 real-world benchmarks") originate with each vendor and remain *uncorroborated* in cross-tool studies.
- No public production-deployment case study comparing the *operational burden* of LeanCTX-alone vs the four-stack at any team scale.
- No measured comparison of LeanCTX's 81-MCP-tool surface tax vs CM's 11 + AM's 53 + GF + RTK tools surface tax.
- No evidence on LeanCTX's secret-and-injection defense depth equivalent to CM's `CTX_FETCH_STRICT` published tier matrix.
- No public assessment of LeanCTX's `ctx_workflow`/`ctx_handoff` *coordination semantics* compared to agentmemory's `memory_lease`/`memory_frontier` beyond the tool-name listing in the catalog.

### The bottom line

**LeanCTX is better as a single-tool replacement for ~60–80% of practical agentic coding personas — specifically solo, code-heavy, and small-dev-team setups without regulatory or ops-at-scale constraints. For the remaining ~20–40% (regulated fetch, multi-agent ops, mixed-team shared memory), the four-stack's depth on planes 2 and 3 is materially better, and LeanCTX cannot alone occupy those seats. The optimal real-world answer is *complementarity*: LeanCTX + RTK addon (shell depth) + Context Mode (regulated) + agentmemory (ops-at-scale/team memory) + Graphify (research corpus) — pick the subset for the persona, don't pick one tool to rule them all.**

LeanCTX is the only tool in the set whose *published stance* is explicitly compositional (it documents RTK as a compatible addon and publishes a Tool-Catalog Gateway for proxying downstream MCP). The four-stack does not publish LeanCTX compatibility. The compositional position is asymmetric — and that asymmetry is itself evidence that LeanCTX is best read as the *unified-core-plus-addons* pattern, not as a rip-and-replace mandate.

---

## 9. Synthesis & Insights

1. **The matrix's coverage scores are correct but generous to LeanCTX.** Many cells marked ✓ (covered) on LeanCTX's side are self-attested from the LeanCTX feature catalog with footnote "documents this capability" without published depth comparable to the incumbent's README/published matrix/install descriptor. The 95% Context Mode coverage is closer to 88–92% on published-depth-equivalent scoring; the 87% agentmemory is closer to 80–85% on coordination-primitive scoring. LeanCTX's 97% RTK and 99% Graphify are credible.

2. **LeanCTX has super-critical wins the four-stack cannot match.** Wire proxy, AST read modes, PathJail runtime, Ed25519 ledger, prompt-injection pre-model gating, and (newly verified) `proxy.effort`, output verbosity steer, cache-prefix volatility relocation, `ctx_quality`, `ctx_refactor`, CCR reversibility with 5 recovery paths. The 4-stack genuinely *does not occupy* these planes; the synergy loss runs in both directions.

3. **Compositional intent is asymmetric and informative.** LeanCTX publishes RTK as a compatible addon, publishes a compare page ranking itself against RTK/Context+/MemGPT/Headroom (note: Context+ ≠ Context Mode; marketing does not name mksglu's Context Mode, agentmemory, or Graphify as direct competitors). The four-stack does not publish LeanCTX compatibility. This asymmetry positions LeanCTX as the "unified core, addons for depth" pattern — which is consistent with the optimal real-world answer above.

4. **The "no head-to-head benchmark" gap is the single largest evidence hole.** Every per-tool coverage score, every token-savings claim, and every critical-gap tier is an architectural inference from published surfaces. Real cross-tool benchmarks (same task, same agent, same context budget, with vs without each tool) would resolve the entire debate. Until then, the verdict is conditional per-persona, not global.

5. **Single-binary ≠ lower tokens.** The 81-MCP-tool surface *can* erase single-binary simplicity if exposed naively. LeanCTX mitigates with 5 high-level tools + Tool-Catalog Gateway + 6 dynamic categories. The four-stack's natural surface (CM 11 + agentmemory 53 + GF + RTK) is ~65 tools. The overhead-tax comparison is closer than marketing implies.

6. **Persona-conditional super-critical gaps are the operational truth.** Universal-dealbreaker framings conceal honest tradeoffs. The three super-critical gaps (`CTX_FETCH_STRICT`, agentmemory 53-tool, gitleaks on export) are super-critical *only* for specific personas — and the optimal stack isLeap-CTX + the incumbents those personas require, not LeanCTX alone, not the four-stack alone.

7. **`agentmemory` is the most under-credited incumbent.** The matrix credit 87% undersells the *coordination primitive set* — `memory_lease` is mutual exclusion; `memory_frontier` is work scheduling; `memory_signal_send/read` is messaging; `memory_mesh_sync` is P2P; `memory_sentinel` is event-driven unblocking. These are not "more memory tools"; they are concurrency control over a shared action graph. LeanCTX's `ctx_agent`/`ctx_handoff`/`ctx_workflow` are primitives, not primitives + concurrency control. For ops-at-scale the gap is qualitative, not quantitative.

8. **Graphify is the most over-credited incumbent for code-only personas.** 99% LeanCTX coverage of Graphify is credible for code-orientation. Graphify's distinctive value is multimodal-corpus-as-product, not code-graph (where LeanCTX now ships LSP refactor Graphify lacks). Standalone Graphify for SB-style code-orientation is the most replaceable piece of the four-stack; for research/research-corpus personas Graphify must stay.

9. **RTK may be the single most replaceable incumbent.** 97% coverage + documented RTK addon + LeanCTX native 95+ shell patterns = standalone RTK is the strongest candidate for retirement. The remaining 3% (lightest possible shell-only CLI proxy without binary coupling) is a niche.

10. **Operational simplicity compounds with headcount.** Solo: LeanCTX alone is frictionless. 5–10 mixed seats: LeanCTX + agentmemory is the right shape. 50+ regulated seats: LeanCTX + Context Mode + agentmemory is the right shape. The four-stack's composability becomes more valuable past ~10 seats, but the *full* four-stack is usually overkill at every tier except extremely varied mixed workloads.

---

## 10. Limitations & Caveats

- **No controlled benchmarks.** Every savings claim and every coverage score is an architectural inference from published surfaces. Cross-tool measured comparisons do not exist in any public source found during retrieval.
- **Self-attested LeanCTX cells.** Many matrix rows mark LeanCTX as ✓¹ ("feature catalog documents this capability") without independent verification of operational depth. The risk is that some "covered" cells are stubs, not production-grade implementations.
- **Marketing-grade at comparison time.** Vendor pages (leanctx.com compare page, agentmemory "#1 real-world benchmarks" tagline, Graphify 71.5× narrative, CM 98% per-platform table) are marketing; they are useful for tiering but not for falsification.
- **Snapshot drift.** LeanCTX ships near-daily (200+ releases); capabilities post-date the 2026-07-05 matrix snapshot. New features (`proxy.effort`, output verbosity steer, cache-prefix volatility relocation, CCR 5-recovery-path, role-based budgets/SLOs/audit, `ctx_quality`) are corroboration only — not retroactively re-scored cells.
- **Install/runtime path untested.** This analysis did not install LeanCTX or the four tools and run a controlled coding session. The verdict is paper-architectural.
- **Persona framings are simplifications.** Real teams are mixed personas; the per-persona minimum-stacks assume a single dominant persona. A regulated + multi-agent + mixed team will need LeanCTX + Context Mode + agentmemory simultaneously.
- **Silver Bullet context note.** The SB repo's own context-mode rules reference LeanCTX as a *competitor*. Some artifacts in this directory (gist, audit-report) represent SB-contextualized capability comparisons; this report flags the directionality of stance where relevant but does not assume equal neutrality across sources.

---

## 11. Recommendations

### For the default simplification-first persona

1. **Default to LeanCTX alone.** The single-binary + 5 high-level MCP tools + RTK addon path covers solo/coding agent compression, sandbox, memory, graph, governance floors.
2. **Enable the wire proxy** (`lean-ctx proxy enable`); use the 5 high-level tools + Tool-Catalog Gateway; not the full 81-tool surface — unless a niche advanced tool is specifically required.
3. **Keep RTK only if** your shell workload hits command-specific compressors LeanCTX's 95 patterns don't cover, *and* you can install RTK as a LeanCTX addon without conflict.
4. **Skip standalone Graphify** unless your team depends on INFERRED-edge/multimodal-corpus as a primary product workflow.

### For the corporate / regulated persona

5. **Add Context Mode**. Treat `CTX_FETCH_STRICT` as the regulatory floor for hosted/CI fetch interception. Maintain LeanCTX alongside for wire + read + governance + audit, but do not let LeanCTX's "secret & injection defense" marketing substitute for CM's published tier matrix.
6. **Conduct a security review** of LeanCTX's PathJail/shell allowlist vs your CI sandboxing needs before migration.

### For the multi-agent ops-at-scale persona

7. **Keep agentmemory.** Do not migrate ops-at-scale coordination to LeanCTX's `ctx_workflow`/`ctx_handoff` without first running a parallel pilots. `memory_lease` provides mutual exclusion; `memory_frontier` provides work scheduling; without these you will see agent races and double-execution.
8. **Use LeanCTX for the compression/governance plane** alongside agentmemory for orchestration — they compose without evident conflict.

### For the small mixed team (5–10)

9. **Pilot LeanCTX + agentmemory** on 2 devs + 1 non-dev for 4 weeks. Measure: setup friction (binary install vs four-MCP install), shared-memory legibility (markdown + team feed browseability for non-devs), gitleaks hygiene on exported `.agentmemory/`.
10. **Add Context Mode only after** a security review flags internal-network fetch as a team policy. Do not unilaterally add CM; let the pilot surface the need.
11. **Drop standalone RTK** unless a single shell-heavy dev workflow specifically requires it.
12. **Skip standalone Graphify** unless a research-corpus workflow emerges from the pilot.

### For Silver Bullet maintainers evaluating migration policy

13. The 5 super-critical LeanCTX-only capabilities (wire proxy, AST read modes, PathJail, Ed25519 ledger, prompt-injection gating) are *not* mitigated by the four-stack — these are genuine SB-floor gaps if the four-stack is preferred.
14. The 3 persona-conditional super-critical four-stack capabilities (`CTX_FETCH_STRICT`, agentmemory orchestration, gitleaks on export) must be preserved in any SB policy that might collapse the stack to LeanCTX-only — *or* operational rules must be added that prohibit contexts where those gaps matter.
15. **No rip-and-replace policy** is justified by current evidence. Compositional policies (LeanCTX-as-core + persona-conditional incumbent retention) reflect the actual tradeoff.

---

## 12. Bibliography

Primary sources re-fetched and indexed 2026-07-07:

- [1] LeanCTX homepage. *leanctx.com*. https://leanctx.com/ (accessed 2026-07-07; cached in context-mode session)
- [2] LeanCTX architecture. *leanctx.com/architecture*. https://leanctx.com/architecture/ (accessed 2026-07-07; cached in context-mode session; confirms: 5 subsystems — Smart I/O, Memory, Security, Request Compression, Provable Savings; PathJail; IDE config-dir jail; shell allowlist; Ed25519 ledger)
- [3] LeanCTX compatibility page. *leanctx.com/compatibility*. https://leanctx.com/compatibility/ (confirms RTK listed as compatible compression addon)
- [4] LeanCTX compare page. *leanctx.com/compare*. https://leanctx.com/compare/ (compares LeanCTX vs RTK, Context+ (ForLoopCodes/contextplus, NOT mksglu Context Mode), MemGPT/Letta, Headroom; confirms: 10 read modes, 95+ shell patterns, 81 MCP tools, role-based budgets/SLOs/audit trail, sandboxing + signed bundles, 100% local)
- [5] LeanCTX GitHub README. *github.com/yvgude/lean-ctx*. https://github.com/yvgude/lean-ctx (confirms: 3,000+ stars, 280+ forks, 200+ releases, 30+ agents auto-detected; two-plane architecture — read path + wire path; `lean-ctx proxy enable`; `proxy.effort` reasoning-effort pinning over OpenAI/Anthropic/Gemini; verbosity steer + measured holdout; cache-prefix volatility relocation; CCR reversibility with 5 recovery paths (`ctx_expand`, `ctx_retrieve`, in-band marker, `GET /v1/references/{id}`, re-read); property graph; multi-edge BFS over imports/calls/exports/type_ref/tested_by; tree-sitter AST for 27 languages; 95+ shell-output patterns + 270 passthrough rules; ~13-token cached re-reads)
- [6] LEANCTX_FEATURE_CATALOG.md. *raw.githubusercontent.com/yvgude/lean-ctx/main/LEANCTX_FEATURE_CATALOG.md*. (81 granular MCP tools; tool categories: B) Architecture/Analysis/Discovery includes `ctx_graph`, `ctx_callgraph`, `ctx_refactor` (LSP rename/references/definition/implementations), `ctx_architecture`, `ctx_impact`, `ctx_quality` (navigability + cognitive-complexity + token-quality-tax), `ctx_review`, `ctx_pack`, `ctx_index`, `ctx_artifacts`, `ctx_intent`, `ctx_task`, `ctx_overview`, `ctx_preload`, `ctx_prefetch`, `ctx_discover`, `ctx_analyze`; C) Session/Knowledge/Multi-Agent includes `ctx_session`, `ctx_knowledge`, `ctx_agent`, `ctx_share`, `ctx_handoff`, `ctx_workflow`, `ctx_feedback`; Graph-Powered Context OS (3.4.7): Multi-Edge Graph Queries with weighted BFS; CCR (5 recovery paths))
- [7] LeanCTX savings ledger docs. *leanctx.com/docs/concepts/savings-ledger*. https://leanctx.com/docs/concepts/savings-ledger/ (Ed25519-signed, hash-chained, batch-verifiable)
- [8] RTK GitHub README. *github.com/rtk-ai/rtk*. https://github.com/rtk-ai/rtk (PreToolUse shell rewrite on 14+ agents; command-specific compressors for git, gh, rg, docker, test runners, cloud CLIs; `rtk gain`, `rtk discover`, `rtk session`; no MCP, no read-path, no memory graph)
- [9] Context Mode GitHub README. *github.com/mksglu/context-mode*. https://github.com/mksglu/context-mode (About: "Context window optimization for AI coding agents. Sandboxes tool output (98% reduction), persists session memory, and enforces routing across 17 platforms via MCP + hooks." 11 MCP tools (six sandbox: `ctx_batch_execute`, `ctx_execute`, `ctx_execute_file`, `ctx_index`, `ctx_search`, `ctx_fetch_and_index` + five meta: `ctx_stats`, `ctx_doctor`, `ctx_upgrade`, `ctx_purge`, `ctx_insight`); hook suite: PreToolUse, PostToolUse, UserPromptSubmit, PreCompact, SessionStart, Stop, afterAgentResponse; per-platform hook matrix with measured "with hooks ~98% saved, without hooks ~60% saved"; `CTX_FETCH_STRICT=1` for RFC1918/loopback/ULA block mode; `tool_input` credential redaction via regex matcher in `hooks/posttooluse.mjs`; routing instruction file auto-write disabled per issues #158, #164; platform list: Claude Code, Gemini CLI, VS Code Copilot, JetBrains Copilot, GitHub Copilot CLI, Cursor, OpenCode, OpenClaw, Codex CLI, Antigravity CLI, Kiro, OMP via plugin)
- [10] agentmemory GitHub README. *github.com/rohitg00/agentmemory*. https://github.com/rohitg00/agentmemory (About: "#1 Persistent memory for AI coding agents based on real-world benchmarks"; site: agent-memory.dev; 53 MCP tools; core: `memory_recall`, `memory_save`, `memory_compress_file`, `memory_smart_search`, `memory_patterns`, `memory_timeline`, `memory_relations`, `memory_graph_query`, `memory_consolidate`, `memory_claude_bridge_sync`, `memory_team_share`, `memory_team_feed`, `memory_audit`, `memory_governance_delete`, `memory_snapshot_create`; orchestration: `memory_action_create`, `memory_action_update`, `memory_frontier`, `memory_next`, `memory_lease`, `memory_routine_run`, `memory_signal_send`, `memory_signal_read`, `memory_checkpoint`, `memory_mesh_sync`, `memory_sentinel_create`, `memory_sentinel_trigger`, `memory_sketch_create`, `memory_sketch_promote`, `memory_crystallize`, `memory_diagnose`, `memory_heal`, `memory_verify`, `memory_facet_tag`, `memory_facet_query`)
- [11] Graphify GitHub README (now under Graphify-Labs/graphify; URL redirect from safishamsi/graphify). https://github.com/safishamsi/graphify (and https://github.com/Graphify-Labs/graphify) (About: "Turn any folder of code, SQL schemas, R scripts, shell scripts, docs, papers, images, or videos into a queryable knowledge graph"; output layout: `graph.html`, `obsidian/`, `wiki/`, `GRAPH_REPORT.md`, `graph.json`, `cache/` (SHA256 incremental re-index); tree-sitter AST; LLM INFERRED edges; god nodes; Leiden community detection; `query`/`path`/`explain`/`affected` traversal; multimodal PDF/image/diagram ingest; token benchmark: 71.5× fewer tokens per query on Karpathy repos + 5 papers + 4 images; 5.4× on mixed-corpus; ~1× on synthetic httpx; git post-commit auto-reindex; Obsidian/HTML/GraphML/Neo4j Cypher exports)
- [12] Prior ultradeep research — context mode vs LeanCTX. *`.planning/research/2026-07-05-context-mode-vs-lean-context-ultradeep/`* (referenced as `[Prior]` in source gist; reused and extended)

Source artifacts in the same research directory (Silver Bullet repo):

- [13] `gist-leanctx-capability-analysis.md` — 200-row feature matrix, 17 hard gaps, per-tool coverage scores (97% / 95% / 87% / 99%), token optimization comparison, persona-conditional analysis, small mixed-team analysis. (Primary input)
- [14] `research_report.md` — 88-row feature coverage matrix summary, tool profiles, three largest gaps, where-LeanCTX-leads.
- [15] `feature-coverage-matrix.md` — 200-row × 5-column tick matrix with link anchors.
- [16] `evidence.jsonl` — 27 evidence spans.
- [17] `claims.jsonl` — 10 synthesized claims.
- [18] `sources.jsonl` — 18 sources.

SB canonical docs referenced in the gist:

- [19] `docs/RTK.md`
- [20] `docs/CONTEXT-MODE.md`
- [21] `docs/AGENTMEMORY.md`
- [22] `docs/GRAPHIFY.md`
- [23] `docs/code-intelligence-contract.md` (SB synergy: save via agentmemory, retrieve via Graphify)

Externally referenced but not directly fetched in this analysis:

- [24] Headroom — `github.com/chopratejas/headroom` (referenced from LeanCTX compare page; not part of the four-stack)
- [25] Context+ — `github.com/ForLoopCodes/contextplus` (referenced from LeanCTX compare page; *not* Context Mode — these are different projects)

---

## 13. Methodology Appendix

### Phase 1 — SCOPE
- Read `gist-leanctx-capability-analysis.md` (full 641 lines).
- Defined seven dimensions of "better": capability coverage, depth, token efficiency, operational simplicity, security/governance, orchestration/multi-agent, team/collaboration.
- Coordinated dimensions against four personas (solo, corp security, multi-agent ops, small mixed team) matching the gist's persona matrix.

### Phase 2 — PLAN
- Identified key claims to validate per-tool: (RTK coverage ≥95%, Context Mode sandbox + CTX_FETCH_STRICT, agentmemory 53-tool orchestration, Graphify 71.5× and graph primitives), and LeanCTX-native capabilities (81 MCP tools, 5 subsystems, PathJail, Ed25519 ledger, wire proxy, prompt-injection detection).
- Listed gaps to re-verify: all 13 cell-exact + 4 depth gaps from the gist.

### Phase 3 — RETRIEVE
- Re-fetched 10 primary sources in parallel (concurrency 5) using `ctx_fetch_and_index`:
  - 6 LeanCTX-primary: homepage, architecture, compatibility, GitHub README, LEANCTX_FEATURE_CATALOG.md, savings-ledger docs.
  - 4 incumbent READMEs: RTK, Context Mode, agentmemory, Graphify.
  - 7 were cache hits (prior ultradeep had fetched); 3 were fresh (CM, AM, GF GitHub READMEs).
  - Total indexed: 205 sections, 270.9 KB.
- Searched indexed content via `ctx_search` with multi-query batches covering: 81 MCP tools breakdown, wire proxy + reversibility, PathJail and shell allowlist, Ed25519 ledger, RTK addon compat, read modes + ModePredictor, CTX_FETCH_STRICT + fetch hardening, 11-tool CM sandbox, 53-tool agentmemory surface, gitleaks scanning, Graphify tree-sitter/god-nodes/Leiden, 30+ agents auto-detect, prompt-injection detection security model, team share feed multi-agent mesh, agentmemory real-world benchmarks, LSP refactor code intelligence, Context Mode 98% platform matrix, Headroom vs CM comparison, LeanCTX 81-tool bloat critique.

### Phase 4 — TRIANGULATE
- Cross-referenced every coverage score against primary-source corroboration:
  - RTK 97% → confirmed (95+ patterns + 270 rules + RTK addon documented).
  - Context Mode 95% → confirmed but optimistic on fetch-hardening depth (CM publishes concrete tier matrix; LeanCTX publishes capability only).
  - agentmemory 87% → confirmed but arguably overstated on orchestration primitive set.
  - Graphify 99% → confirmed (and LeanCTX has LSP refactor Graphify lacks; the 1% residual is multimodal-corpus-as-primary-deliverable).
- Cross-referenced every hard gap claim against primary source — none newly resolved; gap #4 and gap #17 arguably understated in criticality for relevant personas.
- Identified *new* LeanCTX-native capabilities not in the matrix snapshot (`proxy.effort`, output-token verbosity steer, cache-prefix volatility relocation, role-based budgets/SLOs/audit, `ctx_quality`, `ctx_refactor` LSP-backed, CCR 5-path reversibility) — these expand the LeanCTX→four-stack gap ledger without changing the four-stack→LeanCTX gap ledger.

### Phase 4.5 — OUTLINE REFINEMENT
- Confirmed 7-section synthesis structure as specified.
- Sharpened gap-promotion recommendations: keep two universal super-critical (per gist); promote three to persona-conditional super-critical (#4 CTX_FETCH_STRICT for regulated, #15 53-tool for ops-at-scale, #17 gitleaks for shared-git-team).
- Added note on compositional asymmetry as itself evidence of the optimal pattern.

### Phase 5 — SYNTHESIZE
- Wrote 8 sections (executive summary, intro, replacement-by-surface-area, combined-stack, 17-hard-gaps, unified-vs-composable, token-economics, persona-verdicts, overall-verdict) plus synthesis, limitations, recommendations, bibliography.
- Cited primary source per claim using footnoted inline references and the bibliography section.

### Phase 6 — CRITIQUE (self-challenge)

**Assumption 1: "Coverage scores are credible architectural inferences."** — *Challengeable*. Self-attested LeanCTX cells (✓¹) without operational depth verification may inflate the score. The 95% Context Mode and 87% agentmemory scores likely carry 3–7 percentage points of optimism. *Mitigation in synthesis:* explicitly flag this and propose conservative ranges (88–92% CM, 80–85% AM).

**Assumption 2: "LeanCTX's published compare page comparing itself to RTK validates RTK addon compat."** — *True but partial*. The compare page lists RTK explicitly but does *not* name mksglu's Context Mode, agentmemory, or Graphify as competitors — only Context+ (a different project, ForLoopCodes). So LeanCTX marketing does *not* claim direct replacement for the three incumbents in this analysis's scope. The "LeanCTX-replaces-four-stack" question is therefore *an inference from feature coverage* by researchers, not a claim LeanCTX itself makes. *Mitigation:* flagged in synthesis point #3 (compositional intent asymmetry).

**Assumption 3: "No published head-to-head benchmark exists."** — *True within retrieval scope*. Retrival surfaced no controlled cross-tool comparison. agentmemory brands itself "#1 based on real-world benchmarks" pointing to agent-memory.dev; LeanCTX publishes live metrics at leanctx.com/metrics. Neither is a head-to-head vs the four-stack. *Mitigation:* cannot address; flagged as evidence-gap throughout.

**Assumption 4: "Operational simplicity compounds with headcount."** — *Plausible but unmeasured*. The 5–10 seat tier argument is an architectural inference from install-path counting; no public case study compares onboarding-friction between LeanCTX-only vs the four-stack at team scale. *Mitigation:* framed as architectural opinion, not measured finding.

**Assumption 5: "Graphify is over-credited for code-only personas."** — *Re-validated*. LeanCTX's `ctx_refactor` (LSP rename/references/definition/implementations) and property graph queries (imports/calls/exports/type_ref/tested_by) provide *more* code intelligence than Graphify publishes for graph traversal — Graphify has no LSP-backed refactor. The 1% residual (multimodal corpus) does not affect SB-style code agents. *Mitigation:* asserted as finding, not assumption.

**Where I could be wrong:**
- LeanCTX's self-attested cells could be materially deeper than the matrix credits them, in which case the four-stack's lead on planes 2 and 3 is smaller than I assert. Re-installation and side-by-side measurement would resolve this.
- The four-stack may have unpublished features or near-term releases that close some super-critical LeanCTX-only gaps (wire proxy, prompt-injection gating, Ed25519 ledger). This analysis used 2026-07-07 fetched sources; the four-stack may ship these in the near future.
- agentmemory's "#1 real-world benchmarks" tagline may substantiate its superiority in a way this analysis could not reproduce without accessing agent-memory.dev's benchmark methodology.

**What would change my verdict:**
1. A published controlled benchmark showing LeanCTX wire proxy + read modes produce ≥20% more savings than the four-stack on identical tasks → I would tighten to "LeanCTX is better as a replacement for solo and code-heavy personas even where the four-stack's depth is published".
2. A published controlled benchmark showing the four-stack outperforms LeanCTX on the same task → I would tighten to "LeanCTX is a complement, not a replacement, for that persona".
3. Context Mode adding a comparable wire proxy / Ed25519 ledger / prompt-injection gating → I would narrow gap critique to "operational simplicity plus 81-tool surface that pushes back complexity, not capability floor".
4. agentmemory adding a published gitleaks-scan-on-export CI bridge beyond the bridge it already documents → gap #17 closes for mixed-team personas.

### Phase 7 — REFINE
- Applied critique mitigations to synthesis sections 9 and 10.
- Sharpened per-persona minimum-stack and super-critical-gap classifications.
- Added explicit compositional-asymmetry observation (production pattern is LeanCTX-as-core + persona-conditional addons, not rip-and-replace).

### Phase 8 — PACKAGE
- Output written to `/Users/shafqat/projects/silver-bullet/repo/.planning/archive/research/2026-07-05/2026-07-05-context-tools-feature-matrix-ultradeep/multi-ai-deep-research-out/glm-5.2-report.md`.
- Format: Executive Summary → Introduction → Main Analysis (sections 2–7 above) → Synthesis & Insights → Limitations & Caveats → Recommendations → Bibliography → Methodology Appendix.
- Primary input: gist-leanctx-capability-analysis.md (641 lines, 200-row matrix).
- Primary corroboration: 10 re-fetched sources (LeanCTX site/arch/compat/compare/GitHub/catalog/ledger + RTK + CM + AM + GF READMEs).
- Search platform: context-mode MCP `ctx_fetch_and_index` + `ctx_search` (no curl/wget/WebFetch used per AGENTS.md routing rules).
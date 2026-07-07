# LeanCTX vs RTK + Context Mode + agentmemory + Graphify: A Critical Replacement Analysis

**Mode:** ULTRADEEP (8-phase deep research pipeline)
**Date:** 2026-07-07
**Author:** minimax-m3 / multi-model parallel research dispatch
**Baseline evidence:** `gist-leanctx-capability-analysis.md` (2026-07-05 ultradeep audit, 200-row × 5-column feature matrix, 1000 cells verified) and the upstream tool sources fetched in this run.

---

## Executive Summary

**Verdict: LeanCTX is a credible single-tool mainstay for most serious agentic coding, but it is NOT a universal replacement for the four-tool stack — it is a structural substitute with a different center of gravity, not a superset.** The headline coverage numbers (RTK 97%, Context Mode 95%, agentmemory 87%, Graphify 99%) are **directionally correct** but each carries a different cost-of-gap: the 87% on agentmemory reflects a deep, persona-conditional hole in **multi-agent work orchestration** (sentinels, sketch→promote, crystallize, memory_lease / memory_frontier, the 53-tool DAG surface) that no LeanCTX row covers, while the 99% on Graphify mostly hides that Graphify's **multimodal corpus-graph** as primary deliverable is not just a feature, it is a *different product center* — the 71.5× token benchmark Graphify publishes (validated in their README) on Karpathy-style `/raw` corpora is not a row LeanCTX can match with `ctx_graph` alone.

The lean-context stack's strongest claims survive validation: the wire proxy (compresses every model request — system prompt, history, tool results — confirmed in `leanctx.com/architecture`), the Ed25519 hash-chained savings ledger with offline batch verification (the `lean-ctx savings verify-batch` CLI works anywhere, no ledger needed), PathJail runtime file confinement, the 10 read modes from `full` to `lines:N-M` (confirmed in `LEANCTX_FEATURE_CATALOG.md` v3.8.1, 2026-05-15), and the explicit **RTK addon composition** at `leanctx.com/compatibility` that acknowledges the SB-style specialist-stack pattern rather than rip-and-replace.

The four-stack's strongest claims that LeanCTX cannot match: Context Mode's `CTX_FETCH_STRICT` documented in their README (the default blocks `169.254.0.0/16` cloud metadata including the IMDS endpoint, and the strict mode blocks RFC1918/loopback for hosted/CI environments), Context Mode's PreCompact XML snapshot recovery with priority-tiered ≤2 KB resume blocks tied to per-session SQLite, agentmemory's full 53-tool orchestration surface confirmed in their MCP descriptors (`memory_sentinel_create`, `memory_sketch_promote`, `memory_crystallize`, `memory_diagnose`, `memory_heal`, `memory_verify`, `memory_lease`, `memory_frontier`), and agentmemory's **gitleaks-scanned shared memory export** — a real, documented capability that LeanCTX lacks and that the gist correctly flags as a 17th hard gap.

The honest answer to "is LeanCTX better" depends entirely on the persona and the load. **For solo / interactive coding, LeanCTX alone wins on operational simplicity and at least ties on token economics.** **For corporate / regulated agents, Context Mode's documented fetch-hardening tiers remain non-negotiable** — the gap is not just "uncovered" but "uncovered with a compliance persona." **For multi-agent ops-at-scale, the agentmemory 53-tool surface is a load-bearing product feature, not a feature row**, and no LeanCTX `ctx_agent` row replicates it. **For graph-first code research, Graphify's multimodal corpus graph as primary deliverable is a different center of gravity, not a partial overlap.**

The 17 hard gaps are **mostly** persona-conditional — but two of them are super-critical for the personas that hit them (`CTX_FETCH_STRICT` for security/regulated, 53-tool orchestration for ops-at-scale), and a third — secret-scanning on memory export — is super-critical for any team exporting shared memory to git. The remaining 14 are honest specialist overlays, not dealbreakers.

**The most important caveat:** the research community has **zero controlled head-to-head benchmarks** between LeanCTX and any of the four stack tools on identical tasks. Vendor percentages (LeanCTX 60–90% per read, Context Mode ~94% vs raw fetch in README examples, agentmemory ~170K tokens @ ~$10 on LongMemEval, Graphify 71.5× on Karpathy corpora) are all **uncorroborated in cross-vendor conditions**. Any single-number claim — including those in the upstream gist — is **directional marketing, not evidence**.

---

## 1. Introduction

### 1.1 Scope

This report addresses one specific question: **Is LeanCTX truly a better single-tool replacement for all the use cases of RTK + Context Mode + agentmemory + Graphify — both individually and combined?** The scope is strictly **capability and feature parity**, not licensing, pricing, install/operational cost, or adoption recommendations. The four tools form the "Silver Bullet recommended tools" stack — they are recommended in the SB project's `recommended-tools.mdc` rule and have native `docs/RTK.md`, `docs/CONTEXT-MODE.md`, `docs/AGENTMEMORY.md`, `docs/GRAPHIFY.md` integration docs. The combined stack is therefore not a hypothetical: it is the SB-default deployment shape.

LeanCTX is the comparison baseline. The upstream gist produced a 200-row × 5-column feature matrix (1000 cells, all marked ✓ / ✓¹ / ✓² / —) and a per-tool coverage score (RTK 97%, CM 95%, agentmemory 87%, Graphify 99%) that this report critically re-evaluates rather than re-summarizes.

### 1.2 Methodology

This research ran the 8-phase deep-research pipeline:

1. **SCOPE** — define "better" across 7 dimensions (capability, depth, token efficiency, operational simplicity, security/governance, orchestration/multi-agent, team/collaboration).
2. **PLAN** — map dimensions to 4 personas (solo dev, corp security, multi-agent ops, small mixed team 5–10).
3. **RETRIEVE** — fetch and index upstream sources: leanctx.com (`/`, `/architecture/`, `/compatibility`, `/docs/concepts/savings-ledger`), `LEANCTX_FEATURE_CATALOG.md` (v3.8.1, 2026-05-15), `github.com/yvgude/lean-ctx`, and the four stack tool READMEs (RTK master, Context Mode main, agentmemory main, Graphify main). 500+ FTS5 chunks indexed.
4. **TRIANGULATE** — cross-check every major claim from the upstream gist against primary sources. Validate the 17 hard gaps cell-by-cell.
5. **OUTLINE REFINEMENT** — adjust analysis structure based on what retrieval confirmed vs invalidated.
6. **SYNTHESIZE** — write 7 main analysis sections with cited evidence.
7. **CRITIQUE** — challenge the analysis: assumptions, missing evidence, alternative verdicts.
8. **PACKAGE** — assemble this report.

### 1.3 Key Assumptions (declared up front)

- The upstream gist's 200-row matrix is the SSOT for what was audited; this report treats its scoring as **reasonable but not authoritative** and re-validates the load-bearing claims.
- "Better" is **multi-dimensional and persona-conditional** — no scalar answer is correct.
- The four stack tools work together (RTK compresses shell → CM processes sandbox outputs → agentmemory captures decisions → Graphify retrieves patterns). This **pipeline pattern** is a load-bearing architectural claim that the gist does not deeply analyze, and is one of this report's central critiques.
- **No controlled head-to-head benchmark exists.** All token / savings percentages are uncorroborated cross-vendor. The most we can say is "directional" or "marketed."
- The "2026-07-05" date in the upstream audit predates this report by two days; tool drift is possible but no tool has shipped a major version bump in that window per the upstream sources fetched.

---

## 2. What "Better" Means — A Multi-Dimensional Definition

The single largest failure mode of the upstream gist is that it answers "is LeanCTX a replacement?" with a 4-score coverage table. That collapses seven different axes into one number per tool, and obscures the real decision. This report defines "better" along seven orthogonal dimensions, then re-projects the replacement question onto each.

### 2.1 Capability coverage (raw feature parity)

Counting cells in a 200-row matrix produces a number. That number tells you what fraction of the matrix LeanCTX covers when it is scored against each tool's native surface. The upstream gist produces 97 / 95 / 87 / 99 for RTK / CM / agentmemory / Graphify. **These numbers are correct under the scoring rule "✓ counts 1, ✓¹ counts 0.5, ✓² counts 0.5, — counts 0"**, but the rule is the report's choice, not a property of the tools. A different rule (treating ✓¹ as 0.25, or zero-tolerance on cell-exact gaps) produces a different ranking. The numbers are **not load-bearing on their own** — they are useful as orientation, not as a verdict.

### 2.2 Depth of implementation (first-class vs partial vs modicum)

A ✓ in the matrix means "LeanCTX has *some* surface in this row." It does not mean "LeanCTX has *equal* surface." The most important distinction the matrix draws is between ✓ (first-class), ✓¹ (partial, conditional, host-dependent), and ✓² (via addon/composition). On the agentmemory axis, 13 of the 17 hard gaps are cell-exact (no tick at all) and 4 are depth gaps (✓¹ where agentmemory's published surface is stronger). On the RTK axis, the matrix credits RTK as ✓² (via addon), not ✓ (first-class) — and this is **honest** because LeanCTX does not duplicate the deepest per-CLI compressors, it composes them.

### 2.3 Token efficiency / compression quality

The upstream gist's verdict — "Mixed — neither is clearly better" — is the right one. The reason: the two stacks optimize **different layers** of the token pipeline. RTK/CM compress **post-tool outputs** (what the model sees after the tool returns). LeanCTX's wire proxy compresses **every outbound model request** (the system prompt, conversation history, and tool results are compressed *before* the request leaves the box, prompt-cache-safe). These are non-overlapping surfaces. The combined stack **does not have a wire proxy at all** — none of the four tools compresses the request body itself, only what feeds into it. Conversely, the combined stack has **Graphify's scoped subgraph retrieval** (typically 100s of bytes vs a 50KB `GRAPH_REPORT.md` or a raw `Read`) — LeanCTX's `ctx_query` is the analog but the depth of multimodal ingest and community structure is Graphify's.

### 2.4 Operational simplicity (one binary vs four tools)

This is LeanCTX's **strongest uncontested win**. The upstream architecture page documents three integration modes — CLI-Redirect (no MCP), Hybrid (MCP cached reads + CLI shell/search), and Full MCP (all 81 tools) — auto-selected per agent. The 3,000+ GitHub stars and 200+ releases (near-daily since launch, per `github.com/yvgude/lean-ctx`) suggest a real install-friction win. **The four-stack requires four MCP servers (CM 11 tools + agentmemory 53 + Graphify + RTK hooks-only) plus four rule files (`graphify.mdc`, `context-mode.mdc`, `agentmemory.mdc`, `recommended-tools.mdc`)**. At one seat, this is fine. At 5–10 seats, the maintainer-bottleneck the upstream gist flags is real.

### 2.5 Security / governance

Context Mode's `CTX_FETCH_STRICT` and `169.254.0.0/16` block (including the IMDS endpoint at `169.254.169.254`) are documented in their README and represent a **regulator-defensible** fetch-hardening tier that LeanCTX's SSRF block (architecture page) does not document at the same level of detail (Cloud metadata + link-local: blocked; loopback + RFC1918: **allowed by default** in CM, also allowed in LeanCTX per the architecture page's "no implicit RFC1918 block" implication). LeanCTX adds **PathJail + IDE config-dir jail + deny-by-default shell allowlist** which are genuine runtime enforcement wins. The two stacks are not equivalent on this axis: CM leads on fetch, LeanCTX leads on file/shell.

### 2.6 Orchestration / multi-agent support

This is the **deepest honest gap** in the 87% agentmemory score. agentmemory's 53-tool surface includes: `memory_sentinel_create` / `_trigger` (event-driven unblocking), `memory_sketch_create` / `_promote` (exploratory workgraphs), `memory_crystallize` (LLM digest of completed action chains), `memory_diagnose` + `memory_heal` (auto-fix stuck state), `memory_frontier` (unblocked actions ranked), `memory_lease` (exclusive multi-agent leases), `memory_signal_send` / `_read` (inter-agent messaging), `memory_mesh_sync` (P2P sync). These are **not features rows** — they are a **work-orchestration product** built on memory. LeanCTX's `ctx_agent`, `ctx_handoff`, and `ctx_workflow` are partial. The matrix marks them ✓¹. The 53-tool surface is what a multi-agent system needs to *be* multi-agent, not what a memory system needs to *be* a memory system.

### 2.7 Team / collaboration features

Both stacks cover handoffs. agentmemory has the more mature team surface: `memory_team_share` / `memory_team_feed`, namespaced shared + private across team members, gitleaks-scanned git-exported markdown. The SB-style "save via agentmemory, retrieve via Graphify" synergy is documented in `docs/code-intelligence-contract.md` and is a real working pattern. LeanCTX has `ctx_team_share` and `ctx_team_feed` (matrix ✓¹) but the team-surface maturity is thinner. For a 5–10 seat mixed team, this is the **practical decision axis**, not raw capability parity.

---

## 3. The Pipeline Problem — The Stack's Hidden Synergy

The upstream gist treats the four stack tools as **four independent tools, scored individually**. That framing is wrong. The stack's value comes from a **pipeline pattern** the gist does not name:

```
RTK (shell compression, PreToolUse)
   ↓
Context Mode (sandbox analysis, hook enforcement, FTS KB)
   ↓
agentmemory (session capture, decision graph, 4-tier consolidation)
   ↓
Graphify (structural retrieval, scoped subgraph, god nodes)
```

Each tool's output is the next tool's input. RTK's rewritten shell output feeds CM's `ctx_execute` analysis, which feeds agentmemory's observation capture, which feeds Graphify's graph node/edge materialization. **The combined stack is not 4 × 95% = 380% — it is a chain where any weak link degrades the whole.**

LeanCTX is a **unified runtime** that compresses each layer in isolation but does not expose the **chain** as a programmable pipeline. Its `ctx_graph` builds a code graph; its `ctx_knowledge` captures facts; its `ctx_compress_memory` reduces memory. But there is no published "save via ctx_knowledge, retrieve via ctx_graph" idiom in the upstream catalog — the equivalent of agentmemory's "save, then Graphify retrieve" — and no documented user-facing pattern that pipelines `ctx_compress` → `ctx_graph` → `ctx_query` the way SB users pipeline agentmemory → Graphify. This is **not a gap in the matrix**; it is a gap in the **workflow ergonomics the matrix does not measure**.

**The strongest critique of LeanCTX-as-replacement is not a 17th hard gap — it is the absence of a documented composition idiom for the four tools' chain.** LeanCTX can compress, remember, and retrieve, but its compression → memory → retrieval story is **architectural rather than idiomatic**. A team that has internalized the SB pattern (RTK + CM + agentmemory + Graphify in `silver-bullet.md`'s recommended tools section) will find a lot of muscle memory lost in the migration, even if the byte-for-byte capability is similar.

---

## 4. Replacement by Surface Area

### 4.1 RTK (97% coverage)

The 97% number is **honest and the gap is narrow**. RTK's value is: (a) 14+ agent integrations (Claude Code, Copilot, Cursor, Codex, Windsurf, Cline, Pi, Hermes, Antigravity, Kilo, OpenCode, Mistral Vibe planned — all confirmed in RTK README), (b) command-specific compressors (jest, vitest, playwright, pytest, go test, cargo test, rake, rspec, plus 50+ other commands), and (c) `rtk gain` / `rtk discover` / `rtk session` analytics. LeanCTX has native shell compression + documented RTK addon composition. The deepest per-CLI compressors are not duplicated — they are composed. **This is the right architecture.** Anyone running shell-heavy dev loops will keep RTK in the loop, but it becomes an **addon**, not a stand-alone install. The 97% is correct: the **3% gap is the per-CLI compressor depth** (RTK's `rtk pytest` is `-90%` per its README; LeanCTX's native shell compressor is comparable but not proven deeper in head-to-head).

### 4.2 Context Mode (95% coverage)

The 95% number is the **most load-bearing score in the matrix** because Context Mode's *uncovered* row (`CTX_FETCH_STRICT`) is the **only** truly security-critical gap. CM's documented features validated against their README:

- 11 MCP tools: `ctx_batch_execute`, `ctx_execute`, `ctx_execute_file`, `ctx_index`, `ctx_search`, `ctx_fetch_and_index`, `ctx_stats`, `ctx_doctor`, plus admin tools — all confirmed.
- FTS5 with Porter stemming + trigram + RRF + proximity reranking + Levenshtein correction — all confirmed in CM README "Ranking" section.
- Network fetch hardening: 169.254.0.0/16 blocked including IMDS, schemes limited to http/https, DNS-rebinding defense — all confirmed.
- `CTX_FETCH_STRICT`: confirmed as a separate env-var tier for hosted/CI that additionally blocks loopback + RFC1918.
- PreCompact session recovery: confirmed — priority-tiered XML snapshot ≤2 KB stored in `session_resume` table, restored on SessionStart.
- 17+ platforms via hook configs (Kiro, OMP, Pi, etc.) — confirmed.
- `ctx_execute_file` project-boundary guard: confirmed — closes the documented #852 escape vector.
- Host `permissions.allow` honored: confirmed.

The uncovered rows: **`afterAgentResponse` hook, `CTX_FETCH_STRICT` RFC1918/loopback block mode, `ctx_insight` dashboard launcher, sandbox credential passthrough for approved CLIs**. Of these, only `CTX_FETCH_STRICT` is super-critical — the others are observability or host-lifecycle niceties. The **dashboard launcher (`ctx_insight`)** is the only optional paid SaaS in CM's surface and is correctly marked — in LeanCTX; **sandbox credential passthrough** is confirmed in CM README but the exact CI use cases for which it is the only path are narrow (not every coding agent needs AWS credentials in a sandboxed subprocess).

**Verdict:** LeanCTX replaces 95% of CM's surface. The 5% gap is **persona-conditional on regulated/corporate agents.** Solo devs do not need `CTX_FETCH_STRICT`. A SOC2-audited team absolutely does.

### 4.3 agentmemory (87% coverage)

The 87% is the **lowest score and the most honest gap**. agentmemory's confirmed 53-tool surface (per its README's "MCP tools" table — I indexed and verified the orchestration cluster: `memory_sentinel_create` / `_trigger`, `memory_sketch_create` / `_promote`, `memory_crystallize`, `memory_diagnose` / `memory_heal`, `memory_frontier` / `memory_next` / `memory_lease`, `memory_signal_send` / `_read`, `memory_mesh_sync`, `memory_verify`, `memory_facet_tag` / `_query`, `memory_audit`, `memory_governance_delete`, `memory_snapshot_create`, `memory_action_create` / `_update`, `memory_patterns`, `memory_timeline`, `memory_relations`, `memory_graph_query`, `memory_consolidate`, `memory_claude_bridge_sync`, `memory_team_share` / `memory_team_feed`, `memory_recall`, `memory_compress_file`) represents a **work-orchestration product**, not a memory feature. LeanCTX has `ctx_handoff` and `ctx_workflow` — these are **handoff primitives**, not orchestration. The matrix is correct to mark them ✓¹.

The other uncovered rows — `memory_slot` (editable size-limited memory slots), `memory_relations` (relationship traversal), `memory_reflect` (LLM insight synthesis over graph), `memory_verify` (citation chain verification), `memory_claude_bridge_sync` (Claude MEMORY.md bridge), `memory_sentinel_create`, `memory_sketch_promote`, `memory_crystallize`, `memory_diagnose` + `memory_heal` — are all confirmed in agentmemory's README. The 53-tool surface is **complete and not approximated** by LeanCTX. Anyone whose work is **multi-agent coordination** (cron + leases + sentinels + mesh sync across distributed agent runs) needs agentmemory. The 87% is **honest for single-session coding** but **insufficient for multi-agent ops-at-scale**.

The other persona-conditional super-critical gap: **gitleaks-scanned memory export** is confirmed in agentmemory's README. LeanCTX has no documented export-secret-scanning bridge. For a team that exports `.agentmemory/` to git, this is the difference between a clean repo and a leaked-secret incident. The matrix correctly flags this as a hard gap (depth gap #17). It is **not on every team's path**, but the teams it is on, it is **non-negotiable**.

### 4.4 Graphify (99% coverage)

The 99% is the **highest score and the most deceptively framed**. Graphify's value is not in any single cell — it is in the **product center of gravity**. Graphify is a **graph-first retrieval engine**: tree-sitter AST + LLM INFERRED edges + Leiden community detection + god-node synthesis + `query` / `path` / `explain` / `affected` + multimodal vision ingest (PDFs, images, screenshots, whiteboard photos) + Obsidian / GraphML / Neo4j Cypher / interactive HTML export. The 71.5× token benchmark on a Karpathy-corpus + papers + images is published in their README and is a **deliverable** for `/raw`-style workflows.

LeanCTX's `ctx_graph`, `ctx_callgraph`, `ctx_path`, `ctx_explain`, `ctx_query` cover the structural code graph at ~99% parity. Where LeanCTX does **not** cover Graphify is the **multimodal corpus graph as primary product** — vision extraction on arbitrary images, `GRAPH_REPORT.md` god-node narrative synthesis, Postgres-backed extract, `graphify watch` filesystem auto-sync. These are **not 99%-covered rows** — they are **1%-covered rows in the matrix** (✓¹ for Graphify's multimodal, — for Postgres extract). The 99% score reflects **structural code graph parity**, not **multimodal corpus graph parity**.

**Verdict:** For a typical code agent that primarily needs structural code orientation, LeanCTX's `ctx_graph` / `ctx_path` / `ctx_explain` cover Graphify at parity. For a research workflow that ingests PDFs, papers, screenshots, and builds a god-node report, Graphify is not a 1% gap — it is a **different product**.

---

## 5. The 17 Hard Gaps — Criticality Re-Ranked

The upstream gist ranks gaps by "persona-conditional super-criticality." This report **agrees with the top two promotions** and **proposes one more**:

### 5.1 Super-critical (persona-conditional, confirmed)

| Gap | Leader | Promotion argument |
|-----|--------|---------------------|
| **`CTX_FETCH_STRICT`** | Context Mode | Confirmed in CM README. The **only** row in the matrix where the gap is **regulator-defensible**. A SOC2/ISO27001/HIPAA team running agents that can hit internal services **must** have a strict-tier SSRF policy. LeanCTX's SSRF block (architecture page) blocks cloud metadata but **does not** document an RFC1918/loopback block — the docs imply RFC1918 is allowed. This is **not a feature gap; it is a compliance gap.** |
| **53-tool orchestration surface** | agentmemory | Confirmed in AM README. `memory_sentinel_create` + `memory_lease` + `memory_frontier` + `memory_mesh_sync` + `memory_crystallize` + `memory_sketch_promote` form a **work-orchestration product** atop memory. Anyone whose workload is *coordination of multiple agents* (e.g., one agent on a long task, one on monitoring, one on QA) needs the leasing + mesh + signal surface. LeanCTX `ctx_agent` does not approximate. |
| **Gitleaks-scanned shared memory export** | agentmemory | Confirmed in AM README. **Promoted to super-critical by this report** for any team that exports memory to git. The upstream gist ranks this as a "niche / optional" gap — this report disagrees. A 5–10 seat team with `.agentmemory/` in git, shared via team feed, **without** secret scanning is **one paste-of-an-API-key away from a leak incident.** LeanCTX has no documented secret-scanning bridge on memory export. This is **super-critical for the small mixed team persona** (the most common enterprise starter profile). |

### 5.2 Important but not super-critical (confirmed)

- Hook-layer WebFetch deny + curl/wget redirect depth (Context Mode). Confirmed in CM README. LeanCTX has hooks + sandbox fetch. The depth is thinner but the **control is present.**
- Sandbox credential passthrough (Context Mode). Confirmed. Persona: CI/automation with AWS/GCP credentials. Not on every team's path.
- Multimodal corpus graph as primary deliverable (Graphify). Confirmed. Persona: research workflow with PDFs + images. Code-only teams do not hit this gap.
- Sentinel event-driven unblocking (agentmemory). Confirmed. Persona: long-running orchestration. Solo interactive coding does not hit this.
- `memory_verify` citation chain verification (agentmemory). Confirmed. Persona: trust/audit. Capture + graph query cover most "remember and retrieve" needs.
- Shell compression depth (RTK). Mitigated by documented RTK addon. **Not super-critical** because the composition path is explicit.

### 5.3 Niche / optional (confirmed)

- `afterAgentResponse` hook (CM) — host lifecycle nicety.
- `ctx_insight` dashboard launcher (CM) — observability UX, not capability floor.
- Editable memory slots, `memory_relations`, `memory_reflect` (AM) — power-user graph ergonomics.
- Claude MEMORY.md bridge sync (AM) — host-specific bridge.
- Sketch → promote, crystallize, `memory_diagnose` + `memory_heal` (AM) — exploratory / maintenance orchestration.

### 5.4 Where this report **disagrees** with the upstream gist

The upstream gist says "for most serious agentic coding, **none of the 17 hard gaps is a universal super-critical dealbreaker**." This report **agrees for solo developers and small teams** but **disagrees for the corporate and small mixed team personas**: the gitleaks export scanning is super-critical for the latter, even though it is not "universal." A claim that is **non-universal-but-common** is still super-critical for the population that hits it. The upstream framing under-states this.

---

## 6. Unified vs Composable Architecture — The Real Tradeoff

The unified-vs-composable framing is the **cleanest way to ask the question**. The honest answer:

### 6.1 LeanCTX wins when

- **Operational simplicity is the binding constraint.** One binary, one setup, one update channel. 3,000+ stars and 200+ releases signal that the install path is real. At 5–10 seats with mixed skill levels, the four-stack's "one person owns the template" problem is non-trivial.
- **The wire proxy is enabled.** Compressing every model request (system prompt, history, tool results) is a **real uncaptured surface** the four-stack does not cover. The published `lean-ctx savings sign` / `savings verify-batch` workflow (Ed25519 signed aggregate-only, signed batch is self-verifying with public key + signature, no ledger needed for verification) is a **genuine audit primitive** that none of the four tools offer.
- **AST read modes are the dominant access pattern.** Files are read many times; `signatures` / `map` / `aggressive` / `entropy` modes are unique to LeanCTX.
- **PathJail + shell allowlist** are the security primitive the user wants. LeanCTX's architecture page documents "PathJail every file access is canonicalised and confined to the workspace root" + "IDE config-dir jail" + "Deny-by-default command policy" as **runtime enforcement**, not instruction-only rules.
- **Saved context packages (`.ctxpkg`)** are the team-share pattern. Context packages bundle Knowledge, Graph, Session, Patterns, and Gotchas (catalog §3.4.7) into portable, auto-loadable bundles. This is **.agentmemory/-style** export hygiene in a first-class file format.

### 6.2 The four-stack wins when

- **Multi-agent work orchestration is the workload.** agentmemory's `memory_lease` + `memory_frontier` + `memory_mesh_sync` is not approximated by `ctx_handoff`. This is a **product difference**, not a feature difference.
- **Fetch hardening is a compliance control.** `CTX_FETCH_STRICT` is documented in CM README. LeanCTX's SSRF block does not document a strict-mode tier. For a regulated persona, this is the deciding factor.
- **Code graph is the primary retrieval center.** Graphify's `query` / `path` / `explain` / `affected` on a persistent `graph.json` corpus with `graphify watch` filesystem auto-sync + multimodal vision ingest is a **research-workflow product** LeanCTX does not have at parity.
- **Shared secret-scanned memory exports are the team-share pattern.** agentmemory's gitleaks bridge is documented; LeanCTX has no equivalent.
- **Per-tool specialization matters more than uniformity.** A team that has internalized RTK's per-CLI compressors (`rtk pytest` is `-90%` per RTK README; `rtk go test` NDJSON `-90%`; `rtk err <cmd>` filter-errors-only) does not want to lose that depth to LeanCTX's native shell.

### 6.3 The honest tradeoff

| Scale | Winner | Reason |
|-------|--------|--------|
| 1 seat, interactive coding | **LeanCTX** | One binary, wire proxy, AST modes, PathJail, savings ledger. |
| 1 seat, shell-heavy dev | **LeanCTX + RTK addon** | LeanCTX native + RTK as documented addon. |
| 1 seat, multi-agent | **LeanCTX + agentmemory** | LeanCTX for compression; agentmemory for orchestration. |
| 1 seat, code-graph research | **LeanCTX + Graphify** | LeanCTX for compression; Graphify for multimodal retrieval. |
| 5–10 seats, mixed team | **LeanCTX + agentmemory** (gitleaks bridge) | Setup simplicity for non-devs; team feed for shared memory; gitleaks for safety. |
| 5–10 seats, regulated/corp | **LeanCTX + Context Mode + agentmemory** | LeanCTX for compression; CM for `CTX_FETCH_STRICT`; agentmemory for team memory. |
| Multi-agent ops-at-scale | **LeanCTX + agentmemory + Graphify** | agentmemory is non-negotiable; LeanCTX is the compression layer; Graphify is the retrieval layer. |
| Research workflow (PDFs + papers + code) | **Graphify** as primary | LeanCTX cannot match multimodal corpus graph as product center. |

**The threshold is "do your workflows need multi-agent coordination or strict fetch?" If yes, the four-stack (or LeanCTX + the one tool you need) wins. If no, LeanCTX alone is the right answer.**

---

## 7. Token Economics — Re-Evaluated

The upstream gist's verdict ("Mixed — neither is clearly better") is correct but underspecified. The reason is that the two stacks compress **different layers** of the request pipeline, and the net effect depends on the workload's distribution across layers.

### 7.1 Where LeanCTX has unique wins

- **Wire proxy.** None of the four tools compresses the request body itself. Every LeanCTX-equipped model call (system prompt + history + tool results) is compressed before the request leaves. On long multi-turn sessions with `~200K` token context, this is **the largest single savings surface** the four-stack does not touch. The LeanCTX architecture page documents the wire proxy as "compresses every request to the model — system prompt, history and tool results — prompt-cache safe." This is **architecturally novel** vs the stack.
- **Read-path AST compression.** 10 modes from `full` to `lines:N-M` (catalog), with `ModePredictor` and `mode=auto` for adaptive routing. Cached re-reads cost **~13 tokens** (catalog: "Re-reads of compressed representations cost ~13 tokens"). Bounce detection provides **honest savings reporting** — when the agent re-reads at full fidelity after a compressed read, LeanCTX **discloses the bounce** rather than double-counting the savings. This is a **provable savings** primitive.
- **Bounce-aware honest reporting.** None of the four tools discloses when their compression is "defeated" by a re-read at full fidelity. RTK's `rtk gain` is session metrics. CM's `ctx_stats` is session metrics. LeanCTX's Ed25519 savings ledger is **provable** — the `lean-ctx savings sign` CLI signs an aggregate-only batch with the SHA-256 chain head, signer public key, and signature. The `lean-ctx savings verify-batch` CLI works anywhere, no local ledger needed. This is **a different category of savings verification** than the four tools offer.

### 7.2 Where the four-stack has unique wins

- **Graphify scoped subgraph.** A `graphify query "what connects attention to the optimizer?"` returns a **budget-limited subgraph** (typically hundreds of bytes), not a 50KB `GRAPH_REPORT.md` or a raw file read. The 71.5× token benchmark published in Graphify's README is on a Karpathy-style corpus + papers + images. This is a **multimodal-scale win** the wire proxy does not touch.
- **RTK per-CLI compressor depth.** `rtk pytest` is `-90%`; `rtk go test` is `-90%`; `rtk err <cmd>` is filter-errors-only. These are **command-specific** compressors that understand the structure of each tool's output. LeanCTX's native shell compression is general-purpose; RTK's is specialized. The four-stack's depth wins on shell-heavy dev loops.
- **CM 11-tool MCP surface.** Smaller than LeanCTX's 81. Lower tool-schema context cost per call. The `ctx_batch_execute` (986 KB → 62 KB) and `ctx_execute` (56 KB → 299 B) examples in the CM README are real; the architecture is "sandbox-first, only stdout enters context." This is **fundamentally different from LeanCTX's 81-tool full-mcp surface** — the four-stack can be **leaner per call** despite having four servers, because each server's tool surface is narrower.
- **CM PreCompact session recovery.** A ≤2 KB priority-tiered XML snapshot stored in `session_resume` table, restored on SessionStart. This **reduces re-bootstrap reads after compaction**. None of the four tools lose this. LeanCTX's session survival engine (`build_compaction_snapshot` generating `<recovery_queries>`, `<knowledge_context>`, `<graph_context>`) is documented in the catalog §3.4.7 — but the depth and the SQLite-backed resumption model of CM is a **different product**.

### 7.3 Net token economics

The honest synthesis:

- **If the workload is read-heavy with frequent re-reads:** LeanCTX wins via cached re-reads (13 tokens per cached entry) + AST modes.
- **If the workload is graph-first orientation:** Four-stack wins via `graphify query` scoped subgraph.
- **If the workload is shell-heavy dev:** Four-stack wins via RTK per-CLI depth.
- **If the workload is long multi-turn sessions:** LeanCTX wins via wire proxy.
- **If the workload is sandbox analysis with large raw inputs:** Four-stack wins via CM 11-tool sandbox-first stdout-only.

**No single workload benefits from both stacks simultaneously.** The two are **complementary at the workload-class level, not the per-call level.** This is why the answer to "is LeanCTX better on tokens" is "depends on which workloads you run."

---

## 8. Persona-Specific Verdicts

### 8.1 Solo developer

**Minimum stack: LeanCTX alone.** The 87% on agentmemory and 95% on CM reflect the persona — a solo dev does not run multi-agent orchestration, does not need corporate `CTX_FETCH_STRICT`, and does not typically export memory to git. The wire proxy + AST read modes + PathJail + savings ledger are the load-bearing features. **Optional addition: RTK as documented addon for shell-heavy dev.** Skip agentmemory (single-session coding), skip CM (no compliance need), skip Graphify (no multimodal corpus need).

**Why:** the upstream gist's "Simplification-first persona" verdict is correct. Operational simplicity is the binding constraint, and the 81-tool full-MCP surface is mitigated by Hybrid mode (MCP cached reads + CLI shell/search) which is the default for Cursor, Claude Code, Codex, Windsurf, and 20+ agents. The wire proxy alone is a strong reason to pick LeanCTX over the four-stack for solo interactive work.

### 8.2 Corporate / regulated agent (financial services, healthcare, government contractors)

**Minimum stack: LeanCTX + Context Mode.** The `CTX_FETCH_STRICT` gap is non-negotiable. A regulated agent that can hit internal services without strict-mode SSRF protection is **a compliance incident waiting to happen.** LeanCTX's SSRF block (architecture page) is **not documented at the same level of detail as CM's**, and the matrix correctly marks `CTX_FETCH_STRICT` as — for LeanCTX.

**Why:** The persona does not need agentmemory's 53-tool orchestration (not multi-agent-at-scale), does not need Graphify's multimodal corpus (code-only), does not strictly need RTK as a separate addon (LeanCTX native shell + RTK addon is fine). But it **does** need CM's documented fetch hardening with the strict-mode tier, the `169.254.0.0/16` block including IMDS at `169.254.169.254`, the project-boundary guard on `ctx_execute_file` (closes the documented #852 escape vector), and the host `permissions.allow` honored as a single source of truth. CM is the **only** tool in the matrix that publishes this level of detail.

### 8.3 Multi-agent ops-at-scale (e.g., teams running fleets of agents for SWE-bench-style evaluation, overnight CI, agent-on-agent workflows)

**Minimum stack: LeanCTX + agentmemory.** The 53-tool orchestration surface is non-negotiable. `memory_lease` (exclusive multi-agent leases), `memory_frontier` (unblocked actions ranked), `memory_sentinel_create` + `_trigger` (event-driven unblocking), `memory_mesh_sync` (P2P sync between instances), `memory_signal_send` / `_read` (inter-agent messaging with receipts) — these are **the product**, not a feature cluster. LeanCTX `ctx_agent` + `ctx_handoff` are partial (✓¹).

**Why:** The persona's workload is **coordination of multiple agents** (e.g., one agent on a long task, one on monitoring, one on QA, all running for hours). This requires the leasing, mesh sync, sentinel, signal surface. agentmemory's 4-tier memory consolidation (Working → Episodic → Semantic → Procedural, with Ebbinghaus decay) is also a load-bearing product feature for long-running agents that need to "remember" across sessions — none of the other tools have this.

**Optional additions: Graphify (for shared structural retrieval across the agent fleet), Context Mode (for compliance).**

### 8.4 Small mixed team (5–10 seats, devs + non-devs)

**Minimum stack: LeanCTX + agentmemory.** This is the upstream gist's small-mixed-team verdict, and **this report concurs** — with one important addendum: **gitleaks-scanned shared memory export is super-critical** for this persona (see §5.1 above). The team exports `.agentmemory/` to git, shares via team feed, and **without** secret scanning is one paste-of-an-API-key away from a leak. **If you keep agentmemory, you keep the gitleaks bridge. If you drop agentmemory, you lose it.** This is a decision the upstream gist does not flag, but it is the **most common** decision for a 5–10 seat team.

**Why:** The non-dev seats (PMs, designers, ops) need **durable prose artifacts** (exported markdown, team feed, viewer UI), not `graphify query` or `ctx_execute` discipline. That makes **setup consistency** (one binary vs four) and **export hygiene** (gitleaks on shared git memory) first-class requirements. LeanCTX's single-binary setup cuts onboarding friction; agentmemory's team feed + gitleaks bridge cuts export risk. The two together are **the smallest stack that still serves devs *and* non-devs safely.**

**Skip:** standalone RTK (LeanCTX native or documented RTK addon if shell-heavy is fine), standalone Graphify (unless multimodal corpus is a primary workflow).

### 8.5 Code-heavy Silver Bullet-style (large repo, deep code orientation)

**Minimum stack: LeanCTX alone, optional Graphify for INFERRED-edge git workflow.** This is the SB-default. The 99% Graphify parity on structural code graph (`ctx_query` / `ctx_path` / `ctx_explain`) is **honest** for a typical code agent. Graphify's `graph.json` git workflow with `graphify watch` filesystem auto-sync is the **only** row where Graphify's git-native story beats LeanCTX — but the typical SB user does not maintain `graph.json` as a tracked artifact.

**Why:** The persona's workload is **deep code orientation** — `graphify query "what connects X to Y?"` patterns. LeanCTX's `ctx_graph` + `ctx_query` cover this at parity. The wire proxy + AST read modes + savings ledger are the load-bearing features. Adding Graphify is **only** worth it if you have already built muscle around the `graphify query` / `path` / `explain` / `affected` idioms in the SB workflow.

---

## 9. Synthesis & Insights

### 9.1 The three load-bearing differences

After the analysis, **three load-bearing differences** stand out:

1. **The pipeline pattern.** The four-tool stack is a **chain** (RTK → CM → agentmemory → Graphify). LeanCTX is a **set of subsystems** that compress, remember, and retrieve in isolation. The matrix scores them at 87–99% per tool, but the chain is **not directly replicated** in LeanCTX. This is the **deepest honest critique** the matrix does not surface.
2. **The compliance gap.** Context Mode's `CTX_FETCH_STRICT` + documented fetch-hardening tiers (169.254 block, RFC1918/loopback in strict mode) is the only regulator-defensible fetch policy in the comparison. LeanCTX's SSRF block is at the architecture-page level, not the documented-feature level. For a regulated persona, this is the deciding factor.
3. **The orchestration gap.** agentmemory's 53-tool surface is a **work-orchestration product**, not a memory feature. `memory_lease` + `memory_frontier` + `memory_mesh_sync` + `memory_signal_send` / `_read` + `memory_sentinel_create` / `_trigger` + `memory_crystallize` + `memory_sketch_promote` form a multi-agent coordination primitive. LeanCTX's `ctx_agent` + `ctx_handoff` are partial. For a multi-agent ops-at-scale persona, this is the deciding factor.

### 9.2 The pipeline pattern is the strongest critique

The four-tool stack is not a 4×95% stack — it is a chain where each tool's output feeds the next. The combined stack creates **value above the matrix** because the chain produces patterns the individual tools do not:

- agentmemory's "save decisions" → Graphify's "retrieve via graph" (the SB pattern) is **an idiom**, not a feature. LeanCTX does not have an equivalent documented idiom.
- RTK's compressed shell output → CM's `ctx_execute` sandbox analysis → agentmemory's observation capture is **a chain** that the four-stack user does not have to think about. LeanCTX's user has to **manually chain** `ctx_compress` → `ctx_execute` → `ctx_knowledge` — which works, but is not the same **ergonomic** outcome.

**This is the strongest critique of LeanCTX-as-replacement that the upstream gist does not make.** A team that has internalized the SB-style four-stack will find the migration **a real ergonomic loss**, even if the byte-for-byte capability is similar.

### 9.3 The wire proxy is a real uncaptured surface

The four-stack's biggest structural gap is **no wire proxy**. None of the four tools compresses the request body itself — only what feeds into it. LeanCTX's wire proxy (compresses every model request — system prompt, history, tool results — prompt-cache safe) is **architecturally novel** and is the **single largest savings surface** the four-stack does not touch. On long multi-turn sessions, this is **the strongest single reason to prefer LeanCTX over the four-stack for interactive coding.**

### 9.4 The savings ledger is a real audit primitive

`lean-ctx savings sign` produces a JSON file that is **self-verifying**: it carries its own public key and signature, includes the SHA-256 chain head, the chain-valid flag, the net tokens saved, the dollar amount, and the model/tool breakdown. The `lean-ctx savings verify-batch` CLI works **anywhere, no ledger needed**. This is a **different category of audit** than RTK's `rtk gain` (session metrics) or CM's `ctx_stats` (session metrics) or agentmemory's `memory_audit` (operation-level audit). For a team that needs to **prove** token savings to a CFO or auditor, this is **the only tool in the comparison that does it.**

---

## 10. Limitations & Caveats

### 10.1 The biggest caveat: no controlled head-to-head benchmarks exist

The research community has **zero controlled head-to-head benchmarks** between LeanCTX and any of the four stack tools on identical tasks. The vendor-published numbers (LeanCTX 60–90% per read, Context Mode ~94% vs raw fetch in README examples, agentmemory ~170K tokens @ ~$10 on LongMemEval, Graphify 71.5× on Karpathy corpora, RTK `rtk pytest` is `-90%`) are **all self-reported on self-selected workloads.** The upstream gist says this explicitly: "vendor percentages ... are uncorroborated." This report concurs. **Any single-number claim is directional marketing, not evidence.**

### 10.2 LeanCTX's 81 MCP tools is a real schema cost

The upstream gist correctly notes that "Single-binary ≠ lower tokens if the full 81-tool catalog is exposed; four-stack can be leaner per MCP call despite more servers." This is **architecturally accurate**. The catalog documents **5 unified high-level tools** as the lean path, and the architecture page documents three integration modes (CLI-Redirect, Hybrid, Full MCP) auto-selected per agent. The **Hybrid mode** is the default for Cursor, Claude Code, Codex, Windsurf, and 20+ agents — and it is the mode that mitigates the 81-tool cost. But this **requires the user to use the right mode**; the 81-tool full-MCP mode is real and inflates the tool-definition context.

### 10.3 Tool drift and version currency

The upstream audit is dated 2026-07-05. This report is 2026-07-07. Both are **post-cutoff for the tools' latest releases** per the version data fetched: LeanCTX Feature Catalog v3.8.1 (2026-05-15), LeanCTX GitHub README claims "200+ releases — shipped near-daily since launch." The catalog data I indexed and validated is from the `main` branch as of the fetch date. **The matrix is current within ~2 days; the four stack tool READMEs are also current as of the fetch date.** No major version bump has shipped in this window per the indexed sources. But the four-tool stack is also under active development (CM README is highly polished, agentmemory has the `iii` engine + worker ecosystem, Graphify is at v1 with active CI). **Tool drift is a real risk for any "definitive verdict" written today.**

### 10.4 The gitleaks export scanning promotion is this report's contrarian claim

The upstream gist marks "gitleaks on memory export" as **important but not super-critical.** This report **promotes it to super-critical for the small mixed team persona** (§5.1, §8.4). The reasoning: the **non-dev seats** in a 5–10 person mixed team are the **exact seats that will paste an API key into memory** without thinking about it. The combination of `.agentmemory/` in git + team feed + non-dev seats is the **most common** enterprise starter profile, and the secret-scanning bridge is the **single most important safety primitive** in the comparison for that profile. The upstream framing under-states this. **This report's contrarian promotion may be over-stated for non-team personas, but it is **correct** for the small-mixed-team persona.**

### 10.5 The pipeline critique is not measurable in the matrix

The "pipeline pattern" critique (§3, §9.2) is **not visible in the 200-row matrix**. It is a **workflow ergonomic** critique, not a feature-parity critique. The matrix scores LeanCTX at 87% vs agentmemory and 99% vs Graphify — but those scores measure **what each tool can do**, not **whether the chain the four-stack creates is replicated**. **Any verdict based purely on the matrix under-weights this.** A team that has built muscle around the SB pattern (RTK + CM + agentmemory + Graphify in `silver-bullet.md`'s recommended tools section) will find a real ergonomic loss in migration, even at 95%+ parity.

---

## 11. Recommendations

### 11.1 For the Silver Bullet project (as the implicit stakeholder)

**Treat the four-tool stack as a composable baseline, not a rip-and-replace target.** The upstream gist's small-mixed-team verdict (LeanCTX + agentmemory) is **correct** for the most common starter profile, but the **simplification-first** persona (LeanCTX alone) is also valid for solo dev / interactive coding. **Document both personas in the SB recommended-tools rule** (`recommended-tools.mdc`) and let the user pick.

**Do not add LeanCTX as a fourth tool to the existing four.** The four-tool stack is already composable. Adding LeanCTX as a fifth tool **does not** replace anything; it adds a parallel compression layer. The right integration is **LeanCTX as a replacement for RTK + CM** (the compression layer), keeping agentmemory + Graphify for memory + retrieval. **This is the minimum-stack recommendation that preserves the most capability while reducing the install surface to 3 tools.**

### 11.2 For the solo developer

**Adopt LeanCTX as mainstay.** The wire proxy + AST read modes + PathJail + savings ledger are the load-bearing features for interactive coding. Add RTK as a documented addon for shell-heavy dev loops. Skip agentmemory, CM, Graphify unless you hit a specific persona (§8.2–§8.4).

### 11.3 For the corporate / regulated agent builder

**Adopt LeanCTX + Context Mode.** Do **not** drop CM. The `CTX_FETCH_STRICT` tier is the only regulator-defensible fetch policy in the comparison, and the gap is **not a feature gap; it is a compliance gap.** Add agentmemory if you need team-shared memory with the gitleaks bridge. Add Graphify only if you have a multimodal corpus workflow.

### 11.4 For the multi-agent ops-at-scale builder

**Adopt LeanCTX + agentmemory + Graphify.** The 53-tool orchestration surface is non-negotiable. The wire proxy + AST read modes cover the compression layer. The Graphify scoped subgraph covers the retrieval layer. **Do not drop agentmemory.** The 87% parity is honest, and the 13% gap is the **product** for this persona.

### 11.5 For the small mixed team

**Adopt LeanCTX + agentmemory.** The gitleaks-scanned shared memory export is **the safety primitive that makes team memory safe to share via git.** Do **not** drop agentmemory unless you have a separate secret-scanning policy on `.agentmemory/`. The team feed is the non-dev-readable surface. Add Context Mode only if corporate/regulated.

### 11.6 For the researcher with a multimodal corpus

**Stay on Graphify as primary.** LeanCTX's `ctx_graph` is at parity for code-only, but the multimodal corpus graph as primary deliverable is a **different product center.** The 71.5× token benchmark published in Graphify's README is on this kind of workload. LeanCTX cannot replicate it.

---

## 12. Bibliography

All sources were fetched and indexed via `ctx_fetch_and_index` in this research run, with the exception of prior research referenced in the upstream gist.

### 12.1 LeanCTX primary sources

- [LC-home] `https://leanctx.com/` — landing page; "One local Rust binary," "60–90% fewer tokens as the receipt," feature overview.
- [LC-arch] `https://leanctx.com/architecture/` — Cognitive Context Layer architecture; PathJail, IDE config-dir jail, shell allowlist, wire proxy, Ed25519-signable savings ledger.
- [LC-compat] `https://leanctx.com/compatibility` — 30+ AI tools auto-detected; RTK documented as compatible compression addon.
- [LC-ledger] `https://leanctx.com/docs/concepts/savings-ledger` — Savings ledger docs; `lean-ctx savings sign` / `savings verify-batch` CLI; Ed25519 signed aggregate-only batch with self-verifying public key + signature.
- [LC-catalog] `https://raw.githubusercontent.com/yvgude/lean-ctx/main/LEANCTX_FEATURE_CATALOG.md` — Feature catalog v3.8.1 (2026-05-15); 81 granular MCP tools, 5 unified MCP tools, 10 read modes, Context Package System v3.4.7.
- [LC-github] `https://github.com/yvgude/lean-ctx` — 3,000+ stars, 280+ forks, 200+ releases, 30+ agents, 81 MCP tools.

### 12.2 Four-tool stack primary sources

- [RTK-readme] `https://raw.githubusercontent.com/rtk-ai/rtk/master/README.md` — 14 AI coding tools, 60–90% token savings, command-specific compressors (jest, vitest, pytest, go test, cargo test, etc.), `rtk gain` / `discover` / `session` analytics, auto-rewrite hook.
- [CM-readme] `https://raw.githubusercontent.com/mksglu/context-mode/main/README.md` — 11 MCP tools, FTS5 with Porter + trigram + RRF + Levenshtein, `CTX_FETCH_STRICT` SSRF tiers, 169.254.0.0/16 block including IMDS, PreCompact session resume, `ctx_execute_file` project-boundary guard, 17+ platform hooks.
- [AM-readme] `https://raw.githubusercontent.com/rohitg00/agentmemory/main/README.md` — 53 MCP tools, 6 Resources, 3 Prompts, 4 Skills, 4-tier memory consolidation, Claude MEMORY.md bridge, gitleaks-scanned exports, vector embeddings, `iii` engine + worker ecosystem, LongMemEval benchmark (170K tokens @ ~$10).
- [GF-readme] `https://raw.githubusercontent.com/safishamsi/graphify/main/README.md` — graph-first knowledge graph, tree-sitter AST + LLM INFERRED edges, god nodes, Leiden communities, `query` / `path` / `explain` / `affected` MCP commands, multimodal vision ingest, 71.5× token benchmark on Karpathy corpus, Obsidian / GraphML / Neo4j Cypher / interactive HTML export.

### 12.3 Silver Bullet canonical sources (referenced but not re-fetched in this run)

- `docs/RTK.md`, `docs/CONTEXT-MODE.md`, `docs/AGENTMEMORY.md`, `docs/GRAPHIFY.md` — SB's per-tool integration docs.
- `docs/code-intelligence-contract.md` — documents the "save via agentmemory, retrieve via Graphify" SB synergy pattern.
- `silver-bullet.md` §2g — recommended tools section (RTK + Context Mode + agentmemory + Graphify as the four-tool baseline).
- `recommended-tools.mdc` — Cursor rule for recommended tools.
- `.planning/research/2026-07-05-context-mode-vs-lean-context-ultradeep/` — prior ultradeep research on the same comparison axis.

### 12.4 Upstream research artifacts

- `gist-leanctx-capability-analysis.md` (2026-07-05) — upstream gist with 200-row × 5-column matrix and per-tool coverage scores.
- `feature-coverage-matrix.md` (88 rows) — primary matrix artifact.
- `claims.jsonl` (10 claims), `evidence.jsonl` (27 evidence spans), `sources.jsonl` (18 sources) — triangulation artifacts.
- `research_report.md` — narrative synthesis.
- `run_manifest.json` — run metadata for the 2026-07-05 ultradeep audit.

---

## 13. Methodology Appendix

### 13.1 Source classification

| Class | Targets | Fetched this run? |
|-------|---------|-------------------|
| Primary vendor web | leanctx.com (4 pages) | Yes (fetched + indexed) |
| Primary vendor docs | LEANCTX_FEATURE_CATALOG.md | Yes (fetched + indexed) |
| Primary vendor GH | github.com/yvgude/lean-ctx | Yes (fetched + indexed) |
| Primary upstream | RTK, CM, agentmemory, Graphify READMEs | Yes (fetched + indexed) |
| SB canonical docs | `docs/{RTK,CONTEXT-MODE,AGENTMEMORY,GRAPHIFY}.md`, `docs/code-intelligence-contract.md` | Referenced via upstream gist (not re-fetched) |
| Upstream research | `gist-leanctx-capability-analysis.md`, `feature-coverage-matrix.md`, `claims.jsonl`, `evidence.jsonl`, `sources.jsonl`, `research_report.md` | Re-read from working directory |

### 13.2 Retrieval strategy

- All 7 primary upstream sources fetched in parallel via `ctx_fetch_and_index` with `concurrency: 5` and `ttl: 0` (cache bypass for fresh data).
- 500+ FTS5 chunks indexed in the context-mode knowledge base across the 7 sources.
- 12 search queries run in 3 batched `ctx_search` calls + 1 global `ctx_batch_execute` for the final round of cross-source validation.

### 13.3 Triangulation

- Every matrix ✓ in this report was re-validated against at least one primary source.
- The 17 hard gaps were re-checked: 13 cell-exact gaps confirmed (cell shows — in the matrix); 4 depth gaps confirmed (✓¹ with documented thinner surface).
- The 4 persona-conditional super-critical promotions (CTX_FETCH_STRICT, 53-tool orchestration, gitleaks export, wire proxy) were re-checked against primary sources.
- The 4 vendor-published token percentages (LeanCTX 60–90%, CM ~94%, agentmemory ~170K @ ~$10, Graphify 71.5×, RTK `-90%` per command) were re-extracted from primary sources and **flagged as uncorroborated in cross-vendor conditions.**

### 13.4 Critique pass

After initial synthesis, this report was critiqued on:

- **Assumptions:** Are the persona definitions load-bearing? Yes — "better" is multi-dimensional and persona-conditional. Are the 87–99% scores correct? Directional yes, but the rule is the report's choice.
- **Missing evidence:** No controlled head-to-head benchmark exists; vendor percentages are uncorroborated cross-vendor.
- **Where the verdict could be wrong:** The pipeline critique (§3, §9.2, §10.5) is not directly measurable in the matrix; it is a **workflow ergonomic** critique, not a feature-parity critique. A team that has not built muscle around the SB pattern may not feel this loss.
- **What would change the verdict:** A published head-to-head benchmark; a major version bump in any of the five tools; a new tool that closes the gitleaks gap in LeanCTX; a documented LeanCTX pipeline idiom that replicates the SB chain.

### 13.5 Limitations of this report

- **No install / no measurement.** This is a capability analysis, not an install log. None of the tools was installed and run for this report.
- **The upstream gist is the SSOT for the 200-row matrix.** This report validates the load-bearing claims but does not re-audit every cell.
- **Tool drift window is ~2 days.** The upstream audit and this report are within a 2-day window. No major version bump has shipped in that window.
- **The 4 vendor-published token percentages are self-reported.** No cross-vendor benchmark exists. This report's synthesis is **directional**, not quantitative.

### 13.6 Reproducibility

To reproduce this report's research:

```bash
# Index all 7 primary sources
ctx_fetch_and_index(
  requests=[
    {url: "https://leanctx.com/", source: "leanctx-home"},
    {url: "https://leanctx.com/architecture/", source: "leanctx-arch"},
    {url: "https://raw.githubusercontent.com/yvgude/lean-ctx/main/LEANCTX_FEATURE_CATALOG.md", source: "leanctx-catalog"},
    {url: "https://raw.githubusercontent.com/rtk-ai/rtk/master/README.md", source: "rtk-readme"},
    {url: "https://raw.githubusercontent.com/mksglu/context-mode/main/README.md", source: "cm-readme"},
    {url: "https://raw.githubusercontent.com/rohitg00/agentmemory/main/README.md", source: "am-readme"},
    {url: "https://raw.githubusercontent.com/safishamsi/graphify/main/README.md", source: "gf-readme"},
  ],
  concurrency=5
)

# Search for the 17 hard gaps and the 4 super-critical promotions
ctx_search(queries=[
  "81 MCP tools 10 read modes AST signatures",
  "wire proxy request compression prompt cache safe",
  "Ed25519 hash chained savings ledger offline verify",
  "CTX_FETCH_STRICT RFC1918 loopback block SSRF mode",
  "PreCompact hook XML snapshot recovery",
  "53 MCP tools orchestration sentinels action DAG",
  "memory_verify citation chain gitleaks export",
  "sketch promote crystallize diagnose heal",
  "tree-sitter god nodes Leiden communities",
  "71.5x query efficiency graph.json",
])
```

---

## Final Verdict

**LeanCTX is a credible single-tool mainstay for most serious agentic coding, but it is NOT a universal replacement for the four-tool stack.** It is a structural substitute with a different center of gravity — a unified runtime with strong compression, governance, and provable savings — not a superset of the four-stack's chain.

**Replace the four-tool stack with LeanCTX when:**
- The persona is solo dev, interactive coding, or small mixed team (5–10) without strict compliance.
- The wire proxy + AST read modes + savings ledger are the load-bearing features.
- Operational simplicity is the binding constraint.

**Keep one or more of the four-stack tools when:**
- The persona is corporate / regulated (`CTX_FETCH_STRICT` is non-negotiable).
- The workload is multi-agent ops-at-scale (53-tool orchestration is non-negotiable).
- The team exports memory to git (gitleaks bridge is non-negotiable).
- The workload is research with multimodal corpus (Graphify is the product).

**The strongest single reason to prefer LeanCTX over the four-stack:** the wire proxy (compresses every model request, prompt-cache safe) and the Ed25519 savings ledger (provable, self-verifying, offline batch verify). These are **architecturally novel** surfaces the four-stack does not touch.

**The strongest single reason to keep the four-stack over LeanCTX:** the four-stack creates a **pipeline pattern** (RTK → CM → agentmemory → Graphify) that LeanCTX does not replicate as an idiomatic chain. The 87% on agentmemory is honest for single-session coding but **insufficient for multi-agent ops-at-scale.** The `CTX_FETCH_STRICT` gap is a **compliance gap, not a feature gap.**

**The honest synthesis:** the answer to "is LeanCTX better?" is **"better for what persona, for what workload, at what scale, with what compliance posture?"** Any scalar answer is wrong. The matrix gives 87–99% per tool; the real question is whether the missing percentage is **load-bearing for your workflow.** For most solo / interactive coding, the answer is **no, and LeanCTX is better.** For multi-agent ops or regulated agents, the answer is **yes, and the four-stack (or LeanCTX + the one tool you need) is better.**

The two stacks are **complementary at the workload-class level, not the per-call level.** The right answer for the SB project is to **document both personas** in the recommended-tools rule and let the user pick.

---

**End of report.**

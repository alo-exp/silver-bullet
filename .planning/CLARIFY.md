# `/silver:deep-research-multi-ai` — Clarification Brief

**Source plan:** [multi_ai_deep_research_b3d9881b.plan.md](/Users/shafqat/.cursor/plans/multi_ai_deep_research_b3d9881b.plan.md)  
**Clarify run:** 2026-07-15 (AF-CLARIFY on workflow implementation plan)  
**Scope:** Catalog-backed multi-model orchestration layer on the existing SB deep-research engine — not a second DR engine, not a MultAI revival.

---

## Problem Statement

Silver Bullet already ships a mature single-host `/silver:deep-research` workflow (`WF-SILVER-DEEP-RESEARCH`) with a canonical state machine, evidence validators, solution-landscape/compare paths, and `research/<date>-<topic>/` artifacts. Users who want **triangulated, multi-model research** today must either:

- run ad-hoc `silver:multi-ai-task` orchestration (OpenCode-centric, not DR-phase-aware), or
- manually fan out across Cursor subagents with no deterministic consolidation, provenance, or DR artifact compatibility.

The removed `FS-SILVER_MULTI_AI` / MultAI surfaces were intentionally excised from `AF-DECIDE` so ordinary deep research stays direct and dependency-free. The gap remains: **no first-class, opt-in SB workflow** that runs parallel model lanes inside the canonical DR phases and produces byte-stable consolidated output.

**Audience:** Operators and researchers who explicitly want multi-model triangulation for technology decisions, landscape/compare work, or high-stakes architecture spikes — and who accept higher cost, latency, and setup (Cursor custom agents + OpenCode profiles).

**Done looks like:**

- A new opt-in route `WF-SILVER-DEEP-RESEARCH-MULTI-AI` (`/silver:deep-research-multi-ai`) composes the existing DR engine, `silver:agent-opencode` (OCG legs), and six pinned Cursor custom agents.
- Default dry-run resolves **OCG lite + Cursor default pool** (11 agents); pools are selectable/excludable with documented precedence.
- One host-owned SB DR controller advances phases; workers return phase-scoped contributions only; deterministic consolidation merges claims/sources/evidence with full provenance.
- Existing `/silver:deep-research` and generic `/silver:agent-opencode` behavior is unchanged.
- Fresh downstream install/upgrade/repair provisions `sb-dr-*` agents idempotently without touching user-owned agents.

---

## PM Framing

| Dimension | Position |
|-----------|----------|
| **Value** | Higher-confidence research via model diversity; honest divergence/conflict reporting; DR-compatible artifacts for downstream `/silver:feature`, `/silver:plan`, or `/silver:compare` handoff |
| **Cost** | Explicit — parallel legs multiply tokens/API spend; caps and `partial-ok` default acknowledge budget reality |
| **Risk reduction** | No silent model substitution; filesystem containment; no second DR engine; MultAI workflow IDs stay retired |
| **Positioning** | Sibling workflow, user-requested or router-discriminated — never the default path for ordinary "which technology" questions |

---

## Options Considered

### 1. Thin orchestration layer on canonical DR (plan as written) — **recommended**

Add `skills/silver-deep-research-multi-ai/` as a **dispatch + consolidation controller** around the existing `silver-deep-research` state machine. OCG legs go through supervised `/silver:agent-opencode`; Cursor legs use provisioned `sb-dr-*` custom agents. Host owns phase sequencing, validators, manifests, and consolidated writes.

| Pros | Cons |
|------|------|
| Reuses DR phases, validators, `research/` contract, and agent-opencode security/completion contracts | Large implementation surface (8 phases, dual backends, provisioning) |
| Deterministic consolidation with provenance fits SB evidence culture | Requires live Cursor model catalog resolution at implementation time |
| Clear separation from removed MultAI; tests already assert `FS-SILVER_MULTI_AI` absence | Operational complexity: OpenCode drift, Cursor model availability, concurrency tuning |

### 2. Simpler — "second opinion" extension to single-agent DR

Extend `/silver:deep-research` with an optional `--second-model <id>` flag that runs one extra leg and appends a `divergence.md` — no pool algebra, no Cursor agent fleet, no consolidation core.

| Pros | Cons |
|------|------|
| Smallest diff; ships in weeks | Does not meet stated goal (6+1 default pool, exclusion algebra, byte-stable merge) |
| Lower cost and fewer moving parts | Would need a second expansion pass for landscape/compare multi-model paths |
| No new workflow route (avoids 18-route lock tension) | Archived multi-AI consolidation patterns stay unused |

### 3. Reuse `silver:multi-ai-task` as the orchestration spine

Wire existing `multi-ai-task` dispatch/consolidation into DR by translating phase briefs to multi-ai-task prompts and back.

| Pros | Cons |
|------|------|
| Reuses proven OpenCode parallel dispatch patterns | multi-ai-task is spec-heavy, not DR-phase-aware; known gaps (extractor circularity, phase numbering drift per self-review) |
| Less new orchestration code | Bypasses agent-opencode supervision contract the plan explicitly requires |
| | Cursor backend would still need separate provisioning — dual-backend problem remains |

### 4. OCG-only multi-model (defer Cursor pool to v2)

Ship v1 with OCG lite/regular pools only; add Cursor custom-agent provisioning in a follow-on release.

| Pros | Cons |
|------|------|
| Reduces Phase 2 risk (model ID resolution, installer scope) | Default promise is **OCG lite + six Cursor agents** — shipping without Cursor breaks acceptance criteria |
| Faster path to consolidation/dispatch tests with fake backends | Users on Cursor-only hosts get no value from the flagship workflow |

---

## Pressure-Test — Assumptions and Gaps

### Assumptions the plan relies on (validated or reasonable)

- **Single DR engine invariant** — Correct. Forking a second state machine would duplicate validators, `phases.yaml`, and landscape/compare gates. The host-controller pattern matches how SB already treats orchestrator vs worker boundaries.
- **Opt-in sibling, not MultAI revival** — Aligns with repo tests (`FS-SILVER_MULTI_AI` removed), site docs (MultAI only on explicit user request for ordinary DR), and changelog direction.
- **`silver:agent-opencode` as OCG sole path** — Preserves mentor, completion, secret-scan, and log-floor contracts; bypass would be a security/process regression.
- **Deterministic consolidation without LLM in the merge** — Essential for reproducible golden tests and honest consensus denominators.
- **Isolated agent lanes + orchestrator-only top-level writes** — Matches SB path-ownership patterns and prevents cross-agent prompt injection via filesystem reads.

### Uncertainties requiring implementation-time validation

| Area | Gap | Mitigation in plan |
|------|-----|-------------------|
| Cursor model IDs | Opus/Gemini/GLM/Sol bracket params must come from live catalog | Phase 2: capability probe + AskQuestion; hard error on unverified identity |
| Which DR phases are parallelized | Plan says host decides per phase but does not enumerate v1 phase list | Lock during Phase 1 contract: publish `parallel_phases` manifest per research_type |
| 18-route public lock | Router rebuild plan pins exactly 18 `silver:<route>` names | Phase 6 must confirm slot — may require lock amendment or replace a retired route |
| Cost defaults | Caps mentioned but not default values | Define in pool profile JSON + operator guide |
| LLM editorial polish | Optional, non-normative — default off implied but not explicit | Lock: `consolidation.editorial_llm: false` unless `--polish` |
| `ocg-glm-5.2` exclusion | Explicit in plan | Document rationale in operator guide (cost/quality/policy) |

### Research / validation gaps before ship

- Two-agent live smoke (one OCG + one Cursor) is necessary but not sufficient — matrix must cover all six Cursor agents and every included OCG slug.
- Downstream-project install tests (no source checkout dependency) are high-risk; prioritize early in Phase 2.
- Schema migration story for `dispatch_ledger` across versions needs fixture coverage in Phase 4 tests.

---

## Convergence — Recommendation

**Proceed with Option 1 (plan as written).** The inherited GPT-5.6 Sol High review rung is complete; locked behavior is internally consistent with the current repo posture (single-agent DR default, MultAI removed, `research/` contract, agent-opencode supervision).

The plan correctly rejects simpler options for the stated acceptance criteria. Option 2 would under-deliver; Option 3 would inherit multi-ai-task technical debt; Option 4 violates the default pool contract.

### Locked decisions (do not re-litigate without user override)

- Opt-in `WF-SILVER-DEEP-RESEARCH-MULTI-AI`; no replacement of `WF-SILVER-DEEP-RESEARCH`
- One canonical SB DR engine/state machine; workers are phase contributors only
- Default: OCG lite + Cursor default pool (6 agents); `ocg-glm-5.2` excluded; regular/lite mutex
- No silent model substitution — AskQuestion: enable / exclude / abort
- Output under `research/<YYYY-MM-DD>-<topic>/`; per-agent isolated dirs; orchestrator consolidated writes only
- Pool selection algebra: `{none,lite,regular} × {none,default}`, `--include-only` then `--exclude`, reject empty resolved set
- Implementation order: contracts → provisioning → backends → consolidation → registration → verification

### Gray areas to resolve in Phase 1 (contracts), not in clarify

1. **Explicit `parallel_phases` table** per `research_type` (`default`, `solution-landscape`, `solution-compare`) and depth mode.
2. **Router/catalog slot** for the 19th workflow vs amendment to `public-workflow-routes.lock.json` (coordinate with router rebuild milestone).
3. **Default cost/concurrency caps** and failure policy UI copy for `partial-ok` vs `fail-fast`.
4. **Project vs global** Cursor agent scope default (`project` per plan; confirm config key name).

---

## Unresolved Questions (product / technical)

| # | Question | Owner | Suggested resolution |
|---|----------|-------|---------------------|
| Q1 | Does multi-AI DR require explicit user wording every run, or may `preferences.json` set `auto-run` for research triggers? | Product | Mirror ordinary DR: explicit opt-in for route; preferences may default pool selection but not silent invocation |
| Q2 | Should `solution-landscape` / `solution-compare` be v1-supported given backend-independent validator constraint? | Engineering | Yes for types with backend-independent validators; gate others in manifest with clear error |
| Q3 | Where does consolidated HTML rank vs existing `generate_report_spa.py` — merge or parallel generator? | Engineering | Reuse SPA patterns; multi-AI adds `consolidated/report.html` per plan — prove composability in Phase 5 |
| Q4 | Is GLM-5.2 in Cursor pool while `ocg-glm-5.2` is excluded intentional? | Product | Yes unless policy changes — document as asymmetric trust/cost decision |
| Q5 | Interaction with future 18-route lock / native subagent surfaces? | Architecture | Register in Phase 6; do not block Phase 1–5 on router rebuild — use feature branch contract |

---

## Next-Step Notes

**Primary next route:** **`/silver:deep-research-multi-ai` implementation path** — begin **Phase 1 (contracts)** per plan todo `contracts`:

- Add `skills/silver-deep-research-multi-ai/SKILL.md` (thin controller)
- Versioned pool definitions + JSON schemas + fixtures
- CLI/options contract + reuse memo
- Publish `parallel_phases` table and resolve Q1–Q5 gray areas in schema/profile data

**Not recommended next:** `/silver:context` — no brownfield project framing needed; the implementation plan is repo-native and phase-scoped.

**Optional:** `/silver:plan` — only if the parent orchestrator needs `.planning/ROADMAP.md` / phase files materialized from the eight plan phases before spawning implementation workers. The source plan is already implementation-ready; **skip `/silver:plan` unless milestone tracking is required**.

**Suggested worker queue after contracts:**

1. `contracts` → `provisioning` → `backends` → `consolidation` → `registration` → `verification`
2. TDD-first: minimal multi-agent fixture tree + schema tests before live smoke

**Blockers:** None for clarify. **Pre-implementation blockers to watch:** Cursor model catalog access during Phase 2; router lock slot during Phase 6.

---

## Artifacts

| Artifact | Path |
|----------|------|
| Clarify brief (this file) | [.planning/CLARIFY.md](.planning/CLARIFY.md) |
| Source implementation plan | [multi_ai_deep_research_b3d9881b.plan.md](/Users/shafqat/.cursor/plans/multi_ai_deep_research_b3d9881b.plan.md) |
| Parent DR contract | [research/README.md](research/README.md) |
| Clarify workflow reference | [site/help/workflows/silver-clarify.html](site/help/workflows/silver-clarify.html) |

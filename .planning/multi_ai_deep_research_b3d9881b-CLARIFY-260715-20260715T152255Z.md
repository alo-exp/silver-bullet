# `/silver:deep-research-multi-ai` — Clarification Brief

**Source plan:** [multi_ai_deep_research_b3d9881b.plan.md](/Users/shafqat/.cursor/plans/multi_ai_deep_research_b3d9881b.plan.md)  
**Clarify run:** 2026-07-15 (AF-CLARIFY on updated workflow implementation plan)  
**Scope:** Catalog-backed multi-model orchestration layer on the existing SB deep-research engine — with a **new DR-native orchestration spine that replaces `/silver:multi-ai-task`**.

---

## Problem Statement

Silver Bullet ships a mature single-host `/silver:deep-research` workflow with a canonical state machine, evidence validators, solution-landscape/compare paths, and `research/<date>-<topic>/` artifacts. Users who want **triangulated, multi-model research** today must either:

- run ad-hoc `/silver:multi-ai-task` orchestration (OpenCode-centric, not DR-phase-aware, known extractor/phase drift), or
- manually fan out across Cursor subagents with no deterministic consolidation, provenance, or DR artifact compatibility.

The removed `FS-SILVER_MULTI_AI` / MultAI surfaces were intentionally excised from `AF-DECIDE` so ordinary deep research stays direct. The gap remains: **no first-class, opt-in SB workflow** that runs parallel model lanes inside canonical DR phases, produces byte-stable consolidated output, and **supersedes the legacy multi-ai-task spine** for research orchestration.

**Audience:** Operators and researchers who explicitly want multi-model triangulation for technology decisions, landscape/compare work, or high-stakes architecture spikes — and who accept higher cost, latency, and setup (Cursor custom agents + OpenCode profiles).

**Done looks like:**

- Opt-in route `WF-SILVER-DEEP-RESEARCH-MULTI-AI` (`/silver:deep-research-multi-ai`) composes the existing DR engine, supervised `/silver:agent-opencode` (OCG legs), and six pinned Cursor custom agents via a **new orchestration spine**.
- Default dry-run resolves **OCG lite + Cursor default pool** (11 agents); pools are selectable/excludable with documented precedence.
- One host-owned SB DR controller advances phases; workers return phase-scoped contributions only; deterministic consolidation merges claims/sources/evidence with full provenance.
- **`/silver:multi-ai-task` is not used** — the new spine replaces it for DR-multi-AI and becomes the long-term SB multi-model contract.
- Existing `/silver:deep-research` and generic `/silver:agent-opencode` behavior is unchanged.

---

## PM Framing

| Dimension | Position |
|-----------|----------|
| **Value** | Higher-confidence research via model diversity; honest divergence/conflict reporting; DR-compatible artifacts for downstream `/silver:feature`, `/silver:plan`, or `/silver:compare` handoff |
| **Cost** | Explicit — parallel legs multiply tokens/API spend; caps and `partial-ok` default acknowledge budget reality |
| **Risk reduction** | No silent model substitution; filesystem containment; no second DR engine; no dual-spine routing; MultAI workflow IDs stay retired |
| **Positioning** | Sibling workflow, user-requested or router-discriminated — never the default path for ordinary "which technology" questions |

---

## Options Considered

### 1. DR-native thin controller + new orchestration spine (plan as updated) — **recommended**

Add `skills/silver-deep-research-multi-ai/` as dispatch + consolidation controller around the existing `silver-deep-research` state machine. Implement a **new spine** under `skills/silver-deep-research-multi-ai/scripts/` that **replaces** `/silver:multi-ai-task`. OCG legs go through supervised `/silver:agent-opencode`; Cursor legs use provisioned `sb-dr-*` custom agents.

| Pros | Cons |
|------|------|
| Reuses DR phases, validators, `research/` contract, and agent-opencode security/completion contracts | Large implementation surface (8 phases, dual backends, provisioning) |
| Clean long-term multi-model contract; router can deprecate multi-ai-task for research | Migration work for any remaining multi-ai-task callers |
| Deterministic consolidation with provenance fits SB evidence culture | Operational complexity: OpenCode drift, Cursor model availability |

### 2. Simpler — "second opinion" extension to single-agent DR

Extend `/silver:deep-research` with an optional `--second-model <id>` flag.

| Pros | Cons |
|------|------|
| Smallest diff | Does not meet stated pool algebra, consolidation, or spine-replacement goals |

### 3. Reuse `silver:multi-ai-task` as the orchestration spine — **rejected**

Wire existing multi-ai-task dispatch/consolidation into DR by translating phase briefs.

| Pros | Cons |
|------|------|
| Less new orchestration code | **Explicitly rejected** — inherits multi-ai-task technical debt, bypasses agent-opencode supervision, not DR-phase-aware |
| | Conflicts with locked direction: new spine **replaces** multi-ai-task |

### 4. OCG-only multi-model (defer Cursor pool to v2)

| Pros | Cons |
|------|------|
| Reduces Phase 2 risk | Breaks default pool contract (OCG lite + six Cursor agents) |

---

## Pressure-Test — Assumptions and Gaps

### Validated assumptions

- **Single DR engine invariant** — Correct; workers are contributors only.
- **New spine replaces multi-ai-task** — Correct strategic direction; requires router guards + manifest `spine=dr-multi-ai` telemetry.
- **Opt-in sibling, not MultAI revival** — Aligns with repo tests and changelog.
- **`silver:agent-opencode` as OCG sole path** — Preserves security/completion contracts.
- **Deterministic consolidation** — Essential for golden tests and honest consensus denominators.

### Uncertainties (Phase 1 contracts)

| Area | Gap | Mitigation |
|------|-----|------------|
| Cursor model IDs | Live catalog resolution required | Phase 2 capability probe + AskQuestion |
| `parallel_phases` per research_type | Not enumerated in plan | Lock in Phase 1 manifest |
| Router slot / 18-route lock | May need lock amendment | Coordinate Phase 6 registration |
| multi-ai-task deprecation timing | Separate milestone from v1 ship | Catalog deprecation note + migration doc in Phase 6/8 |

---

## Convergence — Recommendation

**Proceed with Option 1 (updated plan).** The new DR-native orchestration spine **replaces** `/silver:multi-ai-task`; `/silver:deep-research-multi-ai` uses the new spine exclusively.

### Locked decisions (`decision_class: locked`)

- Opt-in `WF-SILVER-DEEP-RESEARCH-MULTI-AI`; no replacement of `WF-SILVER-DEEP-RESEARCH`
- **New multi-AI orchestration spine replaces `/silver:multi-ai-task`** — no wrap/translate/delegate to legacy multi-ai-task
- One canonical SB DR engine/state machine; workers are phase contributors only
- Default: OCG lite + Cursor default pool (6 agents); `ocg-glm-5.2` excluded; regular/lite mutex
- No silent model substitution — AskQuestion: enable / exclude / abort
- Output under `research/<YYYY-MM-DD>-<topic>/`; per-agent isolated dirs; orchestrator consolidated writes only
- Pool selection algebra: `{none,lite,regular} × {none,default}`, `--include-only` then `--exclude`, reject empty resolved set
- Implementation order: contracts → provisioning → backends (new spine) → consolidation → registration → verification

### Gray areas (Phase 1, not clarify)

1. Explicit `parallel_phases` table per `research_type` and depth mode.
2. Router/catalog slot vs `public-workflow-routes.lock.json`.
3. Default cost/concurrency caps and `partial-ok` vs `fail-fast` copy.
4. Project vs global Cursor agent scope default config key.

---

## Unresolved Questions

| # | Question | Suggested resolution |
|---|----------|---------------------|
| Q1 | Explicit user wording every run vs `preferences.json` pool defaults? | Explicit route opt-in; preferences may default pools only |
| Q2 | `solution-landscape` / `solution-compare` in v1? | Yes where validators are backend-independent |
| Q3 | Consolidated HTML vs `generate_report_spa.py`? | Reuse SPA patterns; add `consolidated/report.html` |
| Q4 | GLM-5.2 in Cursor pool but `ocg-glm-5.2` excluded? | Document asymmetric policy |
| Q5 | multi-ai-task deprecation milestone vs DR-multi-AI v1 ship? | v1 ships new spine; deprecation note in Phase 6/8 without blocking implementation |

---

## Next-Step Notes

**Primary next route:** **Phase 1 (contracts)** — `skills/silver-deep-research-multi-ai/SKILL.md`, pool schemas, CLI contract, reuse memo (**replace** multi-ai-task), `parallel_phases` table.

**Not recommended:** `/silver:context` — repo-native implementation plan.

**Optional:** `/silver:plan` — only if milestone tracking under `.planning/ROADMAP.md` is required.

**Suggested worker queue:** contracts → provisioning → backends (new spine) → consolidation → registration → verification.

**Blockers:** None for clarify.

---

## Artifacts

| Artifact | Path |
|----------|------|
| Clarify brief (this file) | [.planning/multi_ai_deep_research_b3d9881b-CLARIFY-260715-20260715T152255Z.md](.planning/multi_ai_deep_research_b3d9881b-CLARIFY-260715-20260715T152255Z.md) |
| Source implementation plan | [multi_ai_deep_research_b3d9881b.plan.md](/Users/shafqat/.cursor/plans/multi_ai_deep_research_b3d9881b.plan.md) |
| Clarify path helper | [scripts/lib/planning-clarify-path.sh](scripts/lib/planning-clarify-path.sh) |
| Parent DR contract | [research/README.md](research/README.md) |

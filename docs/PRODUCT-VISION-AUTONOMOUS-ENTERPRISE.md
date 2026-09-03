---
title: Silver Bullet Autonomous Enterprise Delivery — Product Vision
status: vision-synthesis
date: 2026-07-06
sources: silver-bullet.md, docs/ORCHESTRATOR.md, atomic-flow-redesign.plan.md, SB_CONSOLIDATED_PRIOR_ART_REPORT.md
---

# Silver Bullet Autonomous Enterprise Delivery — Product Vision

**Audience:** Technical product / architecture  
**Sources:** [`silver-bullet.md`](../silver-bullet.md), [`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md), [`docs/composable-flows-contracts.md`](composable-flows-contracts.md), [`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md), [`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md), [`skills/silver-orchestrator/SKILL.md`](../skills/silver-orchestrator/SKILL.md), [`skills/silver-feature/SKILL.md`](../skills/silver-feature/SKILL.md), [`.planning/enterprise-e2e/`](../.planning/enterprise-e2e/)  
**Status:** Vision synthesis — not an implementation spec

---

## 1. Vision Statement (Inverted Human/Agent Roles)

### North star

**Silver Bullet is the primary actor; the human is the supervisor of last resort.**

The product vision is an **inverted collaboration model**:

| Traditional AI coding | Silver Bullet vision |
|----------------------|----------------------|
| Human prompts → AI writes snippets → human reviews, integrates, ships | Human states outcome / requirements → **SB plans, implements, verifies, reviews, secures, ships, and deploys** → human approves **locked** decisions and inspects final artifacts |
| User remains orchestrator | **SB is the Agentic Process Orchestrator (APO)** — parent schedules, workers execute, hooks enforce |

This framing is explicit in public docs: the "traditional approach" keeps the user as orchestrator; the "AI-driven approach" makes the AI the executor, with SB preventing drift and skipped steps ([`site/help/getting-started/index.html`](../site/help/getting-started/index.html) §"The Difference From Traditional AI Coding Assistants").

### What "autonomous" means in SB terms

Autonomous mode is not "no rules." It is **process-autonomous with evidence-autonomous defaults**:

- SB composes and drives the full lifecycle DAG from catalog-backed workflows ([`silver-bullet.md`](../silver-bullet.md) §2h).
- The **parent orchestrator never implements** — it reads `orchestrator-directive.json`, spawns Task workers, and advances the queue until empty ([`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md); [`skills/silver-orchestrator/SKILL.md`](../skills/silver-orchestrator/SKILL.md)).
- Clarifying questions are suppressed; SB makes best-judgment calls and logs **Autonomous decisions** ([`silver-bullet.md`](../silver-bullet.md) §4).
- Genuine blockers (credentials, destructive ambiguity) queue under **Needs human review** rather than stalling the whole run ([`silver-bullet.md`](../silver-bullet.md) §4).
- The parent asks the user **only** for `decision_class: blocking` outcomes — material forks, not preferences ([`skills/silver-orchestrator/SKILL.md`](../skills/silver-orchestrator/SKILL.md); [`skills/silver-clarify/SKILL.md`](../skills/silver-clarify/SKILL.md) §Decision taxonomy).

### One-sentence vision

> **After the user supplies intent and an initial requirements spec, Silver Bullet autonomously creates and deploys enterprise-grade applications end-to-end by driving its own workflow DAG — parent orchestrator, atomic-flow workers, V-loops, and hook gates — with the user minimally assisting on locked decisions, credentials, and irreversible external actions.**

---

## 2. What Exists Today vs. What the Vision Requires

### Exists today (substantial)

| Capability | Evidence |
|------------|----------|
| **APO catalog as sole composition authority** | `docs/apo-catalog.json`; generated [`docs/composable-flows-contracts.md`](composable-flows-contracts.md) ([`silver-bullet.md`](../silver-bullet.md) §APO catalog authority) |
| **Parent-only orchestrator mode** | Default `orchestrator_mode: parent`; parent blocked from Edit/Write/Bash on source at tier ≥ 2 ([`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md)) |
| **Eight composer workflows + 27 `AF-*` atomic flows** | Feature, bugfix, UI, devops, research, release, fast, clarify ([`silver-bullet.md`](../silver-bullet.md) §2h; [`docs/composable-flows-contracts.md`](composable-flows-contracts.md)) |
| **Hook-enforced lifecycle** | Planning floor, completion audit, outcomes-check, stop hook ([`silver-bullet.md`](../silver-bullet.md) §1) |
| **Autonomous session mode** | Mode file, anti-stall, structured commentary ([`silver-bullet.md`](../silver-bullet.md) §2f, §4) |
| **Enterprise E2E validation program** | 22-row matrix, shared harness, outcome rubric with blocking autonomy gates ([`.planning/enterprise-e2e/`](../.planning/enterprise-e2e/)) |
| **Atomic-flow redesign (v0.48+)** | Catalog, V-loops, intent ledger, composition log — marked completed in [`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) |

### Vision requires (not yet proven at enterprise scale)

| Requirement | Gap vs. today |
|-------------|---------------|
| **Cold-start autonomy** — vague prompt → shipped app without operator babysitting | Early E2E rounds needed heavy operator intervention ([`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md) §1) |
| **Durable orchestration** — retries, sagas, replay across sessions | Workers are LLM calls in hooks; no Conductor/Temporal substrate ([`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) §8) |
| **Full parallel DAG scheduling** | Designed ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) §Parallel execution rules); host multitask adapters not fully realized |
| **Tri-host parity** | Claude/Codex/Cursor E2E tracks in flight; early program was Claude-centric ([`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md) §2 blind spots) |
| **Claims-grade measurement** | 22/22 ≠ world-class reliability; monitor/ledger drift observed ([`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md)) |
| **True deploy autonomy** | Tags/releases and some destructive ops still user-triggered by policy ([`AGENTS.md`](../AGENTS.md); [`silver-bullet.md`](../silver-bullet.md) §7 file safety) |
| **Default autonomous onboarding** | Session still prompts interactive vs. autonomous unless bypass-permissions ([`silver-bullet.md`](../silver-bullet.md) §4) |

---

## 3. Core Architectural Enablers Already in SB

### 3.1 APO catalog (`docs/apo-catalog.json`)

Silver Bullet self-describes as an **Agentic Process Orchestrator** with hierarchy:

**Process → Workflow → Atomic Flow → Flow Step/Skill**

- 22 `WF-*` workflows, ~27 `AF-*` atomic flows, per-flow and per-step V-loops, evidence records, intent ledgers, tool policies, dynamic rules, process packs ([`silver-bullet.md`](../silver-bullet.md) §APO; [`docs/composable-flows-contracts.md`](composable-flows-contracts.md) §APO Hierarchy).
- Legacy FLOW 1–18 are migration aliases only; canonical execution uses `AF-*` ([`docs/composable-flows-contracts.md`](composable-flows-contracts.md) §Legacy FLOW Compatibility).

### 3.2 Atomic flows as subagent work packages

**One atomic flow = exactly one subagent work package.** Workflows are dependency DAGs; independent flows may parallelize; dependents join on V-gates ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) §Goal; [`docs/research-260624/SB_PRIOR_ART_RESEARCH_PROMPT.md`](research-260624/SB_PRIOR_ART_RESEARCH_PROMPT.md) §Core differentiators).

Each `AF-*` maps to a worker template under `.silver-bullet/orchestrator-workers/` (e.g. `EXECUTE.md`, `SHIP.md`) ([`docs/composable-flows-contracts.md`](composable-flows-contracts.md) §Atomic Flow Catalog).

### 3.3 Parent orchestrator

| Role | Parent | Worker |
|------|--------|--------|
| Implements source | **Never** | Yes |
| Spawns subagents | Task + worker template | N/A |
| Invokes flow skills | **Never** (only `silver` / `silver-orchestrator`) | Must invoke assigned `next_skill` |
| Advances queue | Reads directive after SubagentStop | Records skill via host channel |

State files: `orchestrator.json`, `orchestrator-directive.json`, `orchestrator-intent.txt` ([`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md)).

**Stop semantics:** Parent cannot end session while `current_flow` is pending — must spawn next worker ([`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md) §SubagentStop).

### 3.4 Hooks as fail-closed enforcement

Hooks block **commits, PRs, deploy, release, session stop** until lifecycle evidence exists ([`silver-bullet.md`](../silver-bullet.md) §1; [`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) §8 — "blocks delivery by default").

Key guards:
- `orchestrator-directive-guard.sh` — parent implementation block
- `workflow-chain-guard.sh` — planning floor before edits
- `completion-audit` — delivery-tier blocking
- `outcomes-check.sh` — per-prompt outcome checklist with `decision_class`

### 3.5 V-loops and intent validation

Every atomic flow and flow step owns a V-loop: input → work product → verification (build it right) → validation (build the right thing) → repair → escalation → evidence ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) §APO And V-Model Principles).

Composed workflows roll up child V-gates and end with **`INTENT-GATE-DEFAULT`** — material user-intent claims checked against artifacts ([`docs/composable-flows-contracts.md`](composable-flows-contracts.md) — all workflows declare `Final intent gate: INTENT-GATE-DEFAULT`).

### 3.6 Evidence and recommended tools

Once opted in, Graphify, agentmemory, RTK, Context Mode, Alumnium become **mandatory when relevant** to the active flow; outputs are V-model evidence ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) §Opted-In Tool Governance; [`silver-bullet.md`](../silver-bullet.md) §2g-i).

Enterprise E2E rubric scores **OUT-KM-01** (Graphify + agentmemory), **OUT-VLOOP-01**, **OUT-GATES-01**, **OUT-TRACE-01** ([`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md)).

### 3.7 Dynamic composition with audit

Pre-composed workflows (e.g. `WF-SILVER-FEATURE`) are **defaults, not ceremony**. Runtime may prune/insert/substitute `AF-*` atoms when catalog rules and context justify it; deviations go to `composition_log` ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) §Design Decisions; **OUT-TAILOR-01** in rubric).

---

## 4. Minimal User Touchpoints

### Human **required** (blocking)

| Touchpoint | When | Source |
|------------|------|--------|
| **Initial intent / requirements** | Session start; seeds `orchestrator-intent.txt` | [`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md) Parent loop |
| **`decision_class: blocking`** | Material architecture/product forks unresolved by clarify | [`skills/silver-clarify/SKILL.md`](../skills/silver-clarify/SKILL.md); parent orchestrator contract |
| **Credentials / auth** | External systems (cloud, GitHub auth, API keys) | [`silver-bullet.md`](../silver-bullet.md) §4 "Genuine blockers first" |
| **Destructive / irreversible ops** | File overwrite without prior permission; force push; production deploy without policy | [`silver-bullet.md`](../silver-bullet.md) §7 File Safety |
| **Release publication** | Signed tags, GitHub releases — explicitly not autonomous by policy | [`AGENTS.md`](../AGENTS.md); phase 075 release summary |
| **Permanent step-skip in §9** | Requires explicit confirmation of exact text written | [`silver-bullet.md`](../silver-bullet.md) §2h Step-skip protocol |
| **`SB OVERRIDE:`** | Audited escape when hook/directive cannot be satisfied | [`silver-bullet.md`](../silver-bullet.md) §2h; [`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md) |

### Human **optional** (supervisory)

| Touchpoint | When |
|------------|------|
| Session mode choice | Interactive vs. autonomous at start (skipped if bypass-permissions) |
| Progress narration | Autonomous commentary streams status; user may watch ([`silver-bullet.md`](../silver-bullet.md) §2f) |
| Milestone release confirm | FLOW 18 last phase of milestone ([`skills/silver-feature/SKILL.md`](../skills/silver-feature/SKILL.md)) |
| Visual companion (Alumnium) | UI-heavy clarify topics ([`skills/silver-clarify/SKILL.md`](../skills/silver-clarify/SKILL.md)) |
| External second-opinion review | Optional; feeds SB artifacts only ([`silver-bullet.md`](../silver-bullet.md) §2h) |

### Autonomous defaults (no user prompt)

- `decision_class: autonomous_default` — log assumption, proceed ([`skills/silver-clarify/SKILL.md`](../skills/silver-clarify/SKILL.md))
- Phase gates removed in autonomous mode ([`silver-bullet.md`](../silver-bullet.md) §4)
- Anti-stall: best-judgment + log on non-blocker stalls ([`silver-bullet.md`](../silver-bullet.md) §4)
- Composition approval not requested — `flow-advance.sh` starts tracker ([`skills/silver-feature/SKILL.md`](../skills/silver-feature/SKILL.md))
- Hook friction → autonomous retry (**OUT-HEAL-01**) ([`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md))

---

## 5. End-to-End Flow: Intent → Spec → Build → Verify → Ship → Deploy

```mermaid
flowchart TB
  subgraph intake [Intake - minimal human]
    I[User intent / rough requirements]
    M[Session mode: autonomous]
    C[silver:clarify if fuzzy]
  end

  subgraph parent [Parent orchestrator]
    R[/silver router]
    Q[Seed orchestrator.json queue]
    D[orchestrator-directive.json loop]
    T[Spawn Task workers per AF-*]
  end

  subgraph pre [Pre-execution AFs]
    B[AF-BOOTSTRAP / ORIENT]
    S[AF-SPECIFY → SPEC.md]
    G1[AF-QUALITY-GATE pre-plan]
    P[AF-PLAN]
    DC[AF-DESIGN-CONTRACT if UI]
  end

  subgraph exec [Execution]
    E[AF-EXECUTE via silver:execute]
  end

  subgraph post [WF-POST-EXEC-GATES]
    UQ[AF-UI-QUALITY]
    RV[AF-REVIEW triad]
    VF[AF-VERIFY]
    SC[AF-SECURE]
    G2[AF-QUALITY-GATE pre-ship]
    BF[AF-BRANCH-FINISH]
    CA[AF-COMPLETION-AUDIT]
    SH[AF-SHIP]
  end

  subgraph deploy [Deploy / release]
    DP[silver:deploy / canary]
    RL[AF-RELEASE + create-release]
  end

  I --> M --> C --> R --> Q --> D --> T
  T --> B --> S --> G1 --> P --> DC --> E
  E --> UQ --> RV --> VF --> SC --> G2 --> BF --> CA --> SH
  SH --> DP --> RL
```

### Stage detail (feature path — `WF-SILVER-FEATURE`)

| Stage | Atomic flows / skills | Human involvement |
|-------|----------------------|-------------------|
| **Intent capture** | `AF-ROUTE`, optional `AF-CLARIFY` | User message; clarify only if blocking |
| **Orient** | `AF-ORIENT` (graphify query mandatory when opted in) | None |
| **Specify** | `AF-SPECIFY` → `.planning/SPEC.md` | Skip if SPEC exists |
| **Plan** | `AF-QUALITY-GATE` (pre-plan) → `AF-PLAN` | None in autonomous |
| **Design** | `AF-DESIGN-CONTRACT` if UI scope | None |
| **Build** | `AF-EXECUTE` (internal TDD gate + `silver:execute`) | None |
| **Verify** | Review triad → `AF-VERIFY` → `AF-SECURE` | None |
| **Gate** | `AF-QUALITY-GATE` (pre-ship) | Non-skippable |
| **Ship** | `AF-BRANCH-FINISH` → `AF-COMPLETION-AUDIT` → `AF-SHIP` (PR, CI green) | Hooks enforce evidence |
| **Deploy** | `silver:deploy`, `silver:canary` via `AF-SHIP` skills; devops path via `silver:devops` | Production credentials / approval per policy |
| **Release** | `AF-RELEASE` → `silver:create-release` | User-triggered for external publish |

Standard composition chain is declared in [`skills/silver-feature/SKILL.md`](../skills/silver-feature/SKILL.md); catalog tree in [`docs/composable-flows-contracts.md`](composable-flows-contracts.md) §`WF-SILVER-FEATURE` + `WF-POST-EXEC-GATES`.

### DevOps parallel path

`silver:devops` composes blast-radius → devops-skill-router → plan → execute → post-exec gates ([`silver-bullet.md`](../silver-bullet.md) §2h). Same parent/worker and hook model; **7 IaC-adapted quality dimensions** instead of product 8 ([`silver-bullet.md`](../silver-bullet.md) §2h).

---

## 6. Enterprise App Specifics

### 6.1 Enterprise E2E matrix (22 rows)

The **enterprise-grade-test-app** fixture exercises all catalog workflows via a shared harness ([`.planning/enterprise-e2e/SHARED-HARNESS.md`](../.planning/enterprise-e2e/SHARED-HARNESS.md)):

| Row class | Count | Examples |
|-----------|-------|----------|
| Routing | 1 | Row 1 — `/silver` router only |
| Standalone workflows | 19 | feature, bugfix, UI, release, forensics, incident, … |
| Internal (parent-triggered) | 2 | Rows 21–22 (post-exec-gates, validate-substep inside rows 3–4) |

Per-row applicability: [`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) §Per-workflow applicability matrix.

**Strict-clean round** (release bar) requires ([`.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md`](../.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md)):

1. Review-fix-ladder 8/8 with 2 consecutive clean verify passes  
2. Live matrix 22/22 with outcome PASS (no `partial`)  
3. Blocking autonomy gates: **OUT-AUTO-01**, **OUT-CLARIFY-01**, **OUT-NOOP-01**, **OUT-WORLD-01**  
4. Phase C green (tests, ledger reconcile, RCS ≥ 85)  
5. **2 consecutive** strict-clean rounds per host track  

### 6.2 Supervised vs. autonomous modes

| Mode | Operator role | SB behavior | E2E expectation |
|------|---------------|-------------|-----------------|
| **Supervised (interactive)** | Approves phase gates; answers clarifications | Pauses at decision points ([`silver-bullet.md`](../silver-bullet.md) §4) | Legacy matrix runs; **not** the autonomy vision target |
| **Autonomous** | Watches commentary; intervenes only on blockers | Drives queue; parent spawns workers; no babysitting ([`silver-bullet.md`](../silver-bullet.md) §2f, §4) | **OUT-AUTO-01** blocking PASS required |
| **Supervised delegation** | Parent supervises **external** host TUI (`silver:agent-cursor`, etc.) | Single-task subagent — **not** enterprise matrix ([`agents/claude/silver:agent-cursor/SKILL.md`](../agents/claude/silver:agent-cursor/SKILL.md)) | Distinct from full SB autonomy |
| **Enterprise E2E operator** | Historically babysat TUI sessions | Policy: "never pause for operator on blockers — diagnose, fix SB, re-run" ([`.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md`](../.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md) §C) | Converging operator role toward **harness maintainer**, not **workflow driver** |

**Assist-only = FAIL** for autonomy scoring: SB must drive completion from vague prompts; `silver:clarify` when needed instead of wrong-route execution ([`.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md`](../.planning/enterprise-e2e/CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md) §Outcome assessment).

### 6.3 Tri-host certification

Parallel tracks: Claude, Codex, Cursor — each must achieve 2 consecutive strict-clean rounds on `enterprise-e2e/{claude,codex,cursor}` branches ([`.planning/enterprise-e2e/HOST-CONFIG.md`](../.planning/enterprise-e2e/HOST-CONFIG.md); execution prompts in same directory).

Matrix rows run in **autonomous Agent mode** — no Plan/Debug mid-row ([`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md) §Host modes).

---

## 7. Gaps and Blockers to Full Autonomy

### 7.1 From prior art (honest external assessment)

[`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) §8 identifies three structural lacks:

1. **Durable execution substrate** — no Temporal/Conductor-grade retries, sagas, replay  
2. **Production adoption signal** — defined + documented vs. BMAD/Superpowers community scale  
3. **IDE-native integration** — skills/hooks vs. marketplace-native discoverability  

SB's moat (catalog + V-loop rollups + hook blocking + SE+DevOps unity) is **architecturally differentiated** but **operationally immature** relative to execution engines and IDE hosts.

### 7.2 From enterprise E2E program (internal honesty)

[`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md):

| Proven today | Not proven |
|--------------|------------|
| Harness wiring, hook unit tests (~4700) | Cold install without operator |
| 22 routes can complete **once** with babysitting | Evidence **quality** (parent inline code, fake gates) |
| Structural CI suite | Homepage marketing claims (cost, Veracode stats) |
| | Monitor vs. ledger truth (Round 3 drift — P0 measurement defect) |
| | Codex/Cursor parity at same enforcement tier (in progress) |
| | Statistical flake budget / consecutive-round rigor |

### 7.3 Architectural/runtime gaps

| Gap | Impact on vision |
|-----|------------------|
| **Parallel scheduler + mutation-scope conflict detection** | Designed in atomic-flow plan Phase 8; not fully deployed ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) §Phase 8) |
| **Step V-loop runtime rollup enforcement** | Catalog exists; join gates may not yet block on all step rollups in practice |
| **Tier 0–1 hosts** | No Task/subagent — single-session inline execution ([`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md) §Tier 0–1) |
| **TUI vs. `--print` skill invocation** | Interactive path not fully validated ([`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md)) |
| **Environmental fragility** | 429, provider restarts, ANSI expect bugs consume rounds |
| **File safety + release policy** | By design limits unattended deploy-to-prod |
| **Default interactive prompt** | Friction for "zero-touch after spec" onboarding |

### 7.4 Competitive threats to the vision

From [`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) §8: Superpowers adding V-loops + evidence tiers; GitHub Spec Kit mindshare; gh-aw as enforcement peer; BMAD custom agents dissolving process-pack moat.

---

## 8. Phased Path to the Vision

### Phase A — **Prove autonomy on fixture** (in flight)

**Goal:** 2 consecutive strict-clean rounds per host without operator babysitting.

- Complete tri-host E2E tracks ([`.planning/enterprise-e2e/`](../.planning/enterprise-e2e/))
- Enforce blocking outcomes: OUT-AUTO-01, OUT-CLARIFY-01, OUT-NOOP-01, OUT-WORLD-01
- Fix measurement: ledger reconcile, eliminate monitor/ledger drift ([`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md))
- Claims registry → test mapping for homepage mechanisms ([`docs/testing/claims-registry.json`](testing/claims-registry.json))

**Exit criteria:** Cursor + Codex + Claude each strict-clean × 2; OUT-AUTO-01 pass on all 22 rows; parent never implements inline (**OUT-ORCH-01**).

### Phase B — **Harden runtime orchestration**

**Goal:** Catalog semantics fully drive runtime, not prose.

Aligned with [`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) Phase 8:

- DAG scheduler with recorded subagent IDs, join gates, composition_log
- `test-parallel-scheduling-safety.sh`, `test-step-vloop-runtime-rollup.sh`, `test-dynamic-composition-audit.sh`
- WBS meta-supervision to completion (**OUT-SUPER-01**) — parent cannot exit with pending `current_flow`

**Exit criteria:** Independent `AF-*` parallelize on Cursor Multitask / host equivalents; V-gate failures trigger repair flows without human.

### Phase C — **Default autonomous enterprise onboarding**

**Goal:** Inverted model is the default UX.

- Auto-autonomous when safe (extend bypass-permissions pattern; enterprise policy profiles)
- `silver:clarify --auto` as default front door for vague intent
- Session 0 fully automated (`/silver:init` TUI path validated)
- Process packs for team gate overlays without forking `AF-*` ([`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) Phase 6)

**Exit criteria:** New project: user provides brief → SPEC → multi-phase feature → PR without interactive prompts except `decision_class: blocking`.

### Phase D — **Durable execution + deploy substrate**

**Goal:** Survive session death, quota, and multi-day enterprise builds.

- Integrate durable queue (Conductor/Temporal patterns per prior art recommendation)
- Idempotent ship/deploy workers; sagas for rollback
- Narrow human-only surface to credentials + explicit production promotion
- DevOps path on real IaC fixtures (beyond single Node stub)

**Exit criteria:** Resume after crash continues from `orchestrator.json` + durable event log; deploy row passes without manual ledger patching (**OUT-RELEASE-01**).

### Phase E — **Production enterprise product**

**Goal:** SB as autonomous delivery agent for real customer repos.

- Statistical SLOs (flake budget, consecutive-round definition)
- SOC2/evidence export from `evidence_records` + instruction ledger
- IDE marketplace parity; process-pack marketplace
- Defend moat: unified SE+DevOps catalog, tiered evidence, delivery blocking ([`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) §8 opportunities)

**Exit criteria:** Customer pilot: intent → production deploy with audited composition_log, intent gate PASS, and human touchpoints only on blockers + compliance gates.

---

## Summary Positioning

Silver Bullet's product vision is **not** "another coding assistant." It is an **Agentic Process Orchestrator** that inverts the default human/agent relationship: **SB drives the full SDLC+DevOps DAG; the user supplies intent and locked decisions.**

The **architecture for that vision largely exists** — APO catalog, parent/worker split, atomic flows as Task workers, V-loops, hook-enforced gates, dynamic composition, and an enterprise E2E rubric that encodes autonomy as blocking criteria.

The **gap is operational proof**: durable execution, tri-host strict-clean certification, honest measurement, and policy boundaries on irreversible actions. The phased path moves from **fixture-autonomous** → **runtime-hardened** → **default-autonomous onboarding** → **durable deploy** → **enterprise production**.

---

### Key file index

| Topic | Path |
|-------|------|
| Canonical instructions | [`silver-bullet.md`](../silver-bullet.md) |
| Orchestrator contract | [`docs/ORCHESTRATOR.md`](ORCHESTRATOR.md) |
| Flow contracts (generated) | [`docs/composable-flows-contracts.md`](composable-flows-contracts.md) |
| APO redesign plan | [`docs/research-260624/atomic-flow-redesign.plan.md`](research-260624/atomic-flow-redesign.plan.md) |
| Market positioning | [`docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`](research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) §8 |
| Parent skill | [`skills/silver-orchestrator/SKILL.md`](../skills/silver-orchestrator/SKILL.md) |
| Feature queue builder | [`skills/silver-feature/SKILL.md`](../skills/silver-feature/SKILL.md) |
| Enterprise E2E ops | [`.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md`](../.planning/enterprise-e2e/OPERATIONAL-ADDENDUM.md) |
| Autonomy rubric | [`.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md`](../.planning/enterprise-e2e/OUTCOME-ASSESSMENT-RUBRIC.md) |
| E2E honesty assessment | [`docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md`](testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md) |
| Public inverted-model framing | [`site/help/getting-started/index.html`](../site/help/getting-started/index.html) |

# Silver Bullet — Product / Architecture / Inner-Workings Overview

**Audience:** Adversarial architecture reviewers of plan `router_subagent_surfaces_85bf9f09`  
**Purpose:** Product and runtime mental model — **not** a rules dump. Absorb this before reading the plan.  
**Sources synthesized:** `docs/PRD-Overview.md`, `docs/ARCHITECTURE.md`, `docs/ORCHESTRATOR.md`, `AGENTS.md`, `docs/apo-catalog.json`, `silver-bullet.md` (workflow/orchestrator product lens only).  
**Ladder hygiene (2026-08-14):** §§1–4 are **current-product `/silver` context** (today’s router, workflow names, and install hosts). They are **not** the architecture under review. Judge MVP scope from the plan + clarify: Cursor **host adapter** on MVP; Codex/Claude/OpenCode host adapters **after MVP**; `sb:agent-*` rename in the MVP ship; ILM-01 bootstrap migrate on MVP; MIG-01 reverse-bridge / PROD-01 freeze/drain / OFF-01 **after MVP**. §5 already matches the spec for quality loops.

---

## 1. What Silver Bullet is

Silver Bullet (SB) is a **host coding-agent plugin** for AI-native software engineering and DevOps. Its product promise is:

> Close the gap between “what the agent should do” and “what it actually does” via a single SB-owned lifecycle with layered, hard-to-bypass enforcement.

It is **process authority**, not a business-logic framework:

- Owns routing, composition, quality/release gates, skill tracking, completion claims, and migration of orchestration state.
- Does **not** implement project-specific app logic.
- Does **not** modify third-party plugin files; optional extensions are called only at explicit SB boundaries.

**Core value:** one enforced workflow with many cooperating enforcement layers (hooks, artifacts, dependency gates, completion audit, CI, docs, live matrix, release) so there is no single bypass when context resets.

---

## 2. Product surfaces users see

| Surface | Role |
|---------|------|
| **`/silver` (Process router)** | Sole public Process entry — resolves intent to a Workflow |
| **`silver:<route>` Workflows** | User-facing delivery paths (feature, bugfix, UI, devops, research, release, fast, …) |
| **Atomic Flows (`AF-*`)** | Composable units inside Workflows (orient, clarify, plan, execute, verify, ship, …) |
| **Steps / Skills** | Concrete work units; ~85 skills under `skills/`; ~36 also exposed as command stubs |
| **Help / site catalog** | Public explanation of Process → Workflow → AF ordering (SDLC presentation order) |

**Current-product hosts** (today’s `/silver` plugin install): Cursor, Codex, Claude Code. **Architecture under review (ratified Q5):** MVP = Cursor **host adapter** (Orchestrator as parent inside Cursor) plus `sb:agent-*` rename in the MVP ship. Codex, Claude Code, and OpenCode **host adapters** (Orchestrator as parent inside those hosts) sequence **after MVP**. Do not treat this section as requiring three parent-host adapters on day-1 of the plan. Installers materialize host-specific wiring; the **core contract is host-generic**.

---

## 3. Hierarchy (APO mental model)

```text
Process  (PROC-SB-SE-DEVOPS — SE/DevOps process)
  └── Workflow  (WF-SILVER-FEATURE, WF-SILVER-BUGFIX, … ~26 in catalog)
        └── Atomic Flow  (AF-ORIENT, AF-EXECUTE, AF-VERIFY, … ~29)
              └── Flow Step
                    └── Skill / tool invocation
```

**Process packs** (e.g. default vs regulated) may reorder/gate Workflows without forking AF definitions. Catalog truth lives in [`docs/apo-catalog.json`](../../docs/apo-catalog.json); contracts expand in `docs/composable-flows-contracts.md`.

**Eight primary user Workflows** (product table from SB instructions, product lens):

| Workflow | Intent class |
|----------|----------------|
| `silver:clarify` | Ideas / rough briefs → framed requirements |
| `silver:feature` | Build / enhance product behavior |
| `silver:bugfix` | Defect → fix → verify |
| `silver:ui` | Frontend / design-contract heavy work |
| `silver:devops` | Infra / CI / IaC (adapted quality dimensions) |
| `silver:deep-research` | Tech choice / spike / compare |
| `silver:release` | Milestone publish (≠ phase ship) |
| `silver:fast` | Trivial bounded changes |

Workflows compose **FLOW 1–18** atoms (bootstrap → orient → clarify → … → execute → review → verify → secure → quality gate → ship → debug/document/release). Flow numbers are stable IDs; runtime order is composition + orchestrator queue, not the number sequence alone.

**Ship vs release:** `silver:ship` ≈ phase-level merge/PR; `silver:release` ≈ milestone publish. Different altitudes.

---

## 4. Inner workings — how a run actually proceeds

### 4.1 Orchestrator (parent ≠ implementer)

SB’s orchestrator is **parent-only**:

| Role | May implement? | Job |
|------|----------------|-----|
| **Parent** | **No** | Read directive; spawn Task workers; advance queue |
| **Worker** | **Yes** (after invoking assigned skill) | Execute one atomic flow / template |

Loop (product shape):

```text
User intent → /silver or silver-orchestrator
  → seed orchestrator.json + flow queue
  → directive: next_skill + next_worker_template
  → parent spawns Task with orchestrator-workers/<TEMPLATE>.md
  → worker invokes skill → does the work
  → SubagentStop / join
  → flow-advance → next directive
  → until queue empty
```

State lives under runtime state dir (`orchestrator.json`, `orchestrator-directive.json`, event log). Hooks enforce parent non-implementation and worker skill recording at sufficient capability tiers.

**Why this matters for the plan under review:** the plan extends this world with Authorizer-fenced launches, prompt+work-spec admission, nested Process-authorized Workflows, and quality-loop state machines — it must remain executable on top of parent/worker + hooks, not invent a parallel control plane that hosts cannot spawn.

### 4.2 Enforcement machinery

| Component | Path | Responsibility |
|-----------|------|----------------|
| Hooks | `hooks/*.sh` | Pre/Post tool enforcement; re-fire every tool call (survives context reset) |
| Skills | `skills/*/SKILL.md` | Declarative workflow instructions |
| Templates | `templates/` | Init + worker templates; `silver-bullet.md.base` |
| Scripts | `scripts/` | Install, migrate, sync, doctor, generators |
| Contracts / locks | `contracts/`, APO JSON | Machine-checkable route/hierarchy truth |
| Config | `.silver-bullet.json` | Project opt-ins, enterprise policy, tool prefs |
| Planning artifacts | `.planning/` | Specs, plans, clarify briefs, run ledgers |

**Design principles (architecture):** additive enforcement; many layers; user project instructions can override defaults; packaging boundaries keep plugin cache / generated mirrors separate from editable source.

**Derived surfaces:** edit `skills/` / `templates/` then sync (`sync-codex-package.sh`, `sync-templates.sh`, `generate-plugin-commands.sh`). Never edit installed plugin cache.

### 4.3 Hosts

| Host | Product role |
|------|----------------|
| **Cursor** | Task/subagent workers; rules + hooks; orchestrator parent mode |
| **Codex** | Bundle under `plugins/silver-bullet/`; invoke-skill adapter |
| **Claude Code** | `.claude-plugin/` surface; Skill tool + hooks |

Capability tiers differ (Task/subagent required for full parent blocks). This table is **current-product** install surfaces, not the architecture MVP host-adapter slice. Plan review: the Cursor host adapter must enforce Authorizer + prompt/work-spec + callbacks on MVP; Codex/Claude/OpenCode parent-host adapters are post-MVP (renamed `sb:agent-*` delegates are not those adapters).

---

## 5. Quality behavior as product (not ceremony)

SB already has review/verify culture (review triad, verify, quality gates, completion audit). The architecture plan under review **names and hardens** ordinary delivery quality loops. Historical P-loop (`poa_draft` / executor drafts) and Val-at-every-scope are superseded; this section matches the spec.

| Loop | Product meaning | Who |
|------|-----------------|-----|
| **Advisor-first plan** | Before ordinary I: Orchestrator hands the work spec to Advisor; Advisor produces the plan of action (one-way; Executor never plans) | Advisor |
| **I-loop** | Executor implements. I-clean is judged by Advisor A-loop (two consecutive A-clean rounds). Executor does not self-attest. Process-synthesis I is packet-local composition/findings only | Executor |
| **A-loop** | Mentor/Advisor mentorship until two consecutive A-clean; no open Advisor findings before V. Includes Process-scope A after the top Workflow join | Advisor |
| **V-loop** | Independent contract/completeness verification (never fixes). AF and Workflow stop at V. Process-scope V two-clean after the top Workflow join is mandatory before Process-final Val | Verifier |
| **Process-synthesis** | After the **top** Workflow join only: packet-local composition and findings (projector-only). Inner nested Workflow joins are not Process-scope | Executor (Process-synthesis) |
| **Validation-loop** | Fit-for-purpose judgment vs original user intent, **Process-final only**, once at roll-up. Fail receipt; Orchestrator+Advisor map onto WBS. Not run at AF or Workflow | Validator |

Canonical ordinary order (architecture spec):

```text
Knowledge/Learnings pre-read
  → Advisor planning → one-way plan handoff
  → I-loop (implementation; no self-attest)
  → A-loop (I-clean)
  → V-loop                    ← AF and Workflow stop here
  → (merge code if extra host_native worktree)
  → top Workflow join
  → Process-synthesis I       ← 9a; inner nested Workflow joins do not run this
  → Process-scope A two-clean ← 9b
  → Process-scope V two-clean ← 9c
  → Process-final Validation-loop
  → Knowledge/Learnings post-write (or explicit no-insights receipt)
  → return to parent
```

**Control-plane leaves** (advisor / verifier / validator / defect_escalation) must not recursively run the full I/A/V/Val stack on themselves — otherwise the product deadlocks. They execute role work, return a signed role receipt, and terminate.

**Iterate Ladder** is a separate, activated fitness ladder (explicit user or critical policy) — not required for ordinary delivery, and post-MVP. Until Iterate exists, public `sb:review-fix-ladder` remains as a Verifier+Process-final-Val path or thin alias.

**Knowledge / Learnings:** project insights → `docs/knowledge/`; portable → `docs/learnings/` via the monthly K/L mechanism (git source of truth). agentmemory is the **capture buffer** (`memory_save`), not a second git knowledge tree. `knowledge_postwrite` (Jobs) and FAST thin-capture are the **same leaf, ordered effects:** `memory_save` **first** (same durable text that would have been the K/L entry), then classify, then promote (or no-insight). `kl_write` cites `am_id` (or AM content hash). When AM is opted in, AM save failure / missing `am_captured` is `blocked_knowledge_postwrite` (do not write K/L anyway; FAST-scoped when it is thin-capture — does not invent a Job). When AM is not opted in, receipt is `kl_write_am_skipped`. Do not dual-write; `synergy_max` AM auto-commit is not the K/L path. Team fan-in: local AM then promote durable into git K/L. Team fan-out: `git pull` + Graphify index of those dirs — **do not** reload K/L into each clone's agentmemory (optional thin pointer only). Graphify-first when opted in searches **all** months; INDEX + current-month files are a **context-load cap** when five-tool is not opted in (older months are not discarded). **Job** pre-read before work (step 1 is Job-scoped); post-verify write (or no-insights receipt) before parent return. FAST Q&A is not a Job, skips the quality order, **does not run Job step-1 K/L pre-read**, and still runs thin capture after the FAST leaf. Classified-trivial **reuses** locked IDs `sb:fast` / `WF-SILVER-FAST` / `AF-FAST-PATH`; live composition is **`AF-FAST-PATH` only** (catalog extra AFs `AF-PLAN` / `AF-VALIDATE` / `AF-VERIFY` / `AF-QUALITY-GATE` / `AF-EXECUTE` must not run). Exemption is generators + `check-apo-invariants.py` — do **not** JSON-edit `AF-FAST-PATH`/`WF-SILVER-FAST`; the **only** FAST catalog JSON edit is `PP-SB-STARTUP-FAST.override_rules[0]` → `WF-SILVER-FEATURE`. FAST operator surfaces include the thin-capture deny-all node (no pre-read node). FAST leaf hang/die/wrong-answer → one Authorizer-admitted re-dispatch; second failure → `blocked_fast_leaf` (FAST-scoped; not ESC-02; stops FAST `scope_complete` / user return, not GST). `/sb:agent-*` is catalog dispatch of already-existing Workflow `sb:agent-wrap` owning AF `AF-agent-delegate` (`nested_executor`; WS1 adds those APO records with required `v_loop` `VL-AF-agent-delegate`). **Retracted:** agent-* may not invent a new WF. Every `/sb:agent-*` (Cursor, Codex, Claude, OpenCode, Pi) is an **Executor** that **may invent a new Workflow in-plan** (cited `plan_node_id` / WBS id); out-of-plan → `blocked_executor_wf_out_of_plan` → Advisor. Catalog wrap is the dispatch envelope, not a ban on nested invent inside it. **`/sb` / Orchestrator do not mint or invent Workflows** — they produce **work-spec + Advisor invoke** (plus FAST classify + catalog dispatch). Advisor is the only composer of new WF records and Work Plans. **Nested / opportunistic in-plan Workflow mint or invoke does not return to Orchestrator or `/sb`**. Orchestrator inventing a WF is `blocked_orchestrator_wf_mint`. WBS must show Advisor-planned NWs and Executor-inserted in-plan NWs. FAST classify + catalog dispatch of `AF-FAST-PATH` is **not** an Orchestrator WF-mint exception. **HINST-01 (`VAL/TST-RFL-624`):** Init/Doctor ensures SB on present Cursor/Codex/Claude (`scripts/install-{cursor,codex,claude}.sh`); OpenCode/Pi are instruction-only (point at parent-or-Cursor→Codex→Claude install dir + `$primary_checkout/silver-bullet.md`; parent-proxy for rails; `blocked_sb_host_missing` if no reference dir). Host nesting (Init/Doctor `VAL/TST-RFL-623`, same pass): Cursor official max **2 Task hops** below main (no writable knob; `remaining_depth` only); Codex **no documented nesting-depth number** (may enable `agents.enabled`; do not write `max_depth`); Claude **3 subagent layers** via `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (write `3` if unset/below). Extra worktrees omit `.sb/` (ledger-omit, same as `.planning/` / `graphify-out/` / `.agentmemory/` / project `.silver-bullet/`). Global Status (GST-01) is a team dashboard, not a delivery gate: protected `main` / no push rights / missing git identity stamps `gst_stale` on the local WBS and the **Job continues** (row 34 and row 35 dashboard-only; `VAL/TST-RFL-621` owns both fixtures). UTC rollover: Active rows carry forward; Completed/Blocked stay on the day they terminated; tombstone consulted across current **and previous** day file. GST helper write order: commit/push on git main-worktree if that is operator primary; else fetch+commit on `origin/main` without a second worktree that materializes ledger-omit dirs. `[skip ci]` / `paths-ignore` scoped to **push** heartbeats on `main` (do not suppress `pull_request` checks). Published dashboard MUST NOT write raw `user.email` (display `user.name` or a short hash of email). WBS remains the live execution ledger.

---

## 6. Authorizer, launch, and migration (plan-critical product pieces)

These are the inner-workings concepts the plan expands; review them for executability:

- **Authorizer:** owns project trust/signing outside VCS (`~/.silver-bullet/authorizer-trust/...`), capability tokens, fences, CAS, launch intents — children do not sign authority.
- **Launch admission:** every host subagent spawn needs **prompt-engineered launch prompt + work spec** (goal, outputs, acceptance, scope, context refs); fail-closed.
- **Callbacks / effects / producers:** at-least-once delivery with exactly-once logical identity; outboxes, watermarks, crash recovery.
- **Migration:** current-product name `silver:migrate`. Architecture: bootstrap `bash scripts/sb-migrate-from-silver.sh` (ILM-01) is MVP and must run when `/silver` is already gone; six ordered ingress states plus reverse-bridge rollback (MIG-01) and freeze/drain (PROD-01) sequence **after MVP** — no authority resurrection.

---

## 7. Spec & delivery lifecycle (product spine)

Typical spine (simplified):

1. **Clarify / research / specify** → `.planning/SPEC.md` (+ requirements)
2. **Plan / design contract** → PLAN / DESIGN artifacts; validate gaps
3. **Execute** (TDD gate when behavior-changing)
4. **Review triad → verify → secure → quality gate → ship**
5. **Release** when milestone-ready (UAT / cross-artifact / cleanup)

Progress UX is expected to show **WBS context** (`Process > Workflow > AF > Step`) so humans see where the agent is — the plan under review makes ASCII WBS mandatory on step transitions / status surfaces.

---

## 8. What “good” means when reviewing the architecture plan

Judge the plan against this product machine:

1. **Fit:** Does it strengthen Process → Workflow → AF → Step → Skill without inventing a second public Process router?
2. **Host realism:** Can the **Cursor** MVP host adapter enforce Authorizer + prompt/work-spec + callbacks without host APIs that don’t exist? Codex/Claude/OpenCode parent-host adapters are post-MVP; do not reopen Q5.
3. **Orchestrator realism:** Parent still never implements; workers remain fenced; deny-all leaves don’t recurse quality loops.
4. **Quality product:** P→I→A→V→Val (+ K/L) is unambiguous at AF/Workflow/Process; leaf Step vs AF handoff is clear.
5. **Migration product:** Legacy users can cut over via bootstrap `sb-migrate-from-silver.sh` (ILM-01, MVP) without losing evidence or resurrecting authority. Freeze/drain (PROD-01) and reverse-bridge rollback (MIG-01) are post-MVP; current-product `silver:migrate` naming in §§1–4 is not the architecture sequence.
6. **Traceability / Doctor:** Implementers and Doctor can prove obligations without orphan IDs or ceremony that SB already retired.

**Out of scope for this briefing:** line-by-line enforcement rules from `silver-bullet.md` §0–§11. Use this overview for product/architecture context; use the plan + clarify brief for the proposed contract.

---

## 9. Read order for reviewers (mandatory)

1. **This file** — `SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md`
2. **Plan** — `.planning/router_subagent_surfaces_85bf9f09.plan.md`
3. **Clarify brief** — `.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`
4. Then adversarial review for contradictions, gaps vs locked decisions, state-machine holes, traceability orphans, executability, and fit with §§1–8 above.

Ignore obsolete RFL ceremony (`verify_1`/`verify_2`, charter-signal grep, orchestrator grep, PM filing).


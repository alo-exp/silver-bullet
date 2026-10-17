# Silver Bullet — Prior-Art & Adjacent-Landscape Research (glm-5.2 run)

**Author model:** opencode-go/glm-5.2
**Date run:** 2026-06-27
**Method:** primary-source web fetches via context-mode (`ctx_fetch_and_index`) → indexed knowledge base → `ctx_search` evidence extraction, plus a prior in-session research pass (2026-06-26) whose captures are reused. arXiv open search and GitHub REST `gh search` were attempted; `gh search repos` was rate-limited (HTTP 403) for some queries — negative results noted. Where a candidate's canonical source could not be fetched (BMAD, GSD, Devin), reasoning rests on training data and is flagged `confidence: low`, `last_verified: training-cutoff`.

---

## 1. Executive summary

The landscape splits into four distinct strata:

1. **Agentic SDLC "frameworks"** — a 2026 Cambrian explosion of Claude-Code / Antigravity / Codex skill packs (Antigravity Ultimate SDLC, Haren, Loki Mode/Autonomi, earp-kit, PhaseOps, AutoForge, Myrmion, Superpowers). Most are **catalog-shaped** (named workflows, skills, quality gates) and **prompt/markdown-driven**, with **no runtime enforcement** beyond the host IDE's skill-loading and human-in-the-loop. **Antigravity Ultimate SDLC** is the closest catalog analog to SB: 166 workflows / 236 skills / 13 blocking quality gates / 5 cycle types, with a three-layer workflows→agents→skills architecture — but it is Antigravity-IDE-specific, has **no machine-readable contract catalog** (numbers live in README prose, not a versioned JSON schema), **no V-model left/right arm rollup**, **no orchestrator/worker process split**, and **no hook-enforced delivery blockers**.

2. **Host-vendor agentic-workflow products** — **GitHub Agentic Workflows (gh-aw)** is the only first-party platform that combines compiled YAML workflows, **compile-time validation, sandboxed execution, network isolation (Agent Workflow Firewall), MCP gateway tool allow-listing, and human approval gates**. It is the strongest *enforcement + guardrail* peer to SB, but it is a **generic agentic-workflow runner**, not an SDLC/DevOps **process catalog**: no named workflow set, no atomic-flow uniqueness invariant, no per-step V-loop, no intent-validation gate.

3. **Multi-agent orchestration frameworks** (LangGraph, CrewAI, AutoGen/AG2, Microsoft Agent Framework, LlamaIndex, Haystack) — powerful **dynamic graphs / crews / flows** with human-in-the-loop interrupts, parallel fans, and replanning, but **ship no SDLC or DevOps workflow catalog at all**; composition is left to the user.

4. **Process/workflow engines** (Temporal, Camunda, Conductor, Argo, Airflow) — battle-tested durable BPMN/activity DAGs with retries, compensations, sub-workflows, and policy gates, but **agent-unaware**: they execute steps, not V-gated verified work products.

**Biggest market gaps SB targets:** (a) a **single machine-readable catalog** unifying SE + DevOps with stable IDs and a no-redundancy invariant; (b) **per-step V-loop rollups with a final user-intent validation gate** tying material prompt claims to evidence; (c) **hook-enforced lifecycle blockers** on substantive delivery actions (commit/PR/deploy/session-stop); (d) **catalog-backed, audited dynamic composition** (prune/insert/substitute with rationale log). No single product or paper found combines all four.

---

## 2. Top 5 (and selected extras) — summary table

Rows below. `confidence` reflects certainty of the *classification*, not of existence. `last_verified` = ISO date the primary source was fetched (2026-06-27 unless noted). Duplicate-flagged: AutoGen↔AG2 (canonical = AutoGen). Divergence-flagged entries in §3.

| # | name | url | category | composition_model | v_loop_support | enforcement_mechanism | se_fit | devops_fit | parent_worker_split | evidence_model | dynamic_composition | maturity | gaps_vs_sb | sb_gaps_vs_them | confidence | last_verified |
|---|------|-----|----------|-------------------|---------------|-----------------------|--------|-----------|---------------------|----------------|--------------------|---------|-----------|-----------------|-----------|----------------|
| 1 | Antigravity Ultimate SDLC Framework | github.com/UnpaidAttention/antigravity-ultimate-sdlc-framework | adjacent | Three-layer workflows→agents→skills; ~166 workflows as `/` commands, `skills_required` frontmatter (max 7), intent-matched skill loading; 5 cycle types, 4 councils. Counts in README prose, not a machine-readable catalog schema. | end-only | ide-hook | strong | partial | no | informal | no | beta (2026-03, 1 commit, ~3 stars) | no machine-readable catalog; no orchestrator/worker process split; no audited dynamic composition; enforcement is IDE skill-loading only; single IDE (Antigravity). | richer UI/UX verification layers (4-layer interaction depth, anti-slop); per-project-type wave presets; more workflows/skills out of the box. | high | 2026-06-27 |
| 2 | GitHub Agentic Workflows (gh-aw) | github.com/github/gh-aw | adjacent | Compiled YAML agentic workflows run on GitHub-hosted runners; safe-outputs sanitization; sub-workflows via `gh-aw-actions`; MCP gateway routes tool calls. | none | ci-gate | partial | none | partial | informal | no | beta (2026) | no SDLC/DevOps catalog; no per-step V-loop; no intent gate; workflows are user-authored, not a stable catalog. | Strongest security/guardrail stack: sandboxed exec, network-isolation firewall, compile-time validation, SHA-pinned deps, human approval gates; production-grade runner; vendor-backed. | high | 2026-06-27 |
| 3 | Superpowers | github.com/obra/superpowers | adjacent | Skill-system "Basic Workflow" (brainstorm→worktree→plan→subagent-driven-dev→TDD→review→finish); skills are mandatory, not suggestions; dispatching-parallel-agents + git worktrees. | end-only | prompt-only | strong | none | partial | none | no | beta (2026) | no catalog schema; no V-loop rollup; no hook blockers on delivery; no DevOps; no audit log. | Mature subagent-driven-development + two-stage review (spec compliance then code quality) methodology; clean per-skill contracts; strong TDD discipline. | high | 2026-06-27 |
| 4 | GitHub Spec Kit | github.com/github/spec-kit | adjacent | Spec-driven dev (`constitution→spec→plan→tasks→/speckit.implement`); `tasks.md` with dependency + parallel markers; TDD task plan; presets/bundles/extensions for orgs. | end-only | prompt-only | strong | none | partial | informal | no | beta (2026) | no global atomic-flow catalog; no per-step V-loop; no delivery blockers; no DevOps. | Strong spec→plan→tasks contraction with explicit parallel markers managed by the implement command; bundles/presets/extension extension model for org compliance. | high | 2026-06-27 |
| 5 | Loki Mode / Autonomi | github.com/asklokesh/loki-mode | adjacent | Multi-agent spec→deployed-app; inputs PRD/issue/OpenAPI/brief; "11 quality gates"; spec-driven; multiple AI providers. | per-phase | prompt-only | strong | partial | yes | informal | no | beta (2026) | no machine-readable catalog with stable IDs; no audited dynamic composition; no tiered-evidence/staleness; enforcement is agent prompts. | Spans to deploy (one of few SDLC frameworks claiming deploy coverage); broad provider matrix. | medium | 2026-06-27 |
| 6 | Haren | github.com/odarino/haren | adjacent | Minimal, skill-based agentic SDLC; skill modules. | end-only | prompt-only | strong | none | no | none | no | beta (2026, ~11 stars) | minimal — no catalog enforcement, no V-loop, no DevOps, no orchestration split. | Lightweight; clean skill-scope composition reference point. | medium | 2026-06-27 |
| 7 | Temporal | temporal.io / github.com/temporalio/temporal | tangential | Durable workflow execution: activities, retries, timeouts, compensation/Saga; SDKs for code-defined workflows. | none | ci-gate | none | partial | yes | none | replanner-only | production | no SE/DevOps SDLC catalog; no verification gates; agnostic to work-product validity. | Most mature durable-orchestration/runtime model with state recovery; strong parent/worker (workflow→activities) and parallel/compensation primitives. | high | 2026-06-27 |
| 8 | Camunda 8 | camunda.com / docs.camunda.io | tangential | BPMN 2.0 process + DMN decision engine; "agentic orchestration" of AI/people/systems; process engine orchestrates tasks/steps. | per-phase | policy-engine | none | partial | yes | artifact-based | no | production (v8.9, 2026) | no SE lifecycle fit; no agent work-product verification; no atomic-flow catalog. | Enterprise-grade BPMN process governance, DMN decision tables, human-task gateways, audit history; mission-critical process provenance. | high | 2026-06-27 |
| 9 | Conductor (conductor-oss) | github.com/conductor-oss/conductor | tangential | Declarative workflow DSL: SWITCH, DO_WHILE, FORK_JOIN (dynamic fanout), SUB_WORKFLOW, DYNAMIC tasks; retries/timeouts/compensating tasks. | none | ci-gate | none | none | yes | none | no | beta (active fork) | no SE catalog, no verification V-loop, agent-unaware. | Most expressive composable-pattern DSL (branch/loop/fork/sub-workflow/dynamic) — direct analog to SB's composition patterns. | high | 2026-06-27 |
| 10 | LangGraph | langchain-ai.github.io/langgraph | tangential | State graph of nodes; conditional routing; `interrupt()` for human approval; checkpointing; subgraphs; dynamic routing at runtime. | none | prompt-only | none | none | partial | informal | replanner-only | beta (0.2.x) | ships no SDLC/DevOps catalog at all; verification is user-defined. | First-class human-in-the-loop interrupts + durable checkpointing + dynamic routing reference impl. | high | 2026-06-27 |
| 11 | CrewAI | docs.crewai.com / github.com/crewAIInc/crewAI | tangential | Crews (role-based autonomous collaboration) + Flows (event-driven, conditional branching, state mgmt); combine Crews+Flows. | none | prompt-only | none | none | yes | informal | no | beta (production) | no SDLC catalog; no verification gates; no enforcement. | Clean Crew+Flow dual model (autonomous agents vs deterministic control); role-based declarative crews. | high | 2026-06-27 |
| 12 | AutoGen / AG2 alias | microsoft.github.io/autogen | tangential | Multi-agent conversational graphs; GroupChat managers; selectable agents; runtime tool use. | none | prompt-only | none | none | partial | none | no | beta | no workflow catalog, no gates, no SDLC. | Pioneered agent-group conversation semantics. | high | 2026-06-27 |
| 13 | Microsoft Agent Framework | github.com/microsoft/agent-framework | tangential | Build/orchestrate/deploy AI agents & multi-agent workflows; Python & .NET. | none | prompt-only | none | none | partial | none | no | beta (2026) | no SDLC catalog; no verification model; no enforcement. | First-class multi-language production deployment; Azure integration. | medium | 2026-06-27 |
| 14 | LlamaIndex Workflows | docs.llamaindex.ai | tangential | Event-driven workflow with step functions emitting/consuming events; `agent_workflow` multi-agent dispatcher; conditional via custom routing. | none | prompt-only | none | none | yes | informal | no | beta | no SDLC catalog; no gates; no enforcement. | Compact event-driven workflow primitives + multi-agent `agent_workflow` coordinator. | medium | 2026-06-27 |
| 15 | Haystack 2.x | haystack.deepset.ai | tangential | Pipelines of components; indexing & extraction pipelines; agent components. | none | prompt-only | none | none | no | none | no | beta (v2.30) | no SDLC; no workflow catalog semantics; RAG-focused. | Mature, production-proven pipeline composition framework. | medium | 2026-06-27 |
| 16 | OpenHands | github.com/All-Hands-AI/OpenHands | adjacent | Open agentic runtime; `(agent, llm, env)` event-stream loop; `skills/` + `.agents/skills/` dirs; headless mode; runtime events. | end-only | ide-hook | strong | partial | partial | informal | no | beta (production, ~6.9k commits) | no named workflow catalog with stable IDs; no per-step V-loop; no delivery blockers; no audited dynamic composition. | Most mature open agent runtime with auditable event-stream + skills dir + evaluation harness (SWE-bench lineage). | medium | 2026-06-27 |
| 17 | SWE-agent | github.com/princeton-nlp/SWE-agent | adjacent | Single-agent ACI loop (think/act) for GitHub issues; research-grade; SWE-bench harness. | none | honor-system | strong | none | no | none | no | research (2024–26) | no catalog, no gates, no enforcement, single-agent only, research prototype. | Foundational agent-loop + benchmark science underpinning verification evaluation. | high | 2026-06-27 |
| 18 | Aider | github.com/Aider-AI/aider | tangential | Terminal pair-programmer; repo-map; edit-formats; git-native commits. No workflow catalog. | none | honor-system | partial | none | no | none | no | beta (production) | no catalog, no lifecycle, no gates, no DevOps. | Excellent repo-map + git-integrated edit loop; very stable autonomous-edit UX. | high | 2026-06-27 |
| 19 | Earthly | earthly.dev | adjacent | Programmable CI as code (Earthfiles) + "Engineering Guardrails for the AI Era": AGENTS.md / cursor rules / checklists → deterministic PR + AI-level enforcement; adherence dashboards + continuous audit trail. | end-only | ci-gate | partial | partial | no | artifact-based | no | beta (production) | no workflow catalog; no per-step V-loop; SDLC fit partial. | Strongest "evidence-as-byproduct + audit trail" + AGENTS.md enforcement narrative; closest enforcement/evidence culture match. | high | 2026-06-27 |
| 20 | Open Policy Agent (OPA) / Conftest | openpolicyagent.org / conftest.dev | tangential | General policy-as-code engine (Rego); Conftest tests structured config (K8s, Terraform, CI defs). CI admission gates. | none | policy-engine | none | partial | no | artifact-based | no | production | not an agent orchestrator; no SDLC catalog; no verification loops. | Mature, ubiquitous policy engine — canonical mechanism for contract/admission enforcement SB could adopt. | high | 2026-06-27 |
| 21 | Harness CD | harness.io | tangential | CD pipelines with automated approvals, quality gates, OPA policy engine, AI verification & rollback, GitOps governance. | per-phase | policy-engine | partial | strong | yes | artifact-based | no | production | not an agent workflow catalog; no SE lifecycle; no V-loop. | Production CD "AI verification & rollback" + governance — closest DevOps-path delivery gate analog. | high | 2026-06-27 |
| 22 | Spacelift | spacelift.io | tangential | IaC orchestration + GitOps + policy; "fuses AI, IaC, GitOps pipelines". | none | policy-engine | none | strong | yes | none | no | production | not an SE agent framework; no SDLC catalog; no verification loops. | Mature IaC-policy orchestration — DevOps-route/blast-radius counterpart. | medium | 2026-06-27 |
| 23 | Backstage | backstage.io | tangential | Software catalog + templates (Scaffolder) + plugins for developer portal. | none | honor-system | partial | partial | no | artifact-based | no | production | no agentic execution; no workflow catalog; no verification. | Canonical "catalog as source of truth + templated scaffolding" pattern SB's catalog mirrors. | high | 2026-06-27 |
| 24 | Claude Code plugins | docs.claude.com/en/docs/claude-code/plugins | tangential | Plugin system: commands, hooks, MCP servers, agents; shareable across projects/teams. | none | ide-hook | partial | none | partial | none | no | beta (2026) | no catalog; no gates; infrastructure only. | The host-extension substrate SB itself runs on — hooks-MCP-commands extension surface. | high | 2026-06-27 |
| 25 | Cline | github.com/cline/cline | tangential | VS Code agent; Plan/Act modes; MCP; Checkpoints. | end-only | prompt-only | partial | none | no | informal | no | beta (production) | no catalog, no per-step V-loop, no delivery blockers. | Plan/Act split + Checkpoints (state snapshot/rollback) UX precedent. | medium | 2026-06-27 |
| 26 | Codex (OpenAI) | github.com/openai/codex | tangential | Terminal coding agent; sandboxed; config-driven; agent protocol. | none | honor-system | partial | none | partial | none | no | beta (2025–26) | no catalog, no gates, no DevOps. | Sandbox + config protocol host substrate; a delivery host SB-like systems can target. | medium | 2026-06-27 |
| 27 | CodeRabbit | coderabbit.ai | tangential | Automated PR review agent; configurable review rules. | end-only | ci-gate | partial | none | no | none | no | beta (production) | review-only; no composition; no V-loop; no DevOps. | Mature production automated-review gate — analog to SB's REVIEW-TRIAD flow. | medium | 2026-06-27 |
| 28 | BMAD Method | (canonical GitHub fetch failed — multiple 404s) | adjacent | Training-data summary: role-based multi-agent SDLC methodology (Analyst, PM, Architect, Story Manager, Dev, QA, DevOps) producing templated artifacts via a coordinator; installable prompt-pack, not a machine-readable catalog. | per-phase | prompt-only | strong | partial | yes | informal | no | alpha (training-cutoff — primary source not verifiable) | no machine-readable catalog; no hook/policy enforcement; no audited dynamic composition; no V-loop rollup; evidence is document-shaped only. | Mature, widely-known role+artifact SDLC methodology with explicit agent roles and a full artifact chain. | low | training-cutoff |
| 29 | Devin / Cognition | (docs.cognition.ai DNS lookup failed) | adjacent | Training-data summary: closed-source autonomous software engineer; agentic plan/execute; "Deepnotif"?"; web-based sessions; (no published workflow catalog). | none | honor-system | strong | partial | partial | none | no | closed-source (commercial) | closed; no published catalog/enforcement; no V-loop; not inspectable. | Most mature commercial autonomous-engineer product; broad public awareness. | low | training-cutoff |
| 30 | Anthropic "Building effective agents" | anthropic.com/research/building-effective-agents | adjacent (methodology) | Defines workflow patterns incl. **Orchestrator-workers** (central LLM dynamically breaks down tasks, delegates to workers, synthesizes), routing, parallelization, evaluator-optimizer. Prompt-level methodology, no tooling. | none | prompt-only | partial | none | partial | informal | replanner-only | methodology (2024–25) | no catalog; no enforcement; no evidence model. | Authoritative named "orchestrator-workers" pattern SB's parent/worker split instantiates; evaluator-optimizer = closest intent-validation analog. | high | 2026-06-27 |

> Coverage: 30 distinct candidates. 5 classified `adjacent` strong (rows 1–5, 16, 19) plus methodology (30); ~15 `tangential`; 2 `negative-result/low-confidence` (28, 29 due to fetch failure). Negative-result categories in §5.

---

## 3. Evidence blocks (per candidate)

```
EVIDENCE — Antigravity Ultimate SDLC Framework
    source_type: repo
    version_or_date: 2026-03-30 (1 commit), ~3 stars
    quote: "Agentic SDLC framework for Google Antigravity IDE — 4 councils, 166 workflows, 236 skills, 13 quality gates, 5 cycle types. ... Workflows | ~166 | Process orchestrators — appear as `/` commands ... Quality gates | 13 | Blocking checkpoints across all 4 councils ... Three-Layer Architecture: Workflows → (invoke) → Agents → (load) → Skills. Workflows specify skills via `skills_required` frontmatter (max 7 per workflow)."
    url: https://github.com/UnpaidAttention/antigravity-ultimate-sdlc-framework
```
```
EVIDENCE — GitHub Agentic Workflows (gh-aw)
    source_type: repo
    version_or_date: 2026
    quote: "Guardrails ... run with read-only permissions by default, with write operations only allowed through sanitized `safe-outputs`. ... sandboxed execution, input sanitization, network isolation, supply chain security (SHA-pinned dependencies), tool allow-listing, and compile-time validation. ... human approval gates for critical operations. Agent Workflow Firewall (AWF) - Network egress control for AI agents ... MCP Gateway - Routes Model Context Protocol (MCP) server calls through a unified HTTP gateway."
    url: https://github.com/github/gh-aw
```
```
EVIDENCE — Superpowers
    source_type: repo
    version_or_date: 2026
    quote: "The agent checks for relevant skills before any task. Mandatory workflows, not suggestions. ... subagent-driven-development - Fast iteration with two-stage review (spec compliance, then code quality) ... dispatching-parallel-agents - Concurrent subagent workflows ... using-git-worktrees - Parallel development branches ... finishing-a-development-branch - Merge/PR decision workflow"
    url: https://github.com/obra/superpowers
```
```
EVIDENCE — GitHub Spec Kit
    source_type: repo
    version_or_date: 2026
    quote: "The `/speckit.implement` command will: Validate that all prerequisites are in place (constitution, spec, plan, and tasks); Parse the task breakdown from `tasks.md`; Execute tasks in the correct order, respecting dependencies and parallel execution markers; Follow the TDD approach ... Bundles: Role-Based Setups ... Enforce organizational or regulatory standards | Preset"
    url: https://github.com/github/spec-kit
```
```
EVIDENCE — Loki Mode / Autonomi
    source_type: repo
    version_or_date: 2026
    quote: "Multi-agent autonomous SDLC framework. Spec to deployed app. PRD, GitHub issue, OpenAPI/JSON/YAML, or one-line brief. 5 AI providers, 11 quality gates."
    url: https://github.com/asklokesh/loki-mode
```
```
EVIDENCE — OpenHands
    source_type: repo
    version_or_date: 2026 (~6,964 commits)
    quote: "[repo layout] skills/ , agents/ (top-level skills + .agents/skills), runtime, evaluations; headless mode + event stream."
    url: https://github.com/All-Hands-AI/OpenHands
    note: Inspected repo tree + README; no verbatim "workflow catalog" claim found — classification relies on known architecture.
```
```
EVIDENCE — Conductor (conductor-oss)
    source_type: repo README (raw)
    version_or_date: 2026 (active OSS fork)
    quote: "Conductor supports `SWITCH` (conditional branching), `DO_WHILE` (loops ...), `FORK_JOIN` (parallel execution with dynamic fanout), `SUB_WORKFLOW` (composition), and `DYNAMIC` tasks resolved at runtime. These are composable — you can nest loops inside branches inside forks. ... every task supports configurable retries, timeouts, and optional/compensating tasks."
    url: https://github.com/conductor-oss/conductor
```
```
EVIDENCE — Camunda 8
    source_type: docs
    version_or_date: v8.9 (2026)
    quote: "Orchestrate and automate complex business processes for people, systems, and devices. Build BPMN processes and DMN decisions ... Agentic orchestration: Orchestrate and integrate artificial intelligence (AI) agents into your end-to-end processes."
    url: https://docs.camunda.io/docs/components/concepts/what-is-camunda-8/
```
```
EVIDENCE — LangGraph
    source_type: docs
    version_or_date: 0.2.x (2026)
    quote: "After an interrupt pauses execution, you resume the graph by invoking it again with a `Command` that contains the resume value ... `approval_node` ... `is_approved = interrupt({...})` ... if is_approved: return Command(goto='proceed') else return Command(goto='cancel')"
    url: https://docs.langchain.com/oss/python/langgraph/interrupts
```
```
EVIDENCE — CrewAI
    source_type: repo README (raw)
    version_or_date: 2026
    quote: "Crews: Teams of AI agents with true autonomy ... dynamic task delegation ... Flows: Production-ready, event-driven workflows ... conditional branching for complex business logic. The true power ... emerges when combining Crews and Flows."
    url: https://raw.githubusercontent.com/crewAIInc/crewAI/main/README.md
```
```
EVIDENCE — Earthly
    source_type: docs/site
    version_or_date: 2026
    quote: "Engineering Guardrails for the AI Era. Turn AI prompts, standards, AGENTS.md files, eng wikis, cursor rules, checklists, compliance into deterministic PR and AI-level enforcement in minutes ... Evidence as a Byproduct: Real-time adherence dashboards and a continuous audit trail fall out of enforcement. Not a separate quarterly exercise."
    url: https://earthly.dev/
```
```
EVIDENCE — Harness CD
    source_type: docs/site
    version_or_date: 2026
    quote: "Orchestrate Multi-Stage Promotions ... automated approvals, quality gates, and notifications ... Enforce Enterprise Guardrails ... built-in OPA policy engine ... Deploy Safely with AI Verification & Rollback: Automatically analyze logs and metrics to verify deployment health and trigger an intelligent rollback at the first sign of failure."
    url: https://www.harness.io/products/continuous-delivery
```
```
EVIDENCE — Anthropic "Building effective agents"
    source_type: research article
    version_or_date: 2024–2025
    quote: "In the orchestrator-workers workflow, a central LLM dynamically breaks down tasks, delegates them to worker LLMs, and synthesizes their results. ... well-suited for complex tasks where you can't predict the subtasks needed ... subtasks aren't pre-defined, but determined by the orchestrator based on the specific input."
    url: https://www.anthropic.com/research/building-effective-agents
```
```
EVIDENCE — Microsoft Agent Framework
    source_type: repo
    version_or_date: 2026
    quote: "A framework for building, orchestrating and deploying AI agents and multi-agent workflows with support for Python and .NET."
    url: https://github.com/microsoft/agent-framework
```
```
EVIDENCE — AutoGen
    source_type: repo/docs (index page redirects)
    version_or_date: 2026
    quote: docs index redirects to /autogen/stable/; repo README known to describe "multi-agent conversation" GroupChat managers (canonical alias: AG2 fork).
    url: https://github.com/microsoft/autogen (note: AG2 = community fork, dedup)
```
```
EVIDENCE — BMAD Method / Devin
    source_type: (fetch failed)
    version_or_date: training-cutoff
    quote: NO PRIMARY SOURCE OBTAINED — multiple GitHub URL variants 404; docs.cognition.ai DNS ENOTFOUND. Classification from training data only.
    url: (unverified)
    confidence: low
```

---

## 4. Narrative sections

### 4.1 Executive summary
See §1.

### 4.2 Top 5 direct competitors (ranked)
1. **Antigravity Ultimate SDLC Framework** — only candidate with a comparably-sized *catalog* (workflows/skills/gates/cycles) AND blocking quality gates. Closest catalog analog; gap is enforcement substrate + machine-readability + DevOps + V-loop.
2. **GitHub Agentic Workflows (gh-aw)** — only first-party platform matching SB's *enforcement+evidence+guardrail* ambition (sandbox, firewall, compile-time validation, approval gates). Gap: no SDLC/DevOps catalog, no V-loop, no intent gate.
3. **Loki Mode / Autonomi** — spans spec→deploy (rare SDLC+DevOps in one) with 11 quality gates. Gap: prompt-only enforcement, no audited composition.
4. **GitHub Spec Kit** — strongest spec→plan→tasks *contraction* with parallel markers and TDD discipline and org compliance bundles. Gap: no global catalog, no per-step V-loop, no delivery blockers.
5. **Superpowers** — most mature *subagent-driven methodology* with mandatory workflow, two-stage review, parallel agents. Gap: no machine-readable catalog, no DevOps, no hook blockers.

### 4.3 Top 5 adjacent inspirations (what SB could borrow)
1. **Conductor (conductor-oss)** — proven composable DSL (SWITCH/DO_WHILE/FORK_JOIN/SUB_WORKFLOW/DYNAMIC + compensating tasks) — direct pattern language for SB's composition patterns (sequence/branch/parallel/repair/compensation/reuse).
2. **Temporal** — durable workflow/parent-worker semantics + activity retries + Saga compensation + state recovery — runtime-durability SB currently delegates to host hooks.
3. **Earthly** — "Evidence as a Byproduct / continuous audit trail" + AGENTS.md→deterministic-PR enforcement — closest *enforcement + evidence* culture; SB's evidence_records/composition_logs could mirror this audit-trail-as-emergent philosophy.
4. **Camunda 8 + DMN** — BPMN gateway/DMN decision tables + human-task gateways + process audit history — decision-table-as-policy analogue for SB's dynamic_rules and process governance.
5. **Anthropic orchestrator-workers + evaluator-optimizer** — named canonical workflow patterns; "evaluator-optimizer" is the closest intent-validation analog to SB's user-intent validation gate.

### 4.4 Negative results
- **arXiv** open queries (`"verification loops" "multi-agent"` → 3-4 irrelevant; `phase+gate+LLM+software+delivery` → **no results**) — no primary academic paper combining V-model + LLM-agent + process orchestration was surfaced via arXiv search. Treat as negative result; deeper Google Scholar/proceedings search needed.
- **GitHub REST `gh search repos`** — rate-limited (HTTP 403) for several batches; the one successful `"agentic process orchestrator"` query returned only ~3 repos, dominated by **the Silver Bullet repo itself** plus two 0-star lookalikes (`Contragraviton`, `multi-agent-orchestration-design`). I.e., the "APO" term as SB uses it is essentially uncontested in public registries.
- **Canonical primary sources could not be fetched** for: BMAD Method (multiple URL variants 404), GSD (no stable repo found), Devin/Cognition (docs.cognition.ai DNS ENOTFOUND). These are marked `confidence: low`, `last_verified: training-cutoff`.
- **No product found** that combines, in one model: a *machine-readable catalog with stable IDs + no-redundancy invariant* AND *per-step V-loop rollup + final user-intent validation gate* AND *hook-enforced delivery blockers* AND *audited catalog-backed dynamic composition*. Each differentiator exists piecemeal; the combination is SB's claimed white space.

### 4.5 Open research questions
1. Does any **ML lifecycle** framework (e.g., MLflow Pipelines, Kubeflow Pipelines with DAG + gate stages) carry a comparable per-step verification + artifact-sufficiency model that SB's evidence tiers could learn from? (Not investigated this run.)
2. Are there **enterprise ALM** integrations (Azure DevOps "Required reviewers"+ gates, Jira workflows + Compass) that implement *catalog-backed enforced composition* at a fidelity below marketing claims? Needs docs deep-dive.
3. Is there a **recent (2025–26) academic paper** on "intent satisfaction / specification validation as a final gate" for LLM coding agents? arXiv open search was negative; a targeted Google Scholar / proceedings (ESEC/FSE, ICSE) pass is warranted.
4. **BMAD Method / GSD** canonical repos/maintainership status — confirm current home (possibly moved orgs); a human-curated lookup is needed since automated URL probing failed.
5. Whether **gh-aw** will publish a first-party SDLC/DevOps workflow catalog (it currently ships the *runner* + guardrails, leaving catalogs to users) — a potential competitive convergence risk for SB.

---

## 5. Notes for the cross-AI merge

- **Duplicate-flag:** AutoGen ↔ AG2 (AG2 = community fork of AutoGen); canonical = AutoGen.
- **Deprecated/abandoned flags:** none confirmed abandoned; conductor-oss is an active community continuation of Netflix Conductor.
- **Open-source vs commercial vs research:** open-source = (1,3,4,6,7,11,12,13,15,16,17,18,19,20,21?…); commercial closed = Devin (29), Harness, Spacelift, gh-aw (vendor product), Camunda (open-core), Backstage (open, Spotify); research = SWE-agent, Anthropic article.
- **Divergence with prior sibling runs expected:** Antigravity Ultimate SDLC classification (adjacent vs direct) — maintained `adjacent` here because the "catalog" is README-counted, not a versioned machine-readable schema with stable IDs. gh-aw could be argued `direct` on enforcement+guardrails; kept `adjacent` because it ships no SDLC/DevOps catalog. Conflict resolution per §8.2 should prefer `direct` only if ≥3 SB differentiators are evidenced; Antigravity clearly evidences (catalog+gates+orchestrator/agents split) but lacks V-loop+hook-blockers+audited dynamic+evidence tiers.
- **Scoring snapshot (max 16):** Antigravity ~8, gh-aw ~7, Loki ~6, Spec Kit ~6, Superpowers ~6, Earthly ~6, Camunda ~5, Temporal ~4. No candidate ≥10 → no true *direct architectural match*; SB occupies largely uncontested white space with several strong *single-dimension* peers.
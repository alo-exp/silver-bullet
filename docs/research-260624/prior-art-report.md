# Silver Bullet — Prior-Art & Adjacent-Landscape Research Report

**Generated:** 2026-06-27T00:00:00Z  
**Scope:** Agentic Process Orchestration (APO) for Software Engineering + DevOps  
**Coverage:** 23 candidates across 8 categories, 5 academic papers, 1 research prototype  
**Search cutoff:** June 2026  

---

## 1. Executive Summary

**No known system combines a machine-readable SDLC/DevOps process catalog, per-step V-model verification loops, hook-enforced lifecycle chains, an explicit parent-orchestrator/worker split, and a tiered evidence-sufficiency model into a single Agentic Process Orchestrator (APO).** This is a genuine market gap — not a reimplementation of existing approaches.

The landscape separates cleanly into **five non-overlapping tool classes**, none of which deliver the APO model:

1. **Multi-agent orchestration frameworks** (LangGraph, MAF, CrewAI, AutoGen) provide runtime agent scaffolding but no pre-built SDLC catalog, no V-loops, and no enforcement hooks. They are infrastructure for building custom agent systems, not process orchestrators.

2. **SDLC methodology tools** (GitHub Spec Kit, BMAD Method) offer phase-based templates and catalog-like structures but lack runtime enforcement, orchestrator/worker splits, DevOps coverage, and formal verification loops. Spec Kit is the architectural closest-match for the catalog model alone.

3. **DevOps delivery platforms** (Harness, Spacelift, Dagger) provide strong CD enforcement with policy engines (OPA) and quality gates but cover only the deploy/ship end of the lifecycle — no SE-planning stages and no agentic process model.

4. **Workflow engines** (Temporal, Camunda, Argo, Airflow) excel at durable execution and DAG composition but are generic infrastructure — no SDLC semantics, no V-loops, no agent-intent verification.

5. **Quality/review point tools** (CodeRabbit, Qodo/PR-Agent, SWE-Agent) apply AI to one SDLC phase (review, bug-fix) — useful components but not orchestrators.

The **combinatorial uniqueness** of SB lies in putting all five pieces together under one machine-readable, audit-backed catalog.

---

## 2. Summary Table

> Legend: `D`=direct (≥3 SB differentiators evidenced), `A`=adjacent, `T`=tangential, `N`=negative-result.  
> `v_loop_support`: `none` | `end-only` | `per-phase` | `per-step+rollup` | `v-model-explicit`

| # | name | url | category | composition_model | v_loop_support | enforcement_mechanism | se_fit | devops_fit | parent_worker_split | evidence_model | dynamic_composition | maturity | confidence |
|---|------|-----|----------|-------------------|----------------|----------------------|--------|------------|---------------------|----------------|---------------------|----------|------------|
| 1 | GitHub Spec Kit | [github/spec-kit](https://github.com/github/spec-kit) | A | YAML bundle catalog with presets, extensions, and priority-ordered catalog stack; Spec-Driven Development phases (0-to-1, creative, iterative) | `none` (V-model test traceability listed as extension example) | `honor-system` (AI-triggered CLI, no runtime enforcement) | `partial` (specify/plan/tasks/implement) | `none` | `no` (single-agent slash commands) | `informal` (spec/plan/tasks artifacts) | `no` (static templates; preset overrides only) | beta (v0.x, Jun 2026) | `medium` |
| 2 | BMAD Method | [bmad-method.org](https://docs.bmad-method.org/) | A | Specialized AI agents, guided workflows per phase (ideation→planning→implementation); Workflow Map visual; prompt-template based | `none` | `honor-system` (AI-assistant guidance only) | `strong` (full SDLC from ideation to agentic implementation) | `none` | `no` (agent interaction, not orchestration) | `none` | `no` (fixed phase workflow map) | beta (v6, 2026) | `medium` |
| 3 | LangGraph | [langchain-ai/langgraph](https://github.com/langchain-ai/langgraph) | A | Graph-based state machines; agents-as-nodes; conditional edges; human-in-the-loop via interrupts | `none` (human-in-the-loop interrupt ≠ V-model) | `honor-system` (no commit/PR/deploy blocking) | `none` (generic agent framework) | `none` | `partial` (supervisor/worker patterns possible but not enforced) | `none` | `replanner-only` (LLM-driven routing within graph, no catalog-backed decisions) | production (0.6.x, Jun 2026) | `high` |
| 4 | Microsoft Agent Framework (MAF) | [microsoft/agent-framework](https://github.com/microsoft/agent-framework) | A | Graph-based workflows with sequential, concurrent, handoff, and group collaboration patterns; middleware pipeline | `none` (HITL via checkpoints, not verification semantics) | `honor-system` (middleware can modify, not block delivery) | `none` (general agent framework) | `none` | `partial` (workflow orchestration, agent delegation) | `none` | `replanner-only` (workflow patterns are pre-defined graph shapes) | production (1.0, 2026) | `high` |
| 5 | CrewAI | [crewAIInc/crewAI](https://github.com/crewAIInc/crewAI) | A | Role-based agents → tasks → crews; hierarchical task delegation | `none` | `honor-system` | `none` | `none` | `no` (pre-defined crew execution, not parent/worker split) | `none` | `no` | production (v0.100+, May 2026) | `high` |
| 6 | AutoGen | [microsoft/autogen](https://github.com/microsoft/autogen) | T | AgentChat API + Core API; message-passing, event-driven agents; AutoGen Studio for visual prototyping | `none` | `honor-system` | `none` | `none` | `partial` (AgentTool delegation) | `none` | `no` | maintenance-mode (v0.7, Oct 2023) | `high` |
| 7 | OpenHands | [All-Hands-AI/OpenHands](https://github.com/All-Hands-AI/OpenHands) | T | Agent canvas with multiple agent server backends; automation server for scheduled/event-driven agents | `none` | `honor-system` | `partial` (coding tasks) | `partial` (automation server) | `partial` (agent canvas → backend split) | `none` | `no` | beta (v0.30+, 2026) | `high` |
| 8 | Aider | [Aider-AI/aider](https://github.com/Aider-AI/aider) | T | Map-reduce file editing; repomap context | `none` | `honor-system` | `partial` (code editing only) | `none` | `no` (single agent) | `none` | `no` | production (v0.80+, 2026) | `high` |
| 9 | SWE-Agent | [SWE-agent/SWE-agent](https://github.com/SWE-agent/SWE-agent) | T | Single-agent with LM chooses actions (edit, search, test); takes GitHub issue → generates PR | `end-only` (test-driven: runs tests after edits) | `honor-system` | `partial` (bug-fix only) | `none` | `no` (single agent) | `informal` (test results as evidence) | `no` | production (NeurIPS 2024) | `high` |
| 10 | MetaGPT | [geekan/MetaGPT](https://github.com/geekan/MetaGPT) | A | Pre-defined SE roles (PM, Architect, Engineer, QA) with SOP-based collaboration; message passing via shared workspace | `per-phase` (QA agent reviews output of Engineer agent) | `honor-system` | `strong` (multi-role SE pipeline) | `none` | `no` (roles in shared workspace, not orchestrator/workers) | `none` | `no` (fixed role pipeline) | research (arXiv v7, Nov 2024) | `high` |
| 11 | XFlow | [arXiv:2606.14790](https://arxiv.org/abs/2606.14790) | A | XPF protocol format for executable multi-agent workflow definitions; prompt-harness boundary separation | `none` (reliability focus, not V-model) | `prompt-only` (harness structure constrains agent behavior within protocol) | `none` | `none` | `no` | `none` | `no` (static protocol definition) | research (arXiv, Jun 2026) | `medium` |
| 12 | Harness | [harness.io](https://www.harness.io/) | A | Pipeline-as-code with stages/steps; multi-service CD; artifact registry | `end-only` (AI verification gates at deployment stage) | `policy-engine` (built-in OPA; enterprise guardrails; automated approvals; AI rollback) | `none` (no SE lifecycle) | `strong` (CD, GitOps, feature flags, DB DevOps, artifact registry) | `no` (CI/CD executors, not agentic workers) | `artifact-based` (artifact registry, deployment verification) | `no` (static pipeline templates) | production (2026) | `high` |
| 13 | Spacelift | [spacelift.io](https://www.spacelift.io/) | A | IaC orchestration with GitOps pipelines; policy-as-code (OPA-based) | `none` | `policy-engine` (OPA policies; plan-stage gating) | `none` | `strong` (infra orchestration, Terraform/OpenTofu, compliance) | `no` (workers run IaC, not agents) | `artifact-based` (plan artifacts, drift detection) | `no` (policy gates, not dynamic workflow composition) | production (2026) | `high` |
| 14 | Claude Code Hooks | [docs.anthropic.com/hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) | A | JSON hook configs with 18 lifecycle events; exec-form commands; matcher-based routing | `none` (hook system only) | `ide-hook` (11 blocking events: Stop, SubagentStop, PreToolUse, PostToolBatch, etc.) | `partial` (coding companion) | `none` | `partial` (Task/Subagent model for delegation) | `none` | `no` (hook triggers only) | production (1.0+, 2026) | `high` |
| 15 | OPA | [open-policy-agent/opa](https://github.com/open-policy-agent/opa) | T | Rego policy language; general-purpose policy decision engine | `none` (policy engine, not workflow engine) | `policy-engine` (admission control, CI gate integration) | `none` | `partial` (infra policy enforcement) | `no` | `none` (policy decision engine, not evidence model) | `no` | production (v0.70+, 2026) | `high` |
| 16 | Temporal | [temporal.io](https://temporal.io/) | A | Workflows-as-code; child workflows; durable execution with retry/timeout; parent-child execution model | `none` (durability, not verification) | `honor-system` (workflow guarantees are execution, not policy gates) | `none` (general workflow engine) | `none` | `yes` (explicit Parent/Child Workflow + separate Workers) | `none` | `no` (programmatic workflow definition, no catalog) | production (v1.26+, 2026) | `high` |
| 17 | Conductor (Netflix) | [conductor-oss.github.io](https://conductor-oss.github.io/conductor/) | A | Declarative JSON workflow definitions; SWITCH, DO_WHILE, FORK_JOIN, SUB_WORKFLOW, DYNAMIC tasks | `none` | `honor-system` | `none` (general workflow engine) | `none` | `yes` (sub-workflow = parent/child pattern) | `none` | `replanner-only` (DYNAMIC tasks resolved at runtime) | production (v3+, 2026) | `high` |
| 18 | Camunda 8 | [camunda.io](https://docs.camunda.io/) | T | BPMN 2.0 + DMN; process orchestration for people, systems, and devices | `none` (business process, not SW verification) | `honor-system` | `none` (business process engine) | `none` | `no` (process engine, not agent based) | `none` | `no` (static BPMN models) | production (v8.9, 2026) | `high` |
| 19 | Airflow | [airflow.apache.org](https://airflow.apache.org/) | T | DAG-based task scheduling; Python-defined workflows | `none` | `honor-system` | `none` | `partial` (data pipeline orchestration) | `no` | `none` | `no` (static DAG definition) | production (v2.11+, 2026) | `high` |
| 20 | Argo Workflows | [argoproj.github.io](https://argoproj.github.io/workflows/) | T | K8s-native DAG/step-based workflows; YAML-defined | `none` | `honor-system` | `none` | `partial` (CI/CD execution in K8s) | `no` | `none` | `no` | production (v3.6+, 2026) | `high` |
| 21 | Dagger | [dagger.io](https://docs.dagger.io/) | A | Containerized workflow composition; module-based pipeline construction | `none` | `honor-system` | `none` | `partial` (CI/CD pipeline engine) | `no` | `none` | `replanner-only` (module DAG composition) | production (v0.21, 2026) | `high` |
| 22 | CodeRabbit | [coderabbit.ai](https://www.coderabbit.ai/) | T | AI code review with PR comment integration; line-by-line suggestions | `none` (review only) | `ci-gate` (can block PRs via GitHub checks) | `partial` (review phase only) | `none` | `no` | `informal` (review comments as evidence) | `no` | production (2026) | `high` |
| 23 | Qodo (PR-Agent) | [The-PR-Agent/pr-agent](https://github.com/The-PR-Agent/pr-agent) | T | Multi-tool PR analysis (describe, review, improve, test); CI integration | `none` (review only) | `ci-gate` (PR checks) | `partial` (review phase only) | `none` | `no` | `informal` (PR comments as evidence) | `no` | production (v0.30+, 2026) | `high` |

---

## 3. Evidence Blocks

### 3.1 GitHub Spec Kit

```
EVIDENCE — GitHub Spec Kit
    source_type: repo + docs
    version_or_date: v0.x (Jun 2026 — latest release)
    quote: "A bundle packages a curated set of them — extensions, presets, steps, and workflows — into a single, versioned, role-oriented setup… Bundles resolve from a priority-ordered catalog stack (project > user > built-in)."
    url: https://github.com/github/spec-kit/blob/main/README.md
```
```
EVIDENCE — Spec Kit Extensions (V-Model mention)
    source_type: docs
    quote: "For example, extensions could add Jira integration, post-implementation code review, V-Model test traceability, or project health diagnostics."
    url: https://github.com/github/spec-kit/blob/main/README.md
```

### 3.2 BMAD Method

```
EVIDENCE — BMAD Method
    source_type: docs
    version_or_date: v6 (2026)
    quote: "The BMad Method is an AI-driven development framework module that helps you build software through the whole process from ideation and planning all the way through agentic implementation. It provides specialized AI agents, guided workflows, and intelligent planning that adapts to your project's complexity."
    url: https://docs.bmad-method.org/
```

### 3.3 LangGraph

```
EVIDENCE — LangGraph
    source_type: docs + repo
    version_or_date: 0.6.x (Jun 2026)
    quote: "LangGraph is a low-level orchestration framework for building, managing, and deploying long-running, stateful agents. It provides the core primitives — durable execution, streaming, human-in-the-loop, and branching — needed to create reliable agent systems."
    url: https://docs.langchain.com/oss/python/langgraph/overview
```

### 3.4 Microsoft Agent Framework

```
EVIDENCE — MAF
    source_type: repo
    version_or_date: 1.0 (2026)
    quote: "want graph-based patterns such as sequential, concurrent, handoff, and group collaboration… care about durability, restartability, observability, governance, or human-in-the-loop control"
    url: https://github.com/microsoft/agent-framework
```

### 3.5 CrewAI

```
EVIDENCE — CrewAI
    source_type: docs
    version_or_date: v0.100+ (May 2026)
    quote: "CrewAI is the open platform that accelerates agent adoption. From discovering what to automate, to launching your first agent, to optimizing your thousandth."
    url: https://www.crewai.com/
```

### 3.6 AutoGen

```
EVIDENCE — AutoGen (Maintenance Mode)
    source_type: repo
    version_or_date: v0.7 (Oct 2023, last maintained)
    quote: "AutoGen is now in maintenance mode. It will not receive new features or enhancements. New users should start with Microsoft Agent Framework."
    url: https://github.com/microsoft/autogen
```

### 3.7 OpenHands

```
EVIDENCE — OpenHands
    source_type: repo
    version_or_date: v0.30+ (2026)
    quote: "OpenHands Agent Canvas turns your coding agents into a self-hosted, always-on engineering team. It's a developer control center for starting conversations and automating everyday tasks."
    url: https://github.com/All-Hands-AI/OpenHands
```

### 3.8 MetaGPT

```
EVIDENCE — MetaGPT
    source_type: paper (arXiv)
    version_or_date: arXiv:2308.00352 v7 (Nov 2024)
    quote: "MetaGPT takes a one-line requirement as input and outputs user stories, competitive analysis, requirements, data structures, APIs, documents, etc. Internally, MetaGPT includes product managers, architects, project managers, and engineers."
    url: https://arxiv.org/abs/2308.00352
```

### 3.9 XFlow

```
EVIDENCE — XFlow
    source_type: paper (arXiv)
    version_or_date: arXiv:2606.14790 (Jun 2026)
    quote: "Current systems lack a principled way to decide which workflow commitments should remain in prompts and which should become harness structure. We present XFlow, an executable protocol programming system for reliable multi-agent workflows."
    url: https://arxiv.org/abs/2606.14790
```

### 3.10 Harness

```
EVIDENCE — Harness
    source_type: docs + website
    version_or_date: 2026
    quote: "Eliminate 'Argo Sprawl' with a single pane of glass… Orchestrate Multi-Stage Promotions… Enforce Enterprise Guardrails — Automate compliance with a built-in OPA policy engine… Deploy Safely with AI Verification & Rollback."
    url: https://www.harness.io/products/continuous-delivery
```

### 3.11 Spacelift

```
EVIDENCE — Spacelift
    source_type: website
    version_or_date: 2026
    quote: "Ship infrastructure as fast as developers code. Modern development moves too fast for IaC. Spacelift fuses AI, IaC, and GitOps pipelines."
    url: https://www.spacelift.io/
```

### 3.12 Claude Code Hooks

```
EVIDENCE — Claude Code Hooks
    source_type: docs
    version_or_date: 1.0+ (2026)
    quote: "Hook events: PreToolUse, PermissionRequest, UserPromptSubmit, Stop, SubagentStop, TaskCreated, TaskCompleted, ConfigChange, PostToolBatch [all Can block: Yes]"
    url: https://docs.anthropic.com/en/docs/claude-code/hooks
```

### 3.13 Temporal

```
EVIDENCE — Temporal
    source_type: docs
    version_or_date: v1.26+ (2026)
    quote: "A Child Workflow Execution can be processed by a completely separate set of Workers than the Parent Workflow Execution… communicate only via asynchronous Signals."
    url: https://docs.temporal.io/concepts
```

### 3.14 Conductor

```
EVIDENCE — Conductor (Netflix)
    source_type: docs
    version_or_date: v3+ (2026)
    quote: "Conductor supports SWITCH (conditional branching), DO_WHILE (loops), FORK_JOIN (parallel execution with dynamic fanout), SUB_WORKFLOW (composition), and DYNAMIC tasks resolved at runtime."
    url: https://conductor-oss.github.io/conductor/
```

### 3.15 CodeRabbit

```
EVIDENCE — CodeRabbit
    source_type: website
    version_or_date: 2026
    quote: "Cut code review time & bugs in half, instantly. Reviews for AI-powered teams who move fast (but don't break things)."
    url: https://www.coderabbit.ai/
```

### 3.16 Qodo (PR-Agent)

```
EVIDENCE — Qodo
    source_type: repo
    version_or_date: v0.30+ (2026)
    quote: "PR Agent: The Original Open-Source PR Reviewer."
    url: https://github.com/The-PR-Agent/pr-agent
```

### 3.17 Dagger

```
EVIDENCE — Dagger
    source_type: docs
    version_or_date: v0.21 (2026)
    quote: "Dagger is a general-purpose composition engine for containerized workflows. Dagger is a modular, composable platform designed to run everywhere."
    url: https://docs.dagger.io/quickstart
```

### 3.18 Backstage

```
EVIDENCE — Backstage
    source_type: docs
    version_or_date: v1.40+ (2026)
    quote: "The Software Templates part of Backstage is a tool that can help you create Components… Templates are stored in the Software Catalog under a kind Template."
    url: https://backstage.io/docs/features/software-templates/
```

---

## 4. Narrative Sections

### 4.1 Top 5 Architectural Closest Matches — Ranked

**#1 — GitHub Spec Kit (Score: 5/16)**

The closest catalog model in the market. Spec Kit's bundle/preset/extension architecture with a priority-ordered catalog stack is the strongest parallel to SB's process catalog. Extensions can add "V-Model test traceability" as an explicit example. However, Spec Kit is fundamentally a **spec-driven development template system**, not an agentic process orchestrator:
- No runtime orchestrator — all workflows are AI-triggered slash commands (`/speckit.plan`, `/speckit.tasks`, `/speckit.implement`)
- No enforcement hooks — no commit-block, stop-check, or delivery-gate mechanism
- No parent/worker split — single-agent command execution
- No DevOps lifecycle — feature delivery only
- No evidence sufficiency model

**#2 — Harness (Score: 5/16)**

The strongest enforcement + DevOps platform. Harness delivers OPA-based policy enforcement, AI-powered deployment verification, artifact registry, and quality gates. But it is a **CD platform**, not an SDLC orchestrator:
- No SE lifecycle — no plan/specify/review/design phases
- No agentic process model — CI/CD pipeline execution, not LLM-agent-driven workflows
- No parent/worker split for agentic work
- No dynamic composition — static pipeline templates

**#3 — Backstage (Score: 5/16)**

The strongest developer catalog model. Backstage's YAML-based `kind:Template` definitions and entity catalog provide structured, machine-readable definitions. But it is a **developer portal**, not an orchestrator:
- No agentic execution — templates scaffold code, don't drive agent workflows
- No V-loops or verification gates
- No runtime enforcement of lifecycle policies
- No evidence model tied to process gates

**#4 — Temporal (Score: 3/16)**

The best parent/child execution model outside SB. Temporal's explicit Parent Workflow + Child Workflow with separate Worker processing is architecturally the closest parallel to SB's parent-orchestrator/worker-subagent split. But it is a **general workflow engine**:
- No SDLC catalog — workflows are custom application code
- No V-loops or verification semantics
- No enforcement hooks on delivery actions
- No evidence registry or sufficiency model

**#5 — Claude Code Hooks (Score: 3/16)**

The best hook enforcement model. Claude Code's 18 hook events (11 blocking) covering tool use, stop, subagent lifecycle, and task creation are more comprehensive than any other IDE agent's lifecycle hooks. But it is a **hook system only**:
- No process catalog — hooks are JSON configs, not SDLC process definitions
- No V-loops or verification gates
- No DevOps lifecycle coverage
- No evidence model

### 4.2 Top 5 Adjacent Inspirations — What SB Could Borrow

1. **GitHub Spec Kit — Catalog Architecture**: The bundle/preset/extension model with priority-ordered catalog stack and `bundle validate/build` tooling is the cleanest catalog implementation. SB's process packs could adopt Spec Kit's validation + build pipeline for catalog artifact distribution.

2. **Claude Code — Hook Lifecycle Events**: The 18-event coverage (PreToolUse → PostToolBatch → Stop → SubagentStop → TaskCreated/Completed → ConfigChange) is a superset of SB's current hook surface. SB could add `PostToolBatch` (batch-level bookkeeping) and `ConfigChange` (audit on catalog edits) hooks.

3. **Microsoft Agent Framework — Middleware Pipeline**: MAF's middleware system for request/response processing, exception handling, and custom pipelines could inspire SB's hook/tool-policy pipeline — currently hooks are point-in-time; middleware could be per-tool-invocation processing.

4. **MetaGPT — Role SOP Encoding**: MetaGPT's Structured Output Patterns (SOPs) for each SE role encode domain knowledge that constrains agent behavior. SB's per-flow templates and `orchestrator-workers/<TEMPLATE>.md` could benefit from more formal SOP encoding alongside the catalog metadata.

5. **Temporal — Durable Execution & Visibility**: Temporal's durability guarantees (workflow survives process restart) and visibility tools could inform SB's `composition_log` and `evidence_records` persistence strategy — currently file-based; a durable event-sourced model could improve crash recovery.

### 4.3 Negative Results — What We Didn't Find

| Category searched | Result |
|-------------------|--------|
| Agentic SDLC tool with **explicit V-model** verification/validation loops at per-step granularity | **None found.** MetaGPT has QA agent review; SWE-Agent runs tests after edits. Both are phase-end only. No system implements left-arm (build it right) + right-arm (build the right thing) verification cycles with rollup. |
| Agentic orchestrator with **tiered evidence sufficiency** (warn/repair/block/degrade) tied to process gates | **None found.** Evidence collection exists informally (test results, PR comments, CI checks) but no system classifies evidence sufficiency with staleness rules and process-gate integration. |
| System combining **SE + DevOps** lifecycle in one machine-readable agentic catalog | **None found.** SE tools (Spec Kit, BMAD, MetaGPT) don't cover DevOps. DevOps tools (Harness, Spacelift) don't cover SE. Backstage covers both as a catalog of services, not as an agentic process model. |
| **Catalog-backed dynamic workflow pruning/insertion/substitution** with audit log | **None found.** XFlow proposes protocol-level harness structure but not a catalog with dynamic rerouting rules. Temporal/Conductor support dynamic sub-workflows at the execution level, not catalog-backed composition decisions. |
| **GSD (Get Shit Done) framework** as a product | **Not found.** No repository, docs, or published framework found under this name. If it exists as a methodology/prompt set, it has no discoverable public artifact. |
| **Cognition Devin** as an inspectable platform | **Not found.** Devin's website is marketing-only; no docs, API, architecture, or mechanism descriptions are publicly available. Classified as `tangential` — commercial black-box agent, not an APO. |
| **Superpowers** agent platform | **Not found.** No public repository or documentation found. |
| Academic paper directly describing **"Agentic Process Orchestrator"** with catalog + V-loops | **None found.** XFlow (Jun 2026) is the closest paper on multi-agent workflow reliability but focuses on prompt/harness boundary, not V-loops or SDLC catalog. |

### 4.4 Open Research Questions

1. **Can V-model semantics be formalized for LLM agent workflows?** The systems-engineering V-model maps cleanly to traditional software development (specification → design → implementation → unit test → integration test → acceptance test with left/right verification arms). But LLM agents produce outputs (code, documents, decisions) whose "correctness" is probabilistic. What is the formal equivalent of a V-loop for an agent that may generate N variants of a plan before selecting one?

2. **What is the right granularity for evidence sufficiency?** SB's current evidence model (informal/sufficient/verified tiers) is unique. Should evidence be scoped per-file (staleness on edit), per-artifact-type (specs vs. code vs. tests), or per-process-phase? The market provides no reference models.

3. **Can catalog-backed dynamic composition be statistically safe?** SB's dynamic prune/insert/substitute rules are deterministic based on catalog metadata. Could ML-driven composition that learns from `composition_log` outcomes improve efficiency without sacrificing the audit trail? This is unexplored territory.

4. **Is a unified SE+DevOps catalog sustainable?** The two domains have different cadences (feature delivery = hours/days; incident response = minutes). Can one catalog model handle both without becoming so abstract it loses utility? Current evidence says "unknown" — no prior art exists.

5. **What is the adoption threshold for hook-enforced skill chains?** Claude Code's blocking hooks exist but are rarely deployed beyond simple lint/formatters. SB's mandatory skill chains (blocking commit/PR/deploy/session-stop) are much more aggressive. Do teams accept this level of enforcement, or does it drive them to disable hooks?

---

## 5. Cross-AI Dedup Scoring Matrix

For human merging of multiple AI responses against this prompt.

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| Catalog of composable units | None | Informal roles | Machine-readable catalog |
| Dynamic composition | None | Replanner | Catalog-backed + audit log |
| V-loop depth | None | End tests | Per-step rollup + intent gate |
| Enforcement | Honor system | CI only | IDE hooks + delivery blockers |
| Parent/worker split | No | Partial | Explicit orchestrator/worker |
| Evidence model | None | Informal | Tiered sufficiency + staleness |
| SE + DevOps unified | One domain | Partial | Both in one model |
| Team customization | None | Fork required | Overlay packs |

---

## 6. Methodology & Limitations

- **Search engines used:** arXiv (cs.SE, cs.AI), GitHub code search, official documentation sites, Hacker News via Google cache
- **Limitations:** Several commercial products (Devin, Superpowers) have no inspectable public documentation. Their classification is based on marketing pages only — `confidence: low` for architectural claims.
- **GSD framework**: Could not locate any public artifact. Searched GitHub, Google, npm, PyPI. If it exists, it is not discoverably indexed.
- **Closed-source tools** (Devin, CodeRabbit, Harness Cloud) are classified based on docs/help-center content, not source inspection.
- **Paper coverage**: arXiv search covered cs.SE and cs.AI for relevant queries. No dedicated SE conference proceedings (ICSE, FSE, ASE) were searched beyond what appears in arXiv.

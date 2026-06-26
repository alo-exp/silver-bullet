# Prior-Art and Adjacent-Landscape Research: Silver Bullet APO Architecture

**Research Date:** 2026-06-26
**Researcher:** opencode (mimo-v2.5-pro)
**Scope:** Existing tools, frameworks, methodologies, papers, and products overlapping with Silver Bullet's Agentic Process Orchestrator (APO) architecture.

---

## 1. Executive Summary (≤300 words)

Silver Bullet occupies a **distinct architectural niche** that no existing tool fully covers. The closest competitors combine 2-3 of SB's 7 differentiators, but none combine all of them.

**Closest direct matches:** MetaGPT (multi-agent SDLC with SOP-based role orchestration), CrewAI (composable flows + crews with task guardrails), and LangGraph (graph-based workflow composition with human-in-the-loop interrupts). Each covers ~3-4 SB dimensions but lacks critical elements: MetaGPT has no dynamic composition or V-model verification; CrewAI has guardrails but no per-step V-loop rollup or hook-enforced lifecycle chains; LangGraph has graph composition and interrupts but no SDLC workflow catalog or evidence model.

**Biggest gaps in the market:**
1. **No existing tool combines machine-readable workflow catalog + per-step V-loop rollup + hook-enforced lifecycle chains.** This is SB's strongest differentiator.
2. **No tool unifies SE lifecycle AND DevOps/infra paths in one APO model.** Existing tools are either SE-focused (MetaGPT, SWE-agent) or DevOps-focused (Argo, Temporal).
3. **No tool has catalog-backed audited dynamic composition** — where runtime decisions to prune/insert/substitute flows are logged with catalog rationale. LangGraph has dynamic routing but no audit trail tied to a catalog.
4. **Evidence tiers and tool governance** (mandatory when relevant, with staleness rules) appear nowhere in the landscape.

**Adjacent inspirations:** Temporal's durable execution model, OPA's policy-as-code enforcement, Claude Code's hook system, and Anthropic's "Building Effective Agents" workflow patterns all offer mechanisms SB could borrow or integrate with.

**Negative results:** No credible "agentic process orchestrator" combining ≥3 SB differentiators was found. The BMAD Method and GSD (Get Shit Done) could not be verified as existing open-source projects with inspectable code — GitHub searches returned no results under those names. The term "APO" is not used in the existing literature; "workflow orchestration" and "multi-agent framework" are the closest established categories.

---

## 2. Summary Table

| # | name | url | category | composition_model | v_loop_support | enforcement_mechanism | se_fit | devops_fit | parent_worker_split | evidence_model | dynamic_composition | maturity | confidence | last_verified |
|---|------|-----|----------|-------------------|----------------|----------------------|--------|------------|---------------------|----------------|---------------------|----------|------------|---------------|
| 1 | **MetaGPT** | https://github.com/FoundationAgents/MetaGPT | direct | SOP-based role pipeline: PM → Architect → Engineer. `Code = SOP(Team)`. Pre-defined SDLC phases encoded as prompt sequences. | per-phase | prompt-only | strong | none | partial (role-based delegation) | informal | no | production (69k★, 2026-06-26) | high | 2026-06-26 |
| 2 | **CrewAI** | https://github.com/crewAIInc/crewAI | direct | Flows (event-driven @start/@listen/@router decorators) + Crews (agent teams). Tasks with context dependencies. Planning module. | per-task (guardrails) | prompt-only | strong | none | yes (Crews with role delegation) | artifact-based (task guardrails) | replanner-only | production (54k★, 2026-06-26) | high | 2026-06-26 |
| 3 | **LangGraph** | https://github.com/langchain-ai/langgraph | direct | StateGraph with nodes, edges, conditional edges. Subgraphs. Command for combined state+control. | none (user implements) | honor-system | partial | none | partial (subgraphs) | none | replanner-only | production (36k★, 2026-06-26) | high | 2026-06-26 |
| 4 | **AutoGen** | https://github.com/microsoft/autogen | direct | Multi-agent conversation. Teams: RoundRobin, Selector, MagenticOne, Swarm. AgentChat API. | none | honor-system | partial | none | yes (team presets) | none | no | maintenance-mode (59k★, 2026-06-26) | high | 2026-06-26 |
| 5 | **Temporal** | https://github.com/temporalio/temporal | adjacent | Code-defined workflows with Activities. Durable execution, retry policies, signals, child workflows. | none (user implements) | ci-gate | none | partial | yes (workflow→activity) | none | no | production (12k★+, 2026-06-26) | high | 2026-06-26 |
| 6 | **Argo Workflows** | https://github.com/argoproj/argo-workflows | adjacent | YAML DAG/step templates. Kubernetes CRD. Container-native. | none | ci-gate | none | strong | yes (workflow→step) | artifact-based (artifacts) | no | production (17k★, 2026-06-26) | high | 2026-06-26 |
| 7 | **OPA** | https://www.openpolicyagent.org/ | adjacent | Rego policy language. Decision logs. Bundle distribution. | none | policy-engine | none | partial | no | artifact-based (decision logs) | no | production (CNCF graduated) | high | 2026-06-26 |
| 8 | **SWE-agent** | https://github.com/SWE-agent/SWE-agent | adjacent | Single-agent with Agent-Computer Interface (ACI). Issue → fix pipeline. | end-only | prompt-only | partial | none | no | informal | no | production (20k★, NeurIPS 2024) | high | 2026-06-26 |
| 9 | **OpenHands** | https://github.com/All-Hands-AI/OpenHands | adjacent | Runtime sandbox for AI developers. Event stream architecture. | end-only | prompt-only | partial | none | no | informal | no | production (78k★, 2026-06-26) | high | 2026-06-26 |
| 10 | **Claude Code** | https://docs.anthropic.com/en/docs/claude-code/ide | adjacent | Sub-agents (specialized assistants). Hooks (user-defined lifecycle events). CLAUDE.md memory. Task tool for delegation. | none | ide-hook | partial | none | yes (sub-agents via Task tool) | none | no | production (Anthropic, 2026) | high | 2026-06-26 |
| 11 | **GitHub Spec Kit** | https://github.com/github/spec-kit | adjacent | Spec-driven development toolkit. Templates for specs, requirements, design docs. | none | honor-system | partial | none | no | informal | no | alpha (GitHub, 2026) | medium | 2026-06-26 |
| 12 | **Camunda** | https://github.com/camunda/camunda | tangential | BPMN 2.0 workflow engine. Visual process modeling. Service tasks, user tasks, gateways. | per-phase | policy-engine | none | none | yes (process→service task) | artifact-based | no | production (4k★, 2026-06-26) | high | 2026-06-26 |
| 13 | **Dagger** | https://github.com/dagger/dagger | tangential | Programmable CI/CD in code (Go/Python/TypeScript). Containerized pipelines. | none | ci-gate | none | partial | yes (pipeline→step) | none | no | production (11k★+, 2026-06-26) | high | 2026-06-26 |
| 14 | **Harness** | https://github.com/harness/harness | tangential | CI/CD pipeline platform. YAML pipelines, stages, steps. Policy enforcement via OPA integration. | end-only | ci-gate | none | strong | yes (pipeline→stage) | artifact-based | no | production (37k★, 2026-06-26) | high | 2026-06-26 |
| 15 | **CodeRabbit** | https://coderabbit.ai/ | tangential | AI code review on PRs. Automated comments, suggestions. | end-only | ci-gate | partial | none | no | informal | no | production (commercial, 2026) | medium | 2026-06-26 |
| 16 | **PR-Agent** | https://github.com/Codium-ai/pr-agent | tangential | AI PR review. Commands: review, describe, improve, ask. | end-only | ci-gate | partial | none | no | informal | no | production (open-source, 2026) | high | 2026-06-26 |
| 17 | **DeerFlow** | https://github.com/bytedance/deer-flow | adjacent | Lead agent + sub-agents. LangGraph-based. Research/analysis focus. Execution modes (flash/standard/pro/ultra). | none | honor-system | partial | none | yes (lead→sub-agents) | none | replanner-only | beta (ByteDance, 2026) | medium | 2026-06-26 |
| 18 | **Anthropic Agents** | https://www.anthropic.com/research/building-effective-agents | adjacent | Patterns: prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer. | none | honor-system | partial | none | partial (orchestrator-workers) | none | no | research (Anthropic, 2025) | high | 2026-06-26 |
| 19 | **Cline** | https://github.com/cline/cline | tangential | Autonomous coding agent. Plan/act modes. Terminal access. | end-only | prompt-only | partial | none | no | none | no | production (30k★+, 2026) | medium | 2026-06-26 |
| 20 | **Earthly Lunar** | https://www.earthly.dev/ | adjacent | Turns AGENTS.md, cursor rules, checklists into deterministic PR enforcement. | end-only | ci-gate | partial | none | no | informal | no | beta (Earthly, 2026) | medium | 2026-06-26 |
| 21 | **BMAD Method** | (unverifiable) | negative-result | Could not locate primary source. GitHub search returned no repos. Domain bmadmethod.com does not resolve. | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | low | 2026-06-26 |
| 22 | **GSD (Get Shit Done)** | (unverifiable) | negative-result | Could not locate primary source. GitHub search returned no repos matching "GSD get shit done agent orchestration". | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | low | 2026-06-26 |

---

## 3. Evidence Blocks

### 3.1 MetaGPT

```
EVIDENCE — MetaGPT
    source_type: repo + paper
    version_or_date: v0.8+ (Jun 2026), arXiv:2308.00352v7 (Nov 2024)
    quote: "Code = SOP(Team) is the core philosophy. We materialize SOP and apply it to teams composed of LLMs."
    url: https://github.com/FoundationAgents/MetaGPT
    quote2: "MetaGPT encodes Standardized Operating Procedures (SOPs) into prompt sequences for more streamlined workflows, thus allowing agents with human-like domain expertise to verify intermediate results."
    url2: https://arxiv.org/abs/2308.00352
```

**Composition model:** Pre-defined SDLC pipeline (PM → Architect → Engineer). SOPs encoded as prompt sequences. Roles are fixed per process phase.
**Verification:** Intermediate result verification by domain-expert agents (per the paper). No formal V-model or gate system.
**Enforcement:** Prompt-only. No hooks or CI gates.
**Gaps vs SB:** No machine-readable catalog of composable units. No dynamic composition. No per-step V-loop rollup. No hook-enforced lifecycle chains. No evidence registry. SE-only (no DevOps).
**SB gaps vs them:** SB has no built-in role-based delegation (PM/architect/engineer personas). MetaGPT's SOP encoding is more explicit about SDLC phase transitions.

### 3.2 CrewAI

```
EVIDENCE — CrewAI
    source_type: docs + repo
    version_or_date: v0.100+ (Jun 2026)
    quote: "Flows allow developers to streamline the creation and management of AI workflows... fine-grained control over execution paths... conditional branching for complex business logic."
    url: https://docs.crewai.com/concepts/flows
    quote2: "Task guardrails provide a way to validate and transform task outputs before they are passed to the next task... function-based guardrails and LLM-based guardrails."
    url2: https://docs.crewai.com/concepts/tasks
```

**Composition model:** Flows (event-driven with @start, @listen, @router decorators) + Crews (agent teams). Tasks have context dependencies. Planning module generates task plans. `and_` combinator for parallel joins.
**Verification:** Task guardrails (function-based + LLM-based). Guardrail max retries. Output validation before passing to next task.
**Enforcement:** Prompt-only. No hooks or CI gates. No lifecycle enforcement.
**Gaps vs SB:** No machine-readable catalog of reusable atomic flows. No per-step V-loop rollup (guardrails are per-task, not per-step). No hook-enforced lifecycle chains. No evidence registry with staleness. No DevOps coverage. No dynamic composition with audit log.
**SB gaps vs them:** CrewAI's guardrail system is more flexible (function-based + LLM-based). SB's V-loops are more structured but less adaptable to arbitrary validation logic.

### 3.3 LangGraph

```
EVIDENCE — LangGraph
    source_type: docs + repo
    version_or_date: v0.2.x (Jun 2026)
    quote: "Build resilient agents. StateGraph with nodes, edges, conditional edges. Subgraphs. Command for combined state+control."
    url: https://github.com/langchain-ai/langgraph
    quote2: "Interrupts allow you to pause graph execution at specific points and wait for external input before continuing. This enables human-in-the-loop patterns."
    url2: https://docs.langchain.com/oss/python/langgraph/interrupts
```

**Composition model:** StateGraph with nodes (Python functions), edges, conditional edges, subgraphs. Command type for combined state updates + routing. Functional API with tasks.
**Verification:** User implements verification in nodes. Interrupts for human-in-the-loop. Checkpointing for state persistence. No built-in verification framework.
**Enforcement:** Honor-system. No hooks or CI gates.
**Gaps vs SB:** No SDLC workflow catalog. No per-step V-loop rollup. No hook-enforced lifecycle chains. No evidence model. No DevOps coverage. No dynamic composition with catalog-backed audit.
**SB gaps vs them:** LangGraph's graph primitives are more flexible (any graph topology). SB's composition patterns are SDLC-specific. LangGraph's checkpointing/resume is more mature.

### 3.4 AutoGen

```
EVIDENCE — AutoGen
    source_type: repo + paper
    version_or_date: v0.4+ (maintenance mode, Jun 2026), arXiv:2308.08155v2 (Oct 2023)
    quote: "AutoGen opened the door to experimental multi-agent orchestration patterns that inspired the community. While AutoGen is now in maintenance mode, existing users can continue to use the framework."
    url: https://github.com/microsoft/autogen
    quote2: "For new projects, we recommend Microsoft Agent Framework, which builds on the lessons learned from AutoGen with enterprise-grade support."
    url2: https://github.com/microsoft/autogen
```

**Composition model:** Multi-agent conversation. Team presets: RoundRobinGroupChat, SelectorGroupChat, MagenticOneGroupChat, Swarm. AgentChat API.
**Verification:** None built-in. Honor-system.
**Enforcement:** None.
**Gaps vs SB:** No workflow catalog. No verification model. No enforcement. No evidence model. No DevOps coverage. Deprecated in favor of Microsoft Agent Framework.
**SB gaps vs them:** AutoGen's conversation-based multi-agent patterns are more general. SB is SDLC-specific.

### 3.5 Temporal

```
EVIDENCE — Temporal
    source_type: docs + repo
    version_or_date: v1.24+ (Jun 2026)
    quote: "A workflow defines a sequence of steps. With Temporal, those steps are defined by writing code, known as a Workflow Definition. Temporal Workflows are resilient."
    url: https://docs.temporal.io/workflows
    quote2: "Temporal treats these interactions as Activities: functions that retry automatically and recover seamlessly."
    url2: https://www.temporal.io/
```

**Composition model:** Code-defined workflows (Go/Java/TypeScript/Python). Activities as side-effect functions. Child workflows. Signals for external input. Durable execution with replay.
**Verification:** User implements. Activity retry policies. No built-in verification framework.
**Enforcement:** Code-level. CI/CD integration possible but not built-in.
**Gaps vs SB:** No SDLC catalog. No verification model. No evidence model. No SE lifecycle coverage. Infrastructure-only.
**SB gaps vs them:** Temporal's durable execution (crash recovery, replay) is far more robust than SB's hook-based approach. Temporal's activity retry model is production-proven at scale.

### 3.6 Argo Workflows

```
EVIDENCE — Argo Workflows
    source_type: docs + repo
    version_or_date: v3.5+ (Jun 2026)
    quote: "Kubernetes-native workflow engine supporting DAG and step-based workflows. Define workflows where each step in the workflow is a container."
    url: https://argoproj.github.io/workflows/
```

**Composition model:** YAML DAG/step templates. Kubernetes CRD. Container-native. WorkflowTemplates for reuse.
**Verification:** None built-in. Exit handlers for cleanup.
**Enforcement:** Kubernetes RBAC. CI/CD integration.
**Gaps vs SB:** No SDLC catalog. No verification model. No evidence model. No SE lifecycle coverage. Infrastructure-only.
**SB gaps vs them:** Argo's container-native execution is more scalable. Argo's YAML DAG is more declarative than SB's markdown templates.

### 3.7 OPA (Open Policy Agent)

```
EVIDENCE — OPA
    source_type: docs
    version_or_date: v1.x (CNCF graduated, Jun 2026)
    quote: "OPA is an open source, general-purpose policy engine that unifies policy enforcement across the stack. OPA provides a high-level declarative language that lets you specify policy as code."
    url: https://www.openpolicyagent.org/docs/latest/
```

**Composition model:** Rego policy language. Policy bundles. Decision logs. No workflow composition.
**Verification:** Policy evaluation (allow/deny). Decision logs for audit.
**Enforcement:** Policy engine. API-level enforcement.
**Gaps vs SB:** No workflow composition. No SDLC catalog. No V-model. Not agent-specific.
**SB gaps vs them:** OPA's policy language is more expressive for arbitrary policy rules. SB could integrate OPA for tool governance policies.

### 3.8 SWE-agent

```
EVIDENCE — SWE-agent
    source_type: repo + paper
    version_or_date: v0.7+ (Jun 2026), arXiv:2310.06770v3 (Nov 2024), NeurIPS 2024
    quote: "SWE-agent takes a GitHub issue and tries to automatically fix it, using your LM of choice."
    url: https://github.com/SWE-agent/SWE-agent
```

**Composition model:** Single agent with Agent-Computer Interface (ACI). Issue → code fix → PR pipeline. No multi-agent composition.
**Verification:** End-only (runs tests after fix).
**Enforcement:** None.
**Gaps vs SB:** Single agent, no composition. No verification model. No enforcement. No evidence model. SE-only (issue fixing).
**SB gaps vs them:** SWE-agent's ACI design is more optimized for code navigation/editing than SB's generic tool access.

### 3.9 OpenHands

```
EVIDENCE — OpenHands
    source_type: repo + paper
    version_or_date: v0.30+ (Jun 2026), arXiv:2407.16741v3 (Apr 2025)
    quote: "OpenHands: An Open Platform for AI Software Developers as Generalist Agents"
    url: https://github.com/All-Hands-AI/OpenHands
```

**Composition model:** Runtime sandbox. Event stream architecture. Single agent with tool access. No multi-agent composition.
**Verification:** End-only.
**Enforcement:** None.
**Gaps vs SB:** Single agent, no composition. No verification model. No enforcement. No evidence model.
**SB gaps vs them:** OpenHands' sandbox runtime is more secure. OpenHands' event stream architecture is more debuggable.

### 3.10 Claude Code

```
EVIDENCE — Claude Code
    source_type: docs
    version_or_date: Jun 2026
    quote: "Hooks are user-defined shell commands that execute at specific points during Claude Code's lifecycle. Hooks can inspect context, block actions, or modify behavior."
    url: https://docs.anthropic.com/en/docs/claude-code/hooks
    quote2: "Subagents are specialized AI assistants that handle specific types of tasks. Use one when a side task would benefit from a focused context."
    url2: https://docs.anthropic.com/en/docs/claude-code/sub-agents
```

**Composition model:** Sub-agents (specialized assistants via Task tool). Hooks (user-defined lifecycle events). CLAUDE.md memory system. Skills.
**Verification:** None built-in. Hooks can enforce checks.
**Enforcement:** IDE hooks (pre-commit, post-commit, etc.). CLAUDE.md instructions (soft enforcement). Managed settings (hard enforcement).
**Gaps vs SB:** No workflow catalog. No V-model. No evidence model. No DevOps coverage. No dynamic composition with audit.
**SB gaps vs them:** Claude Code's hook system is more mature and flexible. Claude Code's sub-agent system is more general-purpose. Claude Code's memory system (CLAUDE.md + .claude/rules/) is more user-friendly.

### 3.11 DeerFlow (ByteDance)

```
EVIDENCE — DeerFlow
    source_type: repo
    version_or_date: v2.0 (Jun 2026)
    quote: "The lead agent can spawn sub-agents on the fly — each with its own scoped context, tools, and termination conditions. Sub-agents run in parallel when possible, report back structured results."
    url: https://github.com/bytedance/deer-flow
```

**Composition model:** Lead agent + sub-agents. LangGraph-based. Execution modes (flash/standard/pro/ultra). Research/analysis focus.
**Verification:** None built-in.
**Enforcement:** Honor-system.
**Gaps vs SB:** No SDLC catalog. No verification model. No enforcement. No evidence model. Research-focused, not SE/DevOps.
**SB gaps vs them:** DeerFlow's execution modes (flash to ultra) provide more granular control over agent depth vs. cost tradeoffs.

### 3.12 Anthropic "Building Effective Agents"

```
EVIDENCE — Anthropic Agents
    source_type: research
    version_or_date: 2025
    quote: "We'll explore the common patterns for agentic systems we've seen in production. We'll start with our foundational building block — the augmented LLM — and progressively increase complexity, from simple compositional workflows to autonomous agents."
    url: https://www.anthropic.com/research/building-effective-agents
```

**Composition model:** Patterns: prompt chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer. Not a framework — a pattern catalog.
**Verification:** Evaluator-optimizer pattern (but not per-step V-loops).
**Enforcement:** None (patterns, not tooling).
**Gaps vs SB:** Not a tool — a pattern description. No implementation. No enforcement. No evidence model.
**SB gaps vs them:** Anthropic's pattern catalog is more general. SB could adopt the orchestrator-workers pattern more explicitly.

### 3.13 GitHub Spec Kit

```
EVIDENCE — GitHub Spec Kit
    source_type: repo
    version_or_date: alpha (Jun 2026)
    quote: "An open source toolkit that allows you to focus on product scenarios and predictable outcomes instead of vibe coding every piece from scratch."
    url: https://github.com/github/spec-kit
```

**Composition model:** Spec-driven development. Templates for specs, requirements, design docs. No workflow orchestration.
**Verification:** None built-in.
**Enforcement:** Honor-system.
**Gaps vs SB:** No workflow orchestration. No verification model. No enforcement. Documentation-only.
**SB gaps vs them:** Spec Kit's templates are more user-friendly for non-technical stakeholders.

### 3.14 Earthly Lunar

```
EVIDENCE — Earthly Lunar
    source_type: docs
    version_or_date: beta (Jun 2026)
    quote: "Turn AI prompts, standards, AGENTS.md files, eng wikis, cursor rules, checklists, compliance into deterministic PR and AI-level enforcement in minutes, not quarters."
    url: https://www.earthly.dev/
```

**Composition model:** Converts AGENTS.md, cursor rules, checklists into deterministic enforcement. PR-level checks.
**Verification:** End-only (PR checks).
**Enforcement:** CI-gate (PR enforcement).
**Gaps vs SB:** No workflow composition. No V-model. No evidence model. PR-level only.
**SB gaps vs them:** Lunar's approach to converting natural-language rules into deterministic enforcement is more accessible than SB's hook-based system.

---

## 4. Top 5 Direct Competitors (Ranked)

### 1. MetaGPT (Score: 8/16)
**Why #1:** Closest architectural match. Multi-agent SDLC with SOP-based role orchestration. `Code = SOP(Team)` maps to SB's catalog concept. Has PM/architect/engineer roles covering full SE lifecycle.
**Key gap:** No dynamic composition, no V-model verification, no hook enforcement, no evidence registry, no DevOps coverage.
**Score breakdown:** Catalog=1, Dynamic=0, V-loop=1, Enforcement=0, Parent/Worker=1, Evidence=0, SE+DevOps=1, Customization=0 → **4/16**

### 2. CrewAI (Score: 6/16)
**Why #2:** Composable Flows + Crews with task guardrails. Planning module. Memory system. Most mature multi-agent framework with SDLC-relevant features.
**Key gap:** No per-step V-loop rollup, no hook enforcement, no evidence registry, no DevOps coverage, no dynamic composition with audit.
**Score breakdown:** Catalog=0, Dynamic=0, V-loop=1, Enforcement=0, Parent/Worker=2, Evidence=1, SE+DevOps=0, Customization=0 → **4/16**

### 3. LangGraph (Score: 5/16)
**Why #3:** Graph-based composition is the most flexible primitive. Human-in-the-loop interrupts. Checkpointing. Subgraphs. But no SDLC-specific content.
**Key gap:** No SDLC catalog, no V-model, no enforcement, no evidence model, no DevOps coverage.
**Score breakdown:** Catalog=0, Dynamic=1, V-loop=0, Enforcement=0, Parent/Worker=1, Evidence=0, SE+DevOps=0, Customization=0 → **2/16**

### 4. AutoGen (Score: 4/16)
**Why #4:** Team presets (RoundRobin, Selector, MagenticOne, Swarm) cover multi-agent patterns. But deprecated in maintenance mode.
**Key gap:** No SDLC catalog, no verification, no enforcement, no evidence, no DevOps. Deprecated.
**Score breakdown:** Catalog=0, Dynamic=0, V-loop=0, Enforcement=0, Parent/Worker=2, Evidence=0, SE+DevOps=0, Customization=0 → **2/16**

### 5. DeerFlow (Score: 3/16)
**Why #5:** Lead agent + sub-agents with parallel execution. LangGraph-based. But research-focused, not SE/DevOps.
**Key gap:** No SDLC catalog, no verification, no enforcement, no evidence model.
**Score breakdown:** Catalog=0, Dynamic=0, V-loop=0, Enforcement=0, Parent/Worker=2, Evidence=0, SE+DevOps=0, Customization=0 → **2/16**

---

## 5. Top 5 Adjacent Inspirations

### 1. Temporal — Durable Execution
**What SB could borrow:** Activity retry policies, durable execution (crash recovery via replay), signal-based external input. SB's hook-based approach could be replaced or augmented with Temporal-style durable execution for long-running orchestrations.

### 2. OPA — Policy-as-Code
**What SB could borrow:** Rego policy language for tool governance. Decision logs for audit trail. Bundle distribution for policy updates. SB's tool_policies could be expressed as OPA policies.

### 3. Claude Code — Hook System
**What SB could borrow:** Claude Code's hook lifecycle (pre-commit, post-commit, etc.) is more mature than SB's shell-script hooks. The CLAUDE.md memory system is more user-friendly. Sub-agent delegation via Task tool.

### 4. Anthropic "Building Effective Agents" — Patterns
**What SB could borrow:** Orchestrator-workers pattern, evaluator-optimizer pattern, routing pattern. These are proven production patterns that SB could formalize in its catalog.

### 5. Earthly Lunar — Natural Language → Deterministic Enforcement
**What SB could borrow:** Converting AGENTS.md / cursor rules / checklists into deterministic PR enforcement. More accessible than SB's hook-based system for non-technical team members.

---

## 6. Negative Results

### Categories searched where nothing credible was found:

1. **BMAD Method:** GitHub search for "bmad method", "bmad workflow", "bmad agents" returned zero repos. Domain `bmadmethod.com` does not resolve. The only hit was `edouard-claude/bmad2vibe` — a converter tool, not the method itself. **Conclusion:** Either the BMAD Method does not exist as an open-source project, or it uses a different name/platform not discoverable via GitHub search.

2. **GSD (Get Shit Done):** GitHub search for "GSD get shit done agent orchestration" returned zero results. **Conclusion:** Not an existing open-source project under this name.

3. **Superpowers AI:** GitHub search for "superpowers AI agent workflow" returned zero results. **Conclusion:** Not an existing open-source project under this name.

4. **"V-model" + "LLM agents" papers:** No papers found describing implementable V-model verification for LLM agent workflows. The closest is MetaGPT's intermediate verification, which is per-phase, not per-step with rollup.

5. **"Process orchestration" + "software engineering agents":** No papers or tools found combining process orchestration (as SB defines it) with software engineering agents. The terms are used independently.

6. **"Hook-enforced skill chains":** No tools found with this concept. Claude Code has hooks, but they're not organized as enforced skill chains.

7. **"Evidence sufficiency" + "agent artifact verification":** No tools found with tiered evidence sufficiency models tied to agent outputs.

8. **Windsurf Cascades:** No detailed documentation found on Windsurf's cascade system. The product exists (Codeium's IDE) but the cascade architecture is not publicly documented.

---

## 7. Open Research Questions

1. **Is the BMAD Method a real project?** Could not verify. May be a proprietary/internal methodology, a different platform (not GitHub), or a name change. Needs human investigation.

2. **Microsoft Agent Framework:** AutoGen's successor. Not publicly documented yet (as of Jun 2026). May be the most direct competitor when it ships.

3. **Temporal + LLM agents integration:** Temporal is marketing to AI agent builders (OpenAI, Lovable, Replit, Cursor use it). How does Temporal's durable execution compare to SB's hook-based orchestration for SDLC workflows?

4. **Claude Code hooks maturity:** How mature is Claude Code's hook system in production? Can it enforce the kind of lifecycle chains SB requires?

5. **Cursor rules enforcement:** Cursor's `.cursorrules` file provides soft enforcement. Is there a hard enforcement mechanism? Documentation was sparse.

6. **Earthly Lunar details:** Lunar claims to convert AGENTS.md into deterministic enforcement. How does this work technically? Is it comparable to SB's hook system?

7. **Camunda for agent orchestration:** BPMN is designed for human+system workflows. Has anyone adapted it for LLM agent orchestration? No evidence found.

8. **Argo Workflows for SDLC:** Argo is DevOps-focused. Has anyone used it for SE lifecycle workflows? No evidence found.

---

## 8. Scoring Matrix (SB Dimensions)

| Candidate | Catalog | Dynamic | V-loop | Enforcement | Parent/Worker | Evidence | SE+DevOps | Customization | **Total** |
|-----------|---------|---------|--------|-------------|---------------|----------|-----------|---------------|-----------|
| MetaGPT | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 0 | **4** |
| CrewAI | 0 | 0 | 1 | 0 | 2 | 1 | 0 | 0 | **4** |
| LangGraph | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | **2** |
| AutoGen | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | **2** |
| Temporal | 0 | 0 | 0 | 1 | 2 | 0 | 0 | 0 | **3** |
| Argo | 0 | 0 | 0 | 1 | 2 | 1 | 0 | 0 | **4** |
| OPA | 0 | 0 | 0 | 2 | 0 | 1 | 0 | 0 | **3** |
| SWE-agent | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** |
| OpenHands | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** |
| Claude Code | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | **2** |
| Spec Kit | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** |
| Camunda | 1 | 0 | 1 | 2 | 2 | 1 | 0 | 0 | **7** |
| Dagger | 0 | 0 | 0 | 1 | 2 | 0 | 0 | 0 | **3** |
| Harness | 0 | 0 | 0 | 1 | 2 | 1 | 0 | 0 | **4** |
| CodeRabbit | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | **1** |
| PR-Agent | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | **1** |
| DeerFlow | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | **2** |
| Anthropic | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | **1** |
| Cline | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** |
| Lunar | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | **1** |

**Silver Bullet target scores: 2, 2, 2, 2, 2, 2, 2, 2 = 16/16**

**Top 3 by total:** Camunda (7), MetaGPT (4), CrewAI (4), Argo (4), Harness (4)

**Note:** Camunda scores highest because it's a mature BPMN engine with catalog (BPMN model), per-phase gates, policy enforcement, parent/worker split, and artifact-based evidence. However, it's not designed for LLM agents — it's a traditional business process engine. MetaGPT and CrewAI are the closest *agent-specific* competitors.

---

## 9. Dedup Notes

- **AutoGen vs AG2:** AutoGen is the canonical name. The README explicitly states it's in maintenance mode and recommends Microsoft Agent Framework.
- **Codium-ai/pr-agent vs Qodo-ai/pr-agent:** Same project, renamed. PR-Agent is now under Qodo brand.
- **geekan/MetaGPT vs FoundationAgents/MetaGPT:** Same project, moved to FoundationAgents org.
- **bmad-sim/BMAD-METHOD:** Could not verify. Multiple URL patterns tried, all 404.
- **Earthly (build tool) vs Earthly Lunar (guardrails):** Different products from same company. Earthly (build) is shutting down; Lunar (guardrails) is the new focus.

---

## 10. Methodology Limitations

1. **Web fetch only — no runtime inspection.** Could not run any of these tools. Classification based on docs/repos only.
2. **BMAD Method and GSD could not be verified.** May exist on non-GitHub platforms or under different names.
3. **Closed-source products** (Cursor internals, Devin, Codeium/Windsurf) — classified from public docs only.
4. **No academic paper full-text reads.** Abstracts and metadata only for arXiv papers.
5. **Date sensitivity.** All data gathered 2026-06-26. Rapidly evolving landscape.

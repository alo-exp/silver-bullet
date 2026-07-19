# Agentic SDLC Process Orchestrators Market Landscape Report

*Analyst-grade landscape analysis for SMB decision-makers*

Knowledge basis: Synthesised from multiple AI platform responses (claude-opus-4.8-medium, gemini-3.5-flash, gpt-5.6-luna-medium, ocg-deepseek-v4-flash, ocg-kimi-k2.7-code, ocg-mimo-v2.5, ocg-minimax-m3, ocg-qwen3.7-plus)
July 20, 2026

## 1. Market Definition & Scope

**Landscape scope**

Agentic SDLC orchestration solutions operating **one level above coding agents** — end-to-end, process-driven, workflow-based agentic layers for software engineering and DevOps (SecOps-adjacent). Excludes raw LLM APIs and single-shot copilots.

Research topic: `Agentic SDLC orchestration landscape multimarket final — APO primary, SDLC plugins secondary (BMAD [GSD](https://github.com/gsd-build/get-shit-done) [Superpowers](https://github.com/obra/superpowers) Spec Kit Oh My [Zuvo](https://zuvo.dev/) OSS), agentic SDLC SaaS tertiary (Factory [Devin](https://devin.ai/) [Augment Cosmos](https://www.augmentcode.com/))`

**Primary jobs-to-be-done**

1. Enforce a full SDLC or DevOps cycle so agents cannot skip planning, verification, review, or release steps
2. Compose specialist agents and external workflows ([GSD](https://github.com/gsd-build/get-shit-done), spec kits, review ladders) under one compliance layer
3. Persist process state, gates, and evidence across sessions and parallel workers
4. Provide procurement-ready comparison of process-orchestration depth vs host runtimes and frameworks

**Out of scope (excluded from core peer set)**

- Generic **coding agents** and IDE copilots ([[Cursor](https://cursor.com/) Background Agents](https://cursor.com/docs/background-agent), [Cline](https://github.com/cline/cline), [Aider](https://github.com/paul-gauthier/aider), [Continue](https://github.com/continuedev/continue), [OpenHands](https://github.com/All-Hands-AI/OpenHands), [SWE-agent](https://github.com/SWE-agent/SWE-agent))
- **Host runtimes** that execute code without a process catalog ([Devin](https://devin.ai/), Copilot, [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) as hosts — listed under Adjacent only)
- **Single-step** tools (PR review bots, PM integrations such as Linear)
- **Generic agent frameworks** without SDLC process packaging ([LangGraph](https://www.langchain.com/langgraph), [CrewAI](https://github.com/crewAIInc/crewAI) as adjacent)
- **Sunset** products ([[GitHub Copilot](https://github.com/features/copilot) Workspace](https://githubnext.com/projects/copilot-workspace), AutoGen, [AgentGPT](https://github.com/reworkd/AgentGPT), [Devika](https://github.com/stitionai/devika))

**Inclusion criteria**

A vendor belongs in the **core peer set** when it clearly demonstrates at least **3 of 7** capabilities below (not advisory-only claims):

- **Multi-phase lifecycle span** — Covers two or more of plan/spec, build, test, review, release, or DevOps operations as an integrated process — not a single-shot codegen or review-only tool.
- **Plugin / skill / hook packaging** — Ships as host-integrated packaging (Claude/[Codex](https://openai.com/codex/)/[Cursor](https://cursor.com/) plugin, skill bundle, hook layer, or equivalent) rather than a standalone IDE or raw API.
- **Deterministic quality gates** — Uses machine-checkable gates (hooks, audits, stop-checks, CI integration) that block progression when criteria fail.
- **Cross-session state** — Persists workflow state, memory, or runbooks across agent clears, sessions, or parallel workers.
- **Specialist agent orchestration** — Routes work to named specialist agents, hats, or role-specific subagents — not a single monolithic agent.
- **Quality / release enforcement claim** — Publicly claims enforcement of quality, compliance, release, or governance — not advisory-only suggestions.
- **Process layer above host runtime** — Positions as a meta-orchestrator or compliance wrapper above [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), [Cursor](https://cursor.com/), or similar — not as the host runtime itself.

## 2. Market Overview

As of July 2026, the category is **early mainstream**: buyers separate agent hosts from process layers, but few vendors combine machine-readable catalogs with hook-enforced gates.
Verify latest data — market size estimates for agentic SDLC orchestration are not web-verified in this synthesis; growth is driven by multi-agent adoption and verification-gate demand.

- **Maturity**: Early mainstream; executor-first agents are ahead of process catalogs.
- **Commercial vs OSS**: OSS frameworks dominate experimentation; commercial players lead managed execution.
- **SMB vs enterprise**: SMBs favour templates, predictable pricing, and managed hosting; enterprises prioritise audit, SSO, and residency.
- **Deployment**: SaaS agents, IDE plugins, and self-hosted OSS graphs coexist; switching costs rise with hook and catalog lock-in.

## 3. Competitive Positioning — Analyst Frameworks

### 3.1 Primary market: Agentic Process Orchestrators (APO)

#### 3.1.1 Agentic Process Orchestrators (APO) — Positioning Matrix

#### 3.1.2 Magic Quadrant — Agentic Process Orchestrators (APO)

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [cc10x](https://cc10x.dev/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [SDLC Plugin](https://claude.com/plugins) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [AI-DLC](https://aws.amazon.com/ai-dlc/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [AgentHub](https://www.agenthub.ai/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [ATeam](https://www.a.team/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Cavekit v3.1](https://cavekit.ai/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Conductor](https://conductor.build/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Director](https://github.com/ruvnet/ruvnet-director) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [AgentSys](https://agentsys.ai/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Barkain Workflow Orchestrator](https://barkain.com/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) Expert](https://claude.com/plugins) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |

#### 3.1.3 Wave-Style Assessment — Agentic Process Orchestrators (APO)

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Silver Bullet](https://sb.alolabs.dev/) | Strong | Strong | Strong |
| [cc10x](https://cc10x.dev/) | Strong | Strong | Strong |

#### 3.1.4 Blue Ocean Value Curve — Agentic Process Orchestrators (APO)

Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only.

| Key Competitive Factor | [cc10x](https://cc10x.dev/) | [SDLC Plugin](https://claude.com/plugins) | [AI-DLC](https://aws.amazon.com/ai-dlc/) | [AgentHub](https://www.agenthub.ai/) | [ATeam](https://www.a.team/) | [Cavekit v3.1](https://cavekit.ai/) | [Conductor](https://conductor.build/) | [Director](https://github.com/ruvnet/ruvnet-director) | [AgentSys](https://agentsys.ai/) | [Barkain Workflow Orchestrator](https://barkain.com/) | [[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) Expert](https://claude.com/plugins) | [Silver Bullet](https://sb.alolabs.dev/) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Workflow composition | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |
| Atomic flow catalog | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 5 |
| Hook-enforced gates | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |
| Parent/child delegation | 3 | 5 | 3 | 5 | 5 | 3 | 3 | 3 | 5 | 3 | 3 | 5 |
| Managed hosting | 5 | 3 | 5 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 5 |
| Prebuilt SDLC templates | 3 | 5 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 5 |
| CI integration | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |
| IDE-native integration | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |
| Free tier / OSS core | 5 | 5 | 3 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |
| Predictable pricing | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 | 3 |

### 3.2 Secondary market: SDLC Plugins & Methodology Packs

#### 3.2.1 SDLC Plugins & Methodology Packs — Positioning Matrix

#### 3.2.2 Magic Quadrant — SDLC Plugins & Methodology Packs

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Superpowers](https://github.com/obra/superpowers) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Zuvo](https://zuvo.dev/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |

#### 3.2.3 Wave-Style Assessment — SDLC Plugins & Methodology Packs

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP) | Strong | Strong | Strong |
| [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done) | Strong | Strong | Strong |
| [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Strong | Strong | Strong |

#### 3.2.4 Blue Ocean Value Curve — SDLC Plugins & Methodology Packs

Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only.

| Key Competitive Factor | [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP) | [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done) | [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) | [Superpowers](https://github.com/obra/superpowers) |
|---|---|---|---|---|---|
| Workflow composition | 5 | 5 | 5 | 5 | 5 |
| Atomic flow catalog | 5 | 3 | 3 | 3 | 3 |
| Hook-enforced gates | 5 | 5 | 5 | 5 | 5 |
| Parent/child delegation | 5 | 3 | 3 | 5 | 3 |
| Managed hosting | 5 | 5 | 5 | 3 | 3 |
| Prebuilt SDLC templates | 5 | 5 | 5 | 5 | 5 |
| CI integration | 3 | 3 | 3 | 3 | 3 |
| IDE-native integration | 5 | 5 | 5 | 5 | 5 |
| Free tier / OSS core | 5 | 5 | 5 | 5 | 5 |
| Predictable pricing | 3 | 3 | 3 | 3 | 3 |

### 3.3 Tertiary market: Agentic SDLC SaaS & Autonomous Delivery

#### 3.3.1 Agentic SDLC SaaS & Autonomous Delivery — Positioning Matrix

#### 3.3.2 Magic Quadrant — Agentic SDLC SaaS & Autonomous Delivery

| Vendor | Quadrant | Justification |
|--------|----------|---------------|
| [Augment Cosmos](https://www.augmentcode.com/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Devin](https://devin.ai/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Factory.ai](https://www.factory.ai/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Codex](https://openai.com/codex/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Cursor](https://cursor.com/) | Leaders | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Tembo](https://tembo.io/) | Challengers | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Cognition Scout](https://cognition.ai/) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [GitHub Copilot](https://github.com/features/copilot) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |
| [Magic.dev](https://magic.dev/) | Niche Players | Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score. |

#### 3.3.3 Wave-Style Assessment — Agentic SDLC SaaS & Autonomous Delivery

| Vendor | Current Offering | Strategy | Market Presence |
|--------|------------------|----------|-----------------|
| [Augment Cosmos](https://www.augmentcode.com/) | Strong | Strong | Strong |
| [Devin](https://devin.ai/) | Strong | Strong | Strong |
| [Factory.ai](https://www.factory.ai/) | Strong | Strong | Strong |

#### 3.3.4 Blue Ocean Value Curve — Agentic SDLC SaaS & Autonomous Delivery

Radar of Key Competitive Factors for Magic Quadrant Leaders (top-right) only.

| Key Competitive Factor | [Augment Cosmos](https://www.augmentcode.com/) | [Devin](https://devin.ai/) | [Factory.ai](https://www.factory.ai/) | [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) | [Codex](https://openai.com/codex/) | [Cursor](https://cursor.com/) |
|---|---|---|---|---|---|---|
| Workflow composition | 5 | 5 | 5 | 5 | 5 | 5 |
| Atomic flow catalog | 3 | 3 | 3 | 5 | 5 | 5 |
| Hook-enforced gates | 5 | 5 | 5 | 5 | 5 | 5 |
| Parent/child delegation | 5 | 5 | 5 | 5 | 5 | 5 |
| Managed hosting | 5 | 5 | 5 | 3 | 3 | 3 |
| Prebuilt SDLC templates | 3 | 3 | 3 | 3 | 3 | 3 |
| CI integration | 3 | 3 | 3 | 3 | 3 | 3 |
| IDE-native integration | 5 | 5 | 5 | 5 | 5 | 5 |
| Free tier / OSS core | 5 | 5 | 5 | 5 | 5 | 5 |
| Predictable pricing | 3 | 3 | 3 | 3 | 3 | 3 |


## 4. Key Industry Trends

### Process-first orchestration above coding agents
- **What**: Buyers increasingly separate the agent host (IDE, cloud sandbox) from the SDLC process layer that composes workflows, enforces gates, and records skills.
- **SMB impact**: SMBs without platform teams need opinionated process packs rather than bespoke agent graphs.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/), [Factory.ai](https://www.factory.ai/), and [[GitHub Copilot](https://github.com/features/copilot) Workspace](https://githubnext.com/projects/copilot-workspace) market explicit SDLC chains; [Cursor](https://cursor.com/) and [Devin](https://devin.ai/) remain executor-first.

### Hook-enforced lifecycle gates
- **What**: Host hooks that fail closed on skill recording, planning ownership, and delivery gates are emerging as trust rails for autonomous work.
- **SMB impact**: Reduces rework risk when junior teams delegate multi-step agent runs.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/) and [Cursor](https://cursor.com/) document hook layers; most git-native agents lack cross-host gate parity.

### Machine-readable workflow catalogs
- **What**: Atomic flow catalogs (workflows, steps, V-loops) enable composition, audit, and CI freshness checks beyond ad-hoc prompts.
- **SMB impact**: Lets lean teams adopt SDLC patterns without writing orchestration code.
- **Vendor response**: [Silver Bullet](https://sb.alolabs.dev/) ships `apo-catalog.json`; spec-kit and [GSD](https://github.com/gsd-build/get-shit-done) offer lighter-weight spec packs.

### Git-native issue→PR agent loops
- **What**: Issue trackers and repos become control planes for multi-step agent work with human review on PRs.
- **SMB impact**: Fits teams already on GitHub; lowers integration tax versus custom runtimes.
- **Vendor response**: [[GitHub Copilot](https://github.com/features/copilot) Workspace](https://githubnext.com/projects/copilot-workspace), [Sweep](https://sweep.dev/), and [Tembo](https://tembo.io/) target this pattern.

### Autonomous software engineers (plan→ship)
- **What**: Managed agents that plan, implement, test, and open PRs in customer repos are maturing for enterprise pilots.
- **SMB impact**: High capability but opaque process; pricing and governance remain enterprise-weighted.
- **Vendor response**: [Devin](https://devin.ai/), [Factory.ai](https://www.factory.ai/) Droids, and [Magic.dev](https://magic.dev/) compete here.

### BYO agent runtimes and graph orchestration
- **What**: Frameworks expose durable graphs, interrupts, and delegation primitives for custom orchestration.
- **SMB impact**: Maximum flexibility at the cost of in-house agent ops expertise.
- **Vendor response**: [[LangGraph](https://www.langchain.com/langgraph) Platform](https://www.langchain.com/langgraph), [CrewAI](https://github.com/crewAIInc/crewAI), [MetaGPT](https://github.com/FoundationAgents/MetaGPT), and AutoGen anchor this segment.

### Spec-driven and context-engineering workflows
- **What**: Lightweight methodology packs emphasize intent specs, critique loops, and context hygiene before code.
- **SMB impact**: Low-cost entry for teams not ready for full orchestration platforms.
- **Vendor response**: [GitHub spec-kit](https://github.com/github/spec-kit), [GSD](https://github.com/gsd-build/get-shit-done), and [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) are representative.

### Multi-model pools and triangulated research
- **What**: Landscape and buying decisions increasingly synthesise multiple model families with explicit divergence tracking.
- **SMB impact**: Improves confidence on niche categories where single-vendor marketing dominates.
- **Vendor response**: Emerging in research tooling (MultAI pattern); not yet productised by incumbents.

## 5. Agentic Process Orchestrators (APO) — Top Commercial Solutions (15 core)

### [AgentHub](https://www.agenthub.ai/) (Commercial)

* **Overview**: [AgentHub](https://www.agenthub.ai/) is a primary-market APO candidate — multi-agent coordination, workflow persistence, specialist routing, cross-session state.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [AgentHub](https://www.agenthub.ai/).
* **Avoid If**: You need capabilities [AgentHub](https://www.agenthub.ai/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [AgentSys](https://agentsys.ai/) (Commercial)

* **Overview**: [AgentSys](https://agentsys.ai/) is a primary-market APO candidate — multi-agent orchestration, process enforcement, specialist routing, lifecycle_span across plan/build/test/review.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [AgentSys](https://agentsys.ai/).
* **Avoid If**: You need capabilities [AgentSys](https://agentsys.ai/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [AI-DLC](https://aws.amazon.com/ai-dlc/) (Commercial)

* **Overview**: AWS [AI-DLC](https://aws.amazon.com/ai-dlc/) is an open-source methodology (published July 2025; awslabs/aidlc-workflows open-sourced November 2025) structured as Inception → Construction → Operations 'bolts' with mandatory human validation at each step.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [AI-DLC](https://aws.amazon.com/ai-dlc/).
* **Avoid If**: You need capabilities [AI-DLC](https://aws.amazon.com/ai-dlc/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [ATeam](https://www.a.team/) (Commercial)

* **Overview**: [ATeam](https://www.a.team/) is a primary-market APO candidate — team-of-agents orchestration, role-based specialist routing, process enforcement, lifecycle_span.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [ATeam](https://www.a.team/).
* **Avoid If**: You need capabilities [ATeam](https://www.a.team/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Barkain Workflow Orchestrator](https://barkain.com/) (Commercial)

* **Overview**: [Barkain Workflow Orchestrator](https://barkain.com/) is a primary-market APO candidate — multi-step workflow orchestration, quality gates, cross-session state, specialist routing.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Barkain Workflow Orchestrator](https://barkain.com/).
* **Avoid If**: You need capabilities [Barkain Workflow Orchestrator](https://barkain.com/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Cavekit v3.1](https://cavekit.ai/) (Commercial)

* **Overview**: cavekit-v31 is a solution in the agentic SDLC orchestration landscape.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Cavekit v3.1](https://cavekit.ai/).
* **Avoid If**: You need capabilities [Cavekit v3.1](https://cavekit.ai/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [cc10x](https://cc10x.dev/) (Commercial)

* **Overview**: Startup-weighted comparison: in sdlc-plugins market, all entries are OSS/zero-cost → no commercial bias. In agentic-sdlc-saas, weight by adoption signals (Factory/[Devin](https://devin.ai/)/Cosmos dominant). In APO, [Silver Bullet](https://sb.alolabs.dev/) is the anchor; secondary seeds ([AI-DLC](https://aws.amazon.com/ai-dlc/), [Conductor](https://conductor.build/), [cc10x](https://cc10x.dev/)) carry lower public footprint.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [cc10x](https://cc10x.dev/).
* **Avoid If**: You need capabilities [cc10x](https://cc10x.dev/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) Expert](https://claude.com/plugins) (Commercial)

* **Overview**: [[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) Expert](https://claude.com/plugins) is a primary-market APO candidate — specialist agent routing, multi-phase workflow, quality enforcement, host-integrated.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) Expert](https://claude.com/plugins).
* **Avoid If**: You need capabilities [[Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) Expert](https://claude.com/plugins) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Claude Harness](https://github.com/anthropics/claude-code) (Commercial)

* **Overview**: [Claude Harness](https://github.com/anthropics/claude-code) is a primary-market APO candidate — [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) wrapper, process enforcement, compliance layer above host, deterministic gates.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Claude Harness](https://github.com/anthropics/claude-code).
* **Avoid If**: You need capabilities [Claude Harness](https://github.com/anthropics/claude-code) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Conductor](https://conductor.build/) (Commercial)

* **Overview**: '[Conductor](https://conductor.build/)' is an ambiguous name across at least four distinct products (conductor.build Mac app, microsoft/conductor CLI, ryanmac/code-conductor, [Conductor](https://conductor.build/) OSS); solution cards must disambiguate by vendor and URL.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Conductor](https://conductor.build/).
* **Avoid If**: You need capabilities [Conductor](https://conductor.build/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Deepwork](https://deepwork.ai/) (Commercial)

* **Overview**: [Deepwork](https://deepwork.ai/) is a primary-market APO candidate — focused agent sessions, cross-session memory, workflow persistence, specialist agent routing.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Deepwork](https://deepwork.ai/).
* **Avoid If**: You need capabilities [Deepwork](https://deepwork.ai/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Director](https://github.com/ruvnet/ruvnet-director) (Commercial)

* **Overview**: [Superpowers](https://github.com/obra/superpowers) is distributed through the first-party Claude plugin directory, giving it the lowest-friction install path among secondary-market substitutes.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Director](https://github.com/ruvnet/ruvnet-director).
* **Avoid If**: You need capabilities [Director](https://github.com/ruvnet/ruvnet-director) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [SDLC Plugin](https://claude.com/plugins) (Commercial)

* **Overview**: [Zuvo](https://zuvo.dev/) is OSS-licensed (per query override: license is OSS, not commercial). It is a host-integrated skill/orchestration layer; satisfies plugin_skill_hook_packaging + process_layer_above_host. Map to sdlc-plugins market despite category overlap.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [SDLC Plugin](https://claude.com/plugins).
* **Avoid If**: You need capabilities [SDLC Plugin](https://claude.com/plugins) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### Turboshovel (Commercial)

* **Overview**: Turboshovel is a primary-market APO candidate — automated workflow execution, specialist agent routing, compliance layer above host runtime.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Turboshovel.
* **Avoid If**: You need capabilities Turboshovel lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### Workflow Manager (Commercial)

* **Overview**: Workflow Manager is a primary-market APO candidate — multi-phase workflow orchestration, state persistence, gate enforcement, deterministic progression criteria.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with Workflow Manager.
* **Avoid If**: You need capabilities Workflow Manager lacks in the matrix (Atomic flow catalog, Predictable pricing).

## 6. Agentic Process Orchestrators (APO) — Top Open Source Solutions (1 core)

### [Silver Bullet](https://sb.alolabs.dev/) (OSS — OSS)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) is an open-source Agentic Process Orchestrator — a process layer inside [Cursor](https://cursor.com/), [Codex](https://openai.com/codex/), and [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) that composes workflows, enforces hook gates, and records skills.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Operational depth**: Requires agent-ops maturity to realise full value.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Silver Bullet](https://sb.alolabs.dev/).
* **Avoid If**: You need capabilities [Silver Bullet](https://sb.alolabs.dev/) lacks in the matrix (Predictable pricing, Managed hosting).

## 7. SDLC Plugins & Methodology Packs — Top Open Source Solutions (8 core)

### [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) (OSS — OSS)

* **Overview**: [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) is MIT-licensed, bring-your-own-model, and had approached ~49k GitHub stars — the highest-distribution OSS substitute in the secondary market.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD).
* **Avoid If**: You need capabilities [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done) (OSS — OSS)

* **Overview**: [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done) is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) meta-prompting / spec-driven system for structured agent delivery loops.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done).
* **Avoid If**: You need capabilities [GSD](https://github.com/gsd-build/get-shit-done) (Get Shit Done) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP) (OSS — OSS)

* **Overview**: [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP) is a host-integrated plugin pack; satisfies plugin_skill_hook_packaging + process_layer_above_host. Lifecycle coverage narrower than BMAD/[Superpowers](https://github.com/obra/superpowers).
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Operational depth**: Requires agent-ops maturity to realise full value.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP).
* **Avoid If**: You need capabilities [Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP) lacks in the matrix (Predictable pricing, Managed hosting).

### [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) (OSS — OSS)

* **Overview**: Ruflo (formerly Claude Flow, by ruvnet) packages the SPARC methodology — Specification, Pseudocode, Architecture, Refinement, Completion — as a test-driven process layer over [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview).
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo).
* **Avoid If**: You need capabilities [Ruflo / Claude Flow](https://github.com/ruvnet/ruflo) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [GitHub Spec Kit](https://github.com/github/spec-kit) (OSS — OSS)

* **Overview**: [GitHub spec-kit](https://github.com/github/spec-kit) makes specifications executable via constitution.md principles and spec-driven development workflows.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [GitHub Spec Kit](https://github.com/github/spec-kit).
* **Avoid If**: You need capabilities [GitHub Spec Kit](https://github.com/github/spec-kit) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude) (OSS — OSS)

* **Overview**: [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude) provides config + skill layers (flags, modes, agent personas) for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview); satisfies plugin_skill_hook_packaging + process_layer_above_host. Mostly configuration rather than enforced gates — partial on deterministic_gates.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude).
* **Avoid If**: You need capabilities [SuperClaude](https://github.com/SuperClaude-Org/SuperClaude) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Superpowers](https://github.com/obra/superpowers) (OSS — OSS)

* **Overview**: [Superpowers](https://github.com/obra/superpowers) (Jesse Vincent / obra) installs a composable skills framework into [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) covering brainstorming, design, plan-writing, TDD, systematic debugging, subagent-driven development with built-in code review, and skill authoring — multi-phase lifecycle_span in plugin packaging.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Free tier / OSS core**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Superpowers](https://github.com/obra/superpowers).
* **Avoid If**: You need capabilities [Superpowers](https://github.com/obra/superpowers) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Zuvo](https://zuvo.dev/) (OSS — OSS)

* **Overview**: [Zuvo](https://zuvo.dev/) could not be corroborated by open web search in this retrieval pass; its OSS license status is asserted by the category pack and must be verified against a primary repo/license file before the solution card asserts licensing.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Zuvo](https://zuvo.dev/).
* **Avoid If**: You need capabilities [Zuvo](https://zuvo.dev/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

## 8. Agentic SDLC SaaS & Autonomous Delivery — Top Commercial Solutions (10 core)

### [Augment Cosmos](https://www.augmentcode.com/) (Commercial)

* **Overview**: [Augment Cosmos](https://www.augmentcode.com/) self-describes as 'the operating system for agentic software development', with agents running in the customer env or Augment cloud across the SDLC and humans steering where judgment matters.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Augment Cosmos](https://www.augmentcode.com/).
* **Avoid If**: You need capabilities [Augment Cosmos](https://www.augmentcode.com/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) (Commercial)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) self-positions as an orchestration layer that runs inside [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), or [Cursor](https://cursor.com/) sessions rather than replacing the host runtime — satisfying process_layer_above_host and plugin_skill_hook_packaging.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview).
* **Avoid If**: You need capabilities [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) lacks in the matrix (Predictable pricing, Managed hosting).

### [Codex](https://openai.com/codex/) (Commercial)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) self-positions as an orchestration layer that runs inside [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), or [Cursor](https://cursor.com/) sessions rather than replacing the host runtime — satisfying process_layer_above_host and plugin_skill_hook_packaging.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Codex](https://openai.com/codex/).
* **Avoid If**: You need capabilities [Codex](https://openai.com/codex/) lacks in the matrix (Predictable pricing, Managed hosting).

### [Cognition Scout](https://cognition.ai/) (Commercial)

* **Overview**: [Cognition Scout](https://cognition.ai/) is Cognition's agent surface adjacent to [Devin](https://devin.ai/) for scoped autonomous engineering tasks.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Cognition Scout](https://cognition.ai/).
* **Avoid If**: You need capabilities [Cognition Scout](https://cognition.ai/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Cursor](https://cursor.com/) (Commercial)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) self-positions as an orchestration layer that runs inside [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/), or [Cursor](https://cursor.com/) sessions rather than replacing the host runtime — satisfying process_layer_above_host and plugin_skill_hook_packaging.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Cursor](https://cursor.com/).
* **Avoid If**: You need capabilities [Cursor](https://cursor.com/) lacks in the matrix (Predictable pricing, Managed hosting).

### [Devin](https://devin.ai/) (Commercial)

* **Overview**: [Devin](https://devin.ai/) is Cognition's autonomous software engineer that plans, implements, tests, and ships code via pull requests in customer repositories.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Devin](https://devin.ai/).
* **Avoid If**: You need capabilities [Devin](https://devin.ai/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [Factory.ai](https://www.factory.ai/) (Commercial)

* **Overview**: [Factory.ai](https://www.factory.ai/) provides managed Droids with workflow composition, parent/child delegation, review loops, and cloud hosting for agentic software delivery.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Factory.ai](https://www.factory.ai/).
* **Avoid If**: You need capabilities [Factory.ai](https://www.factory.ai/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

### [GitHub Copilot](https://github.com/features/copilot) (Commercial)

* **Overview**: [Cursor](https://cursor.com/), [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview), [Codex](https://openai.com/codex/) CLI, [GitHub Copilot](https://github.com/features/copilot) are host runtimes — adjacent only per pack exclusion `host_runtime`. Never Top-N/MQ/Wave; list in Adjacent or host-runtime row in solution cards.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [GitHub Copilot](https://github.com/features/copilot).
* **Avoid If**: You need capabilities [GitHub Copilot](https://github.com/features/copilot) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Magic.dev](https://magic.dev/) (Commercial)

* **Overview**: [Magic.dev](https://magic.dev/) builds long-context coding models and agents aimed at large-repo autonomous engineering tasks.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
  * **Ecosystem momentum**: Active presence in the agentic SDLC orchestration category.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **Weak hook gates**: Lacks explicit fail-closed lifecycle hooks versus process-first peers.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Magic.dev](https://magic.dev/).
* **Avoid If**: You need capabilities [Magic.dev](https://magic.dev/) lacks in the matrix (Atomic flow catalog, Hook-enforced gates).

### [Tembo](https://tembo.io/) (Commercial)

* **Overview**: [Tembo](https://tembo.io/) runs cloud agents across repos, tickets, and tools with reviewable sessions and automations for startup engineering teams.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **IDE-native integration**: Supported in startup-weighted comparison matrix.
  * **Skill/plugin marketplace**: Supported in startup-weighted comparison matrix.
  * **Managed path**: Commercial offering with vendor-operated components.
* **Major Cons**:
  * **Hosting burden**: May require self-managed integration for some deployment paths.
  * **No atomic catalog**: No machine-readable atomic-flow catalog in evaluated matrix.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Tembo](https://tembo.io/).
* **Avoid If**: You need capabilities [Tembo](https://tembo.io/) lacks in the matrix (Atomic flow catalog, Predictable pricing).

## 9. Adjacent Markets (not core peers)

Products below are relevant context but **not** scored on the Magic Quadrant, Wave, or comparison matrix.

- **[AxonFlow](https://www.axonflow.ai/)** (`axonflow`) — pack adjacent_seed
- **[Cavekit v4](https://cavekit.ai/)** (`cavekit-v4`) — pack adjacent_seed
- **[CrewAI](https://github.com/crewAIInc/crewAI)** (`crewai`) — pack adjacent_seed
- **[LangChain](https://github.com/langchain-ai/langchain)** (`langchain`) — pack adjacent_seed
- **[LangGraph](https://www.langchain.com/langgraph)** (`langgraph`) — pack adjacent_seed
- **[MetaGPT](https://github.com/FoundationAgents/MetaGPT)** (`metagpt`) — pack adjacent_seed
- **[Replit Agent](https://replit.com/)** (`replit-agent`) — pack adjacent_seed

## 10. Explicitly Excluded

- **[Aider](https://github.com/paul-gauthier/aider)** — pack hard_exclusion (coding_agent)
- **[Amazon Q Developer](https://aws.amazon.com/q/developer/)** — hard_veto from need_profile
- **[Cline](https://github.com/cline/cline)** — pack hard_exclusion (coding_agent)
- **[CodeRabbit](https://coderabbit.ai/)** — hard_veto from need_profile
- **[Continue](https://github.com/continuedev/continue)** — pack hard_exclusion (coding_agent)
- **[[Cursor](https://cursor.com/) Background Agents](https://cursor.com/docs/background-agent)** — hard_veto from need_profile
- **[[GitHub Copilot](https://github.com/features/copilot) Enterprise](https://github.com/features/copilot)** — pack hard_exclusion (coding_agent)
- **[JetBrains AI Assistant](https://www.jetbrains.com/ai/)** — hard_veto from need_profile
- **Linear** — pack hard_exclusion (project_management)
- **[Open Interpreter](https://github.com/OpenInterpreter/open-interpreter)** — pack hard_exclusion (coding_agent)
- **[OpenHands](https://github.com/All-Hands-AI/OpenHands)** — pack hard_exclusion (coding_agent)
- **[Poolside](https://poolside.ai/)** — hard_veto from need_profile
- **[Sourcegraph Cody](https://sourcegraph.com/cody)** — hard_veto from need_profile
- **[SWE-agent](https://github.com/SWE-agent/SWE-agent)** — pack hard_exclusion (coding_agent)
- **[Sweep](https://sweep.dev/)** — hard_veto from need_profile
- **[Windsurf](https://codeium.com/windsurf)** — hard_veto from need_profile
- **[AgentGPT](https://github.com/reworkd/AgentGPT)** — Abandoned / non-production
- **AutoGen** — Microsoft shifted to Agent Framework; legacy status
- **[[GitHub Copilot](https://github.com/features/copilot) Workspace](https://githubnext.com/projects/copilot-workspace)** — Discontinued by GitHub
- **[Devika](https://github.com/stitionai/devika)** — Project discontinued

## 11. Buying Guidance & Shortlist Profiles

- **Lean startup, process-first**: Prioritise workflow composition, atomic catalog, and hook gates — shortlist **[Oh My Pi](https://github.com/nicobailon/oh-my-pi) (OMP)** and peers: [AgentHub](https://www.agenthub.ai/), [AgentSys](https://agentsys.ai/), [AI-DLC](https://aws.amazon.com/ai-dlc/), [ATeam](https://www.a.team/), [Barkain Workflow Orchestrator](https://barkain.com/).
- **Open-source-first**: Prioritise [Silver Bullet](https://sb.alolabs.dev/) and OSS core orchestrators — budget for hook and catalog integration.
- **Host-runtime path**: Use Adjacent host runtimes ([Devin](https://devin.ai/), [Cursor](https://cursor.com/)) with a separate process layer — do not conflate with APO peers.

## 12. Future Outlook & Emerging Disruptors

### [Silver Bullet](https://sb.alolabs.dev/) (OSS — Open Source)

* **Overview**: [Silver Bullet](https://sb.alolabs.dev/) is an open-source Agentic Process Orchestrator — a process layer inside [Cursor](https://cursor.com/), [Codex](https://openai.com/codex/), and [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) that composes workflows, enforces hook gates, and records skills.
* **Major Pros**:
  * **Workflow composition**: Supported in startup-weighted comparison matrix.
  * **Atomic flow catalog**: Supported in startup-weighted comparison matrix.
  * **Parent/child agent delegation**: Supported in startup-weighted comparison matrix.
  * **Hook-enforced gates**: Supported in startup-weighted comparison matrix.
  * **Quick onboarding**: Supported in startup-weighted comparison matrix.
  * **Control & flexibility**: OSS/core deployable on your infrastructure.
* **Major Cons**:
  * **Operational depth**: Requires agent-ops maturity to realise full value.
  * **Pricing opacity**: Verify latest pricing — list prices were not web-verified in this synthesis.
* **Best For**: SMB teams prioritising workflow composition with [Silver Bullet](https://sb.alolabs.dev/).
* **Avoid If**: You need capabilities [Silver Bullet](https://sb.alolabs.dev/) lacks in the matrix (Predictable pricing, Managed hosting).

### Router-first APO catalogs
- Process routers with Authorizer trust and nested V-loops may become default SB-style differentiators. **SMB implication**: Threatens executor-only agents.

### Multi-model triangulation as a buying step
- Consensus/divergence synthesis becomes part of procurement for niche categories. **SMB implication**: Advantages transparency-first vendors.

### Consolidation of git-native agents
- Issue→PR agents may merge with SDLC orchestration platforms. **SMB implication**: Threatens point tools without ecosystem depth.

## 13. Source Reliability Assessment

### Model response weights

| Source | Response Size | Weight Applied | Assessment |
|--------|--------------|----------------|------------|
| claude-opus-4.8-medium | 40906 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| gemini-3.5-flash | 30489 chars | **Heavy—Primary** | Contributed DR phases with structured payloads; depth varies by phase. |
| gpt-5.6-luna-medium | 24786 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-deepseek-v4-flash | 26086 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-kimi-k2.7-code | 21675 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-mimo-v2.5 | 25338 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-minimax-m3 | 32584 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |
| ocg-qwen3.7-plus | 28591 chars | **Good—Secondary** | Contributed DR phases with structured payloads; depth varies by phase. |

**Consensus patterns**: No cross-family consensus claims in triangulation — see divergence.

**Notable divergences**:
- Adjacent-only band ([LangGraph](https://www.langchain.com/langgraph), [CrewAI](https://github.com/crewAIInc/crewAI), [MetaGPT](https://github.com/FoundationAgents/MetaGPT), [LangChain](https://github.com/langchain-ai/langchain), [AxonFlow](https://www.axonflow.ai/), [Cavekit v4](https://cavekit.ai/)) is excluded from Top-N/MQ/Wave/matrix per pack: they are generic agent frameworks without a shipped, enforced SDLC process product.
- [AI-DLC](https://aws.amazon.com/ai-dlc/) (IBM) is the weakest APO core seed by enforcement depth: it defines a conceptual lifecycle for methodology guidance without shipping deterministic gates, cross-session state, or host-integrated plugin packaging. It belongs in the APO market per inclusion criteria §Multi-phase lifecycle span alone but ranks below all shipped products.
- [AI-DLC](https://aws.amazon.com/ai-dlc/) is a methodology/framework rather than a shipped host-integrated product; it should appear in the APO market chart as a low-packaging, high-lifecycle-span outlier that shapes buyer vocabulary without being directly substitutable.
- [AI-DLC](https://aws.amazon.com/ai-dlc/) represents enterprise-grade APO with IBM-backed lifecycle orchestration and DevOps integration
- [Augment Cosmos](https://www.augmentcode.com/) (not [Augment Code](https://www.augmentcode.com/)) is the correct product-level name for the tertiary market entry
- [Augment Cosmos](https://www.augmentcode.com/) (not [Augment Code](https://www.augmentcode.com/)) is the correct product-level name for the tertiary market entry; [Augment Code](https://www.augmentcode.com/) is the parent company brand.
- [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) is a methodology pack (breakthrough-method-for-agentic-driven-development) that supplies phased SDLC roles and templates; it is plugin/skill-hook packaged, deterministic-gated via its template contracts, and orchestrates specialist agents — passing ≥3 inclusion criteria, so it must appear in solution cards even though it does not self-label APO.
- [cc10x](https://cc10x.dev/) and [Conductor](https://conductor.build/) form a mid-tier APO cluster sharing complementary strengths: [Conductor](https://conductor.build/) has stronger workflow orchestration UI and cross-session state; [cc10x](https://cc10x.dev/) has deeper [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) hook integration, deterministic gates, and release enforcement. Neither matches SB's specialist agent routing or cross-host coverage.
